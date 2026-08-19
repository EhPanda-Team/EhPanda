---
phase: quick-260819-lq3
plan: 01
subsystem: downloads
tags: [continued-processing, page-transfer, starvation, progress, g-15-2i]
status: complete
requires: [G-15-2D, G-15-2H]
provides:
  - "DownloadCoordinator.pageTransferAbandonThreshold (60 s, measured from the last byte)"
  - "DownloadCoordinator.abandonPageTransfer(gid:pageIndex:idle:)"
  - "ContinuedSubunitReport (the seam's fourth slot)"
  - "ContinuedProgressNudge (cap 30, headroom 31)"
affects:
  - "AppPackage/Sources/DownloadClient"
  - "AppPackage/Sources/BackgroundProcessingClient"
tech-stack:
  added: []
  patterns:
    - "attempt-scoped Task handle held on the in-flight entry, cancelled by the heartbeat sweep"
    - "withTaskCancellationHandler to keep the caller's cancellation reaching a wrapped attempt"
    - "run/session-scoped display-only reporter value inside the store that owns the system Progress"
key-files:
  created:
    - AppPackage/Sources/BackgroundProcessingClient/ContinuedProgressNudge.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSessionSubtitle.swift
    - AppPackage/Tests/DownloadsFeatureTests/ContinuedProgressNudgeTests.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PageTransferProgress.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSessionHeartbeat.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Networking.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
    - AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift
    - AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadPageTransferProgressTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestSupportTypes.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadProgressSeriesGuardTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionFoldTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionHeartbeatTests.swift
decisions:
  - "Idle time is measured from the last byte (InFlightPageTransfer.lastByteDate), so a slow-but-moving transfer is never abandoned"
  - "An abandoned attempt surfaces as the retryable AppError.networkingFailed; the page's existing downloadPage attempts loop is the retry path"
  - "The nudge lives in ContinuedProcessingSession, the store that owns the system Progress; one Bool crosses the seam"
  - "Only the heartbeat's report may INCREMENT the nudge; every push still snaps it back on a real change"
metrics:
  duration: ~55 min
  completed: 2026-08-19
---

# Quick Task 260819-lq3: Abandon Starved Page Transfers and Nudge a Stalled Card Summary

Closes G-15-2I: a page transfer that goes 60 s without a byte is now cancelled and retried instead of holding the queue, and a stalled continued-processing session can tell the system card "still working" up to 30 times before it goes flat by design.

## Commits

| Task | Commit | Message |
|---|---|---|
| 1 (Half 1) | `2a2c5982` | `fix(15): abandon starved page transfers` |
| 2 (Half 2) | `d6079878` | `fix(15): nudge a stalled session's card` |

Both on `feature/gsd-phase-15`. Code and tests only; `15-UAT.md`, `ROADMAP.md` and `STATE.md` were not touched.

## Test result

Final full `AppPackage-Package` run (iPhone Air simulator, one invocation):

```
** TEST SUCCEEDED ** [50.701 sec]     — 1009 tests, 0 failures
```

