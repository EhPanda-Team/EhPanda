---
phase: 02-native-masonry-grid-swap
plan: 02
subsystem: ui
tags: [swiftui, layout, masonry, spike, pagination, waterfallgrid]

# Dependency graph
requires:
  - phase: 02-native-masonry-grid-swap (plan 01)
    provides: MasonryLayout pure core + thin Layout conformance, GalleryListComponentsTests target
provides:
  - SR-1 spike sign-off (GO) — masonry balancing, reflow-on-load, animation suppression, scrolling all confirmed on the reference sweep
  - Measured proposal.width column-count table (iPhone Air 380→2, iPad 11" portrait 794→4, iPad 11" landscape 1170→5)
  - Frozen m = 185 (owner decision keep-185; matches CONTEXT expected counts exactly — no adjustment)
  - Owner-requested auto-load pagination for the thumbnail grid (D-36, amends D-30) — committed candidate wiring
affects: [02-03 production swap (must preserve auto-load + remove temp GenericList logger), 02-04 dependency removal]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Auto-pagination driven by List scroll geometry (onScrollGeometryChange) gated on a user-driven scroll phase (onScrollPhaseChange) + once-per-galleries.count, with the FetchMoreFooter inside the single masonry row to avoid List bottom-anchoring"

key-files:
  created: []
  modified:
    - AppPackage/Sources/GalleryListComponents/MasonryLayout.swift
    - AppPackage/Sources/GalleryListComponents/GenericList.swift
    - AppPackage/Package.swift

key-decisions:
  - "SR-1 = GO (owner): the custom Layout reproduces masonry balancing + reflow-on-load (A2) + animation suppression (A1/D-31) + smooth scrolling (SR-3); no blocker surfaced"
  - "m frozen at 185 (owner keep-185): the three measured widths land exactly on the CONTEXT expected counts; no code change, Plan 01 columnCount test table already correct"
  - "Animation suppression achieved with .animation(nil, value: galleries) alone — no .transaction fallback needed; no cell-sliding observed across appends"
  - "D-36 (amends D-30, owner request): thumbnail grid pagination changed from the manual chevron footer to automatic load-on-scroll, mirroring detail mode"

# Coverage
coverage:
  - id: D1
    description: "Spike confirms masonry balancing, reflow-on-load (A2), placement-animation suppression on append (A1/D-31), and smooth scrolling (SR-3) on the reference sweep (SR-1 go/no-go)"
    requirement: DEP-04
    verification:
      - kind: manual
        ref: "Owner observation on iPhone Air + iPad Pro 11\" (portrait & landscape); GO"
        status: pass
    human_judgment: true
  - id: D2
    description: "Real proposal.width per device/width logged and assembled into the column-count sign-off table (SR-1 step 3)"
    requirement: DEP-04
    verification:
      - kind: manual
        ref: "Measured: iPhone Air 380→2, iPad 11\" portrait 794→4, iPad 11\" landscape 1170→5 (all match CONTEXT expected counts)"
        status: pass
    human_judgment: true
  - id: D3
    description: "Owner freezes m (D-23) against the measured table"
    requirement: DEP-04
    verification:
      - kind: manual
        ref: "Owner decision: keep m = 185"
        status: pass
    human_judgment: true

# Metrics
duration: iterative (spike + owner-requested behavior change)
completed: 2026-07-11
status: complete
---

# Phase 2 Plan 2: SR-1 Feasibility Spike Summary

**The candidate `MasonryLayout` was wired into the live `.thumbnail` call site and observed on the reference simulators: masonry balancing, reflow-on-load, animation suppression, and scrolling all held (SR-1 = GO). The measured column-count table matches the CONTEXT expected counts exactly, so `m` is frozen at 185. During the spike the owner requested — and this plan delivers — automatic load-on-scroll pagination for the thumbnail grid (D-36, amends D-30).**

## SR-1 Sign-off Table (measured `proposal.width`)

| Device (thumbnail mode) | Content width | Columns (measured) | CONTEXT expected | Match |
|---|---|---|---|---|
| iPhone Air — portrait | 380 pt | 2 | 335–408 → 2 | ✓ exact |
| iPad Pro 11″ — portrait | 794 pt | 4 | ~790 → 4 | ✓ exact |
| iPad Pro 11″ — landscape | 1170 pt | 5 | ~1040–1140 → 5 | ✓ exact |

Formula `max(2, floor((w+15)/200))` verified at each point (e.g. `floor((1170+15)/200) = 5`). Owner chose the **Minimal** sweep (iPhone + iPad portrait/landscape); the extreme bands (iPhone SE 2-clamp, iPad 13″ 6-column) were not measured but are predicted by the formula and covered by Plan 01's unit table.

## Go/No-Go Outcome — GO

- **Masonry balancing** ✓ — correct column counts and shortest-column packing (15 pt spacing, varying heights) on every device/width.
- **Reflow-on-load (A2)** ✓ — cells re-balance as Kingfisher covers settle; the brief cell-resize on image settle is inherent to async loading and owner-accepted.
- **Animation suppression on append (A1/D-31)** ✓ — `.animation(nil, value: galleries)` suppresses placement animation; no `.transaction` fallback needed; no cell-sliding observed across the many appends exercised.
- **Scrolling (SR-3)** ✓ — iPhone Air scrolled cleanly; no hitching reported.

