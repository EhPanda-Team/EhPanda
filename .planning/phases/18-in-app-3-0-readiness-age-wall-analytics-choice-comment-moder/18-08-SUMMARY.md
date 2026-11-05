---
phase: 18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder
plan: "08"
subsystem: ui-test-support
tags: [xcuitest, uitest-launch-keys, reader, debug-only]

requires: ["18-02", "18-04", "18-07"]
provides:
  - "DEBUG-only launch keys: EHPANDA_UITEST_FIRST_LAUNCH=analytics, EHPANDA_UITEST_REQUEST_LOG, EHPANDA_UITEST_BLOCKED_AUTHORS, EHPANDA_UITEST_DISPLAY_NAME, EHPANDA_UITEST_DROP_INITIAL_IDLE"
  - "A deterministic block list and display name at every stubbed launch"
  - "`LocalizedLaunch`: six locales at default size or AX5, with kept `<screen>-<locale>-<size>` screenshots"
  - "`ReaderRebuildUITests`: committed G1/G2 tests (D-19), including the R5-1 drop-idle variant"
affects: [18-09, 18-10, 18-11, 18-12, reader]

actuals:
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "UI-test options set once at launch by AppFeature's automation (`ReaderUITestOptions`); feature modules read no launch key"

key-files:
  created:
    - EhPandaUITests/Support/LocalizedLaunch.swift
    - EhPandaUITests/ReaderRebuildUITests.swift
  modified:
    - AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift
    - AppPackage/Sources/AppFeature/UITestSupport/UITestStubURLProtocol.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Tests/AppFeatureTests/UITestStubTests.swift
    - EhPandaUITests/Support/UITestConstants.swift
    - EhPandaUITests/Support/ReaderPageProbe.swift

key-decisions:
  - "The block-list and display-name preset applies to stubbed launches that are not the visual host. The visual host and the capture launches use in-memory storage that is already empty, and a capture launch ignores the new keys"
  - "An absent or malformed EHPANDA_UITEST_BLOCKED_AUTHORS means an empty list; an absent EHPANDA_UITEST_DISPLAY_NAME means no display name. Every stubbed launch is deterministic, whatever the test before it blocked"
  - "EHPANDA_UITEST_FIRST_LAUNCH=analytics stores the age answer and clears the level. Any other or empty value keeps 18-02's answered preset"
  - "ReadingFeature reads no launch key: AppFeature sets `ReaderUITestOptions.dropsInitialIdleReport` at launch, and that is the default of 18-07's `dropsReaderInitialIdleReport` environment seam"
  - "`LocalizedLaunch` uses launch arguments only (-AppleLanguages, -AppleLocale, -UIPreferredContentSizeCategoryName), so no simulator setting changes"
  - "A failed request-log write is ignored, so a test's log can never break the stubbed app"

patterns-established:
  - "A UI test isolates its storage through launch keys, never through test order (AGENTS.md, Test parallelism)"

requirements-completed: []

coverage:
  - id: T1
    description: "The five DEBUG launch keys and LocalizedLaunch"
    verification:
      - kind: unit
        ref: "AppFeatureTests/UITestStubTests on the phone: 44 test cases passed, 0 failed (18 from the new key cases)"
        status: pass
      - kind: grep
        ref: "Every new key string is inside a #if DEBUG block (listed under Verification)"
        status: pass
    human_judgment: false
  - id: T2
    description: "ReaderRebuildUITests for G1 (forced refresh, direction during auto-play) and G2 (LTR/RTL), plus the drop-idle variant"
    verification:
      - kind: automated_ui
        ref: "UITests plan, ReaderRebuild + ReaderPageSync + ReadingOrientation + DuoReadingPanel on phone and pad, 0 failures, 0 Repetition"
        status: pass
    human_judgment: false

duration: about 1h
completed: 2026-11-05
status: complete
---

# Phase 18 Plan 08: DEBUG launch keys and the G1/G2 reader UI tests Summary

