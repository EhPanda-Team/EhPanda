# Phase 2: Native Masonry Grid Swap - Research

**Researched:** 2026-07-11
**Domain:** SwiftUI custom `Layout` protocol (iOS 26), masonry column-balancing, dependency removal
**Confidence:** HIGH (codebase facts + in-repo precedent), MEDIUM (SwiftUI runtime reflow/animation behavior — the exact points the spike gate exists to confirm)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

Column derivation (owner-decided 2026-07-11):
- **D-20:** Column count derived solely from the `Layout`'s own proposed (container) width — no `UIScreen`, `DeviceUtil`, size-class, or idiom reads. Rule `N = max(2, floor((w + s) / (m + s)))` with `s = 15` (spacing), `m = 185` (minimum cell width). `GridItem(.adaptive(minimum:))` semantics inside the custom `Layout`.
- **D-21:** All cells share one identical *flexible* width per pass: `cellWidth = (w − s·(N−1)) / N`. Spacing fixed at 15pt; leftover goes into cell width, never spacing. Outer padding stays the `List` row insets — the `Layout` adds none.
- **D-22:** Exact 2/4/5 column-count parity with WaterfallGrid **explicitly dropped**. Bar: (a) count is a pure function of container width — structurally immune to cell content, image loading, tag settings, Dynamic Type; (b) density stays near today's (m=185 keeps most environments within ±1 column).
- **D-23:** `m = 185` is a design knob, not a parity constant. Spike logs real `proposal.width` per reference device, produces a column-count table for sign-off; adjusting `m` is a one-constant change.
- **D-24:** No hysteresis on band boundaries. Width input is exact (not measured content), so flips only on genuine window resize.
- **D-25:** The `min 2` clamp covers Slide-Over-width windows (~320pt). No max clamp.

Masonry algorithm parity (still binding):
- **D-26:** Placement preserved exactly: fixed N; items placed in data order into the currently shortest column; ties → leftmost via strict first-minimum scan with exact `CGFloat` comparison (a `<=` scan or tolerance compare changes placements).
- **D-27:** Spacing between items and between columns only — no leading offset, no trailing spacing in reported height (`max(0, tallestColumn − spacing)` equivalent).
- **D-28:** Exact division for `cellWidth` — no pixel rounding "improvements".
- **D-29:** Subview heights come from `subview.sizeThatFits(width: cellWidth, height: nil)` measured *after* N and `cellWidth` are fixed; measurement never feeds back into N. Use a `Layout` cache so a page of ~25 async image loads doesn't re-measure everything twice per invalidation.
- **D-30:** Structure parity: grid remains **one eager row inside the existing `List`** (same `List`, same `.refreshable`, same notice section and fetch-more footer siblings). No lazy-container swap.
- **D-31:** Suppress implicit animations on placement (match today's WaterfallGrid, which internally disables placement animation so fetch-more appends don't animate cell positions).
- **D-32:** Handle degenerate proposals (`nil`/zero/infinite width probes in `sizeThatFits`) defensively, like the existing `FlowLayout` — derive N only from finite widths.
- **D-33:** The synchronous `Layout` removes WaterfallGrid's first-layout opacity flash and async placement hop — an accepted, strictly-beneficial deviation.

