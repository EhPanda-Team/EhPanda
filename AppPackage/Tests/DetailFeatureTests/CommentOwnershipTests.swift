import AppModels
@testable import DetailFeature
import Foundation
import Testing

/// The own-comment rule (research §5.6 b, A-10): a comment is the user's own when the site marks it editable, or when
/// the user is signed in under the name the comment was posted by. Own comments get no Report or Block action.
struct CommentOwnershipTests {
    @Test(arguments: [true, false])
    func anEditableCommentIsOwnSignedInOrOut(didLogin: Bool) {
        let comment = Self.comment(author: "someone", editable: true)

        #expect(CommentOwnership.isOwn(comment, didLogin: didLogin, displayName: nil))
        #expect(CommentOwnership.isOwn(comment, didLogin: didLogin, displayName: "another"))
    }

    @Test
    func aCommentPostedUnderTheSignedInNameIsOwn() {
        let comment = Self.comment(author: "reader", editable: false)

        #expect(CommentOwnership.isOwn(comment, didLogin: true, displayName: "reader"))
    }

    @Test
    func aCommentPostedUnderAnotherNameIsNotOwn() {
        let comment = Self.comment(author: "reader", editable: false)

        #expect(CommentOwnership.isOwn(comment, didLogin: true, displayName: "another") == false)
    }

    @Test
    func theSameNameSignedOutIsNotOwn() {
        let comment = Self.comment(author: "reader", editable: false)

        #expect(CommentOwnership.isOwn(comment, didLogin: false, displayName: "reader") == false)
    }

    @Test
    func noDisplayNameIsNotOwn() {
        let comment = Self.comment(author: "reader", editable: false)

        #expect(CommentOwnership.isOwn(comment, didLogin: true, displayName: nil) == false)
    }

    @Test(arguments: ["Reader", "reader ", ""])
    func theNameMustMatchExactly(displayName: String) {
        let comment = Self.comment(author: "reader", editable: false)

        #expect(CommentOwnership.isOwn(comment, didLogin: true, displayName: displayName) == false)
    }

    @Test
    func anEmptyNameNeverMatchesAnEmptyAuthor() {
        let comment = Self.comment(author: "", editable: false)

        #expect(CommentOwnership.isOwn(comment, didLogin: true, displayName: "") == false)
    }

    private static func comment(author: String, editable: Bool) -> GalleryComment {
        GalleryComment(
            votedUp: false,
            votedDown: false,
            votable: !editable,
            editable: editable,
            author: author,
            contents: [],
            commentID: "1",
            commentDate: Date(timeIntervalSince1970: 0)
        )
    }
}
