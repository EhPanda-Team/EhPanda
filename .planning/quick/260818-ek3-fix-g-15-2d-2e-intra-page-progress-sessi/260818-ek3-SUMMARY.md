---
phase: quick-260818-ek3
plan: 01
subsystem: downloads
tags: [continued-processing, background-downloads, logging, progress, telemetry]
status: complete
requires:
  - DownloadCoordinator's continued-session machinery (D-G2-01, D-G2B-01, D-G2C-01, D-G3-01, D-G7-01)
  - AppActivityLogsPumpReducer and LogsClient
provides:
  - RunLogDrain (single-owner atomic log drain)
  - DownloadClient.observeContinuedSessionLiveness / setIsInBackground
  - Sub-page (in-flight byte) credit on the continued-processing card
  - A 10 s continued-session heartbeat
  - Four grep-able telemetry line families for the next device UAT
affects:
  - AppReducer scene-phase handling
  - BackgroundProcessingClient.updateProgress seam (fifth argument)
tech-stack:
  added: []
  patterns:
    - "actor method with no suspension point as an atomicity primitive"
    - "Mutex-guarded per-task throttle on a URLSession delegate queue"
    - "any Clock<Duration> injection for a repeating coordinator task"
key-files:
  created:
    - AppPackage/Sources/LogsClient/RunLogDrain.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSessionLiveness.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PageTransferProgress.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSessionHeartbeat.swift
    - AppPackage/Sources/DownloadClient/DownloadEnvironmentProbe.swift
    - AppPackage/Tests/SettingFeatureTests/RunLogDrainTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionLivenessTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadContinuedSessionHeartbeatTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadPageTransferProgressTests.swift
    - AppPackage/Tests/DownloadsFeatureTests/ContinuedProcessingSessionFoldTests.swift
  modified:
    - AppPackage/Sources/LogsClient/LogsClient.swift
    - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsPumpReducer.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
    - AppPackage/Sources/BackgroundProcessingClient/BackgroundProcessingClient.swift
    - AppPackage/Sources/BackgroundProcessingClient/ContinuedProcessingSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ContinuedSession.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Manager.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Networking.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Execution.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Testing.swift
    - AppPackage/Sources/DownloadClient/DownloadPageDownloader.swift
    - .planning/phases/15-continued-background-downloads/15-UAT.md
decisions:
  - "PD-1 held: the sub-page term is folded by ContinuedProcessingSession, not by the coordinator, so the pushed pair stays whole pages and no floor writer was added."
  - "Task 2 landed as ONE commit rather than the plan's optional two, because ContinuedSessionPushRecord is required by step 2.5 and declared in the heartbeat file."
  - "The three new fold cases live in their own suite file: adding them to ContinuedProcessingSessionTests.swift crossed the 1000-line file_length ERROR gate."
  - "`.concatenate` is deprecated in this TCA version, so the background log/pause ordering is sequenced inside a single `.run` instead."
metrics:
  duration: ~150 min
  completed: 2026-08-18
  tasks: 3
  commits: 3
---

# Quick Task 260818-ek3: Fix G-15-2D/2E — Summary

Intra-page byte credit, a 10 s session heartbeat and four telemetry line families now keep the
continued-processing card from reading as stalled, and the activity-log pump's cursor moved into a
single-owner actor so the jsonl stops repeating itself.

## Commits

| Task | Commit | Subject |
|------|--------|---------|
| 1 | `e68ca491` | `fix(15): serialize the activity-log pump` |
| 2 | `1f9c3f34` | `feat(15): credit in-flight page bytes and heartbeat` |
| 3 | `abb61ac2` | `docs(15): record G-15-2D/2E fixes in UAT` |

Branch: `feature/gsd-phase-15`. Docs artifacts (PLAN/CONTEXT/SUMMARY/STATE) are deliberately not in
these commits; only Task 3's `15-UAT.md` edit is, as the plan specifies.

## Test counts

| Point | Tests | Failures |
|-------|-------|----------|
| Before this task (this tree) | 973 | 0 |
| After Task 1 | 982 | 0 |
| After Task 2 | 993 | 0 |

22 targets, 0 failures, 0 skipped, 13 pre-existing known issues throughout. 20 new cases: 4
`RunLogDrainTests`, 2 `AppActivityLogsReducerTests`, 2 `AppReducerScenePhaseTests`, 1
`DownloadContinuedSessionLivenessTests`, 3 `ContinuedProcessingSessionFoldTests`, 3
`DownloadContinuedSessionHeartbeatTests`, 5 `DownloadPageTransferProgressTests`.

