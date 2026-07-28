---
phase: 15-continued-background-downloads
plan: 09
subsystem: infra
tags: [background-tasks, continued-processing, swift-concurrency, actor-reentrancy, swift-testing, gap-closure]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "The continued-processing session coordinator, its reconcile/convergence design and the single-tier invariant suite (plans 15-03, 15-05, 15-06, 15-07)"
  - phase: 15-continued-background-downloads
    provides: "The store-side lifecycle fixes plan 15-08 landed — per-request cancellation of an abandoned submission, which is what makes ensure's post-suspension bail-out safe"
provides:
  - "A per-session UUID (`continuedSessionID`) minted by `ensureContinuedSession()` and threaded through event handling, teardown and reconcile"
  - "Stale-teardown immunity: a superseded session's trailing teardown is a proven no-op (CR-02)"
  - "An ownership re-check after ensure's two mid-start suspensions that completes the client session it just created rather than orphaning it (WR-01)"
  - "Identity-gated event delivery, so an expired event from a superseded stream cannot run the D-11 pause-all policy against a newer session's work"
  - "A convergent non-initial cancel branch, so cancelling the last queued update/redownload/repair item completes the session (WR-04)"
  - "Two coordinator-side regression cases pinning both defects"
affects: [15-VERIFICATION SC1 closure, any future continued-session coordinator work]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Session-identity stamping on a reentrant actor: mint an id in the same synchronous run as the liveness flag, then gate every late-arriving mutation (teardown, event delivery, post-suspension resume) on `currentID == boundID`"
    - "Convergence-point discipline: every queue mutation exits through the single forwarder that runs the reconcile tail, so completion logic never has to be duplicated per mutation site"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift

key-decisions:
  - "The liveness flag keeps its role as the cheap two-caller guard, and the session id carries identity: the flag alone cannot say which session it refers to once rollback exists, and the doc comment now says exactly that instead of claiming the flag is never rolled back."
  - "The id is minted and stored in the same synchronous run as the flag, before ensure's first suspension, so no interleaving can observe a live-but-unstamped session."
  - "A mismatched teardown returns silently rather than logging: it is the routine case, not an anomaly — the expired branch awaits an unbounded run of per-gallery pauses before its loop exits."
  - "Ensure's post-suspension bail-out calls `finish(true)` rather than dropping the client session: under 15-08's store fixes that also cancels a never-adopted pending request, so nothing is left for the system to launch into a coordinator that has moved on."
  - "WR-01's re-check ships without a deterministic regression case. Staging that interleave would require a suspension-injection seam into the coordinator that no source artifact asks for; it is pinned structurally by the acceptance grep and semantically by the rewritten doc comments."
  - "The non-initial cancel converges through `scheduleNextIfNeeded()` rather than calling `reconcileContinuedSession()` directly, so the branch behaves identically to every other queue mutation and inherits any future change to the tail."

patterns-established:
  - "Foreign-id driving as a determinism technique: when the racy interleave has no staging seam, drive its *effect* directly (a teardown carrying a UUID nobody minted) instead of trying to reproduce the race."
  - "Cases that end by draining every session they started, so no suite state leaks: the queued-cancel case restores the queue, starts a second session and pauses it to completion."

requirements-completed: [SC1]

