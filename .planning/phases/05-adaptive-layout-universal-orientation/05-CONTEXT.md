# Phase 5: Adaptive Layout & Universal Orientation - Context

**Gathered:** 2026-07-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Let **size classes and the OS govern layout and rotation** — retiring EhPanda's
screen-metric math, the `TouchHandler` global, and the custom orientation lock — at
**reading and rotation parity**. Delivers **UIARCH-01** (modernize adaptive layout;
remove screen-dependent logic across `DeviceUtil` **and** `DeviceClient`; retire
`TouchHandler`; avoid `GeometryReader`; `Defaults.FrameSize`/`ImageSize` no longer derive
size from a global; reading zoom/pan/tap parity) and **UIARCH-03** (universal device
orientation on every page; remove the custom orientation lock so the OS governs).

**What this phase is NOT:**
- Not the root-privacy-mask / auto-lock removal (UIARCH-04/05 — **Phase 7**).
- Not `GenericList` decomposition (UIARCH-02 — **Phase 6**). The masonry `Layout` is used
  as-is; only its landscape-phone column policy is *ratified* here (see D-08).
- Not a full de-globalization of the AppTools Utils (HYG-01 — **Phase 8**). This phase
  pulls **only the Device slice** of HYG-01 forward (see D-01); Haptics / UserDefaults /
  File / Cookie / `URLUtil` / `AppUtil` / `DataCache.shared` stay in Phase 8.
- Not a visual redesign — mechanism swaps at behavior/appearance parity.

**Scouted scope reality (grounds the plan):**
- `DeviceUtil` (`AppPackage/Sources/AppTools/DeviceUtil.swift`) is read by **~25 files**.
  Reads fall into two buckets: **layout-metric** (`windowW`/`absWindowW`/`windowH`/`screen*`,
  `isPadWidth`, `isSEWidth`) and **idiom** (`isPad`/`isPhone`). Also non-layout window access:
  `keyWindow`/`anyWindow` for side-effects.
- **No reducer reads window size.** The 6 reducers that inject `deviceClient`
  (AppReducer, Favorites/Home/Search/Downloads reducers, ReadingReducer) only use
  `deviceClient.isPad` — for the iPad push-vs-present navigation idiom
  (`DetailFeature/GalleryNavigation.swift`, `AppReducer`). So `DeviceClient.absWindowW`,
  `absWindowH`, and `touchPoint` are **dead** (no consumers) and are removed; the client
  collapses to a single `deviceType()` fact.
- `App/Info.plist` **already declares all 4 orientations** (iPhone + iPad). The portrait
  lock lives entirely in `AppOrientationMask.current` + the `AppDelegate`
  `supportedInterfaceOrientationsFor` callback — removing them makes rotation universal with
  **no Info.plist change**.
- `TouchHandler.shared.currentPoint` feeds `GestureHandler` tap-location / anchor math;
  `DeviceClient.touchPoint` and `RootView.addTouchHandler` are its only other touchpoints and
  are removed with it.

</domain>

<decisions>
## Implementation Decisions

### Area 1 — DeviceUtil removal (owner-decided 2026-07-13)
- **D-01:** **`DeviceUtil` (the `AppTools` static global) is deleted this phase.**
  `DeviceClient` becomes the injected home for the residual device facts, accessed **only**
  through `@Dependency(\.deviceClient)` — **no** `DeviceClient.live`/`.liveValue`/static-method
  usage in consumers. This tightens UIARCH-01's own "remove screen-dependent logic across
  `DeviceUtil` **and** `DeviceClient`" wording and pulls the **Device slice of HYG-01**
  forward; the rest of HYG-01 stays in Phase 8.
- **D-02:** **Layout-metric reads are REPLACED by native adaptive SwiftUI**
  (`containerRelativeFrame` / `horizontalSizeClass` / `onGeometryChange` / `ViewThatFits`) —
  **not** routed through DeviceClient. Routing window-size getters through the client would just
  hide the anti-pattern behind a dependency and violate UIARCH-01 acceptance #1
  ("no view reads window/screen for layout"). Confirmed by the scout: no reducer needs window
  size, so nothing metric has to live on the client.
