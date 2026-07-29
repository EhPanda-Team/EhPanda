---
phase: 15-continued-background-downloads
plan: 17
subsystem: architecture
tags: [swift, concurrency, background-processing, download-coordinator, testing]

requires:
  - phase: 15-continued-background-downloads
    provides: "The continued-processing client seam, session identities, and gap-closure regressions from the preceding rounds"
provides:
  - "Deferred reconciliation that preserves coordinator ownership across a suspended client start"
  - "A session spy constrained by the live store's single-session contract"
  - "Deterministic drain/start/tap and expiration interleave coverage stated against production-reachable lifecycles"
affects: [continued-background-downloads, background-processing, download-coordinator, session-lifecycle]

tech-stack:
  added: []
  patterns:
    - "A drain without a client session identity records reconciliation debt instead of releasing ownership"
    - "Test doubles refuse lifecycle transitions that their live counterpart refuses"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift

key-decisions:
  - "A queue drain that cannot name the client session is early rather than authoritative; reconciliation remains debt owned by the current coordinator session."
  - "The session spy records every start attempt but refuses one while an identity is held, releasing that identity only through matching finish or expiration."

patterns-established:
  - "Clear deferred reconciliation before discharging it so a reentrant reconcile can record fresh debt safely."
  - "Drive terminal-event tests through the client seam so spy and coordinator lifecycles remain synchronized."

requirements-completed: [SC1, SC2]

coverage:
  - id: D1
    description: "A drain crossing a suspended client start preserves the live coordinator session and discharges reconciliation after the client identity lands."
    requirement: SC1
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift#testADrainDuringAnInFlightStartDefersReconciliationAndKeepsCoverage"
        status: pass
      - kind: integration
        ref: "xcodebuild test -only-testing:DownloadsFeatureTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "The session spy refuses overlapping starts and preserves live-store identity behavior for progress, finish, and expiration."
    requirement: SC2
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift"
        status: pass
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift"
        status: pass
      - kind: other
        ref: "single-session guard, one-shot refusal, and start-gate release source scans"
        status: pass
    human_judgment: false
  - id: D3
    description: "Direct client composition and macro-generated unimplemented endpoints are documented without naming the removed dependency API."
    requirement: SC2
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift"
        status: pass
      - kind: other
        ref: "clean EhPanda app-scheme build with SwiftLint build plugins"
        status: pass
    human_judgment: false
  - id: D4
    description: "A physical iOS 26 device shows one surviving system progress card for a drain/start/tap interleave."
    requirement: SC1
    verification: []
    human_judgment: true
    rationale: "The Simulator cannot grant continued-processing tasks or render their system progress card; the phase device procedure remains the backstop."

duration: 21min
completed: 2026-07-29
status: complete
---

# Phase 15 Plan 17: Deferred Session Reconciliation Summary

**Suspended session starts now retain coordinator ownership until a client identity arrives, with a production-faithful single-session spy guarding the lifecycle**

## Performance

- **Duration:** 21 min
- **Started:** 2026-07-29T01:57:33Z
- **Completed:** 2026-07-29T02:18:15Z
- **Tasks:** 3
- **Files modified:** 6 Swift files

## Accomplishments

- Added per-session reconciliation debt so a queue drain cannot tear down ownership while the client start is suspended and its identity is not yet available.
- Enumerated the deferred, skipped, and terminal dispositions for every nil client-session identity read, and documented the forbidden and intentionally reachable interleavings at the start path.
- Corrected the session spy to refuse overlapping starts like the live store, made every start gate leak-safe, and restated expiration coverage through the real client seam.
- Replaced stale dependency-registration prose with the actual direct-injection and macro-generated unimplemented-client composition.

## Task Commits

Each task was committed atomically:

1. **Task 1: Defer reconciliation for an in-flight start, and dispose of every nil client-id read** - `13fc1f04` (fix)
2. **Task 2: Bind the session spy to the live single-session contract and triage the suite behind it** - `9a7f9294` (test)
3. **Task 3: Correct the documentation that describes a deleted dependency API** - `fef455c5` (docs)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` - Preserves ownership during suspended starts, discharges reconciliation debt, and records every nil-identity disposition.
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` - Stores documented per-session reconciliation debt and accurately describes direct client composition.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift` - Pins the surviving-session drain/start/tap contract with a leak-safe start gate.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift` - Delivers expiration through the client seam so the held identity is released as production releases it.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` - Describes the no-argument client's macro-generated unimplemented endpoints accurately.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift` - Mirrors the live single-session start, progress, finish, and expiration identity guards.

## Decisions Made

- A caller cannot release coordinator ownership until it can name the client session being released. A drain that arrives before identity installation records debt and returns.
- Reconciliation debt is cleared before discharge and at session teardown, preventing both fresh debt erasure and predecessor debt leakage.
- A refused client start remains terminal and silent; this plan does not add a fallback execution tier.
- The spy records refused start attempts for observability but never creates an identity or event stream for them.

## Test Triage

- **Real behavior change:** `testADrainDuringAnInFlightStartDefersReconciliationAndKeepsCoverage` now asserts one surviving session. Its predecessor expected a second accepted start, which Task 1 deliberately made unreachable.
- **Impossible-contract case:** `testAResumeInsideAStaleExpirationPauseSurvivesAndMobilizesTheQueue` now expires through `BackgroundProcessingClientSpy.expire()`. Directly injecting the coordinator event left the spy's predecessor identity artificially held, a lifecycle the live client cannot produce.
- **Production defects exposed:** None.

## Spy Contract Audit

- `start` records all arguments and refuses when a session identity is already held or the one-shot refusal is armed.
- `updateProgress` accepts only the held matching identity and records foreign or stale identities as rejected.
- `finish` records every call but clears and finishes only the held matching identity.
- `expire()` atomically takes the continuation and clears the held identity before yielding the terminal event.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected inconsistent state metadata emitted by the state handlers**
- **Found during:** Plan state update
- **Issue:** The handlers advanced the current position from plan 1 to plan 2 despite 17 summaries being present, reset completed phases from 14 to 13, wrote an 81 percent frontmatter value beside 188 of 190 completed plans, and labeled both new decisions with an unknown phase.
- **Fix:** Restored plan 17 completion, 14 completed phases, 99 percent plan progress, the next-plan instruction, and Phase 15 decision labels while preserving the handler-recorded metric and session timestamp.
- **Files modified:** `.planning/STATE.md`
- **Verification:** State frontmatter, current-position prose, progress bar, roadmap plan count, decisions, and session record now agree on plan 17 completion.
- **Committed in:** Plan metadata commit

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** The correction affects planning metadata only; implementation and verification remain exactly as planned.

## Issues Encountered

- The installed simulator was iPhone Air on iOS 26.5, so verification used that available runtime.
- A default parallel suite run exposed a pre-existing observer-emission timeout in `DownloadDeleteConvergenceTests`. The plan requires non-overlapping deterministic execution; the unchanged suite passed serially with all 303 tests, so no unrelated source was modified.

## Verification

- Targeted `DownloadContinuedSessionTests`: 27 tests passed with the three expected known issues emitted by the deliberately unimplemented client endpoints.
- Full serial `DownloadsFeatureTests`: 303 tests in 59 suites passed with the same three expected known issues and no unexpected failures.
- Clean `EhPanda` app-scheme build passed with SwiftLint build plugins, zero SwiftLint violations, and zero warnings in touched files.
- Static acceptance gates found four executable reconciliation-debt references, all three nil-identity dispositions, one forbidden and three reachable-by-design interleaving statements, one guarded start-gate call with one adjacent deferred release, and no removed dependency-API spelling.
- Prohibition scans found no timing polls in the held-start regression, no concurrency or SwiftLint escape hatch in touched files, and no legacy background-execution tier.

## Known Stubs

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- CR-01, WR-01, WR-02, and WR-03 are closed in source and automated coverage.
- Phase 15 can proceed to the remaining gap-closure plans, then the existing physical-device backstop for system progress-card behavior.

## Self-Check: PASSED

- All six modified Swift files and this summary exist.
- Task commits `13fc1f04`, `9a7f9294`, and `fef455c5` exist.
- The summary contains no absolute home-directory path.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-29*
