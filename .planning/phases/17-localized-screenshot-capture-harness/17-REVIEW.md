---
phase: 17-localized-screenshot-capture-harness
reviewed: 2026-11-04
depth: standard
effort: high
source_head: 97b31b063
review_head: 9c9f066b9
last_review_commit: 00db53a52
files_reviewed: 89
files_reviewed_list:
  - .gitignore
  - .swiftlint.yml
  - AppPackage/Package.swift
  - AppPackage/Sources/AppComponents/CaptureSystemOverlays.swift
  - AppPackage/Sources/AppComponents/GalleryCover.swift
  - AppPackage/Sources/AppComponents/GalleryCoverMetrics.swift
  - AppPackage/Sources/AppComponents/GalleryCoverStyle.swift
  - AppPackage/Sources/AppComponents/GalleryViewport.swift
  - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
  - AppPackage/Sources/AppFeature/RootView.swift
  - AppPackage/Sources/AppFeature/UITestSupport/CaptureDiagnostics.swift
  - AppPackage/Sources/AppFeature/UITestSupport/CaptureFixtureManifest.swift
  - AppPackage/Sources/AppFeature/UITestSupport/CaptureLiveText.swift
  - AppPackage/Sources/AppFeature/UITestSupport/CaptureSceneConfiguration.swift
  - AppPackage/Sources/AppFeature/UITestSupport/CaptureScenePreparation.swift
  - AppPackage/Sources/AppFeature/UITestSupport/UITestAutomation.swift
  - AppPackage/Sources/AppFeature/UITestSupport/UITestStubURLProtocol.swift
  - AppPackage/Sources/AppLaunchAutomationClient/AppLaunchAutomation.swift
  - AppPackage/Sources/AppTools/DataCache.swift
  - AppPackage/Sources/DetailFeature/DetailReducer+Download.swift
  - AppPackage/Sources/FiltersFeature/FiltersView.swift
  - AppPackage/Sources/GalleryListComponents/GalleryList.swift
  - AppPackage/Sources/HomeFeature/GalleryCardCell.swift
  - AppPackage/Sources/HomeFeature/HomeClient.swift
  - AppPackage/Sources/HomeFeature/HomeReducer+Body.swift
  - AppPackage/Sources/HomeFeature/HomeReducer.swift
  - AppPackage/Sources/HomeFeature/HomeView+Sections.swift
  - AppPackage/Sources/HomeFeature/HomeView.swift
  - AppPackage/Sources/ImageColors/ImageColors.swift
  - AppPackage/Sources/LibraryClient/LibraryClient.swift
  - AppPackage/Sources/ReadingFeature/ReadingView.swift
  - AppPackage/Sources/ReadingFeature/Support/AdvancedList.swift
  - AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift
  - AppPackage/Sources/ReadingFeature/Support/LiveTextCapture.swift
  - AppPackage/Sources/ReadingFeature/Support/LiveTextHandler.swift
  - AppPackage/Sources/ReadingFeature/Support/PageModel.swift
  - AppPackage/Sources/VisualSnapshotSupport/FullContentHost.swift
  - AppPackage/Sources/VisualSnapshotSupport/PublicVisualFixtures.swift
  - AppPackage/Sources/VisualSnapshotSupport/RenderServerCapture.swift
  - AppPackage/Sources/VisualSnapshotSupport/RenderSettlement.swift
  - AppPackage/Sources/VisualSnapshotSupport/RenderedContentInspection.swift
  - AppPackage/Tests/AppFeatureTests/CaptureDownloadTests.swift
  - AppPackage/Tests/AppFeatureTests/CaptureFixtureTests.swift
  - AppPackage/Tests/AppFeatureTests/CaptureLiveTextRecordTests.swift
  - AppPackage/Tests/AppFeatureTests/CaptureRouteTests.swift
  - AppPackage/Tests/AppFeatureTests/CaptureSceneTests.swift
  - AppPackage/Tests/AppFeatureTests/CaptureScreenDiagnosticsTests.swift
  - AppPackage/Tests/AppFeatureTests/LibraryClientReaderCacheTests.swift
  - AppPackage/Tests/AppFeatureTests/TabBarSettingPresentationTests.swift
  - AppPackage/Tests/AppFeatureTests/UITestStubTests.swift
  - AppPackage/Tests/DetailFeatureTests/DetailCaptureRouteTests.swift
  - AppPackage/Tests/DownloadsFeatureTests/DownloadAutomationTests.swift
  - AppPackage/Tests/FeatureTests.xctestplan
  - AppPackage/Tests/HomeFeatureTests/HomeClientTests.swift
  - AppPackage/Tests/ReadingFeatureTests/CaptureLiveTextTests.swift
  - AppPackage/Tests/ReadingFeatureTests/PagerSeedTests.swift
  - AppPackage/Tests/ReadingFeatureTests/PagerTurnGateTests.swift
  - AppPackage/Tests/VisualSnapshotTests/FixtureArtwork.swift
  - AppPackage/Tests/VisualSnapshotTests/FixtureArtworkTests.swift
  - AppPackage/Tests/VisualSnapshotTests/FullContentFeasibilityTests.swift
  - AppPackage/Tests/VisualSnapshotTests/GeometryTests.swift
  - AppPackage/Tests/VisualSnapshotTests/HostedHierarchyTests.swift
  - AppPackage/Tests/VisualSnapshotTests/RenderServerCaptureTests.swift
  - AppPackage/Tests/VisualSnapshotTests/RenderSettlementTests.swift
  - AppPackage/Tests/VisualSnapshotTests/RenderedContentInspectionTests.swift
  - AppPackage/Tests/VisualSnapshotTests/Resources/scenarios.json
  - AppPackage/Tests/VisualSnapshotTests/VisualMatrixTests.swift
  - EhPandaUITests/CaptureIsolationUITests.swift
  - EhPandaUITests/MarketingCaptureUITests.swift
  - EhPandaUITests/Support/CaptureLauncher.swift
  - Scripts/verify-full-content-capture.py
  - Scripts/visual/README.md
  - Scripts/visual/acquire-fixtures.py
  - Scripts/visual/capture-native.py
  - Scripts/visual/contracts.py
  - Scripts/visual/environment.py
  - Scripts/visual/fixtures.py
  - Scripts/visual/record-live-text.py
  - Scripts/visual/regression-environment.json
  - Scripts/visual/run-regression.py
  - Scripts/visual/selection-review.py
  - Scripts/visual/test_capture_native.py
  - Scripts/visual/test_contracts.py
  - Scripts/visual/test_environment.py
  - Scripts/visual/test_fixtures.py
  - Scripts/visual/test_record_live_text.py
  - Scripts/visual/test_release.py
  - Scripts/visual/test_selection_review.py
  - Scripts/visual/verify-release.py
