---
phase: 02-native-masonry-grid-swap
plan: 01
subsystem: ui
tags: [swiftui, layout, masonry, waterfallgrid, swift-testing, spm]

# Dependency graph
requires:
  - phase: 01-dependency-removal
    provides: GalleryListComponents module, ImageColorsTests test-target precedent, standalone SwiftLint config pattern
provides:
  - Module-internal MasonryLayout (SwiftUI Layout) with a pure, unit-testable arithmetic core
  - columnCount(for:) adaptive column rule with degenerate-width clamp (D-20, D-24, D-25, D-32)
  - cellWidth(containerWidth:columns:) exact division (D-21, D-28)
  - masonryPlan(heights:columns:cellWidth:spacing:) leftmost-shortest-column planner (D-26, D-27)
  - GalleryListComponentsTests test target (Wave-0 gap), registered in Package.swift + FeatureTests.xctestplan
affects: [02-02 spike wiring, 02-03, 02-04 WaterfallGrid removal, phase-05 layout-policy ratification]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Layout conformance delegates all arithmetic to internal static pure functions (value-in/value-out testable seam)"
    - "New test target carries its own parent_config .swiftlint.yml and a FeatureTests.xctestplan entry"

key-files:
  created:
    - AppPackage/Sources/GalleryListComponents/MasonryLayout.swift
    - AppPackage/Tests/GalleryListComponentsTests/MasonryLayoutTests.swift
    - AppPackage/Tests/GalleryListComponentsTests/.swiftlint.yml
  modified:
    - AppPackage/Package.swift
    - AppPackage/Tests/FeatureTests.xctestplan

key-decisions:
  - "Pure functions kept internal (not private/public) so @testable import reaches them; MasonryLayout itself stays module-internal, never public (D-35)"
  - "Wave-1 asserts the arithmetic truth (990 → 5 columns); the CONTEXT 13-inch-portrait→4 note is a Wave-2 spike sign-off item, not a Wave-1 assertion (D-23)"
  - "DEP-04 left unmarked — it is a phase-level requirement satisfied only when Plan 04 swaps WaterfallGrid at the call site; this plan is the spike-independent foundation only"

patterns-established:
  - "Pattern 1: MasonryLayout: Layout is thin — sizeThatFits/placeSubviews delegate to static columnCount/cellWidth/masonryPlan"
  - "Pattern 2: within-pass Cache memo only, never a cross-pass height store (D-29)"

requirements-completed: []  # DEP-04 spans the whole phase; not completed by Plan 01 alone

coverage:
  - id: D1
    description: "columnCount(for:) follows max(2, floor((w+15)/200)) at the sign-off widths (335,408,710,790,990,1040,1140,1336,320)"
    requirement: DEP-04
    verification:
      - kind: unit
        ref: "AppPackage/Tests/GalleryListComponentsTests/MasonryLayoutTests.swift#columnCountFollowsAdaptiveRule"
        status: pass
    human_judgment: false
  - id: D2
    description: "Degenerate widths (0, negative, infinity, NaN) clamp to minColumns (D-32)"
    requirement: DEP-04
    verification:
      - kind: unit
        ref: "AppPackage/Tests/GalleryListComponentsTests/MasonryLayoutTests.swift#degenerateWidthsClampToMin"
        status: pass
    human_judgment: false
  - id: D3
    description: "cellWidth divides leftover space exactly with no rounding (D-21, D-28)"
    requirement: DEP-04
    verification:
      - kind: unit
        ref: "AppPackage/Tests/GalleryListComponentsTests/MasonryLayoutTests.swift#cellWidthExactDivision"
        status: pass
    human_judgment: false
  - id: D4
    description: "masonryPlan places items into the leftmost shortest column with exact tie handling and reports max(0, tallest-spacing) height (D-26, D-27)"
    requirement: DEP-04
    verification:
      - kind: unit
        ref: "AppPackage/Tests/GalleryListComponentsTests/MasonryLayoutTests.swift#placementIsLeftmostShortestColumn"
        status: pass
    human_judgment: false
  - id: D5
    description: "GalleryListComponentsTests target exists, is registered in Package.swift + FeatureTests.xctestplan, and its suite is green via AppPackage-Package"
    requirement: DEP-04
    verification:
      - kind: integration
        ref: "xcodebuild test -scheme AppPackage-Package -only-testing:GalleryListComponentsTests"
        status: pass
    human_judgment: false

# Metrics
duration: 8min
completed: 2026-07-11
status: complete
---

# Phase 2 Plan 1: Masonry Layout Pure Core Summary

**Module-internal `MasonryLayout: Layout` whose adaptive column-count, exact cell-width, and leftmost-shortest-column masonry arithmetic live in pure `internal static` functions, locked by a green Swift Testing suite in the new `GalleryListComponentsTests` target.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-11T02:21:29Z
- **Completed:** 2026-07-11T02:29:12Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Landed `MasonryLayout.swift`: a module-internal `Layout` whose `sizeThatFits`/`placeSubviews` are thin, delegating all arithmetic to `columnCount(for:)`, `cellWidth(containerWidth:columns:)`, and `masonryPlan(heights:columns:cellWidth:spacing:)`.
- Column rule `max(2, floor((w+15)/(185+15)))` with a degenerate-width clamp (nil/0/negative/∞/NaN → 2), exact cell-width division, and a strict first-minimum placement scan that preserves WaterfallGrid's leftmost-tie masonry balancing — no force-unwrap (`?? spacing`, not `.max()!`).
- Stood up the missing `GalleryListComponentsTests` target (Wave-0 gap): registered in `Package.swift` and `FeatureTests.xctestplan`, carrying its own `parent_config` SwiftLint config, with a 4-case Swift Testing suite (13 total cases across the parametrized tables) all green.

