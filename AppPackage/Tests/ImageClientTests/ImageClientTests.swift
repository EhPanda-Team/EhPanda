import AppModels
import AppTools
import Foundation
import ImageClient
import Testing

@Suite(.serialized)
struct ImageClientTests {
    @MainActor
    @Test
    func servesCachedImageWithoutNetworkRequest() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://example.com/reader/cached.png"))
        let imageData = try makePNGData()
        try await cache.store(imageData, forKeys: url.imageCacheKeys)
        let (session, sessionID) = makeStubbedSession()
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }
        let client = makeImageClient(dataCache: cache, urlSession: session)

        try await confirmation(expectedCount: 0) { networkRequest in
            SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
                networkRequest()
                return (try makeHTTPResponse(url: url, statusCode: 200), imageData)
            }

            let asset = try await client.fetchImageAsset(url: url).get()

            #expect(asset.data == imageData)
            #expect(asset.image.cgImage?.width == 2)
            #expect(asset.image.cgImage?.height == 2)
        }
    }

    @MainActor
    @Test
    func fetchesDecodesAndStoresCacheMissUnderPrimaryKey() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://ehgt.org/h/abc/primary-key-page/1.jpg"))
        let stableKey = try #require(url.stableImageCacheKey)
        let imageData = try makePNGData()
        let (session, sessionID) = makeStubbedSession()
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }
        let client = makeImageClient(dataCache: cache, urlSession: session)

        try await confirmation(expectedCount: 1) { networkRequest in
            SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
                networkRequest()
                return (try makeHTTPResponse(url: url, statusCode: 200), imageData)
            }

            let asset = try await client.fetchImageAsset(url: url).get()

            #expect(asset.data == imageData)
            #expect(asset.image.cgImage?.width == 2)
            #expect(asset.image.cgImage?.height == 2)
        }
        #expect(await cache.data(forKeys: [stableKey]) == imageData)
        #expect(await cache.data(forKeys: [url.absoluteString]) == nil)
    }

    @MainActor
    @Test
    func surfacesHTTPFailureWithoutCachingResponse() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://example.com/reader/error.png"))
        let imageData = try makePNGData()
        let (session, sessionID) = makeStubbedSession()
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
            (try makeHTTPResponse(url: url, statusCode: 503), imageData)
        }
        let client = makeImageClient(dataCache: cache, urlSession: session)

        let error = await #expect(throws: AppError.self) {
            try await client.fetchImageAsset(url: url).get()
        }

        #expect(error == .networkingFailed)
        #expect(await cache.data(forKeys: url.imageCacheKeys) == nil)
    }

    @MainActor
    @Test
    func purgesCachedPlaceholderAndRefetchesImage() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://ehgt.org/g/509.gif"))
        let placeholderData = try fixtureData(resource: "BandwidthExceeded", pathExtension: "html")
        try await cache.store(placeholderData, forKeys: url.imageCacheKeys)
        let imageData = try makePNGData()
        let (session, sessionID) = makeStubbedSession()
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }
        let client = makeImageClient(dataCache: cache, urlSession: session)

        try await confirmation(expectedCount: 1) { networkRequest in
            SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
                networkRequest()
                return (try makeHTTPResponse(url: url, statusCode: 200), imageData)
            }

            let asset = try await client.fetchImageAsset(url: url).get()

            #expect(asset.data == imageData)
            #expect(asset.image.cgImage?.width == 2)
            #expect(asset.image.cgImage?.height == 2)
        }
        #expect(await cache.data(forKeys: url.imageCacheKeys) == imageData)
    }

    @MainActor
    @Test
    func rejectsNondecodableBodyWithoutCachingIt() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://example.com/reader/not-image.png"))
        let htmlData = Data("<html><body>Not an image</body></html>".utf8)
        let (session, sessionID) = makeStubbedSession()
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
            (try makeHTTPResponse(url: url, statusCode: 200), htmlData)
        }
        let client = makeImageClient(dataCache: cache, urlSession: session)

        let error = await #expect(throws: AppError.self) {
            try await client.fetchImageAsset(url: url).get()
        }

        #expect(error == .parseFailed)
        #expect(await cache.data(forKeys: url.imageCacheKeys) == nil)
    }

    @MainActor
    @Test
    func rejectsQuotaPlaceholderFromNetworkWithoutCachingIt() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://ehgt.org/g/509.gif"))
        let placeholderData = try fixtureData(resource: "BandwidthExceeded", pathExtension: "html")
        let (session, sessionID) = makeStubbedSession()
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
            (try makeHTTPResponse(url: url, statusCode: 200), placeholderData)
        }
        let client = makeImageClient(dataCache: cache, urlSession: session)

        let error = await #expect(throws: AppError.self) {
            try await client.fetchImageAsset(url: url).get()
        }

        #expect(error == .quotaExceeded)
        #expect(await cache.data(forKeys: url.imageCacheKeys) == nil)
    }

    @MainActor
    @Test
    func rejectsAuthenticationPlaceholderFromNetworkWithoutCachingIt() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://exhentai.org/img/kokomade.jpg"))
        let placeholderData = try fixtureData(resource: "Kokomade", pathExtension: "jpg")
        let (session, sessionID) = makeStubbedSession()
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }
        SharedSessionStubURLProtocol.setHandler(for: sessionID) { _ in
            (try makeHTTPResponse(url: url, statusCode: 200), placeholderData)
        }
        let client = makeImageClient(dataCache: cache, urlSession: session)

        let error = await #expect(throws: AppError.self) {
            try await client.fetchImageAsset(url: url).get()
        }

        #expect(error == .authenticationRequired)
        #expect(await cache.data(forKeys: url.imageCacheKeys) == nil)
    }

    @MainActor
    @Test
    func cancellationStopsOwnedFetch() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://example.com/reader/hang.png"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HangingURLProtocol.self]
        let session = URLSession(configuration: configuration)
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

    @MainActor
    @Test
    func cancelledReaderImageAssetFetchReturnsNil() async throws {
        let (cache, rootURL) = makeIsolatedDataCache()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let url = try #require(URL(string: "https://example.com/reader/hang-asset.png"))
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [HangingURLProtocol.self]
        let client = makeImageClient(
            dataCache: cache,
            urlSession: URLSession(configuration: configuration)
        )
        let task = Task { await client.fetchReaderImageAsset(url: url) }

        task.cancel()
        let asset = await task.value

        #expect(asset == nil)
    }
}
