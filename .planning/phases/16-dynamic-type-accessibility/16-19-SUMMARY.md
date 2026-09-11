---
phase: 16-dynamic-type-accessibility
plan: 19
subsystem: accessibility
tags: [voiceover, voice-control, accessibility-value, accessibility-actions, accessibility-hidden, picker, button, rating, catalog, named-substitution, d-20, d-22, d-30, contextmenu-not-exposed]

# Dependency graph
requires:
  - phase: 16-13
    provides: "`16-CONTRAST-AUDIT.md § Decisions` — `STARS=B` (16-19 labels the star group; 16-23 recolours it) and `CONTEXTMENU=not-exposed` with its simulator-tree provenance (swipe actions exposed, context-menu items not)"
  - phase: 16-18
    provides: "The install-over protocol on iPhone 17e `67377A20…`, the `sim-use describe-ui --point` hit-test and `agent-device snapshot -i --actions` / `--json` as the instruments, and the named-substitution catalog template"
  - phase: 16-14
    provides: "`accessibility_hardcoded_string` / `accessibility_text_argument` lint rules that gate every accessibility string (D-30)"
provides:
  - "`RatingView` is one accessibility element on every site (list cells, thumbnail cells, Home cards, history cells, Detail header, user rating): label `accessibility.rating`, value `accessibility.rating_value` carrying the half-rounded rating the stars draw (live: `AXGenericElement 'Rating' AXValue '0.5 out of 5'`; a Frontpage cell button carries `value '1.5 out of 5'`)"
  - "AppComponents catalog: `accessibility.rating` and `accessibility.rating_value` in six locales; `rating_value` is a named `%#@rating@` substitution with `formatSpecifier .1f`, generating `accessibilityRatingValue(rating: Float)`; the catalog's stray trailing comma is gone (strict JSON again)"
  - "The four checkmark menus (favorites index, favorites sort order, toplists type, Downloads filter) verified native inline `Picker`s at HEAD — selection is a trait (live `[selected]` on the chosen item), nothing redone"
  - "`TagCloudCell` spacer image hidden; `TagSuggestionView` phone row is a plain-styled `Button` with its two glyphs hidden; `withArrow` chevron and `ListNoticeView` glyph already inert (verified, not redone)"
  - "Detail tag chips: the context-menu builder also feeds `accessibilityActions`, so Detail / Vote Up / Vote Down / Withdraw Vote reach the Actions rotor under exactly the menu's conditions"
  - "Downloads row: the context-menu-only `Detail` item joins the row's custom actions (live `['Detail', 'Pages', 'Move', 'Delete']`, each once); swipe actions are deliberately not mirrored because SwiftUI already exposes them and does not de-duplicate"
affects: [16-20, 16-23, 16-24, 16-25, 16-26]

# Actuals (#2632) — chars/4 over the realized diff; commits measured from the plan ledger.
actuals:
  tokens: 3201
  tasks: 3
  commits: 3
  plan_head_before: 4fd16013f7da35d4ace614ea00aa31fb79e34d89

tech-stack:
  added: []
  patterns:
    - "A non-integer numeric accessibility value is still a named `%#@variable@` substitution: `formatSpecifier .1f` makes `xcstringstool` generate a `Float` parameter and compiles to `NSStringFormatValueTypeKey f` + `%1$.1f`, which `String(format:locale:)` renders with the locale's decimal separator (`4,5` in de); probe the generator with `xcrun xcstringstool generate-symbols <catalog> -o <dir> -l swift` before committing a shape"
    - "A view inside a `Button` label that carries `.accessibilityElement(children: .ignore)` + label + value merges its label into the button's label and lifts its value onto the button — a list cell needs no `.combine` to announce a rating"
    - "SwiftUI exposes `.swipeActions` as VoiceOver custom actions on iOS 26.5 and does not de-duplicate against `.accessibilityAction(named:)`; mirror only the items that live nowhere else (context-menu-only), and do it with `.accessibilityActions { <the same builder the menu uses> }` so names, sends and conditions are one source"
    - "Instrument split confirmed again: `agent-device snapshot -i --actions` lists a row's custom actions; `sim-use describe-ui --point … --json` returns the VoiceOver hit-test under `data.raw` (`role`, `AXLabel`, `AXValue`, `custom_actions`, `traits`); the plain `agent-device` text tree lists AX-ignored child images (Detail header stars) that VoiceOver never visits"

key-files:
  created: []
  modified:
    - AppPackage/Sources/AppComponents/RatingView.swift
    - AppPackage/Sources/AppComponents/Resources/Localizable.xcstrings
    - AppPackage/Sources/AppComponents/TagCloudView.swift
    - AppPackage/Sources/AppComponents/TagSuggestionView.swift
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsView.swift

