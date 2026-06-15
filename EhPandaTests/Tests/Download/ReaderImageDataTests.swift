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
    func testRejectsAndSkipsCacheForQuotaPlaceholderFromNetwork() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://ehgt.org/g/509.gif"))
        let placeholderData = try fixtureData(resource: "BandwidthExceeded", pathExtension: "html")
        let (session, sessionID) = makeStubbedSession()
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
            (try makeHTTPResponse(url: url, statusCode: 200), placeholderData)
        }

        // The H@H `509` notice is a valid 200 GIF; the owned fetch must surface it as
        // `.quotaExceeded` and never cache it, or it would poison the key until expiry.
        do {
            _ = try await ImageClient.readerImageData(
                url: url, dataCache: cache, urlSession: session
            )
            Issue.record("Expected readerImageData to reject the quota placeholder")
        } catch let error as AppError {
            #expect(error == .quotaExceeded)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        let cached = await cache.data(
            forKeys: url.imageCacheKeys(includeStableAlias: true)
        )
        #expect(cached == nil)
    }

    @Test
    func testRejectsAndSkipsCacheForAuthPlaceholderFromNetwork() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://exhentai.org/img/kokomade.jpg"))
        let placeholderData = try fixtureData(resource: "Kokomade", pathExtension: "jpg")
        let (session, sessionID) = makeStubbedSession()
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
            (try makeHTTPResponse(url: url, statusCode: 200), placeholderData)
        }

        do {
            _ = try await ImageClient.readerImageData(
                url: url, dataCache: cache, urlSession: session
            )
            Issue.record("Expected readerImageData to reject the auth placeholder")
        } catch let error as AppError {
            #expect(error == .authenticationRequired)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        let cached = await cache.data(
            forKeys: url.imageCacheKeys(includeStableAlias: true)
        )
        #expect(cached == nil)
    }

    @Test
    func testPurgesCachedPlaceholderAndRefetches() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://ehgt.org/g/509.gif"))
        let cacheKeys = url.imageCacheKeys(includeStableAlias: true)
        let placeholderData = try fixtureData(resource: "BandwidthExceeded", pathExtension: "html")
        try await cache.store(placeholderData, forKeys: cacheKeys)
        let realImageData = try makePNGData()
        let requestCount = UncheckedBox(0)
        let (session, sessionID) = makeStubbedSession()
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
            requestCount.value += 1
            return (try makeHTTPResponse(url: url, statusCode: 200), realImageData)
        }

        // A placeholder cached before the guard existed must be purged and re-fetched,
        // so a lifted limit recovers without the user clearing the cache by hand.
        let data = try await ImageClient.readerImageData(
            url: url, dataCache: cache, urlSession: session
        )

        #expect(data == realImageData)
        #expect(requestCount.value == 1)
        let cached = await cache.data(forKeys: cacheKeys)
        #expect(cached == realImageData)
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

    @Test
    func testCancellationStopsTheOwnedFetch() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://example.com/reader/hang.png"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HangingURLProtocol.self]
        let session = URLSession(configuration: configuration)

        // Dismissing the reader mid-fetch cancels the Task; the owned URLSession
        // fetch must honor that and stop instead of completing (BUG-24).
        let task = Task {
            try await ImageClient.readerImageData(url: url, dataCache: cache, urlSession: session)
        }
        task.cancel()

        do {
            _ = try await task.value
            Issue.record("Expected the cancelled owned fetch to throw")
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func testCancelledReaderImageAssetFetchReturnsNil() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://example.com/reader/hang-asset.png"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HangingURLProtocol.self]
        var client = ImageClient.noop
        client.dataCache = cache
        client.urlSession = URLSession(configuration: configuration)

        // A cancelled fetch must surface as nil (not a thrown failure), so the reader
        // can distinguish "scrolled away" from a real load failure via Task.isCancelled.
        let task = Task { await client.fetchReaderImageAsset(url: url) }
        task.cancel()
        let asset = await task.value

        #expect(asset == nil)
    }

    private func fixtureData(resource: String, pathExtension: String) throws -> Data {
        let fixtureURL = try #require(
            Bundle(for: TestBundleLocator.self).url(forResource: resource, withExtension: pathExtension)
        )
        return try Data(contentsOf: fixtureURL)
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
