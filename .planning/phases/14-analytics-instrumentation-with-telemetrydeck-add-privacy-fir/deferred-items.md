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
- **RESOLVED (14-17, 2026-07-25):** the edge was added once wave 6 completed and the freeze lifted; `aSuccessfulSearchRecordsThePerformedSignalWithTheResultBucket` asserts three fixture galleries land in the 2-5 bucket. SearchFeatureTests now runs 10 tests, green.

## `updateDownloadDone` has no expressible outcome (surfaced by plan 14-15)

- **Gap:** `DownloadsReducer` has an `updateDownloadDone(Result<Void, AppError>)` completion case — the user re-fetching a gallery flagged `updateAvailable`. It is a genuine user-visible download outcome but is **not** instrumented, because `DownloadOutcome` has no case able to express it (`started`, `retried`, `completed`, `failed`, `deleted`, `moved`, plus `paused`/`resumed` once D-20 lands).
- **Why it was raised rather than instrumented:** exactly the same situation as pause/resume before D-20. Widening a locked signal vocabulary is an owner decision, not an executor's, and plan 14-15's instructions were explicit about raising rather than silently instrumenting.
- **Options for the owner:** (a) leave it unmeasured, so an update reads as no outcome at all; (b) add an `updated` case to `DownloadOutcome` and emit from the success arm, mirroring what D-20 does for pause/resume; (c) map it onto the existing `completed` outcome, which conflates a fresh download with an update and is **not** recommended — that is the "two things under one name" error D-16 and the download-failure ownership split both exist to avoid.
- **Recommendation:** decide alongside D-20's implementation in plan 14-17, since both are the same kind of vocabulary question and touch the same enum.
- **RESOLVED (14-17, 2026-07-25):** the owner chose option (b), recorded as D-21 with a naming correction — `.updated` emits at queue time from both the list's `updateDownloadDone` and detail's mode-`.update` retry path, so one intent carries one name from either screen.
