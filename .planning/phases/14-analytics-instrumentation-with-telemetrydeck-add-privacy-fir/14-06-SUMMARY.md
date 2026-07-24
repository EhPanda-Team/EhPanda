---
phase: 14-analytics-instrumentation
plan: 06
subsystem: infra
tags: [telemetrydeck, analytics, privacy, tca-dependency, swift-testing, mutex]

# Dependency graph
requires:
  - phase: 14-analytics-instrumentation
    provides: "plan 14-05's AnalyticsSignal vocabulary and its internal Rendered form (the wire shape send consumes)"
  - phase: 14-analytics-instrumentation
    provides: "plan 14-03's AnalyticsErrorCategory mirror, translated to the SDK ErrorCategory at this call site"
  - phase: 14-analytics-instrumentation
    provides: "plan 14-04's AppInfo.telemetryDeckAppID and AppInfo.telemetryDeckSalt (D-17) build-time credentials"
  - phase: 14-analytics-instrumentation
    provides: "owner decisions D-10 (built-in identifier only), D-11 (per-signal default parameters), D-12 (single SDK import), D-13 (absent-credential gate), D-17 (the salt)"
provides:
  - "AnalyticsClient — the @Dependency struct of two @Sendable closures (start, send) with the D-13 gate, a Mutex-guarded initialization race, live/preview/test triple, and DependencyKey/DependencyValues wiring"
  - "AnalyticsDefaultParameters — the D-11 global default parameters, a pure snapshot(setting:didLogin:) plus a per-signal live closure that re-reads shared state"
  - "The single TelemetryDeck SDK import site in the repository (D-12); the .noop-derived, LockIsolated-backed spy idiom every later instrumentation plan inherits"
affects: [14-07, 14-08, 14-09, 14-10, 14-11, 14-12, 14-13, 14-14, 14-15, 14-16, 14-17, 14-18]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Credential-gated live client: live reads AppInfo.telemetryDeckAppID once; nil resolves the whole value to .noop and the SDK is never referenced, which is simultaneously the D-13 privacy gate and the guarantee that no signal reaches an uninitialized SDK"
    - "Mutex-guarded initialization race: a Synchronization.Mutex<Bool> flag keeps send inert until start finishes initializing the SDK, so a signal racing launch cannot trip the SDK's uninitialized assertion"
    - "Per-signal default parameters: the SDK's defaultParameters closure declares @Shared/@SharedReader inside its own body so a mid-session setting change is reflected on the very next signal (D-11), never snapshotted at configuration time"
    - "Void-returning unimplemented: the default-placeholder IssueReporting.unimplemented form reports a catchable issue and returns cleanly, unlike the value-returning placeholder: form which fatal-errors when a Void closure is invoked"

key-files:
  created:
    - AppPackage/Sources/AnalyticsClient/AnalyticsClient.swift
    - AppPackage/Sources/AnalyticsClient/AnalyticsDefaultParameters.swift
    - AppPackage/Tests/AnalyticsClientTests/AnalyticsClientGateTests.swift
    - AppPackage/Tests/AnalyticsClientTests/AnalyticsDefaultParametersTests.swift
  modified:
    - AppPackage/Tests/AnalyticsClientTests/AnalyticsSignalRenderingTests.swift

key-decisions:
  - "The SDK is configured with BOTH the app ID and the D-17 salt via TelemetryDeck.Config(appID:salt:); AppInfo.telemetryDeckSalt (String?) is passed straight through, so a salted anonymized identifier is used the moment a credentialed build ships."
  - "The client's closure properties are var, not let (a deliberate departure from the HapticsClient let template) so the ~130 downstream test sites can build a spy from .noop by mutating send while leaving start inert."
  - "unimplemented uses the default-placeholder IssueReporting.unimplemented form rather than the template's placeholder: form: both closures return Void, and the placeholder form evaluates a fatalError placeholder that aborts the test runner when send is actually invoked — the exact case Task 3 asserts on."
  - "AnalyticsErrorCategory is translated to the SDK's ErrorCategory by raw value (ErrorCategory(rawValue:)); the raw spellings match one-to-one, and only the current namespaced entry points (initialize/signal/errorOccurred) are used — no deprecated manager-prefixed spelling appears anywhere."

