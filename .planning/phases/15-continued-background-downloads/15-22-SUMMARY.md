---
phase: 15-continued-background-downloads
plan: 22
subsystem: download-client
tags: [swift, continued-processing, progress-card, gap-closure, exit-path-sweep, regression-testing]

requires:
  - phase: 15-continued-background-downloads
    provides: "The session-scoped retirement ledger and `pushContinuedSessionProgress(sessionID:)` from plans 15-20 and 15-21, whose arithmetic the terminal push reuses unchanged"
provides:
  - "One terminal progress push in the drain branch of `reconcileContinuedSession`, ordered after the client-session deferral and before the teardown (D-G2B-01)"
  - "An ownership re-check behind that push, which is the branch's first suspension point"
  - "One identifier-free drain diagnostic that discriminates DEC-A's two device outcomes"
  - "Production-path drains for all four drain-branch exit paths, replacing three synthesized terminal pushes"
  - "A recorded disposition for every one of the nine ways a continued session can end"
affects: [continued-background-downloads, download-client, system-progress-card, background-scheduling]

tech-stack:
  added: []
  patterns:
    - "A terminal state is asserted only on a drain reached through a production entry point; a directly invoked push at a drain is a call the product never makes, so a value pinned on one proves nothing"
    - "Ordering invariants are made enforceable by two independent test channels: the coordinator's ownership guard makes a too-late push record nothing, and the spy's rejected-update list makes a past-completion push visible"
    - "Falsifiability taken by construction — the drivers are converted before the fix lands and the failing pairs are recorded — rather than by a later deliberate-break pass"

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift

key-decisions:
  - "D-G2B-01 installed as an ordering rule over an existing call, not as new arithmetic: the push sits after the `continuedClientSessionID` deferral and before `markContinuedSessionEnded`, because that teardown both fails the push's own ownership guard and zeroes the ledger the terminal fraction sums."
  - "An ownership re-check was added between the push and the teardown. The push suspends (an index read plus the ledger's record read) where the branch's tail was previously suspension-free, so this is part of the fix rather than polish."
  - "DEC-A left unresolved and treated as unknown. The primary fix (emit the push) plus an identifier-free drain log were implemented; the fallback — rebasing `galleryCount` on the session's whole coverage — is a documented-contract change and was deliberately withheld from the executor."
  - "DEC-B honored: nothing here closes G-15-2B. `15-UAT.md` test 2 remains a physical-device check, and SC2 stays at PRESENT_BEHAVIOR_UNVERIFIED."
  - "The held-push identity case was absorbed, not weakened. Its discriminator changed from 'nothing under S1 was accepted' to 'releasing the held push adds nothing', because S1's own terminal push is now legitimate."
  - "`testEmptySchedulableSetStillPushesAPositiveTotal` was NOT relocated. The plan gated relocation on the 31-line budget failing; it held exactly, so the structural change was not taken."

patterns-established:
  - "Exit-path sweep: every way a session can end is enumerated and dispositioned — covered by a production-path test or recorded as a deliberate exclusion with the reason it cannot repaint — rather than fixing the branch a report happened to name."
  - "A drain-branch invariant is stated in the function's doc comment, outside the branch body, so a structural grep over the branch still reads as the bare call order."

requirements-completed: [SC1, SC2]

