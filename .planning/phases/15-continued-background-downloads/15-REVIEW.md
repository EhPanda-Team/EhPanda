---
phase: 15-continued-background-downloads
reviewed: 2026-08-04T00:00:00Z
depth: standard
files_reviewed: 35
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
  - AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
  - AppPackage/Sources/DownloadClient/DownloadClient.swift
  - AppPackage/Sources/DownloadClient/DownloadStore.swift
  - AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings
  - AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift
findings:
  critical: 1
  warning: 10
  info: 5
  total: 16
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-08-04
**Depth:** standard
**Files Reviewed:** 35
**Status:** issues_found

## Summary

The phase replaces two background-execution tiers (`BGProcessingTask` + `beginBackgroundTask`)
with a single `BGContinuedProcessingTask` session owned by `ContinuedProcessingSession` and driven
by `DownloadCoordinator`. The session store's state machine is genuinely well factored: the
scheduling seam is injectable, identity gating is applied on both sides of every suspension, and
the retirement-ledger arithmetic in `reconcileRetiredSessionPages` is idempotent under concurrent
pushes (a re-detected departure re-assigns rather than accumulates), so the interleavings the doc
comments enumerate really do hold. The localized-string catalog conforms to the project's
labeled-substitution and per-locale rules, and the log-privacy sweep is real rather than cosmetic.

The defects concentrate in two places. First, the set of "queue-mobilizing user actions" that
start a session is incomplete: `enqueue`, `togglePause(.inactive)`, `retry`, `retryPages` and the
superseded-pause path all call `ensureContinuedSession()`, but pull-to-refresh
(`refreshDownloads` -> `syncDownloadsState(scheduleNext: true)`) restarts interrupted downloads
without it, so exactly the work this phase exists to protect can run uncovered. Second, the
ACTIVE-OWNERSHIP CONVERGENCE invariant was closed in `delete`/`deleteFolder` this phase but
`moveDownload` was left with the same scheduling-block-without-convergence shape, and the two
convergence blocks added to `commitPause` sit in `catch` arms that are unreachable because the
functions they guard are declared `throws` but cannot throw.

Findings CR-01/CR-02/CR-03 from the earlier round are not re-reported: the concrete-identifier
registration idiom, the start-snapshot seeding and the foreign-progress-push guard are all present
and tested in the current tree.

## Narrative Findings (AI reviewer)

### Critical Issues

#### CR-01: Pull-to-refresh mobilizes the download queue without starting a continued-processing session

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift:27-29`
(reached via `AppPackage/Sources/DownloadClient/DownloadClient.swift:116`)

**Issue:** `ensureContinuedSession()` is documented as the thing every queue-mobilizing user
action must call, and it is called from `enqueue` (`+PublicAPI.swift:98`), `togglePause`'s
`.inactive` branch (`+PublicAPI.swift:174`), `retry` (`+RetryHelpers.swift:18`), `retryPages`
(`+RetryHelpers.swift:70`) and the superseded-pause path (`+Scheduling.swift:184`).
`refreshDownloads` is the one remaining user-initiated entry point that mobilizes the queue and it
does not.

The path is not theoretical. `refreshDownloads` -> `syncDownloadsState(scheduleNext: true)`
(`+Scheduling.swift:137-153`) runs `normalizeNeedsAttentionDownloads` (clears cancellation-like
errors) and `normalizeInterruptedDownloads` (`+PersistenceNormalize.swift:50-68`, which nulls a
stale `activeGalleryID`), then calls `scheduleNextIfNeeded()`. Both normalizations exist precisely
to make a stranded download schedulable again, and the gid is still in `queueStore`, so
`isQueuedWorkItem` makes it pass `shouldSchedule`. A user who relaunches after a crash, pulls to
refresh on the Downloads tab to restart the queue, and then backgrounds the app gets no session
and no card - the pre-phase behavior this phase was written to remove.

The failure is silent by construction: there is no session to log, and `.unavailable` is silent by
contract, so nothing distinguishes "covered" from "uncovered" at runtime.

**Fix:** Mirror the `togglePause` shape - mobilize, then ensure - in the refresh endpoint:

```swift
// DownloadClient+PublicAPI.swift
public func refreshDownloads() async {
    await syncDownloadsState(scheduleNext: true)
    // Pull-to-refresh is a foreground user gesture that restarts normalized/interrupted
    // downloads, so it is a qualifying tap under D-07 just as enqueue and resume are.
    await ensureContinuedSession()
}
```

`reconcileDownloads()` (the scene-phase path, `AppReducer.swift:121`) must deliberately keep *not*
calling it, since it is not a user action - worth stating in a comment so the asymmetry reads as a
decision rather than the same omission.

### Warnings

#### WR-01: `moveDownload` releases its scheduling block without converging

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift:163-206`

