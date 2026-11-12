@testable import AppComponents
import AppModels
import CookieClient
@testable import DetailFeature
import Foundation
import SwiftUI
import Testing
import UIKit
import WebKit

/// The comment moderation surfaces (UI-SPEC C-4 to C-8): the menu's items from one table, the collapsed row that cannot
/// name the blocked user, and the report sheet's private, pre-seeded web view (research §5.2, A-5; P-11).
@MainActor
struct BlockedCommentPresentationTests {
    // MARK: Menu items

    @Test(arguments: [CommentModerationSurface.list, .card])
    func aForeignCommentOffersReportThenBlock(surface: CommentModerationSurface) {
        let items = CommentModerationMenu.items(
            for: surface, blockStatus: .notBlocked, isRevealed: false, isOwn: false, hasReportTarget: true
        )

        #expect(items == [.report, .block])
    }

    @Test
    func aRevealedCommentInTheListOffersReportThenUnblock() {
        let items = CommentModerationMenu.items(
            for: .list, blockStatus: .blocked, isRevealed: true, isOwn: false, hasReportTarget: true
        )

        #expect(items == [.report, .unblock])
    }

    @Test
    func aRevealedCardAddsHideAsTheThirdItem() {
        let items = CommentModerationMenu.items(
            for: .card, blockStatus: .blocked, isRevealed: true, isOwn: false, hasReportTarget: true
        )

        #expect(items == [.report, .unblock, .hide])
    }

    @Test(arguments: [CommentModerationSurface.list, .card], [false, true])
    func theUsersOwnCommentOffersNothing(surface: CommentModerationSurface, isBlocked: Bool) {
        let items = CommentModerationMenu.items(
            for: surface, blockStatus: isBlocked ? .blocked : .notBlocked, isRevealed: true, isOwn: true,
            hasReportTarget: true
        )

        #expect(items.isEmpty)
    }

    @Test(arguments: [CommentModerationSurface.list, .card])
    func aCollapsedCommentOffersNothing(surface: CommentModerationSurface) {
        let items = CommentModerationMenu.items(
            for: surface, blockStatus: .blocked, isRevealed: false, isOwn: false, hasReportTarget: true
        )

        #expect(items.isEmpty)
    }

    /// Lead decision: with no report page there is nowhere for Report to go, so it is left out, Block kept.
    @Test
    func aGalleryWithNoReportPageOffersNoReport() {
        let foreign = CommentModerationMenu.items(
            for: .list, blockStatus: .notBlocked, isRevealed: false, isOwn: false, hasReportTarget: false
        )
        let revealedCard = CommentModerationMenu.items(
            for: .card, blockStatus: .blocked, isRevealed: true, isOwn: false, hasReportTarget: false
        )

        #expect(foreign == [.block])
        #expect(revealedCard == [.unblock, .hide])
    }

    /// Lead decision (owner msg 1918): a comment with no member ID has nothing stable to block by, so Block is left
    /// out, Report kept; it is never blocked, so no Unblock or Hide either.
    @Test(arguments: [CommentModerationSurface.list, .card])
    func aCommentWithNoMemberIDOffersNoBlock(surface: CommentModerationSurface) {
        let withReport = CommentModerationMenu.items(
            for: surface, blockStatus: .noMemberID, isRevealed: false, isOwn: false, hasReportTarget: true
        )
        let withoutReport = CommentModerationMenu.items(
            for: surface, blockStatus: .noMemberID, isRevealed: false, isOwn: false, hasReportTarget: false
        )

        #expect(withReport == [.report])
        #expect(withoutReport.isEmpty)
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

        let noMemberID = state.actions(
            for: Self.comment(author: "someone", memberID: nil), on: .list, didLogin: true, displayName: "reader",
            perform: { _ in }
        )
        #expect(noMemberID.items == [.report])
    }

    // MARK: Accessibility actions

    /// VoiceOver, Voice Control and Switch Control reach the menu through the element's named actions, after the link
    /// actions, with the visible menu strings (C-4); XCUITest cannot read custom actions, so they are read here.
    @Test
    func theListCellAndTheCardNameTheMenuItemsAsAccessibilityActions() {
        let comment = Self.comment(author: "someone")
        let actions = CommentModerationActions(
            items: [.report, .block], siteName: "E-Hentai", author: comment.author, perform: { _ in }
        )
        let revealed = CommentModerationActions(
            items: [.report, .unblock, .hide], siteName: "E-Hentai", author: comment.author, perform: { _ in }
        )

        let cell = AccessibilityTree.customActionNames(
            in: CommentsView.CommentCell(gid: "3103480", comment: comment, moderation: actions, linkAction: { _ in })
        )
        let card = AccessibilityTree.customActionNames(
            in: DetailView.CommentCell(comment: comment, backgroundColor: .gray, moderation: revealed)
        )
        let own = AccessibilityTree.customActionNames(
            in: CommentsView.CommentCell(gid: "3103480", comment: comment, linkAction: { _ in })
        )
        let linkedComment = Self.comment(author: "someone", text: "See https://example.com/a")
        let linked = AccessibilityTree.customActionNames(
            in: CommentsView.CommentCell(
                gid: "3103480", comment: linkedComment, moderation: actions, linkAction: { _ in }
            )
        )

        #expect(cell == ["Report on E-Hentai", "Block someone"])
        #expect(card == ["Report on E-Hentai", "Unblock someone", "Hide"])
        #expect(own.isEmpty)
        #expect(linked == ["Open link", "Report on E-Hentai", "Block someone"])
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

    private static func comment(
        author: String, memberID: String? = "990213", text: AttributedString = "Text"
    ) -> GalleryComment {
        GalleryComment(
            votedUp: false, votedDown: false, votable: true, editable: false,
            score: "+1", author: author, authorMemberID: memberID, contents: [.init(type: .plainText, text: text)],
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

/// Reads a SwiftUI view's accessibility tree as UIKit exposes it to assistive technologies.
@MainActor
private enum AccessibilityTree {
    /// SwiftUI builds its accessibility elements only while accessibility is on in the process, which a test process
    /// does not have unless it asks, as an assistive technology would.
    private static let enableAccessibility: Void = {
        guard let library = dlopen("/usr/lib/libAccessibility.dylib", RTLD_NOW),
              let symbol = dlsym(library, "_AXSApplicationAccessibilitySetEnabled")
        else { return }
        typealias SetEnabled = @convention(c) (Bool) -> Void
        unsafeBitCast(symbol, to: SetEnabled.self)(true)
    }()

    static func customActionNames(in view: some View) -> [String] {
        _ = enableAccessibility
        let controller = UIHostingController(rootView: view.environment(\.locale, Locale(identifier: "en_US")))
        guard let root = controller.view else { return [] }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 420, height: 900))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        root.frame = window.bounds
        root.layoutIfNeeded()
        RunLoop.main.run(until: .now.addingTimeInterval(0.2))
        return elements(under: root, depth: 0).flatMap { element in
            element.accessibilityCustomActions?.map(\.name) ?? []
        }
    }

    private static func elements(under object: NSObject, depth: Int) -> [NSObject] {
        guard depth < 40 else { return [object] }
        var children = (object.accessibilityElements ?? []).compactMap({ $0 as? NSObject })
        if children.isEmpty {
            let count = object.accessibilityElementCount()
            if count > 0, count != NSNotFound {
                children = (0..<count).compactMap({ object.accessibilityElement(at: $0) as? NSObject })
            }
        }
        if children.isEmpty, let view = object as? UIView {
            children = view.subviews
        }
        return [object] + children.flatMap({ elements(under: $0, depth: depth + 1) })
    }
}
