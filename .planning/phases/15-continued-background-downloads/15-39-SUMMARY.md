---
phase: 15-continued-background-downloads
plan: 39
subsystem: downloads
tags: [swift, downloads, repair-seed, page-file-scan, probe-classification, swift-testing]

requires:
  - phase: 15-continued-background-downloads
    provides: "D-G13-01's per-file refusal in reconcileWorkingManifestAgainstPageFiles (plan 15-33), and D-G7-01's delta-keyed withdrawal bracket in prepareWorkingSeed"
provides:
  - "materializeRepairSeed selects through the full source PageFileScan and returns the claimed pages whose SOURCE-side classification was a non-answer"
  - "setupWorkingFolder returns that set (empty on every non-materialization path); prepareWorkingSeed unions it into the destination scan's unprobedPages before the reconciliation"
  - "Route rule stated in the docs the defect hid behind: collapsing a scan's pairs is licensed only when the answer can never feed a destructive decision, in this folder or any other"
  - "DownloadRepairSeedSignalPropagationTests: the crossed regression (per-file probe failure x title-change re-slot) and its genuine-absence companion"
affects: [15-40, 15-41, continued-background-downloads verification, SC3]

tech-stack:
  added: []
  patterns:
    - "Classification-carrying across a folder boundary: a probe answer that decides another folder's contents travels with the copy instead of being re-derived there"
    - "Crossed regression staging: two existing single-branch stagings combined in a new file rather than extended in either"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadRepairSeedSignalPropagationTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadStore.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadStoreRepairTests.swift

key-decisions:
  - "15-39: The pre-copy guard's disagreement is carried, not thrown: a scan-selected page the copy skips joins the returned set rather than failing the whole preparation."
  - "15-39: The cover copy keeps its plain Bool sanitize guard — it carries no per-page recorded hash, so it is outside the signal's blast radius."
  - "15-39: prepareWorkingSeed constructs the reconciliation scan via PageFileScan's memberwise initializer; `pages` and `scanSucceeded` pass through untouched so an uncopied page is re-fetched, never reused."
  - "15-39: The new suite stages its own batched permissions restore rather than promoting the basis suite's file-private single-URL restorer, keeping DownloadContinuedSessionBasisTests.swift byte-unchanged at 996 lines."

patterns-established:
  - "Route-scoped licensing: PageFileScan's collapse permission is a property of the whole consumer ROUTE, not of the individual call"
  - "Carried non-answers union into the destination scan inside the existing D-G7-01 bracket — no new refusal mechanism, no new suspension"

requirements-completed: [SC3]

coverage:
  - id: D1
    description: "An unprobeable SOURCE page is never blanked at the DESTINATION across the repair-seed copy: no hash blanked, no updateDownloadIndex republish, no floor withdrawal"
    requirement: SC3
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRepairSeedSignalPropagationTests.swift#testAnUnprobeableSourcePageIsNeverBlankedAcrossTheSeedCopy"
        status: pass
    human_judgment: false
  - id: D2
    description: "A genuinely absent SOURCE page is still blanked at the destination, the record republished at the honest lowered count and the pushed pair moved by exactly the counted movement"
    requirement: SC3
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRepairSeedSignalPropagationTests.swift#testAGenuinelyAbsentSourcePageIsStillBlankedAcrossTheSeedCopy"
        status: pass
    human_judgment: false
  - id: D3
    description: "materializeRepairSeed's existing call sites consume the returned set and assert it empty for their fully-probeable stagings; the traversal rejection still measured by containment"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadStoreRepairTests.swift#testMaterializeRepairSeedCopiesOnlyManifestCoverAndExistingPageFiles, #testMaterializeRepairSeedRejectsTraversalPathsInManifestPages"
        status: pass
    human_judgment: false
  - id: D4
    description: "On a physical iOS 26 device, a .repair gallery re-slotted to a new folder whose source pages are transiently unreadable climbs its card without stepping backwards by a laundered blank count"
    verification: []
    human_judgment: true
    rationale: "Backstop truth in the plan's must_haves — a transient per-file probe failure on real hardware cannot be staged by the simulator suite; recorded, not claimed by this plan."

