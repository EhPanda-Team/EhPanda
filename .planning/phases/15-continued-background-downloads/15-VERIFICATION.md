---
phase: 15-continued-background-downloads
verified: 2026-07-29T00:54:46Z
status: gaps_found
score: 1/4 must-haves verified
behavior_unverified: 1
overrides_applied: 0
next_action: "Gaps found. Plan the fixes, then re-run execute-phase before shipping."
next_command: "/gsd:plan-phase 15 --gaps"
re_verification:
  previous_status: gaps_found
  previous_score: 1/4
  gaps_closed:
    - "Initial system-task progress is seeded from the real queue snapshot rather than 0 / 0."
    - "Progress updates carry a client session id and the store rejects updates for another session."
    - "The vanished-record delete branch now notifies observers and reaches scheduling/session convergence."
    - "Expiration-owned pauses use queue-intent generations and deterministic suspension-window regressions."
    - "The owner selected option B and the unused dependency key/accessor were removed."
  gaps_remaining:
    - "A drain while client start is in flight can clear coordinator ownership; a second tap is then refused by the live single-session store and the final pending work has no continued-processing session."
    - "A failed active-gallery folder removal clears the active owner and returns without notifying or rescheduling, stranding the queue and its session."
    - "Downloaded gallery titles and identifiers are emitted as public unified-log fields."
  regressions: []
gaps:
  - truth: "SC1/SC2 — every foreground user action that leaves schedulable work retains exactly one live continued-processing session and its system progress card."
    status: failed
    reason: >-
      `ensureContinuedSession()` suspends in client start. A concurrent drain can run
      `reconcileContinuedSession()`, clear the coordinator session while its client id is still nil,
      and let a second tap attempt another start. The live store refuses that overlapping start,
      the second coordinator session rolls back, and the first start later finishes itself after
      losing ownership. Pending work is left with no background coverage or progress card. The
      held-start regression passes only because its spy accepts overlapping starts, unlike the live
      store.
    artifacts:
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
        issue: "reconcileContinuedSession clears a session whose client start is still in flight instead of deferring reconciliation."
      - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift"
        issue: "BackgroundProcessingClientSpy replaces the held session on every accepted start rather than enforcing the live store's single-session guard."
      - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift"
        issue: "The held-start test therefore proves behavior production cannot exhibit."
    missing:
      - "Keep coordinator ownership while client start is in flight and defer reconciliation until the returned client id is installed."
      - "Make the spy refuse a start while a session is held, matching ContinuedProcessingSession."
      - "Add a deterministic drain/start/tap regression under the corrected spy contract."
  - truth: "SC1 — queue mutations preserve scheduling and continued-session convergence even when deleting the active gallery fails."
    status: failed
    reason: >-
      `delete(gid:)` cancels the active task and clears both active ownership fields before removing
      gallery folders. Both folder-removal catch branches reload and return without notifying or
      calling `scheduleNextIfNeeded()`. The cancelled task's deferred cleanup no longer owns the
      cleared active id, so it cannot recover. The failed gallery and queued successors can remain
      stranded and the continued-processing session is not reconciled.
    artifacts:
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift"
        issue: "Both folder-removal failure branches return before observer and scheduling convergence."
      - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadDeleteConvergenceTests.swift"
        issue: "Coverage exercises only successfully vanished records; no test injects folder-removal failure after active ownership is cleared."
    missing:
      - "Release the scheduling block and run observer/scheduling convergence on both removal-error branches."
      - "Add a failure-injected active-item plus queued-successor regression."
  - truth: "Critical privacy gate — downloaded gallery identity is not disclosed through public system logs."
    status: failed
    reason: >-
      Download completion and enqueue logs publish gallery titles and GIDs, and failure, pause,
      resume, delete, and expiration-interleave logs publish GIDs with `privacy: .public`.
      Titles are direct content identity and a GID resolves to a gallery. This is the current code
      review's third Critical finding. Most affected log lines predate Phase 15, but Phase 15
      modified these files and added another public GID log, so the shipping review gate remains
      open even though the progress-card strings themselves are neutral.
    artifacts:
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift"
        issue: "Completion and failure logs expose title/GID as public fields."
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift"
        issue: "Enqueue and delete logs expose title/GID as public fields."
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift"
        issue: "Pause, resume, and expiration-interleave logs expose GID as a public field."
    missing:
      - "Remove content titles from operational logs and mark identifiers private, preferably hash-masked."
      - "Audit error descriptions that may contain gallery-named paths before logging them publicly."
