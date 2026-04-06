//
//  DownloadImageParsingCacheTests.swift
//  EhPandaTests
//

import CoreData
import Kingfisher
import UIKit
import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadImageParsingCacheTests: DownloadFeatureTestCase {
    func testCachedKokomadePlaceholderStoredUnderNormalImageURLDoesNotRestoreIntoOfflinePages() async throws {
        let container = try makeInMemoryContainer()
        let gid = String(Int(Date().timeIntervalSince1970 * 1_000_000) + 33)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = DownloadFileStorage(rootURL: rootURL, fileManager: .default)
        let manager = DownloadManager(storage: storage, urlSession: .shared, persistenceContainer: container)
        let normalImageURL = try #require(
            URL(string: "https://exhentai.org/fullimg.php?gid=\(gid)&page=1&key=normal-cache-key")
        )
        try insertPersistedGalleryState(in: container, gid: gid, imageURLs: [1: normalImageURL])

        let imageData = try fixtureData(resource: "Kokomade", pathExtension: "jpg")
        let cacheKeys = normalImageURL.imageCacheKeys(includeStableAlias: true)
        for cacheKey in cacheKeys {
            try await KingfisherManager.shared.cache.storeToDisk(imageData, forKey: cacheKey)
        }
        defer { cacheKeys.forEach { KingfisherManager.shared.cache.removeImage(forKey: $0) } }
        await waitUntilCacheReady(for: cacheKeys)

        let payload = try makeExhentaiPayload(gid: gid)
        let restoredCount = try await manager.testingRestoreCachedPages(payload: payload)
        let restoredPageURL = storage.temporaryFolderURL(gid: gid)
            .appendingPathComponent("pages/0001.jpg")

        #expect(restoredCount == 0)
        #expect(FileManager.default.fileExists(atPath: restoredPageURL.path) == false)
    }

    @Test
    func testFileBasedEmptyExResponseMapsToAuthenticationRequired() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .exLoginRequired)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let cookieClient = CookieClient.live
        cookieClient.clearAll()
        defer { cookieClient.clearAll() }
        cookieClient.setOrEditCookie(
            for: Defaults.URL.exhentai,
            key: Defaults.Cookie.yay,
            value: "louder"
        )

        let manager = makeTestingDownloadManager()
        let response = try makeResponse(
            url: Defaults.URL.exhentai,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://exhentai.org/g/1/1/")
        )

        #expect(error == .authenticationRequired)
    }

    @Test
    func testFileBasedAuthHTMLMarkersMapToAuthenticationRequired() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let authHTMLData = Data("""
        <html>
          <body>
            <a href="bounce_login.php">Login</a>
            <img src="/img/kokomade.jpg">
            <p>Access to ExHentai.org is restricted.</p>
          </body>
        </html>
        """.utf8)
        try authHTMLData.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadManager()
        let response = try makeResponse(
            url: Defaults.URL.exhentai,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://exhentai.org/g/1/1/")
        )

        #expect(error == .authenticationRequired)
    }

}

// MARK: - Payload Factory

private extension DownloadImageParsingCacheTests {
    func makeExhentaiPayload(gid: String) throws -> DownloadRequestPayload {
        DownloadRequestPayload(
            gallery: Gallery(
                gid: gid, token: "token", title: "Auth Placeholder", rating: 4,
                tags: [], category: .doujinshi, uploader: "Uploader", pageCount: 1, postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                galleryURL: try #require(URL(string: "https://exhentai.org/g/\(gid)/token") as URL?)
            ),
            galleryDetail: GalleryDetail(
                gid: gid, title: "Auth Placeholder", jpnTitle: nil,
                isFavorited: false, visibility: .yes, rating: 4, userRating: 0, ratingCount: 0,
                category: .doujinshi, language: .japanese, uploader: "Uploader", postedDate: .now,
                coverURL: URL(string: "https://example.com/cover.jpg"),
                favoritedCount: 0, pageCount: 1, sizeCount: 12, sizeType: "MB", torrentCount: 0
            ),
            previewURLs: [:], previewConfig: .normal(rows: 4),
            host: .exhentai, options: DownloadOptionsSnapshot(), mode: .initial
        )
    }
}