key-decisions:
  - "Rating value shape: the plan's primary path (named `%#@rating@` substitution) was kept because the generator CAN express a non-integer substitution — `formatSpecifier .1f` yields `accessibilityRatingValue(rating: Float)`, the rating's own type, so the positional `%@` fallback condition was not met. `.1f` (not `f`, which renders `4.500000`) presents the half-star value: `4.5 out of 5`; whole ratings read `5.0 out of 5`. If the owner prefers `5 out of 5` for whole values, the documented fallback (`formatted(.number.precision(.fractionLength(0...1)))` as a positional `%@`) is the only shape that drops the `.0`; recorded, not applied."
  - "Download row (coordinator decision, option A, 2026-09-12): swipe actions are NOT mirrored. At HEAD the row already exposed `['Pages', 'Move', 'Delete']` as custom actions (SwiftUI's automatic `.swipeActions` exposure), and an uncommitted experiment with two literal `.accessibilityAction(named:)` mirrors read `['Delete', 'Pages', 'Pages', 'Move', 'Delete']` — no de-duplication. The one action that lives only in the context menu, `Detail`, is added via `.accessibilityActions { detailButton }` — the same view `downloadContextMenu()` shows, so name and send cannot drift; live after the fix: `['Detail', 'Pages', 'Move', 'Delete']`, each once."
  - "Tag-cell mirrors use `.accessibilityActions { tagContextMenu(content:translation:) }` (the menu's own builder) rather than hand-written `.accessibilityAction(named:)` calls: the `Detail` item is conditional on a non-empty translation description and the vote items on `didLogin`, and re-stating those conditions beside the menu is exactly the drift env fact 2 forbids. Attached in `DetailFeature/DetailView+Subviews.swift`, where the menu lives (pre-authorised addition to the touched files)."
  - "Cells were not edited: the trailing page glyph in both `GalleryDetailCell` and `GalleryThumbnailCell` is the icon of a `Label`, which VoiceOver does not expose (live cell label `…, Rating, 14, Misc, …` — the bare count), and a cell already reads as one element with the rating value lifted onto its `Button`, so neither `.accessibilityHidden(true)` nor `.combine` had anything to do."
  - "`ListNoticeView` and `withArrow` were not edited for the same reason (Label-native icon; chevron already `.accessibilityHidden(true)` at HEAD); `TagSuggestionView` keeps `.allowsHitTesting(false)` on its text column because the markdown-rendered `Text` could otherwise intercept taps meant for the row."
  - "`requirements-completed` stays empty as in 16-15 … 16-18: A11Y-02 is the whole of round 2 and closes with the phase (`requirements.ready-ids` → `0/1 ready`, sibling plans still open)."

patterns-established:
  - "Re-inventory before editing: the three toolbar menus the plan located in `ToolbarItems.swift` moved into their feature views in round 1 and became `Picker`s there; the plan's file-scoped greps were satisfied against the real files and nothing was converted or screenshotted."

requirements-completed: []

