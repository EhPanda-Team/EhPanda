//
//  DownloadImageErrorTests.swift
//  EhPandaTests
//

import CoreData
import Foundation
import Testing
@testable import EhPanda

@Suite(.serialized)
struct DownloadImageErrorTests: DownloadFeatureTestCase {
    @Test
    func testFileBasedInvalidPageMapsToNotFound() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let invalidPageData = Data("""
        <html><body><h1>Invalid page</h1><p>Gallery not found</p></body></html>
        """.utf8)
        try invalidPageData.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadCoordinator()
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/1/1/"))
        let response = try makeResponse(
            url: galleryURL,
            contentType: "text/html"
        )
        let error = await manager.detectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: galleryURL
        )

        #expect(error == .notFound)
    }

    @Test
    func testFileBasedKeepTryingMapsToNotFound() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let keepTryingData = Data(
            "<html><body><h1>Keep trying</h1></body></html>".utf8
        )
        try keepTryingData.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadCoordinator()
        let pageURL = try #require(URL(string: "https://e-hentai.org/s/1/1-1"))
        let response = try makeResponse(
            url: pageURL,
            contentType: "text/html"
        )
        let error = await manager.detectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: pageURL
        )

        #expect(error == .notFound)
    }

    @Test
    func testFileBasedHTTP404MapsToNotFound() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        try Data("Not here".utf8).write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadCoordinator()
        let notFoundURL = try #require(URL(string: "https://e-hentai.org/g/1/1/"))
        let response = try makeResponse(
            url: notFoundURL,
            statusCode: 404,
            contentType: "text/html"
        )
        let error = await manager.detectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: notFoundURL
        )

        #expect(error == .notFound)
    }

    @Test
    func testFileBased404GalleryNotAvailableFallsBackToNotFound() async throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("html")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let galleryNotAvailableData = Data("""
        <html>
          <head><title>Gallery Not Available</title></head>
          <body><h1>Gallery Not Available</h1></body>
        </html>
        """.utf8)
        try galleryNotAvailableData.write(to: fileURL, options: .atomic)

        let manager = makeTestingDownloadCoordinator()
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/1/1/"))
        let response = try makeResponse(
            url: galleryURL,
            statusCode: 404,
            contentType: "text/html"
        )
        let error = await manager.detectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: galleryURL
        )

        #expect(error == .notFound)
    }

    @Test
    func testFileBasedHTMLBanPageStillParsesThroughParserInsteadOfParseFailed() async throws {
        let fileURL = try writeFixtureToTemporaryFile(filename: .ipBanned)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let manager = makeTestingDownloadCoordinator()
        let bannedURL = try #require(URL(string: "https://example.com/banned"))
        let response = try makeResponse(
            url: bannedURL,
            contentType: "text/html; charset=utf-8"
        )
        let error = await manager.detectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: bannedURL
        )

        #expect(error != .parseFailed)
        guard case .ipBanned = error else {
            Issue.record("Expected ipBanned, got \(String(describing: error))")
            return
        }
    }

    @Test
    func testTextHTMLJSONAPIResponseDoesNotMapToParseFailed() async throws {
        let manager = makeTestingDownloadCoordinator()
        let apiURL = try #require(URL(string: "https://e-hentai.org/api.php"))
        let response = try makeResponse(
            url: apiURL,
            contentType: "text/html; charset=UTF-8"
        )
        let responsePayload: [String: String] = [
            "d": "1184 x 1728 :: 14.78 MiB",
            "o": "org",
            "lf": #"fullimg/3861928/1/99j92okaldl/Karin_1.webp"#,
            "ls": "?f_shash=6aa741ba4e302352139ae2fc7377c846e68d9093",
            "ll": "6aa741ba4e302352139ae2fc7377c846e68d9093"
                + "-15497378-1184-1728-wbp/forumtoken/3861928-1/Karin_1.webp",
            "lo": "s/6aa741ba4e/3861928-1",
            "xres": "1184",
            "yres": "1728",
            "i": "https://mrfmlfe.vzpqazmbjydh.hath.network:60000/h/"
                + "6aa741ba4e302352139ae2fc7377c846e68d9093-15497378-1184-1728-wbp/"
                + "keystamp=1779356100-f4c09dd971;fileindex=232157952;xres=org/Karin_1.webp",
            "s": "48803"
        ]
        let data = try JSONSerialization.data(withJSONObject: responsePayload)

        let error = await manager.detectResponseError(
            data: data,
            response: response,
            requestURL: apiURL
        )

        #expect(error == nil)
    }

}