behavior_unverified_items:
  - truth: "SC3 — real system refusal, indefinite queuing, expiration, process suspension, and next-foreground resume preserve work with no visible error."
    test: "On a physical iOS 26 device, exercise refusal/queued/expiration paths, background beyond the old grace window, foreground again, and compare persisted page and queue state."
    expected: "The app has no fallback tier or visible error; work resumes without lost or duplicated pages."
    why_human: "Simulator tests cover the coordinator policies, but the real scheduler grant/queue/expiration and process-suspension transitions are device-owned and cannot be proven by source presence."
---

# Phase 15: Continued Background Downloads Verification Report

**Phase Goal:** Adopt `BGContinuedProcessingTask` (iOS 26) so a gallery download the user just
started keeps running when the app is backgrounded, surfaced by the system progress UI, rather than
being cut short by the old grace period.

**Verified:** 2026-07-29T00:54:46Z

**Status:** `gaps_found`

**Re-verification:** Yes — after plans 15-12 through 15-16

**Canonical next action:** Gaps found. Plan the fixes, then re-run execute-phase before shipping.

**Canonical next command:** `/gsd:plan-phase 15 --gaps`

The earlier 0 / 0 seed, session-unidentified progress, vanished-record delete, expiration
reentrancy, and unused dependency-registration gaps are closed. The current code review's three
Critical findings and three Warnings were checked against source and tests. All six are
substantiated.

## Goal Achievement

### Observable Truths

| # | Roadmap truth | Status | Evidence |
|---|---|---|---|
| SC1 | A foreground-started download continues to completion after backgrounding beyond the old grace period | ✗ FAILED | A drain during the suspended client start can leave pending work without a session (`DownloadClient+ContinuedSession.swift:79-118,213-227`). Failed active deletion can also strand scheduling (`DownloadClient+PublicAPI.swift:182-215`) |
| SC2 | System UI shows real progress and card cancel matches in-app cancel | ✗ FAILED | Seeded/session-identified progress and expiration parity are implemented, but the start/drain race can leave the newest tap with no card at all. The green held-start test uses a spy lifecycle the live store rejects |
| SC3 | Best-effort refusal/queue/expiration has no fallback, loss, duplication, or visible error | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Legacy tiers are absent and deterministic unavailable/expiration tests exist. Real scheduler queuing, process suspension, and foreground resume remain device-only backstops |
| SC4 | A testable session seam owns scheduler access and exposes start/update/finish plus self-finishing events with an unimplemented value | ✓ VERIFIED | Three-endpoint identified seam; `endSession` finishes its stream; exact refusal/self-finish test passed; scheduler names are confined to `ContinuedTaskScheduling.swift`; direct injection remains after option B |

**Score:** 1/4 roadmap truths verified (1 present, behavior-unverified)

Phase 16 is Dynamic Type work. None of these gaps is specifically covered by a later milestone
phase, so no item is deferred.

## Re-verification of Previous Gaps

| Previous concern | Current evidence | Status |
|---|---|---|
| Adopted task begins at 0 / 0 | Start records the snapshot at `ContinuedProcessingSession.swift:95-98`; adoption writes it at `:218-220` | ✓ CLOSED |
| Stale progress can repaint a successor | `updateProgress` takes a session id and rejects foreign ids at `ContinuedProcessingSession.swift:164-178` | ✓ CLOSED |
| Vanished-record delete bypasses convergence | The not-found branch now notifies and schedules at `DownloadClient+PublicAPI.swift:197-205` | ✓ CLOSED |
| Expiration pause overwrites a newer retry | Generation checks bracket the real suspensions at `DownloadClient+Scheduling.swift:192-222`; the exact gated interleave passed | ✓ CLOSED |
| Unread dependency registration remains | `BackgroundProcessingClientKey` and its accessor are absent; `.live` is injected directly | ✓ CLOSED |

## Plan Must-Have Coverage

Every PLAN frontmatter truth, artifact, key link, prohibition, and SC label was inventoried. The
table groups related checks by plan; backstop truths are carried into the device checks below.

