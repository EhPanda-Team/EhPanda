---
phase: 15-continued-background-downloads
verified: 2026-08-04T17:10:00Z
status: human_needed
score: 3/4 must-haves verified
behavior_unverified: 1
overrides_applied: 0
next_action: "Re-run UAT test 2 on a physical iOS 26 device: the G-15-2 defect it found is fixed in code but has never been re-observed on hardware."
next_command: "/gsd:verify-work 15"
re_verification:
  previous_status: human_needed
  previous_score: 1/4
  gaps_closed:
    - "G-15-2 — a gallery finishing mid-session collapsed the card to a 100% fraction and a shrinking gallery count, freezing the numerator the scheduler reads as a liveness signal."
  gaps_remaining: []
  regressions: []
behavior_unverified_items:
  - truth: "SC2 — the system-provided progress UI reflects real download progress and its cancel affordance stops the queue, leaving state consistent with an in-app cancel."
    test: "On a physical iOS 26 device, queue at least three galleries of clearly different sizes, start in the foreground, background the app, and watch the system card across the FIRST gallery's completion and then across a manual pause of one remaining gallery. Then cancel from the card, foreground, and compare queue state against pausing each gallery by hand."
    expected: "The card's completed count keeps climbing past the first gallery's completion instead of pinning at 100%; the total does not shrink; the subtitle keeps naming the remaining galleries; the remaining galleries keep downloading; a pause leaves the card still able to reach completion; card-cancel leaves the same state as the in-app per-gallery pause."
    why_human: "This is the exact behavior the device UAT found broken (15-UAT.md test 2, result `issue`). The fix is a change to pushed arithmetic, proven deterministically by DownloadContinuedSessionLedgerTests, but the card is rendered by system UI outside the app and neither it nor the scheduler's stall-detection response exists in the simulator. The UAT record has not been re-run since the fix landed."
human_verification:
  - test: "Re-run 15-UAT.md test 2 on a physical iOS 26 device with a multi-gallery queue, watching the card across the first gallery's completion and across a mid-queue pause, then cancelling from the card."
    expected: "Counts advance past the first completion, the total holds, the subtitle names the remaining galleries, the queue keeps downloading, and card-cancel matches the in-app per-gallery pause baseline."
    why_human: "The reported defect was device-observed; the card and the scheduler's stall handling do not exist in the simulator, and the UAT record still reads `result: issue`."
gaps: []
deferred: []
---

# Phase 15: Continued Background Downloads Verification Report

**Phase Goal:** Adopt `BGContinuedProcessingTask` (iOS 26) so a gallery download the user just
started keeps running when the app is backgrounded, surfaced by the system-provided progress UI,
instead of being cut short by the short grace period that bounded the previous behavior.

**Verified:** 2026-08-04T17:10:00Z
**Status:** `human_needed`
**Re-verification:** Yes — after gap-closure plans 15-20 and 15-21, and after the device UAT that
produced gap G-15-2.

**Canonical next action:** Re-run UAT test 2 on a physical iOS 26 device.
**Canonical next command:** `/gsd:verify-work 15`

Every claim below was re-derived from current source before any SUMMARY was read. Build and full
suite results were supplied by the orchestrator at this HEAD (`d246b1a3`, working tree clean):
`BUILD SUCCEEDED`, and `** TEST SUCCEEDED **` for 656 tests across 11 targets. Per the one-run
rule no test was re-run in isolation; that single run is the execution evidence for every named
case below.

## Goal Achievement

### Observable Truths

