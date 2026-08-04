---
phase: 15-continued-background-downloads
plan: 25
subsystem: downloads
tags: [background-tasks, continued-processing, download-manifest, swift-testing, tca]

requires:
  - phase: 15-continued-background-downloads
    provides: "D-G4-01's session basis and trust set (plan 15-24), D-G3-01's drain-ness re-check (15-23), D-G2-01/D-G2B-01's retirement ledger and terminal push (15-22)"
provides:
  - "D-G5-01: the working manifest never claims a page whose file is absent from the working folder, reconciled at the one point every start mode's run converges on"
  - "A run-start announcement push that makes the incomplete window's observation production-guaranteed, deterministically including the single-missing-page case"
  - "WR-03 closed: the session-start seed merges instead of overwriting, so an observation recorded inside the client-start main-actor hop survives"
  - "Five regressions: three at the working-seed seam, two end-to-end on the ledger (K=1 drain, held-open-start interleaving)"
affects: [download-progress-reporting, continued-processing-session, repair-route]

tech-stack:
  added: []
  patterns:
    - "Record-honesty-at-the-convergence-point: fix a false input where every route converges rather than on the branch a report named"
    - "Production-guaranteed observation: when trust is admitted only inside a push, the run issues one push at the moment its own basis becomes true"
    - "Merge-not-overwrite seeding behind an identity guard: a superseded start is excluded by the guard, so the seed is free to preserve this session's own observations"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionPerform.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift

key-decisions:
  - "D-G5-01 installed at prepareWorkingSeed: the repair's own file-validation result marks the record incomplete before the session's snapshot reads it — the gap record's second option, chosen over admitting a gid by resolved start mode (which would open update/redownload at the ceiling at schedule time)"
  - "Record honesty alone was proven insufficient, so the run announces its post-preparation basis through a new wrapper before any page work; the announcement is a call site of the existing hardened push, not a new trust-admission channel"
  - "WR-03 folded into scope as the one recorded trust-machinery exception: the session-start seed became formUnion / keep-observed merge, because the announcement design entangles the two"
  - "The plan's holdNextStart()/releaseHeldStart() spy artifact was NOT added: the spy's pre-existing armStartGate() already parks the next accepted start with the identical contract, so adding a second pair would be a thin wrapper CLAUDE.md forbids (finding, recorded below)"

patterns-established:
  - "Falsifiability by recorded temporary revert: a case that compiles only against the fix is proven by reverting the fix, recording the verbatim reading, and restoring before the commit"
  - "Contract-faithful ledger staging: record state comes from the fixture folder, the run's own preparation and the production flush; every push in the case is production-issued"

requirements-completed: []

coverage:
  - id: D1
    description: "A .repair of a complete-reading record whose page file vanished comes out of prepareWorkingSeed with an incomplete record: the vanished page's hash is blanked, surviving hashes are byte-identical, the manifest is persisted and re-indexed, and the surviving page files are untouched"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift#testARepairWithAVanishedPageFileMarksTheRecordIncomplete"
        status: pass
    human_judgment: false
  - id: D2
    description: "The same reconciliation covers the .initial reuse of a complete manifest (D-G4-01's fourth route), so the fix is invariant-scoped rather than a branch patch"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift#testAnInitialReuseOfACompleteManifestReconcilesVanishedPages"
        status: pass
    human_judgment: false
  - id: D3
    description: "An honest complete record is left byte-identical — the reconciliation writes only when it blanked something, so D-G4-01's ceiling guarantee is untouched"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift#testARepairWithAllFilesPresentRewritesNothing"
        status: pass
    human_judgment: false
  - id: D4
    description: "End to end at one missing page: retryPages resolves .repair on a complete-reading record, the card opens at 0 / 6, the production announcing preparation moves it to 5 / 6, and the drain reports 6 / 6 with one successful completion — 0 → 5 → 6, fraction reaching one only at the drain"
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testARepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull"
        status: pass
    human_judgment: false
  - id: D5
    description: "An announcement landing entirely inside the held-open client-start main-actor hop still drains at the full count, because the session-start seed merges instead of overwriting (WR-03)"
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testAnAnnouncementDuringTheClientStartHopSurvivesTheSeed"
        status: pass
    human_judgment: false
  - id: D6
    description: "SC2 on real hardware: a repair's system card climbs instead of pinning at zero, observed on a physical iOS 26 device (15-UAT.md test 2)"
    verification: []
    human_judgment: true
    rationale: "The continued-processing card renders in system UI on a physical device under a real BGContinuedProcessingTask; the simulator seam is a spy and cannot show what the user sees. Nothing in this plan closes this item."

