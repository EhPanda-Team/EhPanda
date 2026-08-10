---
phase: 15-continued-background-downloads
plan: 65
subsystem: downloads
tags: [download-client, continued-processing, background-tasks, swift-testing, progress-accounting]

# Dependency graph
requires:
  - phase: 15-continued-background-downloads
    provides: "D-G7-01's withdrawal bracket (15-25/15-54) and the generation-scoped session observation introduced by 15-61"
provides:
  - "A self-bracketing queue-intent advance: the increment carries its own D-G7-01 withdrawal, so every present and future queue-mobilizing entrance is enclosed by construction"
  - "A one-at-a-time keeper-page regression that can observe a BELOW-floor defect, which the single-flush sibling case structurally cannot"
  - "A re-derived regime-handoff invariant that names the queue-intent boundary as the third deliberate downward mover"
affects: [continued-processing progress accounting, future redo/requeue work, ContinuedTaskScheduling expiration policy]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "A deliberate basis MOVEMENT may own its bracket instead of its callers, which moves the exhaustiveness burden off a call-site census"
    - "A defect that lives strictly below the monotonic floor is only observable one landing at a time; any test that clears the floor in one jump proves nothing about it"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift

key-decisions:
  - "CR-01: the bracket belongs on the movement, not on the four call sites — a call-site patch is the branch-scoped shape this phase has re-opened repeatedly"
  - "Sibling composition is proved by construction, not by inspection: the bracket's closure is non-async and all four callers are async, so none can be lexically nested inside one"
  - "The regression's baseline is the RE-QUEUE frame, not the pre-requeue frame — a withdrawn deliberate movement is MEANT to lower the card, so comparing across it would assert the defect"
  - "No second bracket was needed for the retirement-ledger drop: it is covered by the same withdrawal because D-G2-01 retires the credited-pages definition's own answer"

patterns-established:
  - "Movement-owned brackets: when a single line moves the counted basis, wrap that line rather than every path that reaches it"
  - "Below-floor discrimination: a monotonic floor makes a masking defect invisible to any observation coarser than one unit of work"

requirements-completed: []

coverage:
  - id: D1
    description: "Every queue-intent advance withdraws its own credited drop from the monotonic floor, so no call site — present or future — can leave the movement unbracketed"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift#testKeeperPagesLandingOneAtATimeMoveTheCardAfterARequeue"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift#testCountedBasisBracketCallSitesMatchTheRecordedCensus"
        status: pass
    human_judgment: false
  - id: D2
    description: "The first page of genuine work after a same-session re-queue moves the pushed numerator — no frozen frames are absorbed by a stale floor (SC2)"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift#testKeeperPagesLandingOneAtATimeMoveTheCardAfterARequeue"
        status: pass
    human_judgment: false
  - id: D3
    description: "Session identity, the client start count, the existing single-flush re-queue case and every other continued-session, ledger, run-proof, reconciliation, expiration and identity suite are unchanged"
    verification:
      - kind: unit
        ref: "xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests (940 tests, 0 failures, 22 targets; downloads target 421 in 71 suites)"
        status: pass
    human_judgment: false

# Metrics
duration: 40min
completed: 2026-08-10
status: complete
---

# Phase 15 Plan 65: Self-Bracketing Queue-Intent Advance Summary

**CR-01 closed at its choke point: `advanceQueueIntentGeneration` now wraps its OWN increment in the D-G7-01 withdrawal bracket, so the credited drop a re-queue causes is given back to the monotonic floor at all four entrances by construction, and the first page of genuine work after a re-queue moves the card again.**

## Performance

- **Duration:** ~40 min
- **Started:** 2026-08-10T07:12Z
- **Completed:** 2026-08-10T07:52Z
- **Tasks:** 2 (RED, GREEN)
- **Files modified:** 5

## Accomplishments

