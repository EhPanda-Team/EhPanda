# Dynamic Type reflow patterns (extracted from a reference project)

A catalogue of how one production SwiftUI codebase (iOS, iPadOS, macOS, widgets, Live Activities; roughly 1,750 commits, 2022 to 2026) reflows its layouts under Dynamic Type. Extracted from the project's full git history and its current HEAD. All identifiers in snippets are renamed to neutral ones; see Method.

## Summary table

| Pattern | Trigger | Applies to | Sites in HEAD |
|---|---|---|---|
| P-01 `AdaptiveStack` | `ViewThatFits(in: .horizontal)` | any horizontal row that may overflow | 20 call sites in 10 files |
| P-02 Space-between stat pair | P-01 with `hSpaceBetween: true` | left/right stat pairs in list rows | 9 of the 20 |
| P-03 "Title …… value" row | P-01 + flexible title frame | key-value boards and info tabs | 1 shared board component; 27 rows opted always-vertical |
| P-04 Size-gated fallback | `dynamicTypeSize <= .accessibility2/3` (or `>= .xxLarge` inverted) | rows whose rigid layout is known to fit below a threshold | 4 gates |
| P-05 Drop decoration, keep text | size gate or outright deletion | decorative glyphs, badges, axis labels | 3 live gates (+1 deletion in history) |
| P-06 Form row label + control | explicit `isAccessibilitySize` branch; native control titles | settings/forms | 1 explicit branch; native titles everywhere |
| P-07 Grid/wide layout to one column | `isAccessibilitySize ? 1 : 2`; width AND not-AX predicate | card grids, two-pane layouts | 2 production sites |
| P-08 Stepped metric | `switch dynamicTypeSize` returning a constant | icon sizes, card heights, chart heights, axis density | 4 switches |
| P-09 Icon row + full-width name | `ViewThatFits` with a two-line fallback that keeps the icon row | file rows with leading icon and trailing status | 1 site |
| P-10 `lineLimit` policy | none (a policy, not a construct) | all text | nil for user text; 1 in stacking containers/fixed budgets; 3 and 30 for badge/log |
| P-11 Scroll-on-demand card + measured sheet | `ViewThatFits(in: .vertical)`; height-measured detents | offer card in a sheet | 1 card + 1 sheet modifier |
| P-12 Bottom-bar overflow | `@ScaledMetric` slot width vs measured bar width | edit-mode bottom bar | 1 (the only `@ScaledMetric` in the app) |
| P-13 Widget content tiers | `dynamicTypeSize` thresholds per widget family | widgets, Live Activities | 4 gates in 2 widget files |
| P-14 Icon-only toolbar items | `Label(...).labelStyle(.iconOnly)` | toolbars, bottom bars | 17 sites |
| P-15 Deliberate opt-out | `.dynamicTypeSize(.medium)` pin | one fixed-height tertiary footer row | 1 site |

## Patterns

### P-01 `AdaptiveStack`: HStack→VStack(leading) fallback component

**Trigger.** `ViewThatFits(in: .horizontal)` picks the `HStack` when the content fits the proposed width, otherwise a `VStack(alignment: .leading)` of the same content. No size class or type-size inspection: the decision is purely "does it fit".

**Before → After.** Before (2022 era): plain `HStack` + `.fixedSize(horizontal: true, vertical: false)` + `.lineLimit(1)`, which truncated or overflowed at large sizes. After (since Sept 2024), the shared component (HEAD state, identifiers renamed):

```swift
struct AdaptiveStack<Content: View>: View {
    var hSpaceBetween = false
    var hSpacing: CGFloat?
    var hAlignment: VerticalAlignment = .center
    var vSpacing: CGFloat?
    var vAlignment: HorizontalAlignment = .leading
    @ViewBuilder var content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: hAlignment, spacing: hSpacing) {
                if hSpaceBetween {
                    Group(subviews: content) { subviews in
                        ForEach(Array(subviews.enumerated()), id: \.element.id) { offset, subview in
                            subview
                            if offset < subviews.count - 1 || subviews.count <= 1 {
                                Spacer()
                            }
                        }
                    }
                } else { content }
            }
            VStack(alignment: vAlignment, spacing: vSpacing, content: { content })
        }
    }
}
```

**Sacrificed vs preserved.** Sacrificed: the single-line silhouette (rows grow taller). Preserved: every word of text at full size, leading alignment, one shared `content` closure so both candidates can never drift apart.

**Where it applies.** List rows and boards throughout the app: item rows in the main table, source rows, filter-info rows, stats boards, log rows, activity settings rows, file/detail rows.

**Evidence.** 20 call sites in 10 files at HEAD (see Method for the count nuance vs the pinned 15). Born Sept 2024 as a private component when the main list row was adapted to the AX5 size; promoted to a shared component Oct 2024. Subview enumeration used a third-party backport package until Nov 2025, when it moved to the native `Group(subviews:)`.

