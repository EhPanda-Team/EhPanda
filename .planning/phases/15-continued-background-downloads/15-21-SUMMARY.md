---
phase: 15-continued-background-downloads
plan: 21
subsystem: download-client
tags: [swift, continued-processing, progress-accounting, regression-testing, gap-closure]

requires:
  - phase: 15-continued-background-downloads
    provides: "The session-scoped retirement ledger, `schedulableSnapshot()` and `reconcileRetiredSessionPages(finishedPages:)` from plan 15-20"
provides:
  - "Departure-by-pause coverage driven through the coordinator's own `pause(gid:)`"
  - "Departure-by-delete coverage exercising the ledger's no-record fallback, pinned to the pause case by a shared expected pair"
  - "Rejoin coverage proving a gallery that leaves and returns is counted once, not twice"
  - "A recorded deliberate-break observation proving the continued-session suites are not passing vacuously"
affects: [continued-background-downloads, download-client, system-progress-card, background-scheduling]

tech-stack:
  added: []
  patterns:
    - "One shared expected pair named on the suite, asserted from two departure paths, so the paths are pinned to each other rather than to two copies of a literal"
    - "A case that drives a real product primitive asserts its last update; a case that asserts a whole pushed series uses the deterministic queue-set seam"
    - "Non-vacuity proved by removing the mechanism under test and recording which cases failed with which reported pairs"

key-files:
  created: []
  modified:
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift

key-decisions:
  - "No production code changed. D-G2-01's single formula already covered pause, delete and rejoin correctly; every new case passed on its first run, which is the evidence the plan asked for rather than a further change to the rule."
  - "The two real-primitive cases assert the last recorded update rather than a list of a known length, because `pause` and `delete` both converge on `scheduleNextIfNeeded` and the surviving gallery's skipped scheduling converges again behind it. Every push after the departure owes the same pair, so the value is deterministic even though the count is not."
  - "The rejoin case uses the queue-set test seam rather than a real resume, because it asserts the whole pushed series and must not also depend on convergence timing. The product's own departure primitives are covered by the pause and delete cases."

patterns-established:
  - "A departure expectation named once on the suite and asserted from every path that must reach it, so two accounting routes to the same value cannot silently diverge."

requirements-completed: [SC1, SC2]

coverage:
  - id: D6
    description: "A gallery leaving the schedulable set by pause retires exactly the pages it had finished: the numerator holds and the denominator drops by its unfinished pages and by nothing else."
    requirement: SC2
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testPausedGalleryRetiresOnlyItsFinishedPages"
        status: pass
    human_judgment: false
  - id: D7
    description: "A gallery leaving by deletion is accounted identically to one leaving by pause, through the ledger's last-observation fallback rather than by dropping the work or inventing a total."
    requirement: SC2
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testDeletedGalleryRetiresTheSamePagesAsAPause"
        status: pass
    human_judgment: false
  - id: D8
    description: "A gallery resumed back into the queue is counted once: the ledger releases it as the live sum picks it up, so no push reports more finished pages than the queue holds."
    requirement: SC2
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testResumedGalleryIsCountedOnce"
        status: pass
    human_judgment: false
  - id: D9
    description: "Work that will never be done never inflates the denominator, so the card can still reach completion after a pause or a delete instead of being pinned below one forever."
    requirement: SC1
    verification:
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testPausedGalleryRetiresOnlyItsFinishedPages"
        status: pass
      - kind: integration
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testDeletedGalleryRetiresTheSamePagesAsAPause"
        status: pass
    human_judgment: false
  - id: D10
    description: "The continued-session suites cannot pass vacuously: with the ledger's contribution removed from the push, eight named cases fail."
    requirement: SC2
    verification:
      - kind: other
        ref: "deliberate-break run, 33 tests in 2 suites, 8 cases failed, tree restored before commit"
        status: pass
    human_judgment: false
  - id: D5
    description: "On a physical iOS 26 device, pausing one gallery of a backgrounded multi-gallery queue leaves the card advancing over the remaining galleries and still able to reach completion."
    verification: []
    human_judgment: true
    rationale: "The system card and its cancel do not render in the simulator, so only the physical-device procedure in 15-UAT.md test 2 can observe a real pause against a real submission."

