---
phase: 15-continued-background-downloads
verified: 2026-07-28T11:08:29Z
status: gaps_found
score: 1/4 must-haves verified
behavior_unverified: 0
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/4
  gaps_closed:
    - "Client completion is now session-identified, so a stale completion cannot finish a successor session."
    - "Store re-entry refusal is observable and coordinator bookkeeping rolls back for a later retry."
    - "Expiration checks coordinator identity before beginning each per-gallery pause."
  gaps_remaining:
    - "SC1 remains blocked by unseeded initial progress, a reentrant expiration pause, and a delete path that bypasses queue/session convergence."
    - "SC2 remains blocked because progress updates are not client-session identified and cancel is not atomic with respect to a new user action."
  regressions: []
gaps:
  - truth: "SC1 — A foreground-started download continues to completion after backgrounding beyond the old grace period."
    status: failed
    reason: >-
      A granted system task is adopted with 0/0 progress until a later flush or queue mutation,
      making a legitimately running download look stalled. In addition, deleting an active gallery
      whose indexed record has vanished clears the active owner and returns without scheduling or
      reconciling, so remaining queued work and the system card can be stranded.
    artifacts:
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
        issue: "ensureContinuedSession computes real counts but does not push them after start succeeds."
      - path: "AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift"
        issue: "start resets saved counts to zero and adopt writes those zero counts into the task's Progress."
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift"
        issue: "delete(gid:)'s notFound branch returns without notifyObservers() or scheduleNextIfNeeded()."
    missing:
      - "Seed the identified session with the start snapshot before a granted task can report 0/0."
      - "Route the vanished-record delete branch through observer notification and queue/session convergence."
      - "Add regression coverage for both initial task seeding and the vanished-active-record delete path."
  - truth: "SC2 — The system progress UI reflects real progress and cancel stops the queue consistently with an in-app cancel."
    status: failed
    reason: >-
      updateProgress has no client session identity, so an old actor continuation can hop to the
      main-actor store after a successor starts and overwrite the successor card. The initial card
      is also seeded with false 0/0 counts. Finally, expiration checks identity only before calling
      the multi-suspension pause primitive; a new resume/retry can interleave inside that pause and
      have its fresh queue intent cleared by the stale expiration.
    artifacts:
      - path: "AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift"
        issue: "updateProgress accepts counts and subtitle but no BackgroundProcessingSession id."
      - path: "AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift"
        issue: "updateProgress applies every call to whichever task the singleton currently holds."
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
        issue: "push re-checks only coordinator identity before suspending into a session-blind client update; pauseAllSchedulable cannot invalidate a pause already in progress."
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift"
        issue: "pause commits queue removal on both sides of real suspension points without a gallery mutation generation."
    missing:
      - "Add the client session id to updateProgress and reject foreign updates in ContinuedProcessingSession."
      - "Make expiration-owned pause commits conditional on a gallery/session generation, or perform an atomic coordinator-owned bulk transition."
      - "Add deterministic tests that hold an S1 progress update and an expiration pause across suspension while S2 or a user resume starts."
  - truth: "SC3 — Best-effort refusal, queuing, and expiration preserve work and resume semantics without a fallback tier or visible error."
    status: failed
    reason: >-
      The no-fallback and silent-refusal topology is present, but expiration resume semantics are
      not preserved under actor reentrancy. After pauseAllSchedulable's identity check, pause(gid:)
      suspends during persisted queue mutations; a foreground resume/retry can succeed in that
      window and then be erased by the stale expiration's settled write. The existing foreign-id
      test returns before entering this window and therefore does not prove the required behavior.
    artifacts:
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
        issue: "The per-iteration identity guard does not protect post-suspension writes inside pause(gid:)."
      - path: "AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionIdentityTests.swift"
        issue: "The foreign-expiration case supplies a foreign UUID while the successor is already live, so the guard returns before pause or any suspension."
    missing:
      - "Protect expiration-owned queue writes with an epoch/generation that a later user action advances."
      - "Replace the foreign-id early-return test with a gated interleave that enters pause, performs a resume/retry, then releases the stale pause."
unverified_prohibitions: 1
prohibition_flags:
  - statement: "Must NOT leave orphaned or unreferenced background-execution machinery in the tree."
    disposition: "unverified-prohibition — human review recommended"
    evidence: >-
      BackgroundProcessingClientKey and DependencyValues.backgroundProcessingClient have no
      source consumer outside their declarations, while the live client is injected directly.
      Later plans explicitly preserved this owner-pending judgment.
