---
phase: 15-continued-background-downloads
plan: 26
subsystem: downloads
tags: [continued-processing, background-downloads, progress-accounting, tdd, swift-testing]

requires:
  - phase: 15-continued-background-downloads
    provides: "D-G5-01's reconcileWorkingManifestAgainstPageFiles and prepareWorkingSeedAnnouncingProgress (15-25), D-G4-01's counted basis and trust set (15-24), D-G2-01's retirement ledger (15-22)"
provides:
  - "D-G6-01: a coordinator-made basis correction withdraws its counted portion from the monotonic floor in the same synchronous stretch that lowers the basis"
  - "The session-start floor seed is an additive merge, so a withdrawal landing inside the client-start main-actor hop survives it"
  - "WR-01: schedulableDownloads() unions activeGalleryID into its queue-scoped read, so the one authority can see the gallery it is running"
  - "WR-02: prepareWorkingSeed is private, so reverting performDownload to the silent preparation is a compile error"
  - "WR-03: the reconciliation's deliberate-consequence doc names storage.validate and both of its consumers"
  - "DownloadContinuedSessionBasisTests — three regressions (correction-then-departure, start-hop seed, running-gallery lag), all observed failing before the fix"
affects: [continued-processing-session, download-scheduling, background-downloads]

tech-stack:
  added: []
  patterns:
    - "Whoever blanks, withdraws: a basis correction and its floor withdrawal live in one non-suspending body, so no push can observe half of it"
    - "Session-scoped scalars seeded across a suspending client start MERGE rather than assign (now applied to all three: the two trust collections and the floor)"
    - "Shared pushed-pair test vocabulary lives in DownloadFeatureTestHelpers; the manual index-patch seam stays private to the ledger suite deliberately"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadInterruptedResumeTests.swift

key-decisions:
  - "D-G6-01: the floor masks only movements the coordinator did not deliberately make; a correction withdraws its counted portion at the correction site"
  - "The withdrawal lives inside reconcileWorkingManifestAgainstPageFiles, not in the announcing wrapper, so every route that converges on prepareWorkingSeed inherits it by construction and the basis/floor pair is atomic on the actor"
  - "The withdrawal is exact-portion: an untrusted complete-reading record contributed zero and withdraws zero, which is what preserves D-G4-01's open-at-zero ceiling guarantee and the whole 15-25 arc"
  - "The subtraction is unclamped and the session-start seed becomes max(snapshot + floor, 0), one fact in one variable rather than a clamped withdrawal plus a hop-window accumulator"
  - "WR-01's union widens WHICH records the scoped read fetches, never WHAT the predicate accepts; the empty-queue full index read is preserved verbatim"

patterns-established:
  - "Coordinator-caused basis movements are excused from the monotonic floor rather than the floor being weakened"
  - "A regression for a serial queue must stage a departure without re-earning; blanking pages of one gallery in a two-gallery queue is vacuous"

requirements-completed: []  # Phase 15 maps no REQUIREMENTS.md IDs. The plan's `requirements: [SC2, SC1]` are ROADMAP success criteria; this plan closes G-15-6 in code but does NOT discharge SC2's physical-device axis (15-UAT.md test 2).

