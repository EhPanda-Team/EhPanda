---
phase: 16-dynamic-type-accessibility
plan: 17
subsystem: accessibility
tags: [voiceover, voice-control, accessibility-representation, toggle, is-selected, button-style, accessibility-value, accessibility-hidden, catalog, d-20, d-30]

# Dependency graph
requires:
  - phase: 16-16
    provides: "The `ButtonStyle`-for-pressed-parity idiom, the `sim-use describe-ui --point` hit-test as the instrument for label / value / traits, and the install-over protocol on iPhone 17e `67377A20…`"
  - phase: 16-14
    provides: "`accessibility_hardcoded_string` / `accessibility_text_argument` lint rules that gate every accessibility string (D-30)"
provides:
  - "`ExcludeToggle` (EhSetting excluded-languages grid) presents to assistive technologies as a system `Toggle` named `Exclude <language> <category>` via `accessibilityRepresentation` — label, on/off value, toggle trait and Voice Control name from one catalog key with two positional `%@`"
  - "The Laboratory feature cell presents as a `Toggle` carrying its own visible title (live: `AXCheckBox 'Bypass SNI Filtering' value 0, traits [Toggle, Button]`)"
  - "`AppIconRow` is a plain-styled `Button` with `.isSelected` on the chosen icon; its checkmark is out of the accessibility tree (live: `Default` traits `[Selected, Button]`)"
  - "Every Setting root row is a `Button` (Voice Control 'Show names' sees its title); `SettingRowStyle` draws the designed pressed background from `configuration.isPressed`, replacing the tap + long-press pair"
  - "Cookie rows: the key text carries `Valid` / `Invalid` as an `accessibilityValue` from the catalog, the glyph is hidden, the `TextField` stays a separate editable field"
  - "General tags-extension warning glyph hidden; Activity Logs level dot labelled with `log.level.title`; Date Seek verified native and left untouched"
  - "Three `accessibility.*` keys in the SettingFeature catalog, six locales each"
affects: [16-18, 16-19, 16-22, 16-24, 16-25, 16-26]

# Actuals (#2632) — chars/4 over the realized diff; commits measured from the plan ledger.
actuals:
  tokens: 4600
  tasks: 2
  commits: 2
  plan_head_before: aa11f083ab161d38bf5684f45f952803e77f0261

tech-stack:
  added: []
  patterns:
    - "A custom on/off cell whose meaning comes from its position gets `.accessibilityRepresentation { Toggle(isOn: $isOn) { Text(.key) } }` — never `.isToggle` + a stateful label — so the system control supplies label, value, trait and Voice Control name at once while the rendered glyph stays as designed"
    - "A custom selectable row becomes `Button` + `.buttonStyle(.plain)` + `.accessibilityAddTraits(isSelected ? .isSelected : [])`, and the visible checkmark that mirrors that trait is `.accessibilityHidden(true)` so 'Selected' is not announced twice"
    - "A gesture-pair row (tap + `onLongPressGesture(pressing:)` for the highlight) becomes a `Button` whose private `ButtonStyle` reads `configuration.isPressed` for the same background — the 16-16 idiom, reused for the Setting root"
    - "State that a glyph shows beside an editable field goes on the neighbouring key `Text` as an `accessibilityValue`, never on the `TextField` (it would replace the field's text) and never via `.combine` over the field (it would lose the editing role)"

key-files:
  created: []
  modified:
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift
    - AppPackage/Sources/SettingFeature/Components/LaboratorySettingView.swift
    - AppPackage/Sources/SettingFeature/AppearanceSetting/AppearanceSettingView.swift
    - AppPackage/Sources/SettingFeature/SettingView.swift
    - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift
    - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift
    - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift
    - AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings

key-decisions:
  - "Setting root row: the `Button` + `ButtonStyle` path (the plan's first option). `SettingRowStyle` reproduces the row's full-width leading layout, its 10/20-pt padding, the tenth-opacity row-colour background while pressed and the 10-pt corner clip; the `.isButton`-trait fallback was not needed. The pressed look and the tap-on-release behaviour match the gesture pair it replaces."
  - "Cookie validity lives on the key `Text` (`.accessibilityValue(validityValue)`), with the glyph hidden and the `TextField` untouched. The plan's first branch (`.combine` over the row, if the field's label survives) was not taken: folding a `TextField` into one combined element removes its text-field role, and a value on the field itself would replace the cookie text it exists to read out. Live: `AXStaticText 'ipb_member_id' AXValue 'Valid'` beside a separate `AXTextField` with `TextEntry`."
  - "`ExcludeToggle` takes `title` + `category` and maps the column offset with `ExcludedLanguagesCategory(rawValue:)` — the same shape `ExcludeLanguageBlock` already uses — rather than `allCases[offset]`, which the `unchecked_subscript_index_access` rule forbids."
  - "`AppIconRow` became the `Button` itself (taking an `action`), so the row that knows `isSelected` is the element that carries the trait; `AppIconView` no longer applies `.contentShape` + `.onTapGesture` from outside."
  - "The App Icon checkmark uses `.opacity(isSelected ? 1 : 0)` + `.accessibilityHidden(true)` instead of `.visible(isSelected)`: `visible` couples hiding to visibility, and here the image must stay hidden even while visible because the `.isSelected` trait is the announced state."
  - "`requirements-completed` stays empty as in 16-15 / 16-16: A11Y-02 is the whole of round 2 and is closed by the phase, not by one plan."

patterns-established:
  - "Re-inventory before editing: the first-row placeholder at HEAD is an inert `Color.clear` (not the research-era `opacity(0)` toggle), so no `.accessibilityHidden(true)` was needed in the grid file; `SeekButton` is already a `Button` whose label reads as its title only."

requirements-completed: []

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "ExcludeToggle and Laboratory cell as Toggle representations; AppIconRow a Button with .isSelected and hidden checkmark; Setting root row a Button with SettingRowStyle; accessibility.exclude_language in six locales"
    requirement: "A11Y-02"
    verification:
      - kind: other
        ref: "greps: accessibilityRepresentation Sections3=1 Laboratory=1; AppearanceSettingView onTapGesture=0 isSelected=7; SettingView onTapGesture=0 Button=1; swiftlint:disable=0; catalog `1 accessibility keys; missing locales: []`, two `$@` in every locale; `xcodebuild build -scheme EhPanda -destination 'generic/platform=iOS Simulator'` BUILD SUCCEEDED, 0 Violation lines"
        status: pass
      - kind: automated_ui
        ref: "sim-use describe-ui on 67377A20…: Setting root `AXButton 'Account' traits [Button, Scrollable]`; agent-device `[button] \"Account\" … \"About\"`; Laboratory `AXCheckBox 'Bypass SNI Filtering' AXValue '0' traits [Toggle, Scrollable, Button]`; App Icon `AXButton 'Default' traits [Selected, Scrollable, Button]`, `'Ukiyo-e' [Button, Scrollable]`, checkmark position resolves to the row. ExcludeToggle: source-verified only (EhSetting is login-gated)"
        status: pass
    human_judgment: true
    rationale: "The EhSetting page needs a signed-in account (D-09: no credential entered), so the `Exclude <language> <category>` toggle is verified from source and the lint build; 16-25's device walkthrough covers it live"
  - id: D2
    description: "Cookie validity as an accessibilityValue on the key text (two six-locale keys), glyph hidden; General warning glyph hidden; Activity Logs level dot labelled; Date Seek verified native"
    requirement: "A11Y-02"
    verification:
      - kind: other
        ref: "greps: AccountSettingView accessibilityCookieValid|Invalid=1 line (both keys); GeneralSettingView accessibilityHidden(true)=1; AppActivityLogsView accessibilityLabel(log.level.title)=1; both catalogs `missing locales: []` (SettingFeature 3 accessibility keys, DateSeek 0); lint build BUILD SUCCEEDED, 0 Violation lines; image files in git status=0"
        status: pass
      - kind: automated_ui
        ref: "sim-use describe-ui on 67377A20… (logged out): Account `AXStaticText 'ipb_member_id' AXValue 'Valid'`, `AXTextField AXValue 'None' traits [TextEntry, …]`, glyph position → scroll container; General: `StaticText 'Enable Tags Extension'` + `CheckBox` only, no image element; Activity Logs `AXImage 'Error' traits [Image, Scrollable]` beside the timestamp; Date Seek `AXButton 'Older' [Button]`, `AXButton 'Newer' [NotEnabled, Button]`"
        status: pass
    human_judgment: false