duration: 45min
completed: 2026-08-05
status: complete
---

# Phase 15 Plan 25: G-15-5 Closure Summary

**A repair's working-seed preparation now blanks the hash of every page whose file is gone, announces that basis to the live session before any page work, and keeps the announcement across the client-start hop through a merged seed — so a `.repair` card runs 0 → 5 → 6 and drains full instead of finishing a pinned `0 / 1 page · 0 galleries`.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-08-04T14:35:00Z (approx.)
- **Completed:** 2026-08-04T15:20:00Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments

- **D-G5-01 installed at the convergence point.** `reconcileWorkingManifestAgainstPageFiles(manifest:existingPages:folderURL:)` runs inside `prepareWorkingSeed`, between the `existingPages` read and the `WorkingSeed` construction, blanking the hash of every page whose file is absent and persisting + re-indexing only when something changed. Every start mode's run converges here, so `.repair`, the `.initial` reuse of a complete manifest and the repair-seed materialization are all covered by one reconciliation; `.redownload` / `.update` / `.initial`-fresh arrive with all-empty manifests and are no-ops.
- **The observation is production-guaranteed.** `prepareWorkingSeedAnnouncingProgress(payload:existingDownload:folderURL:)` prepares the seed and then, when a session is live and the seed manifest reads incomplete, issues one `pushContinuedSessionProgress` before any page work. `performDownload` prepares through it. This closes the deterministic K=1 hole: with one missing page the single completion flush restores completeness before its own push, so no pre-existing push could ever see the incomplete window.
- **WR-03 closed as the one recorded trust-machinery exception.** `ensureContinuedSession`'s post-re-check seeding became `observedSchedulablePages.merge(_:uniquingKeysWith:)` (keep-observed) and `observedIncompleteSessionGIDs.formUnion(_:)`, so an announcement landing inside the client-start main-actor hop is preserved instead of being overwritten by the pre-hop snapshot.
- **Five regressions, both pinned-zero readings observed.** Three at the working-seed seam and two end to end on the ledger, with the pre-fix `0 / 1 page · 0 galleries` reproduced twice by recorded temporary reverts — once on the main path (reconciliation removed) and once in the held-open-start interleaving (seed merge reverted).
- **Full `DownloadsFeatureTests` plan green in one invocation:** 323 tests in 62 suites passed, zero failures, zero SwiftLint violations, zero build warnings.

## Task Commits

