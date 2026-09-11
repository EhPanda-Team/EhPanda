# Phase 16 — deferred items

Out-of-scope discoveries logged by executors (deviation-rule scope boundary). Not fixed by the plan that found them.

## Found during 16-16

- `AppPackage/Sources/AppComponents/Resources/Localizable.xcstrings` is not strict JSON: the last string entry is followed by a trailing comma before `"version"` (`json.load` fails at line 932). Xcode's catalog compiler tolerates it and the build is green, but any script that reads the catalogs (the six-locale check, the D-30 structural guard) must skip or repair this file first. Plan 16-19 lists this catalog among its files and is the natural place to normalise it while adding keys.
- `AppPackage/Sources/DetailFeature/Resources/Localizable.xcstrings`: the existing `vote_up` / `vote_down` keys carry English (`Vote up` / `Vote down`) in `zh-Hant` while every other locale is translated. Pre-existing; not touched by 16-16 (which only added keys). A translation pass over the DetailFeature catalog should fix both.

## Found during 16-17

- `AppPackage/Sources/HomeFeature`: on the Home tab the Frontpage / Toplists thumbnail grid cells are `Button`s with an **empty** accessibility label (`sim-use describe-ui`: eight `Button|''` entries at 87×120 pt beside the labelled hero-carousel and Toplists buttons). Out of this plan's scope (Setting / DateSeek); belongs to the Home VoiceOver plan.
- `Setting › General › App Activity Logs` on the logged-out simulator shows a run of `Error` / `Parser` entries `Text rating failed to parse: AppModels.AppError.parseFailed` (six identical lines at 23:20:54 after the install-over launch). Not an accessibility item and not touched; a parser owner should look at the rating text path.
- `AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift`: with no session the cookie rows show the placeholder `None` and `CookieValue.isInvalid` is `false`, so the glyph (and now the value) read **Valid** for an empty cookie. Pre-existing semantics of `isInvalid`; the value only mirrors what the glyph already claims. Whether an empty cookie should read as "valid" is an owner question.
- `AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift:66`: the tags-extension warning glyph is hidden per the plan, so the "translations are empty" fact it conveys sighted users now reaches assistive technologies only through the footer text (if any). A value on the toggle row would carry it; plan 16-22 (Differentiate Without Color, same site) is the natural place to decide.

## Found during 16-18

- `AppPackage/Sources/ReadingFeature/Support/ReadingToolbar.swift` + `Support/ControlPanel.swift`: with the panel shown the reader exposes **two** buttons named `Close` (the native toolbar's `topBarLeading` item and the lower panel's glass button — live: `AXButton "Close"` at (20,51) and at (173,690)). Both are correct on their own; together, Voice Control "Tap Close" has to disambiguate ("Which Close?"). Pre-existing design of the owner's round-1 toolbar; out of this plan's scope (no plan item covers the pair). An owner call whether the lower button should carry a distinguishing input label or go.
- `AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift`: the slider row's two end labels (`1` and `112`, `Text(…, format: .number)`) are separate `StaticText` stops beside the slider (live entries). Now that the slider itself announces `Page, 1 of 112`, they are redundant stops for VoiceOver; the plan did not ask to hide them and hiding visible text is a semantic call, so they were left. Owner's call (a `Slider(value:in:label:minimumValueLabel:maximumValueLabel:)` would fold them into the control, at a layout cost).
