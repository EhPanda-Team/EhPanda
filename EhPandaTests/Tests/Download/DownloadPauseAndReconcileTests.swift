//
//  DownloadPauseAndReconcileTests.swift
//  EhPandaTests
//

import Foundation
import CoreData
import ComposableArchitecture
import Kingfisher
import UIKit
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadPauseAndReconcileTests: DownloadFeatureTestCase {
    @Test
    func testQuickSearchWordUsesNameWhenContentIsEmpty() {
        let word = QuickSearchWord(name: "artist:hossy", content: "")

        #expect(word.effectiveSearchText == "artist:hossy")
    }

    @Test
    func testPauseKeepsActiveDownloadPausedWhenDeferredSchedulingRuns() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000))
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let manager = DownloadManager(
            storage: DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            urlSession: URLSession(configuration: configuration),
            persistenceContainer: container
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .downloading,
            completedPageCount: 7
        )

        let activeTask = Task { [manager] in
            do {
                try await Task.sleep(for: .seconds(60))
            } catch is CancellationError {
                await manager.testingScheduleNextIfNeeded()
            } catch {}
        }
        await manager.testingInstallActiveTask(gid: gid, task: activeTask)

        let result = await manager.togglePause(gid: gid)

        guard case .success = result else {
            Issue.record("Pause should succeed, got \(result)")
            return
        }

        try await Task.sleep(for: .milliseconds(100))

        let stored = await manager.testingFetchDownload(gid: gid)
        let activeGalleryID = await manager.testingActiveGalleryID()
        #expect(stored?.status == .paused)
        #expect(stored?.badge == .paused(7, 26))
        #expect(activeGalleryID == nil)
    }

    @Test
    func testPauseUsesTemporaryWorkingSetProgressWhenCancelling() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 1)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: URLSession(configuration: configuration),
            persistenceContainer: container
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .downloading,
            completedPageCount: 1,
            pageCount: 2
        )

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(
            to: temporaryFolderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )
        try Data([0x02]).write(
            to: temporaryFolderURL.appendingPathComponent("pages/0002.jpg"),
            options: .atomic
        )

        let activeTask = Task { [manager] in
            do {
                try await Task.sleep(for: .seconds(60))
            } catch is CancellationError {
                await manager.testingScheduleNextIfNeeded()
            } catch {}
        }
        await manager.testingInstallActiveTask(gid: gid, task: activeTask)

        let result = await manager.togglePause(gid: gid)

        guard case .success = result else {
            Issue.record("Pause should succeed, got \(result)")
            return
        }

        let stored = await manager.testingFetchDownload(gid: gid)
        #expect(stored?.status == .paused)
        #expect(stored?.completedPageCount == 2)
        #expect(stored?.badge == .paused(2, 2))
    }

    @Test
    func testReconcileDownloadsNormalizesLegacyFailedStatusToNeedsAttention() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 2)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let manager = DownloadManager(
            storage: DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            urlSession: URLSession(configuration: configuration),
            persistenceContainer: container
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .failed,
            completedPageCount: 0,
            pageCount: 18
        )

        await manager.reconcileDownloads()

        let stored = await manager.testingFetchDownload(gid: gid)
        #expect(stored?.status == .partial)
        #expect(stored?.badge == .partial(0, 18))
    }

    @Test
    func testReconcileDownloadsClearsCancellationLikeGalleryError() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 3)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let manager = DownloadManager(
            storage: DownloadFileStorage(rootURL: rootURL, fileManager: .default),
            urlSession: URLSession(configuration: configuration),
            persistenceContainer: container
        )

        try insertPersistedDownload(
            in: container,
            gid: gid,
            status: .partial,
            completedPageCount: 4,
            pageCount: 18,
            lastError: .init(
                code: .fileOperationFailed,
                message: "The operation could not be completed. (Swift.CancellationError error 1.)"
            )
        )

        await manager.reconcileDownloads()

        let stored = await manager.testingFetchDownload(gid: gid)
        #expect(stored?.lastError == nil)
        #expect(stored?.status == .partial)
    }

    @Test
    func testLoadInspectionFiltersCancellationFailuresIntoPendingPages() async throws {
        let container = try makeInMemoryContainer()
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 4)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage, urlSession: URLSession(configuration: configuration), persistenceContainer: container
        )
        try insertPersistedDownload(
            in: container, gid: gid, status: .partial, completedPageCount: 1, pageCount: 2
        )
        let temporaryFolderURL = try setupCancellationFilterTestFolder(storage: storage, gid: gid)

        let result = await manager.loadInspection(gid: gid)
        guard case .success(let inspection) = result else {
            Issue.record("Expected inspection to load successfully, got \(result)")
            return
        }

        #expect(inspection.pages[0].status == .downloaded)
        #expect(inspection.pages[1].status == .pending)
        #expect((try? storage.readFailedPages(folderURL: temporaryFolderURL).pages.isEmpty) ?? true)
    }
}

// MARK: - Setup Helpers

private extension DownloadPauseAndReconcileTests {
    @discardableResult
    func setupCancellationFilterTestFolder(
        storage: DownloadFileStorage,
        gid: String
    ) throws -> URL {
        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(
            to: temporaryFolderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )
        try storage.writeFailedPages(
            .init(pages: [
                .init(
                    index: 2,
                    relativePath: "pages/0002.jpg",
                    failure: .init(
                        code: .fileOperationFailed,
                        message: "The operation could not be completed. (Swift.CancellationError error 1.)"
                    )
                )
            ]),
            folderURL: temporaryFolderURL
        )
        return temporaryFolderURL
    }
}
