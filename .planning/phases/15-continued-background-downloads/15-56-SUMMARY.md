---
phase: 15-continued-background-downloads
plan: 56
subsystem: downloads
tags: [download-manifest, validation, reconciliation, ssot, tca, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "D-G5-01's blanking loop (`reconcileWorkingManifestAgainstPageFiles`) with its three refusal lines, and D-G7-01's `withdrawingCountedBasisMovement` bracket"
provides:
  - "D-G5B-01: a `.missingFiles` validation verdict reconciles the persisted manifest through the one blanking loop, so the finding is durable and relaunch-stable"
  - "`validationErrors` narrowed to the refusal family's surface only, cleared whenever the record can state the finding itself"
  - "`reconcileWorkingManifestAgainstPageFiles` promoted to module-internal with its second caller named in-doc"
  - "A piecewise validate suite crossing the durable/refusal boundary with relaunch pinned on both sides, plus the validate-to-repair start arc on production entry points"
affects: [15-57, downloads-inspector, continued-session-accounting]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Validate-time reconciliation reuses the repair-preparation blanking loop verbatim rather than growing a second, laxer blanking rule"
    - "Piecewise regime suites: each arm asserts its own regime, neither borrows the other's expectations, both pin post-relaunch behavior"
    - "A blocker gallery parked on a named suspension point makes a queue-status assertion stable instead of momentarily true"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorStorageTests.swift

key-decisions:
  - "D-G5B-01: on a `.missingFiles` verdict, validation re-reads the disk manifest, takes one fresh `pageFileScan`, and runs the existing blanking loop inside `withdrawingCountedBasisMovement` — the finding lands in the manifest, not beside it"
  - "Blank from the scan's own evidence, never from validate's verdict: validate short-circuits at its first failing page, so its message names one page while the missing SET is what must be blanked"
  - "Clear `validationErrors` on the durable arm and keep it on every refusal — it outranks the manifest in `displayStatus`, so a leftover entry pins `.error` over an honest record and leaves it unstartable"
  - "A nil manifest probe at reconciliation time is treated as a refusal, not a fresh start: validate just proved the file readable, so failing now is a race with concurrent deletion — a non-answer, never authority to destroy hashes"
  - "The write-failure catch stays silent by design: a throw can only come from the loop's manifest write, which destroys nothing, and the caller records the transient entry — so the module's hash-masked log inventory is unchanged by the second caller"
  - "The arc test occupies the active slot with a blocker gallery parked on `BlockingRunnerControl.park()` rather than asserting `.queued` against a single-gallery inert runner, whose status races `.active`"

patterns-established:
  - "Evidence-shaped reconciliation: a scan classifies every page and licenses exactly the positively-absent ones; a verdict's first-failure message is never blanking authority"
  - "Contract docs name every caller of a shared destructive loop, because the caller list is what justifies which states remain reachable downstream"

requirements-completed: [SC2]

coverage:
  - id: D1
    description: "A missingFiles verdict durably blanks exactly the positively-absent pages, writes the manifest and updates the index, so the record honestly reads incomplete and the honesty survives relaunch"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift#testValidatingAPartiallyMissingGalleryBlanksExactlyTheMissingPagesOnDisk"
        status: pass
    human_judgment: false
  - id: D2
    description: "After a durable reconciliation no transient error outranks the record: validationErrors is cleared, displayStatus derives .inactive, Resume enables through canTogglePause and resumeMode resolves .repair"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift#testValidatingAPartiallyMissingGalleryBlanksExactlyTheMissingPagesOnDisk"
        status: pass
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift#testAReconciledRecordResumesThroughTogglePauseIntoAQueuedRepair"
        status: pass
    human_judgment: false
  - id: D3
    description: "The refusal family keeps today's transient surface: a wholesale blanking is refused, the session error stands and the on-disk hashes are proven untouched"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift#testWholesaleBlankingIsRefusedSoTheSessionErrorStandsAndTheClaimedHashSurvives"
        status: pass
    human_judgment: false
  - id: D4
    description: "Device retest of 15-UAT.md test 5: after Validate marks missing pages the gallery reads incomplete (e.g. 26/36) with Resume enabled, Resume starts the .repair run, and a force-quit before resuming preserves both the incomplete reading and the enabled Resume"
    verification: []
    human_judgment: true
    rationale: "Relaunch-across-force-quit on a physical device, and the inspector's rendered count and enabled Resume affordance, cannot be observed from the client seam a unit test reaches."

# Metrics
duration: 135min
completed: 2026-08-09
status: complete
---

# Phase 15 Plan 56: Validation Reconciles the Record It Judged Summary

**A `.missingFiles` verdict now blanks exactly the missing pages in the persisted manifest through the one D-G5-01 blanking loop, so the badge count, the display status, the start gates and `resumeMode` all read a single durable truth that survives relaunch — and the refusal family keeps the transient `validationErrors` surface it always had.**

## Performance

- **Duration:** ~135 min of active execution (spread across three sessions: two plan-correction checkpoints and one transport interruption)
- **Started:** 2026-08-09T05:05:00Z
- **Completed:** 2026-08-09T11:25:00Z
- **Tasks:** 2
- **Files modified:** 6 (1 created, 5 modified)

## Accomplishments

- **The root fix, with no new machinery.** `validateImageData` now re-reads the disk manifest, takes one fresh `storage.pageFileScan`, and runs `reconcileWorkingManifestAgainstPageFiles` inside `withdrawingCountedBasisMovement(gid:)`. When the loop blanks, the record itself says the gallery is incomplete: `displayStatus` falls through to `.inactive`, `canTogglePause` accepts it, `resumeMode` resolves `.repair` through its existing `isIncomplete` branch, and the manifest write plus `updateDownloadIndex` make all of it survive a relaunch.
- **The hazard the diagnosis flagged, closed explicitly.** `validationErrors` outranks the queue and the manifest in `displayStatus`, so the durable arm clears the entry. Left behind, it would pin `.error` over an honest record and keep it unstartable — which is exactly the defect being fixed.
- **The blanking evidence is a scan, not a verdict.** `storage.validate` returns at its FIRST failing page, so its message names one page; the scan classifies every page. A partially-missing gallery therefore blanks its whole missing set regardless of which page validate happened to report.
- **The irreversibility defence is inherited verbatim.** The loop is shared, not duplicated (one declaration, two callers): a failed scan, an unprobed page, and the all-or-nothing wholesale shape all refuse at validate time exactly as they refuse at repair-preparation time.
- **Contract docs now match the code in all four places they were stated:** `validateImageData`, the `validationErrors` property, the blanking loop's own gap reference (disambiguated to G-15-5's run-time half, cross-referencing D-G5B-01), and `resumeMode`'s blanker enumeration and case-(b) predicate.

