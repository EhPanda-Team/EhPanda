---
phase: 15-continued-background-downloads
verified: 2026-07-28T15:10:00Z
status: gaps_found
score: 2/4 must-haves verified
behavior_unverified: 1
overrides_applied: 0
re_verification:
  previous_status: gaps_found
  previous_score: 2/4
  gaps_closed:
    - "Retain the minted identifier for the session's lifetime and cancel the request in endSession whenever no task was ever adopted."
    - "Give adopt(_:) an expected-identifier check, and complete (setTaskCompleted) any task it rejects or displaces rather than dropping it."
    - "Stamp each session with an id and make markContinuedSessionEnded a no-op for a superseded session."
    - "Route cancelQueuedWorkItem's non-.initial branch through scheduleNextIfNeeded() like every other queue mutation."
    - "A regression test per defect: a drained-then-relaunched request must not block a later start; a stale teardown must not clear a newer session; a queued update/repair cancel must reconcile the session."
  gaps_remaining: []
  regressions:
    - >-
      NEW: the WR-01 post-suspension bail-out added by 15-09
      (DownloadClient+ContinuedSession.swift:97-100) calls the session-blind
      `backgroundProcessingClient.finish(true)`, which can complete a newer, live, correctly-owned
      session belonging to a different tap. The gap round replaced a stranded session with a
      stolen one. Confirmed independently against the code (CR-04).
gaps:
  - truth: "SC1 — A download started in the foreground continues to completion after the app is backgrounded, for a queue large enough to outlast the beginBackgroundTask grace period."
    status: partial
    reason: >-
      All five prior missing items are genuinely satisfied in code and pinned by three
      substantive regression cases: the pending identifier is retained and cancelled, adoption is
      identity-gated and completes every task it turns away, the coordinator session carries a
      UUID that gates teardown/event delivery/reconcile-drain, and the non-`.initial` queued
      cancel now exits through the convergence point. But the fix for the one remaining prior
      warning (WR-01) introduced a new, worse defect of the same family: the coordinator's only
      completion verb carries no session identity, so a caller that lost ownership across its own
      suspension ends whatever session the store currently holds. Two further live-session hazards
      sit on the same missing invariant — the pause-all loop is the one teardown path with no
      identity gate, and the reconcile drain issues the same untargeted `finish`. Each ends in the
      SC1-breaking symptom: a download the user just started runs with no background coverage and
      no card, or is paused outright, silently and with no state a later action recovers from.
    artifacts:
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
        issue: >-
          Lines 97-100: the post-suspension ownership re-check bails out with
          `await backgroundProcessingClient.finish(true)`. The seam is
          `finish: @Sendable (_ success: Bool) async -> Void`
          (BackgroundProcessingClient.swift:28) — no session identity — and it forwards to
          `ContinuedProcessingSession.finish(success:)` (ContinuedProcessingSession.swift:161-163),
          whose body is `endSession(yielding: nil, success:)` with no identity guard at all
          (`:224-245`). Reachable trace: tap 1's `ensure` suspends inside the `start` main-actor
          hop; a reconcile running from the detached task at
          `DownloadClient+Execution.swift:253-268` drains, passes its own re-check, runs
          `markContinuedSessionEnded(X)` and enqueues `finish`; tap 2's `ensure` now passes the
          liveness guard, mints Y and enqueues its own `start`. Main-actor FIFO yields create A,
          end A, create B. Tap 1 resumes, sees `Y != X`, and issues `finish(true)` — which ends
          **B**, the session tap 2 legitimately owns: B's system task completed, B's card removed,
          B's pending request cancelled, B's stream finished. No existing assertion can see this;
          the coordinator's own state stays self-consistent throughout and converges to "no
          session" when B's consuming task falls out of the finished stream. Nothing retries, so
          tap 2's download runs uncovered until the user makes another qualifying tap.
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
        issue: >-
          Lines 134-137 and 177-182: `pauseAllSchedulable()` is the one teardown path with no
          identity gate. The `.expired` branch clears the session first (line 136, deliberately)
          and then loops `await pause(gid:)` over a pre-loop snapshot; each `pause` genuinely
          suspends on `queueStore.remove` → `Shared.save()` file I/O. A queue-mobilizing tap
          landing inside that loop passes `ensureContinuedSession()`'s guard and starts S2; the
          loop keeps pausing galleries off the stale snapshot — including the ones S2 was just
          started to cover — and each `pause` tails into `scheduleNextIfNeeded()` →
          `reconcileContinuedSession()`, which completes S2 the moment the loop empties the
          schedulable set. The user's brand-new download is paused and their new card dismissed by
          an expiration belonging to a session that no longer exists. This window is materially
          wider than the CR-04 one (N file-I/O suspensions vs one main-actor hop).
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
        issue: >-
          Line 200: the reconcile drain is careful about coordinator state (binds `sessionID`,
          re-checks at line 196, ends with `markContinuedSessionEnded(sessionID:)`) and then
          discards all of it with the same bare `await backgroundProcessingClient.finish(true)`.
          Between the synchronous teardown and the main-actor hop landing, this reentrant actor is
          free to run a tap's `ensure`, which mints a successor and enqueues its own `start`. Same
          missing invariant as CR-04, smaller blast radius today only because of hop ordering.
      - path: "AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift"
        issue: >-
          Lines 71-77: the store's single-session re-entry guard hands back an already-finished
          stream, and `start`'s return type is identical whether a session was created or refused.
          A coordinator whose `start` lands while a predecessor is still held therefore installs a
          consuming task over a dead stream, its ownership re-check passes, and the tap silently
          gets nothing. This is the untouched half of WR-01(b): 15-09 addressed ownership, not
          refusal observability.
    missing:
      - >-
        Give the client seam a session handle: `start` returns a session value carrying an `id`
        plus its event stream, and `finish` becomes `finish(sessionID:success:)`. The store already
        has per-session state — record the id in `start`, clear it in `endSession`, and make
        `ContinuedProcessingSession.finish(sessionID:success:)` a no-op unless the id matches the
        session it currently holds.
      - >-
        Thread that handle through both coordinator completion sites: the ensure bail-out
        (`DownloadClient+ContinuedSession.swift:98`) and the reconcile drain (`:200`), storing the
        client session id beside `continuedSessionID` so a losing caller can only ever complete the
        session it itself created.
      - >-
        Make store refusal observable and retryable rather than silent: `start` must let the
        coordinator distinguish "the store created my session" from "the re-entry guard refused
        me" (for example by returning an optional/`.refused` handle), and
        `ensureContinuedSession()` must roll its own bookkeeping back on refusal
        (`markContinuedSessionEnded(sessionID:)`) so the next queue-mobilizing tap can legitimately
        start a real session instead of consuming a dead stream.
      - >-
        Identity-gate `pauseAllSchedulable()`: take the expiring session's id, and stop the loop
        the moment `continuedSessionID` is neither `nil` nor that id, so an expiration cannot pause
        work a successor session covers.
      - >-
        Close the last asymmetric path for consistency: `pushContinuedSessionProgress(sessionID:)`
        gated on `continuedSessionID` like every other late-arriving mutation, threaded from
        `reconcileContinuedSession()` and from the `DownloadClient+Persistence.swift:223` flush.
      - >-
        Two deterministic regression cases, both cheap with the existing
        `BackgroundProcessingClientSpy`: (a) a bail-out `finish` never lands on the id returned by
        the most recent `start` — drive the drain-then-second-tap interleave and assert the second
        tap's session is still live and still receives progress pushes; (b) a queue-mobilizing tap
        arriving inside `pauseAllSchedulable()` leaves the successor's galleries unpaused and its
        session uncompleted. (The accepted no-test decision covers WR-01's *re-check*; it does not
        extend to the untargeted completion that re-check introduced.)
