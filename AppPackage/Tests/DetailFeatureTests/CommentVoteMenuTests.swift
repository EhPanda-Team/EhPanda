import AppModels
@testable import DetailFeature
import Foundation
import SFSafeSymbols
import Testing

/// The vote row of a comment's menu (UI-SPEC C-6): two slots, always both there, each enabled or not by the comment's
/// vote and whether the user can vote at all.
struct CommentVoteMenuTests {
    @Test
    func noVoteOffersBothDirections() {
        let state = voteMenuState(for: Self.comment(), didLogin: true)

        #expect(state.upSlot == .init(direction: .upVote, isWithdraw: false, isEnabled: true))
        #expect(state.downSlot == .init(direction: .downVote, isWithdraw: false, isEnabled: true))
    }

    @Test
    func votedUpWithdrawsInTheUpSlotAndDisablesDown() {
        let state = voteMenuState(for: Self.comment(votedUp: true), didLogin: true)

        #expect(state.upSlot == .init(direction: .upVote, isWithdraw: true, isEnabled: true))
        #expect(state.downSlot == .init(direction: .downVote, isWithdraw: false, isEnabled: false))
    }

    @Test
    func votedDownWithdrawsInTheDownSlotAndDisablesUp() {
        let state = voteMenuState(for: Self.comment(votedDown: true), didLogin: true)

        #expect(state.upSlot == .init(direction: .upVote, isWithdraw: false, isEnabled: false))
        #expect(state.downSlot == .init(direction: .downVote, isWithdraw: true, isEnabled: true))
    }

    @Test(arguments: [(false, false), (true, false), (false, true)])
    func signedOutDisablesBothWhateverTheVote(votedUp: Bool, votedDown: Bool) {
        let state = voteMenuState(for: Self.comment(votedUp: votedUp, votedDown: votedDown), didLogin: false)

        #expect(state.slots.map(\.isEnabled) == [false, false])
        // The slots stay, in their places.
        #expect(state.slots.map(\.direction) == [.upVote, .downVote])
    }

    @Test(arguments: [(false, false), (true, false), (false, true)])
    func aCommentTheSiteOffersNoVoteOnDisablesBoth(votedUp: Bool, votedDown: Bool) {
        let comment = Self.comment(votedUp: votedUp, votedDown: votedDown, votable: false)
        let state = voteMenuState(for: comment, didLogin: true)

        #expect(state.slots.map(\.isEnabled) == [false, false])
        #expect(state.slots.map(\.direction) == [.upVote, .downVote])
    }

    @Test
    func theUsersOwnCommentIsNeverVotable() {
        // Whatever the page says of it, an editable comment is the user's own.
        let state = voteMenuState(for: Self.comment(votable: true, editable: true), didLogin: true)

        #expect(state.slots.map(\.isEnabled) == [false, false])
    }

    // The owner's rule: cancelling a vote shows the slashed outline thumb, never the filled one, for comments and tags.
    @Test
    func aWithdrawShowsTheSlashedOutlineThumbOfTheVoteItUndoes() {
        #expect(CommentVoteSlot.withdrawSymbol(isVotedUp: true).rawValue == "hand.thumbsup.slash")
        #expect(CommentVoteSlot.withdrawSymbol(isVotedUp: false).rawValue == "hand.thumbsdown.slash")

        let votedUp = voteMenuState(for: Self.comment(votedUp: true), didLogin: true)
        let votedDown = voteMenuState(for: Self.comment(votedDown: true), didLogin: true)
        #expect(votedUp.upSlot.symbol.rawValue == "hand.thumbsup.slash")
        #expect(votedDown.downSlot.symbol.rawValue == "hand.thumbsdown.slash")
    }

    @Test
    func aVoteStillToCastShowsThePlainThumb() {
        let state = voteMenuState(for: Self.comment(), didLogin: true)

        #expect(state.upSlot.symbol.rawValue == "hand.thumbsup")
        #expect(state.downSlot.symbol.rawValue == "hand.thumbsdown")
    }

    @Test
    func theDirectionsSendTheirSigns() {
        #expect(CommentVoteDirection.upVote.value == 1)
        #expect(CommentVoteDirection.downVote.value == -1)
    }

    @Test
    func theUsersOwnCommentKeepsTheVoteRowAsItsWholeMenu() {
        let comment = Self.comment(votable: false, editable: true)
        let actions = CommentModerationActions.none
        #expect(actions.isEmpty)

        let voting = actions.voting(on: comment, didLogin: true) { _ in }

        #expect(voting.isEmpty == false)
        #expect(voting.items.isEmpty)
        #expect(voting.vote?.slots.map(\.isEnabled) == [false, false])
    }

    @Test
    func aChosenVoteGoesToTheVoteAction() {
        var chosen = [CommentVoteDirection]()
        let actions = CommentModerationActions.none
            .voting(on: Self.comment(), didLogin: true) { chosen.append($0) }

        actions.performVote(.upVote)
        actions.performVote(.downVote)

        #expect(chosen == [.upVote, .downVote])
    }

    private static func comment(
        votedUp: Bool = false, votedDown: Bool = false, votable: Bool = true, editable: Bool = false
    ) -> GalleryComment {
        GalleryComment(
            votedUp: votedUp, votedDown: votedDown, votable: votable, editable: editable,
            score: "+1", author: "someone", contents: [], commentID: "1",
            commentDate: Date(timeIntervalSince1970: 0)
        )
    }
}
