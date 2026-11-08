import AppModels
import Foundation
import Synchronization
import XCTest

/// The check's vocabulary, results schema, GET-only allowlist and classification, offline (19-14). Saved pages are
/// served by `SavedPageProtocol` inside each page's session, so no test reaches a host, and none needs the opt-in.
final class LiveCheckOfflineTests: XCTestCase {
    override func tearDown() {
        SavedPageProtocol.reset()
        super.tearDown()
    }

    // MARK: Vocabulary and schema

    func testEveryGuestPageHasOneReaderAndSignedInPagesAreSkipped() {
        let guests = LiveCheckPage.allCases.filter({ !$0.needsSignIn })
        XCTAssertEqual(LiveCheckPage.allCases.filter(\.needsSignIn), [.watched, .favorites, .exhentai])
        XCTAssertEqual(guests.count, 9)
        for page in guests {
            XCTAssertNotNil(page.reader, page.rawValue)
            XCTAssertNotNil(page.primaryExpectation, page.rawValue)
        }
    }

    func testAllowlistNamesOnlyGetRequestTypes() {
        let allowed: Set = [
            "GalleryDetailRequest", "ThumbnailURLsRequest", "GalleryNormalImageURLsRequest", "DataRequest",
            "TagTranslatorRequest", "ReportFormRequest"
        ]
        let named = Set(LiveCheckReader.allCases.flatMap(\.requestTypes))
        XCTAssertEqual(named, allowed)
    }

    func testExpectationsHaveFixedIDsAndSentences() {
        let cases = LiveCheckExpectation.allCases
        XCTAssertEqual(Set(cases.map(\.rawValue)).count, cases.count)
        XCTAssertEqual(Set(cases.map(\.sentence)).count, cases.count)
        XCTAssertEqual(LiveCheckExpectation.toplistsRows.rawValue, "toplists.rows")
        XCTAssertEqual(
            LiveCheckExpectation.toplistsRows.sentence, "expected a gallery table with at least one row, found none"
        )
        let pages = Set(LiveCheckPage.allCases.map(\.rawValue) + ["dependency"])
        for expectation in cases {
            let parts = expectation.rawValue.split(separator: ".")
            XCTAssertEqual(parts.count, 2, expectation.rawValue)
            XCTAssertTrue(pages.contains(String(parts.first ?? "")), expectation.rawValue)
            XCTAssertTrue(expectation.sentence.hasPrefix("expected "), expectation.rawValue)
        }
    }

