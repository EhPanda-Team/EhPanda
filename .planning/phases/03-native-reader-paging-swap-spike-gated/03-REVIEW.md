---
phase: 03-native-reader-paging-swap-spike-gated
reviewed: 2026-07-12T00:00:00Z
depth: standard
files_reviewed: 9
files_reviewed_list:
  - AppPackage/Package.swift
  - AppPackage/Sources/HomeFeature/HomeView+Sections.swift
  - AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift
  - AppPackage/Sources/ReadingFeature/ReadingView.swift
  - AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift
  - AppPackage/Sources/ReadingFeature/Support/PageModel.swift
  - AppPackage/Tests/ReadingFeatureTests/.swiftlint.yml
  - AppPackage/Tests/ReadingFeatureTests/ContainerDataSourceTests.swift
  - AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift
findings:
  critical: 0
  warning: 4
  info: 3
  total: 7
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-07-12T00:00:00Z
**Depth:** standard
**Files Reviewed:** 9
**Status:** issues_found

## Summary

Reviewed the native-paging swap (DEP-05: SwiftUIPager → stock SwiftUI `ScrollView`/`scrollPosition(id:)`) across the Home carousel (`CardSlideSection`), the reader's vertical list (`AdvancedList`) and horizontal pager (`ReadingView.horizontalPagingList`), the new `PageModel` index source, `Package.swift`'s dependency removal, and the frozen regression tests (`PageHandlerTests`, `ContainerDataSourceTests`).

`Package.swift`'s SwiftUIPager removal is clean (package, product alias, and all three target dependencies gone; no dangling references). `PageHandlerTests`/`ContainerDataSourceTests` were hand-traced against the frozen `PageHandler.mapToPager`/`mapFromPager` and `containerDataSource` implementations and are internally correct — every asserted value matches the source math, including the last-page clamp and cover-exception edge cases. `PageModel` and `ReadingView+Gestures.swift` are straightforward and defect-free.

The carousel's sliding-window math (`CardSlideSection`) is sound for a *stable* gallery list (hand-verified the rebase arithmetic with concrete numbers), but the `@State` window/position variables are seeded once at construction and never resynchronized if the underlying `galleries` array changes shape while the view stays mounted — a reachable path via Home's manual refresh button. On the reader side, both paging surfaces use *position*-based ids into `containerDataSource(setting:isLandscape:)`, but nothing remaps `pageModel.index`/`scrollPositionID` when a setting that reshapes that data source (dual-page mode, cover exception, reading direction) changes mid-session through the live-bound reading-setting sheet — the exact class of bug the reader's own resume-seeding comment describes as unacceptable, just triggered by a different event. `AdvancedList` also seeds its scroll position only in `.onAppear` rather than at construction (unlike the horizontal path, which explicitly seeds at `init` to avoid a page-1 flash), and carries a vestigial `ScrollViewReader`/`proxy` that no code path uses. A few smaller dead-code/duplication items round out the Info section.

## Warnings

### WR-01: Carousel sliding-window state goes stale if `galleries` reshapes while mounted