| # | Roadmap success criterion | Status | Evidence |
|---|---|---|---|
| SC1 | A foreground-started download continues to completion after backgrounding, for a queue large enough to outlast the old grace period | ✓ VERIFIED | Device UAT test 1 recorded `result: pass` on physical iOS 26 hardware: pages kept landing well past the deleted `beginBackgroundTask` window, none lost or duplicated. The code path is complete and unblocked — `ensureContinuedSession()` fires from `enqueue` (`+PublicAPI.swift:98`), the `.inactive` resume branch (`+PublicAPI.swift:174`), `retry` and `retryPages` (`+RetryHelpers.swift:18, 70`) and the superseded-pause tail (`+Scheduling.swift:184`); the plist permits `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`. Two coverage asymmetries are recorded as warnings below; neither falsifies the criterion |
| SC2 | System UI shows real progress and card cancel matches an in-app cancel | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | The half that device UAT tested and accepted (one neutral card, monotonic counts, card-cancel parity) passed. The half it rejected — multi-gallery progress across a gallery completion — is now fixed in code by the retirement ledger and pinned by a non-vacuous regression suite, but has **never been re-observed on a device**. `15-UAT.md` test 2 still reads `result: issue` |
| SC3 | Best-effort refusal/queue/expiration: no fallback tier, no loss, no duplication, no visible error | ✓ VERIFIED | Device UAT test 3 recorded `result: pass` — refusal, expiration and force-quit relaunch produced no crash, no visible error, no lost or duplicated pages, and work resumed on foreground. The deletion half is independently proven: no source in `App/`, `AppPackage/` or `ShareExtension/` names `BGProcessingTask`, `beginBackgroundTask`, `BackgroundTaskClient` or `runQueueUntilIdle` (grep, excluding the invariant test that pins them), and `BackgroundExecutionInvariantTests` enforces it permanently |
| SC4 | A testable session seam in `BackgroundProcessingClient` exposing start/update/complete with a self-finishing event stream, unimplemented default, no direct scheduler access | ✓ VERIFIED | `BackgroundProcessingClient.swift` declares exactly three `@DependencyClient` endpoints returning/consuming an identified `BackgroundProcessingSession`; `import BackgroundTasks` occurs in exactly one file in the whole tree (`ContinuedTaskScheduling.swift`); `testUnimplementedClientReportsAnIssueForEveryEndpoint` covers the macro-generated unimplemented value |

**Score:** 3/4 roadmap truths verified (1 present, behavior-unverified)

The next milestone phase is Phase 16 (Dynamic Type Accessibility), which covers none of this work.
Nothing is deferred.

## Gap G-15-2 — Re-verified in Source — ✓ CLOSED

The device report was: with multiple galleries queued, one finishing early made the card report
completion and collapse its description to "1 gallery", leaving the rest apparently stalled.

Root cause confirmed in the pre-fix shape: progress was summed over the *currently schedulable*
set alone, so a finished gallery's pages left the numerator and the denominator together, the
`max()` floor held the numerator at its pre-shrink value, and the total clamp lifted the
denominator to meet that floor — pinning the fraction at exactly 1.0.

The fix is a session-scoped retirement ledger, traced end to end:

- `DownloadClient+Manager.swift:421-435` declares `retiredSessionPages` (per-gallery, not a
  scalar — a scalar could not be corrected on rejoin) and `observedSchedulablePages`, both cleared
  on session start (`+ContinuedSession.swift:132-134`) and on teardown (`:237-238`).
- `schedulableSnapshot()` (`:62-79`) yields the summed progress and the per-gallery finished counts
  from **one** index read, so the ledger cannot disagree with the sums it corrects.
- `reconcileRetiredSessionPages(finishedPages:)` (`:323-350`) applies D-G2-01: rejoiners are
  released first (`retiredSessionPages[gid] = nil`), departures are then valued from the
  authoritative record (`min(max(completed, 0), pageCount)`), falling back to the last observation
  only when the record is gone (deleted outright), and the observed map is replaced so each
  departure is detected exactly once.
- `pushContinuedSessionProgress` (`:385-420`) adds the retired total to the **raw** pair before the
  single display clamp, which is what stops `displayPageCount`'s one-page floor from contributing a
  phantom page and making a drained queue unable to report exactly 1.0.

Independent arithmetic check against the reported scenario: gallery A (10 pages, 6 done) plus
gallery B (4 pages, 0 done) opens at 6/14. A completes and `settleCompletedDownload` removes it
from the queue store; the next push retires A at 10 and reports 10/14 · 1 gallery — the count
advances, the total holds, and the fraction stays strictly below one. That is `testACompleted
GalleryHoldsTheTotalAndAdvancesTheCount`'s exact assertion.

**The sweep is at the membership level, not on the reported branch.** This is the one place the
phase's recurring failure mode (a fix scoped to the branch a report named) was explicitly avoided,
and the code says so at `:312-315`: membership is swept at the single point that already reads the
schedulable set, so completion, pause, delete, queued-work-item cancel, the expiration pause-all and
a scheduling block all retire through one formula with no call site classifying *why* a gallery left.
I verified there is no departure-reason parameter anywhere in the production path.

