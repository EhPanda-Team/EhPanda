---
phase: 18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder
plan: "09"
subsystem: first-launch-ui
tags: [swiftui, first-launch, age-wall, analytics-consent, xcuitest, dynamic-type]

requires: ["18-01", "18-02", "18-03", "18-08"]
provides:
  - "AppComponents: `CheckboxToggleStyle`, `ChoiceCard` (with the Recommended capsule), `FirstLaunchContinueButton`"
  - "`FirstLaunchGateView` with `AgeWallView` and `AnalyticsChoiceView`, rendered by `RootView` instead of the app until both answers exist"
  - "`FirstLaunchTitle` and `TitleWidowGuard`: the first-launch titles keep a single word off their last line (lead msg 1900)"
  - "`FirstLaunchUITests` (7 cases) and `FirstLaunchTitleLayoutUITests` (6 languages × 2 sizes, 24 kept screenshots per device)"
affects: [18-10, 18-12]

actuals:
  tasks: 3
  commits: 7

tech-stack:
  added: []
  patterns:
    - "A first-launch screen is a `FirstLaunchPage`: a 560pt scrolling column with Continue in a `.safeAreaBar(edge: .bottom)` at every text size (D-17b)"
    - "A widow guard measured in the title's own font: the last two words are joined with U+00A0 only when the pair fits the measured width"

key-files:
  created:
    - AppPackage/Sources/AppComponents/CheckboxToggleStyle.swift
    - AppPackage/Sources/AppComponents/ChoiceCard.swift
    - AppPackage/Sources/AppComponents/FirstLaunchContinueButton.swift
    - AppPackage/Sources/AppFeature/FirstLaunch/FirstLaunchGateView.swift
    - AppPackage/Sources/AppFeature/FirstLaunch/AgeWallView.swift
    - AppPackage/Sources/AppFeature/FirstLaunch/AnalyticsChoiceView.swift
    - EhPandaUITests/FirstLaunchUITests.swift
    - EhPandaUITests/FirstLaunchTitleLayoutUITests.swift
  modified:
    - AppPackage/Sources/AppFeature/RootView.swift
    - AppPackage/Tests/AppFeatureTests/FirstLaunchGateTests.swift
    - AppPackage/Tests/AppToolsTests/ReduceMotionGatingSourceTests.swift
    - .planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-UI-SPEC.md
    - .planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/18-CONTEXT.md
    - .planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/mockups/16-age-wall-ax5-top.png
    - .planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/mockups/17-age-wall-ax5-bottom.png
    - .planning/phases/18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder/mockups/18-analytics-ax5.png

key-decisions:
  - "Widow guard (lead msg 1900): at render time, in languages that separate words with spaces, the title's last two words are joined with a no-break space when the pair, measured in bold `.title1` at the current Dynamic Type size, fits the title's width (read with `onGeometryChange`). Otherwise the title is left as is. Catalog strings, visible words and the VoiceOver label are unchanged; there is no `\\n`, scaling, line limit or fixed width"
  - "Accepted exception (owner msg 1903, card 1901): on the iPhone at AX5 the en analytics title ends on \"shares\" and the de age-wall title on \"Erwachsene\". In both, the last two words are wider than the screen, so no layout can join them"
  - "D-17b (owner msg 1903, designer msg 1905): Continue stays pinned in the bottom bar at every text size. At accessibility sizes the age-wall footnote leaves the bar and becomes the last scroll item, 16pt under the checkbox card. The last scroll item ends 24pt above the bar"
  - "The Privacy Policy link uses `.tint(.primary)`: UI-SPEC C-3 draws it in the primary colour, not the accent"
  - "`RootView` keeps 18-01's IN-03 `#if DEBUG` import of AppComponents. The gate views import AppComponents themselves, so RootView needs nothing new in Release"

patterns-established:
  - "UI tests at AX5 scroll a card's centre clear of the pinned Continue before tapping it, so a tap never lands on the bar"

