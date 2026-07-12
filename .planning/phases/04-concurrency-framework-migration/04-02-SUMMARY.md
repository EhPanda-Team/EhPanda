---
phase: 04-concurrency-framework-migration
plan: 02
subsystem: testing
tags: [swift-testing, urlprotocol, synchronization, typed-throws, offline-fixtures]

requires:
  - phase: 04-concurrency-framework-migration
    provides: Request URLSession injection seams from plan 04-01
provides:
  - Per-test-token URLProtocol harness with per-URL scripts, attempt counts, and request recording
  - Stream-safe POST body capture with routing headers removed from recorded requests
  - Typed-throws capture adapter for concrete request parity assertions
affects: [04-03, 04-04, 04-05, 04-06, 04-07, 04-08, 04-09]

tech-stack:
  added: []
  patterns:
    - Mutex-guarded registry keyed by a per-session UUID token
    - Concrete-call typed-throws closures adapted to Result for parity assertions

key-files:
  created:
    - AppPackage/Tests/NetworkingFeatureTests/Support/CountingStubProtocol.swift
    - AppPackage/Tests/NetworkingFeatureTests/Support/RequestHarness.swift
    - AppPackage/Tests/NetworkingFeatureTests/Support/HarnessSelfTests.swift
  modified: []

key-decisions:
  - "Unknown URLs and missing or stale routing tokens fail inside CountingStubProtocol instead of falling through to live networking."
  - "The capture adapter accepts a closure formed on a concrete request type so protocol-extension static dispatch cannot fake parity."

patterns-established:
  - "Offline request parity: every stubbed session carries a unique header token and an isolated script state."
  - "Script exhaustion repeats the final per-URL step, allowing one failure step to model persistent transport failure."

requirements-completed: [CONC-01]

coverage:
  - id: D1
    description: "Offline counting URLProtocol harness with isolated scripts, recorded requests, and streamed-body capture"
    requirement: CONC-01
    verification:
      - kind: unit
        ref: "AppPackage/Tests/NetworkingFeatureTests/Support/HarnessSelfTests.swift#isolation, counting, and body-capture tests"
        status: pass
      - kind: other
        ref: "SwiftLint over all three support files"
        status: pass
    human_judgment: false
  - id: D2
    description: "Typed-throws capture adapter for concrete request parity assertions"
    requirement: CONC-01
    verification:
      - kind: unit
        ref: "AppPackage/Tests/NetworkingFeatureTests/Support/HarnessSelfTests.swift#captureMapsTypedSuccessAndFailure"
        status: pass
      - kind: other
        ref: "NetworkingFeatureTests test-bundle compilation"
        status: pass
    human_judgment: false

duration: 9min
completed: 2026-07-13
status: complete
---

# Phase 04 Plan 02: Offline Request Parity Harness Summary

**Token-isolated URLProtocol scripting with retry counts, exact request capture, streamed POST bodies, and a concrete-call typed-throws adapter**

## Performance

- **Duration:** 9 min
- **Started:** 2026-07-12T15:48:19Z
- **Completed:** 2026-07-12T15:57:00Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Added a fully offline `CountingStubProtocol` whose UUID-routed states cannot cross-talk between parallel tests.
- Added independent ordered scripts and attempt counters per absolute URL, including repeat-last-step behavior for persistent failures.
- Preserved POST bodies delivered as streams and recorded token-stripped requests for exact request-shape assertions.
- Added `capture(_:)` with typed throws plus four Swift Testing self-tests covering isolation, counting, fixtures, body capture, and result mapping.

## Task Commits

Each task was committed atomically:

1. **Task 1: CountingStubProtocol + script model + session factory** - `ea251691` (test)
2. **Task 2: capture adapter + harness self-tests** - `f2879cc7` (test)

## Files Created/Modified

- `AppPackage/Tests/NetworkingFeatureTests/Support/CountingStubProtocol.swift` - Per-token registry, per-URL scripts and counters, response serving, request/body recording, session factory, and handle lifecycle.
- `AppPackage/Tests/NetworkingFeatureTests/Support/RequestHarness.swift` - Concrete-call typed-throws closure adapter to `Result<T, AppError>`.
- `AppPackage/Tests/NetworkingFeatureTests/Support/HarnessSelfTests.swift` - Four deterministic offline self-tests for the harness contract.

## Decisions Made

- `canInit(with:)` accepts every request seen by the configured stub session; invalid tokens and unscripted URLs fail explicitly so the harness cannot fall through to a real socket.
- Stub state is a `Sendable` reference with its own `Mutex`, while the static registry only routes UUID tokens to those states. This keeps registry lock sections short and allows independent sessions to execute concurrently.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Made the routing-header symbol test-visible and typed the throwing test closure explicitly**

- **Found during:** Task 2 (capture adapter + harness self-tests)
- **Issue:** The first test build could not inspect a `fileprivate` routing-header key from the self-test file, and Swift inferred the deliberately throwing capture closure as `throws(any Error)`.
- **Fix:** Gave the header key module-internal visibility and annotated the closure as `() async throws(AppError) -> Int`, matching the documented typed-catch inference constraint.
- **Files modified:** `CountingStubProtocol.swift`, `HarnessSelfTests.swift`
- **Verification:** The corrected NetworkingFeatureTests sources compiled for both arm64 and x86_64 simulator architectures; all three files pass SwiftLint with zero violations.
- **Committed in:** `f2879cc7`

---

**Total deviations:** 1 auto-fixed (1 blocking issue)
**Impact on plan:** The fix only exposed test-support metadata within the test module and made the intended typed-throws contract explicit; there was no scope expansion.

## Validation Results

- `xcodebuild build -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator'` — **passed** (`BUILD SUCCEEDED`).
- SwiftLint over all three new support files with the repository configuration — **passed**, 0 violations.
- NetworkingFeatureTests test-bundle compilation — **passed** for arm64 and x86_64 simulator architectures.
- Full `NetworkingFeatureTests` iOS Simulator execution after elevation reset — **passed**: 76 tests in 9 suites, 0 issues (`TEST SUCCEEDED`).

## Known Stubs

None.

## Issues Encountered

- CoreSimulator was temporarily unavailable after the initial compile-failing attempt; the queued runtime gate passed after elevated capacity reset.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plans 04-03 through 04-09 can build their baseline and parity suites on the committed offline harness.
- The harness runtime gate is green; downstream migration plans can rely on the executable baseline.

## Self-Check: PASSED

- All three declared key files exist.
- Task commits `ea251691` and `f2879cc7` exist in git history.
- No placeholder or production-flow stub was introduced.

---
*Phase: 04-concurrency-framework-migration*
*Completed: 2026-07-13*