**Pitfalls (from revisions).**
- The `|| subviews.count <= 1` spacer guard was added July 2025: with `hSpaceBetween` and a single visible subview, no spacer was emitted and the lone item floated instead of anchoring leading.
- Anything conditional placed in the shared `content` participates in **both** candidates; a `Spacer()` that is harmless in the HStack becomes a vertical expander in the VStack candidate (see P-02 pitfalls).
- `.lineLimit(1)` applied to the whole component keeps each stacked line single-line in the vertical fallback too; that is used deliberately (P-10).

### P-02 Space-between stat pair that stacks; nested two-level degradation

**Trigger.** P-01 with `hSpaceBetween: true`: the component interleaves `Spacer()`s between subviews via `Group(subviews:)`, so the horizontal candidate is a space-between row and the vertical fallback is a plain leading stack with no spacers.

**Before → After.** Before: a `HStack { left; Spacer(); right }` (an earlier divider/spacer helper). After (renamed, from the main item row):

```swift
AdaptiveStack(hSpaceBetween: true) {
    Text(item.size.formatted)          // left stat
    Label(item.groupName, systemSymbol: .listDash)  // right stat
}
.font(.subheadline)
```

Trailing-anchored pairs add `vAlignment: .trailing` plus `.frame(maxWidth: .infinity, alignment: .trailing)` so the vertical fallback hugs the trailing edge the pair used to sit on:

```swift
AdaptiveStack(hSpaceBetween: true, vAlignment: .trailing) {
    Text(etaText)
    Text(statusText)
}
.frame(maxWidth: .infinity, alignment: .trailing)
.lineLimit(1)
```

Nested two-level degradation: a progress label's upper line is an outer space-between pair whose right member is itself an inner `AdaptiveStack` pair (uploaded/downloaded). Under growing text the inner pair stacks first; only when even that no longer fits does the outer pair stack, giving three intermediate layouts between fully horizontal and fully vertical.

**Sacrificed vs preserved.** Sacrificed: the left/right justified silhouette (stacked form is leading- or trailing-aligned). Preserved: pairing and reading order.

**Where it applies.** Stat pairs in the main item row (3), detail rows for endpoints and files (5), and the file viewer row (1): 9 `hSpaceBetween:` sites at HEAD. Trailing-anchored: 2 of the 9 plus one non-space-between trailing counters row.

**Evidence.** Born Sept 2024 together with P-01 (the row previously used a spacer-injecting helper). 9 sites at HEAD.

**Pitfalls.** The July 2025 file-row lesson: a pair built as `AdaptiveStack(vAlignment: .trailing)` whose shared content held a **conditional `Spacer()`** (only when both members exist) stacked wrong, because the spacer turned vertical inside the VStack candidate and blew the row open. The second try replaced it with an explicit `ViewThatFits` whose horizontal candidate owns the `Spacer()` and the `.lineLimit(1)`, and whose vertical candidate has neither:

```swift
ViewThatFits(in: .horizontal) {
    HStack {
        priorityLabel
        if priority != nil, availability != nil { Spacer() }
        availabilityLabel
    }
    .lineLimit(1)

    VStack(alignment: .trailing) {
        priorityLabel
        availabilityLabel
    }
    .frame(maxWidth: .infinity, alignment: .trailing)
}
```

A May 2025 counters row was already written this way (explicit `ViewThatFits`, conditional `Spacer` only in the horizontal candidate), so the codebase converged on: shared-content component for symmetric pairs, explicit candidates whenever a member or spacer is conditional.

### P-03 "Title …… value" row: flexible title, intrinsic value, per-row vertical opt-out

**Trigger.** P-01 around a title given `.frame(maxWidth: .infinity, alignment: .leading)` (it absorbs slack and wraps) and a value kept intrinsic with `.lineLimit(1)` on the value only.

**Before → After.** Before (until Oct 2024): `HStack { title.frame(maxWidth: .infinity, alignment: .leading); value }` with `.lineLimit(1)` on the whole row, so long values truncated. After (HEAD, renamed):

```swift
let titleLabel = statistic.title
    .frame(maxWidth: .infinity, alignment: .leading)
let valueLabel = Text(statistic.value)
    .lineLimit(1)
    .foregroundStyle(.secondary)

switch statistic.layout {
case .automatic:
    AdaptiveStack(hAlignment: .top) {
        titleLabel
        valueLabel
    }
case .vertical:
    VStack(alignment: .leading) {
        titleLabel
        valueLabel
    }
}
```

The per-row opt-out is a row-model enum `Layout { automatic, vertical }` (added April 2025): rows whose values are effectively always long (sizes with totals, file paths, dates, free-text comments) skip the fitting dance and render vertically at every type size.

