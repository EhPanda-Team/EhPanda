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
  - 17-RELEASE-ISOLATION.md, evidence at 9805537a9
affects: [17-23, 18]
actuals:
  tasks: 1
  commits: 3
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
        ref: "python3 -B Scripts/visual/verify-release.py on the Release-iphonesimulator build of 9805537a9 with four final link maps: exit 0, PASS 0 findings"
        status: pass
      - kind: other
        ref: "Same scanner on the Debug build: exit 1, 991 findings (debug-define, instrumented, capture strings, debug/preview dylibs)"
        status: pass
    human_judgment: false
  - id: D2
    description: No environment flag activates capture in a launched Release build.
    requirement: CAP-17-07
    verification:
      - kind: other
        ref: "verify-release.py --device probe on EhPanda iPhone Air: Release survives the capture/UI-test environment for 8 s; the Debug control is ended by UITestAutomation"
        status: pass
    human_judgment: false
  - id: D3
    description: The scanner rejects a seeded bad payload.
    requirement: CAP-17-07
    verification:
      - kind: unit
        ref: "python3 -B -m unittest discover -s Scripts/visual -p test_release.py: 19 tests OK (RED eadb4e8a1, GREEN 7af68d0e6)"
        status: pass
    human_judgment: false
  - id: D4
    description: FeatureTests and UITests pass on phone then tablet, and strict no-cache lint passes, without suppression.
    requirement: CAP-17-07
    verification:
      - kind: other
        ref: "SwiftLint 0.65.1 lint --strict --no-cache: 0 violations in 753 files"
        status: pass
      - kind: unit
        ref: "FeatureTests on EhPanda iPhone Air: 1510 cases, 2 failed, 9 expected failures, 0 Repetition (exit 65)"
        status: fail
      - kind: unit
        ref: "FeatureTests on EhPanda iPad Pro 11-inch (M5): 1510 cases, 7 failed, 9 expected failures, 0 Repetition (exit 65)"
        status: fail
      - kind: unit
        ref: "UITests on EhPanda iPhone Air: 91 cases, 48 passed, 23 failed, 20 skipped, 71 Repetition nodes (exit 65)"
        status: fail
      - kind: unit
        ref: "UITests on EhPanda iPad Pro 11-inch (M5): 91 cases, 48 passed, 26 failed, 17 skipped, 78 Repetition nodes (exit 65)"
        status: fail
    human_judgment: false
duration: 4h
completed: 2026-11-03
status: blocked
blocked_on: "Behavior gate (D4) fails on regressions outside this plan's tooling scope; orchestrator direction needed"
source_head: 9805537a9
---

# Phase 17 Plan 14: Release isolation (T2) Summary

**The Release simulator build of `9805537a9` ships and activates no capture facility: the new
scanner passes it with 0 findings, finds 991 on the Debug build and rejects a seeded bad payload,
and strict lint is clean. T2's acceptance is not met: FeatureTests and UITests fail on phone and
tablet. Most UITests failures trace to `9da595d93`, whose new `/api.php` metadata request has no
UI-test stub route. Per the plan's success criteria, this gate pauses for orchestrator direction.**

## Performance

- Tasks: 1/1 executed (T2 only; T1/T3 moved to Phase 18). Acceptance: blocked on D4.
- Commits: RED, GREEN, isolation evidence; this summary and the STATE/ROADMAP record follow.

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

1. `eadb4e8a1` test(17-14): add failing Release isolation scanner tests (RED)
2. `7af68d0e6` feat(17-14): scan Release builds for capture payload, linkage and activation (GREEN)
3. `035c4a65b` docs(17-14): record Release isolation evidence at 9805537a9

RED: with only `test_release.py`, all 19 tests error with `FileNotFoundError` (no scanner). Against
the first scanner draft, the 9 new behavior tests failed. Those were the indented graph, `XCTest`
linkage, coverage and the accepted shell. GREEN: 19 OK.

## Verification

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

- **UI-test stub has no `/api.php` route (phone 15, tablet 17).** `9da595d93` (2026-11-02) adds a
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
    `9da595d93` also changed `CaptureScenePreparation`.
  - `VisualTracerTests.testHomeFullContentTracer` reports `clippedItem("Visual Home Gallery 1")`.
- **FeatureTests, tablet only (5).** `DownloadContinuedSession` Interleave 1, Expiration 3, Ledger 1:
  timeouts or ordering races.

Result bundles are kept locally under `/tmp/ehpanda-17-14/` and aren't committed.

## Deviations from Plan

1. **Runtest recipe.** The project's `runtest` recipe ran the tests, one invocation at a time, in
   place of raw `xcodebuild test`. Exits and full results were kept; nothing was filtered.
2. **AirBuild archive is Debug-sim.** `airbuild-xcode archive` produced a Debug simulator archive,
   so the Release evidence comes from a direct `xcodebuild build -configuration Release` in a clean
   worktree at `9805537a9`.
3. **Coverage override.** The first Release build was coverage-instrumented (inherited from the test
   plans). It was rebuilt with `CLANG_COVERAGE_MAPPING=NO`, and the scanner now fails instrumented
   compiles. The shipped CI archive path reports no coverage setting.

**Total deviations:** 3 (2 procedural, 1 found and fixed in the tooling). **Impact:** none on the
Release evidence.

## Issues Encountered

1. **UI-test stub has no route for list metadata (regression, open).** `9da595d93` (2026-11-02,
   "apply title preference across views") makes every gallery list call `galleriesWithTitles`, which
   sends `POST /api.php`. `UITestStubURLProtocol.fixtureName` has no route for it, so the stub
   answers 404. The list then fails, and Home and Favorites show "Couldn't Read Page". Reproduced
   outside XCTest: the Debug app launched on the phone with only `EHPANDA_UITEST_STUB_NETWORK` and
   a host fixture directory shows the same page. Fixing it is app/test code, out of this plan's scope.
2. **Detail overflow control not found (open, not root-caused).** `ShareSheetUITests` (1) and
   `DetailNavigationTitleUITests` (4) can't find the Detail "More"/`OverflowBarButtonItem` button.
   No hierarchy shows "Couldn't Read Page", so this may be separate from issue 1.
3. **Env-gated capture tests run in UITests (open).** `MarketingCaptureUITests` (2) and
   `CaptureIsolationUITests` (1) fail on `XCTUnwrap` of `TEST_RUNNER_EHPANDA_CAPTURE_*`. The plan
   skips only `AppshotCaptureUITests`.
4. **CaptureSceneTests settings drift (open).** `sceneSettingsAreTheDefaultsWithTheBypassOn` now
   gets `displayJapaneseTitle: true`. `9da595d93` also changed `CaptureScenePreparation`.
5. **VisualTracerTests.testHomeFullContentTracer (open, not root-caused).**
   `clippedItem("Visual Home Gallery 1")` on both devices.
6. **Tablet-only DownloadContinuedSession timeouts (open).** 5 Interleave, Expiration and Ledger
   cases time out or race on the tablet only, with no Repetition. Not investigated further.
7. **Tablet reader rotation (open, not root-caused).** `ReaderPageSyncUITests` reports a page
   indicator with no page on screen after the turn to landscape.
8. **Scanner limit.** Inert-shell acceptance judges the link maps it's given. It can't tell they
   came from the scanned binary. The README names which final link maps to pass; the caller must
   take them from the same build.

## Next

Paused for orchestrator direction on D4. The Release isolation evidence (D1 to D3) stands at
`9805537a9`. 17-23 is not started.

## Self-Check: PASSED (deliverables present; acceptance gate D4 open)