- **D-03:** The `isPad`/`isPhone` idiom is replaced by the owner-provided **`DeviceType` enum**
  (`unspecified/phone/pad/watch/tv/carPlay/mac/vision`, with a `@MainActor static var current`
  from `UIDevice.current.userInterfaceIdiom`; full source in `<specifics>`). Idiom branches keep
  **device-class semantics** (parity-preserving — *not* converted to size-class) but read
  `deviceClient.deviceType()` via `@Dependency`. `DeviceType.current` is called **only** inside
  `DeviceClient.live`. Reducers switch `deviceClient.isPad` → `deviceType() == .pad`. This
  supersedes the earlier native-lean-vs-parity-lock framing: **only metric reads go native;
  idiom branches stay device-class via the enum.**

### Area 2 — Reader geometry & landscape source (owner-decided 2026-07-13)
- **D-04:** After the lock is gone, the reader decides "landscape" (dual-page eligibility) from
  the **container aspect ratio — width > height** of its captured geometry. Most faithful to
  intent (dual-page wants "reading area wider than tall"), preserves parity (portrait iPad =
  single, landscape iPad = dual), correctly enables dual-page on now-rotatable **landscape
  phones**, and holds under Stage Manager / split view where orientation ≠ container shape.
- **D-05:** **Single source of truth.** One `onGeometryChange` at the reader container writes its
  size into the shared `@Observable` reader model (Phase 3's `PageModel` or a sibling). The
  `GestureHandler` zoom-margin / pan-clamp / scale-anchor / tap-edge-zone math, the dual-page
  half-width, and the D-04 landscape flag all read that **one** size. Tap location comes from
  **`SpatialTapGesture.location`** (same coordinate space, so `point / absWindowW` normalization
  becomes container-relative); pinch anchor from **`MagnifyGesture.startAnchor`** (a `UnitPoint`,
  replacing `correctScaleAnchor(point:)`). Page/stack width stays on Phase 3's
  `.containerRelativeFrame(.horizontal)`. `TouchHandler` (module + `.shared`),
  `DeviceClient.touchPoint`, and `RootView.addTouchHandler` are all deleted.
- **D-06:** **All size reads use `.onGeometryChange(for:of:action:)`** — no `GeometryReader`, no
  background/preference-key reader. The owner's `bindSize` helper (which wraps a `GeometryReader`
  in a `.background`) is **dropped** in favor of `onGeometryChange`, the API PROJECT.md named and
  the only one satisfying UIARCH-01 acceptance #1 as written. `onGeometryChange` is the direct,
  more efficient equivalent on the iOS 26 target.
- **D-06b:** **Convert all 3 pre-existing `GeometryReader` sites** so the codebase is
  GeometryReader-free after Phase 5: `SettingFeature/Login/LoginView.swift` (greedy full-body GR
  for a decorative wave offset — easy), `DetailFeature/GalleryInfos/GalleryInfosView.swift`
  (`proxy.size.width / 3` column width — `containerRelativeFrame`/`onGeometryChange`), and
  `ReadingFeature/Support/LiveTextView.swift` (the reader's live-text `Canvas` overlay maps OCR
  boxes onto `proxy.size` — the **delicate** one; gets a careful coordinate-mapping parity check,
  Canvas reading size from captured state).

### Area 3 — Shared size constants (owner-decided 2026-07-13)
- **D-07:** **Dissolve** the device-derived `Defaults.FrameSize`/`Defaults.ImageSize` computed
  props (`AppModels/Utilities/Defaults+Runtime.swift`) into **native per-site expressions**:
  window-fraction sizes (`cardCellWidth = windowW*0.8`, `rankingCellWidth`, `alertWidthFactor`)
  → `.containerRelativeFrame` fractions; breakpoint-selected fixed sizes (`archiveGridWidth`
  175/125/150, `previewMinW`/`previewMaxW`) → size-class-selected values / `.adaptive(minimum:)`
  grids inline. Keep only genuine constants (`cardCellHeight`). The Home-carousel coupling (card
  width feeds both `preferredItemSize` and the `(windowW - cardWidth)/2` peek inset) is handled
  by **one local `onGeometryChange`** capture in that view, computing both from the captured width.

