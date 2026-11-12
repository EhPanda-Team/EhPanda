import SwiftUI

/// Two rows of covers that share their column widths and row heights, like a two-row `Grid`.
///
/// The subviews are the top row followed by the bottom row, so a column is a cell and the cell
/// `columnCount` places after it. They are direct children of this layout, which is what lets
/// `.scrollTargetLayout()` snap the wall one column at a time: a `Grid`'s children are its rows, and
/// each row spans every column.
///
/// Sizes and positions match the `Grid(alignment: .topLeading)` this replaces: a column is as wide as
/// its widest cell, a row as tall as its tallest, and each cell sits at the top leading corner of its
/// slot. A taller cover in one column therefore still moves the whole bottom row, not just its own.
struct HomeCoverWallLayout: Layout {
    let columnSpacing: CGFloat
    let rowSpacing: CGFloat

    private struct Measurements {
        let topRow: [LayoutSubview]
        let bottomRow: [LayoutSubview]
        let columnWidths: [CGFloat]
        let topHeight: CGFloat
        let bottomHeight: CGFloat

        init(_ subviews: LayoutSubviews) {
            let columnCount = (subviews.count + 1) / 2
            topRow = Array(subviews.prefix(columnCount))
            bottomRow = Array(subviews.dropFirst(columnCount))
            let topSizes = topRow.map({ $0.sizeThatFits(.unspecified) })
            let bottomSizes = bottomRow.map({ $0.sizeThatFits(.unspecified) })
            columnWidths = (0..<columnCount).map { column in
                max(
                    topSizes.dropFirst(column).first?.width ?? 0,
                    bottomSizes.dropFirst(column).first?.width ?? 0
                )
            }
            topHeight = topSizes.map(\.height).max() ?? 0
            bottomHeight = bottomSizes.map(\.height).max() ?? 0
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }
        let measurements = Measurements(subviews)
        let gaps = columnSpacing * CGFloat(measurements.columnWidths.count - 1)
        return CGSize(
            width: measurements.columnWidths.reduce(0, +) + gaps,
            height: measurements.topHeight
                + (measurements.bottomRow.isEmpty ? 0 : rowSpacing + measurements.bottomHeight)
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let measurements = Measurements(subviews)
        let bottomOrigin = bounds.minY + measurements.topHeight + rowSpacing
        var leadingEdge = bounds.minX
        for (column, width) in measurements.columnWidths.enumerated() {
            measurements.topRow.dropFirst(column).first?.place(
                at: CGPoint(x: leadingEdge, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: measurements.topHeight)
            )
            measurements.bottomRow.dropFirst(column).first?.place(
                at: CGPoint(x: leadingEdge, y: bottomOrigin),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: measurements.bottomHeight)
            )
            leadingEdge += width + columnSpacing
        }
    }
}
