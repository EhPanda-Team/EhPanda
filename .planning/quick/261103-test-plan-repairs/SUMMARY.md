# Test plan repairs

The 17-14 T2 runs at `6bccf8468` failed FeatureTests and UITests on both the iPhone Air and the iPad Pro 11-inch
(M5). The [plan](PLAN.md) groups the failures in five. Every change is in the tests or in test support. The app
itself did not change. No assertion is weaker, and `DownloadContinuedSessionTests.swift` is unchanged at 996 lines.

## Causes and changes

| Group | Cause | Change | Commits |
| --- | --- | --- | --- |
| 1. Stub has no `api.php` route | Since `300a29ac4` a list fails when its `gdata` metadata request fails. The UI-test stub answered every `api.php` POST with 404, so every stubbed list showed an error. Most UITests failures on both devices came from this, in Home, Front Page, Library and Favorites. | The stub answers `gdata` from a saved `GalleryMetadata.json`, in request order, with the site's error entry for an unknown gid or a wrong token. Other `api.php` methods still get 404. `StubFixtureCopy` copies every fixture, and its retitle changes a list's HTML and metadata together. | `85ebfe041` (RED), `e6e725fd1` |
| 2. Detail's More not found | iOS 27 names a navigation bar's More button `TopOverflowBarButtonItem`, not `OverflowBarButtonItem`. | One shared predicate matches all three of UIKit's overflow identifiers. | `56076ce11` |
| 3. Capture-only suites in UITests | `MarketingCaptureUITests` and `CaptureIsolationUITests` need a local capture fixture and fail without it by design. | UITests skips both, as it already skips `AppshotCaptureUITests`. The single-pass script removes the two skips from its copy of the test run and records that in `UITests-single-pass.json`. | `9be339053` (RED), `9b163d3dd` |
| 4a. `CaptureSceneTests` | Stale test. The scene turns Japanese titles on only for Korean, Japanese and Chinese interfaces (owner, 2026-11-02). `Setting()` defaults them on, and the test compared against the default. | A `sceneSetting(languageCode:)` seam, a test that takes the language as a parameter, and a test that the property follows the process language. | `188794175` |
| 4b. `VisualTracerTests` clipped item | Stale test. Home covers use `Defaults.ImageSize.coverAspect` (0.707) and the last section is called More (`61ef0232b`). | The tracer expects the shared constant and the More marker. | `99dacb6a7` |
| 4c. Tracer on iPad | This failure had been hidden behind 4b. Once the capture completed on iPad, the tracer's `idiom == .phone` check failed, even though the FeatureTests plan runs the tracer on both devices. | The tracer checks that the viewport has the device's own idiom, either phone or pad. On iPhone the check is unchanged. | `1f70e0ac9` |
| 5a. Tablet `DownloadContinuedSession*` timeouts | The shared helpers defaulted to a real `ContinuousClock`. On a loaded iPad, its 10-second heartbeat fired in the middle of a case and added a push (Ledger read `[4, 4, 0]`). The hang bounds were 10 seconds while cases waited far longer than that just to be scheduled. | Both coordinator helpers default to a `TestClock` that never advances. `waitUntil` and `waitForTaskValue` bound a hang at 30 seconds, as `DownloadObserverBatchTests` already does. | `751527d16` |
| 5b. `ReaderPageSync` in landscape | Match Screen Orientation is on by default since `a76548695` and turns an iPad in landscape into dual-page right-to-left reading. | The test turns the setting off, then turns it back on in portrait. `ReaderPageProbe` owns the toggle, and `ReadingOrientationUITests` reuses it. The probe waits up to 5 seconds for More after a rotation. | `fec74302c` |
| 5c. iPad modal audit | This failure had been hidden behind group 1. A Front Page grid lays out its cards in a scroll view, and the layout chosen in `GalleryCardUITests` persists on the simulator clone, so a `collectionViews` query found nothing. | Front Page galleries are found by their `gallery-list-item-` identifier in either layout. The same query replaces two others with the same order dependence. | `61b65f0bf` |

## Verification

All runs were on iOS 27.2 simulators through `runtest`, one at a time.

| Plan | Device | Before (17-14) | After |
| --- | --- | --- | --- |
| FeatureTests | iPhone Air | 1,510: 1,499 passed, 2 failed, 9 expected failures | 1,512: 1,503 passed, 0 failed, 9 expected failures |
| FeatureTests | iPad Pro 11-inch (M5) | 1,510: 1,494 passed, 7 failed, 9 expected failures | 1,512: 1,502 passed, 1 failed (4c), 9 expected failures. After `1f70e0ac9`, `VisualTracerTests` passed 3 of 3 on both devices |
| UITests | iPhone Air | 91: 48 passed, 23 failed, 20 skipped | 88: 68 passed, 0 failed, 20 skipped |
| UITests | iPad Pro 11-inch (M5) | 91: 48 passed, 26 failed, 17 skipped | 88: 71 passed, 0 failed, 17 skipped |

- The After rows are the final runs. In the first full runs, iPhone failed one test, the restore step that
  `fec74302c` now covers with its wait for More. iPad failed one test, 5c. A focused iPhone rerun of
  `ReaderPageSyncUITests` and `ReadingOrientationUITests` then passed 9 tests, with 2 iPad-only tests skipped.
- UITests has 88 tests rather than 91 because the plan now skips the two capture suites (group 3). The 17 or 20 skips
  are the existing device-gated suites.
- On iPad the `DownloadContinuedSession*` median fell from 53 to 29 seconds of wall time, and the longest case took 48
  seconds where it had taken 85.
- Python capture-script tests: 229 passed. The single-pass test fails on the old script.
- Strict no-cache SwiftLint: 0 violations in 754 files.

## Left open

- **Passed only on a retry.** Each of these failed its first attempt and passed its retry. The UITests plan retries
  a failed test, so neither final run lists them as failures.
  - `GalleryLayoutUITests.testChangingLayoutKeepsMiddleGalleryAndSearchSurvivesDetailReturn` (iPhone, both phone
    runs): checks `isHittable` right after switching back to List, without waiting. It recurs and needs a look.
  - `AccessibilityAuditUITests.testHomeRootAudit` (iPhone): the rotation took 18.5 seconds against its 15-second
    readiness bound.
  - `GalleryCardUITests.testOriginalTitlesInBothLayoutsAndSettingRemoved` (iPhone): the Setting tab never became
    hittable.
  - `ShareSheetUITests.testShareSheetHandoffLandsOnDetail` (iPad): Safari did not show its address field.
  - `ReaderPageSyncUITests.testAutoPlayTurnsThePageAndKeepsTheIndicatorOnIt` (iPad): Off had no hit point.
  - `DeepLinkSchemeUITests.testPageLinkWarmForegroundOpensReaderAtPage` (iPad): the indicator read page 2 while the
    screen showed page 1.
- **Not run here.** The `LandscapePaneUITests` cases touched by `e6e725fd1` and `61b65f0bf` run only with
  `EHPANDA_IPAD_UI_TESTS=1` on iPad or on Duo. `runtest` passes no such variable, so they were skipped. They compile,
  and the same helper and query pass in the suites that ran.
- **Persisted layouts.** UI tests share one app container per simulator clone, so a layout set by one test reaches the
  next. The gallery query no longer depends on that. Other tests may still assume list layout.
- `VisualMatrixTests` and `FullContentFeasibilityTests` still say 8:11 in places. Both are skipped suites, outside this
  task.