Scope fences:
- **D-34:** The two legacy reads die *with the component*: delete `columnsInPortrait`/`columnsInLandscape` in `GenericList.swift` (the library's own `UIScreen.main` read is deleted with the library). Do **not** touch `DeviceUtil.isPadWidth` itself or its five other consumers — that is Phase 5 / UIARCH-01 scope.
- **D-35:** Do not generalize the adaptive rule into an app-wide breakpoint system; keep it a private, documented policy of the masonry layout so Phase 5 can ratify/replace it and Phase 6 (UIARCH-02) can lift the `Layout` unchanged.

### Claude's Discretion

- The exact API shape of the pure `columnCount(for:)` function and where the placement algorithm is factored for unit-testability.
- Spike mechanics (SR-1) and how "scrolling not regressed" (SR-3) is observed given the Xcode-only harness.

### Deferred Ideas (OUT OF SCOPE)

- Landscape-phone column policy (2 via idiom clamp vs 4 via width rule) — Phase 5 (UIARCH-03 unlocks rotation).
- Any app-wide adaptive/breakpoint vocabulary — Phase 5 (UIARCH-01).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEP-04 | Replace WaterfallGrid with a custom SwiftUI `Layout`: cells share one flexible width, 15pt spacing, column count a pure function of container width (`max(2, floor((w+15)/(185+15)))`), masonry shortest-column balancing preserved, no `UIScreen`/`DeviceUtil` reads, WaterfallGrid removed, scrolling not regressed. Spike-gated. | Layout mechanics (§Architecture Patterns), exact parity math extracted from the WaterfallGrid source (§State of the Art / Code Examples), reflow-on-load + animation-suppression patterns (§Common Pitfalls), removal mechanics (§Don't Hand-Roll / Environment), spike design (§Validation Architecture). |
</phase_requirements>

## Summary

This is a behavior-preserving swap of the third-party `WaterfallGrid` (paololeonardi, pinned `1.1.0`, revision `c7c08652`) for an app-owned `struct MasonryLayout: Layout`. The call site is single: the `.thumbnail` branch of `AppPackage/Sources/GalleryListComponents/GenericList.swift` (`WaterfallList`, lines 149–238). The deployment target is **iOS 26** (`AppPackage/Package.swift:991` `platforms: [.iOS(.v26)]`; app target `IPHONEOS_DEPLOYMENT_TARGET = 26.0`), so the full modern `Layout` protocol (iOS 16+) is available unconditionally, and there is an authoritative in-repo precedent — `FlowLayout: Layout` in `AppPackage/Sources/AppComponents/TagCloudView.swift:32–92`.

The parity target is fully extractable from source. WaterfallGrid's `alignmentsAndGridHeight` (`WaterfallGrid.swift:69–89`) and `columnWidth` (`:91–95`) give the exact math: fixed N columns, each item placed in data order into the *leftmost shortest* column (`heights.min()` then `firstIndex(of: minValue)` — exact `CGFloat` equality, D-26), `cellWidth = (w − spacing·(N−1)) / N`, reported grid height `max(0, tallestColumn − spacing)` (D-27). The custom `Layout` reproduces this synchronously (D-33 removes the library's `GeometryReader` + `DispatchQueue` async-preference hop and its `.opacity` first-layout flash).

The genuinely uncertain parts — the exact reason the spike gate exists (SR-1) — are SwiftUI *runtime* behaviors, not API shapes: (1) whether a `Layout` re-runs `sizeThatFits`/`placeSubviews` when a Kingfisher cover settles and a subview's ideal height changes, and does so without a `makeCache`/`updateCache` call (it does not call `updateCache` for pure size changes — the cache must be treated as a within-pass memo, not a cross-pass height store); (2) whether implicit placement animation on fetch-more appends can be suppressed to match today; (3) whether scrolling holds up with ~25+ eager cells and async loads inside a `List` row. All three are observable in the spike before implementation is committed.

**Primary recommendation:** Extract two pure, unit-testable functions — `columnCount(for:) -> Int` and a placement planner over `[CGFloat]` heights → origins + total size — into `GalleryListComponents`, make `MasonryLayout: Layout` a thin conformance that calls them, re-measure heights every `sizeThatFits` pass (never trust cached heights across invalidations), use the `Cache` only to hand the freshly-computed plan to the immediately-following `placeSubviews` of the same pass, and gate the whole implementation behind a spike that (a) logs real `proposal.width` per reference device, (b) confirms masonry + reflow-on-load + scrolling, (c) produces the sign-off table, (d) freezes `m`.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Column count from width | Custom `Layout` (`MasonryLayout`, pure `columnCount(for:)`) | — | D-20: derived solely from the Layout's own proposed width; no device/screen tier involved |
| Masonry placement (shortest-column balancing) | Custom `Layout` (`placeSubviews`, pure planner) | — | D-26/D-27: deterministic geometry owned by the layout |
| Subview intrinsic height | Cell view (`GalleryThumbnailCell`) via `subview.sizeThatFits` | Kingfisher (async cover drives height settle) | D-29: heights measured at fixed `cellWidth`, never fed back into N |
| Scroll, refresh, pagination footer, notice section | `List` (unchanged, in `WaterfallList`) | — | D-30: structure parity; `List` keeps owning scroll + `.refreshable` |
| Animation suppression on append | Grid subtree modifier (`.animation(nil, value:)` / `.transaction`) | — | D-31: neutralize the ancestor `.animation(.default, value: galleries)` for the grid only |

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftUI `Layout` protocol | iOS 16+ (target iOS 26) | App-owned masonry layout container | First-party, zero-dependency; the whole point of DEP-04 is to shed the third-party grid. `[CITED: developer.apple.com/documentation/swiftui/layout]` |
| Kingfisher `KFImage` | 8.x (`Package.swift:22`) | Async cover loading in the cell (existing) | Already the cell's image path; unchanged this phase. `[VERIFIED: AppPackage/Package.swift:22]` |

**No package is added this phase.** DEP-04 is a net *removal* (WaterfallGrid) plus new app-owned Swift in an existing module. There is therefore no install step and no new third-party supply-chain surface.

### Supporting (in-repo, existing)

| Symbol | Location | Purpose | When to Use |
|--------|----------|---------|-------------|
| `FlowLayout: Layout` | `AppComponents/TagCloudView.swift:32` | Precedent: `sizeThatFits`/`placeSubviews`, degenerate-proposal handling, cache-less `inout ()` | Template for the new `MasonryLayout`; copy its defensive `proposal.width ?? .infinity` / `maxWidth.isFinite` idiom (D-32) |
| `GalleryThumbnailCell` | `GalleryListComponents/Cells/GalleryThumbnailCell.swift:10` | The variable-height cell placed into the grid | Unchanged; it is the `subview` the Layout measures. `KFImage … .scaledToFit()` (`:37–45`) is the async-height source |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Custom `Layout` | `LazyVGrid` + `GridItem(.adaptive)` | Rejected implicitly by D-20/D-26/D-30: `LazyVGrid` gives *row*-aligned grids, not masonry shortest-column balancing, and would be a lazy-container swap (D-30 forbids). Not viable for masonry. |
| One eager `Layout` row in `List` | Standalone `ScrollView` + `Layout` | D-30 forbids — would drop `List`'s `.refreshable`/notice/footer structure and invalidate the scrolling comparison. |
| Re-measure heights each pass | Cache heights across passes | D-29 + SwiftUI reality: `updateCache` is NOT called on pure subview-size changes, so a cross-pass height cache goes stale on image load. Re-measure every `sizeThatFits`; cache only within-pass. |

## Package Legitimacy Audit

> Not applicable — this phase installs **no** external packages. It removes one (`WaterfallGrid`) and adds only app-owned Swift. No registry verification is required. See §Environment Availability for the removal mechanics.

## Architecture Patterns

### System Architecture Diagram

```
listDisplayMode == .thumbnail
        │
        ▼
  WaterfallList (private struct, GenericList.swift:149)
        │  owns: List(.plain) + .refreshable + notice Section + fetch-more footer   [D-30 unchanged]
        ▼
  List {
    notice Section?                                             ── unchanged
    ┌─────────────────────────────────────────────┐
    │  ONE eager row:                              │
    │  MasonryLayout {                             │  ◀── replaces WaterfallGrid(...).gridStyle(...)
    │      ForEach(galleries) { Button { cell } }  │
    │  }                                           │
    │  .animation(nil, value: galleries)  [D-31]   │
    └─────────────────────────────────────────────┘
    fetch-more footer / chevron                                 ── unchanged
  }
        │
        ▼  proposal.width  = List row content width (already inset ~16–20pt/side, NOT window width)
  MasonryLayout.sizeThatFits(proposal, subviews, cache)
        │   1. guard finite/positive width (D-32) → else return safe zero-height
        │   2. N   = columnCount(for: width)            (pure, D-20)  → max(2, floor((w+15)/(185+15)))
        │   3. cW  = (width − 15·(N−1)) / N             (exact, D-21/D-28)
        │   4. heights = subviews.map { sizeThatFits(width: cW, height: nil).height }   (D-29 measure)
        │   5. plan = masonryPlan(heights, N, cW, 15)   (pure, D-26/D-27)
        │   6. cache ← (width, plan)                     (within-pass memo only, D-29)
        ▼
  MasonryLayout.placeSubviews(bounds, proposal, subviews, cache)
        │   reuse cache.plan iff cache.width == proposal.width, else recompute
        │   for each subview: place(at: bounds.origin + plan.origins[i], proposal: (width: cW, height: nil))
        ▼
  Rendered masonry (synchronous — no opacity flash, no async hop) [D-33]
```

Async reflow path: `KFImage` cover settles → `GalleryThumbnailCell` reports a new ideal height → SwiftUI invalidates the enclosing `MasonryLayout` → `sizeThatFits`/`placeSubviews` re-run (fresh measure) → columns re-balance. `makeCache`/`updateCache` are **not** re-invoked (subview identity/count unchanged), which is exactly why heights must be re-measured, not cached across passes.

### Recommended Project Structure

```
AppPackage/Sources/GalleryListComponents/
├── GenericList.swift            # EDIT: WaterfallList swaps WaterfallGrid → MasonryLayout;
│                                #       delete columnsInPortrait/columnsInLandscape (D-34);
│                                #       drop `import WaterfallGrid`
├── MasonryLayout.swift          # NEW: struct MasonryLayout: Layout  (thin conformance)
│                                #      + static columnCount(for:) and masonryPlan(...) pure fns (D-35 private policy)
└── Cells/GalleryThumbnailCell.swift   # UNCHANGED (the measured subview)

AppPackage/Tests/GalleryListComponentsTests/   # NEW test target (Wave 0 gap — does not exist)
├── .swiftlint.yml               # parent_config: ../../../.swiftlint.yml
└── MasonryLayoutTests.swift     # Swift Testing table over columnCount(for:) + placement planner
```

### Pattern 1: `Layout` conformance delegating to pure functions

**What:** `MasonryLayout` implements only the two required `Layout` methods; all arithmetic lives in `static` pure functions that take plain values (so they are unit-testable without a live view tree).
**When to use:** Always here — `LayoutSubviews` is not synthesizable in a unit test, so the testable seam must be value-in/value-out.
**Example:**
```swift
// Source: signatures confirmed against AppComponents/TagCloudView.swift:35-69 (FlowLayout precedent)
//         and developer.apple.com/documentation/swiftui/layout
struct MasonryLayout: Layout {
    /// Fixed policy constants — private to the masonry layout (D-35). `m`/`s` are design knobs (D-23).
    static let spacing: CGFloat = 15       // D-21 fixed inter-item/inter-column spacing
    static let minCellWidth: CGFloat = 185 // D-20 `m` (frozen only after spike sign-off, D-23)
    static let minColumns = 2              // D-25 clamp

    struct Cache { var proposalWidth: CGFloat?; var plan: MasonryPlan? }
    func makeCache(subviews: Subviews) -> Cache { Cache(proposalWidth: nil, plan: nil) }
    // updateCache uses the default (re-calls makeCache) — cache holds no cross-pass state anyway.

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        // D-32: derive N only from a finite, positive width; probe proposals get a safe answer.
        guard let w = proposal.width, w.isFinite, w > 0 else {
            return CGSize(width: proposal.width ?? 0, height: 0)
        }
        let n = Self.columnCount(for: w)
        let cellW = Self.cellWidth(containerWidth: w, columns: n)          // D-21/D-28 exact
        // D-29: measure AFTER N and cellWidth are fixed; results never feed back into N.
        let heights = subviews.map { $0.sizeThatFits(.init(width: cellW, height: nil)).height }
        let plan = Self.masonryPlan(heights: heights, columns: n, cellWidth: cellW, spacing: Self.spacing)
        cache.proposalWidth = w; cache.plan = plan                         // within-pass memo only
        return CGSize(width: w, height: plan.size.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        guard let w = proposal.width, w.isFinite, w > 0 else { return }
        let n = Self.columnCount(for: w)
        let cellW = Self.cellWidth(containerWidth: w, columns: n)
        // Reuse the plan from this pass's sizeThatFits; recompute only if the width differs.
        let plan = (cache.proposalWidth == w ? cache.plan : nil)
            ?? Self.masonryPlan(
                heights: subviews.map { $0.sizeThatFits(.init(width: cellW, height: nil)).height },
                columns: n, cellWidth: cellW, spacing: Self.spacing
            )
        for (i, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + plan.origins[i].x, y: bounds.minY + plan.origins[i].y),
                proposal: .init(width: cellW, height: nil)
            )
        }
    }
}
```

### Pattern 2: The pure, testable core (mirrors WaterfallGrid exactly)

```swift
struct MasonryPlan: Equatable { var origins: [CGPoint]; var size: CGSize }

extension MasonryLayout {
    /// D-20: `GridItem(.adaptive(minimum:))` semantics from the container width alone.
    static func columnCount(for width: CGFloat) -> Int {
        guard width.isFinite, width > 0 else { return minColumns }            // D-32
        return max(minColumns, Int((width + spacing) / (minCellWidth + spacing))) // Int() == floor for w>0
    }
    /// D-21/D-28: exact division; leftover space → cell width, never spacing.
    static func cellWidth(containerWidth w: CGFloat, columns n: Int) -> CGFloat {
        (w - spacing * CGFloat(n - 1)) / CGFloat(n)
    }
    /// D-26/D-27: data-order, leftmost-shortest-column, exact CGFloat tie compare;
    /// height = max(0, tallestColumn − spacing). Mirrors WaterfallGrid.alignmentsAndGridHeight.
    static func masonryPlan(heights: [CGFloat], columns n: Int, cellWidth: CGFloat, spacing: CGFloat) -> MasonryPlan {
        var columnHeights = Array(repeating: CGFloat.zero, count: n)
        var origins: [CGPoint] = []
        for h in heights {
            var c = 0                                                        // strict first-minimum scan:
            for i in 1..<n where columnHeights[i] < columnHeights[c] { c = i } // `<` keeps the first on ties (leftmost)
            origins.append(CGPoint(x: CGFloat(c) * (cellWidth + spacing), y: columnHeights[c]))
            columnHeights[c] += h + spacing
        }
        let totalHeight = max(0, (columnHeights.max() ?? spacing) - spacing)  // D-27
        let totalWidth = CGFloat(n) * cellWidth + CGFloat(n - 1) * spacing
        return MasonryPlan(origins: origins, size: CGSize(width: totalWidth, height: totalHeight))
    }
}
```
> The `for i in 1..<n where columnHeights[i] < columnHeights[c]` scan is provably identical to WaterfallGrid's `heights.min()` + `heights.firstIndex(of: minValue)`: both return the *first* index attaining the minimum, using exact equality (D-26). Do not "improve" it to `<=`.

### Pattern 3: Animation suppression matching today (D-31)

WaterfallGrid neutralizes placement animation internally: `.animation(self.loaded ? self.style.animation : nil, value: UUID())` (`WaterfallGrid.swift:64`) — and the call site passes `animation: nil` (`GenericList.swift:216`), so it is effectively `.animation(nil, value: UUID())` on every render. The outer `GenericList` still applies `.animation(.default, value: galleries)` (`GenericList.swift:77`); the library's inner suppression is what stops cell *placement* from animating on fetch-more appends.

The custom `Layout` inherits the ancestor `.animation(.default, value: galleries)` unless neutralized. Match today by attaching a suppressing modifier to the grid subtree only:
```swift
MasonryLayout {
    ForEach(galleries) { gallery in /* Button { GalleryThumbnailCell(...) } */ }
}
.animation(nil, value: galleries)   // innermost wins → grid placement does not animate on append (D-31)
```
`[CITED: developer.apple.com/documentation/swiftui/transaction/disablesanimations]` — the value-based `.animation(nil, value:)` is the precise analog of WaterfallGrid's inner `.animation(nil, value:)`. If a spike shows it does not fully suppress inside a `List` row, fall back to `.transaction { $0.animation = nil }` on the same subtree (broader — verify it does not also kill the cell's `KFImage.fade(duration: 0.25)`). Confirm in the spike (SR-1). `[ASSUMED]` that subtree-level `.animation(nil, value:)` overrides the ancestor animation inside a `List` row — verify in spike.

