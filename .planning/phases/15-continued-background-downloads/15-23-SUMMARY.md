---
phase: 15-continued-background-downloads
plan: 23
subsystem: download-client
tags: [swift, continued-processing, gap-closure, reentrancy, test-doubles, regression-testing]

requires:
  - phase: 15-continued-background-downloads
    provides: "The terminal progress push plan 15-22 added to the drain branch of `reconcileContinuedSession`, whose main-actor hop is the suspension this plan re-validates behind"
  - phase: 15-continued-background-downloads
    provides: "`hasPendingWork()` and `schedulableDownloads()` from the pending-work seam, the drain predicate the re-check re-asks"
provides:
  - "D-G3-01: a drain-ness re-check (`guard await hasPendingWork() == false`) between the terminal push's ownership re-check and the teardown, so a session is never completed over work mobilized inside the push"
  - "A truthful suspension account in the D-G2B-01 doc block: the `updateProgress` main-actor hop, not the same-actor index and ledger reads"
  - "A contract-faithful `BackgroundProcessingClientSpy`: every seam endpoint yields at least once, as the main-actor-confined live value does"
  - "`testWorkMobilizedInsideTheTerminalPushSurvivesTheDrain` — a gated, production-path regression that fails on the pre-fix drain branch"
  - "A recorded disposition for every teardown site in the module, not just the branch the review named"
affects: [continued-background-downloads, download-client, system-progress-card, background-scheduling]

tech-stack:
  added: []
  patterns:
    - "Teardown runs only over a still-true justifying observation: every suspension between the observation and the teardown invalidates it, and the observation itself — not merely session identity — is re-validated behind each one"
    - "A test double must suspend wherever the live value suspends; an atomic double where the seam hops actors certifies reentrancy races as impossible and makes a whole suite green against a defect"
    - "A guard's non-suspension dependency is stated at the call site, so a later `await` added inside its callees is recognisable as reopening the window rather than as a refactor"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift

key-decisions:
  - "The re-check guards drain-ness, not identity. Identity provably cannot change in that window — minting a successor requires `ensureContinuedSession` to pass `!hasLiveContinuedSession`, and that flag stays true until teardown — so 15-22's identity re-check guarded the invariant that cannot fail. Drain-ness is the one that goes stale."
  - "The terminal push was not moved. D-G2B-01's order (deferral, push, teardown, completion) is preserved exactly; the new guard is inserted between the push and the teardown."
  - "One stale-shaped push is accepted, not removed. The push's arguments are computed before the hop, so a mid-hop mobilization can put a terminal-shaped pair on the card for one repaint. Re-checking ahead of the push cannot exist — the push *is* the suspension."
  - "The spy was made always-suspending rather than case-by-case gated. 15-22's drain suite was green precisely because `updateProgress` never suspended unless a case armed a gate, and no drain case armed one."
  - "The pinned push sequence in the new case is four entries, not the plan's three. The plan's expected sequence omitted the inert runner's own completion-tail convergence push (`finishActiveTaskIfOwned(schedulesNext: false)` reconciles the session); the case waits for that convergence before releasing the gate so the order is settled rather than raced."
  - "`testEmptySchedulableSetStillPushesAPositiveTotal` was NOT relocated. The relocation was gated on an absorbed expectation needing room in the 999-line file; the always-suspending spy forced no expectation to change, so the structural move was not taken."

patterns-established:
  - "Invariant-level sweep over branch-level fix: the review named one branch, so every teardown site in the module was re-verified against the invariant and dispositioned in writing, closing the recorded gap-round refill pattern."
  - "Falsifiability is taken with the fix withheld and the observed failure quoted verbatim — assertion, observed value, expected value — before the guard lands."

requirements-completed: [SC1]

coverage:
  - id: D1
    description: "A queue-mobilizing action landing inside the drain's terminal push leaves the session alive with the new work folded in"
    requirement: SC1
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift#testWorkMobilizedInsideTheTerminalPushSurvivesTheDrain"
        status: pass
    human_judgment: false
  - id: D2
    description: "The surviving session is not a zombie: a genuine later drain still completes it exactly once with success"
    requirement: SC1
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift#testWorkMobilizedInsideTheTerminalPushSurvivesTheDrain"
        status: pass
    human_judgment: false
  - id: D3
    description: "D-G2B-01's ordering survives: deferral, push, ownership re-check, drain-ness re-check, teardown, completion"
    requirement: SC1
    verification:
      - kind: static
        ref: "awk over reconcileContinuedSession + grep of the six ordered tokens"
        status: pass
    human_judgment: false
  - id: D4
    description: "Every existing drain and identity case still holds against a seam that suspends on every call"
    requirement: SC1
    verification:
      - kind: unit
        ref: "DownloadsFeatureTests (314 tests, 62 suites)"
        status: pass
    human_judgment: false
  - id: D5
    description: "On a physical iOS 26 device, the system progress card renders real progress and its cancel matches the in-app pause baseline"
    requirement: SC2
    verification: []
    human_judgment: true
    rationale: "15-UAT.md test 2 is a standing physical-device item; the card is system-rendered and the simulator neither renders it nor fires its cancel. Nothing in this plan closes it."

