---
phase: 15-continued-background-downloads
plan: 60
subsystem: downloads
tags: [download-manifest, ssot, property-testing, generated-family, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-59's one display basis (D-SSOT-07/08) — the state whose agreement this suite asserts over"
  - phase: 15-continued-background-downloads
    provides: "15-58's content arm and operation-level-only `validationErrors` (D-SSOT-01..05) — the durable/refusal boundary the family crosses"
  - phase: 15-continued-background-downloads
    provides: "15-57's widened inspector retry (D-SSOT-08 basis) — the forward affordance the refusal regime is driven through"
  - phase: 15-continued-background-downloads
    provides: "15-56's durable validate-time reconciliation (D-G5B-01) — the sensor the totality family runs after each probe"
provides:
  - "D-SSOT-09: the run-owned measured session series is scoped OUT of the record-completeness families, and the exclusion is structural (every fixture uses a noop background client)"
  - "`DownloadManifestSSOTInvariantTests` — three property families over a 9-case generated state family, 27 case instances"
  - "A standing falsifier for `live scans are reconciliation inputs, never a competing display basis`, proven by external mutation plus a full production rescan rather than by reading the code"
  - "A standing falsifier for no-dead-end, enforced by DRIVING production entry points to `.queued` rather than by reading predicates"
affects: [15-verification-round-19, downloads-inspector, downloads-regression-surface]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Assert the PROPERTY over a named generated family, and carry the per-regime expected VALUE in the table: agreement alone is satisfied by a derivation that returns zero everywhere, and per-case values alone say nothing about a shared basis"
    - "Make an invariance claim falsifiable by pinning the mutation's own observability from the other side — otherwise a mutation that silently failed passes the invariance vacuously"
    - "Exclude a quantity structurally rather than by prose: a noop client makes the run-owned series unobservable, so no future edit can start asserting on it by accident"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift
  modified:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift

key-decisions:
  - "D-SSOT-09: record-completeness displays only; the continued-processing card's X/Y series is a different quantity by design and is excluded, structurally as well as in doc"
  - "The generated family is a named table, not randomness — reproducibility beats volume for a standing falsifier, and a failing case must be re-runnable exactly"
  - "Expected values are carried per case rather than derived: a property suite whose expectations were themselves derived would be comparing a derivation with itself"
  - "The external-mutation probe runs a FULL production rescan (`reloadDownloadIndex`) before re-reading, which is the strongest form of the clause rather than a passive re-read"
  - "The snapshot carries `lastError.code`, not the whole `DownloadFailure`: the message is the operation's own report of what a pass found and legitimately moves when a pass is re-run"
  - "The blocker gallery parks on `BlockingRunnerControl.park()` in EVERY staging, so a driven `.queued` is stable rather than momentarily true"
  - "The shared fixture builders were extracted onto `DownloadFeatureTestHelpers.swift` rather than duplicated a third time"

patterns-established:
  - "A property family's header names the AGENTS.md clause it enforces, so a reader knows which invariant a failure falsifies"
  - "Keep an affordance arm no current case reaches when the property is about the state space rather than the table — a future state that can only sense its way out must find the arm already there"

requirements-completed: [SC2]

coverage:
  - id: D1
    description: "Count-basis agreement over the whole generated family, in-session and on a fresh coordinator: badge numerator, rendered numerator, inspector downloaded set, inspector header, Validate gate basis and resume-mode basis are one manifest-derived value in every regime"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift#testEveryDisplayedCompletenessQuantityIsTheSameManifestDerivedValue"
        status: pass
    human_judgment: false
  - id: D2
    description: "Derivation totality by probe: an external delete/corrupt/plant plus a full production rescan moves no displayed quantity, no displayStatus and no affordance predicate, while the rendering resource does follow the disk"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift#testAnExternalFilesystemMutationMovesNothingDisplayedUntilValidateSensesIt"
        status: pass
    human_judgment: false
  - id: D3
    description: "The sensor's boundary pinned from both sides: where the Validate gate is open the state moves to the regime 15-58's rules predict (reconciled or refused), and where it is closed the state does not move at all"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift#testAnExternalFilesystemMutationMovesNothingDisplayedUntilValidateSensesIt"
        status: pass
    human_judgment: false
  - id: D4
    description: "No dead end, enforced by driving: every non-terminal incomplete generated state reaches `.queued` through a production entry point under the mode its shape predicts, with the retry's carried selection asserted"
    requirement: SC2
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift#testEveryNonTerminalIncompleteStateKeepsAForwardAffordanceThatSucceeds"
        status: pass
    human_judgment: false
  - id: D5
    description: "The terminal negative boundary from the other side: a record claiming every page offers no resume-shaped start, `togglePause` refuses it at the production entry point, and the single sensor stays reachable"
    requirement: SC2
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift#testEveryNonTerminalIncompleteStateKeepsAForwardAffordanceThatSucceeds"
        status: pass
    human_judgment: false

# Metrics
duration: 23min
completed: 2026-08-09
status: complete
---

# Phase 15 Plan 60: The SSOT Invariant as a Standing Falsifier Summary

**The manifest-SSOT clause is now executable rather than only written down: over a named family of nine record states crossing every regime phase 15 established, every displayed completeness quantity is asserted to be one manifest-derived value, derivation totality is proven by mutating the filesystem behind the app's back and running a full production rescan, and no non-terminal incomplete state is allowed to lack a forward affordance that actually reaches `.queued` when driven.**

## Performance

- **Duration:** ~32 min of active execution
- **Started:** 2026-08-09T05:15:00Z
- **Completed:** 2026-08-09T05:47:00Z
- **Tasks:** 2 (plus one post-gate naming correction, re-verified)
- **Files modified:** 2 (1 created, 1 modified)

## The Headline: The Suite Found Nothing, Against Unmodified Production

**All 27 case instances passed against post-15-59 production with zero source changes**, and that is a result rather than an absence of one. The families were written to falsify, and each was run before any expectation was tuned: no assertion was weakened to make a case pass, no regime was dropped, and no production file was touched by either commit (`git show --stat` lists two test files across both). This is evidence about 15-55..15-59 — the properties they were built to establish hold over a state space none of them individually enumerated.

Concretely, the suite would have caught G-15-5 in three independent places had it existed then: family 1 would have failed on `completeClaimWithMissingFilesNeverValidated` (badge 3, page list 2), family 2 would have failed the moment a status probe consulted the disk, and family 3 would have failed on the refusal regime with an empty retry basis. It also re-derives 15-59's own composition hazard as a live assertion — `driveStart` asserts `retryablePageIndices` non-empty **before** driving, so a basis that silently collapses fails there rather than in a device session.

## Task Commits

Each task was committed atomically:

1. **Task 1: The generated family, count-basis agreement, and the external-mutation probe** - `d1eab180` (test)
2. **Task 2: The no-dead-end family, and the full-suite gate** - `bcb564b4` (test)
3. **Naming correction: the captured state is a snapshot** - `e02bf4b4` (test)

The third commit is recorded rather than folded into either task, because it was made after both gates had already run and it therefore needed its own. Task 1's acceptance criterion is a literal `grep -c 'snapshot'`, and the type had been written as `SSOTStateProbe` with `probe(_:in:)` — accurate for the ACT of mutating and re-reading, but not for the value, which is exactly the before/after snapshot the plan's action text describes. `SSOTStateProbe` → `SSOTStateSnapshot` and `probe(_:in:)` → `snapshot(_:in:)`, with the doc rewritten to say what the two halves are for. The full `FeatureTests` plan and the file's lint were both re-run from scratch afterwards rather than trusted.

## Files Created/Modified

- `AppPackage/Tests/DownloadsFeatureTests/DownloadManifestSSOTInvariantTests.swift` - **New, 849 lines.** The suite header names the AGENTS.md clause it is the executable form of and carries the D-SSOT-09 scope note; then the three `@Test(arguments:)` families, the nine-case table with a per-case regime rationale, the staging routine, the probe/snapshot types and the drive helpers.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` - the four fixture builders that had been private-duplicated across two suites (`galleryFolderURL`, `pageFileURL`, `recordRealPageHashes`, `corruptPageFile`), each documented with why it is shared and — for `recordRealPageHashes` — the trap of handing it a blank-hash page. `writePageFiles` now resolves its folder through `galleryFolderURL`, so the fixture's folder naming is decided in exactly one place.

## The Conditional File: TOUCHED, and Why

`DownloadFeatureTestHelpers.swift` was declared conditional on "Task 1's shared-fixture extraction landing helpers there instead of the suite file". **The condition fired and the file was touched.** Task 1's `<read_first>` directs the executor to REUSE the existing fixture builders rather than duplicate them, and the same four helpers already exist as private copies in `DownloadValidationReconciliationTests.swift` and `DownloadInspectionBasisTests.swift`. A third private copy in the new suite would have been the one thing the instruction forbids, so the shared surface is where they landed — which is also the pattern that file already establishes for `writePageFiles`, `pageResults` and `restorePermissions`, each carrying a "shared rather than file-private because…" note.

**The two pre-existing private copies were deliberately left in place.** `DownloadValidationReconciliationTests.swift` and `DownloadInspectionBasisTests.swift` are in neither `files_modified` nor either task's `<files>`, and this phase has twice raised a plan-correction checkpoint for exactly the defect of editing an undeclared file. There is no ambiguity hazard: a concrete-type member wins overload resolution over a protocol-extension default, so each suite keeps calling its own copy and the shared one serves the new suite. Recorded here with file names so a follow-up round can collapse them as a pure deletion.

One measurement worth carrying forward: `DownloadFeatureTestHelpers.swift` is now **970 lines against the 1000-line `file_length` error limit** (891 before). The next addition to that surface will need a split, and a split of a protocol-extension file is mechanical (a second `extension DownloadFeatureTestCase` in a new file) rather than a redesign.

## The Generated State Family

Nine named cases × three families = **27 case instances**, all green. A named table rather than randomness, because a standing falsifier has to be re-runnable exactly when it fails.

| # | Case | Manifest claim | Disk reality | Validation history | Queue | Regime | Validate gate |
|---|---|---|---|---|---|---|---|
| 1 | `completeRecordIntactFiles` | 3 of 3 | all present | never | inactive | `.completed`, terminal | open |
| 2 | `completeClaimWithMissingFilesNeverValidated` | 3 of 3 | page 2 gone | never | inactive | `.completed`, terminal | open |
| 3 | `durableAfterValidatingAMissingPage` | 3 of 3 → 2 of 3 | page 2 gone | durable | inactive | `.inactive`, startable | closed |
| 4 | `durableAfterValidatingCorruptBytes` | 3 of 3 → 2 of 3 | page 2 refuted, file removed | durable | inactive | `.inactive`, startable | closed |
| 5 | `refusedWholesaleAfterValidating` | 2 of 2, verbatim | all gone | refused | inactive | `.error`, startable | open |
| 6 | `healthyPartialClaimInactive` | 1 of 3 | page 1 present | never | inactive | `.inactive`, startable | closed |
| 7 | `emptyClaimNothingOnDisk` | 0 of 2 | nothing | never | inactive | `.inactive`, startable | closed |
| 8 | `strayFileBesideBlankHash` | 2 of 3 | 3 files, one unclaimed | never | inactive | `.inactive`, startable | closed |
| 9 | `queuedPartialClaimThroughTogglePause` | 1 of 3 | page 1 present | never | **queued via `togglePause`** | `.queued`, in motion | closed |

Every named boundary is crossed with cases on both sides: durable (3, 4) against refusal (5); in-session (all) against post-relaunch (all but 9); complete (1, 2, 5) against partial (3, 4, 6, 8) against empty (7); queued (9) against inactive (3, 4, 6, 7, 8) against error (5) against completed (1, 2); never-validated (1, 2, 6, 7, 8, 9) against validated-durable (3, 4) against validated-refused (5); and the sensor's own gate open (1, 2, 5) against closed (3, 4, 6, 7, 8, 9).

## Pruned Combinations, Each With Its Reason

An unreachable shape documented is a boundary pinned. Every combination the cross product suggests and the table omits, with why production choreography cannot reach it — or why reaching it would prove nothing:

1. **Partial claim × validated.** `validateImageData` is gated on `download.canValidateImageData`: `.completed`/`.updateAvailable`, or a `fileOperationFailed` entry. An honestly-incomplete record is `.inactive` with no entry, so the sensor returns nil for it. This is not a gap but the sensor's design — the record already states what a pass would find. It is pinned from both sides as the `.gateClosed` arm of family 2 rather than staged as a case.
2. **Queued × relaunch.** Queue membership is in-memory session state by construction, so a fresh coordinator over the same storage has an empty queue and reads case 9's *underlying* record — which case 6 already pins. Case 9 therefore carries `relaunchReading: nil`, spelled out at the site.
3. **All-files-gone × durable reconciliation.** Unreachable by D-SSOT-02: a wholesale prospective blank set is exactly what the irreversibility guard refuses, so "all gone" can only produce case 5's refusal.
4. **The `.active` regime as a target state.** `.active` is in motion exactly as `.queued` is, and case 9 covers the in-motion classification. Staging the *target* as active would mean a second parked runner writing to the record while family 2's probe read it — a fixture racing its own assertions rather than a new regime.
5. **`.updateAvailable`.** Reachable only through `updateRemoteVersion`'s metadata comparison, which is a remote-version concern orthogonal to the record-versus-disk basis; its completeness quantities are the same manifest reads this family already exercises in the `.completed` cases.
6. **A download-level `.error` (`downloadErrors`, e.g. `.networkingFailed`).** Not a record-versus-disk regime at all: it is installed by a run reaching a fatal exit (`persistFailure`) and cleared by the next resume or retry, and reaching it faithfully needs a real failing run, which this fixture family — inert runner, no network — cannot stage without a non-production seam. Worth stating explicitly, because the *inspector's* three affordances do not cover that shape (`canTogglePause`, `canRetryPages` and `canValidateImageData` are all false for it); the forward affordance there is Detail's own retry/repair button, which resolves through `queuedMode`'s `.error` arm. Recorded as an enumerated-but-unstaged shape rather than a finding, since no manifest/disk divergence is involved and Detail's affordance is what keeps it off the dead-end list.

## The Completeness-Quantity Inventory

The full result of `grep -rn "completedPageCount" AppPackage/Sources` outside `DownloadClient`, plus every consumer of `DownloadPageStatus` semantics, with each one's basis and how the suite covers it.

| # | Consumer | Basis | Covered how |
|---|---|---|---|
| 1 | `DownloadedGallery.completedPageCount` | `manifest.completedPageCount` — non-empty hashes | The reference value every other row is asserted against |
| 2 | `DownloadedGallery.badge` → `DownloadProgress` | rows 1 + `pageCount` | `badge.progress.completedPageCount` and `.pageCount` asserted equal to the record's |
| 3 | `DownloadBadgeLabel` (gallery lists, Detail header, Downloads rows) | `badge.progress.displayCompletedPageCount` | The rendered numerator asserted equal to the recorded one; the clamp is inert over this family and that is stated as a claim about the family, not about the clamp |
| 4 | Inspector page groups (`DownloadsView+Subviews`) | `inspection.pages` partitioned by status | The `.downloaded` count asserted equal to row 1, and the full status vector pinned per regime |
| 5 | Inspector header cell | `inspection.download.badge` | Asserted as row 1 through `inspection.download.completedPageCount` |
| 6 | `DownloadInspection.hasDownloadedPages` → `canValidateImageData` | `pages.contains(.downloaded)` | Asserted `== (completedPageCount > 0)` — the equivalence 15-59 made structural |
| 7 | `DownloadedGallery.isIncomplete` → `resumeMode` | `completedPageCount < pageCount` | Asserted `== (recorded < pageCount)` |
| 8 | `DetailView+HeaderSection.isPartialDownloadError` | `badge.progress` | A pure function of row 2 with no independent basis, so row 2 covers it; recorded on the assertion helper |
| 9 | `DetailReducer.State.downloadNeedsRepair` | `badge.progress` + failure code | Same as row 8 |
| 10 | `DownloadInspectorReducer.reconciledRetryingPageIndices` | `inspection.pages` statuses | UI-local overlay reconciliation over row 4's vector, which is pinned |
| 11 | `DownloadInspectorReducer.retryPages` optimistic overlay | UI-local, replaced by the next `loadInspection` | Not a derivation basis and never reaches the record |
| 12 | `DetailReducer+Download` synthetic badges (`completedPageCount: 0`) | an optimistic pre-record badge at enqueue, before any record exists | No record to agree with; deliberately out of the families |
| 13 | `DownloadClient+ContinuedSession` `displayCompletedPageCount` | **run-owned `RunProgressBasis` + session ledger** | **Excluded by D-SSOT-09** — see below |

## D-SSOT-09: The Exclusion, and Why It Is Structural

The continued-processing card's `X / Y` series is a *different quantity by design*. Its numerator is a run-owned MEASURED value (`RunProgressBasis`, the round-18 redesign) and its denominator a session-scoped ledger: progress-of-this-run, not completeness-of-this-record. Unifying it into the manifest basis would reintroduce the inference that redesign deleted and that nine rounds of corrections — trust set, run-owned proof, page-debt subtraction, completeness guard — were spent chasing.

Stating that in a comment would leave the next reader free to "fix" the distinction. So the exclusion is enforced by construction as well: **every fixture in this suite is built with `BackgroundProcessingClient.noop`**, so no progress push is observable from the suite at all. A future edit cannot start asserting on the run-measured series here even by accident, because there is nothing to assert on.

## What Makes Each Family Non-Vacuous

Three ways a property suite can pass while proving nothing, and what closes each:

- **Agreement satisfied by a derivation that returns zero everywhere.** Closed by carrying the expected `displayStatus`, `completedPageCount` and full page-status vector per case, so the regime's own value is a stated claim and the agreement is asserted on top of it.
- **Invariance over a mutation that silently failed.** This is the same shape as a barrier that stops observing when a fix holds its value constant, and it is what `expectRenderingResourcesFollowedTheDisk` closes: after D-SSOT-07 the directory listing resolves rendering resources and nothing else, so a deleted page's `fileURL` must go nil and a planted page's must appear, in the same read that finds every status and every predicate unmoved. Every case carries at least one delete or plant, so no case's invariance rests on a corrupt-in-place rewrite alone.
- **A "forward affordance" that exists but leads nowhere.** Closed by driving rather than reading: the family calls the affordance and requires `.queued` with the mode the record's shape predicts, and for the retry arm it asserts the basis non-empty before the call and the carried selection after it. G-15-5's dead end had predicates that each looked reasonable; only reaching `.queued` proves the way out.

The drive order is production's own: `togglePause` first, then the inspector's `retryPages` over `retryablePageIndices`, then `validateImageData` followed by one of those. The validate-then-start arm is kept although no current case needs it — the property is about the state space, not about this table — and the reason is written on the helper.

## Determinism: Occupancy, Not Polling

Every staging parks a blocker gallery on `BlockingRunnerControl.park()`'s `withCheckedContinuation` and awaits `control.started()` before anything is asserted, so `scheduleNextIfNeededCore`'s `activeTask == nil` guard refuses every later promotion. Without it a driven resume reads `.active` for an actor turn — `togglePause` → `resume` → `scheduleNextIfNeeded` assigns `activeGalleryID` before returning, and `displayStatus` reads `activeGalleryID` ahead of queue membership — which is a pin on a value whose derivation basis is still moving. That is the form 15-56 through 15-59 all converged on, and it is applied here uniformly rather than per case.

The log is the incidental proof that the drive arms are the ones intended: the run records `Download resumed` for gids `216003`, `216004`, `216006`, `216007`, `216008` and `216009` and **not** for `216005`, because the wholesale-refusal case reaches `.queued` through `retryPages`, which issues no such line. The two terminal cases (`216001`, `216002`) never resume at all.

## Contract-Faithful Choreography, Line by Line

No regime is installed through a non-production seam:

- an operation-level `validationErrors` entry arrives **only** by running `validateImageData` on a gate-open record (cases 3, 4, 5);
- the target's queue membership arrives **only** through `togglePause` (case 9, and family 3's drives) or `retryPages` (family 3's refusal drive) — never through `testingSetQueuedGalleryIDs`, which is used solely for the blocker's scaffolding entry;
- the process boundary is **only** a fresh `DownloadCoordinator` over the same storage root;
- every external mutation is a direct `FileManager` / `Data.write` operation with no client call, which is what "outside the app" means.

Two smaller fidelity points, both written at their sites: only pages the manifest already claims are re-hashed (hashing a blank-hash page would promote it to claimed and silently change the regime the case is supposed to be), and the snapshot carries `lastError.code` rather than the whole `DownloadFailure`, because the failure's MESSAGE is the operation's own report of what a pass found and legitimately changes when a pass is re-run — asserting on it would be a fixture stricter than the production guarantee.

## Found-and-Fixed Violations

**None.** No production source file was touched by either commit, and no expectation was relaxed to make a case pass. Two mechanical corrections were made to the test code before the gates closed, neither a production finding:

- a `// swiftlint:disable:next closure_body_length` was written and immediately removed — the rule is not even enabled in this repository, and a suppression is forbidden regardless;
- `retryPages(...).get()` broke the `multiline_function_chains` rule and was split into a `Result` binding followed by `try retried.get()`;
- the captured-state type was renamed from `SSOTStateProbe` to `SSOTStateSnapshot` after both gates had run, which is commit `e02bf4b4` and its own re-verification.

## Deviations from Plan

None — the plan was executed exactly as written, and **no DECISION CHECKPOINT was needed.** Every instruction resolved against the real post-15-59 source, including the two that read as conditionals: the shared-fixture extraction (it landed in the declared conditional file, recorded above) and the violation discipline (no violation was found, so neither the in-plan-fix arm nor the report-as-gap arm was exercised).

Three implementation choices worth naming, all inside the plan's latitude:

- **The invariance probe runs a full `reloadDownloadIndex` before re-reading.** The plan says "re-read everything and assert the snapshot UNCHANGED"; a passive re-read would have been sufficient for the letter of it. The rescan is the production route a user actually triggers (pull-to-refresh, foreground return) and is strictly the stronger claim — the record survives a *scan*, not merely the absence of one.
- **The `Validate`-gate boundary is carried per case rather than computed.** Predicting the post-mutation reconciliation outcome by re-deriving 15-58's rules in the test would have meant re-implementing the production algorithm inside its own falsifier. Each case names its own expected sensing outcome with the set arithmetic written out in a comment beside it, which is fixture bookkeeping rather than a second implementation.
- **The two pre-existing private fixture-builder copies were left alone**, on the undeclared-file rule (see "The Conditional File" above).

## Issues Encountered

- **No log content was added anywhere.** The plan authorized none, and `DownloadLogPrivacyInvariantTests` passed in the full run, so the hash-masked inventory is unchanged — the trap 15-56 recorded. The `Working manifest reconciled` and `Download resumed` lines visible in the run output are the existing blanking loop's and `resume`'s own, exercised by the new fixtures.
- Every `xcodebuild` invocation was run singly and none was killed mid-flight.

## Verification

- Task 1 gate — `-only-testing:DownloadsFeatureTests/DownloadManifestSSOTInvariantTests`: **`** TEST SUCCEEDED **`**, 2 tests × 9 arguments = 18 case instances, zero failures.
- Task 2 gate — full `FeatureTests` plan: **`** TEST SUCCEEDED **`**. Downloads target **397 tests in 71 suites** (+3 tests, +1 suite over 15-59's 394/70); whole plan 906 passed, **0 failed**, 10 expected failures, across 22 bundles.
- Post-rename re-run of the full `FeatureTests` plan, from scratch rather than trusted: **`** TEST SUCCEEDED **`** again.
- `DownloadLogPrivacyInvariantTests` green in that same run.
- Clean app-scheme build: **`** BUILD SUCCEEDED **`**, with zero `warning:` and zero `error:` lines — so zero SwiftLint violations, since the plugin reports through those.
- SwiftLint over both touched Swift files with the repository config in `--strict` mode: **0 violations, 0 serious**. The app-scheme build does not lint `Tests/`, so both files were linted explicitly with the standalone binary.
- No `swiftlint:disable`, no `@unchecked Sendable`, no `@preconcurrency`, no `nonisolated(unsafe)` in either file (grep count: 0 for both).
- No commit deletes a tracked file (`git diff --diff-filter=D` empty for all three).
- `DownloadManifestSSOTInvariantTests.swift` is 849 lines against the 1000-line limit; `DownloadFeatureTestHelpers.swift` is 970.

## Acceptance Criteria

| Criterion | Result |
|---|---|
| `grep -c 'D-SSOT-09'` in the suite file | `2` (≥1 required) |
| `grep -c 'snapshot'` in the suite file | `5` (≥1 required) — `SSOTStateSnapshot`, `snapshot(_:in:)` and their docs; the invariance assertion is `after.displayed == before.displayed` |
| `grep -c 'togglePause'` in the suite file | `9` (≥1 required) |
| `grep -c 'retryPages'` in the suite file | `3` (≥1 required) |
| `grep -c 'single source of truth'` in the suite file (key_link) | `1` (≥1 required) |
| `grep -c 'displayStatus'` in the suite file (key_link) | `23` (≥1 required) |
| Completeness-quantity inventory with each consumer's basis recorded | yes — 13 rows above |
| Pruned-combination list with reasons | yes — 6 entries above |
| Every family piecewise per regime, no blanket assertion spanning a boundary | yes — expectations are carried per case; the only cross-regime assertions are the AGREEMENT and INVARIANCE properties themselves, which are the claims under test |
| Every non-terminal incomplete state reaches `.queued`; terminal boundary pinned | yes — D4 and D5 |
| Task 1 targeted command exit code | `0` |
| Full FeatureTests exit code / clean build lint | `0` / zero violations |
| No production source touched | yes — `git show --stat` lists two test files across both commits |

## User Setup Required

None - no external service configuration required.

## Device Retest Input (15-UAT.md)

**No device retest input changes under this plan.** It adds falsifiers, not behavior: no production file was touched, so every expected observation recorded by 15-56, 15-58 and 15-59 stands exactly as written. The UAT reconciliation should not look for a new one here.

## Next Phase Readiness

- G-15-SSOT now has a standing falsifier as well as a fix. The invariant AGENTS.md records is asserted over a reproducible state family rather than only at the scenarios the fixing plans happened to stage, which is the specific hole that let G-15-5 ship green through 888 tests.
- One enumerated-but-unstaged shape is recorded above with its reasoning: a download-level `.error` from a run's fatal exit is not covered by the inspector's three affordances and depends on Detail's retry/repair button instead. No manifest/disk divergence is involved, so it is out of this suite's clause; a future round that wants it inside would need a fixture able to drive a real run to a fatal exit.
- Two prose residuals remain open from prior plans, both comment-only and both in undeclared files: `AppPackage/Sources/DetailFeature/DetailReducer.swift:112` names the superseded ID D-G5C-01, and `AppPackage/Tests/DetailFeatureTests/DetailDownloadRepairPredicateTests.swift` lines 13 and 52 still describe corrupt-in-place as a complete-claiming family member. A third is added here: the four fixture builders now exist both privately in two suites and on the shared surface, collapsible as a pure deletion.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` is at 970 of 1000 lines. The next addition to that surface needs a split.
- No blockers.

## Self-Check: PASSED

Both claimed files exist on disk, and all three commits (`d1eab180`, `bcb564b4`, `e02bf4b4`) resolve in `git log`. Every grep count in the acceptance table was re-taken against the delivered files rather than transcribed from the plan.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-09*
