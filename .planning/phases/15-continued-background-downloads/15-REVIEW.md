---
phase: 15-continued-background-downloads
reviewed: 2026-08-04T00:00:00Z
depth: standard
files_reviewed: 34
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
  critical: 2
  warning: 11
  info: 0
  total: 13
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-08-04
**Depth:** standard
**Files Reviewed:** 34
**Status:** issues_found

> Severity mapping: **BLOCKER** findings are recorded under the canonical `critical:` frontmatter
> key and carry `CR-` ids. **WARNING** findings carry `WR-` ids.

## Summary

The continued-processing seam is unusually well documented, and the identity discipline around
`continuedSessionID` is genuinely careful. Two defects survive that discipline, and both are
user-visible on ordinary taps.

The first is the change under review. Plan 15-22 inserted `pushContinuedSessionProgress` into the
drain branch of `reconcileContinuedSession`, and the branch's own doc comment reasons about that
insertion from a false premise: it claims the push suspends at "an index read plus the ledger's
record read". Those two reads are same-actor calls that never suspend. The call that *does* suspend
is `backgroundProcessingClient.updateProgress`, which in `.live` hops to the `@MainActor`
`ContinuedProcessingSession`. Because the mitigation was chosen against the wrong suspension, it
guards the wrong invariant: it re-checks *ownership* (unchanged across the window by construction)
but never re-checks *drain-ness*, which is what the branch decided before the window opened. The
result is a reentrancy hole in a tail that was atomic before this commit (CR-01).

The second is older than 15-22 but sits squarely inside the reviewed surface: the session's page
arithmetic treats a queued `.update`/`.redownload` work item on an already-complete gallery as N of
N finished pages, so the system card opens at 100% and the monotonic floor then pins it there for
the whole session. That is the "literal 100% card that could not advance again" failure that
`pushContinuedSessionProgress`'s own doc comment says the retirement ledger fixed, reintroduced
through a different door (CR-02).

Beyond those, the biggest structural concern is that the test double for the client seam
(`BackgroundProcessingClientSpy.updateProgress`) never suspends unless a case explicitly arms a
gate, and no drain case arms one. Every drain assertion added by 15-22 is therefore green for a
reason unrelated to the hazard the same commit introduced (WR-02) — the same shape as the recorded
"contract-faithful test doubles" lesson from the earlier gap rounds.

Checked and clean: localization (`continued_session.*` uses named numeric substitutions in every
locale, `en`/`de` category sets match, CJK/`ko` are `other`-only), SwiftLint budgets (no line over
120 characters in any reviewed file; module `.swiftlint.yml` present with `parent_config`), the
log-privacy masking invariant, the deleted-tier grep invariant, and the path-escape guards in
`DownloadStore`.

## Critical Issues

