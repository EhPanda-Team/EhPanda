public import SwiftUI

/// Room after a horizontal row's last item, so the row can come to rest with that item's leading edge on the
/// content margin like every item before it.
///
/// A scroll view stops at the end of its content, which leaves the last page wherever the content happens to end:
/// the first item in view rests on the margin only if the content's length happens to be a whole number of
/// pages. The room is as wide as the scroll view's content area less the last item, so the last item can be
/// snapped to the margin as well. A row that fits in the scroll view gets none and does not scroll.
///
/// Apply it to the stack that carries `.scrollTargetLayout()`, directly inside the scroll view and after any
/// sizing: the room is a sibling of that stack, not one of its targets.
private struct RowEndRoom: ViewModifier {
    let lastItemWidth: CGFloat
    @State private var contentWidth: CGFloat = 0

    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            content
                .onWidthChange({ contentWidth = $0 })
            Color.clear
                .frame(height: 0)
                .containerRelativeFrame(.horizontal) { container, _ in
                    // `container` is the scroll view less its content margins: the width a page of items has.
                    lastItemWidth > 0 && contentWidth > container ? max(0, container - lastItemWidth) : 0
                }
                .accessibilityHidden(true)
        }
    }
}

extension View {
    /// Reports the view's width whenever it changes, for a row to learn how wide its last item is.
    public func onWidthChange(_ action: @escaping (CGFloat) -> Void) -> some View {
        onGeometryChange(for: CGFloat.self, of: { $0.size.width }, action: action)
    }

    /// Lets a horizontal row come to rest on its last item. `lastItemWidth` is that item's width, `0` while it
    /// is not yet known.
    public func rowEndRoom(lastItemWidth: CGFloat) -> some View {
        modifier(RowEndRoom(lastItemWidth: lastItemWidth))
    }
}
