---
phase: 15-continued-background-downloads
reviewed: 2026-07-28T11:01:13Z
depth: standard
files_reviewed: 26
files_reviewed_list:
  - App/Info.plist
  - AppPackage/Package.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
  - AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift
  - AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift
  - AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
  - AppPackage/Sources/DownloadClient/DownloadClient.swift
  - AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings
  - AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift
findings:
  critical: 4
  warning: 3
  info: 0
  total: 7
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-07-28T11:01:13Z
**Depth:** standard
**Files Reviewed:** 26
**Status:** issues_found

## Summary

The submitted continued-processing implementation compiles under the iOS 26 simulator target, and
its plist and string catalog parse successfully. The lifecycle still has four shipping correctness
defects, however: progress mutations are not client-session identified, a newly adopted system task
starts with a false `0 / 0` progress state, expiration can overwrite a user action that interleaves
inside a per-gallery pause, and one delete edge leaves both queue scheduling and the system session
stranded. The new tests also miss the suspension window they claim to cover and can leak their
deliberately infinite task on an early test exit.

Review guidance used: `gsd-code-review`, `swift-concurrency-pro` (actor reentrancy, cancellation,
unstructured tasks, and `AsyncStream` lifecycle), and `swift-testing-pro` (parallel async-test
determinism and teardown).

## Critical Issues

### CR-01: Progress updates can mutate a successor session

**File:** `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift:38-42`
**Issue:** `finish` carries a client session ID, but `updateProgress` does not. The coordinator only
checks its own ID before suspending into the client (`DownloadClient+ContinuedSession.swift:232-259`);
the live closure then hops to `ContinuedProcessingSession.shared` on the main actor. Actor executors
do not provide a cross-actor FIFO guarantee. If the old session expires or drains and a new tap
starts a successor before that hop executes, the stale counts and subtitle are written into the
successor. `ContinuedProcessingSession.updateProgress` (`:145-155`) has no identity check with which
to reject the mutation. This breaks the identity invariant already applied to completion and can
rewind or replace the new card's progress.

**Fix:**
```swift
public var updateProgress: @Sendable (
    _ sessionID: UUID,
    _ completedUnitCount: Int64,
    _ totalUnitCount: Int64,
    _ subtitle: String
) async -> Void

@MainActor
public func updateProgress(
    sessionID: UUID,
    completedUnitCount: Int64,
    totalUnitCount: Int64,
    subtitle: String
) {
    guard self.sessionID == sessionID else { return }
    // Apply counts and subtitle.
}
```

Pass `continuedClientSessionID`, not the coordinator-only ID, from every push. Update the spy to
ignore foreign IDs and add a gated regression where an S1 update resumes only after S2 starts.

### CR-02: A granted task is deliberately seeded with false `0 / 0` progress

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:86-114`
**Issue:** `ensureContinuedSession` computes a real queue snapshot and includes it in the subtitle,
but after `start` succeeds it never sends those counts to the client. The store resets its saved
counts to zero at `ContinuedProcessingSession.swift:87-88`, and adoption writes those zeros into the
system `Progress` at `:199-200`. The result is an internally contradictory card (a subtitle such as
`120 / 300 pages` backed by a `0 / 0` progress object) until some later manifest flush or queue
mutation happens. During a slow metadata fetch there may be no later push for a long time; this is
also exactly when the scheduler sees a task reporting no progress and may reclaim it as stalled.
The test at `DownloadContinuedSessionTests.swift:189-208` currently enshrines this defect by
requiring no update after start.

**Fix:** Seed the identified client session immediately after the ownership re-check, before
installing the event consumer, using the snapshot already computed:

```swift
continuedClientSessionID = clientSession.id
await backgroundProcessingClient.updateProgress(
    clientSession.id,
    Int64(snapshot.progress.displayCompletedPageCount),
    Int64(snapshot.progress.displayPageCount),
    continuedSessionSubtitle(for: snapshot)
)
guard continuedSessionID == sessionID else {
    await backgroundProcessingClient.finish(clientSession.id, true)
    return
}
```

Alternatively make the initial counts part of `start`, so the main-actor store records them before
submission and even a synchronous launch adopts a correctly seeded `Progress`.

### CR-03: Expiration can overwrite a user action inside the pause suspension

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:188-193`
**Issue:** The session-identity guard protects only the instant before `await pause(gid:)`.
`pause` then performs several real suspension points (`DownloadClient+Scheduling.swift:160-170`),
starting with persisted queue removal. A resume/retry/enqueue for that same gallery can interleave
after the guard, report success, and write fresh queue intent. When the stale expiration-owned
`pause` resumes, `writeSettledPauseRecord` clears that new intent again. Because the gallery is in
`schedulingBlockedGalleryIDs` during the interleave, the new tap can also fail to start a successor
session, leaving the user with a successful action that did not mobilize the download. The
per-iteration guard does not make the multi-await mutation atomic.

