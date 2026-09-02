import SwiftUI

/// A module-internal masonry `Layout` that replaces the third-party `WaterfallGrid` (DEP-04).
///
/// The column count uses the proposed width, preferred cell width, and caller-supplied floor.
/// There are no screen metrics, device-class, size-class, or idiom reads
/// anywhere in this type. All cells share one identical flexible width and a fixed 15pt
/// inter-item/inter-column spacing (D-21); leftover space always flows into the cell width, never
/// into the spacing (D-28). Items are placed in data order into the leftmost shortest column,
/// preserving `WaterfallGrid`'s masonry balancing (D-26/D-27).
///
/// The `spacing` / `defaultMinCellWidth` / `minColumns` constants are design knobs (D-23):
/// `m = 185` was frozen by the SR-1 spike sign-off after measuring real `proposal.width` at the
/// live call site (iPhone Air 380 → 2, iPad 11" portrait 794 → 4, landscape 1170 → 5 — all on the
/// expected bands). Any future adjustment is a one-constant change to `defaultMinCellWidth`.
///
/// The minimum cell width is an *instance* value rather than the constant itself, so a caller can
/// grow it with Dynamic Type: a cell whose text is drawn three times taller needs a proportionally
/// wider column, or it clips its badge, title and star row instead of reflowing. Passing it in
/// leaves the policy question at the call site — where the type ramp is already being read — and
/// leaves this type with nothing of its own to read; the default is the designed grid, so the
/// layout still answers the designed question by itself.
///
/// The caller supplies a viewport-dependent column floor: two normally, three on large landscape views.
///
/// Being a synchronous `Layout`, placement is computed in the same pass the `List` row is laid out,
/// so it sheds `WaterfallGrid`'s first-layout opacity flash and async placement hop (D-33) — a
/// strictly-beneficial deviation, not a behavior regression.
///
/// This type is intentionally **not** `public` (D-35): it is a private, documented masonry-layout
/// policy owned by `GalleryListComponents`, not an app-wide breakpoint system. Phase 5 may ratify or
/// replace the policy, and Phase 6's grid-atom extraction can lift it unchanged. The pure arithmetic
/// lives in `internal static` functions so the test target's `@testable import` can exercise them
/// value-in / value-out, without a live view tree.
struct MasonryLayout: Layout {
    /// Fixed inter-item / inter-column spacing (D-21). Never absorbs leftover width (D-28).
    static let spacing: CGFloat = 15
    /// The designed adaptive minimum cell width `m` (D-20), frozen at 185 by the SR-1 spike
    /// sign-off (D-23). It is what the column rule uses when it is asked without a width of its
    /// own, and the value a caller's `@ScaledMetric` grows from, so the designed grid is what
    /// renders at the designed text size.
    static let defaultMinCellWidth: CGFloat = 185
    /// Default lower clamp on the column count (D-25): two. A grid
    /// that falls to one full-width cell stops being a grid, so the floor is never lowered — not by
    /// a narrow container and not by a minimum that scaled text has grown past the container's
    /// width. There is deliberately no upper clamp.
    static let minColumns = 2

    /// The width one cell must be able to claim before the grid affords another column; scaled text
    /// asks for more of it. See ``defaultMinCellWidth``.
    let minCellWidth: CGFloat
    var minimumColumns: Int = 2

    /// Within-pass memo only — never a cross-pass height store (D-29). `updateCache` is not invoked on
    /// pure subview-size changes (image load), so any cached heights would go stale; heights are always
    /// re-measured in `sizeThatFits`.
    struct Cache {
        var proposalWidth: CGFloat?
        var columns: Int?
        var plan: MasonryPlan?
    }

    func makeCache(subviews: Subviews) -> Cache {
        Cache(proposalWidth: nil, columns: nil, plan: nil)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        // D-32: derive N only from a finite, positive width; degenerate probe proposals get a safe answer.
        guard let width = proposal.width, width.isFinite, width > 0 else {
            return CGSize(width: proposal.width ?? 0, height: 0)
        }
        let columns = resolvedColumnCount(for: width)
        let cellW = Self.cellWidth(containerWidth: width, columns: columns)
        // D-29: measure AFTER N and cellWidth are fixed; measurement never feeds back into N.
        let heights = subviews.map({ $0.sizeThatFits(.init(width: cellW, height: nil)).height })
        let plan = Self.masonryPlan(heights: heights, columns: columns, cellWidth: cellW, spacing: Self.spacing)
        cache.proposalWidth = width
        cache.columns = columns
        cache.plan = plan
        return CGSize(width: width, height: plan.size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        guard let width = proposal.width, width.isFinite, width > 0 else { return }
        let columns = resolvedColumnCount(for: width)
        let cellW = Self.cellWidth(containerWidth: width, columns: columns)
        // Reuse this pass's plan when the geometry it was planned against is unchanged; otherwise
        // re-measure and re-plan. The column count is part of that key rather than the width alone:
        // the caller's minimum cell width can change by itself (Dynamic Type) and re-column the very
        // same container, and cached origins would then describe a different grid than `cellW` does.
        let plan = (cache.proposalWidth == width && cache.columns == columns ? cache.plan : nil)
            ?? Self.masonryPlan(
                heights: subviews.map({ $0.sizeThatFits(.init(width: cellW, height: nil)).height }),
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
    /// ``columnCount(for:minCellWidth:)`` asked under this pass's own minimum cell width.
    func resolvedColumnCount(for width: CGFloat) -> Int {
        max(minimumColumns, Self.columnCount(for: width, minCellWidth: minCellWidth))
    }

    /// `GridItem(.adaptive(minimum:))` semantics from the container width alone (D-20).
    /// Clamps degenerate widths — nil is unreachable here, but 0 / negative / infinite / NaN all
    /// fall back to `minColumns` (D-32). `Int(_:)` truncates toward zero, which equals floor for w > 0.
    /// No hysteresis (D-24).
    ///
    /// The minimum defaults to the designed constant, so this stays the designed rule whenever it
    /// is asked the designed question. A minimum that scaled text has grown past the container
    /// fits zero columns and the floor answers with two, each half the container wide: past that
    /// point the container, not the minimum, is what sets the cell width (P-07).
    static func columnCount(for width: CGFloat, minCellWidth: CGFloat = defaultMinCellWidth) -> Int {
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
    /// equality. `min(by:)` replaces its running minimum only on a strict `<`, so it keeps the
    /// leftmost tie too. Do not "improve" it to `<=` or a tolerance compare — that would break it.
    static func masonryPlan(
        heights: [CGFloat], columns: Int, cellWidth: CGFloat, spacing: CGFloat
    ) -> MasonryPlan {
        var columnHeights = Array(repeating: CGFloat.zero, count: columns)
        var origins: [CGPoint] = []
        for height in heights {
            let column = columnHeights.enumerated().min { $0.element < $1.element }?.offset ?? 0
            origins.append(CGPoint(x: CGFloat(column) * (cellWidth + spacing), y: columnHeights[column]))
            columnHeights[column] += height + spacing
        }
        let totalHeight = max(0, (columnHeights.max() ?? spacing) - spacing)
        let totalWidth = CGFloat(columns) * cellWidth + CGFloat(columns - 1) * spacing
        return MasonryPlan(origins: origins, size: CGSize(width: totalWidth, height: totalHeight))
    }
}