- **The defect, stated as a property.** Since 15-61, regime 2 of the credited-pages definition counts a COMPLETE record raw only while this session's incomplete-observation for the gallery was stamped under the CURRENT queue-intent generation. That makes the generation increment a deliberate DOWNWARD mover of the very quantity the pushed numerator is summed from: for a gallery whose record this session watched complete, `sessionCreditedPages` steps from `recorded` to zero the instant the increment runs. Unwithdrawn, `lastPushedCompletedPageCount` kept its pre-movement value, so the floor sat exactly `recorded` pages above the honest sum and absorbed the next `recorded` pages of real work — the G-15-6/G-15-7 masking the floor's own doc forbids, and the stalled-task signal `ContinuedTaskScheduling`'s most-stalled expiration policy reads.
- **The fix is the review's exact shape, applied at the movement rather than at its callers.** `advanceQueueIntentGeneration(for:)` now runs its increment inside `withdrawingCountedBasisMovement(gid:)`. The bracket is `rethrows`, non-async and delta-keyed, so it costs the other movers nothing and it makes "whoever lowers the counted basis withdraws" true for entrances that do not exist yet. Not one of the four call sites was touched — that branch-scoped shape is what this phase has re-opened five times, and the review, the verification gap's `missing[]` sweep scope and the plan all name it as the thing to avoid.
- **Sibling composition is proved by CONSTRUCTION, not by a four-item inspection.** `withdrawingCountedBasisMovement` takes a non-async, non-escaping `() throws -> T`; all four callers of the advance are `async` functions. A caller therefore *cannot* appear lexically inside a bracket closure, so the advance's bracket can never be the inner half of a nest. The per-site audit below then only has to confirm what the type system already forces.
- **The retirement-ledger drop needed no second bracket, and the reason is a property rather than a lucky number.** When a departed gallery is re-queued, `reconcileRetiredSessionPages` drops its `retiredSessionPages` entry on the next push while its live credit reads zero — a second downward step on the same page count. It is covered by the same withdrawal because D-G2-01 retires *the credited-pages definition's own answer*: the ledger value equals what `sessionCreditedPages` read at the departure, and any change to that reading in between is itself a deliberate mover that was itself bracketed and already withdrew its own delta. Under the (now restored) invariant that every deliberate mover is bracketed, the floor's total reduction equals the numerator's total loss exactly.
- **No spurious rewind frame is introduced in the window between the withdrawal and the rejoin.** Between the advance and `queueStore.enqueue`, the floor has already dropped but the numerator still carries the retirement ledger, so any push landing there reads the unchanged pre-requeue value via `max()`. The card moves once, at the rejoin, and moves to the honest value.
- **The invariant is true against source again, and it now names the boundary it was missing.** `sessionCreditedPages`' regime-handoff paragraph enumerated two boundaries — the announce and the run exit — and concluded "deliberate movers are bracketed". A fresh queue intent is a third: no record moved and no run exited, so neither listed boundary covers it. It is now enumerated, with the reason its exemption travels with the movement rather than with a caller.
- **The regression discriminates a below-floor defect, which the sibling case structurally cannot.** `testARequeuedGalleryInheritsNoPredecessorObservationCredit` lands six keeper pages in a SINGLE flush; only the value after the jump is ever pushed, so a frozen frame inside it is unobservable. The new case lands the keeper's pages one at a time across the whole four-page absorption window — one page, one production flush, one observed frame — and pins the series.

## Task Commits

Each task was committed atomically:

1. **Task 1: RED — prove the re-queue's floor freezes the first post-requeue pages** - `2f9848e5` (test)
2. **Task 2: GREEN — the movement brackets itself; audit every exit path and the invariant doc** - `fe450ded` (fix)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` - `advanceQueueIntentGeneration` wraps its increment in `withdrawingCountedBasisMovement(gid:)` and gains a doc block deriving WHY the movement owns its bracket (the regime-2 equality, the masking it prevents, the four sibling callers, and why `prepareWorkingSeed`'s bracket cannot stand in — by the time the redo runs both of its endpoints read zero). The `lastPushedCompletedPageCount` writer-5 enumeration moved from four bracket call sites to five.
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` - doc only: the bracket's own composition section now records the movement-owned caller shape and its sibling disposition, and the module-internal rationale names all three files that hold callers outside it instead of only `+PublicAPI.swift` (a claim that was already stale before this plan).
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` - doc only: the regime-handoff paragraph on `sessionCreditedPages` gains the queue-intent boundary and re-derives its closing invariant.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` - new `testKeeperPagesLandingOneAtATimeMoveTheCardAfterARequeue` (177 lines with its derivation); the sibling case's "discriminates nothing" paragraph re-derived against post-fix source, with its assertions unchanged.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift` - the counted-basis bracket census gains `DownloadClient+Manager.swift: 1` and its total moves 4 → 5, with the derivation doc recording why this caller is a different shape and why a fifth queue entrance would move the *queue-entrance* census rather than this one.

