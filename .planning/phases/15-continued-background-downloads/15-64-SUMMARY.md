---
phase: 15-continued-background-downloads
plan: 64
subsystem: downloads
tags: [download-client, retry, page-selection, input-validation, swift-testing]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "the queue-intent vocabulary (queuedModes / queuedPageSelections / queueIntentGeneration) 15-61 renamed, and the payload normalization step fetchNormalizeAndDownload drives"
provides:
  - "A fail-closed public retry boundary: an inadmissible page selection is refused before any queue or session mutation"
  - "A three-state page-selection contract — nil unrestricted, present-empty admits nothing, present-nonempty admits its members"
  - "DownloadQueueIntentSnapshot: the whole-state inventory a refusal must leave untouched, read in one actor hop"
  - "An explicitly documented and regression-tested whole-update exception to repair subset preservation"
affects: [selected repair, resume-mode resolution, pending-page scheduling, retry UI failure path]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Validate public input against the current record BEFORE resolving a mode, so no delegation can outrun the admission test"
    - "Encode 'no restriction' and 'restricted to nothing' as different values, never as one value plus an emptiness test"
    - "Assert a negative contract as a whole-state comparison, not as a returned error alone"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadRetryUpdateFallbackTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift

key-decisions:
  - "CR-04: the admission test moves ahead of mode resolution, because the defect was the ORDER — the delegation and the filtering were each correct where they stood"
  - "DEC-A: an explicitly empty request is refused rather than answered .success(()), since a success the caller cannot distinguish from queued work is the same collapse read from the other side"
  - "DEC-B: presence, not emptiness, carries the restriction — normalization keeps a supplied selection non-nil even when filtering empties it"
  - "DEC-C: the whole-update exception is kept and documented rather than narrowed, and gated on at least one admissible page"
  - "DEC-D: refusals are asserted as one Equatable whole-state snapshot, so a partial fix cannot pass a narrower assertion"

patterns-established:
  - "Three-state optional contract: absence and empty presence are different requests and must never share a value"
  - "A test double that reproduces a boundary's transform must be updated with the boundary, or every case built on it silently stops testing the contract"

requirements-completed: []

coverage:
  - id: D1
    description: "An all-invalid repair request is refused with the queue-intent generation, queue membership, queued mode, queued selection, recorded download/page failures and continued-session start count all unchanged"
    requirement: "SC2"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift#testRetryPagesRefusesAnAllInvalidSelectionWithoutMovingAnything"
        status: pass
    human_judgment: false
  - id: D2
    description: "An explicitly empty repair request fails the same way instead of reporting success"
    requirement: "SC2"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift#testRetryPagesRefusesAnExplicitlyEmptySelectionWithoutMovingAnything"
        status: pass
    human_judgment: false
  - id: D3
    description: "A mixed repair request queues exactly its valid deduplicated subset, and performs the clears the refusals withhold"
    requirement: "SC3"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift#testRetryPagesQueuesExactlyTheValidSubsetOfAMixedSelection"
        status: pass
    human_judgment: false
  - id: D4
    description: "An update record refuses empty and all-invalid input before delegation, leaving queue and session state untouched"
    requirement: "SC2"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryUpdateFallbackTests.swift#testAnInadmissibleUpdateRequestIsRefusedBeforeDelegation (2 arguments)"
        status: pass
    human_judgment: false
  - id: D5
    description: "Valid and mixed-validity update input follows the documented whole-update contract: queued mode .update with a nil page selection"
    requirement: "SC3"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadRetryUpdateFallbackTests.swift#testAnAdmissibleUpdateRequestQueuesTheWholeUpdate (2 arguments)"
        status: pass
    human_judgment: false
  - id: D6
    description: "Normalization distinguishes .none from .some([]) for nil, explicit-empty, all-invalid and mixed input, and still discards a selection for .update"
    requirement: "SC3"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift#testNormalizationKeepsNilUnrestrictedAndAnExplicitSelectionPresent"
        status: pass
    human_judgment: false
  - id: D7
    description: "Pending-page scheduling reads nil as unrestricted and a present empty set as no pages, so an all-invalid selection composed through both steps schedules nothing"
    requirement: "SC2"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift#testPendingPagesReadNilAsUnrestrictedAndAPresentEmptySetAsNoPages"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift#testAnAllInvalidSelectionNeverNormalizesIntoWholeGalleryWork"
        status: pass
    human_judgment: false
  - id: D8
    description: "Every pre-existing retry, wholesale-refusal, ledger, zero-page and inspector behaviour is unchanged"
    verification:
      - kind: unit
        ref: "xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests (929 tests, 0 failures; downloads target 420 in 71 suites)"
        status: pass
    human_judgment: false