### Anti-Patterns to Avoid

- **Caching measured heights across layout passes.** `updateCache` is not called when an existing subview merely changes size (image load), so a height cache goes stale and the grid stops reflowing. Re-measure every `sizeThatFits`; cache only the within-pass plan. `[CITED: developer.apple.com/documentation/swiftui/layout/updatecache(_:subviews:)]`
- **Reading `DeviceUtil`/`UIScreen`/size class for N.** Forbidden by D-20/D-34 — the whole point is that N comes from the proposed width only.
- **`<=` or tolerance tie-breaks.** Changes placements vs. WaterfallGrid (D-26).
- **Rounding `cellWidth`.** Forbidden by D-28.
- **Swapping the eager row for a lazy container.** Forbidden by D-30; invalidates the scroll comparison.
- **Adding padding/insets in the Layout.** D-21: outer padding stays the `List` row insets; the Layout adds none.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Container-width measurement | `GeometryReader` wrapper (as WaterfallGrid does, `WaterfallGrid.swift:29`) | `Layout`'s `proposal.width` | The Layout is *handed* its width; `GeometryReader` is exactly what the milestone is trying to shed (UIARCH-01 avoids it) and reintroduces the async hop D-33 removes |
| Async placement plumbing | `onPreferenceChange` + `DispatchQueue` (WaterfallGrid.swift:31–42) | Synchronous `Layout` methods | The Layout protocol computes geometry synchronously on the main layout pass — no preference keys, no dispatch, no first-layout opacity flash (D-33) |
| Column derivation policy | Ad-hoc breakpoints / idiom checks | Single pure `columnCount(for:)` | D-20/D-35: one documented pure function, unit-tested, liftable unchanged by Phase 6 |