### CR-01: Terminal push reopens the drain branch to reentrancy; a live session is torn down over freshly queued work

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:297-318`
(introduced by `f8159740`; supporting doc claim at lines 294-296)

**Issue:**

The drain branch now reads:

```swift
guard await hasPendingWork() else {
    guard continuedSessionID == sessionID else { return }
    guard let clientSessionID = continuedClientSessionID else {
        continuedSessionNeedsReconciliation = true
        return
    }
    await pushContinuedSessionProgress(sessionID: sessionID)   // <-- suspends (main-actor hop)
    guard continuedSessionID == sessionID else { return }      // <-- ownership only
    markContinuedSessionEnded(sessionID: sessionID)
    await backgroundProcessingClient.finish(clientSessionID, true)
    return
}
```

Trace the suspension points, not the `await` keywords:

- `hasPendingWork()` → `schedulableDownloads()` → `queueStore.gids` (a synchronous `Shared` read)
  → `indexedDownloads()` → `downloads(from:)`. Every one of these is a same-actor `async` function
  with no suspension point in its body, so `hasPendingWork()` **does not suspend**.
- Inside `pushContinuedSessionProgress`, `schedulableSnapshot()` and `reconcileRetiredSessionPages`
  → `indexedDownloads(gids:)` are the same — **they do not suspend either**, contrary to the doc
  comment at line 294.
- The last statement, `await backgroundProcessingClient.updateProgress(...)`, resolves in `.live` to
  `await ContinuedProcessingSession.shared.updateProgress(...)` on a `@MainActor` type
  (`BackgroundProcessingClient.swift:70-77`, `ContinuedProcessingSession.swift:33`). That is a real
  cross-actor hop out of and back into the reentrant `DownloadCoordinator` actor.

So before this commit the sequence `hasPendingWork() == false → markContinuedSessionEnded → finish`
was atomic with respect to actor reentrancy. It is no longer. Inside the `updateProgress` hop, a
queue-mobilizing action can land:

1. `enqueue(payload:)` runs: writes the manifest, `queueStore.enqueue(gid)`, `notifyObservers()`,
   `scheduleNextIfNeeded()`. The queue now has pending work and may already hold an `activeTask`.
2. `enqueue` then calls `ensureContinuedSession()`, which returns immediately — its first guard is
   `!hasLiveContinuedSession`, and the draining session has not cleared that flag yet because
   `markContinuedSessionEnded` has not run. The new work folds into the doomed session.
3. The drain resumes. `continuedSessionID == sessionID` still holds — nothing minted a successor —
   so the guard passes, `markContinuedSessionEnded` runs, and `finish(clientSessionID, true)`
   completes the system task.

Net effect: the card disappears and background coverage is dropped while a download the user just
started is running. Per D-03/SC3 there is no fallback tier and no retry, so that work runs
foreground-only until the next qualifying tap. The same window is reachable from
`resume`/`togglePause` (`DownloadClient+PublicAPI.swift:174`), `retry` and `retryPages`
(`DownloadClient+RetryHelpers.swift:18, 70`), which all reach `scheduleNextIfNeeded()` before their
own `ensureContinuedSession()`.

The ownership re-check the commit added cannot catch this: `continuedSessionID` changing would
require `markContinuedSessionEnded` to have run first, which is exactly what has not happened.

**Fix:** re-validate the branch's own predicate, not just ownership, behind the suspension:

```swift
            // D-G2B-01: the card's last word, taken while this session still owns it.
            await pushContinuedSessionProgress(sessionID: sessionID)
            guard continuedSessionID == sessionID else { return }
            // The push crosses the client seam's main-actor hop, so the drain decision taken
            // before it is no longer authoritative. Work mobilized inside that window folds into
            // *this* session — its own `ensureContinuedSession` is inert while
            // `hasLiveContinuedSession` is true — so completing here would drop coverage nothing
            // can restore. Leave the session live; the next convergence reconciles it.
            guard await hasPendingWork() == false else { return }
            logger.notice("Continued-processing session drained, terminal progress pushed.")
            markContinuedSessionEnded(sessionID: sessionID)
            await backgroundProcessingClient.finish(clientSessionID, true)
```

Also correct the doc comment at lines 294-296 (see WR-01): it is the premise the insufficient guard
was chosen from.

### CR-02: A queued update/redownload of a complete gallery opens the card at 100% and pins it there for the whole session

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:127-142, 411-446`
(with `DownloadClient+Scheduling.swift:125-135` and `DownloadClient+RetryHelpers.swift:9-26`)

**Issue:**

`shouldSchedule(download:)` returns `true` for `download.displayStatus == .active ||
download.isQueuedWorkItem` **before** it consults completeness. `isQueuedWorkItem` is
`displayStatus == .queued` (`DownloadedGallery+SupportTypes.swift:83`), and `displayStatus` is
`.queued` whenever `queueStore.contains(gid)`. So a *fully complete* gallery enqueued for `.update`
or `.redownload` is schedulable, and its manifest still reports `completedPageCount == pageCount`
(`DownloadedGallery+Manifest.swift:67-73`) because the fresh manifest has not been written yet.

Ordinary tap sequence — user taps Update on a completed gallery:

1. `retry(gid:mode: .update)` → `performRetry` → `queueStore.enqueue(gid)` →
   `scheduleNextIfNeeded()` (which sets `activeGalleryID = gid`) → `ensureContinuedSession()`.
2. `schedulableSnapshot()` sums that one gallery: `completedPageCount == pageCount == N`.
3. `ensureContinuedSession` submits `start(title, "N / N pages · 1 gallery", N, N)` (lines 136-142).
   The system card opens at **100% with one gallery still to go**, and on adoption
   `ContinuedProcessingSession.adopt` seeds `task.progress` to `N/N` — a `Progress` already
   fulfilled the moment the system launches the task.
