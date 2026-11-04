# Reader page sync: root cause and a single-source-of-truth sketch

Written for owner msg 1630 by the gsd-code-fixer, Phase 17, after the WR-01 and IN-01 fixes
(fb1ea4b18, 443e74541). This is analysis only. Nothing here is implemented.
Copied on 2026-11-05 from the local `/tmp/ehp-17gate/reader-root-cause.md` as the reference for
Phase 18 Step 4b. Checked for LAN addresses, cookies and credentials: none found, nothing redacted.

## 1. What holds "the page" today

The reader has no single value that means "the current page". It has five writable copies and one
read-only truth. Observers mirror them into each other in both directions.

| # | Value | Owner | Space | Role today |
|---|-------|-------|-------|------------|
| A | `pageModel.index` | `ReadingView` `@State` (`PageModel`) | pager position, 0-based. A spread counts as one position in dual-page mode | Called "the single source of truth" (PageModel.swift:4). In practice it is a hub that every other copy writes to |
| B | `scrollPositionID` | `ReadingView` `@State`, bound by `.scrollPosition(id:)` | pager position | Used both to command the paging ScrollView and to report its position. It is reliable as neither: SwiftUI can drop it mid-animation, and at rest it can name a page the ScrollView did not reach |
| C | `shownPagerPosition` | `ReadingView` `@State`, from `onScrollTargetVisibilityChange` | pager position | The only reading of what is actually on screen in horizontal mode (added by 4cc9925e1) |
| D | `pageHandler.sliderValue` | `ReadingView` `@State` (`PageHandler`) | reading page, 1-based | The **displayed** number: the toolbar title `"\(sliderValue) / pageCount"` and the slider. The indicator is this value, not the index |
| E | `readingProgress` / `pendingReadingProgress` | `ReadingReducer` state | reading page, 1-based | Persisted resume page. Read once at `ReadingView.init` to seed D, then written from D through `.syncReadingProgress` |
| F | `AdvancedList.position` / `positionedID` | `AdvancedList` `@State` (vertical mode) | data element + 1 | The vertical list's own copy. Seeded from A at init, it writes back to A at rest |

View-held control state that exists only to reconcile these copies:

- `PagerTurnGate` (`isAnimating`, `isAtRest`, `holdsTurn`, `corrections`): when B may be written, and
  whether C disagrees with A.
- `PagerSeed.isSeeded`: when A and B are first derived from D, and whether the pages may be built.
- `performingChanges`: a 0.2 s time window that suppresses the A to B echo.

## 2. The mirror graph, and where each patch sits

```
          slider drag / tap / autoplay / a11y
                       |
   D sliderValue --setPageIndex--> jump() --> A index --onChange--> D (mapFromPager) --> E reducer
        ^                                     |  ^
        |                         tryScrollTo  |  |  idle: A = B          (horizontal)
        |                     (unless echo     v  |  followScreen: A = C
        |                        guard)       B scrollPositionID <--> ScrollView offset --> C shown
        |                                     |
        +---- containerDataSource change -----+  (dual-page / rotation re-maps D -> A)
                                              A <--> F AdvancedList.position     (vertical)
```

Every edge is an `onChange` or a callback, and several form cycles: A to D to A, A to B to A, and
A to F to A. The echo guard and the gate exist to stop those cycles from fighting an in-flight
scroll.

| Commit | Divergence it closes | Copies it syncs | Mechanism |
|--------|----------------------|-----------------|-----------|
| pre-17 echo guard | A to B to A feedback cancels a scroll | A, B | `performingChanges` 0.2 s window |
| 3708ac32c | B written mid-animation is dropped, so the ScrollView stops short while B and A name the later page | A, B | gate holds the B write until `.idle` |
| 4cc9925e1 | a turn lost at the moment of rest starts no scroll, so no phase reports it | C against A, then B | read C from the screen and re-send B (bounded) |
| a7627790a | after giving up, A (and D) still name the unreached page | A from C | `followScreen`: A = C |
| b2c958838 | first measurement is degenerate, the seed is skipped, and A stays 0 while D holds the resume page | A, B from D | `PagerSeed`: seed at the first real area, build pages after |
| 3642b8cec | the bar's own size counts as an area, so A/F are seeded at 32 x 118 pt and F lays out wrong | F (via the seed timing) | bar waits for a reading area |
| fb1ea4b18 (WR-01) | a rebuilt pager inherits a stale gate (and a stale C), so B is never written again | gate, C, B | reset on `forceRefreshID` and direction change, then B = A |
| 443e74541 (IN-01) | retry count leaks across turns | gate | count resets per admitted turn and on a user scroll |

