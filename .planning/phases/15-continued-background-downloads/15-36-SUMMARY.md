---
phase: 15-continued-background-downloads
plan: 36
subsystem: DownloadClient pause path and scheduling-block accounting
tags: [gap-closure, dead-code, invariants, observability, G-15-16, SC1]
status: complete
requires:
  - "15-35 (comment corrections in DownloadClient+Manager.swift) landed first; the releaseScheduling doc here extends the file as 15-35 left it"
provides:
  - "commitPause with no unreachable exit and no comment describing one — the G-15-8 exit inventory is now accurate"
  - "Both pause-record helpers carrying honest non-throwing, gid-only signatures"
  - "A source-traced, test-cited reason for the pause's second record write, replacing an unexplained duplication"
  - "An unmatched scheduling release reported as an issue, so the G-15-8 convergence invariant is assertable by the suite"
affects:
  - "Every future edit to the pause path: a throwing addition is now a compile-forced catch decision"
  - "Every future case in the download suites: an imbalanced block/release now fails loudly instead of passing over a device log line"
tech-stack:
  added: []
  patterns:
    - "Let the compiler own an unreachability claim rather than a comment asserting it"
    - "reportIssue alongside a privacy-masked log: static message in the issue, identity only in the masked log"
    - "withKnownIssue as a falsifiable pin — it fails when no issue is recorded"
key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift
decisions:
  - "Both pause-record helpers drop throws and the unread download parameter; the compiler then forces out commitPause's do/catch and both dead arms"
  - "writeSettledPauseRecord is KEPT with a traced reason — the plan's teardown-only trace scope was too narrow; its real writers are the queue-mobilizing entry points landing inside the unbounded wait"
  - "The release imbalance is reported with a static, identity-free message before the existing hash-masked log; the guard still returns without mutating"
metrics:
  duration: 37min
  completed: 2026-08-05
---

# Phase 15 Plan 36: Make the Pause Path's Exits Real and Its Release Imbalance Assertable Summary

`commitPause` no longer carries two exits that cannot happen, both pause-record helpers stopped
declaring a `throws` neither body can produce and a parameter neither body reads, and the duplicate
settled write is now justified by a trace that names its actual writers — which turned out not to
be the ones the plan expected. An unmatched scheduling release is reported where the suite can see
it, pinned by a canary that was first run against the unreported guard and failed.

## What Was Built

### Task 1 — the unreachable scaffolding, and the trace it forced

**Commits:** `820c5a06` `refactor(15-36): drop commitPause's unreachable exits`,
`a26be120` `fix(15-36): restore the settled pause record`

Both helpers now read `(gid: String)` with no `throws`:

```swift
private func writeInitialPauseRecord(gid: String) async -> Task<Void, Never>?
private func writeSettledPauseRecord(gid: String) async
```

With no throwing member left in it, the `do` block and both `catch` arms could not survive, and the
comment calling them "that path's single release" died with them. The wrapper's place is taken by
one sentence stating the invariant over the whole class of future edits, not a note about the two
former arms:

> This path is non-throwing end to end, and deliberately so: no member reached from here can fail,
> so every exit below is a real exit and each one releases the scheduling block before it converges.
> A future addition that does throw stops compiling until it is given its own `catch`, which forces
> that release-then-converge decision to be made explicitly instead of letting a standing arm
> absorb it unexamined.

Everything else in `commitPause` is byte-identical: the `.notFound` exit, both `.superseded`
returns, the not-queued-and-not-active `.success`, the release-then-notify-then-schedule ordering on
every one of them, and the pause notice log with its unchanged literal.

Grep, per the acceptance criterion:

```
$ grep -c 'download: DownloadedGallery' AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift
3
119:        _ download: DownloadedGallery          # isSchedulableDownload(_:)
125:    public func shouldSchedule(download: DownloadedGallery) -> Bool
303:        _ download: DownloadedGallery,         # cancelQueuedWorkItem(_:mode:)
```

All three are outside the pause-record helpers. `grep -c '} catch'` over the `commitPause` region
is `0`; the file's one remaining `do`/`catch` is `syncDownloadsState`'s `ensureRootDirectory()`,
untouched.

