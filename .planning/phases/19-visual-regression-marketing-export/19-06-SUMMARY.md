---
phase: 19-visual-regression-marketing-export
plan: "06"
subsystem: testing
tags: [snapshot, scenarios, xctest, swiftui, tca]

requires:
  - phase: 19-02
    provides: "scenarios.json (schema 2), the group catalog files, SnapshotMatrixCase and run-snapshot-local.sh"
  - phase: 19-05
    provides: "BrowsingScenarios user steps (activate, focusSearchField, freezeIndicators) and ListContent"
provides:
  - "Factories for all 36 `plan: 19-06` scenarios in `ScenarioCatalog+Library.swift`, each on the real view and reducer"
  - "Five matrix classes in `LibrarySnapshotTests.swift`: Search, QuickSearch, Favorites, Downloads, GalleryDetail"
  - "Synthetic search history, saved searches, tag translations, download records and folders in `Fixtures/LibraryFixtures.swift`"
  - "The rest step for list pages: every scroll view of the page is pulled past its top and let rest there"
  - "A settle that compares reads as the comparison reads them (8-bit sRGB), in `HostedWindowCapture`"
affects: [19-04, 19-07, 19-08, 19-10, 19-12, 19-13]

actuals:
  tokens: 260000
  tasks: 3
  commits: 5

tech-stack:
  added: []
  patterns:
    - "A list page rests at its top before capture: each scroll view of the page is pulled 400 points past its top and returned, in one main-thread turn, before any confirmation from the initial state is presented"
    - "A bar menu is opened through the trailing-most control of the page's navigation bars (outside the search field), never by its localized label"
    - "Settle compares the reads in the comparison's own form: 8-bit sRGB, premultiplied RGBA"

key-files:
  created:
    - AppPackage/Sources/VisualSnapshotSupport/Fixtures/LibraryFixtures.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/LibrarySnapshotTests.swift
  modified:
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Library.swift
    - AppPackage/Sources/VisualSnapshotSupport/HostedWindowCapture.swift

key-decisions:
  - "Search typing with tag suggestions: the field is focused and the word is typed a key at a time with `insertText`; the keyboard is a separate window and is not drawn (D-05). The caret is held still once the suggestions have appeared."
  - "Quick Search and Filters are the sheets the Search root's own destination presents; Date Seek is the search results' destination, opened on a fixed date."
  - "Confirmations are each reducer's own alert or dialog: Search's Remove All, Quick Search's delete and the Filters reset, Downloads' delete and move (DownloadRowFeature's actions), the gallery page's delete-download and retry alerts."
  - "Download progress is a still: a fixed count of landed pages. The inspector is the list destination's sheet with a fixed inspection."
  - "Gallery detail runs on DetailReducer for the first synthetic gallery, seeded from its download record as the Downloads tab seeds it. On iPad the gallery sheet is the app's own presentation state over the Search tab."
  - "The settle change is a root fix, not a tolerance: any change the comparison can see still restarts the wait; only bits the comparison never reads are ignored."

patterns-established:
  - "One class per group, one method per scenario; `capture(scenario:)` reads the catalog"

requirements-completed: []

coverage:
  - id: D1
    description: "36 factories on real views and reducers; one class per group"
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
        ref: "Task 3: phone en-large 140 / 140 + 140; pad en-large 72 / 72 + 72; ja-accessibility5 140 / 140; de-xSmall 140 / 140; 0 changed, timeout or error; 1 flaky (phone en-large compare 2)"
        status: pass
    human_judgment: false
  - id: D3
    description: "No real content or real search words in a picture"
    requirement: VIS-18-01
    verification:
      - kind: manual
        ref: "19-13 pre-check of every picture (T-19-11, T-19-13)"
        status: pending
    human_judgment: true

duration: one session
completed: 2026-11-08
status: complete
---

# Phase 19 Plan 06: Search, Favorites, Downloads and gallery detail scenarios Summary

