---
phase: 261123-1dk-download-queue-order-and-queue-operation
plan: 01
subsystem: download-queue
tags: [downloads, queue, voiceover, context-menu]
requires: []
provides:
  - waiting downloads listed in the persisted queue's run order, with a VoiceOver place on the badge
  - Download Now, Download Next, Move Up, Move Down and Download Last in the Downloads context menu and VoiceOver actions
key-files:
  created:
    - AppPackage/Sources/AppModels/Download/DownloadQueuePlace.swift
    - AppPackage/Sources/AppModels/Download/DownloadQueueOperation.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+QueueOperations.swift
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+Persistence.swift
    - AppPackage/Sources/DownloadClient/DownloadQueueStore.swift
    - AppPackage/Sources/DownloadsFeature/DownloadGalleryItem.swift
status: complete
commits: 3
plan_head_before: 5657fc9739eccffce64c7725cfed83747c12c42e
plan_head_after: b38e060a956af2c7508d370b72de881c833921e5
actuals:
  tasks: 3
  commits: 3
---

# Quick 261123-1dk: download queue order and queue operations

The Downloads list now shows the waiting group in the order downloads will run, VoiceOver reads a waiting badge's
place, and waiting or paused items offer Download Now, Download Next, Move Up, Move Down and Download Last.

## Commits (signed `G`, author and committer dates +08:00)

| Task | Hash | Message |
|---|---|---|
| 1 | cffaa74c4 | List waiting downloads in queue order |
| 2 | 0cd5287e6 | Add queue reordering to the downloads menu |
| 3 | b38e060a9 | Let Download Now interrupt the active download |

## Baseline (untouched tree: source of 531db50b1; HEAD 5657fc973 is its docs-only child)

- Simulator `EhPanda iPhone Air (261123-1dk)` created for the run.
- BUILD: succeeded, 0 warnings, 0 errors. LINT over the nine directories: empty.
- TEST (FeatureTests, skipping VisualSnapshotTests): Passed 2100, failed 0.
- LINT GATE baseline: exit 0 (after the absolute-path amendment, see deviations).

## Per-task gates

| Task | `ex` gates | Catalog diff | BUILD (new warnings) | LINT | TEST |
|---|---|---|---|---|---|
| 1 | all at EXPECT | 306/0 | succeeded (0) | empty | task1: 2106 passed, 2 failed (flake); task1-rerun: Passed 2108, 0 failed |
| 2 | all at EXPECT | 205/0 | succeeded (0) | empty | task2: 2120 passed, 1 failed (flake); task2-rerun: 2120 passed, 1 failed (flake); gate met under the `.inMemory` rule |
| 3 | all at EXPECT | 41/0 | succeeded (0) | empty | task3: livelock, terminated (see deviations); task3b: Passed 2130, 0 failed |

Task 3 `ex` values: `interruptActiveRun` signature, `liveRunProgressBasis(gid: interrupted)`, `await interruptedTask.value`,
`activeGalleryID = nil`, `activeTask = nil` and `queuedModes[interrupted] = .repair` each 1; `Scheduling(gid:`,
`queueStore.enqueue(` and `removeItem` each 0 in `+QueueOperations.swift`; `privacy: .private(mask: .hash)` 2; "Download
Now's interrupt" 3 in `+Execution.swift` and 1 in `+Scheduling.swift`; the privacy test reads per-file count 2 and total 17.
`DownloadSourceInventoryTests.swift` is unchanged from 531db50b1, so the block census (5) and the queue-entrance census (5)
stand, and it passes in every complete run. Every touched Swift file is at most 1000 lines.

## Final gate and cleanup

- LINT GATE final: exit 0 ("No compiler warning or error and no SwiftLint violation in any target of this repository.").
- Simulator `EhPanda iPhone Air (261123-1dk)` deleted; `simctl list` shows nothing of that name. (`simctl shutdown`
  answered code 405, already shut down.)
- `.capture/` is gitignored; nothing under it was committed.

## Deviations from plan