**Key insight:** The custom `Layout` is *simpler* than WaterfallGrid, not more complex — it deletes an entire class of machinery (GeometryReader, ElementPreferenceKey, background dispatch, alignment guides, opacity gating). The risk is not code volume; it is confirming three SwiftUI runtime behaviors (reflow-on-load, animation suppression, scroll perf) — which is what the spike gate covers.

## Common Pitfalls

### Pitfall 1: Grid stops reflowing after covers load
**What goes wrong:** Cells overlap or leave gaps because column heights were computed against placeholder heights and never recomputed once `KFImage` covers settled.
**Why it happens:** Trusting a cross-pass height cache; `updateCache` fires on subview *identity/count* changes, not on an existing subview's size change.
**How to avoid:** Re-measure `subviews.map { $0.sizeThatFits(...) }` inside every `sizeThatFits`; use `Cache` only to carry that pass's plan to `placeSubviews`. Confirm live in the spike that a settling cover triggers a fresh pass. `[CITED: developer.apple.com/documentation/swiftui/layout/updatecache(_:subviews:)]`
**Warning signs:** Grid looks right only after a scroll nudge; gaps under short cells; overlap where a cover grew.

### Pitfall 2: Cells animate into place on "load more"
**What goes wrong:** Appending a page slides existing cells to new positions (WaterfallGrid never did this).
**Why it happens:** The ancestor `.animation(.default, value: galleries)` (`GenericList.swift:77`) now reaches the Layout's placements.
**How to avoid:** `.animation(nil, value: galleries)` on the grid subtree (Pattern 3); verify inside `List` in the spike.
**Warning signs:** Visible reshuffle on fetch-more; motion on refresh.

