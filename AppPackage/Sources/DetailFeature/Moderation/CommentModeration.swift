import AnalyticsClient
public import AppComponents
public import AppModels
public import ComposableArchitecture
import CookieClient
public import Foundation
import Resources
public import Sharing

/// Comment moderation for one screen (UGC-18-01): the posting warning, Report, Block, Unblock and Show (D-10,
/// D-12, D-13). Report hands the screen a Report form to present (18.1 D-01). `CommentsReducer` and `DetailReducer`
/// each scope one in, so a comment behaves the same in the comments list and in the Detail strip; the views only send
/// these actions and read this state.
///
/// Five actions send an analytics signal, the ones signed off in `20-12-VOCABULARY.md` (product lead msg 2829): the
/// answer to the posting warning, a confirmed block, an unblock, and showing a collapsed comment. Each carries a closed
/// value (the choice, or the surface) and nothing else, so no author name, member ID or comment text leaves the device
/// this way. Reporting is the Report form's signal, not this reducer's.
@Reducer
public struct CommentModerationFeature: Sendable {
    /// The buttons of the screen's moderation alerts.
    @CasePathable
    public enum Alert: Equatable, Sendable {
        /// Posting warning: back to the editor with the text as typed (UI-SPEC C-5, the cancel-role default).
        case edit
        /// Posting warning: send the comment anyway.
        case postAnyway
        /// Block confirmation: the poster's member ID, and the name the comment shows, which the list keeps.
        case confirmBlock(memberID: String, name: String)
    }

    /// What the host screen does with a moderation decision; it owns the editor and the sheets.
    @CasePathable
    public enum Delegate: Equatable, Sendable {
        /// Send the comment in the editor, then close the editor (the warning was overridden).
        case post
        /// Give the editor its focus back; the editor and its text stay as they are.
        case resumeEditing
        /// Present EhPanda's Report form for one comment in the screen's sheet (18.1 D-01).
        case openReportForm(ReportFormFeature.State)
        /// The poster with `memberID` was blocked, so every comment of theirs on the screen collapses, revealed ones
        /// included.
        case didBlock(memberID: String)
    }

    @ObservableState
    public struct State: Equatable {
        @Presents public var alert: AppAlertState<Alert>?
        @Shared(.blockedCommentUsers) public var blockedUsers: [BlockedCommentUser]
        /// Comments shown once despite a blocked author (C-7). Per screen and never stored: it goes with the screen.
        public var revealedCommentIDs = Set<String>()
        /// The gallery the screen's comments belong to; where Report goes (D-10).
        public var galleryURL: URL?

        public init(galleryURL: URL?) {
            self.galleryURL = galleryURL
        }

        /// Whether `comment` shows as the collapsed row (C-6, C-8): its author is blocked and it isn't revealed.
        public func isCollapsed(_ comment: GalleryComment) -> Bool {
            isBlocked(comment) && !revealedCommentIDs.contains(comment.commentID)
        }

        /// Whether `comment`'s poster is blocked, revealed or not; the menu offers Unblock instead of Block (C-4).
        /// Matches the member ID, never the name (owner msg 1918), so a comment with no member ID is never blocked.
        public func isBlocked(_ comment: GalleryComment) -> Bool {
            blockedUsers.isBlocked(memberID: comment.authorMemberID)
        }

        /// The blocked member IDs in block order: what collapsing depends on, without the stored names, so a name
        /// refresh neither animates nor moves VoiceOver focus.
        public var blockedMemberIDs: [String] {
            blockedUsers.map(\.memberID)
        }

        /// Stores the names `comments` show for blocked posters whose name changed, so the Blocked Users list names
        /// them as the site does now. Writes nothing when every stored name is current.
        public mutating func refreshBlockedNames(from comments: [GalleryComment]) {
            let renamed = blockedUsers.renamedUsers(in: comments)
            guard !renamed.isEmpty else { return }
            $blockedUsers.withLock({ $0.updateNames(renamed) })
        }

        /// The posting warning (C-5); the screen presents it instead of sending when the filter matches.
        mutating func presentPostingWarning() {
            alert = AppAlertState {
                TextState(localized: .commentFilterTitle)
            } actions: {
                ButtonState(role: .cancel, action: .edit) {
                    TextState(localized: .commentFilterEdit)
                }
                ButtonState(action: .postAnyway) {
                    TextState(localized: .commentFilterPostAnyway)
                }
            } message: {
                TextState(localized: .commentFilterBody)
            }
        }
    }

