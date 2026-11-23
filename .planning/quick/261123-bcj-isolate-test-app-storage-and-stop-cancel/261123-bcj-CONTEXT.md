---
quick_id: 261123-bcj
date: "2026-11-23"
source: owner answers, 2026-11-23 (one AskUserQuestion round), after quick task 261123-1dk
---

# Quick task 261123-bcj: owner decisions (locked)

Downstream agents must not revisit the decisions below. Anything they do not settle goes back to the
orchestrator; it is not the agent's to choose.

## Background: what failed and why (orchestrator investigation, 2026-11-23)

During 261123-1dk's full FeatureTests runs, a different test failed in each run, and every one of them
builds its storage on Sharing's `UserDefaults.inMemory`:

- `AnalyticsClientTests/InstallSignalSenderTests`: `everySuccessStatusSettles(status:)` and
  `theFirstSendIsOneRequestInTheSDKWireFormat(channel:)` (task1 run).
- `DetailFeatureTests/CommentModerationReducerTests/ownCommentsGetNoReportOrBlock()` (task2 run). The test
  writes `displayName` through one `@Shared(.user)` inside a `withDependencies` closure; that reference dies with
  the closure; the reducer state then creates a new `@Shared(.user)`, which loads from the suite and got the
  old value, so the signed-in user's own comment was treated as someone else's and the report form opened.
- `SettingFeatureTests/MyTagsFeatureTests/turningATagSetOffSendsItAtOnceAndTakesThePage()` (task2 rerun). The
  value lives in a `@Shared(.user)` the whole time, yet `isEnabled` flipped back to its earlier value, most
  likely through the app-storage key's external-change subscription reloading a stale read into the live
  reference.

Root cause: on iOS 17 and later, Sharing's `UserDefaults.inMemory` (`swift-sharing`,
`Sources/Sharing/SharedKeys/AppStorageKey.swift:629`) names its suite
`NSTemporaryDirectory() + "co.pointfree.Sharing.<UUID>"`, which makes it a file-backed suite. The
`defaultAppStorage` dependency's `testValue` is the same `.inMemory`. In the simulator test process, under
parallel load, such suites can stop reflecting new writes and later reads return an earlier value. Plain-named
suites (`UserDefaults(suiteName: "<name>-\(UUID())")`) were never stale in the 2026-11-18 stress probe; commit
`e2427c16b` fixed two raw-read suites this way. The earlier belief that reads through `@Shared` are unaffected
is wrong: a fresh `@Shared` reference loads from the suite, and the external-change subscription writes back
into a live one.

Extent: about 130 `.inMemory` sites in about 50 test files (`grep -rn "\.inMemory" AppPackage/Tests`), plus tests
that never set `defaultAppStorage` and so use the dependency's `testValue`. The two `Sources` uses
(`AppFeature/UITestSupport/UITestAutomation.swift`, `AppFeature/UITestSupport/CaptureScenePreparation.swift`) run
inside the UI-test app, not in parallel unit tests, and stay as they are.

## Decision D-1 (owner): isolate every test's app storage, project-wide

- Add a Swift Testing trait in `TestingSupport` that gives each test case its own plain-named `UserDefaults`
  suite as `defaultAppStorage` for the duration of the case and removes that suite's persistent domain when the
  case ends. Precedent for the shape: swift-dependencies' `_DependenciesTrait`
  (`DependenciesTestSupport/TestTrait.swift`, `TestScoping`, recursive suite trait). Swift tools 6.4.
- Replace every `.inMemory` in the Swift Testing test targets with the trait-provided storage. `TestStore`
  builds its reducer inside `withDependencies` on top of the current task-local values
  (`swift-composable-architecture` `TestStore.swift:537`), so a store inherits the trait's storage unless a test
  overrides it.
- Suites that never set `defaultAppStorage` but exercise app-storage-backed `@Shared` keys get the trait too, so
  the dependency's file-backed `testValue` is not used by any test that persists through app storage.
- XCTest targets (the `VisualSnapshotTests` files that use `.inMemory`) cannot take a Swift Testing trait; give
  them the same isolation through their own setUp/tearDown, with the same plain-named suite and domain removal.
- Add a SwiftLint custom regex rule, scoped to the test directories, that bans `.inMemory` user defaults in tests,
  with a message pointing at the trait, so the class cannot come back. It must not match `FileStorage`'s
  `.inMemory` file system if that is used anywhere (check; scope the regex accordingly).
- Two tests in one case that deliberately share storage (for example `aRevealDoesNotOutliveTheScreen`) keep
  sharing it through the trait's one per-case suite.
- Update the existing `e2427c16b` tests (`LibraryPickerChoicePersistenceTests`, `BlockedCommentUserTests`) to the
  trait as well, so there is one pattern.

## Decision D-2 (owner): bounded waits stop when the waiting task is cancelled

- The test-helper hang itself was fixed in `b38e060a9` (continuation-based `QueueRunGate` hold). An audit of the
  other `sleepIgnoringCancellation` loops in `AppPackage/Tests/DownloadsFeatureTests` found no other unbounded
  spin: the run-holding loops exit on `Task.isCancelled`.
