---
phase: 15-continued-background-downloads
plan: 71
subsystem: downloads
tags: [download-manifest, ssot, repair-seed, entitlement-census, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-66's non-mutating default for `discardingRejected` and the entitlement rule this plan enforces at the one site 15-66 left `true`"
  - phase: 15-continued-background-downloads
    provides: "15-67's classify-authorize-remove ordering at the destination scan, which is what records the absence the source scan no longer deletes for"
provides:
  - "materializeRepairSeed's source page scan reads without deleting — no act on the repair-seed route destroys a file inside the gallery's currently indexed folder"
  - "A per-site entitlement verdict for every surviving `discardingRejected: true` production site"
  - "DownloadSourceInventoryTests.testDiscardingRejectedSitesMatchTheEntitlementCensus — the entitlement rule as a censused invariant"
  - "An interrupted repair-with-rename regression over an all-refused source, asserting source record/disk agreement and index-winner truthfulness"
affects: [download-repair, manifest-reconciliation, verification-round-20]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Destructive-read entitlement census: a source-derived per-file table whose failure message states the rule the next editor must apply before moving the table"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
    - AppPackage/Sources/DownloadClient/DownloadStore.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift

key-decisions:
  - "Took the review's non-mutating arm at the source page scan rather than reconciling the source manifest: the destination's own reconciliation already records what the scan refuses, and the alternative would give the seed route a second manifest writer for a folder it is about to supersede."
  - "Accepted the orphan zero-byte source file as the cost, cited to IN-03's already-recorded unswept population rather than re-derived or silently absorbed."
  - "Scoped the entitlement census to the client module, matching every other production census here, and stated in its doc that the module-locality of the flag's callers is a claim the table cannot itself enforce."
  - "Wrote the index-winner assertion as the second half of a conjunction rather than as an independent property, and said so: it discriminates exactly when the source wins the mtime arbitration, and is vacuous once the deleted set is empty."

patterns-established:
  - "Entitlement census: when a rule is applied per site in comments, pin the population with a table whose failure message states the rule verbatim and names what a new site must prove before joining."
  - "Probe a new census by temporarily reintroducing the violating site and confirming BOTH halves (per-file table and joined total) fail — a census is only owned once its failure has been observed."

requirements-completed: []

coverage:
  - id: D1
    description: "materializeRepairSeed's source page scan no longer deletes: after an interrupted repair-with-rename over an all-refused source, the source manifest and its page files agree"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift#testAnInterruptedRepairWithRenameKeepsTheSourceRecordAndItsFilesInAgreement"
        status: pass
    human_judgment: false
  - id: D2
    description: "Whichever folder deduplicatedDownloadIndex selects after the interrupted repair is not a folder claiming a page the app deleted, read back through a rebuilt coordinator"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift#testAnInterruptedRepairWithRenameKeepsTheSourceRecordAndItsFilesInAgreement"
        status: pass
    human_judgment: false
  - id: D3
    description: "The entitlement rule is a censused invariant: exactly two production `discardingRejected: true` sites, both covers, each with a recorded verdict; a third fails the build"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift#testDiscardingRejectedSitesMatchTheEntitlementCensus"
        status: pass
      - kind: other
        ref: "Temporary third-site probe: reintroduced `discardingRejected: true` at the source scan; census failed on both the per-file table and the joined total, then reverted"
        status: pass
    human_judgment: false

# Metrics
duration: 22min
completed: 2026-08-10
status: complete
---

# Phase 15 Plan 71: Repair-Seed Source Scan Entitlement Summary

**The repair seed's source page scan now reads instead of deleting, and the entitlement rule that convicted it is enforced by a source-derived census rather than by a comment at each site.**

## Performance

- **Duration:** 22 min
- **Started:** 2026-08-10T12:18:00Z
- **Completed:** 2026-08-10T12:40:27Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Closed verification gap 2 / review WR-02 at its root: `materializeRepairSeed`'s source page scan takes the non-mutating default, so the seed route no longer deletes page files inside the gallery's currently indexed folder while blanking only the destination's copy.
- Pinned the defect with an interrupted repair-with-rename regression over an all-refused source. All three of its assertions failed pre-fix, **including the index-winner half** — the source folder really did win `deduplicatedDownloadIndex`'s `displayDate` arbitration with its lie standing, exactly as the review predicted from the mtime ordering.
- Turned the entitlement rule into a censused invariant: `testDiscardingRejectedSitesMatchTheEntitlementCensus` derives the opt-in population from source and fails, with the rule stated verbatim, if a third site appears.
- Re-derived every `discardingRejected: true` site independently and recorded a per-site verdict (below), then corrected the two source docs whose inventories this change falsified.

## Task Commits

1. **Task 1: RED — stage the interrupted repair-with-rename divergence** — `7755141a` (test)
2. **Task 2: GREEN — non-mutating source scan, per-site verdicts, entitlement census** — `d118fa26` (fix)

## Per-site entitlement verdicts (derived from source, not copied)

I re-derived the population myself rather than taking the plan's or the review's list, since the counts have disagreed twice this phase (15-66's summary said four, the review re-derived three, the verifier confirmed three).

`grep -rn "discardingRejected: true" AppPackage/Sources` before this plan returned **three executable sites** plus one doc-comment mention:

| Site | File:line (pre-fix) | Record claiming the page it would destroy | Act that durably blanks that record | Verdict |
|---|---|---|---|---|
| Repair-seed cover scan | `DownloadStore+Operations.swift:142` | none — a cover carries no recorded hash | n/a | **ENTITLED**, kept |
| Repair-seed SOURCE page scan | `DownloadStore+Operations.swift:171` | the SOURCE folder's own manifest — `repairSeed` returns `download.folderURL`, the currently indexed folder | none on this route; the reconciliation blanks the DESTINATION's copy, a different record | **NOT ENTITLED**, converted to the non-mutating default |
| Working-folder cover resolution | `DownloadClient+ExecutionSupport.swift:384` | none — a cover carries no recorded hash | n/a | **ENTITLED**, kept |

(The fourth grep hit, `DownloadClient+ExecutionSupport.swift:336`, is a doc comment describing the site 15-67 already converted; the census's comment filter excludes it, and I confirmed that by observing the census's count rather than assuming it.)

After the change the module holds exactly **two** executable sites, both covers, and both carry their verdict in place.

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` — the source page scan drops its `discardingRejected: true` argument; the comment block that used to concede the open question now records the refusal of entitlement, why the non-mutating arm is the correct one, and the accepted cost.
- `AppPackage/Sources/DownloadClient/DownloadStore.swift` — `probeAssetFile`'s doc re-derived to two entitled sites, both covers, with a pointer to the census; `galleryFolderRecord`'s doc no longer names a source scan that discards.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift` — the interrupted repair-with-rename regression plus two local staging helpers (kept here, not in `DownloadFeatureTestHelpers.swift`, which is at 992/1000).
- `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift` — the entitlement census, its fragment-assembled token, and a header count corrected from "Five" to "Eight" client-module censuses.

## Decisions Made

- **Non-mutating arm over source reconciliation.** The plan's arm was taken as written. Reconciling `sourceFolderURL`'s manifest here would make the seed route a second durable writer for a folder it is about to supersede, and the destination's reconciliation already records the absence of every page the copy does not land.
- **The accepted cost is recorded, not absorbed.** When the run does not complete, the refused source file survives as an orphan zero-byte file. That is IN-03's already-known unswept population and is **not** in this round's scope; it is written down here the way 15-66 wrote down the site this plan closes.
- **The index-winner assertion is honest about its own shape.** It is the first assertion's consequence, discriminating exactly when the source wins the arbitration; the case doc says so rather than presenting it as an independent invariant.

## Verification

Run one xcodebuild invocation at a time, per the machine's constraint.

1. `-only-testing:` the two suites — **19 tests, 0 failures**.
2. Full `FeatureTests` — **954 tests across 22 targets, 0 failures** (the 15-70 baseline of 952 plus this plan's two new cases). `** TEST SUCCEEDED **`.
3. Clean app build into a fresh derived-data path — `** BUILD SUCCEEDED **`, zero warnings, zero errors.
4. SwiftLint run **directly** over the four changed files against the root config (not inferred from the build, because the app scheme's lint gate does not cover `Tests/`) — zero violations.
5. `rg -n 'this round did not answer' AppPackage/Sources` → no matches.

**Pre-fix RED evidence, banked before the fix:**

```
DownloadCoordinatorRepairSeedTests.swift:303: (deletedSourcePages.sorted() → [1, 2, 3]) == []
DownloadCoordinatorRepairSeedTests.swift:304: (sourceClaimedPages.intersection(deletedSourcePages) → [2, 1, 3]) == []
DownloadCoordinatorRepairSeedTests.swift:318: (winnerClaimedPages.intersection(deletedPagesInWinner) → [1, 3, 2]) == []
```

All three zero-byte page files were deleted while the source manifest still claimed all three, and the source folder won the index carrying that claim. The other seven cases in the suite stayed green throughout.

**Census probe (the check that the census is owned rather than merely written):** I temporarily reintroduced `discardingRejected: true` at the source scan and re-ran the inventory suite. It failed on **both** halves — the per-file table (`Operations.swift: 2`) and the joined total (3 ≠ 2) — printing the entitlement rule in its message. The probe was then reverted and the site count re-confirmed at two.

## Claims and their standing

Two rounds running, an executor's load-bearing structural claim was refuted on review, so each claim here is labelled with what backs it.

- **"A third `discardingRejected: true` site cannot ship silently."** *Enforced by test, within its stated scope* — observed failing under the probe above. Scope: the census counts executable lines under `AppPackage/Sources/DownloadClient`. A caller in another module would not be counted; the census's own doc states this as a claim it cannot enforce rather than leaving it implied.
- **"Both surviving sites are entitled."** *Derived, not enforced.* The census pins the population; the ENTITLEMENT of each member is an argument in a doc comment, and no test can check it. What the census guarantees is that the argument must be made before the table moves.
- **"The app no longer deletes a page file without reconciling the record that claims it."** *Test-backed for this route.* The regression pins the repair-seed route; the census pins that no other production site opts in.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Two source docs falsified by the change were corrected**
- **Found during:** Task 2
- **Issue:** `DownloadStore.swift`'s `probeAssetFile` doc named "three sites" including the source scan, and `galleryFolderRecord`'s doc described a "SOURCE folder scan whose refusals reach the destination". Both would have become false the moment the argument was deleted — this phase's recorded generator of repeat findings is precisely load-bearing prose drifting out of agreement with source.
- **Fix:** Re-derived both from source: two entitled sites, both covers, with the source scan's conversion and its reason recorded, and a pointer to the new census.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadStore.swift`
- **Verification:** Clean build; `grep -rn "discardingRejected: true" AppPackage/Sources` agrees with the doc.
- **Committed in:** `d118fa26`

**2. [Rule 1 - Bug] `DownloadSourceInventoryTests`' header said "Five censuses count the client module alone"**
- **Found during:** Task 2
- **Issue:** Seven censuses already scoped through `clientModuleFiles(in:)`, so the number was stale before this plan and would have been stale by two after it. Leaving a number that my own change falsifies is the exact failure this suite exists to prevent.
- **Fix:** Counted the scoping call sites and corrected the clause to "Eight".
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift`
- **Verification:** `grep -n "clientModuleFiles(in: files)"` → eight call sites.
- **Committed in:** `d118fa26`
- **Deliberately NOT touched:** lines 27 and 65-72 of the same header, which name `downloadsTestFiles(in:)` and are gap 5(b) / WR-06, owned by plan 15-74. Correcting them here would collide with that plan's re-derivation.

---

**Total deviations:** 2 auto-fixed (1 missing-critical doc correction, 1 stale-count bug)
**Impact on plan:** Both are doc-truth corrections the change itself forced. No scope creep; no behaviour beyond the plan's single argument deletion.

## Issues Encountered

None. The plan's staging was reachable through the suite's existing production entry point (`testingPrepareWorkingSeedAnnouncingProgress`), and its existing three-page repair payload supplied the rename shape without a new payload factory, because its title differs from the folder title the new fixture stages.

## Known residuals (recorded, not fixed)

- **Orphan zero-byte source file (IN-03).** The refused source file now survives. `removeSupersededFolders` deletes the whole source folder at completion, so it persists only on a run that does not complete — the already-known unswept population, accepted here by the plan's own threat register (`T-15-71-03`).
- **The source record can still over-claim over externally-refuted bytes.** A page whose file was truncated outside the app remains claimed by the source manifest. The app is no longer the AUTHOR of that divergence — it neither creates nor widens it — and on the all-refused shape the established wholesale guard would refuse to reconcile it in any case. Closing it would require giving the seed route a source-side reconciliation, which this round deliberately did not take.
- **`DownloadSourceInventoryTests.swift` is now 987/1000 lines.** Under the error limit but with 13 lines of headroom. 15-74 will delete `downloadsTestFiles(in:)` from it; a later addition should expect to split by pure move.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Verification gap 2 (SC3's record-convergence half) and review WR-02 are closed at their root, with both the regression and the censused invariant the gap's `missing:` bullets asked for.
- Gaps 1, 3, 4 and 5 remain with their own plans; nothing here touches them.
- The census is available for the next round to extend: any new destructive read must state its record and its blanking act before joining the table.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-10*

## Self-Check: PASSED

All modified files present on disk; all three task commits (`7755141a`, `d118fa26`, `6ac9e76f`) present in git history.
