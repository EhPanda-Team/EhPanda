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
        let (storage, manager, rootURL) = makeManager()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        try storage.ensureRootDirectory()

        let created = await manager.createFolder(name: "  Favorites  ")
        guard case .success = created else {
            Issue.record("Expected create to succeed, got \(created)")
            return
        }
        #expect(await manager.fetchFolders() == ["Favorites"])

        let duplicate = await manager.createFolder(name: "Favorites")
        guard case .failure = duplicate else {
            Issue.record("Expected duplicate create to fail")
            return
        }

        let invalid = await manager.createFolder(name: "   ")
        guard case .failure = invalid else {
            Issue.record("Expected invalid name to fail")
            return
        }

        let galleryLike = await manager.createFolder(name: "[123_token] Sample")
        guard case .failure = galleryLike else {
            Issue.record("Expected gallery-like name to fail")
            return
        }
    }

    @Test
    func testRenameFolderRepointsContainedDownloads() async throws {
        let (storage, manager, rootURL) = makeManager()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let gid = "311"
        try writeGalleryFolder(storage: storage, folderName: "Old Name", gid: gid)

        let result = await manager.renameFolder(oldName: "Old Name", newName: "New Name")
        guard case .success = result else {
            Issue.record("Expected rename to succeed, got \(result)")
            return
        }

        let download = await manager.testingFetchDownload(gid: gid)
        #expect(await manager.fetchFolders() == ["New Name"])
        #expect(download?.folderName == "New Name")
        #expect(download?.folderURL.path.contains("/New Name/") == true)
    }

    @Test
    func testRenameFolderRejectsActiveDownloadInside() async throws {
        let (storage, manager, rootURL) = makeManager()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let gid = "312"
        try writeGalleryFolder(storage: storage, folderName: "Busy", gid: gid)
        _ = await manager.reconcileDownloads()
        let blockingTask = Task<Void, Never> { _ = try? await Task.sleep(for: .seconds(60)) }
        defer { blockingTask.cancel() }
        await manager.testingInstallActiveTask(gid: gid, task: blockingTask)

        let result = await manager.renameFolder(oldName: "Busy", newName: "Renamed")
        guard case .failure = result else {
            Issue.record("Expected rename to fail while downloading")
            return
        }
        #expect(await manager.fetchFolders() == ["Busy"])
    }

    @Test
    func testDeleteFolderRemovesContainedDownloadsAndQueueIntents() async throws {
        let (storage, manager, rootURL) = makeManager()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let gid = "313"
        let folderURL = try writeGalleryFolder(storage: storage, folderName: "Doomed", gid: gid)
        await manager.testingSetQueuedGalleryIDs([gid])

        let result = await manager.deleteFolder(name: "Doomed")
        guard case .success = result else {
            Issue.record("Expected delete to succeed, got \(result)")
            return
        }

        #expect(await manager.fetchFolders().isEmpty)
        #expect(await manager.testingFetchDownload(gid: gid) == nil)
        #expect(!FileManager.default.fileExists(atPath: folderURL.path))
    }

    @Test
    func testMoveDownloadRelocatesGalleryFolder() async throws {
        let (storage, manager, rootURL) = makeManager()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let gid = "314"
        let sourceURL = try writeGalleryFolder(storage: storage, folderName: "Source", gid: gid)

        let result = await manager.moveDownload(gid: gid, toFolderName: "Target")
        guard case .success = result else {
            Issue.record("Expected move to succeed, got \(result)")
            return
        }

        let download = await manager.testingFetchDownload(gid: gid)
        #expect(download?.folderName == "Target")
        #expect(download?.folderURL.path.contains("/Target/") == true)
        #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(await manager.fetchFolders() == ["Source", "Target"])
    }

    @Test
    func testMoveDownloadIntoSameFolderIsNoOp() async throws {
        let (storage, manager, rootURL) = makeManager()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let gid = "315"
        let folderURL = try writeGalleryFolder(storage: storage, folderName: "Home", gid: gid)

        let result = await manager.moveDownload(gid: gid, toFolderName: "Home")
        guard case .success = result else {
            Issue.record("Expected same-folder move to succeed, got \(result)")
            return
        }
        #expect(FileManager.default.fileExists(atPath: folderURL.path))
    }

    @Test
    func testMoveDownloadRejectsActivelyDownloadingGallery() async throws {
        let (storage, manager, rootURL) = makeManager()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let gid = "316"
        let folderURL = try writeGalleryFolder(storage: storage, folderName: "Working", gid: gid)
        _ = await manager.reconcileDownloads()
        let blockingTask = Task<Void, Never> { _ = try? await Task.sleep(for: .seconds(60)) }
        defer { blockingTask.cancel() }
        await manager.testingInstallActiveTask(gid: gid, task: blockingTask)

        let result = await manager.moveDownload(gid: gid, toFolderName: "Elsewhere")
        guard case .failure = result else {
            Issue.record("Expected move of active download to fail")
            return
        }
        #expect(FileManager.default.fileExists(atPath: folderURL.path))
    }

    @Test
    func testEnqueueKeepsExistingDownloadInItsFolder() async throws {
        let (storage, manager, rootURL) = makeManager()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        await manager.testingInstallActiveTask(gid: "busy", task: Task {})

        let gallery = sampleGallery()
        let detail = sampleGalleryDetail(gid: gallery.gid, title: gallery.title)
        let galleryFolderName = storage.makeFolderRelativePath(
            gid: gallery.gid,
            token: gallery.token,
            title: detail.trimmedTitle
        )
        try writeGalleryFolder(
            storage: storage,
            folderName: "Original",
            gid: gallery.gid,
            galleryFolderName: galleryFolderName
        )
        _ = await manager.reconcileDownloads()

        let payload = DownloadRequestPayload(
            gallery: gallery,
            galleryDetail: detail,
            previewURLs: [:],
            previewConfig: .normal(rows: 4),
            host: .ehentai,
            folderName: "Requested Elsewhere",
            options: .init(),
            mode: .initial
        )
        let result = await manager.enqueue(payload: payload)
        guard case .success = result else {
            Issue.record("Expected enqueue to succeed, got \(result)")
            return
        }

        let download = await manager.testingFetchDownload(gid: gallery.gid)
        #expect(download?.folderName == "Original")
    }
}

// MARK: - Setup Helpers

private extension DownloadFolderOperationTests {
    func makeManager() -> (DownloadFileStorage, DownloadManager, URL) {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared)
        return (storage, manager, rootURL)
    }

    @discardableResult
    func writeGalleryFolder(
        storage: DownloadFileStorage,
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
