---
phase: 19-visual-regression-marketing-export
plan: "11"
subsystem: testing
tags: [xcuitest, dynamic-type, rotation, native-policy, simulator]

requires: []
provides:
  - "`LiveTextSize` (`set(_:returningTo:)`, `reset()`): the Settings app's Larger Text control driven with public XCUITest means only (D-27)"
  - "`NativeVisualPolicyUITests`: cold entry at Large, AX1, AX3 and AX5 for Home, Search, Favorites, Downloads and Settings; live size changes; turns; reader toolbar priority; dialog and menu anchoring"
affects: [19-10]

actuals:
  tokens: 90000
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "A live text-size change goes through `com.apple.Preferences` (Accessibility, Display & Text Size, Larger Text, the Larger Accessibility Sizes switch, then the slider) and returns to the app"
    - "Title checks on iPad accept the selected floating tab in place of the navigation bar's title"

key-files:
  created:
    - EhPandaUITests/NativeVisualPolicyUITests.swift
    - EhPandaUITests/Support/LiveTextSize.swift
  modified: []

key-decisions:
  - "The Settings route works on iOS 27 (D-27 holds; no app code or launch key added). Settings left on Larger Text is reused, since a relaunch soon after a change to AX5 takes no tap on Display & Text Size. `reset()` returns to Large in each teardown (T-19-23)."
  - "On iPad the tab bar floats at the top in the navigation bar's place, and the bar then shows no title: the selected tab stands for the title. While a search is active the tab bar hides, and the Search page stands for its selected tab."
  - "A dialog (Search's Remove All) is opened before each turn and must stay up through it. The results page's overflow menu is opened after each turn: reopening a menu right after a turn once left the app animating for minutes on the iPhone simulator, and the test ran past its 10-minute allowance."
  - "An open menu or popover is closed by a tap in the half of the window it is not in, away from the edges: a turned phone's camera housing takes no taps."

patterns-established:
  - "UI tests that change the simulator's text size call `LiveTextSize.reset()` in a teardown block"

requirements-completed: [CAP-17-06]

coverage:
  - id: D1
    description: "Cold entry at Large, AX1, AX3 and AX5 shows each root's title and reaches its search field"
    requirement: CAP-17-06
    verification:
      - kind: integration
        ref: "NativeVisualPolicyUITests/testColdEntryAt{Large,AX1,AX3,AX5} on $PHONE and $PAD"
        status: pass
    human_judgment: false
  - id: D2
    description: "The live Settings route reaches every size and returns to the app's page"
    requirement: CAP-17-06
    verification:
      - kind: integration
        ref: "NativeVisualPolicyUITests/testLiveTextSizeRouteReachesEverySize on $PHONE and $PAD"
        status: pass
    human_judgment: false
  - id: D3
    description: "Query, focus, title and selected tab, and the picker and toggle marks, survive live size changes and turns"
    requirement: CAP-17-06
    verification:
      - kind: integration
        ref: "testSearchKeepsQueryFocusAndTabThroughSizesAndTurns, testSettingMarksAndTitleSurviveSizesAndTurns on $PHONE and $PAD"
        status: pass
    human_judgment: false
  - id: D4
    description: "Reader toolbar priority at the narrowest and widest widths; dialog and menu anchored through turns"
    requirement: VIS-18-01
    verification:
      - kind: integration
        ref: "testReaderToolbarKeepsPriorityAtEveryWidth, testDialogAndMenuStayAnchoredThroughTurns on $PHONE and $PAD"
        status: pass
    human_judgment: false

duration: multi-session
completed: 2026-11-07
status: complete
---

# Phase 19 Plan 11: Native visual policy transitions Summary

**Cold entry at four text sizes, live size changes through the Settings app, turns, toolbar priority and anchoring
are tested on both simulators. Each device ran the class 9/9 with 0 Repetition nodes.**

## Performance

- **Tasks:** 2
- **Files created or modified:** 2
- **Class run time:** about 760 s on `$PHONE` and 860 s on `$PAD`

## Accomplishments

- `LiveTextSize` changes the simulator's text size through the Settings app only. No app code and no launch key
  were added.
- `NativeVisualPolicyUITests` has 9 tests:
  - cold entry at four sizes
  - the live route reaching every size
  - Search and Appearance state through sizes and turns
  - reader toolbar priority
  - dialog and menu anchoring
- Verify run with the plan's command (UITests plan, `-only-testing:EhPandaUITests/NativeVisualPolicyUITests`):
  - `$PHONE`: TEST SUCCEEDED, 9 passed, 0 Repetition
  - `$PAD`: TEST SUCCEEDED, 9 passed, 0 Repetition
- `grep EHPANDA_` lists only `EHPANDA_AUTOMATION_TAB`, `_IPB_MEMBER_ID` and `_IPB_PASS_HASH`. All three already
  exist in `AppLaunchAutomation.swift`.
- SwiftLint (strict) reports 0 violations in `EhPandaUITests`.

## Task Commits

1. **Task 1: Live text size helper and cold-entry checks** - `99470c25c` (test)
2. **Task 2: Live change, rotation and preservation on both devices** - `fd9d4baa2` (test)

## Decisions Made

See `key-decisions`.

## Deviations from Plan

1. **iPad title and tab checks.** The plan expects a navigation title on every root. On iPad the floating tab bar
   takes the title's place, so the selected tab is checked instead. This is native iPadOS behaviour, not an app
   change.
2. **Menu anchoring after a turn, not through it.** The overflow menu is opened after each turn and checked beside
   its control. The Remove All dialog is still checked through a turn. The reason is the iPhone stall recorded in
   `key-decisions`.

## Issues Encountered

- Changing the size live means several Settings round trips, so the class takes 13 to 15 minutes per device. 19-10
  should budget for this in the `native-policy` job.

## User Setup Required

None.

## Next Phase Readiness

19-10 can add the class to the gate as the `native-policy` job.