coverage:
  - id: D1
    description: "A superseded session's trailing teardown leaves the live session untouched — it still pushes progress and still completes when the queue drains (CR-02)."
    requirement: "SC1"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift#testStaleTeardownDoesNotClearANewerSession"
        status: pass
    human_judgment: false
  - id: D2
    description: "Cancelling a queued update, redownload or repair item exits through the scheduling convergence point, so a cancel that empties the schedulable set completes the live session instead of stranding the liveness flag true (WR-04)."
    requirement: "SC1"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift#testCancellingTheLastQueuedWorkItemCompletesTheSession"
        status: pass
    human_judgment: false
  - id: D3
    description: "After a session ends, the next queue-mobilizing moment starts a fresh session rather than folding into a dead one (D-07)."
    requirement: "SC1"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift#testCancellingTheLastQueuedWorkItemCompletesTheSession"
        status: pass
    human_judgment: false
  - id: D4
    description: "An ensure that loses ownership across its own suspensions completes the client session it just started instead of installing a consuming task for a session the coordinator already tore down (WR-01)."
    requirement: "SC1"
    verification:
      - kind: static
        ref: "grep 'continuedSessionID == sessionID' AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift (4 sites: event gate, teardown gate, ensure re-check, reconcile drain re-check)"
        status: pass
    human_judgment: false
    rationale: "The interleave has no deterministic staging without a suspension-injection seam into the coordinator; the plan accepted structural pinning plus the doc comment naming the window."
  - id: D5
    description: "An event delivered on a superseded session's stream cannot trigger the D-11 pause-all policy against work a newer session covers."
    requirement: "SC1"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift (the six expiration cases still pass with the identity gate in front of the handler)"
        status: pass
    human_judgment: false
  - id: D6
    description: "No second background-execution tier reappears and the system scheduler stays confined to the client seam."
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift (both cases, unmodified)"
        status: pass
    human_judgment: false
  - id: D7
    description: "SC1's device half — a real queue continuing to completion after backgrounding on iOS 26 hardware — remains unobservable from unit tests."
    verification: []
    human_judgment: true
    rationale: "Background launch, card presentation and system expiration only occur on a real device; the simulator does not support background processing at all."

# Metrics
duration: 47min
completed: 2026-07-28
status: complete
---

# Phase 15 Plan 09: Coordinator Session-Lifecycle Gap Closure Summary

**The continued-processing session now carries a per-session identity, so no late-arriving teardown or event can act on a session that has already been replaced, and the non-initial queued cancel converges through the scheduling tail that completes a drained session.**

## Performance

- **Duration:** 47 min of execution across two agent sessions (wall clock 03:50Z to 05:18Z, including an idle gap after the provider session limit)
- **Started:** 2026-07-28T03:50:00Z
- **Completed:** 2026-07-28T05:18:00Z
- **Tasks:** 2
- **Files modified:** 4 (0 created, 4 modified)

## Accomplishments

- The coordinator can no longer be detached from its own live session. `ensureContinuedSession()` mints a UUID in the same synchronous run that raises the liveness flag, and every later mutation — the consuming task's trailing teardown, each event, the reconcile drain — must present that id to act. A superseded session's teardown, which routinely lands late because the expired branch awaits an unbounded run of per-gallery pauses before its loop exits, is now a no-op (CR-02).
- The D-11 pause-all policy is fenced to the live session. An `.expired` event surfacing from a superseded stream is dropped at the handler's identity gate, so it cannot pause downloads a newer session covers, and cannot log as current.
- `ensureContinuedSession()` no longer orphans the client session it creates. It suspends twice after raising the flag (the schedulable-progress read and the client `start`), and a reconcile from another task can drain the queue and tear the session down inside that window — its `finish` can even land before the `start` does, making the finish a no-op. Ownership is re-checked after `start` returns; on mismatch the just-started client session is completed rather than handed a consuming task (WR-01).
- Cancelling a queued update, redownload or repair item now exits through `scheduleNextIfNeeded()`, the forwarder every other queue mutation converges on and the one the reconcile completion logic is documented against. Before this, a cancel that removed the last schedulable item left the session live with nothing able to complete it, after which the system force-expires the card as stalled and D-11 pauses downloads the user never touched. It is reachable from a plain tap: `toggleDownloadPause` routes a queued update straight into that branch (WR-04).
- Two deterministic regression cases pin both defects with no polling, no sleeps and no network. The stale teardown is driven by a directly issued foreign-id call rather than a staged race; the cancel case runs on the never-self-scheduling queued fixture and ends by draining the second session it starts, so it leaves nothing live behind it.

## Task Commits

Each task was committed atomically:

1. **Task 1: Stamp the session lifecycle with a per-session identity** - `6b5efd0d` (fix)
2. **Task 2: Route the non-initial cancel through the convergence point** - `9403906d` (fix)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` - Added `continuedSessionID: UUID?` beside the three sibling session fields, and rewrote `hasLiveContinuedSession`'s doc comment: it now states that the flag is set with the id before the first suspension so two callers cannot both reach the start call, that the store carries an independent re-entry guard behind it, and — contrary to the previous claim — that the flag *is* rolled back and a concurrent caller can legitimately see it false mid-start, which is why identity exists.
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` - `ensureContinuedSession()` mints and threads the id and re-checks ownership after `start`; `handleContinuedSessionEvent(_:sessionID:)` opens with the identity gate and forwards the id to both teardown branches; `markContinuedSessionEnded(sessionID:)` guards on the id and nils it on the matching path; `reconcileContinuedSession()` binds the id in its opening guard and re-checks it after the schedulable-work await before completing. Every changed doc comment names the window it protects.
- `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` - `cancelQueuedWorkItem`'s redownload/update/repair branch ends through `await scheduleNextIfNeeded()`, with a comment recording that this cancel can remove the last schedulable item and that the `.initial` branch already converges through `pause`.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` - Added `testStaleTeardownDoesNotClearANewerSession` and `testCancellingTheLastQueuedWorkItemCompletesTheSession`, each with a doc comment naming the defect it pins. Suite now 27 cases.

## Decisions Made

- **The flag guards, the id identifies.** `hasLiveContinuedSession` stays as the cheap synchronous two-caller guard; `continuedSessionID` answers *which* session. Collapsing them into one optional would have made every existing liveness read a nil-check and churned call sites for no behavioral gain.
- **A mismatched teardown returns silently.** It is the routine case rather than an anomaly, so logging it would add noise on the normal path. The doc comment carries the explanation instead.
- **Ensure's bail-out finishes the client session it created.** Under 15-08's store fixes `finish(true)` also cancels a never-adopted pending request, so the abandoned start leaves nothing behind for the system to launch into a coordinator that has moved on.
- **WR-01's re-check ships structurally pinned, not test-pinned.** Reproducing "a reconcile drains and completes S1 while ensure is suspended inside `start`" needs a suspension-injection seam in the coordinator that no source artifact asks for. The plan accepted the acceptance grep plus the doc comment as the pin; that judgment is recorded here so a later reader does not mistake the gap for an oversight.
- **The cancel branch converges through the forwarder, not through a direct reconcile call.** Calling `reconcileContinuedSession()` inline would have worked today and drifted tomorrow; routing through `scheduleNextIfNeeded()` makes the branch inherit whatever the tail becomes.

## Review-finding dispositions

| Finding | Disposition |
|---------|-------------|
| CR-02 | Incorporated — Task 1 per-session UUID gating teardown and event delivery; `testStaleTeardownDoesNotClearANewerSession` pins it. |
| WR-01 | Incorporated (folded) — Task 1 honest liveness-flag doc comment plus the post-suspension ownership re-check; structurally pinned. |
| WR-04 | Incorporated — Task 2 convergent cancel branch; `testCancellingTheLastQueuedWorkItemCompletesTheSession` pins it. |
| WR-02 | Deferred per plan (unifying `hasPendingWork()` onto `schedulableDownloads()` changes the scheduling-predicate surface). |
| WR-03 | Deferred per plan (per-pause reschedule churn needs a gate inside `scheduleNextIfNeededCore`). |
| WR-05 | Owner-pending per plan prohibition — the dead dependency key and its accessor were not touched either way. |
| WR-07 | Deferred per plan (fixture-owned teardown would restructure five existing cases). Both new cases follow the suite's trailing-pause convention so the fix lands uniformly later. |
| IN-01, IN-04, IN-05 | Deferred per plan. |

## Deviations from Plan

### Process deviation

**1. Plan execution was interrupted by a provider session limit and resumed by a continuation agent**
- **Found during:** Task 2, after the source edit and before the regression case
- **Issue:** The first executor agent completed and committed Task 1 (`6b5efd0d`), then applied Task 2's source edit to `DownloadClient+Scheduling.swift` and was terminated mid-task by a provider session limit. This was an infrastructure interruption, not a code failure.
- **Fix:** A continuation agent re-verified Task 1's acceptance criteria against the tree, reviewed and kept the uncommitted Task 2 source edit (it matched the plan's `<action>` text verbatim in intent and comment content), then wrote the missing regression case, ran both verification tiers and committed Task 2 atomically.
- **Files modified:** none beyond the plan's own set
- **Verification:** Task 1's five acceptance greps re-checked (3, 5, 2, 4, and the test name present); Task 2's grep outputs `1`; both test tiers green.