coverage:
  - id: D1
    description: "D-G6-01 withdrawal: a counted gallery corrected then departing without re-earning no longer freezes the survivor's pushes"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift#testABlankedGalleryPausedPartWayDoesNotFreezeTheSurvivorsPushes"
        status: pass
    human_judgment: false
  - id: D2
    description: "The additive floor seed: a withdrawal landing inside the client-start main-actor hop survives the seeding that follows it"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift#testAWithdrawalDuringTheClientStartHopSurvivesTheFloorSeed"
        status: pass
    human_judgment: false
  - id: D3
    description: "WR-01: the running gallery stays in the card's numerator, denominator and gallery count when the persisted queue lags behind it"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift#testTheRunningGalleryStaysInTheSessionBasisWhenThePersistedQueueLagsBehindIt"
        status: pass
    human_judgment: false
  - id: D4
    description: "WR-02: prepareWorkingSeed is private, so reverting performDownload to the silent preparation no longer compiles"
    verification:
      - kind: other
        ref: "grep -v '^\\s*//' DownloadClient+ExecutionSupport.swift | grep -c 'public func prepareWorkingSeed(' → 0; 'private func prepareWorkingSeed(' → 1; grep -rn 'prepareWorkingSeed(' AppPackage/Tests | grep -cv AnnouncingProgress → 0; full FeatureTests build+run TEST SUCCEEDED"
        status: pass
    human_judgment: false
  - id: D5
    description: "WR-03: the reconciliation's deliberate-consequence paragraph names validatePage's empty-hash skip, both consumers (validateImageData, loadManifest), and why .valid for an unclaimed page is correct"
    verification:
      - kind: other
        ref: "grep -c validateImageData / loadManifest in DownloadClient+ExecutionSupport.swift → present in the consequence doc"
        status: pass
    human_judgment: true
    rationale: "The deliverable is the accuracy of a prose disposition of a review warning; a grep proves the tokens landed, not that the argument is right. The verifier must read the paragraph against 15-REVIEW.md WR-03."
  - id: D6
    description: "SC2 on physical hardware: the card climbs across a completion, a mid-queue pause and a repair, and card-cancel matches the in-app per-gallery pause"
    verification: []
    human_judgment: true
    rationale: "The system card and the scheduler's stall-expiration response do not exist in the simulator. 15-UAT.md test 2 remains an open physical iOS 26 device re-run; NOTHING in this plan closes it."

duration: 45min
completed: 2026-08-05
status: complete
---

# Phase 15 Plan 26: G-15-6 Closure (D-G6-01) Summary

**The monotonic floor now gives back exactly what a coordinator-made basis correction took, at the moment it takes it — so a reconciled gallery that departs without re-earning its blanked pages can no longer freeze the card across every other gallery's real work.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-08-04T16:45:00Z
- **Completed:** 2026-08-04T17:30:45Z
- **Tasks:** 2
- **Files modified:** 9 (8 modified, 1 created)

## Accomplishments

- **D-G6-01 installed at the correction site.** `reconcileWorkingManifestAgainstPageFiles` now subtracts the blanked-page count from `lastPushedCompletedPageCount` in the same non-suspending body that blanks the hashes, writes the manifest and updates the index — but only when the pre-blanking record was actually being counted (it read incomplete, or its gid was already in `observedIncompleteSessionGIDs`).
- **The second absorber closed.** The session-start floor seed became `max(snapshot + floor, 0)`, so a withdrawal landing inside the client start's main-actor hop is folded in rather than overwritten by the pre-hop snapshot.
- **Three docs re-derived where the code lives:** the push's invalidated floor premise, the scalar's declaration (four writers plus the deliberate negative transient), and the reconciliation's consequence paragraph.
- **WR-01 fixed:** the one authority for selecting schedulable work now unions `activeGalleryID` into its queue-scoped read.
- **WR-02 fixed structurally:** `prepareWorkingSeed` is private; the demonstrated silent-variant revert is now a compile error.
- **WR-03 fixed as documentation:** the `storage.validate` consequence and both consumers are named at the code.
- **One new regression suite (3 cases), all observed failing before the production change landed**, with the pre-fix readings recorded verbatim below.

## Task Commits

1. **Task 1: The D-G6-01 withdrawal, the additive floor seed, the doc re-derivations, and the two regressions watched to fail first** — `0421700f` (fix)
2. **Task 2: The WR-01 authority union with its regression, the WR-02 privatization, the full run, and the sweep verification** — `cabf5ff9` (fix)

## Falsifiability — the RED runs, recorded verbatim

### Task 1 RED (basis + ledger suites, one invocation, unmodified production code)

`** TEST FAILED **` — 6 issues, all in the new suite; every ledger case green in the same run
(`✔ Suite DownloadContinuedSessionLedgerTests passed`).

**Test G — `testABlankedGalleryPausedPartWayDoesNotFreezeTheSurvivorsPushes`** (observed → derived):

