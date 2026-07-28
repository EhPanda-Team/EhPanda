---
phase: 15-continued-background-downloads
reviewed: 2026-07-28T02:01:17Z
depth: standard
files_reviewed: 23
files_reviewed_list:
  - App/Info.plist
  - AppPackage/Package.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
  - AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift
  - AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift
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
  - AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift
findings:
  critical: 3
  warning: 7
  info: 6
  total: 16
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-07-28T02:01:17Z
**Depth:** standard
**Files Reviewed:** 23
**Status:** issues_found

## Summary

Phase 15 replaces two background-execution tiers with a single `BGContinuedProcessingTask`
session owned by `DownloadCoordinator`. The single-tier topology (D-01/D-02) is treated as a
locked decision and is **not** reported as a defect; `BackgroundExecutionInvariantTests` was
verified to pass against the current tree (no banned spelling survives anywhere in `App/`,
`AppPackage/Sources`, `AppPackage/Tests`, `ShareExtension`, or `App/Info.plist`).

What holds up: the `@MainActor` confinement of the non-`Sendable` system task and its `Progress`
is genuine — no `@unchecked Sendable`, no `nonisolated(unsafe)`, no force-unwrap, no lint
suppression anywhere in the changed set, and every changed file is inside the 120-column /
1000-line limits. The progress arithmetic is also correct: `pushContinuedSessionProgress` builds
one `ContinuedSessionProgress` and feeds both the pushed counts and the subtitle from that same
materialized pair, and the `max(displayPageCount, completedPageCount)` clamp plus
`DownloadProgress.displayPageCount = max(pageCount, 1)` make a fraction above one and a zero
denominator both unreachable. All six locales are present for both new catalog keys, every
numeric argument is a named `%#@variable@` substitution, the `en` and `de` plural-category sets
match per variable, and `ja`/`ko`/`zh-Hans`/`zh-Hant` are `other`-only.

Where it does not hold up is **session lifecycle**. Three defects let a system-owned progress
card outlive, or be silently detached from, the work it describes:

- the submitted `BGContinuedProcessingTaskRequest` is never cancelled when the session ends
  before the launch handler fires — the ordinary case under the chosen `.queue` strategy;
- `markContinuedSessionEnded()` carries no session identity, so a stale consuming task tears
  down a *newly started* session's state;
- `adopt(_:)` accepts whatever task the system hands it and overwrites `self.task` without
  completing the previous one.

Each ends with the same user-visible symptom: a stuck system card, background coverage silently
lost for the rest of the process, and eventually a spurious pause-all of the user's queue when
the system force-expires the orphan.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: A submitted continued-processing request is never cancelled, so an ended session leaves an orphan the system later launches

**File:** `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift:88`, `:111-129`, `:178-192`

**Issue:**
`start(...)` mints an identifier (line 88), submits the request (line 120) and sets
`isAwaitingTask = true` (line 128) — but the identifier is **never stored**, and `endSession`
(lines 178-192) clears `task`, `continuation` and `isAwaitingTask` without ever calling
`BGTaskScheduler.shared.cancel(taskRequestWithIdentifier:)`. There is no code path in the module
that can cancel a specific request; the only cancellation is the once-per-process
`cancelAllTaskRequests()` behind `didCancelStaleRequests` (line 69-77), which by construction
cannot run again.

This is not an exotic window. D-03 deliberately chose `request.strategy = .queue` precisely so
that "a request the system cannot start immediately waits behind other work instead of failing"
(line 116-118). The submission therefore routinely sits pending. Meanwhile
`reconcileContinuedSession` calls `finish(true)` the moment the queue drains
(`DownloadClient+ContinuedSession.swift:161-171`) — which for a small or largely-cached gallery
happens in seconds, well before the system gets around to launching the task.

Consequences once the system does launch the abandoned request:

1. The launch handler (line 93-104) calls `adopt(continuedTask)`, which stores the task, seeds
   its `Progress`, installs an expiration handler, and yields `.granted` into a `nil`
   continuation. The card appears on screen titled "Downloading galleries" with frozen counts
   and **no work behind it**.
