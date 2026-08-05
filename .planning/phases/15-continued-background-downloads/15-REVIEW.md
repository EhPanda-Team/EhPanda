---
phase: 15-continued-background-downloads
reviewed: 2026-08-05T00:00:00Z
depth: standard
files_reviewed: 44
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
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionPerform.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Folders.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidationHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift
  - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
  - AppPackage/Sources/DownloadClient/DownloadClient.swift
  - AppPackage/Sources/DownloadClient/DownloadStore.swift
  - AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings
  - AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadInterruptedResumeTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift
findings:
  critical: 2
  warning: 9
  info: 5
  total: 16
status: issues_found
---

# Phase 15: Code Review Report

**Reviewed:** 2026-08-05
**Depth:** standard
**Files Reviewed:** 44
**Status:** issues_found

## Summary

This report replaces the pre-round-11 review and covers the phase as it now stands, after plans
15-27..15-32 landed. Everything below was verified against source; findings resolved in earlier
rounds are not restated.

Two BLOCKERs. CR-01 is the round-11 failure mode repeating itself: the G-15-9 positive-signal
guard added in 15-30 covers only the *total* case (a listing that would blank every claimed page)
while its own written rationale — "the signature of per-file probe failure en masse" — applies
identically to a mass *partial* failure the guard does not stop. One surviving page file disables
it entirely, and the underlying `pageFileScan` still conflates "file absent" with "file present
but unprobeable", so the destructive consumer has no positive signal to test at the per-file
level. CR-02 is a `1...pageCount` range trap the same module explicitly defends against in two
other places, which is the proof that a zero page count is considered a reachable input.

Seven of the nine WARNINGs are the phase's own recurring class: a doc comment asserting an
invariant the code does not have. Two are load-bearing. WR-01 names a recovery mechanism that
exists on only one of four branches that reach the guard it explains. WR-02 has two functions in
the same file asserting opposite things about whether the same call chain suspends, and D-G3-01's
re-check design rests on which is true. WR-03 shows `commitPause`'s two `catch` blocks are
unreachable dead code while a comment asserts they are "that path's single release" — meaning the
G-15-8 convergence sweep counted two exits that cannot happen. WR-06 and WR-07 are
test-fidelity gaps: the session store's entire `.unavailable` branch is unexercised because the
scheduling spy hard-codes registration success, and the WR-01 regression case asserts one
subtitle while its doc claims two consequences.