## Task Commits

Each task was committed atomically:

1. **Task 1: The durable arm — piecewise suite first, then the reconciliation** - `45bd2ba9` (feat)
2. **Task 2: The start arc — from the durable verdict to a queued repair, production path** - `99ec1b19` (test)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift` - D-G5B-01's durable arm in `validateImageData` plus the private `reconcileValidatedRecordAgainstPageFiles` helper (fresh scan, bracket, nil-probe-as-refusal); the validation contract doc rewritten.
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` - `reconcileWorkingManifestAgainstPageFiles` promoted from `private` to module-internal, its doc extended with the second caller and why the name still holds, and its gap reference disambiguated to the run-time half of G-15-5.
- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` - `validationErrors` documented as the refusal surface only, with the outranking hazard stated as the reason clearing is load-bearing.
- `AppPackage/Sources/DownloadClient/DownloadClient+SchedulingHelpers.swift` - `resumeMode`'s "Near-dead after D-G5-01" comment corrected: the enumeration names both callers of the one blanking loop, case (a) is caller-agnostic, and case (b)'s predicate is "neither preparation nor validation has blanked anything this session". The branch itself is untouched.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadValidationReconciliationTests.swift` - **New.** The piecewise regime suite: durable arm, refusal arm, and the start arc.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorStorageTests.swift` - The validation case relocated out (994 → 965 lines against a 1000-line `file_length` limit at error severity), with a pointer comment left in its place.

## Decisions Made

- **Blank from the scan, never from the verdict.** Recorded above; this is what makes the fix evidence-shaped rather than message-shaped.
- **Clear-on-durable, keep-on-refusal.** The two arms write to `validationErrors` in opposite directions on purpose, because the record can speak for one family and cannot speak for the other.
- **A nil manifest probe is a refusal.** Validation had just proved that file readable, so a nil here is a race with concurrent deletion — a non-answer, and the positive-signal rule forbids treating a non-answer as authority.
- **The write-failure catch is deliberately silent, with the reason written in the code.** A throw can only originate in the loop's manifest write, which leaves the record claiming exactly what it claimed, so nothing was destroyed and the caller's transient entry is the honest surface. This also keeps the plan's stated verification true — the second caller introduces no new log content.
- **Q2 form used: option (a), the blocker-gallery form** (not the fallback). Recorded here as the plan requires. The runner double suspends at a named point — `BlockingRunnerControl.park()`'s `withCheckedContinuation`, resumed only by `release()` in teardown — and the arc awaits `control.started()` before asserting, so the blocker's occupancy is a production-issued fact rather than an assumption. `scheduleNextIfNeededCore`'s `activeTask == nil` guard then refuses every promotion, which is what makes the target's `.queued` stable indefinitely rather than momentarily true. The fallback was not needed because the suite's existing control can genuinely suspend.

## Dispositioned Residuals

Both are decisions, not misses:

1. **The wholesale-refusal relaunch reading.** A gallery whose every claimed page is positively absent still refuses, so after relaunch that record reads `.completed` until the user validates again. That is the irreversibility defence working as designed — the loop cannot distinguish "all 36 deleted" from a listing shape neither per-page signal explains — it is re-diagnosable in one tap, and its in-session start affordance is plan 15-57's widened inspector retry. The refusal arm pins the on-disk hashes intact AND this post-relaunch `.completed` reading, with a comment naming it.
2. **Corrupt-in-place stays on the refusal surface.** A page whose file exists but whose bytes mismatch is not blankable: a presence scan cannot license destroying the hash of a file that exists. It keeps `.error` plus a re-runnable Validate, and Detail's destructive redownload remains its honest medicine (15-57's predicate concern).

## Falsifiability Record (banked pre-fix evidence)

Required by the plan's acceptance criteria, captured against pre-fix production with the suite already written:

- **The refusal arm PASSED pre-fix** (0.052s). That is the boundary evidence: the wholesale shape's behavior is unchanged by this plan.
- **The durable arm FAILED pre-fix with 8 issues**, verbatim:
  - `(download.displayStatus → .error) == .inactive`
  - `(download.lastError → DownloadFailure(code: .fileOperationFailed, message: "Page 2 is missing.")) == nil`
  - `(download.completedPageCount → 3) == 2`
  - `(diskManifest.pages[2] → "sha256:done") == ""`
  - `(diskManifest.completedPageCount → 3) == 2`
  - `(reread.displayStatus → .completed) == .inactive`
  - `(reread.completedPageCount → 3) == 2`
  - `reread.canTogglePause → false`
- **`validation == .missingFiles(downloadStorePageMissing(page: 2))` PASSED pre-fix** while the record stayed untouched — the precise shape of the gap: validate reports the missing set's first member and mutates nothing.

## Deviations from Plan

None — the plan was executed exactly as written, after two plan-correction rounds resolved the conflicts BEFORE any code was written or committed (see below). No deviation rule was invoked.

One self-correction inside Task 1 is worth recording because it was mine, not the plan's: an initial draft added a `logger.error` line to the reconciliation's catch block. The full suite surfaced it immediately as `DownloadLogPrivacyInvariantTests.testDownloadIdentityLogsStayHashMasked` (the scanned hash-masked inventory moved from 10 to 11, with `DownloadClient+PersistenceNormalize.swift: 1` appearing). The plan's verification explicitly states the second caller adds no new log content, so the added line was removed rather than the inventory table being edited — which also avoided touching an undeclared test file. The catch now carries a comment explaining why silence is correct there.

## Plan-Correction Rounds

Two DECISION CHECKPOINTs were raised and answered before any commit; both produced real plan fixes, landed in `19d463d8`.

1. **Undeclared conditional file (Task 1, Step 2).** The action ordered an edit to `resumeMode`'s comment in `DownloadClient+SchedulingHelpers.swift` "IF its wording is now wrong", while neither `files_modified` nor Task 1's `<files>` declared that file. Proof that the condition fires was supplied: line 51 enumerated a single blanker, and case (b)'s predicate "no preparation has touched the record this session" would, post-fix, wrongly sort a validated-and-refused record into (b) instead of (a). **Resolution:** the file is now declared in both places and the instruction is unconditional, carrying both truth-fixes. This is the same defect class the planner had just fixed for 15-55 in `1ca32386`.
2. **A raced status assertion (Task 2).** The arc originally asserted `displayStatus == .queued` after `togglePause` on a single-gallery fixture with an inert runner. Derivation from production: `togglePause` → `resume` → `scheduleNextIfNeeded` assigns `activeGalleryID` before returning, and `displayStatus` checks `activeGalleryID` ahead of queue membership, so the status reads `.active` until `finishActiveTaskIfOwned` nils it on a later actor turn. **Resolution:** the plan now mandates the blocker-gallery form with a NAMED suspension point the double can actually reach, with an intent-only fallback recorded. This was the third instance this round of a test keyed on a value whose derivation basis was still moving.

## Issues Encountered

- **The suite gate's fixture had to align recorded hashes with real bytes.** Content validation compares each recorded hash against the file on disk, so a surviving page carrying the fixture's placeholder hash would have been reported corrupted and short-circuited the verdict before it reached the genuinely missing page. The durable arm writes real page files through the existing `writePageFiles` helper and then aligns pages 1 and 3 via the production `refreshManifestPageFileHashes`, which is what makes page 2 the thing under test.
- **A transport interruption cut a verification run mid-flight.** The gate was re-run from scratch rather than trusting the interrupted claim; it passed independently before anything was committed.

## Verification

- Task 1 gate — `-only-testing:DownloadsFeatureTests/DownloadValidationReconciliationTests`: **passed**, re-run independently after the interruption.
- Task 2 gate — full `FeatureTests` plan: **`** TEST SUCCEEDED **`**, 381 tests in 69 suites in the downloads target (+1 from the arc case), zero failures. `DownloadLogPrivacyInvariantTests` green in the same run, confirming the second caller introduces no new log content.
- Clean app-scheme build: **`** BUILD SUCCEEDED **`**, no `warning:`/`error:` lines. SwiftLint over all six touched files with the repository config in `--strict` mode: **0 violations, 0 serious**. No `swiftlint:disable`, no `@unchecked Sendable`, no `@preconcurrency`, no `nonisolated(unsafe)` anywhere in the phase source.

## Acceptance Criteria

| Criterion | Result |
|---|---|
| `grep -c 'func reconcileWorkingManifestAgainstPageFiles'` in ExecutionSupport | `1` — shared, not duplicated |
| `grep -rc 'reconcileWorkingManifestAgainstPageFiles'` in PersistenceNormalize | `1` (≥1 required) |
| `grep -c 'withdrawingCountedBasisMovement'` in PersistenceNormalize | `2` (≥1 required) |
| `grep -c 'D-G5B-01'` in PersistenceNormalize | `2` (≥1 required) |
| `grep -rn 'not persisted'` in PersistenceNormalize | no output, as required |
| `grep -c 'ValidateIndexedMissingFile'` in DownloadCoordinatorStorageTests | `0` |
| `wc -l` DownloadCoordinatorStorageTests | `965` (< 1000) |
| `grep -c 'togglePause'` in the new suite | `4` (≥1 required) |
| Durable arm pins disk truth + second-coordinator `.inactive` and `resumeMode == .repair` | yes |
| Refusal arm pins hashes intact + post-relaunch `.completed` residual with a naming comment | yes |
| Falsifiability recorded in this summary | yes, verbatim above |

## User Setup Required

None - no external service configuration required.

## Device Retest Input (15-UAT.md test 5)

For the owner's physical-device pass, the expected observation after this plan:

1. Delete some page files of a completed gallery outside the app (e.g. 10 of 36), then tap **Validate** in the inspector.
2. The toast still reports the missing-files verdict, and the gallery now reads **incomplete** (26/36) with **Resume enabled** — not the previous yellow error state over a 36/36 claim.
3. **Resume** starts the run, and it resolves `.repair` (existing pages are kept; only the missing ones are fetched).
4. **Force-quit before resuming**, relaunch: the incomplete reading and the enabled Resume both persist, and the badge's count agrees with the inspector's live file scan.
5. The deliberate exception to observe: deleting **every** page of a gallery and validating still shows the error state and still reads `.completed` after relaunch. That is the documented irreversibility defence, not a regression.

## Next Phase Readiness

- 15-57 inherits a narrowed problem: only the refusal family (failed scan, unprobed pages, wholesale absence) and corrupt-in-place now lack an in-session start affordance, and both are documented above with their reasons.
- `resumeMode`'s `storage.validate` branch is shrunk but still load-bearing for exactly the two states enumerated in its corrected comment; it was deliberately left in place.
- No blockers.

## Self-Check: PASSED

All six claimed source/test files exist on disk, and all three commits (`45bd2ba9`, `99ec1b19`, `b56feb58`) resolve in `git log`.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-09*