## All-Exit-Path Audit: the four call sites

The advance has exactly four callers (`rg -n 'advanceQueueIntentGeneration' AppPackage/Sources AppPackage/Tests` → the declaration plus these four; no test forwarder calls it). Each is dispositioned against the bracket's sibling-composition rule (`+ExecutionSupport.swift:262-268`).

| # | Call site | Enclosing brackets on that path | Disposition |
|---|---|---|---|
| 1 | `performRetry` — `+RetryHelpers.swift:37` | None. `retry` → `performRetry` opens no bracket; `clearDownloadSessionState` before it and `queuedModes` / `queueStore.enqueue` / `notifyObservers` / `scheduleNextIfNeeded` after it are all outside any bracket. | **Sibling.** The advance's bracket is the only one on the path. |
| 2 | `performRetryPages` — `+RetryHelpers.swift:117` | None. `retryPages`' domain filter, `clearSelectedFailedPages` and `clearDownloadFailureState` open none. | **Sibling.** |
| 3 | `resume` — `+Scheduling.swift:360` | None. `resume` opens no bracket at all; `resumeMode` reads storage without one. | **Sibling.** |
| 4 | `enqueue` — `+PublicAPI.swift:107` | `writeInitialManifest`'s bracket exists on this path, opened at `:143` and CLOSED at `:157` — inside the call that returns at `:98`, nine lines before the advance. | **Sibling.** The bracket has already closed; nothing spans the advance. This is the site the review flagged as needing the check, and it is also why the old bracket could never see this drop: it measures both endpoints under the OLD generation. |

**The stronger, construction-level proof.** `withdrawingCountedBasisMovement<T>(gid:_:)` takes a non-async, non-escaping `() throws -> T`. All four callers are `async` (`performRetry(...) async throws`, `performRetryPages(...) async throws`, `resume(gid:) async`, `enqueue(payload:) async`), so none of them can be written inside a bracket closure without a compile error. Nesting is therefore refused by the type system, not merely absent at this HEAD. A future *synchronous* caller inside a bracket body would be the one shape that could nest; the census note in `DownloadSourceInventoryTests` and the bracket's own doc both now state the rule for whoever writes it.

**No second mover was found.** The plan named `reconcileRetiredSessionPages`:769-771 as the candidate residual. The RED test's first frame is honest post-fix (`0 / 24`, matching the honest sum exactly) and every one of the four one-at-a-time frames moves, so no residual drop remains unwithdrawn on this path. The derivation for why is in Accomplishments above: D-G2-01 retires the credited-pages definition's own answer, so the ledger drop and the bracket's delta are the same quantity.

## Invariant Re-Audit: `ContinuedSession.swift` regime handoff, clause by clause

