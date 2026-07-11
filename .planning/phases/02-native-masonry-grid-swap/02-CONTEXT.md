# Phase 2: Native Masonry Grid Swap - Context

**Gathered:** 2026-07-11T09:46:14+09:00
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the third-party `WaterfallGrid` dependency with an app-owned custom SwiftUI `Layout` that reproduces vertical masonry column-balancing, validated by a feasibility spike first. Single call site: the `.thumbnail` list display mode in `GalleryListComponents/GenericList.swift` (used by Home / Search / Favorites / etc.). Vertical scrolling only; horizontal is unused.

</domain>

<decisions>
## Implementation Decisions

### Column Derivation (owner-decided 2026-07-11)
- **D-20:** The column count is derived solely from the `Layout`'s own proposed (container) width — no `UIScreen`, `DeviceUtil`, size-class, or idiom reads. Rule: `N = max(2, floor((w + s) / (m + s)))` with `s = 15` (spacing) and `m = 185` (minimum cell width). This is `GridItem(.adaptive(minimum:))` semantics inside the custom `Layout`.
- **D-21:** All cells share one identical *flexible* width per layout pass: `cellWidth = (w − s·(N−1)) / N`. Spacing stays fixed at 15pt; the leftover space goes into cell width, never into spacing. Outer padding remains the `List` row insets — the `Layout` adds none.
- **D-22:** Exact 2/4/5 column-count parity with WaterfallGrid is **explicitly dropped** (owner decision — the counts were never the owner's requirement). The replacement bar: (a) the count is a pure function of container width — structurally immune to cell content, image loading, tag settings, and Dynamic Type; (b) density stays near today's (m = 185 keeps most environments within ±1 column).
- **D-23:** `m = 185` is a design knob, not a parity constant. The spike logs real `proposal.width` values per reference device and produces a column-count table for sign-off; adjusting `m` is a one-constant change.
- **D-24:** No hysteresis on band boundaries. The width input is exact (not measured content), so flips only occur on genuine window resize; hysteresis would make the `Layout` stateful for no benefit.
- **D-25:** The `min 2` clamp covers Slide-Over-width windows (~320pt), matching today's narrow-window behavior. No max clamp.

### Masonry Algorithm Parity (still binding)
- **D-26:** Placement algorithm is preserved exactly: fixed N; items placed in data order into the currently shortest column; ties → leftmost via strict first-minimum scan with exact `CGFloat` comparison (a `<=` scan or tolerance compare changes placements).
- **D-27:** Spacing semantics: between items and between columns only — no leading offset, no trailing spacing in the reported height (`max(0, tallestColumn − spacing)` equivalent).
- **D-28:** Keep exact division for `cellWidth` — no pixel rounding "improvements".
- **D-29:** Subview heights come from `subview.sizeThatFits(width: cellWidth, height: nil)` measured *after* N and `cellWidth` are fixed; measurement results never feed back into N. Use a `Layout` cache so a page of ~25 async image loads doesn't re-measure everything twice per invalidation.
- **D-30:** Structure parity: the grid remains **one eager row inside the existing `List`** (same `List`, same `.refreshable`, same notice section and fetch-more footer siblings). No lazy-container swap — that would be a redesign and invalidate the scrolling comparison.
- **D-31:** Suppress implicit animations on placement. Today's grid internally disables all animation (`.animation(nil, value: UUID())` fires every transaction), so the outer `.animation(.default, value: galleries)` never animates cell placement on fetch-more appends; a naive `Layout` would let placements animate. Match today via transaction suppression.
- **D-32:** Handle degenerate proposals (`nil`/zero/infinite width probes in `sizeThatFits`) defensively, like the existing `FlowLayout` (`AppPackage/Sources/AppComponents/TagCloudView.swift`) — derive N only from finite widths.
- **D-33:** The synchronous `Layout` removes WaterfallGrid's first-layout opacity flash and async placement hop — an accepted, strictly-beneficial deviation.

### Scope Fences
- **D-34:** The two legacy reads die *with the component*: delete `columnsInPortrait`/`columnsInLandscape` in `GenericList.swift` (the library's own `UIScreen.main` read — deprecated API — is deleted with the library). Do **not** touch `DeviceUtil.isPadWidth` itself or its five other consumers (ControlPanel, CategoryView, ArchivesView, PreviewsView, `Defaults+Runtime`) — that is Phase 5 / UIARCH-01 scope.
- **D-35:** Do not generalize the adaptive rule into an app-wide breakpoint system; keep it a private, documented policy of the masonry layout so Phase 5 can ratify or replace it, and Phase 6's grid-atom extraction (UIARCH-02) can lift the `Layout` unchanged.

### Owner Amendments (SR-1 spike, 2026-07-11)
- **D-36 (amends D-30):** The thumbnail grid's pagination changes from the **manual chevron footer** to **automatic load-on-scroll**, mirroring detail display mode — an owner request made during the SR-1 spike. This supersedes only the "fetch-more footer siblings" element of D-30; the rest of D-30 (same `List(.plain)`, `.refreshable`, notice `Section`, one eager masonry row) stays binding. Implementation (committed in the spike as `08e7f7ef`): the manual chevron `Button` is deleted; a `FetchMoreFooter` (spinner/retry only) lives **inside** the single masonry `List` row (a `VStack` with the grid), and pagination is driven by `onScrollGeometryChange` distance-to-bottom, gated on a user-driven scroll phase (`onScrollPhaseChange` = `tracking`/`interacting`/`decelerating`) **and** fired at most once per `galleries.count`. The footer MUST stay inside the masonry row: as a sibling `List` row it is anchored by the List during appends, which pins the viewport to the bottom and chains loads endlessly (root-caused via trigger-diagnostic logs — a load's append perturbs the very scroll geometry a geometry-keyed guard re-arms on). Detail mode's own pagination (`DetailList`, last-cell `onAppear`) is unchanged.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project Scope
- `.planning/ROADMAP.md` — Phase 2 goal and rewritten success criteria.
- `.planning/REQUIREMENTS.md` — DEP-04 rewritten acceptance criteria.
- `.planning/PROJECT.md` — Key Decisions table (column-derivation decision row).

### Call Site And Precedent
- `AppPackage/Sources/GalleryListComponents/GenericList.swift` — `WaterfallList` (the single call site), `columnsInPortrait`/`columnsInLandscape` to delete, notice/footer/List structure to preserve.
- `AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift` — variable-height cell (KFImage `scaledToFit` + title + optional tag cloud); height changes after async image load.
- `AppPackage/Sources/AppComponents/TagCloudView.swift` — existing `FlowLayout: Layout` sibling idiom (cache-less, degenerate-proposal handling).
- `AppPackage/Sources/AppTools/DeviceUtil.swift` — `isPadWidth`/`windowW` definitions (NOT to be modified this phase).

### Replaced Library (behavior baseline)
- `AppPackage/.build/checkouts/WaterfallGrid/Sources/WaterfallGrid/WaterfallGrid.swift` — placement algorithm (`alignmentsAndGridHeight`), column width math, opacity flash, animation suppression.
- `AppPackage/.build/checkouts/WaterfallGrid/Sources/WaterfallGrid/Environment/GridSyle.swift` — the deprecated `UIScreen.main` orientation read being removed.
- `AppPackage/Package.swift` — WaterfallGrid dependency declaration to remove.

</canonical_refs>

<code_context>
## Existing Code Insights (verified 2026-07-11)

### Corrected Facts (differ from earlier assumptions)
- Only the *orientation* half of today's column choice reads the physical screen (`UIScreen.main.bounds`, deprecated API, inside the library). The *pad-vs-phone* half reads the **window** (`keyWindow.frame` short side ≥ 744), so narrow Split View panes already degrade to 2 columns today. The live quirk: landscape 2/3 panes (~772–904pt) get 5 columns crammed in, with an abrupt 5→2 cliff at pane short-side 744.
- **Phone landscape is unreachable for this grid**: `AppOrientationMask` portrait-locks phones app-wide; only the Reading feature unlocks landscape. The phone-landscape vs iPad-portrait width-band collision is latent until Phase 5 (UIARCH-03) removes the lock — Phase 5 must ratify what landscape phones get (the width rule yields 4 columns on most, 2 on SE).
- **Width space matters**: the `Layout` receives the `List` row *content* width (~16–20pt insets per side), not the window width. All constants are defined against content width; the spike must measure real proposals before freezing anything.

### Expected Column Counts at m=185 (content width; sign-off table)
- Phones portrait (335–408pt) → 2 (unchanged)
- iPad mini portrait (~710pt) → 3 (today 4 — accepted)
- 11" iPad portrait (~790pt) → 4 (unchanged)
- 13" iPad portrait (~990pt) → 4 (unchanged)
- iPad landscape ~1040–1140pt → 5 (unchanged)
- 13" iPad landscape (~1336pt) → 6 (today 5 — accepted)
- Split View / Slide Over / Stage Manager → container-coherent bands (today: incoherent window-min-dim + physical-orientation mix)

### Integration Points
- `GenericList` renders the grid as a single `List` row alongside a notice `Section` and a fetch-more footer; `List` owns scroll + `.refreshable`.
- Kingfisher drives async cover loads; cell height settles after load, so the `Layout` must re-flow on subview size invalidation (verify in spike).

</code_context>

<specifics>
## Specific Ideas

- Expose the derivation as a unit-testable pure function (e.g. `columnCount(for width: CGFloat) -> Int`) with named, doc-commented constants; Swift Testing table over the device-width list above.
- Spike order: (1) log real `proposal.width` per reference device; (2) confirm masonry placement + reflow-on-image-load + scrolling; (3) produce the column-count table for owner sign-off; (4) freeze `m`.

</specifics>

<deferred>
## Deferred Ideas

- Landscape-phone column policy (2 via idiom clamp vs 4 via width rule) — decide in Phase 5 when UIARCH-03 unlocks rotation.
- Any app-wide adaptive/breakpoint vocabulary — Phase 5 (UIARCH-01).
</deferred>

---

*Phase: 2-Native Masonry Grid Swap*
*Context gathered: 2026-07-11T09:46:14+09:00*
