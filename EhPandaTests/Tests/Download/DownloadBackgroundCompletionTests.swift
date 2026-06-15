//
//  DownloadBackgroundCompletionTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadBackgroundCompletionTests: DownloadFeatureTestCase {
    @Test
    func testOrphanedBackgroundCompletionAttachesPageAndClearsTaskRecord() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 901)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let taskStore = DownloadBackgroundTaskStore(fileURL: storage.backgroundTaskRegistryURL())
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared,
            backgroundTaskStore: taskStore
        )
        let folderURL = try writeDownloadFolder(
            storage: storage,
            gid: gid
        )
        await manager.reloadDownloadIndex()

        let taskIdentifier = 77
        let stagedURL = try writeStagedBackgroundFile(storage: storage)
        await taskStore.record(
            taskIdentifier: taskIdentifier,
            gid: gid,
            pageIndex: 1
        )
        let responseURL = try #require(URL(string: "https://ehgt.org/ab/cd/0001-\(gid).jpg"))
        let response = try #require(HTTPURLResponse(
            url: responseURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "image/jpeg"]
        ))

        await manager.handleBackgroundPageDownloadCompleted(
            taskIdentifier: taskIdentifier,
            fileURL: stagedURL,
            response: response
        )

        let pageRelativePath = storage.makePageRelativePath(
            gid: gid,
            token: "token",
            index: 1,
            fileExtension: "jpg"
        )
        let pageURL = folderURL.appendingPathComponent(pageRelativePath)
        let manifest = try storage.readManifest(folderURL: folderURL)

        #expect(await taskStore.record(taskIdentifier: taskIdentifier) == nil)
        #expect(FileManager.default.fileExists(atPath: pageURL.path))
        #expect(FileManager.default.fileExists(atPath: stagedURL.path) == false)
        #expect(manifest.pages[1]?.hasPrefix("sha256:") == true)
        #expect(try await manager.loadLocalPageURLs(gid: gid).get()[1] == pageURL)
    }

    @Test
    func testOrphanedBackgroundFailureRecordsPageFailureAndClearsTaskRecord() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 904)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let taskStore = DownloadBackgroundTaskStore(fileURL: storage.backgroundTaskRegistryURL())
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared,
            backgroundTaskStore: taskStore
        )
        _ = try writeDownloadFolder(storage: storage, gid: gid)
        await manager.reloadDownloadIndex()

        let taskIdentifier = 91
        await taskStore.record(
            taskIdentifier: taskIdentifier,
            gid: gid,
            pageIndex: 1
        )

        await manager.handleBackgroundPageDownloadFailed(
            taskIdentifier: taskIdentifier,
            error: .networkingFailed
        )

        #expect(await taskStore.record(taskIdentifier: taskIdentifier) == nil)
        let inspection = try await manager.loadInspection(gid: gid).get()
        #expect(inspection.failedPageIndices.contains(1))
    }

    @Test
    func testOrphanedBackgroundCancellationClearsTaskRecordWithoutPageFailure() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 905)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let taskStore = DownloadBackgroundTaskStore(fileURL: storage.backgroundTaskRegistryURL())
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared,
            backgroundTaskStore: taskStore
        )
        _ = try writeDownloadFolder(storage: storage, gid: gid)
        await manager.reloadDownloadIndex()

        let taskIdentifier = 92
        await taskStore.record(
            taskIdentifier: taskIdentifier,
            gid: gid,
            pageIndex: 1
        )

        await manager.handleBackgroundPageDownloadFailed(
            taskIdentifier: taskIdentifier,
            error: nil
        )

        #expect(await taskStore.record(taskIdentifier: taskIdentifier) == nil)
        let inspection = try await manager.loadInspection(gid: gid).get()
        #expect(inspection.failedPageIndices.isEmpty)
    }

    @Test
    func testDeleteClearsPersistedBackgroundTaskRecords() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 902)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let taskStore = DownloadBackgroundTaskStore(fileURL: storage.backgroundTaskRegistryURL())
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared,
            backgroundTaskStore: taskStore
        )
        _ = try writeDownloadFolder(storage: storage, gid: gid)
        await manager.reloadDownloadIndex()

        await taskStore.record(taskIdentifier: 77, gid: gid, pageIndex: 1)
        await taskStore.record(taskIdentifier: 78, gid: "other", pageIndex: 1)

        let result = await manager.delete(gid: gid)
        guard case .success = result else {
            Issue.record("Expected delete to succeed, got \(result)")
            return
        }

        #expect(await taskStore.records(for: gid).isEmpty)
        #expect(await taskStore.record(taskIdentifier: 78) == .init(gid: "other", pageIndex: 1))
    }

    @Test
    func testDeleteFolderClearsPersistedBackgroundTaskRecords() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 903)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let taskStore = DownloadBackgroundTaskStore(fileURL: storage.backgroundTaskRegistryURL())
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared,
            backgroundTaskStore: taskStore
        )
        _ = try writeDownloadFolder(storage: storage, gid: gid, folderName: "Doomed")
        await manager.reconcileDownloads()

        await taskStore.record(taskIdentifier: 81, gid: gid, pageIndex: 1)
        await taskStore.record(taskIdentifier: 82, gid: "other", pageIndex: 1)

        let result = await manager.deleteFolder(name: "Doomed")
        guard case .success = result else {
            Issue.record("Expected folder delete to succeed, got \(result)")
            return
        }

        #expect(await taskStore.records(for: gid).isEmpty)
        #expect(await taskStore.record(taskIdentifier: 82) == .init(gid: "other", pageIndex: 1))
    }

    private func writeDownloadFolder(
        storage: DownloadStore,
        gid: String,
        folderName: String = "Folder"
    ) throws -> URL {
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "\(folderName)/[\(gid)_token] Background")
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            sampleManifest(gid: gid, title: "Background", pageCount: 2),
            folderURL: folderURL
        )
        return folderURL
    }

    private func writeStagedBackgroundFile(
        storage: DownloadStore
    ) throws -> URL {
        let holdingDirectory = storage.backgroundTransferHoldingDirectoryURL()
        try FileManager.default.createDirectory(
            at: holdingDirectory,
            withIntermediateDirectories: true
        )
        let fileURL = holdingDirectory.appendingPathComponent(UUID().uuidString)
        try Data([0x01, 0x02, 0x03]).write(to: fileURL, options: .atomic)
        return fileURL
    }
}
