---
phase: 15-continued-background-downloads
plan: 57
subsystem: downloads
tags: [download-manifest, affordances, inspector, detail, tca, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-56's D-G5B-01 durable arm, which narrowed `validationErrors` to the refusal family and left exactly that family on the `.error` surface"
  - phase: 15-continued-background-downloads
    provides: "`retryPages(gid:pageIndices:)` / `performRetryPages` — the repair-starter that clears the failure state (including `validationErrors`), pins `.repair` with an explicit page selection, enqueues and schedules"
provides:
  - "D-G5C-01: `DownloadInspection.retryablePageIndices`, one widened page basis read by both the inspector's enabled-state gate and its send"
  - "`canRetryPages` replacing the failed-only gate, so the button can never enable an empty selection"
  - "D-G5D-01: `DetailReducer.State.downloadNeedsRepair` on the record's honesty (`completedPageCount < pageCount`), with the complete-claiming boundary documented at the site"
  - "The dead row-retry predicate deleted from the download support types"
affects: [downloads-inspector, detail-error-affordance, 15-verification-round-19]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "One computed basis feeds both a gate and its action, so an enabled control can never send an empty payload"
    - "An affordance whose payload travels explicitly is independent of the record's claims, which is what makes it work for records that cannot speak for themselves"
    - "Predicate truth tables pinned on BOTH sides of the conjunct that moved, not only at the extremes"

key-files:
  created:
    - AppPackage/Tests/DetailFeatureTests/DetailDownloadRepairPredicateTests.swift
  modified:
    - AppPackage/Sources/AppModels/Download/DownloadInspection.swift
    - AppPackage/Sources/AppModels/Download/DownloadedGallery+SupportTypes.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift
    - AppPackage/Sources/DetailFeature/DetailReducer.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift

key-decisions:
  - "D-G5C-01: the retry basis is the failed set unioned with the pending set exactly when `displayStatus == .error && lastError?.code == .fileOperationFailed`, and the failed set alone everywhere else"
  - "The widening is bounded by that conjunction on purpose: outside it, pending pages are what Resume exists for, and admitting them would grow a second page-selection-shaped resume"
  - "D-G5D-01: Detail offers `.repair` whenever the record honestly reads incomplete beside a file-shaped failure; a complete-claiming `.error` record keeps the destructive `.redownload`, because a presence-based repair fixes neither an unverifiable claim nor a corrupt-in-place file"
  - "The retry button's localized label is unchanged and no catalog key was added — the gap demanded a working start, not copy, and a label rename fans out across every locale"
  - "The dead row-retry predicate was deleted rather than wired to a consumer; it is not named in any new comment"

patterns-established:
  - "Gate-and-payload from one property: `canRetryPages` is defined as the non-emptiness of the very array the button sends"
  - "Boundary pins from both sides: the widened regime and each excluded regime get their own case, so a widening cannot silently spread"

requirements-completed: [SC2]

coverage:
  - id: D1
    description: "The widened basis unions pending pages for the .error/fileOperationFailed shape and stays failed-only everywhere else, with canRetryPages true exactly when the basis is non-empty"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift#testTheRetryBasisUnionsPendingPagesForTheFileFailureErrorShape"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift#testTheRetryBasisStaysFailedOnlyForAnErrorWithADifferentFailureCode"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift#testTheRetryBasisStaysFailedOnlyForANonErrorDownloadWithPendingPages"
        status: pass
    human_judgment: false
  - id: D2
    description: "A refusal-family record (complete-claiming, all files gone, transient error surviving validation) starts through retryPages: the enqueue is not outranked, so displayStatus reads .queued, the intent resolves .repair and the page selection carries the requested indices"
    requirement: SC2
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift#testRetryingThePendingPagesOfARefusedRecordQueuesARepair"
        status: pass
    human_judgment: false
  - id: D3
    description: "The all-missing shape makes the whole page set retryable on a record that reports zero failed pages"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift#testTheAllMissingShapeMakesTheWholePageSetRetryable"
        status: pass
    human_judgment: false
  - id: D4
    description: "downloadNeedsRepair truth table under D-G5D-01, including both boundary rows (26-of-36 true, 36-of-36 false)"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DetailFeatureTests/DetailDownloadRepairPredicateTests.swift#testAPartiallyCompletedFileFailureOffersTheRepair"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DetailFeatureTests/DetailDownloadRepairPredicateTests.swift#testACompleteClaimingFileFailureKeepsTheDestructiveRedownload"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DetailFeatureTests/DetailDownloadRepairPredicateTests.swift#testAZeroCompletedFileFailureOffersTheRepair"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DetailFeatureTests/DetailDownloadRepairPredicateTests.swift#testAnIncompleteRecordUnderANonFileFailureKeepsTheDestructiveRedownload"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DetailFeatureTests/DetailDownloadRepairPredicateTests.swift#testANonErrorRecordNeverOffersTheRepair"
        status: pass
    human_judgment: false
  - id: D5
    description: "Device retest of 15-UAT.md test 5: for an all-pages-missing gallery, Validate still shows the error surface, but the inspector's retry action is ENABLED and starts the .repair run whose card climbs from the announce"
    verification: []
    human_judgment: true
    rationale: "The inspector's rendered enabled/disabled state and the live progress card on a physical device cannot be observed from the client seam a unit test reaches."

# Metrics
duration: 30min
completed: 2026-08-09
status: complete
---

# Phase 15 Plan 57: The Refusal Family Gets Its Start Summary

**Every remaining unstartable validated shape now has a start: the inspector's retry sends the failed pages unioned with the pending ones for exactly the `.error`/fileOperationFailed shape (D-G5C-01), Detail's error button offers the non-destructive repair whenever the record honestly reads incomplete (D-G5D-01), and the gating predicate with no consumers is gone.**

## Performance

- **Duration:** ~30 min of active execution
- **Started:** 2026-08-09T02:28:00Z
- **Completed:** 2026-08-09T02:58:00Z
- **Tasks:** 2
- **Files modified:** 7 (1 created, 6 modified)

## Accomplishments

- **The dead end became a start button, with no new machinery.** `retryPages(gid:pageIndices:)` already cleared the failure state, pinned `.repair` with a page selection, enqueued and scheduled. The inspector was simply sending it the wrong set: externally-deleted pages derive `.pending`, never `.failed`, so a failed-only basis reported nothing for a gallery whose files are gone, and the one enabled action for the refusal family was Validate — which only re-reports itself.
- **The widening is bounded by a conjunction, and both sides are pinned.** `retryablePageIndices` unions the pending pages only at `.error` with a fileOperationFailed code. A networking-shaped error keeps the failed-only basis; a paused gallery keeps it too, and with no failed pages the gate closes rather than offering a second, page-selection-shaped resume.
- **The outranking hazard is asserted on the production path.** `validationErrors` sits ahead of both `activeGalleryID` and queue membership in `displayStatus`, so `.queued` after the retry is reachable only if the entry was cleared at enqueue. The arc drives a real refusal fixture (complete-claiming record, all files gone, `validateImageData` run to install the transient error) through `retryPages` and pins `.queued`, `lastError == nil`, `queuedMode == .repair` and the carried selection `[1, 2]`.
- **Detail's predicate now reads a condition that can hold when a user faces the button.** The old `completedPageCount == 0` conjunct held only AFTER a repair run's blanking loop had already emptied the record, so a mid-run file failure with 26 of 36 pages landed routed to the destructive redownload as its only option. The swept case is a strict superset: zero-completed records satisfy `completedPageCount < pageCount` trivially.
- **The complete-claiming boundary is a documented decision, not an omission.** A record that still claims every page is either wholesale-unverifiable (the refusal family) or corrupt-in-place, and a presence-based repair finds nothing absent to fetch. `.redownload` stays, and the rationale plus the pointer to D-G5C-01's surgical alternative is written on the property.
- **One basis, two consumers, zero orphans.** `canRetryPages` is defined as the non-emptiness of the very array the button sends, so the gate cannot enable an empty selection. The unconsumed row-retry predicate was deleted outright.

## Task Commits

Each task was committed atomically:

1. **Task 1: The widened retry basis, from the model through the button to the queued repair** - `fbbf384f` (feat)
2. **Task 2: Detail's honest-incomplete predicate, and the dead predicate's deletion** - `cb4c73d7` (fix)

## Files Created/Modified

- `AppPackage/Sources/AppModels/Download/DownloadInspection.swift` - `pendingPageIndices` beside `failedPageIndices`, and `retryablePageIndices` implementing D-G5C-01 with the WHY on it: why deleted pages derive `.pending`, why `.error` closes Resume, and why the widening must stop at that conjunction.
- `AppPackage/Sources/AppModels/Download/DownloadedGallery+SupportTypes.swift` - the failed-only gate replaced by `canRetryPages` reading the widened basis; the dead row-retry predicate deleted.
- `AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift` - the retry button's disabled state driven by `canRetryPages` and its send by `inspection.retryablePageIndices`. The localized label and every other action are untouched.
- `AppPackage/Sources/DetailFeature/DetailReducer.swift` - `downloadNeedsRepair`'s zero-completed conjunct replaced by `completedPageCount < pageCount`, with a new doc stating D-G5D-01 and the complete-claiming boundary's reasoning.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift` - the production-path refusal arc plus four basis cases (union regime, other-code boundary, non-error boundary with and without a failed page, all-missing shape) and a `basisInspection` helper.
- `AppPackage/Tests/DetailFeatureTests/DetailDownloadRepairPredicateTests.swift` - **New.** The five-row `downloadNeedsRepair` truth table.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionBasisTests.swift` - the doc comment that argued from the old zero-completed conjunct, re-derived (see below).

## Decisions Made

- **D-G5C-01 and D-G5D-01** as recorded above; both are implemented exactly as the plan specified them, and both carry their rationale at the source site rather than only in planning artifacts.
- **The retry label is left alone, and this is deliberate.** The gap's truth demanded a working start affordance, not copy. A label rename fans out across every catalog locale and is reversible in isolation, so it is left as a one-key follow-up **for the owner**: if the button should name missing pages as well as failed ones, that is a single catalog change with no behavioral consequence.
- **The basis tests live in `DownloadRetryPagesTests`, on the plan's own fallback branch.** The plan directed them beside existing `DownloadInspection` computed-property tests if any existed. A grep for the failed-indices property found only two READS of it inside `DownloadBackgroundCompletionTests`, where it is an observation instrument for background-failure handling rather than a test of the property. No dedicated computed-property suite exists, so the fallback applied — which is also the only placement under which Task 1's declared file set closes over its `-only-testing:DownloadsFeatureTests/DownloadRetryPagesTests` gate.
- **The arc uses the blocker-gallery form** established by 15-56: a second gallery holds the active slot, its runner double parked on `BlockingRunnerControl.park()`'s `withCheckedContinuation` and released only in teardown, with `control.started()` awaited before any assertion. Without it, `scheduleNextIfNeeded` would assign `activeGalleryID` to the target before returning and `displayStatus` — which reads `activeGalleryID` ahead of queue membership — would answer `.active`, making the `.queued` pin a race. This is the same hazard class that produced 15-56's second plan correction.

## Re-derivation of the Basis-Suite Comment (Task 2, Step 4)

`DownloadContinuedSessionBasisTests.swift` justified staging a `.redownload` for a 4-of-6 errored record by arguing that `downloadNeedsRepair` requires `completedPageCount == 0`, "so an errored gallery with ANY downloaded page fails that guard and the button resolves `.redownload`."

Under D-G5D-01 that premise is false: a 4-of-6 record now SATISFIES the completed-count conjunct. The claim survives on the other conjunct instead. `downloadNeedsRepair` is a conjunction of three facts, and the failure code is the one that still excludes this staging: an errored gallery whose failure is networking-shaped — the ordinary interruption, and the one the fixture models — resolves `.redownload` however many pages it has already landed. The comment now says exactly that.

**The scenario itself did not change meaning and was not touched.** Everything the case actually measures — a `.redownload` payload wiping a counted 4-of-6 basis, D-G4-01's raw counting of an `isIncomplete` record, the floor opening at C, the honest one-time dip and the never-loses-ground series — is unaffected by which conjunct closes the `.repair` door. Only the sentence naming that conjunct moved. The surrounding paragraph's contrast with the ledger suite's vacuous 6-of-6 cases is likewise untouched and still holds.

## Falsifiability Record (banked pre-fix evidence)

- **The arc case PASSED pre-fix**, at the client layer, in 0.089s — with the widened-basis assertions not yet present. This is the plan's anticipated outcome and it is worth stating plainly: **the client machinery was never the defect.** `retryPages` already accepted an arbitrary page selection, already cleared `validationErrors` at enqueue, and already resolved `.repair` for a refused record. The affordance wiring was the whole gap — the inspector hardcoded a set that is empty for exactly the family that needed it.
- **The basis cases were RED as a compile failure**, verbatim: `value of type 'DownloadInspection' has no member 'retryablePageIndices'` and `... has no member 'canRetryPages'`, at 12 sites.
- **The D-G5D-01 truth table's swept row FAILED pre-fix and the other four passed**, which is the precise shape of the predicate defect. Verbatim failure: `testAPartiallyCompletedFileFailureOffersTheRepair` recorded `state.downloadNeedsRepair → false` on a badge of `status: .error, progress: (completedPageCount: 26, pageCount: 36)` with `downloadFailureCode: .fileOperationFailed`. The 0-of-36, 36-of-36, non-file-code and non-error rows all passed pre-fix, so the change is provably confined to the swept row.

## Deviations from Plan

None — the plan was executed exactly as written. No deviation rule was invoked, and no DECISION CHECKPOINT was needed: every instruction resolved against the real post-15-56 source, including the two clauses that read like conditionals (the basis-test placement, which took the plan's own stated fallback, and the basis-suite comment, whose claim did change and was re-derived rather than merely reworded).

One process note, not a deviation: Task 1's Step 1 was executed as two edits so the arc's pre-fix status could be observed cleanly. The arc was added and the targeted gate run first — banking the PASS above — and the basis cases plus the arc's two basis assertions were added second, producing the compile-failure RED. Both edits are Step 1's work; the split exists only because a single edit would have made the whole target uncompilable and destroyed the observation the plan explicitly asks to be recorded.

## Issues Encountered

None. No fix attempts, no out-of-scope discoveries, no deferred items.

## Verification

- Task 1 gate — `-only-testing:DownloadsFeatureTests/DownloadRetryPagesTests`: **`** TEST SUCCEEDED **`**, 7 tests in 1 suite, zero failures.
- Task 2 gate — full `FeatureTests` plan: **`** TEST SUCCEEDED **`**. Downloads target 386 tests in 69 suites (+5 from 15-56's 381), every target green, zero failures.
- Clean app-scheme build: **`** BUILD SUCCEEDED **`**, no `warning:` or `error:` lines.
- SwiftLint over all seven touched files with the repository config in `--strict` mode: **0 violations, 0 serious**. The app-scheme build does not lint `Tests/`, so the test files were linted explicitly with the standalone binary.
- No `swiftlint:disable`, no `@unchecked Sendable`, no `@preconcurrency`, no `nonisolated(unsafe)` anywhere in the phase source.

## Acceptance Criteria

| Criterion | Result |
|---|---|
| `grep -c 'retryablePageIndices'` in DownloadInspection.swift | `1` (≥1 required) |
| `grep -c 'retryablePageIndices'` in DownloadsView+Subviews.swift | `1` (≥1 required) |
| `grep -c 'canRetryPages'` in DownloadsView+Subviews.swift | `1` (≥1 required) |
| `grep -rn 'canRetryFailedPages' AppPackage/Sources` | no output, as required |
| Arc asserts `.queued` after `retryPages` on a fixture that first ran `validateImageData` | yes |
| Boundary pinned from both sides (non-error → failed-only; `.error`/fileOperationFailed → union) | yes |
| Task 1 targeted command exit code | `0` |
| `grep -c 'completedPageCount < '` in DetailReducer.swift | `1` (≥1 required) |
| `grep -c 'D-G5D-01'` in DetailReducer.swift | `1` (≥1 required) |
| Truth table pinned with both boundary rows, RED row recorded above | yes |
| `grep -rn 'var canRetry:' AppPackage/Sources` | no output, as required |
| Basis-suite comment no longer argues from the zero-completed conjunct | yes, re-derivation recorded above |
| Full FeatureTests exit code / clean build lint | `0` / zero violations |
| Label and catalog untouched | yes — `.retryFailedPages` unchanged, no catalog file modified |

## User Setup Required

None - no external service configuration required.

## Device Retest Input (15-UAT.md test 5)

For the owner's physical-device pass, alongside 15-56's steps, the expected observation after this plan:

1. Delete **every** page file of a completed gallery outside the app, then tap **Validate** in the inspector. As 15-56 documented, the error surface is still shown and the record still claims its pages — the irreversibility defence, unchanged.
2. **New:** the inspector's retry action is now **enabled** on that screen, where before it was greyed out with nothing to send.
3. Tapping it starts a `.repair` run for the whole page set, and the continued-session card climbs from the announce rather than sitting at the record's stale claim.
4. On a gallery with SOME pages deleted whose validation refused for a different reason, the same action is enabled and sends the missing set only.
5. In **Detail**, a gallery that errored mid-run with pages already on disk (e.g. 26 of 36) now shows the **repair** affordance — the wrench, and the repair confirmation — instead of the destructive redownload. A gallery whose record still claims every page keeps offering the redownload; that is the deliberate boundary, and the inspector's retry is the surgical route for it.

## Next Phase Readiness

- G-15-5 has no unstartable shape left: durable-arm records resume (15-56), refusal-family records retry through the widened basis, and Detail's error button offers repair exactly where repair preserves work.
- Open for the owner, non-blocking: whether the retry button's label should name missing pages as well as failed ones (one catalog key, no behavior change).
- No blockers.

## Self-Check: PASSED

All seven claimed source/test files exist on disk, and both task commits (`fbbf384f`, `cb4c73d7`) resolve in `git log`.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-09*
</content>
</invoke>