**The defect is no longer encoded in the suite.** All three committed expectations that asserted the
shrinking basis were re-derived rather than supplemented (`git show --stat 425b5a8b`:
`DownloadContinuedSessionTests.swift` 90 lines changed, insertions *and* deletions):
`"6 / 14 pages · 2 galleries"` → `"10 / 14 pages · 1 gallery"` (the regression case),
`"2 / 6 pages"` → `"6 / 6 pages · 0 galleries"` (the honest drain), and
`"4 / 8 pages · 2 galleries"` → `"4 / 8 pages · 1 gallery"` (an already-complete gallery retiring
its three pages to both sides).

**Non-vacuity independently reasoned, not just claimed.** Mentally removing `retiredPageCount` from
the push makes `testPausedGalleryRetiresOnlyItsFinishedPages` report `6 / 6 pages · 1 gallery`
against its expected `6 / 10` — the case fails. The executor's recorded deliberate-break run (8 of
33 cases failing with the ledger contribution removed, tree restored before commit) is consistent
with that. Recorded in `15-21-SUMMARY.md` rather than in code, which is weaker pinning than a
committed canary but is a genuine observation.

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `App/Info.plist` | One bundle-scoped continued wildcard | ✓ VERIFIED | Single `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*` entry; `processing` background mode retained with a written justification at lines 160-165 |
| `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift` | Identified start/update/finish seam | ✓ VERIFIED | Three `@DependencyClient` endpoints; `.live` composed directly, injected at `DownloadClient.swift:77` |
| `.../ContinuedProcessingSession.swift` | Main-actor task/session store | ✓ VERIFIED | Single-session guard evaluated and written in one synchronous run (85-98); real seed from the caller's snapshot (97-98); identity-gated `updateProgress`/`finish` (170, 186); per-session UUID identifier (125) |
| `.../ContinuedTaskScheduling.swift` | Sole scheduler adapter | ✓ VERIFIED | The only file in `App/`, `AppPackage/` and `ShareExtension/` importing `BackgroundTasks` |
| `.../DownloadClient+ContinuedSession.swift` | Session lifecycle + retirement ledger | ✓ VERIFIED | `schedulableSnapshot`, `reconcileRetiredSessionPages`, ledger summed into the raw pair before one clamp; ownership re-checked after each of the two suspensions in the push |
| `.../DownloadClient+Manager.swift` | Ledger state and its rationale | ✓ VERIFIED | `retiredSessionPages` / `observedSchedulablePages` declared and documented; ACTIVE-OWNERSHIP CONVERGENCE invariant stated at 345 |
| `.../DownloadClient+PendingWork.swift` | Single schedulable-work authority | ✓ VERIFIED | `hasPendingWork` and `schedulableDownloads` remain the one selection path shared by scheduler, gate and card |
| `.../DownloadClient+PublicAPI.swift` | User actions converge scheduling/session state | ✓ VERIFIED | All three ownership-clearing exits of `delete` converge (196-223) |
| `.../DownloadClient+Folders.swift` | Second removal entry point converges | ✓ VERIFIED for `deleteFolder` (both catch branches, 116-135); see WR-01 for `moveDownload` |
| `AppPackage/Tests/.../DownloadContinuedSessionLedgerTests.swift` | Ledger regression suite | ✓ VERIFIED | 418 lines, 6 cases: sequential completions holding the denominator, order-independence, an emptied live sum, pause departure, delete departure, rejoin; plus reusable monotonicity and fraction-reaches-one-only-at-drain helpers |
| `AppPackage/Tests/.../DownloadContinuedSessionTests.swift` | Re-derived expectations | ✓ VERIFIED | The three defect-encoding literals replaced, not supplemented |
| `AppPackage/Tests/.../BackgroundExecutionInvariantTests.swift` | Permanent topology guard | ✓ VERIFIED | 266 lines; scans app, package sources, package tests, extension and the plist |
| `AppPackage/Tests/.../DownloadLogPrivacyInvariantTests.swift` | Permanent privacy scan | ✓ VERIFIED | 158 lines, two non-vacuous tests; device UAT test 4 confirmed the collected-archive half |
| `.../BackgroundProcessingClient/.swiftlint.yml` | New-module lint inheritance | ✓ VERIFIED | `parent_config: ../../../.swiftlint.yml` |

## Key Link Verification

