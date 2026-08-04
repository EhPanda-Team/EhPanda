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
  warning: 17
  info: 0
  total: 18
status: issues_found
---

# Phase 15: Code Review Report (re-review)

**Reviewed:** 2026-08-04
**Depth:** standard
**Files Reviewed:** 35
**Status:** issues_found

> Severity mapping: **BLOCKER** findings are recorded under the canonical `critical:` frontmatter
> key and carry `CR-` ids. **WARNING** findings carry `WR-` ids.

## Summary

This is a re-review after gap plans 15-23 (G-15-3) and 15-24 (G-15-4). Both previously reported
blockers are genuinely closed, verified against source rather than against the summaries. Two
carry-over warnings from the previous round — the mis-stated suspension in the D-G2B-01 doc block,
and the atomic client-seam double — are also genuinely closed.

The re-review nevertheless finds one new **BLOCKER** that 15-24 introduced. D-G4-01 zeroes a
schedulable gallery's session page count whenever its record reads complete, and grants trust only
from `SchedulableSnapshot.incompleteGalleryIDs` — that is, only when the *manifest* reads
incomplete. A `.repair` never rewrites the manifest (`shouldReuseWorkingFolder` returns `true` for
`.repair`, so `ensureWorkingManifest` returns the existing complete manifest untouched), so a repair
of a complete-reading record can never earn trust and reports a numerator of zero for its entire
run. The prior defect was a card pinned at 100%; on this route the fix replaced it with a card
pinned at 0%, which is strictly worse against the exact stall heuristic the module's own doc names
(D-11: the scheduler force-expires the tasks reporting the *least* progress, and expiration pauses
every schedulable download). That attacks SC1 liveness, not only SC2 honesty.

The remaining findings are seventeen warnings: four new consequences of the two fixes and of the new
scheduling tail, four independently derived, and nine still-open carry-overs from the previous round
(recorded again because they are unfixed, not because they are new).

Checked and clean: localization (`continued_session.*` uses named numeric substitutions in every
locale, `en`/`de` category sets match, `ja`/`ko`/`zh-Hans`/`zh-Hant` are `other`-only, all six
locales present for every key); SwiftLint budgets (no line over 120 characters in any reviewed file,
no `swiftlint:disable`, no `@unchecked Sendable`, no `nonisolated(unsafe)`, no `try?` or force
unwrap in any changed file); the log-privacy masking conversions in `+Folders`, `+Persistence` and
`+ResponseValidation`; and the `BGTaskSchedulerPermittedIdentifiers` wildcard, which matches the
runtime identifier `ContinuedProcessingSession` mints from `Bundle.main.bundleIdentifier`.

### Verification of the two claimed invariants

- **D-G3-01 (teardown only over a still-true justifying observation) — verified.**
  `DownloadClient+ContinuedSession.swift:376-389` runs deferral, push, ownership re-check,
  drain-ness re-check, teardown, completion in that order. The re-check's stated non-suspension
  dependency holds against source today: `hasPendingWork()`
  (`DownloadClient+PendingWork.swift:10-15`) reads `activeTask`, then `queueStore.gids`
  (`DownloadQueueStore.swift:15-17`, a synchronous `Shared` read), then `indexedDownloads`
  (`DownloadClient+Persistence.swift:36-57`), none of whose bodies contain a cross-actor `await`.
  The captured `clientSessionID` cannot go stale behind the push while `continuedSessionID` holds,
  because the only writer of `continuedClientSessionID` mints a fresh coordinator session id first.
  I re-walked the other teardown sites (`:196`, `:220`, `:256`, `:262`) and agree each is either
  suspension-free after its observation or defended by `markContinuedSessionEnded`'s own identity
  guard. The always-suspending spy (`DownloadFeatureTestSupportTypes.swift:257, 294, 325`) is real:
  all three endpoints yield before recording.
- **D-G4-01 (session basis for progress arithmetic) — implemented as written, but the written rule
  is too narrow.** The predicate (`:107-111`) and the retirement gate (`:458-471`) read the record
  and the trust set and nothing else; no `queuedModes` read survives in `schedulableSnapshot()`; the
  trust set's four lifecycle sites are complete by inspection (`:181`, `:213`, `:289`, `:478`); and
  the numerator is summed from the same map the ledger observes. The hole is not in the
  implementation of the rule but in the rule itself — see CR-01.