2. `self.task` is now non-`nil`, so the re-entry guard at line 61
   (`guard task == nil, continuation == nil, !isAwaitingTask`) makes every subsequent `start(...)`
   return an already-finished stream. Background coverage is silently dead for the rest of the
   process — the coordinator's `ensureContinuedSession` will keep believing it started a session
   (it sets `hasLiveContinuedSession = true` before it can observe the refusal) and each attempt
   collapses immediately.
3. The orphan is only cleared when the system force-expires it for reporting no progress, at
   which point `.expired` reaches `handleContinuedSessionEvent` and triggers
   `pauseAllSchedulable()` — pausing downloads the user never asked to pause.

**Fix:**
Retain the identifier for the lifetime of the session and cancel the request in `endSession`
whenever no task was ever adopted.

```swift
private var task: BGContinuedProcessingTask?
private var pendingIdentifier: String?
// ...
        do {
            try BGTaskScheduler.shared.submit(request)
            logger.notice("Submitted continued-processing request.")
        } catch { /* unchanged */ }

        pendingIdentifier = identifier
        isAwaitingTask = true
        return stream
// ...
    private func endSession(yielding event: BackgroundProcessingEvent?, success: Bool) {
        let endingTask = task
        let endingContinuation = continuation
        let abandonedIdentifier = endingTask == nil ? pendingIdentifier : nil
        task = nil
        continuation = nil
        pendingIdentifier = nil
        isAwaitingTask = false
        lastCompletedUnitCount = 0
        lastTotalUnitCount = 0

        // A request that was submitted but never launched stays pending with the scheduler;
        // without this the system starts it later against a session that no longer exists.
        if let abandonedIdentifier {
            BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: abandonedIdentifier)
        }
        endingTask?.setTaskCompleted(success: success)
        // ...
    }
```

`adopt(_:)` should clear `pendingIdentifier` as well (see CR-03 for the identity check it also
needs).

---

### CR-02: `markContinuedSessionEnded()` has no session identity, so a stale consuming task tears down a newly started session

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:89-96`, `:133-137`

**Issue:**
The consuming task ends with an unconditional teardown:

```swift
continuedSessionTask = Task { [weak self] in
    for await event in stream { await self?.handleContinuedSessionEvent(event) }
    await self?.markContinuedSessionEnded()   // line 95
}
```

and `markContinuedSessionEnded()` (lines 133-137) unconditionally writes
`hasLiveContinuedSession = false`, `continuedSessionTask = nil`,
`lastPushedCompletedPageCount = 0`. The doc comment justifies this as "Safe to call more than
once, and routinely called twice" — that reasoning only holds if no *new* session can exist by
the time the stale task runs. It can:

1. Session S1 is live. The queue drains, so `reconcileContinuedSession` (line 161-171) runs
   `markContinuedSessionEnded()` and then `await backgroundProcessingClient.finish(true)`, which
   finishes S1's stream.
2. S1's consuming task `T1` is suspended in `for await`; it becomes runnable and must re-enter
   the coordinator actor to run line 95. That hop is racing every other entry into the actor.
3. Before `T1` wins that race, the user taps download again. `ensureContinuedSession()` sees
   `hasLiveContinuedSession == false`, sets it to `true`, starts session **S2**, and assigns
   `continuedSessionTask = T2`.
4. `T1` finally resumes and clears `hasLiveContinuedSession`, `continuedSessionTask` and
   `lastPushedCompletedPageCount` — **for S2**.

S2 is now live in the system (card on screen) while the coordinator believes no session exists:
`pushContinuedSessionProgress` and `reconcileContinuedSession` both return at their
`guard hasLiveContinuedSession` (lines 162, 182), so S2 is never updated and never completed. The
system force-expires it as stalled, `.expired` reaches `T2`, and `pauseAllSchedulable()` pauses
the user's active queue. In the meantime `hasLiveContinuedSession == false` lets a third
`ensureContinuedSession()` through, which the store then refuses (CR-01, guard at
`ContinuedProcessingSession.swift:61`) — leaving the flag set to `true` for a session that does
not exist.

The `.expired` branch has the same shape with a much wider window: it calls
`markContinuedSessionEnded()` at line 118 and then `await pauseAllSchedulable()` (line 119),
which awaits an unbounded number of `pause(gid:)` calls before the loop exits and line 95 runs
the second, unguarded teardown.

**Fix:**
Stamp each session and only let its own teardown apply.

```swift
// DownloadCoordinator state
public var continuedSessionID: UUID?

