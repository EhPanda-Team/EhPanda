---
phase: 15-continued-background-downloads
plan: 46
subsystem: testing
tags: [swift-testing, download-coordinator, test-doubles, page-selection, gap-closure]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "The round-15 HEAD (6a0059d4) with both refusal cases and the 872-test FeatureTests baseline from 15-45"
provides:
  - "makeStartPayload carrying an optional raw page selection, defaulted so every untouched call site is byte-identical"
  - "makeRetriedPagesPayload — a payload helper applying BOTH production steps in production order"
  - "A named pin case binding the helper's selection to the coordinator entry performRetryPages stores"
  - "A recorded 14-site census with a per-site faithfulness verdict, widened to all 23 payload-construction sites in the test target"
affects: [15-47, 15-48, 15-49]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A test double that drives a state-storing production route builds its payload through the production steps that read that state, never through a literal"
    - "The binding between a double and the route it models is owned by a named case, with the production event holding the state in place named in its doc comment"

key-files:
  created: []
  modified:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift

key-decisions:
  - "The helper takes the raw [Int] indices and the coordinator, not a Set: the coordinator entry is [Int] and the payload's selection is Set<Int>?, so the bridge happens where production bridges it"
  - "The census found a THIRD unfaithful site beyond the two the gap record named, in DownloadContinuedSessionLedgerTests — rebuilt on the same helper"
  - "The two `canonical retryPages route` reachability claims in Basis and Ledger were judged TRUE as written and left byte-unchanged rather than churned"

patterns-established:
  - "Faithfulness by construction: a double reproduces the production chain rather than copying a value the chain would have produced"
  - "Route-binding pin: one named case makes a helper's derived value fail a build when the route's own transform changes"

requirements-completed: [SC2]

coverage:
  - id: D1
    description: "Every payload double in the test target carries the page selection the production route it models stores, produced through both production steps"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift#testAnAllPagesGoneRepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift#testAFailedEnumerationRepairOfACompleteReadingRecordStillEarnsSessionTrust"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testARepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull"
        status: pass
    human_judgment: false
  - id: D2
    description: "The helper's selection is bound to the coordinator entry the route writes, so a change to retryPages' index transform fails a build"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift#testTheRetriedPagesPayloadCarriesExactlyTheSelectionTheRouteStores"
        status: pass
    human_judgment: false
  - id: D3
    description: "On a physical iOS 26 device a selected-page retry that fetches nothing shows a card that does not climb for that gallery"
    verification: []
    human_judgment: true
    rationale: "Backstop observation this plan deliberately does NOT change — G-15-27 is still open and 15-47 owns it. Device-only, and 15-UAT.md test 2 remains an independent axis."

# Metrics
duration: 26min
completed: 2026-08-06
status: complete
---

# Phase 15 Plan 46: Faithful retryPages Payload Doubles Summary

**Every test double that drives `retryPages` now builds its payload through production's own fetch-then-normalize pair, so it carries the selection the route stored — pinned to the coordinator entry by a named case, with the announcement gate provably unmoved.**

## Performance

- **Duration:** 26 min
- **Started:** 2026-08-06T00:35:00Z
- **Completed:** 2026-08-06T01:01:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Derived the production selection chain from source and rebuilt the doubles on it, rather than copying the gap record's suggested signature (which conflates two types source keeps distinct).
- Re-derived the census independently and found a **third** unfaithful site the gap record did not name.
- Added the route-binding pin so the family cannot silently drift again.
- Proved the plan's non-effect on the announcement gate: the rebuilt cases are green on both sides of the payload change, which is what makes 15-47's regression discriminating.

## Step 1 — the production selection chain, derived from source