**Sacrificed vs preserved.** Sacrificed: the dotted-leader-style aligned column of values. Preserved: full value text (the `.lineLimit(1)` value sits alone on its own line after stacking, and always-long values never even try the horizontal form).

**Where it applies.** The shared statistics board (activity monitor stats and the general info tab feed it). 27 rows are declared `layout: .vertical` at HEAD.

**Evidence.** Rows switched from `HStack` to the adaptive form Oct 2024 (the same commit that relaxed the row-wide `lineLimit`); the opt-out enum arrived April 2025 with the info-tab feature.

**Pitfalls.** The Oct 2024 change had to hoist the row-wide `.lineLimit(1)` off the container: left in place it clamps the stacked title too. HEAD keeps `lineLimit(1)` only on the value.

### P-04 Size-gated fallback: keep the rigid layout below a threshold

**Trigger.** An explicit gate around the adaptive construct so that the rigid layout is used verbatim below a threshold, and `ViewThatFits` only arbitrates above it:

```swift
if dynamicTypeSize <= .accessibility3 {
    fullContent                      // rigid: icon + text block
} else {
    ViewThatFits(in: .horizontal) {
        fullContent
        mainContent                  // fallback: text block only
    }
}
```

**Before → After.** Before: either the rigid layout at all sizes, or `ViewThatFits` at all sizes. After: the hybrid above (source row, Oct 2024) and its filter-row siblings gated at `<= .accessibility2` with an `AdaptiveStack` in the else branch. The widget header (July 2026) is the same shape inverted, `if dynamicTypeSize >= .xxLarge { ViewThatFits { withCount; withoutCount } } else { withCount }`, with an in-source doc comment spelling out the rationale.

**Sacrificed vs preserved.** Sacrificed above the gate: whatever the fallback drops (an icon, a count). Preserved below the gate: the exact designed layout, immune to `ViewThatFits` flipping early because a sibling got wider.

**Where it applies.** Rows where the rigid form is known to fit at all non-AX sizes and the reflow should engage only when it can genuinely be needed. 4 gates at HEAD: source row (`<= .accessibility3`), two filter-info rows (`<= .accessibility2`), widget monitor header (`>= .xxLarge`).

**Evidence.** Oct 2024 (app rows) and July 2026 (widget header). The July 2026 doc comment records the two rules the pattern encodes: the fallback sits **outside** the `ViewThatFits` gate so a smaller size can never drop content it does not need to drop, and the flexible `.frame(maxWidth: .infinity)` is applied **outside** the candidates, because inside a candidate a flexible frame absorbs the overflow and every candidate measures as fitting.

**Pitfalls.** Both rules above exist because the naive versions were tried: an ungated `ViewThatFits` dropped the count at small sizes whenever the row was merely narrow, and a flexible frame inside a candidate made the fitting test vacuous.

### P-05 Drop a decorative glyph or secondary line, keep the text

**Trigger.** A size gate that removes ornament rather than reflowing it; or deleting the ornament from the design outright.

**Before → After.** The paywall's decorative logo mark (a fixed-frame, fixed-font-size rounded box) is simply absent at AX sizes:

```swift
HStack(alignment: .top, spacing: 20) {
    if dynamicTypeSize < .accessibility3 {
        Text(brandMark)
            .font(.system(size: 45, design: .monospaced))
            .frame(width: 75, height: 75)
            .background { RoundedRectangle(cornerRadius: 14).stroke(lineWidth: 4) }
    }
    titleBlock   // the text always stays
}
```

The transfer chart hides its y-axis value labels at AX sizes (`if let v = value.as(Int.self), !dynamicTypeSize.isAccessibilitySize { AxisValueLabel(...) }`) but keeps the grid lines. And in Oct 2024 a promotional capsule badge overlaid on a store control was deleted from the design entirely rather than adapted.

**Sacrificed vs preserved.** Sacrificed: ornament (a mark, axis numerals, a badge). Preserved: the information-bearing text, and in the chart's case the shape of the data.

**Where it applies.** Decoration with fixed intrinsic size that would either overflow or dwarf the scaled text next to it. 3 live gates at HEAD (paywall mark, chart axis labels, small-widget freshness line, the last also counted under P-13).

**Evidence.** Chart axis gate Oct 2024; badge deletion Oct 2024; paywall mark gate Mar 2026.

**Pitfalls.** The deleted badge had carried `.lineLimit(1)` on a localized string inside a capsule: unfixable ornament was removed rather than patched, which the history treats as a legitimate outcome of an accessibility pass.

### P-06 Form row label + control: explicit branch, and native titles for system controls

**Trigger.** For custom rows: an explicit `isAccessibilitySize` branch. For system controls (`Picker`, `Toggle`, `TextField`): give the control its real localized title and let the system reflow.

**Before → After.** The current custom-row form (permissions rows, June 2026, renamed):