1. **LINT GATE command.** The plan's relative `--cloned-packages .capture/...` made `lint_check.py` fail with
   `FileNotFoundError` (it runs swiftlint from each module's directory). The orchestrator amended PLAN.md line 278 to
   `--cloned-packages "$PWD/.capture/261123-1dk/dd/SourcePackages"`; used for the baseline rerun and the final gate.
2. **Pre-existing `UserDefaults.inMemory` flakes in full TEST runs** (orchestrator diagnosis: Sharing backs `.inMemory`
   with a file whose raw reads go stale under parallel simulator load; unrelated to this task and tracked separately).
   Each failing test builds its state over `.inMemory`:
   - task1: `AnalyticsClientTests/InstallSignalSenderTests/everySuccessStatusSettles(status:)` ("Expectation failed:
     harness.state.settled", `settled: false`) and `theFirstSendIsOneRequestInTheSDKWireFormat(channel:)` (`harness.state`
     `settled: false`). A targeted `-only-testing:AnalyticsClientTests` run passed 116/0; the full rerun `task1-rerun`
     passed 2108/0 and Task 1 was committed on it.
   - task2: `DetailFeatureTests/CommentModerationReducerTests/ownCommentsGetNoReportOrBlock()` ("Must handle 3 received
     actions before sending an action", `UserDefaults.inMemory` at CommentModerationReducerTests.swift:372); a targeted
     `-only-testing:DetailFeatureTests` run passed. task2-rerun failed
     `SettingFeatureTests/MyTagsFeatureTests/turningATagSetOffSendsItAtOnceAndTakesThePage()` (`isEnabled` false expected,
     true actual; `UserDefaults.inMemory` at MyTagsFeatureTests.swift:324). No target Task 2 touches failed and every test
     it adds passed, so under the orchestrator's rule the gate was met and Task 2 committed.
3. **QueueRunGate hold (approved deviation).** The plan's held-cancelled-run loop (`while held { await
   sleepIgnoringCancellation(...) }`) livelocks: inside a cancelled task `Task.sleep` returns at once, so the loop never
   suspends and starves its executor. The first full TEST of Task 3 hung (xctest worker at ~100% CPU for 34 minutes, stack
   at `QueueRunGate.taskRunner`, `swift_willThrow` under `Task.sleep`) and was terminated by the executor (exit 143). The
   orchestrator approved a continuation-based hold, test-support only: `State` gains `heldRuns`, the run awaits
   `withCheckedContinuation` (resuming at once when no hold applies), and `releaseCancelledRuns()` and `stop()` take the
   held continuations inside the lock and resume them outside it. The type doc states why. task3b then passed 2130/0, all
   twelve Task 3 interrupt cases included.
4. **Step 8 edge, observed and left as written.** `performQueueOperation` returns success without converging when
   `order == waiting`. For Download Now that is the first waiting item while nothing is active; a non-idle queue with no
   active download is not reachable in normal flow, and no plan case exercises it.
5. A compile error in my own Task 2 test draft (`#expect(throws:)` needed `await`) and a 124-column line in a Task 3 test
   draft were fixed before the gates; not plan deviations.

## Design notes

- The waiting order comes from one place: `waitingQueueGIDs()` (the persisted queue the scheduler walks, filtered through
  `displayStatus(for:)`), read by the snapshot comparator, every badge's VoiceOver place and `performQueueOperation`.
- `DownloadQueueStore.reorder(_:)` is a slot-preserving permutation: it never adds or removes an entry, so it is not a
  queue entrance.
- Download Now takes no scheduling block; it cancels the active run, clears the slot, awaits the run, then converges
  (`notifyObservers()` and `scheduleNextIfNeeded()`). The interrupted gallery stays queued directly after the selected one
  with its saved pages, and a `.redownload` or `.update` run that had already replaced its folder continues as `.repair`.
- No queue operation deletes anything, enqueues directly or sends an analytics event (orchestrator decision OQ-5).

## For the owner

- Open question 7 of the plan: on the list row, SwiftUI appends the queue VoiceOver actions after the swipe-derived ones,
  so they are not adjacent to Pause/Resume there. Please check the row's VoiceOver action list on device.

## Known Stubs

None.

## Threat Flags

None. The new log notices carry the gallery id as `.private(mask: .hash)` and the operation name as `.public`
(T-261123-1dk-06; `DownloadLogPrivacyInvariantTests` pins the counts at 2 and 17).

## Self-Check: PASSED

Commits cffaa74c4, 0cd5287e6 and b38e060a9 are ancestors of HEAD and were measured with
`git rev-list --count 5657fc9739eccffce64c7725cfed83747c12c42e..HEAD` = 3; created files exist.
