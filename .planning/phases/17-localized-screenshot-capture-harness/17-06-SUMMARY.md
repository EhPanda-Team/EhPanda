---
phase: 17-localized-screenshot-capture-harness
plan: "06"
subsystem: testing
tags: [swift, python, capture, marketing, live-text, downloads, ui-tests, fixtures]
requires:
  - phase: 17-05
    provides: Capture routes to all eight screens, per-screen diagnostics, MarketingCaptureUITests and capture-native.py
  - phase: 17-03
    provides: The real marketing fixture schema, acquisition and the nonexplicit selection
provides:
  - Live Text records in the marketing fixture, recorded from the app's own recognizer by Scripts/visual/record-live-text.py
  - A Debug-only Live Text seam (LiveTextCapture) that replays a record through the reader's real overlay with Vision off, or lets a recording launch recognize the page
  - Download page files in the fixture and capture-owned download folders seeded with real page files and SHA-256 manifests, read back by the app's own scan
  - Diagnostics and UI test checks for the reading-live-text and downloads screens; all eight marketing screens capturable
affects: [17-07, 17-11, 17-21, marketing]
actuals:
  tokens: 53400
  tasks: 2
  commits: 6
tech-stack:
  added: []
  patterns: [record once from the running app and replay in every capture, seed through the app's own store and read back through its own scan, diagnostics as the only channel out of the app]
key-files:
  created:
    - AppPackage/Sources/ReadingFeature/Support/LiveTextCapture.swift
    - AppPackage/Sources/AppFeature/UITestSupport/CaptureLiveText.swift
    - AppPackage/Tests/ReadingFeatureTests/CaptureLiveTextTests.swift
    - AppPackage/Tests/AppFeatureTests/CaptureLiveTextRecordTests.swift
    - AppPackage/Tests/AppFeatureTests/CaptureDownloadTests.swift
    - Scripts/visual/record-live-text.py
    - Scripts/visual/test_record_live_text.py
  modified:
    - AppPackage/Sources/ReadingFeature/Support/LiveTextHandler.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/AppFeature/UITestSupport/CaptureScenePreparation.swift
    - AppPackage/Sources/AppFeature/UITestSupport/CaptureDiagnostics.swift
    - AppPackage/Sources/AppFeature/UITestSupport/CaptureFixtureManifest.swift
    - AppPackage/Sources/AppFeature/UITestSupport/CaptureSceneConfiguration.swift
    - AppPackage/Tests/AppFeatureTests/CaptureFixtureTests.swift
    - AppPackage/Tests/AppFeatureTests/CaptureRouteTests.swift
    - AppPackage/Tests/AppFeatureTests/CaptureSceneTests.swift
    - AppPackage/Tests/AppFeatureTests/CaptureScreenDiagnosticsTests.swift
    - EhPandaUITests/MarketingCaptureUITests.swift
    - EhPandaUITests/Support/CaptureLauncher.swift
    - Scripts/visual/fixtures.py
    - Scripts/visual/selection-review.py
    - Scripts/visual/test_fixtures.py
    - Scripts/visual/test_selection_review.py
    - Scripts/visual/README.md
key-decisions:
  - Live Text comes from a recording saved in the fixture; the capture never runs Vision. The recording runs the app's own recognizer on the iPhone visual simulator and leaves the app through the diagnostics channel, not logs (owner, 2026-10-09).
  - Acquisition saves the download galleries' page files, all pages of a complete entry and the first completedPages of any other, and the capture seeds capture-owned folders with them (owner, 2026-10-09).
  - Files beyond files_modified are allowed for CaptureDiagnostics, the fixture tooling and tests, the app's manifest decoding and the recording step (owner, 2026-10-09).
patterns-established:
  - A capture shows only what the running app itself produced: Live Text recorded from the app's recognizer, download folders written through the app's store and read back by its scan.
  - A record is validated against the exact page bytes (SHA-256), gallery, page and recognition languages before any capture replays it.
requirements-completed: []
---

# Phase 17 Plan 06: Live Text and Downloads in actual UI Summary

**The reading-live-text and downloads screens now show real state in the actual app. Live Text is
recognized once by the app's own recognizer on the pinned iPhone, saved in the fixture, and
replayed in every capture through the reader's real overlay with Vision off. Downloads lists
capture-owned folders holding real page files, whose manifests carry the files' SHA-256 hashes
and alone decide completeness. All eight marketing screens capture on both visual simulators with
byte-identical cold reruns.**

## Performance

- First source commit `169180e8f` at 2026-10-09T00:35:02Z, last `2d1828cf8` at
  2026-10-09T01:28:24Z.
- Tasks: 2/2. Source commits: 6. Documentation commits: 1 (this record with the owner decisions).
- Realized source diff: about 53,400 tokens (chars/4), against an estimate of 48,000.

## Accomplishments

- **Download pages in the fixture (T2).** `fixtures.collect` derives each download entry's pages
  (every page of a `completed` or `updateAvailable` entry, the first `completedPages` of any
  other) and resolves them as a download does: each batch's preview page and each saved page's
  reader page. Validation repeats the derivation; an incomplete entry must hold fewer pages than
  its gallery has.
- **Live Text records in the fixture (T1).** A `records/<gid>/liveText/<page>.json` entry with a
  null URL holds every group and line (ID, text, four normalized corners), the page image's
  SHA-256, the recognition languages and the recording simulator's model and runtime build.
  `fixtures.validate_live_text` and `publish_records` validate and publish it into a new
  content-addressed version that keeps every other file.
- **The reader seam (T1).** `LiveTextCapture`, Debug only, decides per page: replay the record's
  groups on the capture's page, recognize it for a recording, or leave other pages without Live
  Text. The reader then starts with Live Text on, as the toolbar button leaves it, and the real
  `LiveTextView` draws every line. A request from another gallery is kept as the outcome, so the
  capture fails rather than show foreign groups.
- **Replay and recording scenes (T1).** The `reading-live-text` scene decodes the record with
  strict keys at every level and replays it only once its gallery, page, schema, page bytes and
  recognition languages (from the parsed detail's language) match and every line has text and an
  extent overlapping the page. The `live-text-recording` scenario opens the same reader page and
  lets the reader recognize it.
- **Seeded downloads (T2).** A downloads scene writes one folder per entry under
  `EhPandaCapture/Downloads/Default/` through the app's `DownloadStore`: cover, held page files and
  a manifest built as `makeInitialManifest` builds it, each held page's hash computed from the
  written file. The app's own scan reads them back; each row must read back exactly as written
  and derive the selection's status from the manifest, with only `active` and `queued` coming
  from the simulated queue. `DownloadClient.capture` lists the index and changes nothing.
- **Diagnostics (T1, T2).** The reader reads as `reading-live-text` once it shows the page's Live
  Text and fails on Live Text of another gallery or page, or on an empty recognition; Downloads
  waits for every row's cover. `liveText` and `downloads` report what the screen shows.
- **UI test and recorder (T2).** `CaptureLauncher` requires `reading-live-text` to show exactly
  the fixture's record, each ID once, and `downloads` to show each entry's status, page count and
  page files, with every gallery shown once. `testRecordLiveText` and `record-live-text.py`
  record the page once on the pinned iPhone without retries, verify the attached diagnostics, put
  back appearance and orientation, and publish the record unless the sources, the pin or the
  current version changed.

## Task Commits

1. `169180e8f`, T2: acquire download folder pages.
2. `d7226efa0`, T1: hold Live Text records in fixtures.
3. `34997db21`, T1: let captures drive the reader's Live Text.
4. `632ead924`, T1: replay Live Text records in captures.
5. `f589e84d7`, T2: seed capture download folders.
6. `2d1828cf8`, T2: record Live Text, verify captures.

## Verification

The plan's commands, run sequentially with the iPhone then the iPad, no retries:

```sh
xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests \
  -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:ReadingFeatureTests/CaptureLiveTextTests
xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests \
  -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:AppFeatureTests/CaptureDownloadTests
```

| Check | Evidence | Result |
|---|---|---|
| T1 plan command | `.capture/17-06-h-unit-t1-phone/`, `-t1-tablet/` | 5 tests pass on each device, no Repetition |
| T2 plan command | `.capture/17-06-h-unit-t2-phone/`, `-t2-tablet/` | 6 tests pass on each device, no Repetition |
| Unit targets during T1, T2 | `.capture/17-06-t1-unit-01/` to `-03/`, `17-06-t2-unit-01/` | AppFeatureTests 89, then 101, then 107 tests pass; ReadingFeatureTests 34 |
| Full FeatureTests plan | `.capture/17-06-h-unit-full-phone/` | Every target except VisualSnapshotTests passes (AppFeatureTests 107, ReadingFeatureTests 34, DownloadsFeatureTests 490); 9 VisualSnapshotTests cases fail bare outside the gate's pinned environment, as in 17-05 |
| Isolation UI test | `.capture/17-06-h-isolation-02/` | Passes once on each visual simulator; a first attempt without the fixture variable is recorded as invalid in `17-06-h-isolation/` |
| Commit trees | `.capture/commit-trees-09/` to `-14/` | Each commit builds clean for testing with strict SwiftLint and 0 diagnostics; visual suite 166 to 179 tests pass |
| Release | `.capture/17-06-release-check-01/` | Builds with no warning; no Release binary holds a capture or Live Text capture string, which the Debug build does hold |
| Acquisition | `.capture/17-06-acquire-01.log` | `marketing-26f480c3de513ceb`: the active download's 2 pages and all 27 pages of the completed one |
| Live Text recording | `.capture/17-06-live-text-record-01/` | 8 groups, 35 lines, `en-US`, on the pinned iPhone 24A434; published `marketing-4f2a1ba8efe6f7cb` |
| Eight screens x 2 devices | `.capture/17-06-g-inputs/`, `.capture/17-06-g-native-*/` | All 16 coordinates (English, light) captured, each from two byte-identical cold launches; iPad Home matches the 17-05 gate frame (`910827a3…`) |

## Review

The inline review reread every 17-06 change after the captures: the reader seam and its Debug
guards, the record decoding and replay checks, the seeding and read-back through the app's store
and scan, the status mirror against `DownloadCoordinator`'s derivation (identical except that a
capture has no error to show, which the scene refuses), the diagnostics, the launcher's checks,
the fixture tooling and the recorder. It found no defect.

## Decisions and Deviations

- **Owner decisions, 2026-10-09**, recorded in 17-06-PLAN.md: Live Text from a recording saved
  in the fixture, recorded from the running app through the diagnostics channel; download page
  files in the fixture; the files beyond `files_modified` listed above.
- **The status mirror.** The app derives a row's status inside `DownloadCoordinator` from its
  own queue and error state, so the seeding mirrors that rule for the simulated queue and checks
  every row reads back as the selection's status.
- The plan names `scripts/visual`; the repository directory is `Scripts/visual`.
- No acceptance criterion or threshold changed.

## Unresolved Gates

1. **Owner visual review of the 16 frames** (sent 2026-10-09). Points raised for the owner: the
   reader hides its toolbar and status bar on the Live Text screen; Vision read the vertical
   "HAHAHA" as "DID" and missed a few short bubbles, and every recognized line is drawn as
   recorded; Downloads shows the selection's two rows, with the galleries' posted dates.
2. **Owner gallery input for the explicit set** (carried).
3. **Whether the status bar follows each coordinate's locale** (carried to 17-07).
4. **Final selection** with owner authority remains the Phase 17 closure checkpoint (17-21).

## Issues Encountered

- The first batch capture script stopped after its first coordinate on zsh's read-only
  `status` variable; that coordinate had captured, and the fixed script resumed from the next.
- Another local session's simulators stayed booted throughout; every run used the dedicated
  visual simulators or the unit-test simulators, checked before each run, and both visual
  simulators ended Shutdown.
