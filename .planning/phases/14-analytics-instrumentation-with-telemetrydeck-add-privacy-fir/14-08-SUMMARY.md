---
phase: 14-analytics-instrumentation
plan: 08
subsystem: testing
tags: [telemetrydeck, analytics, tca, teststore, dependency-hardening, swift-testing]

# Dependency graph
requires:
  - phase: 14-06
    provides: "AnalyticsClient with testValue = .unimplemented (loud default) and .noop"
provides:
  - "Every TestStore in SettingFeatureTests resolves analyticsClient to the no-op client"
  - "The second-largest affected test target is pre-hardened so wave-6 SettingFeature/LoginReducer instrumentation cannot turn it red"
affects: [wave-6 SettingFeature instrumentation (14-16), remaining analytics test-hardening waves]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-store analyticsClient = .noop override placed in each TestStore's existing dependency closure"
    - "Bare TestStores given a multi-line trailing dependency closure (single_line_trailing_closure is error severity)"
    - "Shared makeStore/makeHarness factories hardened once, covering every store they vend"

key-files:
  created: []
  modified:
    - AppPackage/Tests/SettingFeatureTests/ (11 test files — every TestStore site hardened)

key-decisions:
  - "Hardened at each real TestStore initializer (28 sites) rather than adding a suite-level dependency trait, per plan guidance"
  - "Existing per-suite store factories (makeStore in SettingReducerNavigationTests / SettingReducerTests / AccountSettingReducerTests, makeHarness in LoginChallengeFlowTests) were hardened once, covering every store they vend"
  - "The client's testValue = .unimplemented was left untouched — hardening happens only at the store sites"

patterns-established:
  - "Analytics dependency hardening: add sorted 'import AnalyticsClient' + '$0.analyticsClient = .noop' to every TestStore closure in a target ahead of reducer instrumentation"

requirements-completed: [ANALYTICS-01]

coverage:
  - id: D1
    description: "Every TestStore in SettingFeatureTests resolves analyticsClient to the no-op client (28 store constructions across 11 files)"
    requirement: ANALYTICS-01
    verification:
      - kind: unit
        ref: "xcodebuild test -only-testing:SettingFeatureTests => TEST SUCCEEDED (47 tests, 11 suites)"
        status: pass
      - kind: other
        ref: "temporary real analyticsClient.send(.cloudflareChallengeEncountered) emission from LoginReducer.login => 47 passed, no unimplemented issue"
        status: pass
    human_judgment: false

# Metrics
duration: ~18min
completed: 2026-07-24
status: complete
---

# Phase 14 Plan 08: Harden SettingFeatureTests Analytics Dependency Summary

**Every TestStore in SettingFeatureTests (28 store constructions across 11 files) now resolves `analyticsClient` to the no-op client, so wave-6 instrumentation of `SettingFeature`/`LoginReducer` (plan 14-16) cannot turn this target red — proven by count reconciliation and a temporary real emission from `LoginReducer`.**

## Performance

- **Duration:** ~18 min
- **Completed:** 2026-07-24
- **Tasks:** 2
- **Files modified:** 11 test files

## Accomplishments

- Hardened the target's analytics dependency at every `TestStore` site: added a sorted `import AnalyticsClient` and `$0.analyticsClient = .noop` to each store's dependency closure.
- Proved full coverage by reconciling the store count against the hardened-store count, and by a behavioral probe (a temporary real `analyticsClient.send(...)` emission from `LoginReducer.login`, a case this target exercises) that stayed green everywhere.
- Left the client's loud `testValue = .unimplemented` default untouched, so any un-hardened suite elsewhere still fails loudly on an unexpected analytics call.

## Task Commits

1. **Task 1: Harden every store in SettingFeatureTests** - `d80ca215` (test)
2. **Task 2: Prove the hardening with a real emission from SettingFeature** - no code commit (probe added, verified green, then reverted — leaves no residue)

**Plan metadata:** `<final>` (docs: complete plan)

## Store-Count Reconciliation

The research figure of **28 store constructions across 11 files** was confirmed by counting the substring `TestStore(` in the target. Every one of the 28 is a real `TestStore(...)` initializer (no factory-call substring inflation in this target, unlike Downloads).

**Reconciliation result:** 28 `TestStore(` sites, 28 `analyticsClient = .noop` overrides — a 1:1 match with zero difference. Where a suite uses a shared store factory, the factory's single `TestStore` is one of the 28 and is hardened once, covering every case that routes through it.

### Per-file `TestStore(` counts (all hardened)

