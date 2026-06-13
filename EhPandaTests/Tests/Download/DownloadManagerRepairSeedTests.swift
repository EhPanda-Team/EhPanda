//
//  DownloadManagerRepairSeedTests.swift
//  EhPandaTests
//

import Kingfisher
import SDWebImage
import UIKit
import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadManagerRepairSeedTests: DownloadFeatureTestCase {
    @Test
    func testRepairSeedReusesCompletedFilesWhenPageCountMatches() async throws {
        let gid = "repair-seed-\(UUID().uuidString)"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared)
        try storage.ensureRootDirectory()

        let sourceFolderURL = storage.folderURL(relativePath: "Folder/[\(gid)_token] Existing")
        let existingDownload = sampleDownload(
            gid: gid, title: "Mixed Version", status: .missingFiles,
            pageCount: 2, completedPageCount: 2,
            folderURL: sourceFolderURL
        )
        try setupRepairSeedFiles(
            storage: storage,
            sourceFolderURL: sourceFolderURL,
            gid: gid
        )

        let payload = makeRepairSeedPayload(gid: gid)
        let workingSeed = try await manager.testingPrepareWorkingSeed(
            payload: payload, existingDownload: existingDownload
        )

        let pageOneRelativePath = storage.makePageRelativePath(
            gid: gid, token: "token", index: 1, fileExtension: "jpg"
        )
        let pageTwoRelativePath = storage.makePageRelativePath(
            gid: gid, token: "token", index: 2, fileExtension: "jpg"
        )
        let coverRelativePath = storage.makeCoverRelativePath(
            gid: gid, token: "token", fileExtension: "jpg"
        )
        let manifest = workingSeed.manifest
        #expect(manifest.gid == gid)
        #expect(workingSeed.existingPages == [
            1: pageOneRelativePath,
            2: pageTwoRelativePath
        ])
        #expect(workingSeed.coverRelativePath == coverRelativePath)
        #expect(
            FileManager.default.fileExists(
                atPath: workingSeed.folderURL.appendingPathComponent(pageOneRelativePath).path
            )
        )
        #expect(
            FileManager.default.fileExists(
                atPath: workingSeed.folderURL.appendingPathComponent(pageTwoRelativePath).path
            )
        )
    }

    @Test
    func testDownloadManagerLoadLocalPageURLsRemovesZeroBytePage() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 13)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared)

        let (emptyPageURL, goodPageURL) = try setupZeroBytePageFiles(
            rootURL: rootURL, gid: gid, storage: storage
        )

        let pageURLs = try await manager.loadLocalPageURLs(gid: gid).get()

        #expect(pageURLs[1] == nil)
        #expect(pageURLs[2] == goodPageURL)
        #expect(FileManager.default.fileExists(atPath: emptyPageURL.path) == false)
    }

    @MainActor
    @Test
    func testImageClientFetchImageUsesStableAliasCacheKey() async throws {
        let url = try #require(
            URL(string: "https://ehgt.org/ab/cd/0001-1234567890.jpg?download=1")
        )
        let stableCacheKey = try #require(url.stableImageCacheKey)
        let image = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            UIColor.systemRed.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let imageData = try #require(image.pngData())

        try await KingfisherManager.shared.cache.store(image, original: imageData, forKey: stableCacheKey)
        defer {
            KingfisherManager.shared.cache.removeImage(forKey: stableCacheKey)
            KingfisherManager.shared.cache.removeImage(forKey: url.absoluteString)
        }

        let result = await ImageClient.live.fetchImage(url: url)
        let fetchedImage = try result.get()

        #expect(fetchedImage.size == image.size)
    }

    @MainActor
    @Test
    func testImageClientDownloadImageCachesKingfisherOriginalUnderStableKey() async throws {
        let sessionID = UUID().uuidString
        let url = try #require(
            URL(string: "https://ehgt.org/ab/cd/0001-1234567890.jpg?download=1")
        )
        let stableCacheKey = try #require(url.stableImageCacheKey)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: .init(width: 1, height: 1),
            format: format
        )
        .image { context in
            UIColor.systemBlue.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let imageData = try #require(image.pngData())
        let originalDownloader = KingfisherManager.shared.downloader
        let downloader = ImageDownloader(name: "test-\(sessionID)")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        configuration.httpAdditionalHeaders = [
            SharedSessionStubURLProtocol.headerKey: sessionID
        ]
        downloader.sessionConfiguration = configuration
        KingfisherManager.shared.downloader = downloader
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { request in
            #expect(request.url == url)
            return (
                try #require(HTTPURLResponse(
                    url: url,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: [
                        "Content-Type": "image/png",
                        "Content-Length": "\(imageData.count)"
                    ]
                )),
                imageData
            )
        }
        defer {
            SharedSessionStubURLProtocol.removeHandler(for: sessionID)
            KingfisherManager.shared.downloader = originalDownloader
            KingfisherManager.shared.cache.removeImage(forKey: stableCacheKey)
            KingfisherManager.shared.cache.removeImage(forKey: url.absoluteString)
        }

        let result = await ImageClient.live.downloadImage(url)
        let downloadedImage = try result.get()

        #expect(downloadedImage.size == image.size)
        await waitUntilCacheReady(for: [stableCacheKey], timeout: .seconds(3))
        let cachedImage = try #require(await LibraryClient.live.cachedImage(stableCacheKey))
        #expect(cachedImage.size == image.size)
    }

    @MainActor
    @Test
    func testImageClientFetchImageUsesSDWebImageStableAliasCacheKey() async throws {
        let url = try #require(
            URL(string: "https://ehgt.org/ab/cd/0001-1234567890.webp?download=1")
        )
        let stableCacheKey = try #require(url.stableImageCacheKey)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: .init(width: 1, height: 1),
            format: format
        )
        .image { context in
            UIColor.systemGreen.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let imageData = try #require(image.pngData())

        await storeSDWebImageData(imageData, forKey: stableCacheKey)
        defer {
            SDImageCache.shared.removeImage(forKey: stableCacheKey) {}
            SDImageCache.shared.removeImage(forKey: url.absoluteString) {}
        }

        let client = ImageClient(
            prefetchImages: { _ in },
            saveImageToPhotoLibrary: { _, _ in false },
            downloadImage: { _ in
                Issue.record("Expected ImageClient to use the cached SDWebImage data.")
                return .failure(AppError.notFound)
            },
            retrieveImage: ImageClient.live.retrieveImage,
            isCached: LibraryClient.live.isCached
        )

        let result = await client.fetchImage(url: url)
        let fetchedImage = try result.get()

        #expect(fetchedImage.size == image.size)
    }

    @MainActor
    @Test
    func testImageClientFetchImageDownloadsWhenCachedRetrievalFails() async throws {
        let url = try #require(
            URL(string: "https://ehgt.org/ab/cd/0001-1234567890.jpg?download=1")
        )
        let expectedCacheKeys = url.imageCacheKeys(includeStableAlias: true)
        let retrievedCacheKeys = UncheckedBox([String]())
        let downloadedURLs = UncheckedBox([URL]())
        let client = ImageClient(
            prefetchImages: { _ in },
            saveImageToPhotoLibrary: { _, _ in false },
            downloadImage: { downloadURL in
                downloadedURLs.value.append(downloadURL)
                return .success(UIImage())
            },
            retrieveImage: { cacheKey in
                retrievedCacheKeys.value.append(cacheKey)
                return .failure(AppError.notFound)
            },
            isCached: { _ in true }
        )

        let result = await client.fetchImage(url: url)
        _ = try result.get()

        #expect(retrievedCacheKeys.value == expectedCacheKeys)
        #expect(downloadedURLs.value == [url])
    }

}

