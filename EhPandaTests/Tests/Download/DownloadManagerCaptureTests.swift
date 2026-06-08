//
//  DownloadManagerCaptureTests.swift
//  EhPandaTests
//

import CoreData
import Kingfisher
import UIKit
import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadManagerCaptureTests: DownloadFeatureTestCase {
    @Test
    func testDownloadManagerCaptureCachedPageRestoresTemporaryPageAndUpdatesCompletedCount() async throws {
        let container = try makeInMemoryContainer()

        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 27)
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
            status: .downloading,
            completedPageCount: 0,
            pageCount: 2
        )

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        try FileManager.default.createDirectory(
            at: temporaryFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )

        let imageURL = try #require(URL(string: "https://ehgt.org/ab/cd/0001-1234567890.jpg"))
        let image = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let imageData = try #require(image.jpegData(compressionQuality: 1))
        let cacheKey = try #require(imageURL.stableImageCacheKey)
        try await KingfisherManager.shared.cache.store(image, original: imageData, forKey: cacheKey)
        defer {
            KingfisherManager.shared.cache.removeImage(forKey: cacheKey)
            KingfisherManager.shared.cache.removeImage(forKey: imageURL.absoluteString)
        }

        await manager.captureCachedPage(
            gid: gid,
            index: 1,
            imageURL: imageURL
        )

        let stored = await manager.testingFetchDownload(gid: gid)
        #expect(stored?.completedPageCount == 1)

        let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()
        let pageRelativePath = storage.makePageRelativePath(
            gid: gid,
            token: "token",
            index: 1,
            fileExtension: "jpg"
        )
        #expect(pageURLs[1] == temporaryFolderURL.appendingPathComponent(pageRelativePath))
    }

    @MainActor
    @Test
    func testDownloadManagerCaptureCachedPageRepairsCompletedDownloadWithLatestRemoteImage() async throws {
        let container = try makeInMemoryContainer()
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 28)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared, persistenceContainer: container)
        try insertPersistedDownload(
            in: container, gid: gid, status: .missingFiles, completedPageCount: 1, pageCount: 2,
            lastError: .init(code: .fileOperationFailed, message: "Page 1 is missing.")
        )

        let completedFolderURL = try setupCaptureMissingFilesFolder(
            rootURL: rootURL, gid: gid
        )
        let (imageURL, cacheKey) = try await setupCaptureCachedImage()
        defer {
            KingfisherManager.shared.cache.removeImage(forKey: cacheKey)
            KingfisherManager.shared.cache.removeImage(forKey: imageURL.absoluteString)
        }

        await manager.captureCachedPage(gid: gid, index: 1, imageURL: imageURL)

        let stored = await manager.testingFetchDownload(gid: gid)
        let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()

        #expect(stored?.status == .completed)
        #expect(stored?.completedPageCount == 2)
        #expect(stored?.lastError == nil)
        let pageRelativePath = storage.makePageRelativePath(
            gid: gid,
            token: "token",
            index: 1,
            fileExtension: "jpg"
        )
        #expect(pageURLs[1] == completedFolderURL.appendingPathComponent(pageRelativePath))
    }

}

// MARK: - Setup Helpers

private extension DownloadManagerCaptureTests {
    func setupCaptureMissingFilesFolder(rootURL: URL, gid: String) throws -> URL {
        let completedFolderURL = rootURL.appendingPathComponent("\(gid) - Pause Race", isDirectory: true)
        try FileManager.default.createDirectory(
            at: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadPages, isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data([0x00]).write(
            to: completedFolderURL.appendingPathComponent("cover.jpg"), options: .atomic
        )
        let page2RelativePath = "\(gid)_token_2.jpg"
        let page2URL = completedFolderURL.appendingPathComponent(page2RelativePath)
        try Data([0x02]).write(
            to: page2URL, options: .atomic
        )
        let manifest = DownloadManifest(
            gid: gid,
            host: .ehentai,
            token: "token",
            title: "Pause Race",
            jpnTitle: nil,
            category: .doujinshi,
            language: .japanese,
            uploader: "Uploader",
            tags: [],
            postedDate: .now,
            coverRelativePath: "cover.jpg",
            rating: 4,
            downloadOptions: DownloadOptionsSnapshot(),
            pages: [
                .init(
                    index: 1,
                    relativePath: "\(gid)_token_1.jpg",
                    fileHash: "sha256:missing"
                ),
                .init(
                    index: 2,
                    relativePath: page2RelativePath,
                    fileHash: try DownloadFileStorage().fileHash(at: page2URL)
                )
            ]
        )
        try JSONEncoder().encode(manifest).write(
            to: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        return completedFolderURL
    }

    @MainActor
    func setupCaptureCachedImage() async throws -> (URL, String) {
        let imageURL = try #require(URL(string: "https://ehgt.org/ab/cd/0001-1234567890.jpg"))
        let image = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            UIColor.systemOrange.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let imageData = try #require(image.jpegData(compressionQuality: 1))
        let cacheKey = try #require(imageURL.stableImageCacheKey)
        try await KingfisherManager.shared.cache.store(image, original: imageData, forKey: cacheKey)
        return (imageURL, cacheKey)
    }
}
