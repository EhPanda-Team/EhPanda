---
phase: 18-in-app-3-0-readiness-age-wall-analytics-choice-comment-moder
plan: "03"
subsystem: analytics
tags: [analytics-level, install-signal, install-source, telemetrydeck, consent, first-launch]

requires: [18-02, 18-04]
provides:
  - "`InstallSourceClient` module: `InstallSource` (`appStore`, `testFlight`, `marketplace(<id>)`, `web`, `other`, `unknown`) with a fixed `wireValue`, and the only MarketplaceKit import in the app sources"
  - "`InstallSignalSender` (actor): the one `App.installed` request in the SDK 2.14.2 wire format, seven body fields, payload exactly `App.installSource`; settled once per install, single flight, 10/20/40 s retries"
  - "`InstallSignalState` persisted under its own `installSignal` shared key, apart from `Setting`, decoded tolerantly"
  - "`AnalyticsClient.apply(AnalyticsLevel?)` replaces `start`; `send` gated by the stored level through `AnalyticsSignal.minimumLevel` / `isSent(at:)`"
  - "`TelemetrySDK` seam (`initialize`, `terminate`, `signal`, `errorOccurred`), the only file importing TelemetryDeck"
  - "`AnalyticsDefaultParameters` returns the five `App.*` parameters at Full only"
  - "`AppReducer` applies the stored level in the deferred launch (both paths) and the chosen level on `.firstLaunch(.delegate(.levelChosen))`"
affects: [18-09, 18-10, 18-12, phase-20-analytics-02]

actuals:
  tasks: 4
  commits: 4

tech-stack:
  added: []
  patterns:
    - "A vendor SDK behind a struct-of-closures seam, so the level gate is tested against a recording fake"
    - "A hand-built signal request for the one signal that must not carry the SDK's device payload"

key-files:
  created:
    - AppPackage/Sources/InstallSourceClient/InstallSourceClient.swift
    - AppPackage/Sources/InstallSourceClient/.swiftlint.yml
    - AppPackage/Sources/AnalyticsClient/InstallSignalSender.swift
    - AppPackage/Sources/AnalyticsClient/TelemetrySDK.swift
    - AppPackage/Sources/AnalyticsClient/AnalyticsSignal+Level.swift
    - AppPackage/Sources/AppModels/Persistent/InstallSignalState.swift
    - AppPackage/Tests/AnalyticsClientTests/InstallSourceTests.swift
    - AppPackage/Tests/AnalyticsClientTests/InstallSignalSenderTests.swift
    - AppPackage/Tests/AnalyticsClientTests/AnalyticsLevelGateTests.swift
  modified:
    - AppPackage/Package.swift
    - AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift
    - AppPackage/Sources/AnalyticsClient/AnalyticsClient.swift
    - AppPackage/Sources/AnalyticsClient/AnalyticsDefaultParameters.swift
    - AppPackage/Sources/AnalyticsClient/AnalyticsOrientation.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
    - AppPackage/Sources/AppFeature/FirstLaunch/FirstLaunchReducer.swift
    - AppPackage/Tests/AnalyticsClientTests/AnalyticsClientGateTests.swift
    - AppPackage/Tests/AnalyticsClientTests/AnalyticsDefaultParametersTests.swift
    - AppPackage/Tests/AppFeatureTests/FirstLaunchGateTests.swift

