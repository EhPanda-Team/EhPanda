---
phase: 15-continued-background-downloads
reviewed: 2026-07-28T05:36:57Z
depth: standard
files_reviewed: 25
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
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift
findings:
  critical: 1
  warning: 7
  info: 9
  total: 17
status: issues_found
---

# Phase 15: Code Review Report (re-review after gap closure)

**Reviewed:** 2026-07-28T05:36:57Z
**Depth:** standard
**Files Reviewed:** 25
**Status:** issues_found

## Summary

This is a re-review of Phase 15 after plans 15-08 and 15-09 landed to close the
session-lifecycle defects the first review found. Every prior finding was re-checked against
the tree, not against the summaries.

**Five of the six store/coordinator lifecycle fixes hold up under inspection.** CR-01, CR-02,
CR-03, WR-04 and WR-06 are genuinely resolved, and the scheduling seam
(`ContinuedTaskScheduling.swift`) is a real improvement rather than a testability veneer: it
confines every `BGTaskScheduler` verb to one value, makes the store's state machine drivable,
and the three new store cases in `ContinuedProcessingSessionTests.swift` pin behaviour that
would not hold without the fixes (the double `granted`, the uncompleted stray, the leaked seed
counts). `handleLaunch(_:expecting:)` / `adopt(_:expecting:)` complete every task they turn
away, which was the leak CR-03 named. The coordinator's per-session `UUID` is minted in the
same synchronous run as the liveness flag and is honoured at the teardown gate, the event gate
and the reconcile drain re-check. No `@unchecked Sendable`, no `nonisolated(unsafe)`, no
`@preconcurrency`, no `swiftlint:disable`, no force-unwrap and no over-length line appears
anywhere in the changed set.

**WR-01's fix, however, introduced a worse defect than the one it closed.**
`ensureContinuedSession()`'s new post-suspension bail-out calls
`backgroundProcessingClient.finish(true)` — and that seam carries no session identity, so it
completes *whatever session the store currently holds*, which under an ordinary three-step
interleave is a newer, live, correctly-owned session belonging to a different tap. The user's
second download tap then runs with no background coverage and no card, silently. That is CR-04
below, and it is a BLOCKER: it defeats the exact guarantee the phase exists to provide, and it
is a regression introduced by the gap-closure work rather than a pre-existing gap.

Two further live-session hazards remain in the same family: `pauseAllSchedulable()` is the one
teardown path whose per-iteration suspensions are *not* identity-gated (WR-08), and
`pushContinuedSessionProgress()` is the one lifecycle entry point still gated on the bare
liveness flag rather than the session id (IN-10). The 15-09 summary's claim that "the D-11
pause-all policy is fenced to the live session" is therefore true only for event *delivery*,
not for the pause loop itself.

Separately, a device-risk finding the previous review did not raise: `App/Info.plist` now
declares a **wildcard** permitted identifier, but the store registers a fresh **concrete**
launch handler for every session (WR-10). Apple's wildcard mechanism exists so an app
registers once and submits many; registering per-session concrete identifiers either fails
outright — in which case the feature is dead on device and silently so, because `.unavailable`
is silent by contract — or accumulates one permanently-unregisterable handler per session for
the process lifetime. Neither outcome is observable in the Simulator.

### Prior-finding disposition

