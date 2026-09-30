---
quick_id: 260930-o3m
phase: quick-260930-o3m
plan: 01
status: complete
date: 2026-09-30
description: Align the reader's Live Text control with Apple's localized Live Text names (de, ja, zh-Hant)
commit: 63eae621
plan_head_before: e38ab187f96748097a6245e89acf41727912e658
subsystem: ReadingFeature localization
tags: [localization, xcstrings, live-text, accessibility, large-content-viewer]
requires: []
provides: [live_text values aligned with Apple's localized names]
affects: [ReadingToolbar Live Text control, Phase 17 localized marketing captures]
tech-stack:
  added: []
  patterns: []
key-files:
  created: []
  modified:
    - AppPackage/Sources/ReadingFeature/Resources/Localizable.xcstrings
decisions:
  - "Live Text is named with Apple's own localized names: de Live-Text, ja テキスト認識表示, zh-Hant 原況文字 (owner decision 2026-09-30, website Phase 05 UAT Test 8)"
metrics:
  duration: "about 3h 15m wall clock (16:45 to 20:05 UTC+8), dominated by UI-test gates and two orchestrator pauses"
  completed: 2026-09-30
actuals:
  tokens: 240
  tasks: 3
  commits: 1
---

# Quick 260930-o3m: Align Live Text localized names with Apple Summary

The reader's Live Text toolbar control now uses Apple's localized names: de `Live-Text`, ja `テキスト認識表示` and zh-Hant `原況文字`. This was a 3-line catalog change. It was verified in the compiled bundle, by three test gates, and by a 24-configuration localized XCUITest capture on the iPhone Air and a fresh iPad mini 6. In every configuration the name sat in the toolbar, and the Large Content Viewer showed the full name.

`actuals.tokens` is chars/4 over the realized commit diff (943 bytes). The whole catalog file is about 5245 tokens by the same measure. `commits` was measured with `git rev-list --count e38ab187..HEAD` = 1.

## (a) Change

| Locale | Before | After | Apple Support source |
|---|---|---|---|
| de | Live Text | **Live-Text** | https://support.apple.com/de-de/guide/iphone/iphcf0b71b0e/ios |
| ja | ライブテキスト | **テキスト認識表示** | https://support.apple.com/ja-jp/guide/iphone/iphcf0b71b0e/ios |
| zh-Hant | 即時文字 | **原況文字** | https://support.apple.com/zh-tw/guide/iphone/iphcf0b71b0e/ios |

Three locales already matched Apple and are unchanged:
- en `Live Text` (https://support.apple.com/guide/iphone/use-live-text-iphcf0b71b0e/ios)
- ko `라이브 텍스트` (https://support.apple.com/ko-kr/guide/iphone/iphcf0b71b0e/ios)
- zh-Hans `实况文本` (https://support.apple.com/zh-cn/guide/iphone/iphcf0b71b0e/ios)

Also unchanged:
- The key `live_text`, the generated symbol `.liveText`, `extractionState: manual`, and every code identifier.
- All six locales stay `translated`.

The consumer is `Label(.liveText, systemSymbol: .viewfinderCircle)` in `AppPackage/Sources/ReadingFeature/Support/ReadingToolbar.swift`. It is now at lines 44–50 rather than the 42–49 recorded at planning time; the content is unchanged, and the orchestrator accepted the shift.

Commit `63eae621` `fix(quick-260930-o3m): use Apple's Live Text names` is pathspec-scoped: one file, numstat `3 3`.

## (b) Audit record

**Authoritative run.** All commands ran from the repository root, prefixed with `LC_ALL=en_US.UTF-8`, with the patterns exactly as in the plan. Outputs are kept in session scratch as `o3m/audit/*-utf8.txt`.

**Locale note (amendment 1).** The first run used the executor's C locale (`LC_CTYPE=C`). There, git grep treated `・?` byte by byte, so pattern (1) missed the ja value `ライブテキスト` at catalog line 22. The audit was therefore repeated under `LC_ALL=en_US.UTF-8`. The C-locale outputs stay in scratch only.

| # | Command / pattern | Paths | Hits | Classification |
|---|---|---|---|---|
| 1 | `git grep -n -I -i -E 'live[ -]?text\|livetext\|ライブ・?テキスト\|テキスト認識\|即時文字\|原況文字\|實況文字\|实况文字\|实况文本\|實況文本\|라이브 ?텍스트'` | all tracked non-Swift text, excluding `.planning` | `AppPackage/Sources/ReadingFeature/Resources/Localizable.xcstrings` lines 10 (en), 16 (de), 22 (ja), 28 (ko), 34 (zh-Hans), 40 (zh-Hant) | (a) the six `live_text` values, in scope |
| 2 | `git grep -n -I -i -E '"[^"]*(live[ -]?text\|ライブ・?テキスト\|テキスト認識\|即時文字\|原況文字\|实况文本\|實況文本\|라이브 ?텍스트)[^"]*"'` | `*.swift` | `ReadingView.swift:430`, `:468`, `:487` (`logger.debug("analyzeImageForLiveText …")`); `Support/LiveTextHandler.swift:58` (`logger.error("Live Text failed, page …")`) | (b) English logger messages, not localized UI, no action |
| 3a | `git grep -n -I -i -E 'text recogn\|Texterkennung\|文字認識\|文字识别\|文字識別\|文字辨識\|텍스트 ?인식\|テキスト認識'` | `*.xcstrings` (incl. `App/InfoPlist.xcstrings`), `README.md`, `READMEs`, `AltStore.json`, `Config`, `ShareExtension` | none (exit 1) | none |
| 3b | `git grep -n -I -i -w -E 'OCR\|Vision'` | same as 3a | none (exit 1) | none |
| 4 | `git ls-files` filtered by `(^\|/)(fastlane\|metadata)/` | all tracked | none (exit 1) | no fastlane or App Store metadata directory |

**Conclusion.** Only the six `live_text` values are user-facing text that names Live Text. No other string needed alignment. Nothing outside the catalog entry was edited.

## (c) Build results

- **Catalog.** `python3 -m json.tool` passed. The exact values for all six locales, all `translated`, and `extractionState` `manual` were asserted. `git diff --numstat` showed `3 3` for the catalog. The only other line was the pre-existing unstaged half of the staged Phase 17 checkpoint file, which was left untouched.
- **AppFeature build** (`generic/platform=iOS Simulator`): `** BUILD SUCCEEDED **`, no `warning:`/`error:` lines.
- **EhPanda app build** (`generic/platform=iOS Simulator`): `** BUILD SUCCEEDED **`, no `warning:`/`error:` lines. The SwiftLint build plugin ran. The known `DownloadClient+Networking.swift:153 [#ImplicitStrongCapture]` warning did not appear either, probably because the build was incremental.
- **Compiled bundle.** In `EhPanda.app/AppPackage_ReadingFeature.bundle/<locale>.lproj/Localizable.strings` (Apple binary property list), `plutil -extract live_text raw` read:
  - en `Live Text`
  - de `Live-Text`
  - ja `テキスト認識表示`
  - ko `라이브 텍스트`
  - zh-Hans `实况文本`
  - zh-Hant `原況文字`

  The Task 1 tracer verify printed `catalog-ok` and `tracer-ok`.
- Build logs are in session scratch.

## (d) Test gates

The UI tests launch in English (`DeepLinkLauncher` forces `(en)`). They are therefore a regression gate for the committed change, not a check of the new names; the names were checked in (e).

| Gate | Device | result | total | passed | failed | skipped | expected failures | retried |
|---|---|---|---|---|---|---|---|---|
| 1 FeatureTests | iPhone Air | Passed | 1068 | 1057 | 0 | 0 | 11 | 0 |
| 2 UITests | iPhone Air | Passed (`** TEST SUCCEEDED **`) | 53 | 51 | 0 | 2 | 0 | 0 |
| 3 UITests (first run) | Reference project VO iPad mini 6 (VoiceOver on) | **Failed** | 53 | 10 | 43 | 0 | 0 | every failure ran 3 iterations |
| 3 UITests (authoritative, amendment 2) | fresh o3m iPad mini 6 | Passed (`** TEST SUCCEEDED **`) | 53 | 53 | 0 | 0 | 0 | 0 |

- **Gate 1:** meets outcome (i). The known `LoginReturnObservationTests` flake did not occur, so no flake re-run was needed. The total, 1068, is 2 above the plan's approximately 1066 baseline; recorded, not a stop.
- **Gate 2:** the 2 skips are `AccessibilityAuditUITests/testPadSettingAndDetailModalsAudit()` and `DeepLinkPadUITests/testPadTabModalReplacedByDeepLink()`, both pad-only. The total, 53, is below the plan's 54 baseline.
- **Gate 3, UI-test totals:** 53 against the old 56 baseline. The orchestrator attributes this to commit 412f43c4, which consolidated the migration UI coverage; recorded, not a stop.
- **Gate 3, first run.** The first Gate 3 ran on "Reference project VO iPad mini 6" (`436B9FD8-BB94-4E4E-ADF0-2384900DF4CF`) and failed 43 of 53.
  - `com.apple.Accessibility` there reads `VoiceOverTouchEnabled = 1`, and a VoiceOver cursor is visible in the mid-run screenshot. Evidence is in session scratch `o3m/diag/`.
  - Typical failures were "navigation title did not appear", "The reader did not show its panel." and "Neither element nor any descendant has keyboard focus". This pattern fits VoiceOver intercepting synthesized input.
  - The device is deliberately VoiceOver-configured and was not reconfigured.
  - Per amendment 2, the iPad gate and the iPad visual matrix ran on a fresh simulator instead: "o3m iPad mini 6" (`273FDD11-E723-4DD0-9044-BF4AFD49126C`, iPad mini 6th generation, iOS 27.0, VoiceOver key absent, portrait, `large`).
  - The failed first run's result bundle and log are kept in session scratch as a record.
- The Task 2 verify, pointed at the `ui-ipad2` result, printed `gates-ok`.
- **Installed bundles before the gates:**
  - iPhone Air: `app.ehpanda.UITests.xctrunner`, `app.ehpanda.personal`.
  - Reference project VO: none.
  - Fresh iPad: none.

  After the gates, all three hold the Debug app and the UI-test runner.
- Result bundles and logs are in session scratch.

## (e) Visual and accessibility matrix

**Capture route (amendment 3).** On iOS 27, `sim-use ui` exposes only the status bar for EhPanda. The advisory read "The frontmost app exposed an empty accessibility tree", although the reader and its toolbar were on screen. It therefore could not drive the plan's P1–P7/C1–C3 procedure.

The capture instead ran as an orchestrator-written throwaway XCUITest, `LiveTextLocaleScratchUITests`:
- It was copied into `EhPandaUITests/`, never staged, and deleted afterwards.
- `testCaptureLiveTextNames` set the reading direction to Left-to-right in an en launch. It then cold-opened the hermetic single-page link (page 2 of 156, failure placeholder) for each configuration.
- It read the reader navigation bar's buttons from an XCUI snapshot and saved a JSON record plus a `-bar.png`.
- At portrait AX5 it held the control for 6 s, while the host script `lcv-watch.sh` captured `-lcv.png` and `-lcv-2.png` with `xcrun simctl io`.
- **Content size was applied per launch** with `-UIPreferredContentSizeCategoryName` (`UICTContentSizeCategoryL` or `UICTContentSizeCategoryAccessibilityXXXL`), not at simulator level. Simulator `content_size` therefore stayed `large` throughout.

Every PNG was viewed by eye. Evidence is in session scratch `o3m/evidence/` (24 JSON, 24 `-bar.png`, 12 LCV PNGs), outside the repository.

Summary of the verdicts:
- The Live Text control was **in the toolbar in all 24 configurations**, so no overflow capture was needed or taken.
- The Dual Page item (`Doppelseitenmodus` / `デュアルページモード` / `雙頁模式`) was present in every landscape bar, so the landscape overflow condition was exercised.
- The Large Content Viewer HUD was **shown** in both screenshots of all 6 portrait AX5 configurations, with the full name and no ellipsis. ja wraps to two lines on the iPhone and fits on one line on the iPad.
- In every bar capture the viewfinder glyph is present and unclipped.
- No truncation anywhere.

Bar frame (x, y, w, h in points) of the Live Text button:
- iPhone portrait: large (246, 72, 40, 36); AX5 (228.7, 72, 46, 36)
- iPhone landscape: large (659.3, 28, 40, 36); AX5 (634.7, 28, 46, 36)
- iPad portrait: large (580, 36, 40, 36); AX5 (561.5, 36, 46.5, 36)
- iPad landscape: large (908.5, 36, 40, 36); AX5 (882, 36, 46.5, 36)

| # | Device | Orientation | Size | Locale | Source + exact label | Dual Page (landscape) | LCV (portrait AX5) | Truncation | Evidence |
|---|---|---|---|---|---|---|---|---|---|
| 1 | iPhone Air | portrait | large | de | bar: `Live-Text` | n/a | n/a | none | `iphone-portrait-large-de.json`, `-bar.png` |
| 2 | iPhone Air | portrait | large | ja | bar: `テキスト認識表示` | n/a | n/a | none | `iphone-portrait-large-ja.json`, `-bar.png` |
| 3 | iPhone Air | portrait | large | zh-Hant | bar: `原況文字` | n/a | n/a | none | `iphone-portrait-large-zh-Hant.json`, `-bar.png` |
| 4 | iPhone Air | portrait | ax5 | de | bar: `Live-Text` | n/a | shown, `Live-Text` in full | none | `iphone-portrait-ax5-de.json`, `-bar.png`, `-lcv.png`, `-lcv-2.png` |
| 5 | iPhone Air | portrait | ax5 | ja | bar: `テキスト認識表示` | n/a | shown, full name on two lines (`テキスト` / `認識表示`) | none | `iphone-portrait-ax5-ja.json`, `-bar.png`, `-lcv.png`, `-lcv-2.png` |
| 6 | iPhone Air | portrait | ax5 | zh-Hant | bar: `原況文字` | n/a | shown, `原況文字` in full | none | `iphone-portrait-ax5-zh-Hant.json`, `-bar.png`, `-lcv.png`, `-lcv-2.png` |
| 7 | iPhone Air | landscape | large | de | bar: `Live-Text` | present (`Doppelseitenmodus`) | n/a | none | `iphone-landscape-large-de.json`, `-bar.png` |
| 8 | iPhone Air | landscape | large | ja | bar: `テキスト認識表示` | present (`デュアルページモード`) | n/a | none | `iphone-landscape-large-ja.json`, `-bar.png` |
| 9 | iPhone Air | landscape | large | zh-Hant | bar: `原況文字` | present (`雙頁模式`) | n/a | none | `iphone-landscape-large-zh-Hant.json`, `-bar.png` |
| 10 | iPhone Air | landscape | ax5 | de | bar: `Live-Text` | present (`Doppelseitenmodus`) | n/a | none | `iphone-landscape-ax5-de.json`, `-bar.png` |
| 11 | iPhone Air | landscape | ax5 | ja | bar: `テキスト認識表示` | present (`デュアルページモード`) | n/a | none | `iphone-landscape-ax5-ja.json`, `-bar.png` |
| 12 | iPhone Air | landscape | ax5 | zh-Hant | bar: `原況文字` | present (`雙頁模式`) | n/a | none | `iphone-landscape-ax5-zh-Hant.json`, `-bar.png` |
| 13 | o3m iPad mini 6 | portrait | large | de | bar: `Live-Text` | n/a | n/a | none | `ipad-portrait-large-de.json`, `-bar.png` |
| 14 | o3m iPad mini 6 | portrait | large | ja | bar: `テキスト認識表示` | n/a | n/a | none | `ipad-portrait-large-ja.json`, `-bar.png` |
| 15 | o3m iPad mini 6 | portrait | large | zh-Hant | bar: `原況文字` | n/a | n/a | none | `ipad-portrait-large-zh-Hant.json`, `-bar.png` |
| 16 | o3m iPad mini 6 | portrait | ax5 | de | bar: `Live-Text` | n/a | shown, `Live-Text` in full | none | `ipad-portrait-ax5-de.json`, `-bar.png`, `-lcv.png`, `-lcv-2.png` |
| 17 | o3m iPad mini 6 | portrait | ax5 | ja | bar: `テキスト認識表示` | n/a | shown, full name on one line | none | `ipad-portrait-ax5-ja.json`, `-bar.png`, `-lcv.png`, `-lcv-2.png` |
| 18 | o3m iPad mini 6 | portrait | ax5 | zh-Hant | bar: `原況文字` | n/a | shown, `原況文字` in full | none | `ipad-portrait-ax5-zh-Hant.json`, `-bar.png`, `-lcv.png`, `-lcv-2.png` |
| 19 | o3m iPad mini 6 | landscape | large | de | bar: `Live-Text` | present (`Doppelseitenmodus`) | n/a | none | `ipad-landscape-large-de.json`, `-bar.png` |
| 20 | o3m iPad mini 6 | landscape | large | ja | bar: `テキスト認識表示` | present (`デュアルページモード`) | n/a | none | `ipad-landscape-large-ja.json`, `-bar.png` |
| 21 | o3m iPad mini 6 | landscape | large | zh-Hant | bar: `原況文字` | present (`雙頁模式`) | n/a | none | `ipad-landscape-large-zh-Hant.json`, `-bar.png` |
| 22 | o3m iPad mini 6 | landscape | ax5 | de | bar: `Live-Text` | present (`Doppelseitenmodus`) | n/a | none | `ipad-landscape-ax5-de.json`, `-bar.png` |
| 23 | o3m iPad mini 6 | landscape | ax5 | ja | bar: `テキスト認識表示` | present (`デュアルページモード`) | n/a | none | `ipad-landscape-ax5-ja.json`, `-bar.png` |
| 24 | o3m iPad mini 6 | landscape | ax5 | zh-Hant | bar: `原況文字` | present (`雙頁模式`) | n/a | none | `ipad-landscape-ax5-zh-Hant.json`, `-bar.png` |

The amended Task 3 JSON check printed `bad: []`.

Observations recorded without action:
- **Out of scope.** On the iPhone Air in landscape AX5, the reader's floating close (×) button overlaps the page placeholder's Reload glyph. This concerns the failure placeholder layout, not the Live Text name.
- **Runtime warning (not a build or lint diagnostic).** The iPad capture log carries one TCA runtime issue: "Sent 'AppReducer.Action.onScenePhaseChange(.active)' while an action was being processed." The same warning appears 20 times in the first Reference project VO gate log, so it predates this task and is unrelated to the catalog change. The helper produced no build or SwiftLint diagnostic.

## (f) Restoration record

| Device | Content size | Orientation | Reading direction | Other |
|---|---|---|---|---|
| iPhone Air `35988D34-…` | `large` (never changed at simulator level) | portrait (`testRestoreDefaults`, `** TEST SUCCEEDED **`) | Vertical (`testRestoreDefaults` → `setDirection(.vertical)`) | fixture copy `Library/o3m-uitest-fixtures` from the abandoned P-step attempt removed, app terminated |
| o3m iPad mini 6 `273FDD11-…` | `large` | portrait (`testRestoreDefaults`, `** TEST SUCCEEDED **`) | Vertical | no fixture copy was made; not deleted or shut down, the orchestrator handles it |
| Reference project VO iPad mini 6 `436B9FD8-…` | `large` | portrait restored with `testRotateToPortrait` (`** TEST SUCCEEDED **`); the UI-test gate had left it landscape-right | untouched | **VoiceOver untouched** (`VoiceOverTouchEnabled = 1` still); no uninstall, no fixture copy |

- The throwaway `EhPandaUITests/LiveTextLocaleScratchUITests.swift` was deleted.
- The plan's `OrientationScratchUITests.swift` was never created, because amendment 3 superseded it.
- `git status --short -- EhPandaUITests` is empty.

App-install state:

| Device | Before | After |
|---|---|---|
| iPhone Air | Debug app and UI-test runner | unchanged |
| Reference project VO | nothing | Debug app and UI-test runner, from the gate run |
| Fresh iPad | nothing | Debug app and UI-test runner |

Nothing was uninstalled.

## (g) Limits

- Windowed, Split View and Slide Over iPad widths were not exercised. Portrait iPad mini 6 is the narrowest full-screen iPad width.
- Simulator only, not a physical device.
- VoiceOver speech was not audited. Only the accessibility label was checked, through XCUI snapshots.
- en, ko and zh-Hans are unchanged and were not visually checked.
- Content size was driven per launch through the launch argument, not through the simulator-wide setting (see (e)).

## (h) Phase 17 note

No Phase 17 file was edited. The website's screenshot spec for the Live Text section shows `ReadingView` with Live Text active. Localized captures made after this change will therefore show the new names: `Live-Text`, `テキスト認識表示` and `原況文字`.

## (i) Git state

- The only code commit is `63eae621`.
- The Phase 17 entries are still staged, unchanged and uncommitted:
  - `AM .planning/phases/17-localized-screenshot-capture-harness/17-DISCUSS-CHECKPOINT.json`
  - `A  .planning/phases/17-localized-screenshot-capture-harness/17-WINDOW-SNAPSHOT-PROBE.md`
- `.gsd/` is untouched.
- This SUMMARY is uncommitted and left for the orchestrator's docs commit.
- All evidence, logs and result bundles stay in session scratch, outside the repository.

## Deviations from Plan

All deviations were orchestrator-directed after executor pauses and are recorded in the plan's `<orchestrator_amendments>`:

1. **Amendment 1 (Task 1 B).** The audit, and every later multibyte comparison, ran under `LC_ALL=en_US.UTF-8`, because the C locale made git grep miss the ja value.
2. **Amendment 2 (Gate 3, Task 3).** The iPad work moved from the VoiceOver-enabled Reference project VO simulator to a fresh o3m iPad mini 6. Reference project VO was only returned to portrait.
3. **Amendment 3 (Task 3).** The sim-use P1–P7/C1–C3 capture route was replaced by the throwaway `LiveTextLocaleScratchUITests` plus `lcv-watch.sh`, because sim-use sees only the status bar for EhPanda on iOS 27. Content size was applied per launch.

Two executor-side notes:
- The first attempt to remove the watcher's `.done` markers was rewritten to use literal paths. A safety check refused a variable-based `rm` glob, and zsh aborted the first rewrite on an unmatched `*.ready` glob. The markers were then removed.
- The abandoned P-step attempt on the iPhone left a fixture copy and a running app. Both were cleaned up per the orchestrator's instruction.

## Known Stubs

None.

## Self-Check: PASSED

- `AppPackage/Sources/ReadingFeature/Resources/Localizable.xcstrings`: FOUND, with the six expected values.
- Commit `63eae621`: FOUND in `git log`.
- Evidence: 24 JSON records and 36 PNGs in session scratch `o3m/evidence/`.
