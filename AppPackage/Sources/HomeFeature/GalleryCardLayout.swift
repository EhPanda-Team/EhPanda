import SwiftUI

/// Resolves the card's cover, title and rating together, before the lazy carousel measures height.
/// A geometry-state round trip would let its initial narrow arrangement seed a stale tall estimate.
struct GalleryCardLayout: Layout {
    let isAccessibilitySize: Bool

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        placement(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let plan = placement(proposal: .init(width: bounds.width, height: nil), subviews: subviews)
        for (subview, frame) in zip(subviews, plan.frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private struct Placement {
        var size: CGSize
        var frames: [CGRect]
    }

    private func placement(proposal: ProposedViewSize, subviews: Subviews) -> Placement {
        guard let cover = subviews.first,
              let text = subviews.dropFirst().first
        else { return Placement(size: .zero, frames: []) }

        let coverSize = cover.sizeThatFits(.unspecified)
        let width = proposal.width ?? coverSize.width + 23 + 200
        let stacks = isAccessibilitySize && width < 550
        let textWidth = stacks ? width : max(0, width - coverSize.width - 23)
        let textSize = text.sizeThatFits(.init(width: textWidth, height: nil))
        let textOrigin = stacks
            ? CGPoint(x: 0, y: coverSize.height + 12)
            : CGPoint(x: coverSize.width + 23, y: 0)
        return Placement(
            size: CGSize(width: width, height: max(coverSize.height, textOrigin.y + textSize.height)),
            frames: [
                CGRect(origin: .zero, size: coverSize),
                CGRect(origin: textOrigin, size: CGSize(width: textWidth, height: textSize.height))
            ]
        )
    }
}
