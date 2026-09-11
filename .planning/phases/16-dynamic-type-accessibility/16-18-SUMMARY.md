---
phase: 16-dynamic-type-accessibility
plan: 18
subsystem: accessibility
tags: [voiceover, voice-control, accessibility-action, accessibility-zoom-action, accessibility-focus-state, accessibility-value, named-substitution, slider, reader, catalog, d-20, d-30]

# Dependency graph
requires:
  - phase: 16-17
    provides: "The install-over protocol on iPhone 17e `67377A20…`, `sim-use describe-ui --point` as the VoiceOver hit-test, and the verification style of the two previous passes"
  - phase: 16-14
    provides: "`accessibility_hardcoded_string` / `accessibility_text_argument` lint rules that gate every accessibility string (D-30)"
provides:
  - "Every reader page element carries two named actions, `Next page` / `Previous page`, that reach `jump(toPagerIndex:)` — the single page-write path the tap zones already use (live: `custom_actions [\"Previous page\", \"Next page\"]` on each `AXImage` page)"
  - "The assistive zoom (`accessibilityZoomAction`) drives the reader's double-tap toggle, direction-guarded so `zoom in` only fires unzoomed and `zoom out` only zoomed"
  - "The page slider announces `Page, 1 of 112`: catalog label plus a value from named `%#@current@` / `%#@total@` substitutions (live: `Slider label \"Page\" value \"1 of 112\"`)"
  - "Showing the control panel moves VoiceOver focus to the panel's lower Close button (`@AccessibilityFocusState`); hiding lets `.visible(false)` drop the panel from the tree"
  - "Toolbar menus verified already native at HEAD (`Label` titles, `Toggle`s, inline `Picker`) — nothing redone; paging scroll verified native; no timer-driven panel hide exists"
  - "Four `accessibility.*` keys in the ReadingFeature catalog, six locales each"
affects: [16-19, 16-20, 16-24, 16-25, 16-26]

# Actuals (#2632) — chars/4 over the realized diff; commits measured from the plan ledger.
actuals:
  tokens: 4104
  tasks: 2
  commits: 2
  plan_head_before: 1885dc6395b920fd4b2d9afe602c9b257d0673a2

tech-stack:
  added: []
  patterns:
    - "Named actions on a container view propagate to every descendant accessibility element — `.accessibilityAction(named:)` on the reader's content `VStack` surfaces on each page `AXImage`; no per-page attachment is needed"
    - "A numeric accessibility value is a catalog key with named `%#@variable@` substitutions (`accessibility.page_of` → generated `accessibilityPageOf(current:total:)`), copied from the `accessibility.downloading` template: `en` = `de` plural sets, `ja` / `ko` / `zh-*` `other`-only"
    - "A custom overlay that stands in for a modal gets `@AccessibilityFocusState` on its first control and sets it in `.onChange(of: isShown)`; the projected `AccessibilityFocusState<Bool>.Binding` is passed into the private subview that owns the control"
    - "An assistive zoom maps to the existing zoom toggle with a direction guard rather than replaying pinch steps — one zoom path, no new step / clamp arithmetic"
    - "Instrument split: `sim-use describe-ui --point` proves label / traits / custom actions (VoiceOver hit-test) but reports a slider's raw numeric `AXValue`; the `accessibilityValue` string of a slider is read from `agent-device snapshot -i --json` (`value` field of the private-AX node)"

key-files:
  created: []
  modified:
    - AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift
    - AppPackage/Sources/ReadingFeature/Resources/Localizable.xcstrings