findings:
  critical: 0
  warning: 2
  info: 3
  total: 5
status: issues_found
scope: plans-17-01..06,17-14,17-16..19,17-23,17-24-key-files-plus-reader-and-capture-overlay-commits
execution: inline-reviewer
---

# Phase 17 code review

This replaces the Task 1-only review of 2026-10-03 (00db53a52), which had no findings.
It covers the SUMMARY key-files of plans 17-01–06, 17-14, 17-16–19, 17-23 and 17-24, plus
`CaptureSystemOverlays.swift` and `FiltersView.swift`, which the DEBUG-only capture commits
d474d7f68 and 61d13639b added or changed. Plans 07–13, 15 and 20–22 are superseded and were
not reviewed. The reviewer read the code only and did not build, test or run anything.

The reader commits got the closest reading: adbd63809, 8f0d09fff, 2539331b2, 4372e4b8f,
90d6a6339, 346a3ea87 and e745f38f6. Release isolation was checked for d474d7f68 and
61d13639b.

## Warnings

### WR-01: The pager's turn gate is not reset when the pager is rebuilt

**File:** `AppPackage/Sources/ReadingFeature/ReadingView.swift:40`, `:219`, `:415-417`, `:503`; `AppPackage/Sources/ReadingFeature/Support/PageModel.swift:73-93`