behavior_unverified_items:
  - truth: "SC2 — The system-provided progress UI reflects real download progress and its cancel affordance stops the queue, leaving download state consistent with an in-app cancel."
    test: >-
      On an iOS 26 device: queue >= 3 galleries totalling >= 300 pages, tap start, confirm
      downloads begin immediately, background the app, confirm the system card appears with the
      neutral title and count subtitle and no gallery title, leave backgrounded past ~60s and
      confirm the counts advance, foreground and confirm the card persists (D-08) and matches
      in-app progress, background again and tap cancel on the card, then foreground.
    expected: >-
      Exactly one card, whose counts track completed/total pages across schedulable galleries and
      whose strings contain no gallery title or tag; after the card cancel, every gallery is
      Paused, identical to having tapped pause on each in-app.
    why_human: >-
      The iOS Simulator does not grant background processing, so nothing on this machine can
      exercise the system granting a session, rendering the card, or delivering a card cancel.
      The coordinator half is unit-tested through the client spy; the framework half
      (task.progress writes, updateTitle, the expiration callback) is present and wired but
      never executed by any run here.
human_verification:
  - test: >-
      SC1 device half — with a queue large enough to outlast the old beginBackgroundTask grace
      window, background the app and confirm the download runs to completion.
    expected: "Downloads keep advancing well past ~60s of backgrounding and finish."
    why_human: "The system must actually grant a continued-processing session; unsupported in Simulator."
  - test: >-
      SC1 durability (confirms the CR-01/CR-03 fixes on device) — download one small or
      largely-cached gallery to completion first, so its queued request is abandoned and cancelled,
      then start a large one and background the app.
    expected: >-
      The second download is covered by a system card and keeps running — the abandoned request no
      longer wedges the store's re-entry guard for the rest of the process.
    why_human: "Requires the system to hold and later launch a real queued request; not reproducible in Simulator."
  - test: >-
      Launch-handler registration under the plist wildcard (WR-10) — on an iOS 26 device, start a
      download and confirm from the log that the session is submitted rather than reporting
      `Identifier … is not permitted by Info.plist`, then confirm the card appears.
    expected: >-
      `BGTaskScheduler.register` accepts the concrete per-session identifier
      `app.ehpanda.continued.<UUID>` matched by the plist wildcard, and the request is submitted.
    why_human: >-
      This is the one assumption in the design no test in the repository can reach, and its failure
      mode is silent by contract (`.unavailable` produces no user-visible signal). It is NOT scored
      as a code defect: the phase's own research records DTS guidance that per-instance registration
      of the concrete identifier immediately before submitting is the intended pattern and that
      registering the wildcard itself is rejected at runtime (crashing on submit), so the review's
      proposed "register the wildcard once" fix would break the feature. The cheap half of the risk
      is already falsified here — the built app's Info.plist expands to the literal
      `app.ehpanda.continued.*`.
  - test: >-
      SC3 force-quit half — force-quit from the app switcher mid-session and relaunch.
    expected: "No crash, and no duplicated pages in any gallery."
    why_human: "Process-lifecycle behavior is not reproducible in unit tests."
  - test: >-
      Card string truncation (15-04 backstop) — observe the card with a long count subtitle.
    expected: "The system truncates under its own policy; the app declares no length limit."
    why_human: "System UI rendering is outside the app process."
  - test: >-
      Prohibition review (judgment tier) — confirm the dead BackgroundProcessingClientKey and
      DependencyValues.backgroundProcessingClient accessor are acceptable under this phase's own
      'dead code is deleted, never stranded' prohibition.
    expected: >-
      Owner decides: delete the key + accessor, or resolve the live client through @Dependency at
      the one construction site. Either way the factually incorrect rationale at
      DownloadClient+Manager.swift:305-308 must not ship as written.
    why_human: >-
      Judgment-tier prohibition, deliberately untouched by 15-09 per its own plan prohibition. A
      tree-wide search still finds no @Dependency(\.backgroundProcessingClient) and no
      self[BackgroundProcessingClientKey.self] outside the declaration.
