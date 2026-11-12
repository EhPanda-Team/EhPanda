# Quick Task 260818-ek3: Fix G-15-2D/2E - Context

**Gathered:** 2026-08-18
**Status:** Ready for planning

<domain>
## Task Boundary

Two fixes decided by the owner on 2026-08-18 after the G-15-2D / G-15-2E investigation of
`Documents/Logs/ehpanda-20260815-194921-3.jsonl` (Run 3, iPhone 11, iOS 26.5.2, branch
`feature/gsd-phase-15`):

1. **G-15-2D liveness:** the continued-processing card must never look stalled to the system for
   30 s while a download is genuinely in flight. Today the card's progress is pushed ONLY when a
   page outcome lands (`DownloadClient+PageDownload.swift:177-222` →
   `flushDownloadProgress`, `DownloadClient+Persistence.swift:201-226`, throttle 8 pages / 0.4 s
   at `DownloadClient+Manager.swift:56-57`), and the default thread limit is 1
   (`Setting.swift:124`), so a single slow or held page freezes the numerator. Apple's SDK header
   (`BGTask.h`, `BGContinuedProcessingTask`) says tasks "that appear stalled may be forcibly
   expired"; Apple DTS states the threshold is ~30 s without a progress update ("Task has not
   reported progress within expected cadence, marking stalled"). Deliver: (a) intra-page
   (byte-level) progress reported through the session client while a page transfer is in flight;
   (b) a session heartbeat that re-pushes the current pair at ≤10 s while a session is live and
   has pending work; (c) the byte-progress instrumentation that discriminates the
   "background-created transfers are discretionary" hypothesis (log per page task: created
   foreground/background, time to first byte, and stalls of ≥10 s with zero bytes).

2. **G-15-2E logging artifact:** the "×3 expired / ×3 paused / ×3 entered foreground" lines were
   the SAME OSLog entries appended to the jsonl three times — a persistence race in
   `AppActivityLogsPumpReducer.swift`, not duplicate event delivery. Deliver: make
   fetch → append → cursor-advance one atomic, serialized step; stop losing the cursor advance when
   an effect is cancelled (TCA `Send` is a no-op after cancellation, the file append is not
   guarded); do not restart the pump on every `.active` bounce; and keep the pump running while a
   continued-processing session is live so background-side lines (the expiry, the pause sweep)
   reach disk even if the process is later killed.

</domain>

<decisions>
## Implementation Decisions

### Scope (owner-selected 2026-08-18)
- IN: intra-page progress + heartbeat (fix 1), log pump race + keep-alive (fix 2), and the
  discriminating byte-progress instrumentation.
- OUT (deferred, not rejected): routing page transfers through the foreground `URLSession` while a
  session is live. Apple's `isDiscretionary` doc: "For transfers started while your app is in the
  background, the system always starts transfers at its discretion". This is a documented mechanism
  consistent with the log shape but not device-confirmed; the byte-progress instrumentation from
  fix 1 is the discriminator, and the decision is taken after the next UAT.
- OUT: changing the D-11 "expiry ⇒ pause all schedulable" policy.

### Intra-page progress (fix 1a)
- Bytes come from `URLSessionDownloadDelegate.urlSession(_:downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:)`
  on `BackgroundPageDownloadDelegate` (`DownloadPageDownloader.swift:315+`), forwarded through the
  existing hub/coordinator seam. Write `completedUnitCount` directly from delegate callbacks; do
  NOT attach child `Progress` objects to the task's progress (Apple DTS thread 809182: child
  progress was LESS reliable in the field, FB21338185).
- The card's unit stays "pages" for the subtitle text (`continuedSessionSubtitle` is unchanged);
  only the numeric pair pushed to `updateProgress` gains sub-page resolution — e.g. scale both
  counts by a fixed factor (1000 per page) and credit each in-flight page with
  `floor(fraction × 1000)`, or an equivalent design the planner justifies. The subtitle must keep
  reading whole pages.
- Monotonicity contract is preserved per page while it is in flight; a page that fails or is
  cancelled drops its partial credit only through the existing D-G7-01 withdrawal bracket or an
  equivalent deliberate mover — no silent rewind, no floor pinning at a stale ceiling
  (`lastPushedCompletedPageCount` and the D-G2-01 retirement ledger must keep their documented
  meaning; read the doc blocks in `DownloadClient+ContinuedSession.swift` before touching them).
- Throttle intra-page pushes to about 1 per second per session; never more often than the existing
  0.4 s flush interval.