requirements-completed: []

coverage:
  - id: D1
    description: "A nil build-time app ID resolves AnalyticsClient.live to the total no-op with the SDK never referenced (D-13), which also stops any signal from reaching an uninitialized SDK"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/AnalyticsClientGateTests.swift#theLiveClientIsInertUnderTheTestHost"
        status: pass
      - kind: other
        ref: "AnalyticsClient.swift contains AppInfo.telemetryDeckAppID and return .noop; grep updateDefaultUserID|defaultUser|customUserID == 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "The D-11 global default parameters are re-read on every signal — a mid-session setting change is reflected on the next signal, not snapshotted at init"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/AnalyticsDefaultParametersTests.swift#liveReReadsTheSharedSettingOnEveryCall, #snapshotAlwaysCarriesExactlyTheSixExpectedKeys, #noSnapshotValueIsABareInteger"
        status: pass
      - kind: other
        ref: "@Shared(.setting) declared inside the live closure body; grep 'App\\.' >= 6 (all keys dot-namespaced)"
        status: pass
    human_judgment: false
  - id: D3
    description: "testValue is the loud unimplemented client and previewValue is the silent no-op (the D-12-locked triple), and the .noop-derived spy records signals in order"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/AnalyticsClientGateTests.swift#theUnimplementedClientReportsAnIssueWhenSendIsCalled, #theUnimplementedClientReportsAnIssueWhenStartIsCalled, #aSpyBuiltFromNoopRecordsEverySignalInOrder, #theNoopClientAcceptsEverySignalWithoutEffect"
        status: pass
    human_judgment: false
  - id: D4
    description: "Exactly one file in the repository imports the TelemetryDeck SDK (D-12), the SDK is configured with the app ID and the D-17 salt, and no deprecated SDK spelling appears anywhere"
    requirement: "ANALYTICS-01"
    verification:
      - kind: other
        ref: "grep -rl 'import TelemetryDeck' across Sources/App/ShareExtension == 1 path under AnalyticsClient; grep -rn 'TelemetryManager.' == 0; AnalyticsClient.swift contains telemetryDeckSalt"
        status: pass
    human_judgment: false
  - id: D5
    description: "SwiftLint reports zero violations across the module and its new test files with no suppression directive added; the full default test plan is green"
    requirement: "ANALYTICS-01"
    verification:
      - kind: other
        ref: "swiftlint --strict over the five new/changed files — 0 violations; xcodebuild test (full default plan) — TEST SUCCEEDED"
        status: pass
    human_judgment: false

# Metrics
duration: ~17min
completed: 2026-07-24
status: complete
---

# Phase 14 Plan 06: The AnalyticsClient dependency, the D-13 gate, and the D-11 default parameters Summary

**The single SDK call site in the repository (D-12): a credential-gated @Dependency client whose nil-app-ID path is a total no-op that never references the SDK (D-13), configured with both the app ID and the D-17 salt, carrying per-signal default parameters that re-read live settings (D-11), with the gate, the initialization-race guard, the loud test default, and the spy idiom all proven by test.**

## Performance

- **Duration:** ~17 min
- **Started:** 2026-07-24T04:37:49Z
- **Completed:** 2026-07-24T04:55:22Z
- **Tasks:** 3 (Task 2 as RED → GREEN; Tasks 1 and 3 build/test-verified)
- **Files created:** 4; **modified:** 1

## Accomplishments