| From | To | Via | Status |
|---|---|---|---|
| Plist wildcard | Runtime identifiers | Bundle prefix plus `.continued.<UUID>` | ✓ WIRED |
| Live client closures | Session store | Main-actor `start`/`updateProgress`/`finish` | ✓ WIRED |
| Session store | System scheduler | `ContinuedTaskScheduling.live` | ✓ WIRED |
| `settleCompletedDownload` (queue-store removal) | Retirement ledger | Departure observed on the next push's membership sweep | ✓ WIRED |
| Throttled page flush | Card | `flushDownloadProgress` → `pushContinuedSessionProgress` under session identity | ✓ WIRED |
| `pause` / `delete` | Retirement ledger | Both converge on `scheduleNextIfNeeded` → `reconcileContinuedSession` → push | ✓ WIRED |
| User taps (enqueue, resume, retry ×2, superseded-pause) | `ensureContinuedSession()` | Success-path calls | ⚠️ PARTIAL — `refreshDownloads` is a sixth queue-mobilizing entry point that does not call it (CR-01) |
| Ownership-clearing exits | Queue convergence | Block release, `notifyObservers()`, `scheduleNextIfNeeded()` | ⚠️ PARTIAL — `moveDownload` takes a scheduling block across three suspensions and converges on no exit (WR-01) |

## Data-Flow Trace

| Data | Source | Sink | Status |
|---|---|---|---|
| Live completed/total counts | One schedulable index read (`schedulableSnapshot`) | Raw pair, then one display clamp | ✓ FLOWING |
| Retired pages | Per-gallery membership difference against the authoritative record | Both sides of every later push | ✓ FLOWING — was the defect |
| Subtitle gallery count | Live schedulable count only | System card subtitle | ✓ FLOWING (D-06/D-10 preserved) |
| Card text | Localized integer-only builder | System title/subtitle | ✓ FLOWING, no gallery identity |
| Operational log identity | Gallery gid | Hash-masked private field | ✓ NON-DISCLOSING (device archive confirmed, UAT test 4) |

## Behavioral Spot-Checks

| Behavior | Evidence | Status |
|---|---|---|
| A completed gallery holds the total and advances the count | `testACompletedGalleryHoldsTheTotalAndAdvancesTheCount` passed in the suite run | ✓ PASS |
| Three sequential completions hold the denominator, in both completion orders | `testSequentialCompletionsHoldTheDenominatorAndAdvanceTheCount`, `testReportedTotalsDoNotDependOnCompletionOrder` passed | ✓ PASS |
| A pause and a delete retire identically (one shared expected pair) | `testPausedGalleryRetiresOnlyItsFinishedPages`, `testDeletedGalleryRetiresTheSamePagesAsAPause` passed | ✓ PASS |
| A rejoining gallery is counted once, not twice | `testResumedGalleryIsCountedOnce` passed | ✓ PASS |
| The fraction reaches one only at the drain; the numerator never rewinds | `expectTheFractionReachesOneOnlyAtTheDrain`, `expectTheCompletedSeriesNeverRewinds` over whole update series | ✓ PASS |
| Card cancel leaves the per-gallery in-app pause baseline | `testExpirationLeavesTheQueueInThePerGalleryPauseBaselineState`, `testExpirationLeavesTheSchedulingBlockedSetAsAPauseDoes` passed | ✓ PASS |
| Drain during an in-flight start defers reconciliation and keeps coverage | `testADrainDuringAnInFlightStartDefersReconciliationAndKeepsCoverage` passed | ✓ PASS |
| Failed removal still converges the queue (both entry points, both error shapes) | `testAFailedRemovalStillConvergesTheQueue`, 4 cases, passed | ✓ PASS |
| Unimplemented client reports an issue on every endpoint | `testUnimplementedClientReportsAnIssueForEveryEndpoint` passed | ✓ PASS |
| No public log interpolation exposes gallery identity | `testNoDownloadLogPublishesGalleryIdentity`, `testDownloadIdentityLogsStayHashMasked` passed | ✓ PASS |
| No deleted background-execution spelling survives | `BackgroundExecutionInvariantTests` passed; independently reproduced by grep | ✓ PASS |
| Multi-gallery card rendering after the ledger fix | Requires physical iOS 26 hardware | ? DEVICE BACKSTOP |

## Probe Execution

No phase-declared or conventional `probe-*.sh` scripts exist in this repository.

## Requirements Coverage

`.planning/REQUIREMENTS.md` maps no requirement IDs to Phase 15 and contains no Phase 15 orphan.
The scope contract is the four roadmap success criteria. All 21 plans declare `requirements:` drawn
only from `SC1`–`SC4`, and every one of the four is claimed by at least one plan.