**All 36 scenarios for Search, Quick Search, Filters, Date Seek, Favorites, Downloads and the gallery page capture
through their real views and reducers. They pass two compares on both devices in `en-large` and one compare each in
`ja-accessibility5` and `de-xSmall` on the phone, with no changed, timed-out or errored picture.**

## Performance

- **Tasks:** 3, plus two fixes found in Task 3
- **Files:** 2 created, 2 modified

## Accomplishments

- **Search, Quick Search, Filters, Date Seek, Favorites** (Task 1, 20 scenarios). The Search root is empty or holds
  synthetic recent searches and recently viewed galleries. Its results page shows a list, a grid, an empty state and
  an error. Tag suggestions come from synthetic translations. Favorites is shown in list, grid, empty and signed-out
  states, and with its menu open.
- **Downloads and gallery detail** (Task 2, 16 scenarios). Downloads covers list, grid, empty, an active download
  beside a failed one, the delete and move confirmations, and the inspector with and without failed pages. The
  gallery page covers loaded, loading, failed, the rating row, a download in progress, and the delete-download and
  retry confirmations. The gallery sheet is iPad-only, as its existing rule says.
- **Both devices and other configurations** (Task 3). Final runs, on the final code (`44ba5eaa2`), all five classes:

| Run | Candidate | Compare 1 | Compare 2 |
|-----|-----------|-----------|-----------|
| `$PHONE` en-large | 140 recorded, 4 n/a (225 s) | 140 passed (220 s) | 140 passed, 1 flaky (404 s) |
| `$PAD` en-large (portrait) | 72 recorded (221 s) | 72 passed (323 s) | 72 passed (219 s) |
| `$PHONE` ja-accessibility5 | 140 recorded, 4 n/a (304 s) | 140 passed (282 s) | — |
| `$PHONE` de-xSmall | 140 recorded, 4 n/a (266 s) | 140 passed (545 s) | — |

Wall times include the build, the simulator preparation and waits for another project's xcodebuild on the host.
The 19-05 classes were compared once against the 19-05 phone en-large candidate after the settle change: 132 passed,
0 flaky.

**Per-class capture seconds** (sum of picture seconds from `results.jsonl`, en-large compare 1; captured / not
applicable):

| Class | `$PHONE` | `$PAD` portrait |
|-------|----------|-----------------|
| SearchSnapshotTests | 50.6 s (32 / 0) | 29.7 s (16 / 0) |
| QuickSearchSnapshotTests | 40.4 s (28 / 0) | 26.3 s (14 / 0) |
| FavoritesSnapshotTests | 34.1 s (20 / 0) | 21.7 s (10 / 0) |
| DownloadsSnapshotTests | 48.2 s (32 / 0) | 28.8 s (16 / 0) |
| GalleryDetailSnapshotTests | 41.0 s (28 / 4) | 28.8 s (16 / 0) |
| **Total** | **214.3 s (140 / 4)** | **135.3 s (72 / 0)** |

That is about 1.5 s per picture on the phone and 1.9 s on the iPad.

**Proposed not-applicable rule (for 19-10; `scenarios.json` is not edited here):**

- `favorites-category-menu`, `when: { family: ipad }`. Reason: on iPad the favorites categories are the sidebar's
  Favorites section; the bar's menu there holds only Seek to Date and Quick Search. The iPad picture today is that
  menu over the list, with the categories in the sidebar, which `favorites-list` already shows. If 19-10 keeps the
  iPad coordinate instead, the scenario's state text should say "the bar menu" for iPad.

- **Verification:**
  - SwiftLint (strict, no cache): `AppPackage/Tests/VisualSnapshotTests/Matrix` 0 violations (11 files);
    `AppPackage/Sources/VisualSnapshotSupport` 0 violations (10 files).
  - Every `plan: 19-06` ID in `scenarios.json` (36) has a method in `LibrarySnapshotTests.swift`, and every method
    names a 19-06 ID.
  - No app-target file changed; only test and `VisualSnapshotSupport` files. Fixture words are invented and neutral
    (T-19-13).