| Plan | Automated must-haves | Result |
|---|---|---|
| 15-01 | Plist wildcard, retained processing mode, old AppFeature wiring and package edge removed | ✓ VERIFIED; built plist resolves `app.ehpanda.continued.*` |
| 15-02 | Assertion state, old drain loop, and fallback tier removed; pending-work helper retained | ✓ VERIFIED |
| 15-03 | Main-actor store, three-endpoint/self-finishing seam, scheduler confinement, lint config | ✓ VERIFIED; the old `BackgroundProcessingClientKey` artifact expectation was intentionally superseded by 15-16 option B |
| 15-04 | Neutral six-locale card strings, numeric substitutions, direct client injection, loud unimplemented client | ✓ VERIFIED in code/tests; system rendering remains device-only |
| 15-05 | One session per queue-mobilizing action, no duplicate session, ordered lifecycle | ✗ FAILED by CR-01's in-flight start/drain overlap |
| 15-06 | Real aggregate progress, pause parity, unavailable silence, convergence | ⚠️ PARTIAL; progress/expiration behaviors are present, but in-flight start convergence is defective and device behavior remains unverified |
| 15-07 | Permanent topology checks and roadmap contract | ✓ VERIFIED automated portion; three physical-device backstops remain |
| 15-08 | Pending-request cancellation, stale-launch rejection, reusable later session | ✓ VERIFIED |
| 15-09 | Coordinator session stamping, stale teardown rejection, cancel convergence | ✓ VERIFIED |
| 15-10 | Identified client completion/refusal/progress threading | ⚠️ PARTIAL; identities work, but a nil client id during start is treated as terminal rather than deferred reconciliation |
| 15-11 | Coordinator identity regressions and deterministic gates | ✗ COVERAGE GAP; the held-start spy accepts overlapping sessions and its parked task lacks failure-safe release |
| 15-12 | Real initial seed, session-identified progress, monotonic floor | ✓ VERIFIED |
| 15-13 | Vanished-record convergence and one schedulable-work authority | ✓ VERIFIED as written; it does not cover the distinct folder-removal failure found by CR-02 |
| 15-14 | Expiration-owned generation guards and leak-safe blocking fixture | ✓ VERIFIED, including deterministic interleave behavior |
| 15-15 | Post-guard expiration/retry interleaves with no sleeps or polling | ✓ VERIFIED; exact named test passed |
| 15-16 | Owner option B, direct composition, preserved loud unimplemented client | ⚠️ PARTIAL QUALITY; implementation matches the decision, but source/test comments still describe the deleted dependency API |

## Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `App/Info.plist` | One bundle-scoped continued wildcard; processing mode retained | ✓ VERIFIED | Source has one wildcard; built product resolves it to `app.ehpanda.continued.*` |
| `BackgroundProcessingClient.swift` | Identified start/update/finish seam | ✓ VERIFIED | Substantive and wired directly into `DownloadClient.live` |
| `ContinuedProcessingSession.swift` | Main-actor task/session store | ✓ VERIFIED | Real seed, session checks, request cancel, stream finish |
| `ContinuedTaskScheduling.swift` | Sole scheduler adapter | ✓ VERIFIED | Register/submit/cancel operations; only Swift source importing `BackgroundTasks` |
| `DownloadClient+ContinuedSession.swift` | Coordinator session lifecycle | ✗ DEFECTIVE | In-flight start can be cleared before the client id arrives |
| `DownloadClient+PublicAPI.swift` | User actions converge scheduling/session state | ✗ DEFECTIVE | Folder-removal catch branches bypass convergence |
| `DownloadClient+PendingWork.swift` | Single schedulable-work authority | ✓ VERIFIED | Progress, expiration, and pending checks use it |
| `DownloadContinuedSessionIdentityTests.swift` | Reentrant lifecycle regressions | ⚠️ MISLEADING | Held-start case passes against a spy that violates the live single-session contract |
| `DownloadDeleteConvergenceTests.swift` | Delete-path regressions | ⚠️ INCOMPLETE | Vanished-record cases pass; removal-failure path is absent |
| `BackgroundExecutionInvariantTests.swift` | Permanent topology and prohibition guard | ✓ VERIFIED | Source scope includes app/package/tests/extension and the plist |
| `BackgroundProcessingClient/.swiftlint.yml` | New-module lint inheritance | ✓ VERIFIED | `parent_config: ../../../.swiftlint.yml` |

