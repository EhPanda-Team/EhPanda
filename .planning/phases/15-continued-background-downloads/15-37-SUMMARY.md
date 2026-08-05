---
phase: 15-continued-background-downloads
plan: 37
subsystem: Continued-processing session store, download-client session boundary, log-privacy invariant
tags: [gap-closure, hygiene, invariants, privacy, access-control, G-15-18, SC2, SC4]
status: complete
requires:
  - "15-36 (DownloadClient+Scheduling.swift and +Manager.swift pause-path cleanup) landed first; both files are edited here on top of that shape"
  - "15-33 (PageFileScan.unprobedPages) landed first; the probe-collapse invariant names that API as the surfaced-signal alternative"
provides:
  - "A session store whose request identity exists before the request is handed over, so a synchronously delivered launch adopts instead of being turned away and awaited forever"
  - "A log-privacy invariant that scans BackgroundProcessingClient under the download client's rules, with no allowlist entry and no exemption"
  - "A submission-failure log carrying the error's type public and its value private"
  - "Nine pieces of continued-session state at internal access, with testingContinuedSessionTask() as the suites' one route to the session task"
  - "A binding rule on the cover/page probe collapse naming the destructive-consumer prohibition and G-15-9 as its recorded cost"
  - "A convergence case that no longer delivers a spy expiration into a deleted fixture"
  - "A superseded-arm safety argument stated entirely on values the coordinator can read"
affects:
  - "Any future linking module: continued-session state is no longer part of DownloadClient's public API"
  - "Any future log line in BackgroundProcessingClient: it is now scanned, so a raw error value or an unclassified interpolation fails the suite"
  - "Any future consumer of existingAssetFileURL(folderURL:prefix:): the audit is re-run, not extended"
tech-stack:
  added: []
  patterns:
    - "Probe a dispositioned removal against the suite before adopting it — a premise the plan states is not a premise source agrees with"
    - "Extend an invariant scan BEFORE the fix it exists to catch, and record the RED verbatim"
    - "State a safety argument only on values the calling side can read; name the guard that makes the inert branch inert"
key-files:
  created: []
  modified:
    - AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
    - AppPackage/Sources/DownloadClient/DownloadStore.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift
decisions:
  - "WR-09 lands as the gap's SECOND authorized disposition: the ensure call is KEPT and its argument restated observably. The plan's dispositioned removal was implemented, probed, and reverted — it fails the pinned interleave regression on exactly two assertions, because the superseding action's own ensure was swallowed by this pause's scheduling block"
  - "IN-03 is ONE case, not two: the verification's `:31,51` are that case's two defer line numbers. A repository-wide sweep for defer-registered expirations returns exactly one hit"
  - "IN-03 disposition: delete the vestigial expiration. Nothing consumes it, and the consuming task needs no expiration to unwind — the spy holds the stream's only continuation and is released with the coordinator"
  - "The privacy scan gained a per-root known member so neither root can walk nothing and pass vacuously; the hash-masked inventory table is unchanged because the new module masks nothing"
metrics:
  duration: 90min
  completed: 2026-08-05
---

# Phase 15 Plan 37: Six Hygiene Items, One of Them Disproved Summary