| Contract | Source plans | Status |
|---|---|---|
| SC1 | 15-05..15-13, 15-17..15-21 (and 15-06, 15-07) | ✓ SATISFIED — device-confirmed, with two recorded warnings |
| SC2 | 15-04, 15-06, 15-07, 15-12..15-15, 15-17, 15-19, 15-20, 15-21 | ⚠️ NEEDS HUMAN — fix present, wired and deterministically tested; device re-check outstanding |
| SC3 | 15-01, 15-02, 15-06, 15-07, 15-14, 15-15 | ✓ SATISFIED — device-confirmed |
| SC4 | 15-01, 15-03, 15-04, 15-07, 15-16 | ✓ SATISFIED |

## Anti-Patterns Found

No `TBD`, `FIXME`, `XXX`, `TODO`, `HACK` or `PLACEHOLDER` marker exists anywhere in
`AppPackage/Sources/DownloadClient`, `AppPackage/Sources/BackgroundProcessingClient`,
`AppPackage/Tests/DownloadsFeatureTests` or `App/Info.plist`. The debt-marker gate reads zero.

No `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency` or SwiftLint suppression exists
in phase source or tests.

## Prohibitions

| Prohibition (plans 15-20, 15-21) | Status | Evidence |
|---|---|---|
| Must NOT reopen D-06 / D-10 — one queue-wide session, one summed page fraction | ✓ VERIFIED | Session end condition remains `hasPendingWork() == false`; no per-gallery completion predicate exists; `testSecondMobilizingActionDuringLiveSessionStartsNoSecondSession` passes |
| Must NOT change the subtitle's gallery count away from the remaining schedulable count | ✓ VERIFIED | `pushed.galleryCount` is taken raw from the live snapshot (`:412`); the ledger never touches it |
| Must NOT remove `settleCompletedDownload`'s queue-store removal | ✓ VERIFIED | Present and used as the staging step in the ledger suite |
| Must NOT retire a departed gallery's unfinished pages into the denominator | ✓ VERIFIED | `min(max(record.completedPageCount, 0), record.pageCount)` — finished pages only; `testPausedGalleryRetiresOnlyItsFinishedPages` asserts the total drops from 14 to 10 |
| Must NOT count a rejoining gallery in both the ledger and the live sum | ✓ VERIFIED | Rejoiners released before departures are computed (`:326-328`); `testResumedGalleryIsCountedOnce` asserts `[6, 6, 6]` / `[14, 10, 14]` |
| Must NOT special-case the departure reason in production code | ✓ VERIFIED by inspection | `reconcileRetiredSessionPages` has no reason parameter and no branch on how a gallery left; one formula, swept from membership |
| Must NOT supplement the defect-encoding cases while leaving old expectations in place | ✓ VERIFIED by inspection and by diff | All three literals replaced |
| Must NOT introduce a second background-execution tier | ✓ VERIFIED | Grep plus `BackgroundExecutionInvariantTests` |
| Must NOT put content identity into system-card strings | ✓ VERIFIED | `continuedSessionSubtitle(for:)` accepts only integers; `testEveryPushedSubtitleCarriesNoGalleryIdentity` passes |
| Must NOT reach for a concurrency or lint escape hatch | ✓ VERIFIED | Grep clean; suite ran with zero lint warnings |
| Must NOT weaken or delete an existing continued-session case to make the new suite pass | ✓ VERIFIED | 15-21's two commits are insertions into one test file only (`151+/8-`, `56+/0-`); the 8 deletions are the shared-constant refactor inside the new file |

## Independent Judgment on the Code Review's Findings

The review (`15-REVIEW.md`, 1 Critical / 10 Warning / 5 Info) was read only after the truths above
were decided from source. Each finding was re-derived and judged against the four success criteria
rather than inherited at its assigned severity.

### CR-01 (reviewer: Critical) — pull-to-refresh mobilizes the queue without ensuring a session

**Independently confirmed as a fact.** `refreshDownloads()` (`+PublicAPI.swift:27-29`) calls
`syncDownloadsState(scheduleNext: true)` → `scheduleNextIfNeeded()` and does not call
`ensureContinuedSession()`, while five sibling entry points do. It reaches the coordinator
synchronously from a foreground user gesture (`DownloadsView.swift:145` `.refreshable`), so it would
qualify for submission.