4. `lastPushedCompletedPageCount = N` is latched (line 160).
5. The update then rewrites the manifest to `0` of `M` done. Every later push computes
   `completedPageCount = max(lastPushedCompletedPageCount, ...) = N` (lines 428-431) and
   `pageCount = max(displayPageCount, completedPageCount) = max(M, N)`. When `M == N` — the normal
   case for a redownload, and common for an update — the card reads `N / N` for the whole session
   and never moves.

This is precisely the failure mode the doc comment on `pushContinuedSessionProgress` (lines 380-387)
says the retirement ledger was built to eliminate: "the two clamps below pinned the pair at a
literal 100% card that could not advance again". It also defeats the liveness requirement stated at
`DownloadClient+Persistence.swift:195-200` — the scheduler "forcibly expires tasks that appear
stalled, and prioritizes terminating the ones reporting the least progress" — and per D-11 an
expiration pauses every schedulable download, i.e. it pauses work the user never touched. The
suite's own invariant helper `expectTheFractionReachesOneOnlyAtTheDrain`
(`DownloadContinuedSessionLedgerTests.swift:433-441`) encodes "1.0 only at drain" as the intended
property; this path violates it on the very first push.

No test covers a queued work item on a *complete* gallery:
`testCancellingTheLastQueuedWorkItemCompletesTheSession` uses `.update` but seeds
`completedPageCount: 1, pageCount: 5`, so it never reaches the degenerate pair.

**Fix:** a queued work item's already-finished pages are work this session has *not* done, so they
must not enter the numerator. Exclude them in the snapshot, which is the one place the card's
arithmetic is derived:

```swift
    public func schedulableSnapshot() async -> SchedulableSnapshot {
        let downloads = await schedulableDownloads()
        // A redownload/update work item intends to redo pages its manifest still reports as done.
        // Counting them opens the card at 1.0 and, with the monotonic floor latched at that value,
        // pins it there for the session — the failure the ledger exists to prevent.
        func sessionCompletedPageCount(_ download: DownloadedGallery) -> Int {
            switch queuedModes[download.gid] {
            case .redownload, .update: 0
            case .initial, .repair, .none: download.completedPageCount
            }
        }
        ...
    }
```

Add a regression case pinning the opening pair for a complete gallery queued for `.update`, and run
`expectTheFractionReachesOneOnlyAtTheDrain` over that fixture too.

## Warnings

### WR-01: Doc comment names the wrong suspension, and CR-01's insufficient guard was derived from it

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:294-296`
**Issue:** "The push suspends — an index read plus the ledger's record read — where this branch's
tail was previously suspension-free, so ownership is re-checked behind it exactly as it is after
every other suspension in this file." Both named reads are same-actor `async` calls with no
suspension point (`schedulableSnapshot` → `schedulableDownloads` → `indexedDownloads` →
`downloads(from:)`; `reconcileRetiredSessionPages` → `indexedDownloads(gids:)`). The real
suspension is the `@MainActor` hop in `backgroundProcessingClient.updateProgress`. This is not
cosmetic: it is the premise CR-01's guard was chosen from, and it will lead the next reader to the
same conclusion.
**Fix:** replace with the actual mechanism, e.g. "The push's tail crosses the client seam, whose
live value is `@MainActor`-confined, so this branch now yields the actor where its tail previously
did not. Ownership *and* the drain predicate are therefore re-checked behind it."

### WR-02: The client-seam double cannot suspend, so the window CR-01 opens is structurally untestable

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift:286-315`
**Issue:** `BackgroundProcessingClientSpy.updateProgress` only awaits when a case has armed a
progress gate; with no gate its body is two `state.withLock` blocks and returns without ever
suspending. No drain case in `DownloadContinuedSessionTests`, `DownloadContinuedSessionLedgerTests`
or `DownloadDeleteConvergenceTests` arms one. The live seam always suspends. So the entire drain
suite added by 15-22 exercises a tail that is atomic in tests and reentrant in production — green
for a reason that does not hold on device.
**Fix:** make the spy's `updateProgress` (and `start`/`finish`) always yield at least once before
recording — e.g. `await Task.yield()` at entry — so every existing case runs against a seam that can
interleave. Then add a case that enqueues fresh work from inside a held progress gate at a drain and
asserts `finishRecords.isEmpty` and `testingHasContinuedSession() == true`.

