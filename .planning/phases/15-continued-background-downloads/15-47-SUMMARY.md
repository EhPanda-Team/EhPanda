---
phase: 15-continued-background-downloads
plan: 47
subsystem: downloads
tags: [download-coordinator, continued-session, trust-basis, page-selection, gap-closure, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "15-46's production-shaped retryPages payload doubles (HEAD 8274cbe8), without which this plan's regression could not discriminate"
provides:
  - "The announcement gated on the run's own pending page list rather than the working folder's shortfall against its manifest"
  - "PreparedWorkingRun — the seed and the run's pending pages as one value, derived once per run inside the preparation"
  - "testASelectedPageRetryThatFetchesNothingLeavesTheGalleryAtZero — RED before the fix, green after"
  - "testPendingPageListEvaluationsMatchTheRecordedCensus — the one-evaluation rule pinned in source rather than in review"
affects: [15-48, 15-49]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A decision and the work it authorizes are derived from ONE expression evaluated once, handed onward rather than recomputed by the caller"
    - "A doc-borne inventory that a later fix could silently invalidate is paired with a source census that fails a build"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionPerform.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionReconciliationTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadCoordinatorRepairSeedTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadInterruptedResumeTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadRepairSeedSignalPropagationTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift

key-decisions:
  - "The carrier is a named struct, not a labelled tuple: it crosses a public testing forwarder and `labeled_tuple_elements` bans a multi-element tuple type in a return position at error severity"
  - "The plan's own RED prediction was corrected against source: the pre-fix crediting push carries FIVE, not the record's original six, because the reconciliation blanks the one absent page before the gate runs"
  - "The forwarder call-site census found 7 suites, not the 3 the plan named; the discrepancy was recorded and every reading site updated rather than only the named ones"
  - "The one-evaluation rule was PINNED rather than merely restated, as a fourth census in DownloadSourceInventoryTests"

patterns-established:
  - "One predicate, one evaluation, handed onward — proven by a source census, not by a comment"

requirements-completed: [SC1, SC2]

coverage:
  - id: D1
    description: "A selected-page retry whose selected pages are all present earns no session trust and credits no pages"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift#testASelectedPageRetryThatFetchesNothingLeavesTheGalleryAtZero"
        status: pass
    human_judgment: false
  - id: D2
    description: "The run's pending page list is derived exactly once per run, so the announcement's gate and the page loop cannot disagree"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift#testPendingPageListEvaluationsMatchTheRecordedCensus"
        status: pass
    human_judgment: false
  - id: D3
    description: "The announcement still fires on every run that really has pages to fetch — the two refusal exits, the single-missing-page repair, the proceeding branch and the queued-window zero"
    requirement: SC1
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
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testACompleteGalleryQueuedForUpdateOpensTheCardAtZero"
        status: pass
    human_judgment: false
  - id: D4
    description: "On a physical iOS 26 device a selected-page retry that fetches nothing leaves that gallery's contribution at zero instead of opening the card at its full page count"
    verification: []
    human_judgment: true
    rationale: "Backstop truth, device-only. 15-UAT.md test 2 remains an independent axis this plan does not claim."

# Metrics
duration: 27min
completed: 2026-08-06
status: complete
---

# Phase 15 Plan 47: Trust Rationed on the Work the Run Will Do Summary

**The announcement now fires on the run's own pending page list — the very list its page loop is fed, derived once inside the preparation and handed onward — so a selected-page retry that will fetch nothing can no longer earn its record's page count, and the one-evaluation rule is pinned by a source census rather than by a comment.**

## Performance

- **Duration:** 27 min
- **Started:** 2026-08-06T00:50:00Z
- **Completed:** 2026-08-06T01:17:00Z
- **Tasks:** 2
- **Files modified:** 12

## Accomplishments

- Derived the two page sets from source and found the plan's own RED prediction wrong in one detail, correcting it rather than staging to match it.
- Replaced one gate with one predicate over one expression, so the fix is family-wide by construction rather than branch-scoped.
- Swept the retired claim out of **five** files including two in the test target, which is where the last two rounds' corrections leaked.
- Pinned the invariant the fix rests on, so a second evaluation fails a build instead of a review.

## Step 0(1) — what the pending list's emptiness means, derived from `pendingPageIndices`

Three conditions fold into it (`DownloadClient+ExecutionSupport.swift`, the function body, untouched by this plan). For each, whether the shortfall comparison it replaces accounted for it:

| # | Condition | Source | Did the shortfall account for it? |
|---|---|---|---|
| 1 | Zero-page guard — `guard payload.galleryDetail.pageCount > 0 else { return [] }` | `:807` | **Yes, incidentally.** `ensureWorkingManifest` validates the stored manifest against `payload.galleryDetail.pageCount` and otherwise writes `makeInitialManifest`'s fresh one at that same count, so an empty manifest gives `existingPages` empty and `manifest.pageCount` zero — `0 < 0` is false. The two quantities agree here, through different values. |
| 2 | Selection membership — `if let selectedIndices, !selectedIndices.contains(page) { return false }` | `:808-812` | **No, not at all.** The shortfall never reads `payload.pageSelection`. This is the whole of G-15-27. |
| 3 | Per-page file existence — `existingPageRelativePaths[page]` then `fileExists` | `:814-822` | **In aggregate only.** A count compared against a count cannot say WHICH pages are missing, so it could not intersect them with the selection even in principle. |

Also derived and worth stating, because it closes a "do they differ in another way too" question: the shortfall's ceiling was the **working manifest's** page count while the pending list's ceiling is the **payload's `galleryDetail`** page count. `ensureWorkingManifest` makes those equal by construction on every path — it returns a stored manifest only when `validatedManifest` accepted it at the payload's count, and otherwise writes a fresh one at that count — so condition 1 is the only place the difference could have surfaced, and there both are zero.

## Step 0(2) — the relocation is a relocation

`performDownload` already computed the identical list one step after the preparation (`+ExecutionPerform.swift:34-38`, pre-edit), from `payload`, `workingFolderURL` and `workingSeed.existingPages`. All three are in scope inside the preparation — `payload` and `folderURL` are its own parameters, `workingSeed` is the local it has just built — so moving the computation inward adds no dependency. It only moves the evaluation from after the announcement's push to before it, which is the direction the fix needs.

## Step 0(3) — the four-mode enumeration

Two readings per mode. **First half (does any production route supply a raw page selection?):** the only production writer of a *non-nil* `queuedPageSelections` entry is `performRetryPages` (`+RetryHelpers.swift:91`), whose `mode` is the literal `.repair` at its call site (`:66`); every other writer sets nil — `performRetry` (`:39`), `resume` (`+Scheduling.swift:363`), `clearDownloadQueueIntent` (`+Manager.swift:686`). Each of those writes the mode and the selection in the same synchronous pair, so a stored selection is paired with `.repair` and nothing else. `fetchNormalizeAndDownload` reads exactly that entry (`+Execution.swift:137`) and hands the same raw value to both payload steps. **Second half (does `normalizeFetchedPayload` preserve a non-empty in-range selection?):** its test is `validPageSelection?.isEmpty == false && mode != .update` (`+ExecutionFetch.swift:167`).

| Mode | A production route supplying a raw selection? | Normalizer preserves it? | Selection live today? |
|---|---|---|---|
| `.initial` | **None.** No writer stores a non-nil entry with this mode. | Yes — `mode != .update` holds. | No |
| `.update` | **None**, twice over: `retryPages` delegates an `.update` record to `retry` (`+RetryHelpers.swift:53`), which stores nil. And on the one path where a `.repair`-stored selection can reach an `.update` run — `queuedMode(for:)` routes the stored mode through `effectiveRetryMode`, which upgrades to `.update` when `download.hasUpdate` — the normalizer drops it anyway. | **No** — the mode test excludes it. | No |
| `.redownload` | **None.** | Yes. | No |
| `.repair` | **`performRetryPages`** (`+RetryHelpers.swift:91`), reached from `retryPages`. | Yes. | **Yes** |

**Construction versus regression, stated.** All four modes are covered **by construction**: the fix replaces one gate with one predicate over one pending-work expression, and that expression branches on nothing mode-specific — it reads the payload's page count, the payload's selection and per-page file existence — so no mode retains the shortfall basis. `.repair` reached through `retryPages` is additionally covered **by regression**, by `testASelectedPageRetryThatFetchesNothingLeavesTheGalleryAtZero`. The per-mode table above is *why the regression lives on `.repair`* rather than a claim that the other three are unprotected: `.initial` and `.redownload` would carry a live selection the moment a route supplied one, and the predicate already honors it.

## Task 1 — the RED, and the one place the plan's prediction was wrong

**Staging.** Six-page complete-reading record; page files written for `[1, 2, 3, 4, 5]`, so page 6 is absent and the folder is one page short; `retryPages(pageIndices: [3])` — a page whose file IS present. Payload through `makeRetriedPagesPayload`, so it carries the selection the route stored. No permissions are touched, per the plan's instruction: a second refusal mechanism would leave the RED reading ambiguous about which gate fired.

**The correction, derived rather than assumed.** The plan's behavior block predicted "a push carrying the record's six pages IS present after the preparation". Source says otherwise, and the case was written to what source says. `reconcileWorkingManifestAgainstPageFiles` runs *inside* the preparation and *before* the gate: page 6 is claimed, absent from a successful scan and not unprobed, so it is blanked; `blankedPageCount (1) < manifest.completedPageCount (6)` so the residual guard does not refuse; the index record moves to 5-of-6. The announcement's snapshot therefore credits **five**, not six. The assertion is written as the stronger and more direct claim instead — every recorded push's numerator is zero — which is exactly "this gallery's contribution stays at zero" and does not depend on a particular numerator value.

**Observed RED**, quoted from the xcresult of the single targeted invocation (`Test-EhPanda-2026.08.06_09-56-17-+0900.xcresult`):

> `DownloadContinuedSessionLedgerRefusalTests.swift:371: Expectation failed: (spy.progressUpdates → [ProgressUpdate(…, completedUnitCount: 0, totalUnitCount: 6, subtitle: "0 / 6 pages · 1 gallery"), ProgressUpdate(…, completedUnitCount: 5, totalUnitCount: 6, subtitle: "5 / 6 pages · 1 gallery")]).allSatisfy({ $0.completedUnitCount == 0 })`

Two production pushes: a convergence push at the queued-window zero, and the preparation's own announcement at `5 / 6 pages · 1 gallery`. The run was `17 tests in 1 suite`, `2 issues`, **both from the new case** — every pre-existing ledger case passed. The non-vacuity assertions (`existingPages.count == 5`, `manifest.pageCount == 6`, `existingPages[3] != nil`, record blanked to 5) all passed, which is what proves the staging reached the gate rather than falling short of it.

**Task-1 acceptance greps:** `grep -c 'testASelectedPageRetryThatFetchesNothingLeavesTheGalleryAtZero' …RefusalTests.swift` → **1**. `grep -c 'makeRepairPayload' …RefusalTests.swift` → **0**. File length after the addition: **468** lines, below the 1000-line error gate, so no relocation was needed. The case issues no push of its own: its only production calls are `retryPages`, `reloadDownloadIndex`, `fetchDownload`, `resumeMode`, `waitUntil` and the preparation forwarder.

**The doc comment's three derived items**, quoted:

> **The two page sets the announcement can be gated on, and why they differ.** … the run's page loop is fed by `pendingPageIndices`, which reads `payload.pageSelection` FIRST and drops every page outside it before it ever asks whether a file is there. Whenever a selection is live those are different sets: the folder can be short of its manifest on pages this run was never asked to fetch.

> **The production route that reaches a present-file retry.** `performCacheCapture` restores a page from the image cache into the working folder, refreshes exactly that page's manifest hash and re-indexes, then clears only the gallery-level last error through `sanitizeLocalFilesIfNeeded(gid:clearingLastError:)`. The PER-PAGE record the inspector lists — `failedPageErrors[gid]`, read by `loadInspection` — is untouched by that route and is cleared only by `clearSelectedFailedPages` inside `retryPages` itself. So a page can still be offered to the user as failed while its file is already on disk.

> **The discrimination, stated.** Against pre-fix source the gate reads the shortfall, which is non-zero, so the preparation announces … After the fix the gate reads the run's own pending list, which is empty, so no push is issued at all.

**Why the forwarder is acceptable here, derived:** the injected `DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })` returns without ever invoking the scheduled operation, so `processDownload` → `fetchNormalizeAndDownload` → `performDownload` is never reached in this fixture and the preparation is unreachable from the fixture's own scheduling. The forwarder is the only way in, and the payload handed to it is the one the route stored.

## Task 2 — one expression, evaluated once

**The gate, quoted** (`+ExecutionSupport.swift`):

```swift
let pendingPages = pendingPageIndices(
    payload: payload,
    folderURL: folderURL,
    existingPageRelativePaths: workingSeed.existingPages
)
if let continuedSessionID, !pendingPages.isEmpty {
    observedIncompleteSessionGIDs.insert(payload.gallery.gid)
    await pushContinuedSessionProgress(sessionID: continuedSessionID)
}
return PreparedWorkingRun(workingSeed: workingSeed, pendingPageIndices: pendingPages)
```

**The carrier.** `DownloadCoordinator.PreparedWorkingRun`, a `Sendable` struct beside `WorkingSeed` in `+Manager.swift`, holding `workingSeed` and `pendingPageIndices`. A named struct rather than a labelled tuple for a reason that is not stylistic: the value crosses a public testing forwarder, and this project's `labeled_tuple_elements` rule bans a multi-element tuple type in a return position at error severity.

**Acceptance greps, quoted:**

| Grep | Result |
|---|---|
| `grep -rn 'hasRealPageWork' AppPackage App ShareExtension \| wc -l` | **0** |
| `grep -c 'existingPages.count <' …+ExecutionSupport.swift` | **0** |
| `grep -c 'pendingPageIndices(' …+ExecutionSupport.swift` | **2** — the declaration plus the single evaluation |
| `grep -c 'pendingPageIndices(' …+ExecutionPerform.swift` | **0** |
| `grep -c 'observedIncompleteSessionGIDs.insert' …+ExecutionSupport.swift` | **1** |

**The trust admission did not move.** The executable diff of `+ExecutionSupport.swift` is exactly the return type, the gate's three lines and the return expression; the `insert` line is byte-identical and still sits inside `if let continuedSessionID, …` and still ahead of `await pushContinuedSessionProgress`. `git diff` shows **no change at all** to `reconcileWorkingManifestAgainstPageFiles`, `prepareWorkingSeed`, `pendingPageIndices`' own body, `schedulableSnapshot`, `shouldSchedule` or the retirement ledger — `+ContinuedSession.swift`'s diff is doc-only (its non-comment diff is empty), and `+Manager.swift`'s is the new struct plus doc.

### The forwarder call-site enumeration — and the plan's count was wrong

Derived by grep rather than from the plan's file list, as instructed. **The plan named three suites; source holds seven.** The discrepancy is recorded here rather than treated as a stop, because grep resolves it definitively and the plan's own prohibition text already anticipated the reconciliation suite's mechanical update while its `files_modified` list omitted that suite. Halting would have left a blocker open over an under-counted file list.

| Suite | Call sites | Read the seed (updated) | Discard with `_ =` (unchanged) |
|---|---|---|---|
| `DownloadContinuedSessionLedgerRefusalTests` | 3 | 3 | 0 |
| `DownloadContinuedSessionReconciliationTests` | 3 | 3 | 0 |
| `DownloadCoordinatorRepairSeedTests` | 3 | 3 | 0 |
| `DownloadRepairSeedSignalPropagationTests` | 2 | 2 | 0 |
| `DownloadInterruptedResumeTests` | 2 | 1 | 1 |
| `DownloadContinuedSessionLedgerTests` | 2 | 0 | 2 |
| `DownloadContinuedSessionBasisTests` | 5 | 0 | 5 |
| **Total** | **20** | **12** | **8** |

Verified after the edit: `grep -rn 'testingPrepareWorkingSeedAnnouncingProgress(' AppPackage/Tests/ | wc -l` → 20; `| grep -c '_ = try'` → 8; `grep -rn '^\s*)\.workingSeed' AppPackage/Tests/ | wc -l` → 12. The change at each reading site is the single suffix `.workingSeed`; no assertion moved.

### The corrected doc sentences, quoted beside the enumeration that produced them

**1. `+ExecutionSupport.swift` — the gate justification.** The retired equivalence is replaced by the derived difference and by the Step-0(1) table:

> **The gate is the work THIS RUN will actually do** … It used to be the working folder's shortfall against its manifest — the seed's existing-page count compared against the manifest's page count — justified here as equivalent to "this run has pages to fetch". **The two are not equivalent, and G-15-27 is the difference.** … `normalizeFetchedPayload` preserves a non-empty in-range selection for every mode but the update mode, and `performRetryPages` stores one alongside the repair mode, so the difference is real on exactly the route a user's page-level retry takes.

> Three conditions fold into that emptiness, and the shortfall accounted for only one and a half of them. The zero-page guard: the shortfall also refuses there, both quantities being zero for an empty manifest. The selection membership test: the shortfall never consulted `payload.pageSelection` at all. The per-page file existence test: the shortfall saw it only in aggregate — a count against a count cannot say WHICH pages are missing, so it could not intersect them with the selection even in principle.

**2. The same doc's deliberate-consequence paragraph, re-derived** rather than left describing one member of what is now a two-member family:

> Two consequences are deliberate rather than oversights, and they are the same rule twice. A record that reads incomplete while its folder holds every page it claims … does not announce, because that run fetches nothing; neither does a selected-page retry whose selected pages are all present.

**3. The same doc's trust-admission rule** (`:372`): "over a record whose working folder cannot supply the pages its manifest claims" → "over a run that still has pages of its own to fetch".

**4. The same doc's named-suspension paragraph**, extended to cover the new synchronous work: "Both the pending-list evaluation and the insert are synchronous same-actor work taken before that hop … and no page the loop is about to fetch can have been decided after it."

**5. `+Manager.swift`, the trust-set declaration:**

> … which admits a gallery whose own run still has pages left to fetch — its pending page list, the very list its page loop is fed, rather than its folder's shortfall against its manifest, which over-admits a selected-page retry whose selected pages are all present (G-15-27).

**6. `+ContinuedSession.swift`, D-G4-01 itself** (`:88`): "having proven at the run's own preparation that its working folder cannot supply the pages its manifest claims" → "having proven at the run's own preparation that the run still has pages of its own to fetch".

**7. `+ContinuedSession.swift`, the predicate-halves paragraph:**

> … when its own pending page list is non-empty, admits the gallery to the trust set in the same breath. That list — the one the run's page loop is fed, honoring the payload's page selection — rather than the folder's shortfall against its manifest, which credits a selected-page retry that will fetch nothing (G-15-27).

**Pin-or-restate decision: PINNED.** The load-bearing claim this fix rests on is not a sentence about the gate but the *one-evaluation* invariant — the exact shape T-15-47-03 names and the exact shape a later fix can silently break. It is now a fourth census in `DownloadSourceInventoryTests`, on the established pattern (repository-root walk, known-member guard, fragment-assembled detection token, per-file table plus a separately-counted joined total): `testPendingPageListEvaluationsMatchTheRecordedCensus`, expecting `["DownloadClient+ExecutionSupport.swift": 1]` and a joined total of `1`. `performDownload` held the second evaluation until this round and nothing failed when it did; now it would.

## Residue sweep — three checks, each recorded

**(a) Newly-orphaned symbols.** `grep -rn 'hasRealPageWork' AppPackage App ShareExtension | wc -l` → **0**, prose included. No helper existed solely to support the shortfall reading: the comparison was two property reads inline, and both properties (`WorkingSeed.existingPages`, `DownloadManifest.pageCount`) have many other consumers and are untouched.

**(b) The retired claim outside this plan's named scope.** `grep -rn "cannot supply the pages\|supply the pages its manifest\|pages the manifest claims\|pages its manifest claims\|existingPages.count <" AppPackage App ShareExtension` → **0 remaining**, after fixing the four Sources sentences above **and two in the test target that the plan's file list did not name**:

- `DownloadContinuedSessionLedgerRefusalTests.swift` — the K=N refusal case's doc read "the announcement gate compares the seed's existing-page count against the working manifest's page count and does not read `payload.pageSelection` at all — which is G-15-27, still open at this file's HEAD."
- `DownloadContinuedSessionLedgerTests.swift:600` — the third rebuilt double's doc read "The announcement gate does not read `payload.pageSelection` (G-15-27, open here)".

Both were rewritten to state why each case's assertions survive the closure **from its own staging** rather than from the gate ignoring the selection: in each the retried index is precisely a page whose file the staging leaves absent, so the pending list is non-empty and the announcement fires exactly as before. This is the G-15-24 shape — a Sources-only correction leaving the same sentence standing in the tests — caught by scanning the test target as the plan required.

A wider scan (`grep -rn "announcement gate\|shortfall\|prepareWorkingSeedAnnouncingProgress" AppPackage/Tests/`) leaves only true statements: the new case's own derivation, three `DownloadCoordinatorRepairSeedTests` mentions naming the function without characterising its gate, one `DownloadRepairSeedSignalPropagationTests` header naming its announcement, and the new census's own doc.

**(c) Newly-dead state.** The carrier has exactly one production consumer, `performDownload`, and it reads **both** members — `preparedRun.workingSeed` into `executePageDownloads(workingSeed:)` and `preparedRun.pendingPageIndices` into its `pendingIndices:`. No production call site discards it. The 20 test forwarder call sites read the seed (12) or discard the whole value (8); the 8 discards are unchanged from before this plan and assert nothing about pending work, so nothing became silently dead there.

## Green

| Run | Scope | Result |
|---|---|---|
| Task 1 verify (pre-fix) | `-only-testing:…/DownloadContinuedSessionLedgerTests` | **TEST FAILED** — 17 tests, 2 issues, both the new case; every pre-existing case passed |
| Task 2 targeted | same | **TEST SUCCEEDED** — 17 tests, 0 failures, 39.5 s |
| Task 2 full | full `FeatureTests` | **TEST SUCCEEDED** — **875 tests, 0 failures**, 98.7 s |

Each was a single invocation; none overlapped. **Test count 875 against 15-46's 873 → net +2:** the regression case and the pending-list census. No other movement. Zero compiler warnings, zero SwiftLint violations, zero lines over 120 characters in any touched file.

## Task Commits

1. **Task 1: Stage the selected-page retry that fetches nothing, RED-first** — `8d07e9f1` (test)
2. **Task 2: Derive the run's pending work once, gate on it, correct the docs, sweep the residue** — `54b6dd79` (fix)

## Prohibitions

| Prohibition | Status | Evidence |
|---|---|---|
| Trust admission stays at the run's own preparation, in the live-session branch, ahead of the push | **held** | `insert` line byte-identical; `grep -c` → 1; diff shows it inside `if let continuedSessionID, …` before the push; `testACompleteGalleryQueuedForUpdateOpensTheCardAtZero` and both refusal cases' queued-window assertions pass |
| No two evaluations of the run's pending work | **held** | 2 in `+ExecutionSupport.swift` (declaration + one call), 0 in `+ExecutionPerform.swift`; pinned by the new census |
| No change to `reconcileWorkingManifestAgainstPageFiles`, `schedulableSnapshot`, `shouldSchedule`, `pendingPageIndices`' body, the retirement ledger | **held** | `git diff` executable-line filter shows the only changes in `+ExecutionSupport.swift` are the return type, the gate and the return expression; `+ContinuedSession.swift` is doc-only |
| No existing case weakened or restaged | **held** | Every pre-existing test diff is the single `.workingSeed` suffix; the two doc corrections in the test target change no assertion; full suite green |
| No concurrency or lint escape hatch, no SwiftLint suppression | **held** | No `swiftlint:disable`, `@unchecked`, `@preconcurrency`, `try?` or force unwrap added; build clean |

## Decisions Made

- The carrier is a named struct (`PreparedWorkingRun`) rather than a labelled tuple, because it crosses a public testing forwarder and the project's `labeled_tuple_elements` rule bans a multi-element tuple type in a return position at error severity.
- The regression's outcome assertion is "every recorded push's numerator is zero" rather than "no push carries the record's six pages", because source shows the pre-fix crediting push carries five — the reconciliation blanks the one absent page before the gate runs. The stronger form states the claim the fix actually makes.
- The forwarder call-site discrepancy (7 suites found, 3 named) was recorded and fully swept rather than stopped on.
- The one-evaluation rule was pinned in `DownloadSourceInventoryTests` rather than only restated in prose.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] The plan's RED prediction contradicted source; the case was written to source**

