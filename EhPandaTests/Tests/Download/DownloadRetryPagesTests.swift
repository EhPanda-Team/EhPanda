//
//  DownloadRetryPagesTests.swift
//  EhPandaTests
//

import CoreData
import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadRetryPagesTests: DownloadFeatureTestCase {
    @Test
    func testRetryPagesQueuesWorkWhenAnotherDownloadIsActive() async throws {
        let container = try makeInMemoryContainer()
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 2)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared, persistenceContainer: container)
        try insertPersistedDownload(
            in: container, gid: gid, status: .partial, completedPageCount: 1, pageCount: 2
        )
        let temporaryFolderURL = try setupRetryPagesPartialFolder(storage: storage, gid: gid)

        let blockingTask = Task<Void, Never> { _ = try? await Task.sleep(for: .seconds(60)) }
        defer { blockingTask.cancel() }
        await manager.testingInstallActiveTask(gid: "other-active-download", task: blockingTask)

        let result = await manager.retryPages(gid: gid, pageIndices: [2])
        guard case .success = result else {
            Issue.record("Retry pages should succeed, got \(result)")
            return
        }

        let stored = await manager.testingFetchDownload(gid: gid)
        #expect(stored?.status == .queued)
        #expect(stored?.badge == .queued)
        #expect(stored?.pendingOperation == nil)
        #expect(stored?.lastError == nil)

        let resumeState = try storage.readResumeState(folderURL: temporaryFolderURL)
        #expect(resumeState.pageSelection == [2])
        #expect(FileManager.default.fileExists(
            atPath: temporaryFolderURL
                .appendingPathComponent(Defaults.FilePath.downloadFailedPages)
                .path
        ) == false)
    }

    @Test
    func testCancelQueuedRepairRestoresReadableCountAndClearsPendingOperation() async throws {
        let container = try makeInMemoryContainer()

        let gid = "cancel-repair-\(UUID().uuidString)"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared,
            persistenceContainer: container
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .missingFiles,
            completedPageCount: 0,
            pageCount: 2,
            remoteVersionSignature: "hash:v1",
            latestRemoteVersionSignature: "hash:v1",
            pendingOperation: .repair
        )

        let completedFolderURL = rootURL.appendingPathComponent("\(gid) - Pause Race", isDirectory: true)
        try FileManager.default.createDirectory(
            at: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0x00]).write(
            to: completedFolderURL.appendingPathComponent("cover.jpg"),
            options: .atomic
        )
        try Data([0x01]).write(
            to: completedFolderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )

        let result = await manager.togglePause(gid: gid)
        guard case .success = result else {
            Issue.record("Cancelling queued repair should succeed, got \(result)")
            return
        }

        let stored = await manager.testingFetchDownload(gid: gid)
        #expect(stored?.status == .missingFiles)
        #expect(stored?.completedPageCount == 1)
        #expect(stored?.pendingOperation == nil)
    }

}

// MARK: - Setup Helpers

private extension DownloadRetryPagesTests {
    @discardableResult
    func setupRetryPagesPartialFolder(
        storage: DownloadFileStorage,
        gid: String
    ) throws -> URL {
        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL,
            withIntermediateDirectories: true
        )
        try storage.writeFailedPages(
            .init(pages: [
                .init(
                    index: 2,
                    relativePath: "pages/0002.jpg",
                    failure: .init(code: .networkingFailed, message: "Network Error")
                )
            ]),
            folderURL: temporaryFolderURL
        )
        return temporaryFolderURL
    }
}
