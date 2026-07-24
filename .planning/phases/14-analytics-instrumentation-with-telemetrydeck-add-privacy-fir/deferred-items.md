# Deferred Items — Phase 14

## Pre-existing flaky test (out of scope for plan 14-07)

- **Test:** `DownloadsFeatureTests/DownloadObserverBatchTests/testDownloadCoordinatorBatchesObserverUpdatesDuringProgressFlush()`
- **Nature:** A non-`@MainActor`, non-`TestStore` test that exercises a real `DownloadCoordinator` progress-flush observer-batching path with wall-clock timing. It is timing-sensitive and fails intermittently only under full-target parallel execution; it passes deterministically when run in isolation.
- **Relation to 14-07:** None. Plan 14-07 is a pure analytics dependency-hardening pass that only adds `import AnalyticsClient` and `$0.analyticsClient = .noop` to `TestStore` closures. This test constructs no `TestStore` and references no analytics; the file's only 14-07 edit is to a different test's store. Confirmed pre-existing (baseline was reported green; this test passes in isolation post-change).
- **Recommendation:** Stabilize the coordinator progress-flush timing test (e.g. inject a controllable clock or relax the batching-window assertion) in a dedicated test-reliability change. Not fixed here to keep 14-07 a pure hardening pass with an additive-only diff.

## Search success-bucket test coverage gap (surfaced by plan 14-12)

- **Gap:** `SearchFeatureTests/AnalyticsEmissionTests` asserts the `searchPerformed` result bucket on the *failure* arm (bucket `0`) and asserts the `SearchShape` derivation with multi-word/tag fixtures, but does not assert a *non-zero* success-arm result bucket. The emission code itself is correct — it sends `CountBucket(count: response.galleries.count)` from the fetch-completion case.
- **Cause:** the assertion requires constructing a `GalleriesResult` fixture, whose type lives in `NetworkingFeature`, and the `searchFeatureTests` target declared by plan 14-01 has no `.module(.networkingFeature)` edge. Plan 14-12 correctly declined to edit `AppPackage/Package.swift` under the wave-6 manifest-freeze rule and reported the gap instead.
- **Note on the freeze:** the manifest-freeze rationale is parallel sibling builds within wave 6. This run executed wave 6 sequentially (worktree isolation auto-degraded off per #683), so the hazard did not actually materialize — the edge can be added safely once wave 6's manifest-sensitive plans are complete.
- **Recommendation:** after wave 6, add `.module(.networkingFeature)` to the `searchFeatureTests` target in `AppPackage/Package.swift`, then add a success-arm test asserting a non-zero `CountBucket` result. Verify against the `-only-testing:SearchFeatureTests` gate. This is the phase's only known coverage gap.
