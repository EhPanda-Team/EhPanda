# Codebase Concerns

**Analysis Date:** 2026-07-09

## Tech Debt

**Migration engine has no real v2 schemas yet:**
- Issue: The progressive schema-migration engine is fully built and tested, but every persisted `@Shared` model still sits at v1. The migration paths are exercised only by throwaway mock models. Correctness against a real breaking change is unproven until the first v2 lands.
- Files: `AppPackage/Sources/AppModels/` (persisted models), `AppPackage/Tests/AppModelsTests/SchemaMigrationTests.swift`
- Impact: First real model change may reveal engine gaps not covered by mocks; contributors may not know the "add a VersionedSchema, then delete the mock" workflow.
- Fix approach: When the first breaking model change arrives, add a real `VersionedSchema` to that model's `schemas` array and delete the corresponding mock + its tests (per the header comment in `SchemaMigrationTests.swift`).

**Throwaway mock models living in the test suite:**
- Issue: `SchemaMigrationTests.swift` defines `ProgressiveMock` and one mock per shape (RENAME/ADD/REMOVE/TYPE/DERIVE/MERGE) explicitly marked "REMOVE when real v2 models land."
- Files: `AppPackage/Tests/AppModelsTests/SchemaMigrationTests.swift`
- Impact: These mocks are scaffolding, not product coverage. If left after real v2 schemas appear, they become dead maintenance weight.
- Fix approach: Delete per-model mocks as each model gets a real v2; keep only engine-level shape coverage.

**HTML-scraping parsers carry heavy complexity suppressions:**
- Issue: The `ParserFeature` module repeatedly suppresses `cyclomatic_complexity` and `function_body_length` because it parses raw website HTML.
- Files: `AppPackage/Sources/ParserFeature/Parser+Profile.swift`, `Parser+Comment.swift`, `Parser+Detail.swift`, `Parser+Torrent.swift`, `Parser+Greeting.swift`, `Parser+Shared.swift`
- Impact: Long, branch-heavy functions are hard to modify safely and hard to review.
- Fix approach: Extract per-field sub-parsers to shrink function bodies; the inline `swiftlint:disable:next` markers point at the exact hotspots.

## Known Bugs

**No known open bugs surfaced during this scan.** No `TODO`/`FIXME`/`HACK`/`XXX` markers exist anywhere in Swift sources, and no `try!`/`as!`/force-unwrap hotspots outside the standard TCA placeholder pattern.

## Security Considerations

**Session cookies live in `HTTPCookieStorage`, not the Keychain:**
- Risk: EHentai/ExHentai authentication is cookie-based (`ipb_member_id`, `ipb_pass_hash`, `igneous`). These sit in the shared `HTTPCookieStorage`, which is less protected than the Keychain.
- Files: `AppPackage/Sources/CookieClient/CookieClient.swift`
- Current mitigation: Standard iOS cookie-store data protection (encrypted at rest with device passcode); credentials never logged (OSLog usage elsewhere marks sensitive values `privacy: .private` by default).
- Recommendations: Evaluate moving the durable auth cookies to Keychain-backed storage; audit that no cookie values are ever emitted to `LogsClient`/OSLog with `.public` privacy.

## Performance Bottlenecks

**Download subsystem is the largest and most complex area:**
- Problem: `DownloadClient` spans many large files coordinating concurrent page downloads, background tasks, and response validation.
- Files: `AppPackage/Sources/DownloadClient/DownloadStore.swift` (555 lines), `DownloadClient+Manager.swift` (457), `DownloadPageDownloader.swift` (434), `DownloadClient+ExecutionSupport.swift` (427), `DownloadClient+ResponseValidationHelpers.swift` (357), `BackgroundTaskClient.swift`
- Cause: Concurrency and scheduling logic concentrated in a few files; historically a flaky scheduling test existed here (fixed in `557b0425`).
- Improvement path: Any regression in download scheduling timing is now a real regression, not flake — treat `DownloadSchedulingTests` failures as signal.

## Fragile Areas

**Website-HTML parsing:**
- Files: `AppPackage/Sources/ParserFeature/*`
- Why fragile: Parsers are tightly coupled to EHentai/ExHentai page structure. Any upstream markup change silently breaks detail, comment, profile, greeting, or torrent parsing.
- Safe modification: Change one field-parser at a time and back it with a fixture-based `ParserFeatureTests` case; never widen a regex without a covering test.
- Test coverage: `ParserFeatureTests` exists — extend it before touching parser internals.

**`Category.private.filterValue` traps:**
- Files: `AppPackage/Sources/AppModels/Gallery/Category.swift:45`
- Why fragile: `filterValue` calls `fatalError` for the `.private` case ("`Private` doesn't have a `filterValue`!"). Any code path that computes a filter bitmask over all categories including `.private` will crash the app.
- Safe modification: Guard/exclude `.private` before calling `filterValue`, or change the return to an optional. Confirm no callsite iterates `Category.allCases` into `filterValue`.

## Scaling Limits

**Not applicable** — this is a client app with no server-side capacity model. Practical limits are per-gallery download concurrency and on-device image cache size (`AppTools/DataCache.swift`, 330 lines), both bounded by device resources rather than a hard ceiling in code.

## Dependencies at Risk

**Not detected** — third-party dependencies are centralized in `AppPackage/Package.swift`; no dependency is flagged as abandoned or blocking in-repo. (A full advisory audit was out of scope for this static scan.)

## Missing Critical Features

**None blocking** — no feature-gap stubs (empty returns, unimplemented cases) were found beyond the intentional `.private` category exclusion noted above.

## Test Coverage Gaps

**Client and feature modules without a test target:**
- What's not tested: 37 of ~44 modules under `AppPackage/Sources` have no matching `AppPackage/Tests/<Module>Tests` directory. Notably absent: `DownloadClient` (largest subsystem), `CookieClient` (auth/security), `ImageClient`, `ReadingFeature`, `HomeFeature`, `SearchFeature`, `FavoritesFeature`, `NetworkingFeature`.
- Files: entire subtrees under `AppPackage/Sources/{DownloadClient,CookieClient,ImageClient,ReadingFeature,HomeFeature,SearchFeature,FavoritesFeature}/`
- Risk: Regressions in downloading, auth-cookie handling, and image caching would land unnoticed. These are the highest-blast-radius areas of the app.
- Priority: High — `DownloadClient` and `CookieClient` first (complexity + security), then `ImageClient`.

**Well-covered areas (for contrast):** `AppModelsTests` (migration + model mocks), `ParserFeatureTests`, and reducer-level tests exist; 87 test files total. The gap is in the client layer, not the model/parser layer.

---

*Concerns audit: 2026-07-09*
</content>
</invoke>
