# Test plan repairs

The 17-14 T2 runs on `feature/gsd-phase-17` failed FeatureTests and UITests on both the iPhone Air and the
iPad Pro 11-inch (M5). The failures fall into five groups. Each fix goes where the cause lies, test or app.
No assertion is weakened, and `DownloadContinuedSessionTests.swift` must not grow.

## Groups

1. **Stub has no `api.php` POST route.** Since `300a29ac4` a list page fails when its `gdata` metadata
   request fails, so every stubbed list now shows an error. The UI-test stub answers `gdata` from a saved
   `GalleryMetadata.json` in the fixture directory, in request order, with the site's error entry for an
   unknown pair. Other `api.php` methods still get 404. Tests that copy the fixtures share one helper,
   `StubFixtureCopy`, which renames a list's titles in both the HTML and the metadata. RED test first.
2. **Detail's More button not found.** iOS 27 names a navigation bar's More button
   `TopOverflowBarButtonItem`. Queries match any of UIKit's overflow identifiers.
3. **Capture-only suites in UITests.** `MarketingCaptureUITests` and `CaptureIsolationUITests` need a
   local capture fixture named through `TEST_RUNNER_EHPANDA_CAPTURE_SOURCE`. Without it they fail by
   design, so an ordinary plan run always failed them. UITests skips both, as it already skips
   `AppshotCaptureUITests`. The single-pass capture script removes the two skips from its copy of the
   plan's test run and records the removal. RED test first.
4. **CaptureSceneTests and VisualTracerTests.** Both tests are stale.
   - The scene's Japanese-title setting follows the process language (owner decision, 2026-11-02), so the
     test passes an explicit language through a `sceneSetting(languageCode:)` seam.
   - Home covers use `Defaults.ImageSize.coverAspect` (0.707), and the section is named More.
5. **Tablet DownloadContinuedSession timeouts and ReaderPageSync in landscape.**
   - The shared download helpers default to a real `ContinuousClock`. Its ten-second heartbeat fires mid-case
     on a loaded iPad and adds a push. Both coordinator helpers now default to a never-advanced `TestClock`.
     The hang bounds rise from 10 to 30 seconds, as in `DownloadObserverBatchTests`.
   - Match Screen Orientation (default on since `a76548695`) puts the iPad in landscape into dual-page
     right-to-left reading. The sync test turns it off, then restores it in portrait.
     `ReadingOrientationUITests` reuses the same probe.

## Verification

FeatureTests and UITests on both simulators, run one at a time, then strict no-cache SwiftLint and the
visual script tests. Before-numbers are the 17-14 bundles: FeatureTests 2 phone and 7 tablet failures,
UITests 23 phone and 26 tablet. Record results in SUMMARY.md and the STATE quick-task table.
