import SwiftUI

/// A horizontal stack that falls back to a vertical one as soon as its content stops fitting the
/// width it is offered.
///
/// A row that pairs a leading member with a trailing one — a value and its unit, a name and a
/// status, a rating and a count — has no width left to give once Dynamic Type grows the text: the
/// members ellipsise, or an over-constrained `HStack` lets them spill over one another.
/// `ViewThatFits(in: .horizontal)` measures the members at their *ideal*, untruncated width, so
/// the designed row survives exactly as long as every member fits it whole and then gives way to
/// a stack in which each member owns a full-width line. Both candidates render the very same
/// `content`, so the two layouts cannot drift apart as the row is edited.
///
/// `hSpaceBetween` interleaves `Spacer()`s between the members of the *horizontal* candidate only,
/// which is what lets the pair read as "leading value … trailing value" while it is a row and as a
/// plain leading-aligned stack once it is not. A lone visible member still gets its trailing
/// spacer, so it anchors leading instead of floating in the middle of the row.
///
/// Two rules the call sites have to respect:
/// - A flexible `.frame(maxWidth: .infinity)` belongs *outside* this view. Inside a candidate it
///   absorbs the overflow, every candidate then measures as fitting, and the fallback never wins.
/// - Anything conditional inside `content` participates in **both** candidates, and a `Spacer()`
///   that merely separates a row turns into a vertical expander once the content stacks. Build a
///   pair with an optional member from an explicit `ViewThatFits` whose candidates own their own
///   spacers and line limits instead of from this view.
///
/// This view deliberately reads no size or size class: whether the designed row still fits is a
/// question about the offered width, and content whose ideal width is unbounded — wrapping body
/// text, a flowing tag cloud — must not be measured this way at all, because no candidate
/// containing it can ever report a fitting ideal width.
public struct AdaptiveStack<Content: View>: View {
    private let hSpaceBetween: Bool
    private let hSpacing: CGFloat?
    private let hAlignment: VerticalAlignment
    private let vSpacing: CGFloat?
    private let vAlignment: HorizontalAlignment
    private let content: Content

    public init(
        hSpaceBetween: Bool = false,
        hSpacing: CGFloat? = nil,
        hAlignment: VerticalAlignment = .center,
        vSpacing: CGFloat? = nil,
        vAlignment: HorizontalAlignment = .leading,
        @ContentBuilder content: () -> Content
    ) {
        self.hSpaceBetween = hSpaceBetween
        self.hSpacing = hSpacing
        self.hAlignment = hAlignment
        self.vSpacing = vSpacing
        self.vAlignment = vAlignment
        self.content = content()
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: hAlignment, spacing: hSpacing) {
                if hSpaceBetween {
                    spacedContent
                } else {
                    content
                }
            }
            VStack(alignment: vAlignment, spacing: vSpacing) {
                content
            }
        }
    }

    private var spacedContent: some View {
        Group(subviews: content) { subviews in
            ForEach(Array(subviews.enumerated()), id: \.element.id) { offset, subview in
                subview
                if offset < subviews.count - 1 || subviews.count <= 1 {
                    Spacer()
                }
            }
        }
    }
}

#Preview("Pair that fits", traits: .sizeThatFitsLayout) {
    AdaptiveStack(hSpaceBetween: true) {
        Text(verbatim: "Uploader")
        Text(verbatim: "English")
    }
    .frame(width: 300)
    .padding()
}

#Preview("Pair that stacks", traits: .sizeThatFitsLayout) {
    AdaptiveStack(hSpaceBetween: true) {
        Text(verbatim: "A considerably longer uploader")
        Text(verbatim: "Traditional Chinese")
    }
    .frame(width: 200)
    .padding()
}

#Preview("Lone member anchors leading", traits: .sizeThatFitsLayout) {
    AdaptiveStack(hSpaceBetween: true) {
        Text(verbatim: "English")
    }
    .frame(width: 300)
    .padding()
}

#Preview("Accessibility size", traits: .sizeThatFitsLayout) {
    AdaptiveStack(hSpaceBetween: true) {
        Text(verbatim: "Uploader")
        Text(verbatim: "English")
    }
    .frame(width: 300)
    .padding()
    .environment(\.dynamicTypeSize, .accessibility3)
}
