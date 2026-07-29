---
phase: 15-continued-background-downloads
reviewed: 2026-07-29T03:38:52Z
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
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift
findings:
  critical: 0
  warning: 9
  info: 5
  total: 14
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-07-29T03:38:52Z
**Depth:** standard
**Files Reviewed:** 34
**Status:** issues_found

## Summary

Re-review of the continued-background-downloads phase after gap-closure plans 15-17, 15-18 and 15-19.

**All three previously recorded Critical findings are resolved.** Each was verified against the
current code rather than against the plan summaries; the evidence is in "Prior Critical Findings"
below. No new Critical-tier defect could be proven. That is a tested statement rather than a pass: I
traced every suspension point in `ensureContinuedSession()`, `reconcileContinuedSession()`,
`pushContinuedSessionProgress()`, `commitPause()` and `pauseAllSchedulable(expiring:)`, and each
interleaving the doc comments label FORBIDDEN is in fact unreachable **on the current code**.

Two caveats attach to that clean bill:

1. Several of the strongest safety properties rest on an invariant the code never states at the place
   it must be maintained: that `hasPendingWork()`, `schedulableDownloads()`, `indexedDownloads()` and
   `DownloadQueueStore.gids` never actually suspend. Adding one `await` to any of them silently
   reopens the double-start window and the pause-vs-enqueue last-writer race that the comments
   describe as "accepted residuals". All four are `public` / `public async` today. See WR-03.
2. The convergence code 15-18 added to `commitPause`'s failure branches is **unreachable**. The two
   helpers it depends on are declared `throws` but cannot throw, and nothing else in the `do` block
   throws either, so both `catch` blocks are dead and no test can make them run. See WR-01.

The privacy sweep (15-19) is substantively correct: no gid, title, folder path or error value reaches
a `privacy: .public` field anywhere in `DownloadClient`. But the invariant test that is supposed to
keep it fixed is materially weaker than its own doc comment, and the sweep left one unannotated
interpolation on the very statement it edited. See WR-07.

Project-convention checks on the changed files came back clean: no line exceeds 120 columns, no
`try?` / `try!` / force unwrap / `as!`, no banned `@unchecked Sendable`, `@preconcurrency`, or
`NSLock`, every multi-element tuple type is labeled, every single-line trailing closure is
parenthesized, multi-line chains put each call on its own line, `private let logger` sits at the top
of each logging file, and both touched modules carry a `.swiftlint.yml` with `parent_config`. The new
`continued_session.*` catalog entries conform to the labeled-substitution rule (named `%#@…@`
substitutions for all three numeric arguments, no bare `%lld` in an outer value, `en` and `de` plural
category sets equal per variable, `ja`/`ko`/`zh-Hans`/`zh-Hant` `other`-only, all six locales
present on both keys).

## Prior Critical Findings — Verification

### 1. `reconcileContinuedSession()` clearing ownership mid-start — RESOLVED

`AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:231-248`. The drain branch
now uses `continuedClientSessionID` as the authority for whether a client session exists yet:

```swift
guard let clientSessionID = continuedClientSessionID else {
    continuedSessionNeedsReconciliation = true
    return
}
```

Traced end to end. `ensureContinuedSession()` writes `hasLiveContinuedSession` and
`continuedSessionID` at lines 93-94 with no suspension before them, suspends only at
`backgroundProcessingClient.start` (line 98), and writes `continuedClientSessionID` at line 120 —
after the ownership re-check. Any reconcile that crosses that window therefore records debt instead
of clearing ownership, and the debt is discharged at lines 130-134 with no suspension between the
client-id write and the discharge. `markContinuedSessionEnded` clears the debt flag (line 191), so it
cannot outlive its session, and a refused start rolls the same bookkeeping back (lines 104-112).
Covered by `DownloadContinuedSessionIdentityTests.testADrainDuringAnInFlightStartDefersReconciliationAndKeepsCoverage`,
which asserts the successor tap folds into the surviving session (`startCount == 1`) rather than
reaching an overlapping start.

### 2. `delete(gid:)` folder-removal failure branches returning without notify / `scheduleNextIfNeeded()` — RESOLVED

`AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift:196-223`. All three previously
silent exits now release the scheduling block, notify observers and converge before returning: the
`notFound` branch (lines 200-203), the typed-`AppError` catch (lines 209-214) and the untyped catch
(lines 217-221). The fix was correctly swept into the second entry point the original finding did not
name, `deleteFolder(name:)` (`DownloadClient+Folders.swift:117-136`). Covered by
`DownloadDeleteConvergenceTests` (2 cases, including the vanished-last-record session completion) and
`DownloadOwnershipConvergenceTests` (4 parameterized cases spanning both entry points × typed and
untyped error shapes, asserting a second observer emission, a recorded schedule, a surviving session
and no `finish`). WR-01 and WR-05 below concern the *shape* of this fix, not its correctness.

### 3. Gallery titles and GIDs emitted as `privacy: .public` — RESOLVED (with a caveat)

A grep across `AppPackage/Sources/DownloadClient` finds no `privacy: .public` interpolation carrying
a gallery identifier, title, folder path, error value or localized error description. The surviving
`.public` fields are non-identifying: `download.pageCount`, `context.mode.rawValue`, a page-index
array, and retry `operation`/`attempt` counters. Identity is emitted as
`privacy: .private(mask: .hash)`, which keeps cross-line correlation without disclosure, at eight
sites. `ContinuedProcessingSession.swift`'s two `.public` fields were audited and are genuinely
identity-free: a bundle identifier plus a minted UUID (line 135), and a `BGTaskScheduler` submission
error raised before any gallery value is in scope (line 144). The card's own content surface is
counts-only by construction — `continuedSessionSubtitle(for:)` takes `ContinuedSessionProgress` and
the catalog key accepts only integers — and `DownloadContinuedSessionTests` line 442 asserts every
pushed subtitle carries no gallery identity. Caveat: WR-07 covers the one interpolation the sweep
missed and the blind spots in the guarding invariant test.

## Warnings

### WR-01: `commitPause`'s entire `do`/`catch` failure path is unreachable dead code

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:189-249` (helpers at `260-285`)

**Issue:** `commitPause` wraps its body in `do { … } catch let error as AppError { … } catch { … }`,
and both `catch` blocks carry the ACTIVE-OWNERSHIP CONVERGENCE fix plus an eight-line comment
justifying why convergence there must be unconditional even for an expiration-owned pause. Neither
block can ever execute. The only `try` calls in the `do` block are `writeInitialPauseRecord` and
`writeSettledPauseRecord`, and neither contains a throwing operation:

```swift
private func writeInitialPauseRecord(gid: String, download: DownloadedGallery) async throws -> Task<Void, Never>? {
    clearDownloadSessionState(gid: gid, includeUpdateFlag: true)   // non-throwing
    await queueStore.remove(gid)                                   // non-throwing
    await backgroundTaskStore.removeAll(for: gid)                  // non-throwing
    await notifyObservers()                                        // non-throwing
    …
}
```

Every other statement in the `do` block (`fetchDownload`, `ownsExpirationPause`, `notifyObservers`,
`scheduleNextIfNeeded`) is non-throwing as well. Because the helpers are *declared* `throws`, the
compiler emits no "catch block is unreachable" warning, so nothing flags this.

Consequences: `pause(gid:)` can never return a failure other than `.notFound`; the convergence branch
documented as load-bearing has never run in production or in a test; and it is untestable, which is
why the ownership-convergence suite covers only `delete` and `deleteFolder`. The `throws` on both
helpers is a false contract that hides all three facts.

**Fix:** Drop `throws` from both helpers, drop the `try`, and delete the now-provably-unreachable
`do`/`catch`. If a throwing failure mode is planned, introduce the throwing operation *first* and
keep the handler alongside a test that exercises it.

```swift
private func writeInitialPauseRecord(gid: String) async -> Task<Void, Never>? { … }
private func writeSettledPauseRecord(gid: String) async { … }

