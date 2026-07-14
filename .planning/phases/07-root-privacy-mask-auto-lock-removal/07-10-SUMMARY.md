---
phase: 07-root-privacy-mask-auto-lock-removal
plan: 10
subsystem: app-privacy-testing
tags: [swift, tca, swift-testing, teststore, swiftpm]

# Dependency graph
requires:
  - phase: 07-09
    provides: settings-independent scene-phase privacy writes and launch-race coverage
provides:
  - Exhaustive exactly-once foreground greeting and clipboard assertions
  - Explicit zero-detection coverage when clipboard detection is disabled
  - AppFeatureTests dependency graph without a redundant direct TCA link
affects: [UIARCH-04, scene-phase-lifecycle, app-feature-tests]

# Tech tracking
tech-stack:
  added: []
  patterns: [exhaustive TestStore action draining, LockIsolated dependency counters, transitive test dependencies]

key-files:
  created: []
  modified:
    - AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift
    - AppPackage/Package.swift

key-decisions:
  - "07-10: Foreground tests explicitly pause the long-lived activity-log pump after receiving every expected action, preserving TestStore exhaustivity without skipping in-flight effects."
  - "07-10: Clipboard cardinality counts the unconditional changeCount read, while the test double returns no URL so unrelated deep-link work cannot enter the assertion."
  - "07-10: The test-only ClipboardClient initializer is reached with @testable import instead of expanding the production client's public API."

patterns-established:
  - "Exactly-once effect tests receive each action once, explicitly cancel intentional long-lived effects, and finish exhaustively."
  - "A LockIsolated counter at an unconditional dependency seam corroborates action cardinality without timing assumptions."

requirements-completed: [UIARCH-04]

coverage:
  - id: D1
    description: Foreground scene activation emits greeting and log-pump actions exactly once, emits clipboard detection exactly once when enabled, and emits it zero times when disabled.
    requirement: UIARCH-04
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift#scenePhaseWritesPrivacyMaskAndStartsForegroundEffectsOnce"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift#activeSceneSkipsClipboardDetectionWhenDisabled"
        status: pass
    human_judgment: false
  - id: D2
    description: AppFeatureTests imports and uses TCA through AppFeature without directly relinking ComposableArchitecture.
    requirement: UIARCH-04
    verification:
      - kind: integration
        ref: "xcodebuild -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:AppFeatureTests test"
        status: pass
    human_judgment: false

# Metrics
duration: 8min
completed: 2026-07-14
status: complete
---

# Phase 07 Plan 10: Foreground Cardinality and Test Dependency Summary

**Exhaustive TestStore coverage now proves one enabled and zero disabled clipboard detections while AppFeatureTests reaches TCA only through AppFeature.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-14T00:51:32Z
- **Completed:** 2026-07-14T00:59:45Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Removed both `withExhaustivity(.off)` scopes and explicitly received every foreground child action.
- Added a `LockIsolated<Int>` clipboard counter proving one enabled detection and zero disabled detections.
- Replaced broad in-flight-effect skipping with an explicit activity-log pump pause before exhaustive `finish()`.
- Removed the direct `ComposableArchitecture` dependency from AppFeatureTests and verified the complete target suite.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Add the failing exhaustive clipboard-cardinality proof** - `f27df052` (test)
2. **Task 1 GREEN: Wire the counting clipboard test double** - `296930fc` (feat)
3. **Task 2: Remove the redundant AppFeatureTests TCA dependency** - `b4ced678` (chore)

## Files Created/Modified

- `AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift` - Exhaustively drains foreground actions, explicitly stops the log pump, and verifies clipboard dependency cardinality.
- `AppPackage/Package.swift` - Leaves AppFeature as the sole AppFeatureTests dependency.

## Decisions Made

- Explicitly send `.appLogsPump(.pausePump)` after the expected foreground receives. The pump is intentionally long-lived, so cancellation is part of deterministic test cleanup rather than a reason to weaken exhaustivity.
- Count `clipboardClient.changeCount()` calls because every `.detectClipboardURL` reduction reads that seam exactly once; `url()` remains a controlled nil to avoid unrelated deep-link effects.
- Use `@testable import ClipboardClient` for the test-local memberwise initializer instead of widening the production API solely for tests.

## TDD Gate Compliance

- **RED:** `f27df052` made the enabled test fail with `clipboardInvocationCount.value` equal to `0` instead of `1`.
- **GREEN:** `296930fc` injected the counting clipboard double; all 3 focused tests passed.
- **REFACTOR:** No separate refactor was needed.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Used the installed project test route and simulator**

- **Found during:** Task 1 and Task 2 verification
- **Issue:** The planned `AppPackage-Package` scheme and iPhone 16 simulator are unavailable in this checkout.
- **Fix:** Used the repository's `EhPanda` scheme, `FeatureTests` test plan, and installed iPhone Air simulator on iOS 26.5.
- **Files modified:** None
- **Verification:** The focused scene-phase suite and complete AppFeatureTests target both exited successfully.
- **Committed in:** No source commit required; verification-only adjustment.

**2. [Rule 3 - Blocking] Kept the counting client test-local without a public API expansion**

- **Found during:** Task 1 GREEN compilation
- **Issue:** `ClipboardClient`'s synthesized memberwise initializer is internal, so a normal import could not construct the required counting double.
- **Fix:** Switched the test import to `@testable import ClipboardClient`; no production declaration changed.
- **Files modified:** `AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift`
- **Verification:** The focused test target compiled and all 3 tests passed.
- **Committed in:** `296930fc`

---

**Total deviations:** 2 auto-fixed (2 blocking verification or compilation issues).
**Impact on plan:** The requested test behavior and package dependency outcome are unchanged; no production API or runtime behavior changed.

## Issues Encountered

- A sandboxed simulator attempt lost its CoreSimulator connection. Re-running with simulator service access completed successfully.
- The initial RED run failed only on the intended `0 == 1` clipboard-cardinality expectation.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Verifier truth #10 is now backed by exhaustive action receives plus dependency counters.
- WR-04 is closed with a green AppFeatureTests target that reaches TCA transitively.
- No stubs, security-boundary changes, lint suppressions, or deferred implementation issues were introduced.

## Self-Check: PASSED

- Commits `f27df052`, `296930fc`, and `b4ced678` exist in git history.
- Both modified files exist and `git diff --check` passes across the plan commits.
- `AppReducerScenePhaseTests.swift` contains no `withExhaustivity(.off)` or `skipInFlightEffects`.
- The focused scene-phase suite passed 3 tests in 1 suite.
- The complete AppFeatureTests target passed after removing its direct TCA dependency.

---
*Phase: 07-root-privacy-mask-auto-lock-removal*
*Completed: 2026-07-14*
