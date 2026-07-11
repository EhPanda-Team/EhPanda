import Testing
import Foundation
import CoreGraphics
@testable import GalleryListComponents

// Wave-1 parity lock for DEP-04. These cases freeze the pure arithmetic of `MasonryLayout` — the
// adaptive column-count rule (m=185, s=15, min-2), the degenerate-width clamp, the exact `cellWidth`
// division, and the leftmost-shortest-column placement planner — independently of the SR-1 spike.
// The pure functions are `internal`, so `@testable import` is required (unlike the `ImageColors`
// public-import analog). The widths are illustrative content-width estimates; Plan 02's spike
// measures the real `proposal.width` and any adjustment is a one-constant change to `m` (D-23).
@Suite
struct MasonryLayoutTests {
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