public func ensureContinuedSession() async {
    guard !hasLiveContinuedSession, await hasPendingWork() else { return }
    hasLiveContinuedSession = true
    lastPushedCompletedPageCount = 0
    let sessionID = UUID()
    continuedSessionID = sessionID
    // ...
    continuedSessionTask = Task { [weak self] in
        for await event in stream {
            await self?.handleContinuedSessionEvent(event, sessionID: sessionID)
        }
        await self?.markContinuedSessionEnded(sessionID: sessionID)
    }
}

/// Clears every trace of *this* session. A teardown arriving from a session that has already
/// been superseded must not touch the live one's state.
public func markContinuedSessionEnded(sessionID: UUID) {
    guard continuedSessionID == sessionID else { return }
    continuedSessionID = nil
    hasLiveContinuedSession = false
    continuedSessionTask = nil
    lastPushedCompletedPageCount = 0
}
```

`reconcileContinuedSession`'s drain branch and both `handleContinuedSessionEvent` branches pass
the same id through.

---

### CR-03: `adopt(_:)` accepts any launched task and overwrites a live one without completing it

**File:** `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift:157-168`

**Issue:**
Launch handlers "can never be unregistered" (the code's own comment, line 86-87), so every
identifier this process has ever registered keeps a live handler that calls `adopt(_:)`. `adopt`
performs `self.task = task` with no check that the arriving task belongs to the session the store
currently believes it is awaiting:

```swift
private func adopt(_ task: BGContinuedProcessingTask) {
    self.task = task            // line 158 — clobbers any previously held task
    ...
    continuation?.yield(.granted)
}
```

Reachable once CR-01 has left a stale request pending: the stale request launches and is adopted
into session *N+1*, so session *N+1*'s consumer receives `.granted` for a task that is not its
own; when *N+1*'s real task then launches, line 158 drops the first task **without calling
`setTaskCompleted(success:)`** — a leaked system task, a second progress card on screen, and a
second `.granted` on the same stream. Two live cards is exactly the outcome
`DownloadClient+Manager.swift:350-357` documents as the thing the design must prevent.

**Fix:**
Capture the identifier in the handler and reject anything that is not the session currently being
awaited; complete the stray task instead of dropping it.

```swift
) { [weak self] task in
    guard let self else {
        task.setTaskCompleted(success: false)
        return
    }
    guard let continuedTask = task as? BGContinuedProcessingTask else {
        task.setTaskCompleted(success: false)
        endSession(yielding: .unavailable, success: false)
        return
    }
    adopt(continuedTask, expecting: identifier)
}

private func adopt(_ task: BGContinuedProcessingTask, expecting identifier: String) {
    // A handler outlives its session and can fire for a request this store has already
    // abandoned; completing it is the only way to get its card off screen.
    guard pendingIdentifier == identifier, self.task == nil else {
        task.setTaskCompleted(success: false)
        return
    }
    self.task = task
    pendingIdentifier = nil
    ...
}
```

## Warnings

### WR-01: `hasLiveContinuedSession` *is* rolled back mid-start, contradicting the invariant the design rests on

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:71-97`; `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:350-360`

**Issue:** Both doc comments assert the flag "is never rolled back" and that "no window exists in
which a concurrent caller sees it false while a start is already in flight". `ensureContinuedSession`
suspends twice after setting the flag — `await schedulableProgress()` (line 84) and
`await backgroundProcessingClient.start(...)` (line 85) — and `DownloadCoordinator` is a reentrant
actor. `reconcileContinuedSession` runs from a *different* task on every
`finishActiveTaskIfOwned` tail (`DownloadClient+Execution.swift:253-268`) and, if the queue has
emptied, calls `markContinuedSessionEnded()` + `finish(true)` inside that window. Two observable
effects: (a) line 89 then assigns `continuedSessionTask` while `hasLiveContinuedSession == false`;
(b) `finish` and `start` are two independent hops onto the `@MainActor` store from two different
tasks, so their relative order is not guaranteed — a `finish` that lands first is a no-op and
leaves the subsequently-created session with nothing that will ever complete it.

