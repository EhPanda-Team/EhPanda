import Resources
import SFSafeSymbols
import SwiftUI

/// A blocked author's comment in the comments list (UI-SPEC C-6, D-13): "Comment from a user you've blocked" with Show
/// and Unblock, in place of the whole comment.
///
/// It is given only the comment's ID and its two actions, never the comment, its author or its text, so nothing it
/// renders or reads out can name the blocked user. The row has no swipe actions and no context menu (nothing to vote
/// on or report while hidden). It is an accessibility container: the label is static text, Show and Unblock ordinary
/// buttons.
struct BlockedCommentRow: View {
    let commentID: String
    let showAction: () -> Void
    let unblockAction: () -> Void

    /// The label, on one line beside the buttons where both fit (iPad, wide windows), else above them.
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                BlockedCommentLabel()
                    .lineLimit(1)
                Spacer(minLength: 8)
                buttons
            }

            VStack(alignment: .leading, spacing: 10) {
                BlockedCommentLabel()
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        buttons
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        buttons
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("blocked_comment_" + commentID)
    }

    @ViewBuilder private var buttons: some View {
        BlockedCommentPill(title: .commentBlockedRowShow, action: showAction)
        BlockedCommentPill(title: .RLocalizable.blockedUsersUnblock, action: unblockAction)
    }
}

/// The `eye.slash` glyph and "Comment from a user you've blocked" (C-6), shared by the collapsed row and card.
struct BlockedCommentLabel: View {
    static let text: LocalizedStringResource = .commentBlockedRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemSymbol: .eyeSlash)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(Self.text)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

/// The line above a revealed comment's header in the list (C-7): the collapsed label and a Hide pill.
///
/// Hide sits beside the label, which wraps as it needs to (mockup 09). At accessibility sizes Hide goes under the
/// label, as the glyphs do on the first-launch cards (C-2): beside it, the label and the pill broke inside words.
struct RevealedCommentLine: View {
    let hideAction: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                label
                hide
            }
        } else {
            HStack(spacing: 8) {
                label
                    .layoutPriority(1)
                Spacer(minLength: 0)
                hide
            }
        }
    }

    private var label: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemSymbol: .eyeSlash)
                .accessibilityHidden(true)
            Text(BlockedCommentLabel.text)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    private var hide: some View {
        BlockedCommentPill(title: .commentBlockedRowHide, action: hideAction)
    }
}

/// Show, Unblock or Hide in the list: a small grey capsule with primary text, never the accent (C-6).
private struct BlockedCommentPill: View {
    let title: LocalizedStringResource
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .tint(.primary)
    }
}
