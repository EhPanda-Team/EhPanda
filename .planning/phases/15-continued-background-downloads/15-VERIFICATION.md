---
phase: 15-continued-background-downloads
verified: 2026-07-29T03:51:37Z
status: human_needed
score: 1/4 must-haves verified
behavior_unverified: 3
overrides_applied: 0
next_action: "Automated checks pass. Run the physical iOS 26 device checks below before shipping."
next_command: "/gsd:verify-work 15"
re_verification:
  previous_status: gaps_found
  previous_score: 1/4
  gaps_closed:
    - "A drain while client start is in flight can clear coordinator ownership; a second tap is then refused by the live single-session store and the final pending work has no continued-processing session."
    - "A failed active-gallery folder removal clears the active owner and returns without notifying or rescheduling, stranding the queue and its session."
    - "Downloaded gallery titles and identifiers are emitted as public unified-log fields."
  gaps_remaining: []
  regressions: []
behavior_unverified_items:
  - truth: "SC1 — a foreground-started download continues to completion after the app is backgrounded, for a queue large enough to outlast the old grace period."
    test: "On a physical iOS 26 device, queue at least three galleries totaling at least 300 pages, start in the foreground, background the app for more than 60 seconds without returning, then foreground and compare persisted page counts against the queue."
    expected: "Pages keep landing while backgrounded, well past the window the deleted `beginBackgroundTask` assertion used to bound; no page is lost or downloaded twice."
    why_human: "The simulator does not grant continued-processing tasks and does not suspend the process the way a device does. Source presence proves the request is submitted, not that the system keeps the process running."
  - truth: "SC2 — the system-provided progress UI reflects real download progress and its cancel affordance stops the queue, leaving state consistent with an in-app cancel."
    test: "Observe the system progress card during the backgrounded run: check that it appears immediately with real counts and keeps advancing. Then tap the card's cancel affordance, foreground the app, and compare queue/manifest state against the state left by pausing each gallery by hand."
    expected: "Exactly one neutral card, counts advancing monotonically, and card-cancel leaving the same queue state as the per-gallery in-app pause."
    why_human: "The card is rendered by system UI outside the app, and the cancel affordance delivers its signal through a system-owned expiration handler. Neither renders nor fires in the simulator."
  - truth: "SC3 — real system refusal, indefinite queuing, expiration, process suspension, and next-foreground resume preserve work with no visible error and no fallback tier."
    test: "Exercise a refused or indefinitely queued submission and a system-initiated expiration on device; force-quit mid-session and relaunch; foreground again after each."
    expected: "No crash, no visible background-processing error anywhere in the UI, no duplicated or lost pages, and persisted work resuming on the next foreground."
    why_human: "Real scheduler grant/queue/expiration decisions and process death are device-owned. The deterministic unavailable/expiration tests cover the coordinator policy, not the system transitions that trigger it."
human_verification:
  - test: "On a physical iOS 26 device, queue at least three galleries totaling at least 300 pages, start in the foreground, background the app for more than 60 seconds, then foreground and compare persisted page counts against the queue."
    expected: "Pages keep landing while backgrounded, well past the old grace window; no page lost or duplicated."
    why_human: "The simulator neither grants continued-processing tasks nor suspends the process as a device does."
  - test: "Observe the system progress card during that run, then cancel from the card, foreground, and compare queue state against pausing each gallery by hand."
    expected: "One neutral card with real, monotonically advancing counts; card-cancel state matches the in-app per-gallery pause baseline."
    why_human: "The card and its cancel affordance are system-owned and do not render or fire in the simulator."
  - test: "Exercise a refused or indefinitely queued submission and a system expiration; force-quit mid-session and relaunch."
    expected: "No crash, no visible error, no duplicated or lost pages, and persisted work resuming on foreground."
    why_human: "Real scheduler decisions and process death are not reproducible in unit tests."
  - test: "Take a sysdiagnose or collected log archive after a real download session and search it for gallery titles and unmasked gallery identifiers."
    expected: "No gallery title and no unmasked identifier from the DownloadClient module appears in collected diagnostics."
    why_human: "The invariant suite proves the source spellings; only a real collected archive proves what the system actually persists."
