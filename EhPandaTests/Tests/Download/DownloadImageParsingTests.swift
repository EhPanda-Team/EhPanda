//
//  DownloadImageParsingTests.swift
//  EhPandaTests
//

import CoreData
import Kingfisher
import UIKit
import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadImageParsingTests: DownloadFeatureTestCase {
    func testFileBasedQuotaImageMapsToQuotaExceeded() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .bandwidthExceeded)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadManager()
        let quotaImageURL = try #require(URL(string: "https://ehgt.org/g/509.gif"))
        let response = try makeResponse(
            url: quotaImageURL,
            contentType: "image/gif",
            contentLength: 28658
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: quotaImageURL
        )

        #expect(error == .quotaExceeded)
    }

    @Test
    func testFileBasedQuotaImageRequiresKnown509Signature() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .bandwidthExceeded)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadManager()
        var data = try Data(contentsOf: fileURL)
        data[0] = 0
        try data.write(to: fileURL, options: .atomic)
        let quotaImageURL = try #require(URL(string: "https://ehgt.org/g/509.gif"))
        let response = try makeResponse(
            url: quotaImageURL,
            contentType: "image/gif",
            contentLength: data.count
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: quotaImageURL
        )

        #expect(error == nil)
    }

    @Test
    func testFileBasedBinaryKokomadeImageMapsToAuthenticationRequired() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("gif")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let imageData = try #require(Data(base64Encoded: "R0lGODlhAQABAIABAP///wAAACwAAAAAAQABAAACAkQBADs="))
        try imageData.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadManager()
        let kokomadeURL = try #require(URL(string: "https://exhentai.org/img/kokomade.jpg"))
        let response = try makeResponse(
            url: kokomadeURL,
            contentType: "image/gif",
            contentLength: imageData.count
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://exhentai.org/fullimg.php?gid=1&page=1")
        )

        #expect(error == .authenticationRequired)
    }

    @Test
    func testFileBasedQuotaImageFingerprintMapsToQuotaExceededEvenWhenURLLooksNormal() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .bandwidthExceeded)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadManager()
        let normalImageURL = try #require(URL(string: "https://ehgt.org/h/normal-image-cache-key/1"))
        let response = try makeResponse(
            url: normalImageURL,
            contentType: "image/gif",
            contentLength: 28658
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: normalImageURL
        )

        #expect(error == .quotaExceeded)
    }

    @Test
    func testFileBasedKokomadeImageFingerprintMapsToAuthenticationRequiredEvenWhenURLLooksNormal() async throws {
        let fileURL = try writeFixtureToTemporaryFile(resource: "Kokomade", pathExtension: "jpg")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadManager()
        let normalImageURL = try #require(
            URL(string: "https://exhentai.org/fullimg.php?gid=1&page=1&key=normal-cache-key")
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: try makeResponse(
                url: normalImageURL,
                contentType: "image/jpeg",
                contentLength: 144844
            ),
            requestURL: normalImageURL
        )

        #expect(error == .authenticationRequired)
    }

    @Test
    func testFileBasedTextImageLimitMapsToQuotaExceeded() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let htmlData = Data("""
        <html><body>You have exceeded your image viewing limits</body></html>
        """.utf8)
        try htmlData.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadManager()
        let quotaURL = try #require(URL(string: "https://e-hentai.org/s/1/1-1"))
        let response = try makeResponse(
            url: quotaURL,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: quotaURL
        )

        #expect(error == .quotaExceeded)
    }

    @MainActor
    @Test
    func testCachedQuotaPlaceholderStoredUnderNormalImageURLDoesNotRestoreIntoOfflinePages() async throws {
        let container = try makeInMemoryContainer()
        let gid = String(Int(Date().timeIntervalSince1970 * 1_000_000) + 32)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared, persistenceContainer: container)
        let normalImageURL = try #require(
            URL(string: "https://ehgt.org/h/quota-placeholder-cache-\(gid)/1")
        )
        try insertPersistedGalleryState(in: container, gid: gid, imageURLs: [1: normalImageURL])

        let placeholderURL = try writeFixtureToTemporaryFile(filename: .bandwidthExceeded)
        defer { try? FileManager.default.removeItem(at: placeholderURL) }
        let placeholderData = try Data(contentsOf: placeholderURL)
        let cacheKeys = normalImageURL.imageCacheKeys(includeStableAlias: true)
        for cacheKey in cacheKeys {
            try await KingfisherManager.shared.cache.storeToDisk(placeholderData, forKey: cacheKey)
        }
        defer { cacheKeys.forEach { KingfisherManager.shared.cache.removeImage(forKey: $0) } }
        await waitUntilCacheReady(for: cacheKeys)

        let payload = makeEhentaiPayload(gid: gid)
        let restoredCount = try await manager.testingRestoreCachedPages(payload: payload)
        let restoredPageURL = storage.temporaryFolderURL(gid: gid)
            .appendingPathComponent("pages/0001.gif")

        #expect(restoredCount == 0)
        #expect(FileManager.default.fileExists(atPath: restoredPageURL.path) == false)
    }

}

// MARK: - Payload Factory

private extension DownloadImageParsingTests {
    func makeEhentaiPayload(gid: String) -> DownloadRequestPayload {
        DownloadRequestPayload(
            gallery: Gallery(
                gid: gid, token: "token", title: "Quota Placeholder", rating: 4,
                tags: [], category: .doujinshi, uploader: "Uploader", pageCount: 1, postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                galleryURL: URL(string: "https://e-hentai.org/g/\(gid)/token")
            ),
            galleryDetail: GalleryDetail(
                gid: gid, title: "Quota Placeholder", jpnTitle: nil,
                isFavorited: false, visibility: .yes, rating: 4, userRating: 0, ratingCount: 0,
                category: .doujinshi, language: .japanese, uploader: "Uploader", postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                favoritedCount: 0, pageCount: 1, sizeCount: 12, sizeType: "MB", torrentCount: 0
            ),
            previewURLs: [:], previewConfig: .normal(rows: 4),
            host: .ehentai, options: DownloadOptionsSnapshot(), mode: .initial
        )
    }
}