| ID | Status | Evidence |
|----|--------|----------|
| CR-01 | **RESOLVED** | `pendingIdentifier` retained (`ContinuedProcessingSession.swift:48`, `:135`) and taken back in `endSession` (`:229`, `:237-239`); `ContinuedTaskScheduling.cancel` added (`ContinuedTaskScheduling.swift:57`, `:92-94`); pinned by `testEndedSessionCancelsItsPendingRequestAndALaterStartIsGranted`. |
| CR-02 | **RESOLVED** | `continuedSessionID` (`DownloadClient+Manager.swift:370`) gates `markContinuedSessionEnded(sessionID:)` (`DownloadClient+ContinuedSession.swift:160`) and `handleContinuedSessionEvent(_:sessionID:)` (`:129`); pinned by `testStaleTeardownDoesNotClearANewerSession`. |
| CR-03 | **RESOLVED** | `adopt(_:expecting:)` gate at `ContinuedProcessingSession.swift:187-190` completes every rejected task; the live seam completes an uncastable stray at `ContinuedTaskScheduling.swift:74`; pinned by `testAStaleLaunchIsCompletedAndNeverDisplacesTheAwaitedTask`. |
| WR-01 | **STILL OPEN (partially addressed; regressed)** | Doc comment corrected (`DownloadClient+Manager.swift:359-362`) and an ownership re-check added (`DownloadClient+ContinuedSession.swift:97-100`) — but the re-check's bail-out is untargeted. See **CR-04**. |
| WR-02 | **STILL OPEN — deferred by decision** | `hasPendingWork()` still re-implements the predicate inline (`DownloadClient+PendingWork.swift:16-18`) instead of calling `isSchedulableDownload`; `schedulableDownloads()` still `private` (`DownloadClient+ContinuedSession.swift:246`). Deferred per 15-09. |
| WR-03 | **STILL OPEN — deferred by decision** | `pauseAllSchedulable()` unchanged (`DownloadClient+ContinuedSession.swift:177-182`); each `pause` still tails into `scheduleNextIfNeeded()`. Deferred per 15-09. |
| WR-04 | **RESOLVED** | `cancelQueuedWorkItem`'s non-`.initial` branch now ends through `await scheduleNextIfNeeded()` (`DownloadClient+Scheduling.swift:225`); pinned by `testCancellingTheLastQueuedWorkItemCompletesTheSession`, which genuinely fails without it (pre-fix `finishCount` would be 0). |
| WR-05 | **STILL OPEN — owner-pending** | `BackgroundProcessingClientKey` and the `DependencyValues` accessor are still unreferenced tree-wide (verified: no `@Dependency(\.backgroundProcessingClient)` anywhere); the incorrect rationale at `DownloadClient+Manager.swift:305-308` is unchanged. Deliberately untouched by 15-09. |
| WR-06 | **RESOLVED** | Seed pair zeroed on the start path (`ContinuedProcessingSession.swift:82-84`); asserted by `testEndedSessionCancelsItsPendingRequestAndALaterStartIsGranted` (`ContinuedProcessingSessionTests.swift:172-173`). |
| WR-07 | **STILL OPEN — deferred by decision** | The blocking-fixture cases still cancel the runner with a trailing statement, not a `defer` (`DownloadContinuedSessionTests.swift:99`, `:122`, `:169`, `:193`, `:236`, `:690`). The two new cases added by 15-09 follow the same pattern (`:718`, `:756`), so the debt grew rather than shrank. |
| IN-01 | **STILL OPEN** | `import Foundation` still unused (`DownloadClient+PendingWork.swift:1`). |
| IN-02 | **STILL OPEN** | `// MARK: Test` still labels the `previewValue` (`BackgroundProcessingClient.swift:63`). |
| IN-03 | **STILL OPEN** | Single-literal-space token assembly unchanged (`BackgroundExecutionInvariantTests.swift:103`, `:107`). |
| IN-04 | **STILL OPEN** | CJK number/unit spacing still inconsistent across `ja`/`ko`/`zh-Hans`/`zh-Hant` (`Localizable.xcstrings:159`, `:173`, `:208`, `:222`, `:259`, `:273`, `:307`, `:321`). |
| IN-05 | **STILL OPEN** | The "queued GIDs or whole index" read is still copy-pasted three times (`DownloadClient+ContinuedSession.swift:247-250`, `DownloadClient+PendingWork.swift:12-15`, `DownloadClient+Scheduling.swift:26-29`). |
| IN-06 | **STILL OPEN** | `guard let self else { return }` still drops a launched task uncompleted (`ContinuedProcessingSession.swift:114`); the seam now hands in a fully-constructed `SystemContinuedTask`, so the leak is unchanged in shape. |

The two `deferred-items.md` entries (the missing Phase 16 progress row and the stale
execution-order line in `.planning/ROADMAP.md`) remain deliberately deferred and are not
re-raised here.