- Unknown `totalBytesExpectedToWrite` (`NSURLSessionTransferSizeUnknown`) credits nothing
  intra-page (whole-page credit on landing only) — but the heartbeat and the stall log still cover it.

### Heartbeat (fix 1b)
- One coordinator-owned repeating task per live session (start it when the session is granted or
  when `continuedClientSessionID` lands, cancel it in `markContinuedSessionEnded`), period ≤10 s,
  which calls the existing `pushContinuedSessionProgress(sessionID:)` so it goes through the same
  ownership guards and the same subtitle writer — no second push path (D-G2C-01: one definition,
  shared by every writer).
- Use the injected clock/`now()` seam already used by the flush throttle so tests can drive it.

### Instrumentation (fix 1c)
- Log via the existing DownloadCoordinator `Logger` at `.notice`, privacy-safe (no gallery values;
  page index and byte counts are fine; gids only through the existing `<mask.hash>` form). One
  line when a page transfer records its first bytes (`created: foreground|background`, elapsed ms),
  one line when a transfer has had zero bytes for ≥10 s, and one heartbeat summary line per push
  ONLY when the numerator changed or ≥30 s passed since the last summary — keep the jsonl small.
- Log NWPath status (wifi/cellular/other), `ProcessInfo.processInfo.isLowPowerModeEnabled` and
  `thermalState` at session start and inside the `.expired` arm.
- Follow `DownloadLogPrivacyInvariantTests` rules (that suite scans the module).

### Log pump (fix 2)
- One owner for the cursor and the file: serialize fetch + append + cursor-advance (an actor in
  `LogsClient`/the pump, or an equivalent single-writer design) so two overlapping effects cannot
  read the same stale cursor.
- Never write to disk without advancing the cursor in the same critical section; if an effect is
  cancelled between fetch and append, it must not append (guard on `Task.isCancelled`) — or, better,
  make the write itself the cursor owner so the question cannot arise.
- `.startPump` on an already-running pump must not restart it (the "App activity logging started"
  header must be emitted once per run — Run 4 shows two headers).
- While a continued-processing session is live, the pump keeps ticking in the background (the
  session keeps the process alive; the pump's 5 s OSLogStore read is cheap). Pause on background
  only when no session is live. The pump does not need to know about downloads directly — prefer a
  small published shared flag / stream the download client already exposes, or a delegate action
  from the coordinator, over coupling `SettingFeature` to `DownloadClient` — the planner decides.
- Existing tests for the pump/logs client stay green; add tests that pin: no duplicate lines under
  overlapping start/pause/start; cursor advance is atomic with the append; header emitted once.

### Claude's Discretion
- Exact scaling factor and where the sub-page term is folded into the pushed pair.
- Whether the heartbeat lives in `DownloadClient+ContinuedSession.swift` or a new file.
- Test file placement, matching the module's existing test suites.

</decisions>

<specifics>
## Specific Ideas

- Evidence timeline (seconds relative to Run 3 line 1): sessions granted→terminal 21.7 s drained,
  70.0 s drained, 10.8 s drained, 9.2 s drained, 115.4 s EXPIRED (backgrounded at 1091.1, expiry
  at +80.7 s), 52.9 s EXPIRED (backgrounded at 1417.2, expiry at +11.8 s — the stall began ~18 s
  BEFORE backgrounding), 142.8 s drained with 123 s of it in the background. Healthy foreground rate
  ≈ 0.77 pages/s; the two expired sessions landed almost nothing (throughput arithmetic).
- No network-fault signal in the log: no `networkingFailed`, no retry warnings, no page-failure
  lines during any session.
- Do not change the pushed subtitle's meaning (D-G2C-01) or the drain/terminal push choreography
  (D-G2B-01, D-G3-01).

</specifics>

<canonical_refs>
## Canonical References

- Apple SDK header `BackgroundTasks/BGTask.h` (BGContinuedProcessingTask doc comment: must report
  progress; stalled tasks may be forcibly expired).
- Apple Developer Forums 805554 (DTS: ~30 s stall threshold; report finer/byte progress),
  809182 (child Progress less reliable than direct completedUnitCount writes; FB21338185),
  806668 (cancel vs reclaim indistinguishable; expired task never resumed).
- Apple doc `URLSessionConfiguration.isDiscretionary` (background-started transfers are always
  discretionary) — context for the deferred decision only.
- `.planning/phases/15-continued-background-downloads/15-UAT.md` gaps G-15-2D and G-15-2E — the
  executor updates G-15-2E to closed with the mechanism above and adds the diagnosis to G-15-2D
  (status stays open until the next device UAT).

</canonical_refs>
