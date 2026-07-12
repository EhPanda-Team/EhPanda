---
phase: 04-concurrency-framework-migration
plan: 09
subsystem: networking
tags: [swift-concurrency, typed-throws, task-group, images, detail]

requires:
  - phase: 04-concurrency-framework-migration
    provides: Async fetch and gdata plumbing plus frozen detail/image baselines
provides:
  - Typed async response methods for all seven detail requests
  - Typed async response methods for all six image requests
  - Per-child retry task-group fan-out and whole-chain image refetch retry parity
affects: [04-10, 04-11, 04-12, 04-13]

tech-stack:
  added: []
  patterns:
    - Sendable task-group result records for indexed image fan-out
    - Explicit whole-chain retry loop for multi-step refetch parity

key-files:
  created:
    - .planning/phases/04-concurrency-framework-migration/04-09-SUMMARY.md
  modified:
    - AppPackage/Sources/NetworkingFeature/Request+Detail.swift
    - AppPackage/Sources/NetworkingFeature/Request+Image.swift
    - AppPackage/Tests/NetworkingFeatureTests/DetailRequestBaselineTests.swift
    - AppPackage/Tests/NetworkingFeatureTests/ImageRequestBaselineTests.swift

key-decisions:
  - "GalleryReverse and GalleryArchiveFunds retry their first fetch while their second fetch remains bare and un-retried."
  - "Image refetch retries the entire three-step chain four times, matching the publisher-level retry placement."
  - "Fan-out uses a Sendable NormalImageInfo record because the compiler crashes on the equivalent labeled-tuple task-group expression."

requirements-completed: [CONC-01]

coverage:
  - id: D1
    description: "All seven detail requests preserve parsing, gdata, and chained retry placement through typed async"
    requirement: CONC-01
    verification:
      - kind: unit
        ref: "DetailRequestBaselineTests through the NetworkingFeatureTests simulator gate"
        status: pass
    human_judgment: false
  - id: D2
    description: "All six image requests preserve fan-out ordering, per-child retry, fail-fast behavior, and whole-chain refetch retry"
    requirement: CONC-01
    verification:
      - kind: unit
        ref: "ImageRequestBaselineTests through the NetworkingFeatureTests simulator gate"
        status: pass
      - kind: unit
        ref: "Full AppPackage iOS Simulator test suite"
        status: pass
    human_judgment: false

duration: 9min
completed: 2026-07-13
status: complete
---

# Phase 04 Plan 09: Detail and Image Async Migration Summary

**All 44 request structs now have parity-proven typed-throws bodies, including chained detail operations and indexed image fan-out.**

## Performance

- **Duration:** 9 min
- **Completed:** 2026-07-13
- **Tasks:** 2
- **Files:** 4

## Accomplishments

- Migrated all seven detail request types, including shared gdata delegation and two-step retry asymmetry.
- Migrated all six image request types, including per-child retry fan-out and index-keyed result restoration.
- Preserved the refetch pipeline's publisher-level retry by rerunning its complete three-step chain up to four times.
- Flipped the frozen detail and image suites to concrete typed async acquisition with all assertions unchanged.

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `02e874b5` | Migrate detail requests and flip parity tests |
| 2 | `768345a5` | Migrate image requests and flip parity tests |

## Deviations from Plan

### [Rule 3 - Blocking] Decomposed a compiler-crashing task-group expression

- **Found during:** Task 2 build verification
- **Issue:** The compiler failed to produce a diagnostic for the inline labeled-tuple `withThrowingTaskGroup` expression.
- **Fix:** Decomposed the child operation into a private async method and used an equivalent private `Sendable` `NormalImageInfo` record as the group element. Retry placement, fail-fast cancellation, and index restoration are unchanged.
- **Verification:** AppFeature builds, the frozen fan-out tests pass, and strict Swift concurrency diagnostics are clean.

### [Rule 3 - Blocking] Kept explicit typed capture signatures

- **Found during:** Both baseline flips
- **Fix:** Used the compiler-required explicit `throws(AppError)` response types established by earlier migration plans.

**Total deviations:** 2 compiler-driven fixes. **Impact:** Implementation shape changed only to avoid a compiler crash; behavior remains proven by the original baselines.

## Validation Results

- SwiftLint over all four modified files — **passed**, 0 violations.
- AppFeature generic iOS Simulator build — **passed**.
- Targeted NetworkingFeatureTests — **passed**, 76 tests in 9 suites.
- Full AppPackage iOS Simulator suite — **passed** (`TEST SUCCEEDED`).
- Typed async request inventory — **passed**, 44 methods across routine, account, gallery, metadata, detail, and image sources.

## Issues Encountered

None outstanding.

## Next Phase Readiness

- The request layer migration is complete; plans 04-10 through 04-12 can switch consumers.
- Publishers remain only for transitional production compatibility until plan 04-13.

## Self-Check: PASSED

- Seven detail and six image typed async methods exist.
- Both migrated baseline files contain no `legacyResponse()` calls.
- Fan-out contains `withThrowingTaskGroup`; targeted and full test gates pass.