# Metrics
duration: 30min
completed: 2026-08-10
status: complete
---

# Phase 15 Plan 64: Retry Page Selection Boundary Summary

**CR-04 closed: `retryPages` now filters a caller's indices against the current record's page domain immediately after the fetch and refuses an inadmissible request before any mutation, and payload normalization keeps an explicit selection PRESENT so only a nil selection can ever mean whole-gallery work.**

## Performance

- **Duration:** ~30 min
- **Started:** 2026-08-10T02:05Z
- **Completed:** 2026-08-10T02:35Z
- **Tasks:** 2 (RED, GREEN)
- **Files created:** 0
- **Files modified:** 8

## Accomplishments

- **The defect was an ORDER, and two correct decisions that shared one value.** `retryPages` resolved the resume mode and, for an update record, delegated to `retry(gid:mode:)` before it had looked at `pageIndices` at all; for a repair it deduplicated the indices without ever asking whether the gallery owned them. Downstream, `normalizeFetchedPayload` dropped out-of-domain values (right) and then encoded the resulting emptiness as `nil` (wrong), and `pendingPageIndices` reads `nil` as no restriction (right). Nothing in that chain is individually mistaken; the widening lives in the seam, where "everything you asked for is inadmissible" and "you asked for no restriction" were the same value. `retryPages(gid:pageIndices: [0, 999])` therefore reported success and scheduled the whole gallery.
- **Admission now precedes everything, and "everything" is enumerated rather than gestured at.** The filter runs immediately after `fetchDownload`, and an empty result returns `.failure(.notFound)` ahead of mode resolution, update delegation, the folder-existence check, `clearSelectedFailedPages`, `clearDownloadFailureState`, the queue-intent generation advance, the queued mode/selection writes, `queueStore.enqueue`, observer notification, `scheduleNextIfNeeded` and `ensureContinuedSession`. The RED run recorded that pre-fix an inadmissible call moved SEVEN of those at once, which is why the refusal is asserted as a whole-state comparison instead of an error alone.
- **Presence carries the restriction; contents only say which pages survive it.** `normalizeFetchedPayload` maps `nil` to `nil`, and any supplied selection to `Set(filtered)` — including the empty set. The second filter is defensive rather than load-bearing, because the boundary already refused an inadmissible request, but it validates against the FETCHED page count, which can differ from the record's. Failing closed is the honest answer to that drift: narrow intent that has become inadmissible schedules nothing rather than everything.
- **The whole-update exception is kept, gated and written down.** An update record with at least one admissible page still delegates to the established whole-update retry with no page selection, because an update re-fetches against a NEW page count and a subset drawn against the old one names pages that may no longer be the same pages. What changed is that the delegation is now unreachable from an empty or entirely out-of-domain request. Both arguments of the mixed case are pinned so a future hardening that also refused mixed input would fail here rather than quietly removing the user's only route to an update.
- **The refusal inventory is a value, and it is read in one actor hop.** `DownloadQueueIntentSnapshot` names the complete set of writes the two retry paths perform plus the session they ensure; assembling it from separate `await`s would let a run interleave between members and record a composite state that never existed. A fix that skipped the enqueue while still clearing a recorded error fails against it instead of passing a narrower assertion.
- **The public caller already had the failure path this needs.** `DownloadInspectorReducer` guards an empty array before it ever reaches the client, and its `retryPagesDone(.failure)` arm clears `retryingPageIndices` and reloads the inspection — so a stale inspection whose indices the boundary now rejects resettles the screen instead of silently starting a broad repair.

## Task Commits

Each task was committed atomically:

1. **Task 1: RED — pin the nil-versus-explicit-empty collapse and its queue-level blast radius** - `3f4a44ac` (test)
2. **Task 2: GREEN — fail closed at retryPages and preserve explicit emptiness downstream** - `9f6fbfd6` (fix)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift` - `retryPages` filters `Set(pageIndices)` against `1 ... download.pageCount` by comparison, sorts, and returns `.failure(.notFound)` on an empty result before mode resolution; the mode resolution and update delegation moved BELOW that guard; a public doc block stating the ordering requirement, the empty-is-a-refusal rule, and the deliberate whole-update exception.
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift` - `normalizeFetchedPayload` expresses the three states directly and returns `Set<Int>?`; its equality guard now compares against `payload.pageSelection` (the only comparison that answers whether a rebuild changes anything) and the rebuild passes the Set through rather than re-mapping an array; a doc block deriving the contract.
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` - `pendingPageIndices` gained the CR-04 paragraph on the selection branch: the optional's presence is the restriction, a present empty set is reachable and intentional, and a "non-empty selection restricts" rewrite would re-open the widening. No behavior change.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift` - three boundary cases (all-invalid, explicit-empty, mixed) on a new `RetryBoundaryFixture`: a three-page record claiming one page with no page files, a recorded download failure and a recorded page failure, with the active slot occupied. The all-invalid case asserts the staged blast radius (`pendingPageIndices` over an unrestricted repair answers `[1, 2, 3]`) before driving the refusal.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadRetryUpdateFallbackTests.swift` - two parameterized cases on a new `UpdateBoundaryFixture` whose `.update` regime comes from the coordinator's updated-gallery set: inadmissible input refused before delegation, admissible and mixed-validity input queuing `.update` with a nil selection. The two existing stubbed-session cases are untouched.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift` - `makeZeroPagePayload` re-expressed over a new `makePayload(pageCount:mode:pageSelection:)`; three new cases covering the three normalization states, the downstream nil-versus-present-empty reading, and the composed widening proof; the pre-existing zero-page normalization assertion updated from `nil` to a present empty set with the reason recorded.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift` - new `DownloadQueueIntentSnapshot` and the `DownloadCoordinator.queueIntentSnapshot(gid:backgroundSessionStartCount:)` reader, plus the `AppModels`/`DownloadClient` imports they need.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` - `makeRetriedPagesPayload` filters against the gallery's page domain so the double still mirrors the route it doubles; `waitForTaskValue`'s default deadline raised to ten seconds with the reasoning recorded (deviation 2).
- `AppPackage/Tests/DownloadsFeatureTests/DownloadObserverBatchTests.swift`, `DownloadCoordinatorStorageTests.swift`, `DownloadDeleteConvergenceTests.swift`, `DownloadOwnershipConvergenceTests.swift` - five redundant explicit one-second deadlines removed so the bound has one owner (deviation 2).

## Decisions Made

- **DEC-A: an explicitly empty request is refused, not answered `.success(())`.** The pre-fix early return reported success for work nobody asked for, and the caller cannot tell that reply apart from one that queued something. Refusing states the truth, and the public caller's existing failure arm already reloads the inspection, so no new UI surface is owed.
- **DEC-B: normalization keeps a supplied selection present.** The alternative — collapse empty to nil and rely on the boundary alone — leaves the widening one edit away and leaves the fetched-versus-recorded page-count drift unanswered. Two independent guards is not belt-and-braces here: they validate against two different page counts.
- **DEC-C: the whole-update exception is documented rather than narrowed.** Preserving a subset into an update would carry indices drawn against a page count the update is about to replace. The requirement is one admissible page, which is exactly what makes the exception not a widening, and both halves are regression-tested.
- **DEC-D: the refusal is asserted as one Equatable snapshot.** Nine members compared as a whole rather than nine separate expectations: a negative contract is only as strong as its inventory, and a per-member assertion set is one member away from silence.
- **DEC-E: the domain filter compares rather than building a range.** `1...download.pageCount` traps at zero, and a record can legitimately claim no pages — the same G-15-14 rule the module already applies at its other page-count sites, extended to the admission test.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] The retried-pages test double no longer mirrored the boundary it doubles**

