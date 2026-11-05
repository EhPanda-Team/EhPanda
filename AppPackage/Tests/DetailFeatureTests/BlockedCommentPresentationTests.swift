@testable import AppComponents
import CookieClient
@testable import DetailFeature
import Foundation
import Testing
import WebKit

/// The comment moderation surfaces (UI-SPEC C-4 to C-8): the report sheet's private, pre-seeded web view (research
/// §5.2, A-5; P-11).
@MainActor
struct BlockedCommentPresentationTests {
    // MARK: Report sheet

    @Test
    func theSheetOpensTheReportPageWithTheSessionForItsHostOnly() throws {
        let storage = HTTPCookieStorage.sharedCookieStorage(
            forGroupContainerIdentifier: "BlockedCommentPresentationTests-\(UUID().uuidString)"
        )
        let cookieClient = CookieClient.live(cookieStorage: storage)
        let ehentai = try #require(URL(string: "https://e-hentai.org/"))
        let exhentai = try #require(URL(string: "https://exhentai.org/"))
        cookieClient.setOrEditCookie(for: ehentai, key: "ipb_member_id", value: "member-fixture")
        cookieClient.setOrEditCookie(for: exhentai, key: "igneous", value: "igneous-fixture")
        let reportURL = try #require(URL(string: "https://e-hentai.org/g/3103480/0000000000/?report=select"))

        let input = ReportPageSheet.sessionInput(for: reportURL, cookieClient: cookieClient)

        #expect(input.url == reportURL)
        #expect(input.cookies.map(\.name) == cookieClient.sessionCookies(for: reportURL).map(\.name))
        #expect(input.cookies.map(\.name).contains("ipb_member_id"))
        #expect(!input.cookies.contains { $0.name == "igneous" })
        #expect(input.cookies.allSatisfy { $0.domain.hasSuffix("e-hentai.org") })
    }

    @Test
    func theWebViewWritesEveryCookieBeforeItLoads() async throws {
        let target = RecordingTarget()
        let url = try #require(URL(string: "https://e-hentai.org/g/3103480/0000000000/?report=select"))
        let cookies = try ["ipb_member_id", "ipb_pass_hash"].map(Self.cookie(named:))

        await SessionWebViewSeeding.seedThenLoad(cookies: cookies, url: url, loadsPage: true, into: target)

        #expect(target.calls == [.setCookie("ipb_member_id"), .setCookie("ipb_pass_hash"), .load(url)])
    }

    @Test
    func noSessionStillLoadsTheSignedOutPage() async throws {
        let target = RecordingTarget()
        let url = try #require(URL(string: "https://e-hentai.org/g/3103480/0000000000/?report=select"))

        await SessionWebViewSeeding.seedThenLoad(cookies: [], url: url, loadsPage: true, into: target)

        #expect(target.calls == [.load(url)])
    }

    @Test
    func aStubbedLaunchSeedsButNeverLoads() async throws {
        let target = RecordingTarget()
        let url = try #require(URL(string: "https://e-hentai.org/g/3103480/0000000000/?report=select"))

        await SessionWebViewSeeding.seedThenLoad(
            cookies: [try Self.cookie(named: "ipb_member_id")], url: url, loadsPage: false, into: target
        )

        #expect(target.calls == [.setCookie("ipb_member_id")])
    }

    @Test
    func theWebViewsStoreIsNotPersistent() {
        let configuration = SessionWebViewController.makeConfiguration()

        #expect(configuration.websiteDataStore.isPersistent == false)
        #expect(configuration.websiteDataStore !== WKWebsiteDataStore.default())
    }

    // MARK: Fixtures

    private static func cookie(named name: String) throws -> HTTPCookie {
        try #require(HTTPCookie(properties: [
            .name: name, .value: "fixture", .domain: ".e-hentai.org", .path: "/"
        ]))
    }
}

@MainActor
private final class RecordingTarget: SessionWebViewTarget {
    enum Call: Equatable {
        case setCookie(String)
        case load(URL)
    }

    private(set) var calls = [Call]()

    func setCookie(_ cookie: HTTPCookie) async {
        // A real store answers later; yielding here makes an unawaited write show up as a load ahead of it.
        await Task.yield()
        calls.append(.setCookie(cookie.name))
    }

    func load(_ request: URLRequest) {
        if let url = request.url {
            calls.append(.load(url))
        }
    }
}