---

# Phase 15: Continued Background Downloads Verification Report

**Phase Goal:** Adopt `BGContinuedProcessingTask` (iOS 26) so a gallery download the user just started keeps running when the app is backgrounded, surfaced by the system-provided progress UI, instead of being cut short by the old short grace period.
**Verified:** 2026-07-28T11:08:29Z
**Status:** gaps_found
**Re-verification:** Yes — after the 15-10/15-11 session-identity closure round

The mandatory clean build, 296-test `DownloadsFeatureTests` run, and complete `FeatureTests`
plan are green. Those gates prove compilation and existing assertions, not the phase goal.
All four Critical and three Warning findings in `15-REVIEW.md` were checked independently
against the current source. Every one is substantiated.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC1 | A foreground-started download continues beyond the old grace period and completes in background | ✗ FAILED | `ensureContinuedSession` passes real counts only in the subtitle (`DownloadClient+ContinuedSession.swift:86-90`), while store start resets counts to zero and adoption writes 0/0 (`ContinuedProcessingSession.swift:90-92, 204-205`). The vanished-record delete branch returns without convergence (`DownloadClient+PublicAPI.swift:196-200`) |
| SC2 | System UI reflects real progress and cancel matches in-app cancel | ✗ FAILED | `updateProgress` has no session id (`BackgroundProcessingClient.swift:38-42`) and the singleton applies it to its current task (`ContinuedProcessingSession.swift:156-164`). Expiration's guard does not cover the awaited pause's later commits (`ContinuedSession.swift:188-193`; `Scheduling.swift:160-170`) |
| SC3 | No fallback; refusal/queue/expiration preserve work and resume semantics silently | ✗ FAILED | The legacy tiers are deleted and unavailable is silent, but a stale expiration pause can erase a user resume/retry that interleaves after the identity guard. The test at `DownloadContinuedSessionIdentityTests.swift:109-137` exercises only an early foreign-id return |
| SC4 | Testable session seam owns scheduler access, exposes start/update/complete plus self-finishing events, and has unimplemented testValue | ✓ VERIFIED | The client exposes the three verbs and optional identified event stream; `ContinuedProcessingSession.endSession` finishes the stream; `BackgroundProcessingClient()` is exercised as unimplemented for all endpoints; `BGTaskScheduler` and `import BackgroundTasks` occur in one source file, `ContinuedTaskScheduling.swift` |

**Score:** 1/4 truths verified

No item is deferred to Phase 16; that phase concerns Dynamic Type and does not cover these
background-execution defects.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `App/Info.plist` | One bundle-scoped continued-processing wildcard | ✓ VERIFIED | Exactly one `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`; `processing` background mode retained |
| `BackgroundProcessingClient.swift` | Identified, testable session API | ⚠️ PARTIAL | Start and finish are identified; update-progress is not, leaving stale writes able to target a successor |
| `ContinuedProcessingSession.swift` | Main-actor session/task store | ⚠️ DEFECTIVE | Substantive and scheduler-wired, but adopts with 0/0 and accepts progress for whichever session is current |
| `ContinuedTaskScheduling.swift` | Sole scheduler-access seam | ✓ VERIFIED | Only Swift file naming the scheduler or importing `BackgroundTasks`; substantive register/submit/cancel operations |
| `DownloadClient+ContinuedSession.swift` | Coordinator lifecycle, progress, completion, expiration | ⚠️ DEFECTIVE | Session-targeted completion is fixed; progress loses client identity and expiration pause is non-atomic |
| `DownloadClient+PublicAPI.swift` | Queue mutations converge on scheduling/session reconcile | ✗ INCOMPLETE | `delete` not-found branch bypasses notification and `scheduleNextIfNeeded()` |
| `DownloadClient+PendingWork.swift` | Canonical schedulable-work predicate | ⚠️ WARNING | Substantive and used, but duplicates filtering also present in `schedulableDownloads()` |
| `DownloadContinuedSessionTests.swift` | Lifecycle/progress/expiration coverage | ⚠️ INCOMPLETE | Existing cases pass, but one explicitly expects no initial update after start |
| `DownloadContinuedSessionIdentityTests.swift` | Reentrant identity regressions | ⚠️ INCOMPLETE | Completion/refusal cases are substantive; foreign expiration never enters the suspension window it claims to cover |
| `BackgroundExecutionInvariantTests.swift` | Permanent topology prohibition | ✓ VERIFIED | Scans source/plist scope, bans both legacy tiers and concurrency escapes, and confines scheduler naming |
| `BackgroundProcessingClient/.swiftlint.yml` | New-module lint inheritance | ✓ VERIFIED | `parent_config: ../../../.swiftlint.yml` |

