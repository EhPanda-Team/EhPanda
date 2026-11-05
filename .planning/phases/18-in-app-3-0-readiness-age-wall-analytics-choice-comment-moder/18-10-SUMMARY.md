---
phase: 18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder
plan: "10"
subsystem: settings-ui
tags: [swiftui, settings, analytics-consent, comment-moderation, xcuitest, dynamic-type]

requires: ["18-03", "18-04", "18-06", "18-08"]
provides:
  - "General → Analytics: a menu picker over Minimal, Basic and Full, with the selected level's description as its footer and a Privacy Policy row (UI-SPEC C-9, D-07)"
  - "`GeneralSettingReducer.analyticsLevelPicked`: stores the level and calls `analyticsClient.apply(level)` once (DD-09a)"
  - "Account → Blocked Users: the counted row and the pushed list (`SettingPath.blockedUsers`, `pushBlockedUsers`) with swipe and context-menu unblock and the C-12 empty state (D-14a, C-10 to C-12)"
  - "`TitleWidowGuard` in AppComponents, shared by the first-launch titles and the Blocked Users empty-state title"
  - "`SettingsModerationUITests` (3 cases) and `BlockedUsersTitleLayoutUITests` (6 languages × 2 sizes, 12 kept screenshots per device)"
affects: [18-11, 18-12]

actuals:
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "A settings level change goes through the reducer only, which writes the setting and applies it to the client once; the view never calls the analytics client"
    - "A `ContentUnavailableView` title that must meet C-3 is a custom label view carrying `TitleWidowGuard`, measured in the label's own font (bold `.title3`)"

key-files:
  created:
    - AppPackage/Sources/SettingFeature/BlockedUsers/BlockedUsersReducer.swift
    - AppPackage/Sources/SettingFeature/BlockedUsers/BlockedUsersView.swift
    - AppPackage/Sources/AppComponents/TitleWidowGuard.swift
    - AppPackage/Tests/SettingFeatureTests/BlockedUsersReducerTests.swift
    - EhPandaUITests/SettingsModerationUITests.swift
    - EhPandaUITests/BlockedUsersTitleLayoutUITests.swift
  modified:
    - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingReducer.swift
    - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift
    - AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings
    - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingReducer.swift
    - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift
    - AppPackage/Sources/SettingFeature/SettingPath.swift
    - AppPackage/Sources/SettingFeature/SettingReducer+Body.swift
    - AppPackage/Sources/SettingFeature/SettingView.swift
    - AppPackage/Tests/SettingFeatureTests/GeneralSettingReducerTests.swift
    - AppPackage/Tests/SettingFeatureTests/SettingReducerNavigationTests.swift
    - AppPackage/Sources/AppFeature/FirstLaunch/FirstLaunchGateView.swift
    - AppPackage/Sources/AppFeature/FirstLaunch/AnalyticsChoiceView.swift
    - AppPackage/Tests/AppFeatureTests/FirstLaunchGateTests.swift

key-decisions:
  - "The Blocked Users empty-state title carries the widow guard (lead msg 1900, as in 18-09). Its last two words are joined with U+00A0 when the pair fits the measured width in bold `.title3` at the current Dynamic Type size; otherwise the title is left as is. The catalog string, the visible words and the VoiceOver label are unchanged. There is no `\\n`, scaling, line limit or fixed width"
  - "`TitleWidowGuard` and the resolved-language lookup (now `ResolvedAppLanguage`) moved from AppFeature to AppComponents, so SettingFeature can use them without depending on AppFeature. A width-and-font overload and a bold text-style font helper keep each call site to one line"
  - "Accepted exception (lead, same principle as owner msg 1903): on the iPhone at AX5 the en empty-state title ends on \"anyone.\" and the de title on \"blockiert.\". In both, the last two words are wider than the line, so no layout within C-3 can join them"
  - "`comment.unblock` (\"Unblock %@\") is copied into the SettingFeature catalog with its six existing translations, word for word, because the DetailFeature catalog that holds it is not reachable from SettingFeature"
  - "The Blocked Users list draws the grouped background itself (`scrollContentBackground(.hidden)` with `systemGroupedBackground`). An empty `List` draws none, so the screen would otherwise turn white when the last name is unblocked (C-12 switches in place)"
  - "Picking the level that is already selected does nothing: no write and no `apply`"