### The settled-record trace, and the disposition it actually forced

The plan scoped this trace to "every write the awaited cancelled task can perform". That
enumeration, walked callee by callee, is genuinely empty — and acting on it alone was wrong.

**Enumerated: every writer module-wide that re-establishes something `writeInitialPauseRecord`
clears** (`clearDownloadSessionState(gid:includeUpdateFlag: true)`, `queueStore.remove(gid)`,
`backgroundTaskStore.removeAll(for: gid)`):

| Writer | Site | Reachable from the awaited cancelled run? |
|---|---|---|
| `settleDownloadFailure` sets `downloadErrors[gid]` | `DownloadClient+Persistence.swift:178` | No — its only run-task route is `persistFailure`, behind all four `shouldSuppressFailurePersistence(for:)` gates |
| `handleProcessDownloadPartialError` sets `failedPageErrors[gid]` | `DownloadClient+Execution.swift:192` | No — gated at `:189` |
| the four failure handlers' gates | `DownloadClient+Execution.swift:169`, `:189`, `:209`, `:228` | — gate returns true while the block is held (`DownloadClient+ResponseValidationHelpers.swift:350`) |
| `normalizeNeedsAttentionDownloads` sets `validationErrors[gid]` | `DownloadClient+PersistenceNormalize.swift:97` | No — reached only from `syncDownloadsState` |
| orphan handlers set `failedPageErrors[gid]` | `DownloadClient+BackgroundDownloads.swift:137`, `:172` | No — URLSession-delegate entries, each guarded by a surviving `backgroundTaskStore` record, and unordered w.r.t. `taskToCancel?.value` |
| `taskStore.record(taskIdentifier:gid:pageIndex:)` | `DownloadPageDownloader.swift:297` | Yes — but every exit removes its own record (`DownloadPageDownloader.swift:309`, `DownloadClient+PageDownloadHelpers.swift:130`, `:137`, `DownloadClient+Networking.swift:123`), inside the task group `DownloadClient+PageDownload.swift:167` awaits |
| `settleCompletedDownload` repeats all three clears | `DownloadClient+Execution.swift:239-241` | No — behind `guard !Task.isCancelled` at `DownloadClient+Execution.swift:36` |
| `performRetry` sets `queuedModes[gid]`, enqueues | `DownloadClient+RetryHelpers.swift:38-40` | **Not from the run — from a concurrent operation** |
| `performRetryPages` sets `queuedModes`/`queuedPageSelections`, enqueues | `DownloadClient+RetryHelpers.swift:90-92` | **Not from the run — from a concurrent operation** |
| `resume(gid:)` sets `queuedModes[gid]`, enqueues | `DownloadClient+Scheduling.swift:348-350` | **Not from the run — from a concurrent operation** |
| `updateRemoteVersion` inserts into `updatedGalleryIDs` | `DownloadClient+PublicAPI.swift:52` | No — separate public entry |
| DEBUG seam writers | `DownloadClient+Testing.swift:30`, `:38`, `:45` | Not production |

Labeled exhaustive over the run task's reachable teardown: the candidate set was built by grepping
every write to each cleared collection (`downloadErrors[`, `validationErrors[`, `failedPageErrors[`,
`queuedModes[`, `queuedPageSelections[`, `updatedGalleryIDs.`, `queueStore.`, `backgroundTaskStore.`,
`taskStore.record`) across `AppPackage/Sources/DownloadClient/`, then classifying each by
reachability rather than sampling the ones that looked plausible.

**The disposition the list forced was DELETE — and that was a regression.** The last three rows are
the reason. They are not the cancelled run's teardown, so the plan's trace scope excluded them by
construction; but they are exactly what the second write exists to re-clear, because none of them
takes a scheduling block and all of them are therefore free to land inside `await
taskToCancel?.value`. The full `FeatureTests` run caught it immediately:

```
✘ Test testAUserPauseIsNeverAbandonedByAnInterleavingRetry() recorded an issue at
  DownloadContinuedSessionInterleaveTests.swift:98:9: Expectation failed: (queueStore.contains(gid) → true) == false
✘ Test testAUserPauseIsNeverAbandonedByAnInterleavingRetry() recorded an issue at
  DownloadContinuedSessionInterleaveTests.swift:99:9: Expectation failed: await context.manager.queuedModes[gid] == nil
```