All artifacts declared in the 11 PLAN frontmatters exist and pass the basic artifact query.
Several generated key-link checks reported an invalid escaped regex; their underlying links
were inspected manually rather than treated as failures or passes.

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| Queue-mobilizing user actions | `ensureContinuedSession()` | Four foreground tap paths | ✓ WIRED | Enqueue/resume/retry/update success paths call ensure after mobilizing work |
| Client live closures | `ContinuedProcessingSession.shared` | Main-actor store methods | ✓ WIRED | Start, update and finish all delegate to the store |
| Store | System scheduler | `ContinuedTaskScheduling.live` | ✓ WIRED | Register/submit/cancel confined to the client module |
| Start snapshot | Adopted task progress | Initial progress seed | ✗ NOT WIRED | Snapshot appears in subtitle only; task gets 0/0 |
| Coordinator progress | Current client session | `updateProgress` | ✗ NOT WIRED (identity) | The coordinator id guard is lost at the client seam |
| Expiration event | Pause-all behavior | `pauseAllSchedulable` → `pause(gid:)` | ⚠️ PARTIAL | Correct primitive, but identity cannot invalidate a pause already past the guard |
| Vanished active delete | Queue/session convergence | `scheduleNextIfNeeded()` | ✗ NOT WIRED | Not-found branch returns before the convergence call |
| Queue drain | Client completion | Identified `finish(sessionID:success:)` | ✓ WIRED | Both completion paths now carry the client id and store rejects foreign ids |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| Card subtitle at start | completed/total/gallery count | `schedulableProgress()` from indexed queued downloads | Yes | ✓ FLOWING |
| Adopted `Progress` at start | `lastCompletedUnitCount`, `lastTotalUnitCount` | Reset in `start`; no initial coordinator push | No — 0/0 | ✗ HOLLOW INITIAL STATE |
| Later card progress | clamped queue-wide snapshot | Page-flush and scheduling reconcile | Yes, but unscoped to client session | ⚠️ FLOWING TO WRONG POSSIBLE OWNER |
| Cancel/expiration queue mutation | captured schedulable gids | Per-gallery `pause(gid:)` | Real persisted queue state | ⚠️ REENTRANT WRITE HAZARD |
| Completion | `continuedClientSessionID` | Identified handle returned by start | Yes | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Evidence | Result | Status |
|----------|----------|--------|--------|
| Legacy discretionary and UIKit assertion tiers are absent | Tree-wide search for all deleted spellings returned no matches | No fallback tier remains | ✓ PASS |
| Scheduler access is confined | Only `ContinuedTaskScheduling.swift` names `BGTaskScheduler` or imports `BackgroundTasks` | One client-module source file | ✓ PASS |
| Permitted identifier is correctly shaped | `PlistBuddy` shows one `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*` entry | One entry; `processing` mode retained | ✓ PASS |
| Existing automated gates | Orchestrator-supplied clean build, 296 Downloads tests, complete FeatureTests plan | All green | ✓ PASS, but not evidence against the four uncovered Critical paths |
| Initial adopted progress | Static execution trace from start through adopt | Real subtitle, `Progress(total: 0, completed: 0)` | ✗ FAIL |
| Foreign expiration regression | Static execution trace of test and production guard | Test exits before first pause | ✗ FAIL AS COVERAGE |
| System grant/card/device cancel | Requires a physical iOS 26 device | Not run here | ? DEVICE CHECK AFTER CODE FIXES |

### Probe Execution

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| — | — | No phase-declared or conventional probe scripts exist | n/a |

### Requirements Coverage

The PLAN `requirements:` fields use only `SC1`–`SC4`, and collectively cover all four
ROADMAP criteria. `.planning/REQUIREMENTS.md` maps no requirement ID to Phase 15, exactly as
the ROADMAP declares; there are no orphaned requirement IDs.

