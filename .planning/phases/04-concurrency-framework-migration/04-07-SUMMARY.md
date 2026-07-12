---
phase: 04-concurrency-framework-migration
plan: 07
subsystem: networking
tags: [swift-concurrency, typed-throws, account, urlsession, parity]

requires:
  - phase: 04-concurrency-framework-migration
    provides: Typed async fetch engine and frozen account baselines
provides:
  - Typed-throws response methods for all 14 account requests
  - Executable parity proof for credentialed form and JSON request assembly
affects: [04-10, 04-13]

tech-stack:
  added: []
  patterns:
    - Verbatim request assembly reused before typed async fetch
    - Optional and required HTTP response casts preserve distinct legacy semantics

key-files:
  created:
    - .planning/phases/04-concurrency-framework-migration/04-07-SUMMARY.md
  modified:
    - AppPackage/Sources/NetworkingFeature/Request+Account.swift
    - AppPackage/Tests/NetworkingFeatureTests/AccountRequestBaselineTests.swift

key-decisions:
  - "Login preserves an optional HTTPURLResponse result; Igneous guard-casts and throws unknown when the response is not HTTP."
  - "All form and JSON assembly blocks remain structurally identical to their temporary publisher counterparts."

requirements-completed: [CONC-01]

coverage:
  - id: D1
    description: "All 14 account requests expose typed async response methods with preserved assembly and mapping"
    requirement: CONC-01
    verification:
      - kind: unit
        ref: "AccountRequestBaselineTests through the NetworkingFeatureTests simulator gate"
        status: pass
      - kind: build
        ref: "AppFeature iOS Simulator build"
        status: pass
    human_judgment: false
  - id: D2
    description: "Account retry count and optional/non-HTTP response behavior remain frozen"
    requirement: CONC-01
    verification:
      - kind: unit
        ref: "AccountRequestBaselineTests#retry and Igneous mapping tests"
        status: pass
      - kind: unit
        ref: "Full AppPackage iOS Simulator test suite"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-07-13
status: complete
---

# Phase 04 Plan 07: Account Request Async Migration Summary

**All 14 account operations now have typed-throws async bodies with their credentialed form and JSON contracts proven unchanged.**

## Performance

- **Duration:** 8 min
- **Completed:** 2026-07-13
- **Tasks:** 2
- **Files:** 2

## Accomplishments

- Added typed async bodies to every account request while retaining publishers for the later deletion plan.
- Preserved Login's optional HTTP response and Igneous's empty-publisher-to-unknown behavior exactly.
- Reused every POST assembly block and proved its semantic form or JSON body through the frozen account suite.
- Re-proved the four-attempt account transport policy through the typed async fetch engine.

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `24e10fea` | Add the first seven account async bodies |
| 2 | `60fdfa16` | Complete account bodies and flip parity tests |

## Deviations from Plan

### [Rule 1 - Bug] Resolved the first-task inventory off-by-one

- **Found during:** Task 1 source inventory
- **Issue:** The plan said “first 7 … through SubmitEhSettingChangesRequest,” but that request is sixth in authoritative file order.
- **Fix:** Included FavorGalleryRequest as the seventh body, satisfying the explicit seven-occurrence gate and leaving seven requests for Task 2.

### [Rule 3 - Blocking] Kept explicit typed-throws closure signatures

- **Found during:** Baseline acquisition flip
- **Issue:** The compiler does not infer `throws(AppError)` for these generic `capture` trailing closures.
- **Fix:** Used explicit response types on capture closures, omitting redundant `Void` return syntax to satisfy SwiftLint.

**Total deviations:** 2 auto-fixed (1 inventory error, 1 compiler-inference requirement). **Impact:** The intended 7+7 split and all frozen assertions are preserved.

## Validation Results

- SwiftLint over both modified files — **passed**, 0 violations.
- AppFeature generic iOS Simulator build — **passed**.
- Targeted NetworkingFeatureTests — **passed**, 76 tests in 9 suites.
- Full AppPackage iOS Simulator suite — **passed** (`TEST SUCCEEDED`).

## Issues Encountered

None outstanding.

## Next Phase Readiness

- Account transport is ready for the production reducer call-site flip.
- Publishers remain intentionally until plan 04-13 removes the Combine layer.

## Self-Check: PASSED

- Fourteen typed async account methods exist.
- The account baseline contains no `legacyResponse()` calls.
- Targeted and full simulator gates pass.