## `m` Frozen — keep 185

Owner decision `keep-185`. All three measured widths land exactly on the CONTEXT expected counts, so no adjustment; `MasonryLayout.minCellWidth` stays 185 and the Plan 01 `columnCount` test table needs no re-baselining (Plan 03 confirms this).

## Task Commits

1. **Task 1: Wire the MasonryLayout candidate into the live `.thumbnail` call site + temporary `proposal.width` logging** — `64870474` (feat)
2. **Tasks 2 & 3 (checkpoints):** resolved by owner interaction — SR-1 GO + keep m=185 (no code).
3. **Owner-requested scope change (D-36): auto-load thumbnail grid on scroll** — `08e7f7ef` (feat)

## Deviations from Plan

### 1. [Owner-requested scope change] Automatic pagination replaces the manual footer (D-36, amends D-30)

- **Origin:** During the SR-1 spike the owner asked to replace the thumbnail grid's manual "load more" chevron footer with **automatic** pagination on reaching the bottom, mirroring the detail display mode. This supersedes only the "fetch-more footer siblings" element of D-30; the rest of D-30 stays binding. Recorded as **D-36** in `02-CONTEXT.md`.
- **Implementation (`08e7f7ef`):** the manual chevron `Button` is removed; a `FetchMoreFooter` (spinner/retry only) lives **inside** the single masonry `List` row (`VStack { MasonryLayout {…}; FetchMoreFooter }`); pagination is driven by `onScrollGeometryChange` distance-to-bottom, gated on a user-driven scroll phase (`onScrollPhaseChange`) **and** fired at most once per `galleries.count`.
- **Root cause of the bugs iterated through (documented so Plan 03 does not regress):**
  1. A footer `onAppear` sentinel fired only once (no page 3+).
  2. `.id(galleries.count)` on the footer re-fired but reset the List scroll to the top (row-identity churn drops the scroll anchor).
  3. A bare geometry trigger + a footer as a **sibling** List row pinned the viewport to the bottom on append (UIKit anchors the visible footer row while the masonry row above it grows → negative distance-to-bottom in the trigger log) and chained loads endlessly.
  - The fix that holds: footer **inside** the masonry row (nothing below the grid is anchored, so appends extend below the viewport and the offset stays put) + the user-scroll-phase / once-per-count guards (data-keyed, which layout cannot perturb). Verified: one fire per genuine bottom-reach, zero fires while idle, scroll position preserved, continuous across pages.
- **Downstream:** Plan 03 must **preserve** the auto-load and **remove** the temporary `GenericList.swift` OSLogExt trigger diagnostic (import + `logger` + `logger.debug`), the same way it removes the MasonryLayout width log. `02-03-PLAN.md` was amended accordingly (must-have truth, Task 2 action + acceptance).

### 2. [Environment] Build/run destination simulator substituted

- The plan's `<verify>` hard-codes `iPhone 16 Pro`, which is not installed. Ran against the booted iPhone Air (`id=ADE09605-…`) and iPad Pro 11″ (M5) by id. No source/logic change. (Same substitution noted in 02-01-SUMMARY.)

**Total deviations:** 1 owner-requested scope change (auto-load, D-36) + 1 environment substitution.
**Impact:** The auto-load is an additive, owner-approved behavior change carried forward by Plan 03; the parity/spike scope of this plan is otherwise unchanged. WaterfallGrid dependency and the legacy `columnsInPortrait`/`columnsInLandscape` vars remain in place for rollback (removed in Plans 03/04).

## Issues Encountered
- Device-orientation rotation of the iOS Simulator is a host-only Simulator.app operation — neither `sim-use` (guest-level HID) nor `simctl ui` can perform it, and osascript keystrokes were blocked by macOS Accessibility permissions. The owner rotated the iPad to capture the landscape width.
- The iPad app defaulted to **detail** display mode on a fresh install; switched to **thumbnail** via Setting → Appearance → Display mode to exercise the masonry.

## User Setup Required
None.

## Next Phase Readiness
- SR-1 passed and `m` is frozen at 185 → Plan 03 may commit the production swap.
- Plan 03 must: finalize `MasonryLayout` (remove width log, lock `minCellWidth = 185`, document policy), complete the `GenericList.swift` swap (drop `import WaterfallGrid`, delete `columnsInPortrait`/`columnsInLandscape`), **preserve the D-36 auto-load** (footer inside the masonry row + scroll-geometry/user-phase guards), and **remove the temporary GenericList OSLogExt diagnostic**. The Plan 01 `columnCount` test table needs no re-baselining (m unchanged).
- WaterfallGrid dependency removal remains Plan 04.

## Self-Check: PASSED

- Task 1 commit `64870474` and the auto-load commit `08e7f7ef` present in history; both touch only GalleryListComponents (+ Package.swift for the earlier candidate wiring).
- Live candidate renders the masonry grid; measured widths match the formula and the CONTEXT expected counts.
- D-36 recorded in `02-CONTEXT.md`; `02-03-PLAN.md` amended to preserve auto-load + remove the temp logger.
- No SUMMARY was written before the checkpoints resolved; STATE.md/ROADMAP.md advanced only now (this finalization).

---
*Phase: 02-native-masonry-grid-swap*
*Completed: 2026-07-11*