| Step | Observed pre-fix | Derived |
|---|---|---|
| The announcement's own push (`:100`) | `completedUnitCount → 7` | `5` |
| The announcement's own push (`:102`) | `"7 / 14 pages · 2 galleries"` | `"5 / 14 pages · 2 galleries"` |
| After the production pause (`:113`) | `completedUnitCount → 7` | `5` |
| After the production pause (`:115`) | `"7 / 10 pages · 1 gallery"` | `"5 / 10 pages · 1 gallery"` |
| Survivor's page-4 push (`:126`) | `"7 / 10 pages · 1 gallery"` | `"6 / 10 pages · 1 gallery"` |
| Survivor's page-5 push (`:132`) | `"7 / 10 pages · 1 gallery"` — **assertion passed pre-fix** | `"7 / 10 pages · 1 gallery"` |

`spy.progressUpdates.count == 1` held at the announcement, so no `5 / 14` pair existed anywhere pre-fix — the
announcement was the only push and it read `7 / 14`. The page-5 assertion passing pre-fix is not a staging
defect: it is the frozen band being *exactly K = 2 pushes wide*, which is what the plan derived (the honest 7
meets the stale floor of 7 there). Its discriminator is the page-4 push above it, which failed.

**Test H — `testAWithdrawalDuringTheClientStartHopSurvivesTheFloorSeed`**:

| Step | Observed pre-fix | Derived |
|---|---|---|
| First push after `gate.release()` (`:225`) | `"4 / 6 pages · 1 gallery"` | `"3 / 6 pages · 1 gallery"` |

The second post-release push (`"4 / 6"` both directions) passed pre-fix by construction, exactly as the plan
states — the honest value meets the stale floor there.

### Task 2 RED (basis suite, after Task 1's fix landed, before the PendingWork edit)

`** TEST FAILED **` — 1 issue; Tests G and H green in the same run.

**Test I — `testTheRunningGalleryStaysInTheSessionBasisWhenThePersistedQueueLagsBehindIt`**:

| Step | Observed pre-fix | Derived |
|---|---|---|
| `startSubtitles.last` after the queue drops the running gallery (`:308`) | `"0 / 4 pages · 1 gallery"` | `"6 / 14 pages · 2 galleries"` |

The running gallery's pages *and* its identity were simply gone from the card, exactly as WR-01 describes.

## The landed hunks

### The withdrawal — blank → write → index update → withdrawal, one synchronous body, no `await` between them

```swift
var pages = manifest.pages
var blankedPageCount = 0
for page in manifest.pages.keys.sorted() {
    guard pages[page]?.isEmpty == false, existingPages[page] == nil else { continue }
    pages[page] = ""
    blankedPageCount += 1
}
guard blankedPageCount > 0 else { return manifest }

var reconciledManifest = manifest
reconciledManifest.pages = pages
try storage.writeManifest(reconciledManifest, folderURL: folderURL)
updateDownloadIndex(folderURL: folderURL, manifest: reconciledManifest)
// D-G6-01, read off the PRE-blanking manifest: the basis was counting this record only if
// it already read incomplete, or if this session had already watched it doing work.
let wasCountedBasis = manifest.completedPageCount < manifest.pageCount
    || observedIncompleteSessionGIDs.contains(manifest.gid)
if continuedSessionID != nil, wasCountedBasis {
    lastPushedCompletedPageCount -= blankedPageCount
}
return reconciledManifest
```

`writeManifest` and `updateDownloadIndex` are same-actor synchronous calls and the enclosing function is
non-`async`, so there is no suspension anywhere between the blanking and the floor write.

### The seed merge

```swift
// Merged rather than assigned, for the reason the two collections below give, reaching the
// scalar through a different writer. A D-G6-01 withdrawal landing inside the client start's
// main-actor hop is a real correction made by THIS session's own scheduled run, and it
// outranks the pre-hop snapshot, which still counted the pages that correction just blanked.
// The withdrawal is the scalar's ONLY writer inside that window — a start-window push
// returns at the nil-client guard before it reaches its floor update — so the value here is
// zero minus any hop-window corrections, and adding it folds them in instead of discarding
// them. The clamp at zero is what keeps a correction for work the snapshot never counted
// from over-withdrawing: it may only under-seed, which is the safe direction, because a
// floor seeded low re-latches at the very next push while a floor seeded high is the defect.
lastPushedCompletedPageCount = max(
    snapshot.sessionProgress.progress.displayCompletedPageCount + lastPushedCompletedPageCount,
    0
)
```