### Area 4 — Orientation-lock removal & masonry (owner-decided 2026-07-13)
- **D-08:** **Masonry landscape-phone keeps the pure width rule (~4 columns), no clamp.**
  Ratifies the decision Phase 2 explicitly deferred here (`02-CONTEXT.md` deferred idea). The
  column count stays a pure function of container width (Phase 2 D-20/D-22) — no idiom clamp,
  consistent with D-01/D-02 (no device-class reads in layout). Landscape phone gets ~4 columns vs
  2 today; that is the intended universal-orientation outcome, not a regression.
- **D-09:** The Reading-Settings **`enablesLandscape` toggle is silently removed** — no
  replacement note. Rotation now follows the device automatically (self-evident); users who want
  to pin orientation use iOS Control Center's rotation lock (the milestone's "defer to iOS
  built-ins" philosophy). (Contrast Phase 7's auto-lock removal, which *does* add a redirect note
  because it removes a security control.)
- **D-10:** **Remove the orientation-lock machinery:** `AppDelegateClient/AppOrientationMask.swift`;
  the `AppDelegate.application(_:supportedInterfaceOrientationsFor:)` override in
  `AppFeature/DataFlow/AppDelegateReducer.swift` (UIKit then falls back to Info.plist = all 4);
  `AppDelegateClient.setOrientation`/`setOrientationMask` and the `setPortraitOrientation`/
  `setAllOrientationMask`/`setPortraitOrientationMask` helpers; `ReadingReducer.setOrientationPortrait`
  (action + body + the `onAppear` `enablesLandscape` branch + the `ReadingView.onChange` sender);
  and `Setting.enablesLandscape` (field + init param, edited **in place at v1** per the schema
  freeze). **`AppDelegateClient` does nothing but orientation** — verify no other consumer and
  **delete the whole client module** if confirmed. **No Info.plist change** (already all 4).

### Claude's Discretion
- **`DeviceType` placement** — leaning `AppTools` (a pure `Sendable` value type with a
  `@MainActor static var current`), which keeps HYG-01's "pure value types & constants stay in
  AppTools" posture; planner may choose the `DeviceClient` module instead if it reduces imports.
- **`DeviceClient` residual shape** — likely just `deviceType: @MainActor @Sendable () async -> DeviceType`
  (reducers currently `await deviceClient.isPad()`); sync-vs-async and any thin `isPad` convenience
  are planner's call. `noop`/`unimplemented`/`live` updated accordingly.
- **Per-site native tool choice** — which of `containerRelativeFrame` / `horizontalSizeClass` /
  `ViewThatFits` / `onGeometryChange` fits each converted metric site (the toolbox is locked by
  PROJECT.md; the per-site pick is discretion).
- **Plan/wave decomposition** — this is a large phase; natural seams (relatively independent):
  (a) orientation-lock removal, (b) `DeviceType` + `DeviceClient` reshape + idiom-consumer swap,
  (c) metric-read → native conversion across the ~25 views, (d) the reader gesture/geometry
  re-plumb (highest parity risk — Phase 3 gesture precedent applies), (e) the 3 GeometryReader
  conversions, (f) `Defaults` dissolution. Planner sequences.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Project scope (the locked contract)
- `.planning/REQUIREMENTS.md` §UIARCH — **UIARCH-01** and **UIARCH-03** acceptance criteria.
- `.planning/ROADMAP.md` §"Phase 5: Adaptive Layout & Universal Orientation" — goal + 4 success
  criteria.
- `.planning/PROJECT.md` §Constraints / §Key Decisions — parity bar; "Avoid `GeometryReader`;
  prefer size classes / `containerRelativeFrame` / `onGeometryChange` / `ViewThatFits`"; "Retire
  `TouchHandler` via `SpatialTapGesture.location` + `MagnifyGesture.startAnchor`"; v1-schema
  freeze (edit `Setting` in place); lint-as-error / no suppressions.

