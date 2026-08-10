---
phase: 15-continued-background-downloads
plan: 66
subsystem: downloads
tags: [download-client, manifest-ssot, filesystem, read-paths, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-62's classification-versus-mutation boundary, PageFileScan.rejectedPageRelativePaths and D-SSOT-07's manifest-only display basis"
provides:
  - "Opt-in mutation across the whole scan/probe/validate parameter family: every discardingRejected defaults to non-mutating, so a deleting caller must name it"
  - "A single enumerated entitled actor (the repair seed, 4 sites) whose deletions are paired with a durable blanking in the same D-G7-01 bracket"
  - "clearStaleDownloadErrorIfNeeded: the honest remainder of the coordinator's former folder sweep, with the side-effect-only scan deleted"
  - "Zero-byte read-path non-mutation regressions over loadManifest, resumeMode and the cover half, asserted from both sides"
affects: [reader open, resume-mode resolution, finalize merge, cache capture, background landing, repair seed]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A destructive parameter DEFAULT is an exit path: flipping it makes the safe property hold for callers that do not exist yet, where a caller-list patch only covers the ones someone enumerated"
    - "Entitlement to delete is a PAIRING, not a position: a caller may discard only where the same act durably reconciles the record for the page it destroyed"
    - "Where a value becomes the default, the explicit argument is removed rather than kept, so the non-default's grep IS the complete inventory of mutators"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadReadPathNonMutationTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadStore.swift
    - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceHelpers.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionPerform.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+BackgroundDownloads.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorStorageTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift

key-decisions:
  - "CR-03: the default is flipped across the WHOLE family — 10 declarations, not the 7 the plan listed — because the family boundary is what makes the property hold by construction"
  - "DEC-A: the entitlement test is the pairing (does this act blank the record for the page it destroyed?), which reduced the ENTITLED set from the plan's ~8 suggested sites to 4, all one actor"
  - "DEC-B: every reclassified site is verdict-preserving — a refused file is outside `pages` whether or not it is deleted — so only the deletion is withheld and no observable answer moved"
  - "DEC-C: redundant `discardingRejected: false` arguments were dropped rather than kept, so `discardingRejected: true` greps as the complete mutator inventory"
  - "DEC-D: `sanitizeLocalFilesIfNeeded` is renamed `clearStaleDownloadErrorIfNeeded` — after the sweep's deletion the name described nothing the function does; `loadManifest` now calls `fetchDownload` directly"
  - "DEC-E: `validate` keeps its parameter although no production caller now passes true — the family stays uniform and the store's public API keeps the opt-in it documents"

patterns-established:
  - "Default-flip over caller-patch: the sweep scope for a defaulted parameter is the parameter, not its call sites"
  - "Two-sided non-mutation assertions: file survival AND unchanged persisted record, the second read back through a fresh coordinator"

requirements-completed: []

coverage:
  - id: D1
    description: "Opening a downloaded gallery whose only page file is zero bytes leaves the file on disk and the manifest byte-identical, in-session and on a fresh coordinator"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadReadPathNonMutationTests.swift#testLoadManifestOverAZeroBytePageLeavesTheFileAndTheRecordUntouched"
        status: pass
    human_judgment: false
  - id: D2
    description: "resumeMode still resolves .repair over a damaged complete record without deleting the file that answers it"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadReadPathNonMutationTests.swift#testResumeModeOverAZeroBytePageResolvesRepairWithoutDeletingIt"
        status: pass
    human_judgment: false
  - id: D3
    description: "The cover half of the same boundary: a zero-byte cover survives a successful reader open"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadReadPathNonMutationTests.swift#testLoadManifestOverAZeroByteCoverLeavesTheCoverOnDisk"
        status: pass
    human_judgment: false
  - id: D4
    description: "The one entitled actor still discards, and its deletion is paired with a durable blanking of the same page"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift#testTheRepairSeedStillDiscardsAZeroBytePageAndBlanksIt"
        status: pass
    human_judgment: false
  - id: D5
    description: "No entitled caller's behaviour drifted and every pre-existing validation, repair, capture, background and display behaviour is unchanged"
    verification:
      - kind: unit
        ref: "xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests (943 tests, 0 failures, 22 targets; downloads target 424 in 72 suites)"
        status: pass
    human_judgment: false

# Metrics
duration: 45min
completed: 2026-08-10
status: complete
---

# Phase 15 Plan 66: Opt-In Mutation Across the Scan Family Summary

**CR-03 closed at the parameter rather than at its callers: every `discardingRejected` in the DownloadStore scan/probe/validate family now defaults to reading, the side-effect-only folder sweep is deleted, and the sole remaining discarder is the repair seed — whose deletions the same bracketed preparation blanks the record for.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-08-10T17:00Z (local 17:00 JST)
- **Completed:** 2026-08-10T17:45Z
- **Tasks:** 2 (RED, GREEN)
- **Files created:** 1
- **Files modified:** 13

## Accomplishments

- **The defect, stated as a property.** A probe that deletes what it refuses performs a mutation while FORMING an answer, so a destructive default made every caller nobody had enumerated a mutator. That is why CR-01's fix did not eliminate the deletion: 15-62 named the routes the finding named and left the parameter defaulting to destroy, so the identical end state was reachable by opening the reader (`loadManifest` → the coordinator sweep → `storage.validate`), by resolving `resumeMode`, and by every other unenumerated caller. Nothing on those routes writes the manifest, so the page kept its non-empty hash, the gallery kept deriving `.completed` under D-SSOT-07, and the divergence outlived the process with not even a session-scoped signal recording it.
- **The fix is the parameter, and the family is wider than the finding's list.** Fresh enumeration found **ten** declarations carrying the flag, not the seven the plan named: the three extra are `existingCoverFileURL` and both private `existingAssetFileURL` overloads, which sit *under* the cover route and would have kept the destructive default while the members above them flipped. All ten now default to `false`. `rg -n 'discardingRejected: Bool = true' AppPackage/Sources` returns nothing.
- **Entitlement was re-derived as a test, not inherited as a list.** The plan offered a candidate ENTITLED set of roughly eight sites and instructed that each be verified against its consumer. The test applied was: *a caller may discard only where the same act durably reconciles the record for the page it destroyed.* Under it the set collapses to **four sites, all one actor** — the repair seed's source scan and cover resolution, and the working folder's destination scan and cover resolution — because each removal becomes a positive absence that `reconcileWorkingManifestAgainstPageFiles` blanks inside the same D-G7-01 bracket. Every other candidate failed the test for the same structural reason, recorded in the table below.
- **The recurring shape the plan warned about was found twice, in sites the review's list did not reach.** `addingCurrentFileHashes` (the finalize merge) and `captureTarget`/`performCacheCapture` scan the WHOLE folder while reconciling at most one page, so a discarding scan deleted the files of pages whose hashes the caller then left standing. `materializeRepairSeed`'s per-page copy guard was worse in kind: it fires only where the file changed since the scan classified it usable, and the page is then recorded as UNANSWERED — deleting it destroys a file the reconciliation is explicitly instructed not to blank the hash for.
- **Every reclassification is verdict-preserving, which is the whole argument.** A refused file is outside `pageFileScan.pages` whether or not it is deleted, so `.missingFiles` still reports the same page, `hashReadableAsset` still throws, `missingFinalizedPageIndices` still returns the same set, `backgroundPageRelativePath` still picks the same fresh name, and `captureTarget`'s preferred path is still nil. The deletion was never what produced any answer — it was only damage — and the two rewritten store cases now assert both halves side by side.
- **The sweep was deleted, not emptied, and the entry it lived in was renamed.** With the deletion withheld, `scanCompletedFolder` computed two answers nobody read (`_ =` on both). What remains of `sanitizeLocalFilesIfNeeded` sanitizes no files at all, so it is now `clearStaleDownloadErrorIfNeeded(gid:)`, expressing the half that was always real: retracting an operation-level signal that outranks the record after the operation that raised it has been falsified. `loadManifest`'s call — which only ever passed `clearingLastError: false` — is now `fetchDownload(gid:)`.
- **Four contract docs were re-proved against source rather than edited around.** The `validate` justification that reasoned from "the answer feeds nothing destructive" is replaced by the corrected rule and by why the old test was the wrong one; `probeAssetFile`'s caller enumeration now names the post-flip set; `makeFolderRecord`'s entitled-paths list (which named five actors, four of which never qualified) is corrected; and `resumeMode`'s (a)/(b) enumeration was re-audited clause by clause and found to argue from the blanking loop rather than from the probe's housekeeping, so it stands with an added note on what the call no longer does.

## Task Commits

Each task was committed atomically:

1. **Task 1: RED — prove an ordinary read deletes a page file and reconciles nothing** - `cc8175f9` (test)
2. **Task 2: GREEN — flip the destructive defaults, delete the side-effect sweep, sweep every caller** - `fc737485` (fix)

## Caller Disposition Table

Derived by fresh enumeration (`rg -n 'discardingRejected' AppPackage/Sources` plus the family-name grep the plan specifies), not copied from the plan or the review. Disposition **(a) READ** takes the new non-mutating default and writes no argument; **(b) ENTITLED** names `discardingRejected: true` with a WHY at the site; **(p) POLICY** threads a value decided at a public boundary; **(t) THREAD** is a pass-through inside the family.

| # | Site | Disposition | Reason |
|---|---|---|---|
| 1 | `PublicAPI.swift:277` `loadManifest` → `storage.validate` | **a** | The reported gap. A report is a read; nothing here writes the manifest. |
| 2 | `SchedulingHelpers.swift:75` `resumeMode` → `storage.validate` | **a** | The second reported route. Converges only if the user later starts the download; until then the record lies about what it deleted. |
| 3 | `PersistenceHelpers.swift` `scanCompletedFolder` (×2) | **deleted** | Both results discarded; the function existed for the deletion alone. |
| 4 | `PersistenceNormalize.swift:132` `validateImageData` → `validate` | **a** | Was explicit `false`; now the default. Its verdict feeds a reconciliation that may refuse. |
| 5 | `PersistenceNormalize.swift:249` presence scan | **a** | Was explicit `false`; evidence gathering below the guard. |
| 6 | `PersistenceNormalize.swift:365` `blankingPass` rescan | **a** | Was explicit `false`; a discard here would silently finish a removal recorded as a hold. |
| 7 | `PublicAPI.swift:393` `loadInspection` pages | **a** | Was explicit `false`; display read (D-SSOT-07). |
| 8 | `PublicAPI.swift:409` `loadInspection` cover | **a** | Was explicit `false`; display read. |
| 9 | `DownloadStore.swift:755` `makeFolderRecord` cover | **a** | Was explicit `false`; index scan is the pull-to-refresh route. |
| 10 | `DownloadStore.swift:756` `makeFolderRecord` pages | **a** | Was explicit `false`; same. |
| 11 | `PersistenceHelpers.swift:54` `captureTarget` | **a** | **Reclassified from the plan's ENTITLED candidate.** Resolves the name ONE page may reuse while the scan probes every claimed page; it lowers no hash but its own. |
| 12 | `PublicAPI.swift:338` `performCacheCapture` | **a** | **Reclassified.** Same whole-folder-scan / one-page-reconcile mismatch. |
| 13 | `ExecutionPerform.swift:131` `missingFinalizedPageIndices` | **a** | **Reclassified.** Only NAMES the missing set and then throws; writes and lowers nothing. |
| 14 | `BackgroundDownloads.swift:214` `backgroundPageRelativePath` | **a** | **Reclassified.** Asks which name one landed page may reuse; records a hash only for that page. |
| 15 | `Operations.swift:198` `addingCurrentFileHashes` | **a** | **Reclassified.** The merge fills EMPTY hashes only, so a discard deletes files of pages whose hashes it then leaves standing and finalize succeeds over them. |
| 16 | `Operations.swift:582` `hashReadableAsset` | **a** | **Reclassified.** Both callers throw on refusal and neither lowers the record for the page thrown over. |
| 17 | `Operations.swift:61` `linkOrCopyReadableAsset` guard | **a** | **Reclassified.** Every caller pre-classified this file, or it is the manifest itself; the throw is the answer either way. |
| 18 | `Operations.swift:174` `materializeRepairSeed` copy guard | **a** | **Reclassified.** Fires only on a change since the scan; the page is recorded UNANSWERED, so its hash is deliberately NOT blanked. |
| 19 | `Operations.swift:317` `contentMismatchScan` re-probe | **a** | Was explicit `false`; a disagreement with the presence scan is a race, held not refuted. |
| 20 | `Operations.swift:139` `materializeRepairSeed` cover | **b** | A cover carries no recorded hash, so removal has nothing to diverge from and the run re-fetches it. |
| 21 | `Operations.swift:156` `materializeRepairSeed` source scan | **b** | Refusals become destination-side positive absences that `prepareWorkingSeed` blanks in the same bracket. Cross-referenced to 15-67's ordering conversion. |
| 22 | `ExecutionSupport.swift:338` `prepareWorkingSeed` destination scan | **b** | Same pairing, three statements above the blanking loop that consumes it. Cross-referenced to 15-67. |
| 23 | `ExecutionSupport.swift:369` `prepareWorkingSeed` cover | **b** | Cover terms, as row 20. |
| 24 | `Operations.swift:594` `validatePages`, `Operations.swift:629` `validatePage` | **p** | Carry `DownloadValidationPolicy.discardingRejected`, decided once at `validate`'s boundary. |
| 25 | `DownloadStore.swift:251/327/342/360/532/567/606/821` | **t** | Family pass-throughs: `existingPageRelativePaths`→`pageFileScan`, `imageURLs`→`existingPageRelativePaths`, `localCoverURL`→`existingCoverFileURL`→`existingAssetFileURL`(×2)→`sanitizeAssetFileIfNeeded`→`probeAssetFile`. |

`existingPageFileURL(folderURL:gid:token:index:)` has no production caller (one test) and inherits the flipped default through row 25.

## `resumeMode` (a)/(b) Comment Re-Audit

| Clause | Verdict against post-flip source | Action |
|---|---|---|
| "(a) the blanking loop REFUSED its destructive half … so the manifest came back verbatim" | TRUE — a statement about what the ONE blanking loop wrote; independent of whether this validate deletes. | Kept verbatim. |
| "(b) neither preparation nor validation has blanked anything this session" | TRUE — same basis. | Kept verbatim. |
| "In both, this branch is what still routes the record to `.repair`" | TRUE — the verdict is unchanged by the flip. | Kept verbatim. |
| (unstated) the cost of ASKING | Was a silent falsehood: the question destroyed the files whose absence it reports, on a route that writes no manifest. | Added as a new paragraph naming what the call no longer does. |

## Decisions Made

- **DEC-A: entitlement is a pairing, not a position.** The tempting rule is "run-time and reconciling callers keep discarding", which is roughly the plan's suggested list. It does not survive contact with the sites: `addingCurrentFileHashes` and `captureTarget` are run-time callers whose scans reach pages they never reconcile, and `materializeRepairSeed`'s copy guard is a reconciling function's own guard whose refusals are explicitly non-blanking. Asking instead "does this act blank the record for the page it destroyed?" answers all eighteen non-entitled sites the same way and leaves an ENTITLED set small enough to state in one sentence.
- **DEC-B: the reclassifications had to be verdict-preserving to be safe, and they are.** Every one was checked by reading what the caller does with a rejected page under both flag values; in all eight cases the file is outside `pages` either way, so the returned set, the throw, the fallback name and the resulting record are identical. The full 943-test run is the check on that reading rather than its substitute.
- **DEC-C: redundant `false` arguments were removed rather than left in place.** Keeping them would restate by hand a property that now holds by construction, which is precisely the kind of restatement that goes stale — and it would leave a reader unsure whether the default might still be destructive. Removing them makes `rg 'discardingRejected: true'` the exact inventory of mutators, which is the invariant the acceptance criteria are written against. The prose at each site was rewritten to argue from the default instead of from the argument.
- **DEC-D: `sanitizeLocalFilesIfNeeded` was renamed.** After the sweep's removal it touches no local file, so the name was a flat lie in a codebase whose rule is that a doc must prove the property the function has. `clearStaleDownloadErrorIfNeeded(gid:)` matches the module's `clearDownload*State` vocabulary, drops the `clearingLastError` parameter (whose `false` callers were pure fetches) and reuses `clearDownloadFailureState(gid:includePageFailures: false)` so the cleared set is unchanged.
- **DEC-E: `validate` keeps `discardingRejected` although no production caller passes `true`.** Removing it was considered — a report that can delete is arguably the defect in miniature — but the plan's contract is "no signature is otherwise changed", the parameter keeps the family uniform, and `DownloadValidationPolicy`'s threading (which a future entitled validation would need) stays meaningful. Recorded here so a later round can take the removal deliberately rather than rediscover the question.
- **DEC-F: the replaced entitled-side pin drives the production route.** `testTheRepairSeedStillDiscardsAZeroBytePageAndBlanksIt` goes through `prepareWorkingSeedAnnouncingProgress` and asserts the PAIRING (file gone AND hash blanked AND blanked on disk), not just the deletion — because a case asserting only the deletion would be satisfied by an entitled actor that destroys without reconciling, which is the defect wearing the entitlement's clothes.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Two existing store cases pinned the destructive behaviour**

- **Found during:** Task 2 (GREEN), first full suite run
- **Issue:** `DownloadStoreTests.testValidateRemovesZeroBytePageFilesAndRequiresRepair` asserted that `storage.validate` DELETES a zero-byte page file — the exact read-path mutation CR-03 removes — and `testExistingPageRelativePathsRemovesZeroByteFinalAssetFiles` asserted the deletion on the (now non-mutating) default. Neither file is in the plan's `files_modified`.
- **Fix:** The validate case is inverted rather than dropped: the verdict assertion is kept beside a survival assertion and a new manifest assertion, so it now proves the deletion was never what produced the answer. The scan case is split by intent — the deleting one names `discardingRejected: true` and is renamed to say it pins the OPT-IN, its sibling drops the now-redundant `false` and is renamed to say it pins the DEFAULT, so re-flipping the default fails it.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadStoreTests.swift`
- **Verification:** Both cases green; full suite 943/0.
- **Committed in:** `fc737485` (Task 2 commit)

**2. [Rule 1 - Bug] The obsolete entitled-side pin and its neighbour's entitlement enumeration**

- **Found during:** Task 2 (GREEN), deleting `scanCompletedFolder`
- **Issue:** `DownloadCoordinatorRepairSeedTests.testSanitizingLocalFilesStillDiscardsAZeroBytePage` existed to prove the sweep still deleted, and its own doc said the sweep "exists for this housekeeping and nothing else" — a case pinning the defect. The sibling case's doc enumerated five entitled actors (validate, the repair seed, the finalize merge, the capture target, the sweep) of which four never qualified under DEC-A.
- **Fix:** Replaced with `testTheRepairSeedStillDiscardsAZeroBytePageAndBlanksIt`, which drives the production preparation and asserts the pairing (see DEC-F); the sibling doc's enumeration is corrected to the one actor and states why the other four are reads.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift`
- **Verification:** Both cases green.
- **Committed in:** `fc737485`

**3. [Rule 1 - Bug] `ContentMismatchScan`'s doc was orphaned onto `DownloadValidationPolicy` (review WR-03)**

- **Found during:** Task 2 (GREEN), rewriting `DownloadValidationPolicy`'s `discardingRejected` sentence
- **Issue:** `DownloadValidationPolicy` had been inserted between `ContentMismatchScan`'s doc block and its declaration with no blank line, so the whole block attached to the policy type. The sentence this plan must correct lives inside that block — leaving the seam would have landed the corrected prose on the wrong type.
- **Fix:** `ContentMismatchScan`'s ten doc lines moved back to immediately precede its declaration; `DownloadValidationPolicy` keeps only its own doc, with the `discardingRejected` paragraph re-derived against the flipped default. Scope: this is the block the plan requires editing, not an unrelated sweep.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift`
- **Verification:** Clean build 0 warnings; SwiftLint `--strict` 0 violations.
- **Committed in:** `fc737485`

**4. [Rule 1 - Bug] Three doc/test references to symbols this change renames or falsifies**

- **Found during:** Task 2 (GREEN)
- **Issue:** `DownloadStore.swift:827` claimed "`discardingRejected: false` is what a display path must pass" (a display path now passes nothing); `makeFolderRecord`'s comment listed five entitled actors; `DownloadContinuedSessionLedgerRefusalTests.swift:339` reasons from `sanitizeLocalFilesIfNeeded(gid:clearingLastError:)`, a symbol this plan renames. All three are defects this change creates.
- **Fix:** All three re-derived against post-change source. No claim's substance changed in the ledger-refusal case — it still describes the same gallery-level clearance beside the untouched per-page record.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadStore.swift`, `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift`
- **Verification:** `rg 'sanitizeLocalFilesIfNeeded' AppPackage App ShareExtension` returns only the one intentional historical reference inside the renamed function's own doc.
- **Committed in:** `fc737485`

### Undeclared files modified

Four test files beyond the plan's `files_modified`: `DownloadStoreTests.swift`, `DownloadCoordinatorRepairSeedTests.swift`, `DownloadCoordinatorStorageTests.swift` (rename call site) and `DownloadContinuedSessionLedgerRefusalTests.swift` (stale doc reference). Each is a direct consequence of this change; the first two were hard gates.

---

**Total deviations:** 4 auto-fixed (3 tests pinning or naming the removed behaviour, 1 pre-existing doc seam inside the block this plan must edit)
**Impact on plan:** No behaviour outside the plan's contract changed. The ENTITLED set is smaller than the plan anticipated and the family is wider — both are results of the fresh enumeration and the entitlement test the plan mandates, and both are recorded above rather than assumed.

## Banked Falsifiability

The RED suite failed against pre-fix production with **6 verbatim issues**, two per case:

| Case | Pre-fix (recorded) | Post-fix (expected) |
|---|---|---|
| `testLoadManifestOverAZeroBytePageLeavesTheFileAndTheRecordUntouched` | `fileExists(atPath: …/215661_token_1.jpg)` FAILED — "an ordinary read must leave the file it refused on disk" — then `attributesOfItem` threw `NSCocoaErrorDomain Code=260` | file present, `.typeRegular`, size 0 |
| `testResumeModeOverAZeroBytePageResolvesRepairWithoutDeletingIt` | the same expectation FAILED, then Code=260 for `215662_token_1.jpg` | same |
| `testLoadManifestOverAZeroByteCoverLeavesTheCoverOnDisk` | the same expectation FAILED, then Code=260 for `215663_token_cover.jpg` | same |

The verdict assertions PASSED pre-fix in all three cases — `.fileOperationFailed(pageMissing(1))`, `.repair`, and a successful `loadManifest` respectively — and that is the finding rather than a weak pin: the answers never depended on the deletion, so the deletion was pure damage. A case asserting only the verdict, or only the manifest, would have been green over the defect; the manifest assertions never even ran, because the `attributesOfItem` read of the deleted file aborted each case first.

`testValidateRemovesZeroBytePageFilesAndRequiresRepair` is the same evidence from the other direction: a pre-existing case that passed only because the defect was there, which is why inverting it (rather than deleting it) is what proves the verdict survived the fix.

## Issues Encountered

- **The plan's suggested ENTITLED list would have preserved the defect at six sites.** Taken literally, `captureTarget`, `ExecutionPerform:127`, `BackgroundDownloads:211` and the DownloadStore-internal sites 55/168/541 keep discarding — and every one of them scans the whole folder while reconciling at most one page, so a zero-byte file for an unrelated claimed page is still destroyed by a finalize, a capture or a background landing. The plan anticipated exactly this by instructing that each be "verified against its consumer before classifying"; DEC-A is the verification's result.
- **The fixture manifest records no hashes.** `sampleManifest` writes empty page hashes, so the replacement entitled-side case had to claim both pages explicitly before the blanking assertion could mean anything — otherwise `pages[1] == ""` is true before the run and the pairing is vacuous. Two claimed pages also keep the blank set under the all-or-nothing threshold so the guard authorizes.

## Verification Evidence

Run one `xcodebuild` invocation at a time, with `-destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` substituted for the plan's ambiguous `name=iPhone Air`:

1. Task 1 RED gate — `-only-testing:DownloadsFeatureTests/DownloadReadPathNonMutationTests` — **TEST FAILED**, 3 tests / 6 issues, exactly the three deletions banked above.
2. Task 2 gate — the same invocation after the fix — **TEST SUCCEEDED**, 3 tests in 1 suite.
3. Full `FeatureTests` — **TEST SUCCEEDED**, **943 tests / 0 failures** across 22 targets (baseline 940, +3); downloads target 424 tests in 72 suites (+3, +1 suite). One intermediate run surfaced the single behavioural pin of the old default (deviation 1) and was re-run to green.
4. `xcodebuild -scheme EhPanda -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/EhPandaPhase1566DerivedData build` — **BUILD SUCCEEDED**, **0 warnings, 0 errors** (the SwiftLint build-tool plugin runs in-build, so this is lint-clean over `Sources/`).
5. Standalone SwiftLint `--strict` over `Sources/DownloadClient` and `Tests/DownloadsFeatureTests` (the app scheme does not lint `Tests/`) — **0 violations, 0 serious in 114 files**.

Acceptance greps:

- `rg -n 'discardingRejected: Bool = true' AppPackage/Sources` → no match.
- `rg -n 'discardingRejected: true' AppPackage/Sources` → exactly 4 hits, all in the repair-seed actor, each preceded by a site comment naming its entitlement.
- `rg -n 'scanCompletedFolder' AppPackage App ShareExtension` → no match.
- `rg -n 'sanitizeLocalFilesIfNeeded' AppPackage App ShareExtension` → 1 hit, the deliberate historical note inside the renamed function's own doc.
- Line lengths: no line over 120 in any touched file. File lengths: `DownloadStore.swift` 981, `+ExecutionSupport.swift` 972, `+Operations.swift` 661, `DownloadReadPathNonMutationTests.swift` 270 — all under 1000. `DownloadFeatureTestHelpers.swift` unchanged at 989 (the new suite's helpers are file-private, as the plan requires).
- `git diff --diff-filter=D --name-only HEAD~1 HEAD` → empty on both task commits.
- No `swiftlint:disable`, no `try?`, no force unwrap, no concurrency escape hatch introduced.

## Self-Check: PASSED

- `AppPackage/Tests/DownloadsFeatureTests/DownloadReadPathNonMutationTests.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadStore.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceHelpers.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionPerform.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+BackgroundDownloads.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift` — FOUND
- Commit `cc8175f9` — FOUND
- Commit `fc737485` — FOUND

## Known Stubs

None. No hardcoded empty value, placeholder string or unwired data source was introduced; the one symbol removed (`scanCompletedFolder`) is gone rather than emptied, and the one renamed symbol has live production and test consumers.

## Threat Flags

None. The plan's three registered threats are addressed rather than extended: T-15-66-01 by the family-wide non-mutating defaults plus the four-site entitlement enumeration, T-15-66-02 by the three zero-byte regressions asserting file survival AND unchanged persisted record on a fresh coordinator, T-15-66-03 by leaving the only destroyers as authorized reconciliations that blank in the same act. No new network endpoint, auth path, file-access pattern or schema was introduced; the change removes file-write authority rather than adding any, and `DownloadLogPrivacyInvariantTests` is green with its masked inventory unchanged (no log line was added).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- CR-03 (verification gap 2's read-path half) is closed at the parameter rather than at its callers, and the doc that applied the wrong test is replaced by one that states the corrected rule and why the old one was wrong.
- **15-67 inherits two cross-references, both placed at the sites it will convert:** `DownloadStore+Operations.swift:156` and `DownloadClient+ExecutionSupport.swift:338` each carry a note that the removal currently precedes the blanking it is paired with. WR-01 (the fourth clause shrinking `blankedPageCount` below the wholesale threshold) and WR-02 (`probeAssetFileContent` returning `.rejected(fileRemains: true)` unconditionally) are untouched here and remain 15-67's scope — this plan changed neither the guard's population nor any probe exit.
- Remaining `15-REVIEW.md` blockers untouched and independent: CR-02 (`deleteFolder`'s unconfined caller-supplied name) and the WR-04/WR-05 consequences of the CR-04 narrowing.
- **DEC-E is an open design question, deliberately left:** `validate`'s `discardingRejected` now has no production caller passing `true`. A later round may remove it and make the report unconditionally non-mutating; doing so would also let `DownloadValidationPolicy` collapse back to a single flag.
- Headroom notes carried forward: `DownloadStore.swift` is at 981 of the 1000-line limit and `DownloadClient+ExecutionSupport.swift` at 972 — both effectively closed to further doc growth. `DownloadContinuedSessionTests.swift` (993) and `DownloadFeatureTestHelpers.swift` (989) are unchanged by this plan and keep their standing split-before-next-addition notes.
- Open, non-blocking, carried forward and unchanged here: `DetailReducer.swift:112` names the superseded decision ID D-G5C-01, and `DetailDownloadRepairPredicateTests.swift` lines 13/52 still describe corrupt-in-place as a complete-claiming family member. Both comment-only, both in files this plan did not declare.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-10*