**Root cause.** "Page shown" (the ScrollView offset, observed only as C) and "page number
displayed" (D) are two different values. A sits between them as a third, and B is a fourth that
looks like both a command and a report. Each patch adds a rule for one way these copies drift
apart, and each rule depends on timing: echo windows, phase reports, a 0.2 s after-check, and the
seed order. Any new event that rebuilds, re-identifies or re-lays out the pager (WR-01 was one)
opens a new drift path, because no invariant ties D to C. Only reconciliation rules do.

## 3. Single-source-of-truth sketch

Invariant to enforce by construction: **the displayed number is a pure function of what the screen
shows at rest, or of the one pending request while a turn is in flight.** No other copy is stored.

1. **One owner, in reading-page space.** Add a `ReaderPosition` value. It could be reducer state, so
   persistence and the a11y/analytics paths read it, or one `@Observable` in the view:
   - `page: Int`: the committed reading page, 1-based. This is E's live value. D (title and slider)
     is *derived* from it, not stored.
   - `request: Request?`: `{ target: Int, generation: Int, tries: Int }`. This is the single pending
     turn, and it replaces `holdsTurn` and `corrections`.
   - `generation: Int`: the pager's identity. It is bumped by anything that builds a new pager
     (`forceRefreshID`, a direction change, a data-source/layout change). A request or observation
     carrying an old generation is ignored, so no reset hooks are needed (WR-01 becomes
     impossible rather than patched).
   Positions (A, B) become derived: `position = mapToPager(page, layout)`. Dual-page and rotation
   then re-derive the position. They no longer re-seed or re-jump.

2. **Intents in, observations in, one reducer of both.** Pure functions, unit-testable:
   - `turn(to:)` (tap, slider commit, autoplay, a11y) sets `request` (latest wins) and emits
     "drive pager to position(target)".
   - `pagerSettled(shown:generation:)`, from C at `.idle`. If it matches the request, commit `page`
     and clear `request`. If it misses and `tries < limit`, re-drive. If it is past the limit, commit
     the shown page (today's followScreen). With no request (a user drag), commit the shown page.
   - `pagerRebuilt(generation:)` clears the request into a placement at `page`.
   The slider preview stays a separate, display-only value while scrubbing. It is not D.

3. **One actuator.** A small driver writes B only on an emitted command. It never mirrors A into B
   with `onChange`, so the echo guard and the A to B to A cycle go away. Vertical mode uses the
   same reducer. F's `followPosition` becomes `pagerSettled`, and `tryScrollTo` becomes the
   command sink.

4. **Seed = first placement.** `PagerSeed` remains only as "has the area been measured". The
   initial placement is a `pagerRebuilt` at `page`, generation 0.

Result: D always equals `page`, which only ever comes from a settled observation (C) or from the
initial resume value. The class "indicator names a page the screen does not show" holds by
construction. It no longer depends on timing.

## 4. Tests that would guard the redesign

Unit (ReadingFeatureTests; port the rules, keep the names where possible):
- `PagerTurnGateTests`: hold/release, the reader's scroll dropping a held turn, re-send at rest,
  follow-the-screen past the limit, count reset per turn/user scroll (IN-01), and rebuild reset
  (WR-01, which becomes "stale generation ignored"). These move onto the `ReaderPosition` reducer
  almost one-for-one.
- `PagerSeedTests`: first real reading area, degenerate sizes.
- `PageHandlerTests` and `ContainerDataSourceTests`: the page-to-position mapping, dual-page and
  except-cover. This is the derived-position function the design leans on.
- `ReaderPagesAccessibilityTests`: next/previous actions go through the one turn intent.
- `AutoPlayHandlerTests`: tick produces a turn and stops at the last page.
- `ReadingOrientationTests`: direction/dual-page changes on rotation (a generation bump plus
  re-derived position).
- `AnalyticsEmissionTests` and the reducer session tests: progress persistence from `page`.

UI (EhPandaUITests/ReaderPageSyncUITests.swift, the end-to-end oracle for the invariant):
`testScrollingKeepsTheIndicatorOnThePageShown`, `testTheSliderLandsOnThePageItNames`,
`testThePagersTapZoneTurnsOnePage`, `testAutoPlayTurnsThePageAndKeepsTheIndicatorOnIt`,
`testReadingAgainResumesOnThePageLeft`, `testTurningTheDeviceKeepsTheResumedPageAtTheTop`,
`testTheStatusBarScrollsTheStripToItsFirstPageAndTheIndicatorFollows`; plus
`ReadingOrientationUITests` and `DuoReadingPanelUITests` for the iPad and direction paths.

Gaps to add with the redesign: a UI test that reloads all images (forced refresh) and then turns
the page, and one that changes direction mid-autoplay. Neither path is covered end to end today.
