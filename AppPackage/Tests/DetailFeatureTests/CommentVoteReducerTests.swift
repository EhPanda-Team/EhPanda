import AnalyticsClient
import AppComponents
import AppModels
import ComposableArchitecture
@testable import DetailFeature
import Foundation
import HapticsClient
import NetworkingFeature
import Testing

// A vote's answer updates the comment: the site's `comment_vote` returns the new score and the user's vote, and both
// screens show them at once. Before, the answer was discarded and the comments screen kept the copy it was pushed with,
// so nothing changed.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are main-actor-isolated.
@Suite
struct CommentVoteReducerTests {
    // MARK: Comments screen

    @MainActor
    @Test
    func aVoteUpUpdatesTheScoreAndTheVoteFromTheResponse() async {
        let store = makeCommentsStore(comments: [Self.comment(id: "7", score: "+4")])

        await store.send(.voteCommentDone(
            commentID: "7", result: .success(.init(commentID: 7, score: 5, vote: 1))
        )) {
            $0.comments = [Self.comment(id: "7", score: "+5", votedUp: true)]
        }
        await receiveVoted(store)
    }

    @MainActor
    @Test
    func aVoteDownUpdatesTheScoreAndTheVoteFromTheResponse() async {
        let store = makeCommentsStore(comments: [Self.comment(id: "7", score: "+4")])

        await store.send(.voteCommentDone(
            commentID: "7", result: .success(.init(commentID: 7, score: 3, vote: -1))
        )) {
            $0.comments = [Self.comment(id: "7", score: "+3", votedDown: true)]
        }
        await receiveVoted(store)
    }

    @MainActor
    @Test
    func theScoreCrossingZeroReadsLikeTheSitesOwn() async {
        let store = makeCommentsStore(comments: [Self.comment(id: "7", score: "+1", votedUp: true)])

        await store.send(.voteCommentDone(
            commentID: "7", result: .success(.init(commentID: 7, score: -2, vote: -1))
        )) {
            $0.comments = [Self.comment(id: "7", score: "-2", votedDown: true)]
        }
        await receiveVoted(store)
    }

    // The same vote again is a withdrawal: the site answers vote 0 and the score it had before.
    @MainActor
    @Test
    func votingAgainWithdrawsTheVote() async {
        let store = makeCommentsStore(comments: [Self.comment(id: "7", score: "+5", votedUp: true)])

        await store.send(.voteCommentDone(
            commentID: "7", result: .success(.init(commentID: 7, score: 4, vote: 0))
        )) {
            $0.comments = [Self.comment(id: "7", score: "+4")]
        }
        await receiveVoted(store)
    }

    // Only the comment voted on changes.
    @MainActor
    @Test
    func otherCommentsAreLeftAlone() async {
        let store = makeCommentsStore(comments: [
            Self.comment(id: "1", score: "+10"), Self.comment(id: "2", score: "+20")
        ])

        await store.send(.voteCommentDone(
            commentID: "2", result: .success(.init(commentID: 2, score: 21, vote: 1))
        )) {
            $0.comments = [Self.comment(id: "1", score: "+10"), Self.comment(id: "2", score: "+21", votedUp: true)]
        }
        await receiveVoted(store)
    }

    // The host's copy is told what the site answered, so the Detail card shows it too, without a fetch.
    @MainActor
    @Test
    func theHostIsToldTheSitesAnswer() async {
        let store = makeCommentsStore(comments: [Self.comment(id: "7", score: "+4")])

        await store.send(.voteCommentDone(
            commentID: "7", result: .success(.init(commentID: 7, score: 5, vote: 1))
        )) {
            $0.comments = [Self.comment(id: "7", score: "+5", votedUp: true)]
        }
        await store.receive({ action in
            guard case .delegate(.commentVoted(let gid, let commentID, let score, let vote)) = action
            else { return false }
            return (gid, commentID, score, vote) == ("42", "7", 5, 1)
        })
    }

