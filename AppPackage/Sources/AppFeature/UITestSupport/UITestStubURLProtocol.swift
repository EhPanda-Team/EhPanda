#if DEBUG
import Foundation
import Synchronization

/// A capture's exact replay: it answers only the URLs its validated fixture lists, with each
/// file's recorded media type and verified bytes, and records every request it cannot answer, so
/// a capture can prove it made no request its fixture could not satisfy.
final class CaptureReplay: Sendable {
    /// One replayed response: a fixture file's verified bytes and its recorded media type.
    struct Response: Equatable, Sendable {
        let data: Data
        let mimeType: String
    }

    private let responses: [String: Response]
    private let unknownRequests = Mutex([String]())

    init(responses: [String: Response]) {
        self.responses = responses
    }

    /// Requests this replay could not answer, as `METHOD URL` in arrival order.
    var unknownRequestDescriptions: [String] {
        unknownRequests.withLock({ $0 })
    }

    /// The response for a `GET` of exactly a listed URL; any other request is recorded and gets none.
    func response(for request: URLRequest) -> Response? {
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? ""
        guard method == "GET", let response = responses[url] else {
            unknownRequests.withLock({ $0.append("\(method) \(url)") })
            return nil
        }
        return response
    }
}

/// Answers every HTTP(S) request of a UI-test or capture launch, so none reaches the network.
///
/// The UI tests' hermetic fixture directory maps request paths to a few saved pages by prefix; a
/// capture launch installs its ``CaptureReplay`` instead, and every request it cannot answer fails.
final class UITestStubURLProtocol: URLProtocol {
    private enum Mode {
        case fixtureDirectory(URL?)
        case replay(CaptureReplay)
    }

    private static let mode = Mutex(Mode.fixtureDirectory(nil))

    /// The replay a capture launch installed, if any.
    static var installedReplay: CaptureReplay? {
        guard case .replay(let replay) = mode.withLock({ $0 }) else {
            return nil
        }
        return replay
    }

    override static func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme?.lowercased() else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            finish(statusCode: 404, data: Data(), url: URL(filePath: "/"), mimeType: Self.htmlMIMEType)
            return
        }
        switch Self.mode.withLock({ $0 }) {
        case .fixtureDirectory(let fixtureDirectory):
            loadFixture(url: url, fixtureDirectory: fixtureDirectory)
        case .replay(let replay):
            guard let response = replay.response(for: request) else {
                client?.urlProtocol(self, didFailWithError: URLError(.resourceUnavailable))
                return
            }
            finish(statusCode: 200, data: response.data, url: url, mimeType: response.mimeType)
        }
    }

    override func stopLoading() {}

    static func configure(fixtureDirectory: URL?) {
        mode.withLock {
            $0 = .fixtureDirectory(fixtureDirectory)
        }
    }

    static func configure(replay: CaptureReplay) {
        mode.withLock {
            $0 = .replay(replay)
        }
    }

    static func fixtureName(for url: URL) -> String? {
        let path = url.path()
        if path.hasPrefix("/g/2930572") {
            return "GalleryDetailAlt.html"
        }
        if path.hasPrefix("/g/") {
            return "GalleryDetail.html"
        }
        if path.hasPrefix("/s/") {
            return "GallerySinglePage.html"
        }
        // Home renders nothing until its popular section resolves, so the popular
        // list is served the same gallery-list markup as the front page.
        if path == "/" || path == "/popular" {
            return "FrontPageList.html"
        }
        return nil
    }

    private static let htmlMIMEType = "text/html; charset=utf-8"

    private func loadFixture(url: URL, fixtureDirectory: URL?) {
        guard let fixtureName = Self.fixtureName(for: url), let fixtureDirectory else {
            finish(statusCode: 404, data: Data(), url: url, mimeType: Self.htmlMIMEType)
            return
        }

        do {
            let data = try Data(contentsOf: fixtureDirectory.appending(path: fixtureName))
            finish(statusCode: 200, data: data, url: url, mimeType: Self.htmlMIMEType)
        } catch {
            finish(statusCode: 404, data: Data(), url: url, mimeType: Self.htmlMIMEType)
        }
    }

    private func finish(
        statusCode: Int,
        data: Data,
        url: URL,
        mimeType: String
    ) {
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": mimeType, "Content-Length": String(data.count)]
        ) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}
#endif
