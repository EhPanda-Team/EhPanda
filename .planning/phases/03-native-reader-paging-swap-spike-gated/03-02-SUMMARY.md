---
phase: 03-native-reader-paging-swap-spike-gated
plan: 02
subsystem: ui
tags: [swiftui, scrollview, viewaligned, scrolltransition, infinite-loop, dep-05]

requires:
  - phase: 03-native-reader-paging-swap-spike-gated
    provides: 03-CONTEXT decisions D-01/D-03/D-06/D-08/D-10/D-11
provides:
  - native CardSlideSection — viewAligned paging ScrollView with centered snap + symmetric peek + 0.2 fade + 20pt spacing
  - tripled-buffer infinite loop with transaction-suppressed idle re-center (replaces .loopPages())
  - outward pageIndex sync (buffer id → logical gallery index) with middle-block resume seed
affects: [03-05]

tech-stack:
  added: []
  patterns: [tripled-buffer + idle-phase suppressed re-center for native infinite paging, contentMargins centering for viewAligned snap]

key-files:
  created: []
  modified:
    - AppPackage/Sources/HomeFeature/HomeView+Sections.swift

key-decisions:
  - "Buffer ids are plain buffer indices (block*count + logical); logical index recovered via modulo, no per-block id struct"
  - "Outward-only pageIndex sync built (no inward re-seam): HomeReducer only observes/reads cardPageIndex, never writes it"
  - "Re-center guard doubles as the idle-handler re-entrancy gate (whole handler no-ops while performingChanges)"

patterns-established:
  - "Infinite native paging: tripled data + settle-time silent re-center inside withTransaction(disablesAnimations)"

requirements-completed: [DEP-05]

coverage:
  - id: D1
    description: "CardSlideSection renders via native viewAligned paging ScrollView (no SwiftUIPager) with centered snap, symmetric peek, 0.2 fade, 20pt spacing"
    requirement: DEP-05
    verification:
      - kind: other
        ref: "xcodebuild build -scheme AppPackage-Package (SwiftLint-as-error) — HomeFeature compiles without SwiftUIPager import"
        status: pass
    human_judgment: true
    rationale: "Peek/fade/spacing/snap feel parity is visual — owner walks it in the Plan 05 go/no-go checklist"
  - id: D2
    description: "Infinite loop preserved via tripled buffer with invisible idle-phase re-center; pageIndex stays in sync"
    requirement: DEP-05
    verification:
      - kind: other
        ref: "xcodebuild build -scheme AppPackage-Package"
        status: pass
    human_judgment: true
    rationale: "Loop-invisibility (no flash/stutter at the wrap boundary) cannot be asserted headlessly — Plan 05 owner gate"

duration: 12min
completed: 2026-07-12
status: complete
---

# Phase 3 Plan 02: Native CardSlideSection Carousel Summary

**Home card carousel rebuilt on a stock viewAligned paging ScrollView — centered snap with symmetric peek via contentMargins, 0.2 scrollTransition fade, 20pt LazyHStack spacing, and a tripled-buffer infinite loop with a transaction-suppressed idle re-center replacing `.loopPages()`**

## Performance

- **Duration:** ~12 min
- **Started:** 2026-07-12T07:06:00+09:00
- **Completed:** 2026-07-12T07:18:00+09:00
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- `CardSlideSection` no longer imports SwiftUIPager and contains no `Pager(`: the body is `ScrollView(.horizontal)` + `LazyHStack(spacing: 20)` + `.scrollTargetLayout()` + `.scrollTargetBehavior(.viewAligned)` + `.scrollPosition(id:)` + `.scrollClipDisabled()`, cards fixed-framed to `Defaults.FrameSize.cardCellSize`, no `GeometryReader`.
- Centered snap (03-REVIEWS MEDIUM fix): `.contentMargins(.horizontal, (DeviceUtil.windowW − cardCellSize.width) / 2, for: .scrollContent)` — the snapped card sits centered with symmetric ~10% peek each side, matching SwiftUIPager's focused-card centering.
- `.interactive(opacity: 0.2)` reproduced per card via `.scrollTransition { content, phase in content.opacity(phase.isIdentity ? 1 : 0.2) }`.
- D-08 infinite loop: three concatenated copies of `galleries` with block-distinct Int ids (`block*count + logical`); starts on the middle copy's entry for the inbound `pageIndex` (index-1 seed parity, 03-REVIEWS LOW); on `.onScrollPhaseChange == .idle` in an edge copy, the position silently re-centers to the middle-block equivalent inside `withTransaction(disablesAnimations: true)`, guarded by a `performingChanges` flag.
- Outward sync preserved: every idle settle maps the buffer id → logical gallery index and writes `$pageIndex` (deduplicated). Inner `Button`/`GalleryCardCell` label, `.frame(height: cardCellHeight)`, and the `Equatable` conformance all preserved verbatim.

## Task Commits

1. **Task 1: Rebuild CardSlideSection as a native viewAligned paging ScrollView** - `786666b3` (feat)
2. **Task 2: Add the tripled-buffer infinite loop with suppressed idle re-center** - `5c15f397` (feat)

## Files Created/Modified
- `AppPackage/Sources/HomeFeature/HomeView+Sections.swift` - CardSlideSection rebuilt natively; rest of file untouched

## Decisions Made
- Modifier mapping recorded for the go/no-go: `.preferredItemSize` → fixed card frame; `.itemSpacing(20)` → `LazyHStack(spacing: 20)`; centering → `.contentMargins` of `(windowW − cardWidth)/2`; `.interactive(opacity: 0.2)` → `.scrollTransition`; `.loopPages()` → tripled buffer + suppressed re-center; `.pagingPriority(.high)` → none needed (native scroll gesture already outranks the card Button); `.synchronize` → settle-time buffer-id → logical-index write.
- **Verified sync asymmetry (03-REVIEWS LOW):** outward-only `pageIndex` sync is parity-adequate because the reducer never writes `cardPageIndex` (`HomeReducer+Body.swift:13-15` observes; `HomeReducer.swift:48` reads). A future reducer-side write would need an inward re-seam (`.onChange(of: pageIndex)` → guarded scroll write).
- Every buffer/logical index is bounds-safe: settled ids clamp to `0..<count*3` before the modulo; `bufferedCards` subscripts only `bufferIndex % count`.
- D-03 options in reserve if the re-center is not flash-free at the owner gate: key strictly off `.idle` (done), tighten buffer id math, try `.onScrollGeometryChange` detection.

## Deviations from Plan

**1. [Rule 1 - Lint] contentMargins expression extracted to a `centeringMargin` property**
- **Found during:** Task 1
- **Issue:** The inline margin expression exceeded the 120-char `line_length` error limit.
- **Fix:** Extracted to a named private computed property with the centering rationale comment.
- **Files modified:** HomeView+Sections.swift
- **Verification:** Build green under SwiftLint-as-error.
- **Committed in:** `786666b3`

**Total deviations:** 1 auto-fixed (lint).
**Impact on plan:** None — same modifier value, named for readability.

## Issues Encountered
None.

## User Setup Required
None.

## Next Phase Readiness
- Carousel parity items (centered snap, peek, fade, spacing, pageIndex sync, loop invisibility) are built and await the owner's device walk in Plan 05's D-11 checklist — loop invisibility is the highest-risk item (no in-repo analog existed).
- SwiftUIPager still declared in Package.swift (rollback-safe); acknowledgements untouched (gated on GO).

---
*Phase: 03-native-reader-paging-swap-spike-gated*
*Completed: 2026-07-12*
