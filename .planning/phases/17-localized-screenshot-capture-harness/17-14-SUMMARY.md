---
phase: 17-localized-screenshot-capture-harness
plan: "14"
subsystem: release
tags: [release-isolation, capture, linkage, tooling, verification]
requires:
  - phase: 17-04
    provides: DEBUG-gated capture activation through UITestAutomation
  - phase: 17-06
    provides: Earlier Release string evidence (context only)
provides:
  - Scripts/visual/verify-release.py, a Release payload, dependency, linkage and activation scanner
  - Scripts/visual/test_release.py, scanner tests including a seeded bad payload
  - 17-RELEASE-ISOLATION.md, first run at 6bccf8468 and the passing final run at 50c794b53
affects: [17-23, 18]
actuals:
  tasks: 1
  commits: 5
tech-stack:
  added: []
  patterns:
    - "Release isolation is judged on link maps and a launched probe, not on lockfile entries or XCTest text"
key-files:
  created:
    - Scripts/visual/verify-release.py
    - Scripts/visual/test_release.py
    - .planning/phases/17-localized-screenshot-capture-harness/17-RELEASE-ISOLATION.md
  modified:
    - Scripts/visual/README.md
key-decisions:
  - "Linkage, not text, decides XCTest: swift-issue-reporting and swift-case-paths keep XCTest-named strings in every configuration, so the scanner reads link maps for XCTest/Testing/XCUIAutomation/SnapshotTesting objects."
  - "UITestAutomation's inert shell is accepted in Release: 11 live symbols per slice, all its metadata or the two DEBUG-gated no-op members, recorded under `accepted` instead of being hidden."
  - "A plain Release build must set CLANG_COVERAGE_MAPPING=NO; the test plans otherwise turn coverage on for `xcodebuild build`, while the shipped archive path does not. The scanner fails any instrumented compile."
patterns-established:
  - "verify-release.py --app/--build-log/--link-map/--device/--debug-control/--output"
requirements-completed: []
coverage:
  - id: D1
    description: The Release app ships no capture fixture, test asset, SnapshotTesting or XCTest linkage, and no DEBUG or instrumented compile.
    requirement: CAP-17-07
    verification:
      - kind: other
        ref: "python3 -B Scripts/visual/verify-release.py on the Release-iphonesimulator build of the 50c794b53 app source (worktree at 1a21bc8d8, identical app source) with four final link maps: exit 0, PASS 0 findings"
        status: pass
      - kind: other
        ref: "Same scanner on the Debug build of that source: exit 1, 991 findings (debug-define, instrumented, capture strings, debug/preview dylibs)"
        status: pass
    human_judgment: false
  - id: D2
    description: No environment flag activates capture in a launched Release build.
    requirement: CAP-17-07
    verification:
      - kind: other
        ref: "verify-release.py --device probe on EhPanda iPhone Air at the 50c794b53 app source: Release survives the capture/UI-test environment for 8 s; the Debug control is ended by UITestAutomation"
        status: pass
    human_judgment: false
  - id: D3
    description: The scanner rejects a seeded bad payload.
    requirement: CAP-17-07
    verification:
      - kind: unit
        ref: "python3 -B -m unittest discover -s Scripts/visual -p test_release.py at 50c794b53: 19 tests OK (RED b840641ff, GREEN af70958e0)"
        status: pass
    human_judgment: false
  - id: D4
    description: FeatureTests and UITests pass on phone then tablet, and strict no-cache lint passes, without suppression.
    requirement: CAP-17-07
    verification:
      - kind: other
        ref: "SwiftLint 0.65.1 lint --strict --no-cache at 50c794b53: 0 violations in 756 files"
        status: pass
      - kind: unit
        ref: "FeatureTests on EhPanda iPhone Air (1a21bc8d8 source, identical for this plan): 1522 cases, 1512 passed, 0 failed, 10 expected failures, 0 Repetition (exit 0)"
        status: pass
      - kind: unit
        ref: "FeatureTests on EhPanda iPad Pro 11-inch (M5) (same source): 1522 cases, 1512 passed, 0 failed, 10 expected failures, 0 Repetition (exit 0)"
        status: pass
      - kind: unit
        ref: "UITests on EhPanda iPhone Air at 50c794b53: 88 cases, 68 passed, 0 failed, 20 skipped, 0 Repetition (exit 0)"
        status: pass
      - kind: unit
        ref: "UITests on EhPanda iPad Pro 11-inch (M5) at 50c794b53: 88 cases, 71 passed, 0 failed, 17 skipped, 0 Repetition (exit 0)"
        status: pass
    human_judgment: false
