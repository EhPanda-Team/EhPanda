---
phase: 261123-c7r-cover-tap-reads-on-every-gallery-list-and-grid
plan: 01
subsystem: AppComponents / DetailFeature / gallery list hosts
tags: [gallery-list, tap-actions, reading, tca, swift-testing, xcuitest]
requires: [D89 Library tap actions (8c19f5f0f)]
provides: [D146 cover tap reads, GalleryReadingFeature, galleryReadCover()]
affects: [every GalleryList host, Downloads row and grid, AppReducer reading flush]
key-files:
  created:
    - AppPackage/Sources/DetailFeature/GalleryReading/GalleryReadingFeature.swift
    - AppPackage/Sources/DetailFeature/GalleryReading/View+GalleryReading.swift
    - AppPackage/Tests/DetailFeatureTests/GalleryReadingFeatureTests.swift
  removed:
    - AppPackage/Sources/FavoritesFeature/FavoritesReducer+Reading.swift
  modified:
    - AppPackage/Sources/AppComponents/GalleryReadInteraction.swift
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift
    - FrontPage, Popular, Toplists, Watched, History, Search, DetailSearch reducers and views
    - AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift and FavoritesView.swift
    - AppPackage/Sources/HomeFeature/HomePath.swift and HomeSheetFeature.swift
    - AppPackage/Sources/SearchFeature/SearchPath.swift
    - AppPackage/Sources/DetailFeature/GalleryNavigation.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
    - AppPackage/Package.swift
    - AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift
    - AppPackage/Tests/FavoritesFeatureTests/ReadingEntryTests.swift
    - EhPandaUITests (tap helpers and five suites)
decisions:
  - "D146 (owner, 2026-11-23): a single tap on a gallery's cover reads; anywhere else opens Detail; double tap still reads."
  - "Scope (owner): every gallery list and grid in both layouts, not only Library. Home's own sections are excluded."
  - "VoiceOver (owner): each entry stays one element; default activation opens Detail, the Read action reads."
  - "Architecture (owner): one shared child reducer, GalleryReadingFeature; Downloads keeps its local reader route."
status: complete
commits:
  - 1bdf89bef lists: read from a tap on the cover
---

# Quick Task 261123-c7r: cover tap reads on every gallery list and grid

## Why

The owner reported that tapping a Downloads row and tapping its thumbnail both opened Detail. That
was not a misrecognized gesture: D89 gave the whole entry one single-tap route (Detail) and a
double-tap route (reading), and no GSD record assigned the cover anything of its own. The owner then
decided D146: a cover tap reads, on every gallery list and grid.

## What changed

- **One gesture, location-aware.** `GalleryReadInteraction` keeps D89's exclusive double-/single-tap
  arbitration, with the single tap now a `SpatialTapGesture`. A tap inside the cover reads, anywhere
  else opens Detail. Cells mark their cover with `galleryReadCover()`, an anchor preference that the
  modifier resolves with `onGeometryChange` (GeometryReader is banned), so cells hold no interaction
  state. The row and grid cells are shared, so Downloads gets the behavior with no change of its own.
- **Shared reader launcher.** `GalleryReadingFeature` (DetailFeature) replaces Favorites' private
  reading reducer: it resolves a local manifest first and otherwise fetches the remote gallery's
  preview configuration, language and first preview URLs, ignores a result whose open was
  superseded, shows a failure toast, and presents the reader. Its `galleryReading(_:)` modifier
  presents the reader and the toast.
- **Every list host embeds it.** Front Page, Popular, Toplists, Watched, History, Search results,
  Detail's tag search and Favorites: list `loadingState` shows loading while a source resolves, a
  Detail tap (and a Toplists type or Favorites category switch) cancels the pending open. Supplying
  `readAction` also brings D89's double-tap reading and the row menu's Read item to these lists.
- **Background flush.** Each reader is registered with `AppReducer.readingFlushEffects` through
  `HomePath.State.readingFlushAction`, `HomeSheetFeature`, `SearchPath.State.readingFlushAction`,
  `GalleryPath` (`.detailSearch`) and Favorites, so a force-quit keeps the last page.
- Favorites' now-unused toast, destination case, actions and package dependencies were removed.

## Verification

- Build (EhPanda scheme, iOS Simulator): succeeded with zero warnings and errors.
- Strict SwiftLint over all 31 changed Swift files (root config) and the UI-test files (their own
  config): 0 violations.
- FeatureTests plan without VisualSnapshotTests, on a new `EhPanda iPhone Air (cover-read)`
  simulator (iOS 27.2): 3355 passed, 0 failed. New cases: six `GalleryReadingFeatureTests` (local,
  remote, failure, cancelled open, flush action, Detail search flush), four Favorites
  `ReadingEntryTests`, and `backgroundFlushesListReadingProgress` over all five host placements.
- The first runs crashed the Detail test process: the new tests had not stubbed the reader's
  haptics, date and launch-automation dependencies. Fixed in the test; no source change.
- Native UI tests, `UITests` plan, new `EhPanda iPhone Air (cover-read)` and
  `EhPanda iPad Pro 11-inch (M5) (cover-read)` simulators (iOS 27.2):
  - iPhone: `LibraryPresentationUITests` 5/5 (Favorites and Downloads, list and grid: a tap outside
    the cover opens Detail, a double tap reads, a cover tap reads with no Detail beneath, the row
    menu's Read), `GalleryLayoutUITests` 4/4, `GalleryCardUITests` 3/3.
  - iPad: `LibraryPresentationUITests` 5/5 and `GalleryLayoutUITests` 4/4; `UITests-iPad` plan
    `DeepLinkPadUITests/testPadTabModalReplacedByDeepLink` and
    `AccessibilityAuditUITests/testPadSettingAndDetailModalsAudit` pass.
- The first iPhone Library run failed: in landscape a grid card is taller than the space between
  the bars, so the card's bottom edge (the old "tap outside the cover" point) was off screen. The
  UI-test helper now drags that edge into view first. Three other cases in that run lost the app
  process (no app crash report); they passed on the rerun with no change.
- UI tests that opened Detail by tapping an entry's centre now tap outside the cover
  (`tapGalleryOutsideCover`), since a Front Page grid set by `GalleryCardUITests` persists on a
  simulator and its centre is now the cover.
- The scroll-edge inventory row for the direct reader now names the shared presentation.

## Not covered

- `LandscapePaneUITests/testHomeAndNestedSheetsUseOppositeHalves` (Duo only) was not run.
- A cover tap on Front Page, Popular, Toplists, Watched, History and the two searches was not
  driven natively: these hosts share the reducer, modifier and gesture that the Favorites (remote
  source) and Downloads (local source) UI tests exercise, and the unit tests cover their wiring.
- Physical-device VoiceOver, keyboard and pointer activation were not exercised.
- The visual snapshot suite was not run: it needs the pinned regression environment, and the change
  adds only a clear background measuring view.

