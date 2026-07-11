# Phase 3: Native Reader Paging Swap (spike-gated) - Context

**Gathered:** 2026-07-11T23:20:17+09:00
**Status:** Ready for planning

<domain>
## Phase Boundary

Replace the third-party `SwiftUIPager` dependency (DEP-05) with **stock SwiftUI** paging — validated by a feasibility spike first — with full behavior/appearance parity, then remove `SwiftUIPager` from `AppPackage/Package.swift`. There are **two** call sites, both in scope because the dependency can only be removed if both convert:

1. **Reader** — `ReadingFeature/ReadingView.swift` horizontal `Pager` (non-vertical reading directions), backed by a shared `Page` object that also drives the vertical `AdvancedList`, autoplay, the slider, and tap-to-turn.
2. **Home carousel** — `HomeFeature/HomeView+Sections.swift` `CardSlideSection`, a peeking / infinite-looping / opacity-fading card carousel.

The swap is **spike-gated and all-or-nothing** (see D-01/D-02): if native standard components cannot reach parity on either site, the whole task is skipped and `SwiftUIPager` is retained.

</domain>

<decisions>
## Implementation Decisions

### Phase-level frame (owner-decided 2026-07-11)
- **D-01:** **Standard components only.** The goal is to prove `SwiftUIPager` can be replaced with stock SwiftUI. Nothing third-party takes its place. If parity is unreachable with standard components, the correct outcome is to keep `SwiftUIPager`.
- **D-02:** **All-or-nothing go/no-go.** The dependency only leaves `Package.swift` if **both** call sites convert. If **either** the reader **or** the Home carousel cannot reach parity, the entire task is **skipped** (SwiftUIPager kept, DEP-05 marked not-viable / deferred). No half-migration where one site is swapped and the dep stays.
- **D-03:** **Exhaust standard approaches before declaring a gap.** The spike must genuinely try hard (tripled-buffer for looping, `.scrollTransition` for opacity, `layoutDirection` for RTL, `.scrollDisabled` for zoom, programmatic `.scrollPosition` for autoplay/slider/tap) before it is allowed to conclude native parity is impossible. "It's hard" is not "it's impossible."

### Native construct (owner-decided — supersedes DEP-05/ROADMAP wording)
- **D-04:** The native construct is a **horizontal paging `ScrollView`**, not a page-style `TabView`. This applies to **both** call sites. This decision **supersedes** the literal "page-style `TabView`" wording in DEP-05, the ROADMAP Phase 3 goal, and the PROJECT.md key-decision row — read those as "native page-style paging (mechanism, not a literal API mandate)."
  - Rationale: a page-style `TabView` provides no built-in way to **freeze its own swipe while an image is zoomed**, but the reader must stop paging when `scale > 1` (today `.allowsDragging(scale == 1)`). A paging `ScrollView` gives `.scrollDisabled` for exactly that, plus a two-way programmatic index via `.scrollPosition(id:)` and RTL via a `layoutDirection` flip.
- **D-05:** **Reader** uses `ScrollView(.horizontal)` + `.scrollTargetBehavior(.paging)` (viewport-width pages) + `.scrollPosition(id:)` + `.scrollDisabled(scale != 1)` + `.containerRelativeFrame(.horizontal)`. No `GeometryReader`.
- **D-06:** **Home carousel** uses `ScrollView(.horizontal)` + `.scrollTargetBehavior(.viewAligned)` + `.scrollTargetLayout()` for the peek/snap, `.scrollTransition` to reproduce `.interactive(opacity: 0.2)`, `.scrollClipDisabled()` to let neighbor cards peek, and item sizing that matches `.preferredItemSize(Defaults.FrameSize.cardCellSize)` + `.itemSpacing(20)`.
- **D-07:** **`Page` (the SwiftUIPager type) is deleted.** A plain index becomes the single source of truth, shared by: the reader's horizontal paging `ScrollView` selection, the vertical `AdvancedList` (already a native `ScrollView` + `scrollPosition` — only its `Page` param is re-seamed to the index), autoplay increment, the slider seek, tap-to-turn (`index ± offset`), and resume-page seeding at construction. A thin app-owned wrapper (mirroring `.update(.next)`/`.update(.new(index:))`) is allowed **only** if it measurably reduces call-site churn — planner's call; the bare `Int`/`@Observable` index is the default.

