//
//  DownloadManagerCaptureTests.swift
//  EhPandaTests
//

import Kingfisher
import UIKit
import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadManagerCaptureTests: DownloadFeatureTestCase {
    @Test
    func testDownloadManagerCaptureCachedPageRestoresFinalPage() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 27)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(
            storage: storage,
            urlSession: .shared
        )

        let completedFolderURL = rootURL.appendingPathComponent("\(gid) - Capture", isDirectory: true)
        try FileManager.default.createDirectory(
            at: completedFolderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            sampleManifest(
                gid: gid,
                title: "Capture",
                pageCount: 2
            ),
            folderURL: completedFolderURL
        )

        let imageURL = try #require(URL(string: "https://ehgt.org/ab/cd/0001-\(gid).jpg"))
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

        let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()
        #expect(pageURLs[1] == completedFolderURL.appendingPathComponent("pages/0001.jpg"))
    }

    @MainActor
    @Test
    func testDownloadManagerCaptureCachedPageRepairsCompletedDownloadWithLatestRemoteImage() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 28)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared)
        let completedFolderURL = try setupCaptureMissingFilesFolder(
            rootURL: rootURL, gid: gid
        )
        let (imageURL, cacheKey) = try await setupCaptureCachedImage(gid: gid)
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
            rating: 4,
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
    func setupCaptureCachedImage(gid: String) async throws -> (URL, String) {
        let imageURL = try #require(URL(string: "https://ehgt.org/ab/cd/0001-\(gid).jpg"))
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
