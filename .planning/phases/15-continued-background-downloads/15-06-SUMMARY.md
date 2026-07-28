---
phase: 15-continued-background-downloads
plan: 06
subsystem: infra
tags: [backgroundtasks, download-queue, progress-reporting, privacy, testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "Plan 15-05's coordinator session lifecycle — `reconcileContinuedSession()` and `pushContinuedSessionProgress()` were written there with no callers, waiting for this plan's wiring, plus the drivable spy and the blocking fixture"
provides:
  - "Two reconcile hooks: the scheduling tail and the execution collision-cleanup branch, so a session is completed exactly once when its work actually runs out"
  - "One progress push, riding the existing throttled manifest flush, so the card's counts advance on the page cadence rather than only on queue mutations"
  - "SC1/SC2/SC3 automated coverage: completion, progress arithmetic, monotonicity, both zero-denominator inputs, neutral strings, expiration parity against a pause baseline, and the unavailable path"
affects: [15-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A behavior whose expected state is another code path's output is asserted against that path's actual output (a per-gallery pause baseline), never against a status literal"
    - "An async settle point is the task that does the work, awaited directly, rather than a polled predicate — the polling helper is reserved for the one path whose task cannot be captured before it starts"
    - "Card bar and card text are derived from one clamped value, so two views of the same fact can never disagree"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift

key-decisions:
  - "The pushed subtitle is built from the same clamped counts the progress bar receives, not from the raw snapshot. The two are two renderings of one fact and a reader sees both at once; under the monotonic clamp's queue-shrink case they would otherwise have shown a full bar beside a `0 / 4 pages` caption."
  - "The zero-page gallery is patched into the index rather than scanned from disk, because `DownloadStore` rejects a page-less manifest on read. That patch call is the same one a flush uses to refresh a record without rescanning, so it is the only route by which the arithmetic could ever meet a zero denominator."
  - "Expiration cases settle by awaiting the coordinator's own consuming task, captured before the expiration is fired. The pause-all runs inside that task, so the await is exact where a polled predicate would only be probable."
  - "The unavailable path is exercised through a purpose-built client value rather than an extension of the spy: nothing about it needs recording, and the case's whole claim is that it is indistinguishable from the inert client."

patterns-established:
  - "A queue fixture built from queued galleries with no task runner installed, so an arithmetic case's only variable is the queue's shape and no download can move the counts underneath an assertion"
  - "Two identical fixtures driven down two different paths and compared whole (`GalleryStateSnapshot`), so a divergence anywhere fails rather than only where an assertion happened to look"

requirements-completed: [SC1, SC2, SC3]

coverage:
  - id: D1
    description: "A live session is completed exactly once, with success, when the queue actually drains — from the scheduling tail every queue mutation converges on"
    requirement: SC1
    verification:
      - kind: unit
        ref: "DownloadContinuedSessionTests#testDrainingTheQueueCompletesTheSessionWithSuccess — pausing the only download drains the queue; finishCount == 1, finishSuccesses == [true], liveness probe false"
        status: pass
      - kind: unit
        ref: "DownloadContinuedSessionTests#testSchedulingPassesAfterTheDrainAddNoSecondCompletion — two further scheduling passes leave finishCount at 1"
        status: pass
      - kind: other
        ref: "grep -c 'reconcileContinuedSession' on DownloadClient+Scheduling.swift => 1 and on DownloadClient+Execution.swift => 1"
        status: pass
    human_judgment: false
  - id: D2
    description: "A scheduling pass taken while work is still pending completes nothing"
    requirement: SC1
    verification:
      - kind: unit
        ref: "DownloadContinuedSessionTests#testSchedulingPassWithWorkStillPendingCompletesNothing — finishCount 0, finishSuccesses empty, session still live"
        status: pass
    human_judgment: false
  - id: D3
    description: "The session is never completed on a foreground return (D-08) — no scene-phase path touches it"
    requirement: SC1
    verification:
      - kind: other
        ref: "grep -rn 'reconcileContinuedSession\\|ensureContinuedSession' AppPackage/Sources/AppFeature | wc -l => 0"
        status: pass
    human_judgment: false
  - id: D4
    description: "Card progress is completed pages over total pages across every schedulable gallery, both read from one snapshot (D-10)"
    requirement: SC2
    verification:
      - kind: unit
        ref: "DownloadContinuedSessionTests#testPushedCountsSumEverySchedulableGallery — 3+2 of 10+6 pushed as 5 / 16 with a matching subtitle"
        status: pass
      - kind: unit
        ref: "DownloadContinuedSessionTests#testTotalGrowsWhenAGalleryJoinsTheQueueMidSession — totals [4, 13], gallery count 1 then 2"
        status: pass
    human_judgment: false
  - id: D5
    description: "The pushed completed count never regresses within a session, and the total is held at or above it"
    requirement: SC2
    verification:
      - kind: unit
        ref: "DownloadContinuedSessionTests#testPushedCompletedCountNeverDecreasesWithinASession — the gallery holding all completed pages leaves; counts stay [6, 6] while the total drops 14 -> 6"
        status: pass
    human_judgment: false
  - id: D6
    description: "Neither zero-denominator input produces a zero or negative total, or a division by zero (T-15-04)"
    requirement: SC2
    verification:
      - kind: unit
        ref: "DownloadContinuedSessionTests#testZeroPageGalleryStillPushesAPositiveTotal — total >= 1, completed within [0, total]"
        status: pass
      - kind: unit
        ref: "DownloadContinuedSessionTests#testEmptySchedulableSetStillPushesAPositiveTotal — an empty sum cannot rewind the card below what it already pushed"
        status: pass
    human_judgment: false
  - id: D7
    description: "Progress is pushed from the throttled page-flush cadence, so a session cannot look stalled between gallery completions (T-15-11, Pitfall 3)"
    requirement: SC2
    verification:
      - kind: unit
        ref: "DownloadContinuedSessionTests#testProgressIsPushedOnTheThrottledPageFlushCadence — frozen clock and seeded flush date make the elapsed-time branch dead; updates land at [8, 16, 20] of 20"
        status: pass
      - kind: other
        ref: "grep -c 'pushContinuedSessionProgress' on DownloadClient+Persistence.swift => 1 and on DownloadClient+PageDownload.swift => 0"
        status: pass
    human_judgment: false
  - id: D8
    description: "Every pushed subtitle carries counts only — no gallery title and no identifier (D-09, T-15-01)"
    requirement: SC2
    verification:
      - kind: unit
        ref: "DownloadContinuedSessionTests#testEveryPushedSubtitleCarriesNoGalleryIdentity — exact equality on the recorded strings plus absence of both fixture titles and both gids"
        status: pass
    human_judgment: false
  - id: D9
    description: "An expiration leaves the queue in exactly the state a per-gallery in-app pause produces (D-11, SC2, T-15-10)"
    requirement: SC2
    verification:
      - kind: unit
        ref: "DownloadContinuedSessionTests#testExpirationLeavesTheQueueInThePerGalleryPauseBaselineState — the expected state is computed by pausing each gallery of an identical fixture, then compared whole"
        status: pass
      - kind: unit
        ref: "DownloadContinuedSessionTests#testExpirationLeavesTheSchedulingBlockedSetAsAPauseDoes — blocked set equals the baseline's, liveness probe false"
        status: pass
      - kind: unit
        ref: "DownloadContinuedSessionTests#testExpirationResultIsIndependentOfEnqueueOrder — forward and reversed enqueue orders yield identical snapshots and blocked sets"
        status: pass
    human_judgment: false
  - id: D10
    description: "An ended session receives no further progress update and no completion, and its consuming task ends without external cancellation"
    requirement: SC2
    verification:
      - kind: unit
        ref: "DownloadContinuedSessionTests#testEndedSessionReceivesNoFurtherUpdateOrCompletion — a scheduling pass and a direct push after expiration add nothing; finishCount stays 0"
        status: pass
      - kind: unit
        ref: "DownloadContinuedSessionTests#testConsumingTaskEndsOnItsOwnAfterExpiration — the captured task completes, isCancelled false, coordinator holds no session task"
        status: pass
    human_judgment: false
  - id: D11
    description: "An unavailable session is indistinguishable from having no session client: same queue state gallery for gallery, no error surfaced, no page lost or duplicated (SC3 as amended)"
    requirement: SC3
    verification:
      - kind: unit
        ref: "DownloadContinuedSessionTests#testUnavailableSessionLeavesQueueStateEqualToTheInertClient — twelve page flushes run twice, snapshots compared whole and equal"
        status: pass
      - kind: unit
        ref: "DownloadContinuedSessionTests#testUnavailableSessionSurfacesNothingAndLeavesNoLiveSession — the mobilizing tap still returns success, no download error recorded, no live session"
        status: pass
    human_judgment: false
  - id: D12
    description: "Existing queue and scheduling behavior is unchanged by the two reconcile hooks and the flush push"
    verification:
      - kind: unit
        ref: "Full FeatureTests plan => ** TEST SUCCEEDED **; DownloadsFeatureTests at 284 tests in 54 suites (267 baseline + 17 new), including DownloadSchedulingTests, DownloadPauseAndReconcileTests and DownloadObserverBatchTests"
        status: pass
      - kind: other
        ref: "xcodebuild clean build -scheme EhPanda => ** BUILD SUCCEEDED ** with zero warning:/error: lines, so the SwiftLint build-tool plugin reported no violations"
        status: pass
    human_judgment: false
  - id: D13
    description: "The system card shows real progress on a device and its cancel affordance stops the queue"
    verification: []
    human_judgment: true
    rationale: "The Simulator does not support continued background processing, so the framework half of SC1/SC2 is device-only by construction. Everything asserted here is coordinator behavior against the spy; the owner's device observation script in 15-VALIDATION.md covers the rest."

# Metrics
duration: 22min
completed: 2026-07-28
status: complete
---

# Phase 15 Plan 06: Session Progress & Completion Wiring Summary

**The continued-processing session is now wired into the queue's two convergence points and into the throttled page flush, so its card advances on the page cadence, completes exactly once when the work really runs out, and its expiration is proven equal to pausing every gallery by hand.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-07-28T10:04:00Z
- **Completed:** 2026-07-28T10:26:00Z
- **Tasks:** 3
- **Files modified:** 5 (0 created)

## Accomplishments

- `scheduleNextIfNeeded()` reconciles the session at its tail again, which is where the deleted background assertion used to be reconciled. The forwarder shape it was left in by plan 15-02 exists precisely so the tail sees every exit path of the core routine — both its early-return guards and its happy path — and the restored comment now says so, including why the pause and delete paths still arrive here even though they null the active task directly.
- `finishActiveTaskIfOwned` reconciles from its collision-cleanup branch too. That branch returns without rescheduling because another owner is already driving the queue, so it is the one exit from a finished download that would otherwise never reach the session — and the download it just finished may have been the last in flight.
- Nothing was added to any scene-phase or foreground-return path, and a grep over `AppPackage/Sources/AppFeature` proves it. D-08 is load-bearing rather than stylistic: re-submission needs a fresh user tap, so completing on `.active` would silently drop background coverage for the rest of the queue and there would be no way to get it back until the user tapped something. The card staying visible while the app is open is the accepted cost.
- `flushDownloadProgress` pushes session progress immediately after its observer notification, inside the branch that actually flushed. Its doc comment records the three reasons this site beats the page-loop call site — one throttle governing both the manifest write and the card, forced flushes covered as well as cadence flushes, and session state already reachable on the coordinator — and, more importantly, why the push exists at all: the scheduler forcibly expires tasks that look stalled and terminates the least-progressing first, so a completed count that only moved when a gallery finished would look stalled for the whole of a long gallery.
- The session suite grew from 8 cases to 25. Three cover completion, seven cover the progress arithmetic and its strings, five cover expiration, two cover unavailability; the eight it started with are unchanged.
- The expiration cases compute their expected state by running an identical fixture and pausing each gallery through `pause(gid:)`, then comparing the two results whole. That is what makes SC2's phrase "consistent with an in-app cancel" a checked claim rather than a paraphrase: a hard-coded `.inactive` would still pass if pause itself changed underneath it.
- The unavailability cases run twelve page flushes twice — once against a client that refuses immediately, once against the inert one — and compare the resulting queue state gallery for gallery: same display statuses, same (absent) errors, same manifest page counts. That is "no page lost or duplicated" as an assertion rather than an assurance.
- No case sleeps and none polls except one. Expiration settles by awaiting the coordinator's own consuming task, captured before the expiration is fired, because the pause-all runs inside that task. Only the unavailable path uses the shared `waitUntil` helper, because its event is delivered during `start` and the task can already be finished by the time a case could capture it.

## Task Commits

Each task was committed atomically:

1. **Task 1: Reconcile the session at the queue convergence points** - `3f7a4eef` (feat)
2. **Task 2: Push progress on the page-flush cadence and assert the numbers** - `713ba7d0` (feat)
3. **Task 3: Cover the expiration policy and the unavailable path** - `0a0baf15` (test)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` (modified) - Reconcile call at the scheduling tail, plus the restored invariant comment.
- `AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift` (modified) - Reconcile in `finishActiveTaskIfOwned`'s collision-cleanup branch.
- `AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift` (modified) - The progress push at the tail of the throttled flush, and the doc comment explaining the site and the liveness requirement behind it.
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` (modified) - The pushed subtitle is now built from the same clamped counts the bar gets (see Deviations).
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` (modified, 214 -> 925 lines) - Seventeen new cases, the queued-coordinator fixture, the comparable queue snapshot, the expiration settle helper, the page-flush scenario runner, and an `unavailable` client value.

## Decisions Made

- **The pushed subtitle is built from the clamped counts, not the raw snapshot.** See Deviations — this is the one production change beyond the two hooks and the push.
- **The zero-page gallery is patched into the index rather than written to disk.** `DownloadStore.validateDecodedManifest` rejects a page-less manifest on read, so a scan can never surface one; the first draft of that case failed for exactly that reason. The case now calls `updateDownloadIndex(folderURL:manifest:)` — the same call a flush uses to refresh a record without rescanning — which is the only route by which this arithmetic could ever meet a zero denominator. A second case covers the reachable zero-denominator input, an empty schedulable set, so the clamp is proven on both.
- **Expiration settles on the consuming task, not on a polled predicate.** The task is captured before `expire()` is fired, because the handler nils it on the way through. The pause-all runs inside that task, so awaiting it is exact; `waitForTaskValue` bounds it at ten seconds so a regression that never finishes fails rather than hangs. The plan asked for the shared condition helper instead of sleeps, and this satisfies that intent more strictly — the one path where the task cannot be captured in time, the unavailable one, does use `waitUntil`.
- **The unavailable path uses a purpose-built client value rather than a new spy capability.** The case's whole claim is that nothing is recorded and nothing is surfaced, so a recorder would have had nothing to record; and adding an "answer unavailable" mode to the spy would have put a second event-delivery path into a double that already has one.
- **Both test fixtures now take a `BackgroundProcessingClient` rather than a spy.** The unavailable cases need a client the spy cannot produce, and every existing call site reads `client: spy.client`, which is if anything more explicit about what the fixture is being given.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The pushed subtitle disagreed with the pushed counts under a queue shrink**

- **Found during:** Task 2 (writing the monotonicity case)
- **Issue:** `pushContinuedSessionProgress()` pushed clamped counts (plan 15-05's monotonic completed count, and a total held at or above it) but built the subtitle from the *raw* snapshot. In the exact case the clamp exists for — a mostly-finished gallery leaving the queue — the card would have rendered a full progress bar beside the caption `0 / 4 pages`. Both are drawn on the same card, at the same time, from what is supposed to be one fact.
- **Fix:** The clamped pair is materialised as a `ContinuedSessionProgress` and used for both the counts and the subtitle, with an inline comment saying why. Nothing else changed: one snapshot in, the same monotonic rule, the same total floor.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift`
- **Verification:** `testPushedCompletedCountNeverDecreasesWithinASession` asserts the shrink pushes `6 / 6 pages · 1 gallery` alongside counts of 6 and 6; `testEmptySchedulableSetStillPushesAPositiveTotal` asserts the same agreement for an empty sum.
- **Committed in:** `713ba7d0` (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** The fix is a two-line widening inside the method the plan already required this task to call, and it strengthens the plan's own must-have that both numbers come from one snapshot. No scope creep; the plan's three tasks landed as written otherwise.

## Issues Encountered

- The first draft of the zero-page case asserted against a gallery seeded on disk and failed with no progress update recorded at all. Root cause was not the clamp but `DownloadStore.validateDecodedManifest`, which throws on a page-less manifest, so the gallery never entered the index and `hasPendingWork()` was false. Resolved by reaching the state through the index-patch call instead, and by adding a second case for the reachable empty-set input. Both are documented in the cases themselves so the next reader does not repeat the attempt.

## Acceptance-Criteria Notes

- Task 1 asked for "at least three completion cases"; three landed. Task 2 asked for "at least five progress cases"; seven landed, the two extra being the split of the zero-denominator input described above. Task 3 asked for "at least seven cases covering expiration and unavailability"; seven landed.
- `grep -c 'sleep(' DownloadContinuedSessionTests.swift` -> `0`. The suite's waits go through `waitForTaskValue` (a bounded await on the real task) and `waitUntil` (the shared condition helper); neither introduces a fixed delay.

## Environment Notes

- Every `<automated>` verify block in the plan pins `-destination 'platform=iOS Simulator,name=iPhone 17'`, which does not resolve on this machine. All commands were run with `-destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` (iPhone Air, iOS 26.5); the id pin is required because `name=iPhone Air` is ambiguous here. Only the destination changed — project, scheme, test plan and `-only-testing` flags are as the plan specifies. This is a local environment fact, not a plan deviation.
- The Simulator does not support continued background processing, so nothing here exercises the framework end to end. Everything asserted is coordinator behavior against a client double.
- The three `withKnownIssue` results the runs report are plan 15-04's seeded contract expectations against the unimplemented test value, not failures.

## Verification Evidence

- `grep -c 'reconcileContinuedSession' AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` -> `1`.
- `grep -c 'reconcileContinuedSession' AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift` -> `1`.
- `grep -rn 'reconcileContinuedSession\|ensureContinuedSession' AppPackage/Sources/AppFeature | wc -l` -> `0`.
- `grep -c 'pushContinuedSessionProgress' AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift` -> `1`.
- `grep -c 'pushContinuedSessionProgress' AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift` -> `0`.
- `grep -c 'sleep(' AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` -> `0`.
- `grep -rn 'swiftlint:disable' AppPackage/Sources/DownloadClient | wc -l` -> `0`.
- `awk 'length > 120'` over every file this plan modified -> no output.
- `grep -c '    @Test' AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` -> `25` (8 from plans 15-04/15-05, 17 added here).
- Task 1 run (`-only-testing:DownloadsFeatureTests`) -> `Test run with 270 tests in 54 suites passed`, `** TEST SUCCEEDED **`.
- Task 2 targeted run (`-only-testing:DownloadsFeatureTests/DownloadContinuedSessionTests`) -> `Test run with 18 tests in 1 suite passed ... with 3 known issues`; full target -> `Test run with 277 tests in 54 suites passed`.
- Task 3 full target -> `Test run with 284 tests in 54 suites passed ... with 3 known issues`, `** TEST SUCCEEDED **`, including `DownloadSchedulingTests`, `DownloadPauseAndReconcileTests` and `DownloadObserverBatchTests`.
- Full `FeatureTests` plan (all 22 targets) -> `** TEST SUCCEEDED ** [65.640 sec]`, no `✘` lines.
- `xcodebuild clean build -project EhPanda.xcodeproj -scheme EhPanda` -> `** BUILD SUCCEEDED **`, zero `warning:`/`error:` lines.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Every seam behavior this phase can prove in the Simulator is now proven. What remains for plan 15-07 and for verification is the framework half: the owner's device observation script in `15-VALIDATION.md`, which is device-only because the Simulator reports `.unavailable` by design.
- The `GalleryStateSnapshot` comparison and the two-fixture baseline shape are reusable for any later case that has to claim two paths leave the queue in the same state.
- No deferred items. Both of plan 15-05's caller-less methods now have callers, and neither has a second one.

## Self-Check: PASSED

All five modified files exist on disk with the expected contents, and all three task commits (`3f7a4eef`, `713ba7d0`, `0a0baf15`) are present in `git log`.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-28*
</content>
</invoke>