requirements-completed: []

coverage:
  - id: T1
    description: "Shared first-launch components"
    verification:
      - kind: build
        ref: "EhPanda scheme on the phone: BUILD SUCCEEDED; no minimumScaleFactor, lineLimit or systemName: in the three files"
        status: pass
    human_judgment: false
  - id: T2
    description: "Gate views, the root switch and FirstLaunchUITests"
    verification:
      - kind: unit
        ref: "AppFeatureTests + ReduceMotionGatingSourceTests on the phone: TEST SUCCEEDED, 308 test cases passed, 0 failed"
        status: pass
      - kind: automated_ui
        ref: "FirstLaunchUITests on phone and pad: 7/7 passed on each, including the AX5 pinned-Continue case"
        status: pass
    human_judgment: false
  - id: T3
    description: "Title line-break screenshots (UI-SPEC C-3), 48 rows"
    verification:
      - kind: automated_ui
        ref: "FirstLaunchTitleLayoutUITests on phone and pad: 6/6 passed on each, 24 screenshots exported per device"
        status: pass
      - kind: visual
        ref: "48-row table below: 46 pass, 2 accepted by the owner (msg 1903)"
        status: pass
    human_judgment: true

duration: about 1h for this close-out (the plan ran in several sessions)
completed: 2026-11-05
status: complete
---

# Phase 18 Plan 09: The first-launch age wall and analytics choice Summary

**Fresh installs and upgraders now meet the age wall, then the analytics choice, and then the app. Nothing of the
app renders behind the gate, and no request is made before the age wall's Continue. Continue stays pinned at every
text size. The titles keep a single word off their last line in all six languages, apart from two phone-AX5 cases
the owner accepted.**

## Accomplishments

- **Components (AppComponents):**
  - `CheckboxToggleStyle`: a card with a square glyph that stacks above the sentence at AX sizes. VoiceOver reads it
    as a toggle.
  - `ChoiceCard`: a radio card with an optional Recommended capsule. The capsule uses `tertiarySystemFill`, never the
    accent, and drops under the name at AX sizes.
  - `FirstLaunchContinueButton`: `.glassProminent`, large, full column width, default action.
- **Root gate:** `RootView` renders `FirstLaunchGateView` instead of `TabBarView` until `firstLaunch.step ==
  .complete`, then crossfades to the app (0.3s, or 0.2s under Reduce Motion). While the gate shows, it delivers
  opened links and scene phases to `AppReducer`, which queues a link until the age wall is answered (DD-07).
- **Age wall (C-2):** icon, title, body, the checkbox card, Continue dimmed until ticked (with the
  `age_wall.continue_hint` VoiceOver hint), and the footnote. The footnote sits in the bar at default sizes and is
  the last scroll item at AX sizes (D-17b).
- **Analytics choice (C-3):**
  - The intro is `consent.body` and `consent.footer` as one paragraph (D-06g). They are joined by a space in en, de
    and ko and by nothing in ja and zh.
  - The Privacy Policy link sits under the intro, above the cards.
  - The cards are Minimal, Basic and Full, with none selected. Basic alone shows Recommended.
  - Continue stays dimmed until a level is picked.
- **Transitions:** the step slides, or crossfades under Reduce Motion. VoiceOver focus moves to each title.
- **Titles:** `FirstLaunchTitle` (bold `.title`, centred, wrapping freely) carries `TitleWidowGuard` (lead msg
  1900).
- **D-17b:** `FirstLaunchPage` pins Continue in the `.safeAreaBar` at every size.

## Task Commits

1. **Task 1, components:** `b6855d0b9` feat(18-09): add the first-launch checkbox, choice card and Continue button
2. **Task 2, gate and root switch:** `69ba52d9f` feat(18-09): gate the app behind the age wall and the analytics
   choice
