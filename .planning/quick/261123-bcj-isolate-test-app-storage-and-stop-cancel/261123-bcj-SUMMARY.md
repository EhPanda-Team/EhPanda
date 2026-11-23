---
phase: 261123-bcj-isolate-test-app-storage-and-stop-cancel
plan: 01
status: complete
---

# Quick task 261123-bcj Summary

## Task 1: tracer (done)

Commit `e8fce24fd` "Add a test trait that isolates app storage" (signed `G`, author and committer dates `+08:00`).
Ten files: `AppPackage/Package.swift`, `AppPackage/Sources/TestingSupport/IsolatedAppStorageTrait.swift` (new),
`AppPackage/Tests/AppModelsTests/IsolatedAppStorageTraitTests.swift` (new), the five converted suites
(InstallSignalSenderTests, CommentModerationReducerTests, MyTagsFeatureTests, LibraryPickerChoicePersistenceTests,
BlockedCommentUserTests), `Scripts/lint/app_storage_isolation.py` and `Scripts/lint/test_app_storage_isolation.py`
(both copied byte for byte from the planning reference copies, `cmp` exit 0).

`plan_head_before`: `f37c003345f85134d95a6a7cb870e723677d6504` (the planning commit; `e99c7bd60..f37c00334` touches
only the plan and context documents, so the plan's "HEAD" values hold).

### Simulator

`EhPanda iPhone Air (261123-bcj)`, UDID `2F71BB50-1060-482C-A287-0CB7761092F9` (iOS 27.2). Kept for Tasks 2 and 3.

### Baseline (untouched code, before any edit)

- BUILD baseline: `TEST BUILD SUCCEEDED`, 0 warnings, 0 errors (`warnings-baseline.txt` is empty).
- LINT baseline over LINT-ALL (27 directories): clean, empty output.
- PY baseline: `Ran 24 tests`, OK.
- TEST baseline: Passed 2130, failed 0 (no failure, so no re-run).
- LINT GATE baseline (`lint_check.py`): exit 0, "No compiler warning or error and no SwiftLint violation in any
  target of this repository."
- SCOPE `task1-start`: NEEDS 224, VIOLATIONS 231, 0 `[has]`, 224 `[missing]`, `READER_MODULES 17` line present.
- PY `task1-copy`: `Ran 36 tests`, OK.

### Task 1 gates

- Every file-content gate printed its EXPECT value: trait file (struct line, `isRecursive`, `@concurrent` signature,
  `withIsolatedAppStorage` signature, return line, single `removePersistentDomain`, `$0.defaultAppStorage =
  appStorage`, `public import Foundation`, `file-backed` count 2, one `app_storage_isolation.py` line), trait test
  (`@Suite(.isolatedAppStorage)` 1, `provideScope` 1, `withIsolatedAppStorage {` 1, `@Test` 3), the five suites
  (trait and import each 1; `func ensureSent()` 0; `.sender.ensureSent()` 13; `storage:` 0; `deinit` 0),
  `.module(.testingSupport)` 12 in Package.swift.
- Counters: IM_TESTS 109, SN_TESTS 16, AS_ST 160, TY_ST 9, IM_SRC 2 (all as expected).
- git status: trait file untracked 1, `AppPackage/Sources/` lines 1, `Scripts/` lines 2, `Package.resolved` 0.
- SCOPE `task1`: NEEDS 225, VIOLATIONS 222, 6 `[has]`, 219 `[missing]`.
- PY `task1`: `Ran 36 tests`, OK.
- BUILD task1: `TEST BUILD SUCCEEDED`, no new warning against the baseline.
- LINT task1 over TestingSupport, AnalyticsClientTests, AppFeatureTests, AppModelsTests, DetailFeatureTests,
  SettingFeatureTests: clean.
- TEST task1-focused (six suites): Passed 77, failed 0.
- TEST task1 (full FeatureTests, VisualSnapshotTests skipped): Passed 2133, failed 0 (baseline 2130 plus the three
  new trait tests).
- All touched Swift files are at most 120 columns and 1000 lines, except `AppPackage/Package.swift`, see Notes.

### Deviations from Plan

None in the code. Two observations, neither changing any file:

1. The line-count gate `awk 'END { exit NR > 1000 }'` "on every touched Swift file" cannot pass for
   `AppPackage/Package.swift` (1262 lines at HEAD, 1268 now). It is a pre-existing length that the baseline lint gate
   accepts, so it was read as not applying to Package.swift.
2. The executor ran in the orchestrator's own checkout on `claude/fervent-kowalevski-27fecc` (a non-protected branch,
   not an `agent-*` name), as instructed, so the per-agent-branch allow-list of the commit protocol did not apply.

### Notes for Tasks 2 and 3

- The other sessions' `xcodebuild` runs (SnapshotMatrix, another project) overlapped for long stretches, so every
  build and test run was started by a small wrapper that waits for `pgrep -x xcodebuild` and `pgrep -x xctest` to be
  empty and then starts at once (`.capture/261123-bcj/run-build.sh`, `run-test.sh`, `run-lintgate.sh`, `gates1.sh`).
  They live under the gitignored `.capture/`.
- Logs, summaries and scope reports are in `.capture/261123-bcj/` (`scope-task1-start.txt`, `scope-task1.txt`,
  `test-task1-summary.json`, ...).

## Task 2: bounded waits stop on cancellation (done)