The artifact query reported one historical mismatch: plan 15-03 expected
`BackgroundProcessingClientKey`, while the owner explicitly chose its removal in plan 15-16.
That is a superseded artifact detail, not missing SC4 substance.

## Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| Plist wildcard | Runtime identifiers | Bundle prefix plus `.continued.<UUID>` | ✓ WIRED | Built plist and source prefix agree |
| Live client closures | Session store | Main-actor `start`/`updateProgress`/`finish` calls | ✓ WIRED | All three delegate to `ContinuedProcessingSession.shared` |
| Session store | System scheduler | `ContinuedTaskScheduling.live` | ✓ WIRED | System types remain confined |
| User start/resume/retry/update | `ensureContinuedSession()` | Success-path calls | ✓ WIRED | Four foreground tap paths call ensure |
| Client start in flight | Queue-drain reconcile | Deferred reconciliation | ✗ NOT WIRED | Nil client id causes ownership to be cleared |
| Held-start test spy | Live store lifecycle | Single-session refusal | ✗ NOT WIRED | Spy overwrites; live store returns nil |
| Delete failure | Queue/session convergence | Notify plus `scheduleNextIfNeeded()` | ✗ NOT WIRED | Both catch branches return first |
| Progress snapshot | Adopted task/card | Seed plus identified updates | ✓ FLOWING | Counts are real, monotonic, and session-scoped |
| Expiration | Per-gallery pause | Session and queue-intent ownership | ✓ WIRED | Exact suspension-window regression passed |

The generated key-link checker reported invalid escaped regexes for several older plan patterns.
Their links were inspected manually: per-gallery pause, injected-store construction, persistence
progress push, and foreign-expiration calls all exist at the declared call sites.

## Data-Flow Trace

| Data | Source | Sink | Status |
|---|---|---|---|
| Initial completed/total counts | One schedulable queue snapshot | Start storage, then adopted task `Progress` | ✓ FLOWING |
| Later card progress | Throttled page flush and scheduling reconcile | Session-identified `updateProgress` | ✓ FLOWING |
| Client session ownership | Client start return | Coordinator liveness/task consumer | ✗ DISCONNECTED during the start suspension |
| Delete error recovery | Reloaded active gallery and retained queue entry | Observer, scheduler, session reconcile | ✗ DISCONNECTED |
| Card text | Localized count-only builder | System title/subtitle | ✓ FLOWING without gallery identity |
| Operational log identity | Gallery title/GID | Unified logging with `.public` privacy | ✗ DISCLOSING |

## Behavioral Spot-Checks

The first targeted build attempt was sandbox-blocked; the second used the installed iPhone Air
simulator. Test enumeration was required because Swift Testing identifiers include trailing
parentheses. The final exact run executed four tests, not four suites or zero tests.

| Behavior | Result | Status |
|---|---|---|
| Live store refuses an overlapping start and later starts again | Exact `testStartWhileASessionIsHeldIsRefusedAndALaterStartSucceeds()` passed | ✓ PASS |
| Existing held-start coordinator regression | Exact `testBailOutFinishNeverLandsOnTheMostRecentStartsSession()` passed | ⚠️ MISLEADING PASS — spy contract differs from live store |
| Retry survives a cancellation-held expiration pause | Exact `testAResumeInsideAStaleExpirationPauseSurvivesAndMobilizesTheQueue()` passed | ✓ PASS |
| Vanished last record completes its session | Exact `testDeletingAVanishedLastRecordCompletesTheSession()` passed | ✓ PASS |
| Actual client grant/card/device cancel | Requires physical iOS 26 hardware | ? DEVICE BACKSTOP |

The exact run finished with `TEST EXECUTE SUCCEEDED` and 4 tests passed. A green test does not
override the static execution trace when the test double permits a state production refuses.

## Probe Execution

No phase-declared or conventional `probe-*.sh` scripts exist.

## Requirements Coverage

There are no mapped requirement IDs for Phase 15. PLAN frontmatter uses only SC1-SC4 and
collectively covers all four roadmap criteria; `.planning/REQUIREMENTS.md` has no Phase 15 orphan.

