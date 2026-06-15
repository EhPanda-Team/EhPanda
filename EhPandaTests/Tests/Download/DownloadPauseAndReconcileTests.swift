//
//  DownloadPauseAndReconcileTests.swift
//  EhPandaTests
//

import Foundation
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
        let gid = String(Int(Date().timeIntervalSince1970 * 1000))
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
        )

        try writeManifestFolder(
            storage: storage,
            gid: gid,
            title: "Pausable",
            pageHashes: Array(repeating: "sha256:done", count: 7)
                + Array(repeating: "", count: 19)
        )
        await manager.reloadDownloadIndex()

        let activeTask = Task { [manager] in
            do {
                try await Task.sleep(for: .seconds(60))
            } catch is CancellationError {
                await manager.scheduleNextIfNeeded()
            } catch {}
        }
        await manager.testingInstallActiveTask(gid: gid, task: activeTask)

        let result = await manager.togglePause(gid: gid)

        guard case .success = result else {
            Issue.record("Pause should succeed, got \(result)")
            return
        }

        try await Task.sleep(for: .milliseconds(100))

        let stored = await manager.fetchDownload(gid: gid)
        let activeGalleryID = await manager.testingActiveGalleryID()
        #expect(stored?.displayStatus == .inactive)
        #expect(
            stored?.badge == DownloadBadge(
                status: .inactive,
                progress: .init(completedPageCount: 7, pageCount: 26)
            )
        )
        #expect(activeGalleryID == nil)
    }

    @Test
    func testTogglePausePausesActiveRetryBeforeClearingQueuedIntent() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 10)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)

        try writeManifestFolder(
            storage: storage,
            gid: gid,
            title: "Active Repair",
            pageHashes: ["sha256:done", ""]
        )
        await manager.reloadDownloadIndex()

        let activeTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(10))
            }
        }
        await manager.testingInstallActiveTask(gid: gid, task: activeTask)

        guard case .success = await manager.retry(gid: gid, mode: .repair) else {
            Issue.record("Retry should set the active gallery's queued intent.")
            return
        }
        guard case .success = await manager.togglePause(gid: gid) else {
            Issue.record("First pause tap should pause active retry work.")
            return
        }

        let stored = await manager.fetchDownload(gid: gid)
        let activeGalleryID = await manager.testingActiveGalleryID()
        let hasActiveTask = await manager.testingHasActiveTask()
        #expect(stored?.displayStatus == .inactive)
        #expect(activeGalleryID == nil)
        #expect(!hasActiveTask)
    }

    @Test
    func testPauseKeepsIndexedManifestProgressWhenCancelling() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 1)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
        )

        try writeManifestFolder(
            storage: storage,
            gid: gid,
            title: "Pausable",
            pageHashes: ["sha256:done", ""]
        )

        let folderURL = storage.folderURL(relativePath: "Folder/[\(gid)_token] Pausable")
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(
            to: folderURL.appendingPathComponent("\(gid)_token_1.jpg"),
            options: .atomic
        )
        try Data([0x02]).write(
            to: folderURL.appendingPathComponent("\(gid)_token_2.jpg"),
            options: .atomic
        )
        await manager.reloadDownloadIndex()

        let activeTask = Task { [manager] in
            do {
                try await Task.sleep(for: .seconds(60))
            } catch is CancellationError {
                await manager.scheduleNextIfNeeded()
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
        #expect(stored?.completedPageCount == 1)
        #expect(
            stored?.badge == DownloadBadge(
                status: .inactive,
                progress: .init(completedPageCount: 1, pageCount: 2)
            )
        )
        #expect(FileManager.default.fileExists(atPath: folderURL.path))
    }

    @Test
    func testReconcileDownloadsKeepsIndexedSessionFailure() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 2)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
        )

        try writeManifestFolder(
            storage: storage,
            gid: gid,
            title: "Failed",
            pageHashes: Array(repeating: "", count: 18)
        )
        await manager.testingSetDownloadError(
            .init(code: .networkingFailed, message: "Network Error"),
            gid: gid
        )

        await manager.reconcileDownloads()

        let stored = await manager.fetchDownload(gid: gid)
        #expect(stored?.displayStatus == .error)
        #expect(stored?.lastError?.code == .networkingFailed)
    }

    @Test
    func testReconcileDownloadsClearsCancellationLikeGalleryError() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 3)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
        )

        try writeManifestFolder(
            storage: storage,
            gid: gid,
            title: "Cancelled",
            pageHashes: Array(repeating: "sha256:done", count: 4)
                + Array(repeating: "", count: 14)
        )
        await manager.testingSetDownloadError(
            .init(
                code: .fileOperationFailed,
                message: "The operation could not be completed. (Swift.CancellationError error 1.)"
            ),
            gid: gid
        )

        await manager.reconcileDownloads()

        let stored = await manager.fetchDownload(gid: gid)
        #expect(stored?.lastError == nil)
        #expect(stored?.displayStatus == .inactive)
    }

    @Test
    func testLoadInspectionFiltersCancellationFailuresIntoPendingPages() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 4)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(
            storage: storage, urlSession: URLSession(configuration: configuration)
        )
        try writeManifestFolder(
            storage: storage,
            gid: gid,
            title: "Inspection",
            pageHashes: ["sha256:done", ""]
        )
        try setupCancellationFilterTestFolder(storage: storage, gid: gid)
        await manager.reloadDownloadIndex()
        await manager.testingSetFailedPageErrors(
            [
                .init(
                    index: 2,
                    relativePath: "\(gid)_token_2.jpg",
                    error: .fileOperationFailed(
                        "The operation could not be completed. (Swift.CancellationError error 1.)"
                    )
                )
            ],
            gid: gid
        )

        let result = await manager.loadInspection(gid: gid)
        guard case .success(let inspection) = result else {
            Issue.record("Expected inspection to load successfully, got \(result)")
            return
        }

        #expect(inspection.pages[0].status == .downloaded)
        #expect(inspection.pages[1].status == .pending)
    }
}

// MARK: - Setup Helpers

private extension DownloadPauseAndReconcileTests {
    func writeManifestFolder(
        storage: DownloadStore,
        gid: String,
        title: String,
        pageHashes: [String]
    ) throws {
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
    }

    func setupCancellationFilterTestFolder(
        storage: DownloadStore,
        gid: String
    ) throws {
        let folderURL = storage.folderURL(relativePath: "Folder/[\(gid)_token] Inspection")
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(
            to: folderURL.appendingPathComponent("\(gid)_token_1.jpg"),
            options: .atomic
        )
    }
}