patterns-established:
  - "Settings UI tests preset the block list through `EHPANDA_UITEST_BLOCKED_AUTHORS` on every launch, so no case depends on another's storage"

requirements-completed: []

coverage:
  - id: T1
    description: "Analytics level picker in General settings"
    verification:
      - kind: unit
        ref: "SettingFeatureTests on the phone: GeneralSettingAnalyticsLevelTests 9/9 (each pick, lowering to Minimal included, stores the level and applies it once; the current level again applies nothing; no other action applies a level)"
        status: pass
      - kind: automated_ui
        ref: "SettingsModerationUITests.testTheAnalyticsPickerChangesTheLevelAndItsDescription on phone and pad"
        status: pass
    human_judgment: false
  - id: T2
    description: "Blocked Users row and list in Account settings"
    verification:
      - kind: unit
        ref: "BlockedUsersReducerTests 5/5 (sort, unblock, empty state) and SettingReducerNavigationTests 13/13 (pushBlockedUsers)"
        status: pass
      - kind: automated_ui
        ref: "SettingsModerationUITests swipe/context-menu unblock and zero-count cases on phone and pad"
        status: pass
    human_judgment: false
  - id: T3
    description: "Empty-state title line-break screenshots (UI-SPEC C-3), 24 rows"
    verification:
      - kind: automated_ui
        ref: "BlockedUsersTitleLayoutUITests on phone and pad: 6/6 passed on each, 12 screenshots exported per device"
        status: pass
      - kind: visual
        ref: "24-row table below: 22 pass, 2 phone-AX5 rows accepted by the lead (same principle as owner msg 1903)"
        status: pass
    human_judgment: true

duration: about 2h (the plan ran in several sessions)
completed: 2026-11-05
status: complete
---

# Phase 18 Plan 10: Settings analytics picker and Blocked Users Summary

**Settings now offers the three analytics levels, with the selected level's approved description and a Privacy Policy
row, and a change takes effect at once. Account settings lists the blocked commenters, who can be unblocked with a
swipe or the context menu. The empty state's title keeps a single word off its last line in all six languages,
apart from two phone-AX5 cases the lead accepted.**

## Accomplishments

- **Analytics in General (C-9, D-07):**
  - A menu `Picker` labelled `shareAnalyticsData` over Minimal, Basic and Full. It shows no Recommended label, which
    belongs to the first-launch choice only (D-06f).
  - The footer is the selected level's description: Minimal from msg 1818, Basic and Full from Revision 6
    (msg 1880).
  - A Privacy Policy row (`consent.privacy_link`) opens `contact.privacy_policy` in the browser. The final URL is
    Phase 20's (OI-2).
  - `shareAnalyticsDataFooter` is gone from the code and the catalog.
  - A pick sends `analyticsLevelPicked`. `GeneralSettingReducer` stores `setting.analyticsLevel` and calls
    `analyticsClient.apply(level)` once, so lowering to Minimal stops the SDK at once (DD-09a, T-18-18). The view
    never calls the client. There is no confirmation either way.
- **Blocked Users (C-10 to C-12, D-14a):**
  - The Account row sits between the account section and the cookies, signed in or out. It shows the count (0 too)
    before the chevron, read by VoiceOver as one element.
  - It pushes `SettingPath.blockedUsers` through `AccountSettingReducer.Delegate.pushBlockedUsers`, like the other
    Account pushes.
  - The list reads the shared comment block list in `localizedStandardCompare` order, with `blocked_users.footer`
    under it.
  - A full trailing swipe (`blocked_users.unblock`) or the context menu (`comment.unblock`) unblocks at once, with no
    confirmation.
  - With nobody left, the screen switches in place to `ContentUnavailableView` with `blocked_users.empty` and the
    `hand.raised` symbol, without the footer.