duration: 22min
completed: 2026-08-04
status: complete
---

# Phase 15 Plan 23: Drain-Ness Re-Check Behind the Terminal Push Summary

**G-15-3 closed: the drain branch now re-asks its own question — is the queue still drained? — behind the terminal push's main-actor hop, so a retry, resume, enqueue or page-retry landing inside that hop keeps the session alive instead of having its work torn down by a decision taken before it existed.**

## What Was Built

### The defect, stated precisely

Plan 15-22 turned the drain branch's tail from suspension-free into reentrant. `pushContinuedSessionProgress` ends at `backgroundProcessingClient.updateProgress`, whose live value hops to the `@MainActor` `ContinuedProcessingSession`. Inside that hop the coordinator actor is free, and a queue-mobilizing action can run to completion there: `retry` enqueues, schedules, pushes its own live progress, and then calls `ensureContinuedSession()`, which returns inert because `hasLiveContinuedSession` is still true. The drain then resumed into `markContinuedSessionEnded` and `finish`, completing the task over live work. With no fallback tier (D-03), that work runs uncovered until the next qualifying tap (D-07).

15-22 did add a re-check there — `guard continuedSessionID == sessionID` — but it guards the property that provably cannot change in that window: minting a successor requires `ensureContinuedSession` to pass `!hasLiveContinuedSession`, and that flag stays true until teardown. The doc comment is why the wrong guard was chosen; it named "an index read plus the ledger's record read" as the suspension, and both are same-actor calls that never suspend.

### The fix

```swift
// D-G2B-01: the card's last word, taken while this session still owns it.
await pushContinuedSessionProgress(sessionID: sessionID)
guard continuedSessionID == sessionID else { return }
// D-G3-01: the push crossed the client seam's main-actor hop, so the drain decision
// taken before it is no longer authoritative. Work mobilized inside that window folded
// into this session — its own `ensureContinuedSession` is inert while
// `hasLiveContinuedSession` is true — so completing here would surrender coverage
// nothing can restore until the next qualifying tap (D-03/SC3: no fallback tier).
// Leave the session live; the next convergence reconciles it.
guard await hasPendingWork() == false else { return }
logger.notice("Continued-processing session drained, terminal progress pushed.")
```

Nothing moved. The push sits where 15-22 put it, the teardown and completion follow in the same order, and the new guard occupies the one position that can exist: between the push and the teardown.

### The paragraph that was replaced

Removed verbatim:

> The push suspends — an index read plus the ledger's record read — where this branch's tail was previously suspension-free, so ownership is re-checked behind it exactly as it is after every other suspension in this file.

Replaced by three paragraphs that (1) name `updateProgress`'s hop to the `@MainActor` `ContinuedProcessingSession` as the whole of the window and state that the index and ledger reads inside the push are same-actor calls that do not suspend; (2) state the re-check's own same-actor dependency in the phrasing `ensureContinuedSession` already uses for its guard — `hasPendingWork()` reads `activeTask` then the queue store through `schedulableDownloads()`, and an `await` introduced inside those callees later would reopen the window behind this guard; and (3) record D-G3-01's accepted transient, the one terminal-shaped pair that can reach the card before the next live push corrects it.

`grep -c 'main-actor'` on the file rose from 1 to 3.

### The seam was made honest

`BackgroundProcessingClientSpy.client` now opens each of `start`, `updateProgress` and `finish` with `await Task.yield()`, before any recording, and the type doc comment states the contract. This is the reason 15-22's entire drain suite was green against a reentrant tail: the spy suspended only when a case armed a gate, and no drain case armed one. Thirty-odd continued-session cases now run against a seam that can interleave everywhere the live one does.

## Structural verification of the ordering