key-decisions:
  - "`apply(nil)` does nothing. Every chosen level asks the install sender first; the sender sends at most once per install. Minimal terminates a running SDK and never initialises it; Basic and Full initialise it once per process."
  - "`send` reads the stored level live on every signal, so lowering the level drops signals at once, before `apply` catches up. Every SDK call is made while holding the `isRunning` mutex, so no signal reaches an SDK that is not initialised (T-14-11)."
  - "`minimumLevel` is an exhaustive switch with no catch-all: the 10 screen, feature and error signals are Basic, and the 3 reading and download signals are Full (D-06f). A new `AnalyticsSignal` case does not compile until it gets a level."
  - "The default parameters are gated at Full only. Basic gets no `App.*` parameter, because only Full's description promises \"your main settings\"."
  - "`TelemetrySDK.Configuration` holds the app ID, salt and default-parameter closure. The orientation enricher stays owned by the live SDK value, so it is not part of the seam."
  - "`OrientationEnricher` is declared `Sendable` in `AnalyticsOrientation.swift`, and its `SignalEnricher` conformance moved to `TelemetrySDK.swift`. That keeps TelemetryDeck to one importing file."
  - "`levelChosen` applies only once the deferred launch has run. Before then, the deferred launch applies the stored level itself, so the client is told the level once and nothing is applied before the unlock."
  - "The unlocked-launch path in `onLaunchFinish` runs the deferred half inline (18-02), so the stored-level effect is added there as well as in `deferredLaunchEffect`, through one helper, `storedAnalyticsLevelEffects`."
  - "REQUIREMENTS.md is not marked: CONSENT-18-01 is shared with 18-09 and 18-10, which have no SUMMARY yet."

requirements-completed: []

coverage:
  - id: D1
    description: "InstallSourceClient maps every AppDistributor case. A thrown error, an unknown future case and an implausible marketplace ID give `unknown`. The live client gives `unknown` on the simulator and `other` in other DEBUG builds, and wire values match a fixed regex."
    requirement: CONSENT-18-01
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/InstallSourceTests.swift (11 tests, 32 test cases with arguments)"
        status: pass
    human_judgment: false
  - id: D2
    description: "One install request: POST to the SDK endpoint, a one-element array with exactly the seven keys, type App.installed, and a payload with only App.installSource. There is no second request after a second apply, a relaunch, a level change or concurrent calls. A nil app ID never calls the transport, and retries back off 10/20/40 s."
    requirement: CONSENT-18-01
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/InstallSignalSenderTests.swift (13 tests)"
        status: pass
    human_judgment: false
  - id: D3
    description: "No level gives no SDK call and no install signal. Minimal gives zero `initialize` across applies, a relaunch and every fixture. Basic sends exactly the 10 Basic signals with no default parameters. Full sends all 13 with the five App.* keys. Lowering and raising the level terminate and re-initialise the SDK, and the stored level gates before apply."
    requirement: CONSENT-18-01
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/AnalyticsLevelGateTests.swift (13 tests), AnalyticsDefaultParametersTests, AnalyticsClientGateTests"
        status: pass
    human_judgment: false
  - id: D4
    description: "A locked launch applies nothing. An unlocked launch with a stored level applies it once. With no level, nothing is applied until the choice, and then the level is applied once. A choice reported before the deferred launch is applied by it once."
    requirement: CONSENT-18-01
    verification:
      - kind: unit
        ref: "FirstLaunchGateTests#aLockedLaunchRunsOnlyLocalWork (unimplemented analytics client), #anUnlockedLaunchWithAStoredLevelAppliesItOnce, #anUnlockedLaunchWithNoLevelAppliesNothingUntilTheChoice, #aFirstLaunchAppliesTheLevelOnlyWhenItIsChosen, #aChoiceBeforeTheDeferredLaunchIsAppliedByItOnce"
        status: pass
    human_judgment: false

duration: about 30 min
completed: 2026-11-05
status: complete
---

# Phase 18 Plan 03: Analytics Levels and the Install Signal Summary

**Analytics now follows the level the user chose. No level sends nothing. Minimal sends one install signal, which
carries only the install source, and never starts the TelemetryDeck SDK. Basic and Full start the SDK and send what
their Revision 6 descriptions promise.**

## Performance

- **Duration:** about 30 min of execution
- **Started:** about 2026-11-05T07:55Z
- **Completed:** 2026-11-05T08:25Z
- **Tasks:** 4
- **Files modified:** 19 (9 created, 10 modified)

## Accomplishments

- **Install source (Task 1).** A new `InstallSourceClient` module reduces MarketplaceKit's `AppDistributor` to six
  fixed values. A marketplace ID is accepted only as a plausible bundle ID of 1 to 155 characters. Anything else, a
  thrown error, or a future case gives `unknown`. Simulator builds return `unknown` and other DEBUG builds return
  `other`; neither asks MarketplaceKit.
