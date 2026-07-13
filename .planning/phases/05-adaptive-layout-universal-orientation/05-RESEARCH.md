# Phase 5: Adaptive Layout & Universal Orientation - Research

**Researched:** 2026-07-13
**Domain:** SwiftUI adaptive layout (size classes / container-relative sizing / geometry observation), native gesture geometry (SpatialTapGesture / MagnifyGesture), UIKit orientation-lock removal, TCA `@Dependency` client reshape — all at behavior/appearance parity on the iOS 26 target.
**Confidence:** HIGH (this is a mechanism-swap refactor over a fully-scouted, already-analyzed codebase; every target API is available on iOS 26; decisions D-01..D-10 are locked)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Area 1 — DeviceUtil removal**
- **D-01:** `DeviceUtil` (the `AppTools` static global) is **deleted** this phase. `DeviceClient` becomes the injected home for residual device facts, accessed **only** through `@Dependency(\.deviceClient)` — no `DeviceClient.live`/`.liveValue`/static usage in consumers. Pulls the **Device slice of HYG-01** forward; the rest of HYG-01 stays in Phase 8.
- **D-02:** Layout-metric reads are **REPLACED by native adaptive SwiftUI** (`containerRelativeFrame` / `horizontalSizeClass` / `onGeometryChange` / `ViewThatFits`) — **not** routed through DeviceClient.
- **D-03:** The `isPad`/`isPhone` idiom is replaced by the owner-provided **`DeviceType` enum** (adopt verbatim — see Standard Stack). Idiom branches keep **device-class semantics** (parity-preserving, *not* converted to size-class) but read `deviceClient.deviceType()` via `@Dependency`. `DeviceType.current` is called **only** inside `DeviceClient.live`. Reducers switch `deviceClient.isPad` → `deviceType() == .pad`.