| Requirement | Source Plans | Status | Evidence |
|-------------|--------------|--------|----------|
| SC1 | 15-05, 15-06, 15-07, 15-08, 15-09, 15-10, 15-11 | ✗ BLOCKED | CR-02 and CR-04 directly undermine continued execution; CR-03 can erase a new user action |
| SC2 | 15-04, 15-06, 15-07 | ✗ BLOCKED | CR-01, CR-02 and CR-03 contradict real, correctly-owned progress and cancel parity |
| SC3 | 15-01, 15-02, 15-06, 15-07 | ✗ BLOCKED | No fallback is verified, but the expiration reentrancy path does not preserve resume intent |
| SC4 | 15-01, 15-03, 15-04, 15-07 | ✓ SATISFIED | Three-endpoint seam, self-finishing event stream, unimplemented test value, one scheduler-owning module |

### Code Review Findings Independently Verified

| Finding | Classification | Independent evidence | Goal impact |
|---------|----------------|----------------------|-------------|
| CR-01 | 🛑 BLOCKER | `updateProgress` has no session id at either seam or store; actor hops can apply an S1 update to S2 | SC2 |
| CR-02 | 🛑 BLOCKER | Start resets saved counts and ensure sends no update; adopt writes 0/0 | SC1, SC2 |
| CR-03 | 🛑 BLOCKER | Pause has multiple awaits and post-await queue clears; expiration guards only before the call | SC2, SC3 |
| CR-04 | 🛑 BLOCKER | Vanished-record delete returns after clearing active/queue state without scheduling/reconcile | SC1 |
| WR-01 | ⚠️ WARNING | Foreign-id expiration test returns at the first guard and never suspends in pause | Coverage gap for CR-03 |
| WR-02 | ⚠️ WARNING | Blocking fixture loops until cancellation; tests defer only directory deletion and cancel at the end of the happy path | Early thrown exit can leak a retained task |
| WR-03 | ⚠️ WARNING | `hasPendingWork` and `schedulableDownloads` independently reproduce queue/index/filter selection | Future predicate drift can desynchronize session lifetime and card counts |

No `TBD`, `FIXME`, or `XXX` debt marker was found in the reviewed phase files.

### Prohibition Review

| Prohibition | Status | Evidence |
|-------------|--------|----------|
| No second background-execution tier | ✓ VERIFIED | Legacy token scan is empty and invariant test encodes it |
| No content-identifying card text | ✓ VERIFIED | Title is neutral; subtitle accepts only three numeric substitutions |
| No lint/concurrency escape hatch | ✓ VERIFIED | No suppression, unchecked-Sendable conformance, unsafe-nonisolated annotation, or preconcurrency attribute in scope |
| Scheduler named only in client module | ✓ VERIFIED | One Swift source file |
| Do not strand dead machinery | ? HUMAN DECISION | Dependency key/accessor have no source consumer; later plans explicitly leave this owner-pending |

### Human Verification Required After Gap Closure

1. **Physical-device continuation and progress**

   **Test:** Queue at least three galleries totalling at least 300 pages, start in foreground,
   background for more than 60 seconds, and observe the system card.

   **Expected:** Download completes beyond the old grace period; one neutral card appears and its
   bar/counts track the app without initially showing 0/0.

   **Why human:** Simulator does not grant continued-processing tasks or render the system card.

2. **Physical-device cancel parity**

   **Test:** While the card is live, use its cancel affordance and foreground the app.

   **Expected:** Every previously schedulable gallery is paused exactly as an in-app pause would
   leave it, with no later resume/retry overwritten by stale expiration work.

   **Why human:** System card cancel and resource expiration share a device-only callback.

3. **Force-quit durability**

   **Test:** Force-quit from the app switcher mid-session and relaunch.

   **Expected:** No crash and no duplicated pages.

   **Why human:** Process lifecycle and queued scheduler behavior are not reproducible in unit tests.

4. **Dead dependency accessor disposition**

   **Test:** Decide whether the unused `BackgroundProcessingClientKey` and
   `DependencyValues.backgroundProcessingClient` are justified solely to host `testValue`, or
   whether live composition should resolve that dependency.

   **Expected:** Either the accessor is made a real composition path or the seam is reshaped without
   leaving unreachable machinery.

   **Why human:** This is a judgment-tier PLAN prohibition explicitly left owner-pending.

### Gaps Summary

The session-identity closure fixed targeted completion and refusal recovery, but it did not
carry identity through progress updates, seed the task's initial `Progress`, make expiration
pause atomic with respect to a newer user action, or converge the vanished-record delete edge.
Those are observable implementation gaps, not device uncertainty, and green build/test gates
do not cover them. Phase 15 must not proceed as achieved until the three structured gap groups
above are closed and their missing interleaving tests exist.

---

_Verified: 2026-07-28T11:08:29Z_
_Verifier: the agent (gsd-verifier)_