- **Install signal (Task 2).** `InstallSignalSender` builds the one `App.installed` request in the SDK 2.14.2 wire
  format and posts it to `https://nom.telemetrydeck.com/v2/`. The request has seven fields and its payload has one
  key, `App.installSource`; nothing about the device is in it. The response is handled as the SDK handles it:
  - accepted, or rejected for good: settled and persisted;
  - retryable: retried after 10, 20 and 40 s.

  The random `clientUser` hash is kept for retries and cleared once the signal settles. One request is in flight at a
  time. `InstallSignalState` lives under its own `installSignal` key.
- **Level gate (Task 3).** `AnalyticsClient.start` is now `apply(level)`, and the SDK sits behind `TelemetrySDK`.
  - No level: nothing.
  - Minimal: the install signal only. A running SDK is terminated.
  - Basic: the install signal, the SDK, and the 10 screen, feature and error signals, with no default parameters.
  - Full: Basic plus the 3 reading and download signals and the five `App.*` parameters.

  This reverses Phase 14's premise that the SDK stays alive with analytics off "so installs are still counted". The
  module comment now says so, and why it must not come back (P-4).
- **Wiring (Task 4).** `AppReducer` applies the stored level when the deferred launch runs, on both of its paths, and
  applies the chosen level on `levelChosen` once the deferred launch has run. `apply` has exactly one call site in the
  sources, `AppReducer.analyticsLevelEffect` (D-08; 18-10 adds Settings).

## Task Commits

1. **Task 1: InstallSourceClient** - `a633a6f1d` (feat)
2. **Task 2: InstallSignalSender and its persisted state** - `19ea9853c` (feat)
3. **Task 3: TelemetrySDK seam, apply(level), level gate** - `c2d233e68` (feat)
4. **Task 4: Wire apply from the reducers** - `a847e2d3e` (feat)

**Plan metadata:** recorded in the `docs(18-03)` commit that adds this file.

All four commits are signed (`G`), and their author and committer dates are in `+08:00`.

## Files Created/Modified

- `InstallSourceClient/InstallSourceClient.swift` (new) and its `.swiftlint.yml`: the source enum and client.
- `AnalyticsClient/InstallSignalSender.swift` (new): the sender, its live transport and `InstallSignalTrigger`.
- `AppModels/Persistent/InstallSignalState.swift` (new) and `AppModels/Persistence/AppSharedKeys.swift`: the
  persisted state and its key.
- `AnalyticsClient/TelemetrySDK.swift` (new): the seam and the live SDK, including the orientation enricher.
- `AnalyticsClient/AnalyticsSignal+Level.swift` (new): `minimumLevel` and `isSent(at:)`.
- `AnalyticsClient/AnalyticsClient.swift`: `apply`, the gate, and `live(appID:salt:sdk:installSignal:)` for tests.
- `AnalyticsClient/AnalyticsDefaultParameters.swift`: Full only.
- `AnalyticsClient/AnalyticsOrientation.swift`: no SDK import (deviation 3).
- `AppFeature/DataFlow/AppReducer.swift`, `AppFeature/FirstLaunch/FirstLaunchReducer.swift` (doc comment): wiring.
- `AppPackage/Package.swift`:
  - the `InstallSourceClient` module and target;
  - the `AnalyticsClient` dependencies on it and on `OSLogExt`;
  - the `AnalyticsClientTests` dependency on it.
- Tests: `InstallSourceTests`, `InstallSignalSenderTests` and `AnalyticsLevelGateTests` (new);
  `AnalyticsClientGateTests` and `AnalyticsDefaultParametersTests` (`start` → `apply`, Full-only parameters);
  `FirstLaunchGateTests` (4 wiring tests and `AnalyticsClientSpy`).

## Verification

- **Task 1:** `InstallSourceTests` green on the phone, 11 tests (32 test cases with arguments).
- **Task 2 RED:** the suite failed to compile with the sender moved aside (`cannot find type 'InstallSignalSender'`).
  **GREEN:** `InstallSignalSenderTests` and `AppModelsTests` passed 131 of 131.
- **Task 3 RED:** `AnalyticsLevelGateTests` failed to compile (`no member 'apply'`). **GREEN:** `AnalyticsClientTests`
  had 102 total, 100 passed, 2 expected failures and 0 failed. All 12 suites passed, including
  `AnalyticsLevelGateTests` (13 tests) and `InstallSignalSenderTests` (13).
