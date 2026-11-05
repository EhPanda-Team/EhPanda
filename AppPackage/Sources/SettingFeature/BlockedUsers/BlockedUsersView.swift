import ComposableArchitecture
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI

/// The Blocked Users list (UI-SPEC C-11) and its empty state (C-12).
///
/// One inset-grouped section of names with the footer, and the empty state in place of the section once nobody is
/// left. The empty state overlays the list rather than replacing it, so removing the last name keeps the screen, its
/// grouped background and its large title where they were, and only the content changes.
///
/// Unblocking has two entry points with the same effect and no confirmation: the trailing swipe, whose full swipe runs
/// it at once and which VoiceOver offers as an action, and the context menu for pointer and keyboard users. The swipe's
/// destructive role is what removes the row with the standard delete animation.
struct BlockedUsersView: View {
    private let store: StoreOf<BlockedUsersReducer>

    init(store: StoreOf<BlockedUsersReducer>) {
        self.store = store
    }

    var body: some View {
        List {
            if !store.isEmpty {
                Section {
                    ForEach(store.authors, id: \.self) { author in
                        row(author)
                    }
                } footer: {
                    Text(.RLocalizable.blockedUsersFooter)
                }
            }
        }
        .overlay {
            if store.isEmpty {
                // The title wraps freely: no line break, scaling, line limit or fixed width (UI-SPEC C-3, C-12).
                ContentUnavailableView {
                    Label(.RLocalizable.blockedUsersEmpty, systemSymbol: .handRaised)
                }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .navigationTitle(.RLocalizable.blockedUsers)
    }

    /// A name as the site prints it, wrapping when long; nothing truncates.
    private func row(_ author: String) -> some View {
        Text(author)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                Button(role: .destructive) {
                    store.send(.unblockTapped(author: author))
                } label: {
                    Text(.RLocalizable.blockedUsersUnblock)
                }
            }
            .contextMenu {
                Button {
                    store.send(.unblockTapped(author: author))
                } label: {
                    Label(.commentUnblock(author), systemSymbol: .handRaisedSlash)
                }
            }
    }
}

#Preview("Blocked users") {
    NavigationStack {
        BlockedUsersView(store: .init(initialState: .init(), reducer: BlockedUsersReducer.init))
    }
}
