import AppComponents
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
                ContentUnavailableView {
                    Label {
                        BlockedUsersEmptyTitle()
                    } icon: {
                        Image(systemSymbol: .handRaised)
                    }
                }
            }
        }
        // An empty `List` draws no grouped background of its own, so the empty state would sit on white while the
        // filled list sits on the grouped grey. Drawing the grouped background behind the list keeps the screen the
        // same colour when the last name goes (C-12 switches in place).
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
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

/// The empty state's title (C-12): `blocked_users.empty` in the `ContentUnavailableView` label's own font, wrapping
/// freely, with no line break, scaling, line limit or fixed width (UI-SPEC C-3, owner msg 1822).
///
/// It carries `TitleWidowGuard` like the first-launch titles: the last two words are joined with a no-break space when
/// they fit on one line at the current width and text size, so German at AX5 on iPad reads "Du hast / niemanden
/// blockiert." When the pair is wider than the line, as in English and German at AX5 on iPhone, the title is left as
/// written (the owner msg 1903 exception). The label keeps the font `ContentUnavailableView` gives it, bold `.title3`,
/// and is measured in that font.
private struct BlockedUsersEmptyTitle: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var availableWidth: CGFloat = 0

    private let title = String(localized: .RLocalizable.blockedUsersEmpty)

    var body: some View {
        Text(verbatim: guardedTitle)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { width in
                availableWidth = width
            }
            .accessibilityLabel(title)
    }

    private var guardedTitle: String {
        TitleWidowGuard.guarded(
            title, width: availableWidth, font: TitleWidowGuard.boldFont(.title3, at: dynamicTypeSize)
        )
    }
}

#Preview("Blocked users") {
    NavigationStack {
        BlockedUsersView(store: .init(initialState: .init(), reducer: BlockedUsersReducer.init))
    }
}