### Pitfall 3: Bogus column count from a probe proposal
**What goes wrong:** `List`'s sizing pass probes `sizeThatFits` with `nil`/`0`/`.infinity` width; a naive `floor((∞+15)/200)` yields a huge/garbage N.
**Why it happens:** No guard on the proposed width.
**How to avoid:** D-32 guard (Pattern 1/2): `guard width.isFinite, width > 0 else { return minColumns }` for N; return a zero-height safe size for degenerate `sizeThatFits`. Mirror `FlowLayout`'s `maxWidth.isFinite ? maxWidth : .greatestFiniteMagnitude` idiom (`TagCloudView.swift:75`).
**Warning signs:** Momentary 1-column or absurd-column render; layout jump on first appear.

### Pitfall 4: `proposal.width` is the row content width, not the window width
**What goes wrong:** Constants tuned against window width put N one band off; the `List` row insets (~16–20pt/side under `.listStyle(.plain)`) are already subtracted from what the Layout receives.
**Why it happens:** Assuming the Layout sees full window width.
**How to avoid:** The spike's step 1 (log real `proposal.width` per reference device) exists precisely to freeze `m` against measured content width (CONTEXT "Width space matters"). Do not freeze `m=185` before that table.
**Warning signs:** Column counts off-by-one from the CONTEXT sign-off table.

### Pitfall 5: `List` row-inset vs. Layout-added padding double counting (D-21)
**What goes wrong:** Adding leading/trailing padding in the Layout on top of `List` row insets narrows the grid vs. today.
**Why it happens:** Treating the Layout as edge-to-edge when `List` already insets the row.
**How to avoid:** Layout adds no outer padding; keep whatever row insets `WaterfallList`'s `List` gives today (no `.listRowInsets` change). Between-item/between-column spacing only (D-27).

## Runtime State Inventory

> This is a code/UI swap, not a rename or data migration — but the audit is run explicitly to avoid missing non-file state.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — the grid holds no persisted state; `@Shared(.setting)` drives `listDisplayMode` and is untouched. Verified: no WaterfallGrid state in any `@Shared`/model. | None |
| Live service config | None — no external service references the grid. | None |
| OS-registered state | None. | None |
| Secrets/env vars | None. | None |
| Build artifacts | `AppPackage/Package.resolved` pins `waterfallgrid` (lines 266–272, rev `c7c08652`, v1.1.0) and `AppPackage/.build/checkouts/WaterfallGrid/` is a resolved checkout. Both regenerate on `swift package resolve` after the `Package.swift` dependency is removed. | Remove dep from `Package.swift`, regenerate `Package.resolved`, let the stale checkout drop |
| Acknowledgement UI | `SettingFeature/Components/AboutView.swift:165–168` renders a WaterfallGrid acknowledgement (`.Constant.acknowledgementWaterfallGrid` + `…Link`). **Precedent:** Phase 1 removed SwiftCommonMark/UIImageColors as deps but *kept* their acknowledgement rows (AboutView still lists SwiftCommonMark `:186`, UIImageColors `:174`, SwiftUIPager `:162`). | Judgment call for the planner — see Open Questions Q1. Leaving the attribution matches Phase 1 precedent; removing it is also defensible. Not blocking. |

## Code Examples

