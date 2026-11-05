---
phase: 18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder
plan: "01"
subsystem: release
tags: [release-isolation, scanner, info-plist, marketplacekit, swift-imports]

requires: []
provides:
  - "`FORBIDDEN_CONTENT` carries `b'captureSystemOverlay'`, so a Release bundle holding the DEBUG-only capture overlay key fails the scan"
  - "`test_capture_system_overlay_key_in_release_fails`: the IN-02 regression case"
  - "RootView imports AppComponents only under `#if DEBUG` (IN-03)"
  - "`App/Info.plist` declares `MKSellsDigitalGoods` = `false` for every build (D-21, DIST-18-01's in-app part)"
affects: [18-09, phase-20-release-scan, release]

actuals:
  tokens: 1200
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - Scripts/visual/verify-release.py
    - Scripts/visual/test_release.py
    - AppPackage/Sources/AppFeature/RootView.swift
    - App/Info.plist

key-decisions:
  - "The AppComponents import is a separate `#if DEBUG` block before the `DEBUG && canImport(Appshot)` block, because that block's extra conditions must not gate AppComponents (Research §7.2). If 18-09's gate UI needs AppComponents in Release, the import moves back out with that use."
  - "REQUIREMENTS.md is not marked: DIST-18-01 stays Pending because its marketplace build flavor is Phase 20 work, and IN-02/IN-03 have no REQUIREMENTS.md entry. `requirements-completed` copies the plan's list as the workflow requires; only the Phase 18 part of DIST-18-01 is done."
  - "SwiftLint is not on PATH on this machine; the plan's strict lint ran with the SwiftLintPlugins binary (0.65.1, the version Package.swift pins) that the Release build resolved under `.build/phase18-release/SourcePackages/artifacts/`."

patterns-established: []

requirements-completed: [DIST-18-01, IN-02, IN-03]

coverage:
  - id: D1
    description: "The Release scanner rejects any bundle file that holds the capture overlay key (IN-02)"
    requirement: IN-02
    verification:
      - kind: unit
        ref: "Scripts/visual/test_release.py#ScannerTests.test_capture_system_overlay_key_in_release_fails"
        status: pass
      - kind: unit
        ref: "python3 -m unittest discover -s Scripts/visual -p 'test_release.py' (20 tests, OK)"
        status: pass
    human_judgment: false
  - id: D2
    description: "RootView's AppComponents import is DEBUG-only and a Release simulator build compiles (IN-03)"
    requirement: IN-03
    verification:
      - kind: other
        ref: "xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda -configuration Release -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/phase18-release (BUILD SUCCEEDED, 0 warnings)"
        status: pass
      - kind: other
        ref: "swiftlint lint --strict --no-cache --config .swiftlint.yml AppPackage/Sources/AppFeature (0 violations in 19 files)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The built product's Info.plist declares MKSellsDigitalGoods as false (D-21)"
    requirement: DIST-18-01
    verification:
      - kind: other
        ref: "plutil -extract MKSellsDigitalGoods raw .build/phase18-release/Build/Products/Release-iphonesimulator/EhPanda.app/Info.plist (prints false)"
        status: pass
    human_judgment: false

duration: 4min
completed: 2026-11-05
status: complete
---

# Phase 18 Plan 01: IN-02, IN-03 and MKSellsDigitalGoods Summary

**The Release scanner now fails on the capture overlay key, RootView's AppComponents import is DEBUG-only, and every build
declares `MKSellsDigitalGoods` = `false`, proven on a Release simulator product.**

## Performance

- **Duration:** about 4 min
- **Started:** 2026-11-05T06:49:13Z
- **Completed:** 2026-11-05T06:52:43Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- IN-02 closed: `b'captureSystemOverlay'` sits in `FORBIDDEN_CONTENT` after `b'CaptureTagTranslation'`. One token covers
  `captureSystemOverlayVisibility` and any other spelling of the key's environment name. A new case seeds the key into the
  bundle binary and expects exit code 1, `passed: false` and a `content` finding with that token.
