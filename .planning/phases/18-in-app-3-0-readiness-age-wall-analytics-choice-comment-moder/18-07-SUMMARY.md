---
phase: 18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder
plan: "07"
subsystem: reader
tags: [swiftui, tca, scrollview, paging, reader]

requires: []
provides:
  - "`ReaderPosition`: the reader's one page, its single pending turn and the pager generation, with pure transitions"
  - "`ReadingReducer` actions `.turn(toPage:)`, `.pagerPhaseChanged`, `.pagerSettled`, `.pagerRebuilt`"
  - "A view that only carries out commands: each pager generation writes its scroll position only for its own command and reports stamped observations"
  - "DEBUG-only `EnvironmentValues.dropsReaderInitialIdleReport` seam for 18-08"
affects: [18-08, reader, capture-diagnostics]

actuals:
  tokens: 26567
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Generation-stamped view observations: the reducer ignores any report from a pager it has rebuilt"
    - "Command/actuator split: the reducer issues `IssuedPagerCommand`s (serial-numbered), the view carries each out once"

key-files:
  created:
    - AppPackage/Sources/ReadingFeature/Support/ReaderPosition.swift
    - AppPackage/Tests/ReadingFeatureTests/ReaderPositionTests.swift
  modified:
    - AppPackage/Sources/ReadingFeature/ReadingReducer.swift
    - AppPackage/Sources/ReadingFeature/ReadingReducer+Session.swift
    - AppPackage/Sources/ReadingFeature/ReadingReducer+Body.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift
    - AppPackage/Sources/ReadingFeature/Support/PageHandler.swift
    - AppPackage/Sources/ReadingFeature/Support/AutoPlayHandler.swift
    - AppPackage/Sources/ReadingFeature/Support/ReaderPagesAccessibility.swift
  deleted:
    - AppPackage/Sources/ReadingFeature/Support/PageModel.swift
    - AppPackage/Tests/ReadingFeatureTests/PagerTurnGateTests.swift

key-decisions:
  - "The page is 1-based everywhere in state. A gallery with no saved progress opens on page 1, so `readingProgress` reads 1, not 0"
  - "`readingProgress` stays public as a computed view of `position.page`. Its setter commits without moving the pager, so existing callers and tests that seed progress keep working"
  - "`sliderValue` is computed: the drag's scrub while dragging, `position.displayedPage` otherwise. A value set outside a drag (accessibility adjust) turns at once"
  - "Turns go to the landing page, the page that names the position the turn lands on (`PageHandler.landingPage`). This keeps the indicator equal to what the settled pager reports in dual-page layouts"
  - "A fourth action, `.pagerPhaseChanged`, carries the scroll phase. The ported hold-while-animating and user-scroll-drops-the-turn rules need it"

patterns-established:
  - "Reader page state lives only in `ReadingReducer.State.position`; views read `position.displayedPage`/`placement`/`issued`"

requirements-completed: []

coverage:
  - id: D1
    description: "ReaderPosition with the ported PagerTurnGate rules, stale-generation rules, rebuild and placement rules"
    verification:
      - kind: unit
        ref: "ReadingFeatureTests/ReaderPositionTests (27 @Test functions)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Reducer and view driven by the one position; old mirrors and gate deleted"
    verification:
      - kind: unit
        ref: "xcodebuild -testPlan FeatureTests -only-testing:ReadingFeatureTests (phone and pad)"
        status: pass
      - kind: automated_ui
        ref: "EhPandaUITests/ReaderPageSyncUITests, ReadingOrientationUITests, DuoReadingPanelUITests (phone and pad, unchanged)"
        status: pass
    human_judgment: false

duration: about 2h over two sessions
completed: 2026-11-05
status: complete
---

# Phase 18 Plan 07: ReaderPosition reader rework Summary

**One `ReaderPosition` in `ReadingReducer.State` now drives the reader. The title, the slider, the saved progress and
the pager position all derive from it. Pager observations carry a generation stamp, so a pager that has been rebuilt
can no longer write a page.**

## Performance

- **Duration:** about 2h over two sessions
- **Completed:** 2026-11-05
- **Tasks:** 2
- **Files modified:** 25 (2 created, 2 deleted)

## Accomplishments

- `ReaderPosition { page, request: {target, generation, tries}?, generation }` holds pure transitions:
  `turn(to:pageCount:)`, `pagerPhaseChanged(to:generation:)`, `pagerSettled(shown:generation:)`, `pagerRebuilt()`
  and `commit(page:)`. Each one emits at most one `PagerCommand` (`place`/`drive`), wrapped in a serial-numbered
  `IssuedPagerCommand`.
