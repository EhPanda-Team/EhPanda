---
phase: 03-native-reader-paging-swap-spike-gated
plan: 03
subsystem: ui
tags: [swiftui, scrollview, paging, observable, rtl, dep-05]

requires:
  - phase: 03-native-reader-paging-swap-spike-gated
    provides: 03-01 PageHandler mapping guard (must stay green through the re-seam)
provides:
  - PageModel — app-owned @Observable plain-index source of truth (D-07), Page-surface-compatible
  - reader horizontal branch on ScrollView(.horizontal) + .scrollTargetBehavior(.paging) + .scrollPosition(id:) + .containerRelativeFrame + .scrollDisabled (D-04/D-05)
  - RTL as an axis-only layoutDirection flip with per-page LTR re-normalization (03-REVIEWS HIGH fix)
  - AdvancedList re-seamed to PageModel byte-for-byte
affects: [03-04, 03-05]

tech-stack:
  added: []
  patterns: [position-based scrollPosition ids (0-based data-source positions == pageModel.index space), performingChanges settle guard on the horizontal branch]

key-files:
  created:
    - AppPackage/Sources/ReadingFeature/Support/PageModel.swift
  modified:
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift
    - AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift

key-decisions:
  - "Horizontal .scrollPosition ids are 0-based POSITIONS in containerDataSource, not element values — dual-page elements are non-uniform ([1,3,5…]/[1,2,4…]), so only positions match the Page.index/mapToPager space with no offset (the AdvancedList ±1 idiom is vertical-only, where the data source is always 1…n)"
  - "scrollPositionID is seeded in init from the same mapToPager resume index as pageModel, so the horizontal list opens on the saved page pre-render"
  - "ReadingView+Gestures.swift re-seamed in this plan (mechanical page.→pageModel. rename) — required for the green-package must_have; Plan 04 still re-routes it through the guarded jump"

patterns-established:
  - "PageModel is the only index bus: every reader writer/reader goes through .index/.update, mirroring the removed Page surface"

requirements-completed: [DEP-05]

coverage:
  - id: D1
    description: "PageModel exists as the app-owned @Observable index source of truth; SwiftUIPager type gone from ReadingView/AdvancedList/Gestures"
    requirement: DEP-05
    verification:
      - kind: other
        ref: "grep: no 'import SwiftUIPager' in ReadingFeature; xcodebuild test -only-testing:ReadingFeatureTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "Horizontal branch pages via stock paging ScrollView with RTL axis-only flip, zoom-freeze, resume-seed, unchanged reducer fan-out"
    requirement: DEP-05
    verification:
      - kind: unit
        ref: "ReadingFeatureTests green post-re-seam (mapping guard unchanged); package compiles under SwiftLint-as-error"
        status: pass
    human_judgment: true
    rationale: "Paging feel, RTL spread order, and dual-page-landscape snap (FB16486510) are device-observable — Plan 05 owner gate items"

duration: 14min
completed: 2026-07-12
status: complete
---

# Phase 3 Plan 03: Reader Core Paging Swap Summary

**Reader's horizontal paging swapped from SwiftUIPager `Pager` to a stock paging ScrollView on a new app-owned `@Observable PageModel` — position-based scrollPosition ids, RTL as an axis-only flip with per-page LTR re-normalization, zoom-freeze via `.scrollDisabled`, resume-seed at construction, reducer contract untouched**

## Performance

- **Duration:** ~14 min
- **Started:** 2026-07-12T07:20:00+09:00
- **Completed:** 2026-07-12T07:34:00+09:00
- **Tasks:** 2
- **Files modified:** 4 (1 created)

