import AppModels
import NetworkingFeature
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI

/// The two directions a comment can be voted in.
enum CommentVoteDirection: Hashable, Sendable {
    case up
    case down

    /// What `comment_vote` is sent: a vote up is `1`, a vote down `-1`. Sent again for the direction already voted,
    /// the site withdraws the vote.
    var value: Int {
        switch self {
        case .up: 1
        case .down: -1
        }
    }
}

/// One of the two vote slots of a comment's menu, whose direction is fixed: Vote Up first, Vote Down second.
struct CommentVoteSlot: Equatable, Sendable {
    let direction: CommentVoteDirection
    /// Whether the slot withdraws the vote already cast in its direction. A withdrawal is the same call as the vote,
    /// sent again.
    let isWithdraw: Bool
    let isEnabled: Bool
}

/// The vote row of a comment's menu: always two slots, always both shown, `up` then `down`.
struct CommentVoteMenuState: Equatable, Sendable {
    let up: CommentVoteSlot
    let down: CommentVoteSlot

    var slots: [CommentVoteSlot] { [up, down] }

    func slot(_ direction: CommentVoteDirection) -> CommentVoteSlot {
        direction == .up ? up : down
    }
}

/// The vote row for `comment`.
///
/// - Not voted: Vote Up and Vote Down, both enabled.
/// - Voted up: Withdraw Vote in the up slot, enabled; Vote Down disabled. Voted down mirrors it.
/// - Disabled throughout when the user is signed out or the site offers `comment` no vote (`votable`, which the
///   user's own comment and the uploader's never are; an editable comment is the user's own whatever else it
///   says).
///
/// The site's own page keeps both arrows while a vote stands, but the spec leaves the opposite one disabled, so
/// here a vote is only ever cast or withdrawn, never switched. A slot is never left out, however impossible: it is
/// shown disabled.
func voteMenuState(for comment: GalleryComment, didLogin: Bool) -> CommentVoteMenuState {
    let canVote = didLogin && comment.votable && !comment.editable
    return CommentVoteMenuState(
        up: CommentVoteSlot(
            direction: .up,
            isWithdraw: comment.votedUp,
            isEnabled: canVote && !comment.votedDown
        ),
        down: CommentVoteSlot(
            direction: .down,
            isWithdraw: comment.votedDown,
            isEnabled: canVote && !comment.votedUp
        )
    )
}

extension CommentVoteSlot {
    /// The slot's name and glyph. A withdrawal reads "Withdraw Vote" with the slashed thumb of the vote it undoes.
    var label: some View {
        Label(title, systemSymbol: symbol)
    }

    var title: LocalizedStringResource {
        isWithdraw ? .withdrawVote : direction == .up ? .voteUp : .voteDown
    }

    var symbol: SFSymbol {
        switch (direction, isWithdraw) {
        case (.up, false): .handThumbsup
        case (.up, true): .handThumbsupSlash
        case (.down, false): .handThumbsdown
        case (.down, true): .handThumbsdownSlash
        }
    }
}

/// Sends a comment vote; one place for the comments screen and the Detail screen, which both vote.
enum CommentVoteRequest {
    static func response(
        host: GalleryHost, apiuid: Int, apiKey: String, gid: Int, token: String, commentID: Int, vote: Int
    ) async -> Result<GalleryCommentVoteResponse, AppError> {
        await Result.Swift::init { () async throws(AppError) in
            try await VoteGalleryCommentRequest(
                host: host, apiuid: apiuid, apikey: apiKey, gid: gid, token: token,
                commentID: commentID, commentVote: vote
            )
            .response()
        }
    }
}

extension Array where Element == GalleryComment {
    /// Applies a vote's outcome to the comment with `commentID`, if it is here.
    mutating func applyVote(commentID: String, score: Int, vote: Int) {
        self = map { comment in
            guard comment.commentID == commentID else { return comment }
            var voted = comment
            voted.applyVote(score: score, vote: vote)
            return voted
        }
    }
}