**Judged NOT a blocker for SC1.** Three independent reasons, checked in source:

1. **The state it fails to rescue is one the phase explicitly accepts.** D-07 (`15-CONTEXT.md:81-85`)
   decides that work becoming schedulable without a qualifying tap "runs foreground-only until the
   next qualifying tap; that is accepted", and enumerates the qualifying set as start / resume /
   retry / update. `DownloadClient.swift:85-86` already calls `reconcileDownloads()` then
   `resumeQueue()` at cold launch — the queue auto-resumes *uncovered by design*. Pull-to-refresh
   does not create that uncovered state; it merely does not lift it.
2. **The reviewer's concrete narrative does not hold as written.** In its crash-relaunch scenario
   both normalizations are no-ops in a fresh process (`normalizeInterruptedDownloads` only nulls a
   stale `activeGalleryID`, which is nil after relaunch; `normalizeNeedsAttentionDownloads` only
   clears in-memory `downloadErrors`, which is empty), and `resumeQueue()` has already scheduled.
   Refresh's real contribution on that path is a second `scheduleNextIfNeeded()`.
3. **Clearing a cancellation-like error does not by itself mobilize.** It moves `displayStatus` from
   `.error` to `.inactive` (`+Persistence.swift:110-113`), and `shouldSchedule` requires `.inactive`
   *plus* a non-empty `queuedPageSelections` entry (`+Scheduling.swift:130-134`). So refresh does not
   silently make error-state galleries schedulable.

SC1 as written covers "a download started in the foreground". Every path by which a user *starts*
work does ensure a session, and device UAT test 1 confirmed continuation. **Classified WARNING.**

That said, this is the phase's recurring failure mode showing again — five branches fixed, a sixth
sibling left — and the asymmetry is **undocumented at the refresh site**, so it reads as an omission
rather than a decision. The honest remedy is either the one-line ensure the reviewer proposes or a
comment at `refreshDownloads` stating why refresh is deliberately excluded while
`reconcileDownloads` is. Recommended before shipping; not a gate.

### WR-01 (reviewer: Warning) — `moveDownload` releases its scheduling block without converging

**Independently confirmed.** `+Folders.swift:163-206` inserts `gid` into
`schedulingBlockedGalleryIDs` with a function-scoped `defer`, suspends three times
(`fetchDownload`, `moveItem`, `reloadDownloadRecord`), and returns on six exits without ever calling
`scheduleNextIfNeeded()`. Its siblings `delete`, `deleteFolder` and `commitPause` all converge — the
first two fixed in this very phase.

**Judged NOT a blocker.** The stated ACTIVE-OWNERSHIP CONVERGENCE invariant
(`+Manager.swift:345-360`) binds paths that *clear* `activeGalleryID`/`activeTask`; `moveDownload`
clears neither (it fails with `.downloadStoreDownloadBusy` when the gallery is active). The real
hazard is narrower and phase-introduced: `isSchedulableDownload` excludes blocked gids, so if the
moved gallery is the only schedulable work and a concurrent `scheduleNextIfNeeded()` (for example the
`Task` spawned by `finishActiveTaskIfOwned`) lands inside the block window, `reconcileContinuedSession`
reads `hasPendingWork() == false` and *completes the live session* — the card goes down while the
gallery is milliseconds from being schedulable again, and no path restarts a session without a fresh
tap. It requires two concurrent coordinator operations and a single-item queue. **Classified WARNING**
— but it is the same branch-scoped-fix pattern as CR-01, on the invariant this phase spent three
rounds installing, so it deserves closing in the same pass.

### Remaining findings

