import AppModels
import ComposableArchitecture
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI

/// One moderation item of a comment (UI-SPEC C-4, C-8).
enum CommentModerationItem: Hashable, Sendable {
    case report
    case block
    case unblock
    /// Collapses a revealed comment again; the Detail strip's card offers it here, having no room for a Hide pill.
    case hide
}

/// Where a comment is shown, which decides whether a revealed comment's Hide is a menu item.
enum CommentModerationSurface: Sendable {
    /// The comments list; a revealed comment has its own Hide pill (C-7).
    case list
    /// The Detail strip's card (C-8).
    case card
}

/// Where a comment's poster stands with the block list (owner msg 1918: blocks match the member ID).
enum CommentBlockStatus: Sendable {
    /// The poster's member ID is blocked.
    case blocked
    /// The poster has a member ID that is not blocked, so Block can add it.
    case notBlocked
    /// The comment carries no member ID: there is nothing stable to block by, and it is never blocked.
    case noMemberID
}

/// The items of a comment's moderation menu, from one source for every entry point: the `…` `Menu` of the comments
/// list, the `.contextMenu` of a list cell or a Detail strip card, and the `accessibilityActions` of the cell's
/// combined element (C-4; a context menu alone is not a VoiceOver source here, research §5.5).
enum CommentModerationMenu {
    /// - The signed-in user's own comment has none (A-10).
    /// - A collapsed comment (blocked, not revealed) has none: it shows only the collapsed row or card (C-6, C-8).
    /// - Otherwise Report then Block, or Report then Unblock when the author is blocked and the comment revealed.
    ///   Report is left out when the gallery has no report page, as there would be nowhere to go (lead decision).
    ///   Block is left out when the comment carries no member ID, as there is nothing stable to block by (lead
    ///   decision, owner msg 1918); such a comment is never blocked, so it never needs Unblock either.
    /// - A revealed card adds Hide as the third item (C-8).
    static func items(
        for surface: CommentModerationSurface,
        blockStatus: CommentBlockStatus, isRevealed: Bool, isOwn: Bool, hasReportTarget: Bool
    ) -> [CommentModerationItem] {
        let isBlocked = blockStatus == .blocked
        guard !isOwn, !isBlocked || isRevealed else { return [] }
        var items = [CommentModerationItem]()
        if hasReportTarget {
            items.append(.report)
        }
        switch blockStatus {
        case .blocked:
            items.append(.unblock)
        case .notBlocked:
            items.append(.block)
        case .noMemberID:
            break
        }
        if isBlocked, surface == .card {
            items.append(.hide)
        }
        return items
    }
}

/// A comment's moderation items with what their labels need, and where a chosen item goes.
struct CommentModerationActions {
    let items: [CommentModerationItem]
    /// The `{site}` of "Report on {site}"; present whenever `items` holds `.report`.
    let siteName: String?
    /// The commenter's name exactly as shown on the comment.
    let author: String
    let perform: (CommentModerationItem) -> Void

    static var none: Self {
        Self(items: [], siteName: nil, author: "", perform: { _ in })
    }
}

extension CommentModerationFeature.State {
    /// The moderation items `comment` offers on `surface`; `didLogin` and `displayName` decide whether it is the
    /// signed-in user's own (A-10).
    func actions(
        for comment: GalleryComment, on surface: CommentModerationSurface,
        didLogin: Bool, displayName: String?,
        perform: @escaping (CommentModerationItem) -> Void
    ) -> CommentModerationActions {
        let siteName = galleryURL.flatMap(CommentReportTarget.siteName(for:))
        let hasReportTarget = siteName != nil && galleryURL.flatMap(CommentReportTarget.reportURL(for:)) != nil
        let blockStatus: CommentBlockStatus = if isBlocked(comment) {
            .blocked
        } else if comment.authorMemberID?.isEmpty == false {
            .notBlocked
        } else {
            .noMemberID
        }
        let items = CommentModerationMenu.items(
            for: surface,
            blockStatus: blockStatus,
            isRevealed: revealedCommentIDs.contains(comment.commentID),
            isOwn: CommentOwnership.isOwn(comment, didLogin: didLogin, displayName: displayName),
            hasReportTarget: hasReportTarget
        )
        return CommentModerationActions(items: items, siteName: siteName, author: comment.author, perform: perform)
    }
}

extension Optional {
    /// The value only while `isPresented`, else `nil`; a write goes through only while `isPresented`.
    ///
    /// Through a binding, this lets every row or card hold the screen's one moderation alert modifier while only the
    /// one that asked presents it (AGENTS.md: an alert sits on the control that triggered it). The others read `nil`
    /// and, presenting nothing, never dismiss it.
    subscript(presentedIf isPresented: Bool) -> Wrapped? {
        get { isPresented ? self : nil }
        set {
            if isPresented {
                self = newValue
            }
        }
    }
}

/// The moderation buttons, the same content in a `Menu`, a `.contextMenu` and an `accessibilityActions` block. The
/// names are the visible menu strings, so Voice Control and VoiceOver use what the screen shows.
struct CommentModerationButtons: View {
    let actions: CommentModerationActions
    /// Declares the items last first. An `accessibilityActions` block hands its actions to assistive technologies in
    /// the reverse of their declaration order, so a block declares its items reversed to list them as the menu does.
    var isReversed = false

    var body: some View {
        ForEach(isReversed ? actions.items.reversed() : actions.items, id: \.self) { item in
            switch item {
            case .report:
                if let siteName = actions.siteName {
                    Button {
                        actions.perform(.report)
                    } label: {
                        Label(.commentReport(siteName), systemSymbol: .exclamationmarkBubble)
                    }
                }
            case .block:
                Button(role: .destructive) {
                    actions.perform(.block)
                } label: {
                    Label(.commentBlock(actions.author), systemSymbol: .handRaised)
                }
            case .unblock:
                Button {
                    actions.perform(.unblock)
                } label: {
                    Label(.commentUnblock(actions.author), systemSymbol: .handRaisedSlash)
                }
            case .hide:
                Button {
                    actions.perform(.hide)
                } label: {
                    Label(.commentBlockedRowHide, systemSymbol: .eyeSlash)
                }
            }
        }
    }
}

/// The comments list's `…` button (C-4): an `ellipsis` in a 44pt hit area that overhangs the row padding, so the row
/// does not grow. It is hidden from accessibility; the same items are the cell's accessibility actions.
///
/// The glyph is `.secondary` gray (UI-SPEC "Muted"), so the button takes the plain style: the borderless style draws
/// the label in the app's accent and overrides its foreground style. Any style but the automatic one also keeps a tap
/// on the rest of the list row from opening the menu.
struct CommentModerationMenuButton: View {
    let actions: CommentModerationActions

    var body: some View {
        Menu {
            CommentModerationButtons(actions: actions)
        } label: {
            Image(systemSymbol: .ellipsis)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(.hoverEffect, .circle)
                .hoverEffect()
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .padding(.vertical, -12)
        .padding(.trailing, -12)
        .accessibilityHidden(true)
    }
}
