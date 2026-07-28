---
phase: 15-continued-background-downloads
plan: 08
subsystem: infra
tags: [background-tasks, continued-processing, swift-concurrency, main-actor, swift-testing, gap-closure]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "The continued-processing session store, its three-event observable contract, and the permanent single-tier invariant suite (plans 15-03, 15-06, 15-07)"
provides:
  - "A module-internal scheduling seam (ContinuedTaskScheduling) confining every system-scheduler verb, including the previously unused cancel-by-identifier call"
  - "A ContinuedProcessingTasking protocol plus its SystemContinuedTask adapter, so the store's lifecycle is drivable by tests"
  - "Per-request cancellation of a submission an ended session abandoned (CR-01)"
  - "Identity-checked adoption that completes every launched task it turns away (CR-03)"
  - "A start-path seed-counter reset so a late progress push cannot seed the next session's card (WR-06)"
  - "A store-level lifecycle regression suite proven to fail against the pre-fix store"
affects: [15-09, continued-session coordinator work, any future background-execution change]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Thin-adapter seam: one injectable struct of main-actor closures owns every untestable system call, leaving the interesting state machine on the testable side"
    - "Expiration handler installed through a method taking a main-actor closure, never a mirrored property, so no isolation-losing conversion is needed"

key-files:
  created:
    - AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift
    - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift
  modified:
    - AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift

key-decisions:
  - "The scheduling seam is a struct of @MainActor closures on a @MainActor struct, so its static live value needs no global-isolation escape and callers cannot reach the scheduler from outside the store's isolation domain."
  - "ContinuedProcessingTasking exposes setExpirationHandler(_:) as a method rather than a settable property: a native property of the system's shape would force an isolation-losing conversion whose only workarounds are the escapes this repository bans."
  - "The launch seam hands the store an optional task and completes an unreadable stray itself, because only the store knows whether a failed launch belongs to the session it is currently awaiting."
  - "endSession cancels the retained identifier only when no task was ever adopted; the conditional is kept as written defense even though adoption already clears it."
  - "The once-per-process cancelAllRequests sweep is retained alongside per-request cancellation — the sweep covers a previous build's orphans, the per-request cancel is this process's per-session bookkeeping."

patterns-established:
  - "Seam-injecting internal initializer: production resolves the singleton, tests build isolated stores over spies, and the default argument keeps every production call site unchanged."
  - "Buffered-stream determinism in lifecycle tests: drive the store to completion first, drain the finished AsyncStream afterwards — no polling helper, no sleep."

requirements-completed: [SC1]

coverage:
  - id: D1
    description: "An abandoned continued-processing request is cancelled when its session ends, and a launch that arrives anyway is completed and turned away rather than wedging the store's single-session guard (CR-01)."
    requirement: "SC1"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift#testEndedSessionCancelsItsPendingRequestAndALaterStartIsGranted"
        status: pass
    human_judgment: false
  - id: D2
    description: "Adoption is gated on the expected identifier, so a stale launch is completed with failure and never displaces the task the store is awaiting or yields a second granted event (CR-03)."
    requirement: "SC1"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift#testAStaleLaunchIsCompletedAndNeverDisplacesTheAwaitedTask"
        status: pass
    human_judgment: false
  - id: D3
    description: "Establishing a session zeroes the seed counters, so a progress push landing after the previous session ended cannot paint the next session's card (WR-06)."
    requirement: "SC1"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift#testEndedSessionCancelsItsPendingRequestAndALaterStartIsGranted"
        status: pass
    human_judgment: false
  - id: D4
    description: "The scheduling seam is behaviorally identical to the previous direct scheduler calls: adoption still seeds progress, subtitle refreshes still preserve the title, and the installed expiration handler still performs the terminal transition."
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift#testAdoptionSeedsProgressAndExpirationStillEndsTheSession"
        status: pass
      - kind: unit
        ref: "xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -only-testing:DownloadsFeatureTests (289 tests, 56 suites)"
        status: pass
    human_judgment: false
  - id: D5
    description: "The system task scheduler stays confined to the client module and no deleted background-execution spelling reappears, despite a new source file and a new test file naming scheduler concepts."
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift#testTheSystemSchedulerIsNamedOnlyByTheClientSeam"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift#testNoDeletedBackgroundExecutionSpellingSurvivesAnywhere"
        status: pass
    human_judgment: false
  - id: D6
    description: "SC1's device half — a real queue continuing to completion after backgrounding on iOS 26 hardware — remains unobservable from unit tests."
    verification: []
    human_judgment: true
    rationale: "Background launch, card presentation and system expiration only occur on a real device; the simulator does not support background processing at all. This plan makes the store durable but cannot demonstrate the end-to-end guarantee."

