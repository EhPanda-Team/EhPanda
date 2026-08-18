@testable import AppFeature
import AppModels
import DownloadClient
import Foundation
import Testing

@Suite
struct DownloadInterruptedResumeTests: DownloadFeatureTestCase {
    @Test
    func testInterruptedSessionResolvesNonDestructiveResumeMode() async throws {
        let manager = makeTestingDownloadCoordinator()

        let queuedPartial = sampleDownload(
            gid: "913000001", title: "Interrupted",
            status: .queued, pageCount: 26, completedPageCount: 7
        )
        let activePartial = sampleDownload(
            gid: "913000002", title: "Interrupted",
            status: .downloading, pageCount: 26, completedPageCount: 7
        )
        let queuedUntouched = sampleDownload(
            gid: "913000003", title: "Interrupted",
            status: .queued, pageCount: 26, completedPageCount: 0
        )
        let queuedComplete = sampleDownload(
            gid: "913000004", title: "Interrupted",
            status: .queued, pageCount: 26, completedPageCount: 26
        )

        #expect(await manager.queuedMode(for: queuedPartial) == .repair)
        #expect(await manager.queuedMode(for: activePartial) == .repair)
        #expect(await manager.queuedMode(for: queuedUntouched) == .initial)
        #expect(await manager.queuedMode(for: queuedComplete) == .repair)
    }

    @Test
    func testWipedWorkingFolderStaysIndexedWithFreshManifest() async throws {
        let gid = "913000005"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)

        let folderURL = try writeManifestFolder(
            storage: storage,
            gid: gid,
            title: "Redownload",
            pageHashes: ["sha256:done", ""]
        )
        await manager.reloadDownloadIndex()
        let stalePageURL = folderURL.appendingPathComponent("\(gid)_token_1.jpg")

        let workingSeed = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makePayload(gid: gid, title: "Redownload", mode: .redownload),
            folderURL: folderURL
        ).workingSeed

        #expect(!FileManager.default.fileExists(atPath: stalePageURL.path))
        let persistedManifest = try storage.readManifest(folderURL: folderURL)
        #expect(persistedManifest == workingSeed.manifest)
        #expect(persistedManifest.pageCount == 2)
        #expect(persistedManifest.completedPageCount == 0)
        let stored = await manager.fetchDownload(gid: gid)
        #expect(stored != nil)
    }

    @Test
    func testPauseAfterInterruptedRedownloadKeepsDownloadListed() async throws {
        let gid = "913000006"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)

        let folderURL = try writeManifestFolder(
            storage: storage,
            gid: gid,
            title: "Pause Survives",
            pageHashes: ["sha256:done", ""]
        )
        await manager.reloadDownloadIndex()

        _ = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makePayload(gid: gid, title: "Pause Survives", mode: .redownload),
            folderURL: folderURL
        )
        await manager.testingSetQueuedGalleryIDs([gid])
        let activeTask = Task {
            do {
                try await Task.sleep(for: .seconds(60))
            } catch {}
        }
        await manager.testingInstallActiveTask(gid: gid, task: activeTask)

        let result = await manager.togglePause(gid: gid)

        guard case .success = result else {
            Issue.record("Pause should succeed, got \(result)")
            return
        }
        let stored = await manager.fetchDownload(gid: gid)
        #expect(stored?.displayStatus == .inactive)
        #expect(
            stored?.badge == DownloadBadge(
                status: .inactive,
                progress: .init(completedPageCount: 0, pageCount: 2)
            )
        )
        #expect(FileManager.default.fileExists(atPath: folderURL.path))
    }

    /// The delete route's primitive removes EVERY folder of the gallery it is given, and only that
    /// gallery's.
    ///
    /// The fixture is the two-folders-for-one-gid shape, which used to be staged here for the
    /// completion sweep's keep-one contract. That sweep is retired — no run removes a folder it did
    /// not create (G-15-2H, resolution 2026-08-19) — so the same staging now pins the one caller
    /// that remains, the user's own `delete(gid:)`: both of the gid's folders go, however the user
    /// named them, and the unrelated gallery is untouched.
    @Test
    func testRemoveGalleryFoldersRemovesEveryFolderOfTheGalleryAndNoOther() async throws {
        let gid = "913000007"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)

        let oldFolderURL = try writeManifestFolder(
            storage: storage, gid: gid, title: "Old Title",
            pageHashes: ["sha256:done", "sha256:done"]
        )
        let newFolderURL = try writeManifestFolder(
            storage: storage, gid: gid, title: "New Title",
            pageHashes: ["sha256:done", "sha256:done"]
        )
        let unrelatedFolderURL = try writeManifestFolder(
            storage: storage, gid: "913000008", title: "Unrelated",
            pageHashes: ["sha256:done"]
        )

        try await manager.removeGalleryFolders(gid: gid, token: "token")

        #expect(!FileManager.default.fileExists(atPath: oldFolderURL.path))
        #expect(!FileManager.default.fileExists(atPath: newFolderURL.path))
        #expect(FileManager.default.fileExists(atPath: unrelatedFolderURL.path))
    }
}

// MARK: - Setup Helpers

private extension DownloadInterruptedResumeTests {
    @discardableResult
    func writeManifestFolder(
        storage: DownloadStore,
        gid: String,
        title: String,
        pageHashes: [String]
    ) throws -> URL {
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[\(gid)_token] \(title)")
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            DownloadManifest(
                gid: gid,
                host: .ehentai,
                token: "token",
                title: title,
                jpnTitle: nil,
                category: .doujinshi,
                language: .japanese,
                remoteCoverURL: nil,
                uploader: "Uploader",
                tags: [],
                postedDate: .now,
                rating: 4,
                pages: Dictionary(
                    uniqueKeysWithValues:
                        pageHashes.enumerated().map({ ($0.offset + 1, $0.element) })
                )
            ),
            folderURL: folderURL
        )
        for (offset, hash) in pageHashes.enumerated() where !hash.isEmpty {
            try Data([UInt8(offset + 1)]).write(
                to: folderURL.appendingPathComponent("\(gid)_token_\(offset + 1).jpg"),
                options: .atomic
            )
        }
        return folderURL
    }

    func makePayload(
        gid: String,
        title: String,
        mode: DownloadStartMode
    ) -> DownloadRequestPayload {
        DownloadRequestPayload(
            gallery: Gallery(
                gid: gid, token: "token", title: title,
                rating: 4, tags: [], category: .doujinshi,
                uploader: "Uploader", pageCount: 2, postedDate: .now,
                coverURL: nil,
                galleryURL: URL(string: "https://e-hentai.org/g/\(gid)/token")
            ),
            galleryDetail: GalleryDetail(
                gid: gid, title: title, jpnTitle: nil,
                isFavorited: false, visibility: .yes,
                rating: 4, userRating: 0, ratingCount: 1,
                category: .doujinshi, language: .japanese,
                uploader: "Uploader", postedDate: .now,
                coverURL: nil,
                favoritedCount: 0, pageCount: 2,
                sizeCount: 1, sizeType: "MB", torrentCount: 0
            ),
            previewURLs: [:], previewConfig: .normal(rows: 4),
            host: .ehentai, folderName: "Folder", mode: mode
        )
    }
}