### Cross-phase carry-forward (fences now lifted / ratified here)
- `.planning/phases/02-native-masonry-grid-swap/02-CONTEXT.md` — D-34 fence (Phase 2 left
  `DeviceUtil.isPadWidth` + its 5 consumers to Phase 5) and the **corrected fact** that
  landscape-phone was unreachable under the lock; the deferred "landscape-phone column policy"
  is ratified by **D-08**.
- `.planning/phases/03-native-reader-paging-swap-spike-gated/03-CONTEXT.md` — D-12 fence (reader
  kept reading `DeviceUtil.isLandscape`/`windowW` in Phase 3, deferred to Phase 5) is **lifted
  here** by D-04/D-05; the shared `PageModel` + paging `ScrollView` + `containerRelativeFrame`
  the reader-geometry work builds on.

### Codebase maps (already-analyzed context)
- `.planning/codebase/CONVENTIONS.md` — lint rules (custom regex rules; `swiftlint_disable_requires_reason`),
  reducer/logger/`@Dependency` conventions.
- `.planning/codebase/STRUCTURE.md` — module layout (AppTools / DeviceClient / AppDelegateClient /
  ReadingFeature / AppModels), where to add code.
- `.planning/codebase/STACK.md` — iOS 26 target, TCA, SwiftUI adaptive API availability.

### Files to modify — DeviceUtil / DeviceClient (D-01/D-02/D-03)
- `AppPackage/Sources/AppTools/DeviceUtil.swift` — **delete**.
- `AppPackage/Sources/DeviceClient/DeviceClient.swift` — reshape to `deviceType()`; drop
  `absWindowW`/`absWindowH`/`touchPoint`.
- Metric-read views (native conversion): `AppComponents/AlertView.swift`,
  `AppComponents/CategoryView.swift`, `AppComponents/NewDawnView.swift`,
  `AppComponents/Placeholder.swift`, `DetailFeature/Comments/CommentsView.swift`,
  `DetailFeature/DetailView+Subviews.swift`, `DetailFeature/Archives/ArchivesView.swift`,
  `DetailFeature/Previews/PreviewsView.swift`, `HomeFeature/HomeView+Sections.swift`,
  `SettingFeature/EhSetting/EhSettingView+Sections3.swift`,
  `ReadingFeature/Support/ControlPanel.swift`, `ReadingFeature/ReadingViewComponents.swift`,
  `AppModels/Utilities/Defaults+Runtime.swift`.
- Idiom-read consumers (→ `deviceType()`): `AppFeature/View/TabBar/TabBarView.swift`,
  `AppComponents/TagSuggestionView.swift`, `HomeFeature/GalleryCardCell.swift`,
  `HomeFeature/HomeView+Sections.swift`, `ReadingSettingFeature/ReadingSettingView.swift`,
  `SearchFeature/SearchRootView+Keywords.swift`, `DetailFeature/GalleryNavigation.swift`,
  `AppFeature/DataFlow/AppReducer.swift`, `FavoritesFeature/FavoritesReducer.swift`,
  `HomeFeature/HomeReducer+Body.swift`, `SearchFeature/SearchRootReducer.swift`,
  `DownloadsFeature/DownloadsReducer.swift`.
- Non-layout window access (must find a new home, not `DeviceUtil`):
  `ApplicationClient/ApplicationClient.swift` (`keyWindow`/`anyWindow` →
  `overrideUserInterfaceStyle`).

### Files to modify — Reader geometry / TouchHandler (D-04/D-05/D-06/D-06b)
- `AppPackage/Sources/AppTools/TouchHandler.swift` — **delete**.
- `AppPackage/Sources/AppFeature/RootView.swift` — remove `addTouchHandler`.
- `AppPackage/Sources/ReadingFeature/Support/GestureHandler.swift` — replace `absWindowW/H` +
  `TouchHandler.shared.currentPoint` with captured size + gesture-supplied location/anchor.
- `AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift` — `TapGesture` →
  `SpatialTapGesture` (location), `MagnificationGesture` → `MagnifyGesture` (`startAnchor`).
- `AppPackage/Sources/ReadingFeature/ReadingView.swift`,
  `ReadingFeature/ReadingViewComponents.swift`, `ReadingFeature/Support/ControlPanel.swift`,
  `ReadingFeature/Support/PageHandler.swift` — `DeviceUtil.isLandscape`/`windowW` → captured
  size + aspect-ratio landscape flag.