private func commitPause(gid: String, expiration: ExpirationPauseOwnership?) async -> PauseCommitOutcome {
    schedulingBlockedGalleryIDs.insert(gid)
    defer { schedulingBlockedGalleryIDs.remove(gid) }
    …  // no do/catch: no statement in this body can throw
}
```

### WR-02: `writeInitialPauseRecord` / `writeSettledPauseRecord` ignore their `download` parameter

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:260-285`

**Issue:** Both helpers take `download: DownloadedGallery` and never read it; both call sites
(lines 217-220 and 225-228) fetch and pass the record anyway. `writeSettledPauseRecord`'s body is
also a verbatim prefix of `writeInitialPauseRecord`'s, so the pair reads as though the "settled"
write differed from the "initial" one in some way tied to `download`, when the only real difference
is the task cancellation. Swift does not warn on unused parameters, so this survives a clean build
and misleads every future reader about what the pause record depends on.

**Fix:** Delete the parameter from both signatures and both call sites. If re-applying the clear
after the cancelled task's deferred cleanup is deliberate, say so on `writeSettledPauseRecord` — that
comment is the only thing that would distinguish it from a copy-paste artifact.

### WR-03: `ensureContinuedSession()`'s single-session guard depends on an unstated non-suspension property

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:90-95`

**Issue:**

```swift
guard !hasLiveContinuedSession, await hasPendingWork() else { return }
let sessionID = UUID()
hasLiveContinuedSession = true
```

The flag is read *before* an `await` and written *after* it. The doc comment claims "Setting the
liveness flag and stamping the session id synchronously, before the first point another caller could
interleave, is the guard against two callers both reaching the start call" — which holds only because
`hasPendingWork()` happens not to suspend today. That chain is `hasPendingWork()` →
`schedulableDownloads()` → `indexedDownloads(gids:)` → `downloads(from:)`, plus a synchronous
`queueStore.gids` read: four `public async` functions and one `Shared` access, none of which
currently awaits anything that hops. `DownloadQueueStore.gids` is synchronous only because
`save()` is a separate method; a lazy load added there would break the guard. The same unstated
property protects `schedulableProgress()` (line 97) and the
ownership-check-to-queue-mutation sequence in `commitPause` that its own comment (lines 213-216)
concedes as an "accepted residual" — that residual is in fact *not* currently reachable, for the same
reason, which makes the whole cluster of safety claims silently load-bearing on the same fact.

Failure mode if it regresses: two callers both mint a session id and both call
`backgroundProcessingClient.start`; the client store's re-entry guard refuses the second, that caller
rolls back, and the first has already lost `continuedSessionID` to the second — so the surviving
client session is finished by the ownership re-check and the queue is left with no background
coverage. Silent, and only visible as a missing progress card.

**Fix:** Make the claim structural rather than incidental — claim ownership before any `await`:

```swift
guard !hasLiveContinuedSession else { return }
let sessionID = UUID()
hasLiveContinuedSession = true
continuedSessionID = sessionID
lastPushedCompletedPageCount = 0
guard await hasPendingWork() else {
    markContinuedSessionEnded(sessionID: sessionID)
    return
}
```

At minimum, add a doc comment on `hasPendingWork()`, `schedulableDownloads()` and
`DownloadQueueStore.gids` stating that they must not introduce a suspension point, and naming
`ensureContinuedSession()` as the reason.

### WR-04: the superseded-pause path starts sessions from a background context, accumulating scheduler registrations

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:169-186`

**Issue:** `pause(gid:expiration:)`'s `.superseded` branch calls `ensureContinuedSession()`. That
branch is reachable only from `pauseAllSchedulable(expiring:)`, i.e. from
`handleContinuedSessionEvent(.expired)` — a system callback that fires while the app is backgrounded
or immediately after the user cancelled the card. This directly contradicts
`ensureContinuedSession()`'s own contract (`DownloadClient+ContinuedSession.swift:65-69`): "Call this
from a queue-mobilizing user action and from nowhere else … a call from a non-user context would mint
an identifier for a session that never starts."

