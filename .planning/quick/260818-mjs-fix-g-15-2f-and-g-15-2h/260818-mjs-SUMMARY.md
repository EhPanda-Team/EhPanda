---
phase: quick-260818-mjs
plan: 01
subsystem: downloads
tags: [download-client, tca, swift-testing, ssot, file-system]

requires:
  - phase: 15-continued-background-downloads
    provides: "RunProgressBasis (the run-owned measurement), the manifest-SSOT display basis (D-SSOT-07/08/09), and the round-6 device UAT that filed both gaps"
provides:
  - "G-15-2H: the gallery folder's readable leaf is frozen at first creation — a repair never renames a user-visible folder"
  - "G-15-2F: a live run's credited page set rides on the published row (D-SSOT-10), so the badge and the Download Status sheet describe the work the run is doing"
  - "One accessor (liveRunProgressBasis) through which both the session numerator and the published row read the measurement"
affects: [downloads-display, download-folder-layout, detail-repair-affordance]

tech-stack:
  added: []
  patterns:
    - "D-SSOT-10: a run-scoped, operation-level display overlay that writes nothing, consults no disk and is retired with the run"
    - "Frozen path leaf: a user-visible on-disk name is chosen once and re-read from the index record, never recomputed from network data"

key-files:
  created:
    - AppPackage/Sources/AppModels/Download/DownloadRunProgress.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+RunProgress.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFolderLeafFreezeTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadRunProgressOverlayTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorRunProgressReloadTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/AppModels/Download/DownloadedGallery.swift
    - AppPackage/Sources/AppModels/Download/DownloadedGallery+SupportTypes.swift
    - AppPackage/Sources/AppModels/Download/DownloadedGallery+Manifest.swift
    - AppPackage/Sources/DetailFeature/DetailReducer.swift

key-decisions:
  - "PD-1 honored: the frozen leaf is resolved from the INDEX record, not from a disk walk — the index is the documented read authority between sync points and both callers already run against a loaded one."
  - "PD-2 honored: the run measurement gets ONE accessor in a new file; the whole-name census stays at seven (+ContinuedSession 3 -> 2, +RunProgress 1)."
  - "PD-4 honored: the row is published at the announce, at every flush and at every exit — including an exit that no longer owns the active slot, which finishActiveTaskIfOwned does not publish from."
  - "PD-5 honored: repairSeed / materializeRepairSeed / RepairSeedContext were NOT deleted; the three re-slot suites were restaged through a PARENT change and the unreachability is recorded as an owner question."
  - "PD-7 fallback taken: a coexisting path was found, so DetailReducer.downloadNeedsRepair now reads the record's own isIncomplete instead of the badge's (now display-basis) numerator."

patterns-established:
  - "A display overlay must be retired by the same code path that retires the state it derives from, and every exit of that path must publish — including the exits that do not own the resource."
  - "When a display basis is narrowed to a run, any PREDICATE that shares the widget must be re-pointed at the record explicitly rather than left to a coexistence argument."

requirements-completed: [G-15-2F, G-15-2H]