Commit `514a13b00` "Stop cancelled test waits from spinning" (signed `G`, author and committer dates `+08:00`).
Three files under `AppPackage/Tests/DownloadsFeatureTests`: `DownloadFeatureTestHelpers.swift` (`drainDetailMetadataEffects`
and `waitUntil` conditions gain `!Task.isCancelled`), `DownloadFeatureTestSupportTypes.swift` (`waitUntilSettled`
condition, plus the four added doc lines on `sleepIgnoringCancellation`), `DownloadProcessCacheTests.swift`
(`waitUntilCacheCleared`). 8 insertions, 4 deletions; no line added to the 996-line helper file or the 310-line cache
test.

### Task 2 gates

- Executable-line counts: new `drainDetailMetadataEffects` condition 1, old 0; new `waitUntil` condition 1 (helpers) and
  1 (support types), old 0 and 0; `deadline.hasTimeLeft(), !Task.isCancelled {` in the cache test 1; `must also stop
  on` 1; helper file 996 lines, cache test 310 lines.
- `git diff --numstat`: Helpers `2 2`, SupportTypes `5 1`, ProcessCacheTests `1 1`, exactly three lines (no other
  file changed).
- SCOPE `task2`: NEEDS 225, VIOLATIONS 222, 6 `[has]`, 219 `[missing]` (unchanged from task1).
- BUILD task2: `TEST BUILD SUCCEEDED`, no new warning against the baseline.
- LINT task2 over `AppPackage/Tests/DownloadsFeatureTests`: clean.
- TEST task2 (full FeatureTests, VisualSnapshotTests skipped, includes DownloadSourceInventoryTests): Passed 2133,
  failed 0, no re-run needed.
- Commit protocol: `git log -1 --format='%G? %aI %cI'` printed `G` and two `+08:00` dates; no deletions in the commit.

## Task 3: every suite on isolated storage (done)

Commit `ff10b4406` "Isolate app storage in every test suite" (230 files, signed `G`, both dates `+08:00`), after
`0d275771b` "Drive the webtoon flush tests with TestClock" (D-5, one file, signed `G`, both dates `+08:00`).

### Gates on the tree that was committed

- Clean BUILD: succeeded, 0 warnings. D-5 alone on `514a13b00`: BUILD succeeded, SwiftLint on its file clean, one full
  run Passed 2133, failed 0.
- TEST, three full FeatureTests runs (VisualSnapshotTests skipped), load 106, 335 and 377 at start: each Passed 2133,
  failed 0, skipped 0.
- PY: Ran 39 tests, OK. Isolation `check`: exit 0, 0 breaks.
- LINT GATE (`lint_check.py`, every test plan's targets and SwiftLint over every module): exit 0, both isolation lines
  in the log. It ran before the commit, on the exact staged tree (`3269941ea`), not after it.
- Review of the diff: no `@Test` added or removed, `#expect` 70 removed and 70 added, no `.serialized`, suppression,
  skip or known issue added.

### The timeouts in the first set of runs (run 3 of 3) and D-5

Run 3 failed `WebtoonReadingTests/aCommittedPageDecidesAndTheHistoryRecordsTheVerdict()` and
`withTheOptionOffNothingIsDetectedOrRecorded()`, so Task 3 stopped. It was not rerun to get past the failure.

- `ReadingFeatureTests` alone did not reproduce it, with the megaYields on or off.
- Six alternating full runs per arm: `514a13b00` 0 of 6 failed, Task 3 1 of 6, the same two tests.
- One sampled run per arm: the preferences calls the trait makes were not on the sampled stacks, so they are not shown
  to be the cause. Up to 13 idle background-priority pool threads were waiting to be scheduled. The base run failed
  `ReadingReducerImageFetchTests/presentingAtASavedPageFetchesThatPageAndMarksItsBatchLoading()`, which read page 1 for
  a saved page 5 from the file-backed default storage, the fault Task 3 removes.
- Hops raised from 20 to 200, four alternating full runs per arm, criteria fixed beforehand: base 0 of 4, Task 3 2 of
  4. By those criteria (base fails at all, or base 0 and Task 3 at least 3) this is inconclusive.
- Over all full runs up to then, under mixed conditions: the two tests failed in 4 of 14 Task 3 runs and 0 of 11 base
  runs. No other test failed in the Task 3 runs.

The owner chose D-5 (`TestClock`). Whether Task 3 makes such timeouts more likely is **not established and not ruled
out**; `ImmediateClock` plus the one-second receive timeout is the weakness D-5 removes from these two tests. The only
other `ImmediateClock()` in the tests is `ReadingOrientationTests`, which did not fail in any run.

### Deviations from plan

1. `CaptureScenePreparation.isolate` keeps five parameters and reads `dependencies.defaultAppStorage` behind a
   `precondition` (orchestrator ruling; a sixth parameter breaks `function_parameter_count`). `install` sets
   `.inMemory` first.
2. A conversion leftover in LibraryNavigationTests (`let (initialState, store) = (initialState, store)`) was removed.
3. The plan's `cmp` gates against the planning reference copies of the two scripts were dropped after Task 1: the
   scripts were byte-identical and the copies were deleted.
4. Column lengths were checked by SwiftLint rather than the plan's awk line.
5. D-5 was added.

### Not done here

- VisualSnapshotTests (converted through `makeIsolatedAppStorage()`) and the UI tests compile in the lint gate but were
  not run.
- Nothing merged or pushed.
