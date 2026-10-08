---
phase: 17-localized-screenshot-capture-harness
plan: "05"
subsystem: testing
tags: [swift, python, capture, marketing, ui-tests, xcuiscreen, simctl, determinism, status-bar]
requires:
  - phase: 17-04
    provides: The isolated offline capture launch, the Home scene and the capture_diagnostics element
  - phase: 17-24
    provides: The tracked rendering pin (Scripts/visual/regression-environment.json) and environment.py
  - phase: 17-03
    provides: The real marketing fixture schema and the nonexplicit selection
provides:
  - Eight capture routes through the app's own navigation (home, detail, comments, filters, reading, reading-live-text, downloads, laboratory)
  - Per-screen capture diagnostics (identity, set, galleries, reader page, readiness, blockers, rendering)
  - MarketingCaptureUITests.testCaptureCoordinate driven by one JSON coordinate (EHPANDA_CAPTURE_COORDINATE)
  - Scripts/visual/capture-native.py, which validates the pin, sets native chrome and proves byte-identical cold reruns on the actual app
  - Dedicated "EhPanda Visual" simulators resolved by name for every visual run
affects: [17-06, 17-07, 17-11, 17-21, marketing]
actuals:
  tokens: 53000
  tasks: 2
  commits: 19
tech-stack:
  added: []
  patterns: [system screenshot settled in the test and taken from the result bundle, two-identical-screenshots settle, settle launch before captures, name-reserved simulators, ExitStack restoration]
key-files:
  created:
    - EhPandaUITests/MarketingCaptureUITests.swift
    - EhPandaUITests/Support/CaptureLauncher.swift
    - Scripts/visual/capture-native.py
    - Scripts/visual/test_capture_native.py
    - AppPackage/Tests/AppFeatureTests/CaptureRouteTests.swift
    - AppPackage/Tests/AppFeatureTests/CaptureScreenDiagnosticsTests.swift
    - AppPackage/Tests/AppFeatureTests/LibraryClientReaderCacheTests.swift
    - AppPackage/Tests/DetailFeatureTests/DetailCaptureRouteTests.swift
  modified:
    - AppPackage/Sources/AppLaunchAutomationClient/AppLaunchAutomation.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
    - AppPackage/Sources/AppFeature/UITestSupport/CaptureScenePreparation.swift
    - AppPackage/Sources/AppFeature/UITestSupport/CaptureDiagnostics.swift
    - AppPackage/Sources/AppFeature/UITestSupport/CaptureFixtureManifest.swift
    - AppPackage/Sources/AppFeature/UITestSupport/CaptureSceneConfiguration.swift
    - AppPackage/Sources/DetailFeature/DetailReducer+Download.swift
    - AppPackage/Sources/HomeFeature/GalleryCardCell.swift
    - AppPackage/Sources/ImageColors/ImageColors.swift
    - AppPackage/Sources/AppTools/DataCache.swift
    - AppPackage/Sources/LibraryClient/LibraryClient.swift
    - EhPandaUITests/CaptureIsolationUITests.swift
    - Scripts/visual/environment.py
    - Scripts/visual/fixtures.py
    - Scripts/visual/README.md
key-decisions:
  - Equally common image colors rank by packed value, and under Reduce Motion the card gradient takes a fixed arrangement and applies a late palette at once (owner, 2026-10-08; D-29 exception).
  - The iPhone stays at Large; comments and reader routes continue from the detail's launch automation (owner, 2026-10-08).
  - The fixture derives the reader's full request set; capture scenes use the paging reader; isCached also asks the reader's DataCache (owner, 2026-10-08).
  - iPad's status bar shows 2026-01-01 9:41, which simctl renders as "Sat Jan 1" (owner, 2026-10-08).
  - Visual runs use dedicated simulators resolved by reserved name (owner, 2026-10-08).
  - A Settings launch settles the status bar before captures, because the first app after a boot lays out iPad's Wi-Fi glyph half a point left (owner, 2026-10-08).
  - Frames are the system screenshot (XCUIScreen) the test settles and attaches, not simctl's framebuffer, whose Liquid Glass pixels depend on render history (owner, 2026-10-09).