**Issue:** `pagerTurnGate` is `@State` on `ReadingView` (:40), so it outlives the paging
ScrollView. That ScrollView is rebuilt by `.id(store.forceRefreshID)` (:219) and by a
`readingDirection` switch (:282). The direction handler (:415-417) resets only
`shownPagerPosition`. Suppose the pager is rebuilt or swapped while `isAnimating == true`. The
gate then clears only if the new ScrollView's first `onScrollPhaseChange` reports `.idle`.
`PagerTurnGateTests.aPagerBuiltAnewClearsAGateLeftMidAnimation` (PagerTurnGateTests.swift:64-75)
assumes that report, but nothing checks it against SwiftUI. `onScrollPhaseChange` fires when the
phase changes, and a newly built view starts at rest without one. If no report comes,
`admitsTurn()` (:503) keeps returning `false`. Taps, slider seeks and auto-play then move
`pageModel.index` but not the pager. `correction(...)` returns `nil` because `isAtRest` is
`false`, so the indicator names a page the screen does not show. This is the same desync
8f0d09fff and 2539331b2 were written to remove. The reader's own drag clears it.

**Fix:** Reset the gate wherever a new pager is built: `pagerTurnGate = PagerTurnGate()` next to
`shownPagerPosition = nil` in the `readingDirection` handler, and in an
`.onChange(of: store.forceRefreshID)`. Then the code no longer relies on an initial `.idle` phase
report. Alternatively, confirm with a hosted test that a rebuilt paging ScrollView does report
`.idle`.

### WR-02: The capture overlay preference reaches only Filters and the reader, not the other sheets

**File:** `AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift:44-49`, `:50-55`; `AppPackage/Sources/HomeFeature/HomeSheetView.swift:15`, `:38`; `Scripts/visual/README.md:620-626`

**Issue:** d474d7f68 sets `captureSystemOverlayVisibility = .hidden` and
`.persistentSystemOverlays(.hidden)` at the root (RootView.swift:33-34). 61d13639b found that the
root's preference does not reach a separately presented NavigationStack, so FiltersView now reads
the environment value at its own root (FiltersView.swift:10, :55). The other capture sheets have
the same presentation shape and were not changed. These are the Setting sheet hosting Laboratory
(TabBarView.swift:44) and `GallerySheetView`, which hosts Detail and Comments on iPad
(TabBarView.swift:54, HomeSheetView.swift:15/:38, DetailFeature/GallerySheetView.swift:15). Only ReadingView and
FiltersView read the value. So iPad Detail, Comments and Laboratory captures can still show the
home indicator, against the README's "absent in every exported screenshot" (README.md:620-626).
The capture is DEBUG-only and Release is unaffected. Not confirmed at runtime, since this review
ran no captures.

**Fix:** Move the consumer into one shared DEBUG-only modifier in AppComponents, for example
`captureSystemOverlays()`, which applies `.persistentSystemOverlays(value ?? .automatic)`. Apply it
at the root of `SettingView`/Laboratory and `GallerySheetView`, as well as Filters. Alternatively,
narrow the README claim to the screens that honor it.

## Info

### IN-01: The correction count carries over between unrelated misses

**File:** `AppPackage/Sources/ReadingFeature/Support/PageModel.swift:98-110`

**Issue:** `corrections` resets only when the pager lands on the index or when it gives up with
`.followScreen`. It does not reset at a new turn, and not when `shown` is `nil`, which returns
early. Suppose one turn's miss gets one `.sendAgain`, and the reader then drags away so that no
single page fills the pager. A later, unrelated miss starts from count 1 and reaches
`.followScreen` after one retry instead of two. This is bounded and cannot loop.

**Fix:** Reset `corrections` when a new turn is admitted (`admitsTurn()` returning `true`), or when
the reader's own scroll takes over in `phaseChanged`. Pin it in `PagerTurnGateTests`.

### IN-02: verify-release.py would not catch a Release leak of the capture overlay key

**File:** `Scripts/visual/verify-release.py:19-35`

**Issue:** `FORBIDDEN_CONTENT` has no token that matches `captureSystemOverlayVisibility` or
`CaptureSystemOverlays`. `CaptureScene` and the other `Capture*` prefixes do not match these names.
The file is fully `#if DEBUG` today, and every consumer is DEBUG-gated, which was checked. But if a
consumer later loses its gate, the Release scanner would not see it.