```swift
if dynamicTypeSize.isAccessibilitySize {
    VStack(spacing: 12) {
        label                                          // Label(title, symbol)
        control.frame(maxWidth: .infinity, alignment: .trailing)
    }
} else {
    HStack(spacing: 12) { label; control }
}
```

**The big lesson.** Oct 2024 introduced a custom `LabeledContentStyle` that flipped label/content into a `VStack` at AX sizes, applied through a `.labeled(title)` helper, with the actual controls created as `Picker("", ...)` and `TextField("", ...)`. Feb 2026 deleted the style and the helper wholesale ("remove the empty-string approach"): system controls already reflow their labeled layouts under Dynamic Type without help, and the empty titles broke VoiceOver, which had nothing to announce for the control itself. After: pickers carry their real titles; text fields carry their real titles too and, on iOS only, are wrapped in a thin `LabeledContent` (`textFieldLabeled`) purely to render the visible leading label next to a trailing-aligned field.

**Sacrificed vs preserved.** Sacrificed: uniform custom styling of every labeled row. Preserved: system reflow behavior, VoiceOver announcements, and one explicit branch where a genuinely custom row (label + status badge/button) needs it.

**Where it applies.** All forms. 1 explicit branch at HEAD; native titles everywhere else.

**Evidence.** Custom style born Oct 2024, deleted Feb 2026 (16 months); explicit permission-row branch June 2026.

**Pitfalls.** The whole 2024 mechanism is the pitfall: replicating a system behavior on top of blanked-out system titles cost accessibility elsewhere. The catalogue's strongest "do not" entry.

### P-07 Collapse a 2-column grid / wide layout to one column

**Trigger.** `dynamicTypeSize.isAccessibilitySize` folded into the column count or the wide-layout predicate.

**Before → After.**

```swift
// grid of stat cards
LazyVGrid(
    columns: .init(repeating: .init(spacing: 24),
                   count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
    spacing: 24
) { ... }

// wide two-pane screen
private var isExpandedLayout: Bool {
    size.width > 750 && !dynamicTypeSize.isAccessibilitySize
}
```

**Sacrificed vs preserved.** Sacrificed: density (one card per row; the single-pane layout on a wide screen). Preserved: every card, at full width, so scaled titles get the entire line.

**Where it applies.** The activity-card grid and the paywall's expanded layout. 2 production sites (the grid predicate is mirrored once in a preview harness).

**Evidence.** The wide-layout predicate is the codebase's **first** Dynamic Type adaptation (May 2024); the grid collapse came in the Oct 2024 accessibility pass. Both unchanged since.

**Pitfalls.** None recorded; the width-AND-not-AX conjunction was designed in from the start (a wide window does not make AX text narrow).

### P-08 Stepped metric by `switch dynamicTypeSize`

**Trigger.** A computed constant stepped over the full `DynamicTypeSize` range, always with `@unknown default` falling back to the base value.

**Before → After.** Before: fixed constants (`.frame(height: 200)`, flag icon 20 pt). After (HEAD, renamed):

```swift
var badgeSize: CGFloat {
    switch dynamicTypeSize {
    case .xSmall, .small: 16
    case .medium, .large, .xLarge, .xxLarge, .xxxLarge: 20
    case .accessibility1, .accessibility2: 30
    case .accessibility3, .accessibility4: 40
    case .accessibility5: 50
    @unknown default: 20
    }
}
```

The same shape sizes stat-card heights (200/250/300/325), chart height (250/350/450/600), and thins the chart's x-axis marks (a tick every 10/15/20 seconds) so scaled labels do not collide.

**Sacrificed vs preserved.** Sacrificed: continuous proportionality (steps, not a multiplier) and, for the axis, label density. Preserved: legible non-text elements that keep pace with the text instead of being dwarfed by it.

**Where it applies.** Non-text metrics that must track text size: image badges, fixed card frames, chart geometry. 4 switches at HEAD.

**Evidence.** Card/chart switches Oct 2024; badge-size switch May 2025.

**Pitfalls.** These switches predate the app's only `@ScaledMetric` (Aug 2026, P-12). The stepped form survives where the designer wants explicit control points (a card that jumps 200 to 250 exactly when the grid also collapses) rather than font-proportional scaling.

### P-09 Icon row + full-width name fallback

**Trigger.** `ViewThatFits(in: .horizontal)` whose fallback keeps a thin icon row (leading type icon, trailing status icon) and moves the name to its own full-width line, instead of stacking icon above name.

**Before → After.** Before: `HStack { Label(name, icon); statusIcon }`, name truncating. After (July 2025, renamed):

```swift
ViewThatFits(in: .horizontal) {
    HStack {
        Label(title: { nameLabel }, icon: { typeIcon })
            .frame(maxWidth: .infinity, alignment: .leading)
        statusIcon
    }
    VStack(spacing: 4) {
        HStack(spacing: .zero) {
            Label(title: { Text("") }, icon: { typeIcon })
                .frame(maxWidth: .infinity, alignment: .leading)
            statusIcon
        }
        nameLabel.frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

macOS is exempt (`#if os(macOS)` keeps the rigid row): pointer-driven windows resize instead.

