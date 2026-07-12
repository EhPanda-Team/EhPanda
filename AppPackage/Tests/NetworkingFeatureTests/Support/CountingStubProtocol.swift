import Foundation
import Synchronization

enum StubStep: Sendable {
    case transportFailure(URLError.Code)
    case http(status: Int, data: Data, headers: [String: String] = [:])
}

struct StubScript: Sendable {
    let stepsByURL: [String: [StubStep]]

    init(_ stepsByURL: [String: [StubStep]]) {
        self.stepsByURL = stepsByURL
    }

    init(_ stepsByURL: [URL: [StubStep]]) {
        self.init(
            Dictionary(
                uniqueKeysWithValues: stepsByURL.map { url, steps in
                    (url.absoluteString, steps)
                }
            )
        )
    }
}

final class StubHandle: Sendable {
    private let token: UUID

    fileprivate init(token: UUID) {
        self.token = token
    }

    func attempts(for url: URL) -> Int {
        CountingStubProtocol.attempts(for: url, token: token)
    }

    var receivedRequests: [URLRequest] {
        CountingStubProtocol.receivedRequests(for: token)
    }

    func tearDown() {
        CountingStubProtocol.removeState(for: token)
    }
}

func makeStubbedSession(script: StubScript) -> (session: URLSession, handle: StubHandle) {
    let token = UUID()
    CountingStubProtocol.register(script: script, for: token)

    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CountingStubProtocol.self]
    configuration.httpAdditionalHeaders = [
        CountingStubProtocol.tokenHeader: token.uuidString
    ]
    return (
        URLSession(configuration: configuration),
        StubHandle(token: token)
    )
}

final class CountingStubProtocol: URLProtocol {
    static let tokenHeader = "X-EhPanda-Stub-Token"

    private static let registry = Mutex<[UUID: StubState]>([:])

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard
            let tokenValue = request.value(forHTTPHeaderField: Self.tokenHeader),
            let token = UUID(uuidString: tokenValue)
        else {
            fail(with: StubFailure.missingToken)
            return
        }
        guard let state = Self.registry.withLock({ $0[token] }) else {
            fail(with: StubFailure.missingState(token))
            return
        }

        var recordedRequest = request
        recordedRequest.setValue(nil, forHTTPHeaderField: Self.tokenHeader)
        if let body = Self.requestBody(from: request) {
            recordedRequest.httpBodyStream = nil
            recordedRequest.httpBody = body
        }

        guard let step = state.recordAndTakeStep(for: recordedRequest) else {
            fail(with: StubFailure.unscriptedURL(request.url))
            return
        }

        switch step {
        case .transportFailure(let code):
            fail(with: URLError(code))

        case .http(let status, let data, let headers):
            guard
                let url = request.url,
                let response = HTTPURLResponse(
                    url: url,
                    statusCode: status,
                    httpVersion: "HTTP/1.1",
                    headerFields: headers
                )
            else {
                fail(with: StubFailure.invalidResponse(request.url, status: status))
                return
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}

    fileprivate static func register(script: StubScript, for token: UUID) {
        registry.withLock { $0[token] = StubState(script: script) }
    }

    fileprivate static func removeState(for token: UUID) {
        registry.withLock { $0[token] = nil }
    }

    fileprivate static func attempts(for url: URL, token: UUID) -> Int {
        registry.withLock { $0[token] }?.attempts(for: url) ?? 0
    }

    fileprivate static func receivedRequests(for token: UUID) -> [URLRequest] {
        registry.withLock { $0[token] }?.receivedRequests ?? []
    }

    private static func requestBody(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }

        stream.open()
        defer { stream.close() }

        var body = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else {
                return nil
            }
            guard count > 0 else {
                return body
            }
            body.append(contentsOf: buffer.prefix(count))
        }
    }

    private func fail(with error: any Error) {
        client?.urlProtocol(self, didFailWithError: error)
    }
}

private final class StubState: Sendable {
    private struct State: Sendable {
        var attemptsByURL = [String: Int]()
        var receivedRequests = [URLRequest]()
    }

    private let script: StubScript
    private let state = Mutex(State())

    init(script: StubScript) {
        self.script = script
    }

    var receivedRequests: [URLRequest] {
        state.withLock { $0.receivedRequests }
    }

    func attempts(for url: URL) -> Int {
        state.withLock { $0.attemptsByURL[url.absoluteString, default: 0] }
    }

    func recordAndTakeStep(for request: URLRequest) -> StubStep? {
        guard let urlKey = request.url?.absoluteString else {
            return nil
        }
        return state.withLock { state in
            state.receivedRequests.append(request)
            let attempt = state.attemptsByURL[urlKey, default: 0]
            state.attemptsByURL[urlKey] = attempt + 1

            guard let steps = script.stepsByURL[urlKey], !steps.isEmpty else {
                return nil
            }
            return steps[min(attempt, steps.count - 1)]
        }
    }
}

private enum StubFailure: Error {
    case missingToken
    case missingState(UUID)
    case unscriptedURL(URL?)
    case invalidResponse(URL?, status: Int)
}
