---
phase: 15-continued-background-downloads
plan: 20
subsystem: download-client
tags: [swift, tca-free-actor, continued-processing, progress-accounting, regression-testing]

requires:
  - phase: 15-continued-background-downloads
    provides: "The one queue-wide continued-processing session, its subtitle builder, and the schedulable-work predicate from plans 15-01 through 15-19"
provides:
  - "A session-scoped, per-gallery retirement ledger that keeps a completed gallery's pages on both sides of the pushed fraction"
  - "One schedulable read yielding both the summed progress and the per-gallery finished counts the ledger is derived from"
  - "A push-time membership sweep covering every departure path by construction rather than one instrumented call site"
  - "A multi-gallery regression suite pinning the drain fraction and the clamp ordering"
affects: [continued-background-downloads, download-client, system-progress-card, background-scheduling]

tech-stack:
  added: []
  patterns:
    - "A session ledger keyed by gallery, so a rejoining gallery can be un-retired instead of double-counted"
    - "Membership observed where the sums are already read, so every departure path is covered without instrumenting any of them"
    - "Raw sums enter the arithmetic and exactly one display clamp applies at the end, over the summed pair"

key-files:
  created:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift

key-decisions:
  - "D-G2-01: a gallery leaving the schedulable set retires exactly the pages it had already finished, added to both the numerator and the denominator, and nothing more. One formula covers completion, pause, delete, cancel and expiration, so no call site classifies why a gallery left."
  - "The ledger is maintained by a push-time membership sweep rather than a hook in settleCompletedDownload, because galleries depart through at least six paths and instrumenting the reported one would leave the other five."
  - "The ledger is keyed by gallery rather than accumulated into a scalar, so a paused gallery resumed back into the queue can be dropped from the ledger instead of counted twice."
  - "The monotonic max() floor is kept but demoted to residual defence against a genuine regression in a gallery's own finished count; monotonicity is now a property of the accounting basis."
  - "The retired total is added to the raw sums, before the single display clamp, because displayPageCount floors at one page and a clamped operand would put a phantom page into every drained queue."
  - "The three committed expectations that encoded the shrinking basis were rewritten, not supplemented, so no committed test still asserts the defect."

patterns-established:
  - "A departure ledger reconciled against the very read whose sums it corrects, so retirement and the live sum can never disagree."
  - "A drain assertion expressed over the whole recorded update list, so a later extra push cannot slip past it."

requirements-completed: [SC1, SC2]

coverage:
  - id: D1
    description: "A gallery finishing mid-session advances the pushed completed count and leaves the pushed total where it was."
    requirement: SC2
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift#testACompletedGalleryHoldsTheTotalAndAdvancesTheCount"
        status: pass
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testSequentialCompletionsHoldTheDenominatorAndAdvanceTheCount"
        status: pass
    human_judgment: false
  - id: D2
    description: "The pushed fraction is strictly below one while any schedulable gallery still has unfinished pages, and exactly one when none does."
    requirement: SC2
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#expectTheFractionReachesOneOnlyAtTheDrain"
        status: pass
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift#testEmptySchedulableSetStillPushesAPositiveTotal"
        status: pass
    human_judgment: false
  - id: D3
    description: "Reported totals do not depend on the order galleries complete in, and an emptied queue with nothing retired still pushes a positive total."
    requirement: SC2
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testReportedTotalsDoNotDependOnCompletionOrder"
        status: pass
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testASessionOutlivingWorkNobodyFinishedStillPushesAPositiveTotal"
        status: pass
    human_judgment: false
  - id: D4
    description: "The liveness signal is restored: every later flush pushes a completed count that has actually moved, so a long multi-gallery queue no longer looks stalled to the scheduler."
    requirement: SC1
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testSequentialCompletionsHoldTheDenominatorAndAdvanceTheCount"
        status: pass
      - kind: other
        ref: "full DownloadsFeatureTests plan, 309 tests in 62 suites, exit 0"
        status: pass
    human_judgment: false
  - id: D5
    description: "On a physical iOS 26 device, a multi-gallery backgrounded queue shows one card whose counts keep advancing past the first gallery's completion and whose subtitle keeps naming the remaining galleries."
    requirement: SC2
    verification: []
    human_judgment: true
    rationale: "Simulator tests prove the arithmetic across every departure path, but only the physical-device procedure in 15-UAT.md test 2 can observe the real system card under a real background submission."

