# Phase 10: UI Polish - Pattern Map

**Mapped:** 2026-07-17
**Files analyzed:** ~90 modified files across 11 sub-tasks (no genuinely new files; 1 module rename)
**Analogs found:** in-repo exemplar exists for every sub-task pattern (RESEARCH.md inventories are the file-level ground truth; this map assigns the pattern to copy per sweep)

## File Classification

This phase modifies existing view files in sweeps rather than creating new files. Classification is therefore per **sweep**, with representative files; the full per-sweep file inventories live in `10-RESEARCH.md` §"Verified Inventories" and are authoritative.

| Sweep (files touched) | Role | Data Flow | Closest Analog (copy from) | Match Quality |
|-----------------------|------|-----------|----------------------------|---------------|
| POLISH-01 numeric text (~7 files, D-05 set) | SwiftUI view (Text modifiers) | live/user-driven value display | `AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift` | exact |
| POLISH-02 ZStack→overlay/background (35 sites, 29 files) | SwiftUI view (layout) | request-response render | `AppPackage/Sources/AppComponents/Placeholder.swift` (BEFORE shape) | exact (conversion target) |
| POLISH-03 `#Preview` migration (42 files) | preview | compile-time fixture | `AppPackage/Sources/DateSeekFeature/DateSeekPickerView.swift` | exact |
| Dynamic Type reflow (risk sites: 33 `lineLimit(1)`, 35 fixed frames, 7 fixed fonts) | SwiftUI view (layout) | render | `AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift` (`ViewThatFits`) | exact |
| `\.inSheet` removal (1 definition, 5 setters, 3 consumers) | environment/color resolution | render | no in-repo analog — use RESEARCH.md Pattern 4 (trait-based `UIColor`) | none (new native mechanism) |
| Deprecated-API sweep (~93 sites) | SwiftUI view (modifiers) | render | modern-form usages already in repo (e.g. `foregroundStyle` in `DownloadsView+Subviews.swift:172`) | exact |
| `cornerRadius(_:corners:)` removal (2 call sites + modifier deletion) | component/shape deletion | render | `.clipShape(.rect(...))` — no in-repo analog yet; RESEARCH.md criterion 8 mapping | role-match |
| Empty-string audit | audit only | — | expected zero matches; document result | n/a |
| `Label` conversion (`ToolbarItems.swift` + toolbar buttons) | component | render | `AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift:68` | exact |
| `SystemNotificationExt`→`SystemNotification` rename | module rename | — | prior module renames (Phase 6 `GenericList→GalleryList`); touch list in RESEARCH.md criterion 11 | role-match |

## Pattern Assignments

### POLISH-01 — Paired numeric text

**Analog:** `AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift` (lines ~177–190)

```swift
Text(status.summaryTitle(count: pages.count))
    .font(.body.weight(.medium))
    .monospacedDigit()
    .contentTransition(.numericText())
    .animation(countAnimation, value: pages.count)

Text(pageNumbersText)
    .font(.callout)
    .monospacedDigit()
    .contentTransition(.numericText())
    .foregroundStyle(pages.isEmpty ? .secondary : .primary)
    .animation(countAnimation, value: pageNumbersText)
```

Copy exactly: both modifiers together (D-04), plus an `.animation(_:value:)` keyed on the changing value so the transition actually animates (per A6, inert otherwise). Apply to the D-05 sites listed in RESEARCH.md (ControlPanel.swift:170, DownloadBadgeLabel.swift:17, ArchivesView.swift:139, DownloadSettingView.swift:15 — add missing half; GeneralSettingView.swift:114, DetailView+Subviews.swift:20–40/104 — add both). Static numbers: neither modifier.

### POLISH-02 — ZStack → overlay/background

**Analog (BEFORE shape to convert):** `AppPackage/Sources/AppComponents/Placeholder.swift` lines 15–21

```swift
// BEFORE — Color is the size-definer, ProgressView decorates:
ZStack {
    Color(inSheet ? .systemGray4 : .systemGray5)
    ProgressView()
}
.aspectRatio(ratio, contentMode: .fill)
.cornerRadius(cornerRadius)

// AFTER — size-defining child becomes the modified view:
Color(...)
    .overlay { ProgressView() }
    .aspectRatio(ratio, contentMode: .fill)
```

Classification rule per site: exactly one size-defining child + decorators → convert (behind = `.background { }`, in front = `.overlay { }`). Union-sized stacks (e.g. `GalleryListComponents/GalleryList.swift:43`) stay ZStacks — keeping them is explicitly permitted. Every converted site is a D-11 sim-use spot-check site.

### POLISH-03 — `#Preview` migration

**Analog:** `AppPackage/Sources/DateSeekFeature/DateSeekPickerView.swift` lines 144–170 (the only modern previews in the repo)

