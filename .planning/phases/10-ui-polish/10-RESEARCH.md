# Phase 10: UI Polish - Research

**Researched:** 2026-07-17
**Domain:** SwiftUI (iOS 26 SDK, Swift 6.3.1 tools) — app-wide UI modernization at appearance/layout parity
**Confidence:** HIGH (all inventories verified by grep against the working tree; external claims cited or flagged)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Dynamic Type (criterion 5) — the phase's heaviest sub-task
- **D-01:** Full whole-app audit-and-fix, **kept in Phase 10** (not split into its own phase). Every user-facing screen — including sheets — must be readable and operable across the DT range up to the max accessibility size.
- **D-02:** Remediation stance = **reflow, never cap.** Text always grows to the user's chosen size everywhere; layouts adapt (ViewThatFits, wrapping, ScrollView, drop fixed heights / `lineLimit(1)`). **No `dynamicTypeSize(…maxSize)` caps anywhere in the app** — not even on non-essential/compact chrome. This is an absolute; the "cap as last resort" alternative was explicitly rejected.
- **D-03:** Verification = the **`sim-use` skill** driving the iOS Simulator, sampling **XXL + AX3 + AX5**, across **every user-facing screen including sheets**. (Owner-signed visual gate, in the spirit of the Phase 5 rotation/Live-Text gates; static/unit checks cannot prove readable-and-operable.)

#### Numeric Text (POLISH-01)
- **D-04:** `monospacedDigit()` and `.contentTransition(.numericText())` are applied **as a pair, and only to values that visibly change on screen.** Static one-off numbers get **neither** — this is the phase's concrete reading of POLISH-01's "where it makes sense." (Note for the verifier: static numbers left untreated are correct, not a coverage gap.)
- **D-05:** The "changing value" set = **live values** (reader current-page indicator on swipe; download progress %/size) **+ user-driven changes** (favorite/comment counts on refresh, rating when tapped, cache size after clearing). Apply best-judgment to any other value that visibly changes.
- **D-06:** No layout jitter on change (POLISH-01 acceptance) — the paired `monospacedDigit()` is what guarantees this for the animated values.