# Coverage metadata (#1602)
coverage:
  - id: D1
    description: "Toolbar / Downloads menus announce selection as a trait (native inline Pickers verified at HEAD); RatingView is one element with catalog label + half-rounded value; two six-locale keys; catalog strict JSON"
    requirement: "A11Y-02"
    verification:
      - kind: other
        ref: "greps: FavoritesView `Picker(selection` = 2 / `pickerStyle(.inline)` = 2 / checkmark 0; ToplistsView 1 / 1 / 0; DownloadsView `Picker(selection` = 1 / checkmark 0; ToolbarItems `Picker(|isSelected` = 0 (no menus there); RatingView `accessibilityElement(children: .ignore)` = 1, `accessibilityRating` = 2; catalog `22 keys; missing locales: []`, `rating_value substitution check OK`, en = de plural sets, strict `json.load` OK; `xcrun xcstringstool generate-symbols` → `accessibilityRatingValue(rating: Float)`; `xcodebuild build -scheme EhPanda -destination 'generic/platform=iOS Simulator'` BUILD SUCCEEDED, 0 Violation lines, swiftlint:disable added 0"
        status: pass
      - kind: automated_ui
        ref: "iPhone 17e 67377A20…: Toplists type menu open → agent-device `[button] \"Yesterday\" [selected]`, `Past Month`, `Past Year`, `All Time`; Downloads filter menu → `[button] \"All\" [selected]`, `Default`, `Second`; Detail header sim-use hit-test (248,358) `AXGenericElement, AXLabel \"Rating\", AXValue \"0.5 out of 5\", children []`; Frontpage cell `Button \"…, Rating, 14, Misc, 2026/09/11, 22:05\" value=\"1.5 out of 5\"`"
        status: pass
    human_judgment: true
    rationale: "The favorites index and sort menus are login-gated (the Favorites tab shows `[button] \"Favorites\"` / `[button] \"Sort Order\"` but their lists cannot load without a session); they are source-verified as the same inline-Picker shape the Toplists menu proved live, and belong to the 16-25 device walkthrough"
  - id: D2
    description: "Decorative glyphs hidden (TagCloudCell spacer, TagSuggestionView glyphs; chevron and notice glyph already inert); TagSuggestionView row a plain Button; Detail tag chips expose their context-menu items as custom actions"
    requirement: "A11Y-02"
    verification:
      - kind: other
        ref: "greps: TagCloudView `accessibilityHidden(true)` = 1; ViewModifiers = 1 (pre-existing); ListNoticeView = 0 (`Label(` = 1, Label-native); TagSuggestionView `accessibilityHidden(true)` = 2, `onTapGesture` = 0, `Button(action` = 1, `buttonStyle(.plain)` = 1; TagCloudView `accessibilityAction(named:` = 0 (no menu in that file); DetailView+Subviews `accessibilityActions {` = 1; lint build BUILD SUCCEEDED, 0 Violation lines"
        status: pass
      - kind: automated_ui
        ref: "Detail tag chip sim-use hit-test (167,460): `AXButton \"ai generated\", custom_actions []` — the correct absence (no translation description, no session); 16-16's Comments row proved the `accessibilityActions` builder surfaces `custom_actions` on the same simulator"
        status: pass
    human_judgment: true
    rationale: "The suggestion row could not be rendered live (the simulator holds no tag translations, so typing `language:` produced no suggestions) and the tag actions only exist for described tags or a signed-in user; both are source-verified and belong to the 16-25 device walkthrough"
  - id: D3
    description: "List cells read as one element with the rating value and no page glyph (verified, no edit needed); Downloads filter menu native; Downloads row exposes Detail + its swipe actions exactly once; DownloadsFeatureTests green"
    requirement: "A11Y-02"
    verification:
      - kind: unit
        ref: "xcodebuild test -scheme EhPanda -testPlan FeatureTests -only-testing:DownloadsFeatureTests on 67377A20…: `Test run with 488 tests in 84 suites passed`, `Suite DownloadsSwipeActionSourceTests passed`, `Suite DownloadSchedulingTests passed`, `** TEST SUCCEEDED **`"
        status: pass
      - kind: automated_ui
        ref: "Downloads row on 67377A20… after the install-over: agent-device `actions: [\"Detail\", \"Pages\", \"Move\", \"Delete\"]`; sim-use hit-test (239,202) `AXButton, custom_actions ['Detail', 'Pages', 'Move', 'Delete'], traits [Scrollable, Button, StaticText]`; HEAD baseline `[\"Pages\", \"Move\", \"Delete\"]`; literal-mirror experiment `[\"Delete\", \"Pages\", \"Pages\", \"Move\", \"Delete\"]`"
        status: pass
      - kind: other
        ref: "greps: `accessibilityActions {` in DownloadsView.swift = 1 (`accessibilityAction(named:` over both Downloads files = 0 — see Deviations); GalleryDetailCell / GalleryThumbnailCell `accessibilityHidden(true)` = 0 with the page glyph inside a `Label` (1 site each); `deleteButton(role:` occurrences unchanged inside both pinned regions; lint build BUILD SUCCEEDED, 0 Violation lines; image files in git status = 0"
        status: pass
    human_judgment: false

# Metrics
duration: 26min
completed: 2026-09-11
status: complete
---

# Phase 16 Plan 19: VoiceOver / Voice Control pass over shared components, list hosts and Downloads Summary

**Every gallery rating now announces once as "Rating, 4.5 out of 5" from a `Float` named-substitution catalog value, the four checkmark menus were verified to be native inline Pickers (selection is a trait, live), the tag-cloud and suggestion glyphs are out of the tree with the suggestion row a real `Button`, Detail tag chips expose their context-menu items as rotor actions from the menu's own builder, and the Downloads row gains the one action it was missing (`Detail`) without doubling the swipe actions SwiftUI already exposes — three lint-green commits, 488/488 `DownloadsFeatureTests`, no suppression.**

## Performance

