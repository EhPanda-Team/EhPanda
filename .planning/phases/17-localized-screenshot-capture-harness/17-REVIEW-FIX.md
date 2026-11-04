---
phase: 17
fixed_at: 2026-11-04T21:55:00+08:00
review_path: .planning/phases/17-localized-screenshot-capture-harness/17-REVIEW.md
iteration: 1
findings_in_scope: 3
fixed: 2
skipped: 1
status: partial
---

# Phase 17: Code Review Fix Report

**Fixed at:** 2026-11-04T21:55:00+08:00
**Source review:** .planning/phases/17-localized-screenshot-capture-harness/17-REVIEW.md
**Iteration:** 1
**Effort:** high (resolved from .planning/config.json)

**Summary:**
- Findings in scope: 3. These are WR-01, WR-02 and IN-01, chosen by the owner's triage (msg 1627).
- Fixed: 2 (WR-01, IN-01)
- Skipped: 1 (WR-02, which the owner accepted as won't-fix)
- Not in scope: IN-02 and IN-03, deferred to Phase 18 by the owner (msg 1627)

`status: partial` reflects the workflow's counting rule. No finding was skipped for a technical
reason. WR-02 was skipped by owner decision.

## Fixed Issues

### WR-01: The pager's turn gate is not reset when the pager is rebuilt

**Files modified:** `AppPackage/Sources/ReadingFeature/ReadingView.swift`, `AppPackage/Sources/ReadingFeature/Support/PageModel.swift`, `AppPackage/Tests/ReadingFeatureTests/PagerTurnGateTests.swift`
**Commit:** 92181ccd2
**Status:** fixed: requires human verification. This is view-state logic. The unit tests pin the gate
itself. The SwiftUI wiring, meaning the rebuild observers and the placement on the index, has no
runtime check here.
**Applied fix:**
- Added `PagerTurnGate.pagerRebuilt()` (PageModel.swift:101-107 at 18ec91b86). It starts the gate over: no turn
  held, at rest, no tries counted. The type's doc no longer relies on a new pager reporting `.idle`.
- Added `ReadingView.pagerRebuilt()` (ReadingView.swift:523-530). It resets the gate, clears
  `shownPagerPosition` so the new pager reports its own page, and sets `scrollPositionID =
  pageModel.index` directly. The new pager's own `initial: true` placement goes through
  `tryScrollTo`, which is skipped inside the echo guard of a turn just made. The direct write
  delivers a turn that was held for the old pager.
- It is called from a new `.onChange(of: store.forceRefreshID)` (ReadingView.swift:220-223). That
  observer is placed *after* `.id(store.forceRefreshID)`, so the identity change does not tear it
  down. It is also called from the existing `readingDirection` observer (ReadingView.swift:418-420),
  which until now reset only `shownPagerPosition`.
- Tests: `aPagerBuiltAnewAdmitsTurnsAGateLeftMidAnimationHeld`,
  `aPagerBuiltAnewDropsTheTurnHeldForTheOldOne`, `aPagerBuiltAnewIsCheckedAtRest` and
  `aPagerBuiltAnewStartsTheCountOver` replace `aPagerBuiltAnewClearsAGateLeftMidAnimation`, which
  assumed the unverified initial `.idle` report. All four failed (RED) against a no-op stub and pass
  (GREEN) with the fix.

Paths audited that rebuild or re-identify the pager, or reset the page shown:

| Path | Rebuilds pager? | Verdict |
|------|-----------------|---------|
| Reload all images, remote (`.reloadAllWebImages` sets `forceRefreshID`, ReadingReducer+Body.swift:170) | yes, via `.id` | **fixed**: there was no reset before |
| Local pages turn up empty, so the reader falls back to remote (sets `forceRefreshID`, ReadingReducer+Session.swift:118) | yes, via `.id` | **fixed**: same observer |
| Reading direction vertical to horizontal (setting sheet, or orientation preferences on rotation, ReadingReducer+Layout.swift:31) | yes: the `switch` branch swaps in a new ScrollView | **fixed**: before this, only `shownPagerPosition` was reset |
| Reading direction horizontal to vertical | yes. The new `AdvancedList` seeds its own state from `pageModel.index`, and the gate is unused in vertical | fine; the reset is harmless |
| LTR to RTL | same `switch` branch, so probably the same ScrollView (unverified) | reset applied by the existing direction observer. If the ScrollView persists mid-animation, the only cost is one admitted turn or correction mid-scroll. `correctPager` and the next `.idle` bound that cost |
| Dual-page toggle, or rotation changing `isLandscape` (data source re-mapped) | no: same ScrollView, positions re-numbered | fine. `onChange(containerDataSource)` goes to `setPageIndex` and `jump`, through the gate. The ScrollView keeps reporting phases. With IN-01, the count restarts at the admitted turn |
| Container size change without re-mapping | no | fine; phases keep coming from the same pager |
| Reload all images, local source (`applyLocalSource`, ReadingReducer+Body.swift:159) | no (no `forceRefreshID`) | fine; a page-count change goes through the data-source observer |
| Retry failed images / single page retry / refetch | no | fine; no pager state is involved |
| Gallery switch | a new presentation means a new `ReadingView`, so all `@State` is fresh | fine |
| Pager seed (`PagerSeed`) | one-shot. After a forced refresh, the pages are rebuilt at once on the seeded index | fine; the direct placement in `pagerRebuilt()` covers the echo-guard skip |
| `performingChanges` echo guard | lowered by its own timer | fine; the only interaction is the skipped placement above, now covered |

### IN-01: The correction count carries over between unrelated misses

**Files modified:** `AppPackage/Sources/ReadingFeature/Support/PageModel.swift`, `AppPackage/Tests/ReadingFeatureTests/PagerTurnGateTests.swift`
**Commit:** 18ec91b86
**Status:** fixed: requires human verification (retry-bound logic)
**Applied fix:** `corrections` resets when `admitsTurn()` admits a turn (PageModel.swift:78-87). It
also resets in `phaseChanged` on any phase other than `.idle` or `.animating` (PageModel.swift:89-99),
the same phases that already drop a held turn. The retry loop stays bounded. `correctPager`'s re-send
calls `scrollPager` directly, not `admitsTurn`, and a programmatic scroll reports `.animating`.
Tests: `aNewTurnStartsTheCountOver` and `theReadersOwnScrollStartsTheCountOver(phase:)` (×3) were RED
before the fix and are GREEN after it. `aProgrammaticScrollKeepsTheCount` guards the bound and is
green before and after.

## Skipped Issues

### WR-02: The capture overlay preference reaches only Filters and the reader, not the other sheets

**File:** `AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:44-49`
**Reason:** accepted / won't-fix by owner decision (msg 1627): "the required pages don't show a home
indicator. Do nothing." No code change.
**Original issue:** The root's `captureSystemOverlayVisibility` does not reach the separately
presented Setting/Laboratory sheet or `GallerySheetView` (iPad Detail/Comments), so those captures
could show the home indicator.

## Not in Scope

### IN-02: verify-release.py would not catch a Release leak of the capture overlay key

Deferred to Phase 18 by the owner (msg 1627). Left untouched.

### IN-03: RootView imports AppComponents unconditionally but uses it only in DEBUG

Deferred to Phase 18 by the owner (msg 1627). Left untouched.

## Verification

- **Where it ran:** the main checkout, `~/Fork/EhPanda`, on branch
  `feature/gsd-phase-17`. The workflow's isolated worktree under `.claude/worktrees/` was not created
  because the owner's rules forbid touching `.claude/`. The results can be reproduced from this tree.
- **Unit tests:** `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests
  -destination id=FFE7E686-7377-4F16-BAB6-F5CB07999788
  -only-testing:ReadingFeatureTests/PagerTurnGateTests`, plus `PagerSeedTests` on the last run.
  - WR-01 RED: 4 failed, 13 passed (exit 65). GREEN: 18 passed, TEST SUCCEEDED.
  - IN-01 RED: `aNewTurnStartsTheCountOver` and `theReadersOwnScrollStartsTheCountOver` ×3 failed
    (exit 65). GREEN: 31 passed across PagerTurnGateTests and PagerSeedTests, TEST SUCCEEDED.
- **Lint:** SwiftLint 0.65.1, `swiftlint lint --strict --no-cache` on every changed Swift file: 0
  violations.
- **Not run (left for the final gate):** full FeatureTests, UITests, and the
  ReaderPageSyncUITests runtime checks of the rebuild paths.

---

_Fixed: 2026-11-04T21:55:00+08:00_
_Fixer: Claude (gsd-code-fixer, inline)_
_Iteration: 1_
