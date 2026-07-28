---
phase: 15-continued-background-downloads
plan: 13
subsystem: background-processing
tags: [swift, swift-concurrency, download-coordinator, swift-testing]

requires:
  - phase: 15-continued-background-downloads
    provides: "Session-identified continued-processing lifecycle and deterministic queue fixtures from plans 15-11 and 15-12"
provides:
  - "Vanished-record deletion that notifies observers and reaches scheduling convergence"
  - "One actor-isolated schedulable-work authority shared by queue lifetime and card progress"
  - "Deterministic regressions for session completion and next-gallery scheduling after deletion"
affects: [continued-background-downloads, download-coordinator, queue-convergence]

tech-stack:
  added: []
  patterns:
    - "Settled queue mutations notify observers before entering scheduling convergence"
    - "One schedulable-download selector serves scheduling, pending-work liveness, and card counts"
    - "Injected skipped-operation runners expose scheduling without performing downloads"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift

key-decisions:
  - "A vanished-record delete preserves its not-found result but first publishes the settled index and enters the same scheduling convergence tail as successful mutations."
  - "The running-task check remains a documented fast-path invariant; every disk-backed schedulable-work decision reads the shared authority."
  - "Regression scheduling is observed synchronously through an injected skipped-operation runner, while observer delivery is awaited as a task value rather than polled."

patterns-established:
  - "Mutation convergence: finish cleanup, notify observers, then schedule and reconcile the continued session."
  - "Schedulable-work authority: queue selection and isSchedulableDownload filtering live in one actor-isolated function."

requirements-completed: [SC1, SC2]

coverage:
  - id: D1
    description: "Deleting the last queued gallery after its indexed record vanishes returns not-found and completes the live continued session with its own client id."
    requirement: SC1
    verification:
      - kind: integration
        ref: "DownloadDeleteConvergenceTests.testDeletingAVanishedLastRecordCompletesTheSession"
        status: pass
      - kind: integration
        ref: "xcodebuild test -only-testing:DownloadsFeatureTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "Deleting a vanished queued record publishes the converged index, schedules exactly the next gallery, and keeps the continued session live while work remains."
    requirement: SC1
    verification:
      - kind: integration
        ref: "DownloadDeleteConvergenceTests.testDeletingAVanishedRecordKeepsTheRestOfTheQueueMoving"
        status: pass
      - kind: integration
        ref: "xcodebuild test -only-testing:DownloadsFeatureTests/DownloadDeleteConvergenceTests"
        status: pass
    human_judgment: false
  - id: D3
    description: "Scheduling, pending-work liveness, and continued-session progress share one schedulable-download selector without changing the existing predicate."
    requirement: SC2
    verification:
      - kind: integration
        ref: "xcodebuild test -only-testing:DownloadsFeatureTests"
        status: pass
      - kind: other
        ref: "static single-authority acceptance checks and clean EhPanda app-scheme build"
        status: pass
    human_judgment: false

duration: 21min
completed: 2026-07-29
status: complete
---

# Phase 15 Plan 13: Delete Convergence and Schedulable-Work Authority Summary

**Vanished download records now converge observer, scheduler, and continued-session state through one shared schedulable-work authority**

## Performance

- **Duration:** 21 min
- **Started:** 2026-07-28T16:24:05Z
- **Completed:** 2026-07-28T16:44:52Z
- **Tasks:** 2
- **Files modified:** 5 Swift files

## Accomplishments

- Closed the vanished-record delete hole by preserving cleanup and not-found semantics while notifying observers and entering the scheduler's reconciliation tail.
- Relocated queue selection and schedulable filtering into one actor-isolated authority used by scheduling, pending-work checks, progress snapshots, and expiration pausing.
- Added deterministic regressions proving the last vanished record completes its own session and a vanished record with work behind it schedules the next gallery and emits the updated index.

## Task Commits

Each task was committed atomically:

1. **Task 1: Converge the vanished-record delete and unify the schedulable-work predicate** - `e07533ec` (fix)
2. **Task 2: Regressions for both vanished-record delete outcomes** - `b2fea9ab` (test)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift` - Publishes and schedules after vanished-record cleanup before returning not-found.
- `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift` - Owns the shared schedulable-download selector and the documented active-task fast path.
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` - Reads the shared selector instead of declaring a private duplicate.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` - Accepts an injectable task runner for queued-coordinator fixtures.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift` - Covers both session-completion and queue-keeps-moving outcomes.

## Decisions Made

- Kept `Result.failure(.notFound)` as the caller-visible outcome after convergence; the defect was the skipped lifecycle tail, not the API contract.
- Kept `activeTask` as an explicit fast path because running work is unambiguous and does not need a disk-backed index read.
- Used the production `reloadDownloadRecord(gid:token:)` path to stage vanished records and an injected `.skippedOperation` runner to observe scheduling without starting a download.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added the typed model import required by the relocated authority**
- **Found during:** Task 1 verification
- **Issue:** Moving `schedulableDownloads()` into `DownloadClient+PendingWork.swift` exposed its `DownloadedGallery` return type in a file that did not import `AppModels`.
- **Fix:** Added the direct `AppModels` import rather than relying on another file's imports.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift`
- **Verification:** The targeted and full download test suites compiled and passed; the clean app-scheme build exited 0.
- **Committed in:** `e07533ec`

**2. [Rule 3 - Blocking] Adapted verification to the installed non-interactive Xcode environment**
- **Found during:** Task 1 verification
- **Issue:** The plan's named iPhone 17 simulator is not installed, and cached macro approvals reject the resolved package graph in non-interactive Xcode runs.
- **Fix:** Used the installed iPhone Air simulator by id and the repository CI's established `-skipMacroValidation -skipPackagePluginValidation` flags. Project, scheme, test plan, filters, tests, and SwiftLint plugins were unchanged.
- **Files modified:** None
- **Verification:** The targeted convergence suite, complete `DownloadsFeatureTests`, and clean app-scheme build all exited 0.
- **Committed in:** Not applicable (verification-command adaptation only)

**3. [Rule 1 - Bug] Corrected inconsistent state metadata emitted by the state handlers**
- **Found during:** Plan state update
- **Issue:** The handlers advanced the plan but rewrote the frontmatter to 13 completed phases and 81 percent while the authoritative body and roadmap remained at 14 phases and 98 percent; added decisions were also labeled with an unknown phase.
- **Fix:** Restored the phase and percentage values, updated the current-position prose for plan 13, and labeled the new decisions as Phase 15.
- **Files modified:** `.planning/STATE.md`
- **Verification:** State frontmatter, current-position prose, progress bar, roadmap counts, and session record agree on plan 13 completion.
- **Committed in:** Plan metadata commit

---

**Total deviations:** 3 auto-fixed (1 bug, 2 blocking)
**Impact on plan:** The adjustments were required to compile, verify, and record the plan accurately; none changed product scope.

## Issues Encountered

- The first sandboxed Xcode invocation could not access Simulator and package-cache services; required test and build commands were rerun with the workspace's approved Xcode permissions.

## Verification

- `DownloadDeleteConvergenceTests`: 2 tests passed, including exact client-session completion, observer delivery, and next-gallery scheduling.
- Full `DownloadsFeatureTests`: passed, including the pending-work, scheduling, folder-operation, and background-execution invariant coverage.
- Clean `EhPanda` app-scheme build: passed with SwiftLint build plugins and zero violations.
- Static acceptance gates: one shared `schedulableDownloads()` declaration, no duplicated executable predicate, required convergence calls and test names present, and no sleep, clock, or polling loop in the new suite.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 15-14 can build expiration ownership generations on a queue whose delete path now always converges.
- The remaining owner-pending dead-accessor review item stays assigned to plan 15-16; this plan did not alter that surface.

## Self-Check: PASSED

- All five created or modified Swift files exist.
- Task commits `e07533ec` and `b2fea9ab` exist.
- The summary contains no absolute home-directory path.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-29*
