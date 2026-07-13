---
phase: 05-adaptive-layout-universal-orientation
reviewed: 2026-07-13T15:40:37+09:00
depth: standard
files_reviewed: 47
files_reviewed_list:
  - AppPackage/Package.swift
  - AppPackage/Sources/AppComponents/AlertView.swift
  - AppPackage/Sources/AppComponents/CategoryView.swift
  - AppPackage/Sources/AppComponents/NewDawnView.swift
  - AppPackage/Sources/AppComponents/Placeholder.swift
  - AppPackage/Sources/AppComponents/PreviewImageView.swift
  - AppPackage/Sources/AppComponents/TagSuggestionView.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
  - AppPackage/Sources/AppFeature/RootView.swift
  - AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift
  - AppPackage/Sources/AppModels/Persistent/Setting.swift
  - AppPackage/Sources/AppModels/Utilities/Defaults+Runtime.swift
  - AppPackage/Sources/AppTools/DeviceType.swift
  - AppPackage/Sources/ApplicationClient/ApplicationClient.swift
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
  - AppPackage/Sources/HomeFeature/GalleryCardCell.swift
  - AppPackage/Sources/HomeFeature/HomeReducer+Body.swift
  - AppPackage/Sources/HomeFeature/HomeView+Sections.swift
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
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift
  - AppPackage/Sources/SettingFeature/Login/LoginView.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadsReducerActionTests.swift
  - AppPackage/Tests/ReadingFeatureTests/GestureHandlerTests.swift
  - AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift
findings:
  critical: 0
  warning: 2
  info: 0
  total: 2
status: issues_found
---

# Phase 05: Code Review Report

**Reviewed:** 2026-07-13
**Depth:** standard
**Files Reviewed:** 47
**Status:** issues found

## Summary

Reviewed all 47 files in the Phase 05 scope, covering the injected device-identity seam,
universal-orientation cleanup, container-relative SwiftUI layout changes, reader geometry and
gesture migration, native horizontal paging, package dependency changes, and the associated
reader/download tests. The main adaptive-layout and reader changes are internally consistent:
reader orientation is derived from its captured container, page mapping receives that context
explicitly, programmatic paging is bounded, and the removed process-global geometry APIs have no
remaining references in the reviewed production files.

Two actionable robustness/accessibility issues remain. Neither is a release-blocking security,
crash, or data-loss defect, but both affect supported user configurations.

## Narrative Findings (AI reviewer)

### Critical

None.

### Warnings

#### WR-01 — The global appearance update targets an arbitrary scene

**Location:** `AppPackage/Sources/ApplicationClient/ApplicationClient.swift:91-105`

`interfaceStyleWindow()` selects `.last` from `UIApplication.shared.connectedScenes`, first at
the scene level and then at the window level. `connectedScenes` has no meaningful ordering, and
the app explicitly supports multiple scenes. With two active windows, changing the preferred
color scheme can therefore update only an arbitrary scene; if the selected scene has no key
window, the fallback can even come from an inactive scene while another foreground scene has a
valid key window.

**Fix:** Treat the setting as application-wide and apply `overrideUserInterfaceStyle` to every
window in every connected `UIWindowScene`. If the intended behavior is scene-local instead,
inject the originating `UIWindowScene`/window into the operation rather than recovering one from
global unordered state.

#### WR-02 — The archive download control is not exposed as an actionable, disabled button

**Location:** `AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift:219-236`

`DownloadButton` renders a `Text` and implements activation and pressed visuals with
`onTapGesture`/`onLongPressGesture`. As a result, assistive technologies do not receive native
button semantics, an activation action, or the disabled state. The visual `isDisabled` guard does
not make the control unavailable to accessibility clients, so Voice Control, Switch Control, and
VoiceOver users cannot reliably operate or understand this primary action.

**Fix:** Make the control a real `Button(action:)`, apply `.disabled(isDisabled)`, and move the
pressed-state rendering into a custom `ButtonStyle` using `configuration.isPressed`. This
preserves the current appearance while restoring native activation, focus, and disabled
semantics.

### Info

None.

---

_Reviewed: 2026-07-13T15:40:37+09:00_
_Reviewer: Codex (standard-depth narrative review)_
_Depth: standard_