| Fact | Source | Value |
|---|---|---|
| Coordinator collection production reads | `DownloadClient+Execution.swift:137` | `let rawPageSelection = queuedPageSelections[gid]` |
| First production step | `DownloadClient+Execution.swift:138-143` | `fetchLatestPayload(for:mode:options:pageSelection: rawPageSelection)` |
| Second production step | `DownloadClient+Execution.swift:144-148` | `normalizeFetchedPayload(fetchedPayload, mode:, rawPageSelection: rawPageSelection)` |
| Order / operand | both steps receive **the same** `rawPageSelection`, fetch first, normalize second |
| Where the fetch step places it | `DownloadClient+ExecutionFetch.swift:82` | `pageSelection: pageSelection.map(Set.init)` inside `buildPayload` |
| The normalizer's equality guard | `DownloadClient+ExecutionFetch.swift:171-173` | `guard pageSelection != rawPageSelection else { return payload }` |
| Guard's consequence | whenever the normalized selection equals the raw one, the payload is **returned untouched** — so a base payload arriving with no selection leaves with no selection. A double that calls only the normalizer keeps a nil selection and looks repaired while remaining unfaithful (T-15-46-04). |
| Index transform before storage | `DownloadClient+RetryHelpers.swift:55` | `let selectedPageIndices = Array(Set(pageIndices)).sorted()` — dedup + ascending sort |
| The storing assignment | `DownloadClient+RetryHelpers.swift:91` | `queuedPageSelections[gid] = selectedPageIndices` |
| Coordinator entry element type | `DownloadClient+Manager.swift:348` | `public var queuedPageSelections = [String: [Int]]()` → **`[Int]`** |
| Payload selection type | `DownloadedGallery+Extensions.swift:30` | `public let pageSelection: Set<Int>?` → **`Set<Int>?`** |

**The two types differ**, which is why the helper's signature was written from source rather than from the gap record: the raw parameter is `[Int]?` (what `fetchLatestPayload` takes) and the payload member is `Set<Int>?` (what `buildPayload` lands).

Also derived, for the doc comments and for the "no assertion moves" claim: `payload.pageSelection` has exactly **one** production consumer, `pendingPageIndices` (`DownloadClient+ExecutionSupport.swift:808`), reached only from `performDownload` (`DownloadClient+ExecutionPerform.swift:34`). `prepareWorkingSeedAnnouncingProgress` never reads it — its gate is `workingSeed.existingPages.count < workingSeed.manifest.pageCount` (`+ExecutionSupport.swift:445`). That is G-15-27, still open, and it is why threading the selection changes no assertion in this plan.

## Step 2 — the census, re-derived

`grep -rn "makeStartPayload(\|makeRepairPayload(" AppPackage/Tests/` → 17 lines, plus 1 doc-comment mention found by a paren-free grep. Classification **agrees exactly** with the plan's pre-derived enumeration: 14 case-body call sites over 5 suites, 1 forwarding call (`DownloadFeatureTestHelpers.swift:518`), 2 declarations (`:488`, `:517`), 1 doc-comment mention (`DownloadRepairSeedSignalPropagationTests.swift:38`). No discrepancy; no STOP.

**Faithfulness question, derived from source rather than prose:** does the production route this case drives write a `queuedPageSelections` entry for the gid before the payload is built? The only production writer of a non-nil entry is `performRetryPages` (`+RetryHelpers.swift:91`); every other writer (`performRetry:39`, `resume` `+Scheduling.swift:363`, `clearDownloadQueueIntent` `+Manager.swift:686`) writes nil.

