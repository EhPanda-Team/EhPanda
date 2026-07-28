---
phase: 15-continued-background-downloads
plan: 15
subsystem: testing
tags: [swift, swift-concurrency, swift-testing, download-coordinator, background-processing]

requires:
  - phase: 15-continued-background-downloads
    provides: "Queue-intent generations, expiration ownership guards, and the explicitly releasable blocking runner from plan 15-14"
provides:
  - "A deterministic expiration-pause interleave proving a retry survives stale settlement and receives a successor session"
  - "A companion user-pause interleave proving expiration ownership guards do not change manual pause semantics"
  - "Honest separation between the existing foreign-session early guard and the new post-guard suspension coverage"
affects: [continued-background-downloads, expiration-reentrancy, download-coordinator, session-identity]

tech-stack:
  added: []
  patterns:
    - "Async race regressions stage exact suspension boundaries through checked-continuation rendezvous rather than sleeps or polling"
    - "Expiration and user-pause interleaves use the coordinator's real public mutation paths"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift
  modified:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift

key-decisions:
  - "Drive expiration through handleContinuedSessionEvent so the regression includes session teardown before the per-gallery pause."
  - "Hold the scheduled runner after cancellation so retry lands after the first ownership guard and before the settled pause write."
  - "Keep user-initiated pause last-writer-wins behavior as the explicit boundary of the expiration-only generation guard."

patterns-established:
  - "Reentrant queue tests await start and cancellation-observed rendezvous, act inside the held window, then release and await the mutation under test."
  - "Coverage names the exact guard or suspension window it exercises instead of treating adjacent identity checks as equivalent."

requirements-completed: [SC2, SC3]

coverage:
  - id: D1
    description: "An ordinary retry inside a cancellation-held expiration pause retains its persisted queue intent, mobilizes work after release, and receives the continued session it requested."
    requirement: SC3
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift#testAResumeInsideAStaleExpirationPauseSurvivesAndMobilizesTheQueue"
        status: pass
      - kind: integration
        ref: "xcodebuild test -only-testing:DownloadsFeatureTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "A user-initiated pause remains last-writer-wins when retry lands inside the same cancellation-held window."
    requirement: SC2
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift#testAUserPauseIsNeverAbandonedByAnInterleavingRetry"
        status: pass
      - kind: other
        ref: "clean EhPanda app-scheme build with SwiftLint build plugins"
        status: pass
    human_judgment: false

duration: 12min
completed: 2026-07-29
status: complete
---

# Phase 15 Plan 15: Continued-Session Interleave Regressions Summary

**Cancellation-held interleave tests now prove stale expiration settlement preserves a newer retry while an ordinary user pause still wins the same race**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-28T17:01:59Z
- **Completed:** 2026-07-28T17:13:39Z
- **Tasks:** 2
- **Files modified:** 2 Swift test files

## Accomplishments

- Staged the CR-03 suspension window through the real expiration event handler, holding active-task cancellation while an ordinary retry advances the gallery's queue intent.
- Proved the retry survives on disk, retains its queued mode, mobilizes the queue after release, and starts a successor continued-processing session without completing that successor.
- Pinned the guard's opposite boundary: a manual pause ignores expiration-only ownership checks and still clears an interleaving retry under established last-writer-wins semantics.
- Rescoped the foreign-session case to the early guard it actually exercises, pointing readers to the new suite for post-guard suspension coverage.

## Task Commits

Each task was committed atomically:

1. **Task 1: The stale expiration pause that a retry survives** - `c81171fd` (test)
2. **Task 2: The guard's boundary, and the round's closing gates** - `cd2ac151` (test)

## Files Created/Modified

- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift` - Holds the two deterministic expiration-versus-user-action interleave regressions.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift` - Describes the foreign-expiration case as an early-guard regression and links the suspension-window coverage.

## Decisions Made

- Used `BlockingRunnerControl.started()` and `cancellationObserved()` as exact rendezvous points; the new suite contains no sleep, clock, or predicate poll.
- Used the real `retry(gid:mode:)`, `pause(gid:)`, and `handleContinuedSessionEvent(_:sessionID:)` paths so assertions cover the same convergence tails as production.
- Asserted persisted queue membership, in-memory queued mode, client start count, coordinator session liveness, and successor completion identity as separate axes of the expiration outcome.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Adapted verification to the installed simulator**
- **Found during:** Task 1 verification
- **Issue:** The plan's iPhone 17 destination is not installed in the execution environment.
- **Fix:** Ran the unchanged project, scheme, test plan, and test filters on the installed booted iPhone Air simulator, retaining the repository's non-interactive macro and package-plugin validation flags.
- **Files modified:** None
- **Verification:** Both targeted runs, the complete `DownloadsFeatureTests` run, and clean app-scheme builds exited 0.
- **Committed in:** Not applicable (verification-command adaptation only)

**2. [Rule 1 - Bug] Corrected inconsistent state metadata emitted by the state handlers**
- **Found during:** Plan state update
- **Issue:** The handlers advanced the plan but rewrote the frontmatter to 13 completed phases and 81 percent, left the current-position prose on plan 14, and labeled the new decisions with an unknown phase.
- **Fix:** Restored the authoritative 14 completed phases and 99 percent, advanced the prose to plan 15 completion, refreshed the activity description, and labeled the decisions as Phase 15.
- **Files modified:** `.planning/STATE.md`
- **Verification:** State frontmatter, current-position prose, progress bar, roadmap counts, and session record agree on plan 15 completion.
- **Committed in:** Plan metadata commit

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking)
**Impact on plan:** Both adjustments preserve the planned code and verification scope while keeping execution metadata internally consistent.

## Issues Encountered

- The first complete download-target run timed out in three pre-existing observer-snapshot cases while 303 tests ran in parallel. All three passed together in an isolated diagnostic run, and the immediately following unchanged full run passed all 303 tests with one expected known issue. No source change or suppression was applied.

## Verification

- Targeted `DownloadContinuedSessionInterleaveTests`: both cases passed.
- Full `DownloadsFeatureTests`: 303 tests passed with zero unexpected failures; the existing expected known issue remained recorded.
- Clean `EhPanda` app-scheme build: passed twice with SwiftLint build plugins and zero violations.
- Static gates: both required test names occur once, the real event handler and cancellation-holding fixture are referenced, all four identity-suite cases remain present, the new file is 98 lines, and it contains no sleep, clock, or polling primitive.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 15-16 can decide the owner-pending dead background-processing dependency accessors without reopening the expiration reentrancy path.
- The physical-device card-cancel/foreground-resume observation remains the phase backstop for system UI behavior; deterministic coordinator coverage is now complete.

## Self-Check: PASSED

- Both Swift test files and this summary exist.
- Task commits `c81171fd` and `cd2ac151` exist.
- The summary contains no absolute home-directory path.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-29*