**The phase's later UI tests can now open the real first-launch gate, record the requests the stub sees, preset a
block list and a signed-in name, and drop the reader's first idle report, all from DEBUG-only launch keys. The Phase 17
reader gaps G1 and G2 are guarded by four committed UI tests that pass on both devices.**

## Performance

- **Duration:** about 1h
- **Completed:** 2026-11-05
- **Tasks:** 2
- **Files modified:** 8 (2 created)

## Accomplishments

- `UITestAutomation` reads five new keys, all inside its `#if DEBUG` block and only for stubbed launches:
  - `EHPANDA_UITEST_FIRST_LAUNCH=analytics` stores the age answer and clears the level. The launch then opens on the
    analytics choice. `show` and an absent key behave as in 18-02.
  - `EHPANDA_UITEST_BLOCKED_AUTHORS` is a JSON array of names written to `@Shared(.blockedCommentAuthors)` at every
    stubbed launch. Absent or malformed means empty.
  - `EHPANDA_UITEST_DISPLAY_NAME` sets `User.displayName` for own-comment tests. Absent means none.
  - `EHPANDA_UITEST_REQUEST_LOG` names a file. `UITestStubURLProtocol` appends one `METHOD host path` line per
    request it sees.
  - `EHPANDA_UITEST_DROP_INITIAL_IDLE=1` sets `ReaderUITestOptions.dropsInitialIdleReport`, the default of the
    reader's `dropsReaderInitialIdleReport` seam from 18-07.
- `EhPandaUITests/Support/LocalizedLaunch.swift` launches the stubbed app in the six locales at the default size or
  AX5, and attaches a kept screenshot named `<screen>-<locale>-<size>` for the UI-SPEC C-3 check in 18-09 and 18-10.
- `ReaderRebuildUITests` rebuilds the pager mid-read by each route and requires, through `ReaderPageProbe`, that the
  indicator names the page on screen:
  - `testReloadAllImagesThenATurnKeepsTheIndicatorOnThePageShown` (G1, forced refresh): Reload All Images at a
    middle page, then one edge-tap turn right away, which must land on the next page.
  - `testReloadAllImagesThenATurnKeepsTheIndicatorOnThePageShownWithoutTheFirstIdleReport`: the same route with
    `EHPANDA_UITEST_DROP_INITIAL_IDLE=1` (R5-1).
  - `testChangingDirectionDuringAutoPlayKeepsTheIndicatorOnThePageShown` (G1, direction).
  - `testSwitchingLeftToRightAndRightToLeftKeepsThePageInSync` (G2): left to right, right to left, then left to
    right again at a middle page, with one next-page tap under each direction.
- `ReaderPageProbe` gained the right-to-left direction, a direction-aware `tapNextPageZone(under:)` and
  `reloadAllImages()`.

## Task Commits

1. **Task 1: DEBUG launch keys:** `d4286af36` (feat)
2. **Task 2: ReaderRebuildUITests:** `d9c60dba6` (test)

## Verification

- Task 1 verify, `-testPlan FeatureTests -only-testing:AppFeatureTests/UITestStubTests` on the phone (FFE7E686):
  TEST SUCCEEDED, 44 test cases passed, 0 failed. Each new key has a passing case:
  `analyticsOpensTheLaunchOnTheAnalyticsChoice(value:)`, `everyStubbedLaunchStartsFromTheBlockListItNames`,
  `theDisplayNameKeyNamesTheSignedInUser`, `theStoragePresetReplacesTheBlockListAndTheDisplayName`,
  `theRequestLogKeyNamesTheFile`, `aRequestThroughTheStubAppendsOneLine`,
  `dropInitialIdleAsksTheReaderToDropItsFirstIdleReport`, `thePhaseLaunchKeysNeedAStubbedLaunch` and
  `aVisualHostWritesNoStoragePreset`.
