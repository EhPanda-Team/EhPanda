---
phase: 15-continued-background-downloads
plan: 02
subsystem: infra
tags: [backgroundtasks, uikit, download-queue, swift-testing, deletion]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "Plan 15-01 removed both AppFeature consumers of the discretionary tier, so this plan's repository-wide deletion gates could be honest rather than narrowed"
provides:
  - "A DownloadCoordinator with no OS execution assertion, no assertion token state, and no injected background client"
  - "The schedulable-work predicate hasPendingWork() surviving in DownloadClient+PendingWork.swift, decoupled from any background mechanism"
  - "A single queue pump: the detached finishActiveTaskIfOwned -> scheduleNextIfNeeded reschedule chain"
  - "A file-scope blocking-coordinator fixture and async-condition helper reachable from any suite in DownloadsFeatureTests"
affects: [15-03, 15-04, 15-06, 15-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Shared test fixtures that suites without protocol conformance must reach live at file scope, not as protocol members"
    - "scheduleNextIfNeeded stays a forwarder over its core so the tail remains the single convergence point a reconcile can hang off"

key-files:
  created:
    - AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
    - AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift
    - App/Info.plist

key-decisions:
  - "The relocated fixture reaches the shared sampleManifest factory through a private empty DownloadFeatureTestCase conformer, because a file-scope function has no receiver for a protocol-extension default."
  - "The fixture's doc comment was repointed off the assertion in Task 1 rather than Task 2: dropping the spy already made the old trailing clause false at that commit."
  - "scheduleNextIfNeeded stays a forwarder with a comment recording why the tail is the convergence point, so plan 15-06 does not have to rediscover the reason."
  - "The Info.plist keep-rationale comment was reworded off the deleted tier's class name, which plan 15-01 had introduced and both this plan's and 15-03's zero-gates require gone."

patterns-established:
  - "A deletion plan takes its own gates literally: a surviving mention in a comment is fixed at the introducing gate, not deferred as 'only a comment'"

requirements-completed: [SC3]

coverage:
  - id: D1
    description: "No OS execution assertion exists anywhere in the tree: the client, its token type, the coordinator's stored dependency and both assertion state fields are gone"
    requirement: SC3
    verification:
      - kind: other
        ref: "grep -rn 'BackgroundTaskClient\\|backgroundTaskClient' App AppPackage ShareExtension | wc -l => 0"
        status: pass
      - kind: other
        ref: "grep -rn 'reconcileBackgroundAssertion\\|backgroundAssertionToken\\|isBeginningBackgroundAssertion\\|testingHasBackgroundAssertion' AppPackage | wc -l => 0"
        status: pass
      - kind: other
        ref: "grep -rn 'downloads[.]assertion\\|beginBackgroundTask' App AppPackage ShareExtension | wc -l => 0"
        status: pass
      - kind: other
        ref: "xcodebuild build -scheme EhPanda clean build => BUILD SUCCEEDED, zero warning:/error: lines (SwiftLint build-tool plugin clean)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The schedulable-work predicate survives in a file named for what it is, and still reports empty-queue false / queued-indexed-download true"
    requirement: SC3
    verification:
      - kind: other
        ref: "test -f DownloadClient+PendingWork.swift && test ! -f DownloadClient+BackgroundAssertion.swift => 0; grep -c 'func hasPendingWork' DownloadClient+PendingWork.swift => 1"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift#testHasPendingWorkReflectsQueueState"
        status: pass
    human_judgment: false
  - id: D3
    description: "The external drain loop and both orphaned facade endpoints are gone; the detached reschedule chain is the sole queue pump"
    requirement: SC3
    verification:
      - kind: other
        ref: "grep -rn 'runQueueUntilIdle\\|runBackgroundProcessing' App AppPackage ShareExtension | wc -l => 0; grep -c 'hasPendingWork' DownloadClient.swift => 0"
        status: pass
      - kind: unit
        ref: "xcodebuild test -scheme EhPanda -testPlan FeatureTests (full plan, all suites) => TEST SUCCEEDED"
        status: pass
    human_judgment: false
  - id: D4
    description: "The blocking-coordinator fixture and the async-condition helper survived their host suite's deletion and are reachable without protocol conformance"
    requirement: SC3
    verification:
      - kind: other
        ref: "grep -n '^struct BlockingCoordinatorContext\\|^func makeBlockingCoordinator\\|^func waitUntil' DownloadFeatureTestHelpers.swift => 3 file-scope declarations"
        status: pass
      - kind: unit
        ref: "xcodebuild test -only-testing:DownloadsFeatureTests => Test run with 259 tests in 53 suites passed"
        status: pass
    human_judgment: false
  - id: D5
    description: "Queue behavior after the deletion is unchanged in the foreground: scheduling, pause/reconcile and the reschedule chain all behave as before"
    requirement: SC3
    verification:
      - kind: unit
        ref: "DownloadSchedulingTests + DownloadPauseAndReconcileTests (inside the 259-test DownloadsFeatureTests run) => passed"
        status: pass
    human_judgment: false
  - id: D6
    description: "Backgrounded downloads suspend with the process between this plan and 15-06, losing and duplicating no work"
    verification: []
    human_judgment: true
    rationale: "T-15-08's accepted consequence is a device-observable process-lifecycle behavior; the Simulator does not support background processing, so no automated test can assert it. It is also intentionally transient — plan 15-06 restores background execution."

# Metrics
duration: 14min
completed: 2026-07-28
status: complete
---

# Phase 15 Plan 02: Delete the Assertion Tier and the Drain Loop Summary

**`DownloadCoordinator` now holds no OS execution assertion and no external drain loop: the queue's only lifecycle is its own in-process scheduling, with the schedulable-work predicate surviving as a mechanism-free `hasPendingWork()`.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-07-27T23:59:54Z
- **Completed:** 2026-07-28T00:14:31Z
- **Tasks:** 3
- **Files modified:** 16 (2 created, 5 deleted, 9 modified)

## Accomplishments

- `BackgroundTaskClient.swift` is gone outright: the client struct, the `BackgroundTaskToken` typealias, its `live`/`noop`/`unimplemented` values, the generic `placeholder()` helper, and the `app.ehpanda.downloads.assertion` name it handed UIKit. Nothing in `App`, `AppPackage` or `ShareExtension` names the type or `beginBackgroundTask` any more.
- `DownloadClient+BackgroundAssertion.swift` became `DownloadClient+PendingWork.swift`, holding only `hasPendingWork()`. `reconcileBackgroundAssertion()` and `endBackgroundAssertion()` are deleted, and the predicate's doc comment no longer names a mechanism — it now says only that it is the queue's schedulable-work predicate and must agree with the scheduler.
- The coordinator lost its `backgroundTaskClient` stored dependency, its init parameter and assignment, and both `backgroundAssertionToken` / `isBeginningBackgroundAssertion` state fields together with the comment explaining their two-state guard. Every other stored dependency, including the injectable `now` clock, is untouched.
- `scheduleNextIfNeeded()` is now a forwarder to `scheduleNextIfNeededCore()`, carrying a comment that records *why* the tail is the single convergence point every queue mutation reaches — so plan 15-06 can re-hang a session reconcile there without rediscovering the reason. `finishActiveTaskIfOwned`'s collision-cleanup branch collapsed back to the plain `guard schedulesNext else { return }`.
- `DownloadClient+BackgroundProcessing.swift` and `runQueueUntilIdle()` are deleted, along with the `hasPendingWork` and `runBackgroundProcessing` façade endpoints, their live-wiring entries and their `noop` members. Under a continued-processing task the process is already running, so the existing detached reschedule chain (`finishActiveTaskIfOwned` into `scheduleNextIfNeeded`) keeps the queue moving; a second pump would race it, which is why the loop is deleted rather than repurposed.
- `BlockingCoordinatorContext`, `makeBlockingCoordinator(gid:title:)` and `waitUntil(timeout:_:)` moved into `DownloadFeatureTestHelpers.swift` as file-scope declarations, so the session suites later plans add can reach them regardless of `DownloadFeatureTestCase` conformance (the same reason `removeTemporaryItem` and `sleepIgnoringCancellation` are free functions).
- `DownloadBackgroundAssertionTests.swift` (six assertion-lifecycle cases plus the mutex-backed spy) is deleted, and `DownloadBackgroundProcessingTests.swift` became `DownloadPendingWorkTests.swift` reduced to the single queue-state case, with its suite-local `waitUntil` dropped in favour of the shared free function.

## Task Commits

Each task was committed atomically:

1. **Task 1: Relocate the blocking-coordinator fixture and retire its host suite** - `3679b2a2` (test)
2. **Task 2: Delete the execution-assertion client and its coordinator state** - `bef95c85` (refactor)
3. **Task 3: Delete the drain loop and its façade endpoints** - `b53f551f` (refactor)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift` (created, renamed from `+BackgroundAssertion.swift`) - Holds only `hasPendingWork()`, the queue's schedulable-work predicate.
- `AppPackage/Sources/DownloadClient/BackgroundTaskClient.swift` (deleted) - The UIKit execution-assertion client.
- `AppPackage/Sources/DownloadClient/DownloadClient+BackgroundProcessing.swift` (deleted) - The external `runQueueUntilIdle()` drain loop.
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` - Stored dependency, init parameter/assignment and both assertion state fields removed.
- `AppPackage/Sources/DownloadClient/DownloadClient.swift` - `backgroundTaskClient: .live` argument removed; two façade endpoints removed from the struct, the live factory and `noop`.
- `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` - Reconcile tail removed; forwarder shape kept with a convergence-point comment.
- `AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift` - Collision-cleanup reconcile call and its comment removed.
- `AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift` - `testingHasBackgroundAssertion()` removed.
- `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift` - The one doc sentence contrasting this client with the deleted one removed; nothing else touched.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` - Gained the file-scope fixture struct, builder and async-condition helper, plus the private factory-conformer that gives them a receiver.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadBackgroundAssertionTests.swift` (deleted) - Six assertion-lifecycle cases and the assertion-client spy.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift` (created, renamed from `DownloadBackgroundProcessingTests.swift`) - The surviving queue-state case and its manifest helper.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift` - Orphaned `hasPendingWork` façade override removed.
- `App/Info.plist` - Keep-rationale comment reworded off the deleted tier's class name.

## Decisions Made

- **A private empty conformer gives the relocated fixture a receiver.** `makeBlockingCoordinator` calls `sampleManifest(gid:title:)`, a `DownloadFeatureTestCase` protocol-extension default, and a file-scope function has no `self` to call it on. `DownloadFeatureTestCase` declares no requirement without a default implementation, so a private empty `struct SharedDownloadTestFactories: DownloadFeatureTestCase {}` is a complete witness and the fixture's body stays otherwise verbatim. The alternative — duplicating the manifest factory into the fixture — would have stranded a second copy of shared test data.
- **The fixture's doc comment was repointed in Task 1, not carried verbatim.** The plan asked for the comment unchanged, but its trailing clause said the fixture existed so "the assertion lifecycle can be observed"; dropping the spy field (which the same plan step required) made that false at Task 1's own commit, before the assertion was even deleted. The comment now says `activeTask` stays installed so queue lifecycle behavior can be observed while a download is genuinely in flight — the same explanatory content, true at every commit.
- **`scheduleNextIfNeeded()` keeps its forwarder shape.** Inlining the core would have been smaller, but the tail is precisely where plan 15-06 re-hangs a reconcile, and the comment recording the every-exit-path guarantee is the reason that placement is correct. Collapsing it would delete the rationale along with the call.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Reworded the Info.plist keep-rationale comment off `BGProcessingTask`**

- **Found during:** Task 3 (acceptance-criteria verification)
- **Issue:** Task 3's gate requires `grep -rl 'BGProcessingTask' App AppPackage ShareExtension` to name exactly one permitted file, `BackgroundProcessingClient.swift`. It named two: plan 15-01 had added an `App/Info.plist` XML comment explaining why `UIBackgroundModes: processing` is kept, and that comment used the literal class name. The planner's gate did not anticipate the comment 15-01 introduced.
- **Fix:** Reworded one line, "not left over from the deleted discretionary `BGProcessingTask` tier" to "not left over from the deleted discretionary background-processing tier". Every other word of the rationale is unchanged, and the comment reads the same. Deferring this would only have moved the failure to plan 15-03 Task 2, whose gate demands a repository-wide zero for the same token.
- **Files modified:** `App/Info.plist`
- **Verification:** `grep -rl 'BGProcessingTask' App AppPackage ShareExtension | sort -u` now prints exactly `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift`; clean app-scheme build succeeds.
- **Committed in:** `b53f551f` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking).
**Impact on plan:** None on scope. The fix is a four-word comment edit that a later plan's gate would have forced anyway; no behavior, no API, no test changed.