3. **Task 2, link colour fix:** `4b14ee9e1` fix(18-09): keep the Privacy Policy link out of the accent
4. **Task 3, title screenshots:** `20bb6938d` test(18-09): keep the first-launch titles in six languages at two
   sizes
5. **Widow guard:** `99e76fb8c` feat(18-09): keep a single word off the first-launch titles' last line
6. **Spec update:** `e04301589` docs(18): keep Continue pinned at every text size (UI-SPEC, CONTEXT D-17b, mockups
   16 to 18)
7. **D-17b:** `9fcc89618` feat(18-09): keep Continue pinned at every text size

## Verification

- **AppFeatureTests and ReduceMotionGatingSourceTests** (`-testPlan FeatureTests`, phone): TEST SUCCEEDED, 308
  test cases passed and 0 failed. This includes:
  - `TitleWidowGuardTests`: fits → NBSP joined; does not fit → unchanged; single word, empty, ja and zh → unchanged,
    and the fit closure is never called for them; ko → joined.
  - The intro separator cases.
  - The Reduce Motion inventory: 22 env reads, 30 ternaries and 66 mentions, with the two gate files listed.
- **`FirstLaunchUITests`** (`-testPlan UITests`): 7/7 passed on the phone (FFE7E686) and 7/7 on the pad (B470DB46).
  The cases cover:
  - The empty request log before Continue.
  - No tab bar behind the gate.
  - The tick and untick gating.
  - Nothing selected at first, and Recommended on Basic only.
  - The intro, then the link, then the cards.
  - The upgrader path.
  - A queued deep link.
  - The new `testContinueStaysPinnedAtTheLargestTextSize`. At AX5, Continue is hittable in the bottom half with no
    swipe on both screens, before and after scrolling. The footnote follows the checkbox card.
  - At the default size, the footnote sits under Continue.
- **`FirstLaunchTitleLayoutUITests`:** 6/6 passed on each device, with 24 attachments exported per device.
- **Strict lint:** no-cache swiftlint over `AppComponents`, `AppFeature`, `AppFeatureTests` and `EhPandaUITests`
  found 0 violations in 116 files.
- **Title rule, static half:** `grep -rn "minimumScaleFactor\|lineLimit\|\\n"` over `AppFeature/FirstLaunch`
  returns 0.
- **Mockups:**
  - 01, 03 and 04 (light and dark) match.
  - The refreshed 16, 17 and 18 (D-17b) match the phone AX5 runs: the top of the age wall with Continue pinned; the
    bottom with the footnote under the card and Continue under it; the analytics cards under the pinned Continue.
  - `chart.bar.xaxis` draws four bars on iOS 27, against three in the mockup. This was accepted.
- **No screenshot committed:** every screenshot stayed in temporary directories outside the repo.

### Title table (UI-SPEC C-3)

The phone is the iPhone Air (FFE7E686) and the pad is the iPad Pro 11" (B470DB46), both in portrait. "Intro" is the
analytics intro's line count (`consent.body` and `consent.footer` joined). At AX5 the intro wraps freely, and on the
phone it runs past the first screen.