```swift
private let previewNewerURL: URL = .init(string: "https://e-hentai.org/?prev=2563984").forceUnwrapped

#Preview("Both directions") {
    @Previewable @State var date: Date = DateSeekNavigation.dateFormatter.date(from: "2015-06-01").forceUnwrapped
    DateSeekPickerView(
        selectedDate: $date,
        navigation: .preview(.both(newer: previewNewerURL, older: previewOlderURL)),
        seekAction: { _ in }
    )
}
```

Copy: named `#Preview("…")` cases per content state; `@Previewable @State` as first statements for interactive bindings; file-private fixture constants; existing `.preview` model helpers (e.g. `Gallery.preview`) for data. TCA views keep the lint-mandated store form: `.init(initialState: .init(), reducer: SomeFeature.init)` (`child_reducer_shorthand_store`). D-09: no DT/color-scheme/fixed-size variants. Enrichment tiers per D-08 (full matrix for cells/rows; single preview or initial/loaded pair for whole-screen TCA views).

### Dynamic Type reflow

**Analog:** `AppPackage/Sources/DetailFeature/DetailView+HeaderSection.swift` lines 216–239 (2 of the repo's 3 `ViewThatFits` sites)

```swift
ViewThatFits(in: .horizontal) {
    HStack(spacing: 6) { downloadButton; favoriteButton; readButton }
        .fixedSize(horizontal: true, vertical: false)

    VStack(alignment: .trailing, spacing: 6) {
        HStack(spacing: 6) { downloadButton; favoriteButton }
        readButton
    }
}
```

Copy: horizontal arrangement first, vertical fallback — a no-op at default type size (Pitfall 6 parity requirement). For fixed metrics tied to text, use `@ScaledMetric(relativeTo:)` (unused in repo today; RESEARCH.md Code Examples has the form). For the 7 `.font(.system(size:))` sites, switch to text-style-relative fonts. Never `dynamicTypeSize(...maxSize)`, never `minimumScaleFactor`, never `GeometryReader`.

### `\.inSheet` removal

**No in-repo analog — this deletes the analog.** Definition being removed: `AppPackage/Sources/AppTools/EnvironmentKeys.swift:3-12` (`InSheetKey` is the file's only content). Replacement pattern (RESEARCH.md Pattern 4, recommended, MEDIUM confidence — verify A3 with a simulator probe first):

```swift
// Placeholder.swift:16 (level-gated, both schemes):
Color(UIColor { traits in
    traits.userInterfaceLevel == .elevated ? .systemGray4 : .systemGray5
})
// DetailView+Subviews.swift:199/:332 (level- AND dark-gated):
Color(UIColor { traits in
    traits.userInterfaceLevel == .elevated && traits.userInterfaceStyle == .dark
        ? .systemGray4 : .systemGray5
})
```

At the 5 setter sites, delete only `.environment(\.inSheet, true)` — **4 of 5 are chained `.privacyMask().environment(\.inSheet, true)`; `.privacyMask()` must survive** (Pitfall 7). Surface the previously-unflagged-sheets delta in the plan (Pitfall 4); fallback = explicit `Bool` init parameter.

### Deprecated-API sweep

**Analogs:** modern forms already used side-by-side in the repo — e.g. `.foregroundStyle(status.tintColor)` at `DownloadsView+Subviews.swift:172`, and `ReadingView.swift:104-110` already stacks `.tint` (there the conversion is deleting the redundant `.accentColor` line). Mappings (full site lists in RESEARCH.md criterion 7):

| Deprecated | Replacement |
|-----------|-------------|
| `.foregroundColor(_:)` (43) | `.foregroundStyle(_:)` — **trap:** `ToolbarItems.swift:29` passes `Color?`; restructure to `if let` conditional application |
| `.accentColor(_:)` modifier (27) | `.tint(_:)` — static `Color.accentColor` (3 sites) is NOT deprecated, leave |
| bare `.cornerRadius(_:)` (16) | `.clipShape(.rect(cornerRadius: N))` — default `.circular` style, do NOT add `.continuous` |
| `.disableAutocorrection(_:)` (6) | `.autocorrectionDisabled(_:)` |
| `.statusBar(hidden:)` (1, `ReadingView.swift:120`) | `.statusBarHidden(_:)` |

Lint constraint: `shape_initializer_argument` bans passing `RoundedRectangle(...)` — must use `.rect(...)` shorthand.

### `cornerRadius(_:corners:)` removal

**Code being deleted:** `AppPackage/Sources/AppComponents/ViewModifiers.swift:27-29` (modifier) and :176-196 (`RoundedCorner` shape, `UIBezierPath`-backed).

```swift
// Call site 1 — GalleryThumbnailCell.swift:50:
.cornerRadius(15, corners: .bottomLeft)  →  .clipShape(.rect(bottomLeadingRadius: 15))
// Call site 2 — CategoryView.swift:33: both callers use default .allCorners →
// drop the dead `corners:` parameter, use .clipShape(.rect(cornerRadius: cornerRadius))
```

Radius-15 uneven corner is a D-11 spot-check site (corner-style drift, A2); pin `style: .circular` only if drift appears.

### `Label` conversion

**Analog:** `AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift:68`

```swift
Label(.appActivityLogsViewOpenInFiles, systemSymbol: .folderBadgeGearshape)
```

**Conversion targets (BEFORE shape):** `AppPackage/Sources/AppComponents/ToolbarItems.swift` — `FiltersButton` (:63-70), `QuickSearchButton` (:82-89), `JumpPageButton` (:103-111), all this shape:

```swift
Button(action: action) {
    Image(systemSymbol: .line3HorizontalDecrease)
    if !hideText {
        Text(.RLocalizable.filters)
    }
}
```

→ `Label(_:systemSymbol:)` + `.labelStyle(.iconOnly)` when `hideText` (if/else branch; no `AnyLabelStyle`). Lint constraints: `systemSymbol:` only (`system_name_image_parameter` bans `systemImage:`); shorthand init only (`label_text_image_shorthand` bans the closure form). Menu-row trailing-checkmark buttons (RESEARCH.md criterion 10): default = leave as-is, note decision in plan. Non-toolbar image-only buttons: out of scope.

### `SystemNotificationExt` → `SystemNotification` rename

**Analog process:** Phase 6's `GenericList→GalleryList` parity rename (mechanical, commit-verified by full suite). Complete touch list verified in RESEARCH.md criterion 11: source dir (2 files) + module `.swiftlint.yml` (content unchanged — `parent_config: ../../../.swiftlint.yml`, depth same), test dir + `@testable import`, `Package.swift` enum cases :103/:128 + 8 `.module(...)` refs, 8 `import` sites, 2 doc comments in `AppAlertState.swift`, and **`AppPackage/Tests/FeatureTests.xctestplan:81-82`** (the easy-to-miss item — Pitfall 8: verification is the renamed test target appearing in test output, not just building).

## Shared Patterns

### Lint compliance (applies to every sweep)
**Source:** `.swiftlint.yml` (repo root) — read before writing any Swift. Load-bearing rules: `system_name_image_parameter`, `label_text_image_shorthand`, `shape_initializer_argument`, `accessibility_empty_string`, `child_reducer_shorthand_store`, `line_length` 120. Plus Phase-11-bound rules to not violate now: `lifecycle_modifiers` (no `.onAppear`/`.task` in previews), `single_line_trailing_closure`, `binding_initializer`.

### Verification gates (applies to every plan)
- Per-plan clean build + SwiftLint zero-new (D-10/D-12), strictly sequential `xcodebuild`.
- `sim-use` D-11 spot-checks on layout-affecting swaps (ZStack, clipShape, Label); diff-review suffices for pure-appearance swaps.
- D-03 DT gate (XXL/AX3/AX5, every screen incl. sheets) runs LAST, on the settled surface.

### Ordering (from RESEARCH.md architecture diagram)
Mechanical sweeps (rename, deprecated APIs, cornerRadius, inSheet) → judgment conversions (Label, ZStack, numeric) → preview migration → Dynamic Type reflow last.

## No Analog Found

| Item | Role | Reason | Fallback pattern source |
|------|------|--------|------------------------|
| Trait-based sheet-elevation color | color resolution | The custom `InSheetKey` being deleted IS the only prior mechanism | RESEARCH.md Pattern 4 + Apple `UIUserInterfaceLevel.elevated` docs; verify A3 via simulator probe before committing plans |
| `@ScaledMetric` usage | DT reflow primitive | 0 uses in repo today | RESEARCH.md Code Examples (`@ScaledMetric(relativeTo: .caption)`) |
| `.clipShape(.rect(cornerRadii:))` | clip modifier | 0 uses in repo today (all clips use deprecated `.cornerRadius`) | Native API; forms given in Pattern Assignments above |

## Metadata

**Analog search scope:** `AppPackage/Sources/**` (all modules), guided by RESEARCH.md verified inventories (grep-verified 2026-07-17 on `feature/gsd-phase-10`)
**Files read for excerpts:** DownloadsView+Subviews.swift, DateSeekPickerView.swift, Placeholder.swift, EnvironmentKeys.swift, ViewModifiers.swift, ToolbarItems.swift, AppActivityLogsView.swift, DetailView+HeaderSection.swift
**Pattern extraction date:** 2026-07-17
