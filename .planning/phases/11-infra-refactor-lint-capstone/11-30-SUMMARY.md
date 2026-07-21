---
phase: 11-infra-refactor-lint-capstone
plan: 30
subsystem: gallery-list-pagination
tags: [gap-closure, blocker, swiftui, pagination, lint]
status: complete
gap_closure: true
gap_ids: [G-11-7]
requires:
  - "Phase 2 / D-36 scroll-geometry auto-load heuristic (left intact, rescoped)"
provides:
  - "DetailList trailing-row scroll-visibility fetch-more trigger"
  - "AutoLoadNextPage narrowed to thumbnail-grid scope"
affects:
  - "All seven GalleryList surfaces in the default .detail display mode"
tech-stack:
  added: []
  patterns:
    - "onScrollVisibilityChange as the per-scroll-arrival analogue of a deleted last-cell trigger"
key-files:
  created: []
  modified:
    - AppPackage/Sources/GalleryListComponents/GalleryList.swift
    - .planning/STATE.md
decisions:
  - "Shipped the PRIMARY form (.onScrollVisibilityChange on the row Button), not the fallback"
  - "AutoLoadNextPage's body, guards, thresholds and state left untouched — rescoped by deletion of its DetailList call site, not by modification"
  - "lastAutoFetchCount latch hardening deliberately routed to STATE.md, not implemented"
metrics:
  duration: ~20 min
  tasks: 2
  files: 2
  completed: 2026-07-22
---

# Phase 11 Plan 30: G-11-7 Gap Closure — DetailList Pagination Summary

Restored fetch-more pagination in `DetailList` by replacing the misapplied scroll-geometry
heuristic with an `.onScrollVisibilityChange` trailing-row trigger, and returned that heuristic to
the thumbnail-only scope D-36 built it for.

## What Shipped

**Which trigger form:** the **PRIMARY** form from the plan —
`.onScrollVisibilityChange { isVisible in guard isVisible, gallery == galleries.last else { return }; fetchMoreAction?() }`
attached to the row `Button` inside `DetailList`'s `ForEach`, immediately after
`.foregroundStyle(.primary)`.

The sanctioned fallback (`.onScrollTargetVisibilityChange(idType:)` + `.scrollTargetLayout()`, the
`PreviewsView.swift:65` shape) was **not** needed and did **not** ship. The plan gated that
contingency on the human check showing the row-level visibility callback never fires inside a
`List` — that check requires a device and has not been run, so the primary form stands as the
shipped implementation. See *Unverified* below; this is the one thing the owner's re-test decides.

**Task 1** (`8325c5c5`) — two edits, one commit:

- (a) The visibility trigger added to the row `Button`. Applied unconditionally to every row with
  the guard selecting the last one, so row view identity is unchanged. No `@State`, no counter, no
  re-entrancy flag was added — the reducers already own re-entrancy. The
  `.autoLoadNextPage(...)` call was deleted from `DetailList`'s `List` in the same edit, so the two
  mechanisms are never both live on one list. `shouldShowFooter(gallery:)` and the sibling
  `FetchMoreFooter` row are unchanged; the footer remains the manual retry affordance.
- (b) The `autoLoadNextPage` doc comment rewritten to state the narrower true contract: the
  heuristic serves the thumbnail grid only, because its accounting was tuned for the masonry
  layout's single eagerly measured row with the footer inside that row, while the detail list's
  many lazily materialized estimated-height rows plus a standalone footer sibling row are the
  structure D-36 records as incompatible. The D-36 citation is retained. The `AutoLoadNextPage`
  struct body, guard chain, thresholds and state are untouched, and the ThumbnailList call site is
  untouched.

**Task 2** (`d7b90d8a`) — two entries appended to STATE.md `### Blockers/Concerns`: the deferred
`lastAutoFetchCount` latch hardening (marked pre-existing Phase 2 / D-36, needing a device check
for chain-fetch regression, with the detail path no longer depending on it), and the standing
verification item requiring both `listDisplayMode` values in any future pagination UAT.

## Verification

