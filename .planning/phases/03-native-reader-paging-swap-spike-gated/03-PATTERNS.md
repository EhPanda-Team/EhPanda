# Phase 3: Native Reader Paging Swap (spike-gated) - Pattern Map

**Mapped:** 2026-07-11
**Files analyzed:** 10 (8 modified, 1 new, cleanup edits across 3)
**Analogs found:** 9 / 10 (the tripled-buffer carousel loop has no in-repo analog)

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `ReadingFeature/ReadingView.swift` (`Pager` @143) | view (reader paging) | event-driven (scroll + programmatic index) | `ReadingFeature/Support/AdvancedList.swift` (same module, already native `ScrollView`+`.scrollPosition`) | exact |
| `ReadingFeature/Support/AdvancedList.swift` | view (vertical reader) | event-driven | itself (re-seam `Page`→index only) | exact (in-place) |
| `ReadingFeature/Support/PageHandler.swift` | utility (pure mapping) | transform | itself (unchanged; consumer re-seamed) | exact (in-place) |
| `ReadingFeature/Support/AutoPlayHandler.swift` | utility (timer) | event-driven | itself (swap closure body) | exact (in-place) |
| `ReadingFeature/ReadingView+Gestures.swift` | view (gestures) | event-driven | itself (`page.update`→index write) | exact (in-place) |
| `ReadingFeature/Support/GestureHandler.swift` | utility (transform state) | transform | itself (unchanged; `scale` gates `.scrollDisabled`) | exact (in-place) |
| `HomeFeature/HomeView+Sections.swift` (`CardSlideSection` @41) | view (carousel) | event-driven + infinite loop | `AdvancedList.swift` (scroll idioms); **no analog** for tripled-buffer loop | partial |
| `AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift` | test (new target) | unit/transform | `Tests/DownloadsFeatureTests/` target + its `.swiftlint.yml` + `Package.swift` `.testTarget` | role-match |
| `AppPackage/Package.swift` (dep + 3 target-deps) | config | build | Phase 2 WaterfallGrid dep removal | role-match |
| `SettingFeature/Components/AboutView.swift` (@161-164) + `Constant.xcstrings` (@508/550) | resource/view (ack row) | config | Phase 2 WaterfallGrid acknowledgement removal | role-match |

## Pattern Assignments

### `ReadingView.swift` — reader horizontal paging (view, event-driven)

**Analog:** `AdvancedList.swift` — THE in-repo native-paging reference. It is already `ScrollView`+`LazyVStack`+`.scrollTargetLayout()`+`.scrollPosition(id:)`+`.onScrollPhaseChange` with the programmatic-write feedback guard. Reuse its shape verbatim, changing `LazyVStack`→`LazyHStack`, adding `.scrollTargetBehavior(.paging)`, `.containerRelativeFrame(.horizontal)`, `.scrollDisabled(scale != 1)`, and the `layoutDirection` RTL flip.

**Current Pager to replace** (`ReadingView.swift:143-155`):
```swift
Pager(
    page: page,
    data: store.state.containerDataSource(setting: store.setting, isLandscape: DeviceUtil.isLandscape),
    id: \.self,
    content: imageStack
)
.horizontal(store.setting.readingDirection == .rightToLeft ? .endToStart : .startToEnd)
.swipeInteractionArea(.allAvailable)
.allowsDragging(gestureHandler.scale == 1)
```
Note the vertical branch already sits beside it (`ReadingView.swift:129-141`) and already carries `.scrollDisabled(gestureHandler.scale != 1)` — the replacement should make the horizontal branch symmetric with it. The whole ZStack has `.id(store.forceRefreshID)` (`:166`) — keep the new paging ScrollView inside that identity so rotation rebuilds it (RESEARCH Pitfall 4).

**Scroll-position binding + feedback guard to COPY VERBATIM** — from `AdvancedList.swift:6-7, 41-61` (RESEARCH says reuse this exact idiom):
```swift
@State var performingChanges = false
@State var scrollPositionID: Int?
// ...
.scrollPosition(id: $scrollPositionID, anchor: .center)
.onScrollPhaseChange { _, newValue in
    if newValue == .idle, let index = scrollPositionID {
        performingChanges = true
        pagerModel.update(.new(index: index - 1))   // becomes: sharedIndex = index - 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            performingChanges = false
        }
    }
}
.onChange(of: pagerModel.index) { _, newValue in    // becomes onChange(of: sharedIndex)
    tryScrollTo(id: newValue + 1, proxy: proxy)
}
// ...
private func tryScrollTo(id: Int, proxy: ScrollViewProxy) {
    if !performingChanges { scrollPositionID = id }
}
```
The `performingChanges` flag + `+1`/`-1` id offset (list ids are 1-based reading pages) is the anti-feedback-loop guard the reader's new writers (autoplay/slider/tap/resume) must route through.