patterns-established:
  - The test that verifies a screen also records its frame, as the system renders a screenshot; the runner reads it from the launch's result bundle, so no handshake is needed.
  - A frame is recorded only after two consecutive screenshots are byte-identical, and accepted only when every cold launch recorded the same bytes.
requirements-completed: []
---

# Phase 17 Plan 05: Native marketing captures Summary

**Marketing now drives the actual app to each of its eight screens through the app's own
navigation, verifies the screen and every image before a frame, and records the frame as the
system renders a screenshot, with its own status bar at the device's native size. On both visual
simulators, two independent cold launches of Home record byte-identical frames showing 9:41 and
no Dynamic Island capsule.**

## Performance

- The first 17-05 commit (an owner decision) landed at 2026-10-07T23:56:41Z, the last source
  commit at 2026-10-08T15:58:41Z.
- Tasks: 2/2. Source commits: 14. Documentation commits: 5 (owner decisions, the T1 record and
  this completion record, which also records the T2 decisions).
- Realized source diff: about 53,000 tokens (chars/4), against an estimate of 48,000.

## Accomplishments

- **Card color determinism (before T1).** `ImageColors` ranks equally common colors by packed
  value instead of hash order. Under Reduce Motion the Home card gradient places its points in
  one fixed R2 arrangement and applies a palette that arrives late at once; without Reduce Motion
  it keeps random placement, movement and the fade.
- **Routes (T1).** `AppLaunchAutomation.CaptureRoute` opens all eight screens through the actions
  a person's taps send: Home, the flow gallery from Home, its comments (Show All) and the reader
  on a page (a preview tap) once the detail loads, Filters from Search, Downloads, and Laboratory
  from Setting. Only a DEBUG capture launch has a route.
- **Diagnostics (T1).** `CaptureDiagnostics` reports the shown screen from navigation state, the
  set, galleries, reader page, readiness, blockers and the app's own rendering (language, locale,
  appearance, text size, family). Each screen waits for its content and every image it shows,
  including the reader's own `DataCache`, which `LibraryClient.isCached` now consults.
- **Fixture (T1).** The acquisition derives the reader's whole request set: every reader page a
  loaded batch lists and the prefetch window around each built page. The nonexplicit selection was
  re-acquired as `marketing-2b4d03cd822461e2`. Capture scenes run the paging reader, which frames
  the page the same way on every run.
- **Marketing UI test (T1, T2).** `MarketingCaptureUITests/testCaptureCoordinate` decodes one
  strict five-key coordinate, launches the app in the coordinate's language, locale and
  appearance at the verified Large size, and passes only when the diagnostics equal what the
  selection expects and the system screenshot (`XCUIScreen`) holds still across two renders a
  second apart. It attaches the diagnostics and that PNG unchanged.
- **Native runner (T2).** `capture-native.py` validates the coordinate and fixture, validates the
  tracked pin against fresh measurements before any launch (never writing it), sets the status
  bar (9:41, Wi-Fi 3, cellular 4, charged 100), settles it with one Settings launch, and runs two
  single-pass cold launches. From each launch's exported attachments it checks that the
  diagnostics name the coordinate and that the screenshot is a complete 8-bit RGB PNG at the
  pin's portrait size. It restores the status bar, appearance, portrait, text size and power
  state on success and failure, and records every outcome.
- **Visual simulators (T2).** `environment.resolve_destinations` resolves "EhPanda Visual iPhone
  Air" and "EhPanda Visual iPad Pro 11-inch (M5)" by name, model and runtime, ignoring other
  simulators of the same model.

## Task Commits

1. `dce38b9e98`, `fae3b53761`, `e7789e746b`, `b0864b3de5`: owner decisions and fixes for
   deterministic card colors.