---

# Phase 15: Continued Background Downloads Verification Report

**Phase Goal:** Adopt `BGContinuedProcessingTask` (iOS 26) so a gallery download the user just
started keeps running when the app is backgrounded, surfaced by the system-provided progress UI,
instead of being cut short by the short grace period that bounded the previous behavior.

**Verified:** 2026-07-29T03:51:37Z

**Status:** `human_needed`

**Re-verification:** Yes — after gap-closure plans 15-17, 15-18 and 15-19

**Canonical next action:** Automated checks pass. Run the physical iOS 26 device checks before shipping.

**Canonical next command:** `/gsd:verify-work 15`

All three gaps recorded by the previous report are closed. Each was re-checked against current
source and against a test that runs, not against the plan summaries. No regression was introduced by
the closure work. What remains is entirely device-owned behavior that no simulator test can decide.

Note on the score: it reads 1/4 in both reports, but the meaning has changed. Previously two truths
were `FAILED` — real, observable code defects blocking the goal. Now zero are failed; three are
present-and-wired with their runtime halves unexercisable off-device.

## Goal Achievement

### Observable Truths

| # | Roadmap truth | Status | Evidence |
|---|---|---|---|
| SC1 | A foreground-started download continues to completion after backgrounding beyond the old grace period | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Both blocking defects are gone (see the gap table). The seam is complete and exercised: `ensureContinuedSession()` is called from all five queue-mobilizing paths, the plist permits `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`, and `testDrainingTheQueueCompletesTheSessionWithSuccess` / `testResumingWithSchedulableWorkStartsExactlyOneSession` pass. Whether the system actually keeps the process running while backgrounded is device-only |
| SC2 | System UI shows real progress and card cancel matches in-app cancel | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Progress flows from one real queue snapshot (`schedulableProgress()` → seeded start → session-identified `updateProgress`) and cancel parity is directly asserted by `testExpirationLeavesTheQueueInThePerGalleryPauseBaselineState` and `testExpirationLeavesTheSchedulingBlockedSetAsAPauseDoes`. The card's rendering and its cancel affordance are system-owned and render nowhere in the simulator |
| SC3 | Best-effort refusal/queue/expiration has no fallback tier, no loss, no duplication, no visible error | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | The deletion half is fully proven: no source anywhere in `App/`, `AppPackage/`, `ShareExtension/` names `BGProcessingTask` or `beginBackgroundTask`, and `BackgroundExecutionInvariantTests` pins that permanently. The `.unavailable` path is silent by construction and tested. Real scheduler refusal/queuing, process suspension and next-foreground resume remain device-only |
| SC4 | A testable session seam owns scheduler access and exposes start/update/finish plus self-finishing events with an unimplemented value | ✓ VERIFIED | Three-endpoint identified seam in `BackgroundProcessingClient`; `endSession` yields then finishes its own stream; `BackgroundProcessingClient()` reports an issue on every endpoint (`testUnimplementedClientReportsAnIssueForEveryEndpoint`); `import BackgroundTasks` occurs in exactly one file (`ContinuedTaskScheduling.swift`) and the invariant test enforces it |

**Score:** 1/4 roadmap truths verified (3 present, behavior-unverified)

Phase 16 is Dynamic Type Accessibility. No later milestone phase covers any of these, so nothing is
deferred.

## Re-verification of the Three Recorded Gaps

Each was traced in current source before reading any summary.

### Gap A (SC1/SC2) — ownership cleared mid-start — ✓ CLOSED

`DownloadClient+ContinuedSession.swift`. Traced end to end:

- `ensureContinuedSession()` writes `hasLiveContinuedSession` and `continuedSessionID` at lines
  93-94, with no suspension between the guard and those writes.
- The client start suspends at line 98; `continuedClientSessionID` is written at line 120, after
  the ownership re-check at line 116.
- `reconcileContinuedSession()` lines 237-240 now treat a nil `continuedClientSessionID` as
  "reconciliation owed", recording `continuedSessionNeedsReconciliation = true` and returning with
  ownership intact instead of clearing it.