Every such call that reaches the store mints a fresh
`"\(bundleIdentifier).continued.\(UUID().uuidString)"` and registers a launch handler for it
(`ContinuedProcessingSession.swift:125-133`). Registrations can never be withdrawn — the file says so
at lines 122-124 — and the `cancelAllRequests` sweep runs once per process. In the background the
submission is dropped by the scheduler, the store yields `.unavailable`, the coordinator tears the
session down, `continuedSessionID` returns to `nil`, and the `pauseAllSchedulable` loop advances to
the next superseded gallery and repeats. One expiration with N superseded galleries can therefore
leave N permanently registered identifiers and N retained closures for the process lifetime.

The reachability bound is narrow — each gallery must have had its `queueIntentGeneration` advanced by
a user action inside that expiration's window — so this is not a crash risk. It is unbounded
accumulation on a path the code explicitly declares must never be taken.

**Fix:** Separate convergence from mobilization. The `.superseded` branch genuinely needs
`notifyObservers()` and `scheduleNextIfNeeded()`; it does not need to start a session, because the
user action that superseded it already calls `ensureContinuedSession()` on its own path (`enqueue`,
`togglePause` → `resume`, `retry`, `retryPages` all do). Delete `await ensureContinuedSession()` at
line 184 and record in the comment that session mobilization belongs to the superseding action.

### WR-05: `schedulingBlockedGalleryIDs` is a Set, so the new early releases can unblock a concurrent holder

**Files:** `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift:212, 219`;
`AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift:121-123, 130-132`

**Issue:** The convergence fix releases the block explicitly, because the function-scoped `defer` has
not run yet:

```swift
} catch let error as AppError {
    await reloadDownloadRecord(gid: download.gid, token: download.token)
    schedulingBlockedGalleryIDs.remove(gid)   // releases *the* block, not *this* block
    await notifyObservers()
    await scheduleNextIfNeeded()
    return .failure(error)
}
```

`schedulingBlockedGalleryIDs` is a plain `Set<String>` with no reference counting. `commitPause`,
`delete`, `deleteFolder` and `moveDownload` all insert the same gid and all remove it on exit, so
whichever operation exits first releases the block for every other operation still in flight on that
gallery. The new branches make this sharper than the pre-existing `defer` because they release
*earlier* and then immediately call `scheduleNextIfNeeded()`, the one call that acts on the released
state. Worst realistic outcome: a `delete` whose folder removal failed unblocks a gallery a
concurrent `moveDownload` still holds, and the scheduler starts a download that writes pages into the
folder being moved out from under it.

**Fix:** Reference-count the block, which also removes the need for the explicit early `remove` in
both failure branches:

```swift
private var schedulingBlockCounts = [String: Int]()

func blockScheduling(_ gid: String) { schedulingBlockCounts[gid, default: 0] += 1 }
func releaseScheduling(_ gid: String) {
    guard let count = schedulingBlockCounts[gid] else { return }
    schedulingBlockCounts[gid] = count > 1 ? count - 1 : nil
}
var schedulingBlockedGalleryIDs: Set<String> { Set(schedulingBlockCounts.keys) }
```