duration: 25min
completed: 2026-08-05
status: complete
---

# Phase 15 Plan 39: Carry the source scan's non-answers across the repair-seed copy Summary

**`materializeRepairSeed` now selects through the full source `PageFileScan` and hands its unanswered pages back through `setupWorkingFolder` into the destination scan's `unprobedPages`, so a per-file probe non-answer in one folder can no longer be laundered into a positive absence that destroys recorded content hashes in another.**

## Performance

- **Duration:** 25 min
- **Started:** 2026-08-05T12:17:00Z
- **Completed:** 2026-08-05T12:42:35Z
- **Tasks:** 2
- **Files modified:** 5 (1 created, 4 modified)

## Accomplishments

- Closed blocker **G-15-19 (SC3)** at the SIGNAL across its whole route rather than inside one function: the source scan's classification travels with the copy, and the existing D-G13-01 refusal line covers the carried population with no new refusal mechanism, no new suspension and no change to `reconcileWorkingManifestAgainstPageFiles`' executable lines.
- Staged the **crossed regression** neither existing suite reached — per-file probe failure (`PartialProbeFailureFileManager` + real `0o000` modes) combined with the title-change re-slot that routes `setupWorkingFolder` into the materialization branch — observed honestly RED, then flipped green by the fix with its assertions unchanged.
- Kept **genuine absence fully blankable** across the same branch: the companion case never moved.
- Corrected the four doc sentences the defect hid behind, and re-derived the consumer census by grep at execution time rather than importing the verification's.

## Task Commits

1. **Task 1: Stage the crossed regression and its genuine-absence companion, RED-first** — `29b6c5a0` (test)
2. **Task 2: Carry the source scan's non-answers across the copy, correct the route docs, re-derive the sweep** — `dc84d193` (fix)

## Files Created/Modified

- `AppPackage/Tests/DownloadsFeatureTests/DownloadRepairSeedSignalPropagationTests.swift` — **created.** The crossed regression and its genuine-absence companion, both driving the production seed route with production-issued pushes only.
- `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` — `materializeRepairSeed(from:manifest:to:)` now returns `Set<Int>` and selects through `pageFileScan` instead of `existingPageRelativePaths`.
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — `setupWorkingFolder` returns the carried set; `prepareWorkingSeed` unions it into the destination scan; the reconciliation doc's seed-route sentence and line-2 population description corrected.
- `AppPackage/Sources/DownloadClient/DownloadStore.swift` — `PageFileScan`'s licensing paragraph and `existingPageRelativePaths`' caller rule carry the route qualifier.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadStoreRepairTests.swift` — both direct `materializeRepairSeed` call sites bind the returned set and assert it empty.

## The RED readings and the green flip

Task 1's targeted run (`-only-testing:DownloadsFeatureTests/DownloadRepairSeedSignalPropagationTests`) failed with 6 issues, all in the crossed case; the companion passed in the same run. The observed readings are exactly the chain the verification traced — three recorded hashes destroyed at the destination, the record republished at 1-of-6, and the floor withdrawn by 3:

```
:161 Expectation failed: await manager.fetchDownload(gid: laundered.gid)?.completedPageCount == 4
:168 (destinationManifest.pages → [1: "sha256:done", 5: "", 2: "", 4: "", 6: "", 3: ""])
     == (stagedManifest.pages → [3: "sha256:done", 2: "sha256:done", 4: "sha256:done",
                                 1: "sha256:done", 6: "", 5: ""])
