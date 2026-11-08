---
phase: 19-visual-regression-marketing-export
plan: "07"
subsystem: testing
tags: [snapshot, scenarios, xctest, swiftui, tca]

requires:
  - phase: 19-02
    provides: "scenarios.json (schema 2), the group catalog files, SnapshotMatrixCase and run-snapshot-local.sh"
  - phase: 19-06
    provides: "The settle on the comparison's 8-bit read, the rest step and the gallery page on DetailReducer"
provides:
  - "Factories for all 37 `plan: 19-07` scenarios in `ScenarioCatalog+Gallery.swift`, each on the real view and reducer"
  - "Five matrix classes in `GallerySnapshotTests.swift`: Comments, ReportForm, DetailPages, DetailPagesMore, Reader"
  - "Synthetic comments, report form, archives, funds, torrents, tag, greeting and Live Text observations in `Fixtures/GalleryFixtures.swift`"
  - "A fixed Swift hash seed in every configuration of `SnapshotMatrix.xctestplan`"
affects: [19-04, 19-08, 19-10, 19-12, 19-13]

actuals:
  tokens: 250000
  tasks: 3
  commits: 5

tech-stack:
  added: []
  patterns:
    - "Snapshot processes run with SWIFT_DETERMINISTIC_HASHING=1, so anything a view builds from a dictionary's order is the same in every run"
    - "A reducer client that would reach the network waits without end in a scenario, so a loading or sending state holds and no request leaves the process"

key-files:
  created:
    - AppPackage/Sources/VisualSnapshotSupport/Fixtures/GalleryFixtures.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/GallerySnapshotTests.swift
  modified:
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Gallery.swift
    - AppPackage/Tests/SnapshotMatrix.xctestplan

key-decisions:
  - "Comments runs on CommentsView and CommentsReducer. The blocked author is matched by member ID (D-03). The posting warning is the reducer's own: Post over a draft that the scenario's one-word filter list matches; the word is invented and neutral."
  - "The Report form is the comment's Report, presented by Comments with ReportFormFeature's state. Its load and send clients wait without end (T-19-15). The email is on a reserved example domain."
  - "Previews, Gallery Info and Detail Search are pushed pages; Archives, Torrents, Tag Detail, New Dawn and the Folder Manager are the gallery page's sheets from DetailReducer's destination. An empty Torrents page is the reducer's not-found answer."
  - "The app has no state of its own for funds too low to pay for an archive. `detail-pages-archives-insufficient-funds` shows balances below every price, with the 1280x archive chosen."
  - "The reader opens the reader-vertical-finite pages as a downloaded gallery. Direction and spread are the persisted reading settings, with automatic layout off for those two. Live Text replays one recorded line over the page's marker through the reader's capture seam; recognition never runs (D-12)."
  - "Gallery Info's Torrent URL query order follows the per-process hash seed. The fix is in the test plan (a fixed seed), not in the app (no app code in this plan)."

patterns-established:
  - "One class per group, one method per scenario; `capture(scenario:)` reads the catalog"

requirements-completed: []

coverage:
  - id: D1
    description: "37 factories on real views and reducers; one class per group, the detail pages over two classes"
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
        ref: "Task 3: phone en-large 146 / 146 + 146; pad en-large 72 / 72 + 72; ja-accessibility5 146 / 146; de-xSmall 146 / 146; 0 changed, timeout or error; 2 flaky (one each in ja-accessibility5 and de-xSmall)"
        status: pass
    human_judgment: false
  - id: D3
    description: "No member name or real comment text in a picture; no report sent"
    requirement: VIS-18-01
    verification:
      - kind: manual
        ref: "19-13 pre-check of every picture (T-19-14)"
        status: pending
    human_judgment: true

duration: one session
completed: 2026-11-08
status: complete
---

# Phase 19 Plan 07: Comments, Report form, detail pages and reader scenarios Summary

**All 37 scenarios for Comments, the Report form, the gallery's detail pages and the reader capture through their
real views and reducers. They pass two compares on both devices in `en-large` and one compare each in
`ja-accessibility5` and `de-xSmall` on the phone, with no changed, timed-out or errored picture.**

## Performance

- **Tasks:** 3, plus one fix found in Task 3
- **Files:** 2 created, 2 modified

## Accomplishments

- **Comments and the Report form** (Task 1, 15 scenarios). Comments covers the list, a row's menu, the block
  confirmation, a blocked row collapsed and shown, Post Comment empty and filled, and the posting warning. The Report
  form covers loading, ready, filled, sending, sent, unavailable and the error alert.
- **Detail pages and the reader** (Task 2, 22 scenarios). Previews (loaded and loading), Gallery Info, Detail Search
  (list and grid), Archives (and insufficient funds), Torrents (and empty), Tag Detail, New Dawn and the Folder
  Manager (and its delete confirmation). The reader covers horizontal, vertical, the two-page spread, controls, the
  slider scrub, a failed page, a loading page, Live Text and the settings sheet.
- **Both devices and other configurations** (Task 3). Final runs, on the final code (`dac4956af`), all five classes:

| Run | Candidate | Compare 1 | Compare 2 |
|-----|-----------|-----------|-----------|
| `$PHONE` en-large | 146 recorded, 2 n/a (202 s) | 146 passed (203 s) | 146 passed (205 s) |
| `$PAD` en-large (portrait) | 72 recorded, 2 n/a (520 s) | 72 passed (497 s) | 72 passed (476 s) |
| `$PHONE` ja-accessibility5 | 146 recorded, 2 n/a (250 s) | 146 passed, 1 flaky (291 s) | — |
| `$PHONE` de-xSmall | 146 recorded, 2 n/a (224 s) | 146 passed, 1 flaky (362 s) | — |

Wall times include the build, the simulator preparation and waits for another project's xcodebuild on the host
(the iPad runs waited about five minutes each). The two not-applicable pictures per run are
`reader-two-page-spread` in portrait, by its existing rule.

**Per-class capture seconds** (sum of picture seconds from `results.jsonl`, en-large compare 1; captured / not
applicable):

| Class | `$PHONE` | `$PAD` portrait |
|-------|----------|-----------------|
| CommentsSnapshotTests | 58.3 s (32 / 0) | 33.3 s (16 / 0) |
| ReportFormSnapshotTests | 51.6 s (28 / 0) | 29.0 s (14 / 0) |
| DetailPagesSnapshotTests | 40.3 s (28 / 0) | 25.5 s (14 / 0) |
| DetailPagesMoreSnapshotTests | 28.8 s (24 / 0) | 20.4 s (12 / 0) |
| ReaderSnapshotTests | 47.3 s (34 / 2) | 26.1 s (16 / 2) |
| **Total** | **226.3 s (146 / 2)** | **134.3 s (72 / 2)** |

That is about 1.6 s per picture on the phone and 1.9 s on the iPad.

**Proposed not-applicable rules (for 19-10):** none. Every 19-07 scenario renders on both devices, in both
orientations, through its real view. The only not-applicable pictures come from the existing
`reader-two-page-spread` portrait rule.

- **Verification:**
  - SwiftLint (strict, no cache): `AppPackage/Tests/VisualSnapshotTests/Matrix` 0 violations (12 files);
    `AppPackage/Sources/VisualSnapshotSupport` 0 violations (11 files).
  - Every `plan: 19-07` ID in `scenarios.json` (37) has a method in `GallerySnapshotTests.swift`, and every method
    names a 19-07 ID.
  - No app-target file changed. Fixture comments, member IDs, tags and the report email are synthetic (T-19-14).
    The Report form's clients never return, so no report can be sent (T-19-15).

## Task Commits

1. **Task 1: Comments and the Report form** - `eda416fde` (test)
2. **Task 2: Detail pages and the reader** - `5c8417e7f` (test)
3. **Task 3: Both devices and other configurations** - `dac4956af` (test) pin the Swift hash seed in the snapshot
   plan

## Decisions Made

See `key-decisions`.

## Deviations from Plan

1. **`SnapshotMatrix.xctestplan` changed (a 19-01 file, not in this plan's file list).** Gallery Info shows a
   Torrent URL. `URLUtil.galleryTorrents` builds its query from a `[Key: Value]` dictionary, so `gid` and `t` swap
   places from one launch to the next as Swift's per-process hash seed changes. In the first Task 3 pass, iPad
   en-large compare 2 had `detail-pages-gallery-info` portrait dark `changed` on both attempts. Earlier phone runs had
   passed the same picture only on its retry (flaky). The plan now sets `SWIFT_DETERMINISTIC_HASHING=1` in its
   default options and in all 18 configurations. Check: an iPad Gallery Info candidate, then four compares, passed
   8 / 8 pictures on the first attempt. All Task 3 runs above were repeated after the change. The app's query order
   itself is unchanged; see Issues.
2. **Verify runs used `/tmp/ehp19/r07/…` output directories instead of `$TMPDIR/ehp19-07…`.** The commands are
   otherwise the plan's.
3. **iPad runs are portrait only**, as in 19-05 and 19-06: the verify command passes no `--orientation`. iPad
   landscape runs in 19-10's shards.

## Issues Encountered

- **The Torrent URL's query order is not stable in the app.** The fixed seed hides this in snapshots. In the shipped
  app the URL still changes order between launches, which works but is untidy (copy, share, cache keys). A follow-up
  could build that query from an ordered list. That is app code, outside this phase's scope.
- **Flaky pictures** (first attempt differed, the retry passed):
  - In final runs: `report-form-unavailable` ja-accessibility5 landscape light and `reader-slider-scrub` de-xSmall
    portrait light (each in compare 1).
  - Seen while building, before the seed fix: `reader-controls` portrait dark, `report-form-filled` portrait dark,
    and `detail-pages-gallery-info` portrait light and dark. The Gallery Info flakes were the hash-seed cause above.
    The others were not seen again.
- **Archives on the phone in landscape:** the archive rows appear to sit partly behind the funds row in the sheet.
  The scenario uses the real view, so this looks like the app's layout at that size. It is worth a look in the 19-13
  review of the pictures.
- **The host** was shared with another project's xcodebuild. `run-snapshot-local.sh` waits for it, which explains
  the longer iPad wall times.

## User Setup Required

None.

## Next Phase Readiness

- 19-08 inherits the fixed hash seed. A scenario with a dictionary-ordered value no longer needs its own fix.
- 19-04 can take the per-class seconds above as measured costs.
- 19-10's inventory check now finds a factory for every `plan: 19-07` scenario. No new rule is proposed.
- VIS-18-01 and CAP-17-01 stay Pending (later plans share them).
