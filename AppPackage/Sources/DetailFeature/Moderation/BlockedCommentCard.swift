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
            // Side by side where both fit, else one above the other, as on the collapsed row (C-6).
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    pills
                }
                VStack(spacing: 8) {
                    pills
                }
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

    @ViewBuilder private var pills: some View {
        BlockedCommentCardPill(title: .commentBlockedRowShow, action: showAction)
        BlockedCommentCardPill(title: .RLocalizable.blockedUsersUnblock, action: unblockAction)
    }
}

/// Show or Unblock on the card. The list's grey bordered fill would vanish on the card's `systemGray5`, so these are
/// plain buttons on their own capsule, the same size and type as the list's pills (C-8, rev 1.1): white in light, and
/// in dark `systemGray3` with a 1pt `systemGray` edge, which meets 3:1 against the card.
private struct BlockedCommentCardPill: View {
    private static let fill = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .systemGray3 : .white })
    private static let stroke = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? .systemGray : .clear })

    let title: LocalizedStringResource
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 14)
                .frame(minHeight: 30)
                .background(Self.fill, in: .capsule)
                .overlay(Capsule().strokeBorder(Self.stroke, lineWidth: 1))
                .contentShape(.hoverEffect, .capsule)
                .hoverEffect(.highlight)
        }
        .buttonStyle(.plain)
    }
}
