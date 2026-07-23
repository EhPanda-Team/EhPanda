#if DEBUG
import Foundation
import Synchronization

final class UITestStubURLProtocol: URLProtocol {
    private static let fixtureDirectory = Mutex<URL?>(nil)

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
            finish(statusCode: 404, data: Data(), url: URL(filePath: "/"))
            return
        }
        guard
            let fixtureName = Self.fixtureName(for: url),
            let fixtureDirectory = Self.fixtureDirectory.withLock({ $0 })
        else {
            finish(statusCode: 404, data: Data(), url: url)
            return
        }

        do {
            let data = try Data(contentsOf: fixtureDirectory.appending(path: fixtureName))
            finish(statusCode: 200, data: data, url: url)
        } catch {
            finish(statusCode: 404, data: Data(), url: url)
        }
    }

    override func stopLoading() {}

    static func configure(fixtureDirectory: URL?) {
        Self.fixtureDirectory.withLock {
            $0 = fixtureDirectory
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

    private func finish(
        statusCode: Int,
        data: Data,
        url: URL
    ) {
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "text/html; charset=utf-8"]
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
