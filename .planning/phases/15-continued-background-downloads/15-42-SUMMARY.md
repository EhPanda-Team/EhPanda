---
phase: 15-continued-background-downloads
plan: 42
subsystem: downloads
tags: [swift, downloads, continued-processing, reentrancy, expiration, swift-testing]

requires:
  - phase: 15-continued-background-downloads
    provides: "15-23's `ExpirationPauseOwnership` and the `.superseded` rescue arm, whose per-iteration generation read this plan narrows"
provides:
  - "G-15-22 closed at the invariant: `pauseAllSchedulable` records every gallery's queue-intent generation in the same synchronous stretch that takes the gid snapshot"
  - "A mobilizing tap landing anywhere after the sweep's snapshot forces `.superseded` and its re-converge-and-re-ensure rescue, so the tap always produces either running covered work or a rescued session"
  - "The multi-gallery mid-sweep regression `testAMobilizationLandingBeforeItsOwnIterationSurvivesTheExpirationSweep`, with the session-start discriminator that separates the rescue from the tap's own deferred ensure"
  - "The mobilizer census re-derived at execution time: four `advanceQueueIntentGeneration(for:)` callers, none stamping `continuedSessionID` before advancing"
affects: [continued-background-downloads verification, SC1, SC3]

tech-stack:
  added: []
  patterns:
    - "Capture the comparison's expectation in the same synchronous stretch as the work list, so a late arrival advances a value the loop has already recorded rather than one it is about to read"
    - "A file-private named pair (`ExpirationPauseTarget`) rather than a tuple, because unlabeled tuple types are error-severity here"
    - "A doc roster of test consumers replaced by the rule every consumer obeys, so the next added case cannot make it false"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift

key-decisions:
  - "15-42: the regression stages BOTH galleries queued, deviating from the plan's `NOT in queuedGIDs` wording for the mobilized one. With that gallery outside the queue it is not schedulable at snapshot time, so the sweep's gid list never contains it, it gets no iteration, and neither the defect nor the fix is expressible — the case would have been RED before and after. Queueing both is what gives the tap an iteration to land ahead of."
  - "15-42: the walk order is fixed by production rather than by the fixture. `downloads(from:)` sorts on `displayStatus.sortPriority`, and `.active` (0) precedes `.queued` (1), so the held gallery is always visited first once it is running. No ordering assumption is imported from `queuedGIDs`."
  - "15-42: the mobilized gallery's expected queue intent is derived in the test from `resumeMode(for:)` against the staged record, not hard-coded, so the assertion pins the intent production records rather than a transcription of it."
  - "15-42: `testingContinuedSessionTask()`'s four-consumer roster was replaced by the invariant it stood for (capture before firing the expiration). Adding a fifth consumer would have made a counted roster false — the exact doc-vs-source generator that has produced a gap in five consecutive rounds."

patterns-established:
  - "A discriminator assertion taken BEFORE the deferred production event: `spy.startCount == 2` at a point where only the `.superseded` rescue can have minted a session proves the loop reached the target's iteration, which a post-ensure reading could not distinguish from an early return"

requirements: [SC1, SC3]
status: complete
---

# Phase 15 Plan 42: Snapshot-Stretch Expiration Pause Ownership Summary

`pauseAllSchedulable` now records each gallery's queue-intent generation with the gid snapshot instead of at that gallery's own iteration, so a tap landing in the `[advance, ensure)` window ahead of its iteration is rescued by `.superseded` rather than paused away.

## What was built

**Task 1 — the regression, RED-first** (commit `5cee098c`).
`testAMobilizationLandingBeforeItsOwnIterationSurvivesTheExpirationSweep` in
`AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift`.
Two galleries are staged through `makeQueuedCoordinator`, both queued. A per-gid parking runner is
built locally from the existing `BlockingRunnerControl` idiom: the held gallery's control stays
parked through cancellation, the mobilized one's releases on cancellation so the pre-fix sweep can
settle instead of deadlocking against the very pause under test. No shared helper was added or
duplicated.

Choreography, all production-issued:

1. `testingEnsureContinuedSession()`, session task captured, `spy.startCount == 1`.
2. `resume(gid: held)`, then `heldControl.started()` — the held gallery is running.
3. `spy.expire()` — the production `.expired` arm runs `markContinuedSessionEnded` then
   `pauseAllSchedulable`; `heldControl.cancellationObserved()` parks the test at the sweep's
   `await taskToCancel?.value` suspension inside `commitPause`.
4. `resume(gid: mobilized)` runs to completion inside that hold — the generation advances after the
   sweep's snapshot, the gallery is enqueued and scheduled, and its run parks. Its trailing ensure
   is deliberately not issued: production issues it one frame up in `togglePause`.
5. Release, settle on the captured session task with `waitForTaskValue`.
6. `#expect(spy.startCount == 2)` BEFORE the deferred ensure — the discriminator.
7. The deferred ensure, commented as standing for `togglePause`'s trailing
   `ensureContinuedSession()`, asserted inert.
8. Final state: mobilized gid still queued with its derived mode, session live, held gid genuinely
   paused, no rejected pushes.