Gates run before every commit: `xcodebuild build -project EhPanda.xcodeproj -scheme AppFeature
-destination 'generic/platform=iOS Simulator'` → BUILD SUCCEEDED, 0 warnings; the full package
suite as one invocation; standalone SwiftLint `--strict` clean over every touched test file
(`AppPackage/.build` deleted first).

File-length gates after the change: `DownloadClient+ContinuedSession.swift` 997,
`DownloadClient+Manager.swift` 961, `DownloadFeatureTestHelpers.swift` 992 (untouched).

## What landed

**Task 1 — G-15-2E, closed.** `RunLogDrain` is a `public actor` whose `drain(into:)` fetches,
appends and advances the cursor with no `await` between them; that absence is the atomicity. A
failed append leaves the cursor so the entries are re-offered, a failed fetch is a silent empty
tick, and both stay silent for the reason the old append did. `LogsClient`'s split
`fetchNewEntries` / `appendToRunFile` became one `drainNewEntries(url)` over one process-wide
drain, and `nextRunCount` became synchronous so `.startPump` derives the run inside the reduce step.
A second `.startPump` is a no-op (`isPumpRunning` replaced `cancelInFlight: true`), which is the Run
4 double-header's cause. The pump publishes to the shared live view by mutating the captured
`Shared` value rather than through `send`, because `Send` is a no-op after cancellation.
`DownloadClient.observeContinuedSessionLiveness` lets `AppReducer` pause the pump on `.background`
only when no session is live, and on the live-to-ended transition while backgrounded.

**Task 2 — G-15-2D, fix landed (gap stays open until the next device UAT).**
`BackgroundProcessingClient.updateProgress` gained `inFlightSubunitCount`, and
`ContinuedProcessingSession` scales: `total * 1000` with
`min(completed * 1000 + inFlight, total * 1000)`, seeded the same way at adoption. The coordinator's
pushed pair is still whole pages. `didWriteData` now reaches the coordinator through a delegate-side
250 ms per-task throttle; credit is monotone by `max`, retired inside `flushManifestPageProgress`
alongside the run measurement's own subtraction, withdrawn by name at a page's `.failure`, and
dropped at `retireRunProgressBasis`. Intra-page pushes are throttled to 1/s on the injected `now`
seam. A 10 s coordinator-owned heartbeat re-pushes the current pair through the same
`pushContinuedSessionProgress`, gated on `hasPendingWork()` and cancelled in
`markContinuedSessionEnded`.

**Task 3.** `15-UAT.md`: G-15-2E is `status: closed` with the mechanism and its pinning tests;
G-15-2D stays `open` with the landed fix, the grep-able prefixes, the deferred foreground-routing
decision and what the next device run must show. Frontmatter `updated` / `awaiting` refreshed.

## Log message prefixes shipped

- `Page transfer first bytes, gid: <mask.hash>, page N, created foreground|background, <ms> ms to first byte, expected <bytes> bytes.`
- `Page transfer starved, gid: <mask.hash>, page N, created foreground|background, <ms> ms without bytes, still transferring|ended.`
- `Continued-session heartbeat: C / T pages, S in-flight subunits, G galleries, X transfers in flight.`
- `Continued-session environment at start|expiry: network <kind>, low power <bool>, thermal <state>.`

Gid is the only masked value; every other field is an integer or a closed symbol name and goes out
`.public`.

## Census and table edits

- **`DownloadLogPrivacyInvariantTests`** — the one deliberate table edit:
  `"DownloadClient+PageTransferProgress.swift": 2` added, `expectedHashMaskedTotal` 11 → 13. The
  two sites are the first-bytes helper and the starved helper; the starved helper is shared by both
  of its detectors, so adding the second detector added no masked site.
- **`DownloadSourceInventoryTests`** — no census moved. Verified by the suite passing unchanged:
  no new `schedulableDownloads()` call (the heartbeat uses `hasPendingWork()`), no new
  `lastPushedCompletedPageCount` assignment, no new `runProgressBases` mention in source, no new
  bracket caller, queue entrance, scheduling block, pending-page-list evaluation or
  `discardingRejected: true` site, and no new hand-built client double (`updateProgress:` label
  count in the double-bearing trees is unchanged at 5).

## Deviations from plan

1. **[Rule 3 — blocking] `.concatenate` is deprecated.** The plan specified
   `.concatenate(logEffect, .send(.appLogsPump(.pausePump)))` for the background arm. In TCA 1.26
   with this project's deprecation traits that emits a warning, and the build gate demands 0
   warnings. The same ordering intent is expressed by sequencing inside one `.run`: log, then
   `await send(.appLogsPump(.pausePump))`. Commit `e68ca491`.