## Critical Issues

### CR-01: A repair of a complete-reading record reports zero progress for its entire run, producing the stalled-task signal D-11 punishes

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:107-111`,
`:123`, `:458-462`; `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:281-282`,
`:245-262`; `AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift:45-95`

**Issue:** D-G4-01's zero branch fires for any schedulable gallery whose record reads complete, and
the only way out of it is `observedIncompleteSessionGIDs`, fed exclusively from
`SchedulableSnapshot.incompleteGalleryIDs` — `Set(downloads.filter(\.isIncomplete).map(\.gid))`
(`:123`). `isIncomplete` is `completedPageCount < pageCount` on the *manifest*
(`DownloadedGallery+SupportTypes.swift:91`, `DownloadedGallery+Manifest.swift:67`), i.e. the count of
non-empty page hash entries.

A `.repair` never makes that count drop:

- `shouldReuseWorkingFolder` returns `true` unconditionally for `.repair`
  (`DownloadClient+ExecutionSupport.swift:281-282`), so the working folder survives.
- `ensureWorkingManifest` then finds a `validatedManifest` (same gid, same page count) and returns it
  verbatim (`:245-262`; `DownloadClient+PersistenceNormalize.swift:6-20`). No fresh all-empty-hash
  manifest is written — unlike `.redownload` / `.update`, which delete the folder first and therefore
  go incomplete within seconds of the tap.
- Nothing else blanks hashes for pages whose files vanished: `sanitizeLocalFilesIfNeeded`
  (`DownloadClient+PersistenceHelpers.swift:7-40`) only re-scans, and the repair's own flushes call
  `refreshManifestPageFileHashes`, which writes *non-empty* hashes.

So for the whole repair, `download.isIncomplete == false`, the gid is never admitted to the trust
set, its session count is `0`, and `lastPushedCompletedPageCount` stays at `0`. Every push during the
repair reports `0 / N`. When it departs, the untrusted branch at `:458-462` retires
`observedSchedulablePages[gid] ?? 0`, which the basis already made `0`, so the terminal push reads
`0 / 1 page · 0 galleries` and `finish(_, true)` reports success for a session that never moved.

The route is reachable from product UI, not a synthetic state:
`DownloadsFeature/DownloadInspectorReducer.swift:169` sends `retryPages`, which resolves `resumeMode`
to `.repair` for a completed gallery whose files are missing, sets `queuedModes[gid] = .repair`,
schedules, and then calls `ensureContinuedSession()`
(`DownloadClient+RetryHelpers.swift:62-71`). `effectiveRetryMode` leaves `.repair` alone unless the
gallery has an update (`DownloadClient+SchedulingHelpers.swift:68-76`).

Why this is a blocker rather than an under-report: the file's own D-G4-01 doc states the harm model —
"the pinned card the retirement ledger exists to prevent … one the scheduler reads as a stalled task
before it force-expires the least-progressing ones" (`:85-88`). A card pinned at zero is the
*maximally* stalled reading, so this route moved from "most likely to be kept" to "first to be
terminated", and `handleContinuedSessionEvent`'s `.expired` branch responds by pausing every
schedulable download (`:254-257`). None of the four new ledger cases covers it: the one case that
exercises trust (`testARedoObservedRunningEarnsItsRecordBackAtTheDrain`,
`DownloadContinuedSessionLedgerTests.swift:549-581`) manufactures incompleteness by hand via
`patchManifest(of:completedPageCount:in:)` — exactly the step a repair never performs.

**Fix:** trust must be earned from an observation of *work*, not from the record's incompleteness,
and the count must come from a measure the repair actually moves. Both are already available. Admit
the gid at the flush that proves it wrote pages:

```swift
// DownloadClient+Persistence.swift, flushDownloadProgress — this gid just wrote pages.
observedIncompleteSessionGIDs.insert(context.gid)
if let continuedSessionID {
    await pushContinuedSessionProgress(sessionID: continuedSessionID)
}
```

and, in `schedulableSnapshot()`, count a trusted-but-complete-reading gallery from the pages whose
files exist rather than from the manifest's hash count, so a repair advances instead of jumping
straight to its ceiling:

```swift
let isSessionWork = download.isIncomplete
    || observedIncompleteSessionGIDs.contains(download.gid)