New in this pass: **CR-04**, **WR-08**, **WR-09**, **WR-10**, **IN-07**, **IN-08**, **IN-09**,
**IN-10**, **IN-11**.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-04: `ensureContinuedSession()`'s WR-01 bail-out completes whatever session the store holds, so it can kill a newer, live, correctly-owned session

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:97-100`; `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift:28`; `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift:161-163`, `:224-245`

**Issue:**
The gap-closure fix reads:

```swift
guard continuedSessionID == sessionID else {
    await backgroundProcessingClient.finish(true)
    return
}
```

and the doc comment above it claims the call completes "the client session `start` just
created". It does not, and it cannot: the seam is
`finish: @Sendable (_ success: Bool) async -> Void` (`BackgroundProcessingClient.swift:28`) with
**no session identity**, and `ContinuedProcessingSession.finish(success:)` forwards straight into
`endSession` (`ContinuedProcessingSession.swift:161-163`), which unconditionally tears down
whichever session the store is holding *at the moment the main-actor hop lands*. The coordinator
has no handle on "its own" client session, so the bail-out is an untargeted kill.

`ensureContinuedSession()` has exactly one real suspension point before that guard —
`await backgroundProcessingClient.start(...)` at line 87, a hop onto the `@MainActor` store.
(`await hasPendingWork()` and `await schedulableProgress()` are same-actor calls whose callees
never suspend, so they open no window today; see IN-11.) That one window is enough:

1. Tap 1 → `ensureA`: flag `true`, `continuedSessionID = X`, suspends inside `start` (main-actor
   hop **#1** enqueued).
2. A page finishes → `finishActiveTaskIfOwned`'s tail (`DownloadClient+Execution.swift:253-268`)
   runs `reconcileContinuedSession()` from a *different* task. The queue has drained, so it
   passes its own re-check, runs `markContinuedSessionEnded(X)` — flag `false`, id `nil` — and
   issues `await backgroundProcessingClient.finish(true)` (hop **#2**).
3. Tap 2 → `ensureB`: sees the flag `false`, sets flag `true`, `continuedSessionID = Y`, and
   issues its own `start` (hop **#3**).
4. The main actor runs the hops in order: #1 creates store session **A**; #2 ends **A**;
   #3 creates store session **B** and hands `ensureB` a live stream.
5. `ensureA` resumes. `continuedSessionID` is `Y`, not `X`, so it takes the bail-out and issues
   `finish(true)` (hop **#4**) — which **ends B**: `setTaskCompleted(success: true)` on B's
   system task, B's card removed, B's pending request cancelled, B's stream finished.
6. `ensureB` resumes, its re-check passes (`Y == Y`), and it installs a consuming task over a
   stream that is already finished. The loop exits immediately and tears the session down.

Net user-visible result: **tap 2 got no background coverage, no progress card, and no signal
that anything went wrong.** Backgrounding the app after that tap suspends the queue — the exact
failure this phase exists to prevent. The coordinator state is left self-consistent (flag
`false`), so the defect is invisible to every existing assertion; nothing recovers until the
user makes another qualifying tap.

The pre-fix code had a different bug here (it installed a consuming task for a session the
coordinator had abandoned). The fix replaced a stranded session with a *stolen* one, which is
strictly worse: the stranded session was eventually force-expired, whereas this one is destroyed
while the user is actively depending on it.

The root cause is that the client seam is session-blind. Every other lifecycle mutation in this
phase was given an identity in 15-09; `finish` was not.

**Fix:**
Give the seam a session handle so `finish` can only complete the session its caller started.
The store already mints a per-session identifier, so it costs nothing to surface:

```swift
// BackgroundProcessingClient.swift
public struct BackgroundProcessingSession: Sendable {
    public let id: UUID
    public let events: AsyncStream<BackgroundProcessingEvent>
}

public var start: @Sendable (_ title: String, _ subtitle: String) async
    -> BackgroundProcessingSession = { _, _ in
        .init(id: UUID(), events: AsyncStream { $0.finish() })
    }
/// Completes `sessionID` if — and only if — it is the session the store currently holds. A
/// caller that lost ownership across its own suspension must not be able to end a successor.
public var finish: @Sendable (_ sessionID: UUID, _ success: Bool) async -> Void
```

```swift
// ContinuedProcessingSession.swift
private var sessionID: UUID?          // set in start(), cleared in endSession()

public func finish(sessionID: UUID, success: Bool) {
    guard self.sessionID == sessionID else { return }
    endSession(yielding: nil, success: success)
}
```

```swift
// DownloadClient+ContinuedSession.swift
let session = await backgroundProcessingClient.start(...)
guard continuedSessionID == sessionID else {
    // Targeted: completes only the client session this call created, never a successor
    // another tap started while this one was suspended inside `start`.
    await backgroundProcessingClient.finish(session.id, true)
    return
}
```

`reconcileContinuedSession()`'s drain branch (line 200) must pass the same handle — store it
alongside `continuedSessionID` — otherwise it retains a narrower version of the same hazard
(see WR-09).

A regression case is now cheap and deterministic, because `BackgroundProcessingClientSpy`
already records every `start`: assert that a `finish` issued by a bail-out never lands on the id
the most recent `start` returned.

## Warnings

### WR-01: the post-suspension ownership re-check does not cover the reverse ordering, and a losing `ensure` can still cost a tap its session

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:91-100`, `:193-204`