### Extracted parity baseline — WaterfallGrid's actual math
```swift
// Source: AppPackage/.build/checkouts/WaterfallGrid/Sources/WaterfallGrid/WaterfallGrid.swift:69-95
// columnWidth (:91-95):
//   width = max(0, geometryWidth - spacing*(columns-1)); return width / columns
// alignmentsAndGridHeight (:69-89):
//   heights = [0]*columns
//   for preference in data-order:
//     indexMin = heights.firstIndex(of: heights.min()!)      // leftmost shortest, exact ==
//     x = cellWidth*indexMin + indexMin*spacing               // == indexMin*(cellWidth+spacing)
//     y = heights[indexMin]
//     heights[indexMin] += preferenceHeight + spacing
//   gridHeight = max(0, heights.max()! - spacing)             // D-27
// NOTE: the library measured each cell's NATURAL size then reframed to columnWidth;
//       the Layout measures at the fixed cellWidth directly (D-29) — equal or more correct.
```

### Swift Testing table for the pure functions (Wave 0 target)
```swift
// Source: pattern per swift-testing-pro; new target AppPackage/Tests/GalleryListComponentsTests
import Testing
@testable import GalleryListComponents

@Suite struct MasonryColumnCountTests {
    // CONTEXT sign-off table (content widths). Values reflect m=185, s=15, min 2.
    @Test(arguments: [
        (335.0, 2), (408.0, 2),          // phones portrait
        (710.0, 3),                       // iPad mini portrait (today 4 — accepted)
        (790.0, 4), (990.0, 4),           // 11" / 13" iPad portrait
        (1040.0, 5), (1140.0, 5),         // iPad landscape
        (1336.0, 6),                      // 13" landscape (today 5 — accepted)
        (320.0, 2)                        // Slide Over clamp (D-25)
    ] as [(CGFloat, Int)])
    func columnCount(width: CGFloat, expected: Int) {
        #expect(MasonryLayout.columnCount(for: width) == expected)
    }

    @Test func degenerateWidthsClampToMin() {
        #expect(MasonryLayout.columnCount(for: 0) == 2)
        #expect(MasonryLayout.columnCount(for: -10) == 2)
        #expect(MasonryLayout.columnCount(for: .infinity) == 2)
        #expect(MasonryLayout.columnCount(for: .nan) == 2)   // D-32
    }

    @Test func placementIsLeftmostShortestColumn() {
        // 2 columns, three equal-height items → cols [0,1,0]; tie always leftmost.
        let plan = MasonryLayout.masonryPlan(heights: [100, 100, 100], columns: 2, cellWidth: 160, spacing: 15)
        #expect(plan.origins.map(\.x) == [0, 175, 0])          // 0, cellW+spacing, 0
        #expect(plan.origins.map(\.y) == [0, 0, 115])          // third stacks under col 0
        #expect(plan.size.height == 215)                        // max col = 100+15+100+15; −15 = 215
    }
}
```
> The pure functions carry the parity assertions; the `Layout` conformance itself is validated visually in the spike (a live `LayoutSubviews` cannot be synthesized in a unit test).

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `WaterfallGrid` (GeometryReader + preference keys + background `DispatchQueue` + alignment guides + opacity gating) | `struct MasonryLayout: Layout` synchronous `sizeThatFits`/`placeSubviews` | iOS 16 (2022) introduced `Layout`; target is iOS 26 | Removes a dependency, the async hop, and the first-layout opacity flash (D-33) |
| Column count from `UIScreen.main.bounds` orientation (`GridSyle.swift:22-24`, deprecated API) + `DeviceUtil.isPadWidth` (`GenericList.swift:160-165`) | Pure `columnCount(for: proposal.width)` | This phase | Kills the deprecated `UIScreen.main` read (dies with the library) and the grid-site `isPadWidth` read (D-34); container-coherent bands |
| `.animation(nil, value: UUID())` inside the library | `.animation(nil, value: galleries)` on the grid subtree | This phase | Same effect (no placement animation), explicit at the call site |

**Deprecated/outdated:**
- `UIScreen.main.bounds` (`GridSyle.swift:23`) — deprecated; removed with WaterfallGrid, not migrated (D-34).
- WaterfallGrid `1.1.0` — last pinned revision `c7c08652`; removed from `Package.swift:23` and `:49`, and from the two target dependency lists (`:301` app target, `:482` GalleryListComponents).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Subtree `.animation(nil, value: galleries)` fully suppresses `Layout` placement animation when the Layout is a row inside `List` | Pattern 3 / Pitfall 2 | Cells animate on fetch-more; fallback is `.transaction { $0.animation = nil }` — verify it doesn't kill `KFImage.fade`. Spike (SR-1) resolves this. |
| A2 | A settling `KFImage` cover triggers a fresh `MasonryLayout` pass (re-measure) without `updateCache` | Pattern 1 / Pitfall 1 | Grid stops reflowing; would need an explicit invalidation trigger. This is a core spike question (SR-1). |
| A3 | `sizeThatFits` and the immediately-following `placeSubviews` receive the same `proposal.width` for a `List` row (so the within-pass cache is a valid optimization) | Pattern 1 | If widths differ, `placeSubviews` recomputes (correctness preserved; just a missed optimization). Low risk — code already falls back. |
| A4 | `m = 185` yields the CONTEXT sign-off column table against *content* width | Standard Stack / Pitfall 4 | Off-by-one bands; `m` is a one-constant change (D-23) after the spike's real-`proposal.width` log. Expected, not a failure. |
| A5 | Column-count expectations in the Swift Testing table (e.g. 710→3, 1336→6) match the CONTEXT table exactly | Code Examples | Test values need adjusting to measured widths post-spike; the table is illustrative until step 1 logs real widths. |