- **Found during:** Task 2 (GREEN)
- **Issue:** `makeRetriedPagesPayload` reproduces `retryPages`' transform of a caller's indices, and its own doc names that as the reason it exists — "a later change to how `retryPages` normalizes a caller's indices fails this case rather than silently un-faithing every double in the family again". The boundary gained a domain filter this plan; the double did not. Every ledger case built on it would have kept constructing payloads the route can no longer produce, and the guardian case would not have noticed, because its argument happens to be in range.
- **Fix:** The helper filters against `gallery.pageCount` before deduplicating and sorting, and its doc records that an argument the filter empties has no faithful payload at all — the route would have refused it, so such a case belongs on `retryPages` itself.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift`
- **Verification:** All six call sites pass in-range indices, so no existing expectation changed; `testTheRetriedPagesPayloadCarriesExactlyTheSelectionTheRouteStores` and the whole ledger family are green.
- **Committed in:** `9f6fbfd6` (Task 2 commit)

**2. [Rule 3 - Blocking issue] Three one-second observer deadlines failed the plan's own full-suite gate**

- **Found during:** Task 2 (GREEN), the first full `FeatureTests` run
- **Issue:** The run reported `TEST FAILED` with three failures — `DownloadCoordinatorStorageTests/testDownloadCoordinatorObserverInitialSnapshotUsesManifestIndex`, `DownloadObserverBatchTests/testObserveDeliversNotifyArrivingDuringSnapshotResolution` and `DownloadObserverBatchTests/testObserverHubBroadcastIsNotSuppressedByLateObserverInitialSnapshot`, all `Timed out waiting for …`. Both suites pass in isolation in 0.074s, so the deadline was measuring the scheduler rather than the code. This is the exact fragility the repo already recorded beside `waitUntil`: "One second did not survive CI, where the whole target's suites run in parallel and a task can sit unscheduled far longer than the work itself takes." `waitForTaskValue` never received that correction. Leaving it would hand the phase's verification a coin flip, which on this phase is how a gap round gets refilled.
- **Fix:** `waitForTaskValue`'s default deadline is ten seconds, with the reasoning recorded on it, and the five redundant explicit one-second arguments were removed so the bound has a single owner. Every one of those call sites already documents its deadline as bounding a hang rather than asserting promptness, and a timeout there throws, so no case can be using it as a negative assertion. The deliberate `.seconds(30)` and `.seconds(10)` sites are untouched.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift`, `DownloadObserverBatchTests.swift`, `DownloadCoordinatorStorageTests.swift`, `DownloadDeleteConvergenceTests.swift`, `DownloadOwnershipConvergenceTests.swift`
- **Verification:** Two consecutive full `FeatureTests` runs green (929 / 0); raising a bound can only remove false failures, never make a genuine hang pass.
- **Committed in:** `9f6fbfd6` (Task 2 commit)

### Undeclared files modified

`DownloadFeatureTestSupportTypes.swift` holds `DownloadQueueIntentSnapshot`. Both boundary suites need the same inventory, and that file is the module's designated home for shared test types (`// MARK: - Supporting Types`); duplicating a nine-member snapshot across two suites is the shape that lets one copy drift while both stay green. The four files named in deviation 2 are likewise undeclared, for the reason recorded there.

---