### The WR-01 union, with the dedupe

```swift
func schedulableDownloads() async -> [DownloadedGallery] {
    let queuedGIDs = queueStore.gids
    var scopedGIDs = queuedGIDs
    if let activeGalleryID, !scopedGIDs.contains(activeGalleryID) {
        scopedGIDs.append(activeGalleryID)
    }
    let downloads = queuedGIDs.isEmpty
        ? await indexedDownloads()
        : await indexedDownloads(gids: scopedGIDs)
    return downloads.filter(isSchedulableDownload)
}
```

The branch still keys on `queuedGIDs.isEmpty`, so the empty-queue full `indexedDownloads()` read that
`nextUnqueuedSchedulableDownload` and the resume-without-queue states depend on is preserved verbatim. The
active gid is appended only when not already contained, because a duplicate reaching `indexedDownloads(gids:)`
would double that gallery's pages in the summed denominator.

### The WR-02 compile-visibility argument (landed doc)

> Prepares the working seed silently — private so no caller outside this file can prepare one without
> announcing it.
>
> The announcing wrapper below is the only public preparation, which is what turns a revert of
> `performDownload`'s call site back to the silent variant into a compile error rather than a suite-green
> regression: D-G5-01's whole liveness half rests on that one line, and both functions being public left it
> unguarded (the post-15-25 review's WR-02).

### The WR-03 paragraph (landed doc)

> The same movement reaches `storage.validate`, and that consequence was considered rather than missed.
> `validatePage` (`DownloadStore+Operations.swift`) returns nil for an empty expected hash — nothing claimed,
> nothing to check — so a blanked page that previously produced `.missingFiles` now leaves the record
> reporting `.valid`. Two consumers see it: `validateImageData(gid:)`, the inspector's user-initiated
> integrity check, and `loadManifest(gid:)`, whose missingFiles gate decides whether the offline reader opens
> the gallery or falls back to remote. Both answer differently for an interrupted repair, and that is correct
> rather than lost coverage: the manifest genuinely no longer claims those pages, which is the exact state an
> interrupted `.initial` download has always presented, and mode resolution still reaches `.repair` through
> `isIncomplete` so the missing pages are still fetched. Validation reports what the record claims; it is not
> a second source of truth about what the gallery ought to contain.

## Sweep verification (mandatory — every row confirmed against source)

### Table 1 — every site that reads or writes `lastPushedCompletedPageCount`

| # | Site (file:line as landed) | Plan disposition | Observed disposition |
|---|---|---|---|
| 1 | Push `max()` + re-latch, `+ContinuedSession.swift:582-586` | untouched | **HOLDS** — outside every diff hunk (hunks are at `:226` and the `:524→:537` doc block); the `max(...)` and the re-latch are byte-identical |
| 2 | Push doc `:524-529` → `:535-546` | EDITED (doc only) | **HOLDS** — the invalidated premise sentence is replaced, not supplemented (`grep -c 'accounting basis no longer'` was `1`, now `0`); no executable line in the function changed |
| 3 | Session reset, `+ContinuedSession.swift:197` | untouched | **HOLDS** — `lastPushedCompletedPageCount = 0`, no hunk |
| 4 | The seed, `:226` → `:236-239` | EDITED to the additive merge | **HOLDS** — assignment became `max(snapshot + floor, 0)`; the nil-client guard at `:575` still precedes the floor update at `:586`, so the withdrawal remains the scalar's only hop-window writer |
| 5 | Teardown reset in `markContinuedSessionEnded`, `:318` → `:331` | untouched | **HOLDS** — no hunk |
| 6 | NEW writer: the withdrawal, `+ExecutionSupport.swift:399` | the one addition | **HOLDS** — unclamped subtraction, gated on a live `continuedSessionID` and the counted-basis test, in the same synchronous body as the blanking and `updateDownloadIndex` |
| 7 | `reconcileRetiredSessionPages`, now `:487-524` | untouched | **HOLDS** — the function spans `:487-524` in the landed file and the second diff hunk starts at `:537`; no hunk falls inside it |

Also present (documentation only, no executable change): the declaration at `+Manager.swift:431`, which gained
the doc naming all four writers and the deliberate negative transient.

### Table 2 — every route into the correction

| # | Route | Blanks? | Withdraws? | Observed |
|---|---|---|---|---|
| 1 | `.repair` reusing its surviving folder over an already-incomplete record | yes, K | yes, K | **HOLDS** — `shouldReuseWorkingFolder` returns `true` unconditionally for `.repair` (`+ExecutionSupport.swift:441-442`); this is Test G's staging, and the K = 2 withdrawal is what its `5 / 14` pair proves |
| 2 | `.repair` over a complete-reading record (G-15-5's route, ledger Test E) | yes | **no** | **HOLDS** — `wasCountedBasis` is false for an untrusted complete record; `testARepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull` passes with its literals untouched (`0 / 6` → `5 / 6` → `6 / 6`) |
| 3 | `.initial` reuse of a matching manifest with vanished files | yes | per the counted-basis test | **HOLDS** by construction — the reconciliation is the single convergence point; `DownloadCoordinatorRepairSeedTests`' `.initial` reconcile case passes unchanged |
| 4 | Repair-seed materialization | yes, the uncopied claims | per the same test | **HOLDS** — `materializeRepairSeed` (`DownloadStore+Operations.swift:38-75`) links/copies the manifest whole but skips any page whose source file is absent or fails sanitization, so the copied manifest reaches the same reconciliation |
| 5 | `.redownload` / `.update` / fresh `.initial` | no | no | **HOLDS** — the folder is deleted and `makeInitialManifest` produces an all-empty page map, so the blanking loop's `pages[page]?.isEmpty == false` guard never fires and the function returns at `guard blankedPageCount > 0` |
| 6 | Any preparation with no live session | possibly | no | **HOLDS** — `continuedSessionID != nil` gates the withdrawal; `DownloadCoordinatorRepairSeedTests` and `DownloadInterruptedResumeTests` run bare coordinators and pass unchanged |

### Table 3 — the counted-basis truth table, as implemented

| Pre-blanking record | Gid in `observedIncompleteSessionGIDs` | `wasCountedBasis` | Withdraw | Observed |
|---|---|---|---|---|
| incomplete | no | `completedPageCount < pageCount` → true | K | **HOLDS** — Tests G and H both stage 4-of-6 records and withdraw 2 |
| incomplete | yes | true (either disjunct) | K | **HOLDS** by the same disjunction |
| complete (C = N) | yes (trusted) | false ‖ true → true | K | **HOLDS** — the trust-set disjunct is the only reason this row withdraws |
| complete (C = N) | no (untrusted) | false ‖ false → false | **0** | **HOLDS** — D-G4-01's ceiling row; ledger Tests E and F pass byte-identically |

### Table 4 — review-warning dispositions

| Finding | Plan disposition | Observed |
|---|---|---|
| WR-01 | FIXED (Task 2) | **FIXED** — the union landed with `isSchedulableDownload`, `shouldSchedule`, `hasPendingWork` and `scheduleNextIfNeededCore` all showing a zero-line diff; pinned by Test I, whose pre-fix reading is recorded above |
| WR-02 | FIXED (Task 2, by visibility) | **FIXED** — `public func prepareWorkingSeed(` → `0`, `private func prepareWorkingSeed(` → `1`, zero non-announcing test call sites, production wiring line unchanged |
| WR-03 | FIXED (Task 1, doc) | **FIXED** — the paragraph is quoted above; `validateImageData` and `loadManifest` both appear in the consequence doc |
| IN-01 / IN-02 / IN-03 | out of scope | **OUT OF SCOPE** — none touches SC1–SC4 and none sits on an edited line; they remain recorded in 15-REVIEW.md |

### Second-reconciliation compounding

Confirmed by inspection of the landed body: the withdrawal keeps **no per-correction state**. `blankedPageCount`
is a function-local counted during the blanking loop, and `wasCountedBasis` is derived from the input manifest
plus the trust set at that instant. Two corrections in one session therefore compose by plain arithmetic in
either order — each subtracts its own counted portion, and the push re-latches the floor between them. No
ordering coupling was introduced, so the plan's decision to cover this case by arithmetic rather than by a
third staging holds.

### Suspension audit

The plan adds no suspension. `prepareWorkingSeed` keeps its non-`async` `throws -> WorkingSeed` signature (only
its access level changed); the withdrawal and the counted-basis test are same-actor synchronous reads and
writes; the seed change is an assignment's right-hand side; the WR-01 union changes which gids one existing
awaited read fetches, not the await structure. The only suspending call in the delivery remains the
pre-existing `updateProgress` main-actor hop inside `pushContinuedSessionProgress`, reached exactly as before,
with the withdrawal already committed before that hop can be reached.

## Blast radius — the full `FeatureTests` plan, one invocation

`** TEST SUCCEEDED ** [112.028 sec]` — 0 failing tests, 149 suites green, 0 SwiftLint violations reported by
the build-tool plugin (which lints `AppPackage/Tests/DownloadsFeatureTests` as well as Sources).

| Suite | Outcome |
|---|---|
| `DownloadContinuedSessionBasisTests` (new) | ✔ 3/3 |
| `DownloadContinuedSessionLedgerTests` | ✔ all cases, including E, F and the four 15-24 regressions; every pinned literal intact |
| `DownloadContinuedSessionTests` | passed (3 pre-existing `withKnownIssue` records in `testUnimplementedClientReportsAnIssueForEveryEndpoint`, untouched by this plan) |
| `DownloadContinuedSessionIdentityTests` | ✔ |
| `DownloadContinuedSessionInterleaveTests` | ✔ |
| `DownloadCoordinatorRepairSeedTests` | ✔ — assertions unchanged through the call-spelling switch |
| `DownloadInterruptedResumeTests` | ✔ — same |
| `DownloadDeleteConvergenceTests` | ✔ |
| `DownloadSchedulingTests` | ✔ (a failure here would be a real regression, never flake) |
| `DownloadPendingWorkTests` | ✔ |
| `DownloadOwnershipConvergenceTests` | ✔ |
| `BackgroundExecutionInvariantTests` | ✔ |
| `DownloadLogPrivacyInvariantTests` | ✔ |

No existing case failed and no existing literal had to change.

## Gates

| Gate | Result |
|---|---|
| Full `FeatureTests`, single invocation, no other xcodebuild active | `** TEST SUCCEEDED **`, exit 0 |
| SwiftLint | 0 violations (build plugin over Sources + Tests; plus a standalone `swiftlint lint --strict` over `AppPackage/Sources/DownloadClient/` and `AppPackage/Tests/DownloadsFeatureTests/`, exit 0) |
| Suppression directives in the change | none — zero `swiftlint:disable`, `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency` |
| `BGTaskScheduler` / `BGContinuedProcessingTask` in the plan's commits | `0` — COVERAGE.md validated, not extended |
| Catalog entries touched | none — every asserted subtitle renders through the existing plural substitutions |
| Trust-set exceptions | zero — `grep -c observedIncompleteSessionGIDs` in `+ContinuedSession.swift` is **7 before and 7 after**; `reconcileRetiredSessionPages` has no diff hunk |

### Line counts (1000-line error gate)

| File | Lines |
|---|---|
| `DownloadClient+ExecutionSupport.swift` | 596 |
| `DownloadClient+ContinuedSession.swift` | 602 |
| `DownloadClient+Manager.swift` | 601 |
| `DownloadClient+PendingWork.swift` | 49 |
| `DownloadContinuedSessionBasisTests.swift` | 345 |
| `DownloadContinuedSessionLedgerTests.swift` | 812 (was 902 — the helper lift restored the headroom) |
| `DownloadFeatureTestHelpers.swift` | 716 |
| `DownloadCoordinatorRepairSeedTests.swift` | 411 |
| `DownloadInterruptedResumeTests.swift` | 236 |

### Acceptance greps

| Grep | Before | After |
|---|---|---|
| `lastPushedCompletedPageCount` in `+ExecutionSupport.swift` | 0 | 2 |
| `displayCompletedPageCount + lastPushedCompletedPageCount` in `+ContinuedSession.swift` | 0 | 1 |
| `D-G6-01` in `+ExecutionSupport.swift` / `+ContinuedSession.swift` / `+Manager.swift` | 0 / 0 / 0 | 2 / 2 / 1 |
| `validateImageData` in `+ExecutionSupport.swift` | 0 | 1 |
| `activeGalleryID` in `+PendingWork.swift` | 0 | 3 |
| `observedIncompleteSessionGIDs` in `+ContinuedSession.swift` | 7 | 7 |
| `struct PushedPair` / `func makeRepairPayload` in helpers | 0 / 0 | 1 / 1 |
| `struct PushedPair` / `func makeRepairPayload` in the ledger suite | 1 / 1 | 0 / 0 |
| ledger `5 / 6 pages · 1 gallery` / `6 / 6 pages · 0 galleries` | 1 / 4 | 1 / 4 |
| `patchManifest` / `completeManifest` in the new suite (non-comment) | — | 0 / 0 |

The helper lift is a move, not a rewrite: the ledger diff is **two deletion-only hunks totalling 90 deletions
and 0 insertions**, and the helpers diff is **90 insertions and 0 deletions**. No `@Test` body was touched.

## Decisions Made

- **D-G6-01** (new): a coordinator-made basis correction withdraws its counted portion from the monotonic floor
  in the same synchronous stretch that lowers the basis. The floor masks only movements the coordinator did not
  deliberately make.
- The withdrawal sits **inside the reconciliation**, not in the announcing wrapper: whoever blanks, withdraws,
  so the pairing is structural for any future route and the basis/floor correction is atomic on the actor.
- The subtraction is **unclamped** and the seed is an **additive merge** — one fact in one variable. The
  rejected alternative (a clamped withdrawal plus a separate hop-window accumulator) would carry the same fact
  twice.
- Rejected as recorded in the plan and re-confirmed here: weakening or deleting the floor (loses the residual
  defence the doc names) and a per-gallery floor map (re-derives what `retiredSessionPages` plus the live sum
  already provide).
- **WR-01's union widens the read, never the predicate.** `scheduleNextIfNeededCore`'s own independent read is
  deliberately NOT edited: its `activeTask` guard makes the running gallery irrelevant to next-task selection.

## Deviations from Plan

### Findings (rows/claims that did not hold exactly as written — reported, not silently adapted)

**1. [Finding — plan claim] Test G's `resumeMode` grounding resolves `.repair` through the missingFiles branch, not the incomplete-inactive branch.**
- **Found during:** Task 1, Step 2 (staging Test G)
- **Detail:** The plan's behavior block calls the grounding "the incomplete-inactive branch — the production
  route into a counted repair". `makeQueuedCoordinator` enqueues the fixture galleries, so
  `displayStatus(for:)` returns `.queued` (queue-store membership outranks the inactive fallback) and
  `resumeMode`'s `displayStatus == .inactive` branch is not taken; the record instead falls through to the
  `storage.validate` → `.missingFiles` branch, which also returns `.repair`.
- **Impact:** none on the assertion or the arithmetic — `resumeMode(for: staged) == .repair` holds as derived,
  the record is counted raw by `isIncomplete` regardless of `displayStatus`, and both branches are production
  routes into a counted repair. The derived pair `5 / 14` was observed exactly.
- **Action:** reported here; no literal was changed to fit an observation.

**2. [Finding — acceptance grep] `grep -c 'accounting basis no longer shrinking'` cannot discriminate; it is `0` before AND after.**
- **Detail:** the phrase wraps across two source lines (`…accounting basis no longer` / `shrinking, the one
  movement…`), so a single-line grep never matched it, including at planning time.
- **Substitute evidence:** `grep -c 'accounting basis no longer'` in `+ContinuedSession.swift` was **1 before
  and 0 after** — the invalidated premise sentence really is replaced rather than supplemented, which is what
  the criterion was for.

**3. [Finding — acceptance grep] `grep -c 'loadManifest' AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` is `5` at planning time, not `0`.**
- **Detail:** the token is a substring of `DownloadManifest` and `makeInitialManifest`, which the file already
  used five times. The count is now `6`.
- **Impact:** the criterion's operative bar ("at least 1") holds, and the WR-03 paragraph genuinely names
  `loadManifest(gid:)`; only the "0 at planning time" premise was wrong.

**4. [Rule 3 - Blocking] Two doc lines in `DownloadCoordinatorRepairSeedTests.swift` re-wrapped after the WR-02 rename.**
- **Found during:** Task 2, Step 3
- **Issue:** `prepareWorkingSeedAnnouncingProgress` is 26 characters longer than `prepareWorkingSeed`, which
  pushed one doc line to 119 characters (against a 120-column error gate) and left both paragraphs raggedly
  wrapped.
- **Fix:** re-wrapped the two affected paragraphs. Zero assertion, staging or call-expression lines beyond the
  five spelling changes; the full call-site diff is reproduced in the plan's own acceptance evidence.
- **Committed in:** `cabf5ff9`

**5. [Finding — pre-existing working-tree state] `.planning/STATE.md` arrived already modified, with its progress fields regressed.**
- **Detail:** at executor start the working tree carried an uncommitted STATE.md edit that rolled
  `completed_phases` 14 → 13, `percent` 88 → 81, `last_updated` forward-to-backward, and replaced the Current
  Position block with "Plan: 1 of 26 / Phase 15 execution started". This was not produced by this plan.
- **Action:** not included in either task commit; corrected by hand during the state update below.

### Environment note (not a deviation)

Every `xcodebuild test` invocation spent ~600 s after the tests finished in
`IDETestOperationsObserverDebug: Failure collecting diagnostics from simulator: Timed out after 600.0 seconds`.
The test runs themselves completed in well under a second each. No result was affected; it only stretched wall
time. Every invocation was run alone, never overlapping another, per this machine's hard constraint.

---

**Total deviations:** 1 auto-fixed (Rule 3 — blocking line-length/wrapping), 4 findings reported.
**Impact on plan:** no scope creep; no derived value was replaced by an observed one.

## Issues Encountered

None beyond the findings above. The first RED run's console output was truncated by a `tail -80` pipe, so the
two earliest failure messages were recovered from the `.xcresult` bundle via
`xcrun xcresulttool get test-results tests` rather than by re-running (the one-run rule, and the overlap
prohibition, both argue against a second invocation).

## Standing device item — NOT closed by this plan

**15-UAT.md test 2 remains an open physical iOS 26 device re-run, recorded in 15-VERIFICATION.md, and nothing
in this plan discharges it.** SC2 is defeated on two independent axes: in code by G-15-6 (which this plan
closes) and behaviourally-unverified on hardware (which this plan does not touch). The system card and the
scheduler's stall-expiration response do not exist in the simulator. The device run should now be scheduled,
since it will no longer observe a known-defective floor, and it should include a `.repair` gallery inside a
multi-gallery queue plus a mid-queue pause of a reconciled gallery — the correction route this plan just
changed.

## Next Phase Readiness

- G-15-6 is closed at the invariant rather than at the branch: the withdrawal rides the reconciliation, so
  every present and future route through `prepareWorkingSeed` inherits it.
- All three open review warnings from the post-15-25 review are dispositioned (WR-01/02/03 fixed; IN-01..03
  recorded out of scope).
- Remaining for the phase: the physical-device UAT re-run above. No code blocker is known.

## Self-Check: PASSED

- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift` — FOUND
- `.planning/phases/15-continued-background-downloads/15-26-SUMMARY.md` — FOUND
- commit `0421700f` — FOUND
- commit `cabf5ff9` — FOUND

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-05*
