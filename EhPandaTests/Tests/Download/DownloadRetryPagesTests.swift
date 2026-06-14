//
//  DownloadRetryPagesTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadRetryPagesTests: DownloadFeatureTestCase {
    @Test
    func testRetryPagesQueuesWorkWhenAnotherDownloadIsActive() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 2)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared)
        try writeManifestFolder(
            storage: storage,
            gid: gid,
            title: "Retry Pages",
            pageHashes: ["sha256:done", ""]
        )
        await manager.reloadDownloadIndex()
        await manager.testingSetFailedPageErrors(
            [
                .init(
                    index: 2,
                    relativePath: "123_token_2.jpg",
                    error: .networkingFailed
                )
            ],
            gid: gid
        )

        let blockingTask = Task<Void, Never> { _ = try? await Task.sleep(for: .seconds(60)) }
        defer { blockingTask.cancel() }
        await manager.testingInstallActiveTask(gid: "other-active-download", task: blockingTask)

        let result = await manager.retryPages(gid: gid, pageIndices: [2])
        guard case .success = result else {
            Issue.record("Retry pages should succeed, got \(result)")
            return
        }

        let stored = await manager.testingFetchDownload(gid: gid)
        #expect(stored?.displayStatus == .queued)
        #expect(stored?.badge.status == .queued)
        #expect(stored?.lastError == nil)

    }

    @Test
    func testCancelQueuedWorkClearsQueueIntent() async throws {
        let gid = "cancel-repair-\(UUID().uuidString)"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        try writeManifestFolder(
            storage: storage,
            gid: gid,
            title: "Queued",
            pageHashes: ["sha256:done", ""]
        )
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs([gid])

        let result = await manager.togglePause(gid: gid)
        guard case .success = result else {
            Issue.record("Cancelling queued work should succeed, got \(result)")
            return
        }

        let stored = await manager.testingFetchDownload(gid: gid)
        #expect(stored?.displayStatus == .inactive)
        #expect(stored?.completedPageCount == 1)
        #expect(
            stored?.badge == DownloadBadge(
                status: .inactive,
                progress: .init(completedPageCount: 1, pageCount: 2)
            )
        )
    }

}

// MARK: - Setup Helpers

private extension DownloadRetryPagesTests {
    @discardableResult
    func writeManifestFolder(
        storage: DownloadFileStorage,
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
                remoteCoverURL: URL(string: "https://example.com/cover.jpg"),
                uploader: "Uploader",
                tags: [],
                postedDate: .now,
                rating: 4,
                pages: Dictionary(
                    uniqueKeysWithValues:
                        pageHashes.enumerated().map { ($0.offset + 1, $0.element) }
                )
            ),
            folderURL: folderURL
        )
        return folderURL
    }

}