# Metrics
duration: 32min
completed: 2026-07-28
status: complete
---

# Phase 15 Plan 08: Session-Lifecycle Gap Closure Summary

**A module-internal scheduling seam that makes the continued-processing store testable, plus the two lifecycle fixes it enables: an abandoned request is now cancelled at session end, and adoption is identity-checked so a stale launch is completed rather than adopted.**

## Performance

- **Duration:** 32 min
- **Started:** 2026-07-28T03:18:00Z
- **Completed:** 2026-07-28T03:50:00Z
- **Tasks:** 3
- **Files modified:** 3 (2 created, 1 modified)

## Accomplishments

- Background coverage is no longer killed by an ordinary short download. The store retains the identifier it submitted and hands the request back when a session ends without adopting a task, so the system can no longer launch an orphan into a store that has moved on and wedge its single-session re-entry guard for the rest of the process (CR-01).
- Adoption is gated on the identifier the store is actually awaiting. Every launch it turns away — a stale request's, or a launch the seam could not read as a continued-processing task — is completed with failure, closing the leaked-task / second-card / foreign-expiration path (CR-03).
- Establishing a session zeroes the seed counters, so a progress push that lands between one session's end and the next session's start cannot paint the new card with the old session's numbers (WR-06).
- `ContinuedTaskScheduling` now owns every system-scheduler verb the store uses, including the cancel-by-identifier call this phase had not previously invoked. The live value and the `SystemContinuedTask` adapter are the whole of the module's untestable surface.
- Three regression cases drive the store through injected spies with no polling and no sleeps. Both defect cases were run against the pre-fix store and fail there — 12 recorded issues including the double `granted` and the leaked 9/7 seed — so they are genuine regressions rather than assertions that happen to hold.

## Task Commits

Each task was committed atomically:

1. **Task 1: Extract the module-internal scheduler seam behind the session store** - `8a13c58e` (refactor)
2. **Task 2: Retain the identifier, cancel abandoned requests, and identity-check adoption** - `35dfae0e` (fix)
3. **Task 3: Store-level lifecycle regression suite** - `5b7ecb19` (test)

## Files Created/Modified

- `AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift` - The seam: `ContinuedProcessingTasking` (the slice of the system task the store touches), `ContinuedTaskLaunchHandler`, `ContinuedTaskScheduling` with its `live` value, and `SystemContinuedTask` forwarding to a real system task.
- `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift` - Refactored onto the seam, given a seam-injecting internal initializer, a retained `pendingIdentifier`, `handleLaunch(_:expecting:)`, `adopt(_:expecting:)` and the session-end cancel; the `BackgroundTasks` import is gone.
- `AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift` - `ContinuedTaskSpy`, `ContinuedTaskSchedulingSpy` and the three-case lifecycle suite.

## Decisions Made

- **`@MainActor` on the seam struct, not just its closures.** `ContinuedTaskScheduling.live` is a stored global; making the struct main-actor isolated is what lets that global hold non-`Sendable` main-actor closures without a global-isolation escape. It also means the seam is unreachable from anywhere the store could not have called the scheduler directly.
- **`setExpirationHandler(_:)` is a method, not a mirrored property.** The system's handler property is a plain non-isolated function type and accepts a main-actor closure only because a closure *literal* formed in a main-actor context inherits that isolation. A native property of the same shape would force an isolation-losing conversion at the assignment, and the only ways around that are the escapes this repository bans. The adapter therefore re-forms a literal inside `setExpirationHandler`, and the doc comment says why so nobody flattens it back.
- **The launch seam passes an optional task rather than swallowing a failed launch.** The live value completes a stray it cannot read as a continued-processing task, but hands the store `nil` regardless, because only the store knows whether that failed launch belongs to the session it is awaiting. A stale handler's failure must not tear down a live session.
- **`endSession` cancels only when no task was adopted.** Adoption already clears `pendingIdentifier`, so the conditional never fires for an adopted session; it is kept as written defense and documented as such.
- **The stale-build sweep stays.** Per-request cancellation and the once-per-process `cancelAllRequests()` cover different populations — a previous build's orphans, whose handlers are not in this binary, versus this process's own per-session bookkeeping. The sweep's comment now states the distinction.