- The reducer gained `positionReducer` with `.turn(toPage:)`, `.pagerPhaseChanged`, `.pagerSettled` and
  `.pagerRebuilt`. A settled page change goes through `.syncReadingProgress`, which keeps the debounce and the
  dismissal flush. `refreshPages()` routes both `forceRefreshID` resets through `pagerRebuilt`.
- `ReadingView` is now an actuator. `HorizontalPager` (one per generation, `.id(placement.generation)`) and
  `AdvancedList` write the scroll position only for a command of their own generation. They report the phase, and at
  rest the page shown, stamped with that generation. A change of reading direction or of the laid-out positions
  (rotation into or out of two pages) sends `.pagerRebuilt`.
- Tap-to-turn, the accessibility next/previous actions, auto-play ticks and the slider's drag end all send
  `.turn(toPage:)`.
- Deleted: `PageModel`, `PagerTurnGate`, `performingChanges`, `echoGuardDuration`, the A↔B, A↔D and A↔F page-mirror
  `onChange`s, `pendingReadingProgress` and `jump`/`correctPager`/`seedPager`/`setPageIndex`. `PagerSeed` only records
  whether the area was measured, and it moved into `ReaderPosition.swift`.
- DEBUG seam: `EnvironmentValues.dropsReaderInitialIdleReport` (default false, no launch key read) drops the first
  `.idle` report of each horizontal pager.

## Task Commits

1. **Task 1: ReaderPosition and its ported rules:** `c6e535e9c` (feat)
2. **Task 2: Wire the reducer and view to the one position:** `b7a759bd8` (feat)

## Test mapping (old → new)

### PagerTurnGateTests (16) → ReaderPositionTests

| Old case | New case |
|---|---|
| aTurnFromRestIsSentAtOnce | aTurnFromRestIsSentAtOnce |
| aTurnWhileThePagerAnimatesIsHeldAndSentAtRest | aTurnWhileThePagerAnimatesIsHeldAndSentAtRest |
| restWithNothingHeldSendsNothing | restWithNothingHeldSendsNothing |
| theReadersOwnScrollDropsTheHeldTurn(phase:) | theReadersOwnScrollDropsTheHeldTurn(phase:) |
| aPagerBuiltAnewAdmitsTurnsAGateLeftMidAnimationHeld | aPagerBuiltAnewAdmitsTurnsAPagerLeftMidAnimationHeld |
| aPagerBuiltAnewDropsTheTurnHeldForTheOldOne | aPagerBuiltAnewDropsTheTurnHeldForTheOldOne |
| aPagerBuiltAnewIsCheckedAtRest | aPagerBuiltAnewIsCheckedAtRest |
| aPagerBuiltAnewStartsTheCountOver | aPagerBuiltAnewStartsTheCountOver |
| aPagerAtRestOnAnotherPageIsSentToTheIndexAgain | aPagerAtRestOnAnotherPageIsSentToTheTurnAgain |
| aPagerAtRestOnTheIndexIsLeftAlone | aPagerAtRestOnTheTurnIsLeftAlone |
| aMovingPagerIsNotCorrected(phase:) | aMovingPagerIsNotCorrected(phase:) |
| theIndexFollowsTheScreenWhenThePagerKeepsMissingIt | thePageFollowsTheScreenWhenThePagerKeepsMissingTheTurn (same retry limit, 2) |
| landingOnTheIndexStartsTheCountOver | landingOnTheTurnStartsTheCountOver |
| aNewTurnStartsTheCountOver | aNewTurnStartsTheCountOver |
| theReadersOwnScrollStartsTheCountOver(phase:) | theReadersOwnScrollStartsTheCountOver(phase:) |
| aProgrammaticScrollKeepsTheCount | aProgrammaticScrollKeepsTheCount |

The new cases are:
- WR-01 stale generations: `aStaleAnimationHoldsNoTurn`, `aStaleRestSendsNothing`, `aStaleObservationChangesNothing`
  and `aStaleRetryChangesNothing`.
- Rebuild and placement: `aRebuildFromAPendingTurnPlacesTheNewPagerOnIt`, `aRebuildAtRestPlacesTheNewPagerOnThePage`
  and `theResumePageIsPlacedOnceTheAreaIsMeasured`.
- The named page: `aDragCommitsThePageItShows`, `theReaderNamesTheTurnUnderWayOrThePage`,
  `aTurnIsClampedToTheGalleryAndATurnToTheNamedPageSendsNothing` and `everyCommandIsIssuedOnce`.

That is 27 test functions in total (at least 20 were required).

### PagerSeedTests (shrunk to "area measured")