| Contract | Source plans | Status |
|---|---|---|
| SC1 | 15-05 through 15-13 as applicable | ✗ BLOCKED by CR-01 and CR-02 |
| SC2 | 15-04, 15-06, 15-07, 15-12 through 15-15 | ✗ BLOCKED by CR-01; no card remains for the newest tap |
| SC3 | 15-01, 15-02, 15-06, 15-07, 15-14, 15-15 | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED on physical-device scheduler/process behavior |
| SC4 | 15-01, 15-03, 15-04, 15-07, 15-16 | ✓ SATISFIED |

## Current Code Review Findings

| Finding | Independent verification | Goal impact |
|---|---|---|
| CR-01: drain during client start loses newest tap's coverage | Confirmed by actor execution trace and mismatch between `ContinuedProcessingSession` and the spy | 🛑 BLOCKER — SC1/SC2 |
| CR-02: failed active deletion stalls scheduling | Confirmed catch branches return after ownership clear; deferred task cleanup fails its ownership guard | 🛑 BLOCKER — SC1/queue lifecycle |
| CR-03: public logs disclose gallery identity | Confirmed title/GID `.public` interpolations in execution, public API, and scheduling | 🛑 BLOCKER — privacy shipping gate |
| WR-01: spy violates the live single-session contract | Confirmed: spy overwrites `currentSessionID`; store returns nil | ⚠️ WARNING — hides CR-01 |
| WR-02: comments describe deleted dependency API | Confirmed at `DownloadClient+Manager.swift:301-309` and `DownloadContinuedSessionTests.swift:10-12` | ⚠️ WARNING — misleading architecture documentation |
| WR-03: held-start test can leak parked task | Confirmed: no `defer { gate.release() }` after `armStartGate()` | ⚠️ WARNING — failure can hang/leak test work |

No `TBD`, `FIXME`, or `XXX` marker exists in the reviewed phase files. The security-specialist
domains (Keychain, biometrics, CryptoKit, trust evaluation) are not touched by this phase; the
relevant security issue here is the independently confirmed unified-log privacy disclosure.

## Prohibitions

| Prohibition | Status | Evidence |
|---|---|---|
| No second background-execution tier | ✓ VERIFIED | Deleted tokens absent; invariant test encodes the topology |
| No content identity in system-card strings | ✓ VERIFIED | Builder accepts only three numeric values across six locales |
| No concurrency/lint escape hatch | ✓ VERIFIED | No phase-source unchecked Sendable, unsafe nonisolated, preconcurrency, or suppression |
| Scheduler named only in the client module | ✓ VERIFIED | One Swift source file owns all scheduler calls |
| No orphaned dependency registration | ✓ VERIFIED | Owner chose option B; key and accessor are absent |

CR-03 is broader than the card-string prohibition: the card itself is neutral, but operational
unified logs still disclose the same sensitive identity.

## Human Verification Required After Gap Closure

### 1. Continuation and honest progress

**Test:** On a physical iOS 26 device, queue at least three galleries totaling at least 300 pages,
start in foreground, background for more than 60 seconds, and observe the system card.

**Expected:** Work continues beyond the old grace period; one neutral card appears immediately with
real counts and its bar/counts continue advancing.

**Why human:** Simulator does not grant continued-processing tasks or render the system card.

### 2. Cancel parity and foreground race

**Test:** Cancel from the live system card, then foreground and immediately resume/retry a gallery.

**Expected:** Card cancel leaves the same state as in-app pause, and no settling expiration
overwrites the newer user action.

**Why human:** The card cancel/resource-expiration callback is system-owned and device-only.

### 3. Force-quit durability and best-effort resume

**Test:** Force-quit mid-session, relaunch, and also observe a refused or queued submission.

**Expected:** No crash, no duplicated/lost pages, no visible background-processing error, and
persisted work resumes on foreground.

**Why human:** Process death and real scheduler decisions are not reproducible in unit tests.

## Gaps Summary

The previous gap-closure rounds fixed their named defects, but the phase goal is still not
achieved. The coordinator must retain or defer reconciliation of an in-flight start, deletion
failure must converge scheduling after active ownership is cleared, and public gallery identity
must be removed from unified logs. The spy and held-start regression must then be made faithful to
the live store. Only after those fixes should the three physical-device checks decide the remaining
SC3 backstop and the device-only halves of SC1/SC2.

---

_Verified: 2026-07-29T00:54:46Z_

_Verifier: the agent (gsd-verifier)_