| Clause (pre-fix text) | Verdict against post-fix source | Action |
|---|---|---|
| "At the announce, an honest record's raw count equals the inherited set's size…" | TRUE — unchanged by this plan; `prepareWorkingSeedAnnouncingProgress`'s two brackets still enclose the announce's movers. | Kept verbatim. |
| "…the deliberate downward movers (a record's positively-absent claims, a complete record's owed claims) are excused from the floor by the announce's own D-G7-01 bracket." | TRUE — still the announce's own bracket. | Kept verbatim. |
| "At a run exit, an honest record's raw count equals the final measurement… and a refusal-family departure retires the value `freezeSessionCreditForRetiringRun` published…" | TRUE — untouched. | Kept verbatim. |
| "No regime boundary can therefore drop the credited count on its own" | Was **FALSE** as written: the regime 2 → regime 3 boundary is crossed by a queue intent with no record movement and no run exit, so the two enumerated boundaries did not cover it. | Replaced: the queue-intent boundary is now enumerated as the third mover, with the note that it is the one this enumeration was missing (CR-01). |
| "deliberate movers are bracketed, and everything else only climbs" | Was **FALSE** for the queue-intent mover; TRUE for every other. | Re-derived as "every deliberate mover — including the one that moves no record at all — carries a D-G7-01 bracket", with the advance's self-bracketing named as why a later queue-mobilizing path inherits the exemption instead of needing instrumentation. |

The two other doc claims this change would have falsified were corrected in the same commit: the writer-5 sentence in `+Manager.swift` ("four call sites") and `withdrawingCountedBasisMovement`'s module-internal rationale ("one call site lives in `+PublicAPI.swift`").

## Decisions Made

- **DEC-A: the bracket wraps the movement, not the callers.** The review, the verification gap's `missing[]` and the plan all specify this, and the reason is the exhaustiveness burden: a call-site patch is an inventory that source can answer with one more entry, which is the failure mode this phase has lost repeated rounds to. The consequence is visible in the census — a fifth queue-mobilizing entrance now moves the *queue entrance* table (which already owns that inventory for the `validationErrors` rule) and needs no bracket work at all.
- **DEC-B: the regression's baseline is the RE-QUEUE frame, not the pre-requeue frame.** The plan's action line reads "assert the first post-requeue push exceeds the last pre-requeue push". Taken literally against post-fix production that is `1 > 4`, which is false — and it *should* be false: withdrawing a deliberate downward movement is meant to LOWER the card, so the pre-requeue `4 / 24` legitimately becomes `0 / 24`. Asserting across that boundary would have pinned the defect rather than the fix. The property the plan is actually after ("the pushed numerator must MOVE on the FIRST keeper page landed after the re-queue") is measured against the frame immediately before that page, which is the re-queue's own convergence push. Pre-fix that frame reads `4 / 24` — exactly "the pre-requeue floor value" the plan's acceptance criterion predicts for a frozen first frame — so the RED evidence matches the plan's stated expectation while the assertion stays true post-fix.
- **DEC-C: the case lands the WHOLE absorption window, not just the first page.** The masking is `recorded` pages deep (four here), so a fixture that stops before four never crosses the frame where the frozen series rejoins truth. The recorded pre-fix series `[4, 4, 4, 4]` against the honest `[1, 2, 3, 4]` shows both sides of the discontinuity: the fourth frame is where the floor stops absorbing, and it is the frame at which a coarser observation would have seen nothing wrong.
- **DEC-D: the re-queue frame is pinned exactly (`0 / 24`), not merely bounded.** That pins the withdrawal's *amount*, not just its existence — a fix that lowered the floor by the wrong number would still satisfy the "first page moves" inequality. Post-fix the frame equals the honest sum exactly, which is the property "withdraws exactly the portion the numerator was counting".
- **DEC-E: the fixture reuses 15-61's staging deliberately.** Same blocker idiom (the keeper is load-bearing twice — it keeps the session alive per D-06 and parks `activeTask` so every push is synchronous), same production entry points (`retry(gid:mode:.repair)`, `flushDownloadProgress(force: true)`, `settleCompletedDownload`, `scheduleNextIfNeeded`), same helpers. Nothing is installed through a testing setter; no test writes `queueIntentGenerations`, `retiredSessionPages`, `runProgressBases`, `observedIncompleteSessionGenerations` or `lastPushedCompletedPageCount`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The counted-basis bracket census refuses a new caller by design**