```
$ awk '/public func reconcileContinuedSession/,/^    \}$/' …/DownloadClient+ContinuedSession.swift \
    | grep -n 'continuedClientSessionID\|pushContinuedSessionProgress(sessionID\|continuedSessionID == sessionID\|hasPendingWork() == false\|markContinuedSessionEnded\|backgroundProcessingClient.finish'
4:            guard continuedSessionID == sessionID else { return }
7:            guard let clientSessionID = continuedClientSessionID else {
12:            await pushContinuedSessionProgress(sessionID: sessionID)
13:            guard continuedSessionID == sessionID else { return }
20:            guard await hasPendingWork() == false else { return }
24:            markContinuedSessionEnded(sessionID: sessionID)
25:            await backgroundProcessingClient.finish(clientSessionID, true)
```

Deferral, push, ownership re-check, drain-ness re-check, teardown, completion — in exactly that relative order.

Other acceptance greps, all satisfied: `hasPendingWork() == false` = 1; `Task.yield()` in the support types = 3; `testWorkMobilizedInsideTheTerminalPushSurvivesTheDrain` = 1; `armProgressGate` in the interleave suite = 1; `finishRecords.isEmpty` = 1; `testingHasContinuedSession` = 3.

## Falsifiability: the pre-fix reading

The spy change and the new case were written first and the interleave suite run against the unmodified drain branch. The case failed on three assertions, quoted verbatim from that run:

```
✘ DownloadContinuedSessionInterleaveTests.swift:155:9: Expectation failed:
  (spy.finishRecords → [FinishRecord(sessionID: 40313987-47CB-40E9-B92D-591AB5991FCD,
   success: true)]).isEmpty → false

✘ DownloadContinuedSessionInterleaveTests.swift:156:9: Expectation failed:
  await fixture.manager.testingHasContinuedSession()

✘ DownloadContinuedSessionInterleaveTests.swift:164:27: Issue recorded
  ↳ Difference: …
        [
          … (3 unchanged),
      +   [3]: "1 / 1 page · 0 galleries"
        ]
```

Read together: the parked drain resumed into teardown and completed the task with `success: true` while the mobilized gallery was still queued; `testingHasContinuedSession()` was false; and the fourth pushed subtitle — the genuine drain's terminal push — never happened, because there was no session left to push it. The coordinator's own log for that run shows the same thing, one drain notice where the fixed run shows the drain deferred and the notice emitted only at the real drain:

```
pre-fix:  Continued-processing session drained, terminal progress pushed.
          Download paused, gid: 210192.
          (no second drain — the session was already gone)

post-fix: Download paused, gid: 210192.
          Continued-processing session drained, terminal progress pushed.
          Download paused, gid: 210193.
```

The two other cases in the suite passed in that same pre-fix run, so the failure is the new case's own, not a suite-wide break.

The fix was then installed and the suite re-run green (3 tests, 0 issues). The tree at commit `60b660fb` carries the fix; no reverted state was committed.

## Teardown-site sweep — every place the module ends a session

Re-verified against source at HEAD. `markContinuedSessionEnded` has five call sites in the module and `backgroundProcessingClient.finish` has two; every one is accounted for below.

| # | Site (line) | Justifying observation | Suspensions between observation and teardown | Disposition |
|---|---|---|---|---|
| 1 | `reconcileContinuedSession` drain branch (`:337`) | `hasPendingWork() == false` | the terminal push's `updateProgress` main-actor hop | **FIXED HERE** — drain-ness re-checked behind the push (D-G3-01) |
| 2 | `handleContinuedSessionEvent` `.expired` (`:206`) | identity guard at function entry (`:199`) | none — the guard, the `logger.notice` and `markContinuedSessionEnded` are all synchronous; `pauseAllSchedulable` is awaited *after* the teardown by design | Sound as written |
| 3 | `handleContinuedSessionEvent` `.unavailable` (`:212`) | identity guard at function entry (`:199`) | none — notice plus teardown, both synchronous | Sound as written |
| 4 | `ensureContinuedSession` refusal rollback (`:149`) | `clientSession == nil` returned by the awaited start | none after the observation; the ownership guard immediately preceding the rollback already defends the start hop, and a refusal is terminal for this session so it cannot go stale | Sound as written |
| 5 | Consuming task's stream-finish tail (`:170`) | the stream ended | arbitrary — the stream's lifetime is unbounded | Sound — `markContinuedSessionEnded`'s own identity guard makes a stale call a no-op |
| 6 | `pauseAllSchedulable` loop (`:254`) | not a teardown site; the session is already ended before the loop runs, and each iteration re-checks ownership | n/a | Non-site, recorded |

One site outside the plan's six-row table, recorded rather than omitted:

| # | Site (line) | Justifying observation | Suspensions between observation and teardown | Disposition |
|---|---|---|---|---|
| 4b | `ensureContinuedSession` superseded-start completion (`:156`) | `continuedSessionID != sessionID`, read on the line immediately above | none — the guard and the `finish` call are adjacent, and the guard is re-taken after the start hop it defends | Sound as written. This completes the *client* session this call started; it clears no coordinator state, so it is a completion rather than a teardown, which is why the plan's table did not list it. |