duration: 4h (first run) + gate rerun
completed: 2026-11-03
status: complete
source_head: 50c794b53
---

# Phase 17 Plan 14: Release isolation (T2) Summary

**The Release simulator build of the source at `50c794b53` ships and activates no capture facility.**
**T2's acceptance is met.**

- The scanner passes the Release build with 0 findings and finds 991 on the Debug build. It rejects a
  seeded bad payload.
- Strict lint is clean.
- FeatureTests and UITests pass on the phone and the tablet, with 0 failures and 0 Repetition nodes.
- The first run, at `6bccf8468`, failed the behavior gate. It got there after:
  - quick task `261103-test-plan-repairs`;
  - two app fixes, `e4e3ddd74` (Library and gallery-list row restore) and `1a21bc8d8` (the Auto-Play menu);
  - four UI-test fixes, one of which ends an orientation leak.

## Performance

- Tasks: 1/1 executed (T2 only; T1/T3 moved to Phase 18). Acceptance: met at `50c794b53` (D1 to D4 pass).
- Commits: RED, GREEN, first-run evidence, the first-run STATE/ROADMAP record, and the final-run record.

## Accomplishments

- `Scripts/visual/verify-release.py` checks five things, and fails on any finding:
  - **Payload:** files, names and strings in the app and the share extension.
  - **Build log:** the `Target dependency graph` (indented entries included), package
    resolution, compiles defining `DEBUG` and coverage-instrumented compiles.
  - **Link maps:** test and snapshot objects, and live capture symbols. `UITestAutomation`'s inert
    shell is accepted and listed.
  - **Launch probe:** an optional launch on a simulator with the capture and UI-test environment set.
  - **Debug control:** the same probe against a Debug build, so the probe is known to bite.
- `Scripts/visual/test_release.py` has 19 tests, including the seeded bad payload (capture
  strings, `.debug.dylib`, HTML fixture, `__Snapshots__`, a SnapshotTesting string in the extension).
- `Scripts/visual/README.md` gives the build and scan commands, including `CLANG_COVERAGE_MAPPING=NO`.
- `17-RELEASE-ISOLATION.md` records the source, commands, numbers, probe, Debug negative check,
  coverage finding, lint and test outcomes.

## Task Commits

1. `b840641ff` test(17-14): add failing Release isolation scanner tests (RED)
2. `af70958e0` feat(17-14): scan Release builds for capture payload, linkage and activation (GREEN)
3. `3315aceed` docs(17-14): record Release isolation evidence at 6bccf8468
4. `a26755100` docs(17-14): record T2 run and open behavior gate in STATE and ROADMAP
5. This record: the final run at `50c794b53` in 17-RELEASE-ISOLATION.md, this summary, STATE and ROADMAP

The fixes that unblocked the gate are their own commits, listed under "Final gate".

RED: with only `test_release.py`, all 19 tests error with `FileNotFoundError` (no scanner). Against
the first scanner draft, the 9 new behavior tests failed. Those were the indented graph, `XCTest`
linkage, coverage and the accepted shell. GREEN: 19 OK.

## Final gate at `50c794b53`

Evidence: the "Final run" section of 17-RELEASE-ISOLATION.md. All runs took place on 2026-11-03, on
iOS 27.2 simulators, one at a time.

**Release checks.**

- Release and Debug were built by one `runbuild` in the clean worktree
  `.airbuild/worktree/ehpanda-1714-release-3` at `1a21bc8d8`, exit 0. The worktree was removed after
  the evidence was recorded.
- `git diff --stat 1a21bc8d8 50c794b53` lists only `EhPandaUITests/LibraryPresentationUITests.swift`.
  That file is in neither the app nor the share extension, so the built source is `50c794b53`'s.