1. **Task 1: The working-seed reconciliation, the run-start announcement, and the seam drains** — `06763885` (feat)
2. **Task 2: The K=1 ledger regression, the interleaved-start regression, the sweep, and the full run** — `7b0fa678` (test)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` (534 lines) — the reconciliation, the announcing wrapper, and their rationale docs
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionPerform.swift` (186 lines) — one call swapped to the announcing wrapper, nothing else
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` (583 lines) — the merged seed and the re-derived D-G4-01 route doc
- `AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift` (410 lines) — Tests A–C
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift` (902 lines) — Tests E and F
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` (626 lines) — `writePageFiles(for:in:indices:)`

All modified files are under the 1000-line `file_length` gate. `DownloadContinuedSessionTests.swift` is unmodified at 999 lines.

## The change, quoted

**The call site — between the existingPages read and the seed construction:**

```swift
let existingPages = storage.existingPageRelativePaths(
    folderURL: folderURL,
    manifest: manifest
)
let reconciledManifest = try reconcileWorkingManifestAgainstPageFiles(
    manifest: manifest,
    existingPages: existingPages,
    folderURL: folderURL
)
let coverRelativePath = storage.existingCoverRelativePath(
    folderURL: folderURL,
    manifest: reconciledManifest
)
return .init(
```

The reconciliation reuses the `existingPages` dictionary `prepareWorkingSeed` already computed — no second disk scan — and its body contains no suspension point: `storage.writeManifest` and `updateDownloadIndex` are same-actor synchronous calls. `prepareWorkingSeed` keeps its non-suspending signature (`sed -n '/public func prepareWorkingSeed(/,/WorkingSeed {/p' … | grep -c 'async'` outputs `0`).

**The announcing wrapper body:**

```swift
public func prepareWorkingSeedAnnouncingProgress(
    payload: DownloadRequestPayload,
    existingDownload: DownloadedGallery,
    folderURL: URL
) async throws -> WorkingSeed {
    let workingSeed = try prepareWorkingSeed(
        payload: payload,
        existingDownload: existingDownload,
        folderURL: folderURL
    )
    if let continuedSessionID, !workingSeed.manifest.isComplete {
        await pushContinuedSessionProgress(sessionID: continuedSessionID)
    }
    return workingSeed
}
```

The push is conditional on both a live session and an incomplete seed manifest. Its doc names the suspension verbatim:

> The suspension this adds is named: the `updateProgress` main-actor hop to `ContinuedProcessingSession` inside `pushContinuedSessionProgress`. It is issued from the run body, which is already reentrant at its payload fetch, cover download and source resolution and holds no coordinator invariant across the call, and every guard-sensitive re-check lives inside that push. `prepareWorkingSeed` itself therefore stays synchronous.

**The full non-doc hunk in `DownloadClient+ContinuedSession.swift`** (`git diff HEAD~2 -- …ContinuedSession.swift`, doc/comment lines filtered out) is exactly the two seed lines:

```diff
-        observedSchedulablePages = snapshot.finishedPages
-        observedIncompleteSessionGIDs = snapshot.incompleteGalleryIDs
+        observedSchedulablePages.merge(
+            snapshot.finishedPages,
+            uniquingKeysWith: { observed, _ in observed }
+        )
+        observedIncompleteSessionGIDs.formUnion(snapshot.incompleteGalleryIDs)
```

Their rewritten comment, in full:

> Merged rather than assigned, because a push landing inside the client start's main-actor hop is a real observation by THIS session and outranks the pre-hop snapshot. That push's reconcile deliberately runs ahead of the nil-client guard, so it records membership and trust while there is still no card to paint; assigning the pre-hop snapshot over it discarded exactly that. On the canonical `retryPages` route the run is scheduled before this trailing ensure, so the run-start announcement (D-G5-01) can land precisely here — and with the old assignment a single-missing-page repair lost the trust it had just earned and finished a pinned-zero card in that interleaving.
>
> The seeding's position still carries the superseded-start rule, and merging cannot weaken it: "a superseded start seeds nothing" is enforced by the ownership guard above, which a superseded start never passes, and both collections were cleared by this session's own synchronous reset — so anything present at seed time is this session's own identity-gated observation, never a predecessor's.

`lastPushedCompletedPageCount`'s seed stays an assignment, unchanged.

## Acceptance-criteria readings

| Check | Result |
|---|---|
| `grep -c 'reconcileWorkingManifestAgainstPageFiles' …ExecutionSupport.swift` | `2` (declaration + call) |
| `sed -n '/public func prepareWorkingSeed(/,/WorkingSeed {/p' … \| grep -c 'async'` | `0` |
| `grep -c 'prepareWorkingSeedAnnouncingProgress' …ExecutionSupport.swift` | `1` |
| `grep -c 'prepareWorkingSeedAnnouncingProgress' …ExecutionPerform.swift` | `1` |
| `grep -c 'observedIncompleteSessionGIDs' …ContinuedSession.swift` | **before `7`, after `7`** — the seed edit replaced one occurrence's operation, not its presence |
| `grep -c 'formUnion(snapshot.incompleteGalleryIDs)' …ContinuedSession.swift` | `2` (the reconcile's accumulation + the converted seed) |
| `grep -c 'observedSchedulablePages.merge(' …ContinuedSession.swift` | `1` |
| `grep -c` the three seam test names | `3` |
| `grep -c 'D-G5-01' …ExecutionSupport.swift` / `…ContinuedSession.swift` | `1` / `3` |
| `grep -c 'testARepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull'` | `1` |
| `grep -c 'testAnAnnouncementDuringTheClientStartHopSurvivesTheSeed'` | `1` |
| `grep -c '5 / 6 pages · 1 gallery'` (ledger) | `1` |
| `grep -c '6 / 6 pages · 0 galleries'` (ledger) | `4` (two pre-existing drains + E + F) |
| `grep -c 'func writePageFiles'` (helpers) | `1` |
| Case bodies E/F (comments stripped) contain `retryPages`(E) / `resumeMode` / `prepareWorkingSeedAnnouncingProgress` / `flushManifestPageProgress` / `settleCompletedDownload` / `scheduleNextIfNeeded` | present in both |
| Case bodies E/F contain `patchManifest` / `completeManifest` / `pushContinuedSessionProgress` / `testingContinuedSessionID` | `0` / `0` / `0` / `0` in both |
| `DownloadClient+Scheduling.swift`, `+SchedulingHelpers.swift`, `+Manager.swift`, `+PendingWork.swift` in the diff | none — 0 files changed |
| `BGTaskScheduler` / `BGContinuedProcessingTask` occurrences in the commits | `0` (COVERAGE.md validated, not extended) |
| `swiftlint:disable` / `@unchecked Sendable` / `nonisolated(unsafe)` / `@preconcurrency` in the diff | `0` |
| Clean app-scheme build | zero SwiftLint violations, zero warnings |

The `holdNextStart` / `releaseHeldStart` criterion is the single one not met — deliberately, as a recorded finding (see Deviations).

## Falsifiability — every reading recorded verbatim

### Tests A and B, before the production change landed (Task 1 Step 1)

Run: `-only-testing:DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests`, pre-fix tree. Both cases failed with four issues each; the arithmetic issues, verbatim from the xcresult:

**Test A (`.repair`)** — derived 2, observed 3:

```
Expectation failed: (workingSeed.manifest.completedPageCount → 3) == 2
Expectation failed: (workingSeed.manifest.pages[3] → "sha256:page-3") == ""
Expectation failed: (persistedManifest.completedPageCount → 3) == 2
Expectation failed: await manager.fetchDownload(gid: gid)?.completedPageCount == 2
```

**Test B (`.initial` reuse)** — derived 2, observed 3, identical readings:

```
Expectation failed: (workingSeed.manifest.completedPageCount → 3) == 2
Expectation failed: (workingSeed.manifest.pages[3] → "sha256:page-3") == ""
Expectation failed: (persistedManifest.completedPageCount → 3) == 2
Expectation failed: await manager.fetchDownload(gid: gid)?.completedPageCount == 2
```

**Test C** passed pre-fix, by design — it is the deliberate no-op guard, recorded as such rather than kept as a baseline.

### Test E, via recorded temporary revert of the reconciliation call

The revert: the single `reconcileWorkingManifestAgainstPageFiles` call inside `prepareWorkingSeed` was commented out and replaced with `let reconciledManifest = manifest`. Nothing else changed; the announcement condition then never fires, because the seed manifest still reads complete.

Observed, verbatim — derived 5 / 6 mid-run and `6 / 6 pages · 0 galleries` at the drain:

```
Expectation failed: await manager.fetchDownload(gid: repair.gid)?.completedPageCount == 5
Expectation failed: (spy.progressUpdates.map(\.subtitle) → ["0 / 6 pages · 1 gallery"]).contains("5 / 6 pages · 1 gallery")
Expectation failed: (terminalPair.completedUnitCount → 0) == 6
Expectation failed: (terminalPair.totalUnitCount → 1) == 6
Expectation failed: (terminalPair.subtitle → "0 / 1 page · 0 galleries") == "6 / 6 pages · 0 galleries"
Expectation failed: (drain.completedUnitCount → 0) == (drain.totalUnitCount → 1)
```

The persisted count stayed 6, **no `5 / 6` pair exists anywhere in the recorded updates** — the whole recorded list is `["0 / 6 pages · 1 gallery"]` — and the terminal card is `0 / 1 page · 0 galleries` while `finishSuccesses == [true]` still held (that assertion did not fail). That is exactly the pinned-zero card G-15-5 describes, reached deterministically at one missing page.

### Test F, via recorded temporary revert of the two seed merge lines

The revert: `observedSchedulablePages.merge(…)` and `observedIncompleteSessionGIDs.formUnion(…)` in `ensureContinuedSession` returned to their pre-plan assignments. The reconciliation stayed in place.

Observed, verbatim:

```
Expectation failed: (terminalPair.completedUnitCount → 0) == 6
Expectation failed: (terminalPair.totalUnitCount → 1) == 6
Expectation failed: (terminalPair.subtitle → "0 / 1 page · 0 galleries") == "6 / 6 pages · 0 galleries"
```

This revert **isolates WR-03 cleanly: Test E still passed under it**, and only Test F failed. So the two mechanisms are independently necessary — record honesty plus the announcement close the main path, and the merged seed is what carries the observation across the start hop.

Both reverts were restored before either commit; `git diff HEAD -- AppPackage/Sources/` was empty against the Task 1 commit before Task 2 was committed.

## Invariant sweep — Table 1: every route that resolves a redo start mode

Confirmed row by row against source.

| # | Route | Observed disposition |
|---|---|---|
| 1 | `retry(gid:mode:)` → `performRetry` | **HOLDS.** `DownloadClient+RetryHelpers.swift:38` sets `queuedModes[gid] = resolvedMode` via `effectiveRetryMode`. `shouldReuseWorkingFolder` returns `false` for `.redownload, .update` (`DownloadClient+ExecutionSupport.swift:283-284`), so the folder is removed and `makeInitialManifest` supplies a fresh all-empty manifest — existing behavior, unchanged. `.repair` returns `true` unconditionally (`:281-282`) and is covered by the new reconciliation. |
| 2 | `retryPages(gid:pageIndices:)` → `resumeMode` → `.repair` | **HOLDS — this is G-15-5's named route.** `RetryHelpers.swift:52-53` short-circuits `.update`; otherwise `performRetryPages` sets `.repair`. `SchedulingHelpers.swift:50-55` is the `storage.validate` missingFiles branch that resolves `.repair` for a complete-reading record. Test E asserts `resumeMode(for:) == .repair` on the staged record before driving `retryPages`, so the route is grounded rather than assumed. Covered by the new reconciliation. |
| 3 | `resume(gid:)` → `resumeMode` | **HOLDS.** `DownloadClient+Scheduling.swift:315` sets `queuedModes[gid] = resumeMode(for: download)`. `resumeMode` (`SchedulingHelpers.swift:38-57`) branches: `hasUpdate` → `.update` (fresh manifest, existing); `.inactive && isIncomplete` → `.repair` on an already-incomplete record (raw counting, existing); missingFiles on a complete-reading record → `.repair` (**new reconciliation**); else `.redownload` (fresh manifest, existing). |
| 4 | `queuedMode` fallbacks with no `queuedModes` entry | **HOLDS, with one noted refinement.** `SchedulingHelpers.swift:15-35`: `.error` + `fileOperationFailed` → repair; `.updateAvailable` → update; `.completed` → redownload; `.error`/`.queued`/`.active` → `interruptedWorkMode` (initial when `completedPageCount == 0`, else repair). The plan's row omits the fifth branch present in source, `.inactive → resumeMode(for:)` (`:23-24`) — that branch's mechanisms are exactly row 3's and are covered there, so the row's claim is true and merely under-enumerated. Repair rows: new reconciliation (complete-reading) or raw counting (already incomplete). |
| 5 | Bare `enqueue` reusing a complete manifest (`shouldReuseWorkingFolder` `.initial` branch) | **HOLDS.** `ExecutionSupport.swift:272-280` reuses when the probed manifest's gid, token and page count all match, then `ensureWorkingManifest` returns it verbatim. Files present → nothing to blank, no write, no dishonesty. Files vanished → new reconciliation, **pinned by Test B**. |
| 6 | Repair-seed materialization (`setupWorkingFolder` → `materializeRepairSeed`) | **HOLDS.** `ExecutionSupport.swift:309-322` materializes when the working folder is absent; `DownloadStore+Operations.swift:38-75` copies the manifest whole but only the pages whose source files exist and pass `sanitizeAssetFileIfNeeded`. The copied manifest can therefore claim pages that were not copied, and the reconciliation — running after `ensureWorkingManifest` inside `prepareWorkingSeed` — blanks exactly those. `testRepairSeedReusesCompletedFilesWhenPageCountMatches` stages an all-empty source manifest, so it is a no-op there and the case passes unchanged. |

## Invariant sweep — Table 1b: what guarantees the session observes the incompleteness

| # | Run shape | Observed disposition |
|---|---|---|
| 1 | `.repair`, K ≤ one flush batch (deterministic at K=1) | **HOLDS, and the hole was observed.** Under the recorded revert of the reconciliation the whole recorded update list was `["0 / 6 pages · 1 gallery"]` and the drain read `0 / 1 page · 0 galleries` — no push ever saw an incomplete window. With the announcement the `5 / 6 pages · 1 gallery` pair is present and the drain reads `6 / 6 pages · 0 galleries` (Test E). |
| 2 | `.repair`, K spanning multiple flushes | **HOLDS by construction.** The announcement is issued between preparation and the first page download, so it does not depend on the 8-page / 0.4 s flush cadence; later flush pushes remain corroborating. Not separately pinned — K=1 is the strictly harder case and is pinned. |
| 3 | `.update` / `.redownload`, pageCount ≤ one flush batch | **HOLDS.** The fresh all-empty manifest reads 0 of N, which is incomplete, so the wrapper's condition fires. This is the latent 15-24 hole the same announcement closes; the four 15-24 regressions all pass with their literals untouched, so nothing about the queued-window zero moved. |
| 4 | `.update` / `.redownload` on larger galleries; `.initial` fresh | **HOLDS.** The announcement makes the observation unconditional rather than cadence-dependent. `DownloadContinuedSessionTests`' cadence series `[8, 16, 20]`, the `10 / 14 pages · 1 gallery` pair and the `1 / 8 pages · 2 galleries` pair are all intact and green. |
| 5 | `.initial` reuse, complete manifest, all files present (no-op run) | **HOLDS.** The reconciliation blanks nothing (Test C: the persisted manifest is `==` the staged one), `workingSeed.manifest.isComplete` is true, so the announcement condition is false by design and the run departs untrusted retiring zero. |
| 6 | Run fails before preparation | **HOLDS by construction.** No seed, no reconciliation, no announcement; the record is unchanged and the departure retires zero. |
| 7 | Run prepares, then fails before downloading | **HOLDS by construction.** The announcement already ran, so trust is earned and the honest N−K record is what a trusted departure retires — exactly the standing work the session observed. |
| 8 | Announcement landing inside the client-start main-actor hop | **HOLDS, and the pre-merge failure was observed.** Test F holds the spy's start open, drives the production preparation inside it, and asserts `spy.progressUpdates.isEmpty` at that moment (the push records its reconcile and then skips the card at the nil-client guard). Reverting the two seed lines to assignments reproduced `0 / 1 page · 0 galleries` in exactly this interleaving while Test E stayed green. |

**K=1 proof, observed end to end (Test E):** tap → the queued window's opening is `startSubtitles.last == "0 / 6 pages · 1 gallery"` → the production announcing preparation persists `completedPageCount == 5` and the `5 / 6 pages · 1 gallery` pair appears in `spy.progressUpdates` → the production `flushManifestPageProgress` writes page 3 → `settleCompletedDownload` + `scheduleNextIfNeeded` drain to `6 / 6 pages · 0 galleries` with `finishSuccesses == [true]` and `rejectedProgressUpdates.isEmpty`. `expectTheCompletedSeriesNeverRewinds` and `expectTheFractionReachesOneOnlyAtTheDrain` both hold over the whole recorded list.

## Invariant sweep — Table 2: every site of `observedIncompleteSessionGIDs`

Verified by diff inspection. There are exactly seven sites in `DownloadClient+ContinuedSession.swift` plus the declaration in `DownloadClient+Manager.swift`; `grep -rn` finds no other production file referencing the set.

| # | Site | Observed disposition |
|---|---|---|
| 1 | Declaration + doc, `DownloadClient+Manager.swift:451` | **UNTOUCHED** — the file does not appear in the diff. Its rule ("earned from observed incompleteness") is now true on the repair route too. |
| 2 | Synchronous reset in `ensureContinuedSession` (`:200`) | **UNTOUCHED** |
| 3 | Post-ownership-re-check seed (`:245`) | **EDITED — the one recorded exception.** `observedIncompleteSessionGIDs = snapshot.incompleteGalleryIDs` → `.formUnion(snapshot.incompleteGalleryIDs)`, and `observedSchedulablePages = snapshot.finishedPages` → `.merge(_, uniquingKeysWith: { observed, _ in observed })`. Behind the unchanged identity guard. |
| 4 | Reset in `markContinuedSessionEnded` (`:321`) | **UNTOUCHED** |
| 5 | `formUnion(snapshot.incompleteGalleryIDs)` accumulation in `reconcileRetiredSessionPages` (`:510`) | **UNTOUCHED** — this is where the repair now earns trust, because its record reads incomplete. |
| 6 | Basis read in `schedulableSnapshot()` (`:128`) | **UNTOUCHED** |
| 7 | Retirement gate in `reconcileRetiredSessionPages` (`:490`) | **UNTOUCHED** — a trusted repair retires its record's full count at the drain, which is what makes Test E's drain read `6 / 6`. |

(`:462` is a doc-comment reference inside `reconcileRetiredSessionPages`' rationale; also untouched.) `reconcileRetiredSessionPages` took no departure-reason parameter before and takes none now.

## Blast-radius catalog — verified in both directions

Single full `DownloadsFeatureTests` invocation, no other xcodebuild active: **323 tests in 62 suites passed, 0 failures**, plus 3 pre-existing known issues (the deliberate `withKnownIssue` expectations of `testUnimplementedClientReportsAnIssueForEveryEndpoint`, unrelated to this plan).

| Predicted-unchanged item | Observed |
|---|---|
| `DownloadCoordinatorRepairSeedTests.testRepairSeedReusesCompletedFilesWhenPageCountMatches` | passed, unedited — its source manifest carries all-empty hashes, so the reconciliation is a no-op |
| Both `DownloadInterruptedResumeTests` `.redownload` cases, `completedPageCount == 0` literal | suite passed, file unedited, the literal is intact |
| Every pre-existing ledger case incl. all four 15-24 regressions (`testACompleteGalleryQueuedForUpdateOpensTheCardAtZero`, `testCancellingANeverStartedUpdateRetiresNothing`, `testAMidQueueUpdateCancelDoesNotInflateTheSurvivors`, `testARedoObservedRunningEarnsItsRecordBackAtTheDrain`) | all passed with literals untouched — the ledger diff is additive only |
| `DownloadContinuedSessionTests` (`[8, 16, 20]`, `10 / 14 pages · 1 gallery`, `1 / 8 pages · 2 galleries`) | passed, file unedited, all three literals intact |
| `DownloadContinuedSessionIdentityTests` | passed, unedited |
| `DownloadContinuedSessionInterleaveTests` | passed, unedited |
| `DownloadDeleteConvergenceTests` | passed, unedited |
| `DownloadSchedulingTests` | passed by name, unedited |
| `DownloadPendingWorkTests` | passed, unedited |
| `BackgroundExecutionInvariantTests` | passed, unedited |
| `DownloadLogPrivacyInvariantTests` | passed by name, unedited |

No literal changed outside this catalog and no existing case failed.

**Mandate 4 sweep.** Grepping the continued-session suites for a repair-shaped staging asserting zero as its expected end state found **none**: before this plan the only `.repair` occurrence anywhere in those suites is a doc-comment line in `DownloadContinuedSessionTests.swift:822` describing a cancel. G-15-5 was uncovered, not mis-covered, so nothing had to be re-derived.

## Downstream consumers of the now-honest record — verified

- **Run internals.** `pendingPageIndices`, `resolveSourceIfNeeded` and `missingFinalizedPageIndices` are all file-existence-driven, so the run downloads the same pages before and after. `finalizeBatchResult` already threw `IncompleteDownloadError` over any missing file and still does. `addingCurrentFileHashes` fills empty hashes only for files that exist, and finalize reaches it only when nothing is missing, so a blanked entry is always re-hashed before completion — Test E's production flush is exactly that path and the record reads complete again afterwards.
- **Display.** An interrupted repair now honestly reads incomplete → `displayStatus` `.inactive` rather than `.completed`, and `resumeMode`'s incomplete-inactive branch resolves `.repair` for it exactly as the missingFiles branch did. Recorded as a deliberate consequence in the D-G5-01 doc comment.
- **Validation.** `validatePage` skips empty-hash pages, so `storage.validate` on a blanked record reports `.valid` rather than `.missingFiles`; mode resolution still reaches `.repair` through `isIncomplete`, so no route is lost.

## Closure inputs

- **Gap closed:** G-15-5 (blocker), introduced by the 15-24 fix. It violated **SC2** (the card must reflect real download progress) directly, and **SC1** through D-11's consequence: a numerator pinned at zero is the maximally stalled reading, the scheduler force-expires the least-progressing tasks first, and that expiration pauses every schedulable download.
- **Fix shape, all three parts:** (a) the gap record's second option — the repair's own file-validation result marks the record incomplete before the snapshot reads it; (b) the checker-required run-start announcement, which makes the incomplete window's observation production-guaranteed at K=1; (c) the WR-03 fold-in — the merged seed that lets a start-window observation survive.
- **Rejections, recorded:** admitting a gid to the trust set when its resolved start mode is a redo this session scheduled was rejected — at schedule time the folder still holds every file, so a trusted `.update`/`.redownload` would count its manifest's full N and open at the ceiling, breaking the very D-G4-01 guarantee this plan preserves; avoiding that would demand a second, file-count-based basis for trusted complete-reading records. Any *new* trust-set write site was likewise foreclosed: the prohibition was kept deliberately and amended only to record the seed's replace-to-merge exception, because the announcement is an observation opportunity through the existing hardened push, not an admission channel.
- **Deliberate consequence:** an interrupted repair now honestly displays as incomplete (`.inactive`).
- **Accepted residual (T-15-74):** a queued repair shows zero between the tap and the run's preparation — the same pre-first-write window every redo has under D-G4-01, now bounded by the announcement rather than by flush cadence. Test E asserts that window's `0 / 6 pages · 1 gallery` opening deliberately.
- **Standing device item:** 15-UAT.md test 2 remains a physical-device re-run on iOS 26 hardware, now also carrying the observational check that a repair's card climbs instead of pinning at zero. **Nothing in this plan closes it.**

## Decisions Made

1. **D-G5-01 at `prepareWorkingSeed`, not at the branch the report named.** Every start mode's run converges there, so one reconciliation covers `.repair`, the `.initial` reuse and the repair-seed materialization; the remaining modes reach the same truth through their existing fresh manifests. This directly answers the phase's recurring failure mode — three earlier branch-scoped gap rounds each found one site.
2. **The announcement is a call site of the existing push, not a new write channel.** The set's only write sites remain the seed and the reconcile's `formUnion`, so the opening rule and the departure rule still cannot disagree.
3. **The WR-03 merge was folded in rather than deferred as a racy residual.** The source-level safety check passes: the superseded-start rule is enforced by the identity guard preceding the seed, and both collections were cleared by this session's own synchronous reset, so a merge can only preserve this session's own identity-gated observations.
4. **The spy's existing `armStartGate()` was used instead of adding `holdNextStart()`/`releaseHeldStart()`** — see Deviations.

## Deviations from Plan

### 1. [Rule 2 — CLAUDE.md-driven] The plan's `holdNextStart()` / `releaseHeldStart()` spy artifact was not added

- **Found during:** Task 2 Step 2.
- **Issue:** The plan specifies adding a one-shot hold/release pair to `BackgroundProcessingClientSpy` and lists `DownloadFeatureTestSupportTypes.swift` in `files_modified`, with the acceptance grep `grep -c 'holdNextStart\|releaseHeldStart' … >= 2`. Its `read_first` cites `refuseNextStart`'s arming idiom but never mentions `armStartGate()` — which **already exists** on the same spy (`DownloadFeatureTestSupportTypes.swift:187-200`), arms a one-shot gate for the next accepted start, parks the start on a rendezvous, and exposes `entered()` / `release()`. It is already used for a held-open-start regression at `DownloadContinuedSessionIdentityTests.swift:105`. The two placements (park after recording vs. before) produce identical observable behavior for Test F, because the announcement's push returns at the coordinator's nil-client guard and never reaches `updateProgress` in either case.
- **Fix:** Test F uses `spy.armStartGate()` + `gate.entered()` + `gate.release()`. `DownloadFeatureTestSupportTypes.swift` is unmodified.
- **Why:** the user's global CLAUDE.md forbids thin wrapper functions that add no value beyond renaming, and `holdNextStart`/`releaseHeldStart` would be exactly that — a duplicate spelling of an established, sufficient API. CLAUDE.md takes precedence over the plan's artifact list.
- **Reported, not silently adapted:** this is a plan defect (an overlooked pre-existing symbol), recorded here with its evidence rather than absorbed. The plan's *behavioral* requirement — "the client-start main-actor hop can be held open deterministically and the interleaved-start seed-merge regression is expressible" — is fully met, and its pre-merge falsifiability reading was taken and recorded.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift`
- **Verification:** Test F passes with the merge and fails with `0 / 1 page · 0 galleries` without it, under the deterministic gate.
- **Committed in:** `7b0fa678`

### 2. [Finding — no code change] Table 1 row 4 under-enumerates `queuedMode`'s branches

- **Found during:** Task 2 Step 4 (sweep verification).
- **Issue:** The plan's Table 1 row 4 lists four `queuedMode` fallbacks; source (`DownloadClient+SchedulingHelpers.swift:15-35`) has five — the row omits `.inactive → resumeMode(for:)`.
- **Disposition:** the row's *claim* still holds. That fifth branch's mechanisms are precisely Table 1 row 3's (`resumeMode`), and row 3 was confirmed independently, so no route is left uncovered. Recorded per the plan's instruction that a row not holding as written is a finding to report rather than to adapt around. No code change.

---

**Total deviations:** 1 CLAUDE.md-driven adjustment + 1 documentation finding. No behavior was added, removed or weakened relative to the plan's intent; no scope creep.

## Issues Encountered

- The plan's Tests A and B share identical assertions over the same staging with only the payload mode differing, so they are driven through one shared `expectVanishedPageIsReconciled(mode:)` helper. Swift Testing still attributes each failure to its own case name, which is how both pre-fix readings above were captured separately.
- The first full-plan invocation exceeded the tool's 600 s foreground window and was moved to the background. It was allowed to finish untouched (never killed, never overlapped — a second concurrent `xcodebuild test` or a mid-launch kill wedges `testmanagerd` on this machine), then re-run cleanly to a log file for the recorded result.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- G-15-5 is closed with both pinned-zero readings observed and recorded, and WR-03 is closed with it. The remaining post-15-24 review warnings (WR-01, WR-02, WR-04..WR-17) stay out of scope, none being necessary to close G-15-5.
- **The phase's only open gate is human:** 15-UAT.md test 2 on physical iOS 26 hardware, which now also carries the repair-route observation (the card must climb, not pin). Run `/gsd-verify-work 15` next.
- `COVERAGE.md` is validated, not extended: the commits contain zero `BGTaskScheduler` / `BGContinuedProcessingTask` occurrences, no persisted-schema change (the manifest keeps its exact `Codable` shape; only page-hash *values* move between empty and non-empty), no catalog entry touched, no new log statement, and no package installs.

## Known Stubs

None — no placeholder values, empty data sources or TODO markers were introduced.

## Self-Check

*(appended below)*

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-05*