| Old case | New case |
|---|---|
| thePagerIsSeededAtTheFirstReadingAreaNotTheFirstMeasurement | theAreaIsMeasuredAtTheFirstReadingAreaNotTheFirstMeasurement |
| aDegenerateMeasurementIsNoReadingArea(size:) | aDegenerateMeasurementIsNoReadingArea(size:) (kept) |
| aPagerNotYetMeasuredIsNotSeeded | aReaderNotYetMeasuredBuildsNoPager |
| (new) | theResumePageIsPlacedOnceAtTheFirstReadingArea |

### Task 2 ported suites (new cases asserting the new actions)

- `AutoPlayHandlerTests`: `aTickTurnsOnePositionAndStopsAtTheLast`, `aTickIsSentAsTheOneTurnIntent`.
- `ReaderPagesAccessibilityTests`: `theElementReadsThePagesOfThePositionTheReadersPageLiesIn` and
  `nextAndPreviousSendTheOneTurnIntent(step:page:)`.
- `PageHandlerTests`: `aTurnLandsOnThePageNamingItsPosition`, `turningByPositionsStaysWithinTheGallery`.
- `ReadingOrientationTests`: `aRotationIntoTwoPagesBuildsANewPagerOnThePageNamed`.
- `AnalyticsEmissionTests`: `theSessionCountsThePagesThePagerSettledOn`. The existing cases now drive pages through
  `.pagerSettled`, using a `read(_:in:)` helper.

## Verification

- `-only-testing:ReadingFeatureTests` passed on the phone FFE7E686 (291 test-case runs, 0 failures) and on the pad
  B470DB46 (291 runs, 0 failures).
- `-only-testing:AppFeatureTests -only-testing:DownloadsFeatureTests -only-testing:VisualSnapshotTests/ReaderListPositionTests`
  passed on the phone (797 runs, 0 failures).
- The `UITests` plan ran `ReaderPageSyncUITests`, `ReadingOrientationUITests` and `DuoReadingPanelUITests`:
  - Phone: TEST SUCCEEDED, with 9 passed, 4 skipped and 0 failed. All 8 ReaderPageSync tests passed.
  - Pad: TEST SUCCEEDED, with 10 passed, 3 skipped and 0 failed.
  - The skips are the suites' own device and env guards: DuoReadingPanel needs its env var, and the
    ReadingOrientation cases are device-specific.
- `git diff --stat EhPandaUITests` lists no files.
- `grep -rn "PagerTurnGate\|performingChanges\|echoGuardDuration" AppPackage/Sources AppPackage/Tests | wc -l` → 0.
- Strict swiftlint over ReadingFeature, ReadingFeatureTests, AppFeature/UITestSupport, AppFeatureTests,
  DownloadsFeatureTests and VisualSnapshotTests found 0 violations.

## Deviations from Plan

1. **Files outside `files_modified`.** Removing `pendingReadingProgress`, `PageModel` and `jump` broke several callers
   outside the plan's list. Each fix is mechanical:
   - `AppFeature/UITestSupport/CaptureDiagnostics.swift`: reads `readingProgress`.
   - `ReadingView+Gestures.swift`: tap zones call `turnPage(by:)`.
   - `AppFeatureTests/AppReducerScenePhaseTests.swift`, `AppFeatureTests/CaptureScreenDiagnosticsTests.swift` and
     `DownloadsFeatureTests/AppReadingFlushTests.swift`: seed `readingProgress` instead of `pendingReadingProgress`.
   - `DownloadsFeatureTests/DownloadObserverReadingTests.swift`: with no saved progress the page is now 1, not 0,
     because state is 1-based (must-have 1).
   - `VisualSnapshotTests/ReaderListPositionTests.swift`: a `ListPageModel` stand-in for the reducer replaces
     `PageModel`, because `AdvancedList` now takes `placement`/`command` and reports.
2. **Action naming.** The plan's `.turn(to:)` is `.turn(toPage:)`. A fourth action, `.pagerPhaseChanged`, carries
   the scroll phase. The ported gate rules (hold while animating, user scroll drops the turn) cannot work without it.
3. **`PagerMotion` is `public`.** It is the payload of a case of the public `Action` enum.
4. **`PagerSeed` moved.** It now lives in `ReaderPosition.swift`, because `PageModel.swift` was deleted. Its tests were
   shrunk in the Task 2 commit, not Task 1, since the type lived in `PageModel.swift` until Task 2.
5. **Rotation without a layout change does not rebuild.** A rotation that leaves the laid-out positions unchanged
   (single-page mode) keeps the pager and does not send `.pagerRebuilt`. A rotation into or out of two pages changes
   the positions and rebuilds.

## Known limits

- The iPad two-page spread stays a known limit (DD-03). No test was added, per the plan.

## Next

18-08 adds the committed UI tests for the G1/G2 gaps. It can wire a launch key to `dropsReaderInitialIdleReport`.