## Acceptance-Criteria Notes

- Task 2's criterion asks that `git diff --stat` on `BackgroundProcessingClient.swift` show "a single-hunk deletion, no additions". The realised diff is one hunk, `1 insertion(+), 3 deletions(-)`. The sentence to delete began mid-line ("…grace period ends. Unlike `BackgroundTaskClient`, …"), so terminating the surviving sentence necessarily rewrites that line; a literally addition-free diff is unsatisfiable for a mid-line sentence deletion. The criterion's intent — delete that sentence and change nothing else in the file — holds exactly, and the full diff is quoted in the verification evidence below.

## Environment Notes

- Every `<automated>` verify block in the plan pins `-destination 'platform=iOS Simulator,name=iPhone 17'`, which does not resolve on this machine. All commands were run with `-destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` (iPhone Air, iOS 26.5); the id pin is required because `name=iPhone Air` is ambiguous here. Only the destination changed — project, scheme, test plan and `-only-testing` flags are as the plan specifies. This is a local environment fact, not a plan deviation.

## Issues Encountered

None.

## Verification Evidence

- `grep -rn 'BackgroundTaskClient\|backgroundTaskClient' App AppPackage ShareExtension | wc -l` → `0` (repository-wide, un-narrowed).
- `grep -c 'BackgroundTaskClient' AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift` → `0`; `git diff` on that file shows one hunk touching only the doc-comment sentence.
- `grep -rn 'reconcileBackgroundAssertion\|backgroundAssertionToken\|isBeginningBackgroundAssertion\|testingHasBackgroundAssertion' AppPackage | wc -l` → `0`.
- `grep -rn 'downloads[.]assertion\|beginBackgroundTask' App AppPackage ShareExtension | wc -l` → `0`.
- `grep -rn 'runQueueUntilIdle\|runBackgroundProcessing' App AppPackage ShareExtension | wc -l` → `0`.
- `grep -rl 'BGProcessingTask' App AppPackage ShareExtension | sort -u` → exactly one line, `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift` (the discretionary client plan 15-03 rewrites; the repository-wide zero is deferred to 15-03 Task 2, not dropped).
- `test -f …/DownloadClient+PendingWork.swift && test ! -f …/DownloadClient+BackgroundAssertion.swift` → succeeds; `grep -c 'func hasPendingWork' …/DownloadClient+PendingWork.swift` → `1`.
- `grep -c 'hasPendingWork' AppPackage/Sources/DownloadClient/DownloadClient.swift` → `0`.
- `test ! -f …/DownloadBackgroundAssertionTests.swift`, `test ! -f …/DownloadClient+BackgroundProcessing.swift`, `test ! -f …/DownloadBackgroundProcessingTests.swift` → all succeed.
- `grep -c 'func makeBlockingCoordinator' / 'struct BlockingCoordinatorContext' / 'func waitUntil'` in `DownloadFeatureTestHelpers.swift` → `1` each, all three declared at column 1 (file scope, not inside a `protocol`/`extension` body).
- `grep -c 'testHasPendingWorkReflectsQueueState' …/DownloadPendingWorkTests.swift` → `1`.
- `xcodebuild test … -only-testing:DownloadsFeatureTests` → `Test run with 259 tests in 53 suites passed`, `** TEST SUCCEEDED **`. (267 before this plan: six assertion cases and two drain cases removed.) `DownloadSchedulingTests` and `DownloadPauseAndReconcileTests` are green.
- Full `FeatureTests` plan → `** TEST SUCCEEDED **` across all 23 suite groups; the "known issue" records are pre-existing `withKnownIssue` expectations.
- `xcodebuild build -scheme EhPanda clean build` → `** BUILD SUCCEEDED **` with zero `warning:`/`error:` lines, so the SwiftLint build-tool plugin reported no violations. Test-file line lengths verified separately (no line over 120 characters) since the app scheme does not lint `AppPackage/Tests/`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 15-03 can rewrite `BackgroundProcessingClient` against a `DownloadClient` that holds no competing background mechanism, and its Task 2 gate now has exactly one file left to clear for the repository-wide `BGProcessingTask` zero.
- Plan 15-06 gets the two seams it needs already shaped: `hasPendingWork()` as a mechanism-free submission/completion gate, and `scheduleNextIfNeeded()`'s tail documented as the convergence point a session reconcile hangs off.
- The session suites later plans add can call `makeBlockingCoordinator` and `waitUntil` directly; when the session client is injected, only the coordinator construction inside the fixture needs a new argument.
- Accepted transient state (T-15-08, D-01/D-02): from this commit until 15-06, a backgrounded download suspends with the process and resumes on next foreground. On-disk manifests and the queue store remain the source of truth, so nothing is lost or duplicated. This is the intended topology, not a regression.

## Self-Check: PASSED

Both created files exist on disk, all five deleted files are absent, and all three task commits (`3679b2a2`, `bef95c85`, `b53f551f`) are present in `git log`.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-07-28*
