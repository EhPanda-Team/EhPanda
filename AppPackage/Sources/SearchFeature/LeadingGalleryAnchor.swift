import AppModels
import SwiftUI
import UIKit

/// What the Recently Viewed row remembers between updates. It is read when the galleries change and never drawn, so it
/// is a plain object: a width kept in `@State` would redraw the row.
@MainActor final class LeadingGalleryKeeper {
    var cardWidth: CGFloat = 0
    fileprivate var galleryIDs: [Gallery.ID] = []
}

/// Keeps the cards of Recently Viewed where they are when a gallery is added before them.
///
/// A gallery that is viewed lands at the front of the row. Left alone, the scroll view keeps its offset and every card
/// on screen moves a place to the right. Carrying the offset on afterwards, from `ScrollPosition` or from a
/// `scrollPosition(id:)` binding, runs after the cards have been laid out at the old offset, and the run loop turn in
/// between reaches the screen. So the offset moves here, while the update that adds the cards is still running: the
/// scroll view is laid out once, with the new cards and the new offset, and no frame shows the one without the other.
struct LeadingGalleryAnchor: UIViewRepresentable {
    let keeper: LeadingGalleryKeeper
    let galleryIDs: [Gallery.ID]
    let spacing: CGFloat
    let inset: CGFloat

    /// Tells the first update of a row's scroll view, which has no earlier galleries to keep.
    final class Coordinator {
        var hasUpdated = false
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Self.Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Self.Context) {
        let old = keeper.galleryIDs
        keeper.galleryIDs = galleryIDs
        defer { context.coordinator.hasUpdated = true }
        guard context.coordinator.hasUpdated, keeper.cardWidth > 0, !old.isEmpty,
              let scrollView = view.enclosingScrollView else { return }
        let step = keeper.cardWidth + spacing
        let offset = scrollView.contentOffset.x
        let leading = min(max(Int(((offset + inset) / step).rounded()), 0), old.count - 1)
        guard let moved = galleryIDs.firstIndex(of: old[leading]), moved != leading else { return }
        scrollView.contentOffset.x = offset + CGFloat(moved - leading) * step
    }
}

private extension UIView {
    var enclosingScrollView: UIScrollView? {
        var view = superview
        while let current = view {
            if let scrollView = current as? UIScrollView { return scrollView }
            view = current.superview
        }
        return nil
    }
}
