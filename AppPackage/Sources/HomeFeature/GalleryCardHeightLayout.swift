import SwiftUI

/// Proposes the viewport ceiling without expanding a shorter card to fill that ceiling.
struct GalleryCardHeightLayout: Layout {
    let maximumHeight: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let size = content.sizeThatFits(.init(width: proposal.width, height: maximumHeight))
        return CGSize(width: size.width, height: min(size.height, maximumHeight ?? size.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}