- `AnalyticsClient` is a public `Sendable` struct of two `@Sendable` closures — `start: () -> Void` and `send: (AnalyticsSignal) -> Void` — declared `var` (not `let`, the template's choice) so downstream tests can build a spy from `.noop`.
- **The D-13 gate lives in `live` and nowhere else.** `live` reads `AppInfo.telemetryDeckAppID` once; a nil value resolves the entire client to `.noop` and the SDK is never referenced. This one check covers contributor clones, forks, CI, the test host and previews at once, and it is simultaneously what stops a signal from ever reaching an uninitialized SDK. The gate carries a load-bearing doc comment so a future reader will not "simplify" it into a call-site check.
- **The SDK is configured with both credentials (D-17).** `start` builds `TelemetryDeck.Config(appID:salt:)` from `AppInfo.telemetryDeckAppID` and `AppInfo.telemetryDeckSalt`, installs `AnalyticsDefaultParameters.live` as the config's default-parameters closure, and initializes. Every other config knob keeps its SDK default per `COVERAGE.md`.
- **The initialization race is guarded (threat T-14-11).** When an app ID is present, `live` captures a `Synchronization.Mutex<Bool>` initialized false; `start` flips it true after initializing, and `send` returns without touching the SDK while it is false.
- **D-10 is honored:** the SDK's built-in anonymized identifier is used as-is — no default user is assigned, no custom user identifier is passed, and the identifier-update API is never called (grep asserts zero occurrences).
- `AnalyticsDefaultParameters` is an uninhabited namespace split into a pure, total `snapshot(setting:didLogin:)` and a three-line `live` closure. `live` declares `@Shared(.setting)` and `@SharedReader(.didLogin)` inside its own body, so the SDK re-evaluates the current settings on every signal (D-11). The six dot-namespaced entries (`App.host`, `App.loggedIn`, `App.readingDirection`, `App.dualPageMode`, `App.translateTags`, `App.listDisplayMode`) render the two Int-raw enums through their stable analytics spelling, so no value is ever a bare integer.
- **Exactly one file imports the SDK (D-12)**, asserted by grep; no deprecated manager-prefixed spelling appears anywhere in the tree.
- Tests: the full `AnalyticsClientTests` target passes (58 tests, 8 suites, 2 expected known issues from the loud unimplemented default). The full default test plan is green. SwiftLint `--strict` reports zero violations across the five new/changed files with no suppression directive.

## Task Commits

1. **Task 2 — D-11 global default parameters** — `ba0d566e` (test, RED) → `715da3f3` (feat, GREEN)
2. **Task 1 — the AnalyticsClient struct, the D-13 gate, the dependency wiring** — `4fc78ad0` (feat)
3. **Fix surfaced by Task 3 — Void-returning unimplemented** — `cb132bdb` (fix)
4. **Task 3 — gate tests, loud default, spy idiom** — `bcd928ef` (test)

## Files Created/Modified

- `AppPackage/Sources/AnalyticsClient/AnalyticsClient.swift` — the client struct, the `live` gate, the Mutex-guarded race, the `// MARK: API` key/DependencyValues wiring, and the `// MARK: Test` no-op/unimplemented values
- `AppPackage/Sources/AnalyticsClient/AnalyticsDefaultParameters.swift` — the pure `snapshot` and the per-signal `live` closure
- `AppPackage/Tests/AnalyticsClientTests/AnalyticsDefaultParametersTests.swift` — exhaustive snapshot sweeps plus the live mutation test that distinguishes a closure from a snapshot
- `AppPackage/Tests/AnalyticsClientTests/AnalyticsClientGateTests.swift` — the gate proof under the test host, the loud unimplemented proof, and the spy proof
- `AppPackage/Tests/AnalyticsClientTests/AnalyticsSignalRenderingTests.swift` — fixture list promoted from `private` to internal so both suites share one list (plan-sanctioned)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 — Bug] Void-returning `unimplemented` form**
- **Found during:** Task 3 (running the gate suite)
- **Issue:** Following the `HapticsClient` template literally, `unimplemented` first used `IssueReporting.unimplemented(placeholder: placeholder())`. The template's placeholder form fits a client whose closures return values; `AnalyticsClient.start`/`send` both return `Void`, so invoking the unimplemented closure evaluated the `fatalError()` placeholder and aborted the whole test runner (`AnalyticsClient.swift:81: Fatal error`) — after recording the issue but before returning. Task 3 requires `unimplemented.send` to report a *catchable* issue, which a `fatalError` defeats.
- **Fix:** Switched both to the default-placeholder `IssueReporting.unimplemented("…")` form, whose placeholder defaults to `()` and returns cleanly after reporting a catchable issue, and dropped the now-unused `placeholder<Result>()` helper. `withKnownIssue` now proves the loud default.
- **Files modified:** `AppPackage/Sources/AnalyticsClient/AnalyticsClient.swift`
- **Commit:** `cb132bdb`

