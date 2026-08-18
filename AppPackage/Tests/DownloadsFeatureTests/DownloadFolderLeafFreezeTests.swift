import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing

/// The gallery folder's readable leaf is chosen ONCE and never recomputed (G-15-2H).
///
/// The downloads directory is user-visible and user-managed through the Files app, so re-deriving
/// `[gid_token] Title` from a fresh network payload on every run made an upstream title edit
/// silently move the user's data: the recomputed path did not exist, the preparation materialized a
/// repair seed at the new name, and the completion sweep deleted the old folder — a rename nobody
/// asked for, observed on device during a whole-gallery repair.
///
/// These four cases pin the freeze from both sides. Three are the locked fix spec's — the same
/// gallery under two titles keeps one folder, a repair over an existing folder reuses it in place,
/// and the PARENT is deliberately not frozen — and the fourth pins the branch the fix leaves
/// untouched, so a gallery with no record still derives a fresh leaf from its payload.
///
/// **Choreography discipline.** Every folder name asserted against is produced by a production API
/// (`DownloadStore.makeFolderRelativePath`, `DownloadCoordinator.folderRelativePath`,
/// `DownloadStore.galleryFolderURLs`), never spelled as a literal, so a naming change fails here
/// rather than leaving the suite green against a layout that no longer exists.
@Suite
struct DownloadFolderLeafFreezeTests: DownloadFeatureTestCase {
    /// A title carrying no `|`, so `trimmedTitle` keeps the whole of it.
    private static let titleWithoutPipe = "Onna no Battle Woman's Battle"
    /// The same gallery as upstream later reports it. `trimmedTitle` truncates at the first `|`,
    /// which is what made the recomputed leaf differ from the stored one on device.
    private static let titleWithPipe = "Onna no Battle | Woman's Battle"

    /// Fix-spec test 1: two runs whose payload titles differ leave ONE folder on disk, under the
    /// leaf the first run created.
    @Test
    func testTwoRunsWithDifferingTitlesKeepOneFolderUnderTheFirstLeaf() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared,
            queueStore: DownloadQueueStore(fileURL: storage.queueURL())
        )
        // A foreign gallery holds the active slot, so neither enqueue can start a run underneath
        // an assertion — the `DownloadEnqueueManifestTests` idiom.
        await manager.testingInstallActiveTask(gid: "busy", task: Task {})

        let gallery = sampleGallery()
        let detailA = sampleGalleryDetail(gid: gallery.gid, title: Self.titleWithoutPipe)
        let detailB = sampleGalleryDetail(gid: gallery.gid, title: Self.titleWithPipe)

        await manager.reloadDownloadIndex()
        await expectEnqueueSucceeds(
            manager: manager,
            payload: leafPayload(gallery: gallery, detail: detailA, mode: .initial)
        )

        let leafA = storage.makeFolderRelativePath(
            gid: gallery.gid,
            token: gallery.token,
            title: detailA.trimmedTitle
        )
        let folderURLA = storage.folderURL(relativePath: "Folder/\(leafA)")
        #expect(FileManager.default.fileExists(atPath: folderURLA.path))
        // Non-vacuity: the second payload really would derive a DIFFERENT leaf, so the reuse below
        // is the freeze rather than two titles that happen to normalize alike.
        let leafB = storage.makeFolderRelativePath(
            gid: gallery.gid,
            token: gallery.token,
            title: detailB.trimmedTitle
        )
        #expect(leafB != leafA)

        let payloadB = leafPayload(gallery: gallery, detail: detailB, mode: .repair)
        #expect(
            await manager.folderRelativePath(for: payloadB, parentFolderName: "Folder")
                == "Folder/\(leafA)"
        )
        // The already-known route: `enqueue` keeps the record's parent folder, and the leaf must
        // now stay put too.
        await expectEnqueueSucceeds(manager: manager, payload: payloadB)

        #expect(
            storage.galleryFolderURLs(gid: gallery.gid, token: gallery.token)
                .map(\.lastPathComponent) == [leafA]
        )
        let manifest = try storage.readManifest(folderURL: folderURLA)
        #expect(manifest.gid == gallery.gid)
        #expect(manifest.token == gallery.token)
    }

    /// Fix-spec test 2: a `.repair` whose payload title differs reuses the existing folder in place,
    /// keeping the page files already there and creating no second folder.
    @Test
    func testARepairOverAnExistingFolderReusesItInPlace() async throws {
        let fixture = try await makeFrozenLeafFixture()
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        let storage = fixture.storage

        try writePageFiles(for: Self.stagedGallery, in: fixture, indices: [1, 2])
        await manager.reloadDownloadIndex()
        let staged = try #require(await manager.fetchDownload(gid: Self.stagedGallery.gid))
        #expect(await manager.resumeMode(for: staged) == .repair)

        let payload = makeRepairPayload(for: Self.retitledGallery)
        // Non-vacuity: the payload's own title derives a leaf that differs from the staged folder's.
        #expect(
            storage.makeFolderRelativePath(
                gid: Self.retitledGallery.gid,
                token: "token",
                title: Self.retitledGallery.title
            ) != staged.folderURL.lastPathComponent
        )

        let relativePath = await manager.folderRelativePath(
            for: payload,
            parentFolderName: staged.folderName
        )
        let folderURL = storage.folderURL(relativePath: relativePath)
        #expect(folderURL.standardizedFileURL == staged.folderURL.standardizedFileURL)

        let seed = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: payload,
            folderURL: folderURL
        ).workingSeed

        // Reused in place: the two staged files are inherited rather than re-fetched, and no second
        // folder was materialized for this gallery.
        #expect(seed.existingPages.keys.sorted() == [1, 2])
        #expect(
            storage.galleryFolderURLs(gid: staged.gid, token: staged.token)
                .map(\.standardizedFileURL) == [staged.folderURL.standardizedFileURL]
        )
        let manifest = try storage.readManifest(folderURL: staged.folderURL)
        #expect(manifest.gid == staged.gid)
    }

    /// Fix-spec test 3: only the LEAF is frozen. The parent still follows the caller, so an in-app
    /// move still relocates the gallery.
    @Test
    func testTheLeafIsFrozenButTheParentIsNot() async throws {
        let fixture = try await makeFrozenLeafFixture()
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager

        await manager.reloadDownloadIndex()
        let staged = try #require(await manager.fetchDownload(gid: Self.stagedGallery.gid))

        #expect(
            await manager.folderRelativePath(
                for: makeRepairPayload(for: Self.retitledGallery),
                parentFolderName: "Elsewhere"
            ) == "Elsewhere/\(staged.folderURL.lastPathComponent)"
        )
    }

    /// The branch the freeze leaves alone: with no record to reuse, the leaf is still derived from
    /// the payload's own trimmed title.
    @Test
    func testAGalleryWithNoRecordStillDerivesAFreshLeaf() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)
        try storage.ensureRootDirectory()
        await manager.reloadDownloadIndex()

        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: Self.titleWithPipe)
        let expectedLeaf = storage.makeFolderRelativePath(
            gid: gallery.gid,
            token: gallery.token,
            title: detail.trimmedTitle
        )

        #expect(
            await manager.folderRelativePath(
                for: leafPayload(gallery: gallery, detail: detail, mode: .initial),
                parentFolderName: "Folder"
            ) == "Folder/\(expectedLeaf)"
        )
    }
}