    @MainActor
    @Test
    func aFailedVoteLeavesTheCommentsAlone() async {
        let comments = [Self.comment(id: "7", score: "+4", votedUp: true)]
        let store = makeCommentsStore(comments: comments)

        await store.send(.voteCommentDone(commentID: "7", result: .failure(.networkingFailed)))
        await store.finish()

        #expect(store.state.comments == comments)
    }

    // MARK: Detail

    @MainActor
    @Test
    func theDetailCardTakesTheVoteTheCommentsScreenMade() async {
        let store = makeDetailStore(comments: [Self.comment(id: "7", score: "+4"), Self.comment(id: "8", score: "+1")])

        await store.send(.applyCommentVote(commentID: "7", score: 5, vote: 1)) {
            $0.galleryComments = [Self.comment(id: "7", score: "+5", votedUp: true), Self.comment(id: "8", score: "+1")]
        }
    }

    @MainActor
    @Test
    func aVoteCastOnTheDetailCardUpdatesItFromTheResponse() async {
        let store = makeDetailStore(comments: [Self.comment(id: "7", score: "+5", votedUp: true)])

        await store.send(.voteCommentDone(
            commentID: "7", result: .success(.init(commentID: 7, score: 4, vote: 0))
        )) {
            $0.galleryComments = [Self.comment(id: "7", score: "+4")]
        }
    }

    @MainActor
    @Test
    func aFailedVoteOnTheDetailCardLeavesItAlone() async {
        let comments = [Self.comment(id: "7", score: "+5", votedUp: true)]
        let store = makeDetailStore(comments: comments)

        await store.send(.voteCommentDone(commentID: "7", result: .failure(.parseFailed)))
        await store.finish()

        #expect(store.state.galleryComments == comments)
    }

    // MARK: Model

    @Test(arguments: [(113, "+113"), (1, "+1"), (0, "0"), (-1, "-1"), (-20, "-20")])
    func theScoreTextCarriesItsSign(score: Int, text: String) {
        #expect(GalleryComment.scoreText(score) == text)
    }

    @Test
    func applyingAVoteSetsTheScoreAndExactlyOneVoteState() {
        var comment = Self.comment(id: "1", score: "+1")

        comment.applyVote(score: 2, vote: 1)
        #expect((comment.score, comment.votedUp, comment.votedDown) == ("+2", true, false))
        comment.applyVote(score: 0, vote: -1)
        #expect((comment.score, comment.votedUp, comment.votedDown) == ("0", false, true))
        comment.applyVote(score: 1, vote: 0)
        #expect((comment.score, comment.votedUp, comment.votedDown) == ("+1", false, false))
    }

    // MARK: Helpers

    @MainActor
    private func receiveVoted(_ store: TestStoreOf<CommentsReducer>) async {
        await store.receive({ action in
            if case .delegate(.commentVoted) = action { true } else { false }
        })
    }

    @MainActor
    private func makeCommentsStore(comments: [GalleryComment]) -> TestStoreOf<CommentsReducer> {
        var state = CommentsReducer.State(gid: "42", token: "abc123", galleryURL: .mock, comments: comments)
        state.comments = comments
        return TestStore(initialState: state, reducer: CommentsReducer.init) {
            $0.analyticsClient = .noop
            $0.hapticsClient = .noop
        }
    }

    @MainActor
    private func makeDetailStore(comments: [GalleryComment]) -> TestStoreOf<DetailReducer> {
        var state = DetailReducer.State(
            gallery: Gallery(
                gid: "42", token: "abc123", title: "Seed", rating: 4.5, tags: [],
                category: .doujinshi, pageCount: 30, postedDate: .init(timeIntervalSince1970: 0),
                coverURL: nil, galleryURL: .mock
            )
        )
        state.galleryComments = comments
        return TestStore(initialState: state, reducer: DetailReducer.init) {
            $0.analyticsClient = .noop
            $0.hapticsClient = .noop
        }
    }

    private static func comment(
        id: String, score: String, votedUp: Bool = false, votedDown: Bool = false
    ) -> GalleryComment {
        GalleryComment(
            votedUp: votedUp, votedDown: votedDown, votable: true, editable: false,
            score: score, author: "someone", contents: [], commentID: id,
            commentDate: Date(timeIntervalSince1970: 0)
        )
    }
}