| # | Site (pre-edit line) | Case | Route driven before the payload build | Verdict |
|---|---|---|---|---|
| 1 | `LedgerRefusalTests:104` | `testAnAllPagesGoneRepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull` | `retryPages(pageIndices: [1,2,3,4,5,6])` at `:91` | **UNFAITHFUL** |
| 2 | `LedgerRefusalTests:204` | `testAFailedEnumerationRepairOfACompleteReadingRecordStillEarnsSessionTrust` | `retryPages(pageIndices: [3])` at `:190` | **UNFAITHFUL** |
| 3 | `LedgerTests:635` | `testARepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull` | `retryPages(pageIndices: [3])` at `:622` | **UNFAITHFUL — not named by the gap record** |
| 4 | `LedgerTests:726` | `testAnAnnouncementDuringTheClientStartHopSurvivesTheSeed` | fixture `queuedGIDs` + `testingEnsureContinuedSession` — no queue-intent writer | faithful |
| 5 | `BasisTests:96` | `testABlankedGalleryPausedPartWayDoesNotFreezeTheSurvivorsPushes` | `testingEnsureContinuedSession` | faithful |
| 6 | `BasisTests:208` | `testAWithdrawalDuringTheClientStartHopSurvivesTheFloorSeed` | gated `testingEnsureContinuedSession` | faithful |
| 7 | `BasisTests:461` | `testARedownloadOfACountedGalleryWithdrawsItsBasisSoTheNextPushAdvances` | `testingEnsureContinuedSession`, `.redownload` | faithful |
| 8 | `BasisTests:555` | `testAnUpdateOfATrustedGalleryWithdrawsItsCountedPortion` | `testingEnsureContinuedSession`, `.update` | faithful |
| 9 | `BasisTests:628` | `testAPageCountMismatchFreshManifestWithdrawsTheCountedBasis` | `testingEnsureContinuedSession` | faithful |
| 10 | `ReconciliationTests:94` | `testAWholesaleScanFailureBlanksNothingWritesNothingAndWithdrawsNothing` | `testingEnsureContinuedSession` | faithful |
| 11 | `ReconciliationTests:222` | `testAMassPartialProbeFailureBlanksNothingWritesNothingAndWithdrawsNothing` | `testingEnsureContinuedSession` | faithful |
| 12 | `ReconciliationTests:299` | `testAGenuinePartialLossBlanksExactlyTheMissingPages` | `testingEnsureContinuedSession` | faithful |
| 13 | `RepairSeedSignalPropagationTests:122` | `testAnUnprobeableSourcePageIsNeverBlankedAcrossTheSeedCopy` | `testingEnsureContinuedSession` | faithful |
| 14 | `RepairSeedSignalPropagationTests:242` | `testAGenuinelyAbsentSourcePageIsStillBlankedAcrossTheSeedCopy` | `testingEnsureContinuedSession` | faithful |

**Census widened beyond the plan's grep, deliberately** (truth 1 states the invariant over the whole family, not over one helper's callers): `grep -rn "DownloadRequestPayload(" AppPackage/Tests/` finds 9 further direct construction sites, in `DownloadFolderOperationTests`, `DownloadZeroPagePayloadTests`, `DownloadEnqueueManifestTests`, `DownloadCoordinatorRepairSeedTests` (×2), `DownloadImageParsingTests` (×2) and `DownloadInterruptedResumeTests`. None of those files calls `manager.retryPages(` at all, so all 9 are faithful by the same source-derived question. The files that DO call `retryPages` and were not already in the census — `DownloadRetryPagesTests`, `DownloadContinuedSessionTests`, `DownloadCoordinatorStorageTests`, `DownloadRetryUpdateFallbackTests`, `DownloadRetryMinimalSourceTests` — build no payload at all and hand nothing to a production preparation.

## Step 3 — the helper

`makeStartPayload` gained `pageSelection: [Int]? = nil` (`DownloadFeatureTestHelpers.swift:499`), threaded into the literal beside the mode as `pageSelection: pageSelection.map(Set.init)` (`:521`) — the same expression `buildPayload` uses. The default keeps every untouched call site byte-identical.

`makeRetriedPagesPayload(for:mode:retriedPageIndices:coordinator:)` applies both steps in production order:

```swift
let rawPageSelection = Array(Set(retriedPageIndices)).sorted()
return await coordinator.normalizeFetchedPayload(
    makeStartPayload(for: gallery, mode: mode, pageSelection: rawPageSelection),
    mode: mode,
    rawPageSelection: rawPageSelection
)
```

Its doc comment states both steps, states the guard as a **rule** (no counts, no line references) and names G-15-28.