### Parity bars (strict — owner-decided)
- **D-08:** **Home carousel infinite loop is MANDATORY parity.** `.loopPages()` wrap-around must be preserved exactly (tripled-data buffer with silent re-centering). Peek + 0.2 opacity fade + 20pt `itemSpacing` + `.pagingPriority(.high)` snap must also match, and the external `pageIndex` binding (today `.synchronize($pageIndex, $page.index)`) must stay in sync. If the loop cannot be made smooth with standard components, that is a parity gap and (per D-02) the whole task is skipped.
- **D-09:** **Reader gesture-under-zoom is FULL parity on all three** (success criterion #3, non-negotiable): (a) paging fully frozen while zoomed (`.scrollDisabled(scale != 1)`), (b) pan works while zoomed, (c) RTL-aware edge single-tap page-turn preserved. Zoom / pan / tap must coexist with the paging `ScrollView` exactly as today.

### Spike (owner-decided)
- **D-10:** **Full-surface spike, then judge.** Build both replacements end-to-end across every behavior before rendering a go/no-go — a truer overall parity read and closer to the final code (chosen over risk-first early-exit). The full parity surface the spike must cover:
  - Reader: horizontal paging; RTL direction (`layoutDirection` flip) with correct index; dual-page mode (landscape) paging over stacks; `PageHandler.mapToPager`/`mapFromPager` index mapping incl. the dual-page cover math; programmatic jumps (slider seek, autoplay `.next`, tap-to-turn, resume-page seeding at construction) smooth with no glitch/off-by-one; gesture coexistence per D-09; the vertical `AdvancedList` re-seamed to the shared index.
  - Home carousel: peek + opacity + spacing + snap + `pageIndex` sync + the mandatory infinite loop (D-08).
- **D-11:** **Spike-to-keep (Phase 2 / SR-1 style).** If parity is proven, the spike code **is** the implementation — committed and evolved into the real swap (as Phase 2 committed its spike work, e.g. `08e7f7ef`), not thrown away. The sign-off artifact is a **go/no-go checklist** covering every parity item above, committed alongside; a genuine gap on any item triggers the D-02 skip and is documented.

### Scope fences (carried forward from Phase 2)
- **D-12:** **Do not touch `DeviceUtil` itself.** The reader legitimately reads `DeviceUtil.isLandscape` and `DeviceUtil.windowW` (dual-page width = `windowW / (isDualPage ? 2 : 1)`); de-globalizing those is Phase 5 (UIARCH-01). Keep using them this phase, unchanged — same fence as Phase 2's D-34.
- **D-13:** **Dependency + acknowledgement cleanup is part of "removed."** Removing `SwiftUIPager` also deletes: the `Package.swift` dependency declaration and its `.targetDependency(.swiftUIPager)` entries (research/planning verifies whether one is stale — 3 target-dependency entries exist but only `ReadingFeature` and `HomeFeature` import it); the `AboutView` SwiftUIPager acknowledgement row (`AppPackage/Sources/SettingFeature/Components/AboutView.swift:162-163`); and its `acknowledgementSwiftUIPager`/`...Link` xcstrings keys — mirroring Phase 2's WaterfallGrid acknowledgement removal. Only performed if D-02's go decision holds.

### Claude's Discretion
- RTL implementation mechanism (`layoutDirection` environment flip vs reversed data source) — spike/planner picks whatever hits parity cleanest, defaulting to the `layoutDirection` flip.
- Whether the shared index is a bare `Int` binding or a thin `@Observable` wrapper (D-07) — planner decides on call-site churn.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project scope
- `.planning/ROADMAP.md` — Phase 3 goal + success criteria (note: "page-style `TabView`" wording is superseded by D-04 → native paging `ScrollView`).
- `.planning/REQUIREMENTS.md` — DEP-05 acceptance criteria ("spike surfaces the gap" clause underwrites the D-02 skip path).
- `.planning/PROJECT.md` — Constraints (parity is absolute; avoid `GeometryReader`), Key Decisions (spike-first row; the "page-style TabView" phrasing superseded by D-04).
- `.planning/phases/02-native-masonry-grid-swap/02-CONTEXT.md` — the spike-gated-swap precedent (SR-1 spike: committed spike, sign-off artifact, mid-spike owner amendments; the `TagCloudView.swift` `FlowLayout` degenerate-proposal idiom).

### Reader call site (DEP-05 core)
- `AppPackage/Sources/ReadingFeature/ReadingView.swift` — the `Pager` (line 143) and the shared `@StateObject var page: Page`; `.horizontal(RTL)`, `.swipeInteractionArea`, `.allowsDragging(scale == 1)`; slider `setPageIndex` → `page.update(.new(index:))`; autoplay `page.update(.next)`; resume seeding `.withIndex` in `init`.
- `AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift` — the **vertical** reading path; already a native `ScrollView` + `LazyVStack` + `.scrollPosition` + `.onScrollPhaseChange`, coupled to SwiftUIPager only via the shared `Page` (re-seam to the plain index).
- `AppPackage/Sources/ReadingFeature/Support/PageHandler.swift` — `mapToPager`/`mapFromPager` index math incl. dual-page cover handling (must stay correct against the new index).
- `AppPackage/Sources/ReadingFeature/Support/AutoPlayHandler.swift` — timer-driven `updatePageAction` (today `page.update(.next)`).
- `AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift` — tap-to-turn (`page.index + offset` → `page.update(.new(index:))`), magnify, pan, dismiss gestures.
- `AppPackage/Sources/ReadingFeature/Support/GestureHandler.swift` — `scale`/`offset`/anchor state that gates paging (`scale == 1`).

### Home carousel call site
- `AppPackage/Sources/HomeFeature/HomeView+Sections.swift` — `CardSlideSection` (line 41): `Pager` with `.preferredItemSize(Defaults.FrameSize.cardCellSize)`, `.interactive(opacity: 0.2)`, `.itemSpacing(20)`, `.loopPages()`, `.pagingPriority(.high)`, `.synchronize($pageIndex, $page.index)`.

### Replaced library (behavior baseline) + cleanup targets
- `AppPackage/Package.swift` — `SwiftUIPager` dependency (line 21) + `.targetDependency(.swiftUIPager)` entries (≈299/718/780) to remove; verify a possibly-stale third entry.
- `AppPackage/.build/checkouts/SwiftUIPager/**` — reference for `Page`, `.loopPages`, `.interactive`, `.itemSpacing`, `.swipeInteractionArea`, `.allowsDragging`, `.synchronize` semantics being reproduced.
- `AppPackage/Sources/SettingFeature/Components/AboutView.swift` (lines 162-163) — SwiftUIPager acknowledgement row to delete; matching `acknowledgementSwiftUIPager`/`...Link` xcstrings keys.

### Native API surface (all available on the iOS 26 target)
- `.scrollTargetBehavior(.paging)` / `.scrollTargetBehavior(.viewAligned)` + `.scrollTargetLayout()` (iOS 17+); `.scrollPosition(id:)` (iOS 17+); `.containerRelativeFrame(_:)` (iOS 17+); `.scrollDisabled(_:)` (iOS 16+); `.scrollTransition` (iOS 17+); `.scrollClipDisabled()` (iOS 17+).

</canonical_refs>

<code_context>
## Existing Code Insights (verified 2026-07-11)

### Reusable Assets
- **The vertical path already went native.** `AdvancedList` is a `ScrollView`/`LazyVStack`/`.scrollPosition` implementation; it depends on SwiftUIPager solely for the `Page` index bus. Re-seaming it to the shared plain index is the smallest part of the swap and de-risks the vertical direction outright.
- **`FlowLayout` degenerate-proposal idiom** (`AppPackage/Sources/AppComponents/TagCloudView.swift`) — the house pattern for defensive geometry, referenced by Phase 2.

### Established Patterns
- **One shared page index drives everything.** Today `Page` unifies horizontal pager, vertical list, autoplay, slider, and tap-to-turn. The replacement must keep that single-source-of-truth shape so the four writers/readers stay coherent — the risk is programmatic writes (autoplay/slider/tap) fighting the `.scrollPosition(id:)` binding (glitch / off-by-one on the leading-item id). This is the spike's central proof.
- **Paging is gated on zoom.** `.allowsDragging(gestureHandler.scale == 1)` today → `.scrollDisabled(scale != 1)` in the replacement (D-09).
- **Dual-page** collapses pages into stacks via `containerDataSource`; the pager pages over stacks, and `PageHandler` maps stack-index ↔ reading-page incl. the cover-exception math. The new construct pages over the same stack data source; only the index binding changes.

### Integration Points
- Reader index changes fan out to the reducer via `.onChange(of: page.index)` → `mapFromPager` → `store.send(.syncReadingProgress(...))`; the slider, autoplay, and resume-seeding write back through the same index. All of this must move onto the plain index without changing the reducer contract.
- Home carousel's `pageIndex` binding is observed by the parent Home view; the replacement must preserve that outward binding (the `.synchronize` equivalent).

</code_context>

<specifics>
## Specific Ideas

- Keep `PageHandler`'s mapping as a unit-testable pure function and add a Swift Testing table over the dual-page / cover / RTL cases exercised against the new index — there is currently no dedicated `PageHandler` test (existing reading tests are reducer-level in `DownloadsFeatureTests`).
- The go/no-go checklist (D-11) should enumerate each parity item from D-10 explicitly (horizontal, RTL, dual-page, index mapping, autoplay, slider, resume-seed, zoom/pan/tap coexistence, carousel peek/opacity/spacing/loop/sync) with a pass/gap mark for owner sign-off.
- Spike should log the real `.scrollPosition(id:)` behavior on programmatic jumps (does the leading-item id land exactly on the target page after `.update`-equivalents?) before trusting it for autoplay/slider.

</specifics>

<deferred>
## Deferred Ideas

- Reconciling the literal "page-style `TabView`" wording in `ROADMAP.md` / `REQUIREMENTS.md` (DEP-05) / `PROJECT.md` with the D-04 paging-`ScrollView` decision — a separate `/gsd-phase` edit if the owner wants the source docs updated; CONTEXT.md records the supersession authoritatively for downstream agents regardless.
- De-globalizing `DeviceUtil` (`isLandscape`/`windowW`) — Phase 5 (UIARCH-01); the reader keeps reading them this phase (D-12).

None else — discussion stayed within phase scope.

</deferred>

---

*Phase: 3-Native Reader Paging Swap (spike-gated)*
*Context gathered: 2026-07-11T23:20:17+09:00*