:169 (destinationManifest.completedPageCount → 1) == 4
:170 (destinationManifest.pages.filter({ !$0.value.isEmpty }).keys.sorted() → [1]) == [1, 2, 3, 4]
:177 (refusalPair.completedUnitCount → 1) == 4
:179 (refusalPair.subtitle → "1 / 6 pages · 1 gallery") == "4 / 6 pages · 1 gallery"
```

Note which assertion did NOT fail: `seed.existingPages.keys.sorted() == [1]` was green before the fix and after it. The copy's behaviour is unchanged — only the classification that reaches the destination reconciliation is. That is the fix's whole shape.

After Task 2, the same targeted invocation reports both cases green, alongside `DownloadStoreRepairTests` (3/3) and `DownloadCoordinatorRepairSeedTests` (6/6): `Test run with 11 tests in 3 suites passed`. The full `FeatureTests` plan then passed in one invocation: `** TEST SUCCEEDED ** [91.834 sec]`.

## Consumer sweep, re-derived at execution time

Grepped `AppPackage/Sources` for `existingPageRelativePaths(`, `pageFileScan(` and `sanitizeAssetFileIfNeeded(`. Each site is dispositioned against the question **"can its output become the INPUT of something that blanks recorded state, in a different folder?"**

| # | Site (post-fix) | Enclosing consumer | Can its answer reach a blanking decision? | Disposition |
|---|---|---|---|---|
| 1 | `DownloadStore.swift:263` | `imageURLs` | No — builds URLs for reading | Non-destructive |
| 2 | `DownloadStore.swift:213` | `existingPageRelativePaths` (the collapse itself) | Only via its callers, all listed here | Forward |
| 3 | `+PersistenceHelpers.swift:32` | `scanCompletedFolder` | No — result discarded (`_ =`); the call exists for its sanitize side effect | Non-destructive |
| 4 | `+PersistenceHelpers.swift:55` | `captureTarget` | No — supplies a preferred relative path for a capture | Non-destructive |
| 5 | `DownloadStore+Operations.swift:124` | `addingCurrentFileHashes` | No — **throws** `downloadStorePageMissing` on a non-answer; a failed, recoverable download | Non-destructive |
| 6 | `DownloadStore+Operations.swift:272` | `validPageCount` | No — reports a count | Non-destructive |
| 7 | `DownloadStore+Operations.swift:308` | `validatePages` → `validatePage` | No — reports `.missingFiles`, which resolves a re-fetch | Non-destructive |
| 8 | `+BackgroundDownloads.swift:211` | `backgroundPageRelativePath` | No — reuses an existing name or derives a new one | Non-destructive |
| 9 | `+PublicAPI.swift:311` | `performCacheCapture` | No — cache restore | Non-destructive |
| 10 | `+PublicAPI.swift:354` | `loadInspection` | No — inspector presentation | Non-destructive |
| 11 | `+ExecutionPerform.swift:128` | `missingFinalizedPageIndices` | No — selects pages to re-fetch | Non-destructive |
| 12 | `+ExecutionSupport.swift:320` | `prepareWorkingSeed` → `reconcileWorkingManifestAgainstPageFiles` | **YES — the one destructive consumer** | Destructive; carries `scanSucceeded` + `unprobedPages` |
| 13 | `DownloadStore+Operations.swift:96` | `materializeRepairSeed` (**the one laundering route**) | Its selection decides a DIFFERENT folder's contents, one step ahead of #12 | **CLOSED this plan** — selects through the full scan and carries the non-answers |

`sanitizeAssetFileIfNeeded` sites, all `Bool` forwards whose false answer re-fetches or refuses rather than blanks: `DownloadStore.swift:505` (`existingAssetFileURL` — a first-match filter), `+Operations.swift:11` (`linkOrCopyReadableAsset` — throws), `:91` (the repair seed's cover — no per-page hash, outside the blast radius), `:105` (the repair seed's pre-copy guard — **now carries** its skip), `:280` (`validPageCount`), `:287` (`isReadableAssetFile`), `:296` (`hashReadableAsset` — throws), `:339` (`validatePage` — `.missingFiles`).

`.redownload` / `.update` delete the working folder and arrive at a fresh all-empty manifest, so #12 is a no-op for them; `repairSeed(for:payload:)` returns nil for every mode but `.repair`, so #13 is unreachable from them.

**Census reconciliation.** The verification's amendment enumerates *11 call sites*. Grepped at the pre-fix HEAD, `existingPageRelativePaths(` had **exactly 11 call sites** (rows 1, 3–11 above plus `materializeRepairSeed`'s, excluding the declaration) — the census agrees exactly. Post-fix it is 10, because `materializeRepairSeed` moved to the full scan. The verification's module list additionally names `+ExecutionSupport` and `+PageDownload`, which are the `pageFileScan` consumer (row 12) and the `existingPageRelativePaths:`-labelled pass-through parameter that carries `workingSeed.existingPages` into `pendingPageIndices` (`+PageDownload.swift:26, 124`) — a consumer of the seed, not a second derivation. **The dispositions match the verification exactly: one destructive consumer, one laundering route, and the laundering route is now closed. No new consumer and no second laundering route was found, so the plan did not stop.**

## Which pre-copy-guard remedy landed, and why

The plan offered two. The **smaller one landed**: a scan-selected page that the pre-copy guard skips is *inserted into the returned set* rather than silently vanishing. The alternative — dropping the redundant re-probe and letting `linkOrCopyReadableAsset`'s own internal guard throw — was **not** taken, because it converts an edge-case skip (a file that changed between the scan and the copy, or a relative path that fails containment validation) into a whole-preparation failure, and the suite does not prove that guard unreachable. Carrying is strictly the safer of the two: an uncopied page is re-fetched, while a thrown preparation fails the download.

Concretely, the guard that used to `continue` now inserts:

```swift
guard let relativePath = sourceScan.pages[page] else { continue }
guard let sourcePageURL = validatedChildURL(root: sourceFolderURL, relativePath: relativePath),
      let destPageURL = validatedChildURL(root: destinationFolderURL, relativePath: relativePath),
      sanitizeAssetFileIfNeeded(at: sourcePageURL)
else {
    unansweredPages.insert(page)
    continue
}
```

The first `guard` still `continue`s deliberately: a page the scan did not select was either never listed or positively rejected, and both are determinations the destination is entitled to read as absence.

## The review's remedy is provably not taken

`materializeRepairSeed`'s body contains **no new throw** — grepped over its post-fix body, the only throws are the pre-existing manifest/page copy propagation. `setupWorkingFolder`'s `try createDirectory(at: folderURL)` fallthrough is therefore unreachable from a successful materialization: the materialization arm `return`s the set directly, and the only way to reach `createDirectory` is `repairSeed(for:payload:)` answering nil, which is the pre-existing no-seed path. This matters because the traced consequence of the review's remedy is strictly worse than the defect: a refusal falls through to `createDirectory`, `ensureWorkingManifest` finds no manifest at the empty destination and writes a fresh all-empty one, and `updateDownloadIndex` republishes at 0-of-N — turning a K-page hash loss into an N-page loss plus a full D-G7-01 withdrawal.

## The corrected docs, quoted

**`DownloadClient+ExecutionSupport.swift`, the reconciliation's seed-route sentence** (`grep -c 'passed sanitization'` now returns `0`):

> …and the repair-seed materialization, which copies the manifest whole while copying the pages selectively — and therefore hands back the claimed pages its SOURCE-side probe could not answer for, which `prepareWorkingSeed` unions into the scan below so this reconciliation sees them as unprobed rather than absent (G-15-19). That route needs the carry because nothing here can derive it: the destination listing is entirely honest about a page the copy never landed, `scanSucceeded` is true and `unprobedPages` is empty, so a source-side non-answer and a source-side positive absence arrive indistinguishable. This paragraph used to classify that route as safe on the grounds that it copied every page whose source file had been sanitized — which is precisely where `.unprobeable` and `.rejected` collapse back together, one layer below the defence, and is the written premise the gap hid behind.

**The same doc block's line 2**, now naming both populations:

> 2. **The per-file positive signal (G-15-13, fixed as D-G13-01; extended across the copy by G-15-19).** `unprobedPages` carries TWO populations by the time it reaches here, and no page in either is blanked: the pages whose file THIS folder's successful listing did yield but whose probe could not classify, and the pages the repair-seed materialization reported unanswerable in the SOURCE folder it copied from, unioned in by `prepareWorkingSeed`. The second exists because this folder's listing cannot see it — a page the copy never landed is honestly absent here — so the classification has to travel with the copy rather than be re-derived.

**`DownloadStore.swift`, `PageFileScan`'s licensing paragraph**, with the route qualifier:

> **"Non-destructive" is a property of the ROUTE, not of the call (G-15-19).** A caller may collapse the pairs only if its output can never become the input of a destructive decision — in this folder or in any other, one step later or ten. `materializeRepairSeed` read as such a caller and was not one: it collapsed the pairs while scanning a SOURCE folder, and the pages it therefore did not copy became positive absences in the DESTINATION folder's own entirely honest scan, where nothing downstream could recover the distinction. A caller whose answer crosses a folder boundary must carry the classification with it, not the collapse.

**`DownloadStore.swift`, `existingPageRelativePaths`' caller rule:**

> A caller that acts irreversibly on the answer — or whose answer FEEDS something that does, even one step later and in a DIFFERENT folder — must use `pageFileScan(folderURL:manifest:)` instead and carry both its `scanSucceeded` flag and its `unprobedPages` set.
>
> The second half of that rule is not hypothetical (G-15-19): `materializeRepairSeed` called this function, and its selection decided which pages a different folder would afterwards be found to hold — so a page this collapse dropped for want of an answer arrived there as a positive absence and had its recorded hash destroyed. It now selects through the full scan and hands the unanswered pages back to its caller.

The all-or-nothing sentence at `+ExecutionSupport.swift:493` and `probeAssetFile`'s guard comment were deliberately left alone — they belong to G-15-20 (WR-04 / WR-03), plan 15-40.

## Prohibitions, checked

| Prohibition | Status | Evidence |
|---|---|---|
| Must NOT throw from `materializeRepairSeed` / treat an unprobeable source page as "no seed" | Held | No new throw in the body; the `createDirectory` fallthrough is unreachable from a materialization |
| Must NOT hand-issue any push in the new cases | Held | `grep` over the new file for push-issuing seams returns 0; the only recorded updates come from `testingEnsureContinuedSession` and `testingPrepareWorkingSeedAnnouncingProgress` |
| Must NOT weaken, delete or restage an existing case | Held | The mass-partial, genuine-partial, wholesale-failure and repair-seed suites all pass unchanged; the only test edits are two `DownloadStoreRepairTests` bindings the signature change required |
| Must NOT add anything to `DownloadContinuedSessionBasisTests.swift`; no concurrency/lint escape hatch or SwiftLint suppression | Held | That file is byte-unchanged at **996 lines**; SwiftLint `--strict` is clean over every edited file with no `swiftlint:disable`, no `@unchecked`, no `@preconcurrency`, no `try?` |

## Decisions Made

- **The pre-copy guard carries rather than throws.** Recorded above with the traced reason.
- **The cover keeps its `Bool` guard.** It has no per-page recorded hash, so an uncopied cover costs a re-download and destroys nothing; the function doc says so.
- **`existingPages` for the `WorkingSeed` stays the destination scan's `pages`.** An uncopied page is re-fetched, never reused — the carry changes only what the reconciliation is allowed to blank, not what the run believes it already holds.
- **The new suite stages its own batched permissions restore.** See the deviation below.

## Deviations from Plan

### 1. [Rule 3 — Blocking] The new suite does not promote the basis suite's permissions restorer

- **Found during:** Task 1 (writing the new file's staging)
- **Issue:** The plan's Step 1 offers two routes — write minimal local staging, or promote the basis suite's file-private `restorePermissions(at:to:)` into `DownloadFeatureTestHelpers.swift` — while forbidding duplication of a nontrivial helper. Promotion is only non-duplicating if the private copy is deleted from `DownloadContinuedSessionBasisTests.swift`, but the same task's acceptance criterion pins that file byte-unchanged at 996 lines (and a plan prohibition forbids touching it). The two instructions cannot both be satisfied by promoting.
- **Fix:** Took the plan's *first* route. The new file owns a private `restoreOriginalModes(of:to:)` — a **batched** restore over the whole staged set, a different shape from the basis suite's single-URL restorer, used at exactly one site. `DownloadFeatureTestHelpers.swift` therefore needed no change; the plan lists it conditionally ("**Possible** shared helper promotion"), so this is within the artifact contract.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadRepairSeedSignalPropagationTests.swift` (only)
- **Verification:** `DownloadContinuedSessionBasisTests.swift` is absent from `git diff --stat` for both task commits and still reports 996 lines; the new suite passes.
- **Committed in:** `29b6c5a0` (Task 1 commit)

### 2. [Rule 1 — Wrong premise in an acceptance criterion] The `existingPageRelativePaths` region criterion was drafted against an incomplete grep

- **Found during:** Task 2 (Step 4, the sweep)
- **Issue:** The plan's acceptance criterion states that after the fix, `grep -n 'existingPageRelativePaths' DownloadStore+Operations.swift` should match "only inside `addingCurrentFileHashes`". Grepped at HEAD, that file has **three** derivation sites, not one: `addingCurrentFileHashes` (`:124`), `validPageCount` (`:272`) and `validatePages` (`:308`), plus `validatePage`'s `existingPageRelativePaths:` parameter label (`:317, :330, :337`).
- **Fix:** No source change — the criterion's *intent* is satisfied and is what matters: `materializeRepairSeed` no longer appears among them. All three remaining derivation sites are dispositioned non-destructive in the sweep table (rows 5–7): a throw, a count, and a `.missingFiles` re-fetch. Recorded here rather than silently satisfied by narrowing a grep.
- **Files modified:** none
- **Verification:** the sweep table above; full `FeatureTests` green.
- **Committed in:** n/a (documentation-only finding)

---

**Total deviations:** 2 (1 blocking-instruction conflict resolved by taking the plan's stated alternative, 1 wrong-premise criterion recorded).
**Impact on plan:** No scope change. Neither deviation weakens the fix or its regression; both are recorded so the next round's verifier can re-derive rather than trust.

## Issues Encountered

None. The crossed case failed on the first targeted run with the exact readings the verification traced, which is the outcome the plan's stop-condition was written for (an unexpectedly *green* crossed case would have meant the staging missed the materialization branch).

## Threat Flags

None. No new network endpoint, auth path, file-access pattern or schema shape is introduced; the change moves an existing per-file classification across an existing copy boundary. `T-15-39-01`, `T-15-39-02` and `T-15-39-03` from the plan's register are all mitigated as planned — the carry closes the laundering, the review's worse remedy is provably not taken, and the genuine-absence companion pins that the carry does not over-protect.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- **G-15-19 closed** on the production route, with the crossed regression and the genuine-absence companion pinning both sides.
- **Ready for 15-40** (G-15-20's doc-vs-source group), which owns the two sentences this plan deliberately did not touch: the all-or-nothing residual's wording at `+ExecutionSupport.swift:493` (WR-04) and `probeAssetFile`'s guard comment (WR-03).
- **Still outstanding and NOT claimed here:** the physical-device re-run of `15-UAT.md` test 2 on iOS 26. With this plan landed, a `.repair` re-slot should no longer step the card backwards by a laundered blank count, so a mid-run backwards step on hardware is now a symptom to report rather than a known defect.

## Self-Check: PASSED

- `AppPackage/Tests/DownloadsFeatureTests/DownloadRepairSeedSignalPropagationTests.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadStore.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadStoreRepairTests.swift` — FOUND
- Commit `29b6c5a0` — FOUND
- Commit `dc84d193` — FOUND

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-05*
