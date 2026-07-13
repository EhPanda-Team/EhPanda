# Phase 5: Adaptive Layout & Universal Orientation - Pattern Map

**Mapped:** 2026-07-13
**Files analyzed:** ~40 (2 net-new, ~35 in-place edits, 3 deletions, 1 possible module deletion)
**Analogs found:** 38 / 40 (2 sites use a new-to-codebase idiom — `onGeometryChange`)

> This is a **parity mechanism-swap** refactor: almost all work is in-place edits and deletions.
> The highest-value analogs are the already-shipped native swaps from **Phase 2** (masonry
> `containerRelativeFrame` column rule) and **Phase 3** (paging `ScrollView` +
> `.containerRelativeFrame(.horizontal)` + `.scrollPosition(id:)`, the `@Observable PageModel`,
> and `PageHandler`'s dual-page maps + its Wave-0 test suite). Where an in-place edit has no
> code analog (a deletion, or the `onGeometryChange` idiom that does not yet exist in the tree),
> the "analog" is the *consumer touch-points to prune* or the cited Apple API, not a file.

## File Classification

### Net-new files

| New File | Role | Data Flow | Closest Analog | Match Quality |
|----------|------|-----------|----------------|---------------|
| `AppTools/DeviceType.swift` (owner-provided enum, verbatim) | model (value type) | transform | `DeviceClient/DeviceClient.swift` shape; any `AppTools` pure `Sendable` type | role-match |
| `Tests/ReadingFeatureTests/GestureHandlerTests.swift` | test | unit | `Tests/ReadingFeatureTests/PageHandlerTests.swift` | exact (same suite, Wave-0 method) |

### Modified — DeviceUtil / DeviceClient (D-01/D-02/D-03)

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------|------|-----------|----------------|---------------|
| `AppTools/DeviceUtil.swift` | utility | — | **delete**; prune ~25 consumers | n/a |
| `DeviceClient/DeviceClient.swift` | client | request-response | itself (reshape to `deviceType()`); `AppDelegateClient` `@DependencyClient` shape | exact |
| `AlertView`, `CategoryView`, `NewDawnView`, `Placeholder`, `CommentsView`, `DetailView+Subviews`, `ArchivesView`, `PreviewsView`, `HomeView+Sections`, `EhSettingView+Sections3`, `ControlPanel`, `ReadingViewComponents` (metric reads) | component | transform | Phase 2 masonry `containerRelativeFrame`; Phase 3 `.containerRelativeFrame(.horizontal)` | role-match |
| `Defaults+Runtime.swift` | config | transform | Phase 2/3 container-relative; Home-carousel `onGeometryChange` (D-07) | partial (dissolve to per-site) |
| Idiom consumers: `TabBarView`, `TagSuggestionView`, `GalleryCardCell`, `HomeView+Sections`, `ReadingSettingView`, `SearchRootView+Keywords`, `GalleryNavigation`, `AppReducer`, `FavoritesReducer`, `HomeReducer+Body`, `SearchRootReducer`, `DownloadsReducer` | view / reducer | request-response | `GalleryNavigation.swift:16` (`await isPad() ? present() : push()`) | exact |
| `ApplicationClient/ApplicationClient.swift` (non-layout window access) | client | request-response | its own `overrideUserInterfaceStyle` side-effect at line 38 | partial (inline a private window lookup) |

### Modified — Reader geometry / TouchHandler (D-04/D-05/D-06/D-06b)

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------|------|-----------|----------------|---------------|
| `AppTools/TouchHandler.swift` | utility | event-driven | **delete**; prune `DeviceClient.touchPoint`, `RootView.addTouchHandler`, `GestureHandler` | n/a |
| `AppFeature/RootView.swift` (`addTouchHandler`) | view | event-driven | prune touch-point | n/a |
| `ReadingFeature/Support/GestureHandler.swift` | utility (handler) | transform | itself + Phase 3 `PageModel` (inject `containerSize`) | exact (make pure) |
| `ReadingFeature/ReadingView+Gestures.swift` | view | event-driven | Apple `SpatialTapGesture` / `MagnifyGesture` (new idiom) | partial |
| `ReadingView`, `ReadingViewComponents`, `ControlPanel`, `PageHandler` (`isLandscape`/`windowW`) | view / handler | transform | Phase 3 captured-size flow; `PageHandler` maps already take `isLandscape:` | role-match |
| `SettingFeature/Login/LoginView.swift` (GeometryReader) | view | transform | `onGeometryChange` (new idiom) | partial |
| `DetailFeature/GalleryInfos/GalleryInfosView.swift` (GeometryReader, `proxy.size.width/3`) | view | transform | `containerRelativeFrame`/`onGeometryChange` | partial |
| `ReadingFeature/Support/LiveTextView.swift` (GeometryReader Canvas OCR) | view | transform | `onGeometryChange` (new idiom) — **delicate** | partial |

### Modified — Orientation lock (D-08/D-09/D-10)

| Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---------------|------|-----------|----------------|---------------|
| `AppDelegateClient/AppOrientationMask.swift` | config | — | **delete** | n/a |
| `AppDelegateClient/AppDelegateClient.swift` | client | request-response | **delete whole module** if no other consumer (verify) | n/a |
| `AppFeature/DataFlow/AppDelegateReducer.swift` (`supportedInterfaceOrientationsFor`) | reducer | event-driven | prune override | n/a |
| `ReadingFeature/ReadingReducer.swift` + `ReadingReducer+Body.swift` | reducer | event-driven | prune `setOrientationPortrait` action+body+`@Dependency` | n/a |
| `ReadingFeature/ReadingView.swift` (`.onChange` sender) | view | event-driven | prune sender | n/a |
| `AppModels/Persistent/Setting.swift` (`enablesLandscape`) | model | — | in-place v1 edit (schema freeze) | n/a |
| `ReadingSettingFeature/ReadingSettingView.swift` (toggle row + xcstrings key) | view | — | prune row + localized key | n/a |
| `AppPackage/Package.swift` (module edges) | config | — | prune `.module(.appDelegateClient)` edges + target + enum case | n/a |

## Pattern Assignments

### `AppTools/DeviceType.swift` (net-new value type)

**Analog:** owner-provided verbatim source (CONTEXT.md §specifics / RESEARCH.md Standard Stack) —
**adopt exactly**, including the `// reason:`-prefixed `// swiftlint:disable:next identifier_name`
for the 2-char `tv` case (`identifier_name` is enabled; `swiftlint_disable_requires_reason` is
error-level, so the reason line is mandatory). Placement recommended in `AppTools` (pure
`Sendable` value type); `DeviceType.current` is called **only** inside `DeviceClient.live`.

### `DeviceClient/DeviceClient.swift` (client, request-response)

**Analog:** itself, reshaped. Current shape (lines 5-22) has 4 members; the phase collapses it to
one `deviceType()` fact (`absWindowW`/`absWindowH`/`touchPoint` are dead — no consumers).

**Current struct + live (lines 5-41):**
```swift
public struct DeviceClient: Sendable {
    public let isPad: @Sendable () async -> Bool
    public let absWindowW: @MainActor @Sendable () -> Double   // DEAD — remove
    public let absWindowH: @MainActor @Sendable () -> Double   // DEAD — remove
    public let touchPoint: @MainActor @Sendable () -> CGPoint? // DEAD — remove (TouchHandler gone)
    // ...
}
extension DeviceClient {
    public static let live: Self = .init(
        isPad: { await MainActor.run { DeviceUtil.isPad } },
        absWindowW: { DeviceUtil.absWindowW },
        touchPoint: { TouchHandler.shared.currentPoint },  // ...
    )
}
```

**Recommended residual shape (RESEARCH Pattern 3 — sync `@MainActor`, discretion):**
```swift
public struct DeviceClient: Sendable {
    public let deviceType: @MainActor @Sendable () -> DeviceType   // live returns DeviceType.current
}
```
Keep the `DependencyKey`/`DependencyValues` boilerplate (lines 44-55) verbatim; update
`noop`/`unimplemented` (lines 58-74) to the single member. **Do not** import `AppTools` for
`DeviceUtil` any longer; import wherever `DeviceType` lands.

**Idiom-consumer swap pattern:**
- Reducer analog — `GalleryNavigation.swift:16`: `await isPad() ? present() : push()` →
  `deviceClient.deviceType() == .pad ? present() : push()` (drop `await` if sync).
- Reducer analog — `AppReducer.swift:249`: `let isPad = await deviceClient.isPad()` →
  `deviceClient.deviceType() == .pad`.
- View analog — `ReadingView.swift:82`: `if !DeviceUtil.isPad && DeviceUtil.isLandscape` → the
  `!DeviceUtil.isPad` half becomes `deviceClient.deviceType() != .pad` (the `isLandscape` half is
  a *separate* metric conversion, see reader section).

### `GestureHandler.swift` (handler, transform) — highest parity risk

**Analog:** itself, made pure by injecting `containerSize` (RESEARCH "GestureHandler with injected
size" example). Current `absWindowW/H` + `TouchHandler.shared.currentPoint` reads to replace:

**Pan-clamp margins (lines 17-28):** `DeviceUtil.absWindowW * (scale-1)/2` →
`containerSize.width * (scale-1)/2` (and `absWindowH` → `containerSize.height`). Term-for-term.

**Scale anchor (lines 33-37):** `correctScaleAnchor(point:)` divides `point.x / DeviceUtil.absWindowW`.
This is **replaced entirely** by `MagnifyGesture.startAnchor` (a `UnitPoint`) — no width division.

**Tap-edge zones (lines 48-67):** reads `TouchHandler.shared.currentPoint?.x` and compares to
`DeviceUtil.absWindowW * 0.2` / `* (1 - 0.2)`. New signature takes
`location: CGPoint, containerWidth: CGFloat` (from `SpatialTapGesture.location` +
`pageModel.containerSize.width`); the `< 0.2` / `> 0.8` RTL logic is unchanged. Coordinate-space
parity holds because tap-to-turn is gated to `scale == 1` (ReadingView.swift:151 `isEnabled:`) and
the container `.ignoresSafeArea()` fills the window — local == layout == window at scale 1.

**Double-tap anchor (lines 69-76):** `TouchHandler.shared.currentPoint` → thread the tap location
through the `SpatialTapGesture(count: 2)` value.

### `ReadingView+Gestures.swift` (view, event-driven)

**Analog:** Apple `SpatialTapGesture` / `MagnifyGesture` (new-to-codebase). Current gestures:
- Line 7 `TapGesture(count: 1)` → `SpatialTapGesture(count: 1, coordinateSpace: .local)`, pass
  `value.location` into `onSingleTapGestureEnded(location:containerWidth:...)`.
- Line 19 `TapGesture(count: 2)` → `SpatialTapGesture(count: 2, coordinateSpace: .local)`.
- Line 29 `MagnificationGesture()` → `MagnifyGesture()`; `onChanged`/`onEnded` pass
  `value.magnification` (not the bare value — Pitfall 2) and `value.startAnchor`.
- Line 41 `DragGesture(minimumDistance:.zero, coordinateSpace:.local)` — **unchanged** (already
  local-space, no `DeviceUtil`).

Preserve the `ExclusiveGesture(doubleTap, singleTap)` composition and the ReadingView `isEnabled:`
wiring (scale-gated tap, `.scrollDisabled(gestureHandler.scale != 1)`).

### `PageHandler.swift` (handler, transform) + its default-arg removal

**Analog:** itself + `PageHandlerTests.swift`. Lines 11 & 26: `isLandscape: Bool = DeviceUtil.isLandscape`
— **remove the default** (Pitfall 5) so callers must thread the D-04 aspect-ratio flag. The maps
themselves survive byte-for-byte. Every call site in `ReadingView.swift`
(lines 133, 181, 245, 279, 283, 321, 344) currently passes `isLandscape: DeviceUtil.isLandscape`
→ replace with the captured-size flag `containerSize.width > containerSize.height`.
`PageHandlerTests` already pass `isLandscape:` explicitly, so removing the default keeps it green.

### `GestureHandlerTests.swift` (net-new test)

**Analog:** `PageHandlerTests.swift` (exact — same `@MainActor @Suite` Swift Testing structure,
same Wave-0 baseline-lock rationale in the header doc comment). Method:
1. Refactor `GestureHandler` to take injected `containerSize`/`location` (pure methods).
2. Assert new pure outputs equal the pre-swap `absWindowW/H`-based results for representative sizes
   (portrait phone, landscape phone, iPad both orientations) and scales — covering
   `edgeWidth`/`edgeHeight` clamps, `correctScaleAnchor`↔`startAnchor` equivalence, and the
   `< 0.2 / > 0.8` RTL tap-zone decisions.

Reuse `PageHandlerTests`'s `makeSetting(...)` helper shape (lines 14-24) and `@Test(arguments:)`
parameterization (line 28).

### `Defaults+Runtime.swift` (config) — dissolve to per-site (D-07)

**Analog:** Phase 2 masonry `containerRelativeFrame`; Home-carousel local `onGeometryChange`
(RESEARCH Code Examples). Current device-derived props to dissolve:
- Line 13 `cardCellWidth = DeviceUtil.windowW * 0.8` → carousel-local captured width `* 0.8`.
- Line 10 `archiveGridWidth` (`isPadWidth ? 175 : isSEWidth ? 125 : 150`) → size-class-selected
  inline value / `.adaptive(minimum:)` grid.
- Lines 18-23 `rankingCellWidth`, `alertWidthFactor` → `containerRelativeFrame` fractions.
- Lines 28-30 `previewMinW`/`previewMaxW` → `horizontalSizeClass`-selected inline.
- **Keep** line 14 `cardCellHeight` (a genuine constant).

### `LiveTextView.swift` (view, transform) — delicate GeometryReader→onGeometryChange (D-06b)

**Analog:** RESEARCH "LiveTextView Canvas without GeometryReader" example. Current: `GeometryReader`
at line 20 reads `proxy.size` and maps normalized OCR corners (`bounds.topLeft * size`, line 39;
`.frame(width: textGroup.width * width ...)`, line 90; `.position(...)`, lines 91-94). Convert to
`@State size` written by `.onGeometryChange(for: CGSize.self){ $0.size } action:`; the `Canvas`
fill/path branch may use `Canvas`'s own size param, but the `ForEach(.position)` overlay must read
the **same** captured `size`. Encode a pixel-identical parity check; guard the one-frame
`size == .zero` first pass.

### `GalleryInfosView.swift` (view, transform) — GeometryReader→ (D-06b)

**Analog:** `containerRelativeFrame`. Line 93 `GeometryReader` → line 100 `.frame(width: proxy.size.width / 3)`
becomes `.containerRelativeFrame(.horizontal){ w, _ in w / 3 }` or an `onGeometryChange` capture.

## Shared Patterns

### Native geometry capture (`onGeometryChange`) — NEW TO CODEBASE
**Source:** none exists yet (`grep onGeometryChange AppPackage/Sources` → 0 hits). Cite Apple docs:
`developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)`.
**Apply to:** reader container single-source-of-truth (D-05), Home carousel (D-07), LiveTextView,
LoginView. Result type must be `Equatable` (`CGSize`/`CGFloat`) so `action` runs only on change.

### `@Dependency` injection over static globals
**Source:** `GalleryNavigation.swift:16`, `AppReducer.swift:249` (existing `deviceClient.isPad`).
**Apply to:** every `DeviceUtil.isPad`/`isPhone` idiom read → `deviceClient.deviceType() == .pad`.

### Container-relative sizing (already shipped)
**Source:** Phase 3 reader page width (`.containerRelativeFrame(.horizontal)`); Phase 2 masonry
column rule (pure width function — ratified by D-08, no idiom clamp).
**Apply to:** all ~12 metric-read view sites and the `Defaults` dissolution.

### `@DependencyClient` reshape + Wave-0 baseline-lock
**Source:** `DeviceClient.swift` (live/noop/unimplemented triad); `PageHandlerTests.swift` (Wave-0).
**Apply to:** `DeviceClient` reshape and the new `GestureHandlerTests`.

### Deletion touch-point pruning (no analog — consumer map)
- **`DeviceUtil.swift`** → ~25 consumers (see File Classification); split metric vs idiom.
- **`TouchHandler.swift`** → `DeviceClient.touchPoint` (DeviceClient.swift:9,38), `RootView.addTouchHandler`,
  `GestureHandler` lines 54, 71, 82.
- **`AppOrientationMask.swift` + `AppDelegateClient` module** → `AppDelegateReducer.swift`
  (`supportedInterfaceOrientationsFor` override + `import`), `ReadingReducer.swift:177,223`,
  `ReadingReducer+Body.swift:73-97`, `ReadingView.swift:233-234`, and `Package.swift`
  `.module(.appDelegateClient)` edges + target + enum case. Verify `AppDelegateClient` has **no**
  other consumer before deleting the whole module (RESEARCH confirms only `ReadingReducer` injects
  it and only `AppDelegateReducer` reads `AppOrientationMask.current`).
- **`ApplicationClient.swift:38`** `(DeviceUtil.keyWindow ?? DeviceUtil.anyWindow)?.overrideUserInterfaceStyle`
  → inline a private window-scene lookup locally (it already side-effects) since `DeviceUtil` is gone.

### xcstrings / lint cross-cutting
- Removing the `enablesLandscape` toggle removes its localized key across **all** locales
  (AGENTS.md xcstrings conventions).
- `Setting.enablesLandscape` removed in place at v1 (schema freeze; decode-safe — synthesized
  `Codable` ignores unknown keys, but confirm `Setting` has no custom strict decoder — RESEARCH A1).
- No `// swiftlint:disable` anywhere except the one owner-authorized, `// reason:`-prefixed line in
  `DeviceType.swift`.

## No Analog Found (new-to-codebase idiom)

| File / concern | Role | Data Flow | Reason |
|----------------|------|-----------|--------|
| `onGeometryChange` usages (reader container, Home carousel, LiveTextView, LoginView) | view | transform | `onGeometryChange` has 0 existing occurrences; planner uses the cited Apple API + RESEARCH Code Examples, not a codebase analog |
| `SpatialTapGesture` / `MagnifyGesture` wiring | view | event-driven | No existing use; the current `TapGesture`/`MagnificationGesture` at `ReadingView+Gestures.swift` are the *structural* template, but the value/coordinate-space handling is new |

## Metadata

**Analog search scope:** `AppPackage/Sources/{AppTools,DeviceClient,AppDelegateClient,ReadingFeature,
AppModels,AppComponents,DetailFeature,HomeFeature,SettingFeature,AppFeature,ApplicationClient}`,
`AppPackage/Tests/ReadingFeatureTests`.
**Files scanned:** ~18 read in full/part; ~40 in the work-list classified.
**Pattern extraction date:** 2026-07-13
</content>
</invoke>