**Issue:** Even with CR-04 fixed, the store's single-session re-entry guard
(`ContinuedProcessingSession.swift:75`) refuses any `start` that lands while a previous session
is still held. In the trace above, if hop #3 lands before hop #2, `ensureB` is handed an
already-finished stream, its ownership re-check *passes* (`Y == Y`), and it installs a consuming
task that immediately tears the session down. Tap 2 again silently gets nothing. The coordinator
cannot distinguish "the store started my session" from "the store refused me", because `start`
returns the same type either way.

This is the residual of the original WR-01(b) — that finding called out that "`finish` and
`start` are two independent hops onto the `@MainActor` store from two different tasks, so their
relative order is not guaranteed". The 15-09 summary marks WR-01 "Incorporated"; only the
ownership half was.

**Fix:** With CR-04's session handle in place, make refusal observable and retryable rather than
silent — for example have `start` return `nil` (or a `.refused` handle) when the re-entry guard
fires, and have `ensureContinuedSession()` roll its own bookkeeping back on refusal so the next
queue-mobilizing moment can legitimately try again:

```swift
guard let session = await backgroundProcessingClient.start(...) else {
    // The store still holds a predecessor whose `finish` has not landed yet. Roll our own
    // bookkeeping back so a later mobilizing moment can start a real session.
    guard continuedSessionID == sessionID else { return }
    markContinuedSessionEnded(sessionID: sessionID)
    return
}
```

---

### WR-08: `pauseAllSchedulable()` is the one teardown path with no identity gate, so an expiration can pause work a *newer* session covers

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:134-137`, `:177-182`

**Issue:** `handleContinuedSessionEvent(.expired, …)` deliberately clears the session *before*
pausing (line 136), then runs:

```swift
public func pauseAllSchedulable() async {
    let gids = await schedulableDownloads().map(\.gid)
    for gid in gids {
        _ = await pause(gid: gid)          // genuinely suspends: queueStore.remove -> save()
    }
}
```

Each `pause(gid:)` suspends for real — `queueStore.remove(_:)` awaits `Shared.save()`, i.e. file
I/O (`DownloadQueueStore.swift:31-36`). Because liveness was already cleared, a queue-mobilizing
tap arriving inside that loop passes `ensureContinuedSession()`'s guard and starts session S2.
The loop then keeps pausing galleries off its pre-loop snapshot — including galleries S2 was just
started to cover — and each `pause` tails into `scheduleNextIfNeeded()` →
`reconcileContinuedSession()`, which completes S2 the moment the loop empties the schedulable
set. The user's brand-new download is paused and their new card dismissed by an expiration
belonging to a session that no longer exists.

The 15-09 summary states that "the D-11 pause-all policy is fenced to the live session". That is
true of event *delivery* only — the gate is at `handleContinuedSessionEvent`'s entry (line 129),
and nothing re-checks anything for the rest of the loop. This is the same class of defect CR-02
fixed for teardown, left unfixed for the policy that teardown exists to run.

**Fix:** Carry the id into the loop and stop the moment it is no longer the reason the loop is
running:

```swift
/// Bound to the session whose expiration asked for it: a tap can legitimately start a
/// successor inside this loop's per-gallery suspensions, and pausing that successor's work
/// would undo a user action with no expiration behind it.
public func pauseAllSchedulable(expiring sessionID: UUID) async {
    let gids = await schedulableDownloads().map(\.gid)
    for gid in gids {
        guard continuedSessionID == nil || continuedSessionID == sessionID else { return }
        _ = await pause(gid: gid)
    }
}
```

(WR-03's batch-blocking flag, when it lands, is the natural place to hang this check.)

---

### WR-09: `reconcileContinuedSession()`'s drain branch calls the same session-blind `finish`

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:193-204`

**Issue:** The drain branch is careful about *coordinator* state — it binds `sessionID`,
re-checks it, and calls `markContinuedSessionEnded(sessionID:)` before completing — and then
throws all of that away at line 200 with a bare `await backgroundProcessingClient.finish(true)`.
Between `markContinuedSessionEnded` (synchronous) and the main-actor hop actually landing, the
coordinator actor is free to run another task: a tap's `ensureContinuedSession()` sees the flag
`false`, mints `Y`, and enqueues its own `start`. Whichever hop lands first decides whether the
reconcile's `finish` ends the session it meant to end or the one the tap just asked for.