| Finding | Confirmed? | Blocks an SC? |
|---|---|---|
| WR-02: expiration pause-all starts then immediately cancels the next gallery per iteration | Yes — `commitPause` reaches `scheduleNextIfNeeded()` (`:230`) while only the current gid is blocked | No. Spurious gallery-detail requests against a quota-limited backend on the card-cancel path. Real waste, no state corruption |
| WR-03: the single-session guard is not atomic across `await hasPendingWork()` | Yes — `:128` awaits before setting the flag; correctness rests on `queueStore.gids` being a synchronous `Shared` read | No. Correct on current code, and the code admits the dependency at `:152-154`. Latent: one `await` added downstream silently reopens the double-start window |
| WR-04: both `catch` arms in `commitPause` are unreachable | Yes — neither `writeInitialPauseRecord` nor `writeSettledPauseRecord` contains a throwing call | No. If nothing throws, `commitPause` always settles and always converges. Dead convergence, not missing convergence |
| WR-05: pause helpers take an unused `download` and a vestigial `throws` | Yes | No. Dead parameter, false contract |
| WR-06: `schedulingBlockedGalleryIDs` is an uncounted `Set`, so overlapping blocks release early | Yes — four `insert` + `defer remove` sites, all suspending, on a reentrant actor | No. Requires two concurrent operations on one gid. Predates the phase in shape; WR-02's proposed fix depends on this being addressed first |
| WR-07: session-lifecycle mutators are `public` only for a cross-module test target | Yes — nine symbols with no production caller outside `DownloadClient` | No. Real API-surface hazard (any linking module can call `markContinuedSessionEnded`), and the module already has the `#if DEBUG` pattern to fix it |
| WR-08: the client spy consumes `refuseNextStart` on refusals it did not cause | Yes | No. A test-double fidelity flaw. The Gap-A regression asserts `startCount == 1`, decided by the *coordinator's* guard, so it does not inherit the weakness |
| WR-09: the `.superseded` arm returns `.success(())` for work it abandoned | Yes | No. Its only caller discards the result today |
| WR-10: every session attempt permanently registers a launch handler, including failed ones | Yes — registration precedes submission and can never be undone | No. Identifiers are per-session UUIDs so the app-terminating hazard is unreachable; the cost is unbounded per-process growth, worst on the `.superseded` path that submits from a background context |
| IN-01..IN-05 | Yes, all five | No. IN-05's "N / N pages · 0 galleries" pair is now the *honest* drain value under the ledger and is pinned as such |

None of the sixteen falsifies a success criterion. CR-01, WR-01 and WR-07 are the three worth acting
on before this area is edited again: the first two are the same incomplete-sweep pattern this phase
has now hit four times, and the third publishes session-teardown mutators to seven modules.

## Human Verification Required

### 1. Multi-gallery card behavior on a physical iOS 26 device (re-run of UAT test 2)

**Test:** Queue at least three galleries of clearly different sizes, start in the foreground, and
background the app. Watch the system card across the **first gallery's completion**, then pause one
of the remaining galleries from the app and watch the card again. Finally cancel from the card,
foreground, and compare queue and manifest state against the state left by pausing each gallery by
hand.

**Expected:** The completed count keeps climbing past the first gallery's completion instead of
pinning at 100%; the total does not shrink; the subtitle keeps naming the *remaining* galleries; the
remaining galleries keep downloading in the background; after a pause the card can still reach
completion rather than being pinned below one; card-cancel leaves the same state as the in-app
per-gallery pause.

**Why human:** This is the exact behavior the device found broken (`15-UAT.md` test 2,
`result: issue`). The fix changes pushed arithmetic and is proven deterministically by
`DownloadContinuedSessionLedgerTests`, but the card is rendered by system UI outside the app and the
scheduler's stall-detection response exists only on hardware. `15-UAT.md` has not been re-run since
the fix landed, so its record still reports the defect.

## Summary

Gap G-15-2 is closed in the code, not merely in the summaries. The retirement ledger is a
membership-level sweep rather than a hook on the completion path the device report happened to name,
and I verified in source that no departure reason is classified anywhere in the production formula —
completion, pause, delete, cancel and a scheduling block all retire through the same line. The three
committed expectations that had encoded the defect were re-derived, not supplemented, and the suite
is non-vacuous by construction as well as by the executor's recorded break run.

SC1, SC3 and SC4 are verified outright, the first two with physical-device evidence from the UAT.
SC2 is the one remaining item and it is honestly unverified rather than failed: everything the
criterion needs is present, wired and deterministically tested, but the half of it the device
rejected has never been re-observed on the device. Shipping without that re-check would be trusting
a unit test to speak for a system-rendered card that has already surprised this phase once.

Two of the sixteen review findings — the missing `ensureContinuedSession()` on `refreshDownloads`
and the missing convergence in `moveDownload` — are the phase's recurring incomplete-sweep pattern
appearing for the fourth and fifth time. Neither falsifies a success criterion on my reading, and
both are recorded here as warnings rather than gaps, but they are the two most worth closing before
this area is touched again.

---

_Verified: 2026-08-04T17:10:00Z_
_Verifier: Claude (gsd-verifier)_