## Task Commits

Each task was committed atomically:

1. **Task 1: Create MasonryLayout.swift with the pure core and thin Layout conformance** - `174fcb93` (feat)
2. **Task 2: Create the GalleryListComponentsTests target and its parity suite** - `7002f6e1` (test)

**Plan metadata:** committed separately (docs: complete plan).

## Files Created/Modified
- `AppPackage/Sources/GalleryListComponents/MasonryLayout.swift` - New module-internal `MasonryLayout: Layout` + `MasonryPlan` + the three pure static functions + within-pass `Cache`.
- `AppPackage/Tests/GalleryListComponentsTests/MasonryLayoutTests.swift` - New Swift Testing parity suite (column-count table, degenerate clamp, exact cellWidth, leftmost-shortest placement).
- `AppPackage/Tests/GalleryListComponentsTests/.swiftlint.yml` - New `parent_config: ../../../.swiftlint.yml` link.
- `AppPackage/Package.swift` - Added `galleryListComponentsTests` Module case + its `.testTarget`.
- `AppPackage/Tests/FeatureTests.xctestplan` - Added the `GalleryListComponentsTests` entry.

## Decisions Made
- Kept the three pure functions `internal static` (not private, not public) so `@testable import GalleryListComponents` reaches them, while `MasonryLayout` itself stays module-internal (D-35).
- Wave-1 asserts arithmetic truth (990 → 5); the "13-inch portrait → 4" CONTEXT note is deferred to the Wave-2 spike sign-off as a one-constant `m` adjustment (D-23).
- Did not mark DEP-04 complete: it is a phase-level requirement satisfied only when Plan 04 swaps the live call site. This plan is the spike-independent foundation and wires no call site.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Build/test destination simulator unavailable**
- **Found during:** Task 1 (build verification)
- **Issue:** The plan's `<verify>` blocks specify `-destination 'platform=iOS Simulator,name=iPhone 16 Pro'`, but that simulator is not installed on this machine (available: iPhone 17e, iPhone Air, iPad Pro 11-inch M5). The exact-name destination also failed to resolve, so the build/test could not run as written.
- **Fix:** Ran `xcodebuild` against the already-booted iPhone Air simulator by device id (`id=ADE09605-A44E-4F00-BE12-235970217355`). No source or plan-logic change — only the local run destination.
- **Files modified:** None (environment/tooling only).
- **Verification:** `xcodebuild build` → BUILD SUCCEEDED; `xcodebuild test -only-testing:GalleryListComponentsTests` → TEST SUCCEEDED (4 tests / 1 suite).
- **Committed in:** n/a (no file change).

**2. [Rule 1 - Bug] SwiftLint identifier_name rejected single-letter parameter names**
- **Found during:** Task 1 (build verification)
- **Issue:** The RESEARCH-provided signatures used `w`/`n` internal parameter names in `cellWidth`/`masonryPlan`; the root SwiftLint `identifier_name` rule (error) requires 3–40 characters, failing the build.
- **Fix:** Renamed the internal parameter names to `width`/`columns` (external argument labels `containerWidth:`/`columns:` unchanged, so the public-to-tests API and the test call sites are unaffected).
- **Files modified:** AppPackage/Sources/GalleryListComponents/MasonryLayout.swift
- **Verification:** Clean build, SwiftLint plugin passes, suite green.
- **Committed in:** `174fcb93` (Task 1 commit).

---

**Total deviations:** 2 auto-fixed (1 blocking-environment, 1 lint bug)
**Impact on plan:** Both were necessary to build/run at all; no scope creep and no behavior change. The simulator substitution is local-machine-only — future runs should use whatever iOS 17+ simulator is installed, not hard-code iPhone 16 Pro.

## Issues Encountered
- Pre-existing warning `variable 'state' was never mutated` in `DownloadsFeatureTests/ReadingReducerLocalTests.swift` surfaced during the test build. Out of scope (unrelated file, not caused by this plan) — left untouched.
- A pre-existing uncommitted STATE.md normalization (phase `2`→`02`, total_plans `9`→`13`) was in the working tree at plan start; it folds into this plan's metadata commit.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- The pure core and `Layout` conformance are ready for Plan 02's SR-1 spike to wire a real `MasonryLayout` into `WaterfallList` (`GenericList.swift`) and measure live `proposal.width`.
- Open item for Plan 02: confirm `m = 185` against measured content width and confirm `.animation(nil, value:)` suppresses placement animation inside a `List` row (Pattern 3 / `[ASSUMED]`).
- No call site references `MasonryLayout` yet; existing thumbnail-grid behavior is unchanged.

## Self-Check: PASSED

- All created files exist on disk (MasonryLayout.swift, MasonryLayoutTests.swift, test target .swiftlint.yml, SUMMARY.md).
- Both task commits present in history (`174fcb93`, `7002f6e1`).
- Acceptance greps: `galleryListComponentsTests` x2 in Package.swift, `parent_config` present, `@testable import` present, xctestplan entry present, `?? spacing` present, no force-unwrap, `MasonryLayout` not public.

---
*Phase: 02-native-masonry-grid-swap*
*Completed: 2026-07-11*
