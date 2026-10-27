---
phase: quick-261027-vgt
plan: "01"
subsystem: infra
tags: [swiftpm, xcode, local-capture, testing]
requires: []
provides:
  - Public app build graphs no longer require the local capture SDK.
  - Explicit isolated snapshots compose the real SDK into local capture builds.
  - SDK-absent launch keys fail closed with regression coverage.
affects: [public-build, local-capture]
actuals:
  tasks: 3
  commits: 5
tech-stack:
  added: []
  patterns:
    - Generated snapshots apply local SDK graph changes without modifying canonical sources.
    - SDK-dependent SwiftUI and UI-test code is isolated behind canImport boundaries.
key-files:
  created:
    - Scripts/visual/prepare-local-capture.py
    - Scripts/visual/test_prepare_local_capture.py
    - AppPackage/Tests/AppFeatureTests/UITestSupport/CaptureSDKAvailabilityTests.swift
  modified:
    - AppPackage/Package.swift
    - AppPackage/Sources/AppFeature/RootView.swift
    - AppPackage/Sources/AppFeature/UITestSupport/AppshotCapture.swift
    - AppPackage/Sources/AppFeature/UITestSupport/CaptureDiagnostics.swift
    - AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift
    - AppPackage/Tests/AppFeatureTests/UITestSupport/AppshotCaptureTests.swift
    - EhPanda.xcodeproj/project.pbxproj
    - EhPandaUITests/AppshotCaptureUITests.swift
    - Scripts/visual/README.md
    - appshot.json5
key-decisions:
  - Keep the real capture SDK as an explicit local-only composition in generated snapshots.
  - Preserve only direct relative source symlinks whose ordinary targets are included in the snapshot.
  - Preserve the capture configuration and pin; report the configuration schema refusal before pin validation separately.
patterns-established:
  - Snapshot preparation is non-destructive and rejects unsafe output paths and source links.
  - Capture scene launch arguments are rejected when the SDK is unavailable.
requirements-completed: [QUICK-261027-vgt]
coverage:
  - id: D1
    description: Public app package and Xcode project resolve without the local capture SDK.
    requirement: QUICK-261027-vgt
    verification:
      - kind: integration
        ref: "Public snapshot: Debug and Release builds; FeatureTests"
        status: pass
    human_judgment: false
  - id: D2
    description: Explicit generated snapshot restores and builds the real SDK integration.
    requirement: QUICK-261027-vgt
    verification:
      - kind: integration
        ref: "SDK snapshot: dump-package, graph resolution, and AppshotCapture test build"
        status: pass
      - kind: unit
        ref: "SDK snapshot FeatureTests: 134 tests"
        status: pass
    human_judgment: false
  - id: D3
    description: Snapshot preparation and SDK-absent launch refusal have regression coverage.
    requirement: QUICK-261027-vgt
    verification:
      - kind: unit
        ref: "python3 -B -m unittest discover -s Scripts/visual -p test_prepare_local_capture.py"
        status: pass
      - kind: unit
        ref: "Public snapshot FeatureTests: 130 tests, including CaptureSDKAvailabilityTests"
        status: pass
    human_judgment: false
completed: 2026-10-27
status: complete
plan_head_before: 50deca5ac591eab47a2d0c188df58e1959d7b4d5
plan_head_after: 391edb63edb2e07bd8e50b4e9e77884103238c36
---

# Phase quick-261027-vgt Plan 01: Independent CI Builds Summary

Public builds now resolve without local capture SDK files, while an explicit isolated source snapshot restores the real SDK for local capture work.

## Accomplishments

- Removed mandatory SDK edges from the canonical Swift package and Xcode project and guarded SDK-dependent app and UI-test code.
- Added an isolated snapshot preparer with graph composition, source integrity checks, safe direct-relative-symlink handling, and rejection tests.
- Added SDK-absent launch refusal tests and documented public and local build workflows.

## Task Commits

1. **Task 1: Isolate the real SDK integration without altering its capture behavior** - `b50b9f9b41` (feat)
2. **Task 2: Remove mandatory dependencies and generate an explicit local composition** - `2436b628db` (feat)
3. **Task 2 follow-up: preserve safe source symlinks and strengthen graph checks** - `671c73fb68` (fix)
4. **Task 3: Document local capture snapshots** - `bcc77fc0a0` (feat)
5. **Final review: inspect nested local dependency declarations correctly** - `391edb63ed` (test)

## Verification

- Python snapshot-preparer tests passed: 9 tests, repeated successfully after the final dependency-inspection correction.
- Public snapshot dependency resolution passed; Debug and Release builds passed; FeatureTests passed: 130 tests.
- SDK-enabled snapshot manifest compiled without warnings, Xcode and SwiftPM graph resolution passed, and AppshotCapture test build passed.
- SDK-enabled FeatureTests passed: 134 tests, including the AppshotCapture adapter tests.
- Strict SwiftLint passed for all changed Swift files.
- The final SDK-enabled test build passed after the final lint-only correction.

## Local Capture Limits

The installed capture tool's doctor rejected the checked-in `appshot.json5` because its `schemaVersion` is 1 while the tool expects 2. Validation stopped before Xcode, simulator, or pin checks; this was not an observed pin-parsing refusal. No licensed capture fixtures are present in the repository, so no capture or screenshot verification was run. The pin values and configuration remain unchanged.

## Deviations from Plan

The approved checkpoint resolution allowed preserving direct relative symlinks only when their ordinary targets are included files under the snapshot root. The preparer retains `CLAUDE.md` as a link to `./AGENTS.md`, rejects unsafe link forms, and has success and rejection tests for that policy. Task 1 omissions identified during review were corrected before the final verification snapshots. A public test build exposed a SwiftLint line-length violation; the test was reformatted and the fresh public FeatureTests run passed.

**Total deviations:** 0 scope deviations; approved checkpoint clarifications and in-scope correctness fixes only.

## Issues Encountered

Local capture was blocked by the current tool/config schema mismatch and absent licensed fixtures, as described above. The public and SDK-enabled build and test checks completed successfully.

## Self-Check: PASSED

All three planned deliverables exist, and all five implementation/review commits are ancestors of the recorded plan head. Commit author and committer timestamps use UTC+8. Runtime token usage was not measured.

The executor used the user-approved model override for this invocation. The saved project configuration was restored unchanged. The model override was supplied to typed dispatch; independent runtime model metadata was unavailable.