- **Found during:** Task 1
- **Issue:** The behavior block predicted "a push carrying the record's six pages IS present after the preparation". With five of six page files present, `reconcileWorkingManifestAgainstPageFiles` blanks the sixth *inside* the preparation and *before* the gate (`blankedPageCount 1 < completedPageCount 6`, so no refusal exit fires), moving the index record to 5-of-6. The announcement therefore credits five. An assertion written to the plan's wording would have passed pre-fix and closed nothing.
- **Fix:** The outcome is asserted as the absence of any crediting push at all — every recorded update's numerator is zero and every subtitle is the queued-window zero — which is both stronger and independent of the blanked value.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift`
- **Verification:** Observed RED with the `5 / 6 pages · 1 gallery` push quoted; green after the fix.
- **Committed in:** `8d07e9f1`

**2. [Rule 2 - Missing Critical] Two retired claims in the test target the plan's file list did not name**

- **Found during:** Task 2 (Step 4, residue check (b))
- **Issue:** `DownloadContinuedSessionLedgerRefusalTests` and `DownloadContinuedSessionLedgerTests` each carried a doc paragraph asserting that the announcement gate "does not read `payload.pageSelection`", stated as the reason the 15-46 payload change moved nothing. Both became false the moment this fix landed. Leaving them is exactly the G-15-24 residue shape that G-15-29 records.
- **Fix:** Both rewritten to derive each case's survival from its own staging — the retried index is a page whose file the staging leaves absent, so the pending list is non-empty and the announcement fires as before.
- **Files modified:** the two suites above.
- **Verification:** `grep` for the retired phrasing across `AppPackage App ShareExtension` → 0; both cases pass unchanged.
- **Committed in:** `54b6dd79`