**Reducer fan-out to preserve unchanged** (`ReadingView.swift:208-214`):
```swift
.onChange(of: page.index) { _, newValue in
    let newValue = pageHandler.mapFromPager(
        index: newValue, pageCount: store.gallery.pageCount, setting: store.setting
    )
    pageHandler.sliderValue = .init(newValue)
    store.send(.syncReadingProgress(.init(newValue)))
}
```
Re-seam `page.index` → the shared plain index; `mapFromPager` and `.syncReadingProgress` are untouched (reducer contract parity).

---

### `AdvancedList.swift` — vertical path re-seam (lowest risk)

**Analog:** itself. Replace the `Page` param (`:9, :17, :21`) and its two touch points — `pagerModel.index` reads (`:39, :52`) and `pagerModel.update(.new(index:))` write (`:45`) — with the shared index binding. The `+1`/`-1` offset and `performingChanges` guard stay exactly as shown above. This is the smallest, first-to-land piece.

---

### `PageHandler.swift` — pure mapping (utility, unchanged)

**Analog:** itself. `mapToPager`/`mapFromPager` (`:11-33`) are pure and stay byte-for-byte identical; only their *caller* switches from `page.index` to the plain index. This file is the unit-tested core (see test target below). Signatures for the test:
```swift
func mapFromPager(index: Int, pageCount: Int, setting: Setting, isLandscape: Bool = DeviceUtil.isLandscape) -> Int
func mapToPager(index: Int, setting: Setting, isLandscape: Bool = DeviceUtil.isLandscape) -> Int
```
Cover-exception branch to cover in tests (`:17-23`): `result = exceptCover ? index*2 : index*2+1`, then `result+1 == pageCount ? pageCount : result`.

---

### `AutoPlayHandler.swift` — timer advance (utility, swap closure)

**Analog:** itself. `setPolicy(_:updatePageAction:)` (`:20-34`) stays; only the `updatePageAction` closure passed in from `ReadingView` changes from `page.update(.next)` to a shared-index advance routed through the `performingChanges` write path (RESEARCH Pattern 2 / Code Examples).

---

### `ReadingView+Gestures.swift` — tap-to-turn (view, event-driven)

**Analog:** itself. The RTL-aware edge tap (`:12-13`):
```swift
setPageIndexOffsetAction: {
    let newValue = page.index + $0
    page.update(.new(index: newValue))
}
```
becomes a shared-index write (guarded). Keep `GestureHandler.onSingleTapGestureEnded`'s existing RTL offset inversion untouched (RESEARCH Pitfall 6). `magnify`/`pan`/`dismiss` gestures and the `scale > 1` gating (`ReadingView.swift:159-164`) are parity-preserved.

---

### `HomeView+Sections.swift` — `CardSlideSection` carousel (view, infinite loop)

**Analog:** `AdvancedList.swift` for the scroll/`.scrollPosition`/`.onScrollPhaseChange` idioms; **NO in-repo analog** for the tripled-buffer infinite loop (D-08) — use RESEARCH Pattern 4 + Phase 2's D-31 transaction-suppression idiom.

**Current Pager to replace** (`HomeView+Sections.swift:42-62`):
```swift
Pager(page: page, data: galleries) { gallery in
    Button { navigateAction(gallery) } label: {
        GalleryCardCell(gallery: gallery, currentID: currentID, colors: colors,
                        webImageSuccessAction: { webImageSuccessAction(gallery.gid, $0) })
            .tint(.primary).multilineTextAlignment(.leading)
    }
}
.preferredItemSize(Defaults.FrameSize.cardCellSize)
.interactive(opacity: 0.2).itemSpacing(20)
.loopPages().pagingPriority(.high)
.synchronize($pageIndex, $page.index)
.frame(height: Defaults.FrameSize.cardCellHeight)
```
Mapping to stock (D-06/D-08): `.preferredItemSize`+`.itemSpacing(20)` → item `.containerRelativeFrame` sizing + `LazyHStack(spacing: 20)`; `.interactive(opacity: 0.2)` → `.scrollTransition { c, p in c.opacity(p.isIdentity ? 1 : 0.2) }`; peek → `.scrollClipDisabled()`; `.loopPages()` → tripled buffer + idle-phase suppressed re-center; `.synchronize($pageIndex, $page.index)` → map buffer id → logical index → the outward `$pageIndex` binding (MANDATORY sync).