- GeometryReader conversions: `SettingFeature/Login/LoginView.swift`,
  `DetailFeature/GalleryInfos/GalleryInfosView.swift`,
  `ReadingFeature/Support/LiveTextView.swift`.

### Files to modify — Orientation lock (D-08/D-09/D-10)
- `AppPackage/Sources/AppDelegateClient/AppOrientationMask.swift` — **delete**.
- `AppPackage/Sources/AppDelegateClient/AppDelegateClient.swift` — remove orientation API;
  **delete the module** if it has no other consumer (verify).
- `AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift` — remove the
  `supportedInterfaceOrientationsFor` override.
- `AppPackage/Sources/ReadingFeature/ReadingReducer.swift` +
  `ReadingFeature/ReadingReducer+Body.swift` — remove `setOrientationPortrait` + `onAppear`
  `enablesLandscape` branch + `@Dependency(\.appDelegateClient)`.
- `AppPackage/Sources/ReadingFeature/ReadingView.swift` — remove the `.onChange(of:
  store.setting.enablesLandscape)` sender.
- `AppPackage/Sources/AppModels/Persistent/Setting.swift` — remove `enablesLandscape` field +
  init param (in-place v1 edit).
- `AppPackage/Sources/ReadingSettingFeature/ReadingSettingView.swift` — remove the toggle row
  (and its localized key, per the xcstrings conventions).

No external ADRs/specs — the contract is fully captured in the requirements/roadmap above plus
the decisions in this document.

</canonical_refs>

<code_context>
## Existing Code Insights (verified 2026-07-13)

### Reusable Assets
- **Phase 3 reader spine** — the shared `@Observable PageModel`, the horizontal paging
  `ScrollView` with `.containerRelativeFrame(.horizontal)` + `.scrollPosition(id:)`, and the
  vertical `AdvancedList` (already native `ScrollView`/`scrollPosition`) are the substrate the
  reader-geometry re-plumb (D-05) hangs off. Page width is already container-driven; only the
  raw-pixel needs (zoom math, tap zones, dual-page half-width, landscape flag) move to the
  captured size.
- **Owner-provided `DeviceType` enum** — the exact idiom type to adopt (see `<specifics>`).
- **`DeviceClient`** already exists as a `@DependencyClient`-style struct with live/noop/unimplemented;
  it shrinks to the `deviceType()` fact (dead `absWindowW`/`absWindowH`/`touchPoint` removed).

### Established Patterns
- **`@Dependency` injection over globals** — the whole phase converts static `DeviceUtil.*` reads
  into either native SwiftUI (metrics) or `@Dependency(\.deviceClient).deviceType()` (idiom). No
  static/global device access remains after Phase 5 (for the Device slice).
- **Native adaptive SwiftUI toolbox (locked by PROJECT.md)** — `containerRelativeFrame`,
  `horizontalSizeClass`, `onGeometryChange`, `ViewThatFits`; `GeometryReader` avoided (and the 3
  legacy sites eliminated, D-06b).
- **Wave-0 baseline-lock-then-swap parity method** (Phases 1–4) is available if the planner wants
  a parity harness around the delicate reader gesture/geometry re-plumb.
- **In-place v1 schema edits** — `Setting.enablesLandscape` is removed by editing the model in
  place (no `VersionedSchema` v2) per the milestone schema freeze.

### Integration Points
- **iPad push-vs-present navigation** — `DetailFeature/GalleryNavigation.swift`
  (`await isPad() ? present() : push()`) and its callers in Favorites/Home/Search/Downloads
  reducers + `AppReducer`; these are the genuine device-class branches that move to
  `deviceType() == .pad`.
- **`AppDelegate` orientation callback** — `supportedInterfaceOrientationsFor` currently returns
  `AppOrientationMask.current`; removing it hands governance to Info.plist (all 4).