duration: 35min
completed: 2026-08-04
status: complete
---

# Phase 15 Plan 21: Departure-Path Coverage for the Retirement Ledger Summary

**Pause, delete and rejoin are now proved to obey rule D-G2-01, and the suite that proves it is proved not to pass vacuously**

## Performance

- **Duration:** 35 min
- **Completed:** 2026-08-04
- **Tasks:** 2
- **Files modified:** 1 modified (tests only)

## Accomplishments

- Added `testPausedGalleryRetiresOnlyItsFinishedPages` and `testDeletedGalleryRetiresTheSamePagesAsAPause`, both driven through the coordinator's own `pause(gid:)` and `delete(gid:)` with an inert task runner, and both pinned to one shared expected pair.
- Added `testResumedGalleryIsCountedOnce`, which asserts the whole pushed series across leave-and-return and fails loudly on the double count a scalar ledger would produce.
- Ran the deliberate-break check: with the ledger's contribution removed from `pushContinuedSessionProgress`, **eight** cases failed, including the rewritten `testEmptySchedulableSetStillPushesAPositiveTotal`. The tree was restored before either commit.
- Confirmed `COVERAGE.md` intact and unchanged, and recorded the device re-run inputs for `15-UAT.md` test 2.

## Task Commits

Each task was committed atomically:

1. **Task 1: Departure by pause and by delete retires only finished pages** - `b76c310c` (test)
2. **Task 2: A resumed gallery is counted once, and the suite is proved non-vacuous** - `00bfd9ad` (test)

## Files Created/Modified

- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift` - Three new cases, one new suite-level expected pair (`departedPair`), and three helpers (`expectTheCompletedSeriesNeverRewinds`, `firstPushedPair`, and `pushedPair`, which `lastPushedPair` now delegates to). The file header was updated to describe the two families the suite now holds. 418 lines, inside the 1000-line error limit.

## No Production Code Changed

The plan's standing instruction was that a case which cannot pass without changing the coordinator is a finding about 15-20's implementation, to be reported rather than fitted. None arose: every new case passed on its first run. `git status` shows only the test file modified at each commit, and `DownloadClient+ContinuedSession.swift` is byte-identical to its committed state (the temporary break was reverted with `git checkout --` on that single file, and `retiredPageCount` was confirmed back in the push arithmetic afterwards).

## What The New Cases Assert

The fixture is the same shape in all three: a 10-page gallery with 6 finished, plus an untouched 4-page gallery, both queued — 6 of 14 pages across 2 galleries at the opening push.

| Case | Departure | Last / final pushed pair |
|---|---|---|
| `testPausedGalleryRetiresOnlyItsFinishedPages` | real `pause(gid:)` | `6 / 10 pages · 1 gallery` |
| `testDeletedGalleryRetiresTheSamePagesAsAPause` | real `delete(gid:)`, no record survives | `6 / 10 pages · 1 gallery`, asserted equal to the pause case's constant |
| `testResumedGalleryIsCountedOnce` | queue-set seam, out and back | completed `[6, 6, 6]`, total `[14, 10, 14]`, third push equal to the first |

The pause and delete cases additionally assert the completed series never rewinds and that the final pair is strictly below one — a departure must never be able to report the session finished.

**Why the two real-primitive cases assert the last update rather than a list.** `pause` and `delete` both converge on `scheduleNextIfNeeded`, whose tail reconciles the session; the surviving gallery is then scheduled, the inert runner returns `.skippedOperation`, and `finishActiveTaskIfOwned` reconciles the session again from a detached task. How many pushes land is therefore a property of the convergence path. The *value* is not: every push after the departure sums the same live 0-of-4 with the same retired 6, so `6 / 10 pages · 1 gallery` is deterministic while the count of pushes is not. A length assertion there would fail for reasons unrelated to the ledger.

## Deliberate-Break Check (run once, not committed)

`pushContinuedSessionProgress` was temporarily reduced to the live sums alone — the arithmetic as it stood before plan 15-20 — and the ledger suite plus the continued-session suite were run together: **33 tests in 2 suites, 8 cases failed with 27 non-known issues.** Every failure and the pair it reported:

| Case | Suite | Reported with the ledger removed | Expected |
|---|---|---|---|
| `testEmptySchedulableSetStillPushesAPositiveTotal` | `DownloadContinuedSessionTests` | completed `[2, 2]`, final total `2`, subtitles `["2 / 6 pages · 1 gallery", "2 / 2 pages · 0 galleries"]` | completed `[2, 6]`, total `6`, final `6 / 6 pages · 0 galleries` |
| `testACompletedGalleryHoldsTheTotalAndAdvancesTheCount` | `DownloadContinuedSessionTests` | completed `[6, 6]`, totals `[14, 6]`, final `6 / 6 pages · 1 gallery` | completed `[6, 10]`, totals `[14, 14]` |
| `testEveryPushedSubtitleCarriesNoGalleryIdentity` | `DownloadContinuedSessionTests` | subtitles `["4 / 8 pages · 2 galleries", "4 / 5 pages · 1 gallery"]` | second push describing the whole queue |
| `testSequentialCompletionsHoldTheDenominatorAndAdvanceTheCount` | ledger | completed `[0, 0, 0, 0]`, totals `[20, 10, 4, 1]`, drain `0 / 1 page · 0 galleries` | completed `[0, 10, 16, 20]`, totals `[20, 20, 20, 20]`, drain `20 / 20 pages · 0 galleries` |
| `testReportedTotalsDoNotDependOnCompletionOrder` | ledger | completed `[0, 0, 0, 0]`, totals `[20, 16, 10, 1]`, final pair `0 / 1` | completed `[0, 4, 10, 20]`, totals `[20, 20, 20, 20]` |
| `testPausedGalleryRetiresOnlyItsFinishedPages` | ledger | `6 / 6 pages · 1 gallery`, and the fraction reaching exactly one | `6 / 10 pages · 1 gallery`, strictly below one |
| `testDeletedGalleryRetiresTheSamePagesAsAPause` | ledger | `6 / 6 pages · 1 gallery`, and the fraction reaching exactly one | `6 / 10 pages · 1 gallery`, strictly below one |
| `testResumedGalleryIsCountedOnce` | ledger | totals `[14, 6, 14]`, middle subtitle `6 / 6 pages · 1 gallery` | totals `[14, 10, 14]`, middle `6 / 10 pages · 1 gallery` |

The plan required at least four named failures including the rewritten `testEmptySchedulableSetStillPushesAPositiveTotal`; eight were observed, and that case was among them.

**`missing[]` item 5 of gap G-15-2 is closed.** That item required the two committed expectations encoding the defect to be rewritten rather than supplemented. `testEmptySchedulableSetStillPushesAPositiveTotal` fails with the ledger removed, reporting `2 / 2 pages · 0 galleries` — which is precisely the defective output it used to assert. It could only fail this way if plan 15-20 re-staged its departure as a real completion; a bare dequeue would still reach a genuinely empty sum and pass. The check therefore confirms the rewrite rather than accepting it on the summary's word.

Only `testASessionOutlivingWorkNobodyFinishedStillPushesAPositiveTotal` in the ledger suite passed unchanged during the break, which is correct: nothing is retired there, so removing the retired total changes nothing.

`AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` was restored with `git checkout --` on that file alone before either commit, and both commits show a clean tree apart from the test file.

## No Pre-existing Assertion Was Weakened

No assertion outside this plan's three new cases was edited. Two non-assertion edits inside the same file are worth naming so the diff is not mistaken for one:

- The file's header doc comment was extended to describe the pause/delete/rejoin family alongside the completion family it already described. It had claimed *every* case stages a completion, which stopped being true.
- `lastPushedPair` was factored over a new `pushedPair(_:)`, and `firstPushedPair` added beside it. `lastPushedPair` keeps its signature, its behavior and its call sites in the three pre-existing cases.

## COVERAGE.md Validated, Not Regenerated

Confirmed unchanged and intact: all 21 rows carry a decision, and each of the 7 `OPT-OUT` rows carries a reason. This gap round introduced no new capability from the continued-processing surface — it changed no coordinator arithmetic at all and touched no `BGTaskScheduler` or `BGContinuedProcessingTask` member, adding only test cases — so no row was needed and none was added.

## Closure Inputs for the UAT Test 2 Re-run

For the verifier:

- **Gap closed by this pair of plans:** `G-15-2` in `15-UAT.md` — plan 15-20 changed the accounting basis, plan 15-21 proves every departure path obeys it.
- **The device re-run is still required.** The system card and its cancel do not render in the simulator, so nothing in either plan can close the gap by itself. Both plans' truths about the pushed arithmetic are simulator-proved; what the card *shows* is not.
- **The observable difference on device:** a multi-gallery backgrounded queue shows one card whose counts keep advancing past the first gallery's completion, while the subtitle keeps naming the remaining galleries rather than collapsing to "1 gallery" at a frozen 100%. Pausing one gallery mid-queue is the same check from the other side: the card must keep advancing over the survivors and must still be able to reach completion, rather than sticking below full for the rest of the session.

## Deviations from Plan

None. The plan executed exactly as written; no auto-fix was needed, no authentication gate was hit, and no architectural question arose.

## Known Stubs

None. Every symbol this plan introduced is exercised by the suite it lives in.

## Verification

- `xcodebuild test ... -only-testing:DownloadsFeatureTests/DownloadContinuedSessionLedgerTests` - 5 tests, 1 suite, exit 0 (after Task 1).
- `xcodebuild test ... -only-testing:DownloadsFeatureTests` - 311 tests after Task 1, then **312 tests in 62 suites, exit 0** after Task 2 (309 before this plan's 3 new cases). `DownloadSchedulingTests` green in every run. Run one invocation at a time, never concurrently.
- Deliberate-break run: 33 tests in 2 suites, 8 failures as tabulated; tree restored; full plan re-run to green afterwards.
- SwiftLint `--strict` over the touched file with the project config: **0 violations, 0 serious**, at 418 lines against the 1000-line error limit. The app-scheme build that fronts every test run above completed with the SwiftLint build plugin active.
- Acceptance greps, final counts: `testPausedGalleryRetiresOnlyItsFinishedPages` 1, `testDeletedGalleryRetiresTheSamePagesAsAPause` 1, `testResumedGalleryIsCountedOnce` 1, `6 / 10 pages · 1 gallery` 4, `6 / 14 pages · 2 galleries` 4, `testingSetQueuedGalleryIDs` 3, `skippedOperation` 2, `pause(gid:` 3, `delete(gid:` 2. Every criterion met or exceeded.

## One Flake Observed, Logged Not Fixed

The full plan was run four times across this plan. Three passed. One failed on a single pre-existing case, `DownloadDeleteConvergenceTests.testDeletingAVanishedRecordKeepsTheRestOfTheQueueMoving`, which timed out on its one-second observer deadline — on the run that immediately followed a full `DownloadClient` recompile, with that case reporting 13.2 seconds of wall time under contention. The immediately following run was green with no change to the tree. The helpers file already records that one second "did not survive CI", which is why the shared `waitUntil` uses ten. The case is outside this plan's scope and the plan forbids editing anything in the suite but its own new cases, so it is recorded in `deferred-items.md` rather than adjusted here.

## Self-Check: PASSED

`AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift` exists on disk carrying all three new case names; both task commits (`b76c310c`, `00bfd9ad`) are present in git history.

## Next Steps

Phase 15's plan pipeline is complete. `/gsd-verify-work 15` next: walk the four physical iOS 26 device checks in `15-UAT.md`, of which test 2 is the re-run this plan supplies the closure inputs for.