**Issue:** `moveDownload` inserts `gid` into `schedulingBlockedGalleryIDs` at line 163 with a
function-scoped `defer` that removes it, then suspends at `await fetchDownload(gid:)` (167) and
`await reloadDownloadRecord(...)` (200/203). On every exit - success (204-205, only
`notifyObservers()`), `.notFound` (168), busy (170-176), same-destination (182-183),
already-exists (185-191) and the move failure (198-202) - it returns without calling
`scheduleNextIfNeeded()`.

Every sibling that takes a scheduling block converges: `commitPause`
(`+Scheduling.swift:209-210, 229-230, 240-241, 245-246`), `delete`
(`+PublicAPI.swift:202-203, 213-214, 220-221, 230-231`) and `deleteFolder`
(`+Folders.swift:124-125, 133-134, 147-148`) - the latter two fixed in this very phase.
`moveDownload` was not. If a `scheduleNextIfNeeded()` from another path (for example the `Task`
spawned by `finishActiveTaskIfOwned`, `+Execution.swift:254`) lands inside the block window and
this gallery is the only schedulable work, the scheduler skips it *and*
`reconcileContinuedSession()` sees `hasPendingWork() == false` and completes the live session -
taking the card down while the gallery is about to become schedulable again with nothing left to
reschedule it.

**Fix:** Converge on the exits that can leave work schedulable, after the block is released:

```swift
// end of moveDownload, replacing the bare notify:
await reloadDownloadRecord(gid: download.gid, token: download.token)
schedulingBlockedGalleryIDs.remove(gid)
await notifyObservers()
await scheduleNextIfNeeded()
return .success(())
```

and the same `remove` + `notifyObservers` + `scheduleNextIfNeeded` on the `catch` at 198-202 and
on the `.notFound` return at 168.

#### WR-02: Expiration pause-all starts the next gallery on every iteration, then immediately cancels it

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:254-264`
(with `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:229-230`)

**Issue:** `pauseAllSchedulable` walks `gids` and calls `pause(gid:expiration:)` for each. On its
happy path `commitPause` ends with `await scheduleNextIfNeeded()` (line 230) while only the
*current* gid is scheduling-blocked - the `defer` that releases it has not run yet. So pausing A
schedules B, which sets `activeGalleryID`/`activeTask` and begins real network work
(`processScheduledDownload` -> `processDownload` -> `fetchLatestPayload`). The next loop iteration
then pauses B and cancels that task.

A user tapping Cancel on the system card therefore fires a spurious gallery-detail request per
queued gallery, in a background window where the session has just been torn down. On this backend
that is not free: gallery fetches count against the image/quota limits the client already has
explicit 509 handling for (`DownloadCoordinator.quotaExceededImageURLSuffixes`).

**Fix:** Block the whole set before pausing any of it, so the intermediate reschedules find
nothing to start:

```swift
public func pauseAllSchedulable(expiring sessionID: UUID) async {
    let gids = await schedulableDownloads().map(\.gid)
    for gid in gids { schedulingBlockedGalleryIDs.insert(gid) }
    defer { for gid in gids { schedulingBlockedGalleryIDs.remove(gid) } }
    for gid in gids { /* unchanged body */ }
}
```

This needs WR-06's counted-block fix first, or the inner `commitPause` `defer` will release a gid
the outer sweep still owns.

#### WR-03: The single-session guard is not atomic across `await hasPendingWork()`

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:127-131`

**Issue:** The doc comment states "Setting the liveness flag and stamping the session id
synchronously, before the first point another caller could interleave, is the guard against two
callers both reaching the start call." The code does the opposite order:

```swift
guard !hasLiveContinuedSession, await hasPendingWork() else { return }   // await BEFORE the set
let sessionID = UUID()
hasLiveContinuedSession = true
```