- The debt is discharged at lines 130-134 immediately after the client id lands, cleared first so a
  fresh reconcile can record new debt.
- `markContinuedSessionEnded` clears the debt flag (line 191), so it cannot outlive its session, and
  a refused start rolls the same bookkeeping back at lines 104-112.

Every nil-client-id read now carries a written disposition — DEFERRED (reconcile), SKIPPED (progress
push, line 264), TERMINAL (refusal, line 105) — which is what the 15-17 must-have demanded.

Behavioral evidence: `DownloadContinuedSessionIdentityTests.testADrainDuringAnInFlightStartDefersReconciliationAndKeepsCoverage`
parks the first start on an armed gate, drains the queue underneath it, taps again, and asserts
`spy.startCount == 1` with the session still live and the deferred reconcile pushing under the first
session id. That assertion depends on the coordinator's own guard, not on the spy's — so WR-08's
spy-fidelity complaint does not weaken it.

### Gap B (SC1) — failed removal stranding the queue — ✓ CLOSED

`DownloadClient+PublicAPI.swift:196-232` — all three exits that clear active ownership now release
the gallery's scheduling block, notify observers and call `scheduleNextIfNeeded()` before returning:
the `notFound` branch (196-205), the typed-`AppError` catch (208-215) and the untyped catch
(216-223).

The fix was correctly swept into the second entry point the original finding never named —
`DownloadClient+Folders.swift:114-135`, `deleteFolder(name:)`, on both error branches, releasing the
block for every contained gid.

The invariant is stated once where it must be maintained, at `DownloadClient+Manager.swift:345`
("ACTIVE-OWNERSHIP CONVERGENCE"), with FORBIDDEN and REACHABLE-BY-DESIGN dispositions, and cited at
eight sites across six files.

Behavioral evidence: `DownloadOwnershipConvergenceTests.testAFailedRemovalStillConvergesTheQueue`,
4 parameterized cases spanning both entry points × typed and untyped error shapes, each asserting the
record survives and stays queued, a schedule was recorded, a second observer emission arrived, the
session is still live and no `finish` was issued.

### Gap C (privacy gate) — public gallery identity in logs — ✓ CLOSED

Independent grep of `AppPackage/Sources/DownloadClient`: every surviving `privacy: .public` field is
non-identifying — `download.pageCount`, `context.mode.rawValue`, `failedPages.map(\.index)`,
`operation`, `attempt`. Every gallery identifier that is still logged carries
`privacy: .private(mask: .hash)`. No gallery title, folder name, folder path, raw error value or
localized error description reaches a public field anywhere in the module. The rejected-response
body snippet is now `.private`.

`ContinuedProcessingSession.swift`'s two remaining `.public` fields were audited and are genuinely
identity-free: a bundle identifier plus a minted UUID (line 135) and a submission error raised
before any gallery value is in scope (line 144).