**Fix:** Either hold the whole start path suspension-free up to the point the stream exists, or
make the state machine tolerant: fix the doc comments to describe what is actually guaranteed, and
have `ensureContinuedSession` re-check ownership after the awaits (with the session id from CR-02)
before assigning `continuedSessionTask` — completing the just-started session if the coordinator
no longer wants one.

---

### WR-02: `hasPendingWork()` and `schedulableDownloads()` disagree, so the card can read "· 0 galleries" at a full bar while work is live

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift:9-19`; `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:213-219`

**Issue:** `hasPendingWork()` short-circuits on `if activeTask != nil { return true }` and then
re-implements the predicate inline (`!schedulingBlockedGalleryIDs.contains($0.gid) && shouldSchedule(...)`)
rather than calling the `isSchedulableDownload` that was made internal at
`DownloadClient+Scheduling.swift:105` explicitly so that "a second, divergent predicate" could not
exist. `schedulableDownloads()` has no `activeTask` shortcut, so the two answer differently
whenever the active gallery is in `schedulingBlockedGalleryIDs` while `activeTask` is still set —
which is precisely the window inside `pause(gid:)` between the `insert` at
`DownloadClient+Scheduling.swift:145` and the `activeTask = nil` in `writeInitialPauseRecord`
(there are `await`s in between, and the actor is reentrant). A `reconcileContinuedSession` landing
there keeps the session alive and pushes a snapshot summing zero galleries; the monotonic floor
turns that into a full bar plus the subtitle "N / N pages · 0 galleries". The test suite blesses
that string at `DownloadContinuedSessionTests.swift:408` rather than treating it as the defect it
is on a live card.

**Fix:** Make `hasPendingWork()` the single predicate over the single set:

```swift
public func hasPendingWork() async -> Bool {
    if activeTask != nil { return true }
    return await !schedulableDownloads().isEmpty
}
```

and raise `schedulableDownloads()` from `private` to internal. Separately, guard the push against
an empty set so the card never renders a completed-looking bar while a download is in flight —
e.g. skip the push when `snapshot.galleryCount == 0 && activeTask != nil`.

---

### WR-03: `pauseAllSchedulable()` re-schedules every gallery it is about to pause, starting network work inside the expiration handler

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:149-154`

**Issue:** Each `pause(gid:)` ends with `await scheduleNextIfNeeded()`
(`DownloadClient+Scheduling.swift:170`), which installs a fresh `activeTask` for the *next*
gallery in the snapshot — one this loop is about to pause on the following iteration. For N
schedulable galleries the expiration handler therefore performs N-1 full scheduling cycles, each
spawning `processDownload` → `fetchLatestPayload` (a live HTTP request to a rate-limiting host)
and then cancelling it. This runs after the system has already signalled that it is reclaiming the
process, where the code's own comment (`ContinuedProcessingSession.swift:162-163`) notes there is
"no documented budget after expiration".

The pause baseline the tests compare against
(`DownloadContinuedSessionTests.swift:514-537`) reproduces the same churn, so equality with the
baseline does not detect it.

**Fix:** Block the whole batch before pausing any of it, so no intermediate reschedule can pick a
gallery that is still on the list. For example, gate `scheduleNextIfNeededCore` on a coordinator
flag for the duration of the batch:

```swift
public func pauseAllSchedulable() async {
    let gids = await schedulableDownloads().map(\.gid)
    isPausingAllForExpiration = true
    defer { isPausingAllForExpiration = false }
    for gid in gids {
        _ = await pause(gid: gid)
    }
}
```

with `scheduleNextIfNeededCore()` returning early while the flag is set (a per-gid pre-insert into
`schedulingBlockedGalleryIDs` will not work: `pause`'s own `defer { remove(gid) }` would clear the
batch entry).