coverage:
  - id: D1
    description: "The gallery folder's readable leaf is chosen once at creation and reused on every later run; the parent still follows the caller."
    requirement: G-15-2H
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadFolderLeafFreezeTests.swift#testTwoRunsWithDifferingTitlesKeepOneFolderUnderTheFirstLeaf"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadFolderLeafFreezeTests.swift#testARepairOverAnExistingFolderReusesItInPlace"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadFolderLeafFreezeTests.swift#testTheLeafIsFrozenButTheParentIsNot"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadFolderLeafFreezeTests.swift#testAGalleryWithNoRecordStillDerivesAFreshLeaf"
        status: pass
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadProcessTests.swift#testProcessDownloadClearsStalePageSelectionWhenLatestPayloadRevealsUpdate"
        status: pass
    human_judgment: true
    rationale: "The reported defect was observed on a physical device through Files.app and a devicectl listing; the UAT entry requires a device re-run showing the folder name unchanged and no Code=4 line in the jsonl."
  - id: D2
    description: "While a run's measurement stands, the badge numerator and the inspector's page states read that run's credited page set; out of a run both read the record."
    requirement: G-15-2F
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRunProgressOverlayTests.swift#testAWholesaleRefusalRepairReadsTheRunNotTheRecord"
        status: pass
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRunProgressOverlayTests.swift#testAnHonestRecordReadsTheSameUnderTheOverlayAndTheRecord"
        status: pass
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRunProgressOverlayTests.swift#testAFailedOutstandingPageReadsFailedUnderTheOverlay"
        status: pass
    human_judgment: true
    rationale: "The defect is what a user reads on the Download Status sheet during a real repair; the UAT entry requires a device re-run showing the sheet climbing with the system card."
  - id: D3
    description: "The row is re-published at the announce, at every flush and at every run exit, including an exit that no longer owns the active slot."
    requirement: G-15-2F
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRunProgressOverlayTests.swift#testANonOwningRunExitStillPublishesTheRecordRead"
        status: pass
    human_judgment: false
  - id: D4
    description: "A published row differing only in runProgress re-sends .loadInspection; an identical row still reloads nothing."
    requirement: G-15-2F
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorRunProgressReloadTests.swift#testARowThatDiffersOnlyInRunProgressReloadsTheInspection"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorRunProgressReloadTests.swift#testAnIdenticalRowStillReloadsNothing"
        status: pass
    human_judgment: false
  - id: D5
    description: "The run measurement's whole-name census stays at seven sites, with the single accessor taking the moved slot."
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift#testRunScopedPageWorkProofSitesMatchTheRecordedCensus"
        status: pass
    human_judgment: false

duration: 105min
completed: 2026-08-18
status: complete
---

# Quick task 260818-mjs: G-15-2F / G-15-2H Summary

**A repair now restores a gallery in place under its original folder name, and the sheet a user opens during that repair describes the work the run is doing instead of the record's stale claim.**

## Performance

- **Duration:** ~105 min
- **Tasks:** 3 of 3
- **Files created:** 5 · **Files modified:** 13
- **Tests:** 993 baseline → **1003**, 0 failures (22 targets)

## Accomplishments

- **G-15-2H — the folder never gets renamed again.** `folderRelativePath(for:parentFolderName:)` reuses the indexed record's `folderURL.lastPathComponent` whenever the gallery already has a record and derives a fresh `trimmedTitle` leaf only when it has none. Both callers (`processDownload` for every mode, and `enqueue`) are covered by construction because the freeze is inside the one function. The parent stays the caller's, so an in-app move still relocates.
- **G-15-2F — one value behind the header and the page groups.** `DownloadedGallery.runProgress` carries the live run's credited page SET. The badge numerator is that set's size and `buildInspectionPages` reads its membership, so they cannot disagree; out of a run both read the record exactly as before. Record-completeness quantities and every gate (`completedPageCount`, `isIncomplete`, `canValidateImageData`, `retryablePageIndices`, `displayStatus`, resume-mode resolution, scheduling) are unmoved, and the overlay writes nothing, touches no disk and is retired with the run.
- **The reload gate closes too.** A refusal repair re-records byte-identical hashes, so the published row used to be `==` its predecessor and `observeDownloadsDone` never reloaded. The row now genuinely differs at every landing — the gate was not weakened.
- **Census discipline held.** Both the session numerator and the published row read the measurement through `liveRunProgressBasis(gid:)`, and the whole-name census still totals seven.

## Task Commits

1. **Task 1: Freeze the gallery folder leaf across runs (G-15-2H)** — `13cad7d9` (fix)
2. **Task 2: Publish the live run's measurement on the row (G-15-2F)** — `764c5958` (fix)
3. **Task 3: Record both fixes in 15-UAT.md** — deliberately **uncommitted** (see below)

