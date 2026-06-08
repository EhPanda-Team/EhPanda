//
//  DownloadFeatureTestSupportTypes.swift
//  EhPandaTests
//

import Foundation
import Synchronization
@testable import EhPanda

// MARK: - Supporting Types

final class UncheckedBox<Value: Sendable>: Sendable {
    private let storage: Mutex<Value>

    init(_ value: Value) {
        storage = Mutex(value)
    }

    var value: Value {
        get { storage.withLock { $0 } }
        set { storage.withLock { $0 = newValue } }
    }
}

struct RequestRecorderSnapshot: Equatable {
    var detailRequests = 0
    var metadataRequests = 0
    var mpvRequests = 0
    var imageDispatchRequests = 0
    var imageDownloads = 0
    var previewPageNumbers = [Int]()
}

final class RequestRecorder: Sendable {
    private let state = Mutex(RequestRecorderSnapshot())

    func recordDetail() {
        state.withLock { $0.detailRequests += 1 }
    }

    func recordMetadata() {
        state.withLock { $0.metadataRequests += 1 }
    }

    func recordPreview(_ pageNumber: Int) {
        state.withLock { $0.previewPageNumbers.append(pageNumber) }
    }

    func recordMPV() {
        state.withLock { $0.mpvRequests += 1 }
    }

    func recordImageDispatch() {
        state.withLock { $0.imageDispatchRequests += 1 }
    }

    func recordImageDownload() {
        state.withLock { $0.imageDownloads += 1 }
    }

    func reset() {
        state.withLock { $0 = .init() }
    }

    func snapshot() -> RequestRecorderSnapshot {
        state.withLock { $0 }
    }
}

func requestBodyData(from request: URLRequest) -> Data? {
    if let httpBody = request.httpBody {
        return httpBody
    }

    guard let stream = request.httpBodyStream else {
        return nil
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    let bufferSize = 1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    while stream.hasBytesAvailable {
        let readCount = stream.read(buffer, maxLength: bufferSize)
        guard readCount >= 0 else {
            return nil
        }
        guard readCount > 0 else {
            break
        }
        data.append(buffer, count: readCount)
    }

    return data
}

final class FailFastURLProtocol: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        client?.urlProtocol(
            self, didFailWithError: URLError(.cancelled)
        )
    }

    override func stopLoading() {}
}

final class HangingURLProtocol: URLProtocol {
    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {}

    override func stopLoading() {
        client?.urlProtocol(
            self,
            didFailWithError: URLError(.cancelled)
        )
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
        guard let sessionID = request.value(
            forHTTPHeaderField: headerKey
        ) else {
            return nil
        }
        return handlers.handler(for: sessionID)
    }

    override static func canInit(with request: URLRequest) -> Bool {
        handler(for: request) != nil
    }

    override static func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler(for: request) else {
            client?.urlProtocol(
                self,
                didFailWithError: URLError(.badServerResponse)
            )
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(
                self,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
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