key-decisions:
  - "`Next page` is `pageModel.index + 1` and `Previous page` is `- 1`, direction-agnostic: the tap zones' RTL correction maps a screen side to an index offset, and the data source stays forward under every reading direction (RTL flips only the paging axis). Feeding the corrected offset straight into `jump(toPagerIndex:)` reuses the tap zones' path without re-deriving direction; synthesising a trailing-edge tap would have turned `Next page` into the previous page under RTL."
  - "The zoom action maps to `onDoubleTapGestureEnded` (the reader's zoom toggle, which the plan allows) with a direction guard, not to stepped `onMagnifyGestureChanged` / `Ended` calls: `setScale` silently ignores any step that leaves `1...maximum`, so a stepped `zoom out` from 1.2 would be a no-op and a stepped `zoom in` near the maximum likewise — a second zoom path with its own clamping problems."
  - "Panel focus lands on the lower panel's Close button (still in `ControlPanel.swift` at HEAD), exactly as the plan wrote it — no `ToolbarItem` focus experiment was needed. The focus binding is passed into `LowerPanel` as `AccessibilityFocusState<Bool>.Binding` and set from `.onChange(of: showsPanel)` on the panel."
  - "The slider's value total is `Int(range.upperBound)`: `LowerPanel` has no `pageCount`, and the reader constructs `range` as `1...Float(pageCount)`, so the bound is the page count without a new parameter."
  - "The `accessibility.page_slider` label is the single word `Page` (de `Seite`, ja `ページ`, ko `페이지`, zh `页码` / `頁碼`) so VoiceOver reads `Page, 1 of 112, adjustable` — the read-out the plan's truth specifies — and Voice Control's name is one word."
  - "`requirements-completed` stays empty as in 16-15 … 16-17: A11Y-02 is the whole of round 2 and closes with the phase (`requirements.ready-ids` → `0/1 ready`, sibling plans still open)."

patterns-established:
  - "Re-inventory before editing: the plan's control-panel menu work had already been delivered by the owner's round-1 native toolbar (`ReadingToolbar.swift`); it was verified by grep and left untouched rather than re-implemented."

requirements-completed: []

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Reader control panel semantics: slider label + page-of-total value from named substitutions (two six-locale keys); panel focus on show; toolbar menus verified native at HEAD"
    requirement: "A11Y-02"
    verification:
      - kind: other
        ref: "greps: ReadingToolbar.swift `Label(.dualPageMode|.autoPlay, systemSymbol` = 2, `Toggle(isOn: $setting.…` = 2, `Picker(selection: $autoPlayPolicy)` = 1, checkmark = 0; ControlPanel.swift `accessibilityPageSlider` = 1, `accessibilityPageOf(current:` = 1, `accessibilityFocused` = 1, numericText 0 (baseline 0; ReadingToolbar 1, baseline 1); catalog `15 keys; missing locales: []`, page_of substitution check OK; `xcodebuild build -scheme EhPanda -destination 'generic/platform=iOS Simulator'` BUILD SUCCEEDED, 0 Violation lines; swiftlint:disable added = 0"
        status: pass
      - kind: automated_ui
        ref: "iPhone 17e 67377A20…, panel shown — agent-device snapshot -i --json: `{type: Slider, label: \"Page\", value: \"1 of 112\"}`; sim-use describe-ui --point 189,786: `AXSlider, AXLabel \"Page\", traits [Adjustable, Scrollable]`; toolbar: `AXButton Close / Live Text / Auto-Play / More`, `AXStaticText \"1 / 112\" #reading_page_indicator`; lower `AXButton \"Close\"` at (173,690)"
        status: pass
    human_judgment: true
    rationale: "VoiceOver does not run on the simulator, so the focus landing on the Close button when the panel opens is source-verified (`@AccessibilityFocusState` set in `.onChange(of: showsPanel)`) and must be observed on the 16-25 device walkthrough"
  - id: D2
    description: "Reader gesture alternatives: named Next page / Previous page actions on the page elements (two six-locale keys), zoom action on the double-tap toggle, paging scroll verified native, no timer-driven hide"
    requirement: "A11Y-02"
    verification:
      - kind: other
        ref: "greps: `accessibilityAction(named: .accessibilityNextPage|PreviousPage` = 2 (ReadingView.swift), `accessibilityZoomAction` = 1, `accessibilityScrollAction` = 0 (native), `isVoiceOverRunning|accessibilityVoiceOverEnabled` in ReadingFeature = 0; `showsPanel` writers = the reducer's `.toggleShowsPanel` only; image files in git status = 0; lint build BUILD SUCCEEDED, 0 Violation lines"
        status: pass
      - kind: automated_ui
        ref: "sim-use describe-ui --point 195,420 on 67377A20…: `AXImage, custom_actions [\"Previous page\", \"Next page\"], traits [Image, Scrollable]`; the same on every page element in the raw tree (four listed); agent-device `@e3 [scroll-area] [scrollable]`"
        status: pass
      - kind: unit
        ref: "xcodebuild test -scheme EhPanda -testPlan FeatureTests -only-testing:ReadingFeatureTests on 67377A20…: `Test run with 24 tests in 5 suites passed`, `** TEST SUCCEEDED **`"
        status: pass
    human_judgment: true
    rationale: "No simulator tool lists the zoom action (it is not a custom action) and the horizontal paging `ScrollView` was not on screen (the simulator's reader is in vertical mode); both are source-verified and belong to the 16-25 device pass"