- **Duration:** 26 min (2026-09-11T14:51:57Z → 2026-09-11T15:18:50Z; the checkpoint wait is not counted)
- **Tasks:** 3
- **Files modified:** 6 (5 Swift, 1 catalog) + `deferred-items.md`

## Accomplishments

### Every change, with its semantic reason

| File | Site | Change | Reason |
|---|---|---|---|
| `AppComponents/RatingView.swift` | the star `HStack` | `.accessibilityElement(children: .ignore)` + `.accessibilityLabel(.accessibilityRating)` + `.accessibilityValue(.accessibilityRatingValue(rating: rating))` where `rating` is `rawRating.halfRounded` | Five SF Symbol images read as "Star Fill, Star Fill, Star Leadinghalf Filled, Star, Star" and make the listener count; one element carries the fact and the value the stars draw. Every `RatingView` site inherits it (list / thumbnail / Home card / history cells, Detail header, user rating) |
| `AppComponents/Resources/Localizable.xcstrings` | two new keys, six locales | `accessibility.rating` (plain), `accessibility.rating_value` (`%#@rating@`, `formatSpecifier .1f`) | D-30: no string reaches an accessibility modifier except through a generated symbol; numeric argument as a labelled parameter per CLAUDE.md |
| same | the entry before `"version"` | one trailing comma removed | Rule 3 (below): the file was not strict JSON |
| `AppComponents/TagCloudView.swift` | `TagCloudCell` spacer `Image(systemSymbol: .photo).opacity(0).overlay(KFImage…)` | `.accessibilityHidden(true)` | The chip's text names it; the spacer would be announced as "Photo" and the tag image has no label |
| `AppComponents/TagSuggestionView.swift` | `SuggestionCell` phone row | `Button(action: action) { HStack … }` + `.buttonStyle(.plain)` replaces `.contentShape(.rect).onTapGesture(perform: action)`; `.accessibilityHidden(true)` on the `magnifyingglass` and `photo` glyphs | A gesture-tapped `HStack` is not a control for VoiceOver or Voice Control; the row's two texts name the button, so the search glyph restates its purpose and the photo glyph only reserves space. Layout, `.contentShape(.rect)` and `.allowsHitTesting(false)` on the text column are kept |
| `DetailFeature/DetailView+Subviews.swift` | `TagRow.tagContentView` chip `Button` | `.accessibilityActions { tagContextMenu(content: content, translation: translation) }` after the `.contextMenu` | `CONTEXTMENU=not-exposed`: the menu's own builder fills the rotor, so Detail (description present) and Vote Up / Vote Down / Withdraw Vote (`didLogin`) appear under exactly the menu's conditions |
| `DownloadsFeature/DownloadsView.swift` | `DownloadRow.body` after the trailing `.swipeActions` | `.accessibilityActions { detailButton }` with a doc comment | The context menu's `Detail` is the only row action with no swipe counterpart; swipe actions are already custom actions (see Deviations) |

No `.accessibilityLabel` was added to any text-bearing control; no string literal or `Text(` reached an accessibility modifier (lint 0 violations, no `swiftlint:disable` added).

### Already satisfied at HEAD, verified, not redone (env fact 1)

| Plan item | State at HEAD | Evidence |
|---|---|---|
| Favorites index menu | `FavoritesView.swift:93-105` — `Menu { Picker(selection: $store.favoritesIndex.sending(\.setFavoritesIndex)) { ForEach(-1..<10) … } label: { Text(.RLocalizable.favorites) }.pickerStyle(.inline) }` | grep `Picker(selection` = 2, `pickerStyle(.inline)` = 2, checkmark = 0 in that file; login-gated → source-verified (Favorites tab live: `[button] "Favorites"`, `[button] "Sort Order"`, list loading) |
| Sort order menu | `FavoritesView.swift:108-120` — same shape over `FavoritesSortOrder.allCases` (it belongs to Favorites; Search results have no sort menu at HEAD — `SearchView.swift` grep `sort` = 0) | same |
| Toplists type menu | `ToplistsView.swift:42-52` — `Picker(selection: $store.type.sending(\.setToplistsType))` inline | grep 1 / 1 / 0; **live**: menu open → `[button] "Yesterday" [selected]`, `Past Month`, `Past Year`, `All Time` |
| Downloads filter menu | `DownloadsView.swift:139-147` — `Picker(selection: $store.folderFilter)` inline under a `Manage Folders` section | grep 1, checkmark 0; **live**: `[button] "All" [selected]`, `Default`, `Second` |
| `ToolbarItems.swift` menus | None — the file holds `ToolbarFeaturesMenu` and four `Label` buttons (92 lines); the three menus moved into their feature views in round 1 (`59fb2eb9`) | plan grep `Picker(\|isSelected` on it = 0; the real files carry the property |
| `withArrow` chevron (`ViewModifiers.swift:40-44`) | already `.accessibilityHidden(true)` with a comment | grep = 1 (pre-existing) |
| `ListNoticeView` glyph | `Label(title:icon:)` — a `Label`'s icon is not exposed (16-16 proved this on the Torrents `Label` variant) | grep `accessibilityHidden(true)` = 0, `Label(` = 1 |
| Cell page glyphs (`GalleryDetailCell.swift:267-272`, `GalleryThumbnailCell.swift:208-213`) | `Label { Text(pageCount) } icon: { Image(.photoOnRectangleAngled) }` | **live** Frontpage cell label `…, Rating, 14, Misc, 2026/09/11, 22:05` — the bare count, no symbol description |
| Cell as one element | `GalleryList` wraps each cell in a `Button`; the button's label is the merged text and the `RatingView` value is lifted onto it | **live** `Button "…" value="1.5 out of 5"` (sim-use), `{type: Button, label: "…, Rating, 14, Misc, …", value: "1.5 out of 5"}` (agent-device `--json`) — no `.combine` needed |
| Hand-drawn checkmark images | none in the plan's scope; the only `Image(systemSymbol: .checkmark)` in `Sources` is a `Label` in `AppActivityLogsView.swift:184` (SettingFeature, 16-17's file) | grep |