That case's own doc states the contract the deletion broke: "a user pause does not yield to an
action that arrives while its cancellation is suspended. Widening the guard to every pause would
reverse last-writer-wins behavior and make an explicit pause unreliable." So `writeSettledPauseRecord`
is **KEPT**, with the trace recorded on it as its reason to exist:

> Re-writes the pause's record after the cancelled run has finished, re-clearing whatever the
> unbounded wait on that run let a concurrent action put back.
>
> The re-established writes come from other operations, not from the cancelled run: its own teardown
> re-establishes none of this. All four of its failure-persistence handlers are gated on
> `shouldSuppressFailurePersistence(for:)`, true for as long as the caller holds this gallery's
> scheduling block; its page loop cancels the batch on that same block and skips its forced flush;
> and every page task removes its own background-task record on each exit, inside the task group the
> run awaits.
>
> The writers this re-clears are the queue-mobilizing entry points, which take no scheduling block
> and so are free to land inside the wait: `performRetry` and `performRetryPages` each set
> `queuedModes[gid]` and enqueue the gid, and `resume(gid:)` does the same. For an expiration-owned
> pause the `ownsExpirationPause` re-check above turns exactly that interleaving into `.superseded`,
> so this line is never reached; for a user pause there is deliberately no such guard, because an
> explicit pause that a background retry could quietly undo is not a pause.
> `testAUserPauseIsNeverAbandonedByAnInterleavingRetry` pins the difference from both sides.

The honest-signature half of the remedy stands on its own: the helpers keep their non-throwing,
gid-only shapes, and the dead arms stay gone. Only the deletion was reverted.

### Task 2 — the release imbalance, reported where tests can see it

**Commits:** `f2393036` `test(15-36): add failing unmatched-release canary`,
`fb77dbe2` `feat(15-36): report an unmatched scheduling release`

The report-then-log branch, unchanged early return:

```swift
func releaseScheduling(gid: String) {
    guard let count = schedulingBlockedGalleryCounts[gid] else {
        reportIssue("Scheduling release without a matching block.")
        logger.error(
            """
            Scheduling release without a matching block, \
            gid: \(gid, privacy: .private(mask: .hash)).
            """
        )
        return
    }
```

The issue text is a static string literal with no interpolation, so no gallery identity enters test
output or a runtime warning; the gid stays only in the hash-masked log line beneath it. The
dictionary is not touched on this path, in release builds exactly as before. `import IssueReporting`
follows the module precedent at `AppPackage/Sources/AppModels/Gallery/Category.swift:1`/`:45` and
needed no `Package.swift` change — it arrives transitively through
`.targetDependency(.composableArchitecture)`.

The DEBUG forwarder `testingReleaseScheduling(gid:)` already existed (added with the WR-03
reference-count work) and needed no new declaration; its doc now names the canary as its second
consumer, per the seam's carries-only-what-a-suite-consumes rule.

## Falsifiability — the RED reading, verbatim

Taken before the report landed, with the canary in place and `releaseScheduling` still log-only:

```
✘ Test testAnUnmatchedSchedulingReleaseReportsAnIssue() recorded an issue at
  DownloadOwnershipConvergenceTests.swift:222:30: Known issue was not recorded
✘ Test testAnUnmatchedSchedulingReleaseReportsAnIssue() failed after 0.021 seconds with 1 issue.
✘ Test run with 5 tests in 1 suite failed after 0.046 seconds with 1 issue.
** TEST FAILED **
```

GREEN, after the report:

```
━ Test testAnUnmatchedSchedulingReleaseReportsAnIssue() recorded a known issue at
  DownloadClient+Manager.swift:620:24: Issue recorded
━ Test testAnUnmatchedSchedulingReleaseReportsAnIssue() passed after 0.017 seconds with 1 known issue.
** TEST SUCCEEDED **
```

The canary then asserts the guard mutated nothing: an ordinary block/release pair on the same gid
still balances exactly, so the unmatched release neither consumed nor created a count.

## Verification

