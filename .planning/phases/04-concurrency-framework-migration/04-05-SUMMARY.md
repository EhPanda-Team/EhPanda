---
phase: 04-concurrency-framework-migration
plan: 05
subsystem: networking-tests
tags: [swift-testing, detail, images, combine-parity, fan-out]

requires:
  - phase: 04-concurrency-framework-migration
    provides: Injectable sessions and offline counting harness
provides:
  - Frozen behavior for all seven Request+Detail request types
  - Frozen behavior for all six Request+Image request types and fan-out/refetch chains
affects: [04-09]

tech-stack:
  added: []
  patterns:
    - Per-step attempt accounting for chained publishers
    - Original-index restoration checks for concurrent image fan-out

key-files:
  created:
    - AppPackage/Tests/NetworkingFeatureTests/DetailRequestBaselineTests.swift
    - AppPackage/Tests/NetworkingFeatureTests/ImageRequestBaselineTests.swift
    - .planning/phases/04-concurrency-framework-migration/04-05-SUMMARY.md
  modified: []

key-decisions:
  - "The established GalleryDetail parser fixture is read directly from the repository so the request baseline exercises the exact proven payload without duplicating a 50 KB fixture."
  - "Actual source ownership governs coverage: GalleryPreviewURLsRequest is tested with Request+Detail; MPVKeysRequest and DataRequest are tested with Request+Image."

requirements-completed: [CONC-01]

coverage:
  - id: D1
    description: "Every detail request freezes assembly, parsing, gdata, and multi-step attempt behavior"
    requirement: CONC-01
    verification:
      - kind: other
        ref: "iOS-target swiftc typecheck, SwiftLint, and source-name coverage"
        status: pass
      - kind: unit
        ref: "NetworkingFeatureTests iOS Simulator runtime gate"
        status: pass
    human_judgment: false
  - id: D2
    description: "Every image request freezes fan-out, refetch, MPV, and raw-data behavior"
    requirement: CONC-01
    verification:
      - kind: other
        ref: "iOS-target swiftc typecheck, SwiftLint, and source-name coverage"
        status: pass
      - kind: unit
        ref: "NetworkingFeatureTests iOS Simulator runtime gate"
        status: pass
    human_judgment: false

duration: 22min
completed: 2026-07-13
status: complete
---

# Phase 04 Plan 05: Detail and Image Request Baselines Summary

**The two most structurally complex request families now have offline parity coverage before their async rewrite.**

## Performance

- **Duration:** 22 min
- **Completed:** 2026-07-13
- **Tasks:** 2
- **Files:** 2

## Accomplishments

- Characterized all seven detail-family requests, including gdata and both multi-step chains.
- Characterized all six image-family requests, including three-way fan-out and whole-chain refetch retries.
- Locked index restoration, healthy/failing child attempt counts, HTTP response preservation, and raw data behavior.

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `a76ee454` | Lock detail request behavior |
| 2 | `9dabc05c` | Lock image request behavior |

## Deviations from Plan

### [Rule 1 - Bug] Corrected the plan's illustrative file ownership

- **Found during:** Read-first source inventory
- **Issue:** The plan listed MPVKeysRequest with Request+Detail and GalleryPreviewURLsRequest with Request+Image, opposite their actual declarations.
- **Fix:** Covered every struct in its authoritative source file as the plan's explicit confirm-the-file rule requires.
- **Verification:** All seven detail structs and all six image structs appear in their corresponding suites.

### [Rule 3 - Blocking] Executed inline after provider executor quota exhaustion

- **Found during:** Wave 3 execution
- **Fix:** Followed execute-plan inline with all read-first, lint, typecheck, and atomic commit gates.

**Total deviations:** 2 auto-fixed (1 plan inventory bug, 1 execution-environment blocker). **Impact:** Coverage is more accurate; product behavior is unchanged.

## Issues Encountered

- The deferred runtime gate passed after elevated capacity reset: 76 tests in 9 suites, 0 issues.

## Next Phase Readiness

- The full 44-request Wave 0 baseline is statically complete and ready for the async engine/migration plans.

## Self-Check: PASSED

- All created files and both task commits exist.
- Static acceptance, SwiftLint, and iOS-target typechecking pass.
- Full `NetworkingFeatureTests` simulator execution passed.