// MARK: - Helpers

private extension DownloadFolderLeafFreezeTests {
    /// The gallery staged on disk for the two repair cases: a record claiming all three pages, with
    /// page 3's file absent, which is what resolves `.repair`.
    static var stagedGallery: SessionGallery {
        SessionGallery(gid: "260818", title: "Kept Name", pageCount: 3, completedPageCount: 3)
    }

    /// The SAME gallery as a later payload reports it. Post-fix the title difference is inert for
    /// the folder, which is the whole property under test.
    static var retitledGallery: SessionGallery {
        SessionGallery(
            gid: stagedGallery.gid,
            title: "Retitled Elsewhere",
            pageCount: stagedGallery.pageCount,
            completedPageCount: stagedGallery.completedPageCount
        )
    }

    /// The staged gallery with nothing queued and no runner, so the record's own shape is the only
    /// variable the folder derivation has to answer to.
    func makeFrozenLeafFixture() async throws -> SessionFixture {
        try await makeQueuedCoordinator(
            galleries: [Self.stagedGallery],
            queuedGIDs: [],
            client: .noop,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
    }

    func leafPayload(
        gallery: Gallery,
        detail: GalleryDetail,
        mode: DownloadStartMode
    ) -> DownloadRequestPayload {
        DownloadRequestPayload(
            gallery: gallery,
            galleryDetail: detail,
            previewURLs: [:],
            previewConfig: .normal(rows: 4),
            host: .ehentai,
            folderName: "Folder",
            mode: mode
        )
    }

    func expectEnqueueSucceeds(
        manager: DownloadCoordinator,
        payload: DownloadRequestPayload
    ) async {
        let result = await manager.enqueue(payload: payload)
        guard case .success = result else {
            Issue.record("Expected enqueue to succeed, got \(result).")
            return
        }
    }
}