### WR-03: `finish(_:success:)` is hard-coded to `true` on every exit, including abandoned queues

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:156, 314`
**Issue:** The drain always reports `success: true`, and so does the superseded-start rollback at
line 156. That value reaches `BGContinuedProcessingTask.setTaskCompleted(success:)`, the system's
signal of whether the work finished. The tests pin drains that ended at
`"0 / 1 page · 0 galleries"` (`DownloadContinuedSessionTests.swift:238`) and
`"1 / 1 page · 0 galleries"` for a 5-page gallery with 4 pages never fetched (line 846) — both
reported as successes. Nothing in the file documents why `true` is unconditional, which is unusual
for this codebase's standard on deliberate designs.
**Fix:** derive it or document it. A derivation is available at the call site without new state: the
terminal push already knows whether the session finished what it intended, so pass `false` when the
drain was produced by a departure that retired unfinished pages. If `true` really is correct for all
exits, say why on `reconcileContinuedSession`.

### WR-04: The terminal push can rewind the card's denominator to the one-page floor

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:428-439`
**Issue:** The monotonic floor protects only the numerator; the denominator is
`max(sessionProgress.displayPageCount, completedPageCount)`, and `displayPageCount` floors an empty
sum at `1`. A user who pauses a 12-page download that had finished nothing sees the card's last
state jump from "0 / 12 pages · 1 gallery" to "0 / 1 page · 0 galleries" — pinned as intended
behavior at `DownloadContinuedSessionTests.swift:238` and `:287`. The terminal push exists so the
card's final string is meaningful; a job that visibly shrinks from 12 pages to 1 page, and a
subtitle that always ends "· 0 galleries", is not obviously better than the stale string it
replaced. This is a design call rather than a coding error, but it is the user-facing output of the
fix and is currently locked in by literals rather than argued for.
**Fix:** either extend the monotonic floor to the denominator (`max(lastPushedPageCount, ...)`) so
the terminal pair keeps the last honest denominator, or give the drained state its own subtitle key
without a gallery clause. Either way, record the reasoning next to the clamp — the current comment
explains only the numerator floor.

### WR-05: The terminal-push log cannot make the distinction it was added for

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:310`
**Issue:** `f8159740`'s message says the notice exists "so a device run can tell 'never pushed' from
'pushed and not repainted'". It is emitted unconditionally after the call returns, but the push can
be silently dropped downstream: `ContinuedProcessingSession.updateProgress` returns at
`guard self.sessionID == sessionID` (the store already ended the session inside its expiration
handler, before the coordinator's event handler ran) or at `guard let task` (submission accepted,
never launched). In both cases the log claims "terminal progress pushed" while nothing reached the
card — exactly the state it is supposed to discriminate.
**Fix:** have the push report whether it crossed the seam and log the outcome, e.g. make
`pushContinuedSessionProgress` `@discardableResult ... -> Bool` returning `false` at each early
guard, and log `"Continued-processing session drained, terminal progress \(pushed ? "pushed" :
"skipped", privacy: .public)."`.

### WR-06: `ensureContinuedSession` resets four session-scoped fields but not the reconciliation debt

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:130-134`
**Issue:** A new session explicitly zeroes `lastPushedCompletedPageCount`, `retiredSessionPages` and
`observedSchedulablePages`, but leaves `continuedSessionNeedsReconciliation` at whatever the
previous session's teardown left. It is safe today only because `markContinuedSessionEnded` clears
it and the `!hasLiveContinuedSession` guard implies teardown ran — an invariant maintained two hops
away from where it is relied on, on a reentrant actor where every other field in the same block is
defended directly.
**Fix:** add `continuedSessionNeedsReconciliation = false` to the same synchronous block so the
session-scoped reset is complete by inspection.

### WR-07: Session lifecycle state is unconditionally `public var` while the debug accessors imply it should not be

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:386-433`
**Issue:** `hasLiveContinuedSession`, `continuedSessionID`, `continuedClientSessionID`,
`continuedSessionNeedsReconciliation`, `continuedSessionTask`, `lastPushedCompletedPageCount`,
`retiredSessionPages` and `observedSchedulablePages` are all `public var` on a `public actor`, so
any module linking `DownloadClient` can write them and break invariants the continued-session file
spends ~450 lines defending. Meanwhile `DownloadClient+Testing.swift:56-64` wraps
`hasLiveContinuedSession` and `continuedSessionID` in `#if DEBUG` accessors, which is only
meaningful if the stored properties are not already public. The only external reader is
`continuedSessionTask`, in three test cases.
**Fix:** demote the set to `internal` (or `private(set)`) and expose the one test-needed value
through the existing `#if DEBUG` seam, e.g.
`public func testingContinuedSessionTask() -> Task<Void, Never>?`.