**File:** `AppPackage/Sources/HomeFeature/HomeView+Sections.swift:24-28,52-53,126-143`
**Issue:** `windowBase` and `scrollPositionID` are `@State`, seeded once from `galleries.count` at `init` (line 53: `galleries.count * middleBlock + $0`) and rebased only in terms of *the current* `galleries.count` at line 139-142. SwiftUI reuses the same `@State` storage across re-renders of the same view identity — the `State(initialValue:)` in `init` does not re-run when the parent passes a new `galleries` array. `CardSlideSection` is only ever un-mounted while `store.popularGalleries.isEmpty` (`HomeView.swift:29`), so a subsequent fetch that keeps the array non-empty but changes its size does **not** remount the carousel. This is directly reachable: `HomeView`'s toolbar refresh button (`HomeView.swift:119-128`) sends `.fetchAllGalleries` unconditionally, even while the carousel is visible with a non-empty array, and `fetchPopularGalleriesDone` re-shuffles/re-trims to a new count of 1-6 (`HomeReducer+Body.swift:108-121`).
Concretely: with `windowBase` and `scrollPositionID` computed against the *old* count, `logicalIndex(of:)` (which divides/mods by the *new* `galleries.count`) can map the very same buffered id to a different card than what was focused before the refresh — the code's own invariant comment ("only ever shifted by whole blocks (multiples of `galleries.count`)") no longer holds once `galleries.count` itself changes. No crash occurs (the modulo keeps indices in range), but the focused/reported card and gradient can silently jump to the wrong gallery after a manual refresh.
**Fix:** Reseed the window state whenever the gallery count changes, e.g.:
```swift
.onChange(of: galleries.count) { _, newCount in
    guard newCount > 0 else { return }
    windowBase = 0
    let clamped = min(max(pageIndex, 0), newCount - 1)
    scrollPositionID = newCount * middleBlock + clamped
}
```

### WR-02: Reader position ids aren't remapped when `containerDataSource` reshapes mid-session