All six G-15-18 items are landed. Five landed as dispositioned. The sixth — WR-09's removal of the
`.superseded` arm's `ensureContinuedSession()` — was implemented exactly as written, run against the
suite, and **reverted on evidence**: the removal fails
`testAResumeInsideAStaleExpirationPauseSurvivesAndMobilizesTheQueue` on both of its session
assertions, because the premise the plan rested the removal on ("every queue-mobilizing action
already owns its ensure") is not true in this window. It lands instead as the gap's own second
authorized remedy — the call kept, its safety argument restated entirely on values the coordinator
can read.

## Deviations from Plan

### 1. [Rule 1 — the fix rests on a claim source contradicts] WR-09's removal reverted; the alternative disposition adopted

- **Found during:** Task 1, at the targeted verification run.
- **Plan text:** *"Remove the `ensureContinuedSession()` call from the `.superseded` arm"*, with the
  must-have *"the ensure call is dropped"* and the acceptance criterion *"the extracted arm shows
  notify + schedule only"*.
- **What was done first:** the call was removed, verbatim as dispositioned, and the targeted run was
  taken with the removal in place.
- **The RED reading (removal in place), from the `.xcresult` failure nodes:**

  ```
  DownloadContinuedSessionInterleaveTests.swift:60: Expectation failed: (spy.startCount → 1) == 2
  DownloadContinuedSessionInterleaveTests.swift:61: Expectation failed: await context.manager.testingHasContinuedSession()
  ```

  ```
  ✘ Suite DownloadContinuedSessionInterleaveTests failed after 0.138 seconds with 2 issues.
  ** TEST FAILED **
  Failing tests:
      DownloadContinuedSessionInterleaveTests.testAResumeInsideAStaleExpirationPauseSurvivesAndMobilizesTheQueue()
  ```

  The other 16 cases in the three targeted suites passed with the removal in place, so the failure is
  attributable to the removed line and nothing else.

- **Why the plan's premise fails — the window, not the branch.** The premise is that reaching
  `.superseded` via the generation branch implies a queue-mobilizing user action ran, and that every
  such action *already ensures its own session*. Both halves are literally true and the conclusion
  still does not follow, because the action's ensure can legitimately have done **nothing**:

  1. `ensureContinuedSession()` opens with `guard !hasLiveContinuedSession, await hasPendingWork()`.
  2. `hasPendingWork()` is `activeTask != nil || schedulableDownloads().isEmpty == false`
     (`DownloadClient+PendingWork.swift:10-15`).
  3. `schedulableDownloads()` filters on `isSchedulableDownload`, whose first clause is
     `schedulingBlockedGalleryCounts[download.gid] == nil` (`+Scheduling.swift:118-123`).
  4. The expiration pause **holds that block** across its unbounded `await taskToCancel?.value`, and
     `writeInitialPauseRecord` has already nilled `activeTask`.

  So the mobilizing action's own ensure returns at its first guard, having started nothing. The
  `.superseded` arm runs *after* `releaseScheduling(gid:)` and is therefore the first moment the
  mobilized gallery is visible to that same predicate. Dropping the call leaves a successful tap with
  running work (the arm's `scheduleNextIfNeeded()` still schedules it) and **no session** — which is
  half of the exact defect the failing case was written to pin: *"a successful tap with neither
  running work nor the continued-processing session it requested."*
- **Disposition adopted:** the gap record itself authorizes both remedies —
  *"drop the `ensureContinuedSession()` call from the `.superseded` arm … **or** restate the safety
  argument in terms of `ownsExpirationPause`'s generation check, which the coordinator can observe"*
  (15-VERIFICATION.md, G-15-18 `suggested_fix`). The second was taken. This also satisfies the plan's
  own prohibition 1 — *"every existing store and coordinator case passes"* — which the first remedy
  violates. The defect the gap actually names (a safety argument stated in unobservable terms) is
  fully closed either way.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift`
- **Commit:** `929ee241`

### 2. [Rule 1 — scope correction] IN-03 is one case, not two

The plan reads the verification's `DownloadOwnershipConvergenceTests.swift:31,51` as two cases. It is
one case and its two defer line numbers: `defer { clientSpy.expire() }` at `:31`, `defer {
removeTemporaryItem(at: fixture.rootURL) }` at `:51`. Swept repository-wide rather than trusting the
count:

```
$ grep -rn "defer { *[A-Za-z]*[Ss]py\.expire()\|defer { *spy.expire()" AppPackage/Tests/
AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift:31:        defer { clientSpy.expire() }

$ grep -rn "\.expire()" AppPackage/Tests/ | wc -l
7
```

Seven `.expire()` sites exist across the suites; exactly one is defer-registered, and it is the one
IN-03 names. The remaining six are in-body calls whose settlement is awaited through the session
task. Nothing else in the tree has the LIFO-after-removal shape.

### 3. [Rule 3 — blocking] The scan's known-member helper needed explicit `private`

`requireKnownMembers(in:)` takes `[ScannedFile]`, a `private` nested type, so it could not be
`fileprivate` by default in a `private extension`. It is declared `private static func`, matching
`scannedFiles()` beside it. This surfaced as a build failure in the first RED attempt; the log line
was untouched, and the RED was re-taken afterwards (below), so the falsifiability record is genuine
rather than a build error mistaken for one.

## What Was Built

### Task 1 — the coordinator side

**Commit:** `929ee241` `refactor(15-37): close the session-state boundary and bind two invariants`

#### WR-09 — the observable safety argument (call kept, see Deviation 1)

The removed premise and the whole rewritten comment:

> **The trailing ensure is stated on what the coordinator can observe (WR-09).** The former argument
> here — "the scheduler's own foreground validation makes a late ensure inert" — named behavior no
> code on this side can check, and a second claim, that the session-liveness guard would stop the
> call anyway, is false: the `.expired` handler calls `markContinuedSessionEnded` BEFORE
> `pauseAllSchedulable` (`+ContinuedSession.swift`), so by the time an expiration pause reaches this
> arm the liveness flag is already down. The observable bound is `ownsExpirationPause`, whose two
> failure branches are the only ways to arrive here:
>
> 1. **The gid's queue-intent generation advanced.** Only a queue-mobilizing user action advances it,
>    and every such action does call `ensureContinuedSession()` — but that call can legitimately have
>    done nothing, because THIS pause still held the gallery's scheduling block when it ran:
>    `isSchedulableDownload` rejects a blocked gid, so `hasPendingWork()` answered false and the
>    action's own ensure returned at its first guard. `releaseScheduling` ran just above, so this line
>    is the first moment the mobilized gallery is visible to that same predicate. Dropping the call
>    leaves a successful tap with running work and no session — half of the defect
>    `testAResumeInsideAStaleExpirationPauseSurvivesAndMobilizesTheQueue` pins, which fails on exactly
>    `spy.startCount` and `testingHasContinuedSession()` without it.
> 2. **A live successor session exists** (a non-`nil` session id that is not the expiring one), minted
>    by a qualifying tap that owned its own ensure. Here the call is inert for a reason this side can
>    check rather than infer: `hasLiveContinuedSession` is true, which is `ensureContinuedSession()`'s
>    own first guard.
>
> So the call starts a session on exactly the branch that would otherwise have none, and returns at a
> locally observable guard on the branch that already has one.

Both branches of the ownership predicate are covered, and the round-11 correction (teardown before
pause-all, so the liveness guard does not stop this call) is stated as the reason the old inertness
claim was wrong — not merely dropped. The convergence half of the arm (`notifyObservers()`,
`scheduleNextIfNeeded()`) is byte-identical.

#### IN-01 — the collapse carries a binding invariant

The rewritten doc on `existingAssetFileURL(folderURL:prefix:)`:

> Finds one named asset, collapsing a failed listing into "not found".
>
> **The binding rule this collapse rests on: a probe consumer may flatten a failed listing into an
> empty answer only while NONE of its own consumers acts irreversibly on that answer.** The moment
> one does, it must stop asking here and consume the surfaced-signal scan instead —
> `pageFileScan(...)`, whose `scanSucceeded` and `unprobedPages` say "unlistable" and "unprobeable"
> out loud rather than as an absence.
>
> G-15-9 is the recorded cost of losing that property silently: a consumer that blanked recorded
> content hashes on an empty answer was reading a failed listing as an empty folder, so a transient
> `contentsOfDirectory` failure — descriptor exhaustion, `EBUSY`, a data-protection denial while the
> device is locked — destroyed real state. Nothing about this function's answer distinguishes those
> cases; only its callers' restraint does.
>
> The audited-safe set at this HEAD is exactly the two lookups below it —
> `existingPageFileURL(folderURL:gid:token:index:)` and `existingCoverFileURL(folderURL:gid:token:)` —
> verified exhaustive by grepping this function's name over `AppPackage/Sources`. Their own consumers
> all treat a nil answer as "redo the work": the page lookup reaches `refreshManifestPageFileHash`,
> which returns the manifest unchanged when it resolves nothing, and the cover lookup reaches
> `localCoverURL` and `existingCoverRelativePath`, whose nil means the online cover is shown or the
> cover is fetched again. Nothing on either route deletes or overwrites recorded state. Adding a third
> caller means re-running that audit, not extending its conclusion.

The audited-safe claim is derived, not asserted — the two direct callers come from the grep, and each
was followed to its own consumers (`DownloadStore+Operations.swift:122`, `DownloadStore.swift:253-264`
and their call sites in `+ExecutionSupport.swift:330`, `+PersistenceHelpers.swift:36`,
`+PublicAPI.swift:370`, `DownloadStore.swift:626`). None destroys state on a nil answer.

#### IN-02 — the session-state boundary, grep-proven

Nine declarations in `DownloadClient+Manager.swift` dropped from `public var` to `var`, doc comments
intact: `hasLiveContinuedSession`, `continuedSessionID`, `continuedClientSessionID`,
`continuedSessionNeedsReconciliation`, `continuedSessionTask`, `lastPushedCompletedPageCount`,
`retiredSessionPages`, `observedSchedulablePages`, `observedIncompleteSessionGIDs`.
`continuedSessionTask` — the only one of the nine with no doc — gained one naming the seam as its
route.

New DEBUG-seam member, documented per the seam's carries-only-consumed rule with its four consumer
sites named:

```swift
public func testingContinuedSessionTask() -> Task<Void, Never>? {
    continuedSessionTask
}
```

**Boundary grep 1 — the nine names over every consumer outside the module** (`App/`,
`ShareExtension/`, and every `AppPackage/Sources` module other than `DownloadClient`), **verified
exhaustive**:

```
$ grep -rn "hasLiveContinuedSession\|continuedSessionID\|continuedClientSessionID\
\|continuedSessionNeedsReconciliation\|continuedSessionTask\|lastPushedCompletedPageCount\
\|retiredSessionPages\|observedSchedulablePages\|observedIncompleteSessionGIDs" \
    App ShareExtension $(ls -d AppPackage/Sources/*/ | grep -v "DownloadClient/")
(exit 1)
```

Zero hits. The module list is generated from the directory listing rather than typed, so a module
added later is swept without editing the command.

**Boundary grep 2 — the session-task property over the test tree, forwarder spelling filtered out,
verified exhaustive:**

```
$ grep -rn "continuedSessionTask" AppPackage/Tests | grep -v "testingContinuedSessionTask"
(exit 1)
```

Zero hits. The four former direct reads —
`DownloadContinuedSessionExpirationTests.swift:156, :166, :342` and
`DownloadContinuedSessionInterleaveTests.swift:36` — now go through the forwarder.

```
$ grep -c 'testingContinuedSessionTask' AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
1
```

#### IN-03 — teardown decision, recorded per case

One case (see Deviation 2): `testAFailedRemovalStillConvergesTheQueue`.

| Case | Consumes the expiration? | Decision | Reason |
|---|---|---|---|
| `testAFailedRemovalStillConvergesTheQueue` | No | Delete the defer | Every assertion, `clientSpy.finishRecords` included, is evaluated before any defer runs; the spy is local to the case; and the expiration is delivered into an unawaited consuming task, so even its intended effect is unobservable to the case. |

The ordering, quoted from the pre-fix source, is what made it harmful:

```swift
let clientSpy = BackgroundProcessingClientSpy()
defer { clientSpy.expire() }                          // :31 — registered first
...
defer { removeTemporaryItem(at: fixture.rootURL) }    // :51 — registered second
```

Under LIFO `:51` runs first, so `:31` delivered `.expired` — and with it the handler's entire
pause-all policy, writing through the storage layer — into a folder the case had already deleted,
after the case returned, with nothing awaiting or asserting the result. The replacement comment
records the whole decision including why no teardown is owed:

> IN-03: no teardown expiration here, deliberately. A `defer { clientSpy.expire() }` registered
> before the fixture-removal defer runs AFTER it under LIFO, so it delivered `.expired` — and with it
> the handler's whole pause-all policy, unawaited — into a folder this case had already deleted, with
> nothing left to observe the result. Nothing consumes it either: every assertion below,
> `clientSpy.finishRecords` included, is evaluated before any defer runs, and this spy is local to
> the case. The consuming task needs no expiration to unwind — the spy holds the stream's only
> continuation, and it is released with the coordinator that holds the client, which finishes the
> stream and ends the task.

The restructure-and-await alternative was considered and rejected for this case: it would run a real
pause-all under the assertions' feet for a result the case does not test.

**Targeted run (single invocation), after the WR-09 revert:**

```
xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests \
  -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355' \
  -only-testing:DownloadsFeatureTests/DownloadContinuedSessionExpirationTests \
  -only-testing:DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests \
  -only-testing:DownloadsFeatureTests/DownloadOwnershipConvergenceTests

━ Test run with 17 tests in 3 suites passed after 0.180 seconds with 1 known issue.
** TEST SUCCEEDED ** [41.033 sec]
```

(The one known issue is the suite's pre-existing `withKnownIssue` canary from 15-36, which fails if
*no* issue is recorded.) The explicit simulator id is used because `name=iPhone Air` is ambiguous on
this host.

### Task 2 — the client side, RED first

**Commit:** `441ca960` `fix(15-37): establish request identity before submission, scan the module`

#### Step 1 — the scan extended, and its RED

`DownloadLogPrivacyInvariantTests` now walks two roots, with one known member per root so neither can
pass on an empty walk:

```swift
private static let clientModuleDirectory = "AppPackage/Sources/DownloadClient"
private static let sessionModuleDirectory = "AppPackage/Sources/BackgroundProcessingClient"
private static let scannedDirectories = [clientModuleDirectory, sessionModuleDirectory]
private static let knownMembers = [
    clientModuleDirectory + "/DownloadClient+Execution.swift",
    sessionModuleDirectory + "/ContinuedProcessingSession.swift"
]
```

The header's out-of-scope audit sentence for this module is gone. What replaces it:

> The scan covers two modules: `DownloadClient`, whose sources handle gallery identifiers,
> title-bearing folder paths and gallery responses, and `BackgroundProcessingClient`, which publishes
> log lines adjacent to system submission where scheduler errors flow. A whole-tree rule would create
> exemptions wherever no gallery value can exist instead of strengthening this boundary, and that
> rationale still governs everything outside these two directories.
>
> The background-processing module was previously out of scope on a point-in-time audit of its two
> public fields. That audit was accurate about the identifier — a bundle identifier plus a minted
> UUID — and wrong about the other field: the submission failure logged its raw `Error` value public,
> and a scheduler error may embed arbitrary system strings. IN-04 retires the audit sentence in favor
> of this scan, so the module now passes the same rules the download client passes, with no allowlist
> entry and no line-level exemption.

**Falsifiability — the RED reading, taken with the scan extended and the log line UNCHANGED:**

```
✘ Test testNoDownloadLogPublishesGalleryIdentity() recorded an issue at
  DownloadLogPrivacyInvariantTests.swift:114:13: Expectation failed:
  (offenders → ["AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift"]).isEmpty → false
↳ A public log interpolation exposes a raw error value in:
  ["AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift"]
✘ Test run with 10 tests in 2 suites failed after 0.038 seconds with 1 issue.
** TEST FAILED **
```

The mechanism caught exactly the defect it exists for: one file, one token, "a raw error value". The
other two tests in the suite passed in the same run — the classification test found nothing
unclassified in the new module, and the hash-masked inventory was unaffected, which is why the table
and its total (`10`) gained no entry: the new module masks nothing, because it holds no value whose
identity a device archive would need to correlate. **No allowlist entry, no exemption, no
masked-count change.**

#### Step 2 — the log (IN-04)

```swift
logger.error(
    """
    Continued-processing submission failed, \
    error type: \(String(describing: type(of: error)), privacy: .public), \
    error: \(error, privacy: .private).
    """
)
```

Type public, value private, both interpolations explicitly classified. The operational signal (which
refusal this was, a closed set of symbol names) survives into the public field; the value, which may
embed arbitrary system strings, does not.

#### Step 3 — identity before submission (WR-08)

```swift
        pendingIdentifier = identifier
        isAwaitingTask = true

        do {
            try scheduling.submit(identifier, title, subtitle)
            logger.notice("Submitted continued-processing request.")
        } catch {
            logger.error( … )
            endSession(yielding: .unavailable, success: false)
            return session
        }

        return session
    }
```

Both assignments sit between the registration guard (`guard registered else { … }`) and the
submission call, and **no assignment to either property follows the call** — the former trailing pair
is deleted, which is what keeps `adopt`'s own clearing of `pendingIdentifier` from being undone. The
comment on the site states the reason and the reachability honestly:

> Identity BEFORE the hand-over (WR-08). The request is named and the awaiting window is open before
> the scheduler can possibly launch it, so a launch delivered *during* `submit` passes `adopt`'s
> identity gate and is adopted. With these two lines after the call, that launch was turned away as a
> stray, completed unsuccessfully, and then awaited forever by a store that had just declared itself
> awaiting a task nobody would deliver. Production cannot stage that delivery — this type is
> `@MainActor` and the system delivers launches on the main queue, so `submit` cannot reenter it —
> but this seam exists to be driven by injected doubles, and a synchronous double is exactly what the
> ordering must survive. Nothing may assign either property after the call returns: `adopt` clears
> `pendingIdentifier` itself, and a trailing assignment would put a dead identifier back.

The rewritten `endSession` paragraph, distinguishing the two pre-identifier arms from the holding
arm:

> The three early unavailable paths no longer answer alike, because the identifier is now recorded
> before the request is handed over (WR-08). The no-bundle-identifier and refused-registration arms
> still run before it is set and so cancel nothing, which stays correct: neither reached `submit`, so
> neither left a request pending. The throwing-submission arm now arrives here holding the
> identifier, so the take-back fires for a request the scheduler never acknowledged accepting. That
> is a deliberate defensive no-op rather than an oversight: cancelling an identifier the scheduler
> does not hold is harmless by its API contract, and a throw is exactly the case where the store
> cannot know how far the submission got — so taking the request back covers a half-submitted
> request, while the alternative ordering covers nothing and risks leaving one behind.

Two property docs also asserted the old ordering and were corrected rather than left contradicting
source: `pendingIdentifier` now reads *"non-`nil` from just before the submission call until either
adoption or the end of the session"*, and `isAwaitingTask` *"Covers the window from just before the
request is submitted until the launch handler fires"*.

#### Existing-case assertions updated for the reorder: none

The reorder's only observable bookkeeping change is that the throwing-submission arm now cancels its
request. `ContinuedTaskSchedulingSpy.submit` cannot throw (it has no injectable submission error —
that is G-15-17's remedy, which plan 15-38 carries), so no existing case reaches that arm, and the
three `cancelledIdentifiers` assertions (`ContinuedProcessingSessionTests.swift:225, :269, :330`)
are untouched and pass unchanged. Nothing else in the suite observes the assignment ordering.

**Targeted run (single invocation), after the fix:**

```
xcodebuild test … -only-testing:DownloadsFeatureTests/DownloadLogPrivacyInvariantTests \
                  -only-testing:DownloadsFeatureTests/ContinuedProcessingSessionTests

✔ Test run with 10 tests in 2 suites passed after 0.033 seconds.
** TEST SUCCEEDED ** [32.428 sec]
```

**Full FeatureTests run (single invocation):**

```
xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests \
  -destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'

** TEST SUCCEEDED ** [63.908 sec]
```

No xcodebuild invocation overlapped another, and none was killed.

## Verification

| Acceptance criterion | Status | Evidence |
|---|---|---|
| Superseded arm shows notify + schedule only | **not met — deliberately** | See Deviation 1: the removal fails the pinned interleave regression; the gap's second authorized remedy was taken instead. The arm's comment names both ownership-predicate branches and the teardown-before-pause correction, quoted above |
| Collapse invariant bound | met | Quoted above: destructive-consumer rule, `PageFileScan`/`unprobedPages` as the alternative, G-15-9 named as the recorded cost |
| Boundary complete and grep-proven | met | Both greps quoted, both empty; `grep -c 'testingContinuedSessionTask' … +Testing.swift` outputs `1` |
| Teardown decisions recorded per case, no expiration after removal | met | One case (sweep quoted), decision table and pre-fix ordering quoted |
| Scan covers the module; header audit sentence gone | met | Two scan roots and two known members quoted; new header quoted |
| RED recorded before the log fix | met | Verbatim failure and its `↳` message quoted |
| Log type-public / value-private, zero allowlist additions | met | Line quoted; table and total unchanged at `10` |
| Identity precedes submission, nothing assigned after | met | `start` body quoted; rewritten `endSession` paragraph quoted |
| Existing assertions updated where the reorder changes them | met (none needed) | The spy cannot throw; reasoned and confirmed by the green run |
| Every edited file below 1000 lines | met | `ContinuedProcessingSession.swift` 305, `+Scheduling.swift` 365, `+Manager.swift` 679, `+Testing.swift` 155, `DownloadStore.swift` 779, `DownloadLogPrivacyInvariantTests.swift` 330, `DownloadOwnershipConvergenceTests.swift` 354, `DownloadContinuedSessionExpirationTests.swift` 417, `DownloadContinuedSessionInterleaveTests.swift` 179 |
| SwiftLint clean, no suppressions | met | `swiftlint lint --quiet` over all nine edited files: exit 0, no output, no `swiftlint:disable` added |

### Prohibitions

| Prohibition | Status | Note |
|---|---|---|
| No session-lifecycle behavior change beyond the two named | **satisfied, with one named remedy replaced** | Only the WR-08 reorder changes behavior. The second named change (the dropped ensure) is precisely the one this prohibition's own second clause — "every existing store and coordinator case passes" — forbids; it was reverted on that evidence |
| No weakening of the privacy scan | satisfied | No allowlist entry, no exemption, no masked-count change; the module passes the same three tests the download client passes |
| No item undecided or half-adopted | satisfied | Six items, six landings; the one that deviates does so to a remedy the gap record authorizes, with the RED evidence quoted |

## Threat Mitigations

| Threat ID | Disposition | Landed |
|---|---|---|
| T-15-37-01 (raw scheduler error value in the public log field) | mitigate | Type-public/value-private shape plus the scan over the module, proven RED against the pre-fix line |
| T-15-37-02 (linking module reading session internals) | mitigate | Nine declarations internal; both boundary greps empty; suites route through the DEBUG seam |
| T-15-37-03 (superseded-arm ensure minting a dead identifier from a background context) | **re-assessed** | The removal that was to mitigate it re-opens a proven regression. The residual is bounded observably instead: branch 2 returns at `hasLiveContinuedSession`, and branch 1 starts a session for work that is genuinely schedulable at that instant — the identifier is not dead, it covers the tap's work. A start the system refuses rolls itself back (`ensureContinuedSession`'s nil-client arm), so no wedge survives |

## Threat Flags

None. No new network endpoint, auth path, file-access pattern or schema change at a trust boundary;
the only access-control movement is a narrowing.

## Known Stubs

None.

## Follow-ups for the verifier

- **G-15-18 closes with a documented substitution on WR-09.** The gap's `suggested_fix` offers two
  remedies and the second was taken on evidence. If the re-verification insists on the literal
  removal, the interleave regression must be re-scoped first — the pinned behavior and the removal
  cannot both hold.
- 15-VERIFICATION.md's G-15-18 detail says `DownloadOwnershipConvergenceTests.swift:31,51` "registers
  `defer { clientSpy.expire() }`" — one site, two line numbers. The plan read it as two cases. The
  sweep is recorded above so the re-verification does not go looking for a second one.

## Self-Check: PASSED

Files claimed, all present:

- `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadStore.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionExpirationTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift` — FOUND

Commits claimed, both present in `git log`:

- `929ee241` — FOUND
- `441ca960` — FOUND