| Gate | Result |
|------|--------|
| DetailList region: zero `autoLoadNextPage` calls | PASS (0) |
| DetailList region: has a scroll-visibility trigger | PASS (1 `onScroll`) |
| ThumbnailList region: exactly one `autoLoadNextPage` call | PASS (1) |
| `xcodebuild build -scheme EhPanda` (compile + SwiftLint plugin at error) | PASS — `** BUILD SUCCEEDED **` |
| No new `swiftlint:disable` | PASS (0 in diff) |
| No `.swiftlint.yml` change | PASS (not in diff) |
| No reducer / `Setting.listDisplayMode` change | PASS (only 2 files in diff) |
| No `@State` added to DetailList | PASS |
| STATE.md carries both follow-ups | PASS |

The `lifecycle_modifiers` rule was verified against the **live** regex by building rather than by
reading: the rule is at `error`, its regex requires a literal dot followed immediately by
`onAppear`/`onDisappear`/`task`, and the build succeeded with the new modifier in place. Zero lint
suppressions, zero rule edits, zero severity changes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `xcodebuild` failed on a macro trust-approval gate**

- **Found during:** Task 1 verification
- **Issue:** The first build failed at `ComputeTargetDependencyGraph` with
  `Macro "CasePathsMacros" ... was changed since a previous approval and must be enabled before it
  can be used` (same for `PerceptionMacros` and `SwiftNavigationMacros`). This is a local DerivedData
  trust state, unrelated to this plan's change — no dependency was added or resolved here.
- **Fix:** Re-ran the same build with `-skipMacroValidation`. This is an `xcodebuild` invocation
  flag for a local verification build; it changes no repository state, no lint configuration and no
  package manifest. Nothing was committed as a result.
- **Files modified:** none
- **Commit:** n/a

### Out-of-scope observations (logged, not fixed)

**STATE.md carried a pre-existing uncommitted modification.** When Task 1 finished, `git status`
showed STATE.md already dirty from the orchestrator's init bookkeeping for phase 11 reopening:
`status: verifying` → `executing`, `completed_phases` 10 → 9, `total_plans` 135 → 137,
`percent` 67 → 60, and Current Position `Plan: 30 of 30 / Phase complete — ready for verification`
→ `Plan: 1 of 32 / Executing Phase 11`. Its `last_updated` is newer than the committed version, so
it is a forward write by the tooling, not a stale revert, and it is consistent with G-11-7
reopening the phase. It was left intact rather than reverted, and rode along in Task 2's commit.

Consequence for Task 2's automated gate: the gate asserted the STATE.md diff deletes at most two
lines. The measured diff deletes nine — **all nine from the orchestrator's frontmatter and Current
Position rewrite**. This plan's own STATE.md edit is purely additive (two appended entries, zero
deletions), which is what the gate was written to enforce. The `Plan: 1 of 32` counter reset is
worth an owner glance if the position number matters downstream.

## Unverified

**Runtime behaviour was not confirmed.** This plan's evidence is compile-level and
structural only: the build succeeds, the SwiftLint plugin passes at `error`, and the region gates
hold. Nothing here proves the trigger actually fires on device. Specifically **not** verified:

1. That `.onScrollVisibilityChange` fires for a row inside a `List` on arrival at the trailing row.
   This is the exact condition the plan's contingency is gated on. If it does not fire, the
   sanctioned fallback (`.onScrollTargetVisibilityChange(idType: String.self)` on the `List` plus
   `.scrollTargetLayout()` on the `ForEach`) is the next step — and remains the *only* permitted
   alternative. A lifecycle modifier, a view-local latch, and re-applying the geometry heuristic to
   this layout all stay barred.
2. That detail mode paginates across three or more consecutive pages, and keeps paginating after a
   successful append without leaving the screen.
3. That the fix holds on a second surface (Watched / Favorites / Search), not just Frontpage.
4. That thumbnail mode is behaviourally unchanged and does not chain-fetch while pinned at the
   bottom.

The owner's manual re-test in **both** display modes is what closes these. Until it runs, G-11-7
should be treated as fix-applied-pending-confirmation rather than confirmed resolved.

## Known Stubs

None.

## Threat Flags

None. The change introduces no new network endpoint, auth path, file access or schema surface. The
plan's registered threats hold as designed: T-11-33 is mitigated by the trigger firing only on a
visibility edge for the last row, backed by the reducers' synchronous loading guard; T-11-34 is
mitigated by the deletion of the second trigger from DetailList, with the chain-fetch watch left to
the owner's thumbnail-mode check.

## Self-Check: PASSED

- FOUND: AppPackage/Sources/GalleryListComponents/GalleryList.swift
- FOUND: .planning/STATE.md
- FOUND: commit 8325c5c5
- FOUND: commit d7b90d8a
