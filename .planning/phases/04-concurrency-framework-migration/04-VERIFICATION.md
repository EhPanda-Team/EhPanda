---
phase: 04-concurrency-framework-migration
verified: 2026-07-13T08:35:00+09:00
status: passed
score: 4/4 must-haves verified
requirements_verified: [CONC-01, CONC-02]
behavior_unverified: 0
behavior_unverified_items: []
gaps: []
human_verification: []
---

# Phase 4 Verification Report

**Phase goal:** Move the request layer to async/await and pin TCA with deprecation traits, preserving request and reducer behavior.

**Result:** PASSED. All four roadmap success criteria and both phase requirements are proven by current source, frozen parity tests, clean builds, the full regression suite, code review, and simulator UAT.

## Goal Scorecard

| # | Success criterion | Status | Evidence |
|---|-------------------|--------|----------|
| 1 | NetworkingFeature returns async results with no `AnyPublisher`; request behavior and error paths are preserved | VERIFIED | 44 Request conformers; protocol plus 44 typed-throws implementations; zero publisher/facade symbols; 76 NetworkingFeature tests and frozen request baselines pass |
| 2 | The four named clients and all consuming reducer effects are off Combine | VERIFIED | Zero `import Combine` under AppPackage/Sources; zero legacy facade calls; all 64 production consumers migrated; full reducer/client suite passes |
| 3 | TCA is pinned from 1.25.3 with both 2.0 deprecation traits | VERIFIED | Manifest contains the required floor and both traits; both lockfiles resolve the canonical package at 1.26.0 |
| 4 | Zero TCA deprecation warnings remain and reducer/store behavior is identical | VERIFIED | Positive control proved traits active before fixes; final app and package logs contain zero deprecation warnings; full suite and four-flow simulator UAT pass |

**Score:** 4/4.

## Requirements Coverage

### CONC-01 — Combine requests to async/await

**Status:** SATISFIED

- `Request` requires `func response() async throws(AppError) -> Response`.
- Exactly 44 concrete request structs conform; the 45 signature grep matches are the protocol requirement plus those 44 implementations.
- AppPackage sources contain zero `AnyPublisher` and zero Combine imports.
- Sources and tests contain zero `legacyResponse` references.
- The Result facade, main-queue hop, retry publisher, continuation bridge, and Combine gdata plumbing are deleted.
- ApplicationClient, AuthorizationClient, ImageClient, and LibraryClient retain their behavior and no longer import Combine.
- All production consumers await typed responses directly or send the same existing Result actions through explicit typed catches.

### CONC-02 — TCA traits and zero deprecations

**Status:** SATISFIED

- `AppPackage/Package.swift` uses `from: "1.25.3"` and enables:
  - `ComposableArchitecture2Deprecations`
  - `ComposableArchitecture2DeprecationOverloads`
- Both resolved files pin `swift-composable-architecture` 1.26.0 at revision `e2fa1df6cd9eec6fa6314aa20513e47da576f24e`.
- A clean reconnaissance build emitted the expected `PopularView.swift:36` warning before fixes, proving trait activation.
- The owner authorized the D-11 expansion from 24 expected sites to the complete 66-site compiler inventory.
- All 45 presentation scopes, 11 Store scopes, and 10 Scope initializers use current APIs.
- Final app and package logs contain zero TCA deprecation warnings.

## Behavioral Parity

### Transport, retry, and error mapping

- Frozen baselines cover URL, method, headers, body, parse output, error mapping, and request counts across the routine, account, gallery, detail, image, and gdata families.
- Transport failures retry four total times; successful requests execute once.
- Parse failures remain outside the retry loop.
- TagTranslator retries metadata and performs its payload download once.
- Detail and archive multi-step requests preserve their original per-step retry asymmetry.
- Image refetch retries the complete three-step chain four times.
- Server response text still survives parser failure through `ResponseParsingError` and `mapAppError`.

### Structured concurrency

- Gallery metadata keeps 25-pair chunks, at most two concurrent requests, failure cancellation, and input-order reconstruction.
- Image fan-out uses a throwing task group and Sendable result record with no shared mutable state.
- Native task cancellation propagates into URLSession and stops transport work immediately.

### Reducers and presentation

- Existing Done actions and Result handlers remain unchanged.
- Reading and detail cancellation identifiers and send order remain unchanged.
- DownloadClient public signatures remain unchanged.
- Presentation modifiers remain attached to their original controls and containers.
- Root tabs, a projected Filters sheet, an anchored confirmation popover, detail navigation, and the full-screen reader were exercised successfully on the current simulator build.

## Automated Checks

| Check | Result |
|-------|--------|
| AppFeature generic iOS Simulator build | PASS — `BUILD SUCCEEDED`; zero TCA deprecation warnings |
| Full AppPackage iPhone Air suite | PASS — `TEST SUCCEEDED`; zero TCA deprecation warnings |
| NetworkingFeature frozen baseline | PASS — 76 tests in 9 suites |
| Full reducer/client regression group | PASS — 261 tests in 53 suites, plus every remaining package test group |
| SwiftLint over Plan 04-14 Swift files | PASS — 0 violations |
| Combine import grep under Sources | PASS — 0 matches |
| AnyPublisher grep under Sources | PASS — 0 matches |
| Legacy request facade grep under Sources and Tests | PASS — 0 matches |
| Deprecated destination-scope grep | PASS — 0 matches |
| TCA positive control before fixes | PASS — one unique `PopularView.swift:36` warning |
| Manifest trait/version and lockfile checks | PASS |

## Simulator UAT

The current Debug app was installed on iPhone Air running iOS 26.5. Four representative flows passed:

1. Home, Search, and Setting root tab scopes rendered and remained interactive.
2. Search Filters presented through the projected destination scope and dismissed back to Search.
3. General Settings presented the clear-cache confirmation popover from its trigger and dismissed without destructive action.
4. A Home gallery opened Detail; Read presented full-screen; Close returned to the same Detail state.

Full evidence is recorded in `04-UAT.md`.

## Code Review

Phase-wide standard review covered 74 source, manifest, and test files. Status: **clean** with zero critical, warning, or informational findings. See `04-REVIEW.md`.

## Regression Gate

The full AppPackage suite includes the earlier milestone's dependency, masonry-layout, reader, parser, networking, reducer, and client tests. It passed after all Phase 4 commits. The current simulator UAT also traversed the native Home and Reading surfaces delivered by Phases 2 and 3.

## Security and Trust Boundaries

- Domain-fronting transport files were not modified; all seven DF request semantics tests pass.
- The offline harness rejects unknown URLs and tokens instead of allowing live-network fallback.
- No dependency was added; the existing canonical TCA repository and revision remain in use.
- No unchecked Sendable conformance, preconcurrency suppression, continuation bridge, or detached task was introduced.

## Accepted Delta

Native URLSession structured cancellation stops active HTTP work immediately. The former continuation bridge could leave it running, while TCA discarded the cancelled effect send in either implementation. This intentional resource improvement does not change user-visible behavior.

## Advisory

The non-blocking codebase-drift gate reports 16 pre-existing unmapped repository-root and GitHub configuration paths with no last mapped commit. Its directive is `warn`, not `auto-remap`; none is part of the Phase 4 source surface.

## Final Determination

Phase 4 achieved its stated goal. CONC-01 and CONC-02 are complete, no verification debt remains, and the phase can be marked complete.