coverage:
  - id: D1
    description: "A drained queue's card receives one final push, ordered after the client-session deferral and before the teardown"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testSequentialCompletionsHoldTheDenominatorAndAdvanceTheCount"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testReportedTotalsDoNotDependOnCompletionOrder"
        status: pass
    human_judgment: false
  - id: D2
    description: "All four drain-branch exit paths — completion, pause, delete, cancel — reach the terminal push through production entry points"
    requirement: SC2
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift#testDrainingTheQueueCompletesTheSessionWithSuccess"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift#testCancellingTheLastQueuedWorkItemCompletesTheSession"
        status: pass
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift#testDeletingTheLastGalleryEndsTheSessionWithNoStaleSubtitle"
        status: pass
    human_judgment: false
  - id: D3
    description: "Exactly one terminal push per drained session — repeated scheduling passes add neither a push nor a completion"
    requirement: SC1
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift#testSchedulingPassesAfterTheDrainAddNoSecondCompletion"
        status: pass
    human_judgment: false
  - id: D4
    description: "The expiration exclusion is proved rather than asserted: neither the accepted nor the rejected push list grows after the store completed the task itself"
    requirement: SC1
    verification:
      - kind: unit
        ref: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift#testEndedSessionReceivesNoFurtherUpdateOrCompletion"
        status: pass
    human_judgment: false
  - id: D5
    description: "On a physical iOS 26 device, a backgrounded multi-gallery queue running to completion leaves the card describing zero remaining galleries, or leaves no card at all"
    requirement: SC2
    verification: []
    human_judgment: true
    rationale: "The card is system-rendered; the simulator neither renders it nor fires its cancel. DEC-A's fallback can only be triggered by a device observation, and DEC-B makes this run the phase-advancement gate."

duration: 35min
completed: 2026-08-04
status: complete
---

# Phase 15 Plan 22: Terminal Progress Push at Queue Drain Summary

**G-15-2B closed in code: the drain branch of `reconcileContinuedSession` now emits one correctly ordered progress push before it tears the session down, so the card's last word describes zero remaining galleries instead of the final gallery's mid-download flush — and every one of the nine ways a session can end is now dispositioned rather than only the branch the report named.**

## What Was Built

### The fix: one push, and the ordering that makes it real

`backgroundProcessingClient.updateProgress` has exactly one call site, inside
`pushContinuedSessionProgress`, and at a drain neither of its two callers runs: control takes the
`markContinuedSessionEnded` / `finish` branch, and `finish` carries no subtitle. The last string the
card held was therefore the final gallery's `force: true` flush, taken while that gallery was still
downloading and therefore still inside its own schedulable set — a string that always ends
"1 gallery".

The drain branch now reads:

```swift
guard let clientSessionID = continuedClientSessionID else {
    continuedSessionNeedsReconciliation = true
    return
}
// D-G2B-01: the card's last word, taken while this session still owns it.
await pushContinuedSessionProgress(sessionID: sessionID)
guard continuedSessionID == sessionID else { return }
logger.notice("Continued-processing session drained, terminal progress pushed.")
// Ended first: completion is the last thing this session does, and the client's
// stream finishing behind it must find no state left to clear.
markContinuedSessionEnded(sessionID: sessionID)
await backgroundProcessingClient.finish(clientSessionID, true)
```