# Metrics
duration: 12min
completed: 2026-09-11
status: complete
---

# Phase 16 Plan 17: VoiceOver / Voice Control pass over SettingFeature and DateSeek Summary

**The three custom toggles/selectables in Settings are now real controls in the live accessibility tree — the excluded-languages circle is a `Toggle` named "Exclude Japanese Translated", the Laboratory cell a `Toggle` with its own title, the App Icon row a `Button` whose selection is the `.isSelected` trait — the Setting root rows are `Button`s with their pressed look kept by a `ButtonStyle`, cookie validity is a catalog-keyed value on the key text, two decorative glyphs are hidden, the log-level dot is named, and Date Seek was confirmed native; three six-locale keys, lint build green with no suppression.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-09-11T14:13:32Z
- **Completed:** 2026-09-11T14:26:11Z
- **Tasks:** 2
- **Files modified:** 8 (7 Swift, 1 catalog)

## Accomplishments

### Every modifier added, with its semantic reason

| File | Site | Change | Reason |
|---|---|---|---|
| `EhSetting/EhSettingView+Sections3.swift` | `ExcludeToggle` | init gains `title: LocalizedStringResource` + `category: EhSetting.ExcludedLanguagesCategory`; `.accessibilityRepresentation { Toggle(isOn: $isOn) { Text(.accessibilityExcludeLanguage(String(localized: title), String(localized: category.value))) } }` | The cell was a bare glyph with no label, trait or value — the highest-priority VoiceOver blocker found. Its meaning is geometric (row name + column word); the representation names it "Exclude <language> <category>" and supplies the on/off value, toggle trait and Voice Control name, while the rendered glyph, `withAnimation` toggle and soft haptic on tap stay untouched |
| same | `ExcludeRow` | `else if let category = EhSetting.ExcludedLanguagesCategory(rawValue: offset) { ExcludeToggle(title:category:isOn:) }` | Column offset → category, the shape `ExcludeLanguageBlock` already uses; no `allCases[offset]` (lint) |
| `Components/LaboratorySettingView.swift` | `LaboratoryCell` | `.accessibilityRepresentation { Toggle(isOn: $isOn) { Text(title) } }` (outermost) | The tinted/gray cell had a tap gesture and no role; the representation gives label (the cell's own visible title — no over-labelling), value, trait and name; rendering, `.animation(.default, value: isOn)` and glass effect unchanged |
| `AppearanceSetting/AppearanceSettingView.swift` | `AppIconRow` | now a `Button(action:)` + `.buttonStyle(.plain)` wrapping the row (`.contentShape(.rect)` inside the label); `.accessibilityAddTraits(isSelected ? .isSelected : [])`; `AppIconView` passes `{ $setting.withLock({ $0.appIconType = icon }) }` as the action, its `.onTapGesture` removed | Row had no role and no name; selection is now a trait, not text |
| same | checkmark `Image(systemSymbol: .checkmarkCircleFill)` | `.opacity(isSelected ? 1 : 0)` + `.accessibilityHidden(true)` (replaces `.visible(isSelected)`) | The checkmark is the sighted rendering of the same trait; left in the tree it would announce "Selected" a second time |
| `SettingView.swift` | `SettingRow` | `Button { tapAction(rowType) } label: { Label … }.buttonStyle(SettingRowStyle(color: color))`; `isPressing` state, `.onTapGesture` and `.onLongPressGesture(pressing:)` removed | Row had no role for VoiceOver and no name for Voice Control "Show names"; the `Label` title now supplies both |
| same | new `SettingRowStyle: ButtonStyle` | `configuration.label.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10).padding(.horizontal, 20).background(configuration.isPressed ? color.opacity(0.1) : .clear).clipShape(.rect(cornerRadius: 10)).contentShape(.rect)` | `.plain` has no hook for the pressed background the plan requires kept; the style draws it from `isPressed` exactly as the long-press hack did |
| `AccountSetting/AccountSettingView.swift` | `CookieRow` key `Text` (`keyLabel`, used by both layouts) | `.accessibilityValue(validityValue)` where `validityValue` is `.accessibilityCookieInvalid` / `.accessibilityCookieValid` by `cookieState.value.isInvalid` | The validity the glyph shows by shape and colour, as a value on the key it belongs to (see decision on why not the field or a combined row) |
| same | `validityGlyph` | `.accessibilityHidden(true)` | Would otherwise be read as "Checkmark Circle" / "Xmark Circle" beside the value |
| `GeneralSetting/GeneralSettingView.swift` | `exclamationmarkTriangleFill` warning glyph | `.accessibilityHidden(true)` placed before `.overlay { ProgressView() }` | Decorative beside the row's own text; placing it before the overlay leaves the spinner its own element |
| `AppActivityLogs/AppActivityLogsView.swift` | level dot `Image(systemSymbol: .circleFill)` | `.accessibilityLabel(log.level.title)` | Colour is the dot's only meaning; the `LocalizedStringResource` from `AppModels` names the level (the visible glyph change for Differentiate Without Color is plan 16-22's) |
| `DateSeekFeature/DateSeekPickerView.swift` | `SeekButton`, picker | **no change** | Live: `AXButton 'Older'` / `'Newer' NotEnabled` — the glyph adds nothing to the label, the `DatePicker` is native; adding a label would over-label (Pitfall 7) |