**2. [Rule 3 — Blocking] `-skipMacroValidation -skipPackagePluginValidation` on every verify gate**
- **Found during:** all build/test runs
- **Issue:** The plan's `<automated>` gates omit both flags; Phase 14's TelemetryDeck dependency invalidated Xcode's macro trust approvals, so unflagged builds fail at `ComputeTargetDependencyGraph`. This is the phase-wide carry-forward flagged in the execution prompt and prior summaries.
- **Fix:** Both flags added to every `xcodebuild` invocation, matching `.github/workflows/test.yml`.
- **Files modified:** none — invocation-level only.

### Plan-sanctioned choices (recorded, not fixes)

- **D-17 scope — both credentials wired.** The client passes `AppInfo.telemetryDeckSalt` to `TelemetryDeck.Config(appID:salt:)` alongside the app ID. Task 1's behavior block already anticipated this ("if D-17 chose one, the salt"); the execution prompt's `<owner_decisions>` made it binding. Recorded here per that instruction: the SDK now carries the write-once D-17 identifier salt, not the app ID alone.
- **Task order.** `AnalyticsDefaultParameters` (Task 2's source) was implemented before `AnalyticsClient` (Task 1's source), because `AnalyticsClient.live` references `AnalyticsDefaultParameters.live` at compile time — Task 1 cannot build without it. Commits still map cleanly to tasks; every commit compiles.
- **`var` closure properties.** A deliberate departure from the `HapticsClient` `let` template, instructed by Task 1's behavior block, so a test spy can override `send` while leaving `start` inert.
- **Fixture reuse.** `AnalyticsSignalRenderingTests.fixtures` was promoted from `private` to internal so `AnalyticsClientGateTests` drives the same list — the plan's sanctioned "promote it to an internal shared fixture" option, chosen over a second list that would drift.

### Requirement tracking

`ANALYTICS-01` is a phase-long requirement threaded through plans 14-01 … 14-18; it is not closed by this plan alone. Following the precedent set by `14-05-SUMMARY.md`, `requirements-completed` is left empty here — plan **14-17** owns closing it out.

## Known Stubs

None. Every value is wired to a real source: the gate reads the real credential, the default parameters read live shared state, and `send` dispatches every signal case to the SDK. There is no placeholder or hardcoded value in the module.

## Threat Flags

None. This plan implements the mitigations the plan's `<threat_model>` assigns (T-14-01 single import, T-14-03 the gate, T-14-11 the race guard) and introduces no new security surface beyond the single outbound call site the model already accounts for.

## Issues Encountered

- The module has no committed `swiftlint` on `PATH`; the SwiftLint binary bundled in an Xcode DerivedData SourcePackages artifact bundle was used for the `--strict` gate, matching the plugin the package builds with.

## User Setup Required

None. The app ID and salt were plumbed in plan 14-04; this plan consumes them. A credentialed release build (one carrying the gitignored local config) begins transmitting; every other build no-ops under D-13.

## Next Phase Readiness

- Wave 5 (plans 14-07 … 14-09) hardens every existing test target against the `testValue = unimplemented` default before wave 6 instruments the reducers. That un-hardened default is deliberate and load-bearing — it makes an un-stubbed analytics call fail loudly.
- Wave 6 (plans 14-10+) resolves `@Dependency(\.analyticsClient)` and emits `AnalyticsSignal` values through `send`; the `.noop`-derived, `LockIsolated`-backed spy proven here is the capture idiom those plans inherit.
- Carry-forward, unchanged: every `xcodebuild` invocation in this phase needs `-skipMacroValidation -skipPackagePluginValidation`.
- Still outstanding (owned by plan 14-17): `Buckets.swift`'s header and `ANALYTICS-01` in `REQUIREMENTS.md` still describe D-08 as having a single documented exception; D-16 made two.

---
*Phase: 14-analytics-instrumentation*
*Completed: 2026-07-24*

## Self-Check: PASSED

All 4 source/test files and the SUMMARY exist on disk; all 5 task commits (`ba0d566e`, `715da3f3`, `4fc78ad0`, `cb132bdb`, `bcd928ef`) resolve in `git log`. No absolute home path appears in this document.
