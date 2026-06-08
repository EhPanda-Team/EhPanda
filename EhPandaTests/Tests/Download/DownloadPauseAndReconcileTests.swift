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
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
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
    func testPauseKeepsIndexedManifestProgressWhenCancelling() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 1)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: URLSession(configuration: configuration)
        )

        try writeManifestFolder(
            storage: storage,
            gid: gid,
            title: "Pausable",
            pageHashes: ["sha256:done", ""]
        )

        let folderURL = storage.folderURL(relativePath: "[\(gid)_token] Pausable")
        try FileManager.default.createDirectory(
            at: folderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(
            to: folderURL.appendingPathComponent("pages/0001.jpg"),
            options: .atomic
        )
        try Data([0x02]).write(
            to: folderURL.appendingPathComponent("pages/0002.jpg"),
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
        #expect(stored?.completedPageCount == 1)
        #expect(stored?.badge == .paused(1, 2))
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
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
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

        let stored = await manager.testingFetchDownload(gid: gid)
        #expect(stored?.status == .failed)
        #expect(stored?.badge == .failed)
    }

    @Test
    func testReconcileDownloadsClearsCancellationLikeGalleryError() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 3)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
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

        let stored = await manager.testingFetchDownload(gid: gid)
        #expect(stored?.lastError == nil)
        #expect(stored?.status == .paused)
    }

    @Test
    func testLoadInspectionFiltersCancellationFailuresIntoPendingPages() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 4)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailFastURLProtocol.self]
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage, urlSession: URLSession(configuration: configuration)
        )
        try writeManifestFolder(
            storage: storage,
            gid: gid,
            title: "Inspection",
            pageHashes: ["sha256:done", ""]
        )
        let folderURL = try setupCancellationFilterTestFolder(storage: storage, gid: gid)

        let result = await manager.loadInspection(gid: gid)
        guard case .success(let inspection) = result else {
            Issue.record("Expected inspection to load successfully, got \(result)")
            return
        }

        #expect(inspection.pages[0].status == .downloaded)
        #expect(inspection.pages[1].status == .pending)
        #expect((try? storage.readFailedPages(folderURL: folderURL).pages.isEmpty) ?? true)
    }
}

// MARK: - Setup Helpers

private extension DownloadPauseAndReconcileTests {
    func writeManifestFolder(
        storage: DownloadFileStorage,
        gid: String,
        title: String,
        pageHashes: [String]
    ) throws {
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "[\(gid)_token] \(title)")
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

    @discardableResult
    func setupCancellationFilterTestFolder(
        storage: DownloadFileStorage,
        gid: String
    ) throws -> URL {
        let folderURL = storage.folderURL(relativePath: "[\(gid)_token] Inspection")
        try FileManager.default.createDirectory(
            at: folderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0x01]).write(
            to: folderURL.appendingPathComponent("pages/0001.jpg"),
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
            folderURL: folderURL
        )
        return folderURL
    }
}
