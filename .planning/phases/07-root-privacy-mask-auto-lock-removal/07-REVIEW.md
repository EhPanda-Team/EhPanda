---
phase: 07-root-privacy-mask-auto-lock-removal
reviewed: 2026-07-13T23:24:11Z
depth: standard
files_reviewed: 41
files_reviewed_list:
  - App/Info.plist
  - App/InfoPlist.xcstrings
  - AppPackage/Package.swift
  - AppPackage/Sources/AppComponents/ViewModifiers.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
  - AppPackage/Sources/AppFeature/Resources/Localizable.xcstrings
  - AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift
  - AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift
  - AppPackage/Sources/AppModels/Persistent/Setting.swift
  - AppPackage/Sources/AppModels/Resources/Localizable.xcstrings
  - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
  - AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchView.swift
  - AppPackage/Sources/DetailFeature/DetailView.swift
  - AppPackage/Sources/DetailFeature/GalleryDestination.swift
  - AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift
  - AppPackage/Sources/DetailFeature/Torrents/TorrentsView.swift
  - AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift
  - AppPackage/Sources/DownloadsFeature/DownloadsView.swift
  - AppPackage/Sources/FavoritesFeature/FavoritesView.swift
  - AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift
  - AppPackage/Sources/HomeFeature/History/HistoryView.swift
  - AppPackage/Sources/HomeFeature/HomeView.swift
  - AppPackage/Sources/HomeFeature/Popular/PopularView.swift
  - AppPackage/Sources/HomeFeature/Toplists/ToplistsView.swift
  - AppPackage/Sources/HomeFeature/Watched/WatchedView.swift
  - AppPackage/Sources/ReadingFeature/ReadingView.swift
  - AppPackage/Sources/SearchFeature/SearchRootView.swift
  - AppPackage/Sources/SearchFeature/SearchView.swift
  - AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingView.swift
  - AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsView.swift
  - AppPackage/Sources/SettingFeature/AppearanceSetting/AppearanceSettingView.swift
  - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView.swift
  - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingReducer.swift
  - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift
  - AppPackage/Sources/SettingFeature/Login/LoginView.swift
  - AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings
  - AppPackage/Sources/SettingFeature/SettingView.swift
  - AppPackage/Tests/AppFeatureTests/.swiftlint.yml
  - AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift
  - AppPackage/Tests/AppModelsTests/SettingPrivacyMaskTests.swift
  - AppPackage/Tests/FeatureTests.xctestplan
findings:
  critical: 1
  warning: 4
  info: 0
  total: 5
status: issues_found
---

# Phase 07: Code Review Report

**Reviewed:** 2026-07-13T23:24:11Z
**Depth:** standard
**Files Reviewed:** 41
**Status:** issues_found

## Summary

The auto-lock removal, localization cleanup, shared blur storage, scoped hit-testing behavior, settings semantics, target registration, and broad modal coverage are internally consistent. The focused AppFeature test run also passes (2 tests in 1 suite).

The review found one security-critical cold-launch race and four warnings. Most importantly, the settings-loaded guard currently suppresses the privacy write itself, so an early inactive transition can expose an unmasked App Switcher snapshot. The claimed exactly-once test coverage is also non-exhaustive, one modal root applies the mask twice, the mask animation ignores Reduce Motion, and the new test target directly links a dependency already supplied by the target under test.

## Narrative Findings (AI reviewer)

## Critical Issues

### CR-01: An inactive transition before settings initialization leaves the App Switcher unmasked