- The Release scan with the four link maps and the phone probe exits 0 with 0 findings.
- The Debug negative control exits 1 with 991 findings, the same as the first run.
- The scanner tests give 19 OK. Strict lint finds 0 violations in 756 files.

**Behavior runs.**

| Plan, device (iOS 27.2) | Source | Exit | Cases | Passed | Failed | Skipped | Expected failures | Repetition nodes |
|---|---|---|---|---|---|---|---|---|
| FeatureTests, EhPanda iPhone Air | `1a21bc8d8` | 0 | 1522 | 1512 | 0 | 0 | 10 | 0 |
| FeatureTests, EhPanda iPad Pro 11-inch (M5) | `1a21bc8d8` | 0 | 1522 | 1512 | 0 | 0 | 10 | 0 |
| UITests, EhPanda iPhone Air | `50c794b53` | 0 | 88 | 68 | 0 | 20 | 0 | 0 |
| UITests, EhPanda iPad Pro 11-inch (M5) | `50c794b53` | 0 | 88 | 71 | 0 | 17 | 0 | 0 |

- FeatureTests' source is identical to `50c794b53` for that plan.
- `UITests.xctestplan` keeps `retryOnFailure`, unchanged as in 16-24. The bundles show single runs
  (0 Repetition nodes).
- The 10th expected failure compared with the first run is
  `SettingReducerTests.defaultProfileCreationUsesOriginatingHostAfterSharedHostChanges`. Its
  non-strict `skipInFlightEffects` records a known issue only when its live profile request is still
  in flight (`9eb9a4731`). That depends on timing, and it is not a new failure.
- Auto-Play stress, at the `1a21bc8d8` app source: 5 of 5 on each device.
- DeepLinkScheme page-link tests after `50c794b53`: they passed on the iPad and the iPhone in a serial
  run after the two landscape Library tests. The device was back in portrait afterwards.

**App bugs fixed.**

1. `e4e3ddd74` fix(gallery-list): return the row a person saw to the top after a layout switch. This
   covers Library (Favorites, Downloads) and gallery-list restore.
   - Row lists anchored on any row at least 10% visible, including one hidden under the navigation
     bar. The restore used the minimal scroll.
   - Rows now report their frames to a shared `GalleryAnchoredList`. The anchor is the highest row whose
     center is in the list's clear area, and the list scrolls it to the top.
2. `1a21bc8d8` fix(reader): keep the open Auto-Play menu across page turns.
   - Each page turn re-evaluated the reader toolbar, and on some launches that rebuilt the open menu's
     rows, so their accessibility IDs changed. A tap on Off could land on a replaced row and be lost.
   - The menu is now its own view, with the `AutoPlayHandler` as its only input. The page indicator is
     unchanged.

**Test fixes.**

- Quick task `261103-test-plan-repairs`: `85ebfe041`, `e6e725fd1`, `56076ce11`, `fec74302c`,
  `1f70e0ac9`, `61b65f0bf`, `751527d16`, `99dacb6a7`, `188794175`, `9b163d3dd`, `9be339053`. It covers
  the stub `gdata` route, iOS 27 overflow identifiers, the capture-only suite skips, stale scene and
  tracer tests, download test clocks, galleries in any layout, and reader orientation matching.
- `be27c08cb` test(ui): require the restored row at the top, clear of both bars.
- `8270ccab3` test(ui): give hittable waits room for XCUITest's own query time.
- `40b0b672b` test(ui): read the Home carousel in one snapshot and wait for its card.
- `50c794b53` test(ui): restore portrait after the landscape Library tap tests. This is the
  orientation leak below.

**DeepLinkScheme failures: an orientation leak, not the app.**

- In one iPad UITests run at `1a21bc8d8`, both page-link tests
  (`testPageLinkColdLaunchOpensReaderAtPage`, `testPageLinkWarmForegroundOpensReaderAtPage`) failed all
  three attempts: "the indicator names page 2 and the screen shows no page".
- Cause: `LibraryPresentationUITests.testFavoritesSingleTapDetailsAndDoubleTapReads` and
  `testDownloadsSingleTapDetailsAndDoubleTapReads` turned the device to landscape and never turned it
  back. The orientation outlives the test on its simulator clone. DeepLinkScheme ran next on that clone
  and opened the iPad reader as a two-page spread.