## Accomplishments
- `Support/PageModel.swift`: `@Observable @MainActor final class` with `index`, `Update.next/.new(index:)`, `update(_:)`, `withIndex(_:)` — the exact `Page` surface the reader used, so writer call sites survived as a type change. Raw increment/set like `Page`; bounds clamping lands with the writers in Plan 04.
- Horizontal branch replaced: `ScrollView(.horizontal)` + `LazyHStack(spacing: 0)` + `.scrollTargetLayout()` + `.scrollTargetBehavior(.paging)` + `.scrollPosition(id: $scrollPositionID)` + per-page `.containerRelativeFrame(.horizontal)` (no GeometryReader) + `.scrollDisabled(gestureHandler.scale != 1)` (D-09a), inside the existing `.id(store.forceRefreshID)` rotation identity (Pitfall 4).
- **RTL with no double-flip (03-REVIEWS HIGH):** `.environment(\.layoutDirection, …)` flip sits on the ScrollView; each page re-normalizes to `.leftToRight` inside the LazyHStack, so `imageContainerConfigs`' `isReversed` swap remains the sole authority for intra-spread order. Gesture modifiers sit outside the flipped subtree (unchanged lines 157-166).
- **Index-space correction:** the `.scrollPosition(id:)` ids are the 0-based positions of `containerDataSource` (`ForEach(dataSource.indices, id: \.self)`), NOT element values — in dual-page mode elements are non-uniform reading pages, so positions are the only space that equals `pageModel.index`/`mapToPager` output with no offset.
- Scroll-settle writes reproduce the AdvancedList guard verbatim: `.onScrollPhaseChange == .idle` → `performingChanges = true` → `pageModel.update(.new(index: position))` → 0.2 s re-arm; `.onChange(of: pageModel.index)` → `tryScrollTo` (suppressed while `performingChanges`); `.onAppear` re-seeds on branch switches.
- `AdvancedList` re-seamed byte-for-byte (only `Page` → `PageModel` in property + init param; `+1`/`-1` offset, guard, scroll logic untouched). Resume-seed (`mapToPager` in init), `activeStackIndex`, the `.onChange` reducer fan-out (`mapFromPager` → `syncReadingProgress`), and `setPageIndex`/`setAutoPlayPolocy` all reference `pageModel`; reducer contract unchanged.

## Task Commits

1. **Task 1: Introduce the app-owned @Observable PageModel** - `6974bcd5` (feat)
2. **Task 2: Re-seam AdvancedList + ReadingView onto PageModel, swap Pager for paging ScrollView** - `79dfff53` (feat)

## Files Created/Modified
- `AppPackage/Sources/ReadingFeature/Support/PageModel.swift` - new plain-index source of truth (D-07)
- `AppPackage/Sources/ReadingFeature/ReadingView.swift` - horizontal paging ScrollView + PageModel wiring
- `AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift` - Page → PageModel type re-seam only
- `AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift` - tap closure `page.` → `pageModel.` (see deviation)

## Decisions Made
- Position-based ids (see key-decisions) — this deviates from a literal reading of "AdvancedList's +1/-1 idiom" because that offset is only correct where the data source is `1…n`; the horizontal dual-page data source is not. `PageHandler` output IS the position space, so no mapping layer was added.
- `scrollPositionID` init-seeded alongside `pageModel` (same `mapToPager` result) so the reader opens on the resume page without a post-render jump — `Page .withIndex` parity.

## Deviations from Plan

**1. [Rule 3 - Blocking] ReadingView+Gestures.swift needed the mechanical rename in this plan**
- **Found during:** Task 2
- **Issue:** The plan's files_modified omits `ReadingView+Gestures.swift`, but its tap closure references `page.index`/`page.update`; after the `page` → `pageModel` rename the package cannot compile (a plan must_have) without touching it.
- **Fix:** Renamed the two references (`pageModel.index + $0` / `pageModel.update(.new(index:))`). No behavior change; Plan 04 Task 2 still re-routes this closure through the guarded jump as planned.
- **Files modified:** AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift
- **Verification:** Package builds clean; ReadingFeatureTests green.
- **Committed in:** `79dfff53`

**Total deviations:** 1 auto-fixed (blocking).
**Impact on plan:** None — Plan 04's scope for this file is unchanged.

## Issues Encountered
None.

## User Setup Required
None.

## Next Phase Readiness
- Plan 04 hardens the three programmatic writers through a clamped, guarded `jump(...)` with landed-id logging (autoplay `.next` is currently raw-unclamped — exact `Page` vertical-mode parity, tightened next).
- Device items for the Plan 05 checklist: RTL spread order (double-flip check), dual-page landscape snap (FB16486510), programmatic-jump landed-id fidelity.
- SwiftUIPager still declared in Package.swift (rollback-safe).

---
*Phase: 03-native-reader-paging-swap-spike-gated*
*Completed: 2026-07-12*