- **Found during:** Task 2 (GREEN)
- **Issue:** `DownloadSourceInventoryTests.testCountedBasisBracketCallSitesMatchTheRecordedCensus` asserts a per-file table of bracket CALL SITES (`expectedBracketCallSites`, total 4). Adding the advance's bracket moves that census, so the suite fails until the table is re-derived — which is precisely what the census exists to force. The plan's `files_modified` did not list this file.
- **Fix:** Added `"DownloadClient+Manager.swift": 1`, moved the total to 5, and did what the census's own failure message obliges before touching the number: re-derived the callers, confirmed none deletes inside its bracket, and confirmed none nests (the audit table above). The derivation doc records that this caller is a movement-owned bracket rather than a work-wrapping one, and that a fifth queue entrance therefore moves the queue-entrance census instead of this one.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift`
- **Verification:** `testCountedBasisBracketCallSitesMatchTheRecordedCensus` and `testFloorWriterAssignmentsMatchTheRecordedCensus` both green; the floor census is unchanged at 5 assignments, as its own blind-spot note predicts.
- **Committed in:** `fe450ded` (Task 2 commit)

**2. [Rule 1 - Bug] Two doc claims about the bracket's caller set became false**

- **Found during:** Task 2 (GREEN)
- **Issue:** `+Manager.swift:568` enumerated the bracket's "four call sites", and `+ExecutionSupport.swift:270` justified the bracket's module-internal access with "one call site lives in `DownloadClient+PublicAPI.swift`" — a sentence already stale before this plan (the validate-time caller lives in `+PersistenceNormalize.swift`) and made more so by adding a caller in `+Manager.swift`. Both are doc defects this change creates or deepens, in a project whose rule is that a doc must prove the property of the function as written. `+ExecutionSupport.swift` was not in the plan's `files_modified`.
- **Fix:** The writer-5 enumeration now lists five call sites naming the advance; the module-internal rationale names all three files holding callers outside `+ExecutionSupport.swift` and states the sibling disposition of the movement-owned caller shape. No claim's *substance* changed — both sentences still argue that one implementation is what stops the withdrawal rule from forking across routes.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift`, `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift`
- **Verification:** Clean build 0 warnings (SwiftLint plugin in-build), standalone SwiftLint `--strict` clean over both files, full suite green.
- **Committed in:** `fe450ded` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (1 blocking census, 1 doc-truth bug). Both are inside the task's scope boundary — each is a consequence of this change rather than a pre-existing issue in an unrelated file, and the census one is a hard build gate.
**Impact on plan:** Two files beyond the plan's declared `files_modified`, both required by the change itself. No production behaviour outside `advanceQueueIntentGeneration` was touched; no new type, file or public API.

## Banked Falsifiability

The RED case failed against pre-fix production with **3 verbatim issues**:

| Site | Pre-fix (recorded) | Post-fix (expected) |
|---|---|---|
| Re-queue frame pair | `completedUnitCount: 4`, `subtitle: "4 / 24 pages · 2 galleries"` | `completedUnitCount: 0`, `subtitle: "0 / 24 pages · 2 galleries"` |
| First-page inequality | `(firstPostRequeuePair.completedUnitCount → 4) > (requeueFramePair.completedUnitCount → 4)` failed | `1 > 0` holds |
| One-at-a-time series | `[4, 4, 4, 4]` — four frozen frames, each with the subtitle `"4 / 24 pages · 2 galleries"` | `[1, 2, 3, 4]` with the matching subtitles |

The frozen series is the defect stated as data: four pages of the keeper's genuine work produced no card movement whatsoever, and the fourth frame is where the stale floor stops absorbing and the two sides coincide again — which is exactly why the single-flush sibling case (six pages at once, landing past that point) could never observe it. The re-queue's generation was observed moving `0 → 1`, with the session id and `spy.startCount` unchanged on both sides of the fix.

## Issues Encountered

- **The plan's assertion as literally worded would have pinned the defect.** Resolved by DEC-B: the property was re-derived from what the withdrawal is *for* before writing the assertion, and the pre-fix evidence was checked against the plan's own predicted failure shape ("the first post-requeue push equals the pre-requeue floor value") to confirm the re-derivation describes the same defect.
- **File-size headroom.** `DownloadContinuedSessionTests.swift` grew 814 → 993 of the 1000-line limit. It fits, so per the plan no extraction was performed, but the file is now effectively closed to further growth — see Next Phase Readiness.

