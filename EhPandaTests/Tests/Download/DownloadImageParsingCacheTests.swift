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
    @Test
    func testCachedKokomadePlaceholderStoredUnderNormalImageURLIsRejected() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1_000_000) + 33)
        let manager = makeTestingDownloadCoordinator()
        let normalImageURL = try #require(
            URL(string: "https://exhentai.org/fullimg.php?gid=\(gid)&page=1&key=normal-cache-key")
        )

        let imageData = try fixtureData(resource: "Kokomade", pathExtension: "jpg")
        let cacheKeys = normalImageURL.imageCacheKeys
        for cacheKey in cacheKeys {
            try await KingfisherManager.shared.cache.storeToDisk(imageData, forKey: cacheKey)
        }
        defer { cacheKeys.forEach { KingfisherManager.shared.cache.removeImage(forKey: $0) } }
        await waitUntilCacheReady(for: cacheKeys)

        let cachedData = await manager.validatedCachedAssetData(
            for: [normalImageURL]
        )

        #expect(cachedData == nil)
    }

    @Test
    func testFileBasedEmptyExResponseMapsToAuthenticationRequired() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .exLoginRequired)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadCoordinator()
        let response = try makeResponse(
            url: Defaults.URL.exhentai,
            contentType: "text/html",
            headers: [
                "Set-Cookie": "\(Defaults.Cookie.yay)=louder; Path=/"
            ]
        )
        let error = await manager.detectResponseError(
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

        let manager = makeTestingDownloadCoordinator()
        let response = try makeResponse(
            url: Defaults.URL.exhentai,
            contentType: "text/html"
        )
        let error = await manager.detectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: URL(string: "https://exhentai.org/g/1/1/")
        )

        #expect(error == .authenticationRequired)
    }

}
