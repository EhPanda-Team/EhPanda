import CoreGraphics
import Foundation
@testable import GalleryListComponents
import Testing

// Wave-1 parity lock for DEP-04. These cases freeze the pure arithmetic of `MasonryLayout` — the
// adaptive column-count rule (m=185, s=15, min-2), the degenerate-width clamp, the exact `cellWidth`
// division, and the leftmost-shortest-column placement planner — independently of the SR-1 spike.
// The pure functions are `internal`, so `@testable import` is required (unlike the `ImageColors`
// public-import analog). The widths are illustrative content-width estimates; Plan 02's spike
// measures the real `proposal.width` and any adjustment is a one-constant change to `m` (D-23).
@Suite
struct MasonryLayoutTests {
    @Test
    func largeLandscapeFloorSurvivesAccessibilityScaling() {
        let layout = MasonryLayout(minCellWidth: 590, minimumColumns: 3)
        #expect(layout.resolvedColumnCount(for: 1170) == 3)
        #expect(MasonryLayout(minCellWidth: 185, minimumColumns: 3).resolvedColumnCount(for: 1170) == 5)
        #expect(MasonryLayout(minCellWidth: 590).resolvedColumnCount(for: 650) == 2)
    }

    // Asserts the formula `max(2, floor((w + 15) / (185 + 15)))` at the sign-off widths (D-20).
    // 990 → 5 because floor((990 + 15) / 200) = 5; the CONTEXT "13-inch iPad portrait → 4" note is a
    // Wave-2 spike sign-off item (whether real measured 13" width yields 4 or 5, and any `m` tweak),
    // NOT a Wave-1 assertion — Wave-1 asserts the arithmetic truth.
    @Test(arguments: zip(
        [335, 408, 710, 790, 990, 1040, 1140, 1336, 320] as [CGFloat],
        [2, 2, 3, 4, 5, 5, 5, 6, 2]
    ))
    func columnCountFollowsAdaptiveRule(width: CGFloat, expected: Int) {
        #expect(MasonryLayout.columnCount(for: width) == expected)
    }

    // D-32: degenerate widths (zero, negative, infinite, NaN) all clamp to `minColumns` (2).
    @Test(arguments: [0, -100, CGFloat.infinity, CGFloat.nan] as [CGFloat])
    func degenerateWidthsClampToMin(width: CGFloat) {
        #expect(MasonryLayout.columnCount(for: width) == MasonryLayout.minColumns)
    }

    // Phase 16: the same rule asked under a caller's scaled minimum. A minimum the container can no
    // longer fit as often sheds columns, and the designed floor still holds underneath it — the
    // phone keeps the two columns it has at the designed size (D-25 parity) even though the strict
    // rule fits only one there.
    @Test
    func scaledMinimumShedsColumnsUnderTheDesignedFloor() {
        #expect(MasonryLayout.columnCount(for: 380, minCellWidth: 250) == 2)
        #expect(MasonryLayout.columnCount(for: 794, minCellWidth: 250) == 3)
        #expect(MasonryLayout.columnCount(for: 1170, minCellWidth: 250) == 4)
    }

    // Two columns is the floor at every text size (owner, 2026-09-03), so no scaled minimum can
    // ever produce a single full-width cell. 590 is the designed 185 grown to AX5 (callout 51/16),
    // which is wider than a phone's whole container and wider than half an iPad's: the strict rule
    // fits one column or none on all three, and the floor answers with two on all three. Past that
    // point the container sets the cell width — a 415pt phone row splits into two 200pt columns.
    @Test
    func floorHoldsAtTwoColumnsForAnyScaledMinimum() {
        #expect(MasonryLayout.columnCount(for: 415, minCellWidth: 590) == 2)
        #expect(MasonryLayout.columnCount(for: 794, minCellWidth: 590) == 2)
        #expect(MasonryLayout.columnCount(for: 1170, minCellWidth: 590) == 2)
        #expect(MasonryLayout.cellWidth(containerWidth: 415, columns: 2) == 200)
    }

    // D-21/D-28: exact `(w − 15·(N−1)) / N` with no rounding. 4 cols @ 790 → (790 − 45) / 4 = 186.25.
    @Test
    func cellWidthExactDivision() {
        #expect(MasonryLayout.cellWidth(containerWidth: 790, columns: 4) == 186.25)
    }

    // D-26 leftmost tie + D-27 `max(0, tallest − spacing)` height. Three equal 100pt cells over two
    // 160pt columns tile A→B→A: origins x [0, 175, 0], y [0, 0, 115], total height 230 − 15 = 215.
    @Test
    func placementIsLeftmostShortestColumn() {
        let plan = MasonryLayout.masonryPlan(
            heights: [100, 100, 100], columns: 2, cellWidth: 160, spacing: 15
        )
        #expect(plan.origins.map(\.x) == [0, 175, 0])
        #expect(plan.origins.map(\.y) == [0, 0, 115])
        #expect(plan.size.height == 215)
    }
}