2. `b59ddeaa94`, `0c787f4f77`: owner decision and fix for the late palette under Reduce Motion.
3. `5f4a61091f`, T1: the reader's full request set in the fixture derivation.
4. `6266f85587`, T1: `DataCache.containsData(forKey:)` and the reader cache in `isCached`.
5. `eaec12c76b`, T1: capture routes, per-screen diagnostics and their tests.
6. `25652e646f`, T1: the marketing UI test and its launcher.
7. `56ff7b0b73`: T1 owner decisions and state.
8. `1d406c2908`, T2: the native runner, its tests, the README and the launcher's handshake.
9. `03901b5aab`, T2: dedicated visual simulators resolved by name.
10. `d82c4f57fa`, T2: the Settings launch before captures.
11. `e9685dc751`, `1fc626c2f5`: review fixes R-1 to R-4.
12. `b292211a37`, T2: system screenshots as frames; the handshake is removed.
13. `051cc01132`: review fixes R-5 to R-8.

## Verification

T1's command, run per coordinate on each device:

```sh
xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan UITests \
  -destination "platform=iOS Simulator,id=$UDID" \
  -only-testing:EhPandaUITests/MarketingCaptureUITests/testCaptureCoordinate
```

T2's command, then the device gate per coordinate:

```sh
python3 -m unittest discover -s Scripts/visual -p test_capture_native.py
python3 -B Scripts/visual/capture-native.py --coordinate <coordinate.json> \
  --fixtures .capture/marketing/current \
  --environment Scripts/visual/regression-environment.json --output .capture/<new run>
```

| Check | Evidence | Result |
|---|---|---|
| T1 capture sweep, 6 screens x 2 devices | `.capture/17-05-t1-ui-04/` | 12 coordinates pass with no repetition; Live Text and Downloads fail as expected until 17-06 |
| T1 locale and theme variants | `.capture/17-05-t1-ui-05/` | zh-Hant dark and German light pass |
| T1 isolation test on the new fixture | `.capture/17-05-t1-isolation-01/` | Passes on both devices |
| T1 unit tests | `.capture/17-05-t1-unit-03/`, `17-05-t1-unit-04/` | Every Swift Testing target passes; AppFeatureTests 85 in 11 suites, DataCacheTests 7 |
| T1 commit trees | `.capture/commit-trees-04/` | Each commit builds clean with strict SwiftLint |
| T2 unit tests (plan command) | `.capture/17-05-t2-mutations-01/` (unmutated run), `commit-trees-08/` | 31 tests pass |
| T2 mutations | `.capture/17-05-t2-mutations-01/` | All 7 mutations of the launch path fail the suite; earlier mutations of restore, preflight and settle did too |
| Visual suite | `.capture/commit-trees-08/` | 162 tests pass |
| T2 commit trees | `.capture/commit-trees-05/` to `commit-trees-08/` | Build 0, lint 0, 0 diagnostics |
| Capsule | `.capture/17-05-t2-capsule-probe-01/`, `17-05-t2-xcuiscreen-02/` | The device mask draws the capsule; neither `--mask=ignored` nor the system screenshot shows it |
| iPad Wi-Fi shift | `.capture/17-05-t2-native-02/`, `17-05-t2-wifi-probe-01/`, `17-05-t2-experiment-01/` | Failed gate traced to the first app after boot; the settle launch fixes it |
| iPad glass rim | `.capture/17-05-t2-native-05/`, `17-05-t2-glass-probe-01/` | Gate on `1fc626c2f5` failed: 1 of 17 framebuffer launches differed on a glass rim; all 17 system screenshots were identical |
| System screenshot frames | `.capture/17-05-t2-xcuiscreen-01/`, `-02/`, `17-05-t2-native-07/`, `-08/` | Uncommitted experiment, then the gate on `b292211a37`: identical cold reruns on both devices |
| Final gate, iPad light | `.capture/17-05-t2-native-09/` | Both launches `910827a3…`, 1668x2420 RGB: byte-identical; 9:41 Sat Jan 1, no capsule |
| Final gate, iPhone dark | `.capture/17-05-t2-native-10/` | Both launches `f90edce1…`, 1260x2736 RGB: byte-identical; 9:41, no capsule |

