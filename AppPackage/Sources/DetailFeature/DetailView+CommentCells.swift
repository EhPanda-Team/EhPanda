import AppComponents
import AppModels
import Resources
import SFSafeSymbols
import SwiftUI

extension DetailView {
    struct CommentCell: View {
        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        let comment: GalleryComment
        let backgroundColor: Color
        /// The card's Report and Block (or Unblock, and Hide when revealed) items: its context menu and
        /// accessibility actions (UI-SPEC C-4, C-8). None for the user's own comment.
        var moderation: CommentModerationActions = .none

        @ScaledMetric(relativeTo: .body) private var cardHeight = CommentCardMetrics.baseHeight

        private var content: AttributedString {
            comment.contents
                .filter({ [.plainText, .linkedText].contains($0.type) })
                .compactMap(\.text)
                .reduce(into: AttributedString()) { result, text in
                    result.append(text)
                }
        }

        /// The card is one accessibility element: a comment is read as a unit — author, vote,
        /// score, date, text — rather than as four stops in a strip of near-identical cards. The
        /// vote travels as the element's value, never as text: the thumb glyph is hidden below,
        /// and the value is attached only while a vote exists, so an unvoted comment has none.
        /// The moderation items of its context menu are also the element's named actions: a
        /// context menu alone is not a VoiceOver source here (research §5.5).
        var body: some View {
            VStack(alignment: .leading) {
                authorAndMetadata

                Text(content)
                    .padding(.top, 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding()
            .frame(
                width: CommentCardMetrics.width(for: dynamicTypeSize),
                height: cardHeight * CommentCardMetrics.heightScale(for: dynamicTypeSize)
            )
            .background(backgroundColor)
            .clipShape(.rect(cornerRadius: CommentCardMetrics.cornerRadius))
            .accessibilityElement(children: .combine)
            .accessibilityValue(.accessibilityVotedUp, isEnabled: comment.votedUp)
            .accessibilityValue(.accessibilityVotedDown, isEnabled: comment.votedDown)
            .accessibilityActions {
                CommentModerationButtons(actions: moderation)
            }
        }

        /// The author and the vote/date group share a line for as long as both fit it whole, and
        /// take a line each once they do not — which is what stops the author being eaten one
        /// ellipsis at a time and lets the banned 0.75 shrink go without taking the name with it.
        ///
        /// The candidates are written out rather than shared through `AdaptiveStack`, because the
        /// spacer that holds the pair apart and the `.lineLimit(1)` that keeps it to one line must
        /// belong to the horizontal candidate alone: in shared content the spacer becomes a
        /// vertical expander once the pair stacks, and the line limit would clamp the stacked
        /// author to the very ellipsis the stacking exists to avoid.
        ///
        /// That spacer replaces a `.frame(maxWidth: .infinity, alignment: .leading)` on the
        /// author, for two reasons. A flexible frame inside a candidate absorbs the overflow, so
        /// every candidate measures as fitting and the fallback can never win. And it was also
        /// *greedy*: it claimed the row's slack for the author's own frame and left the timestamp
        /// beside it short, so the date ellipsised at the default size the moment the shrink that
        /// had been papering over it was removed. `minLength: 0` keeps the spacer from claiming
        /// width of its own — this pair is measured against a card barely wider than the pair, so
        /// the measurement has no room for a gap nobody asked for.
        private var authorAndMetadata: some View {
            ViewThatFits(in: .horizontal) {
                HStack {
                    authorText

                    Spacer(minLength: 0)

                    metadata
                }
                .lineLimit(1)

                VStack(alignment: .leading) {
                    authorText
                    metadata
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }

        private var authorText: some View {
            Text(comment.author)
                .font(.subheadline.bold())
        }

        private var metadata: some View {
            HStack {
                Image(systemSymbol: comment.votedUp ? .handThumbsupFill : .handThumbsdownFill)
                    .animation(.default) {
                        $0.visible(comment.votedUp || comment.votedDown)
                    }
                    .accessibilityHidden(true)

                comment.score.map(Text.init)

                Text(comment.formattedDateString)
                    .accessibilityRepresentation {
                        Text(comment.accessibilityAttributedDateString)
                    }
            }
            .foregroundStyle(.secondary)
            .font(.footnote)
        }
    }
}

/// The Detail strip's card size, shared by the comment card and the collapsed card (C-8), so the strip keeps equal
/// cards whatever they hold.
///
/// The card is a fixed-budget surface: it sits in a horizontal strip whose cards must all be the same size, so the
/// card cannot grow to its content and cannot scroll. Its budget is therefore area, and area has to be bought back
/// deliberately — which is what the two steps below do.
enum CommentCardMetrics {
    /// The card height at the default size (.large); each card scales it with Dynamic Type relative to the card body
    /// text style (.body) through `@ScaledMetric`.
    static let baseHeight: CGFloat = 120
    static let cornerRadius: CGFloat = 15

    /// The width buys characters per line. It cannot grow past what a compact screen holds, so it only takes the
    /// pressure off; the height carries the rest.
    static func width(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small, .medium, .large: 300
        case .xLarge, .xxLarge, .xxxLarge: 320
        case .accessibility1, .accessibility2: 340
        case .accessibility3, .accessibility4: 360
        case .accessibility5: 380
        @unknown default: 300
        }
    }

    /// The scaled height alone grows exactly with the body text, which holds the card's *line* count constant while
    /// every line holds fewer characters — that is precisely how the card used to show less of a comment at each
    /// larger size. This factor is the correction: it grows the height faster than the text so the lines the card
    /// gains make up for the characters each line loses. Its default tier is 1, so the card is untouched at and below
    /// the default size.
    static func heightScale(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small, .medium, .large: 1
        case .xLarge, .xxLarge, .xxxLarge: 1.2
        case .accessibility1, .accessibility2: 1.4
        case .accessibility3, .accessibility4: 1.6
        case .accessibility5: 1.8
        @unknown default: 1
        }
    }
}

struct CommentButton: View {
    let backgroundColor: Color
    let action: () -> Void

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 15)

        Button(action: action) {
            Label {
                Text(.postComment)
                    .bold()
            } icon: {
                Image(systemSymbol: .squareAndPencil)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .clipShape(shape)
        }
        .glassEffect(.clear.interactive(), in: shape)
    }
}