let completed = download.isIncomplete
    ? download.completedPageCount
    : min(download.localPageURLs.count, download.pageCount)
pages[download.gid] = isSessionWork ? completed : 0
```

Add a regression case that drives `retryPages` on a complete-reading record with a deleted page file
and asserts the pushed numerator strictly increases. Whichever shape is chosen, record the repair
route explicitly in the D-G4-01 doc block: it currently lists "a repair on a complete record" among
the routes the rule *covers* (`:83-88`), which reads as a claim that this case is handled.

## Warnings

### WR-01: The retirement doc still asserts an invariant D-G4-01 knowingly falsifies

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:406-411` vs
`:438-441`
**Issue:** Reason 3 of the D-G2-01 block states, unqualified, that symmetric retirement "is the only
rule under which the numerator never rewinds *and* the fraction reaches 1.0 exactly at queue drain."
D-G4-01's accepted residual, thirty lines below in the same doc comment, breaks the second half:
`testCancellingANeverStartedUpdateRetiresNothing`
(`DownloadContinuedSessionLedgerTests.swift:477-481`) pins a drain at `0 / 1 page · 0 galleries`, and
the ledger suite's own `expectTheFractionReachesOneOnlyAtTheDrain` helper is deliberately not applied
to it. A reader who takes reason 3 at face value will read a 0-of-1 drain as a defect, and a future
change may "restore" the invariant by re-introducing the over-retirement 15-24 removed.
**Fix:** qualify reason 3 in place: "…and the fraction reaches 1.0 exactly at queue drain for every
gallery this session observed doing work; a never-trusted departure retires zero and can leave the
drain below one (D-G4-01)."

### WR-02: The monotonic numerator floor does not survive the seam it is pushed through

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:531-548`;
`AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift:164-179`
**Issue:** `lastPushedCompletedPageCount` is applied and stored *before* the suspension, then the
pair crosses `updateProgress`'s main-actor hop. Two pushes are routinely in flight at once — the
page-flush push from inside `activeTask` (`DownloadClient+Persistence.swift:223-225`) and a
convergence push from a `Task` spawned by `finishActiveTaskIfOwned`
(`DownloadClient+Execution.swift:254-270`) or from a user-initiated tap chain. Those tasks carry
different priorities, so the main-actor executor is not obliged to run their jobs in enqueue order.
The store then applies whatever arrives last unconditionally (`lastCompletedUnitCount = …`,
`task.progress.completedUnitCount = …`) because its contract says "the caller owns clamping and
monotonicity" — and the caller's guarantee ends at the suspension. The result is a card that can step
backwards, which the same file calls out as the one movement the scheduler reads as a task losing
ground (`:492-497`).
**Fix:** make the guarantee survive the hop. Either serialize pushes behind a coordinator-held
"push in flight" flag that coalesces a second request into a follow-up push, or move the floor to the
only place that sees the delivery order — clamp in the store
(`completedUnitCount = max(lastCompletedUnitCount, completedUnitCount)`) and amend the endpoint doc
to say the store owns monotonicity while the caller owns the basis.

### WR-03: The post-start seeding overwrites observations made inside the start window

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:208-213`
**Issue:** Both `observedSchedulablePages` and `observedIncompleteSessionGIDs` are *assigned* from
`snapshot`, computed before the suspending `backgroundProcessingClient.start`. A push landing inside
that window does reach `reconcileRetiredSessionPages` — the doc at `:509-513` says that is
deliberate, "a departure during the start window must still be recorded even when there is no card
to paint yet" — and it mutates exactly those two fields. The assignment then discards everything that
push learned and replaces it with the pre-hop values. The accompanying comments justify the
*position* of the seeding (after the ownership guard, so a superseded start seeds nothing) but say
nothing about the overwrite, so the two statements read as though they cover the whole behavior. The
practical effect is a widened D-G4-01 residual: a redo that went incomplete inside the start window
silently loses the trust it had just earned.
**Fix:** merge instead of replace, and say why:
`observedSchedulablePages.merge(snapshot.finishedPages, uniquingKeysWith: { observed, _ in observed })`
and `observedIncompleteSessionGIDs.formUnion(snapshot.incompleteGalleryIDs)`, with a comment stating
that a push inside the start window is a real observation and outranks the pre-hop snapshot.

