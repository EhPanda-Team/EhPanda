---
phase: 04-concurrency-framework-migration
plan: 03
subsystem: networking-tests
tags: [swift-testing, combine-parity, urlprotocol, request-assembly, retry]

requires:
  - phase: 04-concurrency-framework-migration
    provides: Injectable request sessions and the counting offline harness from plans 04-01/04-02
provides:
  - Frozen routine-request assembly, parsing, retry, chain, and AppError behavior
  - Frozen assembly and response mapping for all 14 account requests
affects: [04-06, 04-07]

tech-stack:
  added: []
  patterns:
    - Token-isolated URLProtocol characterization tests
    - Structural form and JSON body assertions independent of dictionary ordering

key-files:
  created:
    - AppPackage/Tests/NetworkingFeatureTests/RoutineRequestBaselineTests.swift
    - AppPackage/Tests/NetworkingFeatureTests/AccountRequestBaselineTests.swift
    - .planning/phases/04-concurrency-framework-migration/04-03-SUMMARY.md
  modified: []

key-decisions:
  - "Account form bodies are decoded to dictionaries before comparison, preserving semantics without relying on Dictionary iteration order."
  - "IgneousRequest's empty-publisher behavior is characterized with a private non-HTTP URLProtocol response and no shared mutable test state."

requirements-completed: [CONC-01]

coverage:
  - id: D1
    description: "Routine requests freeze assembly, parsing, retries, TagTranslator branching, and AppError mapping"
    requirement: CONC-01
    verification:
      - kind: other
        ref: "manual swiftc typecheck and SwiftLint for RoutineRequestBaselineTests.swift"
        status: pass
    human_judgment: true
    rationale: "The exact simulator runtime suite remains pending until CoreSimulator elevation is available."
  - id: D2
    description: "All 14 account requests freeze structural body assembly and response mapping"
    requirement: CONC-01
    verification:
      - kind: other
        ref: "manual swiftc typecheck, 15 @Test declarations, all 14 request names, and SwiftLint"
        status: pass
    human_judgment: true
    rationale: "The exact simulator runtime suite remains pending until CoreSimulator elevation is available."

duration: 25min
completed: 2026-07-13
status: complete
---

# Phase 04 Plan 03: Routine and Account Request Baselines Summary

**Offline characterization coverage now freezes the complete routine and account request families before their async rewrite.**

## Performance

- **Duration:** 25 min
- **Completed:** 2026-07-13
- **Tasks:** 2
- **Files:** 2

## Accomplishments

- Locked four routine requests, four TagTranslator paths, retry counts, and the complete AppError mapping table.
- Locked all 14 account request types with structural form/JSON assembly checks and response mapping.
- Kept every fixture offline and every credential value deliberately synthetic.

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `bf66cc35` | Lock routine request behavior |
| 2 | `94d994c0` | Lock account request behavior |

## Deviations from Plan

### [Rule 3 - Blocking] Continued inline after executor quota exhaustion

- **Found during:** Task 2 handoff
- **Issue:** The executor quota expired after Task 1 committed.
- **Fix:** Recovered the clean task boundary and executed Task 2 inline under the same GSD and project rules.
- **Verification:** The new test sources pass Swift parsing, iOS simulator-target typechecking, SwiftLint, and all static acceptance checks.

**Total deviations:** 1 blocking execution-environment issue resolved inline. **Impact:** No product or test-scope change.

## Issues Encountered

- CoreSimulator execution is pending because sandbox elevation is temporarily unavailable. The phase-wide elevated test gate must run the exact NetworkingFeatureTests suite before verification.

## Next Phase Readiness

- Ready for plans 04-04 and 04-05; the runtime gate remains queued for the phase-wide test pass.

## Self-Check: PENDING RUNTIME GATE

- Created files exist and both task commits are present.
- Static acceptance criteria, SwiftLint, parse, and iOS-target typecheck pass.
- Exact simulator execution is intentionally not claimed until the elevated phase gate runs.