| # | Device | Locale | Size | Screen | Title's last line | Intro | Result |
|---|--------|--------|------|--------|-------------------|-------|--------|
| 1 | phone | en | default | age wall | EhPanda is for adults (one line) | — | pass |
| 2 | phone | en | default | analytics | EhPanda shares | 3 | pass |
| 3 | phone | en | AX5 | age wall | for adults | — | pass |
| 4 | phone | en | AX5 | analytics | shares | free | accepted, owner msg 1903 |
| 5 | phone | de | default | age wall | für Erwachsene | — | pass (widow guard) |
| 6 | phone | de | default | analytics | Wähle, was EhPanda teilt (one line) | 4 | pass |
| 7 | phone | de | AX5 | age wall | Erwachsene | — | accepted, owner msg 1903 |
| 8 | phone | de | AX5 | analytics | EhPanda teilt | free | pass |
| 9 | phone | ko | default | age wall | EhPanda는 성인용 앱입니다 (one line) | — | pass |
| 10 | phone | ko | default | analytics | 정보를 선택하세요 | 2 | pass |
| 11 | phone | ko | AX5 | age wall | 성인용 앱입니다 | — | pass |
| 12 | phone | ko | AX5 | analytics | 선택하세요 | free | pass |
| 13 | phone | ja | default | age wall | のアプリです | — | pass |
| 14 | phone | ja | default | analytics | 情報を選んでください | 3 | pass |
| 15 | phone | ja | AX5 | age wall | アプリです | — | pass |
| 16 | phone | ja | AX5 | analytics | ください | free | pass |
| 17 | phone | zh-Hans | default | age wall | EhPanda 仅限成年人使用 (one line) | — | pass |
| 18 | phone | zh-Hans | default | analytics | 选择 EhPanda 要分享的内容 (one line) | 2 | pass |
| 19 | phone | zh-Hans | AX5 | age wall | 限成年人使用 | — | pass |
| 20 | phone | zh-Hans | AX5 | analytics | 要分享的内容 | free | pass |
| 21 | phone | zh-Hant | default | age wall | EhPanda 僅限成年人使用 (one line) | — | pass |
| 22 | phone | zh-Hant | default | analytics | 選擇 EhPanda 要分享的內容 (one line) | 2 | pass |
| 23 | phone | zh-Hant | AX5 | age wall | 限成年人使用 | — | pass |
| 24 | phone | zh-Hant | AX5 | analytics | 要分享的內容 | free | pass |
| 25 | pad | en | default | age wall | EhPanda is for adults (one line) | — | pass |
| 26 | pad | en | default | analytics | Choose what EhPanda shares (one line) | 2 | pass |
| 27 | pad | en | AX5 | age wall | for adults | — | pass |
| 28 | pad | en | AX5 | analytics | EhPanda shares | 6 | pass |
| 29 | pad | de | default | age wall | EhPanda ist nur für Erwachsene (one line) | — | pass |
| 30 | pad | de | default | analytics | Wähle, was EhPanda teilt (one line) | 3 | pass |
| 31 | pad | de | AX5 | age wall | für Erwachsene | — | pass (widow guard) |
| 32 | pad | de | AX5 | analytics | EhPanda teilt | 8 | pass |
| 33 | pad | ko | default | age wall | EhPanda는 성인용 앱입니다 (one line) | — | pass |
| 34 | pad | ko | default | analytics | EhPanda가 공유할 정보를 선택하세요 (one line) | 2 | pass |
| 35 | pad | ko | AX5 | age wall | 성인용 앱입니다 | — | pass |
| 36 | pad | ko | AX5 | analytics | 정보를 선택하세요 | 5 | pass |
| 37 | pad | ja | default | age wall | EhPanda は成人向けのアプリです (one line) | — | pass |
| 38 | pad | ja | default | analytics | 情報を選んでください | 2 | pass |
| 39 | pad | ja | AX5 | age wall | アプリです | — | pass |
| 40 | pad | ja | AX5 | analytics | 選んでください | 6 | pass |
| 41 | pad | zh-Hans | default | age wall | EhPanda 仅限成年人使用 (one line) | — | pass |
| 42 | pad | zh-Hans | default | analytics | 选择 EhPanda 要分享的内容 (one line) | 2 | pass |
| 43 | pad | zh-Hans | AX5 | age wall | 限成年人使用 | — | pass |
| 44 | pad | zh-Hans | AX5 | analytics | 要分享的内容 | 4 | pass |
| 45 | pad | zh-Hant | default | age wall | EhPanda 僅限成年人使用 (one line) | — | pass |
| 46 | pad | zh-Hant | default | analytics | 選擇 EhPanda 要分享的內容 (one line) | 2 | pass |
| 47 | pad | zh-Hant | AX5 | age wall | 限成年人使用 | — | pass |
| 48 | pad | zh-Hant | AX5 | analytics | 要分享的內容 | 4 | pass |