## Files Created/Modified

Created:
- `AppPackage/Sources/AppModels/Download/DownloadRunProgress.swift` — the row-published form of one run's measurement, with the D-SSOT-10 warrant on the declaration.
- `AppPackage/Sources/DownloadClient/DownloadClient+RunProgress.swift` — `liveRunProgressBasis(gid:)` (the ONE read) and `publishedRunProgress(gid:)`.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFolderLeafFreezeTests.swift` — 4 cases.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadRunProgressOverlayTests.swift` — 4 cases.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadInspectorRunProgressReloadTests.swift` — 2 cases.

Modified (sources): `DownloadClient+ExecutionSupport.swift` (the freeze + the announce publish), `DownloadClient+Execution.swift` (exit publish, `retireRunProgressBasis`/`finishActiveTaskIfOwned` now report, `removeSupersededFolders` doc), `DownloadClient+PublicAPIHelpers.swift` (the two page-state regimes), `DownloadClient+Persistence.swift` (the row learns about the run), `DownloadClient+Manager.swift` (`creditedPageIndices` as the one definition), `DownloadClient+ContinuedSession.swift` (regime 1 through the accessor), `DownloadedGallery.swift` / `+SupportTypes.swift` / `+Manifest.swift`, `DetailFeature/DetailReducer.swift`.

Modified (tests): `DownloadSourceInventoryTests.swift` (census), `DownloadManifestSSOTInvariantTests.swift` (header scope note), `DownloadFeatureTestFactories.swift` + `DownloadContinuedSessionRunProofTests.swift` (the stubbed-session helper hoisted, private copy deleted), `DownloadCoordinatorRepairSeedTests.swift`, `DownloadRepairSeedSignalPropagationTests.swift`, `DownloadProcessTests.swift`, `DetailDownloadRepairPredicateTests.swift`.

## Census table move (PD-2)

`expectedRunProofSites` now reads `+ContinuedSession.swift: 2`, `+Execution.swift: 1`, `+ExecutionSupport.swift: 1`, `+Manager.swift: 1`, `+Persistence.swift: 1`, `+RunProgress.swift: 1` — **total unchanged at 7**. `sessionCreditedPages`'s regime-1 line became `liveRunProgressBasis(gid: gid)` (one line for one line, so `+ContinuedSession.swift` stayed at 997 lines), and the freed slot went to the new single accessor. The census doc and the failure message were rewritten to name the accessor's role, and the file stayed under the 1000-line error gate (996).

## Verification

| Gate | Result |
|---|---|
| Full package suite after Task 1 | 997 tests, 0 failures, `** TEST SUCCEEDED **` |
| Full package suite after Task 2 | **1003 tests, 0 failures**, `** TEST SUCCEEDED **` |
| `xcodebuild build -scheme AppFeature` (SwiftLint plugin runs) | BUILD SUCCEEDED, 0 warnings, both times |
| Standalone SwiftLint `--strict` over every touched/new test file | 0 violations |
| File-length gate (1000, error) | `+ContinuedSession.swift` 997 · `+Manager.swift` 970 · `DownloadSourceInventoryTests.swift` 996 · `DownloadFeatureTestHelpers.swift` 992 (untouched) |

**Banked falsifiability.** Task 1's suite was run BEFORE the fix: 3 of its 4 cases failed with 5 verbatim issues, and `testAGalleryWithNoRecordStillDerivesAFreshLeaf` passed pre-fix as intended (it pins the branch the fix leaves alone). Task 2's overlay pins cannot be run pre-fix (they name a field that did not exist), so the one pin whose production change is a single conditional was checked by inversion instead: with the non-owning-exit publication removed, exactly one case fails — `testANonOwningRunExitStillPublishesTheRecordRead`, timing out on the awaited publication — and nothing else moves. The probe was reverted and the file verified identical before committing.

## Decisions Made

All eight planner decisions were implemented as written, except PD-7 where the plan's own conditional fired (below). Two things the plan asked to be recorded rather than acted on:

- **PD-5 owner question — the repair-seed materialization.** `repairSeed`, `materializeRepairSeed` and `RepairSeedContext` were **not** deleted: WR-02 / G-15-13 / G-15-19 pins still own that branch's contract and the locked fix spec did not ask for removal. The question was raised for the owner: retire the seed materialization in a design round? Recorded in `15-UAT.md` under G-15-2H as well.

  **CORRECTED 2026-08-18.** This bullet originally asserted that the machinery *is now unreachable from `processDownload`*, on the argument that the destination equals the record's folder so `shouldReuseWorkingFolder`'s existence guard and `repairSeed`'s existence guard cannot both fail. A design-round investigation found that claim is **TRUE-WITH-EXCEPTIONS, not an invariant**: it assumes, without stating it, that `downloadIndex[gid]` at the moment `folderRelativePath` is evaluated still names the folder the run captured at its start. It does hold unconditionally for `.initial` / `.redownload` / `.update` (blocked by `repairSeed`'s `payload.mode == .repair` guard) and for the `enqueue` route (no `prepareWorkingSeed`), and for a steady-state `.repair`. But `download` is captured at `DownloadClient+Execution.swift:36` while the derivation runs at `:170`, after real suspensions, and `syncDownloadsState` has no active-run gate — so a `reloadDownloadIndex` failure that empties the index mid-run (E1), or a mid-run dedup-winner flip across parents from externally-created duplicate folders (E2), re-addresses the destination away from a still-standing source and the seed fires. The pins therefore guard a live residual contract, not dead code. The recommendation is to KEEP the machinery and change only its documented role — from "the expected title-re-slot path" to "the salvage net for a run whose destination was re-addressed away from a still-standing source". Full reasoning and the deletion inventory (should the owner override) are in `15-UAT.md` under G-15-2H.
- **PD-7 verification result — a coexisting path DOES exist, so the fallback was taken.** The plan's argument was that `clearDownloadFailureState` at enqueue keeps a live overlay and `.error` apart. Reading `displayStatus(for:)` and the clear sites, that holds for the enqueue direction and for an OWNING run (whose status reads `.active` from `activeGalleryID` until the same synchronous `defer` clears it), but not universally: a run whose slot was taken mid-flight can be `.completed`-reading for the refusal family, which opens `canValidateImageData`, so a `validationErrors` entry can be installed while that run's measurement still stands — and the failure path's own `await queueStore.remove(gid)` is a suspension point between `downloadErrors[gid]` being set and the `defer` retiring the basis. The window is narrow and self-correcting, but it makes the predicate non-deterministic. Per PD-7's instruction, `downloadNeedsRepair` now reads the record: `DetailReducer.State.downloadIsIncomplete` is written by `applyDownload` from `DownloadedGallery.isIncomplete`, alongside the `downloadFailureCode` conjunct it is always read with, so the two always describe one observation. The five-row truth table in `DetailDownloadRepairPredicateTests` is unchanged in meaning and green.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] A pre-existing pin encoded the rename as expected behaviour**
- **Found during:** Task 1 (after the freeze landed)
- **Issue:** `DownloadProcessTests.verifyCompletedProcess` asserted `fileExists(staleFolderURL) == false` after a full `processDownload`. That folder is named `<gid> - Pause Race` (an older naming scheme), so pre-fix the run built its result at a recomputed `[gid_token] Title` path and the completion sweep deleted the folder the user could see — precisely the defect G-15-2H removes. The assertion was therefore RED against the correct behaviour.
- **Fix:** Restaged to the post-fix truth, which is a strictly stronger statement: the run finishes IN the folder the record already pointed at, that folder still exists, and exactly one folder exists for the gid. The comment records what the assertion used to say and why it changed.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadProcessTests.swift`
- **Verification:** Full suite green (997) on the re-run; the case is now the whole-arc version of `DownloadFolderLeafFreezeTests`' unit pins.
- **Committed in:** `13cad7d9`