Behavioral evidence: `DownloadLogPrivacyInvariantTests` — two tests, both of which refuse to pass
vacuously (they require a non-empty scan and a known member file). WR-07's critique of that suite's
strength is recorded below but does not reopen the gap.

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `App/Info.plist` | One bundle-scoped continued wildcard | ✓ VERIFIED | `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`, single entry; `processing` background mode retained with a written justification |
| `BackgroundProcessingClient.swift` | Identified start/update/finish seam | ✓ VERIFIED | Three endpoints, `@DependencyClient`, injected as `.live` at `DownloadClient.swift:77` |
| `ContinuedProcessingSession.swift` | Main-actor task/session store | ✓ VERIFIED | Single-session guard evaluated and written in one synchronous main-actor run (85-98); real seed; identity-gated update/finish; per-request cancel; stream self-finish |
| `ContinuedTaskScheduling.swift` | Sole scheduler adapter | ✓ VERIFIED | The only file in the tree importing `BackgroundTasks` |
| `DownloadClient+ContinuedSession.swift` | Coordinator session lifecycle | ✓ VERIFIED | Deferred-reconciliation contract installed; all nil-client-id reads dispositioned |
| `DownloadClient+PublicAPI.swift` | User actions converge scheduling/session state | ✓ VERIFIED | All three ownership-clearing exits converge |
| `DownloadClient+Folders.swift` | Second removal entry point converges | ✓ VERIFIED | Both catch branches release every contained gid and converge |
| `DownloadClient+PendingWork.swift` | Single schedulable-work authority | ✓ VERIFIED | `hasPendingWork` and `schedulableDownloads` are the one selection path |
| `DownloadOwnershipConvergenceTests.swift` | Parameterized invariant regression | ✓ VERIFIED | 4 cases, both entry points, both error shapes |
| `DownloadContinuedSessionIdentityTests.swift` | Reentrant lifecycle regressions | ✓ VERIFIED | Drain/start/tap case now asserts the post-fix contract; the parked task is released by a `defer` installed the moment the gate is armed (lines 99-100) |
| `DownloadLogPrivacyInvariantTests.swift` | Permanent privacy scan | ✓ VERIFIED (see WR-07) | Runs and passes; its denylist is narrower than its doc comment claims |
| `BackgroundExecutionInvariantTests.swift` | Permanent topology guard | ✓ VERIFIED | Scans app, package sources, package tests, extension and the plist |
| `BackgroundProcessingClient/.swiftlint.yml` | New-module lint inheritance | ✓ VERIFIED | `parent_config: ../../../.swiftlint.yml` |

## Key Link Verification