Today the blast radius is smaller than CR-04's (the tap's `start` is normally enqueued after the
`finish`), but it is the same missing invariant, and it will silently become CR-04-shaped the
moment anything adds a suspension between the drain check and the completion.

**Fix:** Pass the session handle from CR-04's fix:

```swift
markContinuedSessionEnded(sessionID: sessionID)
await backgroundProcessingClient.finish(clientSessionID, true)
```

storing `clientSessionID` beside `continuedSessionID` when `ensureContinuedSession()` receives it
from `start`.

---

### WR-10: a wildcard permitted-identifier is declared but a fresh concrete launch handler is registered per session

**File:** `App/Info.plist:5-8`; `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift:108-124`; `AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift:66-80`

**Issue:** The plist now declares one wildcard entry:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER).continued.*</string>
</array>
```

but the store mints a concrete identifier per session and registers a **new launch handler for
that concrete identifier** on every `start(...)`:

```swift
let identifier = "\(bundleIdentifier).continued.\(UUID().uuidString)"
let registered = scheduling.register(identifier) { [weak self] task in … }
```

The wildcard facility exists precisely so an app registers *one* handler against the pattern and
then submits many uniquely-identified requests behind it — which is also what makes the store's
own constraint ("handlers can never be unregistered and the system kills the app on a second
registration of the same identifier") tractable. The current shape has two possible outcomes,
neither verified:

1. The scheduler rejects registration of a concrete identifier that is not itself listed in
   `BGTaskSchedulerPermittedIdentifiers`. `register` returns `false`, the store logs and yields
   `.unavailable` (lines 120-124) — and `.unavailable` is *silent by contract*
   (`DownloadClient+ContinuedSession.swift:138-142`). The feature would be dead on every device
   with no user-facing symptom and no failing test, because the Simulator cannot distinguish
   that from its own lack of background-processing support.
2. Registration succeeds, and the process accumulates one permanently-unregisterable handler,
   plus its retained identifier string and closure, for every download session in its lifetime
   (see IN-07).

Registration also happens lazily at session start rather than before
`application(_:didFinishLaunchingWithOptions:)` returns, which is the placement
`BGTaskScheduler.register` documents.

**Fix:** Register once, against the wildcard, and keep submitting per-session UUIDs:

```swift
private static let wildcardIdentifier = "\(bundleIdentifier).continued.*"
private var didRegisterLaunchHandler = false

// A wildcard handler is registered exactly once and covers every per-session identifier
// submitted behind it. Registering the concrete identifiers instead would either be refused
// outright or accumulate one unremovable handler per session.
if !didRegisterLaunchHandler {
    didRegisterLaunchHandler = scheduling.register(Self.wildcardIdentifier) { [weak self] task in
        self?.handleLaunch(task)
    }
}
```

`handleLaunch`'s identity check must then compare `pendingIdentifier` against the *launched
task's own* identifier rather than the registered one, which means the seam has to surface it.
**This must be verified on an iOS 26 device before the phase ships** — it is the one assumption
in the whole design that no test in the repository can reach.

---

### WR-02: `hasPendingWork()` and `schedulableDownloads()` still disagree

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift:9-19`; `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:246-252`

**Issue:** Unchanged from the previous review, and deferred by decision in 15-09.
`hasPendingWork()` short-circuits on `activeTask != nil` and then re-implements the predicate
inline rather than calling the `isSchedulableDownload` that was made internal at
`DownloadClient+Scheduling.swift:105` explicitly so a second predicate could not exist. Recorded
here only so it does not fall off the ledger; the original finding text stands verbatim.

**Fix:** As previously written — make `hasPendingWork()` delegate to `schedulableDownloads()` and
raise that helper from `private` to internal.

---