| Check | Result |
|---|---|
| Task 1 targeted run (`DownloadOwnershipConvergenceTests`, `DownloadSchedulingTests`) | `** TEST SUCCEEDED **`, 6 tests, single invocation |
| Task 2 RED (`DownloadOwnershipConvergenceTests`) | `** TEST FAILED **` — known issue was not recorded |
| Task 2 GREEN (`DownloadOwnershipConvergenceTests`) | `** TEST SUCCEEDED **`, 5 tests, 1 known issue |
| Full `FeatureTests` (post-restoration) | `** TEST SUCCEEDED ** [66.901 sec]`, exit `0`, zero `✘` lines, single invocation |
| `DownloadLogPrivacyInvariantTests` (T-15-36-01) | green inside the full run |
| SwiftLint `--strict` over `Sources/DownloadClient/` + `Tests/DownloadsFeatureTests/` | clean, no suppressions |

Acceptance greps:

```
$ grep -c 'import IssueReporting' AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift   → 1
$ grep -c 'reportIssue'           AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift   → 1
$ grep -c 'testAnUnmatchedSchedulingReleaseReportsAnIssue' .../DownloadOwnershipConvergenceTests.swift → 1
$ grep -c 'testingReleaseScheduling' AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift   → 1
```

File lengths, all under the 1000-line boundary: `DownloadClient+Scheduling.swift` 339,
`DownloadClient+Manager.swift` 674, `DownloadClient+Testing.swift` 142,
`DownloadOwnershipConvergenceTests.swift` 347.

The full suite passing with the report live is itself new evidence: no production path trips an
unmatched release today, so the G-15-8 sweep left no imbalance behind.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The settled-record deletion was a regression; restored with a corrected trace**

- **Found during:** Task 2's full `FeatureTests` run, after Task 1 had been committed
- **Issue:** Task 1 deleted `writeSettledPauseRecord` on a trace the plan scoped to the awaited
  cancelled task's teardown. That trace is correct as far as it goes — the teardown re-establishes
  nothing — but the helper's real purpose is to re-clear what a *concurrent* queue-mobilizing
  operation (`performRetry`, `performRetryPages`, `resume`) writes inside the same suspension
  window. `testAUserPauseIsNeverAbandonedByAnInterleavingRetry` pins that contract and failed on
  both of its post-release expectations.
- **Fix:** Restored the helper and its call site verbatim, keeping the non-throwing gid-only
  signature, and wrote the corrected trace onto it naming those three writers with file:line and
  citing the test that pins the behavior. `writeInitialPauseRecord`'s doc was rewritten in the same
  pass — its first version asserted a "once, not twice" property that is now known to be false.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift`
- **Commit:** `a26be120`

**Scope note for the gap round:** this is the invariant-scope failure mode this project has hit
before — a trace bounded by the branch the plan named rather than by every path that can reach the
window. The plan's must_have asked which write "of the awaited cancelled task's teardown" the
helper re-clears; the answer is "none", and answering only that question produces the wrong
disposition. The recorded reason on the helper now states the window (the unbounded wait) rather
than the branch (the cancelled run), so the next reader does not have to rediscover this.

### Deliberate non-changes

- **`writeInitialPauseRecord` keeps its name.** With the settled helper retained, "Initial" still
  contrasts with something real. The plan's artifact contract names both helpers, so no rename was
  in scope either way.
- **The two dead `catch` arms are gone rather than one being kept as defensive.** The gap's
  suggested fix allowed either; deleting both is what makes the compiler own the invariant, which
  is the root-cause half of the remedy.

## Threat Flags

None. `T-15-36-01` (identity leaking through the issue message) is mitigated by the static,
interpolation-free literal, with `DownloadLogPrivacyInvariantTests` green in the full run;
`T-15-36-02` (pause-path failure behavior changing with the dead arms) is mitigated by the
unchanged exits and the green pause suites. No new endpoint, auth path, file access pattern, or
schema change was introduced.

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadOwnershipConvergenceTests.swift` — FOUND
- Commit `820c5a06` — FOUND
- Commit `a26be120` — FOUND
- Commit `f2393036` — FOUND
- Commit `fb77dbe2` — FOUND
