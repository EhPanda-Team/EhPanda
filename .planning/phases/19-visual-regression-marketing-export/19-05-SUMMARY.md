---
phase: 19-visual-regression-marketing-export
plan: "05"
subsystem: testing
tags: [snapshot, scenarios, xctest, swiftui, tca]

requires:
  - phase: 19-02
    provides: "scenarios.json (schema 2), the group catalog files, SnapshotMatrixCase and run-snapshot-local.sh"
provides:
  - "Factories for all 34 `plan: 19-05` scenarios in `ScenarioCatalog+Browsing.swift`, each on the real view and reducer"
  - "Eight matrix classes in `BrowsingSnapshotTests.swift`: FirstLaunch, Shell, Home, FrontPage, Popular, Watched, Toplists, History"
  - "Test-side user steps reused by later plans: `BrowsingScenarios.activate` (VoiceOver activation, then the bar button's primary action), `focusSearchField`, `freezeIndicators`, `ListContent`"
affects: [19-04, 19-06, 19-07, 19-08, 19-10, 19-13]

actuals:
  tokens: 120000
  tasks: 3
  commits: 2

tech-stack:
  added: []
  patterns:
    - "List and grid are set in the scenario's own app storage (`Setting.galleryListPresentation[scope]`), where GalleryLayoutPicker keeps them"
    - "A still frame for loading indicators and the text caret: stop the hosted view's layer clock after the state is reached; every attempt hosts a fresh controller"
    - "A toolbar control UIKit draws (`_UIButtonBarButton`) refuses `accessibilityActivate()`; its `UIControl.performPrimaryAction()` opens its menu or runs its button, as VoiceOver's tap would"

key-files:
  created: []
  modified:
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Browsing.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/BrowsingSnapshotTests.swift

key-decisions:
  - "Synthetic galleries are the 19-01 Home fixtures (`TracerScenarios.homeGalleries`, `PublicVisualFixtures`) with their artwork cached before hosting. No `Fixtures/BrowsingFixtures.swift` was needed (see Deviations)."
  - "Empty states are the reducers' own empty state, `.failed(.notFound)`, which is what History, Watched and Front Page set when a load returns nothing."
  - "The Toplists period menu is a SwiftUI `Menu` with no reducer state. It is opened through the user path (the bar button's primary action), not proposed not applicable."
  - "History's Clear confirmation is the reducer's own `confirmationDialog`, reached through the Clear button."
  - "Front Page search: the typed query is reducer state (`keyword`); the field's focus is a `becomeFirstResponder` on the search field, as a tap would give. The keyboard window is not drawn (D-05)."

patterns-established:
  - "One class per group, one method per scenario; `capture(scenario:)` reads the catalog"

requirements-completed: []

coverage:
  - id: D1
    description: "34 factories on real views and reducers; one class per group"
    requirement: VIS-18-01
    verification:
      - kind: integration
        ref: "run-snapshot-local.sh --device phone --config en-large, Task 1 and Task 2 classes: candidate then compare"
        status: pass
    human_judgment: false
  - id: D2
    description: "Deterministic on both devices in en-large and on the phone in ja-accessibility5 and de-xSmall"
    requirement: CAP-17-01
    verification:
      - kind: integration
        ref: "Task 3: phone en-large 132 recorded / 132 + 132 passed; pad en-large 66 / 66 + 66; ja-accessibility5 132 / 132; de-xSmall 132 / 132; 0 changed, timeout, error or flaky"
        status: pass
    human_judgment: false
  - id: D3
    description: "No real content in a picture"
    requirement: VIS-18-01
    verification:
      - kind: manual
        ref: "19-13 pre-check of every picture (T-19-11)"
        status: pending
    human_judgment: true

duration: one session
completed: 2026-11-07
status: complete
---

# Phase 19 Plan 05: First launch, shell and browsing scenarios Summary

**All 34 browsing scenarios capture through their real views and reducers. They pass two compares on both devices
in `en-large` and one compare each in `ja-accessibility5` and `de-xSmall` on the phone, with no changed, timed-out,
errored or flaky picture.**

## Performance

- **Tasks:** 3 (Task 3 is runs only; it changed no file)
- **Files modified:** 2

## Accomplishments

- **First launch, shell and Home** (Task 1). The age wall unticked and ticked, and the analytics choice with nothing
  selected, then Minimal, Basic and Full, all on `FirstLaunchReducer` state. The Library sidebar (iPad) and title
  menu (iPhone) on the real `LibraryView`. Home populated, loading and failed.
- **List pages** (Task 2). Front Page, Popular, Watched, Toplists and History, each in list and grid, plus their
  loading, error, empty and signed-out states. Toplists has three galleries per period. Three states need a user
  step: the Toplists period menu, History's Clear confirmation and Front Page search with a focused field.
- **Both devices and other configurations** (Task 3), all eight classes:

