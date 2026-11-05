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
    private let answeredRequests = Mutex(Set<String>())
    private let unknownRequests = Mutex([String]())

    init(responses: [String: Response]) {
        self.responses = responses
    }

    /// The listed URLs this replay has answered.
    var answeredURLs: Set<String> {
        answeredRequests.withLock({ $0 })
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
        answeredRequests.withLock({ _ = $0.insert(url) })
        return response
    }
}

/// Answers every HTTP(S) request of a UI-test or capture launch, so none reaches the network.
///
/// The UI tests' hermetic fixture directory maps request paths to a few saved pages by prefix, and
/// answers the `gdata` metadata API from a saved response; a capture launch installs its
/// ``CaptureReplay`` instead, and every request it cannot answer fails. A stubbed launch can also name
/// a request log (`EHPANDA_UITEST_REQUEST_LOG`), which gets one `METHOD host path` line for each
/// request the protocol sees, so a UI test can prove which requests a screen made.
final class UITestStubURLProtocol: URLProtocol {
    private enum Mode {
        case fixtureDirectory(URL?)
        case replay(CaptureReplay)
    }

    private static let mode = Mutex(Mode.fixtureDirectory(nil))
    /// The request log's file. Each line is written while the lock is held, so lines never interleave.
    private static let requestLog = Mutex<URL?>(nil)

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
        Self.logRequest(request)
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

    /// Names the file each request is appended to; `nil` logs nothing.
    static func configure(requestLog url: URL?) {
        requestLog.withLock {
            $0 = url
        }
    }

    /// Appends `METHOD host path` for `request` to the request log, if one is named. The path carries no
    /// query. A failed write is ignored: the log never changes how a request is answered.
    private static func logRequest(_ request: URLRequest) {
        requestLog.withLock { url in
            guard let url else { return }
            let line = "\(request.httpMethod ?? "GET") \(request.url?.host() ?? "") \(request.url?.path() ?? "")\n"
            do {
                try append(line, to: url)
            } catch {
                // The test reading the log finds the line missing; the app under test carries on.
            }
        }
    }

    private static func append(_ line: String, to url: URL) throws {
        let path = url.path(percentEncoded: false)
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer {
            do {
                try handle.close()
            } catch {
                // Closing after a completed write loses nothing the log needs.
            }
        }
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(line.utf8))
    }

    static func fixtureName(for url: URL) -> String? {
        let path = url.path()
        if path == "/archiver.php" {
            return "GalleryArchive.html"
        }
        if path == "/favorites.php" {
            let hasNextPage = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.contains(where: { $0.name == "next" }) == true
            return hasNextPage ? "LibraryGalleriesNext.html" : "LibraryGalleries.html"
        }
        if path.hasPrefix("/g/2930572") {
            return "GalleryDetailAlt.html"
        }
        if path.hasPrefix("/g/") {
            return "GalleryDetail.html"
        }
        if path.hasPrefix("/s/") {
            return "GallerySinglePage.html"
        }
        // All three routes use the same gallery-list parser. Serve populated Home rankings too,
        // so layout and navigation tests exercise gallery rows rather than loading placeholders.
        if path == "/" || path == "/popular" || path == "/toplist.php" {
            return "FrontPageList.html"
        }
        return nil
    }

    private static let htmlMIMEType = "text/html; charset=utf-8"

    private func loadFixture(url: URL, fixtureDirectory: URL?) {
        if url.host() == "fixtures.ehpanda.invalid", url.path() == "/library-cover.png", let fixtureDirectory {
            do {
                let data = try Data(contentsOf: fixtureDirectory.appending(path: "LibraryCover.png"))
                finish(statusCode: 200, data: data, url: url, mimeType: "image/png")
            } catch {
                client?.urlProtocol(self, didFailWithError: error)
            }
            return
        }
        if url.path() == "/api.php" {
            loadGalleryMetadata(url: url, fixtureDirectory: fixtureDirectory)
            return
        }
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

    /// Answers a `gdata` metadata request from the fixture directory's saved API response. Any
    /// other `api.php` method has no fixture and gets 404, as before.
    private func loadGalleryMetadata(url: URL, fixtureDirectory: URL?) {
        do {
            guard let fixtureDirectory, let body = Self.body(of: request),
                  let data = try Self.galleryMetadataResponse(
                    requestBody: body,
                    fixture: Data(contentsOf: fixtureDirectory.appending(path: Self.galleryMetadataFixtureName))
                  )
            else {
                finish(statusCode: 404, data: Data(), url: url, mimeType: Self.htmlMIMEType)
                return
            }
            finish(statusCode: 200, data: data, url: url, mimeType: "application/json")
        } catch {
            finish(statusCode: 404, data: Data(), url: url, mimeType: Self.htmlMIMEType)
        }
    }

    static let galleryMetadataFixtureName = "GalleryMetadata.json"

    /// The site's answer to a `gdata` request body, built from a saved `gmetadata` response: each
    /// requested pair in request order, with the API's error entry for a gid the fixture lacks or a
    /// token that doesn't match. `nil` when the body isn't a `gdata` request; throws when either
    /// body isn't JSON.
    static func galleryMetadataResponse(requestBody: Data, fixture: Data) throws -> Data? {
        guard let request = try JSONSerialization.jsonObject(with: requestBody) as? [String: Any],
              request["method"] as? String == "gdata",
              let pairs = request["gidlist"] as? [[Any]],
              let saved = try JSONSerialization.jsonObject(with: fixture) as? [String: Any],
              let entries = saved["gmetadata"] as? [[String: Any]]
        else { return nil }
        let entriesByGID = Dictionary(
            entries.compactMap { entry in (entry["gid"] as? Int).map({ ($0, entry) }) },
            uniquingKeysWith: { first, _ in first }
        )
        var metadata = [[String: Any]]()
        for pair in pairs {
            guard let gid = pair.first as? Int else { return nil }
            if let entry = entriesByGID[gid], entry["token"] as? String == pair.dropFirst().first as? String {
                metadata.append(entry)
            } else {
                metadata.append(["gid": gid, "error": "Key missing, or incorrect key provided."])
            }
        }
        return try JSONSerialization.data(withJSONObject: ["gmetadata": metadata], options: [.sortedKeys])
    }

    /// A URL session hands a protocol its POST body as a stream rather than as `httpBody`.
    private static func body(of request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else {
                break
            }
            data.append(contentsOf: buffer.prefix(count))
        }
        return data
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