- Four deadline-bounded wait helpers keep polling after cancellation, spinning at full speed until their deadline
  (up to 30 s) because a cancelled `Task.sleep` returns at once: `waitUntil` (`DownloadFeatureTestHelpers.swift`
  ~:993), `waitUntilSettled` (`DownloadFeatureTestSupportTypes.swift` ~:741), `waitUntilCacheCleared`
  (`DownloadProcessCacheTests.swift` ~:277) and `drainDetailMetadataEffects` (`DownloadFeatureTestHelpers.swift`
  ~:138). Each loop condition also stops on `Task.isCancelled`; each helper then reports its normal outcome
  (`waitUntil` fails its `#require`, `waitUntilSettled` returns the condition).
- `sleepIgnoringCancellation`'s doc comment states the requirement: a loop that calls it must check cancellation
  or it spins.

## Constraints (CLAUDE.md, memory)

- No `.serialized`, no runner flags, no single-worker caps; Swift Testing stays parallel.
- No lint suppression or rule disabling. Read the root `.swiftlint.yml` first; new modules (none expected) need a
  `.swiftlint.yml` with `parent_config`.
- Reducers keep the `Feature` suffix (none expected).
- Doc-comment the WHY of the trait (file-backed `.inMemory` goes stale under parallel load) so it does not read
  as over-engineering.
- One atomic commit per task, message of 50 characters or fewer, signed, dates +08:00
  (`TZ=Asia/Shanghai git commit`), no attribution lines. Do not merge or push.
- Gate: clean build, lint over touched directories, the project's lint gate, and the full FeatureTests plan
  (skipping VisualSnapshotTests as before) run repeatedly. Because this task removes the flake class, a
  `.inMemory`-style stale-read failure is now a real failure, not a pass under the 261123-1dk rule.
- One `xcodebuild test` at a time; never kill a process the run did not start.

## Decisions after planning (2026-11-23)

### Decision D-3 (owner): the two Sources helpers take their storage from the caller

Correction to D-1's premise: `CaptureScenePreparation.isolate` and `UITestAutomation.configureVisualTestHost`
(`AppPackage/Sources/AppFeature/UITestSupport/`) are also called from unit tests (CaptureRouteTests,
CaptureTagTranslationTests, CaptureSceneTests, CaptureLiveTextRecordTests, CaptureDownloadTests, UITestStubTests),
so the file-backed suite they build reaches parallel unit tests. Both functions now receive the `UserDefaults` from
their caller instead of building `.inMemory` themselves. Unit-test callers pass the trait's per-case storage; the
UI-test app's own call site creates its storage there, as it does today, so the app's UI-test behaviour is
unchanged. After this, no test path uses a file-backed suite; the Sources `.inMemory` count may drop accordingly.

### Decision D-4 (owner): the scope check becomes a permanent lint-gate check

The planning-time scope tool moves into `Scripts/lint` as a maintained check that the project's lint gate runs:
every Swift Testing suite that reaches app storage carries `.isolatedAppStorage`, no other suite does, every file
that carries it imports TestingSupport, and every such test target links TestingSupport. It gets its own tests
next to the existing `Scripts/lint/test_lint_check.py`, and the lint gate fails when the check fails.

### Orchestrator calls on the planner's other questions

- XCTest granularity: one `makeIsolatedAppStorage()` call per former `.inMemory` site, each removed at teardown
  through `addTeardownBlock`. This keeps per-coordinate isolation in the matrix loops and satisfies D-1's
  "setUp/tearDown" intent (the teardown is XCTest's own).
- The other existing plain-named suites (AppReadingFlushTests, ReadingReducerFlushTests, WebtoonReadingTests,
  TagDatabaseDigestTests) move to the trait too: one pattern.
- HostedViewTests stay out of scope (cannot link TestingSupport; read-only use of app storage). The D-4 check
  states the exclusion explicitly.
- The trait's own test lives in AppModelsTests, which needs TestingSupport anyway for its converted suites.
- Execution: a fresh executor per task.

### Decision D-5 (owner, 2026-11-23): the two timing-out webtoon tests move to `TestClock`

`WebtoonReadingTests/aCommittedPageDecidesAndTheHistoryRecordsTheVerdict()` and
`withTheOptionOffNothingIsDetectedOrRecorded()` timed out in Task 3 full runs. They wait up to one second for work that
`ImmediateClock.sleep` puts behind 20 background-priority hops. They use a `TestClock` the test advances, in a commit of
their own before the Task 3 commit. Task 3's three zero-failure full runs start over after it.

What the evidence says: over all full runs, under mixed conditions, the two tests failed in 4 of 14 Task 3 runs and 0 of
11 runs of `514a13b00`. The amplified experiment, with criteria fixed beforehand, read 0 of 4 against 2 of 4, which
those criteria call inconclusive. Task 3 may make the timeout more likely; that is neither established nor ruled out. A
timeout in any other test in the three runs is a STOP.
