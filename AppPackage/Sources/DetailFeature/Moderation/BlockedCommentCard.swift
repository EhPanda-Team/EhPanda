import Resources
import SFSafeSymbols
import SwiftUI

/// A blocked author's comment in the Detail strip (UI-SPEC C-8, D-13): the collapsed label and Show and Unblock,
/// centred on a card of the comment card's own size, so the strip keeps equal cards at every Dynamic Type step.
///
/// Like the list's collapsed row it is given only the comment's ID and its two actions, never the author or the text.
/// It has no context menu. It is an accessibility container: the label is static text, Show and Unblock buttons.
struct BlockedCommentCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var cardHeight = CommentCardMetrics.baseHeight

    let commentID: String
    let backgroundColor: Color
    let showAction: () -> Void
    let unblockAction: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            BlockedCommentLabel()
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                BlockedCommentCardPill(title: .commentBlockedRowShow, action: showAction)
                BlockedCommentCardPill(title: .RLocalizable.blockedUsersUnblock, action: unblockAction)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .frame(
            width: CommentCardMetrics.width(for: dynamicTypeSize),
            height: cardHeight * CommentCardMetrics.heightScale(for: dynamicTypeSize)
        )
        .background(backgroundColor)
        .clipShape(.rect(cornerRadius: CommentCardMetrics.cornerRadius))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("blocked_comment_card_" + commentID)
    }
}

/// Show or Unblock on the card. The list's grey bordered fill would vanish on the card's `systemGray5`, so these are
/// plain buttons on a `secondarySystemGroupedBackground` capsule, the same size and type as the list's pills (C-8).
private struct BlockedCommentCardPill: View {
    let title: LocalizedStringResource
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .frame(minHeight: 30)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: .capsule)
                .contentShape(.hoverEffect, .capsule)
                .hoverEffect(.highlight)
        }
        .buttonStyle(.plain)
    }
}
