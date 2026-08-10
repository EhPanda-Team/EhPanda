---
phase: 15-continued-background-downloads
plan: 62
subsystem: downloads
tags: [download-client, manifest-ssot, validation, filesystem, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "D-SSOT-01/02/03/04's evidence classes, the single reconcileWorkingManifestAgainstPageFiles blanking loop, and 15-56's wholesale refusal discipline"
provides:
  - "PageFileScan.rejectedPageRelativePaths: the identity of a refuted page file the scan LEFT on disk"
  - "A non-mutating validation route: every scan validateImageData takes before its guard passes discardingRejected: false"
  - "removeRefutedPageFiles: one post-authorization removal for both the mismatched and the rejected family"
  - "A fourth per-file refusal line on the blanking loop, so a surviving refuted file is never blanked around"
affects: [validate-time reconciliation, repair working-seed preparation, manifest SSOT invariant]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Evidence gathering is non-mutating by construction; the authorization guard is the only thing that converts a classification into an act"
    - "A probe outcome carries whether its own housekeeping deletion left the file behind, so no consumer re-asks the filesystem it is describing"
    - "A set that decides both a guard's population and a mutation's population is derived once and handed to both"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadValidationRejectionArmTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadStore.swift
    - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift

key-decisions:
  - "CR-01: a rejection is a positive determination like any other, so it joins the combined prospective blank set — what was wrong was never WHICH pages it covered but WHEN its file was destroyed"
  - "DEC-A: rejected identity is conditional on the file SURVIVING, which is what keeps every discarding caller byte-for-byte unchanged while protecting the non-discarding one"
  - "DEC-B: the blanking loop gained a fourth per-file refusal line rather than the caller lying to it through unprobedPages"
  - "DEC-C: contentMismatchScan's re-probe is non-discarding too, and a page that changed between the two reads is a HOLD rather than a refutation"
  - "DEC-D: the two validation flags became one DownloadValidationPolicy value, fixing a parameter-count violation at its design root instead of threading a sixth flag"

patterns-established:
  - "Classification-versus-mutation: a read may classify, only an authorized reconciliation may act — and 'read' includes the probe's own housekeeping"
  - "A rebuild of a value type from another instance's parts must thread every member, or it silently re-licenses the act the dropped member withheld"

requirements-completed: []

coverage:
  - id: D1
    description: "A one-page complete manifest beside a zero-byte page refuses wholesale reconciliation with both the file and the manifest byte-for-byte unchanged"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationRejectionArmTests.swift#testAWholesaleZeroBytePageRefusesWithItsFileStillOnDisk"
        status: pass
    human_judgment: false
  - id: D2
    description: "The same refusal holds for the other structural rejection exit, a non-regular page path"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationRejectionArmTests.swift#testAWholesaleNonRegularPageRefusesWithItsPathStillOnDisk"
        status: pass
    human_judgment: false
  - id: D3
    description: "Where the combined set is not wholesale, the refuted file is removed only after authorization and its hash blanked durably through the one existing loop"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationRejectionArmTests.swift#testAnAuthorizedRejectionRemovesOnlyTheRefutedPageAndBlanksItsHash"
        status: pass
    human_judgment: false
  - id: D4
    description: "Every pre-existing missing, mismatch, hold, recovery, no-laundering and store-level rejection behaviour is unchanged"
    verification:
      - kind: unit
        ref: "xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests (929 tests, 0 failures; downloads target 410 in 71 suites)"
        status: pass
    human_judgment: false

# Metrics
duration: 35min
completed: 2026-08-10
status: complete
---

# Phase 15 Plan 62: Non-Mutating Validation Evidence Summary

**CR-01 closed: validation now classifies without touching the filesystem, the combined wholesale guard authorizes absences, rejections and mismatches together, and only then are refuted files removed and their hashes blanked through the one existing loop.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-08-10T00:56Z
- **Completed:** 2026-08-10T01:31Z
- **Tasks:** 2 (RED, GREEN)
- **Files created:** 1
- **Files modified:** 6

## Accomplishments

- **The defect, stated as a property.** The rejection family was the only positive per-page determination the PROBE could make by itself, and the probe deleted what it refused as housekeeping. Validation never opted out, so `storage.validate`'s scan, the reconciliation's presence scan and `blankingPass`' rescan all destroyed zero-byte and non-regular page files while the pass was still deciding. On a one-page complete manifest the combined guard then refused — the prospective set was the whole record — and the pass ended having destroyed the file it had just declined to blank the hash for. The `validationErrors` entry marking that is session-scoped, so a relaunch reads the gallery as `.completed` over a page whose file the app itself deleted: precisely the record/disk divergence the manifest-SSOT rule forbids, created by the defence that exists to prevent it.
- **The fix is an ordering, not a new verdict.** A rejection was already inside the prospective blank set — as a positive absence, because the file was gone by the time anyone looked. What changed is only WHEN: `discardingRejected: false` on every scan above the guard, the rejected pages carried by identity instead of by their own disappearance, one `refutedPages` set derived once for both the guard and the removal, and the removal moved below the guard. With an empty rejection set the whole thing reduces byte for byte to what 15-56 and 15-58 established, which is why their seven cases passed unchanged.
- **`PageFileScan.rejectedPageRelativePaths` means "refuted AND still there", and the conditional is load-bearing.** Recording every rejection unconditionally would have regressed the repair path: a discarding scan whose deletion succeeded leaves a page that genuinely IS a positive absence, and treating it as refuted would have kept a hash for a file that no longer exists — trading this plan's divergence for its mirror image. Membership therefore tracks survival, which is decided by the probe (it alone knows which rejection exits carry a deletion at all — the content-read exit never has — and whether that deletion worked). Every discarding caller is byte for byte unchanged, and a discarding caller whose deletion FAILED now gets the same protection from the other direction.
- **The blanking loop gained a fourth refusal line rather than being lied to.** With a non-mutating rescan, a page whose authorized removal failed is still reported as refuted-and-present; the loop's three existing lines would have blanked it, producing the D-SSOT-04 laundering shape — a blank hash beside bytes `finalizeDownload`'s merge would re-record as truth. Line 2b is the mirror of line 2: not "nothing was established" but "acting on what was established means removing the file, and this loop does not remove files". It is a strengthening, and the loop remains the single hash writer with its `<` guard untouched.
- **Every pre-authorization pass was swept, not just the two the finding named.** The review cited `storage.validate` and the presence scan. Two more mutate on that route: `blankingPass`' rescan (the plan called this one out — a discarding rescan would silently complete a removal the accounting had already recorded as a hold) and `contentMismatchScan`'s per-page `sanitizeAssetFileIfNeeded` re-probe. The re-probe can only disagree with the scan that just yielded the file if the file changed between the two reads, so it is now non-discarding and the page is HELD, with hash and file both intact.
- **The affordance stays reachable in the refusal case.** Both wholesale cases assert `canValidateImageData` after the refusal, so the record that could not be corrected keeps the only sensor that can ask again — the far-side pin 15-59 established for the unprobeable hold, applied to the rejection family.

## Task Commits

Each task was committed atomically:

1. **Task 1: RED — pin refusal-before-deletion for rejected page files** - `156562ea` (test)
2. **Task 2: GREEN — classify first, authorize the combined set, then mutate and persist** - `8490136b` (fix)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadStore.swift` - `PageFileScan.rejectedPageRelativePaths` (member, defaulted init argument, and the doc deriving why membership is conditional on survival); `pageFileScan` records the surviving refused candidate and clears it when a usable candidate supersedes it; `AssetFileProbeOutcome.rejected` carries `fileRemains` and the enum became `Equatable`; `discardRejectedAssetIfPermitted` / `discardRejectedAsset` report whether the file is gone; `probeAssetFileContent`'s EOF exit says `fileRemains: true`; `probeAssetFile`'s doc gained the CR-01 paragraph.
- `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` - new file-private `DownloadValidationPolicy`; `validate` gained `discardingRejected` (defaulted) and threads the policy through `validatePages` and `validatePage`; `contentMismatchScan`'s re-probe is non-discarding and its hold documented; `removeMismatchedPageFiles` → `removeRefutedPageFiles` with `refutedPages` and a merged relative-path map, plus the doc paragraph fusing the two families.
- `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift` - `validateImageData` validates non-discarding; `reconcileValidatedRecordAgainstPageFiles` scans non-discarding, derives `refutedPages` once, guards the combined set, removes after the guard through the merged map, and computes `removedPages` off the refutations; `prospectiveBlankPages` takes `refutedPages` and subtracts the rejected keys from its absent half; `blankingPass` rescans non-discarding; four doc blocks rewritten to state the classification-versus-authorized-mutation boundary.
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` - the blanking loop's fourth per-file guard and its line-2b doc; `prepareWorkingSeed`'s scan rebuild threads `rejectedPageRelativePaths` through.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadValidationRejectionArmTests.swift` - new, 3 cases as an extension of the reconciliation suite, plus the shared refusal-contract helper.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift` - `expectNoBlankHashedPageKeptItsFile` widened from file-private to suite-scoped, with the reason recorded; one doc reference re-pointed at the renamed removal.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift` - one doc reference re-pointed at the renamed removal.

## Decisions Made

- **DEC-A: `rejectedPageRelativePaths` records a refused file only while it SURVIVES.** The alternative — record every rejection — reads simpler and regresses the repair path, because a discarding scan's successful deletion really does leave a positive absence. Conditioning on survival is what makes one member serve both callers: the non-discarding one gets the identity it must act on later, the discarding one gets exactly its historical answer, and a failed housekeeping deletion is protected in both.
- **DEC-B: the blanking loop got a fourth refusal line instead of a caller-side workaround.** The alternative was to fold surviving refuted pages into `unprobedPages` at the call site, which would have kept `DownloadClient+ExecutionSupport.swift` untouched at the price of calling a determination a non-answer and adding one more inventory that must stay exhaustive — the failure mode this phase has lost rounds to. The line is a strengthening: it cannot blank MORE than before, and it closes the same laundering shape for the repair path's own failed discards.
- **DEC-C: a page that changed between the presence scan and the content pass is HELD, not refuted.** The two reads can only disagree about a race, and a race is the weakest evidence in the building. The hold keeps the hash and the file and leaves the next validate to classify from a settled disk.
- **DEC-D: the two validation flags became one `DownloadValidationPolicy` value.** Threading a sixth parameter tripped `function_parameter_count`, and the right answer to that warning was not a longer signature but the observation that the flags are one decision made once at the public boundary: how deeply the pass may READ, and whether it may WRITE at all. Suppressing the rule was not an option and was not considered.
- **DEC-E: the new cases are an `extension` of the reconciliation suite in a second file.** `DownloadValidationReconciliationTests.swift` sat at 803 lines and the three cases would have pushed it past the 1000-line error threshold. The repo's existing answer to that is a same-suite extension in a sibling file (`DownloadContinuedSessionRunProofTests`), which also keeps the plan's `-only-testing` gate closed over the new cases, since that flag filters by suite.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] The blanking loop would blank a page whose authorized removal failed**

- **Found during:** Task 2 (GREEN), while making `blankingPass` non-mutating as the plan instructs
- **Issue:** The plan requires that "removal failures join the held set and retain their hashes". With a non-mutating rescan, a page whose refuted file survived is reported as refuted-and-present, and the loop's three existing refusal lines do not cover that shape — it is neither yielded nor unprobed — so the hash would have been blanked beside a surviving file. That is the D-SSOT-04 laundering shape, one repair away from `finalizeDownload`'s merge recording the refuted bytes as truth. `DownloadClient+ExecutionSupport.swift` is named in the plan's `read_first` and `key_links` but not in `files_modified`.
- **Fix:** One additional guard clause on the loop (`pageFileScan.rejectedPageRelativePaths[page] == nil`) with a line-2b doc paragraph, and the `prepareWorkingSeed` scan rebuild threading `rejectedPageRelativePaths` through so the new member is not silently dropped where a scan is reconstructed from another's parts.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift`
- **Verification:** The loop is still the sole declaration (`grep -c 'func reconcileWorkingManifestAgainstPageFiles' AppPackage/Sources/DownloadClient` → 1); the guard can only reduce `blankedPageCount`, so no refusal was weakened; the repair-path suites and the full 929-test run are green.
- **Committed in:** `8490136b` (Task 2 commit)

**2. [Rule 2 - Missing critical functionality] `contentMismatchScan`'s per-page re-probe still mutated before the guard**

- **Found during:** Task 2 (GREEN), sweeping every pass validation takes before authorization rather than only the two the finding named
- **Issue:** The plan's behaviour spec is "every scan performed by `validateImageData` before authorization uses `discardingRejected: false`". `contentMismatchScan` re-probes each yielded page through `sanitizeAssetFileIfNeeded` at the discarding default, so a file that became zero-byte between the presence scan and the content pass would be deleted pre-guard — the same defect at a narrower window.
- **Fix:** The re-probe is non-discarding; such a page lands in `held`, keeping its hash and its file, with the reasoning recorded at the site and on `ContentMismatchScan.held`.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift`
- **Verification:** `grep -n 'discardingRejected: false' AppPackage/Sources/DownloadClient` shows all four validation-route call sites; the hold and mismatch cases are unchanged and green.

**3. [Rule 3 - Blocking issue] A sixth parameter on `validatePage` tripped `function_parameter_count`**

- **Found during:** Task 2 (GREEN), first targeted test run
- **Issue:** Threading `discardingRejected` beside `verifiesContentHash` produced a build warning, and the project's standard is a warning-free build with no suppression permitted.
- **Fix:** Introduced the file-private `DownloadValidationPolicy` and passed it in place of both flags, which also removes the parameter from `validatePages`.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift`
- **Verification:** Clean app-scheme build with 0 warnings; standalone SwiftLint `--strict` reports 0 violations.

**4. [Rule 1 - Bug] Two test doc comments named the renamed removal**

- **Found during:** Task 2 (GREEN)
- **Issue:** `DownloadValidationReconciliationTests.swift:387` and `DownloadFeatureTestSupportTypes.swift:501` both reason from `removeMismatchedPageFiles`, a symbol this plan renames — a documentation defect introduced BY this change.
- **Fix:** Both re-pointed at `removeRefutedPageFiles`. No claim in either sentence changed; both still describe the post-removal window and the injection that stages it.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift`, `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift`
- **Verification:** `grep -rn 'removeMismatchedPageFiles' AppPackage` returns nothing.

### Undeclared file created

`AppPackage/Tests/DownloadsFeatureTests/DownloadValidationRejectionArmTests.swift` is not in the plan's `files_modified`. It exists for a file-length reason recorded as DEC-E, it is an extension of the declared suite rather than a new suite, and it is therefore inside the plan's own `-only-testing` gate. The declared test file was still modified, for the visibility widening the split required and for deviation 4.

---

**Total deviations:** 4 auto-fixed (2 critical-functionality sweeps, 1 lint-root refactor, 1 stale symbol reference this change created) plus 1 undeclared test file
**Impact on plan:** No behaviour outside the plan's contract changed. Deviations 1 and 2 close the same defect class the plan is about, on exit paths the finding did not enumerate.

## Banked Falsifiability

The RED cases failed against pre-fix production with **4 verbatim issues**, two per refusal case:

| Site | Pre-fix (recorded) | Post-fix (expected) |
|---|---|---|
| `DownloadValidationRejectionArmTests.swift` — zero-byte arm | `#expect` "a refusing validate must leave the rejected page file on disk" FAILED, then `attributesOfItem` threw `NSCocoaErrorDomain Code=260 "The file '215612_token_1.jpg' couldn't be opened because there is no such file."` | file present, `.typeRegular`, size 0 |
| `DownloadValidationRejectionArmTests.swift` — non-regular arm | the same expectation FAILED, then `attributesOfItem` threw Code=260 for `215613_token_1.jpg` | path present, `.typeDirectory` |

The manifest assertions in both cases PASSED pre-fix, and that is the finding rather than a weak pin: the guard really did refuse to write, so the record was preserved exactly as designed — what the guard could not undo was the deletion its own evidence gathering had already performed. A manifest-only case would have been green over the defect.

The authorized-partial case PASSED pre-fix, as anticipated: the pre-fix probe deleted the zero-byte file and the ordinary presence arm then blanked the page, reaching the same end state by an unsafe route. It is the positive boundary — it refuses a fix that stops correcting rejections altogether — not the discriminator.

## Issues Encountered

- **The obvious shape of the fix would have regressed the repair path.** Recording every rejection in `rejectedPageRelativePaths` and skipping those pages in the blanking loop protects the validate route and breaks the repair route, where the discarding scan's successful deletion means the page really is absent and its hash must go. Resolved by DEC-A: membership tracks whether the file survived, which makes one member correct for both routes and leaves every existing caller unchanged.
- **The plan's own instruction created the case the loop could not express.** Making `blankingPass` non-mutating is what surfaces a surviving refuted file to the loop at all; before, the rescan's discard hid it. The instruction is right — a discarding rescan silently completes a removal the accounting recorded as a hold — but it cannot be adopted without teaching the loop the new shape, which is deviation 1.

## Verification Evidence

Run one xcodebuild invocation at a time, `-destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` substituted for the plan's ambiguous `name=iPhone Air`:

1. Task 1 RED gate — `-only-testing:DownloadsFeatureTests/DownloadValidationReconciliationTests` — **TEST FAILED**, 13 tests, 4 issues, exactly the two new refusal cases.
2. Task 2 gate — `-only-testing:…/DownloadValidationReconciliationTests -only-testing:…/DownloadStoreTests` — **TEST SUCCEEDED**, 35 tests in 2 suites, 0 warnings.
3. Full `FeatureTests` — **TEST SUCCEEDED**, **929 tests / 0 failures** across all targets (926 baseline + 3); downloads target 410 tests in 71 suites (+3). Zero `warning:` lines in the whole run.
4. `xcodebuild -scheme EhPanda -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/EhPandaPhase1562DerivedData build` — **BUILD SUCCEEDED**, **0 warnings** (the SwiftLint build-tool plugin runs in-build, so this is lint-clean over `Sources/`).
5. Standalone SwiftLint `--strict` over all 7 touched Swift files (the app scheme does not lint `Tests/`) — **0 violations, 0 serious**.

Acceptance greps:

- `grep -rn 'func reconcileWorkingManifestAgainstPageFiles' AppPackage/Sources/DownloadClient` → exactly 1 declaration.
- `grep -rn 'discardingRejected: false' AppPackage/Sources/DownloadClient` → 4 call sites on the validation route (`storage.validate`, the presence scan, `blankingPass`' rescan, `contentMismatchScan`'s re-probe), plus the 2 pre-existing display-path sites and the 2 index-scan sites.
- `grep -rn 'removeMismatchedPageFiles' AppPackage` → no hit.
- `git diff --diff-filter=D --name-only HEAD~1 HEAD` → empty on both task commits.

## Self-Check: PASSED

- `AppPackage/Tests/DownloadsFeatureTests/DownloadValidationRejectionArmTests.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadStore.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — FOUND
- Commit `156562ea` — FOUND
- Commit `8490136b` — FOUND

## Known Stubs

None. No hardcoded empty value, placeholder string or unwired data source was introduced; every symbol this plan declared has a live production consumer.

## Threat Flags

None. The plan's three registered threats are addressed rather than extended: T-15-62-01 by the non-mutating gathering and post-guard removal, T-15-62-02 by the two wholesale refusal cases, and T-15-62-03 by adding no log line anywhere (`DownloadLogPrivacyInvariantTests` is green in the full run, its masked inventory unchanged). No new network endpoint, auth path, file-access pattern or schema was introduced; the one filesystem write path added is a removal already confined by `validatedChildURL`.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- CR-01 is closed at its root. The remaining `15-REVIEW.md` blockers — CR-03 (folder-rename source traversal) and CR-04 (unvalidated page selection widening into a whole-gallery repair) — are independent and untouched by this plan. CR-02 closed in 15-61.
- The two non-validation `storage.validate` callers (`loadManifest`'s readability check, `resumeMode`'s repair-versus-redownload question) deliberately keep the discarding default, per the plan. Neither feeds a destructive decision today; a third caller would need that audit re-run rather than extended.
- Open, non-blocking, carried forward and unchanged here: `DetailReducer.swift:112` names the superseded decision ID D-G5C-01, and `DetailDownloadRepairPredicateTests.swift` lines 13/52 still describe corrupt-in-place as a complete-claiming family member. Both comment-only, both in files this plan did not declare.
- `DownloadFeatureTestHelpers.swift` remains at 976 of the 1000-line limit; this plan added nothing there, reusing `SessionGallery`, `makeQueuedCoordinator`, `galleryFolderURL`, `pageFileURL`, `writePageFiles` and `recordRealPageHashes` unchanged. `DownloadValidationReconciliationTests.swift` is now at 810 and its rejection arm lives next door.
- No new census entry is owed: `DownloadSourceInventoryTests`' eight tables cover scheduling blocks, floor writers, bracket callers, queue entrances, schedulable reads, pending-list evaluations, run-proof sites and client-double sites, and none of them counts scan members, probe outcomes or removal operations. Verified by inspection rather than assumed, and the full run is green.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-10*