**Fix:** Give gallery scheduling mutations an epoch/generation and make the expiration pause
conditional on both the expiring session ID and the captured gallery epoch at every post-suspension
commit. A cleaner solution is a coordinator-owned bulk expiration transition that synchronously
marks all captured galleries paused/blocked and removes their in-memory queue intent before doing
persisted saves, then cancels/awaits the captured tasks. A new user action must advance the epoch so
stale persistence cannot clear it.

### CR-04: Deleting a vanished active record strands the remaining queue and card

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift:181-200`
**Issue:** `delete` cancels and clears an active task before fetching its indexed download. If that
record has disappeared (external file deletion, a stale index repair, or a concurrent reload), the
`notFound` branch clears queue bookkeeping and returns without `notifyObservers()` or
`scheduleNextIfNeeded()`. The cancelled task's generation no longer owns `activeGalleryID`, so its
deferred `finishActiveTaskIfOwned` also refuses to schedule. Remaining queued galleries therefore
stall, and a live continued-processing session is never reconciled or finished; with no remaining
work it leaves an empty card, and with other work it eventually looks stalled and expires.

**Fix:**
```swift
guard let download = await fetchDownload(gid: gid) else {
    clearDownloadSessionState(gid: gid, includeUpdateFlag: true)
    await queueStore.remove(gid)
    await backgroundTaskStore.removeAll(for: gid)
    await notifyObservers()
    await scheduleNextIfNeeded()
    return .failure(.notFound)
}
```

## Warnings

### WR-01: The expiration identity test never enters the reentrant pause window

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift:106-137`
**Issue:** The test description claims to cover a queue-mobilizing tap arriving inside
`pauseAllSchedulable`, but it calls the method with a foreign UUID while the successor is already
live. The first guard returns before `pause(gid:)` or any suspension executes. It therefore passes
with CR-03 present and cannot detect a stale pause overwriting queue intent.

**Fix:** Inject a deterministic gate into the pause/queue persistence seam. Start S1 expiration,
wait until the pause has crossed its identity guard and is suspended, perform the resume/retry that
starts or belongs to S2, then release the gate and assert the new queue intent, active work, and
client session survive.

### WR-02: Blocking fixtures leak an infinite task when a test exits early

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift:424-466`
**Issue:** `makeBlockingCoordinator` installs a runner that loops until cancellation. The lifecycle
tests defer only temporary-directory deletion and call `pause` as their final statement (for
example `DownloadContinuedSessionTests.swift:102-113`). Any throwing `#require`, thrown client call,
or future early return before that final pause leaves the task running indefinitely. The task and
coordinator retain the in-flight operation, so a failing test can hang or contaminate parallel
tests rather than report its original failure.

**Fix:** Make the fixture own a synchronous, idempotent release token that the runner waits on and
that each test can release from `defer`; then await task completion on the normal path. Alternatively
wrap each case in an async fixture helper that guarantees cancellation and awaiting in its own
cleanup path.

### WR-03: Pending-work and progress selection duplicate the scheduler's set definition

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift:9-18`
**Issue:** `hasPendingWork` manually repeats the queue selection and blocked/schedulable filtering
also implemented by `schedulableDownloads` (`DownloadClient+ContinuedSession.swift:264-269`). The
current predicates happen to agree, but session start/completion uses the first while card counts
use the second. A future scheduler predicate change can make the client complete a nonempty card or
keep an empty one alive without a compiler or test forcing the two copies to change together.

**Fix:** Extract one actor-isolated `schedulableDownloads()`/`hasSchedulableDownloads()` authority
used by scheduling, pending-work checks, and progress snapshots. Preserve the `activeTask != nil`
fast path only if it is expressed as an explicit additional invariant rather than a second copy of
the filtering rules.

---

_Reviewed: 2026-07-28T11:01:13Z_
_Reviewer: the agent (gsd-code-reviewer)_
_Depth: standard_
