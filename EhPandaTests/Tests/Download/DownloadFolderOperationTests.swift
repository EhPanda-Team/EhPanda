//
//  DownloadFolderOperationTests.swift
//  EhPandaTests
//

import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadFolderOperationTests: DownloadFeatureTestCase {
    @Test
    func testCreateFolderListsFolderAndRejectsDuplicatesAndInvalidNames() async throws {
        let environment = makeManager()
        defer { try? FileManager.default.removeItem(at: environment.rootURL) }
        try environment.storage.ensureRootDirectory()

        let created = await environment.manager.createFolder(name: "  Favorites  ")
        guard case .success = created else {
            Issue.record("Expected create to succeed, got \(created)")
            return
        }
        #expect(await environment.manager.fetchFolders() == ["Favorites"])

        let duplicate = await environment.manager.createFolder(name: "Favorites")
        guard case .failure = duplicate else {
            Issue.record("Expected duplicate create to fail")
            return
        }

        let invalid = await environment.manager.createFolder(name: "   ")
        guard case .failure = invalid else {
            Issue.record("Expected invalid name to fail")
            return
        }

        let galleryLike = await environment.manager.createFolder(name: "[123_token] Sample")
        guard case .failure = galleryLike else {
            Issue.record("Expected gallery-like name to fail")
            return
        }
    }

    @Test
    func testRenameFolderRepointsContainedDownloads() async throws {
        let environment = makeManager()
        defer { try? FileManager.default.removeItem(at: environment.rootURL) }
        let gid = "311"
        try writeGalleryFolder(storage: environment.storage, folderName: "Old Name", gid: gid)
        await environment.manager.reconcileDownloads()

        let result = await environment.manager.renameFolder(oldName: "Old Name", newName: "New Name")
        guard case .success = result else {
            Issue.record("Expected rename to succeed, got \(result)")
            return
        }

        let download = await environment.manager.fetchDownload(gid: gid)
        #expect(await environment.manager.fetchFolders() == ["New Name"])
        #expect(download?.folderName == "New Name")
        #expect(download?.folderURL.path.contains("/New Name/") == true)
    }

    @Test
    func testRenameFolderRejectsActiveDownloadInside() async throws {
        let environment = makeManager()
        defer { try? FileManager.default.removeItem(at: environment.rootURL) }
        let gid = "312"
        try writeGalleryFolder(storage: environment.storage, folderName: "Busy", gid: gid)
        _ = await environment.manager.reconcileDownloads()
        let blockingTask = Task<Void, Never> { _ = try? await Task.sleep(for: .seconds(60)) }
        defer { blockingTask.cancel() }
        await environment.manager.testingInstallActiveTask(gid: gid, task: blockingTask)

        let result = await environment.manager.renameFolder(oldName: "Busy", newName: "Renamed")
        guard case .failure = result else {
            Issue.record("Expected rename to fail while downloading")
            return
        }
        #expect(await environment.manager.fetchFolders() == ["Busy"])
    }

    @Test
    func testDeleteFolderRemovesContainedDownloadsAndQueueIntents() async throws {
        let environment = makeManager()
        defer { try? FileManager.default.removeItem(at: environment.rootURL) }
        let gid = "313"
        let folderURL = try writeGalleryFolder(storage: environment.storage, folderName: "Doomed", gid: gid)
        await environment.manager.reconcileDownloads()
        await environment.manager.testingSetQueuedGalleryIDs([gid])

        let result = await environment.manager.deleteFolder(name: "Doomed")
        guard case .success = result else {
            Issue.record("Expected delete to succeed, got \(result)")
            return
        }

        #expect(await environment.manager.fetchFolders().isEmpty)
        #expect(await environment.manager.fetchDownload(gid: gid) == nil)
        #expect(!FileManager.default.fileExists(atPath: folderURL.path))
    }

    @Test
    func testDeleteDownloadRemovesSupersededSameIdentityFolders() async throws {
        let environment = makeManager()
        defer { try? FileManager.default.removeItem(at: environment.rootURL) }
        let gid = "314"
        let oldFolderURL = try writeGalleryFolder(
            storage: environment.storage,
            folderName: "Saved",
            gid: gid,
            galleryFolderName: "[\(gid)_token] Old Title"
        )
        let currentFolderURL = try writeGalleryFolder(
            storage: environment.storage,
            folderName: "Saved",
            gid: gid,
            galleryFolderName: "[\(gid)_token] Current Title"
        )
        await environment.manager.reconcileDownloads()

        let result = await environment.manager.delete(gid: gid)
        guard case .success = result else {
            Issue.record("Expected delete to succeed, got \(result)")
            return
        }

        await environment.manager.reconcileDownloads()
        #expect(await environment.manager.fetchDownload(gid: gid) == nil)
        #expect(!FileManager.default.fileExists(atPath: oldFolderURL.path))
        #expect(!FileManager.default.fileExists(atPath: currentFolderURL.path))
    }

    @Test
    func testMoveDownloadRelocatesGalleryFolder() async throws {
        let environment = makeManager()
        defer { try? FileManager.default.removeItem(at: environment.rootURL) }
        let gid = "315"
        let sourceURL = try writeGalleryFolder(storage: environment.storage, folderName: "Source", gid: gid)
        await environment.manager.reconcileDownloads()

        let result = await environment.manager.moveDownload(gid: gid, toFolderName: "Target")
        guard case .success = result else {
            Issue.record("Expected move to succeed, got \(result)")
            return
        }

        let download = await environment.manager.fetchDownload(gid: gid)
        #expect(download?.folderName == "Target")
        #expect(download?.folderURL.path.contains("/Target/") == true)
        #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(await environment.manager.fetchFolders() == ["Source", "Target"])
    }

    @Test
    func testMoveDownloadIntoSameFolderIsNoOp() async throws {
        let environment = makeManager()
        defer { try? FileManager.default.removeItem(at: environment.rootURL) }
        let gid = "316"
        let folderURL = try writeGalleryFolder(storage: environment.storage, folderName: "Home", gid: gid)
        await environment.manager.reconcileDownloads()

        let result = await environment.manager.moveDownload(gid: gid, toFolderName: "Home")
        guard case .success = result else {
            Issue.record("Expected same-folder move to succeed, got \(result)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: folderURL.path))
    }

    @Test
    func testMoveDownloadRejectsActivelyDownloadingGallery() async throws {
        let environment = makeManager()
        defer { try? FileManager.default.removeItem(at: environment.rootURL) }
        let gid = "317"
        let folderURL = try writeGalleryFolder(storage: environment.storage, folderName: "Working", gid: gid)
        _ = await environment.manager.reconcileDownloads()
        let blockingTask = Task<Void, Never> { _ = try? await Task.sleep(for: .seconds(60)) }
        defer { blockingTask.cancel() }
        await environment.manager.testingInstallActiveTask(gid: gid, task: blockingTask)

        let result = await environment.manager.moveDownload(gid: gid, toFolderName: "Elsewhere")
        guard case .failure = result else {
            Issue.record("Expected move of active download to fail")
            return
        }
        #expect(FileManager.default.fileExists(atPath: folderURL.path))
    }

    @Test
    func testEnqueueKeepsExistingDownloadInItsFolder() async throws {
        let environment = makeManager()
        defer { try? FileManager.default.removeItem(at: environment.rootURL) }
        await environment.manager.testingInstallActiveTask(gid: "busy", task: Task {})

        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let galleryFolderName = environment.storage.makeFolderRelativePath(
            gid: gallery.gid,
            token: gallery.token,
            title: detail.trimmedTitle
        )
        try writeGalleryFolder(
            storage: environment.storage,
            folderName: "Original",
            gid: gallery.gid,
            galleryFolderName: galleryFolderName
        )
        _ = await environment.manager.reconcileDownloads()

        let payload = DownloadRequestPayload(
            gallery: gallery,
            galleryDetail: detail,
            previewURLs: [:],
            previewConfig: .normal(rows: 4),
            host: .ehentai,
            folderName: "Requested Elsewhere",
            mode: .initial
        )
        let result = await environment.manager.enqueue(payload: payload)
        guard case .success = result else {
            Issue.record("Expected enqueue to succeed, got \(result)")
            return
        }

        let download = await environment.manager.fetchDownload(gid: gallery.gid)
        #expect(download?.folderName == "Original")
    }
}

// MARK: - Setup Helpers

private struct DownloadFolderOperationTestEnvironment {
    let storage: DownloadStore
    let manager: DownloadCoordinator
    let rootURL: URL
}

private extension DownloadFolderOperationTests {
    func makeManager() -> DownloadFolderOperationTestEnvironment {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)
        return .init(storage: storage, manager: manager, rootURL: rootURL)
    }

    @discardableResult
    func writeGalleryFolder(
        storage: DownloadStore,
        folderName: String,
        gid: String,
        galleryFolderName: String? = nil
    ) throws -> URL {
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(
            relativePath: "\(folderName)/\(galleryFolderName ?? "[\(gid)_token] Sample")"
        )
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            sampleManifest(gid: gid, title: "Sample", pageCount: 2),
            folderURL: folderURL
        )
        return folderURL
    }
}