- IN-03 closed: `import AppComponents` is now inside its own `#if DEBUG` block, directly before the existing
  `#if DEBUG && canImport(Appshot) && canImport(AppshotProtocol)` block. The Release build compiles without it.
- D-21: `MKSellsDigitalGoods` / `<false/>` is in `App/Info.plist`, in key order between
  `LSSupportsOpeningDocumentsInPlace` and `NSPhotoLibraryAddUsageDescription`. No other key changed.

## Task Commits

1. **Task 1: IN-02, scanner token and regression case** - `429ca7512` (fix)
2. **Task 2: IN-03 import and MKSellsDigitalGoods, proven on a Release build** - `319934300` (fix)

**Plan metadata:** recorded in the `docs(18-01)` commit that adds this file.

Both commits are signed (`G`) with `+08:00` author and committer dates.

## Files Created/Modified

- `Scripts/visual/verify-release.py`: one token added to `FORBIDDEN_CONTENT`.
- `Scripts/visual/test_release.py`: `test_capture_system_overlay_key_in_release_fails`.
- `AppPackage/Sources/AppFeature/RootView.swift`: the AppComponents import moved under `#if DEBUG`.
- `App/Info.plist`: `MKSellsDigitalGoods` = `false`.

## Verification

- `python3 -m unittest discover -s Scripts/visual -p 'test_release.py'`: 19 tests OK before the change, 20 tests OK after.
- Falsification: with the token removed again (working copy only, restored at once), the new case fails
  (`FAILED (failures=1)`), so the test depends on the token and not on another one.
- `grep -c "b'captureSystemOverlay'" Scripts/visual/verify-release.py` → `1`;
  `grep -c "def test_capture_system_overlay_key_in_release_fails" Scripts/visual/test_release.py` → `1`.
- Release build (plan command, `-derivedDataPath .build/phase18-release`): `** BUILD SUCCEEDED **`, 0 `warning:` lines.
- `plutil -extract MKSellsDigitalGoods raw …/Release-iphonesimulator/EhPanda.app/Info.plist` → `false`.
- `sed -n 1,8p RootView.swift`: line 3 `#if DEBUG`, line 4 `import AppComponents`, line 5 `#endif`; no other
  AppComponents import in the file.
- Strict no-cache lint on `AppPackage/Sources/AppFeature`: `Found 0 violations, 0 serious in 19 files`.
- Extra check on the real Release product: `grep -rl captureSystemOverlay` over the `.app` finds 0 files, and the
  scanner's `scan_payload` over the same bundle (377 files) has no `captureSystemOverlay` finding. Its one finding is
  the expected `UITestAutomation` inert shell, which the full scan accepts only with link-map evidence; the full
  Release scan with build log and link map is Phase 20's.
- `git diff --stat 825cfdf8a..319934300` lists only the four plan files. `.build/phase18-release` is ignored by
  `.gitignore` (`.build`) and not committed.
- No simulator was needed: the build uses the generic simulator destination and the scanner tests are pure Python.

## Decisions Made

See `key-decisions` above: the separate `#if DEBUG` import block, REQUIREMENTS.md left unmarked (DIST-18-01 is shared with
Phase 20), and the SwiftLint binary used for the lint.

## Deviations from Plan

None - plan executed exactly as written. (Running SwiftLint from the package plugin's binary is how the plan's lint
command was run, not a change to it.)

**Total deviations:** 0.

## Issues Encountered

None.

## User Setup Required

None.

## Next Phase Readiness

- Phase 20's final Release isolation scan now checks the capture overlay key.
- Ready for the other Wave 1 plans (18-02, 18-04, 18-06).

## Self-Check: PASSED

- The four modified files exist and carry the changes; commits `429ca7512` and `319934300` are on
  `feature/gsd-phase-18`.
- Every acceptance criterion of both tasks re-ran and passed (results above).
