import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Resources
import Testing

/// D-SSOT-07: what the inspector's per-page states are DERIVED from.
///
/// The derivation under test is `buildInspectionPages`, and every case reaches it through
/// `loadInspection` — the production entry point the inspector itself calls — over a real storage
/// fixture, so a case that passes says the shipped route derives what it claims rather than that a
/// helper does when called directly.
///
/// The badge counts pages by the manifest's non-empty hashes (`completedPageCount`). If the
/// inspector's page states came from a live file-presence probe instead, the two displays would be
/// two different functions of two different inputs, and they would disagree in exactly the window
/// G-15-5 exposed: files deleted outside the app, the record still claiming complete, the badge
/// reading 3-of-3 while the page list reads one pending. This suite pins the single basis that
/// removes that possibility — a page's status is a function of (recorded hash, recorded page
/// failure) alone — and it pins it from BOTH sides of the divergence window, because the honest
/// pre-validate reading (the record's claim) and the converged post-validate reading (the
/// reconciled record) are different assertions and only one of them is about the fix.
///
/// The live directory listing survives with exactly one job: resolving a page's on-disk
/// relativePath/fileURL so a thumbnail can render. That resource is asserted separately from the
/// status precisely because the two are now independent — a page can read `.downloaded` with no
/// file to show (the record's claim, pre-validate) and a page can read `.pending` with a file
/// sitting at its path (the totality case). Validate is the single tap that senses such a
/// divergence and reconciles it durably; nothing else is allowed to sense it.
struct DownloadInspectionBasisTests: DownloadFeatureTestCase {
    /// Claim-vs-disk divergence, PRE-validate: an externally deleted page still reads the record's
    /// claim, so the page list and the badge cannot disagree.
    ///
    /// Three claimed pages with real hashes and real files, then page 2's file is deleted behind the
    /// app's back — the reported scenario in miniature. The inspector reports all three
    /// `.downloaded`, which is what the record says and what the badge shows; only the rendering
    /// resource for page 2 is gone, which is the approved appearance for a stale-but-honest reading.
    @Test
    func testAnExternallyDeletedPageStillReadsTheRecordsClaimBeforeValidation() async throws {
        let gallery = SessionGallery(
            gid: "215901",
            title: "Claiming",
            pageCount: 3,
            completedPageCount: 3
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        try writePageFiles(for: gallery, in: fixture, indices: [1, 2, 3])
        try recordRealPageHashes(for: gallery, in: fixture, indices: [1, 2, 3])
        try FileManager.default.removeItem(at: pageFileURL(for: gallery, in: fixture, index: 2))
        await fixture.manager.reloadDownloadIndex()

        let inspection = try await fixture.manager.loadInspection(gid: gallery.gid).get()

        #expect(inspection.pages.map(\.status) == [.downloaded, .downloaded, .downloaded])
        // The construction the whole plan is for: the page list's downloaded set IS the set the
        // badge counts, so the two readings are one function of one input.
        #expect(downloadedCount(in: inspection) == inspection.download.completedPageCount)
        #expect(inspection.download.completedPageCount == 3)

        // The rendering resource, asserted separately from the status: the deleted page has nothing
        // to show, and that is all the deletion is allowed to change before Validate runs.
        let deleted = try requirePage(2, in: inspection)
        #expect(deleted.fileURL == nil)
        #expect(deleted.relativePath == nil)
        #expect(try requirePage(1, in: inspection).fileURL != nil)
        #expect(try requirePage(3, in: inspection).fileURL != nil)
    }

    /// Convergence, POST-validate: the same divergence, sensed and durably reconciled by the single
    /// tap, converges the page list and the badge together.
    ///
    /// This is the other side of the window, and it is a different assertion from the case above
    /// rather than its continuation: pre-validate the inspector must show the claim, post-validate it
    /// must show the correction. Both readings come from the same derivation — only the record moved.
    @Test
    func testValidatingConvergesTheInspectorOnTheReconciledRecord() async throws {
        let gallery = SessionGallery(
            gid: "215902",
            title: "Converging",
            pageCount: 3,
            completedPageCount: 3
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        try writePageFiles(for: gallery, in: fixture, indices: [1, 2, 3])
        try recordRealPageHashes(for: gallery, in: fixture, indices: [1, 2, 3])
        try FileManager.default.removeItem(at: pageFileURL(for: gallery, in: fixture, index: 2))
        await fixture.manager.reloadDownloadIndex()

        let validation = await fixture.manager.validateImageData(gid: gallery.gid)

        #expect(validation == .missingFiles(.RLocalizable.downloadStorePageMissing(page: 2)))
        let inspection = try await fixture.manager.loadInspection(gid: gallery.gid).get()

        let reconciled = try requirePage(2, in: inspection)
        #expect(reconciled.status == .pending)
        #expect(reconciled.fileURL == nil)
        #expect(downloadedCount(in: inspection) == 2)
        #expect(downloadedCount(in: inspection) == inspection.download.completedPageCount)
    }

    /// Totality: a blank-hash page reads `.pending` even with a stray file at its path.
    ///
    /// 15-58's no-laundering invariant makes this shape transient in production, but the derivation
    /// has to be TOTAL over it: a status that consulted presence anywhere would report this page
    /// downloaded while the record — and therefore the badge — counted it as undone. The stray file
    /// is still resolved as a rendering resource, which is exactly the demotion under test: visible
    /// to the view, invisible to the status.
    @Test
    func testABlankHashedPageReadsPendingEvenWhenAStrayFileSitsAtItsPath() async throws {
        let gallery = SessionGallery(
            gid: "215903",
            title: "Stray",
            pageCount: 3,
            completedPageCount: 2
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        try writePageFiles(for: gallery, in: fixture, indices: [1, 2, 3])
        await fixture.manager.reloadDownloadIndex()

        let inspection = try await fixture.manager.loadInspection(gid: gallery.gid).get()

        let stray = try requirePage(3, in: inspection)
        #expect(stray.status == .pending)
        #expect(stray.fileURL != nil)
        #expect(inspection.pages.filter({ $0.status == .downloaded }).map(\.index) == [1, 2])
        #expect(downloadedCount(in: inspection) == inspection.download.completedPageCount)
    }

    /// Precedence, unchanged: a recorded page failure still wins over pending.
    ///
    /// The failure branch is not what moved — only the branch ahead of it did — so the ordering is
    /// pinned here rather than assumed: a blank-hash page with a recorded failure reads `.failed`
    /// with its failure attached, and its sibling with a recorded hash still reads `.downloaded`.
    @Test
    func testABlankHashedPageWithARecordedFailureReadsFailed() async throws {
        let gallery = SessionGallery(
            gid: "215904",
            title: "Failing",
            pageCount: 2,
            completedPageCount: 1
        )
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [],
            client: spy.client,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        try writePageFiles(for: gallery, in: fixture, indices: [1])
        await fixture.manager.reloadDownloadIndex()
        await fixture.manager.testingSetFailedPageErrors(
            [
                .init(
                    index: 2,
                    relativePath: "\(gallery.gid)_token_2.jpg",
                    error: .networkingFailed
                )
            ],
            gid: gallery.gid
        )

        let inspection = try await fixture.manager.loadInspection(gid: gallery.gid).get()

        #expect(try requirePage(1, in: inspection).status == .downloaded)
        let failed = try requirePage(2, in: inspection)
        #expect(failed.status == .failed)
        #expect(failed.failure?.code == .networkingFailed)
        #expect(failed.fileURL == nil)
    }
}

// MARK: - Setup Helpers

private extension DownloadInspectionBasisTests {
    func downloadedCount(in inspection: DownloadInspection) -> Int {
        inspection.pages.filter({ $0.status == .downloaded }).count
    }

    func requirePage(
        _ index: Int,
        in inspection: DownloadInspection
    ) throws -> DownloadPageInspection {
        try #require(inspection.pages.first(where: { $0.index == index }))
    }

    func galleryFolderURL(for gallery: SessionGallery, in fixture: SessionFixture) -> URL {
        fixture.storage.folderURL(
            relativePath: "Folder/[\(gallery.gid)_token] \(gallery.title)"
        )
    }

    func pageFileURL(
        for gallery: SessionGallery,
        in fixture: SessionFixture,
        index: Int
    ) -> URL {
        galleryFolderURL(for: gallery, in: fixture)
            .appendingPathComponent(
                fixture.storage.makePageRelativePath(
                    gid: gallery.gid,
                    token: "token",
                    index: index,
                    fileExtension: "jpg"
                )
            )
    }

    /// Replaces the fixture's placeholder hashes for `indices` with the real hashes of the page
    /// files `writePageFiles` just landed.
    ///
    /// Validation compares recorded hashes against the bytes on disk, so a surviving page carrying a
    /// placeholder hash would be reported corrupted and short-circuit the verdict before it reached
    /// the page whose file this suite actually deletes.
    func recordRealPageHashes(
        for gallery: SessionGallery,
        in fixture: SessionFixture,
        indices: [Int]
    ) throws {
        let pageRelativePaths = indices.reduce(into: [Int: String]()) { paths, index in
            paths[index] = fixture.storage.makePageRelativePath(
                gid: gallery.gid,
                token: "token",
                index: index,
                fileExtension: "jpg"
            )
        }
        try fixture.storage.refreshManifestPageFileHashes(
            folderURL: galleryFolderURL(for: gallery, in: fixture),
            pageRelativePaths: pageRelativePaths
        )
    }
}
