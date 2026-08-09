import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Resources
import Testing

/// D-G5B-01: what a `.missingFiles` validation verdict is allowed to make DURABLE, and what it must
/// leave transient.
///
/// The suite is deliberately piecewise, because the contract is. On one side of the boundary the
/// validate-time reconciliation finds positive evidence — a successful page-file scan that names the
/// pages whose files are gone — and the record is corrected on disk: the hashes of exactly those
/// pages are blanked, the manifest is written, the index is updated, and the transient
/// `validationErrors` entry is dropped so nothing outranks the honest record. On the other side the
/// blanking loop refuses (a failed scan, or a shape where every claimed page would be blanked at
/// once), the manifest is left verbatim, and the `validationErrors` entry is what the user sees.
///
/// Each arm asserts its OWN regime and borrows nothing from the other's expectations: a single
/// blanket assertion across the boundary would either pin the refusal family to a correction it
/// never receives, or accept a durable arm that quietly did nothing. Both arms pin their reading
/// after a RELAUNCH — a second coordinator built over the same storage root — because durability is
/// the whole point of the durable arm and the refusal arm's residual is only honest if its
/// post-relaunch reading is stated rather than assumed.
struct DownloadValidationReconciliationTests: DownloadFeatureTestCase {
    /// The durable arm: a partially-missing gallery is corrected on disk by the validation that
    /// found it, so the record, the count and the start gates all read one truth.
    ///
    /// Three of the three claimed pages are recorded complete, pages 1 and 3 really exist with the
    /// bytes their hashes name, and page 2's file is gone — the reported scenario in miniature. The
    /// scan classifies every page, so the blanking covers the missing SET rather than the single
    /// page `storage.validate` short-circuits on, and the record afterwards reads 2 of 3 with no
    /// error over it: `.inactive`, which is what `canTogglePause` accepts and what `resumeMode`
    /// resolves to `.repair`.
    @Test
    func testValidatingAPartiallyMissingGalleryBlanksExactlyTheMissingPagesOnDisk() async throws {
        let gallery = SessionGallery(
            gid: "215601",
            title: "Reconciled",
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

        try writePageFiles(for: gallery, in: fixture, indices: [1, 3])
        try recordRealPageHashes(for: gallery, in: fixture, indices: [1, 3])
        await fixture.manager.reloadDownloadIndex()

        let validation = await fixture.manager.validateImageData(gid: gallery.gid)

        #expect(validation == .missingFiles(.RLocalizable.downloadStorePageMissing(page: 2)))
        let download = try #require(await fixture.manager.fetchDownload(gid: gallery.gid))
        #expect(download.displayStatus == .inactive)
        #expect(download.lastError == nil)
        #expect(download.completedPageCount == 2)

        // Disk truth, not derived state: the persisted manifest is the basis every reading above is
        // supposed to come from, so it is read back directly.
        let folderURL = galleryFolderURL(for: gallery, in: fixture)
        let diskManifest = try fixture.storage.readManifest(folderURL: folderURL)
        #expect(diskManifest.pages[2] == "")
        #expect(diskManifest.pages[1]?.isEmpty == false)
        #expect(diskManifest.pages[3]?.isEmpty == false)
        #expect(diskManifest.completedPageCount == 2)

        // The relaunch pin: a fresh coordinator over the same storage holds none of this session's
        // in-memory state, so anything it still reads correctly was carried by the record alone.
        let relaunched = DownloadCoordinator(
            storage: DownloadStore(rootURL: fixture.rootURL, fileManager: .default),
            urlSession: .shared
        )
        await relaunched.reloadDownloadIndex()
        let reread = try #require(await relaunched.fetchDownload(gid: gallery.gid))
        #expect(reread.displayStatus == .inactive)
        #expect(reread.completedPageCount == 2)
        #expect(reread.canTogglePause)
        #expect(await relaunched.resumeMode(for: reread) == .repair)
    }

    /// The refusal arm: blanking that would empty every claimed hash at once is refused, so the
    /// verdict stays the transient `validationErrors` entry it has always been.
    ///
    /// The single-page fixture is the smallest wholesale shape — one claimed page, no file — so the
    /// all-or-nothing guard fires. That guard is the irreversibility defence: the manifest was just
    /// read out of this very folder, so a listing that explains NO claimed page at all is more
    /// likely a shape neither per-page signal caught than proof that everything vanished. The
    /// on-disk hash is asserted intact precisely because a refusal and a blanking are otherwise
    /// indistinguishable from the derived status alone.
    @Test
    func testWholesaleBlankingIsRefusedSoTheSessionErrorStandsAndTheClaimedHashSurvives() async throws {
        let gallery = SessionGallery(
            gid: "215602",
            title: "Missing",
            pageCount: 1,
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

        let folderURL = galleryFolderURL(for: gallery, in: fixture)
        let claimedHash = try #require(
            fixture.storage.readManifest(folderURL: folderURL).pages[1]
        )

        let validation = await fixture.manager.validateImageData(gid: gallery.gid)

        #expect(validation == .missingFiles(.RLocalizable.downloadStorePageMissing(page: 1)))
        let download = try #require(await fixture.manager.fetchDownload(gid: gallery.gid))
        #expect(download.displayStatus == .error)
        #expect(download.lastError?.code == .fileOperationFailed)

        // The refusal's whole substance: the recorded hash is still on disk, untouched.
        let diskManifest = try fixture.storage.readManifest(folderURL: folderURL)
        #expect(diskManifest.pages[1] == claimedHash)
        #expect(diskManifest.completedPageCount == 1)

        // The documented residual, pinned rather than hidden: `validationErrors` is session-scoped
        // by design, and the record the refusal preserved still claims its page — so a fresh
        // process reads this gallery as `.completed` until the user validates again. That is the
        // irreversibility defence working as designed, not a durability miss; the wholesale shape
        // is exactly the one the guard cannot distinguish from a probe that explained nothing.
        let relaunched = DownloadCoordinator(
            storage: DownloadStore(rootURL: fixture.rootURL, fileManager: .default),
            urlSession: .shared
        )
        await relaunched.reloadDownloadIndex()
        let reread = try #require(await relaunched.fetchDownload(gid: gallery.gid))
        #expect(reread.displayStatus == .completed)
        #expect(reread.lastError == nil)
    }
}

private extension DownloadValidationReconciliationTests {
    func galleryFolderURL(for gallery: SessionGallery, in fixture: SessionFixture) -> URL {
        fixture.storage.folderURL(
            relativePath: "Folder/[\(gallery.gid)_token] \(gallery.title)"
        )
    }

    /// Replaces the fixture's placeholder hashes for `indices` with the real hashes of the page
    /// files `writePageFiles` just landed.
    ///
    /// Content validation compares recorded hashes against the bytes on disk, so a surviving page
    /// carrying a placeholder hash would be reported corrupted and short-circuit the verdict before
    /// it ever reached the genuinely missing page. Aligning the surviving pages is what makes the
    /// missing one the thing under test.
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