**All A1–A5 are exactly what the SR-1 spike de-risks before implementation is committed.** None is a locked-decision infeasibility — no BLOCKER surfaced.

## Open Questions

1. **WaterfallGrid acknowledgement row in `AboutView`.**
   - What we know: `AboutView.swift:165–168` shows a WaterfallGrid acknowledgement; Phase 1 *kept* acknowledgement rows for removed deps (SwiftCommonMark/UIImageColors still listed).
   - What's unclear: whether removing the dep should also remove the attribution.
   - Recommendation: follow Phase 1 precedent (leave the attribution — MIT courtesy) unless the owner wants a clean-up sweep. Either way it is a 1-line localized-string decision, not blocking. Surface to the owner in discuss/plan.

2. **New `GalleryListComponentsTests` target vs. FeatureTests.xctestplan.**
   - What we know: the `AppPackage-Package` scheme runs all test targets automatically (STATE 01-01 note); `FeatureTests.xctestplan` is the app-scheme plan.
   - What's unclear: whether the new target must be added to `FeatureTests.xctestplan` to run under the app scheme.
   - Recommendation: add the target to `Package.swift` (picked up by the package scheme automatically) and, if the phase's CI/verify runs the app scheme's test plan, add it to `FeatureTests.xctestplan` too. Confirm which scheme the phase's test command uses.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode toolchain (Swift 6.3.1) | Build/test (bare `swift build` fails — package memory) | ✓ (project baseline) | 6.3.1 | — |
| iOS Simulators (SE, 15/16 Pro, iPad mini, iPad 11", iPad 13") | Spike step 1 (log real `proposal.width`) + column sign-off table | ✓ assumed (standard Xcode sim set) | iOS 26 | Physical devices |
| Split View / Slide Over / Stage Manager | Spike band coverage (D-25, narrow windows) | ✓ (iPad simulator multitasking) | iOS 26 | Manual resize |
| Instruments (Animation Hitches / Core Animation) | SR-3 scroll observation (optional) | ✓ (ships with Xcode) | — | Manual visual scroll comparison vs. WaterfallGrid baseline |

**Missing dependencies with no fallback:** None.
**Missing dependencies with fallback:** SR-3 scroll perf has no automated harness (see §Validation Architecture) — fallback is manual observation on a large fetched list vs. the current WaterfallGrid build.

## Validation Architecture

> `.planning/config.json` was not found to disable `nyquist_validation`; treated as enabled.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (project standard; e.g. `ImageColorsTests`, `MarkdownExtTests`) |
| Config file | `AppPackage/Package.swift` test targets; `AppPackage/Tests/FeatureTests.xctestplan` (app scheme) |
| Quick run command | `xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -only-testing:GalleryListComponentsTests` |
| Full suite command | `xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone 16 Pro'` |

> Run exactly one `xcodebuild test` invocation at a time (project memory: overlapping invocations wedge `testmanagerd`). `xcodebuild` buffers stdout until exit — no output ≠ hang.

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEP-04 | `columnCount(for:)` is a pure fn of width (adaptive rule, min 2) | unit | `-only-testing:GalleryListComponentsTests/MasonryColumnCountTests/columnCount` | ❌ Wave 0 |
| DEP-04 | Degenerate widths clamp to min (D-32) | unit | `…/degenerateWidthsClampToMin` | ❌ Wave 0 |
| DEP-04 | Placement = leftmost-shortest-column + exact tie + `max(0, tallest−spacing)` height (D-26/D-27) | unit | `…/placementIsLeftmostShortestColumn` | ❌ Wave 0 |
| DEP-04 | Masonry balances + reflows on cover load; no placement animation on append; scroll not regressed | manual / spike | Spike observation on simulator + device (SR-1, SR-3) | N/A (visual) |
| DEP-04 | WaterfallGrid removed from dependency set (SR-4) | build | Full package build; grep confirms zero `WaterfallGrid` refs in `Package.swift`/`.resolved` | build gate |

### Sampling Rate
- **Per task commit:** the `-only-testing:GalleryListComponentsTests` quick run (pure functions) + clean build.
- **Per wave merge:** full package test suite.
- **Phase gate:** full suite green + spike sign-off (SR-1) + manual scroll observation (SR-3) before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `AppPackage/Tests/GalleryListComponentsTests/MasonryLayoutTests.swift` — covers DEP-04 pure-function behavior
- [ ] `AppPackage/Tests/GalleryListComponentsTests/.swiftlint.yml` — `parent_config: ../../../.swiftlint.yml` (per project rule for new modules)
- [ ] `Package.swift`: add `case galleryListComponentsTests = "GalleryListComponentsTests"` to `Module` and a `.testTarget(module: .galleryListComponentsTests, dependencies: [.module(.galleryListComponents)])` entry
- [ ] (If app-scheme tests are used) add `GalleryListComponentsTests` to `AppPackage/Tests/FeatureTests.xctestplan`
- [ ] Spike harness: temporary `proposal.width` logging in `sizeThatFits` for the sign-off table (removed before implementation lands)

