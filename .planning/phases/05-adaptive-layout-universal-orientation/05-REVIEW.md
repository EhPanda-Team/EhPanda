---
phase: 05-adaptive-layout-universal-orientation
reviewed: 2026-07-13T00:00:00Z
depth: standard
files_reviewed: 55
files_reviewed_list:
  - App/Info.plist
  - AppPackage/Package.swift
  - AppPackage/Sources/AppComponents/AlertView.swift
  - AppPackage/Sources/AppComponents/CategoryView.swift
  - AppPackage/Sources/AppComponents/NewDawnView.swift
  - AppPackage/Sources/AppComponents/Placeholder.swift
  - AppPackage/Sources/AppComponents/PreviewImageView.swift
  - AppPackage/Sources/AppComponents/SettingTextField.swift
  - AppPackage/Sources/AppComponents/TagSuggestionView.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
  - AppPackage/Sources/AppFeature/RootView.swift
  - AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift
  - AppPackage/Sources/AppModels/Persistent/Setting.swift
  - AppPackage/Sources/AppModels/Utilities/Defaults+Runtime.swift
  - AppPackage/Sources/AppTools/DeviceType.swift
  - AppPackage/Sources/ApplicationClient/ApplicationClient.swift
  - AppPackage/Sources/DateSeekFeature/DateSeekPickerView.swift
  - AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift
  - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
  - AppPackage/Sources/DetailFeature/Components/TagDetailView.swift
  - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
  - AppPackage/Sources/DetailFeature/GalleryInfos/GalleryInfosView.swift
  - AppPackage/Sources/DetailFeature/GalleryNavigation.swift
  - AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift
  - AppPackage/Sources/DeviceClient/DeviceClient.swift
  - AppPackage/Sources/DownloadClient/BackgroundTaskClient.swift
  - AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift
  - AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift
  - AppPackage/Sources/FavoritesFeature/FavoritesView.swift
  - AppPackage/Sources/FiltersFeature/FiltersView.swift
  - AppPackage/Sources/HomeFeature/GalleryCardCell.swift
  - AppPackage/Sources/HomeFeature/HomeReducer+Body.swift
  - AppPackage/Sources/HomeFeature/HomeView+Sections.swift
  - AppPackage/Sources/HomeFeature/HomeView.swift
  - AppPackage/Sources/QuickSearchFeature/QuickSearchView.swift
  - AppPackage/Sources/ReadingFeature/ReadingReducer+Body.swift
  - AppPackage/Sources/ReadingFeature/ReadingReducer.swift
  - AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift
  - AppPackage/Sources/ReadingFeature/ReadingView.swift
  - AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift
  - AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift
  - AppPackage/Sources/ReadingFeature/Support/GestureHandler.swift
  - AppPackage/Sources/ReadingFeature/Support/LiveTextView.swift
  - AppPackage/Sources/ReadingFeature/Support/PageHandler.swift
  - AppPackage/Sources/ReadingSettingFeature/ReadingSettingView.swift
  - AppPackage/Sources/ReadingSettingFeature/Resources/Localizable.xcstrings
  - AppPackage/Sources/SearchFeature/SearchRootReducer.swift
  - AppPackage/Sources/SearchFeature/SearchRootView+Keywords.swift
  - AppPackage/Sources/SettingFeature/Components/AboutView.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift
  - AppPackage/Sources/SettingFeature/Login/LoginView.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadsReducerActionTests.swift
  - AppPackage/Tests/ReadingFeatureTests/GestureHandlerTests.swift
  - AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift
findings:
  critical: 0
  warning: 4
  info: 4
  total: 8
status: issues_found
---

# Phase 5: Code Review Report

**Reviewed:** 2026-07-13
**Depth:** standard
**Files Reviewed:** 55
**Status:** issues_found

## Narrative Findings (AI reviewer)

### Summary

