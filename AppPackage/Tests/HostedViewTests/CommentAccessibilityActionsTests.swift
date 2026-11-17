import AppModels
@testable import DetailFeature
import Foundation
import SwiftUI
import Testing

/// The comment moderation menu as accessibility actions (UI-SPEC C-4), read from the accessibility tree a hosted
/// comment cell builds. The menu's item table and the other moderation surfaces are covered without a window in
/// `BlockedCommentPresentationTests`.
@MainActor
struct CommentAccessibilityActionsTests {
    /// VoiceOver, Voice Control and Switch Control reach the menu through the element's named actions, after the link
    /// actions, with the visible menu strings (C-4); XCUITest cannot read custom actions, so they are read here.
    @Test
    func theListCellAndTheCardNameTheMenuItemsAsAccessibilityActions() throws {
        let comment = Self.comment(author: "someone")
        let actions = CommentModerationActions(
            items: [.report, .block], siteName: "E-Hentai", author: comment.author, perform: { _ in }
        )
        let revealed = CommentModerationActions(
            items: [.report, .unblock, .hide], siteName: "E-Hentai", author: comment.author, perform: { _ in }
        )

        let cell = try Self.customActionNames(
            in: CommentsView.CommentCell(gid: "3103480", comment: comment, moderation: actions, linkAction: { _ in })
        )
        let card = try Self.customActionNames(
            in: DetailView.CommentCell(comment: comment, backgroundColor: .gray, moderation: revealed)
        )
        let own = try Self.customActionNames(
            in: CommentsView.CommentCell(gid: "3103480", comment: comment, linkAction: { _ in })
        )
        let linkedComment = Self.comment(author: "someone", text: "See https://example.com/a")
        let linked = try Self.customActionNames(
            in: CommentsView.CommentCell(
                gid: "3103480", comment: linkedComment, moderation: actions, linkAction: { _ in }
            )
        )

        #expect(cell == ["Report on E-Hentai", "Block someone"])
        #expect(card == ["Report on E-Hentai", "Unblock someone", "Hide"])
        #expect(own.isEmpty)
        #expect(linked == ["Open link", "Report on E-Hentai", "Block someone"])
    }

    /// The names of the custom actions of every accessibility element `view` builds, in the tree's order.
    private static func customActionNames(in view: some View) throws -> [String] {
        let content = view.environment(\.locale, Locale(identifier: "en_US"))
        return try AccessibilityElements.read(of: content, size: CGSize(width: 420, height: 900)) { elements in
            elements.flatMap({ $0.accessibilityCustomActions?.map(\.name) ?? [] })
        }
    }

    private static func comment(author: String, text: AttributedString = "Text") -> GalleryComment {
        GalleryComment(
            votedUp: false, votedDown: false, votable: true, editable: false,
            score: "+1", author: author, authorMemberID: "990213", contents: [.init(type: .plainText, text: text)],
            commentID: "comment-\(author)", commentDate: Date(timeIntervalSince1970: 0)
        )
    }
}