**Fix:** Add `b'captureSystemOverlay'` to `FORBIDDEN_CONTENT` and a case to `test_release.py`.

### IN-03: RootView imports AppComponents unconditionally but uses it only in DEBUG

**File:** `AppPackage/Sources/AppFeature/RootView.swift:1`

**Issue:** d474d7f68 added `import AppComponents` for the DEBUG-only
`captureSystemOverlayVisibility` key (:33). In Release, nothing in RootView uses the import. This is
harmless, because AppFeature already depends on AppComponents, but it is an unused import in
Release.

**Fix:** Put the import in the existing `#if DEBUG` import block.

## Checked without findings

- **Release isolation of d474d7f68 and 61d13639b.** `CaptureSystemOverlays.swift` is wholly
  `#if DEBUG`. The environment reads in ReadingView (:24-26, :68-75) and FiltersView (:9-11,
  :54-56) are DEBUG-gated, and the `?? .automatic` / `store.showsPanel` fallbacks keep each screen's
  native policy. RootView's use is inside `#if DEBUG`. Release keeps e745f38f6's
  `persistentSystemOverlays(store.showsPanel ? .automatic : .hidden)` unchanged.
  `AppReducer.captureRoute`/`captureRouteEffect` compile into Release but are unreachable, because
  `AppLaunchAutomation.resolve` returns `nil` outside DEBUG. That matches 17-RELEASE-ISOLATION.md.
- **adbd63809, PagerTurnGate hold/release.** Held turns are sent once at `.idle`, and a user scroll
  drops them. The index is already set, so a held turn needs no queue.
- **8f0d09fff and 2539331b2, correction and follow-screen.** The pager is pointed at the shown page
  first, so the re-send registers as a change. The follow-screen write is wrapped in the
  `performingChanges` echo guard. Retries are bounded by `correctionLimit`.
- **4372e4b8f, PagerSeed.** The seed fires once, at the first measurement with a finite positive
  size. Degenerate sizes such as 0×1, NaN and ∞ are rejected. Pages are built only after seeding.
- **90d6a6339, 346a3ea87 and e745f38f6, bottom-edge bar and home indicator.** The bar waits for a
  reading area, the soft-edge policy follows CLAUDE.md, and the home indicator follows
  `showsPanel`.
- **Capture data and diagnostics.** CaptureFixtureManifest, CaptureScenePreparation (download
  seeding, status ordering, Live Text replay validation), UITestStubURLProtocol (gdata fixture
  route), HomeClient, DataCache, LibraryClient and HomeReducer+Body have no findings.
- **Capture screenshot settling.** `XCUIScreen.settledScreenshot` (CaptureLauncher.swift:663-688)
  is bounded at 10 attempts, needs 3 unchanged intervals, and reports `isSettled == false` instead
  of passing silently.
- **Python scripts.** In fixtures.py, the Writer lock, staging and symlink refusal, and
  atomic-rename publish are sound. capture-native.py restores the status bar, appearance and
  portrait orientation in an ExitStack. verify-release.py's link-map, inert-shell and build-log
  checks were checked as well.

## Coverage limits

- The Tier 3 evaluation scope was degraded (`no-task-commit-rows`; the branch has 717 files and 200
  commits), so file scope came from SUMMARY key-files instead. Commits on the branch outside those
  key-files were not reviewed.
- The largest files were reviewed by priority, not line by line: the phase-17 diff hunks plus the
  surrounding code. These were `EhPanda.xcodeproj/project.pbxproj` (diff-only; not counted in
  `files_reviewed`), `CaptureScenePreparation.swift`, `CaptureLauncher.swift`, `test_fixtures.py`,
  `test_capture_native.py` and `Scripts/visual/README.md`. Test files were read for intent and
  coverage, not audited line by line.
- No build, test, lint or capture was run. WR-01 and WR-02 depend on SwiftUI runtime behavior that
  was inferred, not observed.

---

_Reviewer: gsd-code-reviewer (inline, no subagents)_
_Depth: standard · effort: high (resolved from .planning/config.json)_
