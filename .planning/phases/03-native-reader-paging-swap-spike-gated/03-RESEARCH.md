# Phase 3: Native Reader Paging Swap (spike-gated) - Research

**Researched:** 2026-07-11
**Domain:** SwiftUI native scroll-paging (iOS 26 target) replacing the `SwiftUIPager` dependency at two call sites (reader + Home carousel)
**Confidence:** HIGH on the reader mechanics and cleanup targets; MEDIUM on the two make-or-break items (programmatic `.scrollPosition(id:)` fidelity under `.paging`, and a smooth stock infinite carousel loop) — those are exactly what the spike (D-10) exists to prove.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01: Standard components only.** Nothing third-party replaces SwiftUIPager. If parity is unreachable with stock SwiftUI, the correct outcome is to keep SwiftUIPager.
- **D-02: All-or-nothing go/no-go.** The dependency leaves `Package.swift` only if **both** call sites (reader + Home carousel) convert. If either cannot reach parity, the entire task is skipped (SwiftUIPager kept, DEP-05 marked not-viable / deferred). No half-migration.
- **D-03: Exhaust standard approaches before declaring a gap.** The spike must genuinely try tripled-buffer looping, `.scrollTransition` opacity, `layoutDirection` RTL, `.scrollDisabled` zoom-freeze, and programmatic `.scrollPosition` for autoplay/slider/tap before concluding native parity is impossible. "It's hard" is not "it's impossible."
- **D-04: The native construct is a horizontal paging `ScrollView`, NOT a page-style `TabView`.** Applies to both call sites. **Supersedes** the literal "page-style `TabView`" wording in DEP-05, the ROADMAP Phase 3 goal, and the PROJECT.md key-decision row. Rationale: a page-style `TabView` cannot freeze its own swipe while an image is zoomed; a paging `ScrollView` gives `.scrollDisabled(scale != 1)` for exactly that, plus a two-way programmatic index via `.scrollPosition(id:)` and RTL via a `layoutDirection` flip.
- **D-05: Reader** uses `ScrollView(.horizontal)` + `.scrollTargetBehavior(.paging)` + `.scrollTargetLayout()` + `.scrollPosition(id:)` + `.scrollDisabled(scale != 1)` + `.containerRelativeFrame(.horizontal)`. No `GeometryReader`.
- **D-06: Home carousel** uses `ScrollView(.horizontal)` + `.scrollTargetBehavior(.viewAligned)` + `.scrollTargetLayout()` for peek/snap, `.scrollTransition` to reproduce `.interactive(opacity: 0.2)`, `.scrollClipDisabled()` to let neighbors peek, item sizing matching `.preferredItemSize(Defaults.FrameSize.cardCellSize)` + `.itemSpacing(20)`.
- **D-07: `Page` (the SwiftUIPager type) is deleted.** A plain index becomes the single source of truth for: the reader's horizontal paging `ScrollView` selection, the vertical `AdvancedList`, autoplay increment, slider seek, tap-to-turn (`index ± offset`), and resume-page seeding at construction. A thin app-owned wrapper (mirroring `.update(.next)`/`.update(.new(index:))`) is allowed **only** if it measurably reduces call-site churn — planner's call; bare `Int`/`@Observable` index is the default.
- **D-08: Home carousel infinite loop is MANDATORY parity.** `.loopPages()` wrap-around preserved exactly (tripled-data buffer with silent re-centering). Peek + 0.2 opacity fade + 20pt `itemSpacing` + `.pagingPriority(.high)` snap must also match, and the external `pageIndex` binding (today `.synchronize($pageIndex, $page.index)`) must stay in sync. If the loop cannot be made smooth with standard components, that is a parity gap and (per D-02) the whole task is skipped.
- **D-09: Reader gesture-under-zoom is FULL parity on all three** (success criterion #3, non-negotiable): (a) paging fully frozen while zoomed (`.scrollDisabled(scale != 1)`), (b) pan works while zoomed, (c) RTL-aware edge single-tap page-turn preserved.
- **D-10: Full-surface spike, then judge.** Build both replacements end-to-end across every behavior before rendering a go/no-go. Full parity surface enumerated below.
- **D-11: Spike-to-keep (Phase 2 / SR-1 style).** If parity is proven, the spike code **is** the implementation — committed and evolved into the real swap, not thrown away. Sign-off artifact is a **go/no-go checklist** covering every parity item, committed alongside; a genuine gap on any item triggers the D-02 skip and is documented.
- **D-12: Do not touch `DeviceUtil` itself.** The reader legitimately reads `DeviceUtil.isLandscape`, `DeviceUtil.windowW`, `DeviceUtil.absWindowW/H` (dual-page width, edge-tap zones, zoom offset clamps); de-globalizing those is Phase 5 (UIARCH-01). Keep using them unchanged this phase.
- **D-13: Dependency + acknowledgement cleanup is part of "removed."** Removing SwiftUIPager also deletes the `Package.swift` dependency + its `.targetDependency(.swiftUIPager)` entries (one is stale — verified below), the `AboutView` SwiftUIPager acknowledgement row, and the `acknowledgement.swiftUIPager` / `acknowledgement.swiftUIPager_link` xcstrings keys. Only performed if D-02's go decision holds.

### Claude's Discretion
- RTL implementation mechanism (`layoutDirection` environment flip vs reversed data source) — spike/planner picks whatever hits parity cleanest, defaulting to the `layoutDirection` flip.
- Whether the shared index is a bare `Int` binding or a thin `@Observable` wrapper (D-07) — planner decides on call-site churn.

### Deferred Ideas (OUT OF SCOPE)
- Reconciling the literal "page-style `TabView`" wording in ROADMAP.md / REQUIREMENTS.md (DEP-05) / PROJECT.md with the D-04 paging-`ScrollView` decision — a separate `/gsd-phase` edit if the owner wants the source docs updated. CONTEXT.md records the supersession authoritatively.
- De-globalizing `DeviceUtil` (`isLandscape`/`windowW`) — Phase 5 (UIARCH-01); the reader keeps reading them this phase (D-12).
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| DEP-05 | Replace SwiftUIPager with native page-style paging (paging `ScrollView` per D-04); reading paging parity — horizontal/RTL/dual-page, page-index mapping, gesture coexistence; SwiftUIPager removed; if native can't reach parity the spike surfaces it before commit. | Standard Stack (native scroll APIs, all iOS 17+/available on iOS 26 target); Architecture Patterns (reader ScrollView + shared-index source-of-truth; carousel viewAligned + tripled-buffer loop); Common Pitfalls (`.scrollPosition` programmatic-write fidelity, `.paging` landscape misalignment FB, feedback loops, rotation re-layout); Validation Architecture (PageHandler pure-mapping tests + D-10 go/no-go checklist). The "spike surfaces the gap" clause underwrites the D-02 skip path. |
</phase_requirements>

## Summary

This phase removes the `fermoya/SwiftUIPager` package (`from: 2.5.0`) and reproduces its behavior with stock SwiftUI scroll-paging at two call sites: the **reader** (`ReadingView.swift`, horizontal `Pager`) and the **Home carousel** (`HomeView+Sections.swift`, `CardSlideSection`). The iOS 26 deployment target makes the entire iOS 17/18 scroll surface available — `.scrollTargetBehavior(.paging/.viewAligned)`, `.scrollTargetLayout()`, `.scrollPosition(id:)`, `.containerRelativeFrame(_:)`, `.scrollTransition`, `.scrollClipDisabled()`, `.scrollDisabled(_:)` — so no third-party replacement is needed (D-01). The vertical reading path (`AdvancedList`) is *already* a native `ScrollView`/`LazyVStack`/`.scrollPosition` implementation coupled to SwiftUIPager only through the shared `Page` index; re-seaming it to a plain index is the smallest, lowest-risk part of the swap.

The make-or-break risks are two. **(1) The shared index as single source of truth.** Today one `Page` object drives horizontal paging, vertical list, autoplay `.next`, slider seek, tap-to-turn, and resume-seeding at construction. The replacement makes a plain `Int` the truth, with the reader's `.scrollPosition(id:)` binding both *reading* the scrolled page and *receiving* programmatic writes. The proven hazard is a feedback loop (a programmatic write re-fires the `.onChange` that fans out to the reducer) and off-by-one/glitch on the leading-item id when `.update`-equivalents jump the position. **(2) A smooth stock infinite carousel loop (D-08)** — SwiftUIPager's `.loopPages()` uses a rolling modulo window internally; the stock idiom is a tripled-data buffer with silent, animation-suppressed re-centering when the user reaches an edge copy. Both are known-hard-but-standard patterns; D-10 requires proving them end-to-end before the go/no-go.

**Primary recommendation:** Structure the phase as **Wave 0 pure-mapping tests → Wave 1 full-surface spike (both sites, committed) → go/no-go checklist → Wave 2 production finalize + dependency/acknowledgement cleanup**, mirroring Phase 2. Make `PageHandler.mapToPager`/`mapFromPager` the unit-tested pure core (it survives unchanged — only its *consumer* changes from `page.index` to the plain index), and gate autoplay/slider/tap on a spike-verified `.scrollPosition(id:)` programmatic-write behavior before trusting it. If either the reader's programmatic-jump fidelity or the carousel loop cannot be made smooth with stock components, invoke the D-02 skip and keep SwiftUIPager.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Horizontal page turning (reader) | SwiftUI view (`ReadingView`) | — | Pure client-side scroll/gesture; no reducer involvement in the swipe itself |
| Page-index source of truth | SwiftUI view state (`@Observable` index / `@State Int?`) | TCA reducer (progress sync) | Index is UI state; only *committed* progress crosses into the reducer via `.syncReadingProgress` |
| Stack↔reading-page index mapping | Pure value logic (`PageHandler`) | — | `mapToPager`/`mapFromPager` are pure functions; unit-testable, unchanged by the swap |
| Reading-progress persistence | TCA reducer (`ReadingReducer`) | `@Shared(.setting)` / stored progress | Durable state; reducer contract must be untouched (parity) |
| Zoom / pan / tap gestures | SwiftUI view (`GestureHandler`) | `DeviceUtil` (window metrics, D-12) | Client-side transform state; gates paging via `scale` |
| Autoplay timer | View-owned `@Observable` (`AutoPlayHandler`) | — | Timer fires a `@MainActor` closure that advances the index |
| Home carousel paging + loop + fade | SwiftUI view (`CardSlideSection`) | Parent Home view (`pageIndex` binding) | Client-side carousel; only the outward `pageIndex` binding is shared |
| Dependency / acknowledgement removal | Build config (`Package.swift`) + resources (`xcstrings`, `AboutView`) | — | Package-level + string-catalog edits, gated on D-02 go |

## Standard Stack

### Core (native SwiftUI — no packages added; iOS 26 target has all of these)
| API | Availability | Purpose | Why Standard |
|-----|--------------|---------|--------------|
| `ScrollView(.horizontal)` | iOS 13+ | Paging container base | The stock scroll primitive; D-04-mandated construct |
| `.scrollTargetBehavior(.paging)` | iOS 17+ | Viewport-width snap (reader) | Full-page snapping; replaces `Pager` swipe [CITED: developer.apple.com/documentation/swiftui/scrolltargetbehavior/paging] |
| `.scrollTargetBehavior(.viewAligned)` | iOS 17+ | Item-aligned snap (carousel peek) | Snaps to item leading edge; reproduces peek + `.pagingPriority(.high)` |
| `.scrollTargetLayout()` | iOS 17+ | Marks the lazy layout whose children are scroll targets | Required by `.viewAligned` and by `.scrollPosition(id:)` id-tracking |
| `.scrollPosition(id:)` | iOS 17+ | Two-way current-item binding | Reads scrolled page AND receives programmatic writes — the shared-index bus |
| `ScrollPosition` + `.scrollPosition(_:anchor:)` | iOS 18+ | Richer position (id/edge/offset), `scrollTo(id:)` | Optional upgrade over the iOS 17 id-only binding [CITED: nilcoalescing.com/blog/ModernSwiftUIAPIsForProgrammaticScrolling] |
| `.containerRelativeFrame(.horizontal)` | iOS 17+ | Size each page to viewport width, no `GeometryReader` | D-05-mandated; `count:1, span:1` = full viewport width [CITED: fatbobman.com/en/posts/mastering-swiftui-scrolling-implementing-custom-paging] |
| `.scrollDisabled(_:)` | iOS 16+ | Freeze paging while zoomed | `.scrollDisabled(scale != 1)` replaces `.allowsDragging(scale == 1)` (D-09a) |
| `.scrollTransition(_:)` | iOS 17+ | Per-item scroll-driven effect | Reproduces `.interactive(opacity: 0.2)` neighbor fade (D-06) |
| `.scrollClipDisabled()` | iOS 17+ | Let neighbor cards peek past the container bounds | Reproduces the peeking carousel edges (D-06) |
| `.onScrollPhaseChange` | iOS 18+ | React to idle/tracking/decelerating | Already used by `AdvancedList`; useful to gate feedback-loop guards |
| `.onScrollGeometryChange(for:of:)` | iOS 18+ | Continuous offset/geometry reads | Fallback for loop re-center detection if id-tracking is insufficient |
| `EnvironmentValues.layoutDirection` / `.environment(\.layoutDirection, .rightToLeft)` | iOS 13+ | RTL page order flip | Default RTL mechanism (Claude's discretion; D-04/CONTEXT default) |

### Supporting (already in the codebase — reused, re-seamed)
| Component | Purpose | When to Use |
|-----------|---------|-------------|
| `PageHandler` (`Support/PageHandler.swift`) | Pure stack-index ↔ reading-page mapping incl. dual-page cover math | Unchanged logic; only its caller switches from `page.index` to the plain index |
| `AdvancedList` (`Support/AdvancedList.swift`) | Native vertical reader (already `ScrollView`/`.scrollPosition`) | Re-seam its `Page` param to the shared index |
| `AutoPlayHandler` (`Support/AutoPlayHandler.swift`) | Timer-driven page advance | Swap its `updatePageAction` closure to advance the index instead of `page.update(.next)` |
| `GestureHandler` (`Support/GestureHandler.swift`) | `scale`/`offset`/`scaleAnchor` state | Unchanged; `scale` still gates paging (now via `.scrollDisabled`) |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Paging `ScrollView` (D-04) | `TabView(.page)` | **Rejected by D-04**: cannot freeze its own swipe under zoom; no clean two-way programmatic index; RTL awkward. Do not research/plan this. |
| `.scrollPosition(id:)` (iOS 17 id-binding) | iOS 18 `ScrollPosition` + `scrollTo(id:)` | The iOS 18 type is richer (edge/offset, explicit `scrollTo`); the id-only binding is simpler and sufficient for a plain-index bus. Spike may prefer `ScrollPosition` if programmatic-jump fidelity is better. [ASSUMED — decide in spike] |
| `layoutDirection` RTL flip | Reversed data source | Reversing data changes every index-mapping call site and fights `PageHandler`; the environment flip keeps the index space forward. Default to the flip (CONTEXT). |
| Tripled-buffer carousel loop | Very-large-N repeated buffer with mid-jump | Tripling is the minimal buffer that guarantees a full neighbor on each side; larger buffers delay but don't remove the re-center. Tripling is the standard. [ASSUMED] |

**Installation:** None. This phase **removes** a dependency; it adds no packages.

## Package Legitimacy Audit

> Not applicable in the additive sense — this phase installs **zero** new packages. The only package action is **removal** of `fermoya/SwiftUIPager`.

| Package | Registry | Action | Verdict | Disposition |
|---------|----------|--------|---------|-------------|
| `fermoya/SwiftUIPager` (`from: 2.5.0`) | SwiftPM (github.com/fermoya/SwiftUIPager) | REMOVE (gated on D-02 go) | n/a (removal) | Delete dependency decl + 3 target-dependency entries (1 stale) |

**Packages removed:** `SwiftUIPager` (only if D-02 go). **Packages added:** none. **Packages flagged suspicious:** none.

## Architecture Patterns

### System Architecture Diagram — Reader (single-index source of truth)

```
                    ┌─────────────────────────────────────────────┐
   resume seed ────▶│   Shared page index (plain Int / @Observable) │◀──── slider seek (setPageIndex)
   (init)           │   — single source of truth (replaces Page)   │◀──── autoplay .next (AutoPlayHandler timer)
                    └───────────────┬───────────────┬─────────────┘◀──── tap-to-turn (index ± offset, RTL-aware)
                                    │ (write)       │ (write)
              programmatic write    │               │
              via .scrollPosition   ▼               ▼
        ┌───────────────────────────────┐   ┌───────────────────────────┐
        │ Horizontal paging ScrollView  │   │ Vertical AdvancedList      │
        │ .scrollTargetBehavior(.paging)│   │ (native ScrollView already)│
        │ .scrollTargetLayout()         │   │ .scrollPosition(id:)       │
        │ .scrollPosition(id: $index+…) │   │ re-seamed to shared index  │
        │ .containerRelativeFrame(.horiz)│  └───────────────────────────┘
        │ .scrollDisabled(scale != 1)   │            (only one is shown, per readingDirection)
        └───────────────┬───────────────┘
         scroll-driven   │ (read → onChange)
         page change     ▼
        ┌───────────────────────────────┐        ┌──────────────────────────────┐
        │ PageHandler.mapFromPager       │───────▶│ store.send(.syncReadingProgress)│──▶ ReadingReducer
        │ (stack-index → reading-page,   │        │  (reducer contract UNCHANGED)  │    (persist progress)
        │  dual-page cover math)         │        └──────────────────────────────┘
        └───────────────────────────────┘
   ▲ mapToPager (reading-page → stack-index) used by resume-seed + slider-write paths ▲

  Gesture layer (GestureHandler): magnify → scale ; pan (scale>1) → offset ; tap → toggle panel OR edge page-turn
  scale > 1  ⇒  .scrollDisabled(true)  (paging frozen)  +  pan gesture active  ;  scale == 1  ⇒  paging live
```

### System Architecture Diagram — Home carousel (infinite loop)

```
   parent Home view  ◀── pageIndex binding (outward; today via .synchronize) ──▶  logical index
                                                                                       │
   galleries [G0 G1 … Gn]  ──tripled buffer──▶  [ …Gn | G0 G1 … Gn | G0… ]              │
                                                   (front copy)(real)(back copy)         │
                                                        │                                ▼
                              ┌─────────────────────────────────────────────────────────────┐
                              │ ScrollView(.horizontal)                                       │
                              │ .scrollTargetBehavior(.viewAligned) + .scrollTargetLayout()   │
                              │ .scrollPosition(id:) tracks current buffer id                 │
                              │ .scrollClipDisabled() (peek) ; item .containerRelativeFrame    │
                              │ .scrollTransition { … opacity 0.2 … } (interactive fade)       │
                              └───────────────────────────┬──────────────────────────────────┘
                                    user reaches an edge   │  (onScrollPhaseChange == .idle)
                                    copy                    ▼
                              silent re-center: set .scrollPosition to the equivalent id in the
                              real middle block WITHOUT animation → maps buffer id → logical index → pageIndex
```

### Pattern 1: Reader paging ScrollView over the stack data source
**What:** `ScrollView(.horizontal)` whose lazy row of pages is marked `.scrollTargetLayout()`, each page sized to the viewport with `.containerRelativeFrame(.horizontal)`, snapping with `.scrollTargetBehavior(.paging)`, its current item bound with `.scrollPosition(id:)`.
**When to use:** the non-vertical reading directions (`.leftToRight`, `.rightToLeft`) — replaces the `Pager(...)` block at `ReadingView.swift:143`.
**Key seam:** the data source is `store.state.containerDataSource(setting:isLandscape:)` (a `[Int]` of stack indices, already collapsing dual-page stacks). The ScrollView pages over the **same** `[Int]`; only the index binding changes. The leading-item id is the stack index — the `.scrollPosition(id:)` binding must be in the same id space that `PageHandler.mapToPager` produces (a stack index, 0-based today via `page.index`).
```swift
// Illustrative (spike to verify exact id/anchor behavior). Source: composed from
// D-05 + fatbobman paging article + Apple scrollTargetBehavior docs.
ScrollView(.horizontal) {
    LazyHStack(spacing: 0) {
        ForEach(dataSource, id: \.self) { stackIndex in
            imageStack(index: stackIndex)
                .containerRelativeFrame(.horizontal)   // one page == viewport width, no GeometryReader
        }
    }
    .scrollTargetLayout()
}
.scrollTargetBehavior(.paging)
.scrollPosition(id: $currentStackID)                    // two-way: reads scrolled page, accepts writes
.scrollDisabled(gestureHandler.scale != 1)              // D-09a: freeze paging under zoom
.environment(\.layoutDirection,
             store.setting.readingDirection == .rightToLeft ? .rightToLeft : .leftToRight) // RTL default
```

### Pattern 2: Programmatic jump = write the bound id (autoplay / slider / tap / resume)
**What:** every writer (autoplay `.next`, slider `setPageIndex`, tap `index ± offset`, resume seed) sets the same bound id instead of calling `page.update(...)`.
**Critical:** guard against the feedback loop. When a programmatic write lands, `.scrollPosition(id:)` reports the new id and re-fires the read `.onChange`, which currently calls `mapFromPager` → `store.send(.syncReadingProgress)`. Reproduce today's `AdvancedList` guard (a `performingChanges` flag + a short debounce, `AdvancedList.swift:42-49`) so a programmatic set does not round-trip into a redundant progress send or fight the scroll animation.
```swift
// Guard idiom already in the codebase (AdvancedList.onScrollPhaseChange). Reuse it.
func jump(toStackID id: Int) {
    guard currentStackID != id else { return }
    performingChanges = true
    withAnimation(.none) { currentStackID = id }   // spike: verify .paging honors the write w/o glitch
    // re-arm after settle (mirror AdvancedList's 0.2s), or key off onScrollPhaseChange == .idle
}
```

### Pattern 3: Vertical path re-seam (lowest risk)
**What:** `AdvancedList` already tracks `scrollPositionID` and calls `pagerModel.update(.new(index:))` / reads `pagerModel.index`. Replace the `Page` param with the shared index binding; the `+1`/`-1` id offset (list ids are 1-based reading pages, `scrollPositionID = pagerModel.index + 1`) is preserved.
**When to use:** `readingDirection == .vertical` branch (`ReadingView.swift:129`). De-risks the vertical direction outright since the native scroll machinery is unchanged.

### Pattern 4: Home carousel — viewAligned peek + scrollTransition fade + tripled-buffer loop
**What:** `ScrollView(.horizontal)` + `.scrollTargetBehavior(.viewAligned)` + `.scrollTargetLayout()`; each card sized to `Defaults.FrameSize.cardCellSize` with 20pt spacing; `.scrollClipDisabled()` for peek; `.scrollTransition` mapping the non-identity phase to `opacity 0.2`.
```swift
// Reproduces .interactive(opacity: 0.2). Source: Apple scrollTransition docs + D-06.
card.scrollTransition { content, phase in
    content.opacity(phase.isIdentity ? 1.0 : 0.2)
}
```
**Infinite loop (D-08, MANDATORY):** build a tripled buffer `[galleries] + [galleries] + [galleries]` with stable, block-distinct ids; start centered in the middle block; on `.onScrollPhaseChange == .idle`, if the current id is in the front or back copy, silently set `.scrollPosition` to the equivalent id in the middle block **without animation** (transaction-suppressed, like Phase 2's D-31). Map the buffer id back to the logical `galleries` index to keep the outward `pageIndex` binding in sync (the `.synchronize` equivalent). The spike must prove the re-center is invisible (no flash, no stutter) at rest — this is the single most likely D-02 gap.

### Anti-Patterns to Avoid
- **`GeometryReader` for page sizing.** Banned by PROJECT.md + D-05; use `.containerRelativeFrame(.horizontal)`. (Phase 5/UIARCH-01 continues this direction.)
- **Reversing the data source for RTL.** Fights `PageHandler` and every index-mapping call site; prefer the `layoutDirection` flip (default).
- **Unguarded two-way binding.** Letting the scroll-read `.onChange` and the programmatic writer both drive the reducer without a `performingChanges`/idle guard creates the feedback loop; reproduce the existing guard.
- **Animating the loop re-center.** A visible animation on the silent re-center defeats the illusion; suppress the transaction (Phase 2 D-31 idiom).
- **Introducing a new module for this work.** Both call sites live in existing modules (`ReadingFeature`, `HomeFeature`); no new module → the AGENTS.md "new module needs `.swiftlint.yml`" rule does not trigger.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Page snapping | Custom drag-threshold + velocity math | `.scrollTargetBehavior(.paging)` | Apple handles velocity/rubber-banding; hand-rolled snap regresses feel [CITED: Apple docs] |
| Viewport-width pages | `GeometryReader` width capture | `.containerRelativeFrame(.horizontal)` | Banned by project; the modifier is exact and non-greedy |
| Current-page tracking | Manual offset ÷ width | `.scrollPosition(id:)` / `ScrollPosition.viewID(type:)` | The stock two-way binding is the intended mechanism |
| Neighbor peek clipping | Custom padding/frame hacks | `.scrollClipDisabled()` | One modifier vs fragile geometry |
| Opacity fade on scroll | `onScrollGeometryChange` + manual opacity | `.scrollTransition` | Purpose-built, GPU-driven, phase-aware |
| Stack-index ↔ reading-page mapping | New mapping code | Existing `PageHandler` (unchanged) | Already correct incl. dual-page cover math; just unit-test it |

**Key insight:** The stock iOS 17/18 scroll API surface was designed to replace exactly this class of third-party pager. The only genuinely custom code the phase writes is (a) the shared-index bus + feedback guard, and (b) the tripled-buffer loop re-center — and both have established idioms. Everything else is a modifier swap.

## Runtime State Inventory

> This is a dependency-removal / refactor phase. A grep finds files; it does not find build state or catalog state. All five categories answered explicitly.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | **None** — reading progress persists via the `ReadingReducer` / stored `readingProgress` (an `Int` reading-page), which is decoupled from the pager mechanism. The swap changes the *view* index bus, not the persisted value or its schema. Verified: `syncReadingProgress`/`flushReadingProgress` in `ReadingReducer.swift` operate on reading-page ints, unaffected. | None (parity: reducer contract untouched) |
| Live service config | **None** — no external service embeds "SwiftUIPager"; it is a compile-time UI library only. | None |
| OS-registered state | **None** — no Task Scheduler / launchd / background-task identifier references the pager. | None |
| Secrets/env vars | **None** — no secret or env var references SwiftUIPager or the pager index. | None |
| Build artifacts / installed packages | `AppPackage/.build/checkouts/SwiftUIPager/` and `AppPackage/Package.resolved` pin `fermoya/SwiftUIPager`. After removing the dependency, `Package.resolved` must be **regenerated** (Phase 2 precedent: `swift package resolve` regenerates `Package.resolved` + `originHash`; note MEMORY: swiftlint binary/`.build` handling). The `.build/checkouts` copy is stale-but-harmless until resolve. | Regenerate `Package.resolved`; verify `SwiftUIPager` no longer appears |

**The canonical question — after every source file is updated, what still references SwiftUIPager?** (1) `Package.swift`: the dependency decl (line 21) + **3** `.targetDependency(.swiftUIPager)` entries — appFeature (line 299, **STALE**: AppFeature does not `import SwiftUIPager`), homeFeature (line 718, real), readingFeature (line 780, real); plus the `swiftUIPager` static on line 47. (2) `Package.resolved` pin. (3) `AboutView.swift:162-163` acknowledgement row. (4) `Constant.xcstrings` keys `acknowledgement.swiftUIPager` (line 508) + `acknowledgement.swiftUIPager_link` (line 550), each carrying en/de/ja/ko/zh-Hans/zh-Hant localizations (the value is the proper-noun "SwiftUIPager"/URL, `shouldTranslate:false`). All must go on a D-02 go.

## Common Pitfalls

### Pitfall 1: Programmatic `.scrollPosition(id:)` write doesn't land exactly on the target page
**What goes wrong:** under `.scrollTargetBehavior(.paging)`, a programmatic id write can land between pages, off-by-one, or not fire at all — breaking autoplay/slider/tap (the central risk, D-10, and CONTEXT §Specifics).
**Why it happens:** the id space of `.scrollPosition(id:)` is the *leading item* of each scroll target; `.paging` snaps by viewport, and the two must agree. On iOS 18, the `ScrollPosition` `edge/point/x/y` properties become nil the instant the user interacts, and only reflect *programmatic* sets — so reading position needs `viewID(type:)`, while writing needs the id/`scrollTo(id:)` path. Mixing the two spaces yields glitches.
**How to avoid:** in the spike, log the real landed id after each programmatic write (CONTEXT §Specifics explicitly asks for this) before trusting it for autoplay/slider. Prefer the iOS 18 `ScrollPosition` + `scrollTo(id:)` if the id-only binding proves flaky. Keep every page sized to exactly the viewport (`.containerRelativeFrame(.horizontal)`) so page id and paging snap coincide.
**Warning signs:** autoplay drifts by one over many pages; slider seek lands on the neighbor; tap-to-turn double-jumps.

### Pitfall 2: Feedback loop between scroll-read and programmatic-write
**What goes wrong:** a programmatic write updates the bound id → `.onChange(of: id)` fires → maps + sends `.syncReadingProgress` → any downstream that re-seeds the index re-writes it → loop / redundant reducer traffic / fighting the animation.
**Why it happens:** the same binding is both input and output; today `Page` + the `.onChange(of: page.index)` handler (`ReadingView.swift:208`) plus `AdvancedList`'s `performingChanges` guard manage this.
**How to avoid:** reuse the existing `performingChanges` flag + short settle (`AdvancedList.swift:42-49`), or gate the read handler on `onScrollPhaseChange == .idle` so only user-driven settles send progress; programmatic writes set a "suppress next read" guard.
**Warning signs:** progress spam in logs; janky snap-back after slider release; the "showsSliderPreview" gate misbehaving.

### Pitfall 3: `.scrollTargetBehavior(.paging)` landscape misalignment
**What goes wrong:** the default `.paging` behavior has a **reported** misalignment in landscape (fails to snap to the correct page) — Apple FB16486510. The reader's **dual-page landscape** mode is exactly this scenario.
**Why it happens:** page-width vs container-width rounding under certain landscape geometries.
**How to avoid:** verify dual-page landscape paging explicitly in the spike; if `.paging` misaligns, the fallback is `.viewAligned(limitBehavior: .alwaysByOne)` over full-width targets (note: `alwaysByOne` does not strictly guarantee one-view-at-a-time — spike-verify). Treat landscape dual-page as a first-class go/no-go checklist item.
**Warning signs:** in landscape dual-page, swipes land half-way or skip a stack.
[CITED: fatbobman.com/en/posts/mastering-swiftui-scrolling-implementing-custom-paging]

### Pitfall 4: Rotation does not re-invoke the scroll target behavior
**What goes wrong:** on device rotation, SwiftUI does not automatically re-run `updateTarget` for `ScrollTargetBehavior`, so page sizing/snap can be wrong after a rotate.
**Why it happens:** documented SwiftUI behavior; the container relayout doesn't re-drive the target math.
**How to avoid:** rebuild the ScrollView on the size/orientation change — the reader already has `.id(store.forceRefreshID)` on the paging container (`ReadingView.swift:166`) and reads `DeviceUtil.isLandscape`; ensure the paging ScrollView is inside that identity so a rotate rebuilds it. (Do not add a *new* orientation global — reuse the existing signal; D-12.)
**Warning signs:** correct pages before rotation, off-by-one or mis-sized after.
[CITED: fatbobman.com/en/posts/mastering-swiftui-scrolling-implementing-custom-paging]

### Pitfall 5: Visible carousel re-center (D-08 gap)
**What goes wrong:** the tripled-buffer loop's silent re-center flashes or stutters, breaking the "infinite" illusion → a D-02 parity gap → whole task skipped.
**Why it happens:** re-centering while the scroll is settling, or with an animated transaction, is visible.
**How to avoid:** re-center only at `.onScrollPhaseChange == .idle`, with the write in a suppressed transaction (Phase 2 D-31 `.animation(nil, …)` idiom); ensure buffer ids are block-distinct so the position math is exact. Prove invisibility in the spike before the go decision.
**Warning signs:** a perceptible jump when wrapping past the last card to the first.

### Pitfall 6: RTL + `.scrollPosition(id:)` interaction
**What goes wrong:** under `.environment(\.layoutDirection, .rightToLeft)`, the leading edge flips; the `.scrollPosition(id:)` id may track the visually-leading vs logically-first item inconsistently, breaking RTL index mapping.
**Why it happens:** id anchoring is relative to layout direction; the index space must stay logical (forward) while the visual order flips.
**How to avoid:** keep the data source forward and let only `layoutDirection` flip the visual order (the CONTEXT default); verify in the spike that programmatic id writes still land on the logically-correct page under RTL. `PageHandler` stays in logical page space — do not RTL-adjust inside it.
**Warning signs:** RTL reader jumps to the wrong end on seek; tap-to-turn direction inverted (note `GestureHandler.onSingleTapGestureEnded` already inverts offsets for RTL — keep that logic).

## Code Examples

### Reproduce `.interactive(opacity: 0.2)` (carousel neighbor fade)
```swift
// Source: Apple scrollTransition docs + D-06. Non-identity (off-center) phase dims to 0.2.
GalleryCardCell(/* … */)
    .scrollTransition { content, phase in
        content.opacity(phase.isIdentity ? 1.0 : 0.2)
    }
```

### Freeze paging under zoom (`.allowsDragging(scale == 1)` → `.scrollDisabled`)
```swift
// Source: D-09a. Paging frozen while zoomed; pan gesture (scale>1) stays active on the content.
pagingScrollView
    .scrollDisabled(gestureHandler.scale != 1)
```

### Autoplay advance onto the shared index (replaces `page.update(.next)`)
```swift
// Source: AutoPlayHandler.setPolicy(updatePageAction:) — swap the closure body.
func setAutoPlayPolicy(_ policy: AutoPlayPolicy) {
    autoPlayHandler.setPolicy(policy, updatePageAction: {
        // advance the shared index (wrap or clamp per parity with Page's isInfinite=false clamp)
        jump(toStackID: nextStackID(after: currentStackID))
    })
}
```

### PageHandler stays pure — unit-test it directly (no `Page`)
```swift
// mapToPager / mapFromPager are already pure (PageHandler.swift). The swap does NOT change them;
// it changes who calls them. New Swift Testing suite exercises them against the plain index.
let h = PageHandler()
#expect(h.mapToPager(index: 1, setting: dualPageExceptCover, isLandscape: true) == 0)
#expect(h.mapFromPager(index: 0, pageCount: n, setting: dualPageExceptCover, isLandscape: true) == 1)
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `fermoya/SwiftUIPager` (`Page` ObservableObject + `.horizontal`/`.loopPages`/`.interactive`) | Stock `ScrollView` + `.scrollTargetBehavior` + `.scrollPosition(id:)` + `.scrollTransition` | iOS 17 (2023), extended iOS 18 (2024) | Removes a third-party dep; native APIs are the intended replacement |
| `TabView(.page)` for paging | Paging `ScrollView` | iOS 17+ | `TabView(.page)` can't freeze its own swipe or give a clean two-way index — hence D-04 |
| `ScrollViewReader` proxy for programmatic scroll | `.scrollPosition(id:)` (iOS 17) / `ScrollPosition` `scrollTo(id:)` (iOS 18) | iOS 17/18 | Single state var instead of a proxy; `AdvancedList` already uses the newer path |
| `GeometryReader` width capture | `.containerRelativeFrame(_:)` | iOS 17+ | Non-greedy, exact viewport sizing; project-mandated |

**Deprecated/outdated for this phase:**
- `SwiftUIPager` — being removed (DEP-05); no replacement package (D-01).
- Page-style `TabView` as the mechanism — explicitly rejected (D-04). Do not plan it.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The iOS 18 `ScrollPosition` + `scrollTo(id:)` may be needed if the iOS 17 id-only binding proves flaky for programmatic jumps | Standard Stack / Pitfall 1 | Low — spike picks the working one; both are stock |
| A2 | Tripling the data buffer (3×) is the minimal sufficient buffer for the loop re-center | Pattern 4 | Low — larger buffers only delay re-center; correctness unaffected |
| A3 | `.paging` landscape misalignment (FB16486510) may affect dual-page landscape; `.viewAligned(.alwaysByOne)` is the fallback | Pitfall 3 | Medium — if both misalign in dual-page landscape, that is a real D-02 gap; spike must test explicitly |
| A4 | Reusing `store.forceRefreshID` identity is enough to force a rotation rebuild of the paging ScrollView | Pitfall 4 | Low-Medium — spike verifies; if not, a size-class `.id()` is the documented fix |
| A5 | The `.scrollPosition(id:)` id space aligns with the stack-index space that `PageHandler.mapToPager` returns (currently 0-based via `page.index`) | Pattern 1/2 | Medium — an id/anchor mismatch is the off-by-one hazard; spike logs real landed ids |
| A6 | No new module is added, so AGENTS.md's per-module `.swiftlint.yml` rule does not trigger | Anti-Patterns | Low — both call sites are in existing modules |

**All A1–A6 are spike-resolvable** — the full-surface spike (D-10) is precisely the mechanism to convert these from ASSUMED to VERIFIED before the go/no-go.

## Open Questions

1. **Does a programmatic `.scrollPosition(id:)` write land exactly on the target page under `.paging`?** (THE central proof, D-10/§Specifics.)
   - What we know: the binding is two-way; iOS 18 `ScrollPosition` adds `scrollTo(id:)`; pages sized to viewport should make id≡snap.
   - What's unclear: exact landed-id fidelity for autoplay/slider/tap, especially RTL + dual-page landscape.
   - Recommendation: spike logs the landed id after every programmatic write before wiring autoplay/slider/tap; choose id-binding vs `ScrollPosition` accordingly.

2. **Can the tripled-buffer carousel loop re-center invisibly with stock components?** (D-08 MANDATORY.)
   - What we know: idle-phase + suppressed-transaction re-center is the standard idiom (Phase 2 D-31 for suppression).
   - What's unclear: whether stock `.viewAligned` re-centering is truly flash-free at rest.
   - Recommendation: this is the single most likely D-02 gap — prove it early in the spike; if it stutters, exhaust D-03 options before declaring the gap.

3. **Should the shared index be a bare `Int?` binding or a thin `@Observable` wrapper?** (Claude's discretion, D-07.)
   - What we know: five writers/readers touch it; the wrapper could mirror `.update(.next)`/`.update(.new(index:))` to reduce churn.
   - Recommendation: planner decides on measured call-site churn; default to the bare index unless the wrapper demonstrably shrinks the diff.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode toolchain (build/test) | All Swift build/test (bare `swift build` fails — MEMORY: EhPanda build/test commands) | ✓ (assumed) | Swift 6.3.1 / iOS 26 SDK | — |
| iOS 26 Simulator (spike parity verification) | Spike run of reader + carousel across devices/orientations | ✓ (assumed) | iOS 26 | — |
| SwiftPM `swift package resolve` | Regenerate `Package.resolved` after dependency removal | ✓ | bundled | — |
| SwiftLint plugin | Build-tool lint (as-error) | ✓ (in Package.swift) | 0.63.0+ | standalone binary (MEMORY: ehpanda-standalone-swiftlint) |

**Missing dependencies with no fallback:** none identified (all standard Apple/SwiftPM toolchain, already in use for Phases 1–2).
**Note:** No new external tools/services required — this phase removes a dependency and uses only OS-native SwiftUI APIs.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Test`/`@Suite`, `#expect`) — MEMORY: EhPanda build/test commands |
| Config file | none (SwiftPM test targets in `AppPackage/Package.swift`) |
| Quick run command | Xcode test of the affected target's suite (Xcode-only; bare `swift test` fails) |
| Full suite command | `AppPackage-Package` scheme test via `xcodebuild` (one invocation at a time — MEMORY: no-overlapping-xcodebuild-test) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| DEP-05 | `PageHandler.mapToPager`/`mapFromPager` correct for single-page, dual-page, exceptCover cover-exception, and boundary (`result+1==pageCount`) cases | unit | Xcode test `PageHandlerTests` (new) | ❌ Wave 0 |
| DEP-05 | `mapToPager` ↔ `mapFromPager` round-trip identity in each mode | unit | same suite, table-driven | ❌ Wave 0 |
| DEP-05 | RTL index mapping stays logical (data forward, layoutDirection flipped) — mapping unaffected by direction | unit | same suite (mapping is direction-agnostic today — assert it) | ❌ Wave 0 |
| DEP-05 | `containerDataSource` stack collapsing (dual-page / exceptCover strides) matches expected `[Int]` | unit | `ReadingReducer`-level test (state func is pure) | ❌ Wave 0 (no dedicated PageHandler/dataSource test today; existing reading tests are reducer-level in `DownloadsFeatureTests`) |
| DEP-05 | Reducer contract unchanged — `syncReadingProgress` still fires with the correct reading-page after a scroll | integration | TCA `TestStore` (reuse existing reading reducer test scaffolding) | partial (reducer tests exist) |
| DEP-05 (parity) | Horizontal, RTL, dual-page-landscape, autoplay, slider seek, resume-seed, zoom/pan/tap coexistence, carousel peek/opacity/spacing/loop/`pageIndex`-sync | **manual / owner sign-off** | D-11 go/no-go checklist on device+simulator | ❌ produced by spike |
| DEP-05 | SwiftUIPager fully removed (no import, no Package entry, resolved regenerated, acknowledgement + xcstrings gone) | build gate + grep | clean build under SwiftLint-as-error + `grep -r SwiftUIPager` returns only historical docs | ❌ Wave 2 |

### Automatable vs manual
- **Automatable (Swift Testing / TestStore):** all `PageHandler` pure mapping (dual-page/cover/RTL/boundary), `containerDataSource` stack math, round-trip identity, and the reducer progress-sync contract. These are the real regression guards and satisfy CONTEXT §Specifics (add a dedicated `PageHandler` suite — none exists today).
- **Manual / owner sign-off (D-11 go/no-go checklist):** the *feel* parity items that cannot be asserted headlessly — programmatic-jump smoothness, `.scrollPosition` landed-id fidelity, carousel loop invisibility, gesture coexistence under zoom, RTL/dual-page-landscape snapping. The spike must log the real `.scrollPosition` landed id on programmatic jumps (evidence, not vibes) and enumerate each parity item with a pass/gap mark for owner sign-off. A gap on any item ⇒ D-02 skip, documented.

### Sampling Rate
- **Per task commit:** run the affected suite (`PageHandlerTests` / reading reducer tests) — must be green.
- **Per wave merge:** full `AppPackage-Package` suite green + clean build under SwiftLint-as-error.
- **Phase gate:** full suite green **and** the D-11 go/no-go checklist signed off (all parity items pass) **before** the dependency-removal wave and before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift` — dedicated pure-mapping suite (dual-page/cover/RTL/boundary/round-trip). Note: **no `ReadingFeatureTests` target exists today** — the planner must add the test target to `Package.swift` (with a `parent_config` `.swiftlint.yml` if a new module dir is created; a test target under `AppPackage/Tests` follows the same lint plumbing as existing test targets).
- [ ] `containerDataSource` stack-math coverage — can live in the same new suite (the state func is pure and callable).
- [ ] The D-11 go/no-go checklist artifact (committed markdown alongside the spike, Phase 2 SR-1 style) enumerating every D-10 parity item.
- [ ] Framework install: none — Swift Testing is already in use.

## Security Domain

> `security_enforcement: true` in config. This phase is a **UI mechanism swap** (paging construct) with no auth, crypto, network, persistence-schema, or user-input-parsing surface.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Untouched — no auth code in scope |
| V3 Session Management | no | Untouched |
| V4 Access Control | no | Untouched |
| V5 Input Validation | no | No new user-text/network input; page indices are internal ints, already clamped by reducer/model |
| V6 Cryptography | no | None |
| V7 Error Handling / Logging | marginal | Keep new logging at existing privacy levels; do not log content. No secrets in the paging path. |

### Known Threat Patterns for this stack
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Index out-of-bounds on programmatic jump / subscript | Denial of Service (crash) | Clamp writes to `dataSource.indices`; `containerDataSource` already guards `indices.contains`; keep the guard (also aligns with the future `unchecked_subscript_index_access` lint rule — LINT-01) |
| Privacy: reading content leaking via blur/lifecycle | Information Disclosure | Out of scope here (root privacy mask is Phase 7/UIARCH-04); do not regress the existing `.autoBlur(radius:)` sheets |

**Net:** no security-relevant attack surface added; the only correctness/safety concern is bounds-safe index writes, covered by the pure-mapping tests and existing `indices.contains` guards.

## Project Constraints (from CLAUDE.md / AGENTS.md)

- **Reducer naming:** `Feature` suffix (`ReadingReducer` is an existing name — do not rename; new reducers, if any, use `…Feature`). No new reducer is expected this phase.
- **SwiftLint coverage for new modules:** if the planner adds a new test module/dir, add a `.swiftlint.yml` with `parent_config: ../../../.swiftlint.yml` (path per depth). A new test *target* under `AppPackage/Tests` inherits the existing plugin plumbing.
- **Read `.swiftlint.yml` before writing Swift:** active rules relevant here — `force_unwrapping`/`force_try` (error), `system_name_image_parameter` (use `systemSymbol`), `no_unchecked_sendable`/`no_preconcurrency`/`no_nslock` (banned), `line_length`/`file_length` 120/1000. The commented-out rules (`optional_try`, `binding_initializer`, `lifecycle_modifiers`, `single_line_trailing_closure`, `unchecked_subscript_index_access`) are **not yet active** (LINT-01 is Phase 11) — but write to their spirit to avoid rework (esp. bounds-checked subscripts, projected bindings). **Never suppress/disable a rule without explicit user permission.**
- **Labeled localized-format args:** if any new xcstrings numeric-format keys are added (unlikely — this phase removes keys), follow the labeled-substitution rule. Removing `acknowledgement.swiftUIPager*` keys: they are `shouldTranslate:false` proper-noun/URL entries with all-locale copies — delete the whole key entries cleanly.
- **Confirmation dialog / alert placement:** no new dialogs expected; if any, attach to a stable action-source control.
- **Local project reference privacy:** ABSOLUTE — never record any consulted local project's name in any artifact. (Not triggered here; all references are the codebase itself + public Apple/community docs.)
- **No absolute home paths in generated docs:** this file uses only repo-relative and `AppPackage/.build/...` paths — compliant.
- **App-shell + AppPackage layout:** both call sites are in `AppPackage/Sources/{ReadingFeature,HomeFeature}`; deps in `AppPackage/Package.swift`. The stale AppFeature target-dependency entry (line 299) is in the app-shell's `AppFeature` target and can be removed (AppFeature doesn't import SwiftUIPager).

## Sources

### Primary (HIGH confidence — read directly this session)
- Codebase: `ReadingView.swift`, `ReadingView+Gestures.swift`, `Support/{PageHandler,AdvancedList,AutoPlayHandler,GestureHandler}.swift`, `ReadingReducer.swift` (containerDataSource/imageContainerConfigs), `HomeView+Sections.swift` (CardSlideSection), `Package.swift`, `AboutView.swift`, `Constant.xcstrings`, `.swiftlint.yml` — the authoritative behavior baseline and cleanup targets.
- `AppPackage/.build/checkouts/SwiftUIPager/**` — `Page.swift` (index clamp vs infinite modulo-wrap), `PagerContent+Helper.swift` (rolling loop window), `Pager+Buildable.swift`/`loopPages` — the semantics being reproduced.
- CONTEXT.md (D-01..D-13), REQUIREMENTS.md (DEP-05), ROADMAP.md, PROJECT.md, Phase 2 `02-CONTEXT.md` (spike-to-keep precedent, D-31 animation suppression, D-36 scroll-geometry pagination).

### Secondary (MEDIUM confidence — official/community docs, verified against the target)
- [CITED: developer.apple.com/documentation/swiftui/scrolltargetbehavior] and `.../paging` — paging behavior.
- [CITED: nilcoalescing.com/blog/ModernSwiftUIAPIsForProgrammaticScrolling] — iOS 17 `.scrollPosition(id:)` vs iOS 18 `ScrollPosition`/`scrollTo(id:)`/`viewID(type:)`; programmatic props nil on user interaction.
- [CITED: fatbobman.com/en/posts/mastering-swiftui-scrolling-implementing-custom-paging] — `.paging` landscape misalignment (FB16486510), `.viewAligned(.alwaysByOne)` caveat, `.containerRelativeFrame(.horizontal, count:1, span:1)`, rotation not re-invoking `updateTarget` (`.id(sizeClass)` fix).

### Tertiary (LOW confidence — training knowledge, marked ASSUMED)
- The tripled-buffer + idle-phase-suppressed re-center as the standard stock infinite-loop idiom (A2); iOS-18-`ScrollPosition`-if-flaky (A1). Both spike-resolvable.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all APIs are stock, available on iOS 26, and the call-site semantics are read directly from source.
- Architecture / cleanup targets: HIGH — exact file/line references verified (stale target-dep entry, xcstrings keys, AboutView row).
- The two make-or-break behaviors (programmatic `.scrollPosition` fidelity under `.paging`; smooth stock loop re-center): MEDIUM — standard idioms exist but a known landscape FB and the loop invisibility are exactly what D-10's spike must prove; a genuine gap triggers the D-02 skip.

**Research date:** 2026-07-11
**Valid until:** ~2026-08-10 (stable Apple APIs; re-check the `.paging` landscape FB status if the spike hits it).
