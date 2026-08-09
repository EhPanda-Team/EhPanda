---
phase: 15-continued-background-downloads
plan: 59
subsystem: downloads
tags: [download-manifest, ssot, inspector, retry-basis, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-58's content arm and its narrowed `validationErrors` — the operation-level-only refusal surface this plan composes the retry basis over"
  - phase: 15-continued-background-downloads
    provides: "15-57's D-G5C-01 retry affordance and its `canRetryPages` gate — the basis this plan recomposes over the new pending"
  - phase: 15-continued-background-downloads
    provides: "15-56's D-G5B-01 durable validate-time reconciliation — the single sensor the display basis now defers to entirely"
provides:
  - "D-SSOT-07: inspector page states derive from the manifest (recorded hash, recorded page failure) alone; the directory listing is demoted to a rendering-resource resolver"
  - "D-SSOT-08: at the `.error`/`fileOperationFailed` shape the retry basis is the FULL page-index set, so the wholesale-refusal family keeps its start after the display basis moved"
  - "`buildInspectionPages` performs no file-system call of its own — one persisted basis behind badge and page list, by construction"
  - "`DownloadInspection.pendingPageIndices` deleted with its last consumer"
affects: [downloads-inspector, detail-error-affordance, 15-verification-round-19, 15-UAT-test-5]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Demote a sensor rather than reconcile two of them: when two displays disagree, delete the second basis instead of keeping the pair in step"
    - "A record-wide signal licenses a record-wide selection: deriving a per-page subset from an operation-level error is a category error, and the run's own evidence is what narrows it"
    - "When a consumer's input changes derivation basis, re-pin the consumer on the production path — the affordance can survive in shape while losing all of its content"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadInspectionBasisTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift
    - AppPackage/Sources/AppModels/Download/DownloadInspection.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift

key-decisions:
  - "D-SSOT-07: status precedence is unchanged with the sensor swapped — non-empty recorded hash → `.downloaded`, else recorded page failure → `.failed`, else `.pending`; the per-page existence probe is deleted"
  - "D-SSOT-07: the listing keeps exactly one job, resolving `relativePath`/`fileURL` for whichever pages have an on-disk file; a missing thumbnail under a downloaded claim is the approved pre-validate appearance"
  - "D-SSOT-08: the full-set basis at the operation-level-error shape, because a wholesale-refusal record offers no derivable subset and `failed ∪ pending` is EMPTY for exactly that family"
  - "The full set is read off `pages` rather than built as `1...pageCount`: equal by construction, and the range form would trap on a zero-page record (G-15-14)"
  - "`retryablePageIndices` outside the shape stays failed-only, pinned from both sides — undone pages remain Resume's business"
  - "The failed branch keeps `failedPage.relativePath` as its fallback; it is failure metadata rather than a listing product, and this preserves today's value for every case reachable today"
  - "No log line was added anywhere: the plan authorized none, and 15-56 recorded what an unauthorized one costs"

patterns-established:
  - "Pin a divergence window from BOTH sides as separate cases — the stale-but-honest reading and the converged reading are different assertions, and only one of them is about the fix"
  - "Assert an affordance's payload NON-EMPTY before driving it: a basis that silently collapses leaves the control present and the arc passing on everything except the thing that matters"

requirements-completed: [SC2]

coverage:
  - id: D1
    description: "Claim-vs-disk divergence pre-validate: an externally deleted page still reads the record's claim, the downloaded set equals the badge's completedPageCount, and only the rendering resource is gone"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadInspectionBasisTests.swift#testAnExternallyDeletedPageStillReadsTheRecordsClaimBeforeValidation"
        status: pass
    human_judgment: false
  - id: D2
    description: "Convergence post-validate: the same divergence, sensed and durably reconciled by the single tap, converges the page list and the badge together"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadInspectionBasisTests.swift#testValidatingConvergesTheInspectorOnTheReconciledRecord"
        status: pass
    human_judgment: false
  - id: D3
    description: "The derivation is total and its precedence is unchanged: a blank-hash page reads pending even with a stray file at its path, and a blank-hash page with a recorded failure reads failed with its failure attached"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadInspectionBasisTests.swift#testABlankHashedPageReadsPendingEvenWhenAStrayFileSitsAtItsPath"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadInspectionBasisTests.swift#testABlankHashedPageWithARecordedFailureReadsFailed"
        status: pass
    human_judgment: false
  - id: D4
    description: "The full-set basis at the operation-level-error shape, including the wholesale-refusal shape where no page reads pending or failed at all"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift#testTheRetryBasisIsTheWholePageSetForTheFileFailureErrorShape"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift#testTheWholesaleRefusalShapeIsFullyRetryableThoughNoPageReadsPendingOrFailed"
        status: pass
    human_judgment: false
  - id: D5
    description: "The composition hazard closed on the production path: a wholesale-refusal record's basis is non-empty and the whole page set, and retryPages carries it to .queued with the intent resolving .repair"
    requirement: SC2
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift#testRetryingAWholesaleRefusedRecordQueuesARepairOverEveryPage"
        status: pass
    human_judgment: false
  - id: D6
    description: "The basis does not leak: a healthy-incomplete .inactive record keeps the failed-only basis and closes its gate when that set is empty; an .error record with a non-file failure code keeps it too"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift#testTheRetryBasisStaysFailedOnlyForANonErrorDownloadWithPendingPages"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift#testTheRetryBasisStaysFailedOnlyForAnErrorWithADifferentFailureCode"
        status: pass
    human_judgment: false
  - id: D7
    description: "Device retest of 15-UAT.md test 5 with CHANGED expected observations: pre-validate the inspector mirrors the record's claim (pages read downloaded, deleted pages show no thumbnail, count matches the badge); Validate senses and reconciles; the wholesale-missing gallery's retry starts the full re-fetch"
    verification: []
    human_judgment: true
    rationale: "The rendered page groups, the enabled Validate and retry rows, and the live repair on a physical device cannot be observed from the client seam a unit test reaches — and this plan CHANGES what the pre-validate screen is supposed to show."

# Metrics
duration: 66min
completed: 2026-08-09
status: complete
---

# Phase 15 Plan 59: One Basis Behind Every Completeness Display Summary

**The inspector's page states now come from the manifest instead of a live file probe, so the badge and the page list are the same function of the same persisted input and cannot diverge; and because a manifest-derived wholesale-refusal record has no pending page at all, the retry basis at the operation-level-error shape became the whole page set rather than a union that would have silently emptied itself for exactly the family it was built for.**

## Performance

- **Duration:** ~66 min of active execution
- **Started:** 2026-08-09T04:05:00Z
- **Completed:** 2026-08-09T05:11:00Z
- **Tasks:** 2
- **Files modified:** 4 (1 created, 3 modified)

## Accomplishments

- **The second display basis is gone rather than reconciled.** `buildInspectionPages` no longer performs a file-system call of its own: a page's status is `(manifest hash, recorded page failure)` and nothing else, so the inspector's downloaded set is exactly the set `completedPageCount` counts. The badge and the page list can no longer disagree in-session or across relaunch, because there is nothing left to disagree with.
- **The stale reading is now the honest one.** After an external deletion the inspector shows the record's claim — all pages downloaded, the deleted page's thumbnail simply absent — which agrees with the badge beside it and with what a relaunch would read. Validate is the single tap that senses the divergence, and 15-56/15-58 already made it reconcile durably.
- **The composition hazard was real, and it is now pinned end to end.** With Task 1 landed and Task 2's implementation not yet, the arc case failed with the record still `.error`, `lastError` still set and `queuedPageSelections` empty — because the union basis had collapsed to `[]` and `retryPages` was handed nothing. That is the G-15-5 dead end re-created invisibly: the button still there, with nothing in it. The full-set basis closes it, and the arc asserts the basis non-empty BEFORE driving anything, so a future subset-shaped basis fails in a test rather than in a device session.
- **The widening did not leak, and both sides say so.** A healthy-incomplete `.inactive` record keeps the failed-only basis and closes its gate when that set is empty; an `.error` record under a networking-shaped failure keeps it too. Both cases passed pre-fix and post-fix unchanged, which is the boundary evidence that the change is confined to the shape it names.
- **`Validate` became reachable for the family that needs it most — a consequence worth stating.** `DownloadInspection.canValidateImageData` is gated on `hasDownloadedPages`, which is `pages.contains(.downloaded)`. Under the presence basis a gallery whose files were ALL deleted externally had zero downloaded pages, so the inspector's Validate row was **disabled** — the single sensor was unreachable from the screen that reports the problem. Under the manifest basis that property is exactly `completedPageCount > 0`, so the row is enabled and the sensor can be run. No code changed for this; it fell out of the basis.
- **No dead basis survived the change.** `DownloadInspection.pendingPageIndices` had exactly one consumer — the union arm — so it was deleted rather than left as a property nothing reads.

## Task Commits

Each task was committed atomically:

1. **Task 1: The manifest-derived derivation, pinned across the divergence window** - `654a912e` (feat)
2. **Task 2: The full-set retry basis — recomposing 15-57's affordance over the new pending** - `ac6edbd8` (fix)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPIHelpers.swift` - `buildInspectionPages` rewritten to the manifest basis with the per-page `fileExists` probe deleted, and a new D-SSOT-07 doc carrying the WHY (why one basis, why the stale claim is the right pre-validate reading, why the listing is a rendering-resource resolver, why this function writes nothing). The G-15-14 zero-page guard and its comment are untouched, as is `clearSelectedFailedPages`.
- `AppPackage/Sources/AppModels/Download/DownloadInspection.swift` - `retryablePageIndices`' error-shape arm is now `pages.map(\.index).sorted()`, with a new D-SSOT-08 doc; `pendingPageIndices` deleted; the previous round's derivation rationale removed in full.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadInspectionBasisTests.swift` - **New.** Four cases driven through `loadInspection` over real storage fixtures, plus four private fixture helpers.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift` - the union pins rewritten (see below), the arc case renamed and re-pinned on the wholesale-refusal shape.

## Falsifiability Record (banked pre-fix evidence)

**Task 1, against pre-fix production.** Two of the four cases were RED and two passed, and the split is diagnostic: the two that passed are the ones the presence basis and the manifest basis agree on.

`testAnExternallyDeletedPageStillReadsTheRecordsClaimBeforeValidation` — **FAILED, 2 issues:**
- `(inspection.pages.map(\.status) → [.downloaded, .pending, .downloaded]) == [.downloaded, .downloaded, .downloaded]`
- `(downloadedCount(in: inspection) → 2) == (inspection.download.completedPageCount → 3)`

`testABlankHashedPageReadsPendingEvenWhenAStrayFileSitsAtItsPath` — **FAILED, 3 issues:**
- `(stray.status → .downloaded) == .pending`
- `(inspection.pages.filter({ $0.status == .downloaded }).map(\.index) → [1, 2, 3]) == [1, 2]`
- `(downloadedCount(in: inspection) → 3) == (inspection.download.completedPageCount → 2)`

**Passed pre-fix, unchanged:** `testValidatingConvergesTheInspectorOnTheReconciledRecord` (the plan anticipated this — post-validate the record has been corrected, so both bases read the same thing; the case is still the load-bearing half of the window, because it is what says the correction is DISPLAYED) and `testABlankHashedPageWithARecordedFailureReadsFailed` (the failure branch did not move). `DownloadZeroPagePayloadTests` passed pre-fix and post-fix, 5 tests, unchanged.

**Task 2, against the union implementation with Task 1 already landed.** Three cases RED with 9 issues, two boundary cases green.

`testTheRetryBasisIsTheWholePageSetForTheFileFailureErrorShape` — **FAILED, 1 issue:**
- `(inspection.retryablePageIndices → [2, 3]) == [1, 2, 3]`

`testTheWholesaleRefusalShapeIsFullyRetryableThoughNoPageReadsPendingOrFailed` — **FAILED, 2 issues:**
- `(inspection.retryablePageIndices → []) == [1, 2]`
- `#expect(inspection.canRetryPages)` recorded false

`testRetryingAWholesaleRefusedRecordQueuesARepairOverEveryPage` — **FAILED, 6 issues.** This is the hazard demonstrated end to end on the production path:
- `(inspection.retryablePageIndices.isEmpty → true) == false`
- `(inspection.retryablePageIndices → []) == [1, 2]`
- `#expect(inspection.canRetryPages)` recorded false
- `(queued.displayStatus → .error) == .queued`
- `(queued.lastError → DownloadFailure(code: fileOperationFailed, …)) == nil`
- `await fixture.manager.queuedPageSelections[target.gid] == [1, 2]`

The last three are the point: with an empty selection the retry started nothing at all, so the record sat on the error surface exactly as it did before 15-57 existed.

**Passed pre-fix, unchanged, in the same run:** `testTheRetryBasisStaysFailedOnlyForAnErrorWithADifferentFailureCode`, `testTheRetryBasisStaysFailedOnlyForANonErrorDownloadWithPendingPages`, `testRetryPagesQueuesWorkWhenAnotherDownloadIsActive`, `testCancelQueuedWorkClearsQueueIntent`. The excluded regimes are provably untouched.

## The Consumer Sweep (Task 1, Step 3)

Every consumer of `buildInspectionPages`' output and of `DownloadPageStatus` semantics, with its disposition. The inventory is the full result of `grep -rn "DownloadPageStatus"`, `grep -rn "status == \.(pending|downloaded|failed)"` and `grep -rn "hasDownloadedPages"` across `AppPackage/Sources` and `AppPackage/Tests`.

| # | Consumer | Disposition | Reason |
|---|---|---|---|
| 1 | `DownloadClient+PublicAPI.loadInspection` | **Unchanged** | The only production caller. Its signature was allowed to stay as is by the plan; it still supplies the listing (now for resource resolution only) and the cancellation-filtered `failedPages`. It follows the new basis by construction. |
| 2 | `DownloadInspection.failedPageIndices` | **Unchanged** | Filters `.failed`, which under the new basis means blank hash + recorded failure. Still the correct set, and still the whole basis outside the error shape. |
| 3 | `DownloadInspection.pendingPageIndices` | **Deleted** | Its last consumer was the union arm Task 2 replaced. Left in place it would be a property nothing reads, computing a set the new basis never uses. |
| 4 | `DownloadedGallery+SupportTypes.hasDownloadedPages` | **Unchanged, deliberately** | `pages.contains(.downloaded)` is now exactly `completedPageCount > 0`, which is what the property meant all along. It gates `DownloadInspection.canValidateImageData`, and following the new basis is what makes Validate reachable for a wholesale-missing gallery (see Accomplishments). No edit was needed for it to be correct — it is correct *because* the basis moved. |
| 5 | `DownloadsView+Subviews` inspector page groups | **Unchanged** | Consumes the statuses opaquely, filtering `inspection.pages` into three rows. It now renders the record's claim in the same List as the badge that makes it. |
| 6 | `DownloadsView+Subviews.previewInspection` | **Unchanged** | Already built its manifest pages from group membership, with a comment saying so ("a page counts as complete in the manifest only when its relative path is non-empty, so the header cell's badge stays consistent with the page groups"). It was already constructed to satisfy the invariant this plan makes structural — previously by convention, now by construction. |
| 7 | `DownloadInspectorReducer.retryPages` optimistic overlay | **Unchanged** | A UI-local optimistic rewrite of retried pages to `.pending`, replaced by the next `loadInspection`. It is not a derivation basis and never reaches the record. |
| 8 | `DownloadInspectorReducer.overlayRetryingPages` / `reconciledRetryingPageIndices` | **Unchanged, better founded** | Both treat `.downloaded` as "settled, stop showing as retrying". That now means "the manifest recorded the page", i.e. exactly when the repair's flush landed it — where before it meant "a file appeared on disk", which can precede the hash being recorded. |
| 9 | `DownloadZeroPagePayloadTests` (direct `buildInspectionPages` call) | **Unchanged** | Pins the G-15-14 zero-page guard, which is untouched. Green pre-fix and post-fix. |
| 10 | `DownloadCoordinatorStorageTests:814` | **Unchanged** | Manifest `["sha256:done", ""]`, a file for page 1, a recorded failure for page 2 → downloaded/failed under both bases. |
| 11 | `DownloadPauseAndReconcileTests:288` | **Unchanged** | Same manifest shape with a cancellation-like failure that `loadInspection` filters out → downloaded/pending under both bases. |
| 12 | `DownloadRetryPagesTests` arc + basis cases | **Rewritten** | This is the composition hazard's own test. See below. |
| 13 | `DownloadInspectorLoadTests`, `DownloadFeatureTestFactories.sampleInspection` | **Unchanged** | Synthetic `DownloadInspection` values through a stubbed client; they never reach the derivation. |

**Out of scope by prohibition, verified untouched:** the repair-preparation scan path (`prepareWorkingSeed`, `materializeRepairSeed` and the `pageFileScan` consumers in the execution flow). `git show --stat` for both commits lists four files, none of them in that path.

**Undeclared files deliberately left alone**, both recorded here rather than edited:

- `AppPackage/Sources/DetailFeature/DetailReducer.swift` line 112 points at "the downloads inspector's widened retry (D-G5C-01), which carries its page selection explicitly and therefore does not depend on the record's claims". Every factual claim in that sentence is still true under D-SSOT-08 — the selection is still explicit, still independent of the record's claims, and still widened; only the decision ID that names it is superseded. The file is in neither `files_modified` nor either task's `<files>`.
- `AppPackage/Tests/DetailFeatureTests/DetailDownloadRepairPredicateTests.swift` lines 13 and 52 carry 15-58's dispositioned comment-only residual (corrupt-in-place named as a complete-claiming family member). Also undeclared here, and unrelated to this plan's basis.

## Rewritten Rather Than Supplemented

The plan prohibits supplementing 15-57's `failed ∪ pending` boundary pins, on the ground that they encode a basis this plan replaces. All four were rewritten in place; nothing was added beside them.

| 15-57 pin | Fate |
|---|---|
| `testTheRetryBasisUnionsPendingPagesForTheFileFailureErrorShape` | **Renamed and re-expected** → `testTheRetryBasisIsTheWholePageSetForTheFileFailureErrorShape`, `[2, 3]` → `[1, 2, 3]`. |
| `testTheRetryBasisStaysFailedOnlyForAnErrorWithADifferentFailureCode` | **Expectation unchanged, doc rewritten.** The value is the same under both bases; the doc argued from "its pending pages are still ordinary undone work", which is a union-shaped justification, and now argues from the failure being an ordinary interruption whose per-page evidence is intact. |
| `testTheRetryBasisStaysFailedOnlyForANonErrorDownloadWithPendingPages` | **Expectations unchanged, doc rewritten** to name the `.inactive` regime the plan's behavior block names, and to say that the leak would be blunter under the full-set basis than under the union. |
| `testTheAllMissingShapeMakesTheWholePageSetRetryable` | **Rewritten wholesale** → `testTheWholesaleRefusalShapeIsFullyRetryableThoughNoPageReadsPendingOrFailed`. Its old fixture (`[.pending, .pending]`) is unreachable in production under D-SSOT-07 — a refusal record claims every page — so keeping it would have pinned a shape that no longer exists while leaving the shape that does exist unpinned. The rewrite stages `[.downloaded, .downloaded]` and asserts BOTH candidate subsets empty before asserting the full set. |
| `testRetryingThePendingPagesOfARefusedRecordQueuesARepair` (the arc) | **Renamed** → `testRetryingAWholesaleRefusedRecordQueuesARepairOverEveryPage`, and its middle block rewritten: the three assertions that read the pending set are replaced by the manifest-derived reading (`[.downloaded, .downloaded]`), both empty-subset assertions, an explicit `retryablePageIndices.isEmpty == false`, and the routing now goes through `inspection.retryablePageIndices` rather than a locally derived array. |

**No elsewhere-pinned union expectation surfaced.** The full `FeatureTests` run went 390 → 394 tests in the downloads target with zero failures, so nothing outside `DownloadRetryPagesTests` had encoded the union as an assertion.

## The Fate of `pendingPageIndices`

`DownloadInspection.pendingPageIndices` is **deleted**. It had exactly one consumer, `retryablePageIndices`' union arm, and the plan's dead-predicate rule applies directly.

The acceptance criterion's literal command, `grep -rn 'pendingPageIndices' AppPackage/Sources`, does **not** come back empty — and no surviving consumer of the deleted property is the reason. The remaining ten matches are a wholly different symbol in the execution flow: `DownloadCoordinator.pendingPageIndices(payload:folderURL:existingPageRelativePaths:)` (`DownloadClient+ExecutionSupport.swift:895`) and the `PreparedRun.pendingPageIndices` field it feeds (`DownloadClient+Manager.swift:215`, `DownloadClient+ExecutionPerform.swift:47`, `DownloadClient+PageDownload.swift:23`). That is a run's own pending-page selection, has nothing to do with the inspection property, and is out of this plan's scope. The scoped check is the meaningful one and it is clean:

```
grep -n 'pendingPageIndices' AppPackage/Sources/AppModels/Download/DownloadInspection.swift   →  (no output)
```

## Why the Full Set Is Read Off `pages`

`pages.map(\.index).sorted()` rather than `Array(1...download.pageCount)`. The two are equal by construction — `buildInspectionPages` enumerates exactly `1...pageCount` — but the range form traps on a zero-page record, which is the G-15-14 hazard every other page-count site in this module already guards (including `buildInspectionPages` itself, three lines up). Reading the set off the array the inspection already carries is the same set with no new trap, and the reasoning is recorded on the property.

## Deviations from Plan

None — the plan was executed exactly as written, and **no DECISION CHECKPOINT was needed.** Every instruction resolved against the real post-15-58 source.

Three implementation choices worth naming, all inside the plan's latitude rather than departures from it:

- **The failed branch keeps `failedPage.relativePath` as a fallback** (`listedRelativePath ?? failedPage.relativePath`). The plan constrains the LISTING to populating `relativePath`/`fileURL` and says the failure branch behaves "exactly as today". Before the probe was deleted, a failed page could never also be listed — a listed page was downloaded by definition — so this expression reproduces today's value for every case reachable today, and only adds a path where the new basis makes a failed page with a file on disk possible at all. `fileURL` is uniformly listing-derived.
- **The RED observation for Task 2 was taken with `-only-testing:DownloadsFeatureTests/DownloadRetryPagesTests`** rather than the full plan. Task 2's Step 1 says "Run"; Step 3 is what specifies the full suite, and it was run in full for GREEN. `DownloadRetryPagesTests` is a suite defined in its own file with no extensions elsewhere (checked, because file names are not suite names in this target).
- **`buildInspectionPages` retains its signature**, as the plan explicitly permits. `activeFolderURL` and `existingRelativePaths` are still parameters; they now feed resource resolution only.

## Issues Encountered

- **No log content was added anywhere.** The plan authorized none. `DownloadLogPrivacyInvariantTests` passed in the full run, so the hash-masked inventory is unchanged — the trap 15-56 documented.
- **The simulator's diagnostics collection timed out (600s) on both failing runs**, adding ~10 minutes to each RED gate after the tests themselves had finished in well under a second. It is a post-run artifact of `TEST FAILED`, not a hang: both green runs completed in 60s and 128s of testing time. Every `xcodebuild` invocation was run singly, and none was killed mid-flight.
- The verbatim RED expectations for Task 2 were recovered from the run's `.xcresult` via `xcrun xcresulttool`, because the `tail`-filtered console capture had scrolled them off.

## Verification

- Task 1 gate — `-only-testing:DownloadsFeatureTests/DownloadInspectionBasisTests -only-testing:DownloadsFeatureTests/DownloadZeroPagePayloadTests`: **`** TEST SUCCEEDED **`**, 9 tests in 2 suites, zero failures.
- Task 2 gate — full `FeatureTests` plan: **`** TEST SUCCEEDED **`**. Downloads target **394 tests in 70 suites** (+4 tests, +1 suite over 15-58's 390/69), every target green, zero failures.
- Clean app-scheme build: **`** BUILD SUCCEEDED **`**, with zero `warning:` and zero `error:` lines — so zero SwiftLint violations, since the plugin reports through those.
- SwiftLint over all four touched Swift files with the repository config in `--strict` mode: **0 violations, 0 serious**. The app-scheme build does not lint `Tests/`, so the two test files were linted explicitly with the standalone binary.
- No `swiftlint:disable`, no `@unchecked Sendable`, no `@preconcurrency`, no `nonisolated(unsafe)` anywhere in `AppPackage/Sources/DownloadClient`, `AppPackage/Sources/AppModels/Download`, `AppPackage/Sources/DownloadsFeature` or `AppPackage/Tests/DownloadsFeatureTests` (grep count: 0).
- Neither commit deletes a tracked file (`git diff --diff-filter=D` empty for both).

## Acceptance Criteria

| Criterion | Result |
|---|---|
| `grep -c 'D-SSOT-07'` in DownloadClient+PublicAPIHelpers.swift | `1` (≥1 required) |
| `grep -v '^\s*//' PublicAPIHelpers \| grep -c 'fileExists'` | `0`, as required |
| Divergence window pinned from both sides (claim pre-validate, converged post-validate) | yes — D1 and D2 |
| Totality pinned (blank hash + stray file → pending; blank hash + failure → failed) | yes — D3 |
| Consumer inventory with per-consumer disposition recorded | yes — 13 rows above |
| Task 1 targeted command exit code | `0` |
| `grep -c 'D-SSOT-08'` in DownloadInspection.swift | `1` (≥1 required) |
| `grep -c 'no download attempt ever failed'` in DownloadInspection.swift | `0`, as required |
| Composition hazard named and closed on the production path | yes — D5, basis asserted non-empty before `retryPages` |
| Boundary pinned from both sides (healthy-incomplete, other-code, error shape) | yes — D4 and D6 |
| No dead basis survives | `pendingPageIndices` deleted; the literal repo-wide grep matches only the unrelated execution-flow symbol, documented above |
| `grep -c 'completedPageCount'` in PublicAPIHelpers (key_link) | `1` (≥1 required) |
| `grep -c 'retryPages'` in DownloadInspection.swift (key_link) | `1` (≥1 required) |
| Full FeatureTests exit code / clean build lint | `0` / zero violations |
| Repair-preparation scan path untouched | yes — 4 files across both commits, none in that path |

## User Setup Required

None - no external service configuration required.

## Device Retest Input (15-UAT.md test 5)

**The expected observations CHANGE under this plan**, and the change is to the PRE-validate screen, so the owner's physical-device pass should be re-taken for the deletion half. Recorded alongside 15-56's and 15-58's:

1. Delete some page files of a completed gallery outside the app (e.g. 10 of 36), then open the inspector **without** tapping Validate. The pages now read **36 downloaded, 0 pending**, and the count matches the badge — where before the inspector sensed the deletion live and read 26/10 beside a badge saying 36/36. The deleted pages simply have no thumbnail. This stale-but-consistent reading is deliberate.
2. Tap **Validate**. It senses and durably reconciles: the pages become **pending**, both counts converge to 26 of 36, and **Resume** starts the repair. That is 15-56's behavior, now displayed from the one basis.
3. **Force-quit before resuming**, relaunch: the reconciled reading persists, because it was written to the manifest rather than held in the session.
4. Delete **every** page file, then tap Validate. The wholesale refusal still stands (the irreversibility defence), so the error surface remains and the record still claims its pages. On that screen the inspector's **retry** row is enabled and now sends the **whole page set**; tapping it starts the `.repair` run and the continued-session card climbs from the announce.
5. **New, worth checking explicitly:** on that same all-missing gallery the **Validate** row is now enabled too. Under the old basis it was greyed out — no page read `.downloaded`, so the gate that requires at least one closed — which meant the single sensor could not be reached from the screen that reports the problem.
6. A gallery with altered (not deleted) bytes behaves as 15-58 documented; nothing in this plan changes it.

## Next Phase Readiness

- G-15-SSOT is closed on the DISPLAY side as well as the record side: no page state anywhere derives from a live scan, the scan survives only as a reconciliation input behind Validate and as the repair run's own preparation, and the refusal family's start survives the basis change with a principled, non-leaking selection.
- Two undeclared-file prose residuals are open and recorded above with file and line (`DetailReducer.swift:112`'s superseded decision ID, and 15-58's `DetailDownloadRepairPredicateTests.swift` lines 13/52). Both are comment-only with no behavioral consequence.
- No blockers.

## Self-Check: PASSED

All four claimed source/test files exist on disk, and both task commits (`654a912e`, `ac6edbd8`) resolve in `git log`.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-09*
