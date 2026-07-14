import AppModels
import AppTools
import Foundation
import ImageClient
import Synchronization
import Testing
import TestingSupport
import UIKit

func makeIsolatedDataCache() -> (cache: DataCache, rootURL: URL) {
    let rootURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    return (DataCache(configuration: .init(rootURL: rootURL)), rootURL)
}

func makeStubbedSession() -> (session: URLSession, sessionID: String) {
    let sessionID = UUID().uuidString
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [SharedSessionStubURLProtocol.self]
    configuration.httpAdditionalHeaders = [
        SharedSessionStubURLProtocol.headerKey: sessionID
    ]
    return (URLSession(configuration: configuration), sessionID)
}

func makeImageClient(dataCache: DataCache, urlSession: URLSession) -> ImageClient {
    var client = ImageClient.live
    client.dataCache = dataCache
    client.urlSession = urlSession
    return client
}

@MainActor
func makePNGData() throws -> Data {
    let image = UIGraphicsImageRenderer(size: .init(width: 2, height: 2)).image { context in
        UIColor.red.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
    }
    return try #require(image.pngData())
}

func fixtureData(resource: String, pathExtension: String) throws -> Data {
    let fixtureURL = try #require(
        TestFixtures.url(forResource: resource, withExtension: pathExtension)
    )
    return try Data(contentsOf: fixtureURL)
}

func makeHTTPResponse(url: URL, statusCode: Int) throws -> HTTPURLResponse {
    guard let response = HTTPURLResponse(
        url: url,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    ) else {
        throw AppError.unknown
    }
    return response
}

final class HangingURLProtocol: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {}

    override func stopLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
    }
}

final class SharedSessionStubURLProtocol: URLProtocol {
    static let headerKey = "X-TestSession-ID"

    private static let handlers = SharedSessionStubHandlers()

    static func setHandler(
        for sessionID: String,
        handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    ) {
        handlers.setHandler(for: sessionID, handler: handler)
    }

    static func removeHandler(for sessionID: String) {
        handlers.removeHandler(for: sessionID)
    }

    private static func handler(
        for request: URLRequest
    ) -> (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))? {
        guard let sessionID = request.value(forHTTPHeaderField: headerKey) else {
            return nil
        }
        return handlers.handler(for: sessionID)
    }

    override static func canInit(with request: URLRequest) -> Bool {
        handler(for: request) != nil
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler(for: request) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class SharedSessionStubHandlers: Sendable {
    private let handlers = Mutex<
        [String: @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)]
    >([:])

    func setHandler(
        for sessionID: String,
        handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)
    ) {
        handlers.withLock { $0[sessionID] = handler }
    }

    func removeHandler(for sessionID: String) {
        handlers.withLock { $0[sessionID] = nil }
    }

    func handler(
        for sessionID: String
    ) -> (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))? {
        handlers.withLock { $0[sessionID] }
    }
}