- **Reader gesture coexistence** — the `SpatialTapGesture.location` / `MagnifyGesture.startAnchor`
  swap must preserve the post-Phase-3 zoom/pan/tap behavior exactly (acceptance #2); the tap-edge
  page-turn zones (`< 0.2` / `> 0.8` of width, RTL-aware) and zoom pan-clamp margins are the
  parity-sensitive math.

### Parity constraints (do not regress)
- **Reading zoom / pan / tap coexistence** — explicit acceptance criterion; the highest-risk unit.
- **Dual-page mapping** — `PageHandler.mapToPager`/`mapFromPager` (incl. cover math) must stay
  correct against the new aspect-ratio landscape flag.
- **Idiom branch behavior** — kept device-class (D-03), so no split-view/landscape behavior drift
  from an `isPad → sizeClass` swap.

</code_context>

<specifics>
## Specific Ideas

**Owner-provided `DeviceType` enum (adopt verbatim; D-03).** Exposed via
`DeviceClient.deviceType()`; `DeviceType.current` is called **only** inside `DeviceClient.live`:

```swift
#if canImport(UIKit)
import UIKit
#endif

public enum DeviceType: Equatable, Sendable, CaseIterable {
    // swiftlint:disable:next identifier_name
    case unspecified, phone, pad, watch, tv, carPlay, mac, vision

    @MainActor
    public static var current: Self {
        #if os(macOS)
        .mac
        #elseif os(tvOS)
        .tv
        #elseif os(watchOS)
        .watch
        #elseif os(visionOS)
        .vision
        #elseif canImport(UIKit)
        .init(idiom: UIDevice.current.userInterfaceIdiom)
        #endif
    }

    #if canImport(UIKit)
    init(idiom: UIUserInterfaceIdiom) {
        switch idiom {
        case .unspecified: self = .unspecified
        case .phone: self = .phone
        case .pad: self = .pad
        case .tv: self = .tv
        case .carPlay: self = .carPlay
        case .mac: self = .mac
        case .vision: self = .vision
        @unknown default: self = .unspecified
        }
    }
    #endif
}
```

- **Lint note (resolve at root, not suppress):** the pasted `// swiftlint:disable:next
  identifier_name` (for the short `tv` case) needs handling per the project's
  `swiftlint_disable_requires_reason` rule and CLAUDE.md's no-suppression posture. Planner:
  first verify whether `identifier_name` is even enabled in `.swiftlint.yml`; if **not**, drop the
  disable line entirely (cleanest); if it **is**, add the required preceding `// reason:` comment
  (owner has implicitly authorized this specific disable by providing it). Do not carry an
  unreasoned disable.
- **Owner's size-read stance:** avoid `GeometryReader` even when reading size — use
  `onGeometryChange` (D-06). The `bindSize`/`.background(GeometryReader)` helper was proposed and
  then dropped in favor of `onGeometryChange` after confirming it's the direct equivalent.
- **Owner's DeviceClient rule:** no `DeviceClient.live`/`.liveValue`/static usage in consumers —
  only `@Dependency(\.deviceClient)`. The `DeviceType.current` static is the single sanctioned
  static call, confined to `DeviceClient.live`.

</specifics>

<deferred>
## Deferred Ideas

- **Reduce `ZStack` → `.overlay`/`.background`** (owner request, 2026-07-13) — **routed to an
  expanded Phase 10 "UI Polish"** as a new **POLISH-02** task, added to `.planning/REQUIREMENTS.md`
  + `.planning/ROADMAP.md` via `/gsd-phase` immediately after this discussion. Rationale: not
  purely mechanical (`.overlay`/`.background` size to the primary content; `ZStack` sizes to the
  union of children), so it needs per-site judgment and should land **after** the Phase 5–7 UI
  churn to avoid double-touching files. Not in Phase 5 scope.
- **Rest of HYG-01** (Haptics / UserDefaults / File / Cookie / `URLUtil` / `AppUtil` clients;
  `DataCache.shared`) — **Phase 8**. Only the Device slice is pulled forward (D-01).
- **Root privacy mask + auto-lock removal** (UIARCH-04/05) — **Phase 7**.

</deferred>

---

*Phase: 5-Adaptive Layout & Universal Orientation*
*Context gathered: 2026-07-13*