- **Task 4 RED:** with the `AppReducer` change reverted in the working copy, `FirstLaunchGateTests` had 23 total and
  failed exactly the 4 new tests. **GREEN:** AppFeature, AnalyticsClient and AppModels tests passed on both devices:
  - phone: 391 total, 389 passed, 2 expected failures, 0 failed;
  - pad: 391 total, 389 passed, 2 expected failures, 0 failed.
- **Full FeatureTests plan:**
  - phone: 1675 total, 1666 passed, 9 expected failures, 0 failed;
  - pad: 1675 total, 1665 passed, 10 expected failures, 0 failed.

  0 Swift warnings in the package sources. The 2 `ReduceMotionGatingSourceTests` failures that 18-02 recorded were
  fixed before this plan by `1ca189bcd`.
- **Strict lint:** the no-cache lint over `AppPackage/Sources`, `AppPackage/Tests`, `App`, `EhPandaUITests` and
  `ShareExtension` found 0 violations in 780 files.
- **Imports:** `import TelemetryDeck` appears only in `AnalyticsClient/TelemetrySDK.swift`. Among the sources,
  `import MarketplaceKit` appears only in `InstallSourceClient/InstallSourceClient.swift`; the test
  `InstallSourceTests.swift` also imports it, to build `AppDistributor` values.
- **Call sites:** `grep -rn "analyticsClient.apply" AppPackage/Sources` finds one call site, in `AppReducer.swift`.

## Decisions Made

See `key-decisions` above.

## Deviations from Plan

1. **[Rule 3, AGENTS.md] `Sources/InstallSourceClient/.swiftlint.yml` was added.** It is not in `files_modified`, but
   every module carries one, with `parent_config: ../../../.swiftlint.yml`.
2. **[Rule 3] `AnalyticsClient` depends on `OSLogExt`.** The sender logs its dispositions through the module's
   `Logger`. The change is in `Package.swift`, which the plan lists.
3. **[Rule 3] `AnalyticsOrientation.swift` was edited although the plan does not list it.** The verification requires
   TelemetryDeck to be imported only by `TelemetrySDK.swift`. The enricher's `SignalEnricher` conformance moved there,
   and the file lost its import. Behavior is unchanged.
4. **`TelemetrySDK.Configuration` has no `enrichers` field.** The orientation enricher belongs to the live SDK value,
   which keeps the enricher's cache and the SDK type out of the seam.
5. **Task 2's tests were drafted alongside the code.** RED was shown afterwards, by moving the sender aside and
   compiling the suite.

**Total deviations:** 5. None is a product decision.

## Issues Encountered

- During one targeted phone run, `UITestStubTests/hostedStoreKeepsItsFixturesWhenTheCallingTestScopeChanges` failed
  once: `store.isUnlocked` was false. It passed on the rerun, in both full runs and on the pad. The test builds
  `AppReducer.State()` outside any dependency scope, and this plan does not touch the visual-host preset or the scene
  phase. This looks like an existing intermittent failure from shared storage and is recorded for 18-12's gate. It was
  not fixed here.

## User Setup Required

None. The app ID and salt stay in the owner's local configuration. Without them, the client is a no-op and the
sender never runs.

## Next Phase Readiness

- 18-09 renders the analytics choice. Its `analyticsContinue(level)` already reaches `apply` through `levelChosen`.
- 18-10 adds the Settings level picker, which is the second `apply` call site (D-08).
- **Phase 20 carries:**
  - **OI-4:** reconcile the SDK's `newInstallDetected` with `App.installed` at Basic and Full. Both can count one
    install.
  - **ANALYTICS-02:** reuse `InstallSourceClient`, verify its mapping on the real marketplace build and on a device,
    and add the install source to the Basic and Full signals (D-06c).

## Self-Check: PASSED

- Every created file exists, and commits `a633a6f1d`, `19ea9853c`, `c2d233e68` and `a847e2d3e` are on
  `feature/gsd-phase-18`.
- Each task's acceptance criteria were re-run and passed (results above).