---

### `AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift` — NEW test target

**No `ReadingFeatureTests` target exists today.** The planner must add it. Analogs below give the exact plumbing.

**1. Module enum case** — add beside the other test cases (`Package.swift:112-123`):
```swift
case readingFeatureTests = "ReadingFeatureTests"
```

**2. `.testTarget` declaration** — copy the `downloadsFeatureTests` shape (`Package.swift:857-871`, `.parserFeatureTests` shown):
```swift
.testTarget(
    module: .readingFeatureTests,
    dependencies: [
        .module(.testingSupport),
        .module(.readingFeature),
        .module(.appModels),
        .module(.appTools)
    ],
    plugins: swiftLintPlugins
),
```
(The `testTarget(module:dependencies:...)` helper is defined at `Package.swift:221-247`; `swiftLintPlugins` is the existing shared plugin list — every test target already passes it.)

**3. Module `.swiftlint.yml`** — every `Tests/<Module>Tests/` dir carries a one-line file. Copy `Tests/DownloadsFeatureTests/.swiftlint.yml` verbatim to `Tests/ReadingFeatureTests/.swiftlint.yml`:
```yaml
parent_config: ../../../.swiftlint.yml
```
(Satisfies the AGENTS.md "new module needs `.swiftlint.yml` with `parent_config`" rule; depth `../../../` is correct for `AppPackage/Tests/<Module>`.)

**4. Test body** — Swift Testing (`@Suite`/`@Test`/`#expect`), table-driven over single-page / dual-page / exceptCover cover-exception / boundary (`result+1==pageCount`) / `mapToPager↔mapFromPager` round-trip, per RESEARCH Validation Architecture. No `Page` object needed — call `PageHandler()` directly.

---

## Shared Patterns

### Programmatic-write feedback guard (applies to ALL reader index writers)
**Source:** `AdvancedList.swift:6-7, 42-61` (the `performingChanges` flag + 0.2s settle + `!performingChanges` gate).
**Apply to:** the reader's horizontal ScrollView and every writer (autoplay, slider, tap, resume-seed). This is the single most-reused idiom of the phase — the anti-feedback-loop mechanism. Excerpt above under `ReadingView.swift`.

### Rotation rebuild identity
**Source:** `ReadingView.swift:166` — `.id(store.forceRefreshID)` already wraps the paging container.
**Apply to:** keep the new paging ScrollView inside this identity (RESEARCH Pitfall 4); do NOT add a new orientation global (D-12 fence).

### Dependency + acknowledgement removal (Phase 2 WaterfallGrid mirror)
**Apply to:** gated on D-02 go. Three edits:
- `Package.swift` — delete dep decl (`:21`), the `swiftUIPager` static (`:47`), and 3 `.targetDependency(.swiftUIPager)` entries: `:299` (**STALE** — AppFeature target, no import), `:718` (homeFeature, real), `:780` (readingFeature, real). Then regenerate `Package.resolved` via `swift package resolve`.
- `AboutView.swift:161-164` — delete the `.init(urlString: ...SwiftUIPagerLink, text: ...SwiftUIPager)` acknowledgement row.
- `SettingFeature/Resources/Constant.xcstrings` — delete keys `acknowledgement.swiftUIPager` (`:508`) and `acknowledgement.swiftUIPager_link` (`:550`); both are `shouldTranslate:false` proper-noun/URL entries with all-locale copies — delete the whole entries cleanly (AGENTS.md non-translated-key rule; matches Phase 2 removal shape).

## No Analog Found

| File/Concern | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `CardSlideSection` tripled-buffer infinite loop | view | infinite loop | No in-repo infinite-paging construct exists; SwiftUIPager's `.loopPages()` was the only one. Use RESEARCH Pattern 4 (tripled buffer + idle-phase suppressed re-center) + Phase 2 D-31 transaction-suppression idiom. This is the highest-risk parity item and the most likely D-02 gap. |

## Metadata

**Analog search scope:** `AppPackage/Sources/{ReadingFeature,HomeFeature,SettingFeature}`, `AppPackage/Tests/`, `AppPackage/Package.swift`, `SettingFeature/Resources/Constant.xcstrings`
**Files scanned:** ~12 source + config files
**Pattern extraction date:** 2026-07-11