**3. [Rule 2 - Missing Critical] Forwarder call sites: 7 suites, not the 3 the plan named**

- **Found during:** Task 2 (Step 2)
- **Issue:** The plan's `files_modified` named `DownloadCoordinatorRepairSeedTests` and `DownloadRepairSeedSignalPropagationTests` beside the Task-1 file. Grep found 20 forwarder call sites across 7 suites, 12 of which read the returned seed — including `DownloadContinuedSessionReconciliationTests` (3) and `DownloadInterruptedResumeTests` (1), neither listed. The plan's own prohibition text anticipated the reconciliation suite's update, so the omission was in the list rather than in the design.
- **Fix:** All 12 reading sites updated with the single `.workingSeed` suffix; the enumeration is recorded above rather than the plan's count assumed.
- **Files modified:** the two unlisted suites, plus the three listed.
- **Verification:** Post-edit greps agree (20 / 8 / 12); full suite green.
- **Committed in:** `54b6dd79`

**4. [Rule 1 - Bug] The refusal file's header still said "both cases"**

- **Found during:** Task 1
- **Issue:** The header described the file as holding two cases; 15-46 had already added a third, and this plan adds a fourth.
- **Fix:** Reworded to "every case here", with the two later additions named.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerRefusalTests.swift`
- **Verification:** Full suite green.
- **Committed in:** `8d07e9f1`

---

**Total deviations:** 4 auto-fixed (2 bugs, 2 missing critical)
**Impact on plan:** All four are inside the plan's stated scope — Step 4 explicitly mandated the residue sweep that found #2, Step 2 explicitly mandated the grep-derived enumeration that found #3, and Task 1's Step 4 explicitly instructed re-derivation over assumption, which is #1. No production behavior beyond the announcement basis changed.

## Issues Encountered

The Task-1 invocation took 605 s wall-clock, almost all of it a post-failure `IDETestOperationsObserverDebug: Failure collecting diagnostics from simulator: Timed out after 600.0 seconds`. Testing itself completed in well under a second. This is a simulator diagnostics-collection hiccup on a failing run, not a hang, and both subsequent (passing) runs finished in 39 s and 99 s.

## Known Stubs

None.

## Threat Flags

None — no new network endpoint, auth path, file-access pattern or schema change at a trust boundary. The one new file-system read is the pending-list scan, relocated from a caller inside the same actor.

## User Setup Required

None.

## Next Phase Readiness

- **G-15-27 is closed at the family**, with the four-mode coverage derived rather than assumed and the one-evaluation rule pinned.
- **G-15-26 remains OPEN and unchanged**, by design. This plan did not touch where the run's proof is stored — only what it is gated on — so 15-48 binds to the single expression left behind (`PreparedWorkingRun.pendingPageIndices`, evaluated once inside `prepareWorkingSeedAnnouncingProgress`) without having to re-point a recording site.
- **G-15-29** (the hygiene/doc group) is next after 15-48. Note for it: this plan's sweep already retired the two `payload.pageSelection` claims in the test target, so that particular residue is gone.
- **15-UAT.md test 2** still needs its physical-device iOS 26 re-run; this plan does not claim it (coverage `D4`), and the verifier's standing note applies — a zero-progress observation must be attributed to the still-open G-15-26 ordering rather than treated as new information.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-06*

## Self-Check: PASSED

All 12 modified files present on disk; all 3 commits (`8d07e9f1`, `54b6dd79`, `cf038255`) present in git history. No absolute home path in this document.
