public import AppModels
public import ComposableArchitecture
import Foundation
public import Sharing

/// The Blocked Users list in Account settings (UI-SPEC C-11, C-12; D-14, D-14a).
///
/// The screen holds no copy of the block list: it reads `@Shared(.blockedCommentUsers)`, the same store the comment
/// moderation writes, so a user blocked or unblocked anywhere is reflected here at once and the Account row's count
/// never disagrees with the list. Each row shows the name the user was last seen under; Unblock removes by member ID
/// (owner msg 1918). Blocking is local to the device and needs no account, so nothing here depends on
/// signing in.
@Reducer
public struct BlockedUsersReducer: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        @Shared(.blockedCommentUsers) public var blockedUsers: [BlockedCommentUser]

        /// The blocked users in the order the list shows them: by name with `localizedStandardCompare`, so
        /// case-insensitive and numeric as in Finder, then by member ID for two users under one name. The stored list
        /// keeps the order users were blocked in; sorting is for display only.
        public var users: [BlockedCommentUser] {
            blockedUsers.sorted { lhs, rhs in
                switch lhs.name.localizedStandardCompare(rhs.name) {
                case .orderedAscending:
                    true
                case .orderedDescending:
                    false
                case .orderedSame:
                    lhs.memberID.localizedStandardCompare(rhs.memberID) == .orderedAscending
                }
            }
        }

        /// Nobody is blocked, the C-12 empty state.
        public var isEmpty: Bool { blockedUsers.isEmpty }

        public init() {}
    }

    public enum Action: Equatable, Sendable {
        /// The swipe action or the context menu's Unblock. Takes effect at once, with no confirmation (C-11).
        case unblockTapped(memberID: String)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .unblockTapped(let memberID):
                guard state.blockedUsers.isBlocked(memberID: memberID) else { return .none }
                state.$blockedUsers.withLock({ $0.unblock(memberID: memberID) })
                return .none
            }
        }
    }
}