**File:** `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift:81-87,111-117`
**Issue:** `onScenePhaseChange` returns at line 83 whenever `hasLoadedInitialSetting` is false, before either privacy-mask write occurs. The shared blur launches at `0`, and `TabBarView` only dispatches scene changes from `onChange`, so a user who backgrounds the app during the asynchronous launch/settings sequence can reach `.inactive` and `.background` while both transitions are ignored. The resulting App Switcher snapshot is not masked, violating the phase's block-on-high no-content-leak guarantee. The same guard also drops the background-entry latch for that cycle.
**Fix:** Make the privacy writes independent of the settings-loaded side-effect gate: write `privacyMaskIntensity` on every `.inactive` transition and `0` on every `.active` transition before deciding whether greeting/clipboard/logging work may run. Preserve background bookkeeping independently as well. Add a TestStore case whose initial state has `hasLoadedInitialSetting == false`, sends `.inactive` followed by `.background`, and verifies the blur is already set before initialization completes.

## Warnings

### WR-01: Non-exhaustive tests cannot prove exactly-once or disabled clipboard behavior

**File:** `AppPackage/Tests/AppFeatureTests/AppReducerScenePhaseTests.swift:29-38,49-54`
**Issue:** Both foreground tests run under `withExhaustivity(.off)`. That mode permits unasserted actions and state changes, so the first test can pass if a second greeting or clipboard action is emitted, and the disabled test can pass even if `detectClipboardURL` is emitted unexpectedly. Receiving one matching action proves occurrence, not exactly-once behavior; omitting a receive while exhaustivity is disabled does not prove absence.
**Fix:** Keep action exhaustivity enabled and explicitly drain/assert the complete foreground sequence, cancelling only known long-lived effects. If nested reducer noise makes that impractical, instrument the reducer or relevant dependencies with counters and assert greeting/clipboard counts after the effect queue settles. Retain a strict negative assertion for the disabled case.

### WR-02: The Download Inspector applies the configured blur twice

**File:** `AppPackage/Sources/DownloadsFeature/DownloadsView.swift:48-54`, `AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift:99-103`
**Issue:** The inspector sheet masks its enclosing `NavigationStack`, while `DownloadInspectorView` masks its own content again. Gaussian blurs compose, so this one surface is visibly stronger than the configured intensity and runs two mask animations. It also makes the raw count of 40 modifier calls a false coverage proxy: the source has 38 runtime sheet/cover presentations plus the app root (39 distinct roots), with the fortieth call being this duplicate.
**Fix:** Keep `.privacyMask()` on the presented `NavigationStack` root and remove it from `DownloadInspectorView`. Replace the raw call-count gate with an explicit presentation-root inventory so duplicates cannot conceal a missing root.

### WR-03: The privacy-mask animation ignores Reduce Motion

**File:** `AppPackage/Sources/AppComponents/ViewModifiers.swift:9-17`
**Issue:** The owner refinement correctly scopes animation to the blur transform and keeps `allowsHitTesting` outside it, but the linear transition is still unconditional. Users who enable Reduce Motion therefore continue to receive the blur transition on every inactive/active change.
**Fix:** Read `@Environment(\.accessibilityReduceMotion)` in `PrivacyMaskModifier` and supply `nil` animation when reduction is requested, while retaining the scoped animation for other users.

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

content
    .animation(reduceMotion ? nil : .linear(duration: 0.1)) {
        $0.blur(radius: blur)
    }
    .allowsHitTesting(blur < 1)
```

### WR-04: AppFeatureTests directly links a transitive production dependency

**File:** `AppPackage/Package.swift:838-844`
**Issue:** `AppFeatureTests` depends on `AppFeature` and separately links `ComposableArchitecture`, even though `AppFeature` already links that product at line 293. The project's testing guidance requires test targets not to relink dependencies transitively supplied by the system under test because duplicate runtime modules can produce duplicate-class warnings and casting failures.
**Fix:** Remove `.targetDependency(.composableArchitecture)` from `AppFeatureTests`; keep only `.module(.appFeature)` unless the tests add a genuinely test-only product such as dedicated test support.

---

_Reviewed: 2026-07-13T23:24:11Z_
_Reviewer: the agent (gsd-code-reviewer; generic-agent workaround)_
_Depth: standard_