The claim only holds because `hasPendingWork()` -> `schedulableDownloads()` ->
`indexedDownloads()` happen not to contain a real suspension today (`queueStore.gids` is a
synchronous `Shared` read, `DownloadQueueStore.swift:15-17`). That is an implementation detail of
three callees in two other files, and the comment at 152-154 admits it ("whose callees do not
suspend today"). Making `queueStore` an actor, or adding any true `await` inside
`indexedDownloads`, silently converts this into two coordinator sessions racing one client store:
the loser's rollback path (`guard continuedSessionID == sessionID`, line 148) no longer matches,
and both sessions end up torn down with the card gone.

**Fix:** Set the flag first and roll back if there is no work, so the guard is genuinely a
synchronous critical section:

```swift
guard !hasLiveContinuedSession else { return }
let sessionID = UUID()
hasLiveContinuedSession = true
continuedSessionID = sessionID
guard await hasPendingWork() else {
    markContinuedSessionEnded(sessionID: sessionID)
    return
}
lastPushedCompletedPageCount = 0
retiredSessionPages = [:]
observedSchedulablePages = [:]
```

#### WR-04: Both `catch` arms in `commitPause` are unreachable dead code

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:233-248`

**Issue:** The two `catch` blocks carry the phase's ACTIVE-OWNERSHIP CONVERGENCE fix and a
six-line rationale comment, but nothing inside the `do` block can throw. The only `try`
expressions are `try await writeInitialPauseRecord(...)` (217) and
`try await writeSettledPauseRecord(...)` (225), and neither body contains a throwing call -
`clearDownloadSessionState`, `queueStore.remove`, `backgroundTaskStore.removeAll` and
`notifyObservers` are all non-throwing (lines 260-285). `fetchDownload` does not throw either.

So `.settled(.failure(error))` and `.settled(.failure(.unknown))` can never be returned, the
convergence they perform can never run, and no test can cover them. A reader - or a future
reviewer checking the invariant - sees convergence that is not actually installed on any live
path.

**Fix:** Drop the vestigial `throws` from both writers (see WR-05), remove the `do`/`catch`
scaffolding, and hoist the block release to a plain `defer` at the top of `commitPause`. If the
writers are expected to throw later, give them a throwing call now; otherwise delete the arms so
the file stops documenting behavior it does not have.

#### WR-05: `writeInitialPauseRecord` / `writeSettledPauseRecord` take an unused parameter and duplicate each other

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:260-285`

**Issue:** Both functions declare `download: DownloadedGallery` and never reference it; both
declare `throws` and never throw. `writeSettledPauseRecord`'s entire body is the first three lines
of `writeInitialPauseRecord`. The call sites (217-220, 225-228) pass `currentDownload` purely to
satisfy the signature, which makes the record read at line 198 look load-bearing for the write
when it is only used by the `displayStatus` guard at 205-207.

**Fix:**

```swift
private func writeInitialPauseRecord(gid: String) async -> Task<Void, Never>? {
    await clearPauseState(gid: gid)
    await notifyObservers()
    guard activeGalleryID == gid else { return nil }
    let task = activeTask
    activeTask?.cancel()
    activeTask = nil
    activeGalleryID = nil
    return task
}

private func clearPauseState(gid: String) async {
    clearDownloadSessionState(gid: gid, includeUpdateFlag: true)
    await queueStore.remove(gid)
    await backgroundTaskStore.removeAll(for: gid)
}
```

with the settled write becoming a direct `await clearPauseState(gid: gid)`.

#### WR-06: `schedulingBlockedGalleryIDs` is a plain `Set`, so overlapping blocks on one gid release early

**Files:**
`AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:194-197`,
`AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift:183-186`,
`AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift:99-106`,
`AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift:163-166`

**Issue:** Four call sites use the `insert` + `defer remove` idiom on a `Set<String>`. All four
suspend while holding the block (`fetchDownload`, `taskToCancel?.value`, `removeFolder`,
`moveItem`), and `DownloadCoordinator` is a reentrant actor, so two of them can hold the same gid
at once - `delete(gid:)` and `commitPause(gid:)` for the same gallery, or `deleteFolder` for a
folder and `moveDownload` for a gallery inside it. Whichever finishes first removes the shared
entry, and the scheduler is then free to start a download inside a folder that is mid-removal or a
gallery whose active task is mid-cancellation. WR-02's fix cannot be written safely until this is
addressed.

**Fix:** Make it a counted set:

```swift
public var schedulingBlockCounts = [String: Int]()

func beginSchedulingBlock(gid: String) { schedulingBlockCounts[gid, default: 0] += 1 }

func endSchedulingBlock(gid: String) {
    guard let count = schedulingBlockCounts[gid] else { return }
    schedulingBlockCounts[gid] = count > 1 ? count - 1 : nil
}
```

and route `isSchedulableDownload` (`+Scheduling.swift:118-123`) through
`schedulingBlockCounts[download.gid] == nil`.

#### WR-07: Session-lifecycle mutators are `public` purely so a cross-module test target can call them

**Files:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:62, 88, 127,
195, 229, 254, 275, 385`; `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift:10`

**Issue:** `ensureContinuedSession`, `handleContinuedSessionEvent`, `markContinuedSessionEnded`,
`pauseAllSchedulable`, `reconcileContinuedSession`, `pushContinuedSessionProgress`,
`schedulableSnapshot`, `continuedSessionSubtitle` and `hasPendingWork` have no caller outside the
`DownloadClient` module - every production call is same-module, and `hasPendingWork` lost its only
cross-module caller when the `DownloadClient.hasPendingWork` endpoint was deleted this phase. They
are `public` only because `DownloadsFeatureTests` links the module normally. That publishes
state-machine mutators to every module that links `DownloadClient` (`AppFeature`,
`DownloadsFeature`, `DetailFeature`, `HomeFeature`, `SearchFeature`, `FavoritesFeature`,
`ReadingFeature`): any of them can call `markContinuedSessionEnded(sessionID:)` or
`pauseAllSchedulable(expiring:)` and detach a live session while the system card is still on
screen.

The module already has the right pattern - `DownloadClient+Testing.swift` wraps its seams in
`#if DEBUG`, and this phase added `testingHasContinuedSession()` / `testingContinuedSessionID()`
there.

**Fix:** Demote them to `internal` and add `#if DEBUG public` forwarders in
`DownloadClient+Testing.swift` for the ones tests genuinely drive:

```swift
#if DEBUG
extension DownloadCoordinator {
    public func testingEnsureContinuedSession() async { await ensureContinuedSession() }
    public func testingPauseAllSchedulable(expiring sessionID: UUID) async {
        await pauseAllSchedulable(expiring: sessionID)
    }
}
#endif
```

#### WR-08: The client spy consumes its one-shot `refuseNextStart` flag on refusals it did not cause

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift:251-262`

**Issue:**

```swift
guard $0.currentSessionID == nil, !$0.refusesNextStart else {
    $0.refusesNextStart = false
    return true
}
```

The `else` branch clears `refusesNextStart` whichever condition failed. If a session is already
held, an armed refusal is silently consumed by a start that would have been refused anyway, and
the *next* start - the one the test armed the refusal for - is accepted. A test written as "arm
refusal, then drive an action that happens to attempt two starts" would pass for the wrong reason.
The live store has no such coupling: its guard (`ContinuedProcessingSession.swift:85-87`) has no
one-shot flag at all.

**Fix:** Only consume the flag when it is the cause of the refusal:

```swift
let shouldRefuse = self.state.withLock { state -> Bool in
    // ...recording...
    if state.refusesNextStart {
        state.refusesNextStart = false
        return true
    }
    return state.currentSessionID != nil
}
```

#### WR-09: A superseded expiration pause reports `.success(())` for work it did not do

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:169-186`

**Issue:** The `.superseded` arm of `pause(gid:expiration:)` returns `.success(())` after
deliberately abandoning the pause. Today the only caller that can reach it discards the result
(`_ = await pause(gid: gid, expiration: expiration)`, `+ContinuedSession.swift:262`), so nothing
is misled - but the public `pause(gid:)` shares the same return type, and the arm is one caller
away from telling a UI that a pause succeeded while the download is still running.

**Fix:** Give the outcome a name the caller cannot misread - return `Result<PauseOutcome, AppError>`
with `.paused` / `.abandoned`, or keep `.superseded` unreachable from the public verb by having
`pauseAllSchedulable` call `commitPause` directly.

#### WR-10: Every session attempt permanently registers a new launch handler, including failed ones

**File:** `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift:125-147`

**Issue:** `start` mints a fresh UUID identifier and calls `scheduling.register(identifier)`
before `scheduling.submit(...)`. A launch handler can never be unregistered (stated at lines
192-194), so every attempted session leaves a permanent registration behind for the process
lifetime - including the ones whose submission throws and yields `.unavailable` (140-147). The
per-session UUID is forced by the API (re-registering an identifier terminates the app), so some
growth is inherent, but failed attempts currently cost exactly as much as successful ones and
nothing bounds or reports the total.

This compounds with the `.superseded` path at `+Scheduling.swift:184`, which calls
`ensureContinuedSession()` from inside expiration handling - a background context where the
scheduler is expected to refuse the submission. Each such refusal burns a registration and logs an
error, and the surrounding comment's justification ("the scheduler's own foreground validation
makes a late ensure inert") is true of the *submission* but not of the *registration* that
precedes it.

**Fix:** Two independent mitigations:

1. Gate the `.superseded` re-ensure on foreground state, or defer it via a
   `pendingEnsureOnNextForeground` flag consumed by the next qualifying tap, rather than
   attempting a submission the scheduler is documented to drop.
2. Count registrations in `ContinuedProcessingSession` and log at `notice` when the total crosses
   a sane bound, so unbounded growth is observable rather than invisible.

### Info

#### IN-01: `UncheckedBox` is not unchecked

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift:8-19`

**Issue:** The type is `Mutex`-backed and genuinely `Sendable`; "Unchecked" names a safety
property it does not have. In a repository whose lint config bans `@unchecked Sendable` at error
severity and whose new invariant suite greps for that spelling, the name actively misleads.

**Fix:** Rename to `LockedBox` or `MutexBox`.

#### IN-02: A process-shared singleton is defaulted into a `sending` parameter

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift:357`

**Issue:** `fileManager: sending FileManager = FileManager.default`. `sending` asserts the callee
receives a disconnected value it may take exclusive ownership of; `FileManager.default` is the
process-wide shared instance. It compiles, but the annotation now documents a guarantee the
default violates.

**Fix:** Default to `FileManager()` - which is what `DownloadClient.live` itself uses
(`DownloadClient.swift:43`) - rather than `.default`.

#### IN-03: The store's `.unavailable` branches are never exercised

**File:** `AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift:75-93`

**Issue:** `ContinuedTaskSchedulingSpy.scheduling` always returns `true` from `register` and never
throws from `submit`, so none of `ContinuedProcessingSession`'s three `.unavailable` paths
(missing bundle identifier, refused registration, throwing submission -
`ContinuedProcessingSession.swift:116-147`) is covered. Coordinator-side coverage uses a separate
`BackgroundProcessingClient.unavailable` fixture that bypasses the store entirely
(`DownloadContinuedSessionTests.swift:957-965`), so the store's own early-teardown behavior (no
pending request to cancel, stream finished before return, `didCancelStaleRequests` already
latched) is asserted nowhere.