The only `.accessibilityLabel` added in the whole plan is the log-level dot's (an icon with no text); no control with visible text received one; no string literal or `Text(` reached an accessibility label / value modifier (lint-enforced, 0 violations, no `swiftlint:disable`).

### New catalog keys (`SettingFeature/Resources/Localizable.xcstrings`, `extractionState: manual`, six locales)

| Key | en | de | ja | ko | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| `accessibility.exclude_language` | Exclude %1$@ %2$@ | %1$@ %2$@ ausschließen | %1$@の%2$@を除外 | %1$@ %2$@ 제외 | 屏蔽%1$@%2$@ | 排除%1$@%2$@ |
| `accessibility.cookie_valid` | Valid | Gültig | 有効 | 유효함 | 有效 | 有效 |
| `accessibility.cookie_invalid` | Invalid | Ungültig | 無効 | 유효하지 않음 | 无效 | 無效 |

Both arguments of `accessibility.exclude_language` are strings (language name, category word — both already localized `LocalizedStringResource`s from `AppModels`), kept positional (`%1$@`, `%2$@` → generated `accessibilityExcludeLanguage(_:_:)`); no numeric argument, so no `%#@variable@` substitution. The `zh-Hans` wording follows the existing `excluded_languages` key ("屏蔽的语言"), `zh-Hant` follows "排除語言". Keys were inserted in the catalog's sorted position and serialised in its own Xcode style (`"key" : value`, no trailing newline): the diff is 123 added lines, 0 removed. Catalog check: SettingFeature `3 accessibility keys; missing locales: []` (all 155 keys six-locale); DateSeek catalog untouched, `missing locales: []`.

### AX-tree verification (iPhone 17e `67377A20-A90A-4DB2-9A9C-9965532B0AA9`, iOS 26.5, no session)