### WR-04: `commitPause`'s non-pausable exit converges while the gallery is still scheduling-blocked

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:194-211`
**Issue:** `schedulingBlockedGalleryIDs.insert(gid)` is released by a `do`-scoped `defer`, so the
early return for a download that is neither `.queued` nor `.active` (`:205-211`) calls
`notifyObservers()` and `scheduleNextIfNeeded()` while the block is still held. Every other failure
path in the module releases the block first and says why — `delete`
(`DownloadClient+PublicAPI.swift:210-214`), `deleteFolder` (`DownloadClient+Folders.swift:118-124`) —
under the stated rule "release the failed gallery before converging or the scheduler would silently
skip it". This exit is the one place that does not. It matters more than before this phase, because
`scheduleNextIfNeeded` now also runs `reconcileContinuedSession()` (`:34-35`): a blocked gallery is
filtered out of `schedulableDownloads()`, so if it is the last schedulable item the reconcile
observes a false drain and completes the live session over work that becomes schedulable again
microseconds later, when the `defer` fires. The reachable shape is an `.inactive` gallery carrying a
`queuedPageSelections` entry that has not yet landed in the persisted queue — the window
`nextUnqueuedSchedulableDownload`'s own comment describes (`:99-101`).
**Fix:** release before converging, exactly as the two sibling paths do:
```swift
guard [.queued, .active].contains(currentDownload.displayStatus) else {
    schedulingBlockedGalleryIDs.remove(gid)
    await notifyObservers()
    await scheduleNextIfNeeded()
    return .settled(.success(()))
}
```

### WR-05: `finish(_:success:)` is hard-coded to `true` on every exit *(carry-over, unfixed)*

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:203, 389`
**Issue:** Unchanged since the previous round, and 15-24 makes it worse: the drain now also reports
`success: true` for a session whose numerator never left zero
(`DownloadContinuedSessionLedgerTests.swift:481`). That value reaches
`BGContinuedProcessingTask.setTaskCompleted(success:)`, the system's own signal of whether the work
finished, and nothing in the file documents why `true` is unconditional.
**Fix:** derive it at the call site — the terminal push already knows the pair it pushed, so
`finish(clientSessionID, pushedCompleted >= pushedTotal)` needs no new state — or state on
`reconcileContinuedSession` why `true` is correct for every exit, including the superseded rollback
at `:203`.

### WR-06: The terminal push can rewind the card's denominator to the one-page floor *(carry-over, unfixed)*

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:531-542`
**Issue:** The floor protects only the numerator; the denominator is
`max(sessionProgress.displayPageCount, completedPageCount)` and `displayPageCount` floors an empty
sum at 1. A paused 12-page download that finished nothing takes the card from
"0 / 12 pages · 1 gallery" to "0 / 1 page · 0 galleries". The new cases lock more of these in
(`"1 / 1 page · 0 galleries"` at `DownloadContinuedSessionInterleaveTests.swift:173-175`, and the
0-of-1 drain above), so the shape is now pinned by literals in four suites while still not argued
for anywhere.
**Fix:** either floor the denominator too (`max(lastPushedPageCount, …)`) or give the drained state
its own subtitle key with no gallery clause, and record the reasoning beside the clamp — the current
comment explains only the numerator.

### WR-07: The drained-session log cannot make the distinction it exists for *(carry-over, unfixed)*

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:385`
**Issue:** The notice is still emitted unconditionally after `pushContinuedSessionProgress` returns.
The push can be dropped at four internal guards (`:515`, `:517`, `:519`, `:524`) and again inside the
store (`ContinuedProcessingSession.swift:170`, `:173`), so the line can claim "terminal progress
pushed" when nothing reached the card. 15-23 moved the line behind the drain-ness re-check, which
fixed a different ambiguity — it no longer fires for a drain that gets deferred — but not this one.
**Fix:** make `pushContinuedSessionProgress` `@discardableResult … -> Bool` returning `false` at each
early guard, and log `"… terminal progress \(pushed ? "pushed" : "skipped", privacy: .public)."`.