**Task 2 — the hoist** (commit `92a5707b`).
`pauseAllSchedulable(expiring:)` now builds a `[ExpirationPauseTarget]` — a file-private `gid` +
`expiration` pair, chosen over a tuple because `labeled_tuple_elements` is error-severity here — in
the same expression as the `schedulableDownloads()` read. The loop consumes only recorded pairs; the
per-iteration `queueIntentGeneration(for:)` read and per-iteration `ExpirationPauseOwnership`
construction are gone. The loop-level session guard is unmoved. `ownsExpirationPause`, `commitPause`
and the user-pause side are untouched: the fix narrows WHEN the expectation is read, never WHAT the
comparison accepts.

## RED evidence and the green flip

Observed at the Task 1 HEAD (targeted run, `** TEST FAILED **`, 5 issues), exactly the four readings
the plan predicted:

| Reading | RED (pre-fix) | GREEN (post-fix) |
|---|---|---|
| `spy.startCount` before the deferred ensure | `1` (`(spy.startCount → 1) == 2` at `:155`) | `2` |
| `spy.startCount` after the deferred ensure | `1` (`:160`) | `2`, inert |
| `queueStore.contains(mobilizedGID)` | `false` (`:162`) | `true` |
| `queuedModes[mobilizedGID] == mobilizedMode` | failed — the intent was `nil` (`:163`) | equal |
| `testingHasContinuedSession()` | `false` (`:164`) | `true` |

Two assertions passed in BOTH runs, which is what keeps the case honest rather than
vacuously failing: `queueStore.contains(heldGID) == false` (the loop ran its first iteration to
completion) and `spy.rejectedProgressUpdates.isEmpty`.

In the same RED run all three pre-existing interleave cases passed byte-unchanged:
`testAUserPauseIsNeverAbandonedByAnInterleavingRetry`,
`testAResumeInsideAStaleExpirationPauseSurvivesAndMobilizesTheQueue`,
`testWorkMobilizedInsideTheTerminalPushSurvivesTheDrain`. All four pass post-fix
(`** TEST SUCCEEDED **`, 61.7 s), and the full `FeatureTests` plan is green in one invocation
(`** TEST SUCCEEDED **`, 97.7 s, exit `0`) with the pre-existing known issues unchanged.

## The mobilizer census, re-derived

Grep over `AppPackage/Sources/DownloadClient` for `advanceQueueIntentGeneration(for:)` — four
callers, matching the verification's enumeration exactly:

| Caller | Advance | Suspensions between advance and ensure | Ensure | Stamps `continuedSessionID` first? |
|---|---|---|---|---|
| `enqueue(payload:)` | `+PublicAPI.swift:99` | `await queueStore.enqueue`, `await notifyObservers()`, `await scheduleNextIfNeeded()` | `+PublicAPI.swift:107`, same frame | no |
| `resume(gid:)` | `+Scheduling.swift:360` | `await queueStore.enqueue`, `await notifyObservers()`, `await scheduleNextIfNeeded()`, then the return itself | `+PublicAPI.swift:194`, one frame up in `togglePause` | no |
| `performRetry` | `+RetryHelpers.swift:37` | `await queueStore.enqueue`, `await notifyObservers()`, `await scheduleNextIfNeeded()` | `+RetryHelpers.swift:18`, one frame up in `retry` | no |
| `performRetryPages` | `+RetryHelpers.swift:89` | `await queueStore.enqueue`, `await notifyObservers()`, `await scheduleNextIfNeeded()` | `+RetryHelpers.swift:70`, one frame up in `retryPages` | no |

The falsification condition does not fire, and it is checked from the other side too:
`continuedSessionID` has exactly two writers in the whole module — `ensureContinuedSession`
(`+ContinuedSession.swift:201`) and `markContinuedSessionEnded` (`:332`) — and no mobilizer reaches
either before its advance. No fifth mobilizer exists. Closure is therefore derivable, not asserted,
and the plan did not have to stop on a discrepancy.

## The corrected doc, quoted

The stale paragraph (`grep -c 'when this loop chose it'` now returns `0`) is replaced by:

> **Every target's ownership is captured WITH the gid list, never at that target's own iteration
> (G-15-22).** Each pause is bound to the expiring session and to the queue-intent generation that
> was current when the SWEEP chose its targets, so a D-07 tap landing anywhere after that capture —
> including in the whole stretch before the tapped gallery's iteration is reached — advances a
> generation this loop has already RECORDED. `ownsExpirationPause` then fails, the stale pause
> abandons its write as `.superseded`, and that arm re-converges and re-ensures, which is what
> starts the session the tap asked for. Read at each iteration instead, the expectation for a
> gallery the tap had already moved was the advanced value compared against itself: the pause
> settled over the user's action, the design's own compensation never ran, and the tap produced
> nothing at all.
>
> The capture stretch is synchronous, which is what makes every recorded expectation a pre-tap one:
> `schedulableDownloads()` performs no suspending call today — `queueStore.gids` is a synchronous
> property read and `indexedDownloads(gids:)` awaits nothing — so nothing can interleave between
> that read and the pairs built from it. An `await` introduced there reopens exactly this window and
> needs its own re-validation, which is the note `ensureContinuedSession` and
> `pushContinuedSessionProgress` already record for their own guards.