Install-over per `16-SWEEP.md § Protocol`: built by UDID into `$HOME/Library/Caches/ehpanda-phase16/DerivedData` (tree at `c0291090` + the working Task-2 edits later committed unchanged as `311c1456`), `plutil -extract CFBundleIdentifier raw` → `app.ehpanda.personal`, `xcrun simctl install` over the existing bundle; nothing uninstalled or erased. Baselines read after boot and again before shutdown: `content_size large`, `appearance light`, `increase_contrast disabled` (no size or appearance switch was needed). Instruments: `agent-device snapshot -i` for structure and navigation refs; `sim-use describe-ui --device <UDID>` (entry list) and `--point x,y --json` (VoiceOver hit-test) for role / label / value / traits — the 16-16 instrument.

**Live-verified**

| Screen / control | Excerpt |
|---|---|
| Setting root rows | agent-device: `@e7 [button] "Account"`, `@e8 [button] "General"`, `@e9 [button] "Appearance"`, `@e10 [button] "Download"`, `@e11 [button] "Reading"`, `@e12 [button] "Laboratory"`, `@e13 [button] "About"`. sim-use hit-test at the Account row: `role AXButton, AXLabel "Account", AXValue null, traits ["Button","Scrollable"], enabled true` |
| App Icon picker | sim-use entries: `Button 'Default'`, `'Ukiyo-e'`, `'Developer'`, `'Stand With Ukraine (2022)'`, `'NOT MY PRESIDENT'`. Hit-test `Default`: `AXButton, traits ["Selected","Scrollable","Button"]`; `Ukiyo-e`: `traits ["Button","Scrollable"]`; hit-test at the checkmark's position returns the `Default` row itself (no image element) |
| Laboratory cell | agent-device: `@e6 [switch] "Bypass SNI Filtering"`. sim-use: `role AXCheckBox, AXLabel "Bypass SNI Filtering", AXValue "0", traits ["Toggle","Scrollable","Button"]` — one element, label from the visible title, state as value |
| Account (logged out; cookie rows present with placeholder `None`) | sim-use entries: `StaticText 'ipb_member_id' val='Valid'`, `TextField val='None'` (×5 rows across E-Hentai / ExHentai). Hit-test key: `AXStaticText, AXLabel "ipb_member_id", AXValue "Valid"`; hit-test field: `AXTextField, AXLabel null, AXValue "None", traits ["TextEntry","Scrollable","TextOperationsAvailable"]`; hit-test at the glyph's position: the `AXGroup` scroll container, no image element. No cookie text exists on this simulator (T-16-02: only the value line is recorded) |
| General | sim-use entries: `StaticText 'Enable Tags Extension'`, `CheckBox 'Enable Tags Extension' val='0'` — no image element at the glyph's slot (the glyph is also invisible in this state; the hide is structural) |
| Activity Logs | sim-use entries: `Image 'Error'` (17,176 11×11) beside `StaticText '09-11 23:20:54.009'` and `'Parser'`. Hit-test: `AXImage, AXLabel "Error", traits ["Image","Scrollable"]` |
| Date Seek sheet (via Home › Frontpage › toolbar `Date Seek`) | agent-device: `[button] "Previous Month"`, `[button] "Next Month" [disabled]`, `[button] "Show year picker"`, day buttons `"Today, Friday, September 11" [selected]`; sim-use: `Button 'Older'`, `Button 'Newer' states=['disabled']`. Hit-tests: `AXButton "Older" traits ["Scrollable","Button"]`; `AXButton "Newer" traits ["Scrollable","NotEnabled","Button"]` — title only, no glyph description |

**Source-verified only** (not reachable without a session; no live claim is made)