**Area 2 — Reader geometry & landscape source**
- **D-04:** The reader decides "landscape" (dual-page eligibility) from the **container aspect ratio — width > height** of its captured geometry (not device orientation).
- **D-05:** **Single source of truth.** One `onGeometryChange` at the reader container writes its size into the shared `@Observable` reader model (Phase 3's `PageModel` or a sibling). The `GestureHandler` zoom-margin / pan-clamp / scale-anchor / tap-edge-zone math, the dual-page half-width, and the D-04 landscape flag all read that **one** size. Tap location from **`SpatialTapGesture.location`**; pinch anchor from **`MagnifyGesture.startAnchor`**. Page/stack width stays on Phase 3's `.containerRelativeFrame(.horizontal)`. `TouchHandler` (module + `.shared`), `DeviceClient.touchPoint`, and `RootView.addTouchHandler` are all deleted.
- **D-06:** **All size reads use `.onGeometryChange(for:of:action:)`** — no `GeometryReader`, no background/preference-key reader. The owner's `bindSize` helper is **dropped**.
- **D-06b:** **Convert all 3 pre-existing `GeometryReader` sites** so the codebase is GeometryReader-free: `LoginView.swift` (easy), `GalleryInfosView.swift` (`proxy.size.width/3`), and `LiveTextView.swift` (the **delicate** OCR-box `Canvas` mapping — careful coordinate parity).

**Area 3 — Shared size constants**
- **D-07:** **Dissolve** `Defaults.FrameSize`/`Defaults.ImageSize` device-derived computed props into **native per-site expressions**. Keep only genuine constants (`cardCellHeight`). The Home-carousel coupling (card width feeds both card frame and the `(windowW - cardWidth)/2` peek inset) is handled by **one local `onGeometryChange`** capture.

**Area 4 — Orientation-lock removal & masonry**
- **D-08:** **Masonry landscape-phone keeps the pure width rule (~4 columns), no clamp.** Ratifies Phase 2's deferred decision.
- **D-09:** The Reading-Settings **`enablesLandscape` toggle is silently removed** — no replacement note (users use iOS Control Center rotation lock).
- **D-10:** **Remove the orientation-lock machinery:** `AppOrientationMask.swift`; the `supportedInterfaceOrientationsFor` override; `AppDelegateClient.setOrientation`/`setOrientationMask` + helpers; `ReadingReducer.setOrientationPortrait` (action + body + `onAppear` branch + `ReadingView.onChange` sender); `Setting.enablesLandscape` (field + init param, in-place v1 edit). **Delete the whole `AppDelegateClient` module** if it has no other consumer (verify). **No Info.plist change** (already all 4).

### Claude's Discretion
- **`DeviceType` placement** — leaning `AppTools` (pure `Sendable` value type with `@MainActor static var current`); planner may choose `DeviceClient` instead if it reduces imports.
- **`DeviceClient` residual shape** — likely just `deviceType`; sync-vs-async and any thin `isPad` convenience are planner's call. `noop`/`unimplemented`/`live` updated accordingly.
- **Per-site native tool choice** — which of `containerRelativeFrame` / `horizontalSizeClass` / `ViewThatFits` / `onGeometryChange` fits each converted metric site (toolbox locked by PROJECT.md; per-site pick is discretion).
- **Plan/wave decomposition** — natural seams: (a) orientation-lock removal, (b) `DeviceType` + `DeviceClient` reshape + idiom-consumer swap, (c) metric-read → native across ~25 views, (d) reader gesture/geometry re-plumb (highest parity risk), (e) the 3 GeometryReader conversions, (f) `Defaults` dissolution.

### Deferred Ideas (OUT OF SCOPE)
- **`ZStack` → `.overlay`/`.background`** → routed to **Phase 10 POLISH-02**. Not this phase.
- **Rest of HYG-01** (Haptics / UserDefaults / File / Cookie / `URLUtil` / `AppUtil`; `DataCache.shared`) → **Phase 8**.
- **Root privacy mask + auto-lock removal** (UIARCH-04/05) → **Phase 7**.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **UIARCH-01** | Modernize adaptive layout — remove screen-dependent logic across `DeviceUtil` and `DeviceClient`; no view reads `window*/screen*/absWindow*` for layout; `isPadWidth`/`isSEWidth` breakpoints → size-class/container-relative; `TouchHandler` retired via `SpatialTapGesture.location` + `MagnifyGesture.startAnchor`; `GeometryReader` avoided (`containerRelativeFrame`/`onGeometryChange`/`ViewThatFits`); `Defaults.FrameSize`/`ImageSize` no longer derive from a global; reading zoom/pan/tap parity preserved. | Standard Stack (native toolbox + `DeviceType`), Architecture Patterns (single-source-of-truth geometry, gesture re-plumb), Code Examples (each conversion), Don't Hand-Roll (no manual window lookup), Validation Architecture (GestureHandler + PageHandler baseline-lock). |
| **UIARCH-03** | Support device orientation on every page; remove EhPanda's custom orientation lock (`AppOrientationMask`, `AppDelegateClient.setOrientation*`, `setOrientationPortrait`, `Setting.enablesLandscape`); OS governs. | Architecture Patterns (orientation-lock removal → Info.plist governance), Runtime State Inventory (persisted `enablesLandscape` removal is decode-safe), Common Pitfalls (lifecycle subtleties). |
</phase_requirements>

## Summary

This phase retires three legacy mechanisms — screen-metric math (`DeviceUtil` window/screen getters + `isPadWidth`/`isSEWidth`), the `TouchHandler` global, and the custom UIKit orientation lock — and lets SwiftUI size classes / container geometry and the OS govern layout and rotation. It is a **large but mechanically-bounded parity refactor**: every replacement API (`onGeometryChange`, `SpatialTapGesture`, `MagnifyGesture`, `containerRelativeFrame`, `ViewThatFits`, `horizontalSizeClass`) is available on the iOS 26 minimum target [VERIFIED: codebase STACK.md — `platforms: [.iOS(.v26)]`], so **availability is never a blocker** — the work is coordinate-space and behavior equivalence, not new capability.

The scope is fully scouted: `DeviceUtil` is read by ~25 files split into **layout-metric** reads (go native, D-02) and **idiom** reads (`isPad`/`isPhone` → injected `deviceClient.deviceType()`, D-03). No reducer reads window size — the 6 reducers injecting `deviceClient` only use `isPad` for the iPad push-vs-present navigation idiom, so `DeviceClient.absWindowW`/`absWindowH`/`touchPoint` are dead and removed. The orientation lock lives entirely in `AppOrientationMask.current` + the `AppDelegate` `supportedInterfaceOrientationsFor` callback; removing both hands governance to `App/Info.plist` (already all 4 orientations) with **no plist change**. `AppDelegateClient`'s only remaining purpose is orientation, so it is deleted as a whole module after verifying no other consumer (confirmed: only `ReadingReducer` injects it; only `AppDelegateReducer` reads `AppOrientationMask.current`) [VERIFIED: codebase grep].

**Highest parity risk is the reader gesture/geometry re-plumb** (D-04/D-05): `GestureHandler` currently reads `DeviceUtil.absWindowW/H` for its pan-clamp margins, scale-anchor, and RTL tap-edge page-turn zones, and reads `TouchHandler.shared.currentPoint` for tap/pinch location. These must move to a single captured container size (written once by `onGeometryChange`) plus gesture-supplied `SpatialTapGesture.location` (a `CGPoint` in the view's local space) and `MagnifyGesture.startAnchor` (a `UnitPoint`, a direct replacement for `correctScaleAnchor`). Because tap-to-turn only fires at `scale == 1` (where local space == layout space), the normalization stays exact. `GestureHandler` has no unit tests today; the parity harness must inject the size and baseline-lock the clamp/anchor/tap-zone outputs.

**Primary recommendation:** Sequence the six seams so the low-risk mechanical work (orientation-lock removal → `DeviceType`/`DeviceClient` reshape → metric-read conversions → Defaults dissolution → the 2 easy GeometryReader sites) lands first, then treat the reader gesture/geometry re-plumb + the `LiveTextView` Canvas conversion as a dedicated, Wave-0-guarded parity unit (extend the existing `ReadingFeatureTests` pattern to `GestureHandler`, whose methods become pure once the size is injected).

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Layout sizing (card/grid/preview/alert widths) | SwiftUI View (container-relative) | — | D-02: layout is a view concern; container geometry, not a global, owns it. |
| Device-class idiom (iPad push-vs-present nav; landscape-phone chevron) | `DeviceClient` (`@Dependency`) | Reducer / View | D-03: genuine device-class semantics, injected not global. |
| Reader container size (source of truth) | `@Observable` reader model (`PageModel`/sibling) | GestureHandler / PageHandler read it | D-05: one `onGeometryChange` write; all reader math reads it. |
| Tap / pinch location & anchor | SwiftUI gesture value (`SpatialTapGesture.location`, `MagnifyGesture.startAnchor`) | GestureHandler | D-05: native gestures supply location; no global touch handler. |
| Orientation governance | OS / `App/Info.plist` | — | D-10: remove app-level lock; UIKit falls back to Info.plist (all 4). |
| Persisted reading prefs (`Setting`) | `@Shared(.setting)` (v1 in place) | — | D-10: remove `enablesLandscape` field via in-place v1 edit (schema freeze). |

## Standard Stack

This phase installs **no new packages**. It replaces first-party globals with first-party Apple SwiftUI/UIKit APIs already available on the iOS 26 target. "Standard stack" here = the locked native toolbox plus the owner-provided value type.

### Core (Apple SwiftUI/UIKit APIs — all available on iOS 26)

| API | Availability | Purpose | Why Standard |
|-----|--------------|---------|--------------|
| `onGeometryChange(for:of:action:)` | iOS 16.0+ (backported; iOS 18 adds old+new-value overload) [CITED: swiftwithmajid.com/2024/08/13/tracking-geometry-changes-in-swiftui/] | Observe a view's size/frame without imposing layout | D-06: the direct, non-greedy replacement for `GeometryReader`; result type must be `Equatable` so SwiftUI runs `action` only on change [CITED: developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)] |
| `containerRelativeFrame(_:)` | iOS 17.0+ [CITED: developer.apple.com/documentation/swiftui/view/containerrelativeframe(_:alignment:)] | Size a view to a fraction of its scroll/container | Already used by Phase 3 reader page width; the fraction equivalent for `windowW * k` sites |
| `horizontalSizeClass` (`@Environment`) | iOS 8+ | `.compact`/`.regular` width class | The size-class equivalent for `isPadWidth`-style breakpoints (see parity note) |
| `ViewThatFits` | iOS 16.0+ | Pick the first child that fits | Optional per-site tool where a hard breakpoint chose between fixed sizes |
| `SpatialTapGesture` (`.location`) | iOS 16.0+ [CITED: developer.apple.com/documentation/swiftui/spatialtapgesture] | Tap location as `CGPoint` in a chosen coordinate space (default `.local`) | Replaces `TouchHandler.shared.currentPoint` for tap-to-turn & double-tap anchor |
| `MagnifyGesture` (`.magnification`, `.startAnchor`, `.startLocation`) | iOS 17.0+ [CITED: developer.apple.com/documentation/swiftui/magnifygesture] | Pinch value + anchor `UnitPoint` | `MagnificationGesture` is deprecated iOS 17; `.startAnchor` is a `UnitPoint` that directly replaces `correctScaleAnchor(point:)` |

### Supporting (owner-provided value type)

| Type | Purpose | When to Use |
|------|---------|-------------|
| `DeviceType` enum (adopt verbatim, D-03) | Injected device-class idiom (`unspecified/phone/pad/watch/tv/carPlay/mac/vision`) | Every `isPad`/`isPhone` read → `deviceClient.deviceType() == .pad` |

**Owner-provided `DeviceType` (adopt verbatim; `DeviceType.current` called ONLY inside `DeviceClient.live`):**
```swift
#if canImport(UIKit)
import UIKit
#endif

public enum DeviceType: Equatable, Sendable, CaseIterable {
    // reason: mirrors UIUserInterfaceIdiom.tv; the case name is fixed by the platform enum it maps.
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

### `DeviceType` lint handling — RESOLVED (see Common Pitfalls #6 for the analysis)

`identifier_name` **is enabled** (it is a SwiftLint default rule and is **not** in `disabled_rules` in the root `.swiftlint.yml`) [VERIFIED: codebase .swiftlint.yml lines 1-7]. Per the owner's decision tree, because it is enabled the disable line **stays but must carry a preceding `// reason:` comment** to satisfy the `swiftlint_disable_requires_reason` custom rule (error-level) [VERIFIED: codebase .swiftlint.yml lines 171-178]. The verbatim block above shows the added `// reason:` line. Do **not** carry an unreasoned disable (that is itself a lint error), and do **not** drop the disable without handling the `tv` case (a 2-char name).

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `onGeometryChange` | `GeometryReader` in `.background` (owner's dropped `bindSize`) | Rejected by D-06 — greedy, layout-disruptive, and UIARCH-01 acceptance #1 names `onGeometryChange` explicitly |
| `deviceClient.deviceType()` for idiom | `horizontalSizeClass` for idiom branches | Rejected by D-03 — idiom branches keep device-class semantics (an iPad in split-view is still `.pad`); converting to size-class would drift split-view/landscape behavior |
| Sync `deviceType()` | Async `deviceType()` (current `isPad` is `async`) | Discretion — sync `@MainActor` is cleaner for View consumers (no `await` in body) and reducers just call it inside their MainActor effect; recommended below |

**Installation:** none — no `Package.swift` dependency change. (Package.swift edits are limited to **removing** the `AppDelegateClient` module target + its 3 dependency edges after D-10; see File Inventory.)

## Package Legitimacy Audit

**Not applicable.** This phase installs zero external packages. All replacement APIs are Apple first-party (SwiftUI/UIKit) already available on the iOS 26 target, and the only new type (`DeviceType`) is owner-provided first-party source. No registry lookup required. The only `Package.swift` change is *removal* of the `AppDelegateClient` target.

## Architecture Patterns

### System Architecture Diagram (reader geometry/gesture data flow, post-phase)

```
                 rotation / Stage Manager / split-view resize
                                   │
                                   ▼
                    ┌──────────────────────────────┐
   reader container │  .onGeometryChange(for: CGSize)│  ── single source of truth (D-05)
   (ignoresSafeArea)│   { $0.size } action: write ──┼──►  @Observable reader model
                    └──────────────────────────────┘        (PageModel or sibling)
                                                              │  containerSize: CGSize
                       ┌──────────────────────────────────────┼───────────────────────┐
                       ▼                    ▼                  ▼                        ▼
              isLandscape =        edgeWidth/Height     dual-page half-width      ControlPanel
              w > h  (D-04)        pan-clamp margins    = width / (dual ? 2:1)    layout paddings
                  │                (GestureHandler)     (placeholder sizing)      (RTL slider dir)
                  ▼                                                                    
        PageHandler.mapToPager /                     tap location ────────┐            
        mapFromPager (dual-page                      SpatialTapGesture     │            
        cover math) — isLandscape                    .location (.local) ───┤──► GestureHandler
        passed explicitly (no default)                                     │    tap-edge zones
                                                     pinch anchor           │    (< 0.2 / > 0.8 · w,
                                                     MagnifyGesture         │     RTL-aware) — fires
                                                     .startAnchor ──────────┘     only at scale==1
```

File-to-tier mapping is in the File Inventory below.

### Pattern 1: Single-source-of-truth geometry capture (D-05, D-06)
**What:** One `onGeometryChange` at the reader container writes `size` into the shared `@Observable` model; every downstream metric reads that one value.
**When to use:** The reader container, and any converted metric site where a captured size is genuinely needed (Home carousel, GalleryInfos, LiveText).
**Example:**
```swift
// Source: developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)
readerContainer
    .onGeometryChange(for: CGSize.self) { proxy in
        proxy.size
    } action: { newSize in
        pageModel.containerSize = newSize   // the ONE write
    }
// Derived, not stored:
//   var isLandscape: Bool { containerSize.width > containerSize.height }   // D-04
```
`CGSize` is `Equatable`, so `action` runs only on real changes (rotation/resize) [CITED: swiftwithmajid.com/2024/08/13/tracking-geometry-changes-in-swiftui/].

### Pattern 2: Native gesture location replacing the touch global (D-05)
**What:** `SpatialTapGesture.location` (CGPoint, `.local`) supplies tap point; `MagnifyGesture.startAnchor` (UnitPoint) supplies pinch anchor; the captured size normalizes tap fractions.
**When to use:** `ReadingView+Gestures.swift` and `GestureHandler`.
**Example:**
```swift
// Source: developer.apple.com/documentation/swiftui/spatialtapgesture
//         developer.apple.com/documentation/swiftui/magnifygesture
let singleTap = SpatialTapGesture(count: 1, coordinateSpace: .local)
    .onEnded { value in
        gestureHandler.onSingleTapGestureEnded(
            location: value.location,          // was TouchHandler.shared.currentPoint
            containerWidth: pageModel.containerSize.width,   // was DeviceUtil.absWindowW
            readingDirection: store.setting.readingDirection,
            setPageIndexOffsetAction: { jump(toPagerIndex: pageModel.index + $0) },
            toggleShowsPanelAction: { store.send(.toggleShowsPanel) }
        )
    }
let magnify = MagnifyGesture()
    .onChanged { value in
        gestureHandler.onMagnificationGestureChanged(
            value: value.magnification,        // was the bare Double
            anchor: value.startAnchor,         // UnitPoint — replaces correctScaleAnchor(point:)
            scaleMaximum: store.setting.maximumScaleFactor
        )
    }
```
**Coordinate-space equivalence (the load-bearing parity fact):** the old code stored `touch.location(in: touch.window)` (window space) and normalized by `point.x / DeviceUtil.absWindowW` (window width). `SpatialTapGesture.location` in `.local` is the modified view's own space; normalizing by the captured container width is the exact analogue **because the reader container `.ignoresSafeArea()` and fills the window**, and tap-to-turn is gated to `scale == 1` (`.gesture(tapGesture, isEnabled: gestureHandler.scale == 1)`) where local space == layout space (no `scaleEffect`/`offset` distortion). The RTL tap-edge zones (`location.x < width * 0.2` / `> width * 0.8`) and the pan-clamp margins (`width * (scale-1)/2`) map term-for-term onto the captured width/height.

### Pattern 3: Injected device-class idiom (D-03)
**What:** `isPad`/`isPhone` reads become `@Dependency(\.deviceClient).deviceType()`; reducers and views both read it.
**Recommended `DeviceClient` residual shape (discretion):**
```swift
public struct DeviceClient: Sendable {
    public let deviceType: @MainActor @Sendable () -> DeviceType   // sync; live returns DeviceType.current
}
// Reducer idiom branch:  deviceClient.deviceType() == .pad   (no await needed — sync call)
// View idiom branch:     if deviceClient.deviceType() != .pad { ... }
```
Sync `@MainActor` is recommended over the current `async` `isPad`: View consumers (TabBarView, GalleryCardCell, ReadingView chevron, etc.) read it directly in `body`; reducer `.run`/effects already run with MainActor access. Update `noop`/`unimplemented` accordingly. Idiom is a compile-time-stable fact (idiom never changes at runtime), so a non-observed read is correct.

### Pattern 4: Orientation-lock removal → OS governance (D-10)
**What:** Deleting `AppOrientationMask` + the `supportedInterfaceOrientationsFor` override makes UIKit fall back to `App/Info.plist`'s declared orientations (all 4, iPhone + iPad). No plist change.
**Verified chain:** `AppDelegate.application(_:supportedInterfaceOrientationsFor:)` returns `AppOrientationMask.current` [VERIFIED: codebase AppDelegateReducer.swift:59-61]; removing the override method means UIKit uses the Info.plist mask. `ReadingReducer.setOrientationPortrait` + the `onAppear` `enablesLandscape` branch + the `ReadingView.onChange(of: enablesLandscape)` sender all disappear together [VERIFIED: codebase ReadingReducer+Body.swift:73-97, ReadingView.swift:233-235].

### Recommended Project Structure (no new modules; net deletions)
```
AppPackage/Sources/
├── AppTools/
│   ├── DeviceUtil.swift          # DELETE (D-01)
│   ├── TouchHandler.swift        # DELETE (D-05)
│   └── DeviceType.swift          # ADD here (discretion; pure Sendable value type)
├── DeviceClient/DeviceClient.swift   # reshape → deviceType() only
├── AppDelegateClient/            # DELETE whole module (D-10) — verify no other consumer
│   ├── AppDelegateClient.swift
│   └── AppOrientationMask.swift
└── ReadingFeature/…              # gesture/geometry re-plumb (highest risk)
```

### Anti-Patterns to Avoid
- **Routing window-size getters through `DeviceClient`** — explicitly rejected by D-02; it just hides the anti-pattern behind a dependency and violates UIARCH-01 acceptance #1. Metrics go native.
- **Converting idiom branches to size-class** — rejected by D-03; would drift split-view/landscape behavior. Only *metric* reads go native.
- **Storing `isLandscape` as separate state** — derive it from the one captured size (D-04/D-05); a second source of truth can desync from the gesture math.
- **Re-adding a `GeometryReader`** for any of the 3 legacy sites — D-06/D-06b make the codebase GeometryReader-free.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Read a view's size | A `GeometryReader` + `PreferenceKey` pipe, or the dropped `bindSize` background-GR helper | `onGeometryChange(for:of:action:)` | Non-greedy, no layout distortion, `Equatable`-gated updates; D-06 mandates it |
| Tap / pinch location | The `TouchHandler` UIKit gesture-recognizer global writing `currentPoint` | `SpatialTapGesture.location` / `MagnifyGesture.startAnchor` | Native, per-gesture, correct coordinate space; kills a `.shared` singleton |
| "Is landscape?" | `UIDevice`/`UIWindowScene` orientation query (`DeviceUtil.isLandscape`) | `capturedSize.width > capturedSize.height` (D-04) | Correct under Stage Manager / split-view where orientation ≠ container shape |
| Orientation lock | UIKit `requestGeometryUpdate` + a supported-orientations mask | OS governance via `Info.plist` (all 4) + iOS Control Center rotation lock | D-09/D-10; the OS already provides per-app rotation lock |
| Window lookup for `overrideUserInterfaceStyle` | Re-vendor `DeviceUtil.keyWindow`/`anyWindow` | Inline a private window-scene lookup in `ApplicationClient` (it already side-effects) | `DeviceUtil` is deleted; this non-layout window access needs a local home, not a resurrected global |

**Key insight:** In this domain the "custom solution" is exactly the legacy being retired — a global that reaches for `UIScreen`/`UIWindow`. Every hand-rolled screen-metric read is precisely what UIARCH-01 forbids; the native APIs are both the modernization and the parity path.

## Runtime State Inventory

> This is a refactor/in-place-schema-edit phase. Categories checked explicitly.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| **Stored data** | `Setting.enablesLandscape` is a persisted field of the `@Shared(.setting)` model [VERIFIED: codebase Setting.swift:126]. Removing the stored property is **decode-safe with no migration**: Swift `Codable` ignores unknown keys on decode, so a previously-stored `enablesLandscape` key is silently dropped on the next read, and new encodes omit it. No `VersionedSchema` v2 (schema freeze holds). No data migration task. | Code edit only (remove field + init param, in place at v1). |
| **Live service config** | None — no external service embeds these strings. | None. |
| **OS-registered state** | The **orientation lock** is the only OS-facing state, and it is *not* persisted or registered — it lives in the in-memory `AppOrientationMask.current` static + the runtime `supportedInterfaceOrientationsFor` callback [VERIFIED: codebase AppOrientationMask.swift, AppDelegateReducer.swift:59-61]. `App/Info.plist` already declares all 4 orientations, so removal needs **no plist change** and leaves no stale OS registration. | Code deletion only; verify no Info.plist edit needed (confirmed all-4 already). |
| **Secrets/env vars** | None involved. | None. |
| **Build artifacts** | Deleting the `AppDelegateClient` module target requires pruning its `Package.swift` target definition + its 3 consuming dependency edges (appFeature, readingFeature, and one further edge) [VERIFIED: codebase Package.swift lines 67, 261, 375, 761, 876]; a stale `.build` may retain the removed module until a clean build. | Edit `Package.swift`; clean build to clear stale artifacts. |

**Verification note:** `AppDelegateClient`'s only `@Dependency` consumer is `ReadingReducer` and `AppOrientationMask.current`'s only reader is `AppDelegateReducer` [VERIFIED: codebase grep — no other `appDelegateClient`/`AppOrientationMask` references]. After D-10 both are gone, so the whole-module deletion is safe — but the planner must still prune the 3 `Package.swift` edges and confirm no test target references it.

## Common Pitfalls

### Pitfall 1: `scaleEffect`/`offset` distorting tap coordinates
**What goes wrong:** `SpatialTapGesture.location` is read on the reader stack, which has `.scaleEffect(scale, anchor:)` + `.offset()` applied. If the tap gesture that turns pages were enabled while zoomed, its `.local` location would be in a transformed space and the `< 0.2 / > 0.8` zones would be wrong.
**Why it happens:** Rendering transforms remap hit-test coordinates.
**How to avoid:** Preserve the existing gate — tap-to-turn fires **only at `scale == 1`** (`.gesture(tapGesture, isEnabled: gestureHandler.scale == 1)`) [VERIFIED: codebase ReadingView.swift:151]. At scale 1 there is no transform, so local == layout and the captured-width normalization is exact. Keep the double-tap/drag/magnify gestures on their existing `isEnabled:`/`highPriorityGesture` wiring so the composition (simultaneous magnify + tap + the Phase-3 paging `ScrollView`, which is `.scrollDisabled(gestureHandler.scale != 1)`) is unchanged.
**Warning signs:** Page turns triggering from the wrong screen half, or turns firing while zoomed.

### Pitfall 2: `MagnifyGesture.value` shape change vs `MagnificationGesture`
**What goes wrong:** `MagnificationGesture.onChanged` delivered a bare `CGFloat`; `MagnifyGesture` delivers a `MagnifyGesture.Value` — pass `value.magnification`, not `value`. Forgetting this compiles-but-misbehaves if a `Double` is inferred elsewhere, or fails to compile.
**Why it happens:** `MagnificationGesture` is deprecated iOS 17 → `MagnifyGesture`; the value type changed [CITED: developer.apple.com/documentation/swiftui/magnifygesture].
**How to avoid:** `GestureHandler.onMagnificationGestureChanged`/`Ended` keep their `value: Double` param; the call site passes `value.magnification`. Use `value.startAnchor` (`UnitPoint`) directly as the scale anchor — it **replaces** `correctScaleAnchor(point:)` entirely (no width division), a small simplification, not drift.
**Warning signs:** Pinch zoom anchoring at center regardless of pinch location.

### Pitfall 3: `windowW` (min-dimension) vs `absWindowW` (current-dimension) semantics
**What goes wrong:** `DeviceUtil.windowW = min(absW, absH)` is **orientation-independent** (always the short edge), while `absWindowW` is the **current** width. Reader image sizing used `windowW` [VERIFIED: codebase ReadingViewComponents.swift:179], gesture math used `absWindowW` [VERIFIED: codebase GestureHandler.swift:18,34]. Blindly mapping both to "captured container width" changes the `windowW` sites' meaning once landscape phones become reachable.
**Why it happens:** The two getters look interchangeable but encode different intents.
**How to avoid:** For **gesture math** (`absWindowW/H`) → captured container size is the exact equivalent (current dimensions). For **`ImageContainer.width`** (`windowW / (dual ? 2 : 1)`) note it sizes only the **placeholder/error** frames — the *loaded* reader image uses `.scaledToFit()` with no explicit frame [VERIFIED: codebase ReadingViewComponents.swift:252-261, 231-241, 278] — so converting it to a container-fraction (`.containerRelativeFrame` or captured-width * 0.5/1.0) affects only placeholder appearance, a benign parity delta. Document the intent per site.
**Warning signs:** Placeholder tiles the wrong width in landscape dual-page.

### Pitfall 4: `isPadWidth` (744pt breakpoint) does not equal `horizontalSizeClass == .regular`
**What goes wrong:** `isPadWidth = windowW >= 744` is a discrete width breakpoint [VERIFIED: codebase DeviceUtil.swift:13-15]; a landscape phone (now reachable) can be `.compact` width on most models but might cross/miss 744 differently than the size class does. A 1:1 swap to `horizontalSizeClass` shifts some breakpoint decisions.
**Why it happens:** Size classes and raw-point breakpoints partition the device space differently.
**How to avoid:** This is an intended, acceptable behavior change under universal orientation (consistent with D-08's "landscape phone gets the wider layout, not a regression"). For each `isPadWidth` site (`CategoryView` grid min, `ArchivesView`, `PreviewsView` font, `ControlPanel` font/row-count, `Defaults` preview/archive widths) choose `horizontalSizeClass` **or** a `containerRelativeFrame` fraction per intent, and note the site in the plan as a reviewed parity delta rather than a claimed byte-for-byte match.
**Warning signs:** A previously iPad-only layout appearing on a large landscape phone (usually the desired outcome; confirm per site).

### Pitfall 5: Losing the RTL / direction-agnostic contract in `PageHandler`
**What goes wrong:** `PageHandler.mapToPager`/`mapFromPager` take `isLandscape` with a **default of `DeviceUtil.isLandscape`** [VERIFIED: codebase PageHandler.swift:11,26]. Deleting `DeviceUtil` breaks the default; if a caller forgets to pass the new aspect-ratio flag the dual-page math silently uses a wrong value.
**Why it happens:** The default hid the dependency.
**How to avoid:** **Remove the default parameter** so `isLandscape` becomes required, and thread the D-04 aspect-ratio flag from the captured size at every call site. The existing `PageHandlerTests` already pass `isLandscape:` explicitly at every call [VERIFIED: codebase PageHandlerTests.swift], so removing the default keeps the suite green and turns the compiler into the completeness check.
**Warning signs:** Dual-page cover math wrong after rotation; compiler errors at call sites (good — they surface the missing arg).

### Pitfall 6: The `DeviceType.tv` case + `swiftlint_disable_requires_reason`
**What goes wrong:** The pasted `DeviceType` carries `// swiftlint:disable:next identifier_name` with **no reason**, which violates the error-level `swiftlint_disable_requires_reason` custom rule [VERIFIED: codebase .swiftlint.yml:171-178] — a hard build failure under the plugin.
**Analysis:** `identifier_name` is a SwiftLint **default (non-opt-in) rule** and is **not** listed in `disabled_rules` [VERIFIED: codebase .swiftlint.yml:1-7], so it is **enabled**. Its default thresholds flag the 2-character `tv` case. Per the owner's decision tree ("if enabled → add the required preceding `// reason:` comment; owner has implicitly authorized this specific disable"), the correct resolution is to **keep the disable and add a `// reason:` line** (shown verbatim in Standard Stack above). Renaming `tv` is not an option — it mirrors `UIUserInterfaceIdiom.tv`. Do not drop the disable and leave `tv` unhandled; do not carry the disable unreasoned.
**How to avoid:** Ship the `// reason:`-prefixed disable exactly as in the Standard Stack block.
**Warning signs:** Build fails on `swiftlint_disable_requires_reason`, or on `identifier_name` for `tv`.

### Pitfall 7: `AppDelegateClient` module deletion leaving dangling `Package.swift` edges / imports
**What goes wrong:** Deleting the module files without pruning `Package.swift` target + dependency edges, or leaving `import AppDelegateClient` in `AppDelegateReducer.swift`/`ReadingReducer.swift`, breaks the build.
**How to avoid:** Prune all references: the `.module(.appDelegateClient)` edges [VERIFIED: codebase Package.swift:261, 761, 876], the target definition (line 375 region), the enum case (line 67), the `import AppDelegateClient` in `AppDelegateReducer.swift:7` and `ReadingReducer.swift:14`, and `@Dependency(\.appDelegateClient)` in `ReadingReducer.swift:223`. Confirm no test target imports it.
**Warning signs:** "no such module 'AppDelegateClient'" or an unused-import lint.

## Code Examples

### Home-carousel coupling via one local `onGeometryChange` (D-07)
The carousel couples card width and the centering peek inset — both currently derive from `Defaults.FrameSize.cardCellSize.width` (`= windowW * 0.8`) and `centeringMargin = (windowW - cardWidth)/2` [VERIFIED: codebase HomeView+Sections.swift:154-163, 106]. Capture the container width once and compute both:
```swift
// Source pattern: developer.apple.com/documentation/swiftui/view/ongeometrychange(for:of:action:)
@State private var carouselWidth: CGFloat = 0
private var cardWidth: CGFloat { carouselWidth * 0.8 }
private var centeringMargin: CGFloat { (carouselWidth - cardWidth) / 2 }   // == carouselWidth * 0.1
// ...
scrollView
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { carouselWidth = $0 }
    .contentMargins(.horizontal, centeringMargin, for: .scrollContent)
    .frame(height: Defaults.FrameSize.cardCellHeight)   // cardCellHeight stays a genuine constant
```
`cardCellHeight` is a real constant and is kept (D-07). `cardPitch`/`.viewAligned`/window-rebase logic are unaffected — they already read `cardWidth` [VERIFIED: codebase HomeView+Sections.swift:155].

### `LiveTextView` Canvas without GeometryReader (D-06b — the delicate one)
Today the OCR overlay reads `proxy.size` inside a `GeometryReader` and maps normalized OCR box corners onto it (`bounds.topLeft * size`, `.frame(width: group.width * width, ...)`, `.position(...)`) [VERIFIED: codebase LiveTextView.swift:20-95]. Convert to a captured size feeding both the `Canvas` and the `ForEach(.position)` overlay:
```swift
@State private var size: CGSize = .zero
var body: some View {
    ZStack {
        Canvas { context, canvasSize in
            // Prefer Canvas's own `canvasSize` param for the fill/path math where available;
            // use captured `size` for the ForEach positions so both layers share ONE size.
            ...
        }
        ForEach(liveTextGroups) { group in
            HighlightView(text: group.text) { tapAction(group) }
                .frame(width: group.width * size.width, height: group.height * size.height)
                .position(
                    x: (group.minX + group.width / 2) * size.width,
                    y: (group.minY + group.height / 2) * size.height
                )
        }
    }
    .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
}
```
**Parity check to encode:** OCR boxes must land pixel-identically before/after. Because `Canvas`'s closure already receives its own size argument, the fill/path branch can use it directly; the `.position`/`.frame` overlay must use the *same* captured `size`. Guard against the one-frame `size == .zero` before first `onGeometryChange` (the overlay renders at 0 until the first size arrives — acceptable, same as GeometryReader's first pass, but confirm no flash).

### `GestureHandler` with injected size (makes it testable — Wave 0)
```swift
@Observable @MainActor
final class GestureHandler {
    var containerSize: CGSize = .zero   // written from the shared model / passed per call
    // was: DeviceUtil.absWindowW  →  containerSize.width
    private func edgeWidth(xAxis: Double) -> Double {
        let marginW = containerSize.width * (scale - 1) / 2
        ...
    }
    // was: point.x / DeviceUtil.absWindowW  →  location.x / containerSize.width
    func onSingleTapGestureEnded(location: CGPoint, containerWidth: CGFloat, ...) {
        let pointX = location.x
        if pointX < containerWidth * 0.2 { ... }
        else if pointX > containerWidth * (1 - 0.2) { ... }
    }
}
```
Injecting the size removes the `import AppTools` / `DeviceUtil` dependency [VERIFIED: codebase GestureHandler.swift:4,18,24,34,35,60,62] and makes `edgeWidth`/`edgeHeight`/`correctScaleAnchor`/`onSingleTapGestureEnded` pure functions of `(size, scale, anchor, location)` — directly unit-testable.

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `GeometryReader { proxy in }` for size reads | `onGeometryChange(for:of:action:)` | iOS 16 backport (surfaced WWDC24) | Non-greedy, no layout push; D-06 mandates it |
| `MagnificationGesture` (bare `CGFloat`) | `MagnifyGesture` (`.magnification`, `.startAnchor`) | Deprecated iOS 17 | Value type change; `.startAnchor` gives the anchor for free |
| `UIDevice`/`UIScreen` metric globals | Size classes + container-relative sizing | Ongoing SwiftUI direction | Correct under multitasking/Stage Manager; UIARCH-01 target |
| App-level `supportedInterfaceOrientationsFor` lock | `Info.plist` orientations + OS rotation lock | — | Universal rotation; user pins via Control Center (D-09) |

**Deprecated/outdated (being removed this phase):**
- `DeviceUtil` static global (`window*`/`screen*`/`absWindow*`/`isPad*`/`isSEWidth`/`isLandscape`) — deleted (D-01).
- `TouchHandler.shared` UIKit gesture global — deleted (D-05).
- `AppOrientationMask` + `AppDelegateClient` orientation API — deleted (D-10).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | Removing the persisted `Setting.enablesLandscape` field is decode-safe because Swift `Codable` ignores unknown keys, so no migration is needed under the v1 freeze | Runtime State Inventory | LOW — if `Setting`'s decode were strict/custom it could throw on the stale key; verify `Setting` uses synthesized `Codable` (no custom `init(from:)` rejecting unknown keys) during planning. [ASSUMED — based on standard Codable behavior; confirm Setting's decoding] |
| A2 | A sync `@MainActor deviceType()` is preferable to async for View consumers | Standard Stack / Pattern 3 | LOW — discretion item; async also works, just noisier in views |
| A3 | `identifier_name` default thresholds flag the 2-char `tv` case (hence the owner's disable is warranted) | Pitfall 6 | LOW — even if it only warned, the owner's `// reason:`-ed disable is the sanctioned resolution and is safe either way |
| A4 | The third `AppDelegateClient` `Package.swift` edge (line 876 region) is a test-target reference, not a live consumer | Runtime State Inventory / Pitfall 7 | LOW — planner must confirm which target owns each edge before deleting; a missed live consumer would break the build (surfaced immediately by compile) |

**Note:** No `[ASSUMED]` claim here concerns compliance, retention, security, or performance targets — all are structural facts confirmable at plan/execute time by the compiler or a one-line codebase check.

## Open Questions

1. **`Setting` decoding strictness (A1)**
   - What we know: `enablesLandscape` is a stored property of the `@Shared(.setting)` model; models are v1-frozen and edited in place.
   - What's unclear: whether `Setting` uses synthesized `Codable` (unknown-key-tolerant) or a custom decoder.
   - Recommendation: planner adds a one-line check of `Setting`'s conformance; if synthesized, no migration task; if custom, confirm it ignores absent/extra keys. No `VersionedSchema` v2 regardless (schema freeze).

2. **Per-site `isPadWidth` → size-class vs container-fraction (Pitfall 4)**
   - What we know: 6 metric sites use `isPadWidth`; the swap is an intended, reviewable behavior delta on newly-reachable landscape phones.
   - What's unclear: which sites want `horizontalSizeClass` (idiom-ish) vs a `containerRelativeFrame` fraction (pure metric).
   - Recommendation: per-site pick is Claude's discretion (D-02); plan should list each site with its chosen tool and mark it a reviewed parity delta, not a byte-for-byte claim.

3. **Which view owns the reader `onGeometryChange` and where `containerSize` lives (D-05)**
   - What we know: it must be one write at the reader container into the shared `@Observable` model (`PageModel` or a sibling).
   - What's unclear: `PageModel` extension vs a new sibling handler; and whether the container is the outer `ZStack` or the inner scaled stack (must be a view whose `.local` size is the untransformed reader area).
   - Recommendation: attach `onGeometryChange` to the container that also hosts the tap gesture at `scale == 1` so location and size share one space; keep it out of the `.scaleEffect`/`.offset` chain.

## Environment Availability

**Skipped — no new external dependencies.** The phase uses Apple SwiftUI/UIKit APIs already available on the iOS 26 minimum target and the existing Xcode/SwiftLint-plugin toolchain (unchanged from Phases 1–4). Build/test remains Xcode-only via the `AppPackage-Package` scheme [VERIFIED: codebase STACK.md]. No CLI tools, services, or runtimes are added or required.

## Validation Architecture

> Nyquist validation is **enabled** for this phase (`workflow.nyquist_validation: true`) [VERIFIED: .planning/config.json].

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (`@Suite`/`@Test`) [VERIFIED: codebase PageHandlerTests.swift, STACK.md] |
| Config file | `AppPackage/Tests/FeatureTests.xctestplan` |
| Quick run command | `xcodebuild test -scheme AppPackage-Package -only-testing:ReadingFeatureTests` (single-invocation; never overlap runs) |
| Full suite command | `xcodebuild test -scheme AppPackage-Package` (Xcode-only; bare `swift test` fails for this project) |

### Phase Requirements → Test Map
| Req | Behavior | Test Type | Automated Command | File Exists? |
|-----|----------|-----------|-------------------|-------------|
| UIARCH-01 | `PageHandler.mapToPager`/`mapFromPager` dual-page cover math unchanged after `isLandscape` default removal | unit | `-only-testing:ReadingFeatureTests/PageHandlerTests` | ✅ exists (passes explicit `isLandscape:` already) |
| UIARCH-01 | `containerDataSource` unchanged | unit | `-only-testing:ReadingFeatureTests/ContainerDataSourceTests` | ✅ exists |
| UIARCH-01 | `GestureHandler` pan-clamp margins (`edgeWidth`/`edgeHeight`), scale-anchor, and RTL tap-edge zones produce identical outputs for a fixed captured size vs the old `absWindowW/H` values | unit | `-only-testing:ReadingFeatureTests/GestureHandlerTests` | ❌ **Wave 0** — no `GestureHandler` tests today |
| UIARCH-01 | Dual-page eligibility flag `= width > height` (D-04) matches the old portrait=single / landscape=dual truth table (and now enables dual on landscape phone) | unit | (part of `GestureHandlerTests` or a small `LandscapeFlagTests`) | ❌ **Wave 0** |
| UIARCH-01 | `LiveTextView` OCR-box mapping pixel-identical before/after the GeometryReader→`onGeometryChange` swap | manual-verify + snapshot-if-feasible | device/sim visual check; optional SnapshotTesting | ❌ manual (Canvas rendering — automate only if a snapshot fixture is cheap) |
| UIARCH-03 | All pages rotate; reader dual-page toggles correctly on rotation; no orientation lock remains | manual UAT | device rotation of reader + grid + detail | n/a (runtime/manual) |

### Sampling Rate
- **Per task commit:** the `ReadingFeatureTests` quick run (adds `GestureHandlerTests` once written).
- **Per wave merge:** full suite green.
- **Phase gate:** full suite green before `/gsd-verify-work`; plus device rotation UAT for UIARCH-03 (rotate reader in portrait/landscape single & dual-page, RTL; rotate grid to confirm ~4-column landscape phone; confirm no orientation "snap-back").

### Wave-0 Gaps
- [ ] `AppPackage/Tests/ReadingFeatureTests/GestureHandlerTests.swift` — **new**. Baseline-lock (Wave-0 method from Phases 1–4): (1) refactor `GestureHandler` to take an injected `containerSize`/`location` (pure methods), then (2) assert the new pure outputs equal the pre-swap `DeviceUtil.absWindowW/H`-based results for representative sizes (portrait phone, landscape phone, iPad both orientations) and scales — covering `edgeWidth`/`edgeHeight` clamps, `correctScaleAnchor`↔`MagnifyGesture.startAnchor` equivalence, and the `< 0.2 / > 0.8` RTL tap-zone decisions.
- [ ] `PageHandlerTests` — extend the existing suite with the D-04 aspect-ratio flag as the `isLandscape` source (the maps are already frozen; add cases proving the flag threads through unchanged and that removing the `DeviceUtil` default is behavior-neutral).
- [ ] Framework install: none — `ReadingFeatureTests` target already exists [VERIFIED: codebase AppPackage/Tests/ReadingFeatureTests/].

**Parity-harness recommendation:** treat the reader gesture/geometry re-plumb as its own wave with a Wave-0 test task first (lock `GestureHandler` behavior with the size injected but still reading old values), then swap `DeviceUtil`→captured-size and confirm the locked tests stay green. This mirrors the DEP-05 `PageHandlerTests` precedent exactly.

## Security Domain

> `security_enforcement: true`, ASVS level 1 [VERIFIED: .planning/config.json].

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | Untouched — no auth surface in this phase |
| V3 Session Management | no | Untouched |
| V4 Access Control | no | Untouched |
| V5 Input Validation | no | No new external input; gesture coordinates are OS-supplied, not untrusted network data |
| V6 Cryptography | no | Untouched |

**Assessment:** This phase adds **no** security-relevant surface. Critically, the orientation lock being removed is **not a security control** — D-09 explicitly distinguishes it from Phase 7's auto-lock/privacy-mask work (UIARCH-04/05), which *is* security-relevant and is **out of scope here**. The background-blur privacy mask and the biometric auto-lock are untouched by Phase 5. No threat model changes.

### Known Threat Patterns for this stack
None introduced. (The one adjacent concern — that removing an orientation lock could expose content — does not apply: orientation is not a confidentiality boundary, and the privacy blur that *is* the confidentiality control remains in place until Phase 7.)

## Project Constraints (from CLAUDE.md / AGENTS.md)

- **Reducer naming:** `Feature` suffix (project override); follow module-local suffix. `ReadingReducer`/`AppReducer` keep their existing names.
- **SwiftLint-as-error, no suppression** without explicit permission — the `DeviceType.tv` disable is the **one** owner-authorized exception and **must** carry a `// reason:` comment (Pitfall 6).
- **New module `.swiftlint.yml`:** not triggered — this phase adds no module (net deletions); `DeviceType` lands in an existing module (`AppTools` recommended).
- **Labeled localized-format args / non-translated keys every-locale:** the `enablesLandscape` toggle's localized key is **removed** with the toggle (D-10) — remove its `.xcstrings` entry across all locales per the catalog conventions; no new localized numeric args added.
- **Confirmation dialog/alert placement:** no dialogs added; `AlertView` width conversion (metric read) must not move any existing `.alert`/`.confirmationDialog` anchor.
- **Local project reference privacy / no absolute home paths:** honored — this document names no external project and uses only repository-relative paths.
- **Logger placement:** if any touched file adds logging, declare a `private let logger` at file top (init-only `Logger+`).
- **Remove emptied actions:** deleting `setOrientationPortrait` must remove the action case *and* all call sites (ReadingView `onChange` sender + reducer body branch) — no empty stub.

## Sources

### Primary (HIGH confidence)
- **EhPanda codebase** (cited inline as `[VERIFIED: codebase <file:line>]`): `DeviceUtil.swift`, `TouchHandler.swift`, `GestureHandler.swift`, `DeviceClient.swift`, `AppDelegateClient.swift`, `AppOrientationMask.swift`, `AppDelegateReducer.swift`, `ReadingView.swift`, `ReadingView+Gestures.swift`, `ReadingViewComponents.swift`, `ReadingReducer.swift` / `+Body.swift`, `PageHandler.swift`, `PageHandlerTests.swift`, `LiveTextView.swift`, `HomeView+Sections.swift`, `ControlPanel.swift`, `Defaults+Runtime.swift`, `Setting.swift`, `ApplicationClient.swift`, `RootView.swift`, `Package.swift`, `.swiftlint.yml`, `.planning/config.json`.
- Apple Developer Documentation — `onGeometryChange(for:of:action:)`, `SpatialTapGesture`, `MagnifyGesture`, `containerRelativeFrame(_:)`.

### Secondary (MEDIUM confidence)
- Swift with Majid, "Tracking geometry changes in SwiftUI" (2024-08-13) — `onGeometryChange` availability (iOS 16 backport), `Equatable`-gated `action`.

### Tertiary (LOW confidence)
- None load-bearing. All API-availability claims cross-checked against the iOS 26 target (every API ≤ iOS 17, so available regardless).

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all APIs Apple first-party and available on iOS 26; `DeviceType` is owner-provided verbatim.
- Architecture: HIGH — the codebase is fully scouted; every seam has cited file:line evidence and a locked decision.
- Pitfalls: HIGH — the parity-sensitive coordinate-space, value-type, breakpoint, and lint issues are each grounded in specific source lines.
- Validation: HIGH — existing `ReadingFeatureTests` (`PageHandlerTests`/`ContainerDataSourceTests`) establish the exact Wave-0 pattern to extend; the one gap (`GestureHandlerTests`) is clearly specified.

**Research date:** 2026-07-13
**Valid until:** ~2026-08-13 (stable — first-party APIs, no fast-moving deps; the codebase is the source of truth and is under active change on `feature/gsd-phase-5`).
