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

        let manager = makeTestingDownloadManager()
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/1/1/"))
        let response = try makeResponse(
            url: galleryURL,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
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

        let manager = makeTestingDownloadManager()
        let pageURL = try #require(URL(string: "https://e-hentai.org/s/1/1-1"))
        let response = try makeResponse(
            url: pageURL,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
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

        let manager = makeTestingDownloadManager()
        let notFoundURL = try #require(URL(string: "https://e-hentai.org/g/1/1/"))
        let response = try makeResponse(
            url: notFoundURL,
            statusCode: 404,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
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

        let manager = makeTestingDownloadManager()
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/1/1/"))
        let response = try makeResponse(
            url: galleryURL,
            statusCode: 404,
            contentType: "text/html"
        )
        let error = await manager.testingDetectResponseError(
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

        let manager = makeTestingDownloadManager()
        let bannedURL = try #require(URL(string: "https://example.com/banned"))
        let response = try makeResponse(
            url: bannedURL,
            contentType: "text/html; charset=utf-8"
        )
        let error = await manager.testingDetectResponseError(
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

}
