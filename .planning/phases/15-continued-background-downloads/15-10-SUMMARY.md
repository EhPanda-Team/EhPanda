---
phase: 15-continued-background-downloads
plan: 10
subsystem: background-execution
tags: [swift, swift-concurrency, bgcontinuedprocessingtask, swift-testing]

requires:
  - phase: 15-continued-background-downloads
    provides: "Coordinator-side UUID lifecycle and continued-processing session store from plans 15-03 through 15-09"
provides:
  - "Identified background-processing session handles with targeted completion"
  - "Observable store refusal with coordinator rollback"
  - "Identity-gated coordinator completion, expiration pause, and progress paths"
  - "Deterministic store regressions for foreign completion and refused re-entry"
affects: [15-11, continued-background-downloads, background-processing-client]

tech-stack:
  added: []
  patterns:
    - "Session handles carry the identity required for every terminal mutation"
    - "Actor-owned lifecycle mutations re-check coordinator identity after suspension"

key-files:
  created: []
  modified:
    - AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift
    - AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
    - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift

key-decisions:
  - "Promote the store's existing identity through one optional session handle rather than create a parallel completion channel."
  - "Record the client session id only after the coordinator ownership re-check, leaving it nil while start is in flight."
  - "Treat refusal as retryable coordinator rollback and leave the scheduler untouched."
  - "Move shared continued-session fixtures to DownloadFeatureTestHelpers so the hard file-length gate remains satisfied and plan 15-11 can reuse them."

patterns-established:
  - "Targeted lifecycle completion: a caller may finish only the session id returned by its own start."
  - "Stale mutation defense: completion, pause loops, and progress pushes all present coordinator identity."

requirements-completed: [SC1]

coverage:
  - id: D1
    description: "Foreign session completion is a no-op against a held continued-processing task."
    requirement: SC1
    verification:
      - kind: unit
        ref: "ContinuedProcessingSessionTests.testFinishWithAForeignSessionIDIsANoOp"
        status: pass
    human_judgment: false
  - id: D2
    description: "Store re-entry refusal is observable, touches no scheduler state, and permits a later start."
    requirement: SC1
    verification:
      - kind: unit
        ref: "ContinuedProcessingSessionTests.testStartWhileASessionIsHeldIsRefusedAndALaterStartSucceeds"
        status: pass
    human_judgment: false
  - id: D3
    description: "Coordinator completion, expiration pause, and progress paths carry and gate session identity."
    requirement: SC1
    verification:
      - kind: integration
        ref: "xcodebuild test -only-testing:DownloadsFeatureTests"
        status: pass
      - kind: other
        ref: "clean EhPanda app-scheme build with SwiftLint build plugins"
        status: pass
    human_judgment: false

duration: 25min
completed: 2026-07-28
status: complete
---

# Phase 15 Plan 10: Session Identity Promotion Summary

**Identified continued-processing handles now prevent stale callers from completing, pausing, or updating a successor session**

## Performance

- **Duration:** 25 min
- **Started:** 2026-07-28T10:02:04Z
- **Completed:** 2026-07-28T10:26:57Z
- **Tasks:** 2
- **Files modified:** 10 implementation and test files

## Accomplishments

- Promoted the store's UUID into an optional `BackgroundProcessingSession` handle and made completion conditional on presenting that exact id.
- Threaded the client identity through both coordinator completion sites, expiration pause loops, and progress updates, including refusal rollback when the store still holds a predecessor.
- Added deterministic store tests proving foreign completion cannot end a held task and refused re-entry burns no scheduler state.
- Preserved the background-execution topology and counts-only system card while the full Downloads feature suite and clean app build stayed green.

## Task Commits

Each task was committed atomically:

1. **Task 1: Promote the store's session identity into the seam and thread it through every completion path** - `9efdb0b4` (fix)
2. **Task 2: Store-side identity regression cases** - `9b1cb389` (test)

## Files Created/Modified

- `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift` - Defines the identified optional session handle and targeted finish seam.
- `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift` - Mints, guards, and clears the store-side session identity.
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` - Stores the client-side identity beside the coordinator identity.
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` - Handles refusal rollback and identity-gates completion, expiration pauses, and progress.
- `AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift` - Passes the current identity through throttled progress flushes.
- `AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift` - Exposes the coordinator identity needed by lifecycle tests.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift` - Mirrors identity-targeted completion in the client spy.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` - Hosts reusable continued-session fixtures outside the hard file-length boundary.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` - Adapts coordinator lifecycle coverage to identified handles.
- `AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift` - Adapts existing store coverage and adds both identity regressions.

## Decisions Made

- The returned handle is the only client-side identity channel. The coordinator's existing UUID remains its local ownership stamp.
- A nil start is an explicit refusal, so the coordinator rolls back only its own stamp and allows the next queue-mobilizing action to retry.
- The coordinator records the client id only after its post-start ownership check, preventing a losing actor continuation from overwriting successor state.
- Continued-session fixtures moved to the shared helper file both to preserve the 1,000-line hard SwiftLint gate and to support the next interleave suite.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added explicit Swift 6.3 test-support types**

- **Found during:** Task 2 targeted verification
- **Issue:** The current compiler rejected two fixture records nested in a protocol extension and could not infer two optional stream types introduced by the seam migration.
- **Fix:** Moved the records to file scope and annotated the event stream and mutex-returned continuation explicitly.
- **Files modified:** `DownloadFeatureTestHelpers.swift`, `DownloadContinuedSessionTests.swift`, `DownloadFeatureTestSupportTypes.swift`
- **Verification:** Targeted store tests, all Downloads feature tests, and the clean app build passed.
- **Committed in:** `9efdb0b4` (part of the Task 1 migration commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Compiler compatibility only; the planned lifecycle behavior and scope are unchanged.

## Issues Encountered

- The originally named iPhone Air 26.2 destination was not installed. Verification used the installed iPhone Air 26.5 simulator.
- Simulator and Xcode cache access required the approved host execution context.
- Xcode 26.6 reported two pre-existing actor-isolation warnings in a UI-test file outside this plan. They are recorded in the phase deferred-items log; the clean app build itself completed without warnings or SwiftLint violations.

## Verification

- Targeted `ContinuedProcessingSessionTests`: 5 tests passed.
- Full `DownloadsFeatureTests`: 293 tests in 56 suites passed with 3 known expected issues, including `DownloadSchedulingTests` and `BackgroundExecutionInvariantTests`.
- Clean `EhPanda` app-scheme build: succeeded with SwiftLint build plugins and no violations.
- Static contract gates: 7 coordinator identity comparisons, no session-blind `finish(true)`, 916-line adapted coordinator test file, and no prohibited concurrency or lint escape hatches.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 15-11 can build its coordinator interleave regressions on the identified seam and the shared session fixture helpers.
- No implementation blocker remains; device-only continued-processing behavior stays with the phase's existing human verification.

## Self-Check: PASSED

- All ten implementation and test files exist.
- Task commits `9efdb0b4` and `9b1cb389` exist.
- The summary contains no absolute home-directory path.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-28*