**Fix:** Add spy controls (`refusesNextRegistration`, `submissionError`) and one case per branch,
asserting the returned handle's stream yields exactly `[.unavailable]` and that
`cancelledIdentifiers` stays empty.

#### IN-04: `BackgroundExecutionInvariantTests` duplicates two SwiftLint rules

**File:** `AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift:101-108`

**Issue:** The `@unchecked Sendable` and `nonisolated(unsafe)` tokens are already enforced at error
severity by the root `.swiftlint.yml` (`no_unchecked_sendable`) and the lint gate. Two enforcement
points for one rule means a future relaxation has to be found in two places, and the test's
failure message ("reappeared in: ...") is less actionable than the lint message.

**Fix:** Drop those two tokens and leave the phase-specific deletions (`BGProcessingTask`,
`beginBackgroundTask`, `BackgroundTaskClient`, `runQueueUntilIdle`, the two identifiers), which is
what the suite uniquely covers.

#### IN-05: A drained-queue push can render "N / N pages - 0 galleries"

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:407-419`

**Issue:** `pushed.galleryCount` is taken raw from the live snapshot while the numerator and
denominator include the retirement ledger, so a push made once the schedulable set is empty reads
"20 / 20 pages - 0 galleries" - the value the ledger suite pins as the drained pair
(`DownloadContinuedSessionLedgerTests.swift:31-35`). In production the pair should be unreachable
because `reconcileContinuedSession` completes the session before pushing when `hasPendingWork()`
is false, but nothing in `pushContinuedSessionProgress` enforces that, and `flushDownloadProgress`
calls it on a path that never checks pending work (`+Persistence.swift:223-225`).

**Fix:** Either guard the push (`guard snapshot.sessionProgress.galleryCount > 0 else { return }`)
or floor the reported count at one, and state in the doc comment which invariant makes the zero
case unreachable.

---

_Reviewed: 2026-08-04_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