Every row verified as written. No finding.

## Fallout from the honest seam

**None.** The full `DownloadsFeatureTests` plan ran as a single invocation and passed: **314 tests in 62 suites, 0 failures, 3 known issues** (the pre-existing `withKnownIssue` assertions for the unimplemented client's three endpoints). No pre-existing expectation had to change, no assertion was weakened, no case deleted, and no yield removed to make a case pass.

Suites confirmed green by name in that run: `DownloadSchedulingTests`, `DownloadContinuedSessionTests`, `DownloadContinuedSessionLedgerTests`, `DownloadContinuedSessionIdentityTests`, `DownloadContinuedSessionInterleaveTests`, `DownloadPendingWorkTests`, `DownloadLogPrivacyInvariantTests`. `DownloadSchedulingTests` passing is load-bearing: a failure there is a real regression, not flake.

Because nothing had to be absorbed, the sanctioned relocation of `testEmptySchedulableSetStillPushesAPositiveTotal` into the ledger suite was not taken. File lengths after this plan: `DownloadContinuedSessionTests.swift` 999 (unchanged), `DownloadContinuedSessionInterleaveTests.swift` 179, `DownloadFeatureTestSupportTypes.swift` 581, `DownloadClient+ContinuedSession.swift` 472 — all under the 1000-line gate.

## Deviations from Plan

### 1. [Rule 1 — Correctness of the pinned assertion] The push sequence is four entries, not three

- **Found during:** Task 1, Step 2.
- **Issue:** The plan pinned three recorded subtitles — the mid-race push, the released parked push, the final drain push. The retry's scheduling also installs an active task through the inert runner, and that task's completion tail (`finishActiveTaskIfOwned(gid:generation:schedulesNext: false)`) spawns a convergence that calls `reconcileContinuedSession()` and pushes again. Pinning three entries would have been either wrong or flaky depending on whether that convergence landed before or after the gate release.
- **Fix:** The case waits for that convergence (`waitUntil { spy.progressUpdates.count == 2 }`) before releasing the gate, and pins four entries: `1 / 5 pages · 1 gallery`, `1 / 5 pages · 1 gallery`, `1 / 1 page · 0 galleries`, `1 / 1 page · 0 galleries`. The race itself is unchanged — the drain push stays parked across the whole mobilization — and the assertion is now deterministic rather than timing-dependent.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift`
- **Commit:** `60b660fb`

### 2. [Recorded, no change] The plan's `_ = try #require(await …testingContinuedSessionID())` is a discard

The plan asked the case to require the session id without using it. Kept as written (`_ = try #require(…)`): the requirement is the assertion — a nil id would mean no session was minted — and binding it to an unused name would trip nothing but reads as dead state.

## Validation notes

- **COVERAGE.md needs no new row.** This plan adds one guard on an already-integrated coordinator function; `git show HEAD | grep -c 'BGTaskScheduler\|BGContinuedProcessingTask'` returns 0. The matrix is validated, not extended.
- **Lint:** zero violations across `AppPackage/Sources`, `AppPackage/Tests`, `App` and `ShareExtension` under `swiftlint --strict`. No suppression, no `swiftlint:disable`, no `@unchecked Sendable`, no `nonisolated(unsafe)`, no `@preconcurrency` anywhere in this change.
- **Standing device item unchanged:** `15-UAT.md` test 2 remains a physical-device re-run. Nothing in this plan closes it, and SC2 stays where 15-22 left it.
- **Out of scope, untouched:** G-15-4 (plan 15-24, next wave); review warnings WR-03..WR-11 including the spy's dead `inFlightProgressUpdate` slot (WR-10), `finish`'s unconditional `true`, and the denominator floor rewind.

## Observation for the owner (not fixed, not project source)

A repo-wide `swiftlint` run reports ~40 violations under `.claude/worktrees/agent-acd71927a31028dcd/EhPanda/` — a stale, untracked worktree checkout of the pre-modularization tree (`git ls-files` returns 0 files there). It is not repository source and was deliberately left alone; it only means a repo-root lint invocation is noisy unless scoped to the tracked trees.

## Self-Check: PASSED

- `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` — FOUND, contains `hasPendingWork() == false`
- `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionInterleaveTests.swift` — FOUND, contains `testWorkMobilizedInsideTheTerminalPushSurvivesTheDrain`
- `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift` — FOUND, contains 3× `Task.yield()`
- Commit `60b660fb` — FOUND in `git log`
