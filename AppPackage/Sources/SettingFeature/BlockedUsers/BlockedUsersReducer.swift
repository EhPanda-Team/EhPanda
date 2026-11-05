public import AppModels
public import ComposableArchitecture
import Foundation
public import Sharing

/// The Blocked Users list in Account settings (UI-SPEC C-11, C-12; D-14, D-14a).
///
/// The screen holds no copy of the block list: it reads `@Shared(.blockedCommentAuthors)`, the same store the comment
/// moderation writes, so a name blocked or unblocked anywhere is reflected here at once and the Account row's count
/// never disagrees with the list. Blocking is local to the device and needs no account, so nothing here depends on
/// signing in.
@Reducer
public struct BlockedUsersReducer: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        @Shared(.blockedCommentAuthors) public var blockedAuthors: [String]

        /// The blocked names in the order the list shows them: `localizedStandardCompare`, so case-insensitive and
        /// numeric as in Finder. The stored list keeps the order users were blocked in; sorting is for display only.
        public var authors: [String] {
            blockedAuthors.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending })
        }

        /// Nobody is blocked, the C-12 empty state.
        public var isEmpty: Bool { blockedAuthors.isEmpty }

        public init() {}
    }

    public enum Action: Equatable, Sendable {
        /// The swipe action or the context menu's Unblock. Takes effect at once, with no confirmation (C-11).
        case unblockTapped(author: String)
    }

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .unblockTapped(let author):
                guard state.blockedAuthors.isBlocked(author: author) else { return .none }
                state.$blockedAuthors.withLock({ $0.unblock(author: author) })
                return .none
            }
        }
    }
}