### WR-08: The session-scoped reset block still omits the reconciliation debt *(carry-over, unfixed)*

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:176-181`
**Issue:** The block now zeroes five fields — 15-24 added `observedIncompleteSessionGIDs` to it — but
`continuedSessionNeedsReconciliation` is still not among them. It is safe only because
`markContinuedSessionEnded` (`:283`) clears it and the `!hasLiveContinuedSession` guard implies
teardown ran: an invariant maintained two hops from where it is relied on, on a reentrant actor where
every sibling field is now defended directly.
**Fix:** add `continuedSessionNeedsReconciliation = false` to the same synchronous block so the reset
is complete by inspection.

### WR-09: Session lifecycle state is unconditionally `public var`, and 15-24 widened the surface *(carry-over, unfixed)*

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:386-451`
**Issue:** Nine stored properties that the continued-session file spends ~550 lines defending are
`public var` on a `public actor`, so any module linking `DownloadClient` can write them.
`observedIncompleteSessionGIDs` (`:451`) was added to that set by 15-24 — a trust set whose entire
value is that it can only be earned. Meanwhile `DownloadClient+Testing.swift:53-64` wraps
`hasLiveContinuedSession` and `continuedSessionID` in `#if DEBUG` accessors, which is only meaningful
if the stored properties are not already public.
**Fix:** demote the set to `internal` (or `private(set)`) and expose the one value tests read
directly (`continuedSessionTask`) through the existing `#if DEBUG` seam.

### WR-10: `UIBackgroundModes: processing` is retained on a justification that understates the cost *(carry-over, unfixed)*

**File:** `App/Info.plist:160-169`
**Issue:** The comment argues that "an unnecessary declaration costs one stray key". App Review
Guideline 2.5.4 rejects apps declaring background modes they do not use, and this phase deleted the
only tier that used `processing`; the documented requirement for a continued-processing submission is
`BGTaskSchedulerPermittedIdentifiers`, already declared at lines 5-8. The asymmetry runs the opposite
way from what the comment claims.
**Fix:** keep the key until the device experiment settles it if you must, but correct the comment to
name the real cost and tie the removal to the already-open SC2 physical-device UAT item rather than
to an open-ended "experiment of its own".

### WR-11: The store's three `unavailable` exits remain untested despite a seam extracted to test them *(carry-over, unfixed)*

**File:** `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift:116-147`;
`AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift:74-92`
**Issue:** `ContinuedTaskSchedulingSpy` still hard-codes `register` to `true` and a non-throwing
`submit`, and nothing covers the nil-bundle-identifier branch. Those three exits return a
**non-`nil`** session whose stream is already finished with a buffered `.unavailable` and whose
store-side `sessionID` is already `nil`, so the coordinator records `continuedClientSessionID` for a
session the store no longer holds and keeps `hasLiveContinuedSession == true` until the consuming
task drains the buffered event. Simulator runs take this path on every launch.
**Fix:** parameterize the spy (`registerResult: Bool`, `submitError: (any Error)?`) and add a case
per exit asserting `cancelledIdentifiers.isEmpty`, that the stream yields exactly `[.unavailable]`
and finishes, and that a subsequent `start` is granted.

### WR-12: Dead state in the client-seam spy *(carry-over, unfixed)*

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift:163, 303, 316`
**Issue:** `State.inFlightProgressUpdate` is written on entry to `updateProgress` and cleared on exit;
a tree-wide grep confirms it has no reader anywhere. It is also a single slot shared by concurrent
pushes, so it could not report anything reliable even if a reader were added. 15-23 edited this exact
closure to add `Task.yield()` and left the dead slot in place.
**Fix:** delete the property and its two writes.

### WR-13: `DownloadContinuedSessionTests.swift` remains one line from a build failure *(carry-over, unfixed)*

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift`
**Issue:** Confirmed independently at 999 lines against `file_length: error: 1000`. Both gap rounds
recorded holding the file at exactly 999 as a success criterion, and 15-23 explicitly declined the
sanctioned relocation because nothing forced it. Four sibling suites now exist only because of this
ceiling, each re-deriving fixture setup — spawning one suite per gap round is a slow-motion
duplication problem rather than a solved one, and CR-01's regression case needs somewhere to live.
**Fix:** move a coherent group out rather than adding a fifth suite — the four expiration cases are
self-contained and reclaim roughly 150 lines.

