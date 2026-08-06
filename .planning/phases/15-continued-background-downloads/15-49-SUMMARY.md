---
phase: 15-continued-background-downloads
plan: 49
subsystem: downloads
tags: [download-coordinator, continued-session, source-census, doc-hygiene, gap-closure, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-48's census pin (testRunScopedPageWorkProofSitesMatchTheRecordedCensus) and the four censuses before it, all five of which this plan re-scopes and re-derives under a widened scan"
provides:
  - "A census suite whose walk covers the downloads test target as well as the client module, with a known member per directory"
  - "testNoScannedDocNamesTheSharedReadAsTheSchedulersSoleAuthority — the retired single-authority claim owned by a build across every scanned file, observed RED on both retired docs before either was rewritten"
  - "clientModuleFiles(in:) — the seam that keeps a widened walk from re-basing the censuses it now carries"
  - "Two rewritten test doc comments derived from a fresh caller enumeration at this head"
  - "PageDownloadProgress without its dead counter, its early guard restated on the results collection"
  - "A progress gate whose doc promises only what it delivers"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A doc claim is load-bearing wherever it is written; a guard that cannot see the test target cannot own it"
    - "Widening a scan is a change to every census that counts over it, so each census names its own tree explicitly"
    - "A replacement guard is landed and observed RED against the strings it exists to catch BEFORE those strings are removed"

key-files:
  created: []
  modified:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift

key-decisions:
  - "The test target's known member is the file that carried the claim, not an arbitrary one, so the walk's reach is asserted rather than assumed"
  - "Every pre-existing census is scoped to the client module explicitly; the pending-page-list census would otherwise have re-based from 1 to 4"
  - "The prose assertion reads whole files, not executable lines: policing prose is the point, so the comment filter would make it vacuous"
  - "WR-05 remedy is DELETE: neither arming case would assert on the parked arguments, and both already pin the parked push after release through a stronger observation"

patterns-established:
  - "Widened scan + per-census scoping: the walk and the census are separate decisions, and only the prose claim reads the whole walk"

requirements-completed: [SC2, SC3]

coverage:
  - id: D1
    description: "No scanned doc names the shared schedulable read as the scheduler's single authority — across the client module AND the downloads test target"
    requirement: SC3
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift#testNoScannedDocNamesTheSharedReadAsTheSchedulersSoleAuthority"
        status: pass
    human_judgment: false
  - id: D2
    description: "Widening the scan moved no pre-existing census: all five per-file tables and joined totals are unchanged"
    requirement: SC3
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift#testSchedulingBlockCallSitesMatchTheRecordedCensus"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift#testFloorWriterAssignmentsMatchTheRecordedCensus"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift#testSchedulableDownloadsCallSitesMatchTheRecordedCensus"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift#testPendingPageListEvaluationsMatchTheRecordedCensus"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift#testRunScopedPageWorkProofSitesMatchTheRecordedCensus"
        status: pass
    human_judgment: false
  - id: D3
    description: "Removing the dead page counter changes no page-download behavior: the restated guard tests what the counter always tested"
    requirement: SC2
    verification:
      - kind: unit
        ref: "FeatureTests full run — 874 passed, 0 failures, including every DownloadsFeatureTests page-download case"
        status: pass
    human_judgment: false
  - id: D4
    description: "No device-observable behavior changes in this plan; the card's readings are unaffected and 15-UAT.md test 2 remains an independent open axis"
    verification: []
    human_judgment: true
    rationale: "Backstop truth, device-only. This plan is doc hygiene, one dead-state removal and one test-double removal; it claims nothing on hardware."

# Metrics
duration: 14min
completed: 2026-08-06
status: complete
---

# Phase 15 Plan 49: The Claim Becomes a Build Gate Summary

**The single-authority claim that has been wrong for six consecutive rounds is no longer a sentence anyone has to notice: the census suite now walks the downloads test target too, a fragment-assembled prose assertion forbids the retired phrasing across every scanned file, and it was observed FAILING on BOTH retired docs before either was rewritten — while all five pre-existing censuses were re-scoped and re-derived so the widening moved none of them.**

## Performance

- **Duration:** 14 min
- **Started:** 2026-08-06T02:03:05Z
- **Completed:** 2026-08-06T02:17:24Z
- **Tasks:** 2
- **Files modified:** 5

## `files_modified` — the provisional list rewritten to what was actually touched

The plan's frontmatter carried a PROVISIONAL block naming the two suites that arm the progress
gate, to be resolved by the WR-05 decision. **The DELETE remedy was taken, so neither was
modified.** The actual set, with the WR-05 criterion that put each one in or left it out:

| Path | In / out | Criterion |
|---|---|---|
| `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift` | **in** | Task 1 — widened scan, per-census scoping, prose assertion |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift` | **in** | Task 1 — carried the retired claim at `:257` |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift` | **in** | Task 1 — carried the echo at `:26` |
| `AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift` | **in** | Task 2 — the dead counter's three sites and the restated guard |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift` | **in** | Task 2 — the deleted field, both its writes, the corrected gate doc |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift` | **out** | WR-05 DELETE: the case's parked push is already pinned after release through `rejectedProgressUpdates`; an assertion on the parked arguments would restate that single element |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift` | **out** | WR-05 DELETE: the case already asserts the parked push's own subtitle in its ordered position among all four recorded pushes — strictly stronger than reading it mid-park |

## Step 1 — the caller enumeration, derived at this head (`79342758`), not imported

`grep -rn 'schedulableDownloads()' AppPackage/Sources App ShareExtension` — eleven lines in
Sources, zero in `App` and `ShareExtension`, every one classified:

| Role | Site | Count |
|---|---|---|
| Declaration | `+PendingWork.swift:62` | 1 |
| **Call** — the pending-work gate | `+PendingWork.swift:14` | 1 |
| **Call** — the card's snapshot (`schedulableSnapshot`) | `+ContinuedSession.swift:155` | 1 |
| **Call** — the expiration sweep (`pauseAllSchedulable(expiring:)`) | `+ContinuedSession.swift:434` | 1 |
| Doc-comment mention | `+Manager.swift:411`, `+ExecutionSupport.swift:233`, `+Folders.swift:158`, `+Scheduling.swift:230`, `+ContinuedSession.swift:211`, `:427`, `:488` | 7 |

**Three calls, and the scheduler is not one of them.** Re-derived separately from the scheduler's
own core (`+Scheduling.swift:38-67`): `scheduleNextIfNeededCore` reads `queueStore.gids`, then
`indexedDownloads()` when that list is empty or `indexedDownloads(gids: queuedGIDs)` when it is
not, and reaches the predicate through `nextQueuedDownload` / `nextUnqueuedSchedulableDownload`.
**What the two genuinely share is `isSchedulableDownload`, the predicate — not the read scope.**
The divergence is the active-gallery union inside `schedulableDownloads()`, which the scheduler's
queue-scoped read does not carry; it stays inert behind `guard activeTask == nil`.

**Re-verification of 15-44's landed sentence, as the plan required.** `+PendingWork.swift:17-41`
states exactly three call sites, names them, states the scheduler is not among them, names the
scheduler's own read, and records the inert divergence with its re-opening condition. Every clause
matches the enumeration above. It is still true at this head and was mirrored for SHAPE only; every
fact in the two rewrites comes from the enumeration, not from that sentence and not from the gap
record's wording.

## Step 2/3 — the widening, and the hazard it is

`scannedDirectories` is now `[AppPackage/Sources/DownloadClient, AppPackage/Tests/DownloadsFeatureTests]`.

**`grep -c 'knownMembers' …DownloadSourceInventoryTests.swift` → `2`.** The new directory's known
member, quoted:

```swift
    private static let knownMembers = [
        clientModuleDirectory + "/DownloadClient+Manager.swift",
        downloadsTestDirectory + "/DownloadContinuedSessionBasisTests.swift"
    ]
```

It is deliberately the file that carried the claim rather than an arbitrary member, so the walk's
reach into it is asserted rather than assumed — a second, independent defence against the same
silent-pass mode the Step-4 reading falsifies.

### Every pre-existing census, re-derived under the new scoping

Each census now iterates `Self.clientModuleFiles(in: files)` and joins the same subset, so it counts
exactly the tree it always counted. Values before the widening and after:

| Census | Expected table | Total | Before | After | Moved? |
|---|---|---|---|---|---|
| Scheduling-block call sites | `Folders 2, PublicAPI 1, Scheduling 1, Testing 1` | 5 | 5 | 5 | **no** |
| Monotonic-floor writers | `ContinuedSession 4, ExecutionSupport 1` | 5 | 5 | 5 | **no** |
| Schedulable-read call sites | `ContinuedSession 2, PendingWork 1` | 3 | 3 | 3 | **no** |
| Pending-page-list evaluations | `ExecutionSupport 1` | 1 | 1 | 1 | **no** |
| Run-scoped proof sites | `ContinuedSession 1, Execution 1, ExecutionSupport 1, Manager 1` | 4 | 4 | 4 | **no** |

**One of them really would have moved, and this is why the scoping is load-bearing rather than
tidy.** Derived by counting each token in the test target before the change:

| Token | Test-target executable occurrences | Effect on an UNSCOPED census |
|---|---|---|
| `"block" + "Scheduling("` | 0 (`testingBlockScheduling(` differs in case) | none |
| `"lastPushed" + "CompletedPageCount"` | 0 mutations (2 doc mentions only) | none |
| `"schedulable" + "Downloads()"` | 0 (3 mentions, all comment lines) | none |
| `"pendingPage" + "Indices("` | **3** — `DownloadZeroPagePayloadTests.swift:62, 71, 104` | **`{ExecutionSupport: 1}` total 1 → `{ExecutionSupport: 1, DownloadZeroPagePayloadTests: 3}` total 4** |
| `"provenPageWork" + "RunGIDs"` | 0 (1 doc mention) | none |

An unscoped widening would have silently re-based the ONE census whose expected value is a rule
rather than a tally — the one-evaluation rule 15-47 pinned — into a number that no longer means
what its doc says. That is the "one unowned claim traded for three" residue class this round exists
to stop, and it was one edit away.

### The prose assertion, and its token construction quoted

Test name: **`testNoScannedDocNamesTheSharedReadAsTheSchedulersSoleAuthority`**.

```swift
    private static var retiredAuthorityPhrases: [String] {
        ["one" + " authority", "sole" + " authority", "only" + " authority"]
    }
```

Assembled from fragments on the suite's established pattern, so a repository grep counting the
claim cannot match the check that forbids it. Verified: `grep -n 'one authority\|sole authority\|only authority'`
over `DownloadSourceInventoryTests.swift` → **0 matches**, so the check contributes nothing to the
count it enforces.

Unlike every census in the file it reads WHOLE files rather than executable lines — policing prose
is the entire point, and the comment filter would make it permanently vacuous. It reports offending
**paths**, not a count, because Step 4 reads those paths as its evidence.

## Step 4 — the honest RED, taken with BOTH retired sentences still in place

Quoted verbatim from the targeted run over the census suite alone:

> `✘ Test testNoScannedDocNamesTheSharedReadAsTheSchedulersSoleAuthority() recorded an issue at DownloadSourceInventoryTests.swift:385:9: Expectation failed: (offenders.sorted() → ["AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift", "AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift"]) == []`

> `✘ Test run with 6 tests in 1 suite failed after 0.117 seconds with 1 issue.` — `** TEST FAILED **`

**BOTH offending paths are visible in the one reading**, which is what falsifies both silent-pass
modes at once: a mis-assembled token would have passed against the un-rewritten docs, and a walk
that never reached `DownloadContinuedSessionBasisTests.swift` would have named only
`DownloadPendingWorkTests.swift`.

**Every pre-existing census passed in this same run** — the four listed in the log plus
`testFloorWriterAssignmentsMatchTheRecordedCensus`, five of five green with the sixth (the new
assertion) the only failure. The widening moved none of them, measured rather than argued.

**Order of the two readings, stated explicitly.** The RED above came from a run made while BOTH
retired doc comments were still in place — no rewrite had been made at that point and the working
tree held only the census-suite edits. The green in Step 6 came from a run after the rewrites. No
restoration was needed; the plan's `git checkout --` fallback was never reached.

## Step 5 — the two rewrites, quoted

**1. `DownloadContinuedSessionBasisTests.swift`**, WR-01's case. The false premise is replaced; the
case's own subject (the running gallery staying in the card's numerator when the persisted queue
lags) is untouched:

> `schedulableDownloads()` is the read three consumers share — the pending-work gate
> `hasPendingWork()`, this card's own `schedulableSnapshot()`, and the expiration sweep
> `pauseAllSchedulable(expiring:)`. **The scheduler is not among them (G-15-24).**
> `scheduleNextIfNeededCore` reads `queueStore.gids` and then `indexedDownloads()` or
> `indexedDownloads(gids:)` for itself, reaching `isSchedulableDownload` through
> `nextQueuedDownload` / `nextUnqueuedSchedulableDownload`. What the two share is the PREDICATE, not
> the read scope — which is why what this case asserts is the CARD's numerator rather than what the
> scheduler picks up next.
>
> The shared read scoped its index read by queue-store membership alone, while
> `isSchedulableDownload` accepts `displayStatus == .active` — the running gallery — independently
> of that membership. …

**2. `DownloadPendingWorkTests.swift`**, the echo. Same four facts, said from the gate's own side:

> The shared schedulable read's active-gallery union (WR-01, landed in plan 15-26), covered at the
> pending-work seam for the first time.
>
> `schedulableDownloads()` is shared by three callers — this gate, the continued-session card's
> `schedulableSnapshot()`, and the expiration sweep `pauseAllSchedulable(expiring:)` — and **the
> scheduler is not one of them (G-15-24)**: `scheduleNextIfNeededCore` reads `queueStore.gids` and
> then `indexedDownloads()` or `indexedDownloads(gids:)` for itself, and reaches
> `isSchedulableDownload` through `nextQueuedDownload` / `nextUnqueuedSchedulableDownload`. The two
> share the PREDICATE, not the read scope, so the union covered here is a difference between the two
> reads — and this case pins it where a consumer actually asks the question, not at the scheduler.

Each states the caller list, that the scheduler is not among them, what the two share, and where the
scheduler's own read lives. Neither imports the production doc verbatim: each ends by tying the fact
back to its own case, which is what makes them read as test docs.

**Acceptance grep:** `grep -rc 'one authority' AppPackage/Tests` → **0** across all matches, and the
suite's fragment-assembled token confirmed (above) not to contribute to that count. The wider sweep
including the other two phrasings, over `App AppPackage/Sources AppPackage/Tests ShareExtension`, is
also **0**.

## Step 6 — the green

`** TEST SUCCEEDED ** [37.886 sec]` — `✔ Test run with 18 tests in 3 suites passed`, a SINGLE
invocation selecting `DownloadSourceInventoryTests`, `DownloadContinuedSessionBasisTests` and
`DownloadPendingWorkTests` exactly as the task's `<verify>` command does. The assertion that was RED
is green, every re-derived census passed unchanged, and both edited suites passed.

## Task 2 Step 1 — the dead-reader derivation, wider than the module by construction

`grep -rn 'completedCount\b' App AppPackage ShareExtension` — **4 matches, all in one file:**

| Role | Site |
|---|---|
| Declaration | `+PageDownload.swift:12` |
| Assignment (`= progress.results.count`) | `+PageDownload.swift:93` |
| Guard (`> 0`) | `+PageDownload.swift:94` |
| Increment (`+= 1`) | `+PageDownload.swift:250` |

**Zero readers anywhere** — `App`, `AppPackage/Sources`, `AppPackage/Tests` and `ShareExtension` all
scanned. The removal proceeded; no stop condition fired.

**Exclusion method, stated.** The word boundary `\b` is the whole of it. The unbounded grep returns
**7** matches; the extra 3 are a plural local, `let completedCounts = spy.progressUpdates.map(\.completedUnitCount)`
and its two uses at `DownloadContinuedSessionTests.swift:395-397`, which `completedCount\b` excludes
because `s` is a word character.

**A discrepancy with the plan, recorded.** The plan named "three similarly-named symbols that are
not it (the record's completed page count, its display variant, and the unit count on the progress
model)". Those exist — `completedPageCount` (233 sites), `displayCompletedPageCount`, and
`completedUnitCount` (105 sites) — but **none of them contains the substring `completedCount` at
all**, so none was ever a confounder. The one real confounder is the plural test local the plan did
not name. Both facts are recorded here rather than the plan's list being copied forward.

## Task 2 Step 2 — the removal, with the equivalence derivation

The declaration, the assignment and the increment are deleted. The guard is restated, quoted with
the derivation that justifies it:

```swift
        // The collection itself is the condition, and always was: the counter this used to read was
        // assigned `progress.results.count` on the line above and tested for positivity here, so it
        // never said anything the collection does not. Nothing read it afterwards — the batch result
        // is built from `progress.results`, and the manifest flush is handed the same collection —
        // which is what made the increment in `applyPageTaskOutcome` a pure dead write once 15-45
        // removed the last reader (G-15-29).
        guard progress.results.isEmpty == false else { return }
```

**The equivalence is exact and local**, not an argument about intent: line 93 assigned
`progress.results.count` and line 94 tested that value for positivity on the very next line, with
nothing between them. `progress.completedCount > 0` ≡ `progress.results.count > 0` ≡
`progress.results.isEmpty == false`. Nothing downstream moved: `buildBatchResult` and
`flushManifestPageProgress` were already fed `progress.results` directly.

## Task 2 Step 3 — the parked update, DECIDED

**Remedy: DELETE** (the plan's default). The selecting criterion, applied per arming case:

| Arming case | What it parks for | Would it assert on the parked arguments? |
|---|---|---|
| `DownloadContinuedSessionIdentityTests.swift:33` — `testAHeldProgressPushCannotRepaintASuccessorSessionsCard` | To hold an S1 push at the seam while S2 becomes the held client session | **No.** After release it asserts `rejectedProgressUpdates.map(\.sessionID) == [firstClientSessionID]` and `progressUpdates == acceptedBeforeRelease`. The parked update IS that single rejected element; an assertion mid-park would restate it and would say nothing about which side of the identity guard it landed on — which is the case's whole subject. |
| `DownloadContinuedSessionInterleaveTests.swift:238` — `testWorkMobilizedInsideTheTerminalPushSurvivesTheDrain` | To hold the drain's terminal push open while a retry mobilizes work inside that window | **No — it already asserts them, and more strongly.** Its closing `expectNoDifference` enumerates all four recorded subtitles in order, the third annotated in source as "The released parked push, whose arguments were computed at the drain". Reading the argument set mid-park would be a weaker claim than its ordered position among every recorded push. |

Neither case would assert on the parked arguments, so deletion is taken. `inFlightProgressUpdate`,
its write in the progress closure and its clear after the release are gone:
**`grep -rc 'inFlightProgressUpdate' AppPackage/Tests` → 0** across all matches (repository-wide
also 0).

**The removed doc clause, quoted:**

> The call records its complete argument set before signaling `entered`, then parks before the
> identity guard.

**The gate's doc after the change, quoted — it promises only what the gate delivers:**

> The call builds its complete argument set, signals `entered`, and parks BEFORE the identity guard
> and before recording anything. So while the gate is held the spy shows no trace of the parked push
> at all — `progressUpdates` and `rejectedProgressUpdates` gain their entry only once it is
> released, which is where both arming cases read it. Releasing it after a successor starts
> therefore exercises the same stale actor hop as the live seam without a clock, polling, or
> scheduler assumption.
>
> The gate deliberately promises no inspection of the parked arguments: nothing needs it. Both
> arming cases assert the parked push AFTER the release … and each of those is a stronger claim than
> reading the argument set mid-park, because it also pins WHICH side of the identity guard the push
> landed on. A field holding the in-flight update lived here unread until G-15-29 removed it.

The correction is not merely a deletion of a false clause: the doc now states the observable
consequence a reader needs (nothing is visible on the spy until release), which is what a future
case would otherwise have to rediscover.

## Task 2 Step 4 — the residue sweep, four checks

**(a) Orphaned symbols — none.** `grep -rn 'completedCount\b' App AppPackage ShareExtension` → **0**.
`grep -rn 'inFlightProgressUpdate' App AppPackage ShareExtension` → **0**. Nothing existed solely to
feed either deleted write: the counter's increment stood alone inside the `.success` arm (whose
other three statements all survive and are read), and the spy's `update` value is still constructed
and still appended to `progressUpdates` or `rejectedProgressUpdates` after the identity test, so
`ProgressUpdate` and every accessor around it keep their consumers.

**(b) Newly-dead state — none, in either struct.** Stated per member with its count.

`PageDownloadProgress`, after the removal:

| Member | Readers | Where |
|---|---|---|
| `results` | 8 references, 4 of them reads | the restored-index `Set(...)`, the new guard, the manifest flush, `buildBatchResult` |
| `failedPages` | 5 | seeded from `failedPageErrors`, mutated per outcome, read by `buildBatchResult` |
| `pendingResolvedPages` | 3 | appended per success, passed `inout` to `flushDownloadProgress` |
| `lastFlushDate` | 2 | passed `inout` to `flushDownloadProgress`, which compares it |

`BackgroundProcessingClientSpy.State`, after the removal — every member has both a write and a read:

| Member | In-spy lines | Read by |
|---|---|---|
| `startCount` | 2 | accessor; 32 test reads |
| `startTitles` | 2 | accessor; 4 |
| `startSubtitles` | 2 | accessor; 26 |
| `startCompletedUnitCounts` | 2 | accessor; 5 |
| `startTotalUnitCounts` | 2 | accessor; 3 |
| `startSessionIDs` | 2 | accessor; 10 |
| `progressUpdates` | 2 | accessor; 132 |
| `rejectedProgressUpdates` | 2 | accessor; 33 |
| `finishRecords` | 2 | accessor; 13 |
| `currentSessionID` | 6 | the start's single-session guard, the progress identity test, `finish`'s guard |
| `continuation` | 6 | `emit(.granted)`, `takeContinuation`, `finish` |
| `armedStartGate` | 3 | read-and-cleared in the start closure |
| `armedProgressGate` | 3 | read-and-cleared in the progress closure |
| `refusesNextStart` | 3 | read-and-cleared in the start guard |

No write-never-read member remains anywhere. This plan created no new instance of the WR-04 class it
closed.

**(c) The same claim surviving outside scope.** `grep -rni 'completedCount|in-flight progress update|inFlightProgressUpdate|records its complete argument set'`
over `App AppPackage ShareExtension` returns only the plural test local and two unrelated prose uses
of "completed count" that mean the CARD's completed unit count (`DownloadContinuedSessionTests.swift:351,353`,
`+Persistence.swift:197`) — none describes the deleted counter as live, and no doc anywhere
describes the spy field as readable. The retired single-authority phrasings are **0** across all
four trees.

**(d) The census's own reach over this task's files.** Both are inside the widened walk:
`DownloadClient+PageDownload.swift` under `AppPackage/Sources/DownloadClient`, and
`DownloadFeatureTestSupportTypes.swift` under `AppPackage/Tests/DownloadsFeatureTests`. The
enumerator is recursive and the run in Step 5 exercised the whole set with both known members
present, so a future reintroduction of either retired claim in either file fails a build rather than
waiting for a review round.

## Green

| Run | Scope | Result |
|---|---|---|
| Task 1 Step 4 (both retired docs in place) | `-only-testing:…/DownloadSourceInventoryTests` | **TEST FAILED** — 6 tests, 1 issue, the new assertion alone, naming both paths; all five pre-existing censuses green |
| Task 1 Step 6 (after the rewrites) | census suite + both edited suites, one invocation | **TEST SUCCEEDED** — 18 tests in 3 suites, 37.9 s |
| Task 2 Step 5 | full `FeatureTests` | **TEST SUCCEEDED** — **874 passed, 0 failures** (+6 expected failures = 880 counted), 99.2 s |

Each was a single invocation; **none overlapped**. **880 counted against 15-48's 879 → net +1:** the
new prose assertion. The DELETE remedy adds no case, as the plan predicted, and no census was added.
Zero compiler warnings; `swiftlint --strict` over `AppPackage/Sources/DownloadClient` and
`AppPackage/Tests/DownloadsFeatureTests` — **0 violations in 107 files**; zero lines over 120
characters in any touched file; the census suite is 526 lines and the basis suite 701, both below
the 1000-line error gate.

## Task Commits

1. **Task 1: Own the retired single-authority claim** — `23a27799` (test)
2. **Task 2: Drop the dead page counter and the unread parked update** — `fc7b27ae` (refactor)

## Prohibitions

| Prohibition | Status | Evidence |
|---|---|---|
| Must NOT re-baseline an existing census while widening the scan | **held** | All five re-derived and asserted unchanged (table above), with the one that WOULD have moved (pending-page-list, 1 → 4) identified and scoped; all five green in the Step-4 run and again in Step 6 |
| Must NOT correct a doc sentence from the gap record's wording | **held** | Step-1 enumeration performed at HEAD `79342758`, quoted above with per-site classification; 15-44's landed sentence re-verified clause by clause before being mirrored for shape only |
| Must NOT rewrite either doc before the guard is landed and observed FAILING on both | **held** | The RED is quoted with both paths visible and came from a run whose working tree held only the census-suite edits; the ordering is stated explicitly in Step 4 |
| Must NOT scope the dead-counter derivation to the client module | **held** | `grep -rn 'completedCount\b' App AppPackage ShareExtension` — all four trees, result quoted, exclusion method stated |
| Must NOT leave the gate doc promising a reader that does not exist | **held** | Removed clause and replacement doc both quoted; `inFlightProgressUpdate` → 0 repository-wide |
| Must NOT reach for a concurrency or lint escape hatch or a SwiftLint suppression | **held** | No `swiftlint:disable`, `@unchecked`, `@preconcurrency`, `try?` or force unwrap added; `swiftlint --strict` clean over both directories |

## Decisions Made

- The test target's known member is `DownloadContinuedSessionBasisTests.swift`, the file that carried the claim, so the walk's reach into it is asserted rather than assumed — a second defence beside the RED reading.
- Every census is scoped to the client module through `clientModuleFiles(in:)` rather than left counting the walk, because a census counts over the files the scan returns and one of them would have re-based from 1 to 4.
- The prose assertion reads whole files rather than executable lines, the opposite of every census in the file: policing prose is the point, so the comment filter would make it permanently vacuous.
- WR-05 is DELETE: neither arming case would assert on the parked arguments, and both already pin the parked push after release through a strictly stronger observation.
- The restated page guard is `progress.results.isEmpty == false` rather than `progress.results.count > 0`, which says the same thing in the collection's own vocabulary.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The new helper had to be `private` because its result uses a private type**

- **Found during:** Task 1, Step 4's first attempt
- **Issue:** `clientModuleFiles(in:)` returns `[ScannedFile]`, and `ScannedFile` is a `private` nested type. Declared without an explicit modifier inside the file's `private extension`, it drew `error: method must be declared private because its result uses a private type` and the Step-4 reading could not be taken at all (the run failed to compile, not to assert).
- **Fix:** Declared `private static func`, matching `scannedFiles()` beside it, which returns the same type for the same reason.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift`
- **Verification:** The re-run produced the required RED naming both paths; no doc had been rewritten in the interim, so the reading was still taken with both retired sentences in place.
- **Committed in:** `23a27799`

**2. [Rule 1 - Bug] The plan's exclusion list for the dead-counter grep named three symbols that are not confounders, and missed the one that is**

- **Found during:** Task 2, Step 1
- **Issue:** The plan instructed excluding "the record's completed page count, its display variant, and the unit count on the progress model". All three exist (`completedPageCount`, `displayCompletedPageCount`, `completedUnitCount`) but **none contains the substring `completedCount`**, so a substring grep never sees them. The actual confounder is a plural test local, `completedCounts` in `DownloadContinuedSessionTests.swift:395-397`, which the plan did not name.
- **Fix:** The derivation was re-done from source with a word-boundary grep (`completedCount\b`), the real exclusion recorded, and the discrepancy stated rather than the plan's list copied forward. The conclusion is unaffected — zero readers either way.
- **Files modified:** none (derivation only; recorded in this summary)
- **Verification:** Unbounded grep 7 matches, bounded grep 4, difference accounted for line by line.
- **Committed in:** `fc7b27ae` (the removal the derivation authorized)

---

**Total deviations:** 2 auto-fixed (1 blocking, 1 bug)
**Impact on plan:** Both are inside the plan's stated scope — Step 1 explicitly mandated deriving from source rather than importing the record's list, which is #2, and #1 was a compile error on the plan's own Step-4 path. No production behavior beyond the dead counter's removal changed, and that removal is behavior-preserving by the equivalence derivation above.

## Issues Encountered

None. Unlike 15-47 and 15-48, the failing (RED) invocation here finished in 0.12 s of testing and did not hit the 600 s simulator diagnostics-collection timeout those plans recorded — the census suite touches no simulator state worth collecting.

## Known Stubs

None.

## Threat Flags

None — no new network endpoint, auth path, file-access pattern or schema change at a trust boundary. The one new file-system read is the census walk's second directory, which reads Swift sources inside the repository at test time only.

## User Setup Required

None.

## Next Phase Readiness

- **G-15-29 is closed at all three items**, and the first one is closed at the GENERATOR rather than at the sentence: the claim is owned by a build across the test target, so a fourth recurrence fails a build instead of waiting for a review round. The guard's own two silent-pass modes were falsified before it was trusted.
- **All four gaps of round 15 are now closed** — G-15-26 (wave 48), G-15-27 (47), G-15-28 (46), G-15-29 (49).
- **A note for whoever adds the next census here.** The walk and the censuses are now separate decisions. A new census must call `clientModuleFiles(in:)` unless it deliberately means the whole walk; the suite's own doc says so, and `testPendingPageListEvaluationsMatchTheRecordedCensus` is the worked example of what forgetting costs.
- **Two independent items remain open and neither is discharged here.** (1) 15-UAT.md test 2 still needs its physical-device iOS 26 re-run over the `.redownload` route and a `.repair` gallery in a multi-gallery queue; a zero-progress observation there is now NEW information rather than a known G-15-26 ordering. (2) The overlapping-run gating recorded in 15-48-SUMMARY is restated in a doc and not owned by a test, because no current fixture can both hold a runner open mid-run and reach the working-seed preparation.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-06*

## Self-Check: PASSED

All 5 modified source and test files present on disk; all 3 commits (`23a27799`, `fc7b27ae`, `9bfa47ce`) present in git history. No absolute home path in this document.