### Auto-fixed Issues

**2. [Rule 3 - Blocking] Simulator destination substituted**
- **Found during:** Task 2 verification
- **Issue:** The plan's `name=iPhone 17` destination does not exist on this machine; installed iPhone runtimes are iPhone 17e and iPhone Air.
- **Fix:** Ran every verification against `id=BE5CFCC0-BB8B-4B34-A664-C12B5EDACA08` (iPhone Air, iOS 27.0), the destination plan 15-08 and this repository's recent phases used.
- **Files modified:** none
- **Verification:** Both runs completed on that destination and succeeded.

---

**Total deviations:** 1 process interruption, 1 auto-fixed (blocking)
**Impact on plan:** None on shape or scope. The interruption cost wall-clock time only — no task was redone, no commit was rewritten, and the resumed work matched the plan's task text. The destination substitution is an environment fact.

## Issues Encountered

- None beyond the session-limit interruption recorded above. No orphaned build or simulator process remained; the continuation agent's first test invocation started cleanly.

## Verification

- Targeted run — `DownloadsFeatureTests/DownloadContinuedSessionTests` under the `FeatureTests` plan: **27 tests passed** in 0.68s (3 known issues, the pre-existing `withKnownIssue` unimplemented-endpoint cases), including both new cases and every pre-existing case.
- Full run, executed only after the targeted run completed — `-only-testing:DownloadsFeatureTests`: **291 tests in 56 suites passed** in 12.9s wall (54s including build), including `DownloadSchedulingTests` (deterministic since 557b0425, so green there is meaningful), `DownloadPendingWorkTests`, and both `BackgroundExecutionInvariantTests` cases unmodified.
- Acceptance greps: `continuedSessionID` in Manager = 3; `markContinuedSessionEnded(sessionID:` = 5; `sessionID: UUID` = 2; `continuedSessionID == sessionID` = 4; the `cancelQueuedWorkItem` region contains exactly one `scheduleNextIfNeeded`.
- App-scheme build: **BUILD SUCCEEDED** with zero warnings and zero errors.
- SwiftLint over `AppPackage/Sources/DownloadClient` and `AppPackage/Tests/DownloadsFeatureTests` with the repository config in `--strict` mode: **0 violations in 93 files**. No suppression, no `swiftlint:disable`, no `@unchecked Sendable`, no `nonisolated(unsafe)`, no `@preconcurrency` anywhere in the changed set.
- The test file is 994 lines against the repository's 1000-line `file_length` error threshold — under the limit but with six lines of headroom. Flagged for the owner: the next case added to this suite will trip the rule, and WR-07's deferred fixture-owned teardown is the natural moment to split it.

## Known Stubs

None.

## Threat Flags

None — no new network endpoint, auth path, file access pattern or schema change. The session id is process-local bookkeeping and never reaches the system card, whose counts-only subtitle surface is unchanged.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Both coordinator-side gap artifacts from 15-VERIFICATION.md are closed. With plan 15-08's store-side half, SC1's automatable coverage is complete: the one-session design now holds against actor reentrancy on both sides of the client seam.
- SC1's device half stays open and is human-judgment only: background launch, card presentation and system expiration are observable only on iOS 26 hardware, and the simulator does not support background processing at all.
- Three review findings remain owner-pending or deferred by contract (WR-02, WR-03, WR-05, plus WR-07's test hygiene and the IN-series tidies). None blocks the phase; all are recorded in the disposition table above and in 15-08's.

## Self-Check: PASSED

All four modified artifacts exist on disk, both new test names are present in the suite, and both task commits (`6b5efd0d`, `9403906d`) are in git history.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-28*
</content>
</invoke>