Structural checks passed: no file exceeds the 1000-line `file_length` gate (largest is
`DownloadContinuedSessionLedgerTests.swift` at 812), no changed line exceeds 120 columns, no
`try?` / `@unchecked Sendable` / `NSLock` / `nonisolated(unsafe)` appeared, imports are sorted in
every new file, the `.xcstrings` substitutions satisfy the labeled-numeric-argument rule and the
`en`/`de` plural-category coherence rule with `ja`/`ko`/`zh-*` other-only, and every `testing*`
forwarder in the DEBUG seam has at least one consumer (so that file's own "only members a suite
consumes" premise holds).

## Critical Issues

### CR-01: The positive-signal blanking guard covers only total scan failure, not mass per-file failure

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:471-478`
(root cause at `AppPackage/Sources/DownloadClient/DownloadStore.swift:197-212`)

**Issue:** The G-15-9 refusal is written as:

```swift
guard blankedPageCount > 0 else { return manifest }
// Only claimed pages are blanked above, so equality here means every one of them would go.
guard blankedPageCount < manifest.completedPageCount else { return manifest }
```

`DownloadManifest.completedPageCount` is the count of pages with a non-empty hash, and only such
pages are blanked, so this guard fires **exactly** when *every* claimed page would be blanked.
Its own doc justifies the refusal as recognising "the signature of per-file probe failure en
masse — the sanitization levels above failing for every file". A gallery with 100 claimed pages
where 99 per-file probes fail and one succeeds yields `blankedPageCount == 99 < 100`: the guard
passes, 99 recorded content hashes are destroyed irreversibly, the record is republished at
1-of-100, and the enclosing D-G7-01 bracket withdraws 99 from the monotonic floor. One surviving
file disables the whole protection.

The root cause is one level down. `pageFileScan` drops a page when `sanitizeAssetFileIfNeeded(at:)`
returns false, which happens both when the file is genuinely gone or zero-byte **and** when
`attributesOfItem` throws and the `canReadNonEmptyFile` fallback cannot open the file (descriptor
exhaustion, `EACCES`, `EIO`). The resulting `[Int: String]` map therefore conflates "absent" with
"present but unprobeable" — the same conflation `scanSucceeded` fixed at the directory level — and
the blanking consumer reads `existingPages[page] == nil` as proof of absence. Raising the
threshold alone is not a fix, because a genuine partial repair (three of ten files deleted in the
Files app) must still blank exactly those three; the caller needs a positive per-file signal.

**Fix:** Surface per-file probe failure alongside the pages, and blank only pages whose file was
never listed at all:

```swift
public struct PageFileScan: Equatable, Sendable {
    public let pages: [Int: String]
    /// Pages whose file WAS listed but whose probe failed: present-but-unreadable, never absent.
    public let unprobedPages: Set<Int>
    public let scanSucceeded: Bool
}
```

then in `reconcileWorkingManifestAgainstPageFiles`:

```swift
for page in manifest.pages.keys.sorted() {
    guard pages[page]?.isEmpty == false,
          existingPages[page] == nil,
          !unprobedPages.contains(page)   // a non-answer is never authority to destroy a hash
    else { continue }
    pages[page] = ""
    blankedPageCount += 1
}
```

Keep the existing all-or-nothing guard as a second line of defence.

### CR-02: `1...pageCount` traps the process when a gallery reports zero pages

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:673`
and `AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift:81-83`

**Issue:** Both sites build a closed range from a value the same module treats as possibly zero:

```swift
// pendingPageIndices
return (1...payload.galleryDetail.pageCount).filter { page in ...

// initializePageDownloadState
let pageIndices = Array(1...context.payload.galleryDetail.pageCount)
```

`1...0` is an invalid `ClosedRange` and traps at runtime, killing the app mid-download. That
`pageCount == 0` is a reachable input is established by the module itself: `makeInitialManifest`
(`DownloadClient+ExecutionSupport.swift:12-15`) guards `pageCount > 0` before building its page
dictionary, and `reusableExistingManifest` (`DownloadClient+PublicAPI.swift:155-157`) guards the
same value. The value reaching these two sites comes from `fetchLatestPayload` →
`normalizeFetchedPayload`, i.e. a freshly parsed `GalleryDetail`, and no guard sits between the
enqueue and `performDownload`. A gallery whose detail page parses with no page count (expunged,
partially rendered, upstream HTML change) therefore crashes the process rather than failing the
download.

**Fix:** Return early for the empty case at both sites, matching the sibling guards:

```swift
public func pendingPageIndices(
    payload: DownloadRequestPayload,
    folderURL: URL,
    existingPageRelativePaths: [Int: String]
) -> [Int] {
    guard payload.galleryDetail.pageCount > 0 else { return [] }
    ...
}

private func initializePageDownloadState(...) async throws {
    let pageCount = context.payload.galleryDetail.pageCount
    guard pageCount > 0 else { return }
    let pageIndices = Array(1...pageCount)
    ...
}
```

Consider additionally rejecting a zero-page payload at `enqueue`, so the queue never holds a
gallery the run cannot finish.

## Warnings

### WR-01: The nil-client skip names a recovery mechanism that exists only on the drain branch

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:574-578`
(flag written only at `:414-419`, read only at `:267-271`)

**Issue:** The comment on the skip reads:

> SKIPPED: nil means there is no card to paint yet. The deferred reconcile after start re-reads
> schedulable work and pushes fresh counts, so this update is recovered.

The deferred reconcile runs only when `continuedSessionNeedsReconciliation` is true, and that
flag is set in exactly one place: the **drain** branch of `reconcileContinuedSession` (line 417).
Every other push that lands inside the client start's main-actor hop — the flush push
(`DownloadClient+Persistence.swift:223`), the run-start announcement
(`prepareWorkingSeedAnnouncingProgress`, `DownloadClient+ExecutionSupport.swift:378-380`), and the
non-drain tail of `reconcileContinuedSession` (line 437) — returns at this guard while recording
**no** debt, so no deferred reconcile exists to recover it. The suite depends on this:
`DownloadContinuedSessionBasisTests.swift:208-211` asserts the announcement's push "paints
nothing", and no deferred push follows. The card is repainted only by the next unrelated flush or
convergence.

Behavior is currently benign, because a drain always emits a terminal push. The defect is that
the comment cannot be used to reason about the window — the same class as G-15-7.

**Fix:** State what is true, and if the recovery is wanted, make it real:

```swift
// SKIPPED: nil means there is no card to paint yet. Only the DRAIN branch records reconciliation
// debt, so this update is NOT replayed; the next flush or convergence repaints the card.
guard let clientSessionID = continuedClientSessionID else { return }
```

Alternatively set `continuedSessionNeedsReconciliation = true` here, which makes the existing
comment accurate for every caller.

### WR-02: Two functions in the same file assert opposite things about whether the same call chain suspends

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:400-403`
vs `:563-567`, and `:192-195`

**Issue:** `reconcileContinuedSession` states:

> The re-check itself must not suspend … `hasPendingWork()` reads `activeTask` and then the queue
> store through `schedulableDownloads()`, and those callees do not suspend today.

`pushContinuedSessionProgress`, 150 lines later, states:

> Interleaving dispositions: the snapshot read and the retirement reconcile can both suspend, so
> ownership is re-checked after each of them.

The "snapshot read" is `schedulableSnapshot()` → `schedulableDownloads()` → `indexedDownloads()`
— the *same* chain `hasPendingWork()` uses, all same-actor `async` calls that do not suspend.
One of these two premises is wrong, and D-G3-01's whole argument ("re-checking identity alone
would guard the invariant that cannot fail") is built on the first one.

A third instance sits in `ensureContinuedSession`, whose doc claims the liveness flag is set
"synchronously, before the first point another caller could interleave". Line 193 is
`guard !hasLiveContinuedSession, await hasPendingWork() else { return }` and the flag is set at
line 195 — *after* an `await`. The claim holds only because that callee does not suspend today,
the exact caveat spelled out at lines 400-403 and omitted here.

**Fix:** Pick one wording and apply it at all three sites — e.g. "these are same-actor calls that
do not suspend today; an `await` introduced inside them reopens this window and needs its own
re-validation" — and keep the defensive re-checks under that justification rather than an
inconsistent one.

### WR-03: `commitPause`'s error handling is unreachable dead code, and a comment asserts otherwise

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:245-263`
and `:275-300`

**Issue:** Both catch blocks carry:

> Both catches are reachable only from the two record writes above, which sit past the block and
> ahead of every release, so this is that path's single release.

Neither write can throw. `writeInitialPauseRecord` and `writeSettledPauseRecord` are declared
`throws`, but their bodies call only `clearDownloadSessionState` (non-throwing),
`queueStore.remove(_:)` (non-throwing), `backgroundTaskStore.removeAll(for:)` (declared
`public func removeAll(for gid: String) async` in `DownloadBackgroundTaskStore.swift:60`,
non-throwing) and `notifyObservers()` (non-throwing). No other call in the `do` block throws
either. The compiler stays silent because the callees are *declared* `throws`, so both `catch`
arms are unreachable — and the G-15-8 convergence sweep counted two exits that cannot occur.

Two further defects in the same pair: both helpers take a `download: DownloadedGallery` parameter
neither body reads, and `writeSettledPauseRecord` re-runs verbatim the three mutations
`writeInitialPauseRecord` already performed, with nothing explaining what the awaited cancelled
task can have undone to make the repeat necessary.

**Fix:** Drop `throws` and the unused parameter from both helpers, delete the two dead catch arms
(or keep one, explicitly marked defensive), and either delete `writeSettledPauseRecord` or
document which mutation it re-establishes:

```swift
private func writeInitialPauseRecord(gid: String) async -> Task<Void, Never>? { ... }
private func writeSettledPauseRecord(gid: String) async { ... }
```

### WR-04: The floor's "four writers, and no others" list omits a fifth writer

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:431-442`
(unlisted writer at `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:331`)

**Issue:** `lastPushedCompletedPageCount`'s doc opens with "Four writers, and no others:
`ensureContinuedSession`'s synchronous reset to zero, that same function's additive seed merge …,
the re-latch at the end of every accepted push, and the **D-G7-01** withdrawal".
`markContinuedSessionEnded` also assigns it (`lastPushedCompletedPageCount = 0`) and is absent
from the list; the closing sentence "cleared when a session starts and when one ends" describes
the behavior but contradicts the enumerated "and no others". This phase has already lost four
rounds to an enumeration of movers that source disagreed with, so an exhaustive-sounding list
that is not exhaustive is a liability rather than documentation.

**Fix:** Either count the teardown ("Five writers …, plus `markContinuedSessionEnded`'s
session-scoped reset") or drop the count and state the rule.

### WR-05: The app still declares an unused `processing` background mode

**File:** `App/Info.plist:160-169`

**Issue:** The phase's stated topology decision is "the app keeps exactly one
background-execution mechanism", enforced by `BackgroundExecutionInvariantTests`, which bans every
symbol of the deleted discretionary tier *and scans this plist for them*. The plist nevertheless
still declares `UIBackgroundModes: [processing]`, the capability key that existed for that deleted
tier. The inline comment defends it as asymmetric-risk insurance, but its own justification is
explicitly unverified ("Removing it would need a device-verified experiment of its own"), and an
app that declares a background mode it does not use is a documented App Review rejection reason.
Nothing in the invariant suite covers this key, so the one artifact contradicting the topology
decision is also the one the topology test leaves unchecked.

**Fix:** Run the device-verified experiment the comment describes (submit with the key removed and
confirm no `notPermitted`), then delete the key. If it must stay for now, add it to
`BackgroundExecutionInvariantTests` as an explicit named exemption with the same "paid for rather
than waived" treatment `schedulerScopeExemptions` receives, so it cannot be forgotten.

### WR-06: The store's whole `.unavailable` branch is untested because the scheduling spy cannot refuse

**File:** `AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift:75-94`
(claim at `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift:24-26`)

**Issue:** `ContinuedTaskSchedulingSpy.scheduling` hard-codes `register: { … return true }` and a
non-throwing `submit`, with the comment "Registration always succeeds here; the refusal path is
the store's early-unavailable branch, which owns no pending request." Consequently no case reaches
any of the three `.unavailable` producers in `ContinuedProcessingSession.start` (missing bundle
identifier, refused registration, throwing submission), and no case calls
`spy.launch(identifier, with: nil)`, so `handleLaunch`'s nil-task arm and its
`pendingIdentifier == identifier` identity gate
(`ContinuedProcessingSession.swift:195-205`) never execute. Meanwhile the client type's doc
asserts "the client tests exercise that behavior for every endpoint".

This is more than coverage. The coordinator treats any non-nil session handle as success and
learns of unavailability only through a stream event, so the `.unavailable` yield plus
self-finish is the sole mechanism that ever releases `hasLiveContinuedSession` on the Simulator
and on a refused submission.

**Fix:** Give the spy controllable outcomes and add the missing cases:

```swift
var refusesNextRegistration = false
var nextSubmissionError: (any Error)?
// register: { identifier, handler in
//     guard !self.refusesNextRegistration else { self.refusesNextRegistration = false; return false }
//     ...
// }
// submit: { identifier, title, subtitle in
//     if let error = self.nextSubmissionError { self.nextSubmissionError = nil; throw error }
//     ...
// }
```

Assert that each path yields exactly `[.unavailable]`, finishes the stream, cancels nothing (no
pending request existed), and leaves the store willing to grant the next start; and add a
`spy.launch(staleIdentifier, with: nil)` case proving a stale nil launch cannot end a live
session.

### WR-07: The WR-01 regression case asserts one subtitle while its doc claims two consequences

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift:266-314`

**Issue:** `testTheRunningGalleryStaysInTheSessionBasisWhenThePersistedQueueLagsBehindIt`
documents two consequences of the pre-fix scoping bug: the running gallery's progress leaving the
pushed pair and being "retired at a frozen value while it is still downloading", and
"`pauseAllSchedulable(expiring:)` selects through this same call, so an expiration would skip
pausing the one gallery actually consuming resources — the SC2 cancel half". The body asserts only
`spy.startSubtitles.last == "6 / 14 pages · 2 galleries"`. Neither the retirement behavior nor the
expiration-pause behavior is exercised; the SC2 half in particular is a liveness claim about a
function the case never calls. The sibling
`DownloadPendingWorkTests.testHasPendingWorkSeesAnActiveGalleryThePersistedQueueLagsBehindIt`
covers the pending-work seam, but likewise not `pauseAllSchedulable`.

**Fix:** Add the missing half here or as a sibling: with the same lag staging, drive
`testingPauseAllSchedulable(expiring:)` for the live session and assert the running gallery is
among the paused set — the assertion the doc's SC2 claim promises.

### WR-08: `pendingIdentifier` / `isAwaitingTask` are written after `submit`, so a synchronous launch wedges the session

**File:** `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift:140-151`

**Issue:**

```swift
do {
    try scheduling.submit(identifier, title, subtitle)
    logger.notice("Submitted continued-processing request.")
} catch { ... }

pendingIdentifier = identifier
isAwaitingTask = true
```

If the seam delivers a launch during `submit`, `handleLaunch` runs with `pendingIdentifier == nil`,
`adopt` fails its `pendingIdentifier == identifier` gate and completes the task with
`success: false`. Control returns here, sets `pendingIdentifier` / `isAwaitingTask`, and the store
then waits forever for a launch already consumed: no event is ever yielded, the stream never
finishes, the coordinator's consuming task never exits, and `hasLiveContinuedSession` stays true
until an unrelated drain calls `finish`. The system scheduler cannot deliver synchronously from
the main queue, but `ContinuedTaskScheduling` exists precisely so the store's lifecycle can be
driven through injected values — its own doc says "every lifecycle case drives the store through a
double instead" — and nothing in the protocol forbids synchronous delivery or tests it.

**Fix:** Establish the request's identity before handing it to the scheduler:

```swift
pendingIdentifier = identifier
isAwaitingTask = true
do {
    try scheduling.submit(identifier, title, subtitle)
    logger.notice("Submitted continued-processing request.")
} catch {
    logger.error("\(error, privacy: .public)")
    endSession(yielding: .unavailable, success: false)
    return session
}
return session
```

`endSession` already clears both fields and cancels `pendingIdentifier`, so the throwing path
stays correct (it now also cancels a request the scheduler never accepted, a harmless no-op).
Update the `endSession` paragraph that currently states the early-unavailable paths "all run
before `pendingIdentifier` is set".

### WR-09: The expiration pause path can start a continued-processing session from the background

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift:169-186`
(contract at `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift:167-171`)

**Issue:** `ensureContinuedSession()`'s contract is "Call this from a queue-mobilizing user action
and from nowhere else", because the scheduler validates foreground state and silently drops
submissions it disagrees with. The `.superseded` arm of `pause(gid:expiration:)` calls it, and
that arm is reachable only from `pauseAllSchedulable(expiring:)`, which runs inside the
session-event consuming task while the app is backgrounded and the system has just expired the
task. The in-place comment argues "the scheduler's own foreground validation makes a late ensure
inert if the action no longer qualifies" — but a *silently dropped* submission is not inert from
the coordinator's side: `hasLiveContinuedSession` is set and `continuedSessionID` stamped
synchronously, a fresh never-unregisterable launch handler is registered, and the single-session
slot stays occupied until a drain reaches `finish`. Inside that window a genuine foreground tap
cannot start a real session.

The path is currently near-harmless only incidentally: every public entry point that can supersede
an expiration pause (`enqueue`, `retry`, `retryPages`, `togglePause`) already calls
`ensureContinuedSession` itself, so this call almost always no-ops on the liveness guard. That is
not the property the comment claims.

**Fix:** Either drop the `ensureContinuedSession()` call from the `.superseded` arm (the
superseding user action owns its own ensure), or restate the safety argument in terms the
coordinator can observe rather than in terms of unobservable scheduler behavior.

## Info

### IN-01: The new nil-vs-empty distinction is discarded again by the asset-lookup helpers

**File:** `AppPackage/Sources/DownloadClient/DownloadStore.swift:400-407`

**Issue:** `existingAssetFileURLs` now answers `nil` on a failed listing, but
`existingAssetFileURL(folderURL:prefix:)` immediately collapses it with `?? []`, so
`localCoverURL`, `existingCoverRelativePath` and `existingPageFileURL` again cannot distinguish a
failure from an empty folder. Correct today because none of those consumers acts irreversibly —
but that is a property of the current call graph, and nothing enforces it. It is exactly how the
G-15-9 defect arrived.

**Fix:** Add a one-line note on the helper naming the invariant its consumers must keep ("no
consumer of this may destroy recorded state on an empty answer"), or thread the optional through
so a future consumer has to choose.

### IN-02: Continued-session state is public read surface despite the G-15-11 hardening

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:407-495`
(read directly at
`AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift:156,166,342`)

**Issue:** 15-28 moved the session *mutators* to module-internal, and
`DownloadClient+Testing.swift` records that "an unconsumed forwarder is attack surface rather than
a seam". Nine pieces of session state (`hasLiveContinuedSession`, `continuedSessionID`,
`continuedClientSessionID`, `continuedSessionNeedsReconciliation`, `continuedSessionTask`,
`lastPushedCompletedPageCount`, `retiredSessionPages`, `observedSchedulablePages`,
`observedIncompleteSessionGIDs`) remain `public var`, readable from every module in the package —
and the expiration suite reads `continuedSessionTask` directly rather than through the DEBUG seam,
bypassing the boundary 15-28 drew. Actor isolation prevents external writes, so this is exposure
rather than a mutation hazard.

**Fix:** Make the session-scoped storage `internal` and add a `testingContinuedSessionTask()`
forwarder for the two suites that need it.

### IN-03: An expiration is fired after its fixture directory has been deleted

**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift:31,51`

**Issue:** `defer { clientSpy.expire() }` is registered before
`defer { removeTemporaryItem(at: fixture.rootURL) }`, so LIFO order runs the removal first and the
expiration last. The coordinator's consuming task then executes `pauseAllSchedulable` — which
reads the index and writes queue state — against a deleted directory, unawaited, after the test
returned. Nothing asserts the result, so the expiration buys the case nothing while leaving work
running past it.

**Fix:** Drop the `expire()` defer (the case asserts `clientSpy.finishRecords.isEmpty`, which does
not need it), or move it above the removal and await the session task the way
`DownloadContinuedSessionExpirationTests.expireSession(of:spy:)` does.

### IN-04: A raw `Error` is logged `.public` in the one file exempt from the module's privacy invariant

**File:** `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift:144`
(exemption at `AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift:6-11`)

**Issue:** `logger.error("\(error, privacy: .public)")` writes a `BGTaskScheduler` submission error
verbatim into the public log field. The module-wide invariant lists `error, privacy: .public`
among its forbidden shapes, and this file is excluded from the scan by directory. The exemption's
stated basis — an audit of the file's two public fields, both currently gallery-free — is accurate
today (the submitted `title` is a fixed string and the `subtitle` is a numbers-only localized
string), but it is a point-in-time audit with no mechanism behind it.

**Fix:** Log the error's classification rather than the value
(`\(String(describing: type(of: error)), privacy: .public)`), or extend the invariant's scan to
`BackgroundProcessingClient` with an explicit line-level exemption.

### IN-05: A scheduling-block imbalance is only ever a log line

**File:** `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift:601-616`

**Issue:** `releaseScheduling` documents an unmatched release as "a contract violation rather than
a tolerated no-op", then tolerates it: `logger.error` and return. Combined with WR-03 — where two
counted release sites turn out to be unreachable — a real imbalance introduced by a future edit
would surface only in a device log, never in the suite that guards G-15-8.

**Fix:** Report the violation where tests can see it, keeping production behavior identical:

```swift
guard let count = schedulingBlockedGalleryCounts[gid] else {
    reportIssue("Scheduling release without a matching block.")
    logger.error(...)
    return
}
```

---

_Reviewed: 2026-08-05_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