## Verification Evidence

Run one xcodebuild invocation at a time, with `-destination 'platform=iOS Simulator,id=ADE09605-A44E-4F00-BE12-235970217355'` substituted for the plan's ambiguous `name=iPhone Air`:

1. `-only-testing:DownloadsFeatureTests/DownloadContinuedSessionTests` before the fix — **TEST FAILED** (the 3 issues banked above, all in the new case).
2. `-only-testing:DownloadsFeatureTests/DownloadContinuedSessionTests -only-testing:DownloadsFeatureTests/DownloadSourceInventoryTests` after the fix — **TEST SUCCEEDED**, 30 tests in 2 suites; `testARequeuedGalleryInheritsNoPredecessorObservationCredit` green with its assertions unchanged.
3. Full `FeatureTests` — **TEST SUCCEEDED**, 940 tests / 0 failures across 22 targets (baseline 939, +1 for the new case); downloads target 421 tests in 71 suites.
4. `xcodebuild -scheme EhPanda -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/EhPandaPhase1565DerivedData build` — **BUILD SUCCEEDED**, **0 warnings, 0 errors** (the SwiftLint build-tool plugin runs in-build, so this is lint-clean over `Sources/`).
5. Standalone SwiftLint `--strict` over all 5 touched files (the app scheme does not lint `Tests/`) — **0 violations**.

Acceptance greps:

- `rg -n 'withdrawingCountedBasisMovement' AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` → 2 hits: the advance's own bracket at the call, and the writer-5 doc line.
- `rg -n 'advanceQueueIntentGeneration' AppPackage/Sources AppPackage/Tests` → 5 hits: the declaration plus the four production call sites; no test forwarder and no test calls it.
- Line lengths: no line over 120 in any touched file. File lengths: `+Manager.swift` 888, `+ExecutionSupport.swift` 961, `+ContinuedSession.swift` 969, `DownloadContinuedSessionTests.swift` 993, `DownloadSourceInventoryTests.swift` 911 — all under 1000.
- No `swiftlint:disable`, no `try?`, no force unwrap, no concurrency escape hatch introduced.

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadSourceInventoryTests.swift` — FOUND
- Commit `2f9848e5` — FOUND
- Commit `fe450ded` — FOUND

## Known Stubs

None. No hardcoded empty value, placeholder string or unwired data source was introduced.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- CR-01 (verification gap 1) is closed at the movement rather than at its callers, and the invariant the review found falsified reads true against source clause by clause.
- The remaining `15-REVIEW.md` blockers are untouched and independent of this plan: CR-03 (read paths still delete rejected page files and reconcile nothing) with WR-01/WR-02 in its wake, CR-02 (`deleteFolder`'s unconfined caller-supplied name), and the WR-04/WR-05 consequences of the CR-04 narrowing.
- **`DownloadContinuedSessionTests.swift` is at 993 of the 1000-line limit** and must be split before the next case or doc paragraph is added there. `DownloadFeatureTestHelpers.swift` remains at 989 with the same standing note from 15-60; this plan added nothing to it (the new case reuses `SessionGallery`, `makeQueuedCoordinator`, `galleryFolderURL`, `writePageFiles`, `pageResults`, `lastPushedPair`, `PushedPair` and `BlockingRunnerControl` unchanged).
- One census owed and paid: the counted-basis bracket table. The other seven `DownloadSourceInventoryTests` tables (scheduling blocks, floor writers, queue entrances, schedulable reads, pending-list evaluations, run-proof sites, client-double sites) were inspected and none covers `queueIntentGenerations` or the advance; the floor census stays at 5 assignments by its own stated blind spot.
- Open, non-blocking, carried forward and unchanged here: `DetailReducer.swift:112` names the superseded decision ID D-G5C-01, and `DetailDownloadRepairPredicateTests.swift` lines 13/52 still describe corrupt-in-place as a complete-claiming family member. Both comment-only, both in files this plan did not declare.

---
*Phase: 15-continued-background-downloads*
*Completed: 2026-08-10*