No parity screenshots were taken: no menu was converted, so there is nothing to compare (env fact 1). `$HOME/Library/Caches/ehpanda-phase16/round2/` received no file from this plan.

### Rating value: argument shape

`accessibility.rating_value` is a named `%#@rating@` substitution in all six locales — `argNum 1`, `formatSpecifier ".1f"`, plural `other` → `%arg` (en = de = `{other}`; ja / ko / zh-Hans / zh-Hant `other`-only). The plan's fallback condition ("the generator cannot express a non-integer substitution") did not trigger: `xcrun xcstringstool generate-symbols` produces `static func accessibilityRatingValue(rating: Float) -> LocalizedStringResource` (defaultValue `"\(rating, specifier: "%.1f")"`), i.e. the rating's own type; `xcstringstool compile` emits `NSStringFormatValueTypeKey f` with the `other` variant `%1$.1f`; `String(format: "%.1f", locale:)` renders `4.5` / `4,5` (de) / `4.5` (ja). `f` alone was rejected (renders `4.500000`), `g` / `lf` generate `Double` (not the rating type). Live: `0.5 out of 5`, `1.5 out of 5`, `3.5 out of 5`, `4.5 out of 5`, `5.0 out of 5`.

| Key | en | de | ja | ko | zh-Hans | zh-Hant |
|---|---|---|---|---|---|---|
| `accessibility.rating` | Rating | Bewertung | 評価 | 평점 | 评分 | 評分 |
| `accessibility.rating_value` | `%#@rating@ out of 5` | `%#@rating@ von 5` | `5 点満点中 %#@rating@ 点` | `5점 만점에 %#@rating@점` | `%#@rating@ 分，满分 5 分` | `%#@rating@ 分，滿分 5 分` |

Owner note: whole ratings read `5.0 out of 5`. The only shape that says `5 out of 5` is the plan's positional fallback (`rating.formatted(.number.precision(.fractionLength(0...1)))` as `%@`); it was not applied because the plan's decision tree lands on the named substitution.

### `CONTEXTMENU=not-exposed` at the real sites