**File:** `AppPackage/Sources/ReadingFeature/ReadingView.swift:181-221`
**Issue:** `horizontalPagingList` treats `pageModel.index` / `scrollPositionID` as raw *positions* into `store.state.containerDataSource(setting:isLandscape:)` (per the file's own comment at lines 177-180). That data source's shape depends on `setting.enablesDualPageMode`, `setting.exceptCover`, and `setting.readingDirection`. The reading-setting sheet writes the same live `@Shared(.setting)` storage `ReadingView` reads (see the doc comment on `setting` at lines 20-22), so toggling "Dual Page Mode" or "Except Cover" — or rotating the device while dual-page is enabled — reshapes `containerDataSource` *while the reader is open*, but nothing recomputes `pageModel.index`/`scrollPositionID` to keep pointing at the same reading page. Position N under the old shape (e.g. a `[1,3,5,...]` dual-page stride) generally does not correspond to position N under the new shape (e.g. `[1,2,3,...]` single-page), so the pager can silently reposition to an unrelated page. This is exactly the failure mode `jump(toPagerIndex:)`'s doc comment (line 308-312) says was fixed for resume-seeding ("must be positioned at construction or every session would open at page 1") — it just isn't covered for the reshape-while-open case.
**Fix:** Capture the current reading page before the reshape and re-derive the pager index after it, mirroring what `setPageIndex(sliderValue:)` already does:
```swift
.onChange(of: [store.setting.enablesDualPageMode, store.setting.exceptCover, store.setting.readingDirection == .vertical]) { _, _ in
    setPageIndex(sliderValue: pageHandler.sliderValue)
}
```
(or equivalent — key off whichever setting properties feed `containerDataSource`).

### WR-03: `AdvancedList` seeds its scroll position on `.onAppear`, not at construction — resume flash in vertical mode

**File:** `AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift:6,15-26,38`
**Issue:** `scrollPositionID` (line 6) has no seeded initial value; it's only set the first time `.onAppear` fires (line 38: `tryScrollTo(id: pagerModel.index + 1, proxy: proxy)`). Contrast with `ReadingView.init`, which explicitly seeds `_scrollPositionID = State(initialValue: pagerIndex)` at construction (`ReadingView.swift:52`) specifically so the horizontal pager "opens on the resume page" without a page-1 flash (see the comment at `ReadingView.swift:42-46`, which states plainly that seeding after appearance was rejected: "the pager must be positioned at construction or every session would open at page 1"). `AdvancedList` (used for `.vertical` reading direction) reintroduces exactly that rejected pattern: a large `LazyVStack`/`ScrollView` opening with no `scrollPositionID` set, then jumping to the resume id once `.onAppear` runs, risking a visible flash to the top of the list before it snaps to the saved page for vertical-direction sessions.
**Fix:** Seed `scrollPositionID` from `page.index` in `AdvancedList.init`, the same way `ReadingView` does for the horizontal path:
```swift
init<Data: RandomAccessCollection>(
    page: PageModel, data: Data,
    id: KeyPath<Element, ID>, spacing: CGFloat, gesture: G,
    @ViewBuilder content: @escaping (Element) -> PageView
) where Data.Index == Int, Data.Element == Element {
    self.pagerModel = page
    self.data = .init(data)
    ...
    _scrollPositionID = State(initialValue: page.index + 1)
}
```

### WR-04: Vestigial `ScrollViewReader`/`proxy` — dead parameter, unnecessary wrapper

**File:** `AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift:29,56-60`
**Issue:** `body` wraps everything in `ScrollViewReader { proxy in ... }` and threads `proxy: ScrollViewProxy` through to `tryScrollTo(id:proxy:)`, but that function never calls `proxy.scrollTo` — it only ever does `scrollPositionID = id` (line 58). Scrolling is driven entirely by the `.scrollPosition(id: $scrollPositionID, anchor: .center)` binding (line 40); the `ScrollViewReader` and its `proxy` parameter do nothing. This is leftover from before the migration to `.scrollPosition(id:)`-based scrolling and should be removed — keeping it invites a future reader to think programmatic `proxy.scrollTo` calls are still in play.
**Fix:**
```swift
var body: some View {
    ScrollView(showsIndicators: false) {
        LazyVStack(spacing: spacing) {
            ForEach(data, id: id) { index in
                content(index).gesture(gesture)
            }
        }
        .scrollTargetLayout()
        .onAppear(perform: { tryScrollTo(id: pagerModel.index + 1) })
    }
    .scrollPosition(id: $scrollPositionID, anchor: .center)
    .onScrollPhaseChange { _, newValue in
        if newValue == .idle, let index = scrollPositionID {
            performingChanges = true
            pagerModel.update(.new(index: index - 1))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                performingChanges = false
            }
        }
    }
    .onChange(of: pagerModel.index) { _, newValue in
        tryScrollTo(id: newValue + 1)
    }
}

private func tryScrollTo(id: Int) {
    if !performingChanges {
        scrollPositionID = id
    }
}
```

## Info

### IN-01: Unused `@Bindable` locals in `ReadingView.body`

**File:** `AppPackage/Sources/ReadingFeature/ReadingView.swift:75-76`
**Issue:** `body` declares `@Bindable var bindableLiveTextHandler = liveTextHandler` and `@Bindable var bindablePageHandler = pageHandler`, but neither is referenced anywhere in the rest of `body` — only `content` (lines 124-125) and `pageAndAutoPlayTriggers` need their own local `@Bindable` copies, and they declare them separately. These two locals are dead weight, likely left over from an earlier version of `body` where `content` was inlined.
**Fix:** Remove the two unused declarations at lines 75-76.

### IN-02: `0.2`-second settle-debounce duplicated across three sites

**File:** `AppPackage/Sources/ReadingFeature/ReadingView.swift:212-214,326-328`; `AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift:44-47`
**Issue:** The `performingChanges` reset delay (`DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)`) is copy-pasted verbatim in three places across two files, all implementing the same "ignore programmatic scroll echoes for N seconds" pattern. A future change to this tuning constant would need to be applied in three places by hand.
**Fix:** Hoist the constant (and ideally the reset closure) into one shared location, e.g.:
```swift
private let scrollEchoGuardDuration: TimeInterval = 0.2
```

### IN-03: Unused `Element: Equatable` generic constraint

**File:** `AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift:4`
**Issue:** `AdvancedList<Element, ID, PageView, G>` requires `Element: Equatable`, but no equality comparison on `Element` occurs anywhere in the file — `ForEach(data, id: id)` only needs `ID: Hashable`. The constraint is unused and slightly narrows what can be passed as `Element`.
**Fix:** Drop `Element: Equatable` from the `where` clause unless a specific caller genuinely needs it (none of the current call sites do).

---

_Reviewed: 2026-07-12T00:00:00Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