2. **[Rule 1 — plan detail wrong against source] Baseline test count.** The plan states a 980-test
   baseline (quoted from STATE.md). The true baseline in this tree is **973**: commit `81a2b6d5`
   ("drop the logs directory migration") deleted `LogsDirectoryMigrationTests.swift` after that
   figure was recorded. 973 + 20 new = 993, which is what the suite reports.
3. **[Environment] Simulator destination.** `-destination 'platform=iOS Simulator,name=iPhone 17e'`
   resolves `OS:latest` = 26.5, which is not installed for that device here. Every run used
   `'platform=iOS Simulator,name=iPhone 17e,OS=26.4.1'`. No code impact.
4. **[Plan option not taken] Task 2 is one commit, not two.** The plan allowed splitting after step
   2.5. `ContinuedSessionPushRecord` is required by 2.5 and the plan places its declaration in the
   heartbeat file (step 2.6), so the split would have meant changing
   `pushContinuedSessionProgress`'s signature twice. Landed atomically instead.
5. **[Rule 3 — blocking] New suite file for the fold cases.** Adding the three
   `ContinuedProcessingSession` fold cases to `ContinuedProcessingSessionTests.swift` took it to
   1019 lines against the 1000-line `file_length` ERROR. They live in
   `ContinuedProcessingSessionFoldTests.swift`; the original file is back at 914 lines with only the
   14 scaled assertions changed.
6. **[Rule 3 — blocking] `applyPageTaskOutcome` parameter count.** Adding `gid:` as the plan
   requires took it to 6 parameters, tripping `function_parameter_count`. The two `inout Bool`
   flags were folded into the `PageDownloadControl` value they already live in at the call site (5
   parameters). Suppressing the rule was not an option.
7. **[Rule 3 — blocking] `subunitsPerUnit` needed `nonisolated`.** `ContinuedProcessingSession` is
   `@MainActor`, so a plain `public static let` is main-actor isolated and unreachable from the
   coordinator actor.
8. **[Rule 2 — undeclared files, dependency completeness]** Three test files outside
   `files_modified` needed changes the new seams make mandatory:
   `DownloadAutomationTests.swift` (a `downloadClient = .noop` for the launch case, which now
   subscribes to the liveness stream, and a `setIsInBackground` stub for the scene-phase case);
   `DownloadContinuedSessionTests.swift` (three `updateProgress` call sites and one `ProgressUpdate`
   initializer at the new arity). Each is a stub for a dependency the test already implicitly used.
9. **[Rule 3]** `DownloadPageTransferProgressTests` needed a small `FrozenDate` final class: `Mutex`
   is non-copyable and cannot be a stored property of the fixture struct.

Nothing else deviated. The deferred foreground-`URLSession` routing was not implemented and the
D-11 expiry policy is untouched, as instructed. The doc blocks D-G2-01, D-G2B-01, D-G2C-01,
D-G3-01 and D-G7-01 are preserved; the only additions to them are one sentence on
`pushContinuedSessionProgress` (the sub-page term travels beside the pair) and one on
`flushManifestPageProgress` (the atomic trade).

## Threat surface

No new surface beyond the plan's register. T-Q-01 is mitigated as specified (one masked gid per
telemetry helper, explicit `privacy:` on every interpolation, deliberate table edit); T-Q-02 by the
delegate-side 250 ms throttle plus the 1 s push throttle and the 10 s heartbeat; T-Q-03 by
`RunLogDrain`'s suspension-free critical section, pinned by `RunLogDrainTests`; T-Q-04 by the
client-side clamp, pinned by `theFoldNeverExceedsTheTotal`. `DownloadEnvironmentProbe` reads
`NWPath`, `isLowPowerModeEnabled` and `thermalState` and surfaces them only as closed symbol names;
no gallery value or free-form system string reaches a log. No new packages: `Network` and
`Synchronization` are Apple system frameworks.

## Known stubs

None.

## Left open

- **G-15-2D stays `open`.** Every claim above is compile-time and unit-test evidence; none of it is
  device-confirmed. The next UAT round of test 2 on this build is what closes or reopens it.
- **The deferred decision** on routing page transfers through the foreground `URLSession` while a
  session is live, to be taken after that round reads the `created background` field and the
  TTFB / starvation durations.
- **G-15-11** remains open and untouched by this task.
- The heartbeat's summary-suppression rule (log only on numerator change or after 30 s) is exercised
  through its firing path but has no dedicated case for the suppression branch itself.

## Self-Check: PASSED

All ten created files exist on disk; all three commit hashes resolve in `git log`.