## Task Commits

1. **Task 1: Search, Quick Search, Filters, Date Seek, Favorites** - `97967f85b` (test)
2. **Task 2: Downloads and gallery detail** - `6602f79a5` (test)
3. **Task 3: Both devices and other configurations** - three fixes:
   - `34dc087a5` (fix) lists rest at their top before capture
   - `614667a7e` (fix) the rest step and the overflow menu in every language
   - `44ba5eaa2` (fix) settle on the picture the comparison reads

## Decisions Made

See `key-decisions`.

## Deviations from Plan

1. **`HostedWindowCapture.swift` changed (a 19-01 file, not in this plan's file list).** The settle compared PNG
   bytes of the 16-bit capture. Liquid Glass changes the capture's low bits from read to read (up to 56 of 65535 on
   an alert), which the comparison never reads: it draws both pictures into 8-bit sRGB. The landscape dark
   delete-download confirmation took 8 to 40 reads from one process to the next and once timed out on both attempts.
   The settle now compares reads in the comparison's 8-bit form. A settle can only end at the same read or earlier.
   After the change the same picture settled in 8 or 9 reads in four processes. The 19-05 classes still pass against
   their 19-05 candidate.
2. **Task 1 and Task 2 verify runs used `/tmp/ehp19/r06/…` output directories instead of `$TMPDIR/ehp19-06a|b|c`.**
   The commands are otherwise the plan's.
3. **iPad runs are portrait only**, as in 19-05: the verify command passes no `--orientation`. iPad landscape runs in
   19-10's shards.

## Issues Encountered

- **The search field latched part-way collapsed** on the first Favorites or Downloads capture of a process, so a
  picture was stable within a run but changed between runs. Fixed in `34dc087a5`: the list is pulled past its top
  and rests there, as a user's pull does.
- **ja-accessibility5: the rest step and the menu.** The list there has two scroll views (the collection view and
  SwiftUI's hosting scroll view); the bar followed the second. The step now pulls every scroll view, by 400 points
  (more than the 134 points of title and field at accessibility5). The category menu was opened by its English label
  "More", which the system localizes; it is now opened through the trailing-most bar control. Both in `614667a7e`.
- **One flaky picture, `search-root-empty` landscape light** (phone en-large compare 2: the first attempt differed,
  the retry passed). The same picture made the first de-xSmall run fail: that candidate settled after 5 reads (the
  minimum), and every later compare differed from it by 1 level on 587 pixels in the search field and title area.
  The usual settle there takes 10 reads, so the glass appears to change once about half a second after hosting, and
  a read that is still for 500 ms before that change can settle early. The de-xSmall runs were repeated from a new
  candidate and passed. Not fixed here. **Risk for 19-12:** a candidate captured before that change would be a wrong
  reference. If it recurs, look at what the search bar's glass updates after hosting, and wait for it in the scenario.
- **Other single flakes seen once each while fixing** (retry passed, not seen in the final runs):
  `gallery-detail-loaded` portrait light (de-xSmall), `favorites-grid` portrait dark (de-xSmall).
- **The host** was shared with another project's xcodebuild; `run-snapshot-local.sh` waits for it, which explains
  the longer wall times.

## User Setup Required

None.

## Next Phase Readiness

- 19-07 and 19-08 can reuse the rest step and the bar-menu opener in `ScenarioCatalog+Library.swift`.
- 19-04 can take the per-class seconds above as measured costs.
- 19-10's inventory check now finds a factory for every `plan: 19-06` scenario; it should decide on the proposed
  iPad rule for `favorites-category-menu`.
- VIS-18-01 and CAP-17-01 stay Pending (later plans share them).