# Metrics
duration: 13min
completed: 2026-09-11
status: complete
---

# Phase 16 Plan 18: VoiceOver / Voice Control pass over the reader Summary

**Reading now works without gestures: every page element exposes `Next page` / `Previous page` rotor actions that reach the reader's single page-write path, the assistive zoom drives the double-tap toggle with a direction guard, the page slider announces `Page, 1 of 112` from a named-substitution catalog value, and opening the control panel moves VoiceOver focus into it — four six-locale keys, lint build green twice, `ReadingFeatureTests` 24/24 on the simulator, no suppression.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-09-11T14:32:28Z
- **Completed:** 2026-09-11T14:45:47Z
- **Tasks:** 2
- **Files modified:** 4 (3 Swift, 1 catalog) + `deferred-items.md`

## Accomplishments

### Every change, with its semantic reason

| File | Site | Change | Reason |
|---|---|---|---|
| `Support/ControlPanel.swift` | `Slider` in `LowerPanel` | `.accessibilityLabel(.accessibilityPageSlider)` + `.accessibilityValue(.accessibilityPageOf(current: Int(sliderValue), total: Int(range.upperBound)))` | A slider's own value is a percentage; the page it stands for is the value that means something. `range.upperBound` is the page count (the reader passes `1...pageCount`), so no new parameter |
| `Support/ControlPanel.swift` | `ControlPanel` | `@AccessibilityFocusState private var isCloseButtonFocused: Bool`; `.onChange(of: showsPanel) { _, isShown in if isShown { isCloseButtonFocused = true } }` | The panel is a custom overlay, not a sheet, so nothing moves VoiceOver into it by itself; showing it lands focus on its first control the way a modal surface would. Hiding needs no counterpart: `.visible(false)` (opacity 0 + `accessibilityHidden`) takes the panel out of the tree and VoiceOver falls back to the page |
| `Support/ControlPanel.swift` | `LowerPanel` | new `closeButtonFocus: AccessibilityFocusState<Bool>.Binding` (init parameter, stored `let`); `.accessibilityFocused(closeButtonFocus)` on the lower Close `Button` | The control that receives focus lives in the private subview; the projected binding is threaded in, no state duplicated |
| `ReadingView.swift` | reader content `VStack` (after the gestures) | `.accessibilityAction(named: .accessibilityNextPage) { jump(toPagerIndex: pageModel.index + 1) }` / `.accessibilityPreviousPage … - 1` | Edge taps are the only page-turn while the panel is hidden (VoiceOver criterion 5, Voice Control criterion 2). Both actions reach `jump(toPagerIndex:)`, the one write path (D-07) the tap zones' offset closure already lands on. "Next" is +1 in the data source, which stays forward under every reading direction, so no direction is derived and no second path exists |
| `ReadingView.swift` | same | `.accessibilityZoomAction(performAccessibilityZoom)` | The pinch has no assistive equivalent; the modifier answers VoiceOver's zoom rotor and Voice Control's "zoom in / out" |
| `ReadingView+Gestures.swift` | new `performAccessibilityZoom(_:)` | `switch action.direction` (`@frozen`, exhaustive): `.zoomIn` guards `scale == 1`, `.zoomOut` guards `scale > 1`; then `gestureHandler.onDoubleTapGestureEnded(location: action.point, scaleMaximum:, doubleTapScale:)` | Double tap is the reader's zoom toggle (1 ↔ `doubleTapScaleFactor` at a point); the direction guard keeps the toggle honest so neither direction can land on the opposite side. Pinch steps are deliberately not replayed (see Decisions) |
| `Resources/Localizable.xcstrings` | four keys, six locales | below | D-30: no string reaches an accessibility modifier except through a generated symbol |