**Total deviations:** 2 auto-fixed (1 test-double faithfulness gap this change created, 1 blocking pre-existing flake surfaced by the plan's own gate) plus 5 undeclared test files
**Impact on plan:** No behaviour outside the plan's contract changed. Deviation 1 is inside the plan's own subject matter; deviation 2 touches only test deadlines and changes no assertion.

## Banked Falsifiability

The RED cases failed against pre-fix production with **15 verbatim issues** across 6 of the 8 new cases:

| Case | Pre-fix (recorded) | Post-fix |
|---|---|---|
| repair, all-invalid `[0, 999]` | snapshot moved on seven members at once — `queueIntentGeneration 0→1`, `isQueued false→true`, `queuedMode nil→.repair`, `queuedPageSelection nil→[0, 999]`, `downloadError` cleared, `hasContinuedSession false→true`, `backgroundSessionStartCount 0→1` — and the result was `success()` | refused, snapshot identical |
| repair, explicit empty `[]` | result `success()` (the pre-fix early return); nothing moved | refused, snapshot identical |
| repair, mixed `[0, 2, 2, 999]` | stored `[0, 2, 999]` | stored `[2]` |
| update, `[]` and `[0, 999]` | both arguments: the same seven-member move with `queuedMode nil→.update`, and `success()` | refused before delegation, snapshot identical |
| normalization, three states | explicit-empty and all-invalid each failed BOTH the presence and the contents expectation — `.none` where `.some([])` was required | present empty set |
| zero-page normalization | the pre-existing assertion's new form failed the same way | present empty set |
| composed widening proof | "An all-invalid selection scheduled `[1, 2, 3]` instead of nothing." | scheduled nothing |

Two cases PASSED pre-fix, deliberately, and they are the positive boundaries rather than discriminators: `testAnAdmissibleUpdateRequestQueuesTheWholeUpdate` (both arguments) pins the exception the fix must NOT remove, and `testPendingPagesReadNilAsUnrestrictedAndAPresentEmptySetAsNoPages` pins the downstream reading the fix depends on but does not change.

The composed proof is the one that states the size of the finding: a two-index request answered with the whole gallery. Asserting only "the boundary returned failure" would have been green over half the defect, because normalization's collapse is reachable from any future producer as well.

## Issues Encountered

- **A refusal case is only as good as what it has to destroy.** A fixture with no recorded failure, no queue entry and no session would let a fix that merely returns early look identical to one that also stops mutating. Both boundary fixtures therefore stage a recorded download failure, a recorded page failure and a claimed-but-fileless record, and the mixed/admissible cases assert that those clears DO happen — so "nothing moved" is a property of the refusal rather than of an empty fixture.
- **The plan's own full-suite gate surfaced an unrelated flake, and the first instinct was the wrong one.** The three failures were not reproducible in isolation, which makes "re-run until green" tempting and wrong. Establishing that the deadline was one second while the target's other wait helper had already been raised to ten for exactly this reason is what turned a flake into a decidable defect (deviation 2).

## Verification Evidence

Run one xcodebuild invocation at a time, `-destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` substituted for the plan's ambiguous `name=iPhone Air`:

1. Task 1 RED gate — the plan's three `-only-testing` suites — **TEST FAILED**, 22 tests in 3 suites, **15 issues**.
2. Task 2 gate — the same invocation — **TEST SUCCEEDED**, 22 tests in 3 suites, 0 warnings.
3. Full `FeatureTests` — **TEST SUCCEEDED**, **929 tests / 0 failures / 10 expected failures**; downloads target 420 tests in 71 suites (412 baseline + 8). Confirmed twice, the second run after deviation 2. Zero `warning:` lines.
4. `xcodebuild -scheme EhPanda -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/EhPandaPhase1564DerivedData build` — **BUILD SUCCEEDED**, **0 warnings** (the SwiftLint build-tool plugin runs in-build, so this is lint-clean over `Sources/`).
5. Standalone SwiftLint `--strict` over all 12 touched or newly-lint-relevant files (the app scheme does not lint `Tests/`) — **0 violations, 0 serious**.

Acceptance greps:

- `grep -c "return .failure(.notFound) }" …/DownloadClient+RetryHelpers.swift` → exactly 1, the admission guard.
- The guard precedes `resumeMode(for:)`, the `.update` delegation, the folder check and `performRetryPages` by inspection of the function body.
- `normalizeFetchedPayload` builds no `ClosedRange`; both it and `retryPages` admit by comparison, so a zero-page record admits nothing rather than trapping.
- No `swiftlint:disable`, `@unchecked Sendable`, `@preconcurrency`, `try?`, force try or force unwrap was added.
- `git diff --diff-filter=D --name-only HEAD~2 HEAD` → empty on both task commits.
- File lengths after the change: `DownloadClient+RetryHelpers.swift` 140, `DownloadClient+ExecutionFetch.swift` 212, `DownloadClient+ExecutionSupport.swift` 952, `DownloadFeatureTestHelpers.swift` 989, `DownloadFeatureTestSupportTypes.swift` 853 — all under the 1000-line error.

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadClient+RetryHelpers.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadRetryPagesTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadRetryUpdateFallbackTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadZeroPagePayloadTests.swift` — FOUND
- Commit `3f4a44ac` — FOUND
- Commit `9f6fbfd6` — FOUND

## Known Stubs

None. No hardcoded empty value, placeholder string or unwired data source was introduced; every symbol added has a live consumer.

## Threat Flags

None. The plan's four registered threats are addressed rather than extended: T-15-64-01 by the post-fetch domain filter ahead of every mutation, T-15-64-02 by presence-preserving normalization, T-15-64-03 by refusing before delegation while documenting and testing the whole-update contract, and T-15-64-04 (accepted) by leaving the typed `.notFound` failure as the only signal — no log line was added anywhere. No new network endpoint, auth path, file-access pattern or schema was introduced, and the public retry surface now has strictly fewer reachable arguments than before.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- CR-04 is closed at its root. With CR-01 (15-62), CR-02 (15-61) and CR-03 (15-63) already closed, `15-REVIEW.md` has no remaining blockers.
- The producer side was swept rather than spot-fixed: `queuedPageSelections` has exactly one writer of a non-nil value (`performRetryPages`), and three writers of nil (`performRetry`, `clearDownloadQueueIntent`, the scheduling cancel path). `payload.pageSelection` has exactly one consumer (`pendingPageIndices`). `shouldSchedule`'s `queuedPageSelections[gid]?.isEmpty == false` test is unchanged and remains correct, because the boundary can no longer store an empty array.
- One narrowing worth knowing: a retry naming only pages the record no longer has now fails with `.notFound` instead of quietly repairing the whole gallery. The inspector's failure arm reloads the inspection, so the user sees a refreshed page list rather than a dead end — but a caller that ignores the result will observe a no-op where it previously observed broad work.
- Open, non-blocking, carried forward unchanged: `DetailReducer.swift:112` names the superseded decision ID D-G5C-01, and `DetailDownloadRepairPredicateTests.swift` lines 13/52 still describe corrupt-in-place as a complete-claiming family member. Both comment-only, both in files this plan did not touch.
- `DownloadFeatureTestHelpers.swift` is now at 989 of the 1000-line limit. The next addition there needs a same-suite extension in a sibling file, the pattern 15-62 recorded as DEC-E.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-10*
