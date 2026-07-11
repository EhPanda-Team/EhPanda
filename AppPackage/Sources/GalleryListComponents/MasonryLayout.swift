import SwiftUI

/// A module-internal masonry `Layout` that replaces the third-party `WaterfallGrid` (DEP-04).
///
/// The column count is derived **solely** from the proposed container width (D-20): there is no
/// `UIScreen` / `DeviceUtil` / size-class / idiom read anywhere in this type. All cells share one
/// identical flexible width and a fixed 15pt inter-item/inter-column spacing (D-21); leftover space
/// always flows into the cell width, never into the spacing (D-28). Items are placed in data order
/// into the leftmost shortest column, preserving `WaterfallGrid`'s masonry balancing (D-26/D-27).
///
/// The `spacing` / `minCellWidth` / `minColumns` constants are design knobs (D-23): the `m = 185`
/// value is provisional and is frozen only after the SR-1 spike sign-off measures real
/// `proposal.width` at the live call site. Any adjustment is a one-constant change to `minCellWidth`.
///
/// This type is intentionally **not** `public` (D-35): it is a private, documented masonry-layout
/// policy owned by `GalleryListComponents`, not an app-wide breakpoint system. Phase 5 may ratify or
/// replace the policy. The pure arithmetic lives in `internal static` functions so the test target's
/// `@testable import` can exercise them value-in / value-out, without a live view tree.
struct MasonryLayout: Layout {
    /// Fixed inter-item / inter-column spacing (D-21). Never absorbs leftover width (D-28).
    static let spacing: CGFloat = 15
    /// The adaptive minimum cell width `m` (D-20). A design knob, frozen only after SR-1 sign-off (D-23).
    static let minCellWidth: CGFloat = 185
    /// Lower clamp on the column count (D-25). There is deliberately no upper clamp.
    static let minColumns = 2

    /// Within-pass memo only — never a cross-pass height store (D-29). `updateCache` is not invoked on
    /// pure subview-size changes (image load), so any cached heights would go stale; heights are always
    /// re-measured in `sizeThatFits`.
    struct Cache {
        var proposalWidth: CGFloat?
        var plan: MasonryPlan?
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(proposalWidth: nil, plan: nil)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        // D-32: derive N only from a finite, positive width; degenerate probe proposals get a safe answer.
        guard let width = proposal.width, width.isFinite, width > 0 else {
            return CGSize(width: proposal.width ?? 0, height: 0)
        }
        let columns = Self.columnCount(for: width)
        let cellW = Self.cellWidth(containerWidth: width, columns: columns)
        // D-29: measure AFTER N and cellWidth are fixed; measurement never feeds back into N.
        let heights = subviews.map { $0.sizeThatFits(.init(width: cellW, height: nil)).height }
        let plan = Self.masonryPlan(heights: heights, columns: columns, cellWidth: cellW, spacing: Self.spacing)
        cache.proposalWidth = width
        cache.plan = plan
        return CGSize(width: width, height: plan.size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        guard let width = proposal.width, width.isFinite, width > 0 else { return }
        let columns = Self.columnCount(for: width)
        let cellW = Self.cellWidth(containerWidth: width, columns: columns)
        // Reuse this pass's plan when the width is unchanged; otherwise re-measure and re-plan.
        let plan = (cache.proposalWidth == width ? cache.plan : nil)
            ?? Self.masonryPlan(
                heights: subviews.map { $0.sizeThatFits(.init(width: cellW, height: nil)).height },
                columns: columns, cellWidth: cellW, spacing: Self.spacing
            )
        for (subview, origin) in zip(subviews, plan.origins) {
            subview.place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .init(width: cellW, height: nil)
            )
        }
    }
}

/// The pure, testable output of a masonry layout pass: per-item origins plus the total content size.
struct MasonryPlan: Equatable {
    var origins: [CGPoint]
    var size: CGSize
}

extension MasonryLayout {
    /// `GridItem(.adaptive(minimum:))` semantics from the container width alone (D-20).
    /// Clamps degenerate widths — nil is unreachable here, but 0 / negative / infinite / NaN all
    /// fall back to `minColumns` (D-32). `Int(_:)` truncates toward zero, which equals floor for w > 0.
    /// No hysteresis (D-24).
    static func columnCount(for width: CGFloat) -> Int {
        guard width.isFinite, width > 0 else { return minColumns }
        return max(minColumns, Int((width + spacing) / (minCellWidth + spacing)))
    }

    /// Exact division (D-21/D-28): leftover space becomes cell width, never spacing. No rounding.
    static func cellWidth(containerWidth width: CGFloat, columns: Int) -> CGFloat {
        (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
    }

    /// Places `heights` in data order into the leftmost shortest column (D-26), reporting total height
    /// `max(0, tallestColumn − spacing)` (D-27). Mirrors `WaterfallGrid.alignmentsAndGridHeight`.
    ///
    /// The strict `<` first-minimum scan is provably identical to `heights.min()` +
    /// `firstIndex(of:)`: both return the first index attaining the minimum, using exact CGFloat
    /// equality. Do not "improve" it to `<=` or a tolerance compare — that would break the leftmost tie.
    static func masonryPlan(
        heights: [CGFloat], columns: Int, cellWidth: CGFloat, spacing: CGFloat
    ) -> MasonryPlan {
        var columnHeights = Array(repeating: CGFloat.zero, count: columns)
        var origins: [CGPoint] = []
        for height in heights {
            var column = 0
            for index in 1..<columns where columnHeights[index] < columnHeights[column] {
                column = index
            }
            origins.append(CGPoint(x: CGFloat(column) * (cellWidth + spacing), y: columnHeights[column]))
            columnHeights[column] += height + spacing
        }
        let totalHeight = max(0, (columnHeights.max() ?? spacing) - spacing)
        let totalWidth = CGFloat(columns) * cellWidth + CGFloat(columns - 1) * spacing
        return MasonryPlan(origins: origins, size: CGSize(width: totalWidth, height: totalHeight))
    }
}