### Spike Design (SR-1 gate)
Ordered per CONTEXT "Specific Ideas":
1. **Log** real `proposal.width` in `MasonryLayout.sizeThatFits` across reference devices (SE, 15/16 Pro, iPad mini, 11", 13") and multitasking widths (Split View / Slide Over / Stage Manager). Produce the column-count table.
2. **Confirm** live: masonry shortest-column placement matches WaterfallGrid intent; grid re-flows when Kingfisher covers settle (A2); no placement animation on fetch-more append (A1); scrolling is smooth on a large fetched list.
3. **Produce** the owner sign-off column-count table (compare to the CONTEXT expected-counts list).
4. **Freeze** `m` (default 185; adjust as a one-constant change if the table warrants — D-23).

If step 2 surfaces that reflow-on-load or animation suppression cannot be achieved with the `Layout` approach, that is the BLOCKER the spike gate exists to surface *before* implementation is committed (SR-1).

### Scroll performance (SR-3)
No automated harness exists (Xcode-only, no perf-assertion infrastructure in the repo). Observe, don't assert:
- Fetch several pages (Popular/Frontpage) to get 100+ eager cells, scroll fast, and compare against a current WaterfallGrid build for dropped frames / hitches. Optionally attach Instruments (Animation Hitches or Core Animation FPS) for a numeric read.
- The synchronous `Layout` should *improve* first-layout behavior (D-33 removes the opacity flash + async hop); the risk is per-frame `sizeThatFits` cost with many subviews — the within-pass cache (Pattern 1) keeps it to one measure per invalidation.

## Project Constraints (from CLAUDE.md / AGENTS.md)

- **Reducer naming:** N/A this phase (no new reducer; `MasonryLayout` is a view type, not a `Feature`).
- **New module `.swiftlint.yml`:** the new `GalleryListComponentsTests` test target needs `AppPackage/Tests/GalleryListComponentsTests/.swiftlint.yml` with `parent_config: ../../../.swiftlint.yml` (matches every existing test dir, e.g. `ImageColorsTests/.swiftlint.yml`). `GalleryListComponents/` itself already has one.
- **Read root `.swiftlint.yml` before writing Swift:** done. Active rules that touch this code — `force_unwrapping` **error** and `force_try` **error** (§`.swiftlint.yml:13-17`): the planner-facing code above uses no `!`/`try!` (note `columnHeights.max()!` in the illustrative snippet must become `?? spacing` in real code — the WaterfallGrid original force-unwraps but the app rule forbids it). `line_length`/`file_length` 120/1000 at error. No `// swiftlint:disable` without owner permission.
- **Labeled localized-format args:** N/A — no new numeric localized-format strings this phase (the acknowledgement string question is plain text).
- **Confirmation-dialog placement:** N/A this phase.
- **Local-project-reference privacy:** honored — no external project named anywhere in this research.
- **No absolute home paths in generated docs:** honored — all paths repository-relative.

## Sources

### Primary (HIGH confidence — in-repo, authoritative)
- `AppPackage/Sources/AppComponents/TagCloudView.swift:32-92` — `FlowLayout: Layout` precedent (method signatures, degenerate-proposal handling)
- `AppPackage/.build/checkouts/WaterfallGrid/Sources/WaterfallGrid/WaterfallGrid.swift:27-95` — placement algorithm, column-width math, opacity/animation behavior (parity baseline)
- `AppPackage/.build/checkouts/WaterfallGrid/Sources/WaterfallGrid/Environment/GridSyle.swift:16-25` — deprecated `UIScreen.main` orientation read (removed with the library)
- `AppPackage/Sources/GalleryListComponents/GenericList.swift:6,58-64,149-238` — single call site, `columnsInPortrait/Landscape` to delete, `List`/notice/footer structure to preserve
- `AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift:35-95` — variable-height cell; `KFImage … scaledToFit()` async-height source
- `AppPackage/Package.swift:23,49,301,482,991` — WaterfallGrid dependency lines + iOS 26 platform
- `AppPackage/Package.resolved:266-272` — WaterfallGrid pin (v1.1.0, rev c7c08652)
- `AppPackage/Sources/AppTools/DeviceUtil.swift:13-15` — `isPadWidth` (NOT modified this phase, D-34)
- Repo grep — the *only* `import WaterfallGrid` is `GenericList.swift:6`; other refs are the AboutView acknowledgement string

### Secondary (MEDIUM confidence — official Apple docs, cited)
- developer.apple.com/documentation/swiftui/layout — protocol methods, cache lifecycle
- developer.apple.com/documentation/swiftui/layout/updatecache(_:subviews:) — cache invalidation on subview change
- developer.apple.com/documentation/swiftui/transaction/disablesanimations — animation suppression

### Tertiary (LOW confidence — community, corroborating only)
- swiftwithmajid.com / swiftui-lab.com Layout-protocol articles — corroborate cache-updates-on-subview-change and the double `sizeThatFits`→`placeSubviews` pass; treated as directional, verified against the FlowLayout precedent

## Metadata

**Confidence breakdown:**
- Parity algorithm / column math: HIGH — extracted verbatim from WaterfallGrid source and expressible with the in-repo `FlowLayout` idioms.
- `Layout` API mechanics (signatures, cache, degenerate handling): HIGH — confirmed by the in-repo `FlowLayout` precedent + Apple docs.
- Runtime reflow-on-load + animation suppression inside `List` (A1/A2): MEDIUM — the explicit reason SR-1 is spike-gated; observable before commit.
- Scroll perf (SR-3): MEDIUM — no automated harness; manual observation vs. baseline.

**Research date:** 2026-07-11
**Valid until:** 2026-08-10 (stable APIs; re-verify only if the iOS/SwiftUI target or WaterfallGrid pin changes)