### WR-08: `UIBackgroundModes: processing` is retained on a justification that understates the cost

**File:** `App/Info.plist:160-169`
**Issue:** The comment argues that "an unnecessary declaration costs one stray key, while a wrong
removal makes every submission fail". The first half is not true: App Review Guideline 2.5.4 rejects
apps that declare background modes they do not use, and this phase deleted the only tier that used
`processing`. The documented requirement for a continued-processing submission is
`BGTaskSchedulerPermittedIdentifiers`, already declared at lines 5-8. The failure modes are
asymmetric in the opposite direction from what the comment claims.
**Fix:** keep the key until the device experiment settles it if you must, but correct the comment to
name the real cost (2.5.4 rejection risk) and tie the removal decision to the already-open SC2
physical-device UAT item rather than leaving it as an open-ended "experiment of its own".

### WR-09: The store's three `unavailable` exits are untested despite a seam extracted to test them

**File:** `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift:116-147`;
`AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift:75-94`
**Issue:** `ContinuedTaskScheduling` was extracted precisely so "every lifecycle case drives the
store through a double" (`ContinuedTaskScheduling.swift:6-11`), yet `ContinuedTaskSchedulingSpy`
hard-codes `register` to `true` and a non-throwing `submit`, and nothing covers the
nil-bundle-identifier branch. Those three paths encode a non-obvious contract nothing pins: unlike
the re-entry refusal (which returns `nil`), they return a **non-`nil`** `BackgroundProcessingSession`
whose stream is already finished with a buffered `.unavailable` and whose store-side `sessionID` is
already `nil`. The coordinator then records `continuedClientSessionID` for a session the store no
longer holds and keeps `hasLiveContinuedSession == true` until the consuming task drains the
buffered event — a window in which another tap's `ensureContinuedSession()` folds into a dead
session. Simulator runs take this path on every launch.
**Fix:** parameterize the spy (`registerResult: Bool`, `submitError: (any Error)?`) and add a case
per exit asserting `cancelledIdentifiers.isEmpty` (no request was left pending), that the stream
yields exactly `[.unavailable]` and finishes, and that a subsequent `start` is granted.

### WR-10: Dead state in the client spy

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift:157, 295, 308`
**Issue:** `State.inFlightProgressUpdate` is written on entry to `updateProgress` and cleared on
exit, but never read by any accessor or assertion. It is also a single slot shared by concurrent
pushes (`testAHeldProgressPushCannotRepaintASuccessorSessionsCard` has two in flight at once), so it
could not report anything reliable even if a reader were added.
**Fix:** delete the property and its two writes, or expose the accessor the gated cases apparently
wanted (`var inFlightProgressUpdate: ProgressUpdate?`) and assert on it.

### WR-11: `DownloadContinuedSessionTests.swift` is one line from breaking the build *(already tracked)*

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift:999`
**Issue:** Confirmed independently — the file is at 999 lines against `file_length: error: 1000`.
Three sibling suites (`...IdentityTests`, `...InterleaveTests`, `...LedgerTests`) exist solely
because of this ceiling, and each re-derives fixture setup. Spawning one suite per gap round is a
slow-motion duplication problem rather than a solved one.
**Fix:** move a coherent group out rather than adding a fifth suite next round — the expiration
cases (`testExpirationLeavesTheQueueInThePerGalleryPauseBaselineState`,
`testExpirationLeavesTheSchedulingBlockedSetAsAPauseDoes`,
`testExpirationResultIsIndependentOfEnqueueOrder`,
`testEndedSessionReceivesNoFurtherUpdateOrCompletion`) are self-contained and reclaim roughly 150
lines.

## Note on known items

- SC2 (present-behavior on a physical device) remains deliberately unverified, and CR-01 and WR-04
  are both properties of the card the user actually sees, so the open physical-device UAT item is
  the only thing that can close them observationally. The D-G2B-01 fix's premise — that iOS renders
  the last-pushed subtitle in the completed card at all — is itself unverified.
- WR-11 restates the tracked file-length ceiling; it is included because CR-01's and CR-02's
  regression cases will need somewhere to live.

---

_Reviewed: 2026-08-04_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