#### Preview Enrichment (POLISH-03 / criterion 12)
- **D-07:** Migrate **all 42** `PreviewProvider` structs to `#Preview`; **no `PreviewProvider` may remain** in the codebase.
- **D-08:** Enrichment is **pragmatic by view.** Stateful views (list cells, detail rows, cards, loading/error views) get the full realistic-state matrix — empty / loading / loaded / error + boundary values (min/max rating, counts, page numbers, long vs. short text) — as named `#Preview("…")` cases using modern features (`@Previewable`, preview traits like `.sizeThatFitsLayout`). Trivial leaf views get one clean `#Preview`.
- **D-09:** **Do NOT standardize Dynamic Type or color-scheme preview variants, and do NOT pin a fixed size or scheme.** Previews stay at the default environment and cover realistic **content states** only. DT/appearance is proven by the D-03 `sim-use` pass, not by preview variants. (This narrows criterion 12's "environment/DT/color-scheme variants where useful" to: not a blanket rule.)

#### Parity Verification (mechanical sweeps: ZStack, cornerRadius, foregroundStyle, Label, empty-string, inSheet, rename)
- **D-10:** All conversions build clean with **zero new SwiftLint/compiler warnings.**
- **D-11:** **Risk-tiered `sim-use` visual spot-check** — before/after visual check on the **layout-affecting** swaps (`ZStack`→overlay/background, `cornerRadius`→`clipShape`, `Label` conversions), since these can shift sizing (overlay/background is sized to primary content; ZStack is union-sized). **Diff-review is sufficient** for pure-appearance swaps (`foregroundColor`→`foregroundStyle` on `Color`). One tool (`sim-use`) serves both DT (D-03) and parity.
- **D-12:** Per-plan clean-build gate + strictly sequential `xcodebuild` (no overlapping invocations on this machine) carries forward from prior phases.

### Claude's Discretion
Mechanical items — rules already fixed by the criteria; not discussed. These execute to their stated criterion rule; the planner/researcher owns the "how":
- `SystemNotificationExt` → `SystemNotification` rename (criterion 11) — module + every import/reference; keep its `.swiftlint.yml` `parent_config` wiring under the new name.
- `cornerRadius(_:corners:)` → `.clipShape(.rect(cornerRadii:))` at appearance parity, then remove the custom modifier + its `RoundedCorner` shape (criterion 8).
- Deprecated-API sweep incl. `foregroundColor`→`foregroundStyle` (criterion 7).
- Empty-string audit: meaningful string or hidden label (criterion 9).
- `Label` conversion where fitting; toolbar buttons also cover text-only/image-only (criterion 10).
- `\.inSheet` removal (criterion 6) — pick the native/non-custom-environment replacement for the presentation-context logic it drives; surface the chosen mechanism in the plan.

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope. Splitting comprehensive Dynamic Type into its own phase was considered and explicitly rejected (D-01: kept in Phase 10).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| POLISH-01 | `.monospacedDigit()` + `.contentTransition(.numericText())` on number-bearing text; no layout jitter | Verified baseline: 6 existing `monospacedDigit` sites, 2 existing `numericText` sites (DownloadsView+Subviews is the complete paired exemplar). Candidate inventory below maps every D-05 value to its file/line. |
| POLISH-02 | `ZStack` → `.overlay`/`.background` where a child overlays/underlays primary content | Verified inventory: 35 `ZStack` occurrences across 29 files (full list below) with classification guidance + sizing-semantics pitfall. |
| POLISH-03 | Migrate all `PreviewProvider` to `#Preview`, enrich realistic states | Verified inventory: 42 `: PreviewProvider` structs in 42 files (full list below); 3 existing `#Preview("…")` cases in `DateSeekPickerView.swift` are the in-repo exemplar. Migration pattern + lint traps documented. |

The remaining 9 success criteria (ROADMAP §Phase 10) are covered in dedicated sections below — the authoritative scope is the 12 ROADMAP criteria, not just these 3 requirement IDs.
</phase_requirements>

## Summary

Phase 10 is 11 sub-tasks of view-layer modernization on an already-settled SwiftUI surface (iOS 26 min target, Liquid Glass `glassEffect` already adopted, no `GeometryReader`, adaptive layout landed in Phase 5). **Nothing here needs a new dependency, a new module, or a new pattern** — every sub-task is either a mechanical swap to a current native API or an audit-and-fix pass, and the repository already contains a working exemplar for each pattern (paired numeric text in `DownloadsView+Subviews.swift`, named `#Preview` cases in `DateSeekPickerView.swift`, `Label(_:systemSymbol:)` throughout).

The two decisions the planner must get right: (1) the **`\.inSheet` replacement mechanism** — the recommended native mechanism is a `UIColor` dynamic provider keyed on `traitCollection.userInterfaceLevel` (modal sheets receive the `.elevated` trait), but it has one behavioral delta vs. the environment key that D-11's spot-check must cover (detailed below, with an exact-parity alternative); (2) **sequencing** — the deprecated-API sweep, `Label` conversion, and ZStack conversion all touch the same files as the Dynamic Type reflow, so mechanical sweeps should land before the DT audit-and-fix to avoid re-checking screens twice.

Two criteria are smaller than the ROADMAP implies: the **empty-string audit (criterion 9) finds zero matches in the current tree** (multiple grep patterns; a custom lint rule already guards the accessibility variants), so it reduces to a documented audit result; and the **`cornerRadius(_:corners:)` removal (criterion 8) has exactly 2 call sites**. Conversely, the **deprecated-API sweep (criterion 7) is larger than its example suggests**: beyond 43 `foregroundColor` sites there are 27 `.accentColor(_:)` modifier sites, 16 bare `.cornerRadius(_:)` sites, 6 `.disableAutocorrection(_:)`, and 1 `.statusBar(hidden:)` — all doc-deprecated with current replacements.

**Primary recommendation:** Plan as parallel-auditable, sequentially-built sweeps: (rename + mechanical API sweeps) → (Label/ZStack/numeric conversions with D-11 spot-checks) → (preview migration) → (whole-app Dynamic Type reflow + D-03 gate last, on the final surface).

## Project Constraints (from CLAUDE.md)

Actionable directives the planner MUST honor (repo `CLAUDE.md` + `.swiftlint.yml`):

1. **Read `.swiftlint.yml` before writing Swift** — custom regex rules are error-level. Directly load-bearing for this phase:
   - **`system_name_image_parameter` BANS `systemImage:`/`systemName:`** → criterion 10's "`Label(_:systemImage:)`" must actually be **`Label(_:systemSymbol:)`** (SFSafeSymbols 7.0.0, already used at 8+ sites, e.g. `AppActivityLogsView.swift:68`).
   - **`label_text_image_shorthand`** — a `Label { Text(...) } icon: { Image(systemSymbol:) }` closure form is a lint error; conversions must use the shorthand init.
   - **`shape_initializer_argument`** — passing `RoundedRectangle(...)`/`UnevenRoundedRectangle(...)` as an argument is a lint error → criterion 8's replacement must use the `.rect(...)` shorthand (which the criterion already specifies).
   - **`accessibility_empty_string`** — a11y modifiers may not receive `""` (relevant to criterion 9's "hidden label" option: hide by conditional application, never by empty string).
   - `line_length` 120 (error), `force_unwrapping`/`force_try` (error), `swiftlint_disable_requires_reason`; **no suppressions ever** without explicit user permission.
   - Commented-out rules that Phase 11 ratchets to error — Phase 10 must add **zero** violations of `lifecycle_modifiers` (bans `.onAppear/.onDisappear/.task` — prefer reducer actions; **do not add `.onAppear` in enriched previews**), `single_line_trailing_closure`, `binding_initializer` (no `Binding(get:set:)` — also the pfw-modern-swiftui rule), `optional_try`, `unchecked_subscript_index_access`.
2. **Reducer naming:** `Feature` suffix (no new reducers expected this phase, but preview helpers must not introduce `*Reducer`-named types).
3. **Labeled localized-format arguments / non-translated keys need every locale** — if the `Label` or empty-string audits add or change `.xcstrings` keys, numeric format args must be named `%#@variable@` substitutions and `shouldTranslate: false` keys must carry all locales.
4. **Confirmation dialog / alert placement** — any `Label`/toolbar edit that touches a view carrying a `.confirmationDialog`/`.alert` must keep the modifier on the stable triggering control.
5. **SwiftLint coverage for renamed module** — `AppPackage/Sources/SystemNotification/.swiftlint.yml` must keep `parent_config: ../../../.swiftlint.yml` (path depth unchanged by the rename — verified the file exists today with exactly that line).
6. **No absolute home paths / no local-project names in generated docs.**

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Numeric text styling (POLISH-01) | SwiftUI view layer | — | Pure modifier application at `Text` sites; no reducer/state change |
| ZStack→overlay/background (POLISH-02) | SwiftUI view layer | — | Layout-mechanism swap; sizing semantics owned by the view tree |
| Preview migration (POLISH-03) | Per-module view files | AppModels (fixture data) | `#Preview` blocks live beside views; state fixtures come from existing `.preview` helpers / model inits |
| Dynamic Type reflow | SwiftUI view layer | — | Reflow via layout primitives; no state or reducer involvement |
| `\.inSheet` removal | AppComponents/AppTools (color resolution) | Setter sites (5 views) | Consumers only pick gray tones; replacement is a color-resolution concern, not navigation state |
| Deprecated-API sweep | SwiftUI view layer | — | 1:1 modifier swaps |
| `SystemNotificationExt` rename | AppPackage package manifest | All importers + test plan | Module identity lives in `Package.swift`; 10 import sites + xctestplan follow |
| Verification (D-03/D-11) | iOS Simulator via `sim-use` | xcodebuild (build/lint/test gates) | Visual readable-and-operable proof cannot be static |

## Standard Stack

### Core (all already in the dependency graph — nothing new is installed)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI (iOS 26 SDK, Xcode 26.6) | system | All 11 sub-tasks | Min target `.iOS(.v26)` in `AppPackage/Package.swift:1026` — every modern API in this phase is available unconditionally `[VERIFIED: Package.swift]` |
| SFSafeSymbols | 7.0.0 | `Label(_:systemSymbol:)` for criterion 10 | Pinned in `Package.swift:18`; `systemImage:` is lint-banned `[VERIFIED: Package.resolved + .swiftlint.yml]` |
| ComposableArchitecture | 1.25.3+ (traits) | Preview `Store(initialState:reducer:)` construction | Existing; lint rule `child_reducer_shorthand_store` requires `reducer: SomeFeature.init` form in previews too `[VERIFIED: .swiftlint.yml]` |

### Supporting

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `sim-use` skill | D-03 DT gate + D-11 parity spot-checks | Every visual verification; the single verification mechanism (no snapshot infra) |
| SwiftLint (DerivedData artifactbundle binary — not on PATH) | D-10 zero-new-violations gate | Per-plan; delete `AppPackage/.build` first if stale (established Phase 1–9 practice) |
| `pfw-modern-swiftui`, `swiftui-pro`, `swift-accessibility-skill`, `swiftui-performance-audit` skills | Curated implementation guidance | Load during execution of DT reflow, preview enrichment, deprecated sweep |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `UIColor` trait provider for `\.inSheet` | Explicit `init` parameter threading | Exact parity but reintroduces parameter drilling (the pattern Phase 7 spent 12 plans removing); see Criterion 6 section |
| `sim-use` visual gates | Snapshot tests | Owner explicitly chose no snapshot infra (CONTEXT: Reusable Assets) |

**Installation:** none — no new packages.

## Package Legitimacy Audit

**This phase installs no external packages.** No legitimacy check required. All libraries referenced above are already pinned in `AppPackage/Package.swift` / `Package.resolved` and were vetted in prior phases.

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Verified Inventories (the phase's ground truth)

All counts verified by grep on 2026-07-17 against the working tree (branch `feature/gsd-phase-10`). `[VERIFIED: codebase grep]` applies to this whole section.

### POLISH-01 — Numeric text

**Existing paired exemplar (copy this):** `AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift:179-186` — two `Text`s each carrying `.monospacedDigit()` + `.contentTransition(.numericText())`.

**Existing `monospacedDigit`-only sites (audit for the missing `numericText` half — these display values that change):**

| Site | Value | Changes when |
|------|-------|--------------|
| `ReadingFeature/Support/ControlPanel.swift:170` | reader "current / total" title | every page swipe (D-05 live value) |
| `GalleryListComponents/DownloadBadgeLabel.swift:17` | download progress text | live during download (D-05 live value) |
| `DetailFeature/Archives/ArchivesView.swift:139` | GP/credits funds | after archive purchase |
| `SettingFeature/Components/DownloadSettingView.swift:15` | thread-limit slider value | user drags slider |

**Candidate sites currently carrying neither (D-05 set):**

| Site | Value | Changes when |
|------|-------|--------------|
| `SettingFeature/GeneralSetting/GeneralSettingView.swift:114` | `diskImageCacheSize` string ("12.3 MB") | after clearing cache (D-05 explicitly) |
| `DetailFeature/DetailView+Subviews.swift:20-40` (`DescScrollInfo` rows) | favoritedCount, ratingCount, pageCount, sizeCount, rating | refresh / user rates (D-05 explicitly) |
| `AppComponents/RatingView.swift` consumers showing live rating (`DetailView+Subviews.swift:104`) | rating stars | user taps to rate |

Anything else found during the sweep that visibly changes → best judgment per D-05. Static numbers (e.g. one-shot parse results in pushed detail rows that never mutate on screen) get **neither** modifier — that is the intended outcome, not a gap.

**Note on `numericText`:** use `.contentTransition(.numericText(value:))` with the numeric value when the text is a pure number whose direction matters (count up vs down); plain `.numericText()` is correct for mixed strings like "12.3 MB". Both require the change to happen inside `withAnimation`/an `.animation` scope to animate — TCA state changes animate when the store mutation is wrapped; where no animation context exists the transition is simply inert (no harm, no jitter). `[ASSUMED]`

### POLISH-02 — ZStack inventory (35 occurrences, 29 files)

| File | Count |
|------|-------|
| `AppComponents/NewDawnView.swift` | 3 |
| `ReadingFeature/ReadingView.swift`, `ReadingFeature/ReadingViewComponents.swift`, `AppComponents/Placeholder.swift`, `DetailFeature/DetailView+HeaderSection.swift` | 2 each |
| `SettingFeature/{AboutView,EhSettingView,GeneralSettingView,LoginView,AppActivityLogsView}.swift`, `ReadingFeature/Support/LiveTextView.swift`, `SystemNotificationExt/View+Toast.swift`, `FavoritesFeature/FavoritesView.swift`, `HomeFeature/{GalleryCardCell,HomeView,Watched/WatchedView}.swift`, `SearchFeature/SearchRootView.swift`, `GalleryListComponents/GalleryList.swift`, `AppComponents/{CategoryView,AlertView}.swift`, `DetailFeature/{DetailView+CommentCells,DetailView,Torrents/TorrentsView,Comments/CommentsView,FolderManager/FolderManagerView,Archives/ArchivesView}.swift`, `DownloadsFeature/{DownloadsView,DownloadsView+Subviews}.swift`, `QuickSearchFeature/QuickSearchView.swift` | 1 each |

**Classification rule for the audit:** identify the *size-defining* child. If exactly one child defines the intended size and the others decorate it → convert: decorator behind = `.background { }`, decorator in front = `.overlay { }` (both are sized to the modified view — this is what criterion 4 means by "sized to the primary content"). If the stack's size is genuinely the union of ≥2 independently-sized children (e.g. `GalleryList.swift:43`, where content and the loading/error overlay both contribute) → decide which is primary; if neither is, **keep the ZStack** (explicitly permitted). Typical convertible shape in this codebase: `ZStack { Color(...); ProgressView() }` (`Placeholder.swift:15-19`) → `Color(...).overlay { ProgressView() }` keeps the Color as the size-definer at exact parity.

### POLISH-03 — PreviewProvider inventory (42 structs, one per file)

SettingFeature (10): `SettingView`, `AccountSettingView`, `DownloadSettingView`, `AboutView`, `AppearanceSettingView`, `LaboratorySettingView`, `EhSettingView`, `GeneralSettingView`, `LoginView`, `AppActivityLogsView`.
HomeFeature (8): `GalleryCardCell`, `GalleryRankingCell`, `HomeView`, `ToplistsView`, `PopularView`, `WatchedView`, `HistoryView`, `FrontpageView`.
DetailFeature (9): `DetailView`, `TorrentsView`, `CommentsView`, `FolderManagerView`, `GalleryInfosView`, `DetailSearchView`, `ArchivesView`, `PreviewsView`, `TagDetailView`.
SearchFeature (3): `GalleryHistoryCell`, `SearchRootView`, `SearchView`.
GalleryListComponents (2): `GalleryThumbnailCell`, `GalleryDetailCell`.
AppComponents (3): `NewDawnView`, `RatingView`, `SubSection`.
One each: `ReadingView`, `TabBarView`, `FavoritesView`, `DownloadsView`, `QuickSearchView`, `FiltersView`, `ReadingSettingView`.

**In-repo modern exemplar:** `DateSeekFeature/DateSeekPickerView.swift:144-170` — three named `#Preview("…")` cases. The only `#Preview` uses in the codebase today.

**Enrichment tiers (D-08):** full state matrix for stateful cells/rows/cards (`GalleryDetailCell`, `GalleryThumbnailCell`, `GalleryCardCell`, `GalleryRankingCell`, `GalleryHistoryCell`, `RatingView`, `DownloadBadgeLabel` if given previews, error/loading surfaces); single clean `#Preview` for trivial leaves and whole-screen TCA views where states require deep store fixtures (`HomeView`, `TabBarView`, etc. — a loaded-vs-initial pair is realistic; a full matrix is not pragmatic). Boundary fixtures: min/max rating (0/5), 0 vs. large counts, page 1 vs. max, short vs. long titles — construct via existing `.preview` model helpers (e.g. `Gallery.preview`, seen in `DetailView` preview).

### Criterion 5 — Dynamic Type risk inventory

| Pattern | Count | Notes |
|---------|-------|-------|
| `dynamicTypeSize(` | **0** | No caps exist today; D-02 requires it stays 0 |
| `@ScaledMetric` | 0 | Available tool, currently unused |
| `lineLimit(1)` | 33 | Each is a potential clipped-essential-text site at AX5 |
| Fixed `frame(height:)`/`frame(width:h:)` | 35 | Fixed heights fight text growth |
| Fixed-size fonts `.font(.system(size:))` | 7 | **Do not scale with DT at all** — the highest-risk sites: `ReadingViewComponents.swift:268` (30pt), `HomeView+Sections.swift:457` (50pt icon), `AlertView.swift:112` (50pt icon), `DetailView+Subviews.swift:62` (20pt), `:104` (12pt rating), `:144` (24pt), `DetailView+HeaderSection.swift:210` (10pt semibold) |
| `ViewThatFits` | 3 | Established primitive; reuse |

**Screen inventory for the D-03 pass** (every user-facing screen incl. sheets): Home (+ Frontpage, Popular, Watched, History, Toplists sheets), Search (+ history cells), Favorites, Downloads (+ detail subviews), Detail (+ Archives, Torrents, Comments, Previews, GalleryInfos, DetailSearch, PostComment, TagDetail, FolderManager), Reading (+ ControlPanel, ReadingSetting sheet), Setting (+ Account, Login, EhSetting webview/native, General, Appearance, Reading, Laboratory, About, AppActivityLogs), Filters, QuickSearch, DateSeek, NewDawn, error surface (ErrorInfoView), toasts.

### Criterion 6 — `\.inSheet` (13 grep hits: 1 definition, 5 setters, 3 consumer files)

- Definition: `AppTools/EnvironmentKeys.swift:3-12` (`InSheetKey`, the file's only content — likely deletable wholesale; verify no other keys get added there first).
- Setters (all `.environment(\.inSheet, true)` on sheet content): `AppFeature/View/TabBar/TabBarView.swift:98`, `HomeFeature/Popular/PopularView.swift:34`, `HomeFeature/Watched/WatchedView.swift:56`, `HomeFeature/Frontpage/FrontpageView.swift:36`, `SearchFeature/SearchRootView.swift:39`. **Four of five are chained as `.privacyMask().environment(\.inSheet, true)` — when deleting the environment call, the `.privacyMask()` MUST remain** (it is the Phase 7 no-content-leak guarantee).
- Consumers — all three only pick a gray tone:
  - `AppComponents/Placeholder.swift:16`: `Color(inSheet ? .systemGray4 : .systemGray5)` — **not dark-gated** (gray4 in sheets in light mode too)
  - `DetailFeature/DetailView+Subviews.swift:199`: `inSheet && colorScheme == .dark ? Color(.systemGray4) : Color(.systemGray5)`
  - `DetailFeature/DetailView+Subviews.swift:332`: `inSheet && colorScheme == .dark ? Color(.systemGray5) : Color(.systemGray6)`

**Recommended replacement — trait-based dynamic color.** UIKit passes `UIUserInterfaceLevel.elevated` in the trait collection to modally presented view controllers (sheets), in light and dark mode alike [CITED: developer.apple.com/documentation/uikit/uiuserinterfacelevel/elevated]. SwiftUI sheet content inherits the hosting controller's traits, so a `UIColor` dynamic provider reproduces the logic natively with zero plumbing:

```swift
// Placeholder (level-gated, both schemes — mirrors current logic exactly where inSheet was set):
Color(UIColor { traits in
    traits.userInterfaceLevel == .elevated ? .systemGray4 : .systemGray5
})
// DetailView+Subviews (level- and dark-gated):
Color(UIColor { traits in
    traits.userInterfaceLevel == .elevated && traits.userInterfaceStyle == .dark
        ? .systemGray4 : .systemGray5
})
```

**Known behavioral delta the plan must surface and D-11 must check:** the environment key was only set on 5 specific sheets; *other* sheets that render `Placeholder`/these Detail subviews (e.g. QuickSearch, Filters, Favorites' modal detail, deep-link modal detail) currently resolve the non-sheet gray and would resolve the elevated gray under the trait approach. That is arguably the *bug-fixed* behavior (those sheets were missed setters), but it is a visible delta from today. **Exact-parity alternative:** thread an explicit `Bool` init parameter from the 5 former setter sites (native, non-environment — but reintroduces drilling). Recommendation: trait-based, with the delta explicitly listed in the plan and spot-checked; fall back to the init parameter only if the owner rejects the delta at the D-11 gate. Note `@Environment(\.isPresented)` is NOT equivalent — it is also true for navigation-pushed views, which would flip pushed Detail on iPhone. `[ASSUMED]`

### Criterion 7 — Deprecated-API sweep inventory

| Deprecated API | Sites | Replacement | Notes |
|---------------|-------|-------------|-------|
| `.foregroundColor(_:)` | 43 | `.foregroundStyle(_:)` | Pure-appearance → diff-review tier (D-11). **Trap:** `CustomToolbarItem` (`AppComponents/ToolbarItems.swift:29`) passes `Optional<Color>` (`foregroundColor(tint)` where `tint: Color?`; nil = inherit). `foregroundStyle` accepts no Optional — restructure to conditional application (`if let`) at parity. |
| `.accentColor(_:)` modifier | 27 | `.tint(_:)` | `ReadingView.swift:104-110` already stacks `.accentColor` AND `.tint` with the same value — the conversion there is deletion of the `.accentColor` line. `RootView.swift:13` `.accentColor(.primary)` → `.tint(.primary)`: spot-check tab-bar/link tinting (layout-safe but appearance-relevant). Static `Color.accentColor` (3 sites: `EhSettingView+Sections1.swift:102`, `ControlPanel.swift:380`, `LiveTextView.swift:71,79`) is **not** deprecated — leave. |
| `.cornerRadius(_:)` (bare) | 16 | `.clipShape(.rect(cornerRadius:))` | Deprecated with "Use clipShape or fill instead" [CITED: serialcoder.dev/text-tutorials/swiftui/replacing-the-deprecated-cornerradius-view-modifier-in-swiftui]. Default `.rect` style is `.circular`, matching the deprecated modifier — do not add `style: .continuous` (that would change appearance). Sites listed by grep in Code Examples section. **Semantics note:** `.cornerRadius` clips; `clipShape` clips — parity. Where it follows `.background(color)` (e.g. `GalleryThumbnailCell.swift:94`) the clip applies to the composite exactly as before. |
| `.disableAutocorrection(_:)` | 6 | `.autocorrectionDisabled(_:)` | Renamed; mechanical. Sites: `AccountSettingView.swift:170`, `EhSettingView+Sections3.swift:195`, `LoginView.swift:139`, `SettingTextField.swift:45`, `FolderManagerView.swift:107`, `QuickSearchView.swift:155` |
| `.statusBar(hidden:)` | 1 | `.statusBarHidden(_:)` | `ReadingView.swift:120` `[ASSUMED — confirm rename compiles on iOS 26 SDK]` |

Most of these are *soft*-deprecated (doc-deprecated, no compiler warning — which is why the project builds clean today) `[ASSUMED]`. The sweep is driven by grep + docs, not by warnings; the D-10 gate then proves no *new* warnings. During execution, also let the compiler/docs flag anything this list missed (e.g. check whether `navigationBarTitleDisplayMode` — 7 sites — is deprecated in the iOS 26 SDK in favor of `toolbarTitleDisplayMode`; treat as in-scope only if doc-deprecated `[ASSUMED]`).

### Criterion 8 — `cornerRadius(_:corners:)` removal (2 call sites)

- Modifier: `AppComponents/ViewModifiers.swift:27-29`; shape: `RoundedCorner` at `ViewModifiers.swift:176-196` (UIBezierPath `byRoundingCorners`). Both to be deleted.
- Call site 1: `GalleryListComponents/Cells/GalleryThumbnailCell.swift:50` — `cornerRadius: 15, corners: .bottomLeft` → `.clipShape(.rect(bottomLeadingRadius: 15))`. Leading==left in all shipped locales (en/de/ja/ko/zh-Hans/zh-Hant — no RTL), so `UIRectCorner.bottomLeft` → `bottomLeadingRadius` is appearance-identical. `[VERIFIED: codebase — locale set from .xcstrings catalogs]`
- Call site 2: `AppComponents/CategoryView.swift:33` — parameterized `corners:`, but **both** `CategoryView` callers (`EhSettingView+Sections1.swift:222`, `FiltersView.swift:87`) use the default `.allCorners` → the `corners` init parameter is dead flexibility; drop it and use `.clipShape(.rect(cornerRadius: cornerRadius))`.
- **Style parity:** UIBezierPath corner arcs ≈ `.circular`; `.rect(cornerRadius:)` defaults `.circular`, but the **uneven** shorthand's default style should be confirmed at the call site (pass `style: .circular` explicitly on the uneven one if the D-11 spot-check shows drift) `[ASSUMED]`. Radius 15 on a thumbnail corner makes any circular/continuous difference visible — this is a D-11 spot-check site.

### Criterion 9 — Empty-string audit: **zero current matches**

Grep patterns `Text("")`, `Label(""`, `Button("")`, `TextField("")`, and the general regex `[A-Z]\w*\("",` / `[A-Z]\w*\(""\)` all return nothing in `AppPackage/Sources`, `App`, `ShareExtension`. The `accessibility_empty_string` lint rule (error) already prevents the a11y-modifier variant. **The criterion reduces to: run the audit during execution, document the (expected-empty) result in the SUMMARY, done.** If a site appears mid-phase (e.g. from a Label conversion), apply the criterion's rule: meaningful string, or hide via conditional application — never `""`.

### Criterion 10 — Label conversion inventory

- **`Button { Image + conditional Text }` components (the core targets):** `AppComponents/ToolbarItems.swift` — `FiltersButton` (:63-70), `QuickSearchButton` (:82-89), `JumpPageButton` (:103-111). Pattern: `Image(systemSymbol:)` + `if !hideText { Text(...) }` → `Label(_:systemSymbol:)` + icon-only label style when `hideText` (conditional `labelStyle` needs an `if/else` or custom style — there is no `AnyLabelStyle`). Toolbar context renders `Label` icon-only automatically; the title still feeds accessibility/Voice Control `[ASSUMED]` — verify the visible result at D-11 (a title suddenly appearing next to a toolbar icon would be a parity break).
- **Menu-row buttons with `Text + conditional checkmark Image`** (`FavoritesIndexMenu:149-153`, `ToplistsTypeMenu:177-181`, `SortOrderMenu:204-209`): "where fitting" judgment — a `Label(title, systemSymbol: .checkmark)` puts the icon in the leading slot while the current trailing-checkmark rendering inside `Menu` is system-managed. These may be better served by `Picker` inside `Menu` (native selection checkmark) — but that is a behavior-surface change; converting or leaving them is planner judgment under "where fitting," with parity the veto.
- **~25 image-only `Button { Image(systemSymbol:) }` sites** (many in toolbars, e.g. `ToolbarFeaturesMenu`'s `Menu` label, `ControlPanel` buttons): toolbar ones are in scope per criterion 10's toolbar clause; non-toolbar image-only buttons are NOT in scope (criterion covers text+image for all buttons; text-only/image-only for toolbar buttons only).
- 56 existing `Label(` sites define the house style; the lint rule enforces the shorthand.

### Criterion 11 — `SystemNotificationExt` → `SystemNotification` rename

Verified touch list:
1. `AppPackage/Sources/SystemNotificationExt/` directory (2 source files: `ToastMessageView.swift`, `View+Toast.swift`) + its `.swiftlint.yml` (`parent_config: ../../../.swiftlint.yml` — depth unchanged, content survives as-is).
2. `AppPackage/Tests/SystemNotificationExtTests/` directory (`ToastInteractionTests.swift` with `@testable import SystemNotificationExt`).
3. `AppPackage/Package.swift` — enum cases at :103 (`systemNotificationExt = "SystemNotificationExt"`) and :128 (tests), plus 8 `.module(.systemNotificationExt)` refs (:292, :361, :605, :653, :734, :763, :1014, :1016).
4. `import SystemNotificationExt` at 6 sites: `SettingFeature/AccountSetting/AccountSettingView.swift:8`, `ReadingFeature/ReadingView.swift:10`, `AppFeature/View/TabBar/TabBarView.swift:8`, `DetailFeature/Torrents/TorrentsView.swift:5`, `DetailFeature/Comments/CommentsView.swift:7`, `DetailFeature/GalleryInfos/GalleryInfosView.swift:6`, `DetailFeature/Archives/ArchivesView.swift:6`, `DownloadsFeature/DownloadsView+Subviews.swift:7` (8 imports total).
5. Doc comments: `AppComponents/AppAlertState.swift:11` and `:132`.
6. **Easy to miss:** `AppPackage/Tests/FeatureTests.xctestplan:81-82` references `SystemNotificationExtTests` by identifier and name.
7. **No collision:** no external package named SystemNotification in `Package.resolved`; the resolved graph (Kanna, SFSafeSymbols, Kingfisher, SDWebImage, TCA deps, ColorfulX, …) is clash-free. `[VERIFIED: xcodebuild -list resolved packages]`
8. `EhPanda.xcodeproj/project.pbxproj` has zero references — the app links `AppFeature` only.

## Runtime State Inventory

(Required: criterion 11 is a rename.)

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | **None** — the module name is a compile-time identity; no persisted `@Shared` model, cache key, or file path embeds "SystemNotificationExt" (grep over Sources/Tests: only code/doc refs listed above) | none |
| Live service config | **None** — no external service references module names | none |
| OS-registered state | **None** — no OS registration keys on module identity | none |
| Secrets/env vars | **None** — no secret or env var references the module | none |
| Build artifacts | Stale DerivedData / `AppPackage/.build` products under the old module name; `FeatureTests.xctestplan` target identifier (item 6 above) | xctestplan edit is a **code edit** in the rename commit; stale artifacts resolve via the per-plan clean build (and the established delete-`AppPackage/.build`-before-SwiftLint practice) |

Also rename-adjacent but not runtime state: `Package.resolved` is unaffected (local package, not pinned).

## Architecture Patterns

### System Architecture Diagram

```
                 ┌─────────────────────────────────────────────────┐
                 │              Phase 10 work surface               │
                 └─────────────────────────────────────────────────┘

  Mechanical sweeps (grep-driven)          Audit-and-fix passes (judgment-driven)
  ────────────────────────────────         ─────────────────────────────────────
  rename SystemNotificationExt   ──┐        ZStack classification (35 sites)
  deprecated APIs (93 sites)       │        Label "where fitting" (toolbar+buttons)
  cornerRadius(_:corners:) (2)     │        numeric-text D-05 set
  inSheet removal (13 refs)        │        empty-string audit (expected: none)
                                   ▼                     │
                        per-plan clean build ◄───────────┘
                        + SwiftLint zero-new (D-10)
                                   │
                                   ▼
                   Preview migration (42 structs → #Preview)
                                   │
                                   ▼
                   Dynamic Type reflow (runs LAST, on settled surface)
                                   │
                                   ▼
              sim-use gates: D-11 parity spot-checks (layout-affecting swaps)
                            D-03 DT pass (XXL/AX3/AX5 × every screen)
                                   │
                                   ▼
                        full test suite (sequential xcodebuild)
```

**Ordering rationale:** every mechanical sweep rewrites lines the DT reflow will re-touch; previews should be migrated before DT work so enriched previews aid the reflow; DT runs last so the D-03 gate certifies the final surface once.

### Pattern 1: Paired numeric text (in-repo exemplar)

```swift
// Source: AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift:179-186 (existing code)
Text(progressText)
    .monospacedDigit()
    .contentTransition(.numericText())
```
Always both modifiers together (D-04); only on values that visibly change (D-05).

### Pattern 2: ZStack → overlay/background at parity

```swift
// BEFORE (Placeholder.swift:15-19): Color defines the fill, ProgressView decorates
ZStack {
    Color(...)
    ProgressView()
}
// AFTER — Color stays the size-definer; overlay is sized to it:
Color(...)
    .overlay { ProgressView() }
```
The size-defining child becomes the modified view. If conversion would change which child sizes the composite → keep the ZStack (criterion 4 permits it).

### Pattern 3: #Preview migration with TCA store + lint compliance

```swift
// BEFORE (HomeView.swift:164-170)
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(store: .init(initialState: .init(), reducer: HomeReducer.init))
    }
}
// AFTER — named case, store shorthand form kept (child_reducer_shorthand_store rule):
#Preview("Initial") {
    HomeView(store: .init(initialState: .init(), reducer: HomeReducer.init))
}
```
For interactive bindings use `@Previewable @State var …` as the first statements of the `#Preview` body; for intrinsic-size components add `traits: .sizeThatFitsLayout`. No `.onAppear`/`Binding(get:set:)` in preview bodies (Phase 11 rules). D-09: no DT/color-scheme/fixed-size variants.

### Pattern 4: Trait-based sheet-elevation color (criterion 6 recommendation)

```swift
// Native replacement for \.inSheet — UIKit sets .elevated on modally presented content
// Source: developer.apple.com/documentation/uikit/uiuserinterfacelevel/elevated
Color(UIColor { traits in
    traits.userInterfaceLevel == .elevated ? .systemGray4 : .systemGray5
})
```

### Anti-Patterns to Avoid

- **`dynamicTypeSize(...maxSize)` anywhere** — absolute prohibition (D-02).
- **`.minimumScaleFactor` to "fix" DT breakage** — it shrinks text below the user's chosen size; that is a cap in disguise. Reflow instead. `[ASSUMED — reading of D-02's intent; flag any pre-existing minimumScaleFactor uses to the owner rather than adding new ones]`
- **`GeometryReader`** — banned by Phase 5 convention; use `onGeometryChange`/`containerRelativeFrame`/`ViewThatFits`.
- **Empty string as hidden label** — violates criterion 9 and the a11y lint rule; hide by conditional application or `.labelStyle(.iconOnly)`.
- **`systemImage:`/`systemName:` parameters** — lint-banned; always `systemSymbol:`.
- **Blanket ZStack conversion** — union-sized stacks must stay; conversion is per-site classification, not a regex.
- **Dropping `.privacyMask()` while deleting `.environment(\.inSheet, true)`** — four setter sites chain both.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Uneven corner rounding | Custom `Shape` over `UIBezierPath` (the thing being deleted) | `.clipShape(.rect(bottomLeadingRadius:…))` | Native, animatable, no UIKit bridge |
| "Am I in a sheet?" | Custom `EnvironmentKey` (the thing being deleted) | `UIColor` dynamic provider on `userInterfaceLevel` | The trait system already models elevation; zero plumbing |
| Numeric change animation | Custom transition/offset animation | `.contentTransition(.numericText())` | System-tuned per-digit animation, Reduce Motion-aware |
| Text-size-responsive metrics | `onGeometryChange` math on font metrics | `@ScaledMetric(relativeTo:)` | Scales any constant with the user's type size |
| Preview interactive state | Wrapper `@State` container views | `@Previewable @State` | Macro-generated; removes boilerplate structs |
| Icon+title buttons | `HStack { Image; Text }` | `Label(_:systemSymbol:)` | Correct toolbar/menu/a11y adaptivity for free |

**Key insight:** this phase deletes two hand-rolled mechanisms (`RoundedCorner`, `InSheetKey`) precisely because iOS 26-era SwiftUI covers them natively — do not introduce replacements that recreate the same shape of custom code.

## Common Pitfalls

### Pitfall 1: Overlay/background changes composite size silently
**What goes wrong:** `ZStack`s size to the union of children; `.overlay`/`.background` size to the modified view. Converting a stack whose "decorator" was actually larger than the "primary" shrinks the composite.
**How to avoid:** classify per-site (which child defines size?); D-11 before/after spot-check on every converted site.
**Warning signs:** hit-target shrinkage, clipped ProgressView, changed cell heights in lists.

### Pitfall 2: `foregroundStyle` has no nil/inherit form
**What goes wrong:** `CustomToolbarItem` passes `Optional<Color>` to `foregroundColor` (nil = inherit). A mechanical `foregroundColor`→`foregroundStyle` regex breaks it (no Optional overload).
**How to avoid:** conditional application (`if let tint { content.foregroundStyle(tint) } else { content }`) — and audit for any other Optional-color call sites before the sweep.

### Pitfall 3: Corner-style drift on the clip swaps
**What goes wrong:** `.circular` vs `.continuous` differ visibly at radius ≥ ~10. The deprecated `.cornerRadius` and `.rect(cornerRadius:)` default match (`.circular`), but adding `style: .continuous` "because it's the system style" would break parity; the uneven-corner shorthand's default needs on-device confirmation.
**How to avoid:** keep defaults on even corners; spot-check the two `corners:` conversion sites (radius 15) at D-11; pin `style:` explicitly only if drift appears.

### Pitfall 4: Trait-based inSheet color changes previously-unflagged sheets
**What goes wrong:** sheets that never set `\.inSheet` (QuickSearch, Filters, modal Detail entries) currently show the base gray; the trait provider will show the elevated gray there. Correct-but-different.
**How to avoid:** the plan lists this delta explicitly (owner sees it before execution); D-11 spot-checks one previously-unflagged sheet. Fall back to explicit init parameter if rejected.

### Pitfall 5: Preview code triggering Phase 11 lint rules
**What goes wrong:** enriched previews casually use `.onAppear`, single-line trailing closures, `Binding(get:set:)`, or bare `Reducer()` closures — all of which become errors in Phase 11 (or are errors now: `child_reducer_shorthand_store`).
**How to avoid:** previews follow the same rules as production code; use `@Previewable @State`, `reducer: Feature.init`, and reducer-driven state fixtures instead of appear-hooks.

### Pitfall 6: DT reflow drifting into redesign
**What goes wrong:** "reflow, never cap" invites layout rewrites; the milestone forbids visual redesign — at *default* type size, every screen must look unchanged.
**How to avoid:** reflow constructs (`ViewThatFits`, wrapping, `@ScaledMetric`) must be no-ops at `.large` default size; D-11-style before/after check at default size for any reflowed screen.

### Pitfall 7: Losing `.privacyMask()` at inSheet setter sites
**What goes wrong:** 4 of 5 setter deletions are on chained `.privacyMask().environment(\.inSheet, true)` lines — deleting the whole line reopens the Phase 7 content-leak hole (39-root coverage reconciliation would catch it late).
**How to avoid:** delete only the `.environment` call; re-run the privacy-mask coverage check (Phase 7's 39-root inventory) after the sweep.

### Pitfall 8: Rename misses the xctestplan
**What goes wrong:** `FeatureTests.xctestplan:81-82` references `SystemNotificationExtTests` by string; Package.swift renames alone leave the test plan pointing at a nonexistent target.
**How to avoid:** the rename commit's verification is the full test suite actually *running* the renamed test target (check it appears in test output), not just building.

## Code Examples

### Bare `.cornerRadius(_:)` sites (criterion 7, 16 sites)
```
SettingFeature/SettingView.swift:109              .cornerRadius(10)
SettingFeature/Components/LaboratorySettingView.swift:73   .cornerRadius(15)
HomeFeature/GalleryCardCell.swift:74,90           .cornerRadius(5 / 15)
HomeFeature/GalleryRankingCell.swift:21           .cornerRadius(2)
HomeFeature/HomeView+Sections.swift:284,462       .cornerRadius(2 / 15)
SearchFeature/GalleryHistoryCell.swift:19         .cornerRadius(2)
GalleryListComponents/Cells/GalleryThumbnailCell.swift:94  .cornerRadius(15)
AppComponents/CategoryView.swift:91               .cornerRadius(5)
AppComponents/TagCloudView.swift:125              .cornerRadius(5)
AppComponents/NewDawnView.swift:167               .cornerRadius(width / 3)
AppComponents/SettingTextField.swift:45           .cornerRadius(5)
AppComponents/Placeholder.swift:21                .cornerRadius(cornerRadius)
DetailFeature/DetailView+CommentCells.swift:40    .cornerRadius(15)
DetailFeature/DetailView+Subviews.swift:207       .cornerRadius(5)
```
Each becomes `.clipShape(.rect(cornerRadius: N))` (default `.circular` style preserves appearance).

### Label conversion with conditional icon-only style
```swift
// BEFORE (ToolbarItems.swift:63-70)
Button(action: action) {
    Image(systemSymbol: .line3HorizontalDecrease)
    if !hideText {
        Text(.RLocalizable.filters)
    }
}
// AFTER (shape — exact style mechanism is planner's choice):
Button(action: action) {
    if hideText {
        Label(.RLocalizable.filters, systemSymbol: .line3HorizontalDecrease)
            .labelStyle(.iconOnly)
    } else {
        Label(.RLocalizable.filters, systemSymbol: .line3HorizontalDecrease)
    }
}
```

### Dynamic Type reflow primitives (established in this codebase)
```swift
// Scaled constant replacing a fixed metric tied to text:
@ScaledMetric(relativeTo: .caption) private var badgeHeight = 20
// Alternative arrangements (3 existing ViewThatFits uses to copy):
ViewThatFits(in: .horizontal) { HStack { … }; VStack { … } }
// Fixed-size icon fonts (the 7 .system(size:) sites) — scale with the paired text style, e.g.:
.font(.system(.title, design: .default).weight(.medium))  // or @ScaledMetric-driven size
```

## State of the Art

| Old Approach (in repo) | Current Approach | Impact |
|--------------|------------------|--------|
| `foregroundColor` / `accentColor` / `cornerRadius` / `disableAutocorrection` / `statusBar(hidden:)` | `foregroundStyle` / `tint` / `clipShape(.rect)` / `autocorrectionDisabled` / `statusBarHidden` | Criterion 7 sweep — all replacements available since ≤ iOS 17, target is iOS 26 |
| `UIBezierPath`-backed `RoundedCorner` shape | `.rect(cornerRadii:)` shorthand | Criterion 8; kills a UIKit bridge |
| Custom `InSheetKey` environment | `UIUserInterfaceLevel` trait (elevation is a first-class trait) | Criterion 6 |
| `PreviewProvider` structs | `#Preview` macro + `@Previewable` + traits | Criterion 12/POLISH-03 |
| Static text for changing numbers | `.contentTransition(.numericText())` + `monospacedDigit()` | POLISH-01 |

**Deprecated/outdated in this phase's scope:** everything in the criterion 7 table; `PreviewProvider` (soft-deprecated pattern, macro replaces it).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Soft-deprecation status (no compiler warnings today) for foregroundColor/cornerRadius/accentColor/statusBar | Criterion 7 | None material — sweep is grep-driven either way; if they *do* warn, D-10 already demands zero warnings |
| A2 | `UnevenRoundedRectangle`/uneven `.rect` default corner style matches `UIBezierPath` rendering closely enough at radius 15 | Criterion 8 | Visible corner-shape drift → caught by D-11 spot-check; fix by explicit `style:` |
| A3 | SwiftUI sheet content inherits `.elevated` trait from its hosting controller (UIKit doc covers UIKit presentation; SwiftUI `.sheet` hosting inferred) | Criterion 6 | Recommendation collapses → fall back to explicit init parameter; verify with a 5-minute simulator probe before committing plans |
| A4 | Toolbar context renders `Label` icon-only by default (no visible title appears after conversion) | Criterion 10 | Parity break in toolbars → caught by D-11; fall back to `.labelStyle(.iconOnly)` explicitly |
| A5 | `navigationBarTitleDisplayMode` / other unswept modifiers may or may not be doc-deprecated in the iOS 26 SDK | Criterion 7 | Sweep under- or over-reaches → executor checks each candidate against SDK docs at implementation time |
| A6 | `.contentTransition` animates only within an animation scope and is inert otherwise (no jitter risk when unanimated) | POLISH-01 | Some treated values never visibly animate → still meets D-04/D-06 (no jitter); add `withAnimation` at the mutation if animation is required |
| A7 | `@Environment(\.isPresented)` is true for navigation-pushed views too (reason it was rejected for criterion 6) | Criterion 6 | If actually sheet-only, it becomes a second viable native mechanism — doesn't change the recommendation's validity |

## Open Questions

1. **inSheet replacement mechanism — trait-based (recommended) vs explicit init parameter?** *(RESOLVED — see plan 10-04: trait-based implementation with A3 probe in Task 2, delta owner-gated at the Task 3 checkpoint, init-parameter fallback documented)*
   - What we know: consumers only select gray tones; trait approach is native and plumbing-free; it changes previously-unflagged sheets (Pitfall 4).
   - What's unclear: whether the owner accepts the "missed sheets now render elevated gray" delta.
   - Recommendation: plan proposes trait-based with the delta stated explicitly (CONTEXT requires the mechanism surfaced in the plan); D-11 gates it; init-parameter fallback documented.
2. **Menu-row Text+checkmark buttons (criterion 10 "where fitting")** *(RESOLVED — see plan 10-05 Task 1: the three menu-row buttons are left as-is, verdict recorded)*
   - What we know: three menus use trailing conditional checkmarks; `Label` reorders the icon leading; `Picker`-in-`Menu` is the native selection idiom but changes the rendering surface.
   - Recommendation: default to leaving these three as-is (fitting = no); note the decision in the plan.
3. **Does the D-03 DT gate include the EhSetting webview-backed screens?** *(RESOLVED — see plan 10-10 Task 2: native chrome audited; WebKit-rendered text checked but out of remediation scope, noted in the verdict table)*
   - What we know: EhSettingView has native + web content; DT applies to native chrome; web content scales via WebKit's own text sizing.
   - Recommendation: gate covers the native chrome; web content readable-and-operable is checked but WebKit-rendered text is out of remediation scope.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode + iOS 26 SDK | all builds | ✓ | Xcode-26.6.0 (verified via `xcodebuild -list` invocation path) | — |
| iOS Simulator + `sim-use` skill | D-03 / D-11 gates | ✓ (skill listed; simulator ships with Xcode) | — | — |
| SwiftLint | D-10 gate | ✓ (DerivedData artifactbundle binary — **not on PATH**; delete `AppPackage/.build` first if resolution is stale) | — | — |
| Swift Testing suite | regression gate | ✓ (505 tests green as of Phase 9; `FeatureTests.xctestplan`) | — | — |

**Missing dependencies with no fallback:** none.
**Constraint:** strictly ONE `xcodebuild` invocation at a time on this machine (D-12; wedged `testmanagerd` risk) — plans must serialize build/test waves.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (existing; Xcode-run only — bare `swift build`/`swift test` fails on this package) |
| Config file | `AppPackage/Tests/FeatureTests.xctestplan` |
| Quick run command | `xcodebuild test -project EhPanda.xcodeproj -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SystemNotificationTests` (post-rename name; adjust destination to the machine's installed simulator) |
| Full suite command | `xcodebuild test -project EhPanda.xcodeproj -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| POLISH-01 | numeric modifiers applied; no jitter | manual-only (visual) + grep audit | grep pair-check (`monospacedDigit` ⇔ `numericText` co-located) | manual — justified: modifier presence is greppable, jitter is visual |
| POLISH-02 | ZStack conversions at parity | manual-only (D-11 sim-use) + build/lint | full suite guards regressions | manual — justified: layout parity is visual |
| POLISH-03 | no `PreviewProvider` remains | static check | `grep -rn "PreviewProvider" AppPackage App ShareExtension --include="*.swift"` must return 0 hits | ✓ (grep, no new file) |
| crit. 5 | DT readable/operable XXL/AX3/AX5 | manual-only (D-03 sim-use, owner-signed) | — | manual — justified per D-03: static checks cannot prove it |
| crit. 6 | `\.inSheet` gone | static check + existing toast/detail tests | `grep -rn "inSheet" AppPackage --include="*.swift"` = 0 hits | ✓ (grep) |
| crit. 7/8/9/10 | sweeps complete, zero new warnings | build + SwiftLint + greps (e.g. `foregroundColor` = 0 outside allowed) | full suite green | ✓ (existing infra) |
| crit. 11 | rename complete, tests still run | full suite — renamed `SystemNotificationTests` target must appear in test output | full suite command above | ✓ (existing `ToastInteractionTests` rides along) |

### Sampling Rate
- **Per task commit:** clean build of touched scheme (D-12 gate)
- **Per wave merge:** full suite (sequential, single invocation)
- **Phase gate:** full suite green + D-03 DT pass + D-11 spot-checks before `/gsd-verify-work`

### Wave 0 Gaps
None — existing test infrastructure covers all phase requirements; this phase adds no unit-testable logic (view-layer only). The one flaky-history test (`DownloadSchedulingTests`) is fixed deterministically — a failure during this phase is a real regression.

## Security Domain

This phase is view-layer polish with no new attack surface: no authentication, session, crypto, storage, or network changes.

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | — |
| V3 Session Management | no | — |
| V4 Access Control | no | — |
| V5 Input Validation | no (no new input paths; preview fixtures are compile-time) | — |
| V6 Cryptography | no | — |

### Known Threat Patterns for this phase

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Privacy-mask regression via inSheet setter deletion (App Switcher content leak) | Information Disclosure | Keep `.privacyMask()` on all 4 chained sites; re-verify Phase 7's 39-root coverage after the sweep |
| Diagnostic/preview fixtures embedding real credentials or gallery data | Information Disclosure | Preview fixtures use synthetic `.preview` model helpers only (existing convention) |

## Sources

### Primary (HIGH confidence)
- Codebase greps + file reads (this session, working tree at `88513339`) — all inventories, counts, and line references
- `.swiftlint.yml`, `AppPackage/Package.swift`, `FeatureTests.xctestplan` — constraint verification
- `pfw-modern-swiftui` skill (curated) — action-closure and binding patterns for enriched previews

### Secondary (MEDIUM confidence)
- [UIUserInterfaceLevel.elevated — Apple Developer Documentation](https://developer.apple.com/documentation/uikit/uiuserinterfacelevel/elevated) — modal presentation passes `.elevated` to presented content (via WebSearch)
- [Replacing the deprecated cornerRadius modifier — SerialCoder.dev](https://serialcoder.dev/text-tutorials/swiftui/replacing-the-deprecated-cornerradius-view-modifier-in-swiftui/) and [Rounding corners in SwiftUI — BleepingSwift](https://bleepingswift.com/blog/corner-radius-swiftui) — deprecation message, `.rect` shorthand, circular-vs-continuous defaults (via WebSearch)

### Tertiary (LOW confidence)
- Training-knowledge items tagged `[ASSUMED]` in the Assumptions Log (A1–A7) — each has an execution-time verification path

## Metadata

**Confidence breakdown:**
- Inventories & constraints: HIGH — grep/file-read verified this session
- Deprecated-API replacements: HIGH — replacements all pre-date the iOS 26 minimum by many SDK versions
- inSheet trait mechanism: MEDIUM — UIKit behavior cited; SwiftUI-hosting inheritance is A3, needs a 5-minute probe
- Dynamic Type remediation effort: MEDIUM — risk counts verified, but which of the 33+35+7 sites actually break at AX5 is only knowable in the simulator

**Research date:** 2026-07-17
**Valid until:** 2026-08-16 (stable domain — codebase-anchored; re-verify only if the tree moves under it)