| File | count | how hardened |
|---|---|---|
| AccountSettingReducerTests.swift | 1 | `makeStore(cookieClient:)` factory |
| AppActivityLogsReducerTests.swift | 4 | each store's trailing closure (spy-by-mutation idiom preserved) |
| AppIconReducerTests.swift | 1 | store's trailing closure |
| AppearanceSettingReducerTests.swift | 1 | store's trailing closure |
| GeneralSettingReducerTests.swift | 2 | two bare stores given a minimal trailing closure |
| LaboratorySettingReducerTests.swift | 1 | store's trailing closure |
| LoginChallengeFlowTests.swift | 1 | `makeHarness(...)` factory (the LoginReducer store) |
| SettingPresentationTests.swift | 6 | each store's trailing closure |
| SettingReducerNavigationTests.swift | 9 | `makeStore(...)` factory + 8 inline stores (2 bare → trailing closure) |
| SettingReducerTests.swift | 1 | `makeStore(cookieClient:)` factory |
| SettingWriteThroughTests.swift | 1 | store's trailing closure |
| **Total** | **28** | **All covered** |

## Behavioral Probe

**Result: PASS.** As required, a throwaway `analyticsClient.send(.cloudflareChallengeEncountered)` emission was temporarily added to `LoginReducer`'s `.login` case (the case this target exercises through `LoginChallengeFlowTests` and the post-login cascade in `SettingReducerNavigationTests`), together with `import AnalyticsClient` and `@Dependency(\.analyticsClient)`. `SettingFeature` already declares `.module(.analyticsClient)` as a source dependency, so no Package.swift edit was needed. Running the full target produced **47 passed, 0 analytics-related failures** — no store hit the `.unimplemented` client's issue-reporting `send`, confirming the override takes effect through each store's per-store dependency resolution (a grep proves text presence; this proves runtime effect). The edit was then reverted, and `git status --porcelain AppPackage/Sources` is **empty** at task end; `git diff --name-only` lists nothing outside `AppPackage/Tests/SettingFeatureTests`. No unhardened store was exposed by the probe.

## Verification

- `xcodebuild test -skipMacroValidation -skipPackagePluginValidation -only-testing:SettingFeatureTests`: **TEST SUCCEEDED** (47 tests, 11 suites; the 2 "known issues" are pre-existing `withKnownIssue`-style markers, not failures).
- The macro-validation skip flags are required after Phase 14's TelemetryDeck dependency invalidated Xcode's macro trust approvals; they are the repo's established CI flags, not a suppression of a real error.
- The `git diff` for Task 1 is additive except for four bare-form `TestStore` lines (two in `GeneralSettingReducerTests`, two in `SettingReducerNavigationTests`) that were rewritten with a trailing dependency closure; no `#expect`, `store.send`, `store.receive`, or state-mutation closure was changed.
- Imports remain sorted (`sorted_imports`, error severity): `import AnalyticsClient` sorts first (case-insensitively before `AppComponents`/`AppModels`/`ApplicationClient`/`ComposableArchitecture`) in every touched file.
- SwiftLint runs as the SPM build-tool plugin during the build; error-severity violations would fail compilation, and the build succeeded.

## Decisions Made

- Hardened at each real `TestStore` initializer (per-store closure, or once per shared factory) rather than introducing a suite-level dependency trait — the plan explicitly rules out the trait.
- Placed `$0.analyticsClient = .noop` first (alphabetically) within multi-override closures for consistency; the four bare sites received a minimal multi-line trailing closure to satisfy `single_line_trailing_closure`.

## Deviations from Plan

None - plan executed exactly as written. The four bare `TestStore` sites were converted to the multi-line trailing dependency-closure form, which the plan explicitly anticipates ("add the override to that store's existing trailing dependency-configuration closure" / introduce one where absent).

## Issues Encountered

None.

## Next Phase Readiness

- Wave 6 can now instrument `SettingFeature` / `LoginReducer` (plan 14-16) without inheriting test breakage from this target.
- The remaining affected test targets (`AppFeatureTests`, `HomeFeatureTests`, `DetailFeatureTests`, `ReadingFeatureTests`) still need the same hardening in plan 14-09 before their reducers are instrumented.

## Self-Check: PASSED

- SUMMARY.md exists on disk.
- Task commit `d80ca215` is present in git history.
- Task 2 intentionally produced no commit (probe reverted); `git status --porcelain AppPackage/Sources` empty confirms no residue.

---
*Phase: 14-analytics-instrumentation*
*Completed: 2026-07-24*
