---
phase: 15-continued-background-downloads
plan: 67
subsystem: downloads
tags: [download-client, manifest-ssot, filesystem, wholesale-guard, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-62's per-page refutation hold, 15-66's opt-in mutation defaults and the two cross-references it left at the seed-route sites"
provides:
  - "One wholesale guard basis: blankable absences PLUS surviving refutations, measured inside the shared blanking loop so no caller can relax the threshold"
  - "Classify-authorize-remove ordering on the repair-seed route, mirroring the validated-record pass and reusing removeRefutedPageFiles"
  - "A crossing fixture pair over the wholesale threshold, staged through the probe exit that yields a surviving rejection for a discarding caller"
  - "Three re-derived doc contracts: PageFileScan membership, the loop's line 2b, and the all-or-nothing guard's basis"
affects: [repair seed preparation, working-manifest blanking, validate-time reconciliation, run progress announcement]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A per-page hold that removes a page from a threshold's numerator changes that threshold for every other page; hold and guard must be measured over one population"
    - "Put the guard where the act is, not at the callers: a threshold restated at a call site is a threshold the next call site can forget"
    - "A guard basis chosen so the authorized act is guard-NEUTRAL makes the caller's predicate and the callee's provably identical"
    - "Split a file before growing its contract docs; a 1000-line ceiling reached by prose is a signal the type or the function wants its own file"

key-files:
  created:
    - AppPackage/Sources/DownloadClient/PageFileScan.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+WorkingManifestReconciliation.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadStore.swift
    - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadValidationRejectionArmTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift

key-decisions:
  - "DEC-A: the guard's combined basis is computed INSIDE the loop, so both present callers and any future one inherit it; the seed route's own pre-removal guard is the same expression rather than a second rule"
  - "DEC-B: the combined basis was chosen partly because it makes the comparison INVARIANT under an authorized removal — a removal moves a page from the refutation term to the absence term — so the caller's guard and the loop's cannot disagree"
  - "DEC-C: `materializeRepairSeed`'s SOURCE scan stays discarding and is NOT converted; its refusals reach a different folder as positive absences, so neither WR-01 nor WR-02 is reachable through it. The stale forward reference 15-66 left there is replaced by that disposition"
  - "DEC-D: both mixed-shape cases are staged through `probeAssetFileContent`'s surviving-rejection exit rather than through a removal failure, because a removal-failure double would also block `removeRefutedPageFiles` and make the authorized side unobservable"
  - "DEC-E: two files were split rather than grown — `PageFileScan` to its own file, the blanking loop to `DownloadClient+WorkingManifestReconciliation.swift` — because both hosts were within 30 lines of the 1000-line error"
  - "DEC-F: the seed's `existingPages`, `unprobedPages` and `scanSucceeded` now all come from the POST-removal scan, so the announcement's evidence and the blanking's evidence are one probe"

patterns-established:
  - "Crossing fixture pair: one staging helper, two regimes differing only in the page that moves the shape across the discontinuity"
  - "A doc that names what an adjacent guard does must be re-proved against the guard, not against the sub-expression it quotes"

requirements-completed: []

coverage:
  - id: D1
    description: "A mixed rejected-plus-absent shape whose combined prospective set is the whole record blanks nothing and removes nothing"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationRejectionArmTests.swift#testAMixedRejectedAndAbsentShapeRefusesTheWholesaleBlanking"
        status: pass
    human_judgment: false
  - id: D2
    description: "The same folder one usable page short of wholesale removes the refuted file and blanks both corrections in the one preparation"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationRejectionArmTests.swift#testAMixedShapeBelowTheThresholdRemovesTheRefutedPageAndBlanksBoth"
        status: pass
    human_judgment: false
  - id: D3
    description: "The entitled repair-seed pairing, the two wholesale rejection refusals and the authorized single-page rejection are unchanged"
    verification:
      - kind: unit
        ref: "xcodebuild test -only-testing:DownloadsFeatureTests/DownloadValidationReconciliationTests -only-testing:DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests (22 tests, 0 failures)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Every pre-existing validation, repair, capture, background, display and privacy-invariant behaviour is unchanged"
    verification:
      - kind: unit
        ref: "xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests (945 tests, 0 failures, 22 targets; downloads target 426 in 72 suites)"
        status: pass
    human_judgment: false

# Metrics
duration: 25min
completed: 2026-08-10
status: complete
---

# Phase 15 Plan 67: One Evidence Rule at Both Blanking Entry Points Summary

**The all-or-nothing guard is now measured over the combined positively-refuted population inside the blanking loop itself, and the repair-seed route classifies, authorizes, removes and only then blanks — so a per-page hold can no longer relax a wholesale threshold, and no automatic pass leaves a claimed hash standing over bytes it positively refuted.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-08-10T08:28Z (local 17:28 JST)
- **Completed:** 2026-08-10T08:53Z
- **Tasks:** 2 (RED, GREEN)
- **Files created:** 2
- **Files modified:** 5

## Accomplishments

- **WR-01, stated as the property rather than as the counterexample.** A threshold is a statement about a quantity, so a per-page rule that removes a page from that quantity redefines the threshold for every other page. 15-62 added the fourth clause and reported it as "can only blank less"; measured over `blankedPageCount` alone it blanks MORE. The fix puts both terms on one side of one comparison — blankable absences plus surviving refutations, unprobed pages excluded — and puts that comparison inside the loop, where every present and future caller inherits it. A refutation is a positive determination that the recorded hash describes nothing reusable, which is the same evidence class as an absence and licenses the same correction; that is why it belongs in the count even though this loop is not the thing that acts on it.
- **WR-02 was not "deleted too early" but "never deleted at all", and that changed where the fix had to go.** `probeAssetFileContent` — the exit `probeAssetFile` falls back to when the metadata read throws — reports an empty file as `.rejected(fileRemains: true)` unconditionally, for a discarding caller too. `removeRefutedPageFiles` was reachable only from `reconcileValidatedRecordAgainstPageFiles`, which only a user-initiated Validate reaches. So between those two facts a repair-seed preparation could meet a claimed page whose bytes were positively refuted and leave it exactly as found, run after run, with line 2b correctly declining to blank it because nothing had removed the file. The seed route now performs the removal under the same guard, through the same primitive.
- **The combined basis was chosen for an invariance property, not only for correctness at one shape.** A removal converts a member of the surviving-refutation term into a member of the blankable-absence term and leaves the sum unchanged. So the caller's pre-removal guard and the loop's post-removal guard evaluate the same number, and the removal can never be the thing that talks the loop into blanking. Under the OLD basis the same removal moved the numerator upward, which is why "guard at the caller, guard again at the loop" was not previously a statement about one predicate.
- **The fixture crosses the discontinuity by construction.** Both cases share one staging helper and differ only in `gallery.pageCount`: two claimed pages puts the combined set at exactly the record (refuse), three puts it one short (authorize). Each side asserts its own regime's complete end state — in-memory manifest, on-disk manifest, both files, the no-laundering structural pin, and the record a relaunched coordinator reads — rather than a single discriminating value.
- **The staging reaches the surviving rejection through the production exit that produces one.** `PartialProbeFailureFileManager` throws from `attributesOfItem` for page 1's path fragment and from nothing else; the directory listing, the existence check and the `FileHandle` read are all real, and page 1 is a real zero-byte file. That is WR-02's own mechanism. Staging the survival with a removal-failure double instead would have been unfaithful in a way that hid the authorized side: the same double would also fail `removeRefutedPageFiles`, so the authorized case would have been green over the defect.
- **Two files were split rather than grown, before any code was written.** `DownloadStore.swift` was at 981 of the 1000-line error and `DownloadClient+ExecutionSupport.swift` at 972, and this plan adds an evidence rule plus three re-derived contracts. `PageFileScan` moved to `PageFileScan.swift` with its contract doc; `reconcileWorkingManifestAgainstPageFiles` moved to `DownloadClient+WorkingManifestReconciliation.swift`. Post-change: 929 and 878.
- **Three doc claims were re-proved against source clause by clause**, and a fourth was found false by the change itself (deviation 2). None was edited around.

## Task Commits

Each task was committed atomically:

1. **Task 1: RED — pin the mixed rejected-plus-absent shape on both sides of the threshold** - `96987202` (test)
2. **Task 2: GREEN — combined guard basis and seed-route classify-authorize-remove ordering** - `37cc25af` (fix)

## Banked Falsifiability

The RED suite failed against pre-fix production with **9 verbatim issues**. The two headline observations are exactly WR-01 and WR-02, in that order:

| Case | Pre-fix (recorded verbatim) | Post-fix |
|---|---|---|
| `testAMixedRejectedAndAbsentShapeRefusesTheWholesaleBlanking` | `(seedManifest.pages → [2: "", 1: "sha256:done"]) == (claimedHashes → [1: "sha256:done", 2: "sha256:done"])` failed; same on disk; `completedPageCount → 1` where 2 was required; the relaunched record read `1` / `.inactive` | manifest verbatim, 2 of 2, page 1's zero-byte file intact, relaunched `.completed` |
| `testAMixedShapeBelowTheThresholdRemovesTheRefutedPageAndBlanksBoth` | `(seedManifest.pages[1] → "sha256:done") == ""` failed, `completedPageCount → 2` where 1 was required, and `fileExists(refutedPageURL) → true` — the claimed hash standing beside the refuted file | page 1 removed and blanked, page 2 blanked, page 3 untouched, 1 of 3 after relaunch |

Two details worth recording rather than smoothing over:

- The refusal side's pre-fix failure is the WR-01 relaxation **exactly as the review derived it**: `blankedPageCount == 1` for the absence alone, `1 < 2` passes, and page 2 is blanked over a pass that had explained away the entire record. No fixture adjustment was needed to reach it, because the surviving rejection arrives through the probe's content-read exit rather than through a failed deletion.
- The authorized side's `displayStatus == .inactive` assertion **passed pre-fix** (2 of 3 also reads incomplete). That is not a weak pin: it is the regime's end state, and the three assertions that do discriminate are stated beside it. A case built only around the display reading would have been green over both defects.

## Loop-Caller Sweep, Post-Change

Both callers of `reconcileWorkingManifestAgainstPageFiles`, enumerated fresh (`rg -n 'reconcileWorkingManifestAgainstPageFiles' AppPackage/Sources` → the declaration plus exactly these two):

| Caller | Evidence ordering after this change |
|---|---|
| `DownloadClient+ExecutionSupport.swift:372` (`prepareWorkingSeed`) | Non-mutating scan → union the seed copy's carried non-answers → derive refuted survivors (claimed ∩ rejected ∖ unprobed) → combined guard → `removeRefutedPageFiles` → fresh non-mutating scan → loop. All inside the existing D-G7-01 bracket; no new bracket nested. |
| `DownloadClient+PersistenceNormalize.swift:370` (`blankingPass`, from `reconcileValidatedRecordAgainstPageFiles`) | Byte-for-byte unchanged. It already had this ordering with one extra evidence class (the content pass), and its combined guard already preceded its removal. |

`rg -n 'removeRefutedPageFiles' AppPackage/Sources/DownloadClient` → the declaration plus exactly two call sites, one per row above.

Every consumer of `rejectedPageRelativePaths` in `AppPackage/Sources`, with its disposition:

| Site | Disposition |
|---|---|
| `DownloadStore.swift:214-249` | Producer. Unchanged: membership is "refuted AND still there", first surviving candidate wins, a usable candidate clears it. |
| `DownloadClient+ExecutionSupport.swift:360` | Threads the destination scan's member into the classified scan. Unchanged (dropping it would re-license the act line 2b withholds). |
| `DownloadClient+ExecutionSupport.swift:453/458/471/485` | **New.** The refuted-survivor derivation, the absent-half subtraction, the removal's path map, and the post-removal rescan's pass-through. |
| `DownloadClient+PersistenceNormalize.swift:272/286/450` | Validated-record pass. Unchanged. |
| `DownloadClient+WorkingManifestReconciliation.swift:226` | The loop's line 2b, now also incrementing the guard's second term. |

No other blanking-adjacent consumer exists.

## Doc Re-Audit, Clause by Clause

| Doc | Clause as it stood | Verdict against post-change source | Action |
|---|---|---|---|
| `PageFileScan` membership | "A discarding caller whose housekeeping deletion succeeded reports nothing here … which keeps every pre-existing caller byte for byte" | **FALSE.** The content-read exit refuses without deleting for every caller alike, so a discarding caller does see members. | Replaced: membership is reached by two routes (failed deletion, or the never-deleting content exit), with the false clause named as what it cost. |
| `PageFileScan` member list | "zero bytes, or not a regular file" | Incomplete — omitted the content-read refusal. | Extended to "zero bytes, not a regular file, or empty on a content read". |
| Loop line 2b | "The caller that removed the file first … the discarding scan whose housekeeping deletion failed … every pre-existing caller is byte for byte unchanged" | Half true, half false: the ordering existed on ONE route, and the byte-for-byte clause repeats the refuted claim. | Rewritten: the removal belongs to the caller and BOTH callers now perform it; membership is conditional on survival but NOT on the caller having declined to discard. |
| Loop guard prose (line 3) | "Widening the comparison to the blankable population would refuse those genuine absences because some OTHER page went unanswered" | TRUE **of the unprobed pages**, and it is kept for them. It was silently doing double duty as a rationale for excluding refutations, which are not non-answers. | Split: the unprobed rationale is kept verbatim in its own paragraph; the refutation term gets its own derivation, including why the basis is measured here rather than at the callers. |
| Loop guard prose, shape | (absent) | The comparison is piecewise — the `blankedPageCount > 0` early return means it is only ever evaluated where at least one page would be blanked. | Added, so a reader does not take it for a property of the scan. |
| `probeAssetFile`'s entitled-site enumeration | "Exactly one production actor writes it, at four sites … the working folder's destination scan" | **FALSE after this change** — that site no longer discards. | Corrected to three sites, with the fourth's removal and its reason recorded. |
| `probeAssetFileContent` | "without discarding … deliberately" | TRUE, and it stays. | Kept, with a paragraph naming the consequence for its consumers rather than leaving it to be rediscovered. |
| `makeFolderRecord`'s entitlement note | "the only entitled actor left is the repair seed, whose deletions the same bracketed preparation blanks the record for" | The actor is still one; the clause after it now describes only the cover and the source scan. | Narrowed to exactly those two. |
| `materializeRepairSeed` source scan | "(15-67 converts this route's classify-then-authorize ordering; until then …)" | **FALSE** — this round does not convert it (DEC-C). | Replaced by the disposition and the folder-boundary argument for why neither WR-01 nor WR-02 is reachable through it, plus an explicit statement that what the SOURCE record owes is unanswered. |

## Decisions Made

- **DEC-A: the guard basis lives in the loop, not at the callers.** The seed route computes the identical prospective set before removing, but that is a precondition for its own destructive step rather than a second copy of the threshold: if only the caller measured it, a third entry point would inherit nothing. Putting it in the loop is what makes "no per-page hold can relax the wholesale threshold, at any caller, by construction" a statement about the code rather than about the current call graph.
- **DEC-B: the basis was picked so the authorized removal is guard-neutral.** This is the argument the plan asked to be recorded. Let `A` be the blankable absences and `R` the surviving refutations at classification time. The caller authorizes on `|A ∪ R| < completedPageCount`. After removing `R' ⊆ R`, the loop sees absences `A ∪ R'` and survivors `R ∖ R'`, so its sum is `|A| + |R|` — identical. A rescan can differ only by demoting a page to a non-answer (sum moves down, and the loop would not blank that page anyway) or by catching a file that vanished in the race (a genuine positive absence, licensed on its own). So the two predicates cannot disagree in the direction that matters, and in particular the inner guard cannot be *relaxed* by the act the outer one authorized. Under the pre-change basis the same removal raised the loop's numerator, which is precisely why the two guards were not one predicate before.
- **DEC-C: `materializeRepairSeed`'s source scan is not converted, and the reason is a folder boundary rather than scope.** There the deletion is in the SOURCE folder while the blanking is of the DESTINATION's manifest, for a page the copy never landed — so the destination meets a positive absence, never a surviving refutation. Neither the WR-01 numerator shrink nor the WR-02 standing hash is reachable through it. What the source folder's own record owes for a file removed there is a real and separate question; it is named in the code rather than implied to be answered.
- **DEC-D: the crossing fixture is staged through the probe's content-read exit, not through a removal failure.** The review's counterexample uses a failed housekeeping deletion, which is faithful for the refusal side. It is not usable for the pair: `FailingRemovalFileManager` keyed on page 1 would also fail `removeRefutedPageFiles`, so the authorized side's post-fix end state would equal its pre-fix end state and the case would be green over the defect. The content-read exit produces the same surviving rejection while leaving the authorized removal able to succeed, which is the only staging that lets one helper serve both regimes.
- **DEC-E: split before writing.** Both hosts were inside 30 lines of the hard 1000-line error while this plan had to add an evidence rule and three re-derived contracts to them. `PageFileScan` is a public model with a long contract doc and had no reason to live inside the store; the blanking loop is the shared rule two entry points reach and now has a file named for it. Neither move changes a declaration, and both are pure relocations apart from the doc corrections this plan owes.
- **DEC-F: the seed's returned evidence follows the post-removal scan.** `existingPages`, `unprobedPages` and `scanSucceeded` all come from the scan the loop consumed. Leaving `existingPages` pinned to the pre-removal classification would let the run treat a page whose refuted file this very preparation deleted as already present.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The plan's `-only-testing` selector names a file, not a suite**

- **Found during:** Task 1 (RED gate)
- **Issue:** `-only-testing:DownloadsFeatureTests/DownloadValidationRejectionArmTests` selects nothing. That file is an `extension` of `DownloadValidationReconciliationTests`, so the runnable suite is the latter. The first RED run reported `TEST SUCCEEDED` over seven repair-seed cases and never executed either new case — a green that meant nothing.
- **Fix:** Substituted `-only-testing:DownloadsFeatureTests/DownloadValidationReconciliationTests` in every gate invocation. No other flag changed.
- **Verification:** The corrected invocation runs 22 tests in 2 suites.
- **Committed in:** n/a (invocation only)

**2. [Rule 1 - Bug] The log-privacy invariant is keyed by file name, and the split moved a key**

- **Found during:** Task 2 (GREEN), first full suite run
- **Issue:** `DownloadLogPrivacyInvariantTests.testDownloadIdentityLogsStayHashMasked` asserts an equality against a per-file table of hash-masked interpolations. Relocating the blanking loop moved its `logger.notice` from `DownloadClient+ExecutionSupport.swift` to `DownloadClient+WorkingManifestReconciliation.swift`, so the table's key was stale while the count and the total were unchanged. The file is not in the plan's `files_modified`.
- **Fix:** The `+ExecutionSupport` entry is replaced by a `+WorkingManifestReconciliation` entry at the same count of 1; `expectedHashMaskedTotal` is unchanged at 11, which is the check that the edit moved a key rather than lost a site.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift`
- **Verification:** Full suite 945/0; the suite's own doc, which explains the table as the thing that makes such a change "a deliberate, visible edit here", reads true of this edit.
- **Committed in:** `37cc25af` (Task 2 commit)

**3. [Rule 1 - Bug] Two doc contracts this change itself falsified**

- **Found during:** Task 2 (GREEN)
- **Issue:** `probeAssetFile`'s doc enumerated four entitled discarding sites including the working folder's destination scan, which this plan converts; `makeFolderRecord`'s note described the entitled actor's deletions as ones "the same bracketed preparation blanks the record for", which after the conversion describes only the cover and the source scan.
- **Fix:** Both re-derived against post-change source. Neither is a scope widening — they are the sites whose truth this change moves.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadStore.swift`
- **Verification:** Clean build 0 warnings; SwiftLint `--strict` 0 violations.
- **Committed in:** `37cc25af`

**4. [Rule 1 - Bug] 15-66's forward reference at the un-converted sibling site**

- **Found during:** Task 2 (GREEN)
- **Issue:** `DownloadStore+Operations.swift:154` carried "(15-67 converts this route's classify-then-authorize ordering …)". Under DEC-C this round does not convert it, so the comment would have become a false promise.
- **Fix:** Replaced by the site's actual disposition and the folder-boundary argument for it, plus an explicit note that the source record's own obligation is unanswered.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift`
- **Verification:** `rg -n '15-67' AppPackage App ShareExtension` returns nothing.
- **Committed in:** `37cc25af`

### Files declared but not modified

`AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift` is in the plan's `files_modified` and was left untouched. The plan permits either home for the seed-route arcs; the rejection-arm file is the correct one because the suite is organised by the REJECTION family rather than by the entry point, it already owns the wholesale-refusal template and the no-laundering structural pin, and it is the file the plan's `artifacts` block names. That suite's existing seed cases are unmodified and green.

### Undeclared files modified

`DownloadLogPrivacyInvariantTests.swift` (deviation 2) and `DownloadStore+Operations.swift` (deviation 4). Both are direct consequences of this change; the first was a hard gate.

---

**Total deviations:** 4 (1 blocking invocation correction, 3 doc/test contracts this change falsified)
**Impact on plan:** No behaviour outside the plan's contract changed. The one substantive departure from the plan's own text is DEC-C, and the plan anticipated it by requiring a disposition for every site rather than a conversion.

## Issues Encountered

- **The plan's predicted RED sequence for the refusal side did not need its fallback.** The plan allowed for the pre-fix discarding scan deleting page 1 first and asked for the observed sequence to be recorded verbatim if so. It did not happen, because the staging reaches the surviving rejection through the exit that never deletes. The recorded pre-fix behaviour is therefore the clean WR-01 relaxation, banked above.
- **A first attempt at the authorized side using a removal-failure double was discarded before it was written**, for the reason in DEC-D. Recording it because the failure mode is silent: the case would have passed against unfixed production.

## Verification Evidence

Run one `xcodebuild` invocation at a time, with `-destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` substituted for the plan's ambiguous `name=iPhone Air`, and `DownloadValidationReconciliationTests` substituted for the plan's non-selecting `DownloadValidationRejectionArmTests` (deviation 1):

1. Task 1 RED gate — the two-suite selector — **TEST FAILED**, 22 tests / **9 issues**, exactly the observations banked above.
2. Task 2 gate — the same invocation after the fix — **TEST SUCCEEDED**, 22 tests in 2 suites.
3. `xcodebuild -scheme EhPanda -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/EhPandaPhase1567DerivedData build` — **BUILD SUCCEEDED**, **0 warnings, 0 errors** (the SwiftLint build-tool plugin runs in-build, so this is lint-clean over `Sources/`).
4. Full `FeatureTests` — **TEST SUCCEEDED**, **945 tests / 0 failures** across 22 targets (baseline 943, +2); downloads target 426 tests in 72 suites (+2, no new suite). One intermediate run surfaced deviation 2 and was re-run to green.
5. Standalone SwiftLint `--strict` over `Sources/DownloadClient` and `Tests/DownloadsFeatureTests` (the app scheme does not lint `Tests/`) — **0 violations, 0 serious in 116 files**.

Acceptance greps:

- `rg -n 'removeRefutedPageFiles' AppPackage/Sources/DownloadClient` → the declaration plus exactly two call sites: `PersistenceNormalize.swift:283` (validated record) and `ExecutionSupport.swift:471` (repair seed).
- `rg -n 'discardingRejected: true' AppPackage/Sources` → 3 hits, all in the repair-seed actor: `Operations.swift:142` (seed cover), `Operations.swift:159` (seed source scan), `ExecutionSupport.swift:384` (working-folder cover). The fourth, the working-folder destination scan, is gone.
- `rg -n '15-67' AppPackage App ShareExtension` → no match.
- File lengths: `DownloadStore.swift` 929 (was 981), `+ExecutionSupport.swift` 878 (was 972), `+WorkingManifestReconciliation.swift` 255, `PageFileScan.swift` 80, `+Operations.swift` 673, `DownloadValidationRejectionArmTests.swift` 419 — all under 1000. `DownloadContinuedSessionTests.swift` (993) and `DownloadFeatureTestHelpers.swift` (989) were not touched.
- Line lengths: no line over 120 in any touched file.
- `git diff --diff-filter=D --name-only HEAD~1 HEAD` → empty on both task commits.
- No `swiftlint:disable`, no `try?`, no force unwrap, no concurrency escape hatch introduced.

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/PageFileScan.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+WorkingManifestReconciliation.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadStore.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadValidationRejectionArmTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadLogPrivacyInvariantTests.swift` — FOUND
- Commit `96987202` — FOUND
- Commit `37cc25af` — FOUND

## Known Stubs

None. No hardcoded empty value, placeholder string or unwired data source was introduced. The two new files are relocations plus corrected contracts; the one new private function is fully wired into the production preparation and exercised from both sides of its guard.

## Threat Flags

None. The plan's three registered threats are addressed rather than extended: T-15-67-01 by the combined basis living inside the loop plus the crossing fixture pinning both sides, T-15-67-02 by the seed route's classify-authorize-remove ordering with unremoved files keeping hash AND file, T-15-67-03 by keeping unprobed holds out of the guard's basis, with the pre-existing genuine-absence arms (`testARepairWithAVanishedPageFileMarksTheRecordIncomplete`, `testAnInitialReuseOfACompleteManifestReconcilesVanishedPages`) green unchanged. No new network endpoint, auth path, file-access pattern or schema was introduced; the change adds one removal that is strictly narrower than the deletion it replaces, since the old one fired during classification with no guard at all. `DownloadLogPrivacyInvariantTests` is green with its masked total unchanged at 11.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- WR-01 and WR-02 — verification gap 2's evidence-ordering half — are closed at the invariant rather than at the two shapes the review named: the guard basis is a property of the loop, and the removal ordering is now identical on both blanking entry points.
- **DEC-C leaves one named, deliberate residual:** `materializeRepairSeed` still discards while scanning the SOURCE folder, and what the source gallery's own record owes for a file removed there is unanswered. It is recorded at the site in code, not only here. Neither WR-01 nor WR-02 is reachable through it, so it is not a re-opening of either.
- Remaining `15-REVIEW.md` blockers untouched and independent: CR-01 (the unbracketed queue-intent generation advance) was closed by 15-66's predecessors, CR-02 (`deleteFolder`'s unconfined caller-supplied name) is open, as are WR-04/WR-05 (the CR-04 narrowing's caller consequences) and IN-01/IN-02.
- **DEC-E is carried forward as a standing rule, not a one-off:** `DownloadStore.swift` and `+ExecutionSupport.swift` now have 71 and 122 lines of headroom, but `DownloadContinuedSessionTests.swift` (993) and `DownloadFeatureTestHelpers.swift` (989) keep their split-before-next-addition notes and were not touched here.
- 15-66's DEC-E is still open and unchanged: `validate`'s `discardingRejected` has no production caller passing `true`, and removing it would let `DownloadValidationPolicy` collapse to a single flag.
- Open, non-blocking, carried forward and unchanged: `DetailReducer.swift:112` names the superseded decision ID D-G5C-01, and `DetailDownloadRepairPredicateTests.swift` lines 13/52 still describe corrupt-in-place as a complete-claiming family member. Both comment-only, both in files this plan did not declare.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-10*
