---
phase: 15-continued-background-downloads
plan: 58
subsystem: downloads
tags: [download-manifest, validation, reconciliation, ssot, content-hash, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-56's D-G5B-01 durable presence arm — the `.missingFiles` reconciliation, its fresh-scan discipline and the `withdrawingCountedBasisMovement` bracket this plan extends inside"
  - phase: 15-continued-background-downloads
    provides: "D-G5-01's blanking loop (`reconcileWorkingManifestAgainstPageFiles`) with its three refusal lines — reused verbatim, never modified"
  - phase: 15-continued-background-downloads
    provides: "15-57's D-G5C-01 widened inspector retry, which is the in-session start affordance for every shape this plan leaves on the refusal surface"
provides:
  - "D-SSOT-01: positive content-level evidence (a readable file whose fresh hash mismatches its record) durably blanks that page, so a corrupt-in-place gallery reaches the same honest, relaunch-stable, immediately-resumable state a missing-file gallery does"
  - "D-SSOT-02: the all-or-nothing wholesale guard evaluated over the COMBINED prospective blank set before any destructive step"
  - "D-SSOT-04: guarded removal of the refuted file, which precludes the laundering shape structurally"
  - "D-SSOT-05: `validationErrors` narrowed to an operation-level signal in code and in doc"
  - "`ContentMismatchScan` — a three-way partition (verified / mismatched / held) that says what each set licenses"
  - "AGENTS.md's manifest-SSOT invariant no longer contradicts the code (D-SSOT-06)"
affects: [15-verification-round-19, downloads-inspector, detail-error-affordance]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Evidence partitions, not flags: a pass returns verified / positively-refuted / held so a caller can ask whether it classified everything, without re-deriving a remainder"
    - "Guard over the COMBINED prospective effect, evaluated before the first irreversible act — never over one family at a time and never after the act it authorizes"
    - "Converting a shape rather than branching for it: removing the refuted file turns corrupt-in-place into the positively-absent shape every downstream mechanism already handles"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DetailFeature/DetailReducer.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift
    - AGENTS.md

key-decisions:
  - "D-SSOT-01: a readable file whose freshly computed hash mismatches its recorded hash is a positive, page-scoped determination of the same strength as a positive absence, so it licenses durable blanking"
  - "D-SSOT-02: the wholesale guard runs over positively-absent ∪ positively-mismatched, BEFORE any removal or blanking, and reuses the loop's own comparison shape so the two guards cannot drift"
  - "D-SSOT-03: a read failure is a per-page hold — hash kept, file kept, entry kept — never blanking authority; the unreadable-is-corrupt equivalence survives only in validate's reporting"
  - "D-SSOT-04: the refuted file is removed under containment, converting corrupt-in-place into the positively-absent shape, so the ONE blanking loop stays the only blanking path and no new branch is added anywhere downstream"
  - "D-SSOT-05: `validationErrors` says the last validation could not produce trustworthy evidence for every claimed page — never anything about the record"
  - "D-SSOT-06: the AGENTS.md invariant's refusal example rewritten, because the content arm makes it false"
  - "No log line was added anywhere in this plan: the plan authorized none, and 15-56 recorded what an unauthorized one costs"

patterns-established:
  - "A partition type documents what each member LICENSES, not merely what it observed — the licensing statement is what stops a later reader from treating a non-answer as evidence"
  - "Where an ordering is load-bearing, the test asserts the ordering's observable consequence (the untouched file under a refusal), not just the end state"

requirements-completed: [SC2]

coverage:
  - id: D1
    description: "A readable-but-mismatched page is durably blanked and its file removed, so the record reads honestly incomplete, derives .inactive, survives relaunch and resolves resumeMode .repair"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift#testValidatingAMismatchedPageBlanksItsHashAndRemovesItsFileOnDisk"
        status: pass
    human_judgment: false
  - id: D2
    description: "Absence and mismatch are one evidence class: a single validate reconciles both families at once, and the mismatched page is reconciled even though the verdict short-circuited on the missing one"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift#testValidatingAMixedMissingAndMismatchedGalleryReconcilesBothFamiliesAtOnce"
        status: pass
    human_judgment: false
  - id: D3
    description: "The combined-wholesale shape refuses entirely and refuses BEFORE any file is removed: the manifest is verbatim, the mismatched file is still on disk, the entry is kept and the post-relaunch .completed residual is pinned"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift#testACombinedWholesaleShapeRefusesBeforeAnyFileIsRemoved"
        status: pass
    human_judgment: false
  - id: D4
    description: "A page whose bytes cannot be read holds — hash and file intact, entry kept, displayStatus .error — while a mismatched sibling in the same gallery still reconciles durably"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift#testAnUnreadablePageHoldsWhileAMismatchedSiblingStillReconciles"
        status: pass
    human_judgment: false
  - id: D5
    description: "The no-laundering invariant: after any durable reconciliation, no page carries a blank hash while its file still exists"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift#expectNoBlankHashedPageKeptItsFile"
        status: pass
    human_judgment: false
  - id: D6
    description: "15-56's presence-arm discipline is unweakened: the durable arm, the wholesale refusal and the togglePause start arc all pass unchanged in the same run"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift#testWholesaleBlankingIsRefusedSoTheSessionErrorStandsAndTheClaimedHashSurvives"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift#testValidatingAPartiallyMissingGalleryBlanksExactlyTheMissingPagesOnDisk"
        status: pass
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift#testAReconciledRecordResumesThroughTogglePauseIntoAQueuedRepair"
        status: pass
    human_judgment: false
  - id: D7
    description: "Device retest of 15-UAT.md test 5, corrupt-in-place half: after Validate on a gallery whose page bytes were altered outside the app, the affected pages read pending, the count converges, Resume is enabled and the repair re-downloads exactly those pages; the altered files are gone from the folder"
    verification: []
    human_judgment: true
    rationale: "The inspector's rendered count and enabled Resume, the Files-app view of the folder, and relaunch across a force-quit on a physical device cannot be observed from the client seam a unit test reaches."

# Metrics
duration: 68min
completed: 2026-08-09
status: complete
---

# Phase 15 Plan 58: Positive Content Evidence Reconciles Too Summary

**A readable file whose bytes no longer hash to what the manifest claims is now the same kind of evidence as a missing file: validation blanks that page durably, removes the refuted file so the blank is genuinely repairable, and clears the transient entry — leaving `validationErrors` as an operation-level signal only, with the irreversibility defence extended over the combined blank set rather than weakened.**

## Performance

- **Duration:** ~68 min of active execution (one transport interruption between the two task gates; every verification was re-run from scratch afterwards rather than trusted)
- **Started:** 2026-08-09T02:52:00Z
- **Completed:** 2026-08-09T04:00:00Z
- **Tasks:** 2
- **Files modified:** 6 (0 created, 6 modified)

## Accomplishments

- **The last per-page state basis collapsed into the manifest.** `validateImageData` is the only path that re-reads page bytes, so it alone holds a determination a presence scan cannot make. That determination is now durable: a corrupt-in-place gallery validates into the identical end state a missing-file gallery reaches — `.inactive`, converged count, `canTogglePause`, `resumeMode == .repair`, all of it re-derived by a fresh coordinator over the same storage root.
- **The laundering hazard is precluded structurally, not guarded against.** Blanking a corrupt page while leaving its file would have been silently self-healing in the worst direction: `resolveSourceIfNeeded` filters a run's pending pages down to those whose file is MISSING, so the repair would skip it, and `finalizeDownload`'s `addingCurrentFileHashes` merge hashes exactly the blank-hash pages from the files on disk, re-recording the stale bytes as truth. Removing the file converts the shape into the positively-absent one, so the fetch filter, the finalize merge, the working-seed preparation and the blanking loop all handle it with **zero new branches**.
- **The blanking loop was not touched.** One declaration, still two callers. The content arm adds no second blanking rule to drift from the first — it removes files, rescans, and lets the existing loop's three refusal lines decide, inside the same `withdrawingCountedBasisMovement` bracket.
- **The irreversibility defence grew rather than shrank.** A systematically wrong hash pipeline would mismatch every readable page; the wholesale guard now sees that shape because it measures the combined set. With an empty mismatch set the guard reduces byte for byte to the presence arm's, which is why 15-56's cases pass untouched.
- **Evidence is gathered fresh, and the suite proves it.** `storage.validate` short-circuits at its first failing page. The mixed case stages a missing page 1 and a corrupted page 3, and the verdict names page 1 only — yet page 3 is reconciled. A verdict-shaped implementation could not produce that result.
- **One contract in three places.** The `validationErrors` property doc, `validateImageData`'s doc and AGENTS.md's invariant now all say the same thing, and Detail's D-G5D-01 rationale no longer argues from a shape that can no longer reach its button.

## Task Commits

Each task was committed atomically:

1. **Task 1: The content arm — regime cases first, then guard → removal → rescan → the one loop** - `7586dc26` (feat)
2. **Task 2: The contract sweep — validationErrors doc, AGENTS.md invariant, stale rationale, full suite** - `7a01604f` (docs)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` - `ContentMismatchScan` (the verified / mismatched / held partition, each member documented by what it LICENSES), `contentMismatchScan(folderURL:manifest:pageFileScan:)` carrying D-SSOT-01 and D-SSOT-03, and `removeMismatchedPageFiles(folderURL:pageRelativePaths:mismatchedPages:)` carrying D-SSOT-04 with the verified laundering chain named at the site.
- `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift` - the extended reconciliation (presence scan → content pass → combined guard → removal → fresh rescan → the one loop), the private `prospectiveBlankPages(manifest:presenceScan:mismatchedPages:)` helper that D-SSOT-02's guard is measured over, and the `validateImageData` contract doc rewritten to D-SSOT-01/D-SSOT-05. **This is where Task 2's PersistenceNormalize sweep landed** — see "The PersistenceNormalize sweep" below.
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` - the `validationErrors` property doc rewritten as an operation-level signal: what an entry says, the five operation-level conditions that keep one, and why clearing is load-bearing.
- `AppPackage/Sources/DetailFeature/DetailReducer.swift` - `downloadNeedsRepair`'s complete-claiming rationale re-derived to the two families that can still reach it, with the departed shape named as "present-but-mismatched bytes, now reconciled durably at validate time (D-SSOT-01)". The predicate itself is byte-for-byte unchanged.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift` - four new regime cases, three new helpers (`pageFileURL`, `corruptPageFile`, `expectNoBlankHashedPageKeptItsFile`) and a rewritten suite doc. 252 → 601 lines.
- `AGENTS.md` - one clause of the manifest-SSOT invariant, and nothing else in the file.

## The Conditional File: NOT Created

`AppPackage/Tests/DownloadsFeatureTests/DownloadValidationContentArmTests.swift` was declared conditional on Task 1's 1000-line `file_length` split triggering. **It did not trigger and the file was not created.** `DownloadValidationReconciliationTests.swift` finished at **601 lines** against the limit of 1000, and `DownloadClient+PersistenceNormalize.swift` at **262**. Creating a near-empty sibling to match the declaration would have split one contract across two files for no reason, so the four content-arm cases live beside the presence-arm cases they are the piecewise complement of — which is also what lets Task 1's `-only-testing:DownloadsFeatureTests/DownloadValidationReconciliationTests` gate close over the whole boundary in one run.

## The PersistenceNormalize Sweep (asked explicitly)

Task 2's `<files>` lists `DownloadClient+PersistenceNormalize.swift` for its stale rationale comments, and that file was **not dirty at Task 2 time**. The reason is scheduling, not omission: Task 1's own Step 3 already ordered "sweep the module for any doc still stating that a present-but-mismatched file cannot be blanked", so the rewrite landed inside Task 1's commit `7586dc26`, where the code it describes also lives. Two paragraphs were replaced there:

- the **D-G5B-01 statement**, which described the branch as taking "one fresh page-file scan" and running the loop — now states D-SSOT-01 (both kinds of positive per-page evidence reconcile, because they are the same kind) alongside it;
- the **"`validationErrors` remains exactly the REFUSAL family's surface"** paragraph, whose enumeration ("where the scan failed, or where blanking would empty every claimed hash at once") was the module's own statement of the stance this plan retires — now D-SSOT-05's operation-level contract.

Verified after the fact: `grep -n "REFUSAL family\|cannot license\|existing file\|present-but-mismatched"` over that file returns nothing, and `D-SSOT-01` / `D-SSOT-05` are recorded at their decision sites. A module-wide sweep for the same stance outside the two declared files (`grep -rn "existing file\|present but\|present-but\|mismatch"` over `AppPackage/Sources/DownloadClient`) found no other occurrence — in particular `DownloadClient+ExecutionSupport.swift`'s loop doc and `DownloadClient+SchedulingHelpers.swift`'s `resumeMode` comment never carried it, so neither undeclared file needed an edit.

## D-SSOT-02: The Ordering, Shown Rather Than Asserted

This is the property whose failure destroys user data, so the proof is written out.

**The code order** in `reconcileValidatedRecordAgainstPageFiles` is a straight line with no early destructive exit:

1. `storage.probeManifest` — nil is a refusal (a race with concurrent deletion is a non-answer).
2. `storage.pageFileScan` — `guard presenceScan.scanSucceeded else { return false }`, 15-56's directory-level refusal line, kept.
3. `storage.contentMismatchScan` over that scan's yield — **reads bytes, writes nothing**.
4. `prospectiveBlankPages(...)` = (claimed − yielded − unprobed) ∪ mismatched, then
   `guard prospectiveBlankPages.count < manifest.completedPageCount else { return false }`.
5. **Only past that guard**: `storage.removeMismatchedPageFiles(...)` — the first line in the whole function that can modify the filesystem.
6. A fresh `storage.pageFileScan`, then `reconcileWorkingManifestAgainstPageFiles` inside the bracket — the only line that can modify the manifest.

Steps 1–4 are provably non-destructive by inspection: `probeManifest`, `pageFileScan` and `contentMismatchScan` open files for reading and hash them, and `prospectiveBlankPages` is pure set algebra. So a refusal at step 4 returns before step 5 exists.

**The test proof**, `testACombinedWholesaleShapeRefusesBeforeAnyFileIsRemoved`: a 2-page gallery with page 1's file deleted and page 2's bytes overwritten. The combined set is `{1, 2}` against `completedPageCount == 2`, so `2 < 2` is false and the whole reconciliation refuses. The case then asserts all three consequences separately, because the end state alone cannot tell a refusal from a partial one:

- `diskManifest.pages == claimedHashes` — the manifest is verbatim, both hashes intact;
- **`FileManager.default.fileExists(atPath: pageTwoURL.path)` is TRUE** — the file the reconciliation would have removed is still there, which is only possible if the guard ran first;
- the entry is kept (`displayStatus == .error`, `lastError?.code == .fileOperationFailed`), and the post-relaunch `.completed` residual is pinned with a comment naming the defence.

That third assertion is the load-bearing one for this criterion. Had the guard been evaluated after the removal, the manifest assertions would still pass while the file was already destroyed — the record and the disk disagreeing in the one direction nothing can undo.

**The reduction proof** that 15-56 is not weakened: with an empty mismatch set, `prospectiveBlankPages` is exactly `claimed − yielded − unprobed`, which is precisely the predicate the loop's own blanking iteration applies, compared against the same `manifest.completedPageCount` in the same `<` shape. The two guards therefore agree by construction rather than by coincidence, and `testWholesaleBlankingIsRefusedSoTheSessionErrorStandsAndTheClaimedHashSurvives` and `testValidatingAPartiallyMissingGalleryBlanksExactlyTheMissingPagesOnDisk` both pass unchanged in the same run.

## D-SSOT-04: No Page Ends Blank Beside a Surviving File

Asserted structurally rather than per case. `expectNoBlankHashedPageKeptItsFile(for:in:)` re-reads the persisted manifest, iterates **every** page whose hash is empty, and requires that page's file to be absent. It is called by the content-durable arm, the mixed arm and the read-failure hold — the three cases that write a manifest — so a future change that blanks without removing fails in three places rather than in whichever one a reviewer happened to think of.

Per-case evidence beside it:

- content-durable arm: page 2's file gone, pages 1 and 3's files present with their hashes intact;
- mixed arm: page 3's file gone (its bytes were refuted), page 1 never had one, pages 2 and 4 untouched;
- read-failure hold: page 2 blanked and removed, page 3's hash **and** file both intact — the hold pinned from both sides in one gallery.

The removal's own failure mode is closed too: `removeMismatchedPageFiles` returns the pages it could not remove, and the caller unions them into the held set, so a page whose file survived keeps its recorded hash and the entry is kept. There is no path on which a removal failure produces a blank hash beside a file.

## Falsifiability Record (banked pre-fix evidence)

Captured against pre-fix production with the four cases already written, before any source change. Three arms failed and the three 15-56 presence-arm cases passed in the same run. Verbatim, per arm:

**`testValidatingAMismatchedPageBlanksItsHashAndRemovesItsFileOnDisk` — FAILED, 10 issues:**
- `(download.displayStatus → .error) == .inactive`
- `(download.lastError → DownloadFailure(code: fileOperationFailed, message: "Page 2 image data is corrupted.")) == nil`
- `(download.completedPageCount → 3) == 2`
- `(diskManifest.pages[2] → "sha256:0f6724ab…") == ""`
- `(diskManifest.completedPageCount → 3) == 2`
- `(fileManager.fileExists(atPath: pageTwoURL.path) → true) == false`
- `(reread.displayStatus → .completed) == .inactive`
- `(reread.completedPageCount → 3) == 2`
- `reread.canTogglePause → false`
- `await relaunched.resumeMode(for: reread) == .repair`

**`testValidatingAMixedMissingAndMismatchedGalleryReconcilesBothFamiliesAtOnce` — FAILED, 5 issues**, and the shape is diagnostic: page 1's ABSENCE was already reconciled pre-fix, so every failure is page 3's mismatch half.
- `(download.completedPageCount → 3) == 2`
- `(diskManifest.pages[3] → "sha256:fe5d32f0…") == ""`
- `(diskManifest.completedPageCount → 3) == 2`
- `(fileManager.fileExists(atPath: pageThreeURL.path) → true) == false`
- `(reread.completedPageCount → 3) == 2`

**`testAnUnreadablePageHoldsWhileAMismatchedSiblingStillReconciles` — FAILED, 3 issues.** The hold half already held pre-fix (nothing was blankable, so the loop refused and the entry stood); what failed is the mismatched sibling's durable half.
- `(download.completedPageCount → 3) == 2`
- `(diskManifest.pages[2] → "sha256:0f6724ab…") == ""`
- `(FileManager.default.fileExists(atPath: pageFileURL(…, index: 2).path) → true) == false`

**`testACombinedWholesaleShapeRefusesBeforeAnyFileIsRemoved` — FAILED, 5 issues.** The plan anticipated this arm's refusal half would already pass; it did not, and the reason IS D-SSOT-02's substance. Pre-fix the guard saw only the positively-absent page 1, so `1 < 2` passed and page 1 was blanked while page 2's mismatch went unnoticed — a partial reconciliation of a shape that should refuse entirely:
- `(download.displayStatus → .inactive) == .error`
- `(download.lastError?.code → nil) == .fileOperationFailed`
- `(diskManifest.pages → [2: "sha256:0f6724ab…", 1: ""]) == (claimedHashes → [1: "sha256:0eb236e5…", 2: "sha256:0f6724ab…"])`
- `(diskManifest.completedPageCount → 1) == 2`
- `(reread.displayStatus → .inactive) == .completed`

**Passed pre-fix, unchanged, in the same run:** `testValidatingAPartiallyMissingGalleryBlanksExactlyTheMissingPagesOnDisk`, `testWholesaleBlankingIsRefusedSoTheSessionErrorStandsAndTheClaimedHashSurvives`, `testAReconciledRecordResumesThroughTogglePauseIntoAQueuedRepair`. That is the boundary evidence: the presence arm's behavior is untouched by this plan, before and after.

## Rewritten Rather Than Supplemented

The plan directed the executor to locate and REWRITE any existing pin asserting that a readable-but-mismatched file leaves the manifest verbatim with the entry kept.

**No such pin existed.** A search across the test tree found the corrupt-in-place stance recorded only as prose, never as an expectation: `DownloadStoreHashTests.testValidateReportsCorruptedPageImageData` asserts `storage.validate`'s VERDICT (unchanged by this plan — the store still reports a corrupted page), and `DownloadInspectorLoadTests` drives a stubbed `validateImageData` closure and asserts toast plumbing. Neither reaches the coordinator's reconciliation. So the four cases are additive by circumstance, and the rewrite the plan anticipated applied to the DOC comments instead — which is where 15-56 had actually recorded the stance (its dispositioned residual #2), and where Task 1's module sweep and Task 2's contract sweep both landed.

**No elsewhere-pinned expectation surfaced in the full run.** The suite went 386 → 390 tests in the downloads target with zero failures, so nothing outside this suite had encoded mismatch-stays-refusal as an assertion.

## Dispositioned Residuals

Both are decisions carried forward from the plan, not misses:

1. **The combined-wholesale relaunch reading.** A gallery whose combined blank set covers every claimed page still refuses, so after relaunch its record reads `.completed` until the user validates again. That is the irreversibility defence working as designed — the guard cannot distinguish "every page is genuinely broken" from a systematically wrong hash pipeline — it is re-diagnosable in one tap, and its in-session start affordance is 15-57's widened inspector retry. Pinned, with a comment naming it, in `testACombinedWholesaleShapeRefusesBeforeAnyFileIsRemoved`.
2. **The guard-then-removal drift window.** If files vanish concurrently between the guard's scan and the post-removal rescan, the loop's own guards may refuse blanking after corrupt files were already removed; the record then over-claims until the next validate, which sees positive absences and reconciles. Hashes were never destroyed on untrustworthy evidence, which is the property the defence protects, and the window is bounded by two same-actor synchronous scans.

## Observed, Out of Scope, Not Changed

`AppPackage/Tests/DetailFeatureTests/DetailDownloadRepairPredicateTests.swift` carries the retired stance in two doc comments — line 13 (`… or files that exist and are wrong (corrupt-in-place), and a repair that only fetches absent pages fixes neither of those`) and line 52 (`… would leave a wholesale-unverifiable or corrupt-in-place gallery exactly as it was`). Post-D-SSOT-01 a corrupt-in-place gallery no longer reaches the complete-claiming `.error` family those sentences enumerate, so the enumeration is stale in exactly the way `DetailReducer.swift`'s was.

It was **not edited**, deliberately and on the plan's own scoping: Task 2's Step 3 sweeps "any other **source** comment", the file is a test file under `AppPackage/Tests`, and it is declared in neither `files_modified` nor Task 2's `<files>`. Every acceptance criterion of Task 2 is satisfiable without touching it (the `corrupt-in-place` grep targets `DetailReducer.swift`, which now returns `0`), its five expectations are about the predicate's truth table and pass unchanged, and the predicate they pin did not move. Recorded here with file and line so a follow-up round can close it as a one-line prose fix rather than rediscovering it.

## Deviations from Plan

None — the plan was executed exactly as written, and **no DECISION CHECKPOINT was needed**. Every instruction resolved against the real post-15-57 source, including the three that read as conditionals: the 1000-line split (did not trigger, recorded above), the existing corrupt-in-place pin to rewrite (none existed as an expectation; the stance lived in prose and was rewritten there), and the elsewhere-pinned expectations Step 4 anticipates (none surfaced).

Two implementation choices worth naming, both inside the plan's latitude rather than departures from it:

- **`removeMismatchedPageFiles` treats an already-absent file as a no-op success**, mirroring `removeFolder(at:)`'s posture in full (containment check plus an existence guard) rather than only its containment check. A file that vanished concurrently has reached the goal state — no file remains — so reporting it unremoved would demote a page to a hold for an outcome that already succeeded.
- **The guard's set computation was extracted** into the private `prospectiveBlankPages(manifest:presenceScan:mismatchedPages:)` rather than left inline, which is the readability extraction Step 5 calls for. It is a meaningful unit — D-SSOT-02's measured set — not a rename wrapper, and its doc records why the set must be computed before any removal (afterwards the two halves are indistinguishable, so the guard would be measuring the consequence of the act it authorizes).

## Issues Encountered

- **A transport interruption cut the session between the two task gates.** Task 1 was already committed. Every verification touched by the interruption was re-run from scratch rather than trusted: the full `FeatureTests` plan, the clean app-scheme build, and standalone SwiftLint over all five Swift files. All three were run as single, non-overlapping invocations.
- **No log content was added anywhere.** The content pass's read-failure catch and the removal's failure catch are both deliberately silent, each with a comment saying why: the outcome is a hold, and the kept operation-level signal is the surface. `DownloadLogPrivacyInvariantTests.testDownloadIdentityLogsStayHashMasked` passed in the same run, confirming the hash-masked inventory is unchanged — the trap 15-56 documented.

## Verification

- Task 1 gate — `-only-testing:DownloadsFeatureTests/DownloadValidationReconciliationTests`: **`** TEST SUCCEEDED **`**, 7 tests in 1 suite, zero failures.
- Task 2 gate — full `FeatureTests` plan, re-run from scratch after the interruption: **`** TEST SUCCEEDED **`**. Downloads target **390 tests in 69 suites** (+4 over 15-57's 386), every target green, **zero** recorded failures across the whole run.
- 15-56's presence-arm suite green in that same run, named individually: `testValidatingAPartiallyMissingGalleryBlanksExactlyTheMissingPagesOnDisk` ✔, `testWholesaleBlankingIsRefusedSoTheSessionErrorStandsAndTheClaimedHashSurvives` ✔, `testAReconciledRecordResumesThroughTogglePauseIntoAQueuedRepair` ✔.
- `DownloadLogPrivacyInvariantTests` ✔ in the same run (`testDownloadIdentityLogsStayHashMasked` passed).
- Clean app-scheme build: **`** BUILD SUCCEEDED **`**, no `warning:` or `error:` lines.
- SwiftLint over all five touched Swift files with the repository config in `--strict` mode: **0 violations, 0 serious**. The app-scheme build does not lint `Tests/`, so the test file was linted explicitly with the standalone binary.
- No `swiftlint:disable`, no `@unchecked Sendable`, no `@preconcurrency`, no `nonisolated(unsafe)` anywhere in `AppPackage/Sources/DownloadClient` or `AppPackage/Sources/DetailFeature` (grep count: 0).

## Acceptance Criteria

| Criterion | Result |
|---|---|
| `grep -c 'contentMismatchScan'` in DownloadStore+Operations.swift | `1` (≥1 required) |
| `grep -c 'contentMismatchScan'` in DownloadClient+PersistenceNormalize.swift | `1` (≥1 required) |
| `grep -c 'func reconcileWorkingManifestAgainstPageFiles'` in ExecutionSupport | `1` — shared, not duplicated |
| `grep -v '^\s*//' PersistenceNormalize \| grep -c 'pages\[page\] = ""'` | `0` — no inline blanking in the validate path |
| `grep -c 'D-SSOT-01'` in DownloadClient+PersistenceNormalize.swift | `3` (≥1 required) |
| `grep -c 'D-SSOT-04'` in DownloadStore+Operations.swift | `1` (≥1 required) |
| Guard-before-removal pinned (corrupt file still on disk after the refusing validate) | yes — see D-SSOT-02 section |
| Hold pinned from both sides (page 2 blanked+removed, page 3 hash+file intact, entry kept) | yes |
| No-laundering invariant asserted after durable reconciliation | yes — `expectNoBlankHashedPageKeptItsFile`, called from three cases |
| Falsifiability recorded (which arms failed pre-fix; presence arm unchanged) | yes, verbatim above |
| Task 1 targeted command exit code | `0` |
| `grep -c 'positive content-level evidence'` in AGENTS.md | `1` (≥1 required) |
| `grep -c 'stays a session-scoped refusal'` in AGENTS.md | `0`, as required |
| `grep -c 'operation-level'` in DownloadClient+Manager.swift | `2` (≥1 required) |
| `grep -c 'corrupt-in-place'` in DetailReducer.swift | `0`, as required |
| Full FeatureTests exit code / clean build lint | `0` / zero violations |

## User Setup Required

None - no external service configuration required.

## Device Retest Input (15-UAT.md test 5)

**The expected observations CHANGE under this plan**, so the owner's physical-device pass should be re-taken for the corrupt-bytes half:

1. Alter the bytes of some page files of a completed gallery outside the app (e.g. overwrite 10 of 36 with different content), then tap **Validate** in the inspector.
2. The toast still reports the corrupted-page verdict — but the gallery now reads **incomplete** (26/36) with **Resume enabled**, where before it stayed a yellow error over a 36/36 claim.
3. In the Files app, the 10 altered files are **gone from the folder**. That is deliberate: it is what makes those pages genuinely re-fetchable rather than silently re-blessed on the next run.
4. **Resume** starts the run, it resolves `.repair`, and exactly those 10 pages are re-downloaded; the other 26 are kept.
5. **Force-quit before resuming**, relaunch: the incomplete reading and the enabled Resume both persist.
6. The deliberate exceptions to observe, both still showing the error surface: a gallery whose pages are **all** broken (deleted, altered, or a mix) — the combined-wholesale refusal, which after relaunch still reads `.completed` — and a gallery with a page whose file cannot be read at all. Both remain startable through the inspector's retry action (15-57).

## Next Phase Readiness

- G-15-SSOT is closed for the validate path: every positive per-page finding, absence or mismatch, is durable, and the session-scoped surface carries only what the manifest legitimately cannot record.
- One prose residual is open and recorded above with file and line (`DetailDownloadRepairPredicateTests.swift`, lines 13 and 52), deliberately left out of scope as an undeclared file. It is a comment-only change with no behavioral consequence.
- No blockers.

## Self-Check: PASSED

All six claimed source/test files exist on disk, `DownloadValidationContentArmTests.swift` correctly does not, and both task commits (`7586dc26`, `7a01604f`) resolve in `git log`.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-09*