- The failure screenshot shows the spread of pages 1 and 2 with "2 / 156". So the reader did open at
  the linked page.
- In a serial run that rotates to landscape first, both tests fail the same way with the `1a21bc8d8`
  app and with the `40b0b672b` app. The app change is not involved.
- `50c794b53` restores portrait in a teardown block in both tests.

## First run at `6bccf8468` (superseded)

```sh
python3 -B -m unittest discover -s Scripts/visual -p test_release.py           # 19 OK
python3 -B Scripts/visual/verify-release.py --app … --build-log … --link-map … (x4) \
  --device "$PHONE_UDID" --debug-control … --output "$OUT"                      # exit 0, 0 findings
python3 -B Scripts/visual/verify-release.py (Debug app and log)                  # exit 1, 991 findings
"$SWIFTLINT" lint --strict --no-cache --config .swiftlint.yml \
  AppPackage/Sources App ShareExtension EhPandaUITests AppPackage/Tests         # exit 0, 0 in 753 files
runtest <project-id> --script app --additional-options '-testPlan FeatureTests -destination id=$PHONE_UDID'
runtest <project-id> --script app --additional-options '-testPlan FeatureTests -destination id=$TABLET_UDID'
runtest <project-id> --script app --additional-options '-testPlan UITests -destination id=$PHONE_UDID'
runtest <project-id> --script app --additional-options '-testPlan UITests -destination id=$TABLET_UDID'
```

| Plan, device (iOS 27.2) | Exit | Cases | Passed | Failed | Skipped | Expected failures | Repetition nodes |
|---|---|---|---|---|---|---|---|
| FeatureTests, EhPanda iPhone Air | 65 | 1510 | 1499 | 2 | 0 | 9 | 0 |
| FeatureTests, EhPanda iPad Pro 11-inch (M5) | 65 | 1510 | 1494 | 7 | 0 | 9 | 0 |
| UITests, EhPanda iPhone Air | 65 | 91 | 48 | 23 | 20 | 0 | 71 |
| UITests, EhPanda iPad Pro 11-inch (M5) | 65 | 91 | 48 | 26 | 17 | 0 | 78 |

Failures by cause. None of them is in the Release isolation tooling.

- **UI-test stub has no `/api.php` route (phone 15, tablet 17).** `300a29ac4` (2026-11-02) adds a
  `POST /api.php` metadata request to every gallery list (`galleriesWithTitles`).
  `UITestStubURLProtocol.fixtureName` answers it with 404, so Home and Favorites show "Couldn't Read
  Page". Affected suites: AccessibilityAudit (6, plus `testPadSettingAndDetailModalsAudit` on the
  tablet), GalleryCard 3, GalleryLayout 3, LibraryPresentation 3 and, on the tablet,
  `DeepLinkPadUITests`. Reproduced by launching the Debug app with only the stub environment.
- **Detail overflow control not found (5 on each device).** ShareSheet 1, DetailNavigationTitle 4.
  Not root-caused.
- **Env-gated capture tests (3 on each device).** `MarketingCaptureUITests` (2) and
  `CaptureIsolationUITests` (1) need `TEST_RUNNER_EHPANDA_CAPTURE_*`. The UITests plan skips only
  `AppshotCaptureUITests`.
- **Tablet reader rotation (1).** `ReaderPageSyncUITests.testTurningTheDeviceKeepsTheResumedPageAtTheTop`:
  after turning to landscape, the indicator names a page that the screen doesn't show. Not
  root-caused.
- **FeatureTests on both devices (2).**
  - `CaptureSceneTests.sceneSettingsAreTheDefaultsWithTheBypassOn` gets `displayJapaneseTitle: true`.
    `300a29ac4` also changed `CaptureScenePreparation`.
  - `VisualTracerTests.testHomeFullContentTracer` reports `clippedItem("Visual Home Gallery 1")`.
- **FeatureTests, tablet only (5).** `DownloadContinuedSession` Interleave 1, Expiration 3, Ledger 1:
  timeouts or ordering races.

Result bundles are kept locally under `/tmp/ehpanda-17-14/` and aren't committed.

## Deviations from Plan