| From | To | Via | Status |
|---|---|---|---|
| Plist wildcard | Runtime identifiers | Bundle prefix plus `.continued.<UUID>` | ✓ WIRED |
| Live client closures | Session store | Main-actor `start`/`updateProgress`/`finish` | ✓ WIRED |
| Session store | System scheduler | `ContinuedTaskScheduling.live` | ✓ WIRED |
| User taps (enqueue, togglePause→resume, retry ×2, superseded-pause) | `ensureContinuedSession()` | Success-path calls | ✓ WIRED (the fifth call site is WR-04's contract contradiction, below) |
| Client start in flight | Queue-drain reconcile | `continuedSessionNeedsReconciliation` deferral | ✓ WIRED — was the previous NOT_WIRED |
| Delete / deleteFolder failure | Queue + session convergence | Block release, `notifyObservers()`, `scheduleNextIfNeeded()` | ✓ WIRED — was the previous NOT_WIRED |
| Page-flush + scheduling reconcile | Card | `pushContinuedSessionProgress` under session identity | ✓ FLOWING |
| Expiration event | Per-gallery pause | Session id + queue-intent generation ownership | ✓ WIRED |

## Data-Flow Trace

| Data | Source | Sink | Status |
|---|---|---|---|
| Initial completed/total counts | One schedulable queue snapshot | Start storage, then adopted task `Progress` | ✓ FLOWING |
| Later card progress | Throttled page flush and scheduling reconcile | Session-identified `updateProgress`, monotonic floor | ✓ FLOWING |
| Client session ownership | Client start return | Coordinator liveness, deferred-reconcile discharge | ✓ FLOWING — was DISCONNECTED |
| Delete/deleteFolder error recovery | Reloaded record, retained queue entry | Observer, scheduler, session reconcile | ✓ FLOWING — was DISCONNECTED |
| Card text | Localized count-only builder | System title/subtitle | ✓ FLOWING, no gallery identity |
| Operational log identity | Gallery gid | Hash-masked private field | ✓ NON-DISCLOSING — was DISCLOSING |

## Behavioral Spot-Checks

The full workspace suite was run once against this HEAD (`ba6828df`) by the orchestrator:
`xcodebuild test -scheme AppPackage-Package` → `** TEST SUCCEEDED **`, 0 failures, ~820 tests across
22 target runs, no compile or SwiftLint warnings. That single run is the execution evidence for
every named test below; per the one-run rule, no test was re-run in isolation.

| Behavior | Evidence | Status |
|---|---|---|
| Drain during an in-flight start defers reconciliation and keeps coverage | `testADrainDuringAnInFlightStartDefersReconciliationAndKeepsCoverage` passed in the suite run | ✓ PASS |
| Failed removal still converges the queue, both entry points, both error shapes | `testAFailedRemovalStillConvergesTheQueue` (4 cases) passed | ✓ PASS |
| No public log interpolation exposes gallery identity | `testNoDownloadLogPublishesGalleryIdentity` + `testDownloadIdentityLogsStayHashMasked` passed | ✓ PASS |
| Live store refuses an overlapping start and a later start succeeds | `testStartWhileASessionIsHeldIsRefusedAndALaterStartSucceeds` passed | ✓ PASS |
| Card cancel leaves the per-gallery in-app pause baseline | `testExpirationLeavesTheQueueInThePerGalleryPauseBaselineState`, `testExpirationLeavesTheSchedulingBlockedSetAsAPauseDoes` passed | ✓ PASS |
| Unimplemented client reports an issue on every endpoint | `testUnimplementedClientReportsAnIssueForEveryEndpoint` passed | ✓ PASS |
| No deleted background-execution spelling survives; scheduler named only by the client seam | `BackgroundExecutionInvariantTests`, 2 tests, passed; independently reproduced by grep | ✓ PASS |
| Real system grant, card rendering, device cancel, process suspension | Requires physical iOS 26 hardware | ? DEVICE BACKSTOP |

## Probe Execution

No phase-declared or conventional `probe-*.sh` scripts exist in this repository.

## Requirements Coverage

`.planning/REQUIREMENTS.md` maps no requirement IDs to Phase 15 and contains no Phase 15 orphan. The
scope contract is the four roadmap success criteria, referenced by plans as SC-labels. All 19 plans
declare `requirements:` drawn only from `SC1`–`SC4`; every one of the four is claimed by at least one
plan.

| Contract | Source plans | Status |
|---|---|---|
| SC1 | 15-01 through 15-03, 15-05 through 15-15, 15-17, 15-18 | ⚠️ NEEDS HUMAN — code path complete and unblocked; continuation is device-observable |
| SC2 | 15-04, 15-06, 15-07, 15-12 through 15-15, 15-17, 15-19 | ⚠️ NEEDS HUMAN — progress and cancel parity proven at the seam; card is device-observable |
| SC3 | 15-01, 15-02, 15-06, 15-07, 15-14, 15-15 | ⚠️ NEEDS HUMAN — deletion half proven; scheduler and process transitions are device-observable |
| SC4 | 15-01, 15-03, 15-04, 15-07, 15-16 | ✓ SATISFIED |

## Anti-Patterns Found

No `TBD`, `FIXME`, `XXX`, `TODO`, `HACK` or `PLACEHOLDER` marker exists anywhere in
`AppPackage/Sources/DownloadClient`, `AppPackage/Sources/BackgroundProcessingClient` or
`AppPackage/Tests/DownloadsFeatureTests`. The debt-marker gate reads zero.

## Prohibitions

| Prohibition | Status | Evidence |
|---|---|---|
| No second background-execution tier | ✓ VERIFIED | `BGProcessingTask`, `beginBackgroundTask`, `BackgroundTaskClient`, `runQueueUntilIdle` and both deleted identifiers are absent from every scanned directory and the plist; the invariant test pins it |
| No content identity in system-card strings | ✓ VERIFIED | `continuedSessionSubtitle(for:)` accepts only `ContinuedSessionProgress` integers; `testStartStringsCarryNoGalleryIdentity` and `testEveryPushedSubtitleCarriesNoGalleryIdentity` pass |
| No concurrency or lint escape hatch | ✓ VERIFIED | No `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency` or SwiftLint suppression in phase source; the suite ran with zero lint warnings |
| Scheduler named only in the client module | ✓ VERIFIED | Single `import BackgroundTasks`; invariant test enforces it, plist exemption paid for by a stricter line-count check |
| No orphaned dependency registration | ✓ VERIFIED | No `DependencyKey`, `testValue` or `DependencyValues` accessor for `BackgroundProcessingClient`; `.live` is composed in directly |
| Must not silently dequeue a gallery whose removal failed | ✓ VERIFIED | The convergence regression asserts `retainedDownload != nil` and `isQueuedWorkItem == true` on all four cases |
| Must not delete a log line to satisfy the privacy rule | ✓ VERIFIED | `testDownloadIdentityLogsStayHashMasked` asserts the four operational messages survive and at least eight hash-masked fields exist |

## Owner Decisions

Spot-checked against `15-CONTEXT.md`: D-01/D-02 (both legacy tiers deleted) verified by grep and
invariant test; D-03 (best-effort, no fallback) verified by the silent `.unavailable` path; D-04/D-05
(session API in `BackgroundProcessingClient`, coordinator owns lifecycle) verified; D-06 (one
queue-wide session) verified by `testSecondMobilizingActionDuringLiveSessionStartsNoSecondSession`;
D-07 (every queue-mobilizing tap ensures a session) verified at all call sites, with the WR-04
exception noted below; D-09 (neutral card) verified; D-11 (expiration pauses all schedulable work
through the per-gallery primitive) verified.

SC4's literal "`testValue` unimplemented" wording is superseded by the owner's option-B decision in
plan 15-16: the client carries no `DependencyKey`, so there is no `testValue` symbol. Its role is
served by the macro-generated `BackgroundProcessingClient()`, which reports an issue on every
endpoint and is tested for exactly that. This is a recorded supersession, not a shortfall.

## Current Code Review Findings — Independent Judgment

The fresh review (`15-REVIEW.md`, 0 Critical / 9 Warning / 5 Info) was read and each warning judged
against the four success criteria rather than accepted as scored.

| Finding | Independently confirmed? | Blocks a success criterion? |
|---|---|---|
| WR-01: `commitPause`'s `do`/`catch` is unreachable — both helpers declare `throws` but contain no throwing operation | Yes. `writeInitialPauseRecord` and `writeSettledPauseRecord` bodies are entirely non-throwing, and no other statement in the `do` block uses `try` | **No.** If nothing can throw, `commitPause` always reaches a settled outcome and always converges. The convergence code is dead rather than wrong; SC1 is not weakened by it. The plan 15-18 must-have it answers ("holds structurally rather than depending on which of its calls can currently throw") is satisfied in letter. Quality debt: a false `throws` contract hiding untested, untestable code |
| WR-02: pause helpers ignore their `download` parameter | Yes | No. Dead parameter |
| WR-03: the single-session guard rests on `hasPendingWork()` never suspending, a property nothing states | Yes — that chain is non-suspending today, and the property is unstated at all four places it must be maintained | No. The guard is correct on current code. This is latent fragility: one `await` added to `hasPendingWork()`, `schedulableDownloads()`, `indexedDownloads()` or `DownloadQueueStore.gids` silently reopens the double-start window Gap A just closed. The most valuable of the nine to act on |
| WR-04: the `.superseded` pause branch calls `ensureContinuedSession()` from a system-callback context, contradicting that function's own contract and accumulating unrevokable registrations | Yes — confirmed at `DownloadClient+Scheduling.swift:184`, and `git log -L` dates it to plan 15-14, not to the three closure plans | No. Identifiers are freshly minted UUIDs, so the "second registration of the same identifier terminates the app" hazard is not reachable; a background submission is dropped silently and yields `.unavailable`, so SC3's no-visible-error clause holds. Unbounded per-process accumulation of registered identifiers and retained closures on a path the code declares must never be taken |
| WR-05: `schedulingBlockedGalleryIDs` is an unreference-counted `Set`, so 15-18's early release can unblock a concurrent holder | Yes — the early `remove` is new in `bea9eef8` | No. Requires two concurrent coordinator operations on the same gid; the shape of the flaw predates the fix (the function-scoped `defer` had it too), the new branch only widens the window on the failure path |
| WR-06: the coordinator's client default is `.noop`, while its doc comment describes the unimplemented value | Yes — `DownloadClient+Manager.swift:417` defaults to `.noop`; the comment at 301-309 describes `BackgroundProcessingClient()` | No, but it touches SC4's intent. The *seam's* unimplemented value exists and is tested, which is what SC4 names. The coordinator's composition default is a separate choice that makes session behavior silently unasserted in tests that inject nothing. The doc comment should say so |
| WR-07: one unannotated `url:` interpolation survives, and the privacy invariant is a four-literal denylist | Yes, both halves | No. `Logger` redacts dynamic string interpolations by default, so the URL is not a live disclosure; it is a convention break on the very statement 15-19 edited. The denylist genuinely cannot see unannotated interpolations or other identity-bearing spellings — the gate closes today but is weakly pinned for tomorrow |
| WR-08: the spy's start guard and its write sit in two critical sections, and `refusesNextStart` is consumed by the session guard | Yes | No. The two sections are separated only by `UUID()` and `AsyncStream.makeStream` with no suspension between them, so they are effectively atomic under the tests. More importantly, the Gap A regression asserts `startCount == 1`, which is decided by the *coordinator's* guard, not the spy's — that test does not inherit the weakness |
| WR-09: `hasLiveContinuedSession` and `continuedSessionID` encode one fact | Yes | No. Redundant state, correct today |

None of the nine falsifies a success criterion. Collectively they are worth a cleanup pass, with
WR-03 and WR-07 the two whose value is preventive rather than cosmetic: both concern guards that are
correct now and weakly pinned against a future edit.

## Human Verification Required

### 1. Continuation past the old grace window

**Test:** On a physical iOS 26 device, queue at least three galleries totaling at least 300 pages,
start in the foreground, background the app for more than 60 seconds without returning, then
foreground and compare persisted page counts against the queue.

**Expected:** Pages keep landing while backgrounded, well past the window the deleted
`beginBackgroundTask` assertion used to bound. No page lost, none downloaded twice.

**Why human:** The simulator neither grants continued-processing tasks nor suspends the process the
way a device does. Source presence proves the request is submitted, not that the system honors it.

### 2. Card fidelity and cancel parity

**Test:** Observe the system progress card during that run. Then cancel from the card, foreground,
and compare queue and manifest state against the state left by pausing each gallery by hand.

**Expected:** Exactly one neutral card, appearing immediately with real counts and advancing
monotonically; card-cancel leaves the same state as the in-app per-gallery pause.

**Why human:** The card is rendered by system UI outside the app and its cancel affordance fires a
system-owned expiration handler. Neither exists in the simulator.

### 3. Best-effort refusal, expiration and force-quit durability

**Test:** Exercise a refused or indefinitely queued submission and a system-initiated expiration.
Force-quit mid-session and relaunch. Foreground again after each.

**Expected:** No crash, no visible background-processing error anywhere, no duplicated or lost pages,
and persisted work resuming on the next foreground.

**Why human:** Real scheduler decisions and process death are not reproducible in unit tests.

### 4. Collected-diagnostics privacy confirmation

**Test:** Take a sysdiagnose or collected log archive after a real download session and search it for
gallery titles and unmasked gallery identifiers.

**Expected:** Neither appears from the `DownloadClient` module.

**Why human:** The invariant suite proves the source spellings; only a real archive proves what the
system persists.

## Summary

The three recorded gaps are closed in the code, not merely in the summaries. The in-flight start no
longer surrenders ownership to a concurrent drain; both removal entry points converge on every
ownership-clearing exit; and no gallery title or unmasked identifier reaches a public unified-log
field. Each closure carries a regression that runs and passes, and each was re-derived here from
source before any summary was read. No regression was introduced.

What remains is not a gap. SC1, SC2 and SC3 each assert a runtime transition that only a physical
iOS 26 device can produce — the system continuing a backgrounded process, rendering and cancelling
its own progress card, and deciding whether to grant, queue or expire a submission. Those are routed
to the four human checks above. SC4 is verified outright.

The nine open warnings are quality debt, not blockers. WR-03 and WR-07 deserve attention before the
next edit to this area, because both describe guards that are correct today and weakly pinned
against tomorrow.

---

_Verified: 2026-07-29T03:51:37Z_

_Verifier: Claude (gsd-verifier)_