- **Tag cells.** `AppComponents/TagCloudView.swift` has no `.contextMenu` and no gesture (its cells are the callers' `Button`s), so the plan's grep on it reads 0 by construction (env fact 2). The menu lives in `DetailFeature/DetailView+Subviews.swift` (`TagRow.tagContentView`); the builder `tagContextMenu(content:translation:)` now also fills `.accessibilityActions`. Live on a public gallery with no session and no translation descriptions the chip reads `AXButton "ai generated", custom_actions []` — the correct absence; the builder form is the one 16-16 proved live (`custom_actions ["Open link"]` on the Comments row).
- **Downloads row.** SwiftUI already exposes the swipe set as custom actions (HEAD: `["Pages", "Move", "Delete"]`), so the only context-menu item that needed a mirror is `Detail`; live after the change: `["Detail", "Pages", "Move", "Delete"]`. `Update` / `Pause` / `Resume` are in the swipe set whenever their conditions hold and are exposed then.

### AX-tree verification (iPhone 17e `67377A20-A90A-4DB2-9A9C-9965532B0AA9`, iOS 26.5, no session)

Install-over per `16-SWEEP.md § Protocol`, twice: booted from Shutdown; baselines `content_size large`, `appearance light`, `increase_contrast disabled`; built by UDID into `$HOME/Library/Caches/ehpanda-phase16/DerivedData`; `plutil -extract CFBundleIdentifier raw` → **`app.ehpanda.personal`** both times; `xcrun simctl install` over the existing bundle (the only EhPanda bundle installed, before and after); nothing uninstalled, erased or reset. The first install carried Tasks 1–2 plus the uncommitted duplicate-actions experiment; the second (Task 3 at `9b349248`'s tree) replaced it, so the simulator now holds the committed tree. Route: `agent-device open app.ehpanda.personal --platform ios --device "iPhone 17e" --foreground [--relaunch]`; no credential entered (D-09). Instruments per excerpt: `agent-device snapshot -i` / `-i --actions` / `-i --json`, `sim-use describe-ui --device <UDID>` (entry list) and `--point x,y --json` (hit-test, `data.raw`).

**Live-verified**

| Surface | Excerpt |
|---|---|
| Frontpage list cell (Home › Frontpage › Show All) | sim-use entries: `Button "[Cue-02] 罗德岛常识修改 [AI Generated], 米凯拉的卫兵, Chinese, Rating, 1…" value="1.5 out of 5"`, `Button "[Pixiv] Melowh … Rating, 1139,…" value="3.5 out of 5"`, `… value="4.5 out of 5"`; agent-device `--json`: `{type: Button, label: "…, Chinese, Rating, 14, Misc, 2026/09/11, 22:05", value: "1.5 out of 5"}`. HEAD baseline read before Task 1: the same cell label with no rating at all (`…, ramaboy28, English, 5, Doujinshi, …`) |
| Detail header rating (standalone `RatingView`) | sim-use hit-test (248,358): `AXGenericElement, AXLabel "Rating", AXValue "0.5 out of 5", custom_actions [], children []`; entry `@20 GenericElement "Rating" (211,352 75x13)` beside `StaticText "0.50"` |
| Home hero card / Search history cell (other `RatingView` hosts) | sim-use: hero `Button "Caste Saijoui …" value="4.5 out of 5"`, `value="2.0 out of 5"`, `value="5.0 out of 5"`; history `Button "單腳, cococan16, Rating" value="0.5 out of 5"`; hit-test on the history cell: `AXButton, AXLabel "單腳, cococan16, Rating", AXValue "0.5 out of 5"` |
| Toplists type menu (Home › Toplists › Show All › `Type`) | agent-device toolbar `[button] "Type"`; open: `[button] "Yesterday" [selected]`, `[button] "Past Month"`, `[button] "Past Year"`, `[button] "All Time"` |
| Downloads filter menu (`Filters`) | open: `[button] "Manage Folders"`, `[button] "All" [selected]`, `[button] "Default"`, `[button] "Second"` |
| Downloads row — HEAD | agent-device `--actions`: `[button] "<title>" actions: ["Pages", "Move", "Delete"]` |
| Downloads row — literal-mirror experiment (uncommitted, reverted) | `actions: ["Delete", "Pages", "Pages", "Move", "Delete"]` |
| Downloads row — committed Task 3 | `actions: ["Detail", "Pages", "Move", "Delete"]`; sim-use hit-test (239,202): `AXButton, custom_actions ['Detail', 'Pages', 'Move', 'Delete'], AXValue null, traits ['Scrollable', 'Button', 'StaticText']` |
| Detail tag chip | sim-use hit-test (167,460): `AXButton "ai generated", AXValue null, custom_actions [], traits ['Scrollable', 'Button']` |
| Favorites tab (login-gated) | agent-device: `[button] "Favorites"`, `[button] "Sort Order"`, `[button] "More"`, `[search] "Search"`, `[other] "Loading..."` — the menus exist and are titled; their lists cannot load without a session |

**Source-verified only** (no live claim): the favorites index / sort menus' items (login-gated; same `Picker` shape as the live Toplists menu); the `TagSuggestionView` row (the simulator holds no tag translations — typing `language:` into the Search field produced no suggestion rows); the tag chips' `Detail` / vote actions (need a described tag or a session); `ListNoticeView` (QuickSearch, not opened; `Label`-native per 16-16's Torrents evidence).

Baselines read back before shutdown: `large` / `light` / `disabled` (nothing switched). `agent-device close` → `Closed: default`, `sessions: 0`; `xcrun simctl shutdown` → `Shutdown`. No screenshot taken; `git status` image count 0.

## Task Commits

1. **Task 1: Toolbar menus (selection as trait) and `RatingView` (label + value)** — `ac1b92b0` (feat)
2. **Task 2: Decorative glyphs hidden; `TagSuggestionView` row native; tag context-menu mirrors** — `86ad21a7` (feat)
3. **Task 3: List cells and download rows — hidden glyphs, single-element cells, named actions, Downloads menu, verification** — `9b349248` (feat)

**Plan metadata:** recorded in the docs commit that carries this file.

## Files Created/Modified

- `AppPackage/Sources/AppComponents/RatingView.swift` — single element, label + value.
- `AppPackage/Sources/AppComponents/Resources/Localizable.xcstrings` — two keys × six locales; trailing comma normalised.
- `AppPackage/Sources/AppComponents/TagCloudView.swift` — spacer image hidden.
- `AppPackage/Sources/AppComponents/TagSuggestionView.swift` — `Button` row, glyphs hidden.
- `AppPackage/Sources/DetailFeature/DetailView+Subviews.swift` — tag chip `accessibilityActions` from the menu builder.
- `AppPackage/Sources/DownloadsFeature/DownloadsView.swift` — `accessibilityActions { detailButton }` on the row.
- `.planning/phases/16-dynamic-type-accessibility/deferred-items.md` — one out-of-scope observation appended (below).

Read and grepped, not changed: `ToolbarItems.swift`, `ViewModifiers.swift`, `ListNoticeView.swift`, `GalleryDetailCell.swift`, `GalleryThumbnailCell.swift`, `DownloadsView+Subviews.swift`, `FavoritesView.swift`, `ToplistsView.swift`, `SearchView.swift`, `GalleryList.swift`.

## Decisions Made

See `key-decisions` in the frontmatter.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] AppComponents catalog normalised to strict JSON**
- **Found during:** Task 1 (adding keys; pre-authorised by env fact 4)
- **Issue:** a trailing comma after the last string entry, before `"version"` (`json.load` failed at line 932); Xcode tolerated it, scripts could not.
- **Fix:** the one comma removed while inserting the keys; the file was re-serialised in Xcode's own shape (indent 2, `" : "`, sorted keys, no trailing newline), round-trip byte-identical apart from the insertion — diff: 1 line removed (`    },`), 180 added.
- **Files modified:** `AppPackage/Sources/AppComponents/Resources/Localizable.xcstrings`
- **Verification:** strict `json.load` OK; `22 keys; missing locales: []`; the DetailFeature `vote_up` / `vote_down` zh-Hant issue was not touched (still deferred).
- **Committed in:** `ac1b92b0`

### Plan deviations decided at the Task-3 checkpoint (coordinator, option A, 2026-09-12)

**2. Download row: swipe actions not mirrored; only the context-menu-only `Detail` added**
- **Found during:** Task 3
- **Issue:** the plan's truth and acceptance ("named `accessibilityAction`s mirroring its swipe actions — inspect, move, update, pause/resume, delete"; grep ≥ 3) rest on the research-era assumption that swipe actions are invisible to assistive technologies. Live at HEAD the row already exposed `["Pages", "Move", "Delete"]`, and an uncommitted experiment with two literal mirrors measured `["Delete", "Pages", "Pages", "Move", "Delete"]` — SwiftUI does not de-duplicate, so the literal plan would double every rotor entry. `16-CONTRAST-AUDIT § Decisions` (`CONTEXTMENU=not-exposed`) names *context-menu* items of Downloads rows as what 16-19 mirrors.
- **Fix:** `.accessibilityActions { detailButton }` in `DownloadRow` beside the swipe blocks, with a doc comment recording the measurement; the plan's grep `accessibilityAction(named:` over the two Downloads files therefore reads **0** (`accessibilityActions {` = 1) and the "≥ 3 incl. inspect / pause-or-resume / delete" criterion is met by SwiftUI's own exposure (live: each of Detail / Pages / Move / Delete exactly once). Delete still goes through the confirmation alert (the swipe button's `rowStore.send(.deleteButtonTapped)` is untouched). The plan's artifact line placing `accessibilityAction` in `DownloadsView+Subviews.swift` is satisfied in `DownloadsView.swift` instead — the plan's own "build the actions where the row is constructed" option — because the conditions and buttons live there.
- **Files modified:** `AppPackage/Sources/DownloadsFeature/DownloadsView.swift`
- **Verification:** live row excerpt above; `DownloadsSwipeActionSourceTests` and `DownloadSchedulingTests` green (the addition sits outside both pinned brace regions).
- **Committed in:** `9b349248`

### Re-inventory at HEAD (env facts 1–2, pre-authorised)

3. **Menus already native.** All four are inline `Picker`s in their feature views; `ToolbarItems.swift` holds no menu, so its grep reads 0 and the real files read 2 / 1 / 1. Nothing converted; no `--scale 1` parity screenshots (and `xcrun simctl io screenshot` has no `--scale` flag anyway, env fact 5).
4. **Tag-cell menu mirrored in `DetailView+Subviews.swift`,** not `TagCloudView.swift` (which has no menu): plan grep on `TagCloudView.swift` = 0, DetailFeature `accessibilityAction` = 1 — in the `accessibilityActions { }` builder form (16-16's precedent) so the conditions are the menu's own.
5. **Cells, chevron, notice glyph not edited:** `Label`-hosted icons are not exposed and the cell already reads as one element with the value; the plan's per-file `accessibilityHidden(true)` greps read 0 on `GalleryDetailCell.swift`, `GalleryThumbnailCell.swift` and `ListNoticeView.swift` with the property verified live / by construction.

### Environment deviations (pre-authorised, recorded as required)

6. **Simulator:** iPhone 17e `67377A20…` for everything (`xcodebuild test`, install-over ×2, AX reads) instead of the `16-SWEEP.md § Infrastructure` UDIDs and the plan's `88B217DA…`; booted from Shutdown, baselines confirmed unchanged, shut down.
7. **AX tooling:** `agent-device open … --device "iPhone 17e"` (a stale `default` session had to be closed first, twice); `snapshot -i --actions` listed the row actions directly this time; `sim-use describe-ui --point … --json` read under `data.raw`; each excerpt names its tool. `agent-device close` run (`sessions: 0`).
8. **Test destination:** the plan's `-destination … id=88B217DA…` replaced by the UDID above; the rest of the command as written.

### Observations (no change made)

- `deferred-items.md` gained one entry: the Detail user-rating `RatingView` (`ActionSection`) is driven by a `DragGesture` only; it now announces its value correctly but has no `accessibilityAdjustableAction`, so assistive users cannot rate — DetailFeature site, owner call. A second entry drafted at the checkpoint (the Downloads `Detail` context item unexposed) was removed once this plan exposed it.
- The plain `agent-device` text tree still lists the Detail header's star images as `[image]` children under `[other] "Rating"`; the hit-test shows `children []` — the node dump is not VoiceOver's element list (16-16's caveat holds).
- `agent-device press` on Home hero-carousel pages fails with a diagnostics reference (the paging `ScrollView`); the Frontpage list and Downloads tab were used for navigation instead.

---

**Total deviations:** 1 auto-fixed (Rule 3); 1 checkpoint-decided plan deviation (option A); 3 re-inventory differences; 3 pre-authorised environment deviations.
**Impact on plan:** Every truth met, with the download-row truth met by SwiftUI's own swipe exposure plus the one missing item rather than by duplicating mirrors. No layout changed, no visible element added (D-24) — no D-25 re-sweep candidate from this plan. `STARS=B` colour work remains 16-23's.

## Issues Encountered

- The zsh `=====` echo quirk (a bare `=word` is expanded) truncated several batched reads; re-read with `printf`.
- `agent-device type` into the Search field worked only after a second press on the field; the typed `language:` produced no suggestions because the simulator has no tag translations.

## Known Stubs

None.

## Threat Flags

None — no new network, auth, file-write or schema surface. T-16-19 mitigated (the only new action is `detailButton`'s `store.send(.galleryTapped(gid))`; the delete path is untouched and still alert-first; `DownloadsFeatureTests` 488/488). T-16-16 mitigated (every name is the visible `Label` title or a catalog symbol; lint 0 violations). T-16-03 mitigated (bundle id checked before both install-overs; nothing uninstalled, erased or reset; baselines unchanged; text evidence only).

## User Setup Required

None.

## Next Phase Readiness

Wave 17 closed; next is 16-20 (wave 18, Reduce Motion). For later plans: probe a catalog argument shape with `xcrun xcstringstool generate-symbols` before building; treat `.swipeActions` as already-exposed custom actions and mirror only context-menu-only items; 16-23 recolours the stars (`STARS=B`) — the value is colour-independent; 16-25's device walkthrough should confirm the favorites menus' selected state, the suggestion row and the tag-chip actions live, and the owner should decide on `5.0 out of 5` versus `5 out of 5`.

## Self-Check: PASSED

All 6 modified files present; commits `ac1b92b0`, `86ad21a7`, `9b349248` present in `git log`; `commits: 3` measured from the ledger (`4fd16013..HEAD`); no absolute home path in this file; no image in `git status`.