### WR-14: The spy's one-shot start refusal is consumed by an unrelated guard failure

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift:264-268`
**Issue:**
```swift
guard $0.currentSessionID == nil, !$0.refusesNextStart else {
    $0.refusesNextStart = false
    return true
}
```
The `else` branch clears the one-shot flag on *either* failure. A case that arms `refuseNextStart()`
while a session is still held has its armed refusal silently consumed by the single-session guard,
and the next start — the one the case meant to refuse — is granted. The double then diverges from the
live store, whose re-entry guard and refusal are independent
(`ContinuedProcessingSession.swift:85-87`). This is latent today only because the single call site
arms the flag with no session live.
**Fix:** separate the two conditions:
```swift
guard $0.currentSessionID == nil else { return true }
guard !$0.refusesNextStart else {
    $0.refusesNextStart = false
    return true
}
```

### WR-15: The new regression case polls for an exact push count

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift:150`
**Issue:** `try await waitUntil { spy.progressUpdates.count == 2 }` polls every 10 ms for a strict
equality. The two pushes it waits for come from two independently spawned tasks (the retry's own
convergence and the inert runner's completion tail); if a third convergence ever lands, or if the
count is only sampled once both plus a successor have run, the predicate can never hold again and
`waitUntil` fails on its timeout with "Timed out waiting for condition" rather than on the real
assertion. 15-23's own deviation note says the pinned sequence had to be raised from three entries to
four because an extra convergence turned out to exist — evidence that the exact count is not a
property of the subject under test.
**Fix:** wait on `spy.progressUpdates.count >= 2`, and let the exact sequence assertion at `:164-177`
remain the thing that pins the count.

### WR-16: The untrusted-departure branch reads as a computation but is provably a constant zero

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:458-462`
**Issue:** `retiredSessionPages[gid] = observedSchedulablePages[gid] ?? 0` in the untrusted branch can
only ever assign `0`. `observedSchedulablePages` and `observedIncompleteSessionGIDs` are written from
the same snapshot at both write sites (`:210-213`, `:475-478`), and that snapshot gives a nonzero
count only to a gid it simultaneously admits to the trust set (`:107-111`, `:123`), so a gid outside
the trust set always has an observed value of `0`. The comment beside it — "retire what was observed,
which the basis made zero" — states the constant, and then the code recomputes it, which invites a
future reader to conclude the two maps can disagree.
**Fix:** write `retiredSessionPages[gid] = 0` and keep the comment as the proof that this equals the
last observation, or express the pairing as an assertion so it is enforced rather than argued.

### WR-17: The topology-invariant suite scans the compile machine's filesystem

**File:** `AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift:189-208, 227-256`
**Issue:** `repositoryRoot()` walks up from `#filePath` and both tests then read every Swift file
under four directories from disk at run time. The suite therefore passes or fails on properties of
the machine that *compiled* it: it cannot run from a built `.xctestrun` on another machine, it breaks
if the checkout is moved or renamed after building, and it reads the whole source tree twice per run.
It is also blind to what it does not enumerate — `AppPackage/Package.swift`, `EhPanda.xcodeproj`, the
extension's `Info.plist` and every `.xcstrings` are outside `scannedDirectories`, so a deleted
spelling returning in a manifest or a project file passes silently.
**Fix:** move this to a build-phase or CI grep gate, where a source-tree scan belongs; or at minimum
widen `scannedDirectories` to cover the package manifest and the project file, and document that the
suite is checkout-local by construction.

## Note on known items

- SC2 (present-behavior on a physical device) remains deliberately unverified. CR-01, WR-02 and WR-06
  are all properties of the card the user actually sees, so the open physical-device UAT item is the
  only thing that can close them observationally — and the UAT's newly added observation ("a queued
  update no longer opens the card at 100%") will not catch CR-01, because a repair is a different
  tap.
- Nine of the seventeen warnings (WR-05 through WR-13) are carry-overs recorded verbatim in the
  previous round and declared out of scope by both gap plans. They are restated here because this
  report replaces that one, not because they are new.

---

_Reviewed: 2026-08-04_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
