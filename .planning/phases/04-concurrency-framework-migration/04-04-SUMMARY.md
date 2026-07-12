---
phase: 04-concurrency-framework-migration
plan: 04
subsystem: networking-tests
tags: [swift-testing, gallery-lists, gdata, request-parity, urlprotocol]

requires:
  - phase: 04-concurrency-framework-migration
    provides: Injectable sessions and offline counting harness
provides:
  - Frozen URL and parse behavior for all 12 gallery-list requests
  - Frozen structural gdata POST, decode, retry, and error behavior
affects: [04-08]

tech-stack:
  added: []
  patterns:
    - Semantic full-URL assertions independent of query-item ordering
    - Structural JSON request-body characterization

key-files:
  created:
    - AppPackage/Tests/NetworkingFeatureTests/GalleryRequestBaselineTests.swift
    - AppPackage/Tests/NetworkingFeatureTests/GalleriesMetadataBaselineTests.swift
    - .planning/phases/04-concurrency-framework-migration/04-04-SUMMARY.md
  modified: []

key-decisions:
  - "Gallery URLs are compared by exact scheme, host, path, and query dictionary so nondeterministic Dictionary iteration cannot make the baseline flaky."
  - "The metadata baseline targets one concrete gdata POST; caller-side chunking remains outside this transport contract."

requirements-completed: [CONC-01]

coverage:
  - id: D1
    description: "All 12 gallery-list requests freeze URL assembly, parse output, and retry behavior"
    requirement: CONC-01
    verification:
      - kind: other
        ref: "iOS-target swiftc typecheck, SwiftLint, all 12 request-name checks"
        status: pass
      - kind: unit
        ref: "NetworkingFeatureTests iOS Simulator runtime gate"
        status: pass
    human_judgment: false
  - id: D2
    description: "GalleriesMetadataRequest freezes structural gdata assembly, decoding, errors, and four attempts"
    requirement: CONC-01
    verification:
      - kind: other
        ref: "iOS-target swiftc typecheck and SwiftLint"
        status: pass
      - kind: unit
        ref: "NetworkingFeatureTests iOS Simulator runtime gate"
        status: pass
    human_judgment: false

duration: 18min
completed: 2026-07-13
status: complete
---

# Phase 04 Plan 04: Gallery Lists and Metadata Baselines Summary

**The highest-traffic gallery-list URLs and gdata metadata transport are frozen against the pre-migration Combine layer.**

## Performance

- **Duration:** 18 min
- **Completed:** 2026-07-13
- **Tasks:** 2
- **Files:** 2

## Accomplishments

- Characterized all 12 gallery-list request pipelines with exact URL semantics and deterministic parse output.
- Locked persistent-failure retry behavior at four attempts.
- Locked the gdata JSON contract, successful decode path, parse failure, and network failure mapping.

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `e5500fcf` | Lock gallery-list request behavior |
| 2 | `f2923185` | Lock gdata metadata behavior |

## Deviations from Plan

### [Rule 3 - Blocking] Executed inline after provider executor quota exhaustion

- **Found during:** Wave 3 execution
- **Issue:** Typed executor dispatch and the generic-agent workaround were unavailable.
- **Fix:** Followed execute-plan inline with the same read-first, lint, verification, and commit gates.
- **Verification:** Both files pass SwiftLint, parsing, and iOS simulator-target typechecking.

**Total deviations:** 1 execution-environment deviation. **Impact:** No scope or behavior change.

## Issues Encountered

- The deferred runtime gate passed after elevated capacity reset: 76 tests in 9 suites, 0 issues.

## Next Phase Readiness

- Ready for 04-05 and for the typed-throws re-run in 04-08.

## Self-Check: PASSED

- All created files and both task commits exist.
- Static acceptance, SwiftLint, and iOS-target typechecking pass.
- Full `NetworkingFeatureTests` simulator execution passed.