### WR-06: the coordinator's default background-processing client is `.noop`, not the unimplemented client

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:301-309, 417`

**Issue:** The property's doc comment states "The no-argument client carries macro-generated
unimplemented endpoints that report an issue when called", but the initializer default is

```swift
backgroundProcessingClient: BackgroundProcessingClient = .noop,
```

and `.noop.start` returns `nil` silently (`BackgroundProcessingClient.swift:86-91`). Every existing
coordinator test that does not inject a spy — the majority of `DownloadsFeatureTests` — therefore
drives `ensureContinuedSession()`, `reconcileContinuedSession()` and `pushContinuedSessionProgress()`
against a client that quietly refuses to start anything. The session path degrades to a no-op instead
of reporting an unimplemented-endpoint issue, so a regression that made an unexpected path touch the
session would be invisible. The comment describes a safety net the code does not install.

**Fix:** Either change the default to `BackgroundProcessingClient()` (the `@DependencyClient`
unimplemented value) and pass `.noop` explicitly in the tests that legitimately want silence, or
correct the doc comment to say the default is a silent no-op and that session behavior is unasserted
unless a client is injected.

### WR-07: the privacy sweep missed one interpolation, and the new invariant test cannot catch that class

**Files:** `AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift:267-273`;
`AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift:30-50`

**Issue:** 15-19 privatized the `snippet` field of this statement and left the `url` field one line
above with no privacy annotation at all:

```swift
logger.error(
    """
    Download received unexpected HTML response, \
    url: \(requestURL?.absoluteString ?? ""), \
    snippet: \(String(textPrefix.prefix(240)), privacy: .private)
    """
)
```

That URL is a gallery page or image-server URL and embeds the gid and page token. `Logger` redacts
dynamic strings by default, so this is not a live disclosure — but it is the only unannotated
interpolation left in the module, it sits on the very statement the sweep edited, and it breaks the
module's convention of stating privacy explicitly at every site.

The invariant test cannot see it. `DownloadLogPrivacyInvariantTests` substring-matches exactly four
tokens — `gid, privacy: .public`, `title, privacy: .public`, `error, privacy: .public`,
`localizedDescription, privacy: .public` — so it is blind to (a) interpolations with no privacy
annotation at all, and (b) any identity-bearing expression whose text does not end in one of those
four words, for example `\(folderURL.path, privacy: .public)`,
`\(record.relativePath, privacy: .public)`, `\(download.folderName, privacy: .public)` or
`\(manifest.title.prefix(20), privacy: .public)`. The suite's doc comment ("Keeps gallery-derived
values out of public unified-log fields") claims considerably more than four literals deliver.

**Fix:** Annotate the URL, and invert the invariant from a four-spelling denylist to an allowlist of
what may be public:

```swift
url: \(requestURL?.absoluteString ?? "", privacy: .private),
```

```swift
// Every `privacy: .public` interpolation in DownloadClient must name one of these expressions,
// and every interpolation inside a logger call must carry an explicit `privacy:` classification.
private static let permittedPublicExpressions: Set<String> = [
    "download.pageCount", "context.mode.rawValue", "operation", "attempt",
    "String(describing: error.failedPages.map(\\.index))"
]
```

### WR-08: `BackgroundProcessingClientSpy` is not a faithful double of the store's single-session guard

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift:250-285`

**Issue:** The spy's doc comment claims "The spy mirrors the live store's single-session guard:
`start` refuses while a session identity is held." It does not, in two ways.

1. The guard is evaluated in one critical section (lines 251-262) and `currentSessionID` is written
   in a second (lines 269-276), with an unlocked gap between them. Two concurrent `start` calls both
   observe `currentSessionID == nil`, both proceed, and the second overwrites the first's
   `currentSessionID` and `continuation`. The live store does its check and its write in one
   synchronous main-actor run (`ContinuedProcessingSession.swift:85-98`). So the double is *weaker*
   than production on exactly the property WR-03 depends on: a regression that reopened the
   coordinator's double-start window would not be detected here.
2. The one-shot `refusesNextStart` arm is consumed by any refusal:

```swift
guard $0.currentSessionID == nil, !$0.refusesNextStart else {
    $0.refusesNextStart = false   // cleared even when the *session guard* caused the refusal
    return true
}
```

   A case that arms a refusal and then happens to hit the session guard first loses the arm silently
   and asserts against the wrong branch.

**Fix:** Collapse the two critical sections into one so the guard, the recording, the session id and
the continuation are published atomically, and clear `refusesNextStart` only when it is the reason
for the refusal:

```swift
let outcome: (refused: Bool, sessionID: UUID?) = self.state.withLock {
    $0.startCount += 1
    …
    if $0.refusesNextStart { $0.refusesNextStart = false; return (refused: true, sessionID: nil) }
    guard $0.currentSessionID == nil else { return (refused: true, sessionID: nil) }
    let sessionID = UUID()
    $0.currentSessionID = sessionID
    $0.continuation = continuation
    …
    return (refused: false, sessionID: sessionID)
}
```