Result: 46 pass and 2 accepted (rows 4 and 7). On the phone at default size:
- The en intro is three lines, as designer msg 1899 expects.
- The de intro is four lines, which the plan allows.
- The Privacy Policy link shows above the cards without scrolling in every locale.

Before the widow guard, three German rows failed by ending on "Erwachsene": rows 5, 7 and 31. The guard fixed rows 5
and 31. Row 7 is physically impossible to fix, since "für Erwachsene" is wider than the phone at AX5. Row 4 failed
before and after the guard for the same reason ("EhPanda shares" at AX5). The guard did not change any other title
screenshot. A pixel diff against the run before the guard was identical outside the German age wall. The analytics
shots differed only in the link colour, which `4b14ee9e1` fixed after that run.

## Deviations from Plan

1. **Widow guard instead of plain `Text` titles (lead msg 1900).** The plan's must-have says the titles are plain
   `Text`. They are now `FirstLaunchTitle`: `Text(verbatim:)` of the localized string, with the last two words joined
   by U+00A0 when they fit. It still has no `\n`, scaling, line limit or fixed width. It lives in
   `FirstLaunchGateView.swift`, with `TitleWidowGuardTests` in `FirstLaunchGateTests.swift`. The language lookup
   moved from `AnalyticsChoiceView` into a shared `FirstLaunchLanguage.code`.
2. **Two phone-AX5 rows accepted rather than passing (owner msg 1903, card 1901).** See rows 4 and 7.
3. **D-17b came in during execution.** The plan built 18-UI-SPEC's earlier rule, where the bar is removed at AX sizes
   and Continue joins the scroll content. Owner msg 1903 and designer msg 1905 changed it:
   - The spec, `18-CONTEXT.md` (D-17b) and mockups 16 to 18 were committed as `e04301589` at the lead's direction.
     These files are outside `files_modified`.
   - `9fcc89618` implements the change.
   - `FirstLaunchUITests` gained `testContinueStaysPinnedAtTheLargestTextSize` and keeps two screenshots,
     `age-wall-en-AX5-bottom` and `analytics-choice-en-AX5-basic`.
   - Both suites' swipe helpers scroll a card's centre clear of the bar before tapping it. The first AX5 run tapped
     the checkbox through the bar.
4. **`ReduceMotionGatingSourceTests.swift` modified.** This file is outside `files_modified`. The source inventory
   had to list `FirstLaunchGateView.swift` (1/2/3) and `RootView.swift` (1/1/2), now 22, 30 and 66 in total. A doc
   comment records the first launch as a UI-SPEC-mandated motion exception.
5. **Lint-driven changes:**
   - `loggedRequests()` uses do/catch with `XCTFail` instead of `try?` (`optional_try`).
   - Two long lines in `FirstLaunchUITests` were wrapped.
   - `introSeparator` is `nonisolated`, so the unit test calls it off the main actor.
6. **XCUI queries:** the declaration toggle is a Switch in XCUI, so the tests use `app.switches`, not
   `app.buttons`. Accessibility identifiers were added to both titles and to the AX-size footnote so the tests can
   reach them.
7. **Privacy Policy link colour (`4b14ee9e1`).** It rendered in the accent until it got `.tint(.primary)`, per C-3.
8. **Dark screenshots.** They came from a throwaway `EhPandaUITests/TmpEhp1809DarkShots.swift`, which set
   `XCUIDevice.shared.appearance` on the test clone. It was deleted and never committed, and no simulator setting
   changed.

## Notes for later plans

- 18-10 can reuse `FirstLaunchTitle` or `TitleWidowGuard` for any long title it must check under C-3.
- 18-12's closing gate should rerun `FirstLaunchUITests` and `FirstLaunchTitleLayoutUITests` on both devices. Its
  table should carry rows 4 and 7 as accepted (owner msg 1903).

## Next

18-10 and 18-11 continue Wave 3.