| Control | Why not live | What the source guarantees |
|---|---|---|
| `ExcludeToggle` (EhSetting › Excluded Languages) | EhSetting is the account settings page; no session (D-09) | `EhSettingView+Sections3.swift`: `.accessibilityRepresentation { Toggle(isOn: $isOn) { Text(.accessibilityExcludeLanguage(String(localized: title), String(localized: category.value))) } }`; `ExcludeRow` passes `title` and `ExcludedLanguagesCategory(rawValue: offset)`; key present in six locales with two positional `%@`; lint build green. The plan's acceptance line asking for a live `Toggle` element whose label starts with "Exclude" is therefore met by this excerpt, not by a snapshot (pre-authorised, env fact 3) |
| Cookie row with an *invalid* value | Only a real cookie can be invalid; none entered | `validityValue` switches on `cookieState.value.isInvalid`; the valid branch is the one verified live, the same modifier carries `.accessibilityCookieInvalid` |
| General warning glyph while visible | Needs `translateTags` on with an empty translator | `.accessibilityHidden(true)` is unconditional on the `Image`, before the spinner overlay |

`agent-device close` → `Closed: default`; simulator shut down (`Shutdown` in `simctl list`). One diagnostic screenshot (Home tab, after a tap that did not navigate) was written to the session scratchpad only; `git status` image count 0.

## Task Commits

1. **Task 1: `ExcludeToggle`, Laboratory cell, App Icon row, Setting root row** — `c0291090` (feat)
2. **Task 2: Account, General, Activity Logs, Date Seek** — `311c1456` (feat)

**Plan metadata:** recorded in the docs commit that carries this file.

## Files Created/Modified

- `AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift` — `ExcludeToggle` title/category + representation; `ExcludeRow` category mapping.
- `AppPackage/Sources/SettingFeature/Components/LaboratorySettingView.swift` — cell representation.
- `AppPackage/Sources/SettingFeature/AppearanceSetting/AppearanceSettingView.swift` — `AppIconRow` as `Button` with `.isSelected`, hidden checkmark.
- `AppPackage/Sources/SettingFeature/SettingView.swift` — `SettingRow` as `Button`; `SettingRowStyle`.
- `AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift` — `keyLabel` with validity value; hidden glyph.
- `AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift` — hidden warning glyph.
- `AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift` — level dot label.
- `AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings` — three keys × six locales.
- `.planning/phases/16-dynamic-type-accessibility/deferred-items.md` — four out-of-scope findings appended (below).

`DateSeekFeature/DateSeekPickerView.swift` and `DateSeekFeature/Resources/Localizable.xcstrings` are in the plan's file list but were not changed: verification showed nothing to add.

## Decisions Made

See `key-decisions` in the frontmatter.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Cookie validity on the key text, not a combined row**
- **Found during:** Task 2
- **Issue:** The plan's first branch combines the `HStack` (key + `TextField` + glyph) into one element carrying the value "only if the field's own label survives combining". A combined element has no text-field role, so VoiceOver could no longer edit the cookie; and the plan's fallback ("keep the field separate and hide only the glyph") would drop the validity value the must-haves require.
- **Fix:** the value goes on the key `Text` beside the glyph (`keyLabel`, shared by both layouts), the glyph is hidden, the `TextField` is untouched. Verified live: key `AXStaticText … AXValue "Valid"`, field `AXTextField` with `TextEntry`.
- **Files modified:** `AccountSetting/AccountSettingView.swift`
- **Committed in:** `311c1456`

### Re-inventory at HEAD

2. **First-row placeholder:** at HEAD `ExcludeRow` already renders an inert `Color.clear` for the missing `original` slot (with a comment explaining why not an `opacity(0)` toggle), so it is not an accessibility element and nothing was hidden; the acceptance grep `accessibilityHidden(true)` in `EhSettingView+Sections3.swift` reads `0` for that reason. The above-default `ExcludeLanguageBlock` already uses real `AppToggle`s.
3. **App Icon checkmark:** at HEAD it used `.visible(isSelected)` (opacity + conditional hidden) rather than a bare `Image`; replaced by unconditional hiding as recorded above.
4. **`SeekButton`:** the research inventory listed `DateSeekPickerView:103` as an icon-only control needing a label; at HEAD it is a `Button` whose label is `Image` + `Text(title)`, and the live tree reads the title only. Nothing added (plan text agrees).