---

# Phase 15: Continued Background Downloads Verification Report

**Phase Goal:** Adopt `BGContinuedProcessingTask` (iOS 26) so a gallery download the user just started keeps running when the app is backgrounded, surfaced by the system-provided progress UI, instead of being cut short by the short grace period that bounded the previous behavior.
**Verified:** 2026-07-28T15:10:00Z
**Status:** gaps_found
**Re-verification:** Yes — after the 15-08 / 15-09 gap-closure round

Verified against the **amended** ROADMAP.md Phase 15 entry (SC3 and SC4 were rewritten by plan 15-07 to state the shipped single-tier contract; that supersession is the contract, not drift). Every claim below was re-derived from the tree at HEAD (`1ac99560`), not from the 15-08/15-09 summaries.

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC1 | A foreground-started download continues to completion after backgrounding, for a queue large enough to outlast the old grace period | ✗ FAILED | All five prior missing items are genuinely closed (see Gap-Closure Ledger) — but the WR-01 fix introduced an untargeted `finish` that can end a newer, live session (CR-04), and two sibling paths (`pauseAllSchedulable`, the reconcile drain) carry the same missing identity invariant. Device half additionally unobservable here |
| SC2 | The system progress UI reflects real progress and its cancel stops the queue, consistent with an in-app cancel | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Unchanged by the gap round. Coordinator half proven by the passing session suite; the card render / card cancel half needs a device and cannot run in Simulator. Note: the WR-08 pause-all hazard listed under SC1 also degrades this criterion's "consistent with an in-app cancel" clause |
| SC3 | No fallback tier: both older tiers deleted outright; refusal/expiry suspends with the process, no lost or duplicated work, no user-visible error | ✓ VERIFIED | Re-run at HEAD: zero greps for every deleted spelling across `App`, `AppPackage`, `ShareExtension`; `BackgroundExecutionInvariantTests` passes unmodified after the seam extraction; the `.unavailable` path is still silent by contract (`DownloadClient+ContinuedSession.swift:138-142`) |
| SC4 | A testable client seam in `BackgroundProcessingClient` exposing start / update-progress / finish with a self-finishing event stream, `testValue` unimplemented, no reducer **or coordinator** touching the task scheduler directly | ✓ VERIFIED | Three endpoints + three-case event enum unchanged; `testValue = BackgroundProcessingClient()` with all three endpoints asserted unimplemented (`DownloadContinuedSessionTests.swift:14-24`); `BGTaskScheduler` and `import BackgroundTasks` now appear in exactly one file (`ContinuedTaskScheduling.swift`), still one module, still asserted by the invariant suite. See the caveat below |

**Score:** 2/4 truths verified (1 present, behavior-unverified)

**SC4 caveat (recorded, not scored):** the seam satisfies SC4 as written — the three named verbs, the self-finishing stream, the unimplemented `testValue`, and the scheduler confined out of every reducer and the coordinator. But its `finish` verb cannot name the session it completes, and that omission is the root cause of the SC1 blocker. Closing the SC1 gap will change this public API surface. Not double-counted as an SC4 failure; flagged so the next planner knows the seam is not final.

### Gap-Closure Ledger — the five prior `missing:` items

