---
phase: 15-continued-background-downloads
plan: 12
subsystem: background-processing
tags: [swift, swift-concurrency, bgcontinuedprocessingtask, swift-testing]

requires:
  - phase: 15-continued-background-downloads
    provides: "Identified continued-processing session handles and deterministic start staging from plans 15-10 and 15-11"
provides:
  - "Initial progress snapshots recorded atomically with continued-session submission"
  - "Client-session identity required and checked for every system-card progress mutation"
  - "Deterministic store and coordinator regressions for seeded adoption and stale progress"
affects: [continued-background-downloads, background-processing-client, download-coordinator]

tech-stack:
  added: []
  patterns:
    - "Every system-visible session mutation presents the client session identity"
    - "AsyncStream rendezvous gates stage actor interleaves without sleeps or polling"

key-files:
  created: []
  modified:
    - AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift
    - AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
    - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift

key-decisions:
  - "Capture title, subtitle, completed count, and total count from one coordinator snapshot before submitting the continued session."
  - "Read the client session id only after the coordinator's post-suspension ownership re-check, and send nothing while start is still in flight."
  - "Park staged progress after it crosses the client seam but before its identity guard, making the stale S1-to-S2 hop deterministic."

patterns-established:
  - "Identity-complete seam: start returns the identity and every later card mutation must present it."
  - "Seeded monotonicity: the coordinator's completed-count floor begins at the same snapshot the card initially displays."

requirements-completed: [SC1, SC2]

coverage:
  - id: D1
    description: "A task launched immediately after submission adopts the real non-zero queue snapshot rather than 0 / 0 progress."
    requirement: SC1
    verification:
      - kind: integration
        ref: "ContinuedProcessingSessionTests.testAdoptionSeedsProgressFromTheStartSnapshot"
        status: pass
      - kind: integration
        ref: "DownloadContinuedSessionTests.testStartIsRecordedBeforeAnyProgressUpdate"
        status: pass
    human_judgment: false
  - id: D2
    description: "The store rejects progress whose client session id does not name the held session."
    requirement: SC2
    verification:
      - kind: integration
        ref: "ContinuedProcessingSessionTests.testAForeignProgressPushCannotRepaintTheHeldSession"
        status: pass
    human_judgment: false
  - id: D3
    description: "A progress push held across an S1-to-S2 transition is rejected and S2 remains pushable and finishable."
    requirement: SC2
    verification:
      - kind: integration
        ref: "DownloadContinuedSessionIdentityTests.testAHeldProgressPushCannotRepaintASuccessorSessionsCard"
        status: pass
      - kind: integration
        ref: "xcodebuild test -only-testing:DownloadsFeatureTests"
        status: pass
      - kind: other
        ref: "clean EhPanda app-scheme build with SwiftLint build plugins"
        status: pass
    human_judgment: false

duration: 12min
completed: 2026-07-29
status: complete
---

# Phase 15 Plan 12: Seeded, Session-Identified Progress Summary

**Continued-processing cards now start from the queue's real snapshot and reject every progress push that does not name the held client session**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-28T16:08:21Z
- **Completed:** 2026-07-28T16:20:16Z
- **Tasks:** 2
- **Files modified:** 7 Swift files

## Accomplishments

- Extended the background-processing seam so start carries the initial completed and total counts, allowing immediate task adoption to report real progress.
- Made progress updates client-session identified at the seam, store, coordinator, and test-double boundaries; foreign updates cannot touch saved counts or a successor card.
- Seeded the coordinator's monotonic completed-count floor from the submitted snapshot and abandoned pushes that lose ownership across the schedulable-progress suspension.
- Added deterministic regressions for non-zero adoption, foreign-id rejection, and a held S1 push released only after S2 becomes live.

## Task Commits

Each task was committed atomically:

1. **Task 1: Seed the start snapshot and identify every progress push** - `47413bc0` (fix)
2. **Task 2: Regressions for seeded adoption, rejected foreign progress, and the held-push interleave** - `5f486b1d` (test)

## Files Created/Modified

- `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift` - Carries initial counts through start and a client session id through every progress push.
- `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift` - Seeds adoption from start and identity-checks progress before changing saved or system task state.
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` - Submits one coherent snapshot, seeds the monotonic floor, and re-checks ownership after suspension.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift` - Records start counts, distinguishes accepted and rejected progress, and stages one progress call deterministically.
- `AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift` - Proves seeded adoption and foreign progress rejection at the store.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift` - Proves a held S1 push cannot repaint S2.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` - Verifies the start call itself carries the card's initial counts.

## Decisions Made

- One coordinator snapshot supplies all four start arguments so the card's text and progress bar cannot disagree at submission.
- The client session id is read only after the post-suspension coordinator ownership check; a start still in flight has no card identity and receives no push.
- The progress test gate records the in-flight arguments, then suspends before the identity guard so the reviewed stale-hop ordering is staged rather than timing-dependent.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Adapted verification to the repository's non-interactive Xcode environment**
- **Found during:** Task 1 verification
- **Issue:** The requested iPhone 17 simulator is not installed, and Xcode's cached macro approvals reject the resolved package graph in non-interactive runs.
- **Fix:** Used the installed iPhone Air simulator by id and the repository CI's established `-skipMacroValidation -skipPackagePluginValidation` flags. Project, scheme, test plan, target filter, compilation, tests, and SwiftLint checks remained unchanged.
- **Files modified:** None
- **Verification:** Full `DownloadsFeatureTests` and clean app-scheme builds exited 0 after both tasks.
- **Committed in:** Not applicable (verification-command adaptation only)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Verification semantics were unchanged; only local destination and non-interactive trust-gate arguments differed.

## Issues Encountered

- The first sandboxed Xcode invocation could not access Simulator and package-cache services; the same required command was rerun with the workspace's approved Xcode permissions.

## Verification

- Full `DownloadsFeatureTests`: passed after Task 1 and Task 2, including `DownloadSchedulingTests` and both `BackgroundExecutionInvariantTests` cases.
- Clean `EhPanda` app-scheme build after each task: passed with the SwiftLint build plugins and no violations.
- Static acceptance gates: both seam count parameters and store identity guards present; client id appears at every coordinator lifecycle point; all three regressions and the progress gate present.
- Identity suite contains no `waitUntil` or `Task.sleep`; `DownloadContinuedSessionTests.swift` remains below 1000 lines.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- SC1's unseeded initial-progress gap and SC2's session-blind progress gap are closed with deterministic regression coverage.
- Later gap-closure plans can build on the rule that every seam verb mutating a live card carries the client session identity.

## Self-Check: PASSED

- All seven modified Swift files exist.
- Task commits `47413bc0` and `5f486b1d` exist.
- The summary contains no absolute home-directory path.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-29*
