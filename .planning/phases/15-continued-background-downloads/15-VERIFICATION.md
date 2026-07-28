---
phase: 15-continued-background-downloads
verified: 2026-07-28T02:15:43Z
status: gaps_found
score: 2/4 must-haves verified
behavior_unverified: 1
overrides_applied: 0
gaps:
  - truth: "SC1 — A download started in the foreground continues to completion after the app is backgrounded, for a queue large enough to outlast the beginBackgroundTask grace period."
    status: partial
    reason: >-
      The submission path, the four D-07 tap sites, the non-gating of download work, and the
      throttled progress push are all present, wired and unit-tested. But three independently
      confirmed session-lifecycle defects make the guarantee non-durable across a process: after
      an ordinary short download, background coverage can be permanently dead for every
      subsequent download in that process, and a live session can be silently detached from the
      work it covers. The device half of SC1 is additionally unobservable on this machine.
    artifacts:
      - path: "AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift"
        issue: >-
          start() mints `identifier` as a local (line 88) and never stores it; endSession
          (lines 178-192) clears task/continuation/isAwaitingTask without ever calling
          BGTaskScheduler.shared.cancel(taskRequestWithIdentifier:). The only cancellation in the
          module is the once-per-process cancelAllTaskRequests() behind didCancelStaleRequests
          (lines 69-77), which by construction cannot run twice. Under the chosen
          `request.strategy = .queue` (line 118) a submission routinely sits pending, while
          reconcileContinuedSession calls finish(true) the instant the queue drains — so a small
          or largely-cached gallery abandons a live request as a matter of course. When the
          system later launches it, adopt() sets `self.task`, which makes the re-entry guard at
          line 61 (`guard task == nil, continuation == nil, !isAwaitingTask`) reject every
          subsequent start() for the rest of the process.
      - path: "AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift"
        issue: >-
          adopt(_:) (lines 157-168) writes `self.task = task` with no check that the arriving
          task belongs to the session being awaited, and without completing any task it
          displaces. Reachable once a stale request is pending: the stale task is adopted into
          the next session (yielding a spurious .granted on that session's continuation), and
          when the real task lands, the first is dropped with no setTaskCompleted(success:) —
          a leaked system task and a second progress card. Its later force-expiration delivers
          .expired to the live session's stream, triggering pauseAllSchedulable() on downloads
          the user never paused.
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift"
        issue: >-
          markContinuedSessionEnded() (lines 133-137) carries no session identity and writes
          hasLiveContinuedSession/continuedSessionTask/lastPushedCompletedPageCount
          unconditionally. DownloadCoordinator is a reentrant actor
          (DownloadClient+Manager.swift:50). The consuming task's trailing teardown at line 95
          runs after the whole `for await` body, and the .expired branch awaits
          pauseAllSchedulable() (line 119) — an unbounded sequence of pause(gid:) calls with
          file IO — before that teardown fires. A queue-mobilizing tap landing in that window
          starts session S2, whose state the stale teardown then clears: S2 is live in the
          system while pushContinuedSessionProgress and reconcileContinuedSession both return
          at their `guard hasLiveContinuedSession` (lines 162, 182), so S2 is never updated and
          never completed.
      - path: "AppPackage/Sources/DownloadClient/DownloadClient+Scheduling.swift"
        issue: >-
          cancelQueuedWorkItem's .redownload/.update/.repair branch (lines 208-223) mutates the
          queue (clearDownloadQueueIntent + queueStore.remove) and returns via notifyObservers()
          without reaching scheduleNextIfNeeded() — the single convergence point that
          scheduleNextIfNeeded's own doc comment (lines 14-23) and reconcileContinuedSession's
          (lines 156-160) both rest on. If that removal empties the schedulable set while a
          session is live, nothing reconciles it: hasLiveContinuedSession stays true, so the next
          mobilizing tap folds into a dead session and starts nothing. Reachable from
          toggleDownloadPause on a queued update/redownload/repair item.
    missing:
      - "Retain the minted identifier for the session's lifetime and cancel the request in endSession whenever no task was ever adopted."
      - "Give adopt(_:) an expected-identifier check, and complete (setTaskCompleted) any task it rejects or displaces rather than dropping it."
      - "Stamp each session with an id and make markContinuedSessionEnded a no-op for a superseded session."
      - "Route cancelQueuedWorkItem's non-.initial branch through scheduleNextIfNeeded() like every other queue mutation."
      - "A regression test per defect: a drained-then-relaunched request must not block a later start; a stale teardown must not clear a newer session; a queued update/repair cancel must reconcile the session."
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
      SC1 durability — download one small or largely-cached gallery to completion first, then
      start a large one and background the app.
    expected: >-
      The second download is still covered by a system card and keeps running. If it is not,
      the CR-01 abandoned-request defect is confirmed live rather than only by inspection.
    why_human: "Requires the system to launch a real abandoned request; not reproducible in Simulator."
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
    expected: "Owner decides: delete the key + accessor, or resolve the live client through @Dependency at the one construction site."
    why_human: >-
      Judgment-tier prohibition. A tree-wide search finds no @Dependency(\.backgroundProcessingClient)
      and no self[BackgroundProcessingClientKey.self] outside the declaration; the doc comment at
      DownloadClient+Manager.swift:305-308 justifying them is factually incorrect.
---

# Phase 15: Continued Background Downloads Verification Report

**Phase Goal:** Adopt `BGContinuedProcessingTask` (iOS 26) so a gallery download the user just started keeps running when the app is backgrounded, surfaced by the system-provided progress UI, instead of being cut short by the short grace period that bounded the previous behavior.
**Verified:** 2026-07-28T02:15:43Z
**Status:** gaps_found
**Re-verification:** No — initial verification

Verified against the **amended** ROADMAP.md Phase 15 entry (SC3 and SC4 were deliberately rewritten by plan 15-07 to state the shipped single-tier contract; that supersession is treated as the contract, not as drift).

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| SC1 | A foreground-started download continues to completion after backgrounding, for a queue large enough to outlast the old grace period | ✗ FAILED | Submission path present and wired at all four D-07 tap sites and unit-tested — but four confirmed lifecycle defects (see Gaps) break the guarantee on ordinary sequences, and the device half is unobservable here |
| SC2 | The system progress UI reflects real progress and its cancel stops the queue, consistent with an in-app cancel | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Coordinator half proven by 26 passing cases (progress sums, monotonic floor, pause-all equal to a per-gallery baseline, order-independence, neutral strings); the card render / card cancel half needs a device and cannot run in Simulator |
| SC3 | No fallback tier: both older tiers deleted outright; refusal/expiry suspends with the process, no lost or duplicated work, no user-visible error | ✓ VERIFIED | Zero greps for every deleted spelling across `App`, `AppPackage`, `ShareExtension`; permanent invariant suite passes; `.unavailable` proven silent and state-equal to the inert client by two passing cases |
| SC4 | A testable client seam in `BackgroundProcessingClient` exposing start / update-progress / finish with a self-finishing event stream, `testValue` unimplemented, no reducer **or coordinator** touching the task scheduler directly | ✓ VERIFIED | Three endpoints + three-case event enum; `testValue = BackgroundProcessingClient()` and all three endpoints report issues when called (test passes); `BGTaskScheduler` appears in exactly one Swift file, asserted permanently by a passing invariant test |

**Score:** 2/4 truths verified (1 present, behavior-unverified)

### Deferred Items

None. Phase 16 (Dynamic Type Accessibility) is the only later phase in this milestone and covers none of these gaps, so nothing here is deferrable.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `App/Info.plist` | Continued-processing permitted-identifier wildcard, exactly one entry | ✓ VERIFIED | Line 7: `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*`; `grep -c BGTaskScheduler` = 1, `grep -c BGTaskSchedulerPermittedIdentifiers` = 1; `UIBackgroundModes: processing` deliberately retained with an in-file rationale (ROADMAP: "keeps its background-modes declaration") |
| `AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift` | Launch wiring with the background-URLSession handler intact, no scheduler registration | ✓ VERIFIED | Only `handleEventsForBackgroundURLSession` remains; no `register`, no `BGTask*` |
| `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift` | No `.background` scene-phase scheduling | ✓ VERIFIED | `.background` branch now only latches and flushes; comment states no background window is requested |
| `AppPackage/Package.swift` | AppFeature no longer depends on the client module | ✓ VERIFIED | `.module(.backgroundProcessingClient)` absent from the `appFeature` target (lines 272-310); present only on `downloadClient` and `downloadsFeatureTests` |
| `AppPackage/Sources/DownloadClient/DownloadClient+PendingWork.swift` | Schedulable-work predicate decoupled from any background mechanism | ✓ VERIFIED | `hasPendingWork()` present, no background import; regression suite passes |
| `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift` | Main-actor-confined store owning the task, its `Progress`, the continuation | ⚠️ SUBSTANTIVE, WIRED, DEFECTIVE | 193 lines, `@MainActor`, `using: .main`, no `@unchecked Sendable`/`nonisolated(unsafe)`. Confinement design holds; identifier retention and adopt-identity do not (see Gaps) |
| `AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift` | Session client seam with unimplemented `testValue` | ✓ VERIFIED | `@DependencyClient` struct, three endpoints, `.live` / `.noop` / `testValue`; key + accessor present but unreachable (warning) |
| `AppPackage/Sources/BackgroundProcessingClient/.swiftlint.yml` | Per-module lint config chaining to root | ✓ VERIFIED | Present with `parent_config` |
| `AppPackage/Sources/DownloadClient/Resources/Localizable.xcstrings` | Neutral card title + count subtitle in six locales | ✓ VERIFIED | `continued_session.title` and `continued_session.subtitle` both carry `de/en/ja/ko/zh-Hans/zh-Hant`; every numeric argument is a named `%#@variable@` substitution, no bare `%lld` in an outer value |
| `AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift` | Coordinator session lifecycle, progress arithmetic, expiration policy | ⚠️ SUBSTANTIVE, WIRED, DEFECTIVE | 220 lines; `ensureContinuedSession`, `pushContinuedSessionProgress`, `reconcileContinuedSession`, `pauseAllSchedulable` all present and called. `markContinuedSessionEnded` lacks session identity (see Gaps) |
| `AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift` | Session-liveness probe | ✓ VERIFIED | `testingHasContinuedSession()` present under `#if DEBUG`, used by the suite |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift` | Session seam contract coverage | ✓ VERIFIED | 26 `@Test` cases; whole suite passes |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift` | `Mutex`-backed spy with controllable continuation | ✓ VERIFIED | `BackgroundProcessingClientSpy`, `Mutex`-backed `State`, `emit`/`expire`, `Sendable` |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift` | Relocated blocking-coordinator fixture | ✓ VERIFIED | `makeBlockingCoordinator` survived the host-suite deletion and is reachable |
| `AppPackage/Tests/DownloadsFeatureTests/DownloadPendingWorkTests.swift` | Surviving queue-state regression coverage | ✓ VERIFIED | `testHasPendingWorkReflectsQueueState` present and passing |
| `AppPackage/Tests/DownloadsFeatureTests/BackgroundExecutionInvariantTests.swift` | Permanent source-tree invariant | ✓ VERIFIED | Walks 4 directories + the plist from `#filePath`, asserts non-empty input, 8 assembled forbidden tokens, scheduler-scope + plist-count assertions; both cases pass |
| `.planning/ROADMAP.md` | Amended phase contract matching the shipped design | ✓ VERIFIED | SC3 states "no fallback tier … deleted outright rather than fallen back to"; SC4 states the session API and "no reducer **or coordinator**"; the resolved-in-discuss-phase line records the full replacement |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `App/Info.plist` | `ContinuedProcessingSession.swift` | Permitted wildcard matches the minted identifier prefix | ✓ WIRED | Plist `$(PRODUCT_BUNDLE_IDENTIFIER).continued.*` vs runtime `"\(bundleIdentifier).continued.\(UUID().uuidString)"` (line 88) — prefixes match |
| `DownloadClient+Scheduling.swift` | `DownloadClient+PendingWork.swift` | Predicate available to the session reconcile | ✓ WIRED | `reconcileContinuedSession()` guards on `await hasPendingWork()` |
| `BackgroundProcessingClient.swift` | `ContinuedProcessingSession.swift` | Each live closure awaits the shared main-actor store | ✓ WIRED | All three `.live` closures call `ContinuedProcessingSession.shared` |
| `DownloadClient.swift` | `BackgroundProcessingClient.swift` | Live composition root injects the live client | ✓ WIRED | `DownloadClient.swift:77` `backgroundProcessingClient: .live` into the coordinator init |
| `DownloadClient+PublicAPI.swift` | `DownloadClient+ContinuedSession.swift` | Each queue-mobilizing entry point ensures a session on its success path | ✓ WIRED | Start `PublicAPI.swift:97`; resume-via-toggle `:174`; retry `RetryHelpers.swift:18`; retry-pages `:69`. Update reaches it through `retry(gid, .update)` (`DownloadsReducer.swift:358`) — all four D-07 moments covered |
| `DownloadClient+ContinuedSession.swift` | `DownloadClient+Scheduling.swift` | Expiration pauses through the per-gallery `pause(gid:)` primitive | ✓ WIRED | `pauseAllSchedulable()` loops `await pause(gid:)` |
| `DownloadClient+Persistence.swift` | `DownloadClient+ContinuedSession.swift` | Throttled flush pushes progress in the same branch that notifies observers | ✓ WIRED | `Persistence.swift:223` `await pushContinuedSessionProgress()` immediately after `notifyObservers()` |
| `DownloadClient+Scheduling.swift` | `DownloadClient+ContinuedSession.swift` | Scheduling tail reconciles and completes the session | ⚠️ PARTIAL | `scheduleNextIfNeeded()` tail calls `reconcileContinuedSession()` (line 22) and `Execution.swift:264` does too — but `cancelQueuedWorkItem`'s non-`.initial` branch bypasses the convergence point entirely (see Gaps) |
| `BackgroundExecutionInvariantTests.swift` | `AppPackage/Sources` | Walks the tree from `#filePath` | ✓ WIRED | `repositoryRoot()` climbs to the marker directories; scan asserted non-empty before use |
| `BackgroundProcessingClientKey` / `DependencyValues.backgroundProcessingClient` | (any consumer) | `@Dependency` resolution | ✗ NOT_WIRED | No `@Dependency(\.backgroundProcessingClient)` and no `self[BackgroundProcessingClientKey.self]` anywhere outside the declaration — dead seam, and the doc comment defending it is incorrect |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|--------------------|--------|
| System card counts | `ContinuedSessionProgress` | `schedulableProgress()` → `schedulableDownloads()` → `indexedDownloads()` filtered by `isSchedulableDownload` (the scheduler's own predicate, made internal for exactly this) | Yes — real per-gallery `completedPageCount`/`pageCount`, summed from one snapshot | ✓ FLOWING |
| Card subtitle | `String(localized: .continuedSessionSubtitle(...))` | Built from the *clamped* pushed pair, not the raw snapshot | Yes — three integer arguments only, no gallery value in scope | ✓ FLOWING |
| `task.progress` | `completedUnitCount` / `totalUnitCount` | `updateProgress` writes total first, then completed | Yes, when a task is held; a push with no adopted task only seeds `lastCompleted/TotalUnitCount` | ⚠️ STATIC (device-only to confirm the write reaches the card) |
| `hasLiveContinuedSession` | coordinator flag | `ensureContinuedSession` / `markContinuedSessionEnded` | Yes, but the flag can be cleared by a superseded session and can be stranded true by the bypassed convergence point | ⚠️ HOLLOW — see Gaps |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Deleted-tier spellings absent from the tree | `grep -rn "BGProcessingTask\|beginBackgroundTask\|BackgroundTaskClient\|runQueueUntilIdle\|downloads.processing\|downloads.assertion" App AppPackage ShareExtension` | no output | ✓ PASS |
| Scheduler named in exactly one Swift module | `grep -rn --include='*.swift' "BGTaskScheduler" App AppPackage ShareExtension \| cut -d: -f1 \| sort -u` | `AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift` | ✓ PASS |
| Plist scheduler mentions == permitted-key mentions == 1 | `grep -c "BGTaskScheduler" App/Info.plist` / `grep -c "BGTaskSchedulerPermittedIdentifiers" App/Info.plist` | `1` / `1` | ✓ PASS |
| Session suites + regression suites pass | `xcodebuild test … -only-testing:DownloadsFeatureTests/{DownloadContinuedSessionTests,BackgroundExecutionInvariantTests,DownloadSchedulingTests,DownloadPendingWorkTests}` (iPhone Air, iOS 26.5) | `** TEST SUCCEEDED **`, 30 tests / 4 suites, 3 known issues (the deliberate `withKnownIssue` unimplemented-endpoint expectations) | ✓ PASS |
| Card keys carry all six locales with named numeric substitutions | JSON read of `Localizable.xcstrings` | `continued_session.title` and `.subtitle` both `[de, en, ja, ko, zh-Hans, zh-Hant]`; all three numeric args are `%#@…@` substitutions | ✓ PASS |
| System grants a session and renders the card | — | not runnable: Simulator does not support background processing | ? SKIP → human |

Orchestrator-supplied gates relied on and not re-run: post-merge clean build (`** BUILD SUCCEEDED **`, zero `warning:`/`error:` — which via the SwiftLint build-tool plugin also means lint-clean for built targets) and the post-merge full suite (`** TEST SUCCEEDED **`, 800 tests / 22 targets). My own targeted run above is independent confirmation of the phase-critical suites.

### Probe Execution

| Probe | Command | Result | Status |
|-------|---------|--------|--------|
| — | — | No `scripts/*/tests/probe-*.sh` exist in this repository and no plan declares one | n/a |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| SC1 | 15-05, 15-06, 15-07 | Foreground-started download survives backgrounding | ✗ BLOCKED | Four lifecycle defects; device half unverified |
| SC2 | 15-04, 15-06, 15-07 | Card reflects real progress; its cancel matches an in-app cancel | ? NEEDS HUMAN | Coordinator half proven by tests; card render/cancel is device-only |
| SC3 | 15-01, 15-02, 15-06, 15-07 | No fallback tier; both older tiers deleted; silent on refusal | ✓ SATISFIED | Grep gates at zero, permanent invariant suite, two `.unavailable` cases |
| SC4 | 15-01, 15-03, 15-04, 15-07 | Testable session seam, unimplemented `testValue`, scheduler confined | ✓ SATISFIED | Three endpoints, three-case stream, unimplemented-endpoint test passes, scheduler in one module |

No `REQ-*` IDs map to this phase by design (`ROADMAP.md`: "Requirements: None mapped — the scope contract is this phase's four success criteria"). Cross-checked `.planning/REQUIREMENTS.md`: no requirement row assigns itself to Phase 15, so there are no orphaned requirement IDs.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `ContinuedProcessingSession.swift` | 88, 178-192 | Minted identifier discarded; no per-request cancellation path | 🛑 Blocker | Abandoned request permanently disables background coverage for the process |
| `ContinuedProcessingSession.swift` | 157-168 | `adopt` overwrites `self.task` without identity check or `setTaskCompleted` | 🛑 Blocker | Leaked system task, second card, spurious pause-all |
| `DownloadClient+ContinuedSession.swift` | 133-137 | Identity-free teardown on a reentrant actor | 🛑 Blocker | Stale teardown detaches a newer live session |
| `DownloadClient+Scheduling.swift` | 208-223 | Queue mutation returns without the convergence point | ⚠️ Warning | Session can be stranded live; next tap starts nothing |
| `DownloadClient+Manager.swift` | 350-360 | Doc comment asserts an invariant ("never rolled back … no window exists") the code does not hold — `ensureContinuedSession` suspends twice after setting the flag | ⚠️ Warning | Misleads the next reader about the concurrency contract |
| `DownloadClient+PendingWork.swift` | 9-19 | Second, divergent copy of the schedulable predicate (`activeTask` shortcut) alongside `schedulableDownloads()` | ⚠️ Warning | Card can read "N / N pages · 0 galleries" at a full bar while work is live; `DownloadContinuedSessionTests.swift:408` currently blesses that string |
| `DownloadClient+ContinuedSession.swift` | 149-154 | `pauseAllSchedulable` re-schedules each gallery it is about to pause | ⚠️ Warning | N-1 scheduling cycles (each a live HTTP fetch) inside the expiration handler, after the system signalled reclaim |
| `BackgroundProcessingClient.swift` | 49-61 | Unreachable `DependencyKey` + `DependencyValues` accessor | ⚠️ Warning | Dead seam; the doc comment justifying it is factually wrong |
| `ContinuedProcessingSession.swift` | 57-65, 140-149 | `start` does not reset the seed counters `endSession` zeroes | ⚠️ Warning | A late push between sessions can paint a new card with old counts |
| `DownloadContinuedSessionTests.swift` | 99, 122, 169, 193, 236 | Blocking-fixture cancellation is a trailing statement, not a `defer` | ⚠️ Warning | An early assertion failure leaves a forever-spinning task in a parallel test target |
| `BackgroundExecutionInvariantTests.swift` | 101-108 | Forbidden-token scan matches one literal space where `.swiftlint.yml` matches `\s+` | ℹ️ Info | `@unchecked  Sendable` would pass the invariant while failing lint |
| `DownloadClient+PendingWork.swift` | 1 | Unused `import Foundation` | ℹ️ Info | None |
| `BackgroundProcessingClient.swift` | 63 | `// MARK: Test` labels the value wired as `previewValue` | ℹ️ Info | Inconsistent with the sibling client |
| `Localizable.xcstrings` | ja/ko/zh number-unit spacing | Inconsistent numeral/measure-word spacing across CJK locales | ℹ️ Info | Cosmetic |

No `TODO`, `FIXME`, `TBD`, `XXX`, `HACK` or `PLACEHOLDER` marker exists in any file this phase touched, and there is no `@unchecked Sendable`, `nonisolated(unsafe)`, force-unwrap or `swiftlint:disable` anywhere in the changed set — the invariant suite proves the first three permanently.

### Prohibitions (judgment tier — non-authoritative LLM-judge verdict, human review recommended)

| Prohibition | Judge verdict | Basis |
|-------------|---------------|-------|
| No secondary background-execution mechanism retained as a fallback tier | ✓ upheld | Zero greps for every deleted spelling; the permanent invariant suite makes reintroduction a build failure |
| No orphaned or unreferenced background-execution machinery; dead code deleted, not stranded | ⚠️ **flagged — unverified-prohibition** | `BackgroundProcessingClientKey` and `DependencyValues.backgroundProcessingClient` are unreferenced; the doc comment defending them is incorrect. Needs an owner call — this is machinery for the *new* tier, so whether the prohibition reaches it is a judgment |
| No SwiftLint suppression, no `@unchecked Sendable`, no `nonisolated(unsafe)` | ✓ upheld | Invariant suite asserts all three tokens absent tree-wide; warning-free build implies the plugin found nothing |
| No content-identifying text on the system card | ✓ upheld | Subtitle builder takes only three `Int`s; no gallery value is in lexical scope; two cases assert the exact start and every later string |

### Human Verification Required

#### 1. SC1 device half — a large queue outlasts the old grace window

**Test:** Queue >= 3 galleries totalling >= 300 pages on an iOS 26 device, tap start, confirm downloads begin immediately, background the app and leave it backgrounded well past ~60s.
**Expected:** The card's counts advance and the downloads run to completion.
**Why human:** The Simulator does not grant background processing; nothing here can exercise the system granting a session.

#### 2. SC1 durability — a second download after a short one

**Test:** Download one small or largely-cached gallery to completion first (so its request is abandoned before launch), then start a large gallery and background the app.
**Expected:** The second download is still covered by a system card and keeps running.
**Why human:** This is the live confirmation of the CR-01 abandoned-request defect, which is currently established only by code inspection. If it reproduces, the gap is confirmed end-to-end.

#### 3. SC2 device half — card content, persistence, and cancel

**Test:** With a session live, background the app and read the card; foreground and compare against in-app progress; background again and tap cancel; foreground.
**Expected:** Exactly one card, neutral title plus count subtitle with no gallery title, counts advancing, card persists across the foreground return (D-08), and after the cancel every gallery is Paused exactly as an in-app pause leaves it.
**Why human:** The card is system UI outside the app process, and the cancel signal only arrives from real system UI.

#### 4. SC3 force-quit half

**Test:** Force-quit from the app switcher mid-session and relaunch.
**Expected:** No crash and no duplicated pages.
**Why human:** Process lifecycle is not reproducible in unit tests.

#### 5. Card string truncation

**Test:** Observe the card with a long count subtitle.
**Expected:** The system truncates under its own policy; the app imposes no limit of its own.
**Why human:** System UI rendering.

#### 6. Prohibition decision — the dead dependency key

**Test:** Decide whether the unreachable `BackgroundProcessingClientKey` and `DependencyValues.backgroundProcessingClient` accessor violate this phase's own "dead code is deleted, never stranded" prohibition.
**Expected:** Either delete both and correct the `DownloadCoordinator` doc comment, or resolve the live client through `@Dependency` at the one construction site.
**Why human:** Judgment-tier prohibition with a defensible reading either way.

### Gaps Summary

The phase's *structural* contract landed cleanly and, in places, better than asked. The two older tiers are genuinely gone — not deprecated, not fenced off, but absent from every Swift source, the plist and the test tree, with a permanent invariant suite standing behind that so a future phase cannot quietly bring one back. The seam is the shape SC4 specifies, the non-`Sendable` system objects are confined to the main actor without a single escape annotation, the card carries counts and nothing else across all six locales, and the coordinator-side arithmetic (monotonic completed count, a total floored at that count, one snapshot feeding both the bar and the caption) is covered by 26 passing cases including an order-independence proof and an equality-with-per-gallery-pause baseline. SC3 and SC4 are done.

What is not done is the session's **lifecycle**. Reading the code independently of the review, four defects hold up, and they share one root: the design assumes at most one session can be in play at a time, but nothing in the code enforces that assumption at either end of the seam.

At the client end, a submitted request is never cancelled. Because D-03 deliberately chose `.queue` so a request waits rather than fails, and because `reconcileContinuedSession` finishes the session the instant the queue drains, an ordinary short download routinely walks away from a live request. When the system eventually launches it, `adopt` stores the task, and the re-entry guard at line 61 then rejects every subsequent `start` for the rest of the process — background coverage silently dead, which is the exact capability SC1 names. `adopt` also has no identity check and completes nothing it displaces, so once one request is stale, two cards and a leaked task follow, and the orphan's eventual force-expiration pauses a queue the user never touched.

At the coordinator end, `markContinuedSessionEnded` carries no session identity while `DownloadCoordinator` is a reentrant actor. The trailing teardown at line 95 runs after `pauseAllSchedulable()` has awaited an unbounded run of `pause(gid:)` calls — a wide window in which a new tap can start a session whose state the stale teardown then wipes. And `cancelQueuedWorkItem`'s update/redownload/repair branch mutates the queue without reaching `scheduleNextIfNeeded()`, which is the single point the whole reconcile design is documented to hang off, so a session can be stranded live with nothing left to complete it.

None of these are exotic. Each is reachable from ordinary user actions — finish a small gallery, pause a queued update, tap download twice — and each ends in the same class of symptom: a stuck or duplicated system card, background coverage lost for the remainder of the process, and a spurious pause-all of work the user wanted running. Fixes are small and local (retain and cancel the identifier; stamp the session; route the one branch through the convergence point), but each needs its own regression test, because the current suite passes cleanly through all four.

Separately, SC1 and SC2 each have a device-only half that no run on this machine can reach — the Simulator does not grant background processing. Those are recorded as human verification items rather than gaps: they are inherent to the API, not a coverage failure by this phase. SC2 is marked present-but-behavior-unverified for exactly that reason and is not counted toward the score.

---

_Verified: 2026-07-28T02:15:43Z_
_Verifier: Claude (gsd-verifier)_