**2. [Rule 2 — Correctness] `DetailReducer.downloadNeedsRepair` re-pointed at the record**
- **Found during:** Task 2 (PD-7's mandated verification)
- **Issue:** The predicate's incompleteness conjunct read `badge.progress`, which Task 2 turned into a display quantity. See the PD-7 paragraph above for the coexisting path.
- **Fix:** New record-derived `State.downloadIsIncomplete`, written in `applyDownload`; the predicate reads it. `DetailFeature` was not in the plan's declared file list — PD-7 explicitly authorizes this site and asks for it to be reported.
- **Files modified:** `AppPackage/Sources/DetailFeature/DetailReducer.swift`, `AppPackage/Tests/DetailFeatureTests/DetailDownloadRepairPredicateTests.swift`
- **Verification:** Full suite green (1003); the predicate's five-row truth table unchanged and passing.
- **Committed in:** `764c5958`

**3. [Rule 3 — Stale doc] `stageAllRefusedSourceFolder`'s doc**
- **Found during:** Task 1 (restaging PD-5's suites)
- **Issue:** Its doc said the fixture is staged "under a title that differs from `makeReconcilePayload`'s so the working folder the repair resolves is a different path" — false once the leaf is frozen.
- **Fix:** Corrected in place: the title difference no longer moves the folder, and the caller stages the differing destination by naming a different parent.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift`
- **Verification:** Full suite green; standalone lint clean.
- **Committed in:** `13cad7d9`

---

**Total deviations:** 3 (1 × Rule 1, 1 × Rule 2 under PD-7's own conditional, 1 × Rule 3).
**Impact on plan:** No scope creep. Two are corrections to artefacts that encoded the pre-fix behaviour, and the third is the fallback the plan itself specified.

## Issues Encountered

None that required problem-solving beyond the deviations above. Two mechanical notes: `xcodebuild test` exceeded the 600 s foreground limit twice and was run in the background and waited on to completion (never interrupted, never `pkill`ed); and the sensitivity probe of PD-4(c) was performed on a backed-up copy of `DownloadClient+Execution.swift`, restored and diffed before the commit.

## Docs Left Uncommitted (deliberate)

- **`.planning/phases/15-continued-background-downloads/15-UAT.md` is MODIFIED and NOT committed**, per the plan and the orchestrator's constraints — the orchestrator makes the docs commit. Edited with `Edit` only (never a whole-file `Write`). Both gap entries keep `status: open` on the G-15-2D precedent and gained `fix_landed_2026_08_18` blocks naming the commits, the mechanism, the tests and what the next device round must show; G-15-2F also gained the two-part `root_cause`; G-15-2H's `severity` became `confirmed-defect (fixed in code; awaiting device verification)`. The Summary's `completion_note`/`open_issues_note` and the frontmatter's `updated:`/`awaiting:` were refreshed. The gaps block and the frontmatter both still parse as YAML, and the file contains no absolute home path.
- `STATE.md` and `ROADMAP.md` were deliberately not touched: this is a quick task, separate from the planned-phase counters.

## Next Phase Readiness

Both fixes are code-complete and awaiting a device round on the 260818-mjs build. Nothing is blocked: the phase-15 plan queue (15-77 and verification round 21) is unaffected, and the one open design question — retiring the now-unreachable repair-seed materialization — is a follow-up, not a dependency.

## Self-Check: PASSED

All five created files exist on disk, all thirteen modified files carry the described changes, and both commit hashes resolve:

- `13cad7d9` — `fix(15): freeze the gallery folder leaf`
- `764c5958` — `fix(15): overlay a live run's progress on the row`

---
*Quick task: 260818-mjs*
*Completed: 2026-08-18*
