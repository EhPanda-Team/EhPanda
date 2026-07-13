---
phase: 05-adaptive-layout-universal-orientation
reviewed: 2026-07-13T19:15:00+09:00
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
  warning: 1
  info: 0
  total: 1
status: issues_found
---

# Phase 05: Code Review Report

**Reviewed:** 2026-07-13
**Depth:** standard
**Files Reviewed:** 55
**Status:** issues found

## Summary

Reviewed all 55 implementation and test files named by the 18 Phase 05 summaries, including gap
plans 05-11 through 05-18. The device-identity seam, universal-orientation cleanup,
container-relative layout conversions, reader gesture and paging migration, gap-closure UI
changes, routing, concurrency boundaries, and focused regression tests are internally consistent.

The previous arbitrary-scene appearance warning is resolved: the app now explicitly disables
multiple scenes in `App/Info.plist`, so `interfaceStyleWindow()` no longer chooses among multiple
independent app windows. The gap fixes also keep About metadata in scrollable content, constrain
reader placeholders on both axes, restore sheet cancellation controls, regroup Favorites toolbar
actions, clear iPad window controls, and establish an opaque Home surface without introducing a
new code-level finding.

One existing accessibility warning remains. The outstanding device-only orientation and
window-control checks recorded by verification/UAT are manual validation items, not additional
static-review findings.

## Narrative Findings (AI reviewer)

### Critical

None.

### Warnings

#### WR-01 — The archive download control is not exposed as an actionable, disabled button

**Location:** `AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift:219-236`

`DownloadButton` renders a `Text` and implements activation and pressed visuals with
`onTapGesture`/`onLongPressGesture`. Assistive technologies therefore do not receive native
button activation, keyboard focus, or the disabled state. The visual `isDisabled` guard only
blocks the gesture closure; it does not expose the control as unavailable to VoiceOver, Voice
Control, or Switch Control.

**Fix:** Replace the gesture-driven `Text` with `Button(action:)`, apply `.disabled(isDisabled)`,
and move the pressed-state styling into a custom `ButtonStyle` using
`configuration.isPressed`. This preserves the current appearance while restoring native
activation, focus, and disabled semantics.

### Info

None.

---

_Reviewed: 2026-07-13T19:15:00+09:00_
_Reviewer: Codex (standard-depth narrative review)_
_Depth: standard_