1. **Runtest recipe.** The project's `runtest` recipe ran the tests, one invocation at a time, in
   place of raw `xcodebuild test`. Exits and full results were kept; nothing was filtered.
2. **AirBuild archive is Debug-sim.** `airbuild-xcode archive` produced a Debug simulator archive,
   so the Release evidence comes from a direct `xcodebuild build -configuration Release` in a clean
   worktree at `6bccf8468`.
3. **Coverage override.** The first Release build was coverage-instrumented (inherited from the test
   plans). It was rebuilt with `CLANG_COVERAGE_MAPPING=NO`, and the scanner now fails instrumented
   compiles. The shipped CI archive path reports no coverage setting.
4. **Final-run sources by equivalence.**
   - The final Release and Debug builds come from a worktree at `1a21bc8d8`, not `50c794b53`. FeatureTests
     also ran at the `1a21bc8d8` source.
   - The only difference is `EhPandaUITests/LibraryPresentationUITests.swift`. It is in neither the app,
     the share extension nor the FeatureTests plan.
   - UITests, lint and the scanner tests ran at `50c794b53` itself.
5. **Phone booted for the probe.** The Release scan's launch probe needs a booted simulator. The first
   attempt in the final run stopped at `simctl install` on the shut-down phone, before any finding. The
   phone was booted, the scan was rerun, and afterwards the app was uninstalled and the phone shut down.

**Total deviations:** 5 (4 procedural, 1 found and fixed in the tooling). **Impact:** none on the
Release evidence.

## Issues Encountered

The first run's issues are all resolved for the gate. The orientation leak was found during the rerun.

1. **UI-test stub had no route for list metadata.** Fixed by `85ebfe041` and `e6e725fd1` (the stub
   answers `gdata`).
2. **Detail overflow control not found.** Fixed by `56076ce11`: iOS 27 names it `TopOverflowBarButtonItem`.
3. **Env-gated capture tests ran in UITests.** Fixed by `9be339053` and `9b163d3dd`, which skip the
   capture-only suites.
4. **CaptureSceneTests settings drift.** Stale test, fixed by `188794175`.
5. **VisualTracerTests clipped item.** Stale test, fixed by `99dacb6a7` and `1f70e0ac9`.
6. **Tablet-only DownloadContinuedSession timeouts.** Fixed by `751527d16`, which adds a test clock and
   30 s hang bounds.
7. **Tablet reader rotation.** Fixed by `fec74302c`, which turns orientation matching off in the test.
8. **Orientation leak into DeepLinkScheme.** Fixed by `50c794b53`, described above.
9. **Scanner limit (unchanged).** Inert-shell acceptance judges the link maps it's given. It can't tell
   they came from the scanned binary. The README names which final link maps to pass, and the caller
   must take them from the same build.

## Known risks

None of these failed the final gate. They are recorded so a later failure is recognized.

- **`ReaderPageProbe` can't read an iPad landscape spread.** It checks the page under the reader's
  center, which in a two-page spread is the gutter, so it reports "no page". Any page-link or reader
  test that runs while the iPad is in landscape with orientation matching on fails this way, even when
  the reader is right. `ReaderPageSyncUITests` and `ReadingOrientationUITests` avoid it by turning
  matching off (`fec74302c`). DeepLinkScheme relies on starting in portrait.
- **DeepLinkScheme depends on the clone's orientation.** `50c794b53` fixes the one known leak. A future
  test that leaves landscape behind would bring the failure back.
- **Long-press in Library downloads (iPad).**
  - In one diagnostic iPad run, `LibraryPresentationUITests.testDownloadManagementInBothLayouts` failed
    with "Inspect downloaded pages from grid never became hittable" after `press(forDuration: 1)`.
  - It did not recur in the final runs. The cause is not established.
- **Show All on the Front Page (iPad).**
  - In the same diagnostic run, `AccessibilityAuditUITests.testFrontPageAudit` failed with "Front Page
    navigation title did not appear".
  - It did not recur in the final runs. The cause is not established.

## Next

17-23: the final reduced-scope gate and the completion report. The GSD close steps follow 17-23 and
are not part of this plan.

## Self-Check: PASSED (deliverables present; D1 to D4 pass at 50c794b53)
