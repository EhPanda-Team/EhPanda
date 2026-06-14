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
        await manager.reloadDownloadIndex()

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

        let (cache, cacheRootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: cacheRootURL) }
        var client = ImageClient.live
        client.dataCache = cache

        let result = await client.fetchImage(url: url)
        let fetchedImage = try result.get()

        #expect(pixelSize(fetchedImage) == pixelSize(image))
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
        let downloader = ImageDownloader(name: "test-\(sessionID)")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        configuration.httpAdditionalHeaders = [
            SharedSessionStubURLProtocol.headerKey: sessionID
        ]
        downloader.sessionConfiguration = configuration
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
            KingfisherManager.shared.cache.removeImage(forKey: stableCacheKey)
            KingfisherManager.shared.cache.removeImage(forKey: url.absoluteString)
        }

        let result = await ImageClient.downloadStaticImage(
            url: url,
            downloader: downloader,
            cache: KingfisherManager.shared.cache
        )
        let downloadedImage = try result.get()

        #expect(downloadedImage.size == image.size)
        await waitUntilCacheReady(for: [stableCacheKey], timeout: .seconds(3))
        let cachedImage = try #require(await LibraryClient.live.cachedImage(stableCacheKey))
        #expect(cachedImage.size == image.size)
    }

    @MainActor
    @Test
    func testImageClientDownloadImageCancelsKingfisherTask() async throws {
        let url = try #require(
            URL(string: "https://ehgt.org/ab/cd/0001-1234567890.jpg?download=1")
        )
        let downloader = ImageDownloader(name: "cancel-\(UUID().uuidString)")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HangingURLProtocol.self]
        downloader.sessionConfiguration = configuration
        let task = Task {
            await ImageClient.downloadStaticImage(
                url: url,
                downloader: downloader,
                cache: KingfisherManager.shared.cache
            )
        }

        task.cancel()
        let result = try await waitForTaskValue(
            task,
            timeout: .seconds(1),
            description: "Kingfisher image cancellation"
        )

        #expect(throws: CancellationError.self) {
            try result.get()
        }
    }

    @MainActor
    @Test
    func testImageClientDownloadImageCancelsSDWebImageOperation() async throws {
        let url = try #require(
            URL(string: "https://ehgt.org/ab/cd/0001-1234567890.webp?download=1")
        )
        let downloaderConfig = SDWebImageDownloaderConfig()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HangingURLProtocol.self]
        downloaderConfig.sessionConfiguration = configuration
        let downloader = SDWebImageDownloader(config: downloaderConfig)
        let manager = SDWebImageManager(cache: SDImageCache.shared, loader: downloader)
        let task = Task {
            await ImageClient.downloadAnimatedImage(url: url, manager: manager)
        }

        task.cancel()
        let result = try await waitForTaskValue(
            task,
            timeout: .seconds(1),
            description: "SDWebImage image cancellation"
        )

        #expect(throws: CancellationError.self) {
            try result.get()
        }
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

        let (cache, cacheRootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: cacheRootURL) }
        let client = ImageClient(
            prefetchImages: { _ in },
            saveImageToPhotoLibrary: { _, _ in false },
            saveImageDataToPhotoLibrary: { _ in false },
            downloadImage: { _ in
                Issue.record("Expected ImageClient to use the cached SDWebImage data.")
                return .failure(AppError.notFound)
            },
            retrieveImage: ImageClient.live.retrieveImage,
            isCached: LibraryClient.live.isCached,
            dataCache: cache
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
        let (cache, cacheRootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: cacheRootURL) }
        let retrievedCacheKeys = UncheckedBox([String]())
        let downloadedURLs = UncheckedBox([URL]())
        let downloadedImage = UIGraphicsImageRenderer(size: .init(width: 1, height: 1)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(.init(x: 0, y: 0, width: 1, height: 1))
        }
        let client = ImageClient(
            prefetchImages: { _ in },
            saveImageToPhotoLibrary: { _, _ in false },
            saveImageDataToPhotoLibrary: { _ in false },
            downloadImage: { downloadURL in
                downloadedURLs.value.append(downloadURL)
                return .success(downloadedImage)
            },
            retrieveImage: { cacheKey in
                retrievedCacheKeys.value.append(cacheKey)
                return .failure(AppError.notFound)
            },
            isCached: { _ in true },
            dataCache: cache
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

    /// A `DataCache` backed by a throwaway directory, isolated from `DataCache.shared`.
    ///
    /// `ImageClient.imageData` consults its `dataCache` before the retrieve/download
    /// closures, and `.shared` persists on disk across runs. Injecting a per-test cache
    /// keeps these tests hermetic and repeatable without clearing the simulator cache.
    func makeIsolatedDataCache() -> (cache: DataCache, rootURL: URL) {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return (DataCache(configuration: .init(rootURL: rootURL)), rootURL)
    }

    /// The image's dimensions in pixels (`size` in points × `scale`).
    ///
    /// `fetchImage` round-trips images through `Data`, which yields a scale-1 image with
    /// the original pixel dimensions. Comparing pixels keeps cache-hit assertions stable
    /// regardless of the stored image's scale.
    func pixelSize(_ image: UIImage) -> CGSize {
        .init(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
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
            host: .ehentai, folderName: "Folder", mode: .repair
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
