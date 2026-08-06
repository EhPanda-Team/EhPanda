---
phase: 15-continued-background-downloads
plan: 50
subsystem: downloads
tags: [download-coordinator, continued-session, progress-accounting, gap-closure, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-43/15-48's run-scoped proof of page work (G-15-23/G-15-26) and 15-47's single pending-page evaluation (G-15-27) — this plan promotes the first without reopening either"
  - phase: 15-continued-background-downloads
    provides: "15-49's widened inventory scan, which already reaches every file this plan edited"
provides:
  - "provenPageWorkRunPageDebts — the pages each gallery's current run still owes, replacing the membership set"
  - "sessionCreditedPages(gid:completedPageCount:pageCount:) — one definition of a gallery's session-credited pages, read by the opening snapshot and by the departure retirement"
  - "freezeSessionCreditForRetiringRun(gid:) — the run's final credited basis published as the session's last observation, which is what makes the departure retirement ordering-insensitive"
  - "A decrement inside flushManifestPageProgress, the single point every landed page passes"
  - "testARefusalRepairPausedPartWayDrainsAtTheWorkItActuallyDid — the drain-terminal pair for a repair paused after K of N"
  - "testARefusalRepairsIntermediatePushesStrictlyIncrease — a series property that fails against a numerator frozen at either constant"
  - "testAFailedRefusalRepairsGalleryContributesNothingWhileMerelyQueued — the queued window after a failed run, pinning the trust withdrawal"
  - "A re-derived run-proof census: four sites become six across five files"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Trust selects the branch; the run's outstanding work decides the size"
    - "A retiring run publishes its final basis before withdrawing the state that produced it, so both departure orderings retire the same number"
    - "A decrement carried as a SET of page numbers is idempotent under retries and inert for pages the run never owed"
    - "A corrected assertion must be shown capable of failing by an observed reading, not by argument"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift

key-decisions:
  - "The decrement point is flushManifestPageProgress, NOT the review's flushDownloadProgress: the derivation found a background page landing that reaches the manifest without passing the throttle, and the narrower point would have credited it nothing"
  - "The debt is a Set of page numbers, not a count: a retry can present one page twice and a restored-page flush can present pages the run never owed, and both over-credit under a count"
  - "The run's exit withdraws the SESSION trust its proof granted, alongside the debt — otherwise a debt-only retirement leaves a trusted record credited in full, which is the over-retirement in a new place"
  - "The run's exit freezes its final credited basis into observedSchedulablePages FIRST, which is what makes the trusted and last-observation retirement branches produce the same number"
  - "An INCOMPLETE-reading record still counts raw with nothing subtracted: its own count already excludes what the run has not written, so subtracting would remove those pages twice"
  - "The two gap-named cases moved their discriminator from the opening to the progression; under the corrected basis the opening reads the same for a kept proof and a lost one, so an opening assertion would have been vacuous"
  - "SC1 is deliberately NOT claimed: a numerator pinned HIGH is protective against D-11's stall amplifier where the pinned-zero one was lethal"

patterns-established:
  - "Publish-then-withdraw at a lifecycle boundary: a value derived from state about to be dropped is written to the collection its consumer will read instead"

requirements-completed: [SC2]

coverage:
  - id: D1
    description: "A refusal repair paused after K of N pages terminates at K, through reconcileContinuedSession's drain branch, rather than at the record's N"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift#testARefusalRepairPausedPartWayDrainsAtTheWorkItActuallyDid"
        status: pass
    human_judgment: false
  - id: D2
    description: "A refusal repair's pushed numerator climbs across at least three distinct values as its pages land, so no constant can satisfy it"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift#testARefusalRepairsIntermediatePushesStrictlyIncrease"
        status: pass
    human_judgment: false
  - id: D3
    description: "After a failed repair the gallery contributes nothing while merely queued — the queued-window zero D-G4-01 guarantees"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift#testAFailedRefusalRepairsGalleryContributesNothingWhileMerelyQueued"
        status: pass
    human_judgment: false
  - id: D4
    description: "Neither G-15-26 nor G-15-27 is reopened: the proof stays run-scoped and session-seeded, and the pending page list is still evaluated exactly once"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift#testRunScopedPageWorkProofSitesMatchTheRecordedCensus"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift#testPendingPageListEvaluationsMatchTheRecordedCensus"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift#testARepairPreparedWithNoLiveSessionIsCreditedByTheNextSession"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift#testAnUnavailableTeardownDoesNotStripTheRunsProofFromTheNextSession"
        status: pass
    human_judgment: false
  - id: D5
    description: "SC1 is not claimed by this plan; G-15-30 does not reach it through D-11's stall-expiration amplifier"
    verification: []
    human_judgment: true
    rationale: "Backstop truth. The round-16 verification judged that a numerator pinned HIGH is protective where the pinned-zero one was lethal, and no new evidence in this plan contradicts it."
  - id: D6
    description: "No device-observable change beyond the card's readings; 15-UAT.md test 2 remains an independent open axis"
    verification: []
    human_judgment: true
    rationale: "Backstop truth, device-only. Nothing here can discharge the physical-device re-run."

# Metrics
duration: 41min
completed: 2026-08-07
status: complete
---

# Phase 15 Plan 50: The Run's Own Work, Not the Record's Ceiling Summary

**The card now opens at the work a refusal repair has actually done, climbs page by page as pages land, and terminates at that same number for every departure kind in both orderings — because the run's proof of page work carries the PAGES it still owes instead of a bare membership, and the decrement rides the one write every landed page passes rather than the one the review named.**

## Performance

- **Duration:** 41 min
- **Started:** 2026-08-06T14:38Z
- **Completed:** 2026-08-06T16:19Z (wall clock includes four serialized `xcodebuild` invocations)
- **Tasks:** 3
- **Files modified:** 9

## `files_modified` — the provisional list rewritten to what was actually touched

The plan's frontmatter carried a PROVISIONAL line below the fold: `DownloadClient+PageDownload.swift`,
the pre-derived candidate for Derivation A's restored-pages route. **Derivation A dispositioned it as
owing no edit**, and one file the plan did not list was added. The actual set, with the derivation
result that put each path in or left it out:

| Path | In / out | Criterion |
|---|---|---|
| `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` | **in** | The promoted declaration and its doc; the two neighbouring docs it invalidated |
| `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` | **in** | The recording, now the pending list itself rather than its non-emptiness |
| `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` | **in** | The basis definition, the freeze, the session-start seed, the retirement branch, the D-G2-01 doc |
| `AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift` | **in** | The three-step retirement and its derivation |
| `AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift` | **in** | The derived decrement point |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift` | **in** | The re-derived run-proof census |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift` | **in** | Two corrected cases, two new regressions, the lifetime case's staging |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift` | **in** | The consequence-3 regression, two corrected assertions, the rewritten ceiling argument |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` | **in** | NOT in the plan's list. `pageResults` was file-private to the refusal suite and a second file now needs it; its own doc stated the promotion rule ("the shared helper surface earns a member when a second suite needs it"), so it was promoted rather than duplicated |
| `AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift` | **out** | Derivation A row 2: the restored-pages flush at `:99` reaches the decrement through `flushManifestPageProgress` like every other route, and the pages it carries are by construction outside the run's debt, so the set subtraction is inert there. No edit needed |

## Artifact list — the pre-derived candidate names rewritten to what landed

| Plan's candidate | What landed | Why |
|---|---|---|
| `provenPageWorkRunShortfalls: [String: Int]` | `provenPageWorkRunPageDebts: [String: Set<Int>]` | Derivation B: a count over-credits under a retry and under a restored-page flush; the page numbers are exact in both |
| "a basis accessor on the snapshot path" | `sessionCreditedPages(gid:completedPageCount:pageCount:)` | Takes the three primitives rather than a `DownloadedGallery`, so the departure retirement and the run-exit freeze — which hold a `DownloadManifest`, not a gallery — read the same definition |
| "a decrement, expected in `flushDownloadProgress`" | inside `flushManifestPageProgress` | Derivation A: the background page landing reaches the manifest without passing the throttle |
| "a retirement of the outstanding debt alongside `retireProvenPageWork`" | `retireProvenPageWork` became three steps: freeze, drop the debt, withdraw the trust | Derivation C needed the freeze; Derivation D needed the withdrawal |
| — (not anticipated) | `freezeSessionCreditForRetiringRun(gid:)` | The design change that buys ordering-insensitivity |
| `testAFailedRefusalRepairsGalleryReturnsToZeroWhileMerelyQueued` | `testAFailedRefusalRepairsGalleryContributesNothingWhileMerelyQueued` | The gallery's contribution returns to zero; the pushed numerator does not, because the monotonic floor holds the session's real work |
| `testARefusalRepairPausedPartWayDrainsAtTheWorkItActuallyDid` | unchanged | |
| `testARefusalRepairsIntermediatePushesStrictlyIncrease` | unchanged | |

**No new production types, no new public API surface, no new module** — as planned. `sessionCreditedPages` and `freezeSessionCreditForRetiringRun` are module-internal.

---

# Task 1 — the four derivations, and three regressions observed RED

## Derivation A — every route that RAISES a gallery's finished-page count during a run

Enumerated by these greps, run at HEAD `3961698c`:

```
grep -rn 'updateDownloadIndex' AppPackage/Sources/DownloadClient
grep -rn 'flushManifestPageProgress' AppPackage/Sources/DownloadClient
grep -rn 'refreshManifestPageFileHash' AppPackage/Sources/DownloadClient
grep -rn 'addingCurrentFileHashes' AppPackage/Sources/DownloadClient
grep -rn 'flushDownloadProgress' AppPackage/Sources AppPackage/Tests
```

| # | Site | Can it land a page THIS RUN owed? | Disposition |
|---|---|---|---|
| 1 | `+Persistence.swift:215` — `flushManifestPageProgress` inside `flushDownloadProgress` | **Yes** — this is the page loop's own cadence and forced flush | The decrement's primary route. Passes the chosen point |
| 2 | `+PageDownload.swift:99` — the DIRECT flush for RESTORED pages in `initializePageDownloadState` | **No, by construction** (see the overlap answer below) | Passes the chosen point anyway; the set subtraction is inert because the pages are not in the debt. No edit |
| 3 | `+BackgroundDownloads.swift:193` — a background page landing | **Yes** — an out-of-process task completing for a gallery whose run may still be live | **This row selected the decrement point.** It reaches `flushManifestPageProgress` and never `flushDownloadProgress`, so the review's proposed point would have credited it nothing |
| 4 | `+ExecutionPerform.swift:178` — `finalizeDownload`'s `addingCurrentFileHashes` + `updateDownloadIndex` | Only a page whose file landed but whose flush threw | Does NOT pass the decrement point. **Hole, under-crediting**: the record rises while the debt still holds the page, so the basis stays below truth until the run exits. Accepted; it runs on the success path only, microseconds before the `defer` |
| 5 | `+ExecutionSupport.swift:660` — the reconciliation's blanking write | No: it only ever LOWERS the count | Not a raise route. Enclosed by D-G7-01's bracket |
| 6 | `+ExecutionSupport.swift:690` — `ensureWorkingManifest`'s fresh manifest | No: all-empty, so it lowers or holds | Not a raise route |
| 7 | `+PublicAPI.swift:142`, `:147` — `writeInitialManifest`'s two branches | No: reuse re-indexes the same manifest; fresh is all-empty | Not a raise route. Enclosed by D-G7-01's bracket |
| 8 | `+PublicAPI.swift:346` — `performCacheCapture`'s `refreshManifestPageFileHash` | **Yes** — a cache restore can land a page the run owes | Does NOT pass the decrement point. **Hole, under-crediting**: the page is still in `remainingPageIndices`, so the run fetches it anyway and the flush then clears the debt. Self-healing. Accepted |

**The restored-pages overlap question, answered.** `pendingPageIndices` returns a page when its
relative path is absent from `workingSeed.existingPages` **or** its file does not exist now;
`collectExistingPages` restores a page when its relative path IS in that same map **and** its file
does exist. Under a single scan the two sets are exact complements — disjoint by construction. The
`restoredIndices` filter at `+PageDownload.swift:41-43` exists only because the two `fileExists`
probes are separated in time: a file that vanished at the first probe and reappeared at the second
is both pending and restored. Such a page is filtered out of `remainingPageIndices`, so the run
never fetches it and its debt entry is never cleared by a fetch — **but it IS cleared, because the
restored-pages flush at `:99` passes the same decrement point and carries that page number.** So the
residual cannot leave a page owed forever. Had the decrement been keyed on a count instead, this
same site would have over-decremented for every restored page; the set is what makes it exact.

**Direction rule applied.** Every hole above (rows 4 and 8) under-credits. No enumerated site can
over-credit, because the two that raise a complete-reading record's count cannot — a complete record
is already at N — and the subtraction applies only to a complete-reading record.

## Derivation B — the decrement point's correctness conditions

Point chosen: the last statement of `flushManifestPageProgress`, after `updateDownloadIndex`.

| Reach-without-a-record-rise condition | Disposition |
|---|---|
| `flushDownloadProgress`'s throttle guard returns before consuming | `flushManifestPageProgress` is never called. Credits nothing |
| `flushManifestPageProgress` returns early on an empty page list | Early return precedes the decrement. Credits nothing |
| `flushManifestPageProgress` returns early when the manifest file is absent | Early return precedes the decrement. Credits nothing |
| `refreshManifestPageFileHashes` / `writeManifest` throws | The decrement sits after both, so the throw skips it — the same condition that stops `flushDownloadProgress` from clearing `pendingResolvedPages`. Credits nothing |
| One page appears across two flushes after a retry | `Set.subtract` is idempotent. Credits once |

**The placement rule that keeps the decrement and the pending-page-list clearing from drifting.** The
clearing (`pendingResolvedPages.removeAll`) is gated on the success of exactly one call, and the
decrement is the last statement inside that call. Both are synchronous and no `await` separates them,
so no interleaving can observe one without the other and no future edit can move one without moving
the call they both hang off.

**The five test call sites of `flushDownloadProgress`, each with a verdict.** All five remain correct
under the decrement, because all five reach it through the same production write:

| Call site | Verdict |
|---|---|
| `DownloadContinuedSessionTests.swift:576`, `:583` | Correct — no run-scoped debt exists in that staging, so the subtraction is a no-op on a nil entry |
| `DownloadCoordinatorStorageTests.swift:779` | Correct — same |
| `DownloadObserverBatchTests.swift:126`, `:133` | Correct — same |
| `DownloadContinuedSessionExpirationTests.swift:386`, `:393` | Correct — same; this is the established production-flush staging two of this plan's regressions copy |

## Derivation C — the departure orderings, over every departure kind

Ordering **(i)** = the departure's `reconcileRetiredSessionPages` runs while the run's page debt is
still recorded. Ordering **(ii)** = `processDownload`'s `defer` has already retired it.

| Departure kind | Ordering (i) retires | Ordering (ii) retires |
|---|---|---|
| Run completion (`settleCompletedDownload`, `+Execution.swift:72`) | `sessionCreditedPages` = record − debt, and a completed run's debt is empty ⇒ the record | The frozen basis, computed the same way an instant earlier ⇒ the record |
| Run failure (`settleDownloadFailure`, `+BackgroundDownloads.swift:110`, `:144`, `+Persistence.swift:171`, every arm of `handleProcessDownloadError`) | record − debt | The frozen basis = record − debt |
| User pause through `pause(gid:)` | record − debt | The frozen basis = record − debt |
| Queued-work-item cancel | record − debt | The frozen basis = record − debt |
| Outright delete (no record survives) | The last observation, which the freeze has set to record − debt | The frozen basis = record − debt |
| D-11's expiration sweep through `pauseAllSchedulable` | record − debt | The frozen basis = record − debt |

**Every row's two values are the work the run actually did.** The design change that bought this is
`freezeSessionCreditForRetiringRun`: the run's exit publishes its final credited basis into
`observedSchedulablePages` **before** dropping the debt and the trust, so ordering (ii)'s
last-observation branch reads exactly what ordering (i)'s trusted branch would have computed. Without
it, ordering (ii) read "whatever the last push happened to record", which a background page landing
between the last push and the exit can leave stale.

**The user pause and the expiration sweep are issued from OUTSIDE the run**, so their ordering against
the cancelled run's `defer` is not controlled by either call site: `commitPause` nils `activeTask`
while the run it interrupts is still unwinding, and `pauseAllSchedulable` reaches the same primitive.
Those are the two rows that make ordering (i) real rather than theoretical; the three in-run
departures are the ones that make ordering (ii) the normal case.

## Derivation D — the outliving-trust arm, dispositioned

**What the snapshot-sourced union can and cannot re-add.** `observedIncompleteSessionGIDs` has exactly
two grantors: the run's proof, and `formUnion(snapshot.incompleteGalleryIDs)` inside
`reconcileRetiredSessionPages` (and the identically-shaped start seed). The second is built from
`isIncomplete`, so it **can** re-add any gid whose record honestly reads incomplete, at the very next
push — and it **provably cannot** re-add a record that reads COMPLETE, which is the entire reason the
run's proof exists.

**Chosen direction: the run's exit withdraws the trust its proof granted.** What it costs is that a
run's landed pages stop being credited through the gallery while it waits for its next run; the
monotonic floor still holds them, so the effect is a numerator that does not rise rather than one
that falls — the under-crediting direction. What it buys is D-G4-01's queued window restored exactly,
and — as the sensitivity reading below shows — the departure retirement itself: a debt-only
retirement leaves a trusted record credited its count MINUS nothing, because the debt that held the
correction no longer has an owner.

**Which observation re-adds it.** The snapshot's `formUnion`, on the next push, for as long as the
record reads incomplete. A complete-reading record is never re-added, which is the point.

## The three RED readings, quoted verbatim

Run: `xcodebuild test … -only-testing:DownloadsFeatureTests/DownloadContinuedSessionLedgerTests`
against the unmodified production tree — **23 tests, 7 issues, exit non-zero**. Every pre-existing
case passed; all seven issues belong to the three new cases.

```
✘ testARefusalRepairPausedPartWayDrainsAtTheWorkItActuallyDid
  DownloadContinuedSessionLedgerRefusalTests.swift:481: Expectation failed: (terminalPair.completedUnitCount → 6) == 2
  DownloadContinuedSessionLedgerRefusalTests.swift:482: Expectation failed: (terminalPair.totalUnitCount → 6) == 2
  DownloadContinuedSessionLedgerRefusalTests.swift:483: Expectation failed: (terminalPair.subtitle → "6 / 6 pages · 0 galleries") == "2 / 2 pages · 0 galleries"

✘ testARefusalRepairsIntermediatePushesStrictlyIncrease
  DownloadContinuedSessionRunProofTests.swift:386: Expectation failed: (Set(numerators).count → 1) >= 3

✘ testAFailedRefusalRepairsGalleryContributesNothingWhileMerelyQueued
  DownloadContinuedSessionRunProofTests.swift:472: Expectation failed: (spy.progressUpdates.map(\.completedUnitCount) → [6, 6]).contains(2)
  DownloadContinuedSessionRunProofTests.swift:494: Expectation failed: (finalPair.completedUnitCount → 6) == 2
  DownloadContinuedSessionRunProofTests.swift:496: Expectation failed: (finalPair.subtitle → "6 / 16 pages · 2 galleries") == "2 / 16 pages · 2 galleries"
```

The first observed reading of `Set(numerators).count → 1` is worth reading twice: against the
unmodified tree the refusal family's numerator takes **exactly one value** across the whole
re-download. That is consequence 2 measured rather than argued.

**Which of Derivation C's orderings each case exercises**, stated in each case's own doc: the
paused-departure case exercises ordering (i) — no run is driven to an exit, so the pause finds the
debt standing; the queued-window case exercises ordering (ii) — a real `processDownload` unwinds
through its `defer` before the failure's dequeue is detected. Each names the other as its companion.

### One staging correction, recorded

The queued-window case first failed on `waitUntil { testingHasActiveTask() == false }` after
`processDownload`. That was a staging defect, not a finding: `waitUntil` evaluates its condition once
in the loop and again in the `#require`, and the exit's own convergence legitimately schedules the
surviving gallery in between, so the active slot flickers true → false → true. It was replaced with a
MONOTONE production observation — the pushed gallery count crossing to one, and back to two after the
re-queue — which crosses once each.

---

# Task 2 — the mechanism

## The membership set is GONE

```
$ grep -rn 'provenPageWorkRunGIDs' --include='*.swift' .
(no output)
```

**Zero surviving mentions, including doc comments.** Every doc that named it was rewritten to the
promoted name rather than left to record history, so there is nothing to quote under the plan's
"surviving doc mention" allowance.

## The two invariants that must not reopen, each confirmed by a quoted line

**G-15-26 — run-scoped, session-seeded.** The recording is outside the live-session branch
(`+ExecutionSupport.swift:504`, the `if let continuedSessionID` opens on the line after it):

```swift
if !pendingPages.isEmpty {
    provenPageWorkRunPageDebts[payload.gallery.gid] = Set(pendingPages)
    if let continuedSessionID {
```

No clear exists in `markContinuedSessionEnded` or in `ensureContinuedSession`'s reset — the census
below counts every site and there is none in either. The session start still seeds inside the
SYNCHRONOUS reset, ahead of the snapshot the opening subtitle is built from
(`+ContinuedSession.swift:336`, with `let snapshot = await schedulableSnapshot()` two lines later):

```swift
observedIncompleteSessionGIDs = Set(provenPageWorkRunPageDebts.keys)
```

**G-15-27 — one evaluation.** `performDownload` still consumes `preparedRun.pendingPageIndices`
(`+ExecutionPerform.swift:47`) and the census is re-derived unchanged at 1:

```
$ grep -rn 'pendingPageIndices(' AppPackage/Sources/DownloadClient | grep -v '///'
AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:498:        let pendingPages = pendingPageIndices(
AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift:859:    public func pendingPageIndices(
```

`:859` is the declaration, excluded by the census's `declarationPrefix` filter. One call, in
`+ExecutionSupport.swift`, exactly as before.

## The basis — one definition, three derived branches

```swift
func sessionCreditedPages(
    gid: String,
    completedPageCount: Int,
    pageCount: Int
) -> Int {
    let recorded = min(max(completedPageCount, 0), max(pageCount, 0))
    guard recorded >= pageCount else { return recorded }
    guard observedIncompleteSessionGIDs.contains(gid) else { return 0 }
    return max(recorded - (provenPageWorkRunPageDebts[gid]?.count ?? 0), 0)
}
```

- **Incomplete ⇒ raw.** An incomplete record's own count already excludes the pages this run has not
  written — that is what incomplete means — so subtracting the debt would remove them twice.
- **Trusted and complete-reading ⇒ record minus the debt.** For the refusal family the record's count
  IS the run's remaining work, so this is the only branch where the two quantities are opposites and
  the only branch G-15-30 touches.
- **Otherwise zero**, D-G4-01's queued window, unchanged.
- **The clamp is required, not defensive.** The debt is derived against the WORKING FOLDER and the
  count against the INDEX RECORD; a repair whose folder is emptier than its record claims makes the
  debt legitimately exceed the count.

Both readers call it: `schedulableSnapshot`'s `reduce(into:)` and `reconcileRetiredSessionPages`'
trusted branch.

## D-G7-01 interaction — derived, not assumed

`withdrawingCountedBasisMovement` withdraws the RECORD's raw before/after delta; the numerator moves
by the basis delta. `max(x − owed, 0)` is non-decreasing in `x` and 1-Lipschitz, so **the basis delta
can only be smaller than the record delta, never larger**: a withdrawal may take more off the floor
than the numerator lost, never less. A floor left low re-latches at the very next push while a floor
left high is the defect, so **the difference errs in the safe direction by construction.**

## The decrement, quoted beside the clearing it must not drift from

```swift
// DownloadClient+Persistence.swift — flushManifestPageProgress, last statement
updateDownloadIndex(folderURL: folderURL, manifest: manifest)
provenPageWorkRunPageDebts[manifest.gid]?.subtract(pageRelativePaths.keys)
```

```swift
// DownloadClient+Persistence.swift — flushDownloadProgress, the clearing
try flushManifestPageProgress(
    folderURL: context.folderURL,
    pages: resolvedPages
)
pendingResolvedPages
    .removeAll(keepingCapacity: true)
```

Every Derivation B condition credits nothing when the record did not rise, as tabulated above.

## The retirement — three steps

```swift
private func retireProvenPageWork(gid: String, generation: Int?) {
    guard !isSupersededByALiveRun(gid: gid, generation: generation) else { return }
    freezeSessionCreditForRetiringRun(gid: gid)
    provenPageWorkRunPageDebts[gid] = nil
    observedIncompleteSessionGIDs.remove(gid)
}
```

The superseded-run gate is unchanged and now covers all three, for the reason it already recorded: a
superseded predecessor must not drop a live successor's state.

## The run-proof census, re-derived by a fresh grep

```
$ grep -rn 'provenPageWorkRunPageDebts' AppPackage/Sources/DownloadClient | grep -v '///' | grep -v ': *//'
…+Manager.swift:631:    var provenPageWorkRunPageDebts = [String: Set<Int>]()
…+ExecutionSupport.swift:504:            provenPageWorkRunPageDebts[payload.gallery.gid] = Set(pendingPages)
…+Persistence.swift:273:        provenPageWorkRunPageDebts[manifest.gid]?.subtract(pageRelativePaths.keys)
…+Execution.swift:331:        provenPageWorkRunPageDebts[gid] = nil
…+ContinuedSession.swift:235:        return max(recorded - (provenPageWorkRunPageDebts[gid]?.count ?? 0), 0)
…+ContinuedSession.swift:336:        observedIncompleteSessionGIDs = Set(provenPageWorkRunPageDebts.keys)
```

**Four sites become six across five files**, and the table's doc was rewritten to say what the new
number pins: four pinned a lifetime alone (recorded, read, retired); six pin the lifetime **and the
arithmetic**, because a seventh site is now either a second reader of the credited basis — how the
opening rule and the departure rule come to disagree about one gallery — or a second writer of the
debt. The `+Persistence.swift` entry is load-bearing as a count of ONE: a second decrement point means
a landed page credited twice.

## The targeted proof

`-only-testing:…LedgerTests -only-testing:…SourceInventoryTests` — **29 tests, 6 issues**. All three
regressions PASS, every census passes, and the failing set is exactly the six pre-existing basis
assertions enumerated below. No seventh failure appeared.

Notably, **the two terminal-pair assertions at `…RefusalTests.swift:147-151` and `:264-267` PASSED
unchanged.** Those cases land their pages through a direct `flushManifestPageProgress` call, so they
credit only because the decrement lives there rather than in `flushDownloadProgress`. That is the
derivation beating the review's proposal, observed rather than argued.

---

# Task 3 — the pinned cases, the docs, the sweep

## Step 1 — every assertion encoding the pre-fix basis, enumerated and classified

```
$ grep -rn '"[0-9]\+ / [0-9]\+ page' \
    AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift \
    AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift
```

(plus the numeric-count siblings at `RunProofTests:127-128` and the two terminal pairs, which carry no
subtitle literal.)

**Encodes the defect — six, and the two the gap named are two of them:**

| # | File:line | Assertion | Observed under the corrected basis |
|---|---|---|---|
| 1 | `RunProofTests:127` | `startCompletedUnitCounts.last == 6` | `0` |
| 2 | `RunProofTests:129` | `startSubtitles.last == "6 / 6 pages · 1 gallery"` | `"0 / 6 pages · 1 gallery"` — **named by the gap** |
| 3 | `RunProofTests:199` | `progressUpdates…contains("6 / 6 pages · 1 gallery")` | `["0 / 6 pages · 1 gallery"]` |
| 4 | `RunProofTests:212` | `startSubtitles.last == "6 / 6 pages · 1 gallery"` | `"0 / 6 pages · 1 gallery"` — **named by the gap** |
| 5 | `RefusalTests:136` | `contains("6 / 6 pages · 1 gallery")` | `["0 / 6 pages · 1 gallery"]` |
| 6 | `RefusalTests:251` | `contains("6 / 6 pages · 1 gallery")` | `["0 / 6 …", "5 / 6 …"]` |

**Encodes a rule that still holds — untouched:**

| File:line | Rule |
|---|---|
| `RefusalTests:110`, `:224`, `:344`, `:439` | The queued-window zero at the start (D-G4-01) |
| `RefusalTests:150` + counts, `:267` + counts | The terminal `6 / 6 pages · 0 galleries` for a repair that FINISHED all six — now honestly earned, since the debt reached empty |
| `RefusalTests:377` | The selected-page retry that fetches nothing stays at zero (G-15-27) |
| `RunProofTests:128` | The denominator, which the rule never touches |
| `RunProofTests:185` | The pre-preparation opening zero |
| `RunProofTests:309` (now `:405`) | The lifetime boundary's redo opening at zero |

Editing only the two the gap named would have left four.

## Step 2 — the discriminator moved, not substituted

Under the corrected basis both named cases' openings read the same for a kept proof and a lost one:
the run owes all six pages at that instant, so the credited work is zero either way. Replacing `"6 / 6"`
with `"0 / 6"` would have restored the pre-G-15-26 constant while claiming to fix it. So:

- `testARepairPreparedWithNoLiveSessionIsCreditedByTheNextSession` — the opening is **demoted** to a
  recorded fact and the proof moves to: land two pages through `flushDownloadProgress` after the
  start, assert the credited work RISES above the opening and equals the two pages landed.
- `testAnUnavailableTeardownDoesNotStripTheRunsProofFromTheNextSession` — both halves move. Two pages
  land in session 1 (the numerator must reach two, which proves the trust was EARNED), two more land
  in session 2 (it must reach four, which proves the trust SURVIVED).

Each case's doc records why the opening was demoted and what replaced it. Both keep their original
subject and staging: the seeding route, the teardown route and the no-session precondition are
untouched.

## Step 3 — both sensitivity readings per corrected case

**Perturbation:** `+ContinuedSession.swift`'s session-start seed changed from
`observedIncompleteSessionGIDs = Set(provenPageWorkRunPageDebts.keys)` to
`observedIncompleteSessionGIDs = []`, nothing else. That is the G-15-26 mechanism both cases exist to
pin.

**FAIL with the seed removed** (23 tests, 4 issues — exactly these two cases):

```
✘ testARepairPreparedWithNoLiveSessionIsCreditedByTheNextSession
  DownloadContinuedSessionRunProofTests.swift:166: Expectation failed: (creditAfterLanding → 0) > (openingCredit → 0)
  DownloadContinuedSessionRunProofTests.swift:167: Expectation failed: (creditAfterLanding → 0) == 2

✘ testAnUnavailableTeardownDoesNotStripTheRunsProofFromTheNextSession
  DownloadContinuedSessionRunProofTests.swift:286: Expectation failed: (creditInSecondSession → 0) > (creditInFirstSession → 2)
  DownloadContinuedSessionRunProofTests.swift:287: Expectation failed: (creditInSecondSession → 0) == 4
```

**PASS with the seed restored** (same invocation, unperturbed):

```
✔ Test run with 23 tests in 1 suite passed after 0.641 seconds.
```

### Two further sensitivity readings, taken because a written claim demanded them

**(a) The lifetime case's own doc demanded one and could no longer deliver it.**
`testAProofDoesNotOutliveItsRunIntoALaterRedo` asserted that with the retirement removed it must
fail. Under the promoted shape that had quietly become **false**: an un-retired entry owing all six
pages subtracts back to exactly the zero the case asserts — the stale debt cancels the stale trust
and the case goes vacuous again, for a new reason. The staging was corrected (two of the six paid
inside the first run, through the production flush) and the perturbation re-run:

```
Perturbation: retireProvenPageWork's body emptied (freeze, debt drop and trust withdrawal all removed)
✘ testAProofDoesNotOutliveItsRunIntoALaterRedo
  DownloadContinuedSessionRunProofTests.swift:405: Expectation failed: (spy.startCompletedUnitCounts.last → 2) == 0
  DownloadContinuedSessionRunProofTests.swift:406: Expectation failed: (spy.startSubtitles.last → "2 / 6 pages · 1 gallery") == "0 / 6 pages · 1 gallery"
```

**(b) The trust withdrawal is a design choice this plan added, so it was pinned rather than argued.**

```
Perturbation: ONLY `observedIncompleteSessionGIDs.remove(gid)` deleted from retireProvenPageWork
✘ testAFailedRefusalRepairsGalleryContributesNothingWhileMerelyQueued
  DownloadContinuedSessionRunProofTests.swift:591: Expectation failed: (finalPair.completedUnitCount → 6) == 2
  DownloadContinuedSessionRunProofTests.swift:593: Expectation failed: (finalPair.subtitle → "6 / 16 pages · 2 galleries") == "2 / 16 pages · 2 galleries"
```

Both restored and green in the full run below. All four perturbations were reverted and verified
against the committed tree by `git diff` before the final run.

## Step 4 — the two rewritten docs, quoted in full

### (a) `reconcileRetiredSessionPages`' earned-authority paragraph, rewritten from Task 2's implementation

> **The record's authority is earned AND bounded (D-G4-01, G-15-30).** It is authoritative about the
> *manifest*, and about nothing else. Trust decides whether it speaks for this session at all: only
> for a gallery this session has already trusted — observed incomplete, or proven page work for at
> the run's own preparation — is a surviving record consulted, and a departed gallery outside
> `observedIncompleteSessionGIDs` retires its last observation instead, which the same rule made zero
> while it was present. A redo that never ran — a complete manifest queued for an update and then
> cancelled — would otherwise retire pages the session never downloaded into both sides of the
> fraction and report a finished session.
>
> What the record is authoritative FOR is the manifest's finished-page count. What corrects it is the
> pages the gallery's run still OWES: `sessionCreditedPages` subtracts them, and a departure retires
> exactly that corrected number rather than the count itself. Trust alone was not enough, because for
> the refusal family the two quantities are opposites — the reconciliation hands the manifest back
> verbatim, so the record reads N-of-N for the entire re-download while the run has fetched a
> fraction of N. Retiring N there put the run's UNDONE work into both sides of the fraction, and when
> the departing gallery was the session's last the drain branch reported a paused or
> expiration-swept repair as a fully successful N-page completion.
>
> This is still not a departure-reason branch. The formula takes no reason parameter, no call site
> classifies why a gallery left, and completion, pause, delete, cancel and expiration are treated
> identically; the gate reads only what this session observed while the gallery was there, and the
> correction reads only what that gallery's run had left to do.
>
> Departures are also detected on either side of a run's own exit, and both sides retire the same
> number by construction: `freezeSessionCreditForRetiringRun` publishes the run's final corrected
> basis as this session's last observation before the run's proof is withdrawn, so the
> last-observation branch below reads what the trusted branch would have computed. That derivation
> lives on the freeze itself.
>
> Accepted residual: a never-trusted redo that starts *and* finishes entirely between two
> observations retires at its observed basis of zero. That is the unobserved-work convention above
> reached from one observation further out, and the direction is deliberate — under-retiring keeps
> the fraction at or below truth, while over-retiring is the defect.

Derived from Derivation C's table and Task 2's Step 5. It **keeps** the not-a-departure-reason-branch
claim and the direction rule verbatim, because both survived re-checking.

### (b) The refusal suite's `BY DESIGN` ceiling argument, rewritten as a test doc

> **Which series helper applies here, and why the previous answer was wrong for most of the family
> (G-15-30).** This case used to record that `expectTheFractionReachesOneOnlyAtTheDrain` did not
> apply, on the argument that a trusted complete-reading record honestly rides at its own ceiling BY
> DESIGN — the record genuinely claims six pages and the refusal is precisely the defence against
> destroying those six recorded hashes. That argument was sound for exactly one departure, the one
> this case's own staging drives: a repair that COMPLETES, where the terminal six happens to be true.
> It said nothing about the paused, deleted, cancelled and expiration-swept departures that reach the
> same retirement through the same line, and for those the ceiling is not honest at all.
>
> The rule that holds for the whole family is narrower: a refusal-family gallery is credited with its
> record's count MINUS the pages its run still owes, so the fraction reaches one when the run has
> actually fetched them and not before. Under that rule this case does reach one only at the drain,
> because its last two pages land immediately before the settle — but the helper is still not
> asserted, and now for a stated reason rather than an argued exemption: the retirement folds those
> pages into both sides at the drain, so the LAST push before it already reads six of six over one
> gallery. That is a fact about where this staging puts its final flush, not a property of the
> family, and pinning it would pin the staging. `expectTheCompletedSeriesNeverRewinds` is asserted
> instead, and the climb it guards is asserted directly by the intermediate reading below.
>
> The departure half of the family — the ceiling being retired for a repair that did NOT finish — is
> covered by `testARefusalRepairPausedPartWayDrainsAtTheWorkItActuallyDid` in this file, which pauses
> after two of six pages and asserts the drain's terminal pair is the two. The queued window, where
> nothing has run at all, stays pinned by the assertion above and by
> `testACompleteGalleryQueuedForUpdateOpensTheCardAtZero` in the sibling file.

Neither rewrite reproduces the gap record's or the review's phrasing, and neither was copied from the
other: the production doc states the retirement rule, the test doc states which series helper applies
and names the case covering the departure half.

## The consequence-3 case's terminal reading

```
terminalPair = (completedUnitCount: 2, totalUnitCount: 2, subtitle: "2 / 2 pages · 0 galleries")
spy.finishSuccesses == [true]
```

Produced by `reconcileContinuedSession`'s **drain branch** — the gallery is the session's only one,
the pause removes it from the queue store, and the convergence tail finds no pending work. Two pages
of real work, reported as two, with `finish(success: true)` telling the truth about what the session
covered. Against the unmodified tree the same line read `"6 / 6 pages · 0 galleries"`.

## Step 5 — the residue sweep, four checks

**(a) Orphans.**

```
$ grep -rn 'provenPageWorkRunGIDs' --include='*.swift' .
(no output)
```

Zero survivors, doc comments included.

**(b) Newly-unowned claims.** Greps for `unlock`, `full count`, `whole count`, `record's ceiling`,
`retires what the record`, `the record's own count`, `authoritative about this session` across both
trees. Every hit is either the corrected past-tense description of the defect or the new rule itself.
Three standing claims were found and rewritten beyond the two the plan named:

| Site | Claim | Correction |
|---|---|---|
| `+ContinuedSession.swift` — the departed-records comment | "reading it is what makes a gallery that completed between two pushes retire its full page count" | Now says it retires the record corrected by the run's outstanding debt, which for a run that really did finish is zero — so a completion still retires its whole count |
| `+Manager.swift` — `observedIncompleteSessionGIDs`' opening paragraph | "the record is authoritative twice over … its departure retires what that record says it finished" | Now bounds it: authoritative about the COUNT, not about how much of it this session earned |
| `RunProofTests` — the lifetime case's opening paragraph | "a proof … never retired makes every later redo open at its record's full page count" | Now describes the mechanism the promoted shape actually produces: the trust survives, so the redo selects the credited branch and opens at the record less whatever debt the dead run left |

`+Manager.swift`'s `observedIncompleteSessionGIDs` doc also gained the within-session withdrawal,
which its session-scoping paragraph would otherwise have contradicted.

**(c) Census reach.**

```
$ git diff --name-only 3961698c -- AppPackage | sed 's#/[^/]*$##' | sort -u
AppPackage/Sources/DownloadClient
AppPackage/Tests/DownloadsFeatureTests
```

Both are exactly 15-49's `scannedDirectories`, so every file this plan edited is inside the widened
inventory scan: a reintroduction of a corrected claim fails a build rather than waiting for a review
round.

**(d) Direction audit — every accepted residual this plan created:**

| Residual | Direction |
|---|---|
| Derivation A row 4 — `finalizeDownload`'s hash fill for a page whose flush threw | **Under-crediting.** The record rises while the debt still holds the page |
| Derivation A row 8 — `performCacheCapture` landing an owed page | **Under-crediting**, and self-healing: the run still fetches the page and the flush then clears the debt |
| Derivation D — the trust withdrawal at the run's exit | **Under-crediting.** A failed run's landed pages stop being credited through the gallery; the monotonic floor still holds them, so the numerator does not rise rather than falling |
| Ordering (ii)'s frozen basis vs a basis measured an instant later | **Under-crediting.** The freeze cannot be newer than the exit |

All four err downward. No enumerated residual over-credits.

## Step 6 — full green

```
xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests \
  -destination 'platform=iOS Simulator,name=iPhone Air'
** TEST SUCCEEDED ** [95.997 sec]

totalTestCount = 883
passedTests    = 876
failedTests    = 0
skippedTests   = 0
expectedFailures = 7
result = Passed
```

**883 against 15-49's recorded 880**, and the movement is accounted for case by case: `+3`, being the
three regressions Task 1 added. No case was added for Derivation C's second ordering — the
queued-window regression already reaches it — and no case was removed. The seven expected failures
are the target's pre-existing known issues, unchanged.

No SwiftLint rule is suppressed, disabled or annotated away anywhere in this plan; the plugin runs on
every build above at error severity and reported nothing. No changed file crosses 1000 lines
(`+ExecutionSupport.swift` 888, `+ContinuedSession.swift` 820, `+Manager.swift` 800). No `xcodebuild`
invocation overlapped another — all six were serialized.

---

## Deviations from Plan

### Auto-fixed / auto-derived, no user decision required

**1. [Rule 2 — derivation overrides the plan's candidate] The decrement point is `flushManifestPageProgress`, not `flushDownloadProgress`**
- **Found during:** Task 1, Derivation A
- **Issue:** The plan and the review both named `flushDownloadProgress`. Derivation A found
  `+BackgroundDownloads.swift:193`, an out-of-process page landing that reaches the manifest without
  passing the throttle at all, so the named point would have left it crediting nothing.
- **Fix:** The decrement lives at the last statement of `flushManifestPageProgress`, which all three
  production flush routes pass through.
- **Files:** `DownloadClient+Persistence.swift`
- **Commit:** `818d229f`
- **Evidence it mattered:** the two existing terminal-pair assertions at `RefusalTests:147-151` and
  `:264-267` land their pages through a direct `flushManifestPageProgress` call and passed unchanged;
  under the review's point they would have read `0 / 0`.

**2. [Rule 2 — derivation overrides the plan's candidate] The debt is a `Set<Int>`, not an `Int`**
- **Found during:** Task 1, Derivation B
- **Issue:** A count over-decrements when a retry presents one page across two flushes, and again when
  the restored-pages flush carries pages the run never owed. Both over-credit.
- **Fix:** `[String: Set<Int>]`, subtracted by page number.
- **Files:** `DownloadClient+Manager.swift` and every consumer.
- **Commit:** `818d229f`

**3. [Rule 2 — missing critical mechanism] `freezeSessionCreditForRetiringRun`**
- **Found during:** Task 1, Derivation C
- **Issue:** With only the debt drop, ordering (ii) retired "whatever the last push recorded", which a
  background landing can leave stale — the design would have been ordering-sensitive.
- **Fix:** The run's exit publishes its final credited basis before withdrawing the state that
  produced it.
- **Files:** `DownloadClient+ContinuedSession.swift`, `DownloadClient+Execution.swift`
- **Commit:** `818d229f`

**4. [Rule 2 — missing critical mechanism] The run's exit withdraws the session trust its proof granted**
- **Found during:** Task 1, Derivation D
- **Issue:** A debt-only retirement leaves a trusted complete-reading record credited its count minus
  nothing — the over-retirement in a new place.
- **Fix:** `observedIncompleteSessionGIDs.remove(gid)` inside `retireProvenPageWork`.
- **Files:** `DownloadClient+Execution.swift`
- **Commit:** `818d229f`
- **Pinned by:** the isolated sensitivity reading quoted above.

**5. [Rule 1 — a written argument that source does not implement] The lifetime case's sensitivity claim had become false**
- **Found during:** Task 3, Step 3
- **Issue:** `testAProofDoesNotOutliveItsRunIntoALaterRedo`'s doc demanded a failing reading with the
  retirement removed. Under the promoted shape a stale debt of six cancels the stale trust exactly,
  so the case passed either way — vacuous again, for a new reason. This is the same failure class the
  plan exists to close, found in a case the plan did not name.
- **Fix:** Two of the six pages are paid inside the first run, breaking the cancellation; the doc says
  why. The perturbation was then run and the failure OBSERVED.
- **Files:** `DownloadContinuedSessionRunProofTests.swift`
- **Commit:** `fc48fe82`

**6. [Rule 3 — blocking] `pageResults` promoted to the shared helpers**
- **Found during:** Task 1
- **Issue:** File-private to the refusal suite; the run-proof cases now stage page landings the same
  way and cannot see it.
- **Fix:** Promoted beside `writePageFiles`, on the rule its own doc stated. Adds
  `DownloadFeatureTestHelpers.swift` to `files_modified`.
- **Commit:** `46aec511`

**7. [Rule 1 — test staging defect] The queued-window case's quiescence poll was racy**
- **Found during:** Task 1, first RED run
- **Issue:** `waitUntil { testingHasActiveTask() == false }` evaluates its condition twice and the
  exit's own convergence reschedules the surviving gallery in between.
- **Fix:** Replaced with a monotone production observation (the pushed gallery count crossing).
- **Commit:** `46aec511`

### Deliberately NOT done

- **The plan's "six pre-existing assertions" count was checked, not assumed.** The recorded grep found
  exactly six defect-encoding assertions, matching the plan. The classification of the remaining ten
  is recorded above.
- **SC1 is not claimed.** The round-16 judgement — that a numerator pinned HIGH is protective against
  D-11's stall amplifier where the pinned-zero one was lethal — is not relitigated.
- **15-UAT.md test 2 is not discharged.** It remains an independent open axis.

## Known limitations, stated rather than left implicit

- **Derivation C's two orderings can measure the run's basis at instants a few microseconds apart.**
  Neither can produce the record's ceiling and neither exceeds truth; the freeze makes them read the
  same expression, and any residual difference is a page that landed in between, erring downward.
- **A background page landing for a gallery whose run has ended cannot be staged by any current
  fixture.** That is the one observation that would separate "the debt entry survived" from "the trust
  survived" independently of the departure retirement. The trust withdrawal is instead pinned through
  the departure, which the sensitivity reading above shows is sufficient to discriminate.
- **The overlapping-run gating recorded in 15-48-SUMMARY remains unowned by a test**, unchanged by this
  plan: no fixture can both hold a runner open mid-run and reach the working-seed preparation.

## Self-Check: PASSED

Files asserted to exist:

- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionRunProofTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` — FOUND

Commits asserted to exist:

- `46aec511` — FOUND
- `818d229f` — FOUND
- `fc48fe82` — FOUND