## Review

The inline review (17-05-REVIEW.md) ran in two rounds. Round one reread every change through
`d82c4f57fa` after its gate passed: one failed restore step skipped the next (R-1), the portrait
restore inherited the last launch's capture parameters (R-2), a missing blank line (R-3) and two
stale doc comments (R-4), fixed in `e9685dc751` and `1fc626c2f5`. The gate on `1fc626c2f5` then
failed on iPad (the glass rim), and round two reread the frame source change `b292211a37`: lines
past 120 columns (R-5), a loose test assertion (R-6), an unclear comment (R-7) and two runner
checks without a failing test (R-8), fixed in `051cc01132`. The final gate ran on `051cc01132`.

## Decisions and Deviations

- **Owner decisions, 2026-10-08**, each recorded in 17-05-PLAN.md: card color determinism (tie
  ranking, fixed arrangement, late palette at once as a D-29 exception); Large on the iPhone;
  comments and reader routes through the detail's launch automation; the reader's full request
  set; the paging reader; the reader cache in `isCached`; the iPad status bar date; dedicated
  visual simulators; the Settings launch before captures. On 2026-10-09: system screenshots as
  frames.
- **Files beyond the plan's list**, each covered by those decisions: ImageColors, HomeFeature,
  DetailFeature, DataCache, LibraryClient, `fixtures.py`, `environment.py` and their tests.
- **The frame source.** The plan's first try was `simctl io screenshot --mask=ignored`. Its
  framebuffer keeps Liquid Glass as the display last composed it, so one iPad cold launch in 17
  recorded a glass rim one level off, and identical cold reruns could not be guaranteed; the stop
  rule applied. With the owner's decision the frame is the system screenshot the test takes, a
  native render with the same status bar and no capsule; nothing is cropped, painted, stitched or
  faked. The first T2 design, a test-held screen with a `ready.json`/`answer.json` handshake while
  the host took screenshots, was removed with it.
- **Settle rules.** A frame needs two identical screenshots a second apart; the Settings launch
  uses the same rule, with simctl screenshots, before it quits.
- The plan names `scripts/visual`; the repository directory is `Scripts/visual`.
- No acceptance criterion or threshold changed.

## Unresolved Gates

1. **Agent-assisted gallery preparation for both sets.** The agent prepares the explicit fixture alongside the nonexplicit fixture, validates each selection and captures only its declared content.
2. **Live Text and Downloads** coordinates fail until 17-06 gives them state and seeded downloads.
3. **The status bar follows the simulator's region, not the coordinate's locale.** The visual
   simulators use the host's region (`en_JP`), so a German coordinate still shows "9:41 Sat Jan 1"
   in English. Whether marketing chrome should follow each locale is a 17-07 question for the
   owner.
4. **The vertical reader's resume offset** is a production defect, filed as a separate task.
5. **Final selection** with owner authority remains the Phase 17 closure checkpoint (17-21).

## Issues Encountered

- Another local session created same-model iOS 27 simulators, so model-and-runtime resolution
  became ambiguous; the dedicated visual simulators resolve it.
- A freshly created simulator dropped Reduce Motion during its first boot; it was set again and
  the README says to read it back after a reboot.
- `simctl status_bar --time` keeps the real date unless given a full ISO time, and then derives
  the weekday as if the year were 2000.
- simctl's framebuffer differs from the system screenshot by one level on some glass pixels on
  every launch, and once differed between two cold launches of one iPad screen; the system
  screenshot never did.
- The first commit message of T2 exceeded 50 characters and was amended before anything else
  built on it (message only, tree unchanged).

## User Setup Required

None for the nonexplicit set. The visual simulators exist; the README shows how to create and set
them up again.

## Next Plan Readiness

17-06 can give Live Text and Downloads their state. 17-07 can expand native captures across
screens, locales and themes with `capture-native.py`, one coordinate per run, after the owner
answers the status bar locale question. Phase progress is 6/24 plans; CAP-17-02, CAP-17-04 and
CAP-17-06 stay open until every declaring plan finishes.