| # | Prior missing item | Now | Code evidence |
|---|--------------------|-----|---------------|
| 1 | Retain the minted identifier and cancel the request in `endSession` when no task was adopted | ✓ SATISFIED | `pendingIdentifier` declared (`ContinuedProcessingSession.swift:48`), set only after a successful submit (`:135`), taken back in `endSession` (`:229` binds it only when no task was adopted, `:237-239` cancels) through the new `ContinuedTaskScheduling.cancel` verb (`ContinuedTaskScheduling.swift:57`, live at `:92-94` → `BGTaskScheduler.shared.cancel(taskRequestWithIdentifier:)`). The once-per-process sweep is explicitly documented as non-subsuming (`:94-98`) |
| 2 | Identity-check `adopt(_:)` and complete every task it rejects or displaces | ✓ SATISFIED | `adopt(_:expecting:)` gate at `:187-190` — `guard pendingIdentifier == identifier, self.task == nil else { task.setTaskCompleted(success: false); return }`. `handleLaunch(_:expecting:)` also gates the failed-launch reset on `pendingIdentifier == identifier` (`:175`), and the live seam completes an uncastable stray before the handler runs (`ContinuedTaskScheduling.swift:71-77`) |
| 3 | Stamp each session with an id; make `markContinuedSessionEnded` a no-op for a superseded session | ✓ SATISFIED | `continuedSessionID` (`DownloadClient+Manager.swift:370`) minted in the same synchronous run as the liveness flag (`ContinuedSession.swift:81-83`); `markContinuedSessionEnded(sessionID:)` guards at `:160`; event delivery guards at `:129`; the reconcile drain re-checks after its suspending read at `:196` |
| 4 | Route `cancelQueuedWorkItem`'s non-`.initial` branch through `scheduleNextIfNeeded()` | ✓ SATISFIED | `DownloadClient+Scheduling.swift:222-225` — the branch now ends with `await scheduleNextIfNeeded()` and carries a comment naming why |
| 5 | A regression test per defect | ✓ SATISFIED | `ContinuedProcessingSessionTests.swift` is new (285 lines, `@testable import BackgroundProcessingClient`) with three store cases driving an isolated `ContinuedProcessingSession(scheduling:)` over spies (`:127`, `:198`, `:246`). `DownloadContinuedSessionTests.swift:700-760` adds the two coordinator cases; both are substantive (the WR-04 case asserts `finishCount == 1` where the pre-fix path produced 0, then proves a fresh session starts and also drains) |

**No prior gap item was closed on paper only.** The `ContinuedTaskScheduling` extraction is a real testability seam, not a veneer: it confines every scheduler verb to one value and is what makes the store's state machine drivable at all.

### What the gap round broke