### WR-03: `pauseAllSchedulable()` still re-schedules every gallery it is about to pause

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:177-182`

**Issue:** Unchanged, deferred by decision in 15-09. Each `pause(gid:)` tails into
`scheduleNextIfNeeded()`, which installs an `activeTask` for the next gallery in the same
snapshot — so an expiration performs N-1 scheduling cycles, each spawning a live HTTP request to
a rate-limiting host and then cancelling it, after the system has signalled that it is
reclaiming the process. Recorded so it does not fall off the ledger.

**Fix:** As previously written — gate `scheduleNextIfNeededCore()` on a batch flag for the
duration of the loop. WR-08's identity check belongs in the same edit.

---

### WR-07: blocking-fixture cases still leak a forever-spinning task on early failure, and two more were added

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift:99`, `:122`, `:169`, `:193`, `:236`, `:690`, `:718`, `:756`; `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift:329-336`

**Issue:** Unchanged in substance, deferred by decision — but the debt grew. The runner installed
by `makeBlockingCoordinator` spins on `while !Task.isCancelled` and is only stopped by the
trailing `_ = await context.manager.pause(gid: gid)` at the end of each case, which any earlier
throwing `#require` / `try … .get()` skips. `testStaleTeardownDoesNotClearANewerSession`
(line 718) and `testCancellingTheLastQueuedWorkItemCompletesTheSession` (line 756) both adopt the
same pattern, and both have throwing statements above their cleanup line. A leaked runner spins
for the rest of the process on a target whose suites run in parallel.

**Fix:** As previously written — give `BlockingCoordinatorContext` a `tearDown()` and call it from
a single `defer`, which also removes the temporary directory.

---

### WR-05: `BackgroundProcessingClientKey` and its accessor are still unreachable, with an incorrect rationale attached

**File:** `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift:50-61`; `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:301-310`

