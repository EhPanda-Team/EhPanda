import Foundation
import XCTest

/// The probe's privacy and safety rules, offline (19-03; T-19-05). Like every test in this target they run only
/// with the opt-in, and they reach no host.
final class ProbeReportTests: XCTestCase {
    override func setUp() async throws {
        try LiveCheckGate.requireOptIn()
    }

    func testObservationKeepsOnlyStatusAndChallengeHeader() throws {
        let response = try XCTUnwrap(HTTPURLResponse(
            url: URL(string: "https://e-hentai.org/g/1234567/0a1b2c3d4e/")!, statusCode: 403, httpVersion: nil,
            headerFields: ["cf-mitigated": "challenge", "X-Title": "A Title-Like String", "Set-Cookie": "ipb=1"]
        ))
        XCTAssertEqual(PageObservation(response: response), PageObservation(status: 403, cfMitigated: true))
        let reached = HTTPURLResponse(
            url: try XCTUnwrap(response.url), statusCode: 200, httpVersion: nil, headerFields: ["server": "cloudflare"]
        )
        XCTAssertEqual(PageObservation(response: reached), PageObservation(status: 200, cfMitigated: false))
        XCTAssertEqual(PageObservation(response: nil), .unreached)
    }

    func testReportCarriesNoResponseContent() throws {
        let response = HTTPURLResponse(
            url: URL(string: "https://e-hentai.org/g/1234567/0a1b2c3d4e/")!, statusCode: 200, httpVersion: nil,
            headerFields: ["X-Title": "A Title-Like String", "Location": "https://e-hentai.org/g/7654321/ffff/"]
        )
        let page = ProbePage(.gallery, observation: PageObservation(response: response), parsed: true)
        let unreached = ProbePage(.popular, observation: .unreached, parsed: false)
        let data = try ProbeReport(mode: "local", date: .now, pages: [page, unreached]).encoded()
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        for content in ["Title-Like", "1234567", "0a1b2c3d4e", "7654321", "e-hentai.org", "http"] {
            XCTAssertFalse(text.contains(content), "The report carries response content.")
        }
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["schema", "mode", "date", "pages"])
        let pages = try XCTUnwrap(object["pages"] as? [[String: Any]])
        let fields: Set<String> = ["page", "status", "cfMitigated", "parsed"]
        XCTAssertEqual(pages.map({ Set($0.keys) }), [fields, fields])
        XCTAssertTrue(pages.last?["status"] is NSNull)
    }

    func testSessionRefusesAnythingButGet() async throws {
        let observer = PageObserver()
        let session = observer.makeSession()
        defer { session.invalidateAndCancel() }
        var request = URLRequest(url: URL(string: "https://example.invalid/api.php")!)
        request.httpMethod = "POST"
        do {
            _ = try await session.data(for: request)
            XCTFail("A POST left a live check session.")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .unsupportedURL)
        }
        XCTAssertFalse(GetOnlyURLProtocol.canInit(with: URLRequest(url: URL(string: "https://example.invalid/")!)))
    }

    func testSessionKeepsNoCookiesOrCache() {
        let configuration = PageObserver().makeSession().configuration
        XCTAssertNil(configuration.httpCookieStorage)
        XCTAssertFalse(configuration.httpShouldSetCookies)
        XCTAssertNil(configuration.urlCache)
    }
}