| Introduced by | Location | Effect |
|---------------|----------|--------|
| 15-09, WR-01 fix | `DownloadClient+ContinuedSession.swift:97-100` | New call site of the session-blind `finish`. Pre-fix, a losing `ensure` installed a consuming task for an abandoned session (stranded, eventually force-expired). Post-fix it can complete a *successor*: destroyed while the user is actively depending on it. Confirmed by reading the diff — this call site did not exist at `4ca2f734` |

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `AppPackage/Sources/BackgroundProcessingClient/ContinuedTaskScheduling.swift` | Module-internal seam owning every scheduler verb | ✓ VERIFIED | 135 lines, `@MainActor` struct with four verbs (`cancelAllRequests`, `register`, `submit`, `cancel`), one `live` value, and the `SystemContinuedTask` adapter. The only file naming `BGTaskScheduler` or importing `BackgroundTasks` |
| `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift` | Main-actor store with identifier retention and identity-checked adoption | ✓ VERIFIED | 246 lines, `@MainActor`, no escape annotations. Both prior store defects fixed; seed counters now reset on the start path (`:82-84`, prior WR-06) |
| `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift` | Session seam with unimplemented `testValue` | ⚠️ SUBSTANTIVE, WIRED, INCOMPLETE CONTRACT | Three endpoints and `testValue` present as specified — but `finish` carries no session identity (`:28`), which is the CR-04 root cause. Dead `BackgroundProcessingClientKey` + accessor (`:50-61`) still unreferenced (owner-pending) |
| `AppPackage/Sources/BackgroundProcessingClient/.swiftlint.yml` | Per-module lint config chaining to root | ✓ VERIFIED | Present, `parent_config: ../../../.swiftlint.yml` |
| `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` | Session-id-stamped coordinator lifecycle | ⚠️ SUBSTANTIVE, WIRED, DEFECTIVE | 253 lines. Stamping, gated events, no-op stale teardown and re-checked drain all present and correct — but the two `finish` call sites (`:98`, `:200`) and `pauseAllSchedulable()` (`:177-182`) are session-blind |
| `AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift` | Per-session identity state + honest liveness doc comment | ✓ VERIFIED | `continuedSessionID: UUID?` at `:370`; the liveness-flag comment (`:349-363`) now states plainly that the flag is rolled back and that `ensureContinuedSession()` suspends after setting it |
| `AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift` | Convergent queue mutations | ✓ VERIFIED | 244 lines; the non-`.initial` cancel branch converges at `:225`; `scheduleNextIfNeeded()` remains the documented forwarder (`:14-22`) |
| `AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionTests.swift` | Store-level lifecycle regression suite | ✓ VERIFIED | 285 lines, three cases, isolated stores over injected spy scheduling |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` | Coordinator regression cases | ✓ VERIFIED | 994 lines; the two new cases are real (foreign-UUID teardown proven inert; convergence-point cancel proven to complete). Six lines under the hard `file_length: error: 1000` — see Anti-Patterns |
| `AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift` | Permanent source-tree invariant | ✓ VERIFIED | Unmodified by the gap round and still passing after the scheduler moved files — the assertion is module-scoped, not file-name-scoped |
| `App/Info.plist` | Permitted-identifier wildcard, exactly one entry | ✓ VERIFIED | Line 5-8, `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`; the built product expands it to `app.ehpanda.continued.*` (spot-check below) |
| Everything verified in the prior report and untouched by the gap round (`AppDelegateReducer`, `AppReducer`, `Package.swift`, `DownloadClient+PendingWork`, `Localizable.xcstrings`, `DownloadClient+Testing`, test support types, `.planning/ROADMAP.md`) | — | ✓ VERIFIED (regression check) | `git diff 4ca2f734..HEAD -- AppPackage App` touches exactly 7 files, none of them these |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `ContinuedProcessingSession.swift` | `ContinuedTaskScheduling.swift` | `endSession` cancels an abandoned request through the seam | ✓ WIRED | `scheduling.cancel(abandonedIdentifier)` at `:238`; live verb at `ContinuedTaskScheduling.swift:92-94` |
| `ContinuedProcessingSessionTests.swift` | `ContinuedProcessingSession.swift` | Cases build isolated stores over spy scheduling | ✓ WIRED | `ContinuedProcessingSession(scheduling: spy.scheduling)` at `:127`, `:198`, `:246` |
| `DownloadClient+ContinuedSession.swift` | `DownloadClient+Manager.swift` | Every teardown and event dispatch gated on the stamped identity | ✓ WIRED | `continuedSessionID` compared at `:97`, `:129`, `:160`, `:196` |
| `DownloadClient+Scheduling.swift` | `DownloadClient+ContinuedSession.swift` | Scheduling tail reconciles and completes the session | ✓ WIRED | Previously ⚠️ PARTIAL. Now every branch converges: `:22` forwarder tail, `:225` non-`.initial` cancel, `Execution.swift:264` collision-cleanup branch |
| `DownloadClient+PublicAPI.swift` / `+RetryHelpers.swift` | `DownloadClient+ContinuedSession.swift` | Four D-07 tap sites ensure a session | ✓ WIRED | `PublicAPI.swift:97`, `:174`; `RetryHelpers.swift:18`, `:69` — unchanged by the gap round |
| `DownloadClient+Persistence.swift` | `DownloadClient+ContinuedSession.swift` | Throttled flush pushes progress | ✓ WIRED | `:223` `await pushContinuedSessionProgress()` |
| `DownloadClient+ContinuedSession.swift` | `BackgroundProcessingClient.finish` | Coordinator completes the session it owns | ✗ NOT_WIRED (identity) | Both call sites (`:98`, `:200`) invoke a verb with no session parameter, so "the session it owns" is unexpressible. This is the CR-04 link failure |
| `DownloadClient+ContinuedSession.swift` | `pause(gid:)` | Expiration pauses through the per-gallery primitive | ⚠️ PARTIAL | The loop is correct per gallery, but unbounded and identity-free (WR-08) |
| `BackgroundProcessingClientKey` / `DependencyValues.backgroundProcessingClient` | (any consumer) | `@Dependency` resolution | ✗ NOT_WIRED | Re-verified: no `@Dependency(\.backgroundProcessingClient)` and no `self[BackgroundProcessingClientKey.self]` outside the declaration. Owner-pending, not scored |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| System card counts | `ContinuedSessionProgress` | `schedulableProgress()` → `schedulableDownloads()` → `indexedDownloads()` filtered by `isSchedulableDownload` | Yes — real per-gallery counts from one snapshot | ✓ FLOWING |
| Card subtitle | `String(localized: .continuedSessionSubtitle(...))` | Built from the clamped pushed pair; three `Int`s only | Yes | ✓ FLOWING |
| `task.progress` | `completedUnitCount` / `totalUnitCount` | `updateProgress` writes total then completed; adoption seeds from the (now correctly reset) last-pushed pair | Yes when a task is held | ⚠️ STATIC (device-only to confirm the write reaches the card) |
| `continuedSessionID` | coordinator identity | `ensureContinuedSession` mint / gated teardown | Yes — honored at four gates | ✓ FLOWING |
| Store-side session identity | (none) | — | **No such value exists** | ✗ DISCONNECTED — the store has `pendingIdentifier` for the *request* but nothing the caller can name a *session* by, which is exactly why `finish` is untargeted |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Deleted-tier spellings absent tree-wide | `grep -rn "BGProcessingTask\|beginBackgroundTask\|BackgroundTaskClient\|runQueueUntilIdle\|downloads.processing\|downloads.assertion" App AppPackage ShareExtension` | no output | ✓ PASS |
| Scheduler named in exactly one Swift file | `grep -rn --include='*.swift' "BGTaskScheduler" … \| cut -d: -f1 \| sort -u` | `…/BackgroundProcessingClient/ContinuedTaskScheduling.swift` | ✓ PASS |
| `import BackgroundTasks` confined to that same file | `grep -rn --include='*.swift' "^import BackgroundTasks" …` | one hit, same file | ✓ PASS |
| Built app's plist expands the wildcard (research assumption A2) | `plutil -extract BGTaskSchedulerPermittedIdentifiers xml1 -o - "$HOME/Library/Developer/Xcode/DerivedData/EhPanda-*/Build/Products/Debug-iphonesimulator/EhPanda.app/Info.plist"` | `app.ehpanda.continued.*` | ✓ PASS |
| Gap-round diff is exactly the declared surface | `git diff --stat 4ca2f734..HEAD -- AppPackage App` | 7 files, +648/−57, all declared in 15-08/15-09 `files_modified` | ✓ PASS |
| No debt markers / escapes / over-length lines in the changed set | per-file `grep` + `awk 'length>120'` | no output | ✓ PASS |
| Regression cases present and substantive | read of `ContinuedProcessingSessionTests.swift` and `DownloadContinuedSessionTests.swift:700-760` | 3 store cases + 2 coordinator cases, all asserting behavior the pre-fix code could not produce | ✓ PASS |
| Full `FeatureTests` plan at HEAD | orchestrator-supplied | 138 suites, 0 failures, exit 0 | ✓ PASS (not evidence for SC1 — CR-04 is invisible to every existing assertion by construction) |
| System grants a session and renders the card | — | not runnable: Simulator does not support background processing | ? SKIP → human |

### Probe Execution

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| — | — | No `scripts/*/tests/probe-*.sh` exist in this repository and no plan declares one | n/a |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| SC1 | 15-05, 15-06, 15-07, 15-08, 15-09 | Foreground-started download survives backgrounding | ✗ BLOCKED | Five prior items closed; one new blocker (CR-04) plus two sibling identity gaps (WR-08, WR-09) and the untouched refusal-observability half of WR-01 |
| SC2 | 15-04, 15-06, 15-07 | Card reflects real progress; its cancel matches an in-app cancel | ? NEEDS HUMAN | Device-only; unchanged by the gap round |
| SC3 | 15-01, 15-02, 15-06, 15-07 | No fallback tier; both older tiers deleted; silent on refusal | ✓ SATISFIED | Grep gates at zero, invariant suite passes unmodified after the seam extraction |
| SC4 | 15-01, 15-03, 15-04, 15-07, 15-08 | Testable session seam, unimplemented `testValue`, scheduler confined | ✓ SATISFIED | Three endpoints, three-case stream, unimplemented-endpoint test, scheduler in one file of one module (caveat above) |

No `REQ-*` IDs map to this phase by design (`ROADMAP.md`: "Requirements: None mapped — the scope contract is this phase's four success criteria"). Re-checked `.planning/REQUIREMENTS.md`: no requirement row assigns itself to Phase 15, so there are no orphaned requirement IDs.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `DownloadClient+ContinuedSession.swift` | 97-100 | Untargeted completion of a shared singleton's current session | 🛑 Blocker | Ends a newer, live, correctly-owned session; the tap that owns it silently gets no coverage and no card (CR-04) |
| `DownloadClient+ContinuedSession.swift` | 177-182 | Unbounded, identity-free loop across real file-I/O suspensions | 🛑 Blocker | An expiration pauses work a successor session covers and dismisses the user's new card (WR-08) |
| `DownloadClient+ContinuedSession.swift` | 200 | Same session-blind `finish` on the reconcile drain | ⚠️ Warning | Same missing invariant; smaller blast radius today purely by hop ordering (WR-09) |
| `ContinuedProcessingSession.swift` | 71-77 | Refusal and success share a return type | ⚠️ Warning | The coordinator cannot tell "started" from "refused", so a refused tap consumes a dead stream in silence (WR-01 residual) |
| `DownloadClient+ContinuedSession.swift` | 91-96 | Doc comment names two suspension windows where one exists | ⚠️ Warning | Spreads attention away from the single hop where the defect lives (IN-11) |
| `DownloadClient+ContinuedSession.swift` | 214-215 | `pushContinuedSessionProgress()` still gated on the bare liveness flag | ⚠️ Warning | Last asymmetric path in a design whose premise is that every late mutation presents an id (IN-10) |
| `BackgroundProcessingClient.swift` | 50-61 | Unreachable `DependencyKey` + accessor, with an incorrect rationale at `DownloadClient+Manager.swift:305-308` | ⚠️ Warning | Dead seam; owner-pending judgment call (WR-05) |
| `ContinuedProcessingSession.swift` | 108-124 | One permanently-unregisterable launch handler per session | ⚠️ Warning | Monotonically growing handler set for the process lifetime. DTS-acknowledged for this API; a real cost, not a mistake (IN-07) |
| `DownloadContinuedSessionTests.swift` | 994 lines | Six lines under the hard `file_length: error: 1000` | ⚠️ Warning | The next case added to this suite fails the lint gate rather than the test run (IN-09) |
| `DownloadContinuedSessionTests.swift` | 99, 122, 169, 193, 236, 690, 718, 756 | Blocking-fixture cancellation is a trailing statement, not `defer` | ⚠️ Warning | An early throwing assertion leaks a forever-spinning runner in a parallel target; the gap round added two more instances (WR-07, deferred by decision) |
| `DownloadClient+PendingWork.swift` | 9-19 | Second, divergent copy of the schedulable predicate | ⚠️ Warning | Deferred by decision in 15-09 (WR-02) |
| `DownloadClient+ContinuedSession.swift` | 177-182 | Pause-all re-schedules each gallery it is about to pause | ⚠️ Warning | Deferred by decision in 15-09 (WR-03); WR-08's identity check belongs in the same edit |
| `ContinuedProcessingSession.swift` | 113-119 | `guard let self else { return }` drops a launched task uncompleted | ℹ️ Info | Unreachable (`self` is a `static let`), but a silent leak path if it ever became reachable (IN-06) |
| `BackgroundExecutionInvariantTests.swift` | 101-108 | Single-literal-space token assembly vs the lint rule's `\s+` | ℹ️ Info | Invariant marginally weaker than the rule it mirrors (IN-03) |
| `DownloadClient+PendingWork.swift` | 1 | Unused `import Foundation` | ℹ️ Info | None (IN-01) |
| `BackgroundProcessingClient.swift` | 63 | `// MARK: Test` labels the `previewValue` | ℹ️ Info | Inconsistent with the sibling client (IN-02) |
| `Localizable.xcstrings` | CJK locales | Number/unit spacing inconsistent | ℹ️ Info | Cosmetic (IN-04) |

No `TODO`, `FIXME`, `TBD`, `XXX`, `HACK` or `PLACEHOLDER` marker exists in any file the gap round touched, and there is no `@unchecked Sendable`, `nonisolated(unsafe)`, `@preconcurrency`, force-unwrap, force-cast or `swiftlint:disable` anywhere in the changed set. No line exceeds 120 characters. The invariant suite makes the first three permanent.

### Review findings assessed but NOT scored as defects

| Finding | Verdict here | Basis |
|---------|--------------|-------|
| **WR-10** — wildcard permitted identifier vs per-session concrete registration | **Not a code defect.** Recorded as a device-verification item instead | The phase's own research (`15-RESEARCH.md`, DTS threads 796944 / 799126) records that per-instance registration of the concrete identifier immediately before submitting is the *intended* pattern, that the wildcard is a plist permission pattern only, and that registering the wildcard as a handler is rejected — crashing on submit with `No launch handler registered for task with identifier …`. The review's proposed fix would therefore break the feature outright. The cheap half of the risk (does `$(PRODUCT_BUNDLE_IDENTIFIER)` expand?) is falsified here: the built plist reads `app.ehpanda.continued.*`, which the minted `app.ehpanda.continued.<UUID>` matches. What remains is a genuine device-only unknown, and its failure mode is silent, so it is listed under Human Verification with that framing |
| **IN-07** — handler accumulation per session | Warning, not a gap | Direct and DTS-acknowledged consequence of the pattern above; no in-repo fix exists that does not reintroduce the crash |
| **WR-02 / WR-03 / WR-07** | Not gaps | Deferred by explicit decision in 15-09 |
| **WR-05** | Not a gap | Owner-pending judgment-tier prohibition; 15-09 was prohibited from touching it either way |
| Two `deferred-items.md` entries | Not gaps | Deferred by decision |

### Prohibitions (judgment tier — non-authoritative LLM-judge verdict, human review recommended)

| Prohibition | Judge verdict | Basis |
|-------------|---------------|-------|
| No secondary background-execution mechanism retained as a fallback tier | ✓ upheld | Zero greps for every deleted spelling; the invariant suite passed unmodified through a refactor that moved the scheduler to a new file |
| No orphaned or unreferenced background-execution machinery; dead code deleted, not stranded | ⚠️ **flagged — unverified-prohibition** | `BackgroundProcessingClientKey` and its accessor remain unreferenced; the rationale at `DownloadClient+Manager.swift:305-308` remains factually wrong. Owner call, deliberately untouched by 15-09 |
| No SwiftLint suppression, no `@unchecked Sendable`, no `nonisolated(unsafe)`, no `@preconcurrency` | ✓ upheld | Absent from the whole changed set and asserted tree-wide by the invariant suite |
| No content-identifying text on the system card | ✓ upheld | Subtitle builder still takes three `Int`s; no gallery value is in lexical scope; unchanged by the gap round |

### Human Verification Required

#### 1. SC1 device half — a large queue outlasts the old grace window

**Test:** Queue >= 3 galleries totalling >= 300 pages on an iOS 26 device, tap start, background the app well past ~60s.
**Expected:** The card's counts advance and the downloads run to completion.
**Why human:** The Simulator does not grant background processing.

#### 2. SC1 durability — a second download after a short one (confirms the CR-01/CR-03 fixes)

**Test:** Download one small or largely-cached gallery to completion first, then start a large one and background the app.
**Expected:** The second download is covered by a card and keeps running — the abandoned request no longer wedges the store's re-entry guard.
**Why human:** Requires the system to hold and later launch a real queued request.

#### 3. Launch-handler registration under the plist wildcard (WR-10)

**Test:** On an iOS 26 device, start a download and check the log for `Identifier … is not permitted by Info.plist`; confirm the card appears.
**Expected:** `register` accepts the concrete per-session identifier matched by the wildcard, and submission succeeds.
**Why human:** The one design assumption no test here can reach, and `.unavailable` is silent by contract. See the "assessed but not scored" table for why the review's proposed fix must not be applied.

#### 4. SC2 device half — card content, persistence, and cancel

**Test:** With a session live, background and read the card; foreground and compare to in-app progress; background again and tap cancel; foreground.
**Expected:** Exactly one card, neutral title plus counts only, counts advancing, card persists across the foreground return (D-08), and after the cancel every gallery is Paused exactly as an in-app pause leaves it.
**Why human:** The card is system UI outside the app process.

#### 5. SC3 force-quit half

**Test:** Force-quit from the app switcher mid-session and relaunch.
**Expected:** No crash and no duplicated pages.
**Why human:** Process lifecycle is not reproducible in unit tests.

#### 6. Card string truncation

**Test:** Observe the card with a long count subtitle.
**Expected:** The system truncates under its own policy.
**Why human:** System UI rendering.

#### 7. Prohibition decision — the dead dependency key

**Test:** Decide whether the unreachable `BackgroundProcessingClientKey` and its `DependencyValues` accessor violate this phase's "dead code is deleted, never stranded" prohibition.
**Expected:** Either delete both and correct the `DownloadCoordinator` doc comment, or resolve the live client through `@Dependency` at the one construction site. The incorrect rationale must not ship as written either way.
**Why human:** Judgment-tier prohibition with a defensible reading either way.

### Gaps Summary

The gap round did its declared job. Every one of the five prior `missing:` items is satisfied in the code, not in the summary: the store retains the identifier it submits and hands the request back when a session ends without adopting a task; adoption is gated on the expected identifier and completes every task it turns away, including strays the seam intercepts before they reach the store; the coordinator's session now carries a UUID that is honored at teardown, at event delivery and at the reconcile drain's post-suspension re-check; the one queue mutation that bypassed the convergence point now exits through it; and five new regression cases pin behavior the pre-fix code could not have produced. The `ContinuedTaskScheduling` extraction that made the store testable is a genuine structural improvement — the scheduler is now named in one file, and the invariant suite that guards against a second background tier passed through the move unmodified.

What is not done is the same thing that was not done last time, entering through a different door. The design's whole premise after 15-09 is that every late-arriving mutation must present a session identity. One verb never got one: `finish`. It takes a `Bool` and nothing else, and it routes to an `endSession` with no identity guard, so it completes whatever session the shared store happens to hold when the main-actor hop lands. 15-09 then added a *new* call site for exactly that verb — the WR-01 bail-out — in the one place where the caller is, by construction, a caller that has already lost ownership. Under the drain-then-second-tap interleave the bail-out ends the session the second tap legitimately owns: card gone, request cancelled, system task completed, and not one existing assertion able to see it, because both halves of the coordinator's state stay internally consistent the whole way through. The pre-fix bug stranded a session that the system would eventually force-expire; this one destroys a session while the user is depending on it. That is a regression, and it is the exact capability SC1 names.

Two more sit on the same missing invariant. `pauseAllSchedulable()` is the one teardown path with no identity gate at all, and its window is the widest in the file — N per-gallery pauses, each suspending on real file I/O — so a tap arriving inside a card-cancel's pause loop gets its brand-new download paused off a stale snapshot and its new card dismissed. The reconcile drain issues the same untargeted `finish` and is protected today only by hop ordering. And the half of WR-01 that 15-09 did not take up still stands: the store's re-entry guard returns a finished stream that is indistinguishable from a live one, so a refused tap silently gets nothing and nothing retries.

All four are one fix in shape: surface the store's session identity across the seam, then thread it through the two `finish` call sites, the pause loop and (for symmetry) the progress push, and make refusal something the coordinator can see and recover from. Each half needs its own regression case, and both are now cheap — the spy already records every `start`, so "a bail-out `finish` must never land on the id the most recent `start` returned" is a deterministic assertion. The accepted decision to ship WR-01's re-check without a test covers the re-check; it does not extend to the untargeted completion that re-check introduced.

Separately, the review's WR-10 does not survive contact with this phase's own research and is not scored as a defect: registering the concrete per-session identifier immediately before submitting is the pattern Apple DTS describes, and registering the wildcard instead is documented to crash on submit. The residual uncertainty is real but device-only, and it is recorded as such — with the cheap half already checked here, since the built product's plist does expand to `app.ehpanda.continued.*`. SC1's and SC2's device halves remain what they were: inherent to an API the Simulator does not implement, carried as human verification rather than counted as gaps.

---

_Verified: 2026-07-28T15:10:00Z_
_Verifier: Claude (gsd-verifier)_
