@testable import AppComponents
import AppModels
import CookieClient
@testable import DetailFeature
import Foundation
import SwiftUI
import Testing
import WebKit

/// The comment moderation surfaces (UI-SPEC C-4 to C-8): the menu's items from one table, the collapsed row that cannot
/// name the blocked user, and the report sheet's private, pre-seeded web view (research §5.2, A-5; P-11).
@MainActor
struct BlockedCommentPresentationTests {
    // MARK: Menu items

    @Test(arguments: [CommentModerationSurface.list, .card])
    func aForeignCommentOffersReportThenBlock(surface: CommentModerationSurface) {
        let items = CommentModerationMenu.items(
            for: surface, isBlocked: false, isRevealed: false, isOwn: false, hasReportTarget: true
        )

        #expect(items == [.report, .block])
    }

    @Test
    func aRevealedCommentInTheListOffersReportThenUnblock() {
        let items = CommentModerationMenu.items(
            for: .list, isBlocked: true, isRevealed: true, isOwn: false, hasReportTarget: true
        )

        #expect(items == [.report, .unblock])
    }

    @Test
    func aRevealedCardAddsHideAsTheThirdItem() {
        let items = CommentModerationMenu.items(
            for: .card, isBlocked: true, isRevealed: true, isOwn: false, hasReportTarget: true
        )

        #expect(items == [.report, .unblock, .hide])
    }

    @Test(arguments: [CommentModerationSurface.list, .card], [false, true])
    func theUsersOwnCommentOffersNothing(surface: CommentModerationSurface, isBlocked: Bool) {
        let items = CommentModerationMenu.items(
            for: surface, isBlocked: isBlocked, isRevealed: true, isOwn: true, hasReportTarget: true
        )

        #expect(items.isEmpty)
    }

    @Test(arguments: [CommentModerationSurface.list, .card])
    func aCollapsedCommentOffersNothing(surface: CommentModerationSurface) {
        let items = CommentModerationMenu.items(
            for: surface, isBlocked: true, isRevealed: false, isOwn: false, hasReportTarget: true
        )

        #expect(items.isEmpty)
    }

    /// Lead decision: with no report page there is nowhere for Report to go, so it is left out, Block kept.
    @Test
    func aGalleryWithNoReportPageOffersNoReport() {
        let foreign = CommentModerationMenu.items(
            for: .list, isBlocked: false, isRevealed: false, isOwn: false, hasReportTarget: false
        )
        let revealedCard = CommentModerationMenu.items(
            for: .card, isBlocked: true, isRevealed: true, isOwn: false, hasReportTarget: false
        )

        #expect(foreign == [.block])
        #expect(revealedCard == [.unblock, .hide])
    }

    @Test
    func theStateDerivesTheItemsAndTheSiteFromTheGallery() throws {
        let galleryURL = try #require(URL(string: "https://e-hentai.org/g/3103480/0000000000/"))
        let state = CommentModerationFeature.State(galleryURL: galleryURL)

        let actions = state.actions(
            for: Self.comment(author: "someone"), on: .list, didLogin: true, displayName: "reader", perform: { _ in }
        )
        let own = state.actions(
            for: Self.comment(author: "reader"), on: .list, didLogin: true, displayName: "reader", perform: { _ in }
        )
        let noGallery = CommentModerationFeature.State(galleryURL: nil).actions(
            for: Self.comment(author: "someone"), on: .list, didLogin: false, displayName: nil, perform: { _ in }
        )

        #expect(actions.items == [.report, .block])
        #expect(actions.siteName == "E-Hentai")
        #expect(actions.author == "someone")
        #expect(own.items.isEmpty)
        #expect(noGallery.items == [.block])
    }

    // MARK: Collapsed row

    /// The row is built from the comment's ID and its two actions only, so no author or text can reach it (D-13).
    @Test
    func theCollapsedRowHoldsNoAuthorOrText() {
        let row = BlockedCommentRow(commentID: "6894060", showAction: {}, unblockAction: {})
        let card = BlockedCommentCard(
            commentID: "6894060", backgroundColor: .gray, showAction: {}, unblockAction: {}
        )

        let rowFields = Mirror(reflecting: row).children.compactMap(\.label)
        let cardFields = Mirror(reflecting: card).children.compactMap(\.label).filter { !$0.hasPrefix("_") }

        #expect(rowFields == ["commentID", "showAction", "unblockAction"])
        #expect(cardFields == ["commentID", "backgroundColor", "showAction", "unblockAction"])
    }

    @Test
    func theCollapsedLabelIsTheCatalogString() {
        let label = BlockedCommentLabel.text

        #expect(label.key == "comment.blocked_row")
        var english = label
        english.locale = Locale(identifier: "en")
        #expect(String(localized: english) == "Comment from a user you've blocked")
    }

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

    private static func comment(author: String) -> GalleryComment {
        GalleryComment(
            votedUp: false, votedDown: false, votable: true, editable: false,
            score: "+1", author: author, contents: [.init(type: .plainText, text: "Text")],
            commentID: "comment-\(author)", commentDate: Date(timeIntervalSince1970: 0)
        )
    }

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