Phase 5 replaces the global `DeviceUtil` (window-size / orientation / touch singletons) with
injected `DeviceClient.deviceType`, native SwiftUI geometry (`onGeometryChange`,
`containerRelativeFrame`, size classes), and native gestures (`SpatialTapGesture` / `MagnifyGesture`).
It removes the `enablesLandscape` setting plus the AppDelegate orientation-mask machinery, and deletes
`DeviceUtil`, `TouchHandler`, and the `AppDelegateClient` module. The mechanical substitutions are
clean: I verified no dangling references to any removed symbol (`DeviceUtil`, `TouchHandler`,
`enablesLandscape`, `AppDelegateClient`/`appDelegateClient`/`AppOrientationMask`/`setOrientationPortrait`,
`absWindowW/H`, `windowW/H`, `isPadWidth`, `cardCellWidth`, `cardCellSize`, `rankingCellWidth`,
`archiveGridWidth`, `previewAvgW/MinW/MaxW`) remain in Sources; `Package.swift` drops the dead
module and its test dependency cleanly; and the new gesture/page arithmetic is locked by two new
test suites (`GestureHandlerTests`, `PageHandlerTests`).

No blockers found. The findings below are correctness-adjacent semantic changes and quality
regressions introduced by the geometry migration. The two most substantive are a silent
`maxWidth`→fixed-width semantics change (WR-01) and the reader resume-index seeding a hardcoded
`isLandscape: false` that must self-correct via a later geometry event (WR-02).

### Warnings

#### WR-01: `maxWidth` cap silently converted to a fixed width in AlertView (and TextEditor height)

**File:** `AppPackage/Sources/AppComponents/AlertView.swift:117`
**Issue:** The migration replaced `.frame(maxWidth: DeviceUtil.windowW * 0.8)` with
`.containerRelativeFrame(.horizontal) { width, _ in width * 0.8 }`. These are not equivalent:
`maxWidth:` is an upper bound (the card shrinks to fit short content), whereas
`containerRelativeFrame` pins the card to *exactly* 80% of the container width regardless of content.
Short alerts (e.g. a one-line message) now always render at 80% width, which on iPad in particular
produces a much wider card than before. The same `maxHeight → containerRelativeFrame(.vertical)`
substitution appears at `EhSettingView+Sections3.swift:189` for the excluded-uploaders `TextEditor`
(`maxHeight` cap → fixed 30% height); there the greedy `TextEditor` masks the difference, but the
semantics still changed. The other converted sites (`Placeholder.swift`, `CommentsView.swift`,
`DetailView+Subviews.swift`) were already fixed `.frame(width:)`, so those conversions are faithful —
this finding is specifically the two `max*`→fixed conversions.
**Fix:** Preserve the cap semantics for the alert, e.g.
```swift
.containerRelativeFrame(.horizontal, alignment: .center) { width, _ in min(width * 0.8, 500) }
.frame(maxWidth: 500)
```
or measure the container via `onGeometryChange` and feed a `maxWidth:` rather than a fixed
`containerRelativeFrame`. Confirm the TextEditor at Sections3:189 is intended to be a fixed 30% height
rather than a cap.

#### WR-02: Reader resume index seeds `isLandscape: false`, mis-maps dual-page landscape resume

**File:** `AppPackage/Sources/ReadingFeature/ReadingView.swift:52-59`
**Issue:** The initializer computes the initial pager index with a hardcoded
`handler.mapToPager(index: resumePage, setting: store.state.setting, isLandscape: false)`, and
`pageModel` / `scrollPositionID` are seeded from that value at construction (the init comment notes the
pager *must* be positioned at construction or every session opens at page 1). When the reader opens in
landscape with dual-page mode enabled, the correct resume mapping differs from the portrait mapping, so
the reader is seeded on the wrong pager slot. Recovery depends entirely on the later
`.onChange(of: containerDataSource)` firing once `gestureHandler.containerSize` is measured and
`isLandscape` flips to `true` — a side effect, not a guarantee, and it can produce a visible jump on
open. (When dual-page is off, `mapToPager` ignores `isLandscape`, so only the dual-page-landscape
resume path is affected.)
**Fix:** Seed from a synchronously-available orientation signal instead of a literal `false` — resolve
an initial `isLandscape` at construction (e.g. from interface orientation or an injected value) so the
pager opens on the correct slot, or explicitly document that dual-page landscape intentionally
re-lands after first layout and verify there is no visible flash.

#### WR-03: `MiscGridItem` stacks `.glassEffect(...)` and a redundant `.cornerRadius(15)`