**Sacrificed vs preserved.** Sacrificed: one-line compactness. Preserved: both icons in their meaningful positions (type leading, status trailing) and the full name wrapping across the whole width.

**Where it applies.** The file row inside the file-tree viewer; 1 site at HEAD. (The related source row drops its icon instead, via P-04's gated fallback.)

**Evidence.** July 2025, the second commit of the file-row saga (see P-02 pitfalls for the first).

**Pitfalls.** The empty-title `Label(title: { Text("") })` used to keep icon alignment is visual-only here and the row combines children for accessibility, so the P-06 empty-string concern does not bite; the name is read from its own `Text`.

### P-10 `lineLimit` policy

**Trigger.** A policy applied consistently rather than a construct:

- **`nil` (unlimited) for user-authored and localized text** standing on its own line: filter names were relaxed from `lineLimit(1)` to `lineLimit(nil)` in the Oct 2024 sweep; log timestamps carry `lineLimit(nil)`.
- **`1` only where a stacking container or a fixed budget owns the overflow**: inside `AdaptiveStack`-based rows (each stacked line stays single-line because the stack itself is the wrapping mechanism), and in fixed-height surfaces (stat cards, the status tray, widgets) where the height cannot give.
- **Small budgets for bounded semi-structured text**: the log row gives the category badge `lineLimit(3)` and the message body `lineLimit(30)`; insight rows carry per-item budgets (default 1, 2 for long names).

**Before → After.** Oct 2024 is the pivot: the same commit that added the adaptive rows also deleted or relaxed `lineLimit(1)` wherever it had been standing in for reflow (filters `1 → nil`, list rows losing row-wide clamps).

**Sacrificed vs preserved.** Sacrificed: unbounded growth for logs (a runaway message stops at 30 lines). Preserved: user text is never silently truncated at large sizes; truncation is only allowed where a budget was chosen on purpose.

**Where it applies.** Everywhere; roughly 50 `lineLimit(1)` sites at HEAD, all inside stacking containers or fixed budgets, plus the 2 explicit `nil` relaxations and the 3/30 log budgets.

**Evidence.** Relaxations Oct 2024; log budgets Oct 2024; insight budgets Mar 2025 onward.

**Pitfalls.** `lineLimit(1)` placed on a shared container clamps the vertical fallback too; the July 2025 file-row fix moved it onto the horizontal candidate only (P-02). That is the boundary of the "inside stacking containers" rule: on the component when single-line-per-stacked-line is wanted, on the horizontal candidate when the fallback must be allowed to wrap.

### P-11 Scroll-on-demand card + measured sheet height

**Trigger.** `ViewThatFits(in: .vertical)`: the card renders inline when it fits the proposed height, otherwise the same content wraps in a `ScrollView`. Paired with a sheet whose detent is the measured content height.

**Before → After.** Introduced whole in Mar 2026 with a one-time-offer card (renamed):

```swift
ViewThatFits(in: .vertical) {
    content
    ScrollView(content: { content })
        .scrollIndicators(.hidden)
}
```

```swift
// sheet modifier: measure an invisible copy, feed the detent
content
    .background {
        if let item {
            sheetContent(item)
                .bindSize(as: \.height, to: $measuredHeight, ignoresZero: true)
                .hidden()
        }
    }
    .sheet(item: $item) { item in
        sheetContent(item)
            .presentationDetents([.height(measuredHeight)])   // default 400
    }
```

**Sacrificed vs preserved.** Sacrificed: the fixed half-sheet silhouette. Preserved: a sheet that is exactly as tall as its scaled content (no clipped CTA at AX sizes, no dead space at small sizes), with scrolling appearing only when even full height is not enough.

**Where it applies.** The offer card presented from the paywall; 1 card and 1 reusable sheet modifier at HEAD.

**Evidence.** Mar 2026, alongside the premium-tier paywall work.

**Pitfalls.** The hidden measuring copy renders the sheet content twice; the modifier guards with `ignoresZero` so the pre-layout zero pass cannot collapse the detent.

### P-12 Bottom-bar overflow from measured width and `@ScaledMetric`

**Trigger.** The bar collapses its trailing button group into a single `More` menu when the measured bar width cannot give every item a minimum slot, where the minimum slot scales with text:

```swift
@ScaledMetric(relativeTo: .body) var barMinSlotWidth: CGFloat = 56
```

**Before → After.** Before Aug 2026 the edit-mode bar simply crowded. After: a pure, unit-tested resolver decides the shape, and the view renders from that single value (renamed):

```swift
struct BarLayout: Equatable {
    enum Trailing: Equatable { case inline, overflow }
    static let leadingSlotCount = 3
    let trailing: Trailing
    let slotCount: Int

    static func resolve(
        supportsGroupAction: Bool, supportsTagAction: Bool,
        availableWidth: CGFloat, minSlotWidth: CGFloat
    ) -> Self {
        let trailingCount = 1 + [supportsGroupAction, supportsTagAction].count(where: { $0 })
        let inlineSlotCount = leadingSlotCount + trailingCount
        let collapses = trailingCount > 1
            && availableWidth > .zero
            && availableWidth < CGFloat(inlineSlotCount) * minSlotWidth
        return collapses
            ? .init(trailing: .overflow, slotCount: leadingSlotCount + 1)
            : .init(trailing: .inline, slotCount: inlineSlotCount)
    }
}
```

The view passes `screenWidth * 0.9` as the available width, gives every item an equal `.frame(maxWidth: .infinity)` slot, and renders the overflow case as a `Menu { trailingItems } label: { Label(more, .ellipsisCircle) }`. The whole bar is `.labelStyle(.iconOnly)` (P-14).

**Sacrificed vs preserved.** Sacrificed: direct one-tap access to trailing actions when collapsed. Preserved: equal-width tap targets that grow with text, and the three primary actions always inline.

**Where it applies.** The edit-mode bottom bar; the only `@ScaledMetric` in the codebase.

**Evidence.** Aug 2026, with dedicated resolver unit tests. Two guards are load-bearing and doc-commented: an unmeasured bar (width 0) must not pre-collapse, and a lone trailing item never collapses because a lone `More` slot frees no width.

**Pitfalls.** Rendering count and width math both derive from the one resolved value so they cannot disagree; the earlier ad-hoc approach let the drawn item count drift from the width assumption.

### P-13 Widget content tiers by size

**Trigger.** Fixed-height widget families cannot scroll or grow, so content is tiered by explicit `dynamicTypeSize` thresholds: each tier drops the least important element.

**Before → After.** Widgets shipped May 2026 with `minimumScaleFactor(0.7)`/`0.75` sprinkled on; six days later those were stripped and replaced with tiers, refined through July 2026 (renamed):

```swift
// small family: freshness line is the first casualty
if dynamicTypeSize < .xxLarge { FreshnessLabel(...) }

// medium family: multi-item stack only while text is small enough
if dynamicTypeSize < .xLarge, items.count > 1 {
    MultiItemStack(items: items)
} else if let item = items.first {
    SingleItemView(item: item)
}

// monitor header: count yields, via the P-04 gated ViewThatFits
if dynamicTypeSize >= .xxLarge {
    ViewThatFits(in: .horizontal) {
        headerLabels(includesCount: true)
        headerLabels(includesCount: false)
    }
} else { headerLabels(includesCount: true) }
```

**Sacrificed vs preserved.** Sacrificed, in order: freshness metadata, then multi-item density, then a count. Preserved: the headline data (name, free space, speeds) at full, unscaled text size.

**Where it applies.** Both widget files (dashboard and monitor) plus the Live Activity views; 4 gates at HEAD.

**Evidence.** Scale factors added May 23 2026, stripped May 29 2026; medium-family tier refined July 6 2026; Live Activity scale factors stripped and the header gate added July 20 2026. Snapshot tests pin the boundaries, with a comment naming `.xLarge` as the last size that always keeps the count and `.accessibility5` as the size where it must give way.

**Pitfalls.** The stripped scale factors are the lesson: shrinking text in an unscrollable surface defeats the user's size choice; dropping the least important line keeps the rest honest.

### P-14 Toolbar items as `Label(...).labelStyle(.iconOnly)`; fixed-budget tray keeps scaling

**Trigger.** Toolbar and bar items are always `Label(title, systemSymbol:)` with `.labelStyle(.iconOnly)`: the title exists for accessibility, the glyph is what renders, and SF Symbols scale with the text style on their own.

**Before → After.** Stable since the 2023 bottom-bar work; 17 sites at HEAD:

```swift
Menu(content: content) {
    Label(moreActionsTitle, systemSymbol: .ellipsisCircle)
        .labelStyle(.iconOnly)
}
```

Toolbars are otherwise never size-adaptive: no `dynamicTypeSize` reads, no `ViewThatFits`, in any toolbar file. The one exception is the edit-mode bar's overflow logic (P-12), which is width-driven, not size-branched.

The bottom status tray is the companion case: a fixed-height strip that keeps text (speeds, status) rather than icons. It does not pin its type size; it constrains with `.lineLimit(1)` and `.minimumScaleFactor(0.5)` and lets an `isAccessibilitySize`-aware host swap it for a vertical layout elsewhere.

**Sacrificed vs preserved.** Sacrificed: visible words in bars. Preserved: symbol legibility at every size, VoiceOver labels via the `Label` title, and in the tray a bounded scale-down (never below half size) instead of truncation.

**Where it applies.** All toolbars, the more-menu, bar buttons; the status tray.

**Evidence.** Icon-only bars from Mar 2023; tray scale factor set at 0.5 in the Oct 2024 pass and unchanged since.

**Pitfalls.** None recorded for icon-only items. The tray's `0.5` is one of only 7 surviving `minimumScaleFactor` sites (see Cross-cutting).

### P-15 Deliberate opt-outs pinned to a fixed size

**Trigger.** `.dynamicTypeSize(.medium)` pinning a subtree to one size, on purpose.

**Before → After.** One production site (Aug 2025, renamed):

```swift
HStack(spacing: .zero) {
    Label(removeAdsTitle, systemSymbol: .eyeSlash)
        .padding(.horizontal, 16).padding(.vertical, 4)
        .onTapGesture(perform: openPaywall)
    Color.secondary.frame(width: 1, height: 10)
    Label(pauseAdsTitle, systemSymbol: .timer)
        .padding(.horizontal, 16).padding(.vertical, 4)
        .onTapGesture(perform: openSubscriptionSettings)
}
.dynamicTypeSize(.medium)
.font(.caption2)
.lineLimit(1)
.fixedSize(horizontal: true, vertical: false)
```

**Sacrificed vs preserved.** Sacrificed: text scaling for two tertiary, icon-bearing shortcuts in a fixed-height sidebar footer. Preserved: the footer's geometry; both actions remain reachable full-size one tap away (the paywall and settings they open scale normally).

**Where it applies.** Exactly this one row. The only other `.dynamicTypeSize(...)` call in the tree is a snapshot-test harness that parameterizes sizes on purpose.

**Evidence.** Aug 2025; unchanged since.

**Pitfalls.** The history shows restraint as the pattern: one pin in the whole app, on caption-sized ancillary UI, never on content.

## Cross-cutting observations

- **`minimumScaleFactor` is a retreat, and the codebase kept retreating from it.** Born at `0.2` (Oct 6 2024), raised to `0.5` sixteen days later, added to widgets at `0.7`/`0.75` (May 23 2026) and stripped within a week, stripped from Live Activities (July 2026). HEAD: 7 sites, all `0.5`, confined to the two fixed-height surfaces (stat cards, status tray) where height genuinely cannot give.
- **`ViewThatFits` needed a second run-up.** Tried July 2022 in the very first list row, removed Feb 2023 in favor of `fixedSize` + `lineLimit(1)`, returned Sept 2024 wrapped in the `AdaptiveStack` component, and has been the backbone ever since. The wrapper, not the raw API, is what made it stick: one shared content closure, spacer injection, and consistent alignment defaults.
- **Zero-site APIs.** `AnyLayout`, custom `Layout` conformances, `reservesSpace`, and `allowsTightening` have no uses in HEAD or at any point in the history. The `ViewThatFits`-based component covers the HStack/VStack swap without identity preservation, and the catalogue's animations tolerate that.
- **Monospaced digits keep the fitting stable.** 23 `monospacedDigit()`/monospaced-font sites (a dedicated Oct 2024 commit) prevent live counters from changing width every tick, which would otherwise make `ViewThatFits` flip candidates during animation.
- **`fixedSize(horizontal: true, vertical: false)` marks intrinsic members** inside horizontal candidates (speed labels, value texts) so the flexible member is unambiguous.
- **Stacked fallbacks are paired with `.accessibilityElement(children: .combine)`** on the row, so a layout that visually splits into four lines still reads as one element to VoiceOver, usually with hand-written `accessibilityLabel`s per member.
- **Adaptation lives in the view layer.** Every branch reads `@Environment(\.dynamicTypeSize)` locally; nothing about type size enters reducers or models. The single exception routes a scaled *value* (not the size enum) into pure logic: P-12 passes the `@ScaledMetric` slot width into a testable resolver.
- **Explicit gates beat blanket fitting.** The mature sites (P-04, P-13) gate `ViewThatFits` behind a size check so reflow can only happen where it can be needed, a direct correction of the naive "wrap everything and hope" first drafts.

## Timeline

| When | Event |
|---|---|
| Jul 2022 | `ViewThatFits` first tried in the very first list row. |
| Feb 2023 | Removed; row reverts to `HStack` + `fixedSize` + `lineLimit(1)`. |
| Mar 2023 | Icon-only bar/toolbar labels established (P-14). |
| May 2024 | First Dynamic Type predicate: paywall wide layout requires `width > 750 && !isAccessibilitySize` (P-07). |
| Sep 2024 | `ViewThatFits` returns as the `AdaptiveStack` component; main row adapted to AX5 (P-01, P-02). |
| Oct 6 2024 | Activity monitor ships with `minimumScaleFactor(0.2)`. |
| Oct 22 2024 | Accessibility pass: `0.2 → 0.5`; grid 2 → 1 column (P-07); stepped card/chart heights and axis density (P-08); axis labels dropped at AX (P-05); tray gets `0.5` (P-14). |
| Oct 27 2024 | Promotional badge deleted (P-05); monospaced digits for dynamic numbers. |
| Oct 29 2024 | `AdaptiveStack` promoted to a shared component. |
| Oct 30 2024 | Dynamic Type sweep: custom `LabeledContentStyle` + empty-title controls introduced (P-06); filter-info gates (P-04); `lineLimit` relaxations and the 30-line log budget (P-10); source-row gated fallback (P-04/P-09 sibling). |
| Mar 2025 | Insight rows with per-item line budgets (P-10). |
| Apr 2025 | Per-row always-vertical opt-out in the stats board (P-03). |
| May 2025 | Counters row with explicit `ViewThatFits` (P-02); stepped badge size in detail rows (P-08). |
| Jul 2025 | File row, two takes: spacer guard added to `AdaptiveStack`; conditional-`Spacer` pair rebuilt as explicit `ViewThatFits` with `lineLimit` on the horizontal candidate only (P-02); icon-row fallback (P-09). |
| Aug 2025 | The one fixed-size pin: sidebar footer ad row at `.medium` (P-15). |
| Nov 2025 | Backport dropped for native `Group(subviews:)` (P-01). |
| Feb 2026 | Empty-string approach deleted: native control titles, custom `LabeledContentStyle` removed (P-06). |
| Mar 2026 | Premium paywall work: decorative mark gated off at AX (P-05); scroll-on-demand card + measured sheet detent (P-11). |
| May 2026 | Widgets ship with `0.7`/`0.75` scale factors (May 23); stripped and replaced by content tiers within a week (May 29) (P-13). |
| Jun 2026 | Integration page rebuilt with the explicit AX branch for label + control rows (P-06). |
| Jul 2026 | Medium-widget tier refined (Jul 6); Live Activity scale factors stripped; gated `ViewThatFits` header with the rationale doc comment (Jul 20) (P-04, P-13). |
| Aug 2026 | Edit-mode bottom bar: the app's only `@ScaledMetric`, measured-width overflow, unit-tested pure resolver (P-12). |

## Method

**Sources.** A local read-only clone of the reference project (a shipping SwiftUI app, about 1,750 commits, 2022 to 2026). Discovery ran `git log -S` pickaxe over `*.swift` for `dynamicTypeSize` (13 commits), `isAccessibilitySize` (5), `ViewThatFits` (9), `minimumScaleFactor` (8), `accessibility3`, `ScaledMetric`, `lineLimit`, `fixedSize`, and `labelStyle`; every hit's diff was read with `git show`, and the current HEAD state of the 17 files matching `isAccessibilitySize|dynamicTypeSize|ViewThatFits|AnyLayout|ScaledMetric` was read in full. Site counts are `git grep` over HEAD.

**Anonymization.** The project is proprietary. Its name, bundle identifiers, feature and brand names, authors, dependency hosts, and commit hashes are omitted throughout; commits are cited by month/year and message paraphrase. All identifiers in snippets are renamed to neutral ones (`AdaptiveStack`, `ItemRow`-style names, `BarLayout`, `badgeSize`, and so on); structure, modifiers, and constants are reproduced faithfully.

**Verification notes and discrepancies.**
- **P-01 site count:** the pinned figure of 15 call sites undercounts. HEAD has **20** `AdaptiveStack` call sites across 10 files: 15 pass at least one argument and 5 use all defaults; the 15 evidently counted only the parenthesized calls. 9 of the 20 use `hSpaceBetween:` (P-02's figure of 9 is confirmed exactly).
- **`ViewThatFits` return date:** the pinned timeline says removed Feb 2023, returned Oct 2024. History shows the return was **Sept 22, 2024** (the AX5 row adaptation that created the component); Oct 2024 is when it spread and was shared. P-01's own "born Sept 2024" is the accurate date.
- All other pinned facts re-verified against the history and kept: the `Group(subviews:)` spacer injection with the single-subview guard; the trailing-pair recipe; the `<= .accessibility2/3` gate shapes with fallback outside the gate and flexible frames outside the candidates; the Oct 2024 to Feb 2026 arc of the custom `LabeledContentStyle`; the July 2025 file-row second try; the `0.2 → 0.5` and widget/Live Activity scale-factor arcs (HEAD: 7 sites, all `0.5`, in two fixed-height surfaces); the Jul 2022 / Feb 2023 / 2024 `ViewThatFits` arc; the single `@ScaledMetric` with its unit-tested resolver; the 17 icon-only label sites; the `lineLimit` policy including the (3, 30) log budgets; and the zero-site status of `reservesSpace`, `allowsTightening`, `AnyLayout`, and custom `Layout`.