### Environment deviations (pre-authorised by the orchestrator, recorded as required)

5. **Simulator:** iPhone 17e `67377A20-A90A-4DB2-9A9C-9965532B0AA9` (iOS 26.5) instead of the `16-SWEEP.md § Infrastructure` UDIDs; booted from Shutdown, baselines restored, shut down.
6. **agent-device:** `open app.ehpanda.personal --platform ios --device "iPhone 17e" --foreground` worked first time (no `DEVICE_IN_USE`); `agent-device close` run at the end. `sim-use describe-ui` supplied the element-level reads; each excerpt above names its tool.
7. **EhSetting not reachable logged-out:** `ExcludeToggle` source-verified (table above); no credential requested or entered.
8. **Cookie rows reachable after all:** env fact 3 expected the Account cookie rows to be login-gated; on this simulator the logged-out Account screen shows them with placeholder `None`, so the value and the separate field were verified live (no session data involved).
9. **Navigation quirk:** on the Home tab, pressing the `Frontpage` section-header button (agent-device ref and a `sim-use tap` at its centre) did not push the Frontpage list; its `Show All` button did. Recorded as an observation, not investigated (Home is out of scope).

### Observations (no change made)

- The representation `Toggle(isOn: $isOn)` flips the binding directly when VoiceOver activates it, so that path skips the sighted tap's `withAnimation` crossfade and soft haptic (as the plan's literal shape specifies). `ExcludeLanguageBlock` fires its haptic from `.onChange(of: isOn)`; unifying `ExcludeToggle` on that shape would give parity under VoiceOver, if the owner wants it.
- Four out-of-scope findings were appended to `deferred-items.md`: empty-labelled Home thumbnail buttons (Home plan), a run of `Parser` errors in Activity Logs (`Text rating failed to parse`), empty cookies reading "Valid" (pre-existing `isInvalid` semantics, now also the value), and the hidden General warning's information now depending on the footer (16-22's site).

---

**Total deviations:** 1 auto-fixed (Rule 1); 3 re-inventory differences; 5 pre-authorised environment deviations.
**Impact on plan:** Every plan truth met; one acceptance grep (`accessibilityHidden(true)` in the grid file) reads 0 because the placeholder is not an element. No layout changed, no visible element added (D-24) — no D-25 re-sweep candidate from this plan. The `AppIconRow` and `SettingRow` conversions keep the rendered layout (same frames, padding and pressed background); only the hit-test/role changed.

## Issues Encountered

- `agent-device` refs shift after every navigation; a back-press followed by a stale ref opened Appearance instead of General once. Re-snapshotting before each press (as 16-16 noted) resolved it.
- The `zsh` `=====` echo quirk from 16-16 recurred; harmless.

## Known Stubs

None.

## Threat Flags

None — no new network, auth, file-write or schema surface. T-16-02 mitigated (the Account excerpts record only the key label and the `Valid` value; the simulator holds no cookie text). T-16-16 mitigated (every string a catalog symbol; representations labelled from the same resources as the visible text; no label on a text-bearing control; lint 0 violations). T-16-03 mitigated (bundle id checked before the single install-over; nothing uninstalled, erased or reset; baselines restored; text evidence only).

## User Setup Required

None.

## Next Phase Readiness

Wave 15 closed; next is 16-18 (wave 16). The `accessibilityRepresentation { Toggle … }` shape is now the house idiom for custom on/off cells (two sites); `SettingRowStyle` joins `DownloadBannerStyle` (16-16) as the pattern for gesture-pair rows that must keep a pressed look.

## Self-Check: PASSED

All 10 files present; commits `c0291090` and `311c1456` present in `git log`; no absolute home path in this file.
