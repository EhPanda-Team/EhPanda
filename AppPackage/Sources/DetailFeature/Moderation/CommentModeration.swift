public import AppComponents
public import AppModels
public import ComposableArchitecture
import CookieClient
public import Foundation
import Resources
public import Sharing

/// Comment moderation for one screen (UGC-18-01): the posting warning, Report, Block, Unblock and Show (D-10,
/// D-12, D-13). `CommentsReducer` and `DetailReducer` each scope one in, so a comment behaves the same in the
/// comments list and in the Detail strip; the views only send these actions and read this state.
///
/// Nothing here sends an analytics signal (D-02): no author name or comment text leaves the device this way.
@Reducer
public struct CommentModerationFeature: Sendable {
    /// The buttons of the screen's moderation alerts.
    @CasePathable
    public enum Alert: Equatable, Sendable {
        /// Posting warning: back to the editor with the text as typed (UI-SPEC C-5, the cancel-role default).
        case edit
        /// Posting warning: send the comment anyway.
        case postAnyway
        /// Report confirmation: open the gallery's report page.
        case confirmReport(URL)
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
        /// Present the report page in the screen's in-app sheet.
        case openReportPage(URL)
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

    @Dependency(\.cookieClient) private var cookieClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .alert(.presented(.edit)):
                return .send(.delegate(.resumeEditing))

            case .alert(.presented(.postAnyway)):
                return .send(.delegate(.post))

            case .alert(.presented(.confirmReport(let url))):
                return .send(.delegate(.openReportPage(url)))

            case .alert(.presented(.confirmBlock(let memberID, let name))):
                state.$blockedUsers.withLock({ $0.block(memberID: memberID, name: name) })
                return .send(.delegate(.didBlock(memberID: memberID)))

            case .alert, .delegate:
                return .none

            case .reportTapped(let comment):
                // A gallery with no report page gets no alert either: Open would have nowhere to go (A-5).
                guard !isOwn(comment), let galleryURL = state.galleryURL,
                      let url = CommentReportTarget.reportURL(for: galleryURL),
                      let site = CommentReportTarget.siteName(for: galleryURL)
                else { return .none }
                state.alert = AppAlertState {
                    TextState(localized: .commentReportConfirmTitle)
                } actions: {
                    ButtonState(role: .cancel) {
                        TextState(localized: .RLocalizable.cancel)
                    }
                    ButtonState(action: .confirmReport(url)) {
                        TextState(localized: .commentReportOpen)
                    }
                } message: {
                    TextState(localized: .commentReportConfirmBody(site, comment.author))
                }
                return .none

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
                // No confirmation: blocking again is one menu away (C-6).
                state.$blockedUsers.withLock({ $0.unblock(memberID: memberID) })
                return .none

            case .show(let commentID):
                state.revealedCommentIDs.insert(commentID)
                return .none

            case .hide(let commentID):
                state.revealedCommentIDs.remove(commentID)
                return .none
            }
        }
        .ifLet(\.$alert, action: \.alert)
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