The ownership re-check quoted above — `guard continuedSessionID == sessionID else { return }` — is
part of the fix, not polish. The push suspends (an index read plus the ledger's record read) where
this branch's tail was previously free of suspension points, so ownership is re-checked behind it
exactly as it is after every other suspension in the file.

The invariant and both failure modes are written into the function's doc comment rather than into
the branch body, deliberately: the plan's structural check greps the branch for the bare call order,
and prose naming `markContinuedSessionEnded` inside it would have made that check unreadable.

### Structural verification of the ordering

```
$ awk '/guard await hasPendingWork/,/^        }$/' …/DownloadClient+ContinuedSession.swift \
    | grep -n 'continuedClientSessionID\|pushContinuedSessionProgress\|markContinuedSessionEnded\|backgroundProcessingClient.finish'
5:            guard let clientSessionID = continuedClientSessionID else {
10:            await pushContinuedSessionProgress(sessionID: sessionID)
15:            markContinuedSessionEnded(sessionID: sessionID)
16:            await backgroundProcessingClient.finish(clientSessionID, true)
```

Deferral, push, teardown, completion — in exactly that order.

### The coverage that was missing

Four terminal pushes across the two suites were being manufactured by calling
`pushContinuedSessionProgress(sessionID:)` directly after the last `settleCompletedDownload` — a call
the product never makes at a drain. All four now end at `await fixture.manager.scheduleNextIfNeeded()`,
the tail every queue mutation converges on, and assert the value that tail produced. Mid-queue pushes
stay direct calls: those are arithmetic assertions rather than timing ones, and the ledger suite's
header comment now says so explicitly and says why the terminal ones differ.

## Falsifiability: the pre-fix readings

### Task 1 — the two ledger completion drains, observed before the push existed

The drivers were converted first and the suite run against the unmodified drain branch. Both cases
failed, each on its own derivation:

| Case | Pushes recorded | Last recorded pair | Own derivation | Match |
|---|---|---|---|---|
| `testSequentialCompletionsHoldTheDenominatorAndAdvanceTheCount` | 3 (expected 4) | `16 / 20 pages · 1 gallery` (16, 20) | `16 / 20 pages · 1 gallery` | yes |
| `testReportedTotalsDoNotDependOnCompletionOrder` | 3 (expected 4) | `10 / 20 pages · 1 gallery` (10, 20) | `10 / 20 pages · 1 gallery` | yes |

The two owe different pre-fix strings because they finish in opposite orders — the sequential case has
retired large's 10 and middle's 6 with the 4-page gallery still schedulable, the order-independence
case has retired small's 4 and middle's 6 with the 10-page gallery still schedulable. Each reading
matches its own case's derivation and neither matches the other's, which is what makes them evidence
rather than coincidence. Reported verbatim by the run:

```
Expectation failed: (finalPair → PushedPair(completedUnitCount: 16, totalUnitCount: 20,
  subtitle: "16 / 20 pages · 1 gallery")) == (Self.drainedPair → PushedPair(completedUnitCount: 20,
  totalUnitCount: 20, subtitle: "20 / 20 pages · 0 galleries"))

Expectation failed: (finalPair → PushedPair(completedUnitCount: 10, totalUnitCount: 20,
  subtitle: "10 / 20 pages · 1 gallery")) == (Self.drainedPair → PushedPair(completedUnitCount: 20,
  totalUnitCount: 20, subtitle: "20 / 20 pages · 0 galleries"))
```

Neither case passed in Step 1, so the driver conversion was genuine on both.

### Task 2 — the extended cases, read against a temporarily reverted drain branch

The terminal push was removed, the two named cases were run, and the tree was restored with
`git checkout -- <file>` before committing; `git status` carried no trace of the temporary edit.

| Case | Reported without the terminal push |
|---|---|
| `testDrainingTheQueueCompletesTheSessionWithSuccess` (pause-to-empty) | `spy.progressUpdates.count → 0` and `spy.progressUpdates.last?.subtitle → nil` — the card received **nothing at all** after the start string |
| `testDeletingTheLastGalleryEndsTheSessionWithNoStaleSubtitle` (delete-to-empty) | `terminalPair.subtitle → "6 / 10 pages · 1 gallery"` and `terminalPair.totalUnitCount → 10` — the **stale pre-delete string survived as the card's last word** |

The delete case reproduces the device-reported shape exactly: a queue that is empty while the card
still names a gallery that no longer exists.

## Exit-path sweep — every way a session can end

Three prior gap rounds in this phase each fixed the branch the report named and each refilled, so the
sweep below is reproduced in full with its covering test named per row.

| # | Exit path | Where it ends | Disposition | Covering test | Status |
|---|---|---|---|---|---|
| 1 | Last gallery **completes** | drain branch | Terminal push | `testSequentialCompletionsHoldTheDenominatorAndAdvanceTheCount`, `testReportedTotalsDoNotDependOnCompletionOrder`, `testEmptySchedulableSetStillPushesAPositiveTotal` | pass |
| 2 | Last schedulable gallery **paused** | drain branch | Terminal push | `testDrainingTheQueueCompletesTheSessionWithSuccess` | pass |
| 3 | Last gallery **deleted** | drain branch | Terminal push | `testDeletingTheLastGalleryEndsTheSessionWithNoStaleSubtitle` (new) | pass |
| 4 | Last **queued work item cancelled** (update / redownload / repair) | drain branch | Terminal push | `testCancellingTheLastQueuedWorkItemCompletesTheSession` | pass |
| 5 | Repeated scheduling passes after a drain | drain branch, already ended | Exactly one terminal push, never a second | `testSchedulingPassesAfterTheDrainAddNoSecondCompletion` | pass |
| 6 | **Expiration** (system reclaim, or user cancel on the card) | `handleContinuedSessionEvent(.expired)` | **Deliberate exclusion** | `testEndedSessionReceivesNoFurtherUpdateOrCompletion` (extended) | pass |
| 7 | **Unavailable** session | `handleContinuedSessionEvent(.unavailable)` | **Deliberate exclusion** | `testUnavailableSessionSurfacesNothingAndLeavesNoLiveSession` (unchanged) | pass |
| 8 | **Start refused** | `ensureContinuedSession` rollback | **Deliberate exclusion** | `testARefusedStartRollsBookkeepingBackAndTheNextTapStartsARealSession` (unchanged) | pass |
| 9 | Superseded session's trailing teardown | `markContinuedSessionEnded` identity guard | **Deliberate exclusion** | `testStaleTeardownDoesNotClearANewerSession` (unchanged) | pass |

Exclusion reasons, restated for rows 6–9:

- **Row 6 — expiration.** The store has already run `setTaskCompleted(success: false)` inside its own
  expiration handler before the event reaches the coordinator, so there is no task left to repaint.
  The coordinator's handler must also end the session *before* pausing, or each pause's reschedule
  tail would reconcile a session the system already took. The extended case now proves the exclusion
  instead of asserting it: `spy.rejectedProgressUpdates` staying empty is the stronger claim, because
  the coordinator's own guard refused before anything reached the client seam.
- **Row 7 — unavailable.** No task was ever adopted, so no card exists to leave stale.
- **Row 8 — start refused.** Same reason: no card.
- **Row 9 — superseded teardown.** A foreign id is a no-op by construction, and the live successor
  keeps pushing.

Rows 1–4 share one code point, which is the whole argument for fixing at the convergence point rather
than at `settleCompletedDownload`: instrumenting the completion path alone would have left three
siblings open, which is exactly how the previous rounds refilled.

## Derived terminal values, and what the runs reported

Every literal below is asserted as an exact value and every run matched its derivation. No observed
pair contradicted D-G2-01, and no expectation was written from an observation.

| Case | Fixture at drain | Terminal pair | Observed |
|---|---|---|---|
| Ledger completion drains | 10 + 6 + 4 pages, all finished | `20 / 20 pages · 0 galleries` | as derived |
| `testEmptySchedulableSetStillPushesAPositiveTotal` | 6 pages, all finished | `6 / 6 pages · 0 galleries` | as derived (unchanged; only the driver changed) |
| `testDrainingTheQueueCompletesTheSessionWithSuccess` | 2 pages, 0 finished, paused | `0 / 1 page · 0 galleries` | as derived |
| `testSchedulingPassesAfterTheDrainAddNoSecondCompletion` | same fixture | `0 / 1 page · 0 galleries`, exactly one push | as derived |
| `testCancellingTheLastQueuedWorkItemCompletesTheSession` | 5 pages, 1 finished, cancelled | `1 / 1 page · 0 galleries`, twice | as derived |
| `testDeletingTheLastGalleryEndsTheSessionWithNoStaleSubtitle` | 10 pages, 6 finished, deleted | `6 / 6 pages · 0 galleries` | as derived |

The drained fraction is honest arithmetic rather than a special case: the retirement ledger already
holds every page the session finished, so a drained queue sums to N of N with no gallery remaining.
Nothing in the ledger, `schedulableSnapshot`, the display clamps or `settleCompletedDownload`'s queue
shrink was reopened.

## Pre-existing expectations the terminal push forced to change

One, in a file the plan's `<files>` list did not anticipate.

**`DownloadContinuedSessionIdentityTests.testAHeldProgressPushCannotRepaintASuccessorSessionsCard`.**
The case gates a push at the client seam under S1, then cancels the last queued work item — which now
drains S1 and therefore emits S1's own terminal push before completing. That push is legitimate: it
lands while S1 still owns the card. Two assertions had to be restated, neither relaxed:

- `#expect(!spy.progressUpdates.contains(where: { $0.sessionID == firstClientSessionID }))` became
  `expectNoDifference(spy.progressUpdates, acceptedBeforeRelease)`, with the accepted list captured
  immediately before `gate.release()`. The discriminator for the *held* push is no longer "nothing
  under S1 was accepted" but "releasing it adds nothing" — which is strictly what the case is about,
  and is if anything sharper than the original.
- The post-release accepted-session list moved from `[secondClientSessionID]` to
  `[firstClientSessionID, secondClientSessionID]`, the first entry being S1's terminal push.

`spy.rejectedProgressUpdates.map(\.sessionID) == [firstClientSessionID]` is unchanged and still
carries the case's core claim. No assertion was dropped or shortened.

The three other cases in that suite, and the two other suites that hold the spy
(`DownloadDeleteConvergenceTests`, `DownloadOwnershipConvergenceTests`,
`DownloadContinuedSessionInterleaveTests`), assert `finishRecords` only or take their push readings
before the drain, so none required a change.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Collateral coverage] Extended the sweep into `DownloadContinuedSessionIdentityTests.swift`**
- **Found during:** Task 2
- **Issue:** The plan's Task 2 `<files>` list named only the two continued-session suites, but its
  action text mandates absorbing any pre-existing expectation the terminal push forces to change. The
  held-push identity case is exactly such an expectation.
