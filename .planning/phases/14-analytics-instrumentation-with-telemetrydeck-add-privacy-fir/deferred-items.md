# Deferred Items — Phase 14

## Pre-existing flaky test (out of scope for plan 14-07)

- **Test:** `DownloadsFeatureTests/DownloadObserverBatchTests/testDownloadCoordinatorBatchesObserverUpdatesDuringProgressFlush()`
- **Nature:** A non-`@MainActor`, non-`TestStore` test that exercises a real `DownloadCoordinator` progress-flush observer-batching path with wall-clock timing. It is timing-sensitive and fails intermittently only under full-target parallel execution; it passes deterministically when run in isolation.
- **Relation to 14-07:** None. Plan 14-07 is a pure analytics dependency-hardening pass that only adds `import AnalyticsClient` and `$0.analyticsClient = .noop` to `TestStore` closures. This test constructs no `TestStore` and references no analytics; the file's only 14-07 edit is to a different test's store. Confirmed pre-existing (baseline was reported green; this test passes in isolation post-change).
- **Recommendation:** Stabilize the coordinator progress-flush timing test (e.g. inject a controllable clock or relax the batching-window assertion) in a dedicated test-reliability change. Not fixed here to keep 14-07 a pure hardening pass with an additive-only diff.