No `.accessibilityLabel` was added to any text-bearing control (the lower Close, Live Text and retry controls are `Label`s already); the only label added is the slider's, whose visible content is a track. No string literal or `Text(` reached an accessibility modifier (lint-enforced, 0 violations, no `swiftlint:disable` added — the one in `ReadingView.swift:130` is the pre-existing, reasoned `onDisappear` exception).

### Already satisfied at HEAD, verified, not redone (env fact 1)

The plan's menu work targets `ControlPanel.swift` lines that no longer exist: the owner's round-1 commit `59fb2eb9` moved the upper panel into the **native navigation-bar toolbar** `Support/ReadingToolbar.swift` (92 lines), toggled by `ReadingView.swift:86` `.toolbarVisibility(store.showsPanel ? .visible : .hidden, for: .navigationBar)`. At HEAD:

| Plan item | State at HEAD | Evidence |
|---|---|---|
| Dual-page `Menu` label `Label(.dualPageMode, systemSymbol: .rectangleSplit2x1)` | present (`ReadingToolbar.swift:59`, with the `.symbolVariant(… ? .fill : .none)`) | grep `Label(.dualPageMode, systemSymbol\|Label(.autoPlay, systemSymbol` = **2** |
| Auto-play `Menu` label `Label(.autoPlay, systemSymbol: .timer)` | present (`:75`) | same grep |
| Dual-page items as `Toggle`s | `Toggle(isOn: $setting.enableDualPageMode) { Text(.dualPageMode) }`, `Toggle(isOn: $setting.exceptCover) { Text(.exceptTheCover) }.disabled(!setting.enableDualPageMode)` (`:51–57`) | grep `Toggle(isOn: $setting.` = **2** |
| Auto-play items as a `Picker` | `Picker(selection: $autoPlayPolicy) { ForEach(AutoPlayPolicy.allCases) { Text(policy.value).tag(policy) } } label: { Text(.autoPlay) }.pickerStyle(.inline)` (`:66–73`) | grep `Picker(selection: $autoPlayPolicy)` = **1**, `pickerStyle(.inline)` = **1** |
| Hand-drawn checkmark images | none | grep -i `checkmark` = **0** |
| `.labelStyle(.iconOnly)` | not present and not needed: a `Label` inside a `ToolbarItem` is rendered icon-only by the system toolbar, and the title is its VoiceOver label / Voice Control name | grep = 0; live: `AXButton "Auto-Play"`, `"Live Text"`, `"More"`, `"Close"` — titles, not symbol descriptions |
| Page indicator `.contentTransition(.numericText())` + `reading_page_indicator` | present (`:31–32`) | `numericText` ReadingToolbar = 1 / ControlPanel = 0, both unchanged from before the plan |