- DEBUG-only placement of every new key string:
  - `UITestAutomation.swift`: lines 86 to 429, all inside the `#if DEBUG` block at lines 37 to 468.
  - `UITestStubURLProtocol.swift`: the whole file is inside `#if DEBUG` (lines 1 to 291).
  - `ReadingView.swift`: `ReaderUITestOptions` and the seam are inside `#if DEBUG` at lines 655 to 674, plus the
    `Synchronization` import inside `#if DEBUG` at lines 16 to 18.
  - `Scripts/visual/verify-release.py` already forbids the `EHPANDA_` token in Release. 18-12 runs that scan.
- Task 2 verify, `-testPlan UITests`:
  - Phone (FFE7E686), `ReaderRebuildUITests` alone: TEST SUCCEEDED, 4 passed, 0 Repetition nodes.
  - Phone, all four reader suites (ReaderRebuild, ReaderPageSync, ReadingOrientation, DuoReadingPanel): TEST
    SUCCEEDED, 17 tests with 13 passed, 4 skipped and 0 failed. 0 Repetition nodes.
  - Pad (B470DB46), the same four suites: TEST SUCCEEDED, 17 tests with 14 passed, 3 skipped and 0 failed. 0
    Repetition nodes.
  - The skips are the suites' own device and env guards (DuoReadingPanel needs its env var, and the
    ReadingOrientation cases are device-specific).
- The drop-idle seam engages end to end. A temporary, uncommitted probe in the pager's drop branch recorded a dropped
  first idle report for pager generations 0, 1 and 2 during the drop-idle test, and the test passed. The same run
  pointed `EHPANDA_UITEST_REQUEST_LOG` at a temporary file and got 935 `METHOD host path` lines. Both probes were
  removed, and the committed tree has no trace of them.
- Strict no-cache swiftlint over `AppPackage/Sources/AppFeature`, `AppPackage/Sources/ReadingFeature`,
  `AppPackage/Tests/AppFeatureTests` and `EhPandaUITests` found 0 violations in 96 files.
- Before the Task 2 commit, `git status --short` listed only `EhPandaUITests/ReaderRebuildUITests.swift`,
  `EhPandaUITests/Support/ReaderPageProbe.swift` and the untracked `.claude/`. No file from the Phase 17 UAT harness
  was copied, and no video or log evidence was committed.

## Deviations from Plan

1. **Compiler workaround in a Task 1 test.** `#expect(user.displayName == ...)` over a `@Shared` local made the Swift
   compiler fail with a SIL "function type mismatch" in the macro expansion. The assertion uses `expectNoDifference`
   instead. The check is the same.
2. **`ReaderPageProbe.Direction.allCases` is explicit.** Adding `rightToLeft` to the `CaseIterable` enum would have
   made `ReaderPageSyncUITests`, which loops over `allCases`, run every route under right to left too. `allCases`
   stays `[.vertical, .leftToRight]`, and `ReaderRebuildUITests` switches into and out of right to left on its own.
3. **The direction test restarts auto-play.** The direction changes from the Reading Setting sheet, and presenting a
   sheet stops auto-play by design (`ReadingView`). The first version waited for a tick after the change that could
   never come, and failed in the first run (that run's retries also produced Repetition nodes). The test now changes
   the direction right after auto-play has turned the pages, requires the page to hold, starts auto-play again on the
   pager the change built, and requires the indicator to name the page shown after the next tick. The closing
   evidence above comes from clean runs only.
4. **Task 1 is one commit.** The task is `tdd="true"`. The tests and the keys went in together as one `feat` commit,
   following the earlier Phase 18 executors.

## Notes for later plans

- The pad run reported a runtime warning in `ReaderPageSyncUITests.testTurningTheDeviceKeepsTheResumedPageAtTheTop`,
  a suite this plan did not change. That test passed. 18-12 should look at it in its closing gate.
- `LocalizedLaunch` is compiled and linted here. 18-09 and 18-10 are its first callers.
- A UI test that blocks an author or signs in passes `EHPANDA_UITEST_BLOCKED_AUTHORS` or
  `EHPANDA_UITEST_DISPLAY_NAME` through `openCold(_:extraEnvironment:)`. The next launch resets both.

## Next

Wave 3: 18-09, 18-10 and 18-11 build their UI tests on these keys.