| Run | Candidate | Compare 1 | Compare 2 |
|-----|-----------|-----------|-----------|
| `$PHONE` en-large | 132 recorded, 4 n/a (218 s) | 132 passed (207 s) | 132 passed (224 s) |
| `$PAD` en-large (portrait) | 66 recorded, 2 n/a (317 s) | 66 passed (377 s) | 66 passed (416 s) |
| `$PHONE` ja-accessibility5 | 132 recorded, 4 n/a (288 s) | 132 passed (194 s) | — |
| `$PHONE` de-xSmall | 132 recorded, 4 n/a (206 s) | 132 passed (207 s) | — |

Wall times include the build and the simulator preparation.

**Per-class capture seconds** (sum of picture seconds from `results.jsonl`, en-large compare 1; captured /
not applicable):

| Class | `$PHONE` | `$PAD` portrait |
|-------|----------|-----------------|
| FirstLaunchSnapshotTests | 37.0 s (24 / 0) | 17.0 s (12 / 0) |
| ShellSnapshotTests | 6.4 s (4 / 4) | 3.2 s (2 / 2) |
| HomeSnapshotTests | 17.8 s (12 / 0) | 15.6 s (6 / 0) |
| FrontPageSnapshotTests | 35.4 s (24 / 0) | 22.4 s (12 / 0) |
| PopularSnapshotTests | 22.6 s (16 / 0) | 12.0 s (8 / 0) |
| WatchedSnapshotTests | 28.5 s (20 / 0) | 14.9 s (10 / 0) |
| ToplistsSnapshotTests | 22.9 s (16 / 0) | 12.0 s (8 / 0) |
| HistorySnapshotTests | 24.1 s (16 / 0) | 12.9 s (8 / 0) |
| **Total** | **194.7 s (132 / 4)** | **110.1 s (66 / 2)** |

That is about 1.5 s per picture on the phone and 1.7 s on the iPad, under the 2.4 s of the model cost table that
19-04 replaces.

**Proposed not-applicable rules:** none. The two by-design rules already in `scenarios.json` (the sidebar is
iPad-only, the title menu iPhone-only) are the only ones that apply.

- **Verification:**
  - SwiftLint (strict, no cache) on `AppPackage/Tests/VisualSnapshotTests/Matrix`: 0 violations.
  - The prohibition greps: no `#if` capture branch and no test-only launch key were added; only test files changed.

## Task Commits

1. **Task 1: First launch, shell and Home** - `827c0ef7e` (test)
2. **Task 2: Front Page, Popular, Watched, Toplists and History** - `92e62f838` (test)
3. **Task 3: Both devices and other configurations** - no commit; the runs needed no change.

## Decisions Made

See `key-decisions`.

## Deviations from Plan

1. **No `AppPackage/Sources/VisualSnapshotSupport/Fixtures/BrowsingFixtures.swift`.** The plan lists it, but the
   browsing pages need only the 19-01 Home galleries and their artwork, which `TracerScenarios` and
   `PublicVisualFixtures` already provide. `VisualSnapshotSupport` depends on nothing but SnapshotTesting, so it
   could hold only plain data, not `Gallery` values. The fixtures stay test-side.
2. **The Toplists period menu is captured, not proposed not applicable.** The plan opens menus "through the view's
   own state where it has one, otherwise" proposes not applicable. The menu has no state, but the bar button opens
   it through `UIControl.performPrimaryAction()`, which is the user path and adds no app code. The picture shows the
   real menu.
3. **iPad runs are portrait only.** The plan's verify command passes no `--orientation`, so the iPad runs took the
   runner's default, portrait. iPad landscape needs a second process per configuration (19-01) and runs in 19-10's
   shards.

## Issues Encountered

- **One wrong picture in an early Task 2 candidate run.** `toplists-grid__en__large__portrait__iphone__dark` was
  recorded as the list layout, so the following compare reported it `changed`. The cause was not found: each
  coordinate gets a fresh in-memory app storage and writes the grid mode before the store is built. It did not
  recur in any of the later runs: Task 2 again, then all ten Task 3 runs, with 10 to 20 grid pictures in each. If it comes
  back, look at how the `Setting` app-storage reference is shared between the scenario's write and the store.
- **The three user steps at first failed.** VoiceOver activation (`accessibilityActivate()`) returns `false` on a
  bar button UIKit draws. The step now falls back to the control's primary action. The Front Page search step first
  timed out on the settle: the caret blinks. The layer clock is now stopped after the field has focused.
- **The host's 30-minute task limit.** The Task 3 runs were split across three invocations; the runs and their
  results are unchanged.

## User Setup Required

None.

## Next Phase Readiness

- 19-06 to 19-08 can reuse `BrowsingScenarios.ListContent` (list, grid, loading, failed) and the user steps.
- 19-04 can take the per-class seconds above as measured costs.
- 19-10's inventory check now finds a factory for every `plan: 19-05` scenario.
