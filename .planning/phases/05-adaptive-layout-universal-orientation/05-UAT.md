---
status: diagnosed
phase: 05-adaptive-layout-universal-orientation
source: [05-VERIFICATION.md]
started: 2026-07-13T06:52:36Z
updated: 2026-07-13T08:28:00Z
---

## Current Test

[testing complete]

## Tests

### 1. Universal rotation and reader state

expected: Home, detail, grid, settings, and reader surfaces rotate without snap-back; reader page, dual-page mapping, RTL order, and resume position stay correct.
result: issue
reported: |
  issues in landscape orientation:
  - aboutview copyright and version not visible
  - readingview loading pages height too small

  issues in both orientations:
  - homeview slideshow card size is broken
  - filtersview pages range textfield prompt clipped, prompt should be removed
  - filtersview doesn't have a dismiss button, search all sheets without a dismiss button and add Button(role: .cancel) with no title to fix this
  - favoritesview dateseek toobar item not responding
severity: blocker

### 2. Reader gesture and assistive-technology coexistence

expected: Tap-to-turn, double-tap, pinch, pan, paging, VoiceOver, and Switch Control remain operable without conflicts; tap-to-turn remains disabled while zoomed.
result: pass

### 3. Live Text alignment

expected: OCR boxes and interactive overlays align with glyphs in portrait/landscape and single-/dual-page layouts.
result: pass

### 4. Representative adaptive-layout visual pass

expected: Compact/regular widths, split view, dark appearance, Increase Contrast, the home carousel, category/grid layouts, previews, archives, and settings remain readable, centered, and unclipped.
result: issue
reported: |
  issues:
  - when displayed in an ipad window
    - the custom upper toolbar is overlapping the macos style traffic light button group.
    - all windows use a sheet style background color, making the homeview other section cards background invisible, try using other color or material or glass to improve visibility.
  - ehpanda doesn't really support multiple windows, all windows share the same state. should remove the support checkbox.
  - openning detail pages now present a modal sheet on iphone too, it used to be a navigation push
    - is this behavior change intentional or it's a regression?
severity: major

### 5. Maximum Dynamic Type

expected: App surfaces remain readable and usable at the maximum Dynamic Type size without clipping or inaccessible controls.
result: skipped
reason: "Deferred follow-up: The app was built without comprehensive Dynamic Type support, and the gap is too large to address in Phase 5. Move it to Phase 10."

## Summary

total: 5
passed: 2
issues: 2
pending: 0
skipped: 1
blocked: 0

## Gaps

- gap_id: G-05-1
  truth: "Universal rotation and adaptive layouts preserve visible content, correctly sized reader loading pages and home slideshow cards, unclipped filter controls, dismissible sheets, and a responsive Favorites date-seek toolbar item."
  status: failed
  reason: "User reported six regressions: About copyright/version hidden in landscape; reader loading-page height too small in landscape; broken Home slideshow card sizing; clipped Filters page-range prompt; Filters and potentially other sheets missing an untitled cancel-role dismiss button; and an unresponsive Favorites date-seek toolbar item."
  severity: blocker
  test: 1
  root_cause: "Six independent view-contract defects: About metadata exists only in a large-title toolbar placement; reader placeholders use width-only sizing plus a portrait aspect ratio; Home applies nested 80%-width sizing; Filters gives fixed-width range fields a redundant prompt; reusable sheet roots omit cancellation actions; and Favorites overpacks one toolbar item while disabling date seek when metadata is absent."
  artifacts:
    - path: "AppPackage/Sources/SettingFeature/Components/AboutView.swift"
      issue: "Copyright and version are rendered only in a large-title-only toolbar placement."
    - path: "AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift"
      issue: "Loading and failed pages ignore available landscape height."
    - path: "AppPackage/Sources/HomeFeature/HomeView+Sections.swift"
      issue: "The carousel already owns card width and snapping pitch."
    - path: "AppPackage/Sources/HomeFeature/GalleryCardCell.swift"
      issue: "The card independently applies a second 80%-width calculation."
    - path: "AppPackage/Sources/FiltersFeature/FiltersView.swift"
      issue: "Page-range fields have a redundant clipped prompt and the sheet root lacks cancellation."
    - path: "AppPackage/Sources/QuickSearchFeature/QuickSearchView.swift"
      issue: "Reusable sheet root lacks cancellation."
    - path: "AppPackage/Sources/DateSeekFeature/DateSeekPickerView.swift"
      issue: "Reusable sheet root lacks cancellation."
    - path: "AppPackage/Sources/FavoritesFeature/FavoritesView.swift"
      issue: "Four controls are packed into one custom toolbar item."
    - path: "AppPackage/Sources/AppComponents/ToolbarItems.swift"
      issue: "Date seek is inert whenever optional navigation metadata is absent."
  missing:
    - "Render About metadata in stable scrollable content."
    - "Size reader placeholders against both container axes."
    - "Make the Home carousel the sole card-width owner."
    - "Remove the visible page-range prompt while retaining an accessibility label."
    - "Add untitled cancellation-role actions to reusable sheet roots."
    - "Give Favorites controls valid toolbar grouping and handle unavailable date-seek metadata explicitly."
  debug_session: ".planning/debug/phase-05-layout-regressions.md"

- gap_id: G-05-4
  truth: "iPad windows keep custom toolbars clear of window controls and use visually distinct backgrounds; the app does not advertise unsupported multi-window behavior; opening detail pages on iPhone preserves navigation-push behavior unless an intentional change is documented."
  status: failed
  reason: "User reported that the custom upper toolbar overlaps iPad window controls, sheet-style window backgrounds hide Home card backgrounds, the app advertises multi-window support despite shared state, and iPhone detail pages now open as modal sheets instead of navigation pushes."
  severity: major
  test: 4
  root_cause: "Four independent causes: the reader upper toolbar uses fixed padding and ignores iPad window controls; the root/Home hierarchy inherits a window background that can match Home's systemGray6 cards; multiple scenes are advertised while every window receives one shared AppDelegate store; and iPhone modal detail presentation contradicts the preserved iPad-modal/non-iPad-push contract, making it a regression or entry-path-specific routing mismatch."
  artifacts:
    - path: "AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift"
      issue: "The custom upper toolbar reserves no iPad window-control exclusion region."
    - path: "AppPackage/Sources/HomeFeature/HomeView.swift"
      issue: "Home inherits the platform window background."
    - path: "AppPackage/Sources/HomeFeature/HomeView+Sections.swift"
      issue: "Other-section cards can match the inherited window surface."
    - path: "App/Info.plist"
      issue: "The target advertises multiple-scene support."
    - path: "App/EhPandaApp.swift"
      issue: "Every scene is created from the same app delegate."
    - path: "AppPackage/Sources/AppFeature/RootView.swift"
      issue: "Every window receives the shared app-delegate store."
    - path: "AppPackage/Sources/DetailFeature/GalleryNavigation.swift"
      issue: "The intended contract remains iPad modal and non-iPad push."
  missing:
    - "Make the custom reader toolbar aware of iPad window-control safe geometry."
    - "Establish distinct semantic root and card surfaces."
    - "Disable unsupported multiple-scene capability."
    - "Reproduce the exact iPhone entry path and preserve navigation pushes for every non-pad gallery host."
  debug_session: ".planning/debug/phase-05-ipad-window-navigation.md"

## Deferred Follow-Ups

- test: 5
  idea: "Add comprehensive Dynamic Type support across the app and verify layouts at the maximum accessibility size."
  deferred_at: 2026-07-13