`ReadingToolbar.swift` was therefore **read and grepped, not edited** (pre-authorised addition to the plan's touched files). No before/after parity screenshots were taken: no menu was changed, so there is nothing to compare (env fact 1). The dual-page menu is landscape-only (`isLandscape && readingDirection != .vertical`) and was not on screen in portrait; its state is source-verified from the excerpt above.

### New catalog keys (`ReadingFeature/Resources/Localizable.xcstrings`, `extractionState: manual`, six locales)

| Key | en | de | ja | ko | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| `accessibility.next_page` | Next page | Nächste Seite | 次のページ | 다음 페이지 | 下一页 | 下一頁 |
| `accessibility.previous_page` | Previous page | Vorherige Seite | 前のページ | 이전 페이지 | 上一页 | 上一頁 |
| `accessibility.page_slider` | Page | Seite | ページ | 페이지 | 页码 | 頁碼 |
| `accessibility.page_of` | `%#@current@ of %#@total@` | `%#@current@ von %#@total@` | `%#@total@ ページ中 %#@current@ ページ` | `%#@total@ 페이지 중 %#@current@ 페이지` | `第 %#@current@ 页，共 %#@total@ 页` | `第 %#@current@ 頁，共 %#@total@ 頁` |

`accessibility.page_of` carries the `accessibility.downloading` substitution structure: `current` (`argNum 1`) and `total` (`argNum 2`), `formatSpecifier lld`, plural `other` → `%arg`, in every locale; no bare `%lld` in any outer value. Plural sets: `en` = `de` = `{other}`; `ja` / `ko` / `zh-Hans` / `zh-Hant` `other`-only — the six-locale python check printed `15 keys; missing locales: []` and `page_of substitution check OK` (every locale's value contains both `%#@current@` and `%#@total@`). The generated call is `.accessibilityPageOf(current:total:)` — labeled numeric arguments per CLAUDE.md. Keys were inserted alphabetically after the leading `live_text` entry; the file was re-serialised with the `json.dumps(indent=2)` shape it already had (round-trip byte-identical before insertion): 344 added lines, 0 removed across the two commits.

### Auto-hide finding: `no timer-driven hide`

The only writer of `showsPanel` is the reducer's `.toggleShowsPanel` (`ReadingReducer+Body.swift:71`), sent by the centre tap zone; nothing else sets it. `AutoPlayHandler`'s `Timer` (`:10` / `:25`) turns **pages** (`updatePageAction` → `jump`), never the panel. So the plan's conditional does not apply: no timer was suspended, auto-play was left alone (env fact 6), and nothing in `ReadingFeature` reads `isVoiceOverRunning` / `accessibilityVoiceOverEnabled` (grep = 0).

### Scroll actions: native, nothing added

The reader's scroll container is a stock SwiftUI `ScrollView` / `List` in every direction (`horizontalPagingList` is `ScrollView(.horizontal)` + `.scrollTargetBehavior(.paging)`; vertical is `AdvancedList`). Live, every page element carries the `Scrollable` trait and agent-device lists `@e3 [scroll-area] [scrollable]`; VoiceOver's three-finger swipe and Voice Control's "Scroll left / right" are the native scroll actions of that container. `accessibilityScrollAction` = 0 — not duplicated.

### AX-tree verification (iPhone 17e `67377A20-A90A-4DB2-9A9C-9965532B0AA9`, iOS 26.5, no session)

Install-over per `16-SWEEP.md § Protocol`: booted from Shutdown; baselines read after boot `content_size large`, `appearance light`, `increase_contrast disabled`; built by UDID into `$HOME/Library/Caches/ehpanda-phase16/DerivedData` at `73383692` + the working Task-2 edits (later committed unchanged as `5d76fed7`); `plutil -extract CFBundleIdentifier raw` → **`app.ehpanda.personal`**; `xcrun simctl install` over the existing bundle (the only EhPanda bundle installed, before and after); nothing uninstalled, erased or reset. Route: `agent-device open app.ehpanda.personal --platform ios --device "iPhone 17e" --foreground` → Downloads tab → the downloaded gallery row (`112/112`) → reader; no credential entered (D-09). The simulator's reader setting is **vertical** reading direction (page frames stack at y = 0 / 551 / 1101 / 1647).

Instruments, per excerpt: `sim-use describe-ui --device <UDID> --point x,y --json` (VoiceOver hit-test: role, label, traits, custom actions), `sim-use describe-ui --json` (entry list with frames), `agent-device snapshot -i` (structure, refs) and `agent-device snapshot -i --json` (private-AX nodes with the `value` string).

**Live-verified**

| Control | Excerpt |
|---|---|
| Reader page element (panel hidden, hit-test at 195,420) | sim-use: `role AXImage, AXLabel null, custom_actions ["Previous page", "Next page"], traits ["Image", "Scrollable"], enabled true` — the named actions surface on the page element inside the `.contain` container (Pitfall 13 holds); the raw tree lists the same two actions on all four laid-out page images |
| `reading_view` container | agent-device: `@e2 [other] "reading_view"` wrapping `@e3 [scroll-area] [scrollable]` and the panel nodes — the `.contain` element still exposes its children |
| Page slider (panel shown) | agent-device `--json`: `{"type": "Slider", "label": "Page", "value": "1 of 112", "hittable": true}`; sim-use hit-test at 189,786: `role AXSlider, AXLabel "Page", traits ["Adjustable", "Scrollable"]` |
| Native toolbar (panel shown) | sim-use entries: `Button "Close" (20,51)`, `StaticText "1 / 112" #reading_page_indicator`, `Button "Live Text"`, `Button "Auto-Play"`, `Button "More"` — titles, no SF Symbol descriptions; the dual-page menu is landscape-only and absent in portrait as designed |
| Lower panel Close (focus target) | sim-use: `AXButton, AXLabel "Close", traits ["Button", "Scrollable"], frame (173,690 44×44)`; agent-device `@e10 [button] "Close"` enabled while shown, `[disabled]` when hidden |
| Panel toggle | one centre tap (vertical direction) showed the panel (`Close` / `Page` enabled, toolbar appeared); a second hid it again (`[disabled]`) — the reader was left in its initial hidden-panel state |

**Tool limits and source-verified items** (no live claim is made for these)

| Item | Limit | What the source guarantees |
|---|---|---|
| `agent-device snapshot -i --actions` on the reader | Did not recur as "No snapshot backend could read this screen" (env fact 3), but its output printed no action names for any node and hid the page content under the scroll-area, so it produced no usable listing; the listing above comes from `sim-use describe-ui --point` (custom actions) and the raw tree | — |
| Slider value via `sim-use` | Reports `AXValue 0` as a JSON **number** (the slider's raw value through its macOS-AX-style bridge), so it cannot show a slider's `accessibilityValue` string in either direction; the string was read from agent-device's private-AX node (`"1 of 112"`) | `.accessibilityValue(.accessibilityPageOf(current:total:))` on the `Slider` |
| Zoom action | Not a custom action; no simulator tool lists `accessibilityZoomAction` | `ReadingView.swift` `.accessibilityZoomAction(performAccessibilityZoom)`; the handler above |
| Focus landing on show | VoiceOver does not run on the simulator; `AccessibilityFocusState` has no observable effect there | `.onChange(of: showsPanel)` sets `isCloseButtonFocused = true`; the binding is attached to the lower Close button, which becomes visible in the same update |
| Horizontal paging `ScrollView` | Not on screen: the simulator's reader is in vertical mode, and switching the reading direction would write the app's persisted `Setting` in the data container | `horizontalPagingList` is a stock `ScrollView(.horizontal)` with `.scrollTargetBehavior(.paging)`; native scroll exposure is the same as the verified vertical container |

Baselines read back before shutdown: `large` / `light` / `disabled` (nothing was switched, so nothing needed restoring). `agent-device close` → `Closed: default`; `xcrun simctl shutdown` → `Shutdown`. No screenshot was taken; `git status` image count 0.

## Task Commits

1. **Task 1: Control panel — slider label + value, panel focus, catalog keys; toolbar menus verified native** — `73383692` (feat)
2. **Task 2: Reader gestures — named page actions, zoom action, verification** — `5d76fed7` (feat)

**Plan metadata:** recorded in the docs commit that carries this file.

## Files Created/Modified

- `AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift` — slider label + value; `@AccessibilityFocusState` + `.onChange(of: showsPanel)`; `LowerPanel.closeButtonFocus` + `.accessibilityFocused`.
- `AppPackage/Sources/ReadingFeature/ReadingView.swift` — two named page actions and the zoom action on the reader content.
- `AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift` — `performAccessibilityZoom(_:)`.
- `AppPackage/Sources/ReadingFeature/Resources/Localizable.xcstrings` — four keys × six locales.
- `.planning/phases/16-dynamic-type-accessibility/deferred-items.md` — two out-of-scope observations appended (below).

`Support/ReadingToolbar.swift` was read and grepped (pre-authorised) but not changed.

## Decisions Made

See `key-decisions` in the frontmatter.

## Deviations from Plan

### Re-inventory at HEAD (env fact 1, pre-authorised)

1. **Menu labels / `Toggle`s / `Picker` already native.** The upper panel is the native toolbar in `ReadingToolbar.swift` since round 1; every menu item of Task 1 was verified by grep and live (table above) and **not redone**. `ReadingToolbar.swift` joins the plan's touched files as a read-only verification target. The plan's acceptance grep `Label(.dualPageMode, systemSymbol\|Label(.autoPlay, systemSymbol` therefore reads **2 in `ReadingToolbar.swift` and 0 in `ControlPanel.swift`**; the property it checks for is present. No parity screenshots (nothing changed to compare).
2. **Panel focus attached as written.** The lower Close button is still in `ControlPanel.swift`, so the plan's `@AccessibilityFocusState` shape applied cleanly; no `ToolbarItem` experiment and no "not applicable" recording were needed.
3. **Slider total from `range.upperBound`.** The plan writes `total: pageCount`; `LowerPanel` has no such parameter and `range` is `1...Float(pageCount)`, so `Int(range.upperBound)` is the same number with no new plumbing.
4. **`numericText` baseline.** The plan's "unchanged from before the plan" grep is on `ControlPanel.swift`; the transition moved with the indicator to `ReadingToolbar.swift` in round 1. Recorded both: ControlPanel 0 → 0, ReadingToolbar 1 → 1.

### Environment deviations (pre-authorised by the orchestrator, recorded as required)

5. **Simulator:** iPhone 17e `67377A20-A90A-4DB2-9A9C-9965532B0AA9` (iOS 26.5) for the install-over, the AX reads and `ReadingFeatureTests`, instead of the `16-SWEEP.md § Infrastructure` UDIDs and the plan's `88B217DA…`; booted from Shutdown, baselines confirmed, shut down.
6. **AX tooling:** `agent-device open … --device "iPhone 17e"` worked first time; `snapshot -i --actions` produced no action listing (recorded above as a tool limit rather than the previous "no backend" error); `sim-use describe-ui --point` and `agent-device snapshot -i --json` supplied the element-level evidence, each excerpt naming its tool. `agent-device close` run.
7. **Auto-hide:** `no timer-driven hide` (env fact 6); auto-play untouched.
8. **Test destination:** the plan's `-destination … id=88B217DA…` replaced by the UDID above; the rest of the command (`-scheme EhPanda -testPlan FeatureTests -only-testing:ReadingFeatureTests`) as written.

### Observations (no change made)

- The `sim-use` entry list includes the slider preview's page labels (`0`, `1`, `2`) and its `ProgressView` while the preview is hidden by `.visible(false)`; as 16-16 noted, that list is the node tree, not VoiceOver's element list — the hit-test is the instrument for hidden-ness.
- Two out-of-scope items were appended to `deferred-items.md`: the reader exposes two buttons named `Close` while the panel is shown (native toolbar + lower panel → Voice Control disambiguation), and the slider row's end labels `1` / `112` are now redundant VoiceOver stops beside a slider that says `1 of 112`.

---

**Total deviations:** 0 auto-fixed; 4 re-inventory differences; 4 pre-authorised environment deviations.
**Impact on plan:** Every plan truth met; the one acceptance grep that reads 0 on the plan's named file (`Label(.dualPageMode|.autoPlay` in `ControlPanel.swift`) reads 2 on the file that holds the menus at HEAD. No layout changed, no visible element added (D-24) — no D-25 re-sweep candidate from this plan.

## Issues Encountered

- `agent-device tap … --settle` on the reader twice reported "not settled after 10003ms" (the snapshot capture stalls on the reader's tree); the tap itself landed each time, confirmed by a following `snapshot -i --force-full`. Harmless.
- The `zsh` `=====` echo quirk noted by 16-16 recurred once; harmless.

## Known Stubs

None.

## Threat Flags

None — no new network, auth, file-write or schema surface. T-16-17 mitigated (both named actions and the zoom action delegate to `jump(toPagerIndex:)` / `onDoubleTapGestureEnded`; `ReadingFeatureTests` 24/24). T-16-18 not exercised (no menu item was converted, so `.large` appearance could not change). T-16-03 mitigated (bundle id checked before the single install-over; nothing uninstalled, erased or reset; baselines confirmed; text evidence only).

## User Setup Required

None.

## Next Phase Readiness

Wave 16 closed; next is 16-19 (wave 17, shared components). Two instrument notes for later plans: a slider's `accessibilityValue` string is read from `agent-device snapshot -i --json`, not from `sim-use` (numeric `AXValue`); and `.accessibilityAction(named:)` on a container propagates to every descendant element, so page-level actions need one attachment. The reader's two `Close` buttons and the slider's end labels are owner calls recorded in `deferred-items.md`; 16-25's device walkthrough should observe the focus landing and the zoom rotor live.

## Self-Check: PASSED

All 5 files present; commits `73383692` and `5d76fed7` present in `git log`; no absolute home path in this file; no image in `git status`.