The suspension-free claim was re-derived rather than copied: `schedulableDownloads()`
(`+PendingWork.swift:42-52`) reads `queueStore.gids` (a synchronous property over a `Mutex`-backed
`Shared` value), appends `activeGalleryID`, and calls `indexedDownloads(gids:)`, whose body —
`downloads(from:)` → `deduplicatedDownloadIndex` → `downloadedGallery` → `sorted` — contains no
`await` at all. Both are same-actor and neither suspends. Per the plan's prohibition, the
justification names only those two facts; it does not repeat the standing false claim that
`schedulableDownloads()` is an authority the scheduler reads (that sentence is G-15-24's, left for
plan 15-44).

## Prohibitions, checked

| Prohibition | Status |
|---|---|
| Must NOT widen `ownsExpirationPause` or add a generation guard to the user-pause side | Held. `git diff` shows `DownloadClient+Scheduling.swift` byte-unchanged, and `testAUserPauseIsNeverAbandonedByAnInterleavingRetry` and `testAResumeInsideAStaleExpirationPauseSurvivesAndMobilizesTheQueue` pass byte-unchanged in both runs. |
| Must NOT describe `schedulableDownloads()` as an authority the SCHEDULER reads | Held. The new doc names only the two suspension facts. `grep` confirms no new `schedulableDownloads()` call site: three, as before (`+PendingWork.swift:14`, `+ContinuedSession.swift:132`, `:383`). |
| Must NOT hand-issue any push or session start in the regression | Held. The case body enters the sweep only through `spy.expire()`, mobilizes only through `resume(gid:)`, contains no `pauseAllSchedulable` and no direct push call, and carries exactly two `testingEnsureContinuedSession()` calls — the staging one and the deferred one with its naming comment. |
| Must NOT reach for a concurrency/lint escape hatch, a SwiftLint suppression, or an unlabeled multi-element tuple type | Held. `ExpirationPauseTarget` is a named struct; `swiftlint --strict` reports 0 violations over all three touched files; no `// swiftlint:disable` anywhere in the diff. |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] The plan's staging for the mobilized gallery could not express the regression**

- **Found during:** Task 1
- **Issue:** The behavior block specifies gallery B as "incomplete, NOT in `queuedGIDs`". Traced
  through source, that staging cannot reach the defect. `schedulableDownloads()` takes the scoped
  branch whenever `queueStore.gids` is non-empty, and a gallery that is neither queued nor active is
  outside the scope; even on the empty-queue branch `shouldSchedule` rejects an `.inactive`
  incomplete record with no `queuedPageSelections` entry. So B is absent from the sweep's gid
  snapshot, gets no iteration, is never paused, and can never go `.superseded` — the case would have
  read RED both before and after the fix, and `spy.startCount == 2` would have been unreachable.
- **Fix:** Both galleries are staged queued (`queuedGIDs: [heldGID, mobilizedGID]`). The mobilized
  gallery is then in the snapshot with an iteration of its own, which is exactly the shape the gap's
  own detail describes — the loop reaches its iteration, reads the already-advanced generation, and
  `commitPause`'s `[.queued, .active]` gate admits it. Everything else in the behavior block is
  unchanged, including the multi-gallery requirement, the tap landing before its own iteration
  (never inside its pause), and the discriminator ordering.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift`
- **Commit:** `5cee098c`

**2. [Rule 2 - Missing correctness] `testingContinuedSessionTask()`'s consumer roster went stale**

- **Found during:** Task 2
- **Issue:** That seam's doc enumerated "Four consumers" by name. The new regression is a fifth, so
  the count and the roster became false the moment Task 1 landed — the doc-vs-source generator that
  has produced a promoted gap in five consecutive rounds of this phase.
- **Fix:** The roster is replaced by the rule every consumer obeys ("the capture must be taken
  BEFORE the expiration is fired, since the handler nils the property on its way through"), so no
  future case can falsify it. Same treatment 15-40 applied to IN-01.
- **Files modified:** `AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift`
- **Commit:** `92a5707b`

### Authentication Gates

None.

## Not claimed by this plan

The physical-device UAT re-run (`15-UAT.md` test 2) stays open. The backstop truth — a download tap
landing while an expiration sweep is pausing another gallery still starts its session on iOS 26
hardware — is recorded, not discharged.

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` — FOUND
- `AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift` — FOUND
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift` — FOUND
- `.planning/phases/15-continued-background-downloads/15-42-SUMMARY.md` — FOUND
- commit `5cee098c` — FOUND
- commit `92a5707b` — FOUND
- `grep -c 'testAMobilizationLandingBeforeItsOwnIterationSurvivesTheExpirationSweep'` in the
  interleave suite — `1`
- `grep -c 'when this loop chose it'` in `+ContinuedSession.swift` — `0`
- `git diff` for `+Scheduling.swift` — empty