---

### WR-04: `cancelQueuedWorkItem`'s non-`.initial` branch mutates the queue without reaching `scheduleNextIfNeeded()`

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:208-223`

**Issue:** `reconcileContinuedSession` is documented as hanging off "the single point every queue
mutation converges on" (`DownloadClient+Scheduling.swift:14-23`,
`DownloadClient+ContinuedSession.swift:156-160`). This path breaks that: for
`.redownload` / `.update` / `.repair` it calls `clearDownloadQueueIntent(gid:)` and
`await queueStore.remove(download.gid)` — after which `displayStatus` is no longer `.queued` and
`shouldSchedule` returns `false` — then `notifyObservers()` and returns, with **no**
`scheduleNextIfNeeded()`. If that removal empties the schedulable set while a session is live,
nothing ever reconciles it: no push, no `finish(true)`, `hasLiveContinuedSession` stuck at `true`,
so the next mobilizing tap folds into a dead session and starts nothing.

**Fix:** End the branch through the convergence point like every other queue mutation:

```swift
        clearDownloadQueueIntent(gid: download.gid)
        await queueStore.remove(download.gid)
        await notifyObservers()
        await scheduleNextIfNeeded()
        return .success(())
```

---

### WR-05: `BackgroundProcessingClientKey` and `DependencyValues.backgroundProcessingClient` are unreachable, and the doc comment justifying them is wrong

**File:** `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift:49-61`; `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:301-310`

**Issue:** A tree-wide search finds no `@Dependency(\.backgroundProcessingClient)` and no
`self[BackgroundProcessingClientKey.self]` outside the declaration itself — the client is only
ever injected directly into `DownloadCoordinator.init`. The `DependencyKey` conformance,
`liveValue`, `previewValue`, `testValue` and the `DependencyValues` accessor are therefore dead.
The doc comment at `DownloadClient+Manager.swift:305-308` defends keeping them because "that is
what gives it the unimplemented `testValue` an unexpected call must fail on" — but the only test
that exercises the unimplemented behaviour builds the value directly
(`BackgroundProcessingClient()`, `DownloadContinuedSessionTests.swift:14`), which is a property of
`@DependencyClient`'s memberwise init and needs no key. D-01's own wording ("Dead code must be
deleted, not stranded") applies.

**Fix:** Either delete `BackgroundProcessingClientKey` and the `DependencyValues` extension and
correct the `DownloadCoordinator` doc comment, or actually resolve the live client through
`@Dependency` at the one construction site in `DownloadClient.live(...)`. Do not leave the
rationale as written — it is factually incorrect and will mislead the next reader.

---

### WR-06: `start(...)` does not reset the seed counters, so a new session can adopt the previous session's numbers

**File:** `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift:57-65`, `:140-149`

**Issue:** `updateProgress` writes `lastCompletedUnitCount` / `lastTotalUnitCount` *before* the
`guard let task else { return }` (lines 141-143), so a push that arrives after the session ended
re-populates them. `endSession` zeroes them, but `start(...)` does not, and `adopt` seeds the new
task's `Progress` from whatever they hold (lines 159-160). A late `updateProgress` between one
`endSession` and the next `start` therefore paints the new session's card with the old session's
counts — and the client is a public, domain-agnostic seam whose contract explicitly puts
clamping and monotonicity on the caller, so it cannot assume the caller never pushes late.

**Fix:** Reset the seed pair as part of establishing a new session, immediately after the guard at
line 61:

```swift
        let (stream, continuation) = AsyncStream.makeStream(of: BackgroundProcessingEvent.self)
        self.continuation = continuation
        // A push that landed after the previous session ended must not seed this one's card.
        lastCompletedUnitCount = 0
        lastTotalUnitCount = 0
```

---

### WR-07: blocking-fixture cases leak a forever-spinning task when an assertion fails early

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift:99`, `:122`, `:169`, `:193`, `:236`; `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift:329-336`