    func testResultsCarryOnlyTheFourPageFields() throws {
        let results = LiveCheckResults(date: Date(timeIntervalSince1970: 1_735_689_600), mode: .local, pages: [
            LiveCheckPageResult(page: .toplists, status: 200, classification: .parser, expectation: .toplistsRows),
            LiveCheckPageResult(page: .gallery, status: nil, classification: .unreachable),
            LiveCheckPageResult(page: .watched, status: nil, classification: .skipped)
        ])
        let data = try results.encoded()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["schema", "date", "mode", "pages"])
        XCTAssertEqual(object["schema"] as? Int, 1)
        let pages = try XCTUnwrap(object["pages"] as? [[String: Any]])
        let fields: Set = ["page", "status", "classification", "expectation"]
        XCTAssertEqual(pages.map({ Set($0.keys) }), [fields, fields, fields])
        XCTAssertTrue(pages.last?["expectation"] is NSNull)
        XCTAssertEqual(try LiveCheckResults.decoded(from: data), results)
    }

    // MARK: Classification

    func testGoodToplistsPageIsOk() async throws {
        try SavedPageProtocol.serve(status: 200, fixture: "toplists")
        let read = await runner().list(.toplists, url: Self.toplistsURL)
        XCTAssertEqual(read.result, LiveCheckPageResult(page: .toplists, status: 200, classification: .okay))
        XCTAssertEqual(read.value?.count, 2)
    }

    func testToplistsWithoutItsTableIsAParserBreak() async throws {
        try SavedPageProtocol.serve(status: 200, fixture: "toplists-changed")
        let read = await runner().list(.toplists, url: Self.toplistsURL)
        XCTAssertEqual(read.result, LiveCheckPageResult(
            page: .toplists, status: 200, classification: .parser, expectation: .toplistsRows
        ))
    }

    func testCloudflareChallengeIsUnreachable() async throws {
        try SavedPageProtocol.serve(status: 403, fixture: "challenge", headers: ["cf-mitigated": "challenge"])
        let read = await runner().list(.toplists, url: Self.toplistsURL)
        XCTAssertEqual(read.result, LiveCheckPageResult(page: .toplists, status: 403, classification: .unreachable))
    }

    func testIPBanPageIsUnreachable() async throws {
        try SavedPageProtocol.serve(status: 200, fixture: "ip-banned")
        let read = await runner().list(.toplists, url: Self.toplistsURL)
        XCTAssertEqual(read.result, LiveCheckPageResult(page: .toplists, status: 200, classification: .unreachable))
    }

    func testServerErrorIsUnreachable() async throws {
        try SavedPageProtocol.serve(status: 503, fixture: "toplists")
        let read = await runner().list(.toplists, url: Self.toplistsURL)
        XCTAssertEqual(read.result, LiveCheckPageResult(page: .toplists, status: 503, classification: .unreachable))
    }

    func testGalleryFollowsToplistsWhenToplistsFails() async throws {
        try SavedPageProtocol.serve(status: 503, fixture: "toplists")
        var gallery = await runner().run(mode: .local).pages.first(where: { $0.page == .gallery })
        XCTAssertEqual(gallery, LiveCheckPageResult(page: .gallery, status: nil, classification: .unreachable))
        try SavedPageProtocol.serve(status: 200, fixture: "toplists-changed")
        gallery = await runner().run(mode: .local).pages.first(where: { $0.page == .gallery })
        XCTAssertEqual(gallery, LiveCheckPageResult(
            page: .gallery, status: nil, classification: .parser, expectation: .earlierPage
        ))
    }

    func testRunSendsOnlyGetAndReportsEveryPageOnce() async throws {
        try SavedPageProtocol.serve(status: 200, fixture: "toplists")
        let refused = GetOnlyURLProtocol.refused
        let results = await runner().run(mode: .hosted)
        XCTAssertEqual(GetOnlyURLProtocol.refused, refused)
        XCTAssertEqual(results.mode, .hosted)
        XCTAssertEqual(results.pages.map(\.page), LiveCheckPage.allCases)
        XCTAssertNotEqual(results.pages.first(where: { $0.page == .gallery })?.classification, .okay)
        let methods = SavedPageProtocol.methods
        XCTAssertGreaterThan(methods.count, 5)
        XCTAssertEqual(Set(methods), ["GET"])
    }

    // MARK: Support

    private static let toplistsURL = URLUtil.toplistsList(host: .ehentai, catIndex: 15)

    private func runner() -> LiveCheckRunner {
        LiveCheckRunner(pause: .zero, protocolClasses: [SavedPageProtocol.self])
    }
}

/// Serves one saved page, with a fixed status and headers, for every request of a live check session, and records
/// each request's method. Only the tests above install it.
final class SavedPageProtocol: URLProtocol {
    private struct Page {
        let status: Int
        let body: Data
        let headers: [String: String]
    }

    private static let state = Mutex<(page: Page?, methods: [String])>((nil, []))

    static func serve(status: Int, fixture: String, headers: [String: String] = [:]) throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: fixture, withExtension: "html", subdirectory: "Fixtures")
        )
        let page = Page(status: status, body: try Data(contentsOf: url), headers: headers)
        state.withLock({ $0 = (page, []) })
    }

    static func reset() {
        state.withLock({ $0 = (nil, []) })
    }

    static var methods: [String] {
        state.withLock({ $0.methods })
    }

    override static func canInit(with request: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let page = Self.state.withLock { state in
            state.methods.append(request.httpMethod ?? "GET")
            return state.page
        }
        guard let page, let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: page.status, httpVersion: "HTTP/1.1",
                                             headerFields: page.headers)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: page.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
