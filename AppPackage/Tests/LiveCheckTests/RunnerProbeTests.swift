import AppModels
import Foundation
import Kanna
import NetworkingFeature
import ParserFeature
import XCTest

/// The one-off runner-IP probe (19-03; 19-CONTEXT D-25): three guest GETs, 5 s apart — the front page, Popular,
/// then the first Popular gallery — each on its own cookieless session. It records, per page, only the status,
/// whether Cloudflare challenged and whether the app's parser succeeded, into `probe.json`. It does not fail on a
/// block: the probe records, it does not judge.
///
/// The list pages are fetched with the app's URL builders and read by the app's list parser. Their request types
/// would also send the `gdata` title query, a POST, which the probe never sends (D-21); the gallery page uses
/// `GalleryDetailRequest`, a GET.
final class RunnerProbeTests: XCTestCase {
    func testProbe() async throws {
        try LiveCheckGate.requireOptIn()
        let output = try XCTUnwrap(LiveCheckGate.outputDirectory, "EHPANDA_LIVE_CHECK_OUTPUT is not set.")
        let frontPage = await Self.list(.frontPage, url: URLUtil.frontPageList(host: .ehentai, filter: Filter()))
        try await Task.sleep(for: .seconds(5))
        let popular = await Self.list(.popular, url: URLUtil.popularList(host: .ehentai, filter: Filter()))
        try await Task.sleep(for: .seconds(5))
        let gallery = await Self.gallery(popular.galleries.first)
        let report = ProbeReport(
            mode: LiveCheckGate.mode, date: .now, pages: [frontPage.page, popular.page, gallery]
        )
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try report.encoded().write(to: output.appending(path: "probe.json"))
    }

    private struct ListResult {
        let page: ProbePage
        let galleries: [Gallery]
    }

    private static func list(_ page: ProbePage.Name, url: URL) async -> ListResult {
        let observer = PageObserver()
        let session = observer.makeSession()
        defer { session.finishTasksAndInvalidate() }
        var galleries = [Gallery]()
        do {
            let (data, response) = try await session.data(for: URLRequest(url: url))
            if PageObservation(response: response).status.map({ (200..<300).contains($0) }) == true {
                galleries = try Parser.parseGalleries(doc: Kanna.HTML(html: data, encoding: .utf8))
            }
        } catch {
            galleries = []
        }
        let probePage = ProbePage(page, observation: observer.observation, parsed: !galleries.isEmpty)
        return ListResult(page: probePage, galleries: galleries)
    }

    private static func gallery(_ gallery: Gallery?) async -> ProbePage {
        guard let gallery, let galleryURL = gallery.galleryURL else {
            return ProbePage(.gallery, observation: .unreached, parsed: false)
        }
        let observer = PageObserver()
        let session = observer.makeSession()
        defer { session.finishTasksAndInvalidate() }
        let request = GalleryDetailRequest(gid: gallery.gid, galleryURL: galleryURL, urlSession: session)
        let parsed: Bool
        do {
            _ = try await request.response()
            parsed = true
        } catch {
            parsed = false
        }
        return ProbePage(.gallery, observation: observer.observation, parsed: parsed)
    }
}

/// `probe.json`: a fixed schema whose only page fields are the page's name, status, `cf-mitigated` presence and
/// parse result (19-CONTEXT D-22, D-25). Nothing from a response but its status and that one header's presence
/// can reach it.
struct ProbeReport: Encodable {
    let schema = 1
    let mode: String
    let date: Date
    let pages: [ProbePage]

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

struct ProbePage: Encodable, Equatable {
    enum Name: String, Encodable {
        case frontPage, popular, gallery
    }

    private enum CodingKeys: String, CodingKey {
        case page, status, cfMitigated, parsed
    }

    let page: Name
    let status: Int?
    let cfMitigated: Bool
    let parsed: Bool

    init(_ page: Name, observation: PageObservation, parsed: Bool) {
        self.page = page
        status = observation.status
        cfMitigated = observation.cfMitigated
        self.parsed = parsed
    }

    /// Writes every field, a missing status as `null`, so each page always has the same four keys.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(page, forKey: .page)
        try container.encode(status, forKey: .status)
        try container.encode(cfMitigated, forKey: .cfMitigated)
        try container.encode(parsed, forKey: .parsed)
    }
}