// MARK: - Repair Seed Helpers

private extension DownloadManagerRepairSeedTests {
    func storeSDWebImageData(_ data: Data, forKey key: String) async {
        await withCheckedContinuation { continuation in
            SDImageCache.shared.storeImageData(data, forKey: key) {
                continuation.resume()
            }
        }
    }

    func setupRepairSeedFiles(
        storage: DownloadFileStorage,
        sourceFolderURL: URL,
        gid: String
    ) throws {
        try FileManager.default.createDirectory(
            at: sourceFolderURL,
            withIntermediateDirectories: true
        )
        let oldManifest = try sampleManifest(
            gid: gid, title: "Mixed Version",
            pageCount: 2
        )
        try JSONEncoder().encode(oldManifest).write(
            to: sourceFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x00]).write(
            to: sourceFolderURL.appendingPathComponent(
                storage.makeCoverRelativePath(gid: gid, token: "token", fileExtension: "jpg")
            ),
            options: .atomic
        )
        try Data([0x01]).write(
            to: sourceFolderURL.appendingPathComponent(
                storage.makePageRelativePath(gid: gid, token: "token", index: 1, fileExtension: "jpg")
            ),
            options: .atomic
        )
        try Data([0x02]).write(
            to: sourceFolderURL.appendingPathComponent(
                storage.makePageRelativePath(gid: gid, token: "token", index: 2, fileExtension: "jpg")
            ),
            options: .atomic
        )
    }

    func makeRepairSeedPayload(gid: String) -> DownloadRequestPayload {
        DownloadRequestPayload(
            gallery: Gallery(
                gid: gid, token: "token", title: "Mixed Version",
                rating: 4, tags: [], category: .doujinshi,
                uploader: "Uploader", pageCount: 2, postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                galleryURL: URL(string: "https://e-hentai.org/g/\(gid)/token")
            ),
            galleryDetail: GalleryDetail(
                gid: gid, title: "Mixed Version", jpnTitle: nil,
                isFavorited: false, visibility: .yes,
                rating: 4, userRating: 0, ratingCount: 1,
                category: .doujinshi, language: .japanese,
                uploader: "Uploader", postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                favoritedCount: 0, pageCount: 2,
                sizeCount: 1, sizeType: "MB", torrentCount: 0
            ),
            previewURLs: [:], previewConfig: .normal(rows: 4),
            host: .ehentai, folderName: "Folder", options: .init(), mode: .repair
        )
    }

    func setupZeroBytePageFiles(
        rootURL: URL, gid: String, storage: DownloadFileStorage
    ) throws -> (URL, URL) {
        let completedFolderURL = rootURL.appendingPathComponent(
            "Folder/\(gid) - Pause Race", isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: completedFolderURL,
            withIntermediateDirectories: true
        )
        let manifest = try sampleManifest(gid: gid, title: "Pause Race")
        try JSONEncoder().encode(manifest).write(
            to: completedFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            options: .atomic
        )
        try Data([0x00]).write(
            to: completedFolderURL.appendingPathComponent(
                storage.makeCoverRelativePath(gid: gid, token: "token", fileExtension: "jpg")
            ),
            options: .atomic
        )
        let emptyPageURL = completedFolderURL.appendingPathComponent(
            storage.makePageRelativePath(gid: gid, token: "token", index: 1, fileExtension: "jpg")
        )
        try Data().write(to: emptyPageURL, options: .atomic)
        let goodPageURL = completedFolderURL.appendingPathComponent(
            storage.makePageRelativePath(gid: gid, token: "token", index: 2, fileExtension: "jpg")
        )
        try Data([0x02]).write(to: goodPageURL, options: .atomic)
        return (emptyPageURL, goodPageURL)
    }
}