997 before this task → 1002 after Task 1 (+5 Half 1 cases) → 1009 after Task 2 (+4 pure-reporter cases, +3 end-to-end fold cases). App-scheme build (`AppFeature`, `generic/platform=iOS Simulator`) is **BUILD SUCCEEDED with zero warnings and zero errors**; the standalone SwiftLint binary reports 0 violations over `AppPackage/Sources/BackgroundProcessingClient`, `AppPackage/Sources/DownloadClient` and `AppPackage/Tests/DownloadsFeatureTests` (the app scheme's build plugin does not lint `Tests/`). No `swiftlint:disable` anywhere, no rule edited.

## What landed

### Half 1 — abandon and retry a starved transfer

- `DownloadCoordinator.pageTransferAbandonThreshold: TimeInterval = 60`, beside the unchanged 10 s `pageTransferStallThreshold`. Two constants on purpose: the log stays sensitive, the action stays conservative.
- `InFlightPageTransfer` gained `lastByteDate`, `isAbandoned`, `attempt` (the attempt's own `Task`) and one `idleInterval(at:)` definition. All four are attempt-scoped and reset by `beginPageTransfer`; only `creditedSubunits` crosses attempts.
- `recordPageTransferBytes` reads the clock ONCE when bytes arrive and stamps both dates from it, on the same path that grows the credit.
- The heartbeat's `sweepStarvedPageTransfers` (now internal) applies both thresholds to that one idle value: `>= 60` abandons, otherwise `>= 10` logs `still transferring` once. Abandonment routes through the ONE existing `logStarvedPageTransfer` helper with outcome `abandoned` — the hash-masked census for that file is still 2.
- `rawPageDownloadResponse` runs the attempt as its own `Task`, attaches it via `attachPageTransferAttempt`, and awaits it under `withTaskCancellationHandler`. A new private `pageTransferCancellationError(gid:pageIndex:)` decides what a cancellation-shaped end means, in this order: `Task.isCancelled` → `CancellationError`; entry `isAbandoned` → `AppError.networkingFailed`; otherwise `CancellationError`.
- Test seam: `testingSweepStarvedPageTransfers()` and `testingIsPageTransferring(gid:pageIndex:)`.
- Five new cases in `DownloadPageTransferProgressTests`, all driving the REAL `rawPageDownloadResponse` path against an injected hanging downloader over the file's frozen clock: abandon at the threshold (with a 59 s negative control), the slow-but-moving control, per-attempt idle measurement with credit kept across the re-open, caller cancellation stays `CancellationError`, and the 10 s sweep leaving the transfer running.

### Half 2 — the bounded stall nudge

- `ContinuedSubunitReport { inFlightSubunitCount, nudgesWhenStalled }` is the seam's fourth slot. Arity stays 5, so `.noop`'s and the expiration suite's `{ _, _, _, _, _ in }` doubles are untouched and the `DownloadSourceInventoryTests` construction (5) and `Task.yield()` (9) censuses did not move.
- `ContinuedProgressNudge` (internal, `BackgroundProcessingClient`): `cap = 30`, `headroom = cap + 1 = 31`, `record(measuredSubunits:nudgesWhenStalled:)`, `reportedSubunits`. Its doc carries the honesty argument, the headroom rationale, the cap derivation and the SSOT boundary in prose.
- `ContinuedProcessingSession` replaced `lastCompletedUnitCount`/`lastInFlightSubunitCount` with one `nudge`; `foldedCompletedUnitCount` is gone, replaced by `measuredSubunitCount(...)` = `max(0, min(completed * 1000 + inFlight, total * 1000 - headroom))`. `start` seeds the nudge from the caller's opening snapshot, `adopt` publishes `nudge.reportedSubunits`, `endSession` resets it. A stalled report logs one distinct line, integers only, every interpolation `.public`.
- `pushContinuedSessionProgress(sessionID:nudgesWhenStalled: = false)`; only `beatContinuedSession` passes `true`, unconditionally, with **no** second "is there work" condition beside the existing `hasPendingWork()` gate.
- `continuedSessionSubtitle(for:)` relocated verbatim into `DownloadClient+ContinuedSessionSubtitle.swift`; `DownloadClient+ContinuedSession.swift` is now 978 lines (was 997), `DownloadContinuedSessionTests.swift` still 995.
- Tests: new `ContinuedProgressNudgeTests` (one per stalled report; snap back both directions; the cap at 30 over 40 reports; a non-liveness identical report holds without incrementing or dipping), three new end-to-end cases in `ContinuedProcessingSessionFoldTests` asserting the REAL `task.progress.completedUnitCount`, `theFoldNeverExceedsTheTotal` re-pinned as `theFoldNeverReachesTheTotal`, and the heartbeat pin that every beat carries `nudgesWhenStalled == true` with zero in-flight sub-units while the seam push carries `false`.

## For the UAT record

**PD-3 — the attempt-count consequence of abandonment.** Abandonment counts as a networking failure of the ATTEMPT, not against `withRetry`/`retryLimit` (page transfers deliberately bypass those, `retriesRequest: false`). The retry path is `downloadPage`'s existing attempts loop, `autoRetryFailedPages ? 2 : 1`, which re-resolves the image URL through the failover request and so may reach a different image host. So: with auto-retry **on** (the default) a persistently starved page fails after two attempts ≈ 2 × (60–70 s) ≈ **120–140 s** plus resolution latency; with the user's auto-retry **off** it fails after one attempt ≈ **60–70 s**, like every other network failure under that setting — the setting governs. A transfer the SYSTEM has merely deferred (a discretionary background transfer waiting its turn) is treated exactly like a hung one: abandoned, retried, then failed and left retryable through the record's own retry surface. This is inside the owner's binding 60 s decision and is not special-cased. `withRetry`, `retryLimit`, `AppError` and `endPageTransfer`'s exit check are untouched.

**PD-6 — the 30-nudge cap re-derived, verdict: the cap holds.** This app performs no in-run quota back-off wait: a 509 arrives as a placeholder image, becomes `AppError.quotaExceeded`, is fatal at the account level, and the run fails — the queue moves or drains. So the "back-off can exceed five minutes" premise names no wait this app makes. The longest legitimate flat stretch is a page starving through its attempts under Half 1: ≈ 140 s plus resolution. Thirty nudges at the 10 s heartbeat ≈ **300 s**, more than double that. Past the cap the published count goes flat ON PURPOSE: the system reclaims the session roughly 30 s later and the existing expiry arm pauses schedulable downloads — a wedged queue cannot hold a session open forever, which is the guarantee the cap carries. Any future in-run wait longer than the cap (none exists today) must publish progress of its own or re-derive the number. This rationale is written into `ContinuedProgressNudge`'s doc comment.

## Deviations from plan

1. **`ContinuedProcessingSession`'s stall log reads the nudge count into a local first.** A `Logger` message's interpolations are autoclosures, so `\(nudge.count, …)` demanded an explicit `self` for capture semantics (compile error). Reading `let nudgeCount = nudge.count` before the call is the cleaner fix than annotating the capture, and the reason is recorded at the site. Log content unchanged.
2. **`ContinuedProgressNudgeTests` assigns each `record(...)` result to a local before `#expect`.** `#expect` takes an autoclosure and a `mutating` call cannot run inside one. Every assertion the plan specified is still made, on named locals.
3. **Fold Tests 5 and 7 open their session one page BEHIND the series they observe.** As specified (session opened at the series' own value), the very first push was itself a stalled report — `start` seeds the nudge with the caller's opening snapshot, so an identical first liveness report is correctly nudged and the observed series was `[4001, 4002, 4003]` rather than `[4000, 4001, 4002]`. Rather than weaken the pin or change `start`'s seeding (which adoption-before-any-push depends on, and which the plan itself specifies), the staging now opens at 3/10 so every observed push carries a measurement the store has not seen. The plan's expected series — `[4000, 4001, 4002]` and `[4000, 4500, 5000, 5250]` — are pinned exactly as written, and both cases document why the session opens where it does. The interaction is behaviour, not a defect: a liveness report identical to a session's opening measurement IS a stalled report.
4. **`DownloadContinuedSessionTests` took four one-line changes, not three.** The plan counted the three `updateProgress` seam calls; the `ProgressUpdate` expectation literal at line 68 is a fourth site (`inFlightSubunitCount: 250` → `subunits: .init(inFlightSubunitCount: 250)`). One line each, file still 995 lines.
5. **`anHonestMovingSeriesIsUnchangedByTheNudge` uses a nested `MovingStep` struct rather than a tuple array.** A mixed labelled/unlabelled tuple literal degrades to `(Int64, Int64)` and the project bans unlabelled multi-element tuple types at error severity.
6. **`theFoldNeverExceedsTheTotal` was renamed `theFoldNeverReachesTheTotal`** to match its new meaning, as the plan's `<behavior>` describes ("becomes 'the fold never REACHES the total'").
7. **Half 1 Test 2 reports 100 bytes at t=50 and 300 at t=100** rather than repeating the same figure, so the "slow but MOVING" control moves in credit as well as in time. The idle-time assertions the plan specifies are unchanged.

## Self-Check: PASSED

- All three created files exist on disk and are tracked in `d6079878`.
- Both commits are present: `2a2c5982`, `d6079878`.
- Working tree clean; no `.planning/` file is part of either commit.