**Acceptance greps:**
- `grep -c 'pageSelection' …/DownloadFeatureTestHelpers.swift` → **6** (≥ 3). The three code occurrences are `:499  pageSelection: [Int]? = nil` (parameter), `:521  pageSelection: pageSelection.map(Set.init)` (literal member), `:561  pageSelection: rawPageSelection` (the production-shaped helper's use). The other three (`:489`, `:490`, `:491`) are doc-comment mentions.
- `grep -v '^[[:space:]]*//' …/DownloadFeatureTestHelpers.swift | grep -c 'normalizeFetchedPayload'` → **1**. The call is `:557  return await coordinator.normalizeFetchedPayload(`. Doc-comment mentions of the identifier: **0** — the helper's doc names the two steps in prose without spelling the symbol, which is what keeps the non-comment count exactly 1.
- `grep -c '@Test' …/DownloadFeatureTestHelpers.swift` → **0**.
- `git diff` over the four census suites other than the refusal file: `BasisTests`, `ReconciliationTests`, `RepairSeedSignalPropagationTests` → **zero changes**. (`LedgerTests` DID change — it holds census site 3, which the plan's provisional list correctly anticipated as a candidate.)

## Step 4 — the pin

**Case:** `testTheRetriedPagesPayloadCarriesExactlyTheSelectionTheRouteStores`
**File:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift` (an extension of `DownloadContinuedSessionLedgerTests`, so it inherits that suite's identity and traits — the same relocation pattern the file's header records).

It drives `retryPages(gid:pageIndices: [4, 2, 2])` — unordered and duplicated on purpose — then asserts `stored == [2, 4]` and `payload.pageSelection == Set(stored)`, bridging the two types explicitly.

**The production event named in its doc comment**, quoted:

> **The production event that holds the entry in place while the assertion runs** is `processScheduledDownload`'s `.skippedOperation` arm: it releases active ownership through `finishActiveTaskIfOwned`, which touches no queue intent at all, so a schedule that runs no operation leaves the selection standing for the run that follows — which is precisely why the run can still read it.

Derived, not assumed: `processScheduledDownload` (`+Scheduling.swift:73-81`) calls only `finishActiveTaskIfOwned` on that arm, and `finishActiveTaskIfOwned` (`+Execution.swift:244-271`) writes only `activeTask`/`activeGalleryID`. Every production clear of `queuedPageSelections` runs from a settle (`+Execution.swift:239`), a failure persistence (`:212`), a pause (`+Scheduling.swift:290`,`:329`), a resume (`:363`), a queued-item cancel (`:345`), an enqueue-time reset (`+Persistence.swift:179`) or a folder deletion (`+Folders.swift:138`) — this case drives none of them. `.skippedOperation` is a genuine production outcome of `DownloadTaskRunner`, not a test-only shape.

## Task Commits

1. **Task 1: Derive the chain, census every double, build the faithful helper** — `b384b7fc` (test)
2. **Task 2: Rebuild every unfaithful double, sweep the residue, prove green** — `0ce01ed0` (test)

## Files Created/Modified

- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` — `makeStartPayload` gains the defaulted selection; `makeRetriedPagesPayload` added; `makeRepairPayload`'s doc retargeted at no-selection routes.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift` — both refusal cases rebuilt on the helper; the pin case added.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift` — census site 3 rebuilt on the helper.

### `files_modified` rewritten (replacing the plan's PROVISIONAL candidate list)

| Path | In or out | Census verdict that decided it |
|---|---|---|
| `…/DownloadFeatureTestHelpers.swift` | **modified** | Holds both declarations; the helper landed here per the phase's promotion rule |
| `…/DownloadContinuedSessionLedgerRefusalTests.swift` | **modified** | Sites 1 and 2 UNFAITHFUL; also the pin's home |
| `…/DownloadContinuedSessionLedgerTests.swift` | **modified** | Site 3 UNFAITHFUL (`retryPages([3])` at `:622`); site 4 faithful and untouched |
| `…/DownloadContinuedSessionBasisTests.swift` | **not modified** | Sites 5–9 all faithful — `testingEnsureContinuedSession`, no queue-intent writer |
| `…/DownloadContinuedSessionReconciliationTests.swift` | **not modified** | Sites 10–12 all faithful — same route |
| `…/DownloadRepairSeedSignalPropagationTests.swift` | **not modified** | Sites 13–14 faithful — same route |

## Residue sweep (three checks, each recorded)

**(a) Newly-orphaned symbols.** `makeRepairPayload` lost 3 of its 11 callers. Remaining: **8** case-body call sites (`grep -rn "makeRepairPayload(for:" AppPackage/Tests/ | wc -l` → 8, of which 1 is the declaration line and 1 the forwarding body, leaving 6 case-body callers across Basis ×2, Reconciliation ×3, RepairSeedSignalPropagation ×2 and LedgerTests ×1 — 8 call-shaped lines total). Non-zero, so it is kept, not deleted. `makeStartPayload` retains 3 direct case-body callers (`BasisTests:461,555,628`) plus its two in-helper callers. Nothing orphaned; nothing deleted.

**(b) The same unfaithful CLAIM elsewhere.** Scanned the test target for suite headers and case docs asserting that a payload models a production route. Three claims found, each checked against source and each **TRUE as written**, so all three were left byte-unchanged rather than churned:
- `DownloadContinuedSessionBasisTests.swift:163` — "On the canonical `retryPages` route the run is scheduled BEFORE the trailing `ensureContinuedSession`". A claim about where the interleaving is *reachable*, not about the payload; the case drives no selection-storing route, so its nil selection is faithful.
- `DownloadContinuedSessionLedgerTests.swift:683` — the identical claim in the sibling hop case. Same reading; treating one and not the other would have been an inconsistent rule.
- `DownloadRepairSeedSignalPropagationTests.swift:38` — "`makeRepairPayload` keeps the title, so `shouldReuseWorkingFolder` returns true". A claim about the folder name, unaffected by this change and still true.

**(c) Newly-stale prose.** One found and fixed: `makeRepairPayload`'s doc read "spelled at every existing call site exactly as before", which stopped being true the moment three sites moved off it. Rewritten to say what the helper now means — the `.repair` payload for a case whose route stores **no** selection — and to point `retryPages`-driving cases at `makeRetriedPagesPayload`. `makeStartPayload`'s doc was extended in the same commit rather than left describing a selection-free payload.

## Green, both sides recorded

| Run | Scope | Result |
|---|---|---|
| Task 1 verify (payloads still selection-free) | `-only-testing:DownloadsFeatureTests/DownloadContinuedSessionLedgerTests` | **TEST SUCCEEDED**, 16 tests, 0 failures, 3.78 s |
| Task 2 verify (payloads production-shaped) | full `FeatureTests` | **TEST SUCCEEDED**, 873 tests, 0 failures, 6 expected failures, 101.9 s |

**Test count:** 873 against 15-45's baseline of **872** → net **+1**, exactly the pin case added in Task 1. No other movement.

**The plan's central negative result.** All three rebuilt cases were observed passing on **both** sides of the payload change:

- BEFORE (Task-1 run, payloads still built by `makeRepairPayload`): `✔ Test testAFailedEnumerationRepairOfACompleteReadingRecordStillEarnsSessionTrust() passed after 0.108 seconds.`, `✔ Test testARepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull() passed after 0.118 seconds.`, `✔ Test testAnAllPagesGoneRepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull() passed after 0.122 seconds.`
- AFTER (Task-2 full run, payloads production-shaped), read from the xcresult: all four of `testAnAllPagesGoneRepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull`, `testAFailedEnumerationRepairOfACompleteReadingRecordStillEarnsSessionTrust`, `testARepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull`, `testTheRetriedPagesPayloadCarriesExactlyTheSelectionTheRouteStores` → `Passed`.

That symmetry is the evidence the repair **did not move the announcement gate**: G-15-27 is still open at this plan's end, and 15-47's regression therefore has something to discriminate.

## Prohibitions

| Prohibition | Status | Evidence |
|---|---|---|
| No production source file changed | **held** | `git diff --stat -- AppPackage/Sources App ShareExtension` → 0 files |
| Not only the two cited cases | **held** | 14-site census recorded with per-site verdicts; a third unfaithful site found and repaired; family widened to 23 payload sites |
| Signature derived, not copied | **held** | Both element types quoted from source above; the raw parameter is `[Int]?`, the payload member `Set<Int>?` |
| No staging helper duplicated into a suite | **held** | The new helper lives in `DownloadFeatureTestHelpers.swift`; nothing was copied |
| No concurrency / lint escape hatch | **held** | No `swiftlint:disable`, no `@unchecked`, no `@preconcurrency`; 0 lines over 120 chars in the touched files; all three files well under the 1000-line limit (802 / 826 / 359) |

## Decisions Made

- The helper takes raw `[Int]` indices plus the coordinator and bridges to `Set<Int>?` exactly where production bridges it, because the coordinator entry and the payload member are genuinely different types.
- The `mode` parameter is explicit rather than defaulted to `.repair`, so a future non-repair selection route cannot inherit the wrong mode silently.
- The pin lands in the refusal suite, not the helpers file — it is a test about the route, and the helpers file holds no `@Test` and must not start holding one.
- The two reachability claims naming `retryPages` were judged true and left alone; consistency across identical claims mattered more than a cosmetic rewrite.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Repaired a third unfaithful double the gap record did not name**

- **Found during:** Task 1 (Step 2 census)
- **Issue:** `DownloadContinuedSessionLedgerTests.testARepairOfACompleteReadingRecordReportsItsWorkAndDrainsFull` drives `retryPages(pageIndices: [3])` at `:622` and then built a selection-free payload at `:635` — the same contract-unfaithful shape as the two cases G-15-28 cites. Repairing only the cited two would have left the class live, which is exactly threat T-15-46-03.
- **Fix:** Rebuilt on `makeRetriedPagesPayload` with the case's own index set, doc comment updated on the same terms as the two refusal cases.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift`
- **Verification:** Case passes in the full run; its diff is confined to the payload construction and its doc.
- **Committed in:** `0ce01ed0` (Task 2 commit)

**2. [Rule 1 - Bug] Retired stale prose on `makeRepairPayload`**

- **Found during:** Task 2 (Step 3, residue check (c))
- **Issue:** Its doc read "spelled at every existing call site exactly as before", false once three sites moved to the new helper — the doc-vs-source drift class this phase has re-generated repeatedly.
- **Fix:** Rewritten to state which routes the nil selection is faithful for, and to route `retryPages`-driving cases to `makeRetriedPagesPayload`.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift`
- **Verification:** Full suite green; no other doc restates the old selection-free shape.
- **Committed in:** `0ce01ed0` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 missing critical, 1 bug)
**Impact on plan:** Both are inside the plan's stated family scope — the census was explicitly instructed to widen past the two cited cases, and Step 3 explicitly required the stale-prose sweep. No scope creep; no production file touched.

## Issues Encountered

None. The census matched the plan's pre-derived enumeration exactly (14/1/2/1), so no STOP condition fired.

## Known Stubs

None.

## Threat Flags

None — no new network endpoint, auth path, file-access pattern or schema change. This plan is test-target only.

## User Setup Required

None.

## Next Phase Readiness

- **15-47 (G-15-27) is unblocked and its regression will now discriminate:** the doubles reach the announcement gate carrying a real selection, and the gate provably still ignores it (`payload.pageSelection`'s only consumer is `pendingPageIndices`, unreached by `prepareWorkingSeedAnnouncingProgress`).
- **G-15-27 and G-15-26 remain open**, unchanged by this plan, as designed.
- **15-UAT.md test 2** still needs its physical-device iOS 26 re-run; this plan does not claim it (coverage `D3`).

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-06*

## Self-Check: PASSED

All 3 modified files present on disk; all 3 commits (`b384b7fc`, `0ce01ed0`, `8274cbe8`) present in git history. No absolute home path in this document.