### WR-09: `hasLiveContinuedSession` and `continuedSessionID` encode the same fact

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:373-394`

**Issue:** `continuedSessionID`'s own doc says it is "nil exactly when no session is live", and every
writer sets both fields together: `ensureContinuedSession` (lines 93-94) and
`markContinuedSessionEnded` (lines 189-192). `hasLiveContinuedSession == (continuedSessionID != nil)`
is therefore an invariant, not a design. Two fields for one fact means every future writer has to
remember both, and `reconcileContinuedSession` already opens with
`guard hasLiveContinuedSession, let sessionID = continuedSessionID` to prove something a single
optional would state outright. The comment defending the flag ("The flag alone therefore cannot say
*which* session it refers to") is an argument for keeping the id, not for keeping the flag.

**Fix:** Delete the stored flag and derive it. `DownloadClient+Testing.swift:56-58`
(`testingHasContinuedSession`) keeps working unchanged.

```swift
public var hasLiveContinuedSession: Bool { continuedSessionID != nil }
```

## Info

### IN-01: `ProgressFlushContext.gid` is written at every call site and never read

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:185-193`
**Issue:** `flushDownloadProgress` reads only `context.folderURL`; both construction sites
(`DownloadClient+PageDownload.swift:62-64` and `195-197`) populate `gid`. Dead field on a `Sendable`
value that crosses the page-download hot path.
**Fix:** Drop `gid` from the struct and both call sites.

### IN-02: redundant guard in `normalizeNeedsAttentionDownloads`

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift:32-48`
**Issue:** The guard admits `download.displayStatus == .error || shouldClearCancellationError`, but
the body is a single `if shouldClearCancellationError { … }`, so the `.error`-only arm of the guard
reaches a no-op. The function is also `async` with no `await`. Pre-existing, but it sits in a file
this phase touched and it makes the normalization pass read as though it handled `.error` downloads.
**Fix:**
```swift
public func normalizeNeedsAttentionDownloads(_ downloads: [DownloadedGallery]) {
    for download in downloads
    where download.lastError.map({ isCancellationLikeAppError($0.appError) }) == true {
        downloadErrors[download.gid] = nil
    }
}
```

### IN-03: the store's three `.unavailable` exit paths are untested

**File:** `AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift:75-94`
**Issue:** `ContinuedTaskSchedulingSpy.register` always returns `true` and its `submit` never throws,
so `ContinuedProcessingSession.start`'s three early-unavailable branches — missing bundle identifier
(`:116-120`), refused registration (`:134-138`), throwing submission (`:140-147`) — never execute in
any test. Neither does the property they turn on: that none of them leaves a pending request behind
(`endSession`'s comment at `:247-249` asserts this by construction only). That is a gap in a seam
whose stated justification was "every lifecycle case drives the store through a double".
**Fix:** Give the spy `var registrationSucceeds = true` and `var submissionError: (any Error)?`, then
add two cases asserting `spy.cancelledIdentifiers.isEmpty` and a drained `[.unavailable]` stream.

### IN-04: `UIRequiredDeviceCapabilities` still declares `armv7`

**File:** `App/Info.plist:174-177`
**Issue:** The package targets `.iOS(.v26)`, which is arm64-only; `armv7` has not been a shippable
slice for years and the key as written asserts a capability no supported device has. Pre-existing and
outside this phase's intent, but the plist is in review scope and this phase edited it.
**Fix:** Remove the `UIRequiredDeviceCapabilities` array, or replace `armv7` with `arm64`.

### IN-05: `pauseAllSchedulable(expiring:)` snapshots its target set once, undocumented

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:210-220`
**Issue:** `let gids = await schedulableDownloads().map(\.gid)` is read before the loop, so a gallery
that becomes schedulable during the unbounded run of per-gallery pauses is not paused by that
expiration and silently continues foreground-only. This is very likely intended — re-reading the set
would let a concurrent enqueue keep the loop alive indefinitely — but it is the one interleaving
disposition in this file absent from its explicit FORBIDDEN / REACHABLE BY DESIGN list, which is
exactly the kind of omission that makes a deliberate design read as a bug later.
**Fix:** Add the disposition to the doc comment: "REACHABLE BY DESIGN: work that becomes schedulable
during the pause loop is not paused by this expiration; re-reading the set here would let a
concurrent enqueue keep the loop alive indefinitely."

---

_Reviewed: 2026-07-29T03:38:52Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