## Review-finding dispositions

| Finding | Disposition |
|---------|-------------|
| CR-01 | Incorporated — Task 2 retained identifier + session-end cancel; Task 3 case 1 pins it. |
| CR-03 | Incorporated — Task 2 `adopt(_:expecting:)` gate, every rejected task completed; Task 3 case 2 pins it. |
| WR-06 | Incorporated — Task 2 start-path seed reset; Task 3 case 1 asserts the zero seed. |
| IN-02 | Deferred per plan (naming tidy, outside the SC1 lifecycle contract). |
| IN-03 | Deferred per plan (would edit the invariant suite this plan must leave unmodified). |
| IN-06 | Deferred per plan (unreachable weak-capture branch; owner's hygiene call). Task 1 preserved today's shape. |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `@escaping` restored on the seam's launch-handler parameter**
- **Found during:** Task 1 (seam extraction)
- **Issue:** The launch-handler parameter was first written without `@escaping`, on the assumption that parameters of a closure *type* are implicitly escaping. They are not — the compiler rejected the live value with "escaping closure captures non-escaping parameter 'launchHandler'".
- **Fix:** Wrote the parameter as `_ launchHandler: @escaping ContinuedTaskLaunchHandler`, which is what the plan specified in the first place.
- **Files modified:** `AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift`
- **Verification:** Build succeeds; `DownloadsFeatureTests` green.
- **Committed in:** `8a13c58e` (Task 1 commit)

**2. [Rule 3 - Blocking] Simulator destination substituted**
- **Found during:** Task 1 (first verification run)
- **Issue:** The plan's `name=iPhone 17` destination does not exist on this machine; the only installed iPhone runtimes are iPhone 17e (26.4.1) and iPhone Air (26.5 / 27.0).
- **Fix:** Ran every verification against `id=BE5CFCC0-BB8B-4B34-A664-C12B5EDACA08` (iPhone Air, iOS 27.0), the destination this repository's recent phases have used.
- **Files modified:** none
- **Verification:** All runs completed on that destination.
- **Committed in:** n/a (no source change)

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Neither changes the plan's shape. The first restores the plan's own wording; the second is an environment substitution. No scope creep.

## Issues Encountered

- One verification invocation (the pre-fix regression check) exceeded a 10-minute command budget and was terminated. The working tree was left holding the reverted store file; it was restored with `git checkout HEAD -- <file>` and the environment was confirmed healthy by re-running the full `DownloadsFeatureTests` (289 tests, 61s) before retrying. The retry completed in 68s and produced the intended failures. No orphaned build or simulator process remained.

## Verification

- Full `DownloadsFeatureTests` under the `FeatureTests` plan: **289 tests in 56 suites passed** (3 known issues, the pre-existing `withKnownIssue` cases), including `DownloadContinuedSessionTests`, `DownloadSchedulingTests`, `DownloadPendingWorkTests` and both `BackgroundExecutionInvariantTests` cases — the scheduler stayed confined to the client module and the new test file spells no banned token.
- The new suite's three cases pass in 0.006s with no polling and no sleeps.
- Pre-fix control run: the store reverted to its Task-1 (seam-only, behavior-unchanged) state fails both defect cases with 12 recorded issues — no cancellation recorded, the stray never completed, a second `granted` on the live stream, and the new session's card seeded 9/7 from the late push. The parity case passes there, as it should.
- SwiftLint over both changed directories with the repository config: zero violations. No suppression, no `@unchecked Sendable`, no `nonisolated(unsafe)`, no `@preconcurrency` anywhere in the changed set.

## Known Stubs

None.

## Threat Flags

None — no new network endpoint, auth path, file access pattern or schema change. The seam forwards caller-provided strings untouched and no gallery value is in scope in the module.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The store's end of the seam now enforces the one-session-at-a-time invariant. Plan 15-09 closes the coordinator side (CR-02 session identity, CR-04 the `cancelQueuedWorkItem` reconciliation gap), after which SC1's automatable half is complete.
- SC1's device half stays open: background launch, card presentation and system expiration are only observable on iOS 26 hardware, and the simulator does not support background processing at all.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-28*
