---
phase: 04-concurrency-framework-migration
plan: 06
subsystem: networking
tags: [swift-concurrency, typed-throws, urlsession, retry, parity]

requires:
  - phase: 04-concurrency-framework-migration
    provides: Frozen routine baselines and offline request harness
provides:
  - Typed async URLSession fetch helper with four-attempt transport retry parity
  - Typed-throws response methods for all four routine requests
  - Routine baseline acquisition flipped from Combine to native async
affects: [04-07, 04-08, 04-09, 04-10, 04-13]

tech-stack:
  added: []
  patterns:
    - Fetch-only retry loop with cancellation short-circuit
    - Concrete typed-throws request methods captured as Result for parity tests

key-files:
  created:
    - .planning/phases/04-concurrency-framework-migration/04-06-SUMMARY.md
  modified:
    - AppPackage/Sources/NetworkingFeature/Request.swift
    - AppPackage/Tests/NetworkingFeatureTests/RoutineRequestBaselineTests.swift

key-decisions:
  - "Fetch errors are mapped inside fetch exactly once; parse errors are mapped after fetch returns, so parse failures never retry."
  - "TagTranslator metadata uses the retry helper, while its payload download deliberately remains a single bare URLSession data call."
  - "Native URLSession cancellation is preserved as structured cancellation rather than detached work."

requirements-completed: [CONC-01]

coverage:
  - id: D1
    description: "Fetch helper preserves four attempts, fetch-only retry scope, cancellation, and AppError mapping"
    requirement: CONC-01
    verification:
      - kind: unit
        ref: "RoutineRequestBaselineTests#greetingPersistentTransportFailureRetriesFourTimes"
        status: pass
      - kind: build
        ref: "AppFeature iOS Simulator build"
        status: pass
    human_judgment: false
  - id: D2
    description: "Four routine requests preserve assembly, parsing, errors, and TagTranslator chain asymmetry through typed async"
    requirement: CONC-01
    verification:
      - kind: unit
        ref: "NetworkingFeatureTests iOS Simulator runtime gate"
        status: pass
      - kind: unit
        ref: "Full AppPackage iOS Simulator test suite"
        status: pass
    human_judgment: false

duration: 7min
completed: 2026-07-13
status: complete
---

# Phase 04 Plan 06: Async Engine and Routine Requests Summary

**The native async transport engine is live and all routine requests now prove identical behavior through concrete typed-throws methods.**

## Performance

- **Duration:** 7 min
- **Completed:** 2026-07-13
- **Tasks:** 2
- **Files:** 2

## Accomplishments

- Added a typed `fetch(_:in:)` helper with four total attempts, cancellation short-circuiting, and one AppError funnel per thrown fetch error.
- Added typed-throws `response()` implementations for Greeting, UserInfo, FavoriteCategories, and TagTranslator requests while retaining their temporary Combine publishers.
- Preserved TagTranslator's asymmetric two-step policy: retried metadata, date gate, and un-retried payload download.
- Flipped the frozen routine suite to concrete async acquisition without changing any fixture or expectation.

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `4cb44890` | Add typed async fetch retry helper |
| 2 | `2774c140` | Migrate routine requests and flip parity tests |

## Deviations from Plan

### [Rule 3 - Blocking] Made typed-throws closure result types explicit

- **Found during:** Task 2 compile verification
- **Issue:** Swift inferred trailing `capture` closures as `throws(any Error)` despite the concrete typed-throws call, rejecting conversion to `throws(AppError)`.
- **Fix:** Added explicit `() async throws(AppError) -> Response` signatures to the acquisition closures. Fixtures and assertions remained byte-identical.
- **Verification:** NetworkingFeatureTests and the full AppPackage test suite both pass.

**Total deviations:** 1 compile-blocking inference fix. **Impact:** Test acquisition is more explicit; runtime behavior and assertion scope are unchanged.

## Validation Results

- SwiftLint over both modified Swift files — **passed**, 0 violations.
- AppFeature generic iOS Simulator build — **passed**.
- Targeted NetworkingFeatureTests — **passed**, 76 tests in 9 suites.
- Full AppPackage iOS Simulator suite — **passed** (`TEST SUCCEEDED`).

## Issues Encountered

None outstanding.

## Next Phase Readiness

- The shared typed async engine is proven and ready for account, gallery, detail, and image request migrations.
- Combine publishers remain intentionally until the production call-site flip and deletion plans.

## Self-Check: PASSED

- Both task commits and all declared files exist.
- `RoutineRequestBaselineTests.swift` contains no `legacyResponse()` acquisition.
- Exact targeted and full simulator test gates pass.
