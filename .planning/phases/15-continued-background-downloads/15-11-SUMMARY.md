---
phase: 15-continued-background-downloads
plan: 11
subsystem: testing
tags: [swift, swift-concurrency, bgcontinuedprocessingtask, swift-testing]

requires:
  - phase: 15-continued-background-downloads
    provides: "Identified continued-processing handles and coordinator identity gates from plan 15-10"
provides:
  - "Deterministic start-gate and refusal staging for the background-processing client spy"
  - "CR-04 interleave coverage proving stale completion cannot finish a successor session"
  - "WR-01 refusal recovery and WR-08 foreign-expiration coordinator regressions"
affects: [continued-background-downloads, background-processing-client, download-coordinator]

tech-stack:
  added: []
  patterns:
    - "AsyncStream rendezvous gates stage actor reentrancy without polling or clock sleeps"
    - "Lifecycle tests assert both stale-session isolation and successor liveness"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift
  modified:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift

key-decisions:
  - "Record every accepted start completely before parking it behind the one-shot test gate."
  - "Model refusal as an observable call that mints no session identity or event continuation."
  - "Keep coordinator identity regressions in a separate suite to preserve the established lifecycle file's hard length boundary."

patterns-established:
  - "Deterministic interleave staging: expose an entered signal only after all spy state is recorded, then release explicitly."
  - "Successor survival proof: assert targeted completion identity, retained liveness, and a subsequent progress push."

requirements-completed: [SC1]

coverage:
  - id: D1
    description: "An abandoned in-flight start completes only its own client session, never the successor started after a queue drain."
    requirement: SC1
    verification:
      - kind: integration
        ref: "DownloadContinuedSessionIdentityTests.testBailOutFinishNeverLandsOnTheMostRecentStartsSession"
        status: pass
    human_judgment: false
  - id: D2
    description: "A refused start rolls coordinator bookkeeping back and the next tap installs a real, push-capable session."
    requirement: SC1
    verification:
      - kind: integration
        ref: "DownloadContinuedSessionIdentityTests.testARefusedStartRollsBookkeepingBackAndTheNextTapStartsARealSession"
        status: pass
    human_judgment: false
  - id: D3
    description: "A foreign expiration cannot pause, complete, or detach work covered by a successor session."
    requirement: SC1
    verification:
      - kind: integration
        ref: "DownloadContinuedSessionIdentityTests.testAForeignExpirationCannotPauseWorkASuccessorSessionCovers"
        status: pass
      - kind: integration
        ref: "xcodebuild test -only-testing:DownloadsFeatureTests"
        status: pass
      - kind: other
        ref: "clean EhPanda app-scheme build with SwiftLint build plugins"
        status: pass
    human_judgment: false

duration: 10min
completed: 2026-07-28
status: complete
---

# Phase 15 Plan 11: Continued-Session Identity Regressions Summary

**Deterministic actor interleaves now prove stale starts, refused starts, and foreign expirations cannot corrupt a successor continued-processing session**

## Performance

- **Duration:** 10 min
- **Started:** 2026-07-28T10:37:10Z
- **Completed:** 2026-07-28T10:46:39Z
- **Tasks:** 2
- **Files modified:** 2 test-support and regression files

## Accomplishments

- Added a one-shot `AsyncStream` rendezvous that records an accepted start completely before parking it, plus deterministic refusal staging that records the call without minting session state.
- Staged the CR-04 drain-then-second-tap interleave and proved the losing continuation targets its own session while the successor remains live and receives progress.
- Covered coordinator rollback after store refusal and verified a foreign expiration cannot pause or complete successor work.
- Kept all 296 Downloads feature tests green with the existing three known issues, and passed a clean app build with no SwiftLint violations.

## Task Commits

Each task was committed atomically:

1. **Task 1: Spy staging verbs and the drain-then-second-tap interleave regression** - `b89c46d4` (test)
2. **Task 2: Refusal-rollback and foreign-expiration regressions, and the phase's closing gates** - `0840bc67` (test)

## Files Created/Modified

- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift` - Holds the three deterministic coordinator identity regressions.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift` - Adds one-shot accepted-start gating and refusal staging to the background-processing spy.

## Decisions Made

- Accepted starts publish their complete recorded identity before the gate's entered signal, making the exact reentrant state observable without polling.
- A refused start increments the call count and records presentation strings, but creates no identity or stream continuation, matching the real store contract.
- Identity regressions remain separate from `DownloadContinuedSessionTests.swift` so the existing lifecycle suite stays below the project's hard file-length limit.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Verification

- Targeted `DownloadContinuedSessionIdentityTests`: 3 tests passed.
- Full `DownloadsFeatureTests`: 296 tests in 57 suites passed with 3 known expected issues, including scheduling and background-execution invariant coverage.
- Clean `EhPanda` app-scheme builds after both tasks: succeeded with SwiftLint build plugins and no violations.
- Static gates: both staging verbs present, all three named regressions present, foreign expiration driven directly, 139-line suite, and no polling or clock-sleep call in the new file.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The SC1 coordinator identity gaps are closed with deterministic regression coverage.
- Phase 15's automated surface is ready for final verification; device-only continued-processing behavior remains covered by the phase's existing human procedure.

## Self-Check: PASSED

- Both test files exist.
- Task commits `b89c46d4` and `0840bc67` exist.
- The summary contains no absolute home-directory path.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-28*