- **Fix:** Restated two assertions as described above, with a comment recording why. Nothing weakened.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift`
- **Commit:** d1e2a5b4

No other deviations. No architectural questions arose, no packages were installed, and no
authentication gate was hit.

## Decisions Left Open, Deliberately

### DEC-A — does a push immediately followed by `setTaskCompleted` repaint on device?

Unresolved, and treated as unknown. The primary fix is implemented; so is the evidence hook. The drain
branch logs one static, identifier-free `notice` immediately after the push, carrying no gallery value
and no identifier, so it stays inside the module's log-privacy invariant
(`DownloadLogPrivacyInvariantTests` green in both tasks' runs). **That log line is the discriminator
between DEC-A's two failing branches** — without it, a device run still showing "1 gallery" cannot
distinguish *the push was never emitted* from *the push was emitted and the system did not repaint*,
and those have opposite fixes.

The fallback — rebasing `galleryCount` from the live schedulable set onto the session's whole coverage
— is **not implemented**, deliberately. It is a documented-contract change, not a bug fix: it rewrites
the `ContinuedSessionProgress` doc comment, changes every mid-run string the user sees, and interacts
with the base-mixing observation recorded as `secondary_note` in `15-UAT.md`.

Trigger table, restated for whoever takes the device run:

| Device observation | Verdict |
|---|---|
| Final subtitle names zero galleries | DEC-A resolved: the push repaints. No contract change. Close G-15-2B. |
| Card disappears at completion without a readable final string | DEC-A resolved: satisfied vacuously — `15-UAT.md` test 2 accepts "or the card ending". No contract change. |
| Final subtitle still names one gallery **and** the drain log line is present | The push is emitted and the system does not repaint. **Fallback triggered** — return to the owner as a new gap round proposing the contract change; do not apply it silently. |
| Final subtitle still names one gallery **and** the drain log line is absent | The push never fired — an ordering or guard defect in this change, not a repaint question. Fix that first and re-run. |

### DEC-B — device verification gates phase advancement

**Nothing in this plan closes G-15-2B.** `15-UAT.md` test 2 remains a physical-device check and
`15-VERIFICATION.md` keeps SC2 at `PRESENT_BEHAVIOR_UNVERIFIED`. Three facts make an
automated-green-only advance unsafe: the simulator neither renders the card nor fires its cancel; this
exact defect class — a terminal state no test observed — escaped the suite twice in this phase; and
DEC-A's fallback can only be triggered by a device observation.

**Retest inputs for `15-UAT.md` test 2.** Queue several galleries, background the app, and let the
whole queue run to completion. The observable difference this plan makes: **after every queued gallery
completes, the card's description names zero remaining galleries, or the card is gone — never a
leftover gallery.** If it still names one, check the unified log for the drain notice
("Continued-processing session drained, terminal progress pushed.") and route by the table above.

## Gate Confirmations

- **API coverage:** `COVERAGE.md` needs no new row, confirmed. This round adds one call to an
  already-integrated coordinator function and touches no `BGTaskScheduler` or
  `BGContinuedProcessingTask` member.
- **Schema:** no persisted schema changes.
- **Privacy:** the one new log statement is static text with no interpolation;
  `DownloadLogPrivacyInvariantTests` ran green alongside both tasks.
- **Localization:** no catalog entry touched. The string catalog already renders a count of zero
  through the plural `other` category, so the labeled-format-argument rule is not engaged.
- **Lint:** `swiftlint --strict` over `AppPackage/Sources/DownloadClient` and
  `AppPackage/Tests/DownloadsFeatureTests` exits 0 with zero violations. No suppression, disable or
  exemption was added anywhere; no unchecked-Sendable, unsafe-nonisolated or preconcurrency escape
  hatch was used.
- **File length:** `DownloadContinuedSessionTests.swift` is **999** lines against the 1000-line
  error-severity limit; `DownloadContinuedSessionLedgerTests.swift` is 477.

## Finding for the verifier — the 1000-line ceiling

`DownloadContinuedSessionTests.swift` went from 968 to **999** lines, using the plan's 31-line budget
exactly. It fits, so the plan's relocation remedy was gated off and
`testEmptySchedulableSetStillPushesAPositiveTotal` was left where it is; moving it would have been an
unrequested structural change the plan explicitly conditioned on the budget failing. No assertion was
dropped, shortened or exempted to make room.

**One line of headroom remains.** The next edit to that file — including a one-line assertion added by
a future gap round — trips `file_length` at error severity and fails the build. Recorded here rather
than acted on: the sanctioned remedy is already written down in this plan (relocate
`testEmptySchedulableSetStillPushesAPositiveTotal`, whole and with its doc comment, into the ledger
suite, which frees roughly 48 lines and sits at 477).

## Test Results

| Run | Scope | Result |
|---|---|---|
| Task 1, pre-fix | `DownloadContinuedSessionLedgerTests` | **failed**, 9 issues across the two converted cases — the intended falsifiability reading |
| Task 1, post-fix | `DownloadContinuedSessionLedgerTests` + `DownloadLogPrivacyInvariantTests` | 8 tests in 2 suites passed |
| Task 2, pre-fix probe | both continued-session suites, terminal push temporarily removed | **failed** on the two named cases, readings recorded above; tree restored before commit |
| Task 2, final | full `DownloadsFeatureTests` plan | **313 tests in 62 suites passed** (3 known issues — the `withKnownIssue` unimplemented-client assertions) |

`DownloadSchedulingTests` was green in the final run. Every xcodebuild invocation ran alone; none
overlapped another.

## Self-Check: PASSED

Files verified present:
- FOUND: `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift`
- FOUND: `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLedgerTests.swift`
- FOUND: `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift`
- FOUND: `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift`

Commits verified present:
- FOUND: `f8159740` — fix(15-22): push terminal progress when the queue drains
- FOUND: `d1e2a5b4` — test(15-22): cover every way a continued session ends