**Issue:** `makeBlockingCoordinator` installs a runner whose body is
`while !Task.isCancelled { await sleepIgnoringCancellation(for: .milliseconds(10)) }`. The only
thing that cancels it is the trailing `_ = await context.manager.pause(gid: gid)` at the end of
each case — which is a plain statement, not a `defer`. Every case in between contains throwing
`#require` / `try ... .get()` calls, so any earlier failure skips the cancellation. A running Task
retains itself, so the loop then spins for the remainder of the test process, on a target whose
suites run in parallel. That converts one genuine failure into timing pressure on unrelated
suites, and the fixture's temporary directory teardown (`defer { removeTemporaryItem(...) }`)
already demonstrates the right pattern one line above.

**Fix:** Pair the fixture with its own cleanup:

```swift
let context = try await makeInactiveCoordinator(gid: gid, client: spy.client)
defer { removeTemporaryItem(at: context.rootURL) }
// The blocking runner exits only on cancellation; without this an early failure leaves it
// spinning for the rest of the process.
defer { Task { _ = await context.manager.pause(gid: gid) } }
```

or better, give `BlockingCoordinatorContext` a `tearDown()` the cases call from a single `defer`.

## Info

### IN-01: unused `import Foundation`

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift:1`
**Issue:** The file references only stdlib types (`Bool`, `Set<String>`, `[String]`) and
coordinator members; nothing from Foundation is used.
**Fix:** Delete the import.

### IN-02: `// MARK: Test` labels a value used as `previewValue`

**File:** `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift:63`
**Issue:** `noop` is wired as `previewValue` (line 52). The sibling client in the same phase's
scope uses `// MARK: Preview` for the identical construct (`DownloadClient.swift:190`).
**Fix:** Rename the MARK to `Preview` for consistency.

### IN-03: the forbidden-token scan matches a single literal space where the lint rule it mirrors matches `\s+`

**File:** `AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift:101-108`
**Issue:** `"@unchecked" + " " + "Sendable"` only catches exactly one space. `.swiftlint.yml`'s
`no_unchecked_sendable` uses `@unchecked\s+Sendable`, so `@unchecked  Sendable` or a line-broken
form passes this invariant while still being a lint error. Same for the parenthesised
`nonisolated(unsafe)` token, which is whitespace-sensitive in the same way.
**Fix:** Compare against a whitespace-normalised copy of the file contents, or match with
`NSRegularExpression` built from assembled fragments so the two gates agree.

### IN-04: number/unit spacing differs between the CJK locales of the new subtitle key

**File:** `AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings:159`, `:173`, `:208`, `:222`, `:259`, `:273`, `:307`, `:321`
**Issue:** `ja` uses no space (`%argページ`, `%arg件のギャラリー`), `ko` mixes (`%arg페이지` but
`%arg개 갤러리`), and both Chinese locales insert one (`%arg 页`, `%arg 个图库`, `%arg 頁`,
`%arg 個圖庫`). Conventional Chinese typography sets a numeral and its measure word without an
intervening space.
**Fix:** Pick one convention per language and apply it to both substitutions in that locale.

### IN-05: the "queued GIDs or whole index" read is copy-pasted three times

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:214-217`; `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift:12-15`; `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:26-29`
**Issue:** The identical four lines appear in `schedulableDownloads()`, `hasPendingWork()` and
`scheduleNextIfNeededCore()`. This is the mechanical half of WR-02's divergence risk.
**Fix:** Extract one `private func queuedOrIndexedDownloads() async -> [DownloadedGallery]` and
call it from all three.

### IN-06: `guard let self else { return }` in the launch handler leaves the system task uncompleted

**File:** `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift:94`
**Issue:** `self` is `ContinuedProcessingSession.shared`, a `static let` that never deallocates,
so the `[weak self]` capture is dead defensiveness — but if it ever did fire, the handler returns
without `task.setTaskCompleted(success:)`, stranding a system task and its card. The sibling
`else` branch two lines down gets this right.
**Fix:** Complete the task before returning (see the CR-03 snippet), or drop the `weak` capture
and document why the singleton makes it unnecessary.

---

_Reviewed: 2026-07-28T02:01:17Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