duration: 25min
completed: 2026-08-04
status: complete
---

# Phase 15 Plan 20: Continued-Session Retirement Ledger Summary

**A completed gallery's pages now stay on both sides of the session's page fraction, so the system card advances across gallery boundaries instead of freezing at a literal 100%**

## Performance

- **Duration:** 25 min
- **Completed:** 2026-08-04
- **Tasks:** 2
- **Files modified:** 3 modified, 1 created

## Accomplishments

- Replaced the shrinking accounting basis with a session-scoped, per-gallery retirement ledger: a gallery leaving the schedulable set folds the pages it finished into both the numerator and the denominator of every later push.
- Replaced `schedulableProgress()` with `schedulableSnapshot()`, one index read yielding the summed progress and the per-gallery finished counts together, so the ledger is reconciled against the very read whose sums it corrects.
- Added `reconcileRetiredSessionPages(finishedPages:)`, a push-time membership sweep that covers all six departure paths by construction and un-retires a gallery that rejoins.
- Rewrote the three committed expectations that asserted the shrinking basis, and added a multi-gallery suite that proves the denominator survives every completion in either order and that the fraction reaches one only at the drain.

## Task Commits

Each task was committed atomically:

1. **Task 1: Replace the shrinking basis with a session-scoped retirement ledger, and re-derive the expectations that encoded it** - `425b5a8b` (fix)
2. **Task 2: Regression suite for multi-gallery completion ordering and the queue-drain fraction** - `925669bf` (test)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` - Declares `retiredSessionPages` (the ledger) and `observedSchedulablePages` (the membership map it is derived from), both session-scoped, both documented with why the ledger is keyed by gallery rather than summed into a scalar.
- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` - Adds `SchedulableSnapshot` and `schedulableSnapshot()`, adds the retirement reconcile carrying rule D-G2-01, rewrites the push arithmetic over the summed pair, clears and seeds both maps in `ensureContinuedSession()` and `markContinuedSessionEnded(sessionID:)`, and corrects the doc comments that called the queue shrink rare.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` - Re-derives the three cases that encoded the old basis; two of them now stage their departure as a real completion through `updateDownloadIndex` plus `settleCompletedDownload`.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift` - New suite: two three-gallery drains in opposite completion orders, the drain-fraction assertion over the recorded list, and the inherited zero-denominator guard.

## The Arithmetic That Changed

The push now sums live schedulable work plus the ledger, and clamps once at the end:

- raw session completed = live raw completed + retired total
- raw session total = live raw total + retired total
- one `DownloadProgress` is built from that raw pair
- pushed completed = `max(lastPushedCompletedPageCount, displayCompletedPageCount)`
- pushed total = `max(displayPageCount, pushed completed)`
- gallery count = the snapshot's count, unchanged

A three-gallery queue of 10, 6 and 4 pages therefore pushes `0 / 20`, `10 / 20`, `16 / 20`, `20 / 20` as its galleries finish. Under the old basis the second push already read `10 / 10` with the queue two thirds full.

**The clamp-ordering canary held.** Both drain literals came out exactly `20 / 20` and `6 / 6` on the first run, not one page high, confirming the retired total is added to raw sums rather than to a denominator `displayPageCount` had already floored at one.

## Suite Sweep

Every remaining continued-session expectation was re-derived against the new basis and confirmed unaffected, by name:

| Case / suite | Why unaffected |
|---|---|
| `testPushedCountsSumEverySchedulableGallery` | No departure occurs; the ledger is empty at the single push. |
| `testTotalGrowsWhenAGalleryJoinsTheQueueMidSession` | A gallery joins rather than leaves, so nothing is retired and the growth still shows in the total. |
| `testZeroPageGalleryStillPushesAPositiveTotal` | Single gallery, no departure; still exercises the zero-page denominator clamp. |
| `testProgressIsPushedOnTheThrottledPageFlushCadence` | Single gallery, no departure; the cadence is unchanged. |
| `DownloadContinuedSessionIdentityTests` | Asserts session identity and call counts, never arithmetic. |
| `DownloadContinuedSessionInterleaveTests` | Asserts ordering and ownership across suspensions, never arithmetic. |
| `ContinuedProcessingSessionTests` | Client-module suite; its subtitles are literals the test itself supplies and never cross the coordinator's arithmetic. |

`DownloadSchedulingTests` is green as part of the full plan run. The subtitle builder was not touched: `continuedSessionSubtitle(for:)` keeps its signature and body, and still receives the snapshot's remaining-gallery count.

## Decisions Made

- **D-G2-01** is recorded on the retirement reconcile, where it is implemented, with its three-part rationale: keeping a paused gallery's unfinished pages would pin the card permanently below 1.0; dropping its finished pages would rewind the stall signal; symmetric retirement is the only rule under which the numerator never rewinds *and* the fraction reaches 1.0 exactly at drain. A completed gallery is that same rule with nothing left over.
- **D-10 is extended, not reopened.** D-10 reads "completed pages / total pages across all schedulable galleries" and anticipated totals recomputing when galleries *join*. The pushed pair now also carries pages retired from galleries that have left that set, because summing the live set alone is precisely what produced this gap. What a reader sees is unchanged: one summed page fraction over the work the session covers, totals still growing when galleries join, and a subtitle still naming the remaining schedulable galleries. D-06 (one queue-wide session, queue-wide completion predicate) is untouched.
- The sweep observes membership instead of hooking a departure, because three earlier gap rounds in this phase refilled from branch-scoped fixes; this one covers completion settle, the incomplete-error dequeue, pause, delete, the queued-work-item cancel and the expiration pause-all with a single mechanism.

## Known Limitation (documented, out of scope)

One pre-existing window is unchanged and is not a failure of the truth above: a gallery whose manifest has just been completed stays schedulable until `settleCompletedDownload` removes it from the queue store, so a throttled flush landing inside that window pushes an honest N-of-N for work that is genuinely finished. It is transient, it predates this gap, the ledger neither causes nor cures it, and closing it would require a per-gallery completion predicate, which D-06 forbids.

## Deviations from Plan

None - the plan executed exactly as written. No auto-fixes were needed, no authentication gates were hit, and no architectural question arose.

## Known Stubs

None. Every symbol this plan introduced is wired into the push path and exercised by the suite.

## Verification

- `xcodebuild test ... -only-testing:DownloadsFeatureTests/DownloadContinuedSessionLedgerTests` - 3 tests, 1 suite, exit 0.
- `xcodebuild test ... -only-testing:DownloadsFeatureTests` - 309 tests in 62 suites, exit 0 (306 before this plan's 3 new cases). Run after the targeted invocation, never concurrently.
- SwiftLint over all four touched files with `--strict`: 0 violations, 0 serious. Line length within 120 on every rewritten line; `DownloadContinuedSessionTests.swift` at 968 lines and the new suite at 219, both inside the 1000-line error limit.
- Acceptance greps: every literal and symbol count in both tasks' acceptance criteria met or exceeded.

## Self-Check: PASSED

All four source files and the new suite exist on disk; both task commits (`425b5a8b`, `925669bf`) are present in git history.

## Next Steps

`15-UAT.md` test 2 is re-run on a physical iOS 26 device after plan 15-21 lands: a multi-gallery backgrounded queue must show one card whose counts keep advancing past the first gallery's completion and whose subtitle keeps naming the remaining galleries.