**Issue:** Re-verified: a tree-wide search finds no `@Dependency(\.backgroundProcessingClient)`
and no `self[BackgroundProcessingClientKey.self]` outside the declaration. Owner-pending per the
15-09 plan prohibition, so the *code* is not a new defect — but the doc comment at
`DownloadClient+Manager.swift:305-308` is still factually wrong ("that is what gives it the
unimplemented `testValue` an unexpected call must fail on"), and the only test exercising that
behaviour builds `BackgroundProcessingClient()` directly
(`DownloadContinuedSessionTests.swift:14`). Whatever the owner decides about the key, the
rationale must not ship as written.

**Fix:** Delete the key and the `DependencyValues` extension and correct the comment, or resolve
the live client through `@Dependency` at `DownloadClient.live(...)`. Correcting the comment is
required either way.

## Info

### IN-07: one permanently-unregisterable launch handler is accumulated per session

**File:** `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift:108-119`
**Issue:** Every `start(...)` mints a UUID identifier and registers a handler that, by the code's
own comment, "can never be unregistered". A long-lived process that starts many download sessions
therefore holds an unbounded, monotonically growing set of registered identifiers in
`BGTaskScheduler`, each retaining a closure. Direct consequence of WR-10's shape.
**Fix:** Fold into WR-10 — one wildcard registration covers every session.

### IN-08: session-lifecycle internals are `public` shipping API solely to satisfy tests

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:125`, `:159`, `:177`, `:214`; `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:370-371`
**Issue:** `handleContinuedSessionEvent(_:sessionID:)`, `markContinuedSessionEnded(sessionID:)`,
`pauseAllSchedulable()`, `pushContinuedSessionProgress()`, `continuedSessionID` and
`continuedSessionTask` have no production caller outside the `DownloadClient` module; they are
`public` only because `DownloadContinuedSessionTests` imports the module without `@testable`. The
codebase already owns the right idiom — `DownloadClient+Testing.swift` is a `#if DEBUG` seam
containing exactly this kind of accessor — and the new CR-02 case
(`DownloadContinuedSessionTests.swift:710`) calls `markContinuedSessionEnded` with a fabricated
foreign UUID, which is a test affordance rather than an API.
**Fix:** Reduce to `internal` and move the test-only entry points behind the existing `#if DEBUG`
seam, or make the suite `@testable import DownloadClient`.

### IN-09: `DownloadContinuedSessionTests.swift` is six lines under a hard `file_length` error

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift:994`
**Issue:** The root `.swiftlint.yml` sets `file_length` to `error: 1000`. The file is at 994
lines, so the next case added to this suite fails the lint gate rather than the test run — an
unhelpful place to discover it. The executor flagged this in the 15-09 summary; recorded here so
it is tracked as a code finding rather than a summary note.
**Fix:** Split the arithmetic cases and the lifecycle cases into two suites, most naturally at the
same moment WR-07's fixture-owned teardown lands.

### IN-10: `pushContinuedSessionProgress()` is the only lifecycle entry still gated on the bare liveness flag

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:203`, `:214-215`
**Issue:** 15-09 gave teardown, event delivery, the ensure resume and the reconcile drain a
session id; the push kept `guard hasLiveContinuedSession`. `reconcileContinuedSession()` even
re-checks the id at line 196 and then hands off to a function that re-derives liveness from the
flag, so the re-check is not carried through. The practical effect today is small — the pushed
numbers are recomputed from a fresh snapshot — but it leaves one asymmetric path in a design
whose whole point is that every late-arriving mutation presents an id.
**Fix:** `public func pushContinuedSessionProgress(sessionID: UUID)` with
`guard continuedSessionID == sessionID else { return }`, threaded from
`reconcileContinuedSession` and from `flushDownloadProgress` (which can read `continuedSessionID`
at its call site).

### IN-11: the `ensureContinuedSession()` doc comment names two suspension windows where only one exists

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:91-96`
**Issue:** "Both awaits above are windows" is inaccurate: `await hasPendingWork()` and
`await schedulableProgress()` are same-actor calls whose callees (`indexedDownloads()`,
`downloads(from:)`, `queueStore.gids`) never suspend, so neither opens a reentrancy window today.
Only `await backgroundProcessingClient.start(...)` does. Given the project's "document deliberate
designs" rule, an over-broad description here is worse than none: it spreads attention across
three points instead of focusing it on the single hop where CR-04 actually lives.
**Fix:** Name the real window (`start`'s main-actor hop) as the one that matters, and describe the
other two as defended-by-construction rather than as windows.

### IN-01: unused `import Foundation`

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift:1`
**Issue:** Unchanged. The file references only stdlib types and coordinator members.
**Fix:** Delete the import.

### IN-02: `// MARK: Test` labels a value used as `previewValue`

**File:** `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift:63`
**Issue:** Unchanged. `noop` is wired as `previewValue` (line 52); the sibling client uses
`// MARK: Preview` for the identical construct (`DownloadClient.swift:190`).
**Fix:** Rename the MARK to `Preview`.

### IN-03: the forbidden-token scan matches one literal space where the lint rule it mirrors matches `\s+`

**File:** `AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift:101-108`
**Issue:** Unchanged. `"@unchecked" + " " + "Sendable"` misses `@unchecked  Sendable` and any
line-broken form, both of which `no_unchecked_sendable`'s `@unchecked\s+Sendable` still catches —
so the invariant is weaker than the rule it claims to mirror. Same for the parenthesised
`nonisolated(unsafe)` token.
**Fix:** Normalise whitespace in the scanned contents before matching, or match with
`NSRegularExpression` built from assembled fragments.

### IN-04: number/unit spacing differs between the CJK locales of the subtitle key

**File:** `AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings:159`, `:173`, `:208`, `:222`, `:259`, `:273`, `:307`, `:321`
**Issue:** Unchanged and re-verified: `ja` uses no space (`%argページ`), `ko` mixes (`%arg페이지`
but `%arg개 갤러리`), and both Chinese locales insert one (`%arg 页`, `%arg 个图库`, `%arg 頁`,
`%arg 個圖庫`).
**Fix:** Pick one convention per language and apply it to both substitutions in that locale.

### IN-05: the "queued GIDs or whole index" read is copy-pasted three times

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:247-250`; `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift:12-15`; `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:26-29`
**Issue:** Unchanged. The identical four lines appear in `schedulableDownloads()`,
`hasPendingWork()` and `scheduleNextIfNeededCore()`; this is the mechanical half of WR-02's
divergence risk.
**Fix:** Extract one `private func queuedOrIndexedDownloads() async -> [DownloadedGallery]`.

### IN-06: `guard let self else { return }` in the launch handler leaves the system task uncompleted

**File:** `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift:113-119`
**Issue:** Unchanged, and now slightly sharper: the seam constructs a full `SystemContinuedTask`
before invoking the handler (`ContinuedTaskScheduling.swift:78`), so a `nil` `self` drops a live
system task with no `setTaskCompleted(success:)` anywhere. `self` is
`ContinuedProcessingSession.shared`, a `static let` that never deallocates, so the branch is
unreachable — which is exactly why it should either be removed or made correct rather than left
as a silent leak path.
**Fix:** Complete the task before returning, or drop the `weak` capture and document why the
singleton makes it unnecessary.

---

_Reviewed: 2026-07-28T05:36:57Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