- **Title (C-3):** the empty-state title carries `TitleWidowGuard`, now shared from AppComponents.

## Task Commits

1. **Task 1, analytics picker:** `76860cfa5` feat(18-10): analytics level picker in General settings
2. **Task 2, Blocked Users:** `27fca0e69` feat(18-10): Blocked Users row and list in Account settings
3. **Task 3, title screenshots and widow guard:** `459021794` test(18-10): Blocked Users empty-state title layout in
   six languages

## Verification

- **SettingFeatureTests and AppFeatureTests** (`-testPlan FeatureTests`, phone), run after the last code change:
  TEST SUCCEEDED, 402 test cases passed and 0 failed. This includes:
  - `GeneralSettingAnalyticsLevelTests` (9): each pick, lowering to Minimal included, stores the level and applies
    it once (18-03's tests cover `apply(.minimal)` stopping the SDK); picking the current level applies nothing; no
    other action applies a level.
  - `BlockedUsersReducerTests` (5): `localizedStandardCompare` order, unblock removes the name from the shared store,
    unblocking a name not in the list changes nothing, removing the last name leaves the empty state, and nobody
    blocked is the empty state.
  - `SettingReducerNavigationTests` (13), with `pushBlockedUsers`.
  - `TitleWidowGuardTests` (10), with two new cases for the width-and-font overload: a title not yet laid out is
    unchanged, and the pair is joined at exactly its measured width and not 1pt narrower.
- **`SettingsModerationUITests`** (`-testPlan UITests`): 3/3 passed on the phone (FFE7E686) and 3/3 on the pad
  (B470DB46):
  - `testTheAnalyticsPickerChangesTheLevelAndItsDescription`: Minimal to Full, with the footer following and the
    Privacy Policy link present.
  - `testBlockedUsersCanBeUnblockedBySwipeAndContextMenu`: the counted row, the sorted list with its footer, a
    full-swipe unblock, a context-menu unblock, then the empty state in place without the footer.
  - `testTheRowCountsZeroAndOpensTheEmptyList`.
- **`BlockedUsersTitleLayoutUITests`:** 6/6 passed on each device, with 12 attachments exported per device.
- **First-launch regression** (the shared guard moved): `FirstLaunchUITests` and `FirstLaunchTitleLayoutUITests`
  passed, 6/6 tests per device on both devices.
- **Strict lint:** no-cache swiftlint over every changed Swift file found 0 violations.
- **Title rule, static half:** `grep -rn "minimumScaleFactor\|lineLimit"` over `SettingFeature/BlockedUsers` returns
  0, and `shareAnalyticsDataFooter` has 0 hits in the repo.
- **No screenshot committed:** every screenshot stayed in temporary directories outside the repo.

### Title table (UI-SPEC C-3)

The phone is the iPhone Air (FFE7E686) and the pad is the iPad Pro 11" (B470DB46), both in portrait. The title is
`blocked_users.empty`, bold `.title3`, centred. On the pad the Settings screen is a sheet.

| # | Device | Locale | Size | Title's last line | Result |
|---|--------|--------|------|-------------------|--------|
| 1 | phone | en | default | You haven't blocked anyone. (one line) | pass |
| 2 | phone | en | AX5 | anyone. | accepted (lead, same principle as owner msg 1903) |
| 3 | phone | de | default | Du hast niemanden blockiert. (one line) | pass |
| 4 | phone | de | AX5 | blockiert. | accepted (lead, same principle as owner msg 1903) |
| 5 | phone | ko | default | 차단한 사용자가 없습니다. (one line) | pass |
| 6 | phone | ko | AX5 | 없습니다. | pass |
| 7 | phone | ja | default | ブロックしたユーザーはいません。 (one line) | pass |
| 8 | phone | ja | AX5 | いません。 | pass |
| 9 | phone | zh-Hans | default | 你还没有屏蔽任何人。 (one line) | pass |
| 10 | phone | zh-Hans | AX5 | 屏蔽任何人。 | pass |
| 11 | phone | zh-Hant | default | 你還沒有封鎖任何人。 (one line) | pass |
| 12 | phone | zh-Hant | AX5 | 封鎖任何人。 | pass |
| 13 | pad | en | default | You haven't blocked anyone. (one line) | pass |
| 14 | pad | en | AX5 | blocked anyone. | pass |
| 15 | pad | de | default | Du hast niemanden blockiert. (one line) | pass |
| 16 | pad | de | AX5 | niemanden blockiert. | pass (widow guard) |
| 17 | pad | ko | default | 차단한 사용자가 없습니다. (one line) | pass |
| 18 | pad | ko | AX5 | 사용자가 없습니다. | pass |
| 19 | pad | ja | default | ブロックしたユーザーはいません。 (one line) | pass |
| 20 | pad | ja | AX5 | ユーザーはいません。 | pass |
| 21 | pad | zh-Hans | default | 你还没有屏蔽任何人。 (one line) | pass |
| 22 | pad | zh-Hans | AX5 | 你还没有屏蔽任何人。 (one line) | pass |
| 23 | pad | zh-Hant | default | 你還沒有封鎖任何人。 (one line) | pass |
| 24 | pad | zh-Hant | AX5 | 你還沒有封鎖任何人。 (one line) | pass |

Result: 22 pass and 2 accepted (rows 2 and 4). On the first run, before the guard, row 16 also failed, ending on
"blockiert."; the guard fixed it. Rows 2 and 4 failed before and after the guard: at AX5 on the phone, "blocked
anyone." and "niemanden blockiert." are each wider than the line, so the guard leaves the title as written rather
than break a word.

At AX5 the system's large navigation title truncates ("Blocked Use…"). This is the system's own navigation bar,
outside C-3's in-content titles, and was left as it is.

## Deviations from Plan

1. **Widow guard on the empty-state title.** The plan's must-have says plain text. The title is now a custom
   `ContentUnavailableView` label, `BlockedUsersEmptyTitle`: `Text(verbatim:)` of the localized string with the last
   two words joined by U+00A0 when they fit, and the original string as its accessibility label. It still has no
   `\n`, scaling, line limit or fixed width.
2. **Files outside `files_modified`.** The guard moved to the new `AppComponents/TitleWidowGuard.swift`, so
   `FirstLaunchGateView.swift`, `AnalyticsChoiceView.swift` and `FirstLaunchGateTests.swift` (18-09's files) changed
   with it. `FirstLaunchLanguage` is now `ResolvedAppLanguage`. 18-09's behaviour is unchanged, and its UI suites
   pass again on both devices.
3. **Two phone-AX5 rows accepted rather than passing** (rows 2 and 4). The lead accepted them under the same
   principle as owner msg 1903 and is telling the owner.
4. **Grouped background on the Blocked Users list**, so the empty state does not sit on white (C-12).
5. **`comment.unblock` copied into the SettingFeature catalog** with its six existing translations, unchanged.

## Notes for later plans

- 18-11 can reuse `TitleWidowGuard` from AppComponents (`guarded(_:width:font:)` and `boldFont(_:at:)`) for any
  title it must check under C-3.
- 18-12's closing gate should rerun `SettingsModerationUITests` and `BlockedUsersTitleLayoutUITests` on both devices.
  Its table should carry rows 2 and 4 as accepted.
- CONSENT-18-01 and UGC-18-01 stay Pending: 18-11, 18-12 and Phase 20 share them.

## Next

18-11 continues Wave 3.
