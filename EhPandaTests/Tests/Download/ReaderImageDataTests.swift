//
//  ReaderImageDataTests.swift
//  EhPandaTests
//

import Foundation
import Testing
import UIKit
@testable import EhPanda

@Suite(.serialized)
struct ReaderImageDataTests {
    @Test
    func testFetchesAndStoresOnCacheMiss() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://example.com/reader/fetch.png"))
        let imageData = try makePNGData()
        let requestCount = UncheckedBox(0)
        let (session, sessionID) = makeStubbedSession()
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
            requestCount.value += 1
            return (try makeHTTPResponse(url: url, statusCode: 200), imageData)
        }

        let data = try await ImageClient.readerImageData(
            url: url, dataCache: cache, urlSession: session
        )

        #expect(data == imageData)
        #expect(requestCount.value == 1)
        let cached = await cache.data(
            forKeys: url.imageCacheKeys(includeStableAlias: true)
        )
        #expect(cached == imageData)
    }

    @Test
    func testReturnsCachedBytesWithoutNetwork() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://example.com/reader/cached.png"))
        let imageData = try makePNGData()
        try await cache.store(
            imageData, forKeys: url.imageCacheKeys(includeStableAlias: true)
        )
        let requestCount = UncheckedBox(0)
        let (session, sessionID) = makeStubbedSession()
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
            requestCount.value += 1
            return (try makeHTTPResponse(url: url, statusCode: 200), imageData)
        }

        let data = try await ImageClient.readerImageData(
            url: url, dataCache: cache, urlSession: session
        )

        #expect(data == imageData)
        #expect(requestCount.value == 0)
    }

    @Test
    func testThrowsAndSkipsCacheOnHTTPError() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://example.com/reader/error.png"))
        let imageData = try makePNGData()
        let (session, sessionID) = makeStubbedSession()
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
            (try makeHTTPResponse(url: url, statusCode: 503), imageData)
        }

        do {
            _ = try await ImageClient.readerImageData(
                url: url, dataCache: cache, urlSession: session
            )
            Issue.record("Expected readerImageData to throw on an HTTP error")
        } catch let error as AppError {
            #expect(error == .networkingFailed)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        let cached = await cache.data(
            forKeys: url.imageCacheKeys(includeStableAlias: true)
        )
        #expect(cached == nil)
    }

    @Test
    func testRejectsAndSkipsCacheForNonDecodableBody() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://example.com/reader/notimage.png"))
        let htmlData = Data("<html><body>Your IP has been temporarily banned</body></html>".utf8)
        let (session, sessionID) = makeStubbedSession()
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
            (try makeHTTPResponse(url: url, statusCode: 200), htmlData)
        }

        do {
            _ = try await ImageClient.readerImageData(
                url: url, dataCache: cache, urlSession: session
            )
            Issue.record("Expected readerImageData to reject a non-decodable body")
        } catch let error as AppError {
            #expect(error == .parseFailed)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        let cached = await cache.data(
            forKeys: url.imageCacheKeys(includeStableAlias: true)
        )
        #expect(cached == nil)
    }

    @Test
    func testFetchImageAssetServesOwnedCacheAndRoutesByBytes() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://example.com/reader/export.png"))
        let imageData = try makePNGData()
        try await cache.store(
            imageData, forKeys: url.imageCacheKeys(includeStableAlias: true)
        )
        let requestCount = UncheckedBox(0)
        let (session, sessionID) = makeStubbedSession()
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
            requestCount.value += 1
            return (try makeHTTPResponse(url: url, statusCode: 200), imageData)
        }
        var client = ImageClient.live
        client.dataCache = cache
        client.urlSession = session

        let asset = try await client.fetchImageAsset(url: url).get()

        #expect(asset.data == imageData)
        #expect(asset.isAnimated == false)
        #expect(requestCount.value == 0)
    }

    private func makeIsolatedDataCache() -> (cache: DataCache, rootURL: URL) {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return (DataCache(configuration: .init(rootURL: rootURL)), rootURL)
    }

    private func makeStubbedSession() -> (session: URLSession, sessionID: String) {
        let sessionID = UUID().uuidString
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
        configuration.httpAdditionalHeaders = [
            SharedSessionStubURLProtocol.headerKey: sessionID
        ]
        return (URLSession(configuration: configuration), sessionID)
    }

    private func makePNGData() throws -> Data {
        let image = UIGraphicsImageRenderer(size: .init(width: 2, height: 2)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        return try #require(image.pngData())
    }
}

private func makeHTTPResponse(url: URL, statusCode: Int) throws -> HTTPURLResponse {
    guard let response = HTTPURLResponse(
        url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil
    ) else {
        throw AppError.unknown
    }
    return response
}