    public enum Action: Equatable, Sendable {
        case alert(PresentationAction<Alert>)
        case delegate(Delegate)
        case reportTapped(GalleryComment)
        case blockTapped(GalleryComment)
        case unblock(memberID: String)
        case show(commentID: String)
        case hide(commentID: String)
    }

    @Dependency(\.analyticsClient) private var analyticsClient
    @Dependency(\.cookieClient) private var cookieClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .alert(.presented(.edit)):
                return .merge(
                    signal(.commentPostingWarningAnswered(.edit)),
                    .send(.delegate(.resumeEditing))
                )

            case .alert(.presented(.postAnyway)):
                return .merge(
                    signal(.commentPostingWarningAnswered(.postAnyway)),
                    .send(.delegate(.post))
                )

            case .alert(.presented(.confirmBlock(let memberID, let name))):
                state.$blockedUsers.withLock({ $0.block(memberID: memberID, name: name) })
                return .merge(
                    signal(.commentPosterBlocked),
                    .send(.delegate(.didBlock(memberID: memberID)))
                )

            case .alert, .delegate:
                return .none

            case .reportTapped(let comment):
                // No alert: Report opens the form at once (18.1 D-01). A gallery with no report target opens
                // nothing, since the form would have nowhere to read or send (A-5).
                guard !isOwn(comment), let galleryURL = state.galleryURL,
                      let form = ReportFormFeature.State(comment: comment, galleryURL: galleryURL)
                else { return .none }
                return .send(.delegate(.openReportForm(form)))

            case .blockTapped(let comment):
                // A comment with no member ID cannot be blocked: there is nothing stable to match (owner msg 1918).
                guard !isOwn(comment), let memberID = comment.authorMemberID, !memberID.isEmpty else { return .none }
                state.alert = AppAlertState {
                    TextState(localized: .commentBlockConfirmTitle(comment.author))
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState(localized: .RLocalizable.cancel)
                    }
                    ButtonState(role: .destructive, action: .confirmBlock(memberID: memberID, name: comment.author)) {
                        TextState(localized: .commentBlockConfirm)
                    }
                } message: {
                    TextState(localized: .commentBlockConfirmBody)
                }
                return .none

            case .unblock(let memberID):
                // No confirmation: blocking again is one menu away (C-6). Someone who is not blocked is not
                // unblocked, so that is not reported.
                let wasBlocked = state.blockedUsers.isBlocked(memberID: memberID)
                state.$blockedUsers.withLock({ $0.unblock(memberID: memberID) })
                return wasBlocked ? signal(.commentPosterUnblocked(from: .comment)) : .none

            case .show(let commentID):
                state.revealedCommentIDs.insert(commentID)
                return signal(.blockedCommentShown)

            case .hide(let commentID):
                state.revealedCommentIDs.remove(commentID)
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
    }

    /// Sends one signed-off signal (20-12). The signals carry closed values only, so nothing of the comment can follow.
    private func signal(_ value: AnalyticsSignal) -> Effect<Action> {
        .run { _ in analyticsClient.send(value) }
    }

    /// The signed-in user's own comments get no Report or Block (A-10).
    private func isOwn(_ comment: GalleryComment) -> Bool {
        if comment.editable {
            return true
        }
        @SharedReader(.user) var user
        return CommentOwnership.isOwn(comment, didLogin: cookieClient.didLogin, displayName: user.displayName)
    }
}

extension CommentModerationFeature.State {
    /// Collapses the comments of the poster with `memberID` among `comments` again, revealed ones included, after a
    /// block (C-4).
    mutating func collapseComments(by memberID: String, in comments: [GalleryComment]) {
        let ids = comments.filter({ $0.authorMemberID == memberID }).map(\.commentID)
        revealedCommentIDs.subtract(ids)
    }
}

// MARK: - Posting filter

/// The posting filter's term list, a dependency so tests can match against a list of their own instead of the
/// bundled one.
enum CommentFilterTermsKey: DependencyKey {
    static let liveValue = CommentFilterTerms.bundled
    static let testValue = CommentFilterTerms.bundled
}

extension DependencyValues {
    var commentFilterTerms: CommentFilterTerms {
        get { self[CommentFilterTermsKey.self] }
        set { self[CommentFilterTermsKey.self] = newValue }
    }
}
