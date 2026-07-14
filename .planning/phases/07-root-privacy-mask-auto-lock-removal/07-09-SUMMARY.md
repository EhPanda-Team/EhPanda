---
phase: 07-root-privacy-mask-auto-lock-removal
plan: 09
subsystem: app-privacy
tags: [swift, tca, swift-testing, shared-state, privacy-mask]

# Dependency graph
requires:
  - phase: 07-08
    provides: shared privacy-mask state, scene-phase behavior, and AppFeatureTests infrastructure
provides:
  - Settings-independent active/inactive privacy-mask writes and background-entry latching
  - Exhaustive regression coverage for the pre-settings inactive-to-background launch race
affects: [UIARCH-04, app-switcher-privacy, scene-phase-lifecycle]

# Tech tracking
tech-stack:
  added: []
  patterns: [safety-critical state mutations before side-effect gates, exhaustive TestStore launch-race coverage]

key-files:
  created: []
  modified:
    - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
    - AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift

key-decisions:
  - "07-09: Scene-phase privacy writes and background latching run before the settings-loaded guard; greeting, clipboard, pump, reconcile, scheduling, and reading-flush effects remain gated."

patterns-established:
  - "Safety-critical snapshot protection mutates shared state before initialization-dependent side effects are considered."
  - "Pre-initialization reducer paths are tested exhaustively with no received actions when effects must remain gated."

requirements-completed: [UIARCH-04]

coverage:
  - id: D1
    description: Active and inactive mask writes plus background latching run before settings finish loading while settings-dependent effects remain gated.
    requirement: UIARCH-04
    verification:
      - kind: integration
        ref: "xcodebuild -workspace EhPanda.xcodeproj/project.xcworkspace -scheme AppFeature -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' build"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift#maskAndLatchAreWrittenBeforeSettingsLoad"
        status: pass
    human_judgment: false
  - id: D2
    description: The scene-phase test helper can represent unloaded settings and defaults existing tests to their prior loaded-settings setup.
    requirement: UIARCH-04
    verification:
      - kind: unit
        ref: "xcodebuild -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -only-testing:AppFeatureTests/AppReducerScenePhaseTests test"
        status: pass
    human_judgment: false

# Metrics
duration: 7min
completed: 2026-07-14
status: complete
---

# Phase 07 Plan 09: Pre-Settings Privacy-Mask Race Closure Summary

**Scene transitions now protect App Switcher snapshots and latch background entry before settings initialization, with an exhaustive regression proving the cold-launch path emits no gated effects.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-07-14T00:17:49Z
- **Completed:** 2026-07-14T00:25:15Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Moved the active/inactive shared-mask writes and background-entry latch ahead of the `hasLoadedInitialSetting` guard.
- Preserved the existing initialization-dependent greeting, clipboard, pump, reconcile, scheduling, and reading-flush effect gate.
- Added an exhaustive pre-settings regression that drives inactive then background, verifies blur intensity `40` and the background latch, and receives no actions.
- Parameterized the TestStore helper without changing the loaded-settings default used by existing tests.

## Task Commits

1. **Task 1: Make scene-phase privacy state settings-independent** - `f5ec8904` (fix)
2. **Task 2 RED: Add the pre-settings regression** - `6853a70a` (test)
3. **Task 2 GREEN: Parameterize the scene test helper** - `d4e68abe` (feat)

## Files Created/Modified

- `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift` - Performs snapshot-safety mutations before the settings-loaded side-effect gate.
- `AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift` - Covers the unloaded-settings inactive/background path and exposes helper setup for that state.

## Decisions Made

- Kept the latch-consuming foreground reconcile behind the settings guard; only the latch assignment moved before it.
- Used a dedicated first scene-phase switch for safety-critical state changes so all existing side-effect branches remain visibly and structurally gated.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated stale Xcode verification routing**

- **Found during:** Task 1 and Task 2 verification
- **Issue:** The planned `AppPackage-Package` scheme is not present, `AppPackage/` is not directly accepted as a package by this Xcode installation, and the planned iPhone 16 simulator is unavailable.
- **Fix:** Built the `AppFeature` workspace scheme and ran the repository's `EhPanda` `FeatureTests` test plan on the installed iPhone Air simulator with iOS 26.5.
- **Files modified:** None
- **Verification:** The AppFeature build succeeded with SwiftLint enabled; all 3 focused tests in 1 suite passed.
- **Committed in:** No source commit required; verification-only adjustment.

---

**Total deviations:** 1 auto-fixed (1 blocking verification-environment issue).
**Impact on plan:** The intended production module and focused test suite were verified on the available Xcode scheme and simulator; implementation scope was unchanged.

## Issues Encountered

- The first sandboxed focused-test attempt could not access CoreSimulator services. The established app test-plan invocation was rerun with simulator access and completed successfully.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Threat T-07-20's pre-settings information-disclosure path is mitigated in source and covered by an automated regression.
- Plan 07-10 can address the remaining scene-phase test-exhaustivity gap independently.
- No stubs, new trust boundaries, lint suppressions, or deferred implementation issues were introduced.

## Self-Check: PASSED

- Commits `f5ec8904`, `6853a70a`, and `d4e68abe` exist in git history.
- Both modified source files exist and `git diff --check` passes across the three task commits.
- The AppFeature simulator build succeeded with SwiftLint enabled.
- `AppReducerScenePhaseTests` passed 3 tests in 1 suite, including `maskAndLatchAreWrittenBeforeSettingsLoad`.
- Safety-critical mask writes and background latching precede the settings-loaded guard; all named settings-dependent effects follow it.
- The new regression is exhaustive, contains no `receive`, and finishes with no in-flight effects.

---
*Phase: 07-root-privacy-mask-auto-lock-removal*
*Completed: 2026-07-14*