**File:** `AppPackage/Sources/HomeFeature/HomeView+Sections.swift:437-439`
**Issue:** The tile now applies `.glassEffect(.clear.interactive(), in: .rect(cornerRadius: 15))`
followed by `.cornerRadius(15)`. The glass effect already clips to a 15pt rounded rect; the trailing
`.cornerRadius(15)` is a deprecated modifier clipping the already-shaped glass a second time — at best
dead styling, at worst it clips the glass highlight. The old code needed `.cornerRadius` because it
wrapped a `Color(.systemGray6)` background, which is now gone.
**Fix:** Drop the trailing `.cornerRadius(15)` and let `glassEffect(in:)` own the shape:
```swift
.padding(30)
.glassEffect(.clear.interactive(), in: .rect(cornerRadius: 15))
```

#### WR-04: Setting field label switched to `EmptyView()` — verify every call site supplies a prompt

**File:** `AppPackage/Sources/AppComponents/SettingTextField.swift:38-42`
**Issue:** The field's label changed from `Text(title)` to `EmptyView()`, relying on
`.accessibilityLabel(title)` for VoiceOver and on `prompt` for the visible placeholder. This is fine
while the field is empty, but once the user types, the prompt disappears and there is no visible label.
A caller that passes an empty or absent `prompt` would present a fully unlabeled control both visually
and (if `title` were ever empty) to assistive tech.
**Fix:** Confirm every `SettingTextField` call site passes a non-empty localized `prompt`, and that
`title` is always non-empty so `.accessibilityLabel(title)` never receives `""`. Otherwise the field
is context-free once filled.

### Info

#### IN-01: Named layout constants replaced by scattered magic numbers

**File:** `AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift:82`,
`AppPackage/Sources/DetailFeature/Components/TagDetailView.swift:55`,
`AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift:27-28`,
`AppPackage/Sources/DetailFeature/DetailView+Subviews.swift:291`
**Issue:** Sizing that was named (`Defaults.FrameSize.archiveGridWidth`,
`Defaults.ImageSize.previewAvgW/MinW/MaxW`) is now inline literals per view (`175 : 150`,
`200 : 110`, `180/220 : 100/120`). Two sites (`TagDetailView` and `PreviewsSection`) share the
identical `horizontalSizeClass == .regular ? 200 : 110` rule with no shared source, so they can drift.
**Fix:** Hoist the recurring size-class thresholds into named module-local constants so the detail
preview width has a single definition.

#### IN-02: `DescriptionSection` duplicates the container-relative width closure

**File:** `AppPackage/Sources/DetailFeature/DetailView+Subviews.swift:51-53,62-64`
**Issue:** The `max(width / 5, 80)` `containerRelativeFrame` closure is now repeated verbatim on both
the item stack and the ellipsis button. It was previously a single `itemWidth` computed property; the
two copies must now stay in sync by hand.
**Fix:** Extract a shared `ViewModifier` (or a single closure constant) so both frames use one
definition.

#### IN-03: `PreviewImageView.defaultMaxPixelSize` hardcoded to `660` without derivation

**File:** `AppPackage/Sources/AppComponents/PreviewImageView.swift:10`
**Issue:** `Defaults.ImageSize.previewMaxW * 3` became a bare `660`. The `× 3` decode-scale intent is
lost; a future change to the base preview width will silently desync this downsample budget.
**Fix:** Document that 660 = 3× the ~220pt preview max width, or derive it from the per-site preview
constant introduced in IN-01.

#### IN-04: `Setting.enablesLandscape` removed from a persisted `Codable` model without a schema note

**File:** `AppPackage/Sources/AppModels/Persistent/Setting.swift:26,51,124`
**Issue:** `enablesLandscape` is dropped from the persisted `Setting` (a `SchemaVersioned` `Codable`).
Decoding old JSON is safe (synthesized `Codable` ignores the unknown key) and the project is
pre-release under a v1-schema policy, so this is not a defect — flagged only so removal of a persisted
field is a conscious, documented decision. No `schemaVersion` bump accompanies it.
**Fix:** No code change required; confirm the pre-release v1-schema policy covers dropping a persisted
field and that no migration/version bump is expected.

---

_Reviewed: 2026-07-13_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
