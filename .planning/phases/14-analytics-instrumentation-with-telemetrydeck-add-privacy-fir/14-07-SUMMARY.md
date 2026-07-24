---
phase: 14-analytics-instrumentation
plan: 07
subsystem: testing
tags: [telemetrydeck, analytics, tca, teststore, dependency-hardening, swift-testing]

# Dependency graph
requires:
  - phase: 14-06
    provides: "AnalyticsClient with testValue = .unimplemented (loud default) and .noop"
provides:
  - "Every TestStore in DownloadsFeatureTests resolves analyticsClient to the no-op client"
  - "The largest affected test target is pre-hardened so wave-6 DownloadsReducer instrumentation cannot turn it red"
affects: [wave-6 DownloadsReducer instrumentation, remaining analytics test-hardening waves]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-store analyticsClient = .noop override placed in each TestStore's existing dependency closure"
    - "Bare/trailing-closure TestStores given a multi-line trailing dependency closure (single_line_trailing_closure is error severity)"

key-files:
  created:
    - .planning/phases/14-analytics-instrumentation-with-telemetrydeck-add-privacy-fir/deferred-items.md
  modified:
    - AppPackage/Tests/DownloadsFeatureTests/ (23 test files — every TestStore site hardened)

key-decisions:
  - "Hardened at each real TestStore initializer (55 sites) rather than adding a suite-level dependency trait, per plan guidance"
  - "Existing per-suite/per-file store factories were hardened once, covering every store they vend"
  - "The client's testValue = .unimplemented was left untouched — hardening happens only at the store sites"

patterns-established:
  - "Analytics dependency hardening: add sorted 'import AnalyticsClient' + '$0.analyticsClient = .noop' to every TestStore closure in a target ahead of reducer instrumentation"

requirements-completed: [ANALYTICS-01]

coverage:
  - id: D1
    description: "Every TestStore in DownloadsFeatureTests resolves analyticsClient to the no-op client (55 real initializers, covering all 75 grep-counted store constructions)"
    requirement: ANALYTICS-01
    verification:
      - kind: unit
        ref: "xcodebuild test -only-testing:DownloadsFeatureTests (serial) => TEST SUCCEEDED"
        status: pass
      - kind: other
        ref: "temporary real analyticsClient.start() emission from DownloadsReducer.fetchDownloadsDone/observeDownloadsDone => 252 passed, no unimplemented issue"
        status: pass
    human_judgment: false

# Metrics
duration: ~40min
completed: 2026-07-24
status: complete
---

# Phase 14 Plan 07: Harden DownloadsFeatureTests Analytics Dependency Summary

**Every TestStore in DownloadsFeatureTests (55 real initializers across 23 files) now resolves `analyticsClient` to the no-op client, so wave-6 instrumentation of `DownloadsReducer` cannot turn this target red — proven by count reconciliation and a temporary real emission.**

## Performance

- **Duration:** ~40 min
- **Completed:** 2026-07-24
- **Tasks:** 2
- **Files modified:** 23 test files (+ 1 tracking file created)

## Accomplishments

- Hardened the target's analytics dependency at every `TestStore` site: added a sorted `import AnalyticsClient` and `$0.analyticsClient = .noop` to each store's dependency closure.
- Proved full coverage by reconciling the store count against the hardened-store count, and by a behavioral probe (a temporary real `analyticsClient.start()` emission from a heavily-exercised `DownloadsReducer` case) that stayed green everywhere.
- Left the client's loud `testValue = .unimplemented` default untouched, so any un-hardened suite elsewhere still fails loudly on an unexpected analytics call.

## Task Commits

1. **Task 1: Harden first half (first 12 files, 24 store initializers)** - `b7aa25b8` (test)
2. **Task 2: Harden second half (last 11 files, 31 store initializers) + prove full coverage** - `5f6475b9` (test)

**Plan metadata:** `<final>` (docs: complete plan)

## Store-Count Reconciliation

The research figure of **75 "store constructions"** is the raw count of the substring `TestStore(` across the target. That count conflates two things:

| Category | Count | How hardened |
|---|---|---|
| Real `TestStore(...)` initializers (word-boundary match) | **55** | Each hardened directly — `$0.analyticsClient = .noop` added to its dependency closure |
| Factory-call substring matches (`makeXxxTestStore(...)`, e.g. `makeDownloadTestStore`, `makeMetadataTestStore`, `makeDownloadedMetadataTestStore`, `makeUpdateTestStore`, `makeObserveTestStore`) | **20** | Covered transitively — each routes through a factory whose single internal `TestStore` is among the 55 and is hardened once |
| **Total (research's 75)** | **75** | **All covered** |

**Reconciliation result:** 55 real initializers, 55 `analyticsClient = .noop` overrides — a 1:1 match with zero difference. The 20 factory-call sites are covered by their factory definitions (already within the 55). No store left behind.

### Per-file real `TestStore(` counts (all hardened)

**Task 1 (first 12 files, git ls-files order) — 24 initializers:**

| File | count |
|---|---|
| AppReadingFlushTests.swift | 2 |
| DetailReducerDownloadTests.swift | 1 (factory `makeDownloadTestStore`, 5 call sites) |
| DetailReducerMetadataTests.swift | 2 (factories `makeMetadataTestStore` / `makeDownloadedMetadataTestStore`) |
| DetailReducerMetadataUpdateTests.swift | 2 |
| DetailReducerObserveTests.swift | 3 |
| DetailReducerPauseAndGuardTests.swift | 3 |
| DownloadAutomationTests.swift | 5 |
| DownloadBackgroundProcessingTests.swift | 1 |
| DownloadInspectorLoadTests.swift | 1 |
| DownloadInspectorRetryTests.swift | 1 |
| DownloadInspectorSkipTests.swift | 2 |
| DownloadObserverBatchTests.swift | 1 |

**Task 2 (last 11 files) — 31 initializers:**

| File | count |
|---|---|
| DownloadObserverReadingTests.swift | 3 |
| DownloadObserverRefreshTests.swift | 2 |
| DownloadsPresentationLifecycleTests.swift | 2 |
| DownloadsReducerActionTests.swift | 10 |
| DownloadsReducerReadingDismissTests.swift | 1 |
| DownloadsReducerRefreshTests.swift | 3 |
| FolderManagerReducerTests.swift | 1 |
| PreviewsReducerDownloadTests.swift | 2 |
| ReadingReducerDownloadTests.swift | 3 |
| ReadingReducerFlushTests.swift | 2 |
| ReadingReducerLocalTests.swift | 2 |

## Behavioral Probe

**Result: PASS.** As required, a throwaway `analyticsClient.start()` emission was temporarily added to `DownloadsReducer`'s `.fetchDownloadsDone`/`.observeDownloadsDone` case (the target's most heavily-exercised case), together with `import AnalyticsClient` and `@Dependency(\.analyticsClient)`. Running the full target produced **252 passed, 0 analytics-related failures** — no store hit the `.unimplemented` client's issue-reporting `start`, confirming the override takes effect through each store's per-store dependency resolution (a grep proves text presence; this proves runtime effect). The edit was then reverted, and `git status --porcelain AppPackage/Sources` is **empty** at task end.

## Verification

- `xcodebuild test -only-testing:DownloadsFeatureTests` (serial): **TEST SUCCEEDED** (all tests, including the timing suite).
- The `git diff` for both tasks is additive except for three bare-form `TestStore` lines that were rewritten with a trailing dependency closure; no `#expect`, `store.send`, `store.receive`, or state-mutation closure was changed.
- Imports remain sorted (`sorted_imports`, error severity): `import AnalyticsClient` sorts first (case-insensitive) in every touched file.
- SwiftLint runs as the SPM build-tool plugin during the build; error-severity violations would fail compilation, and the build succeeded.

## Decisions Made

- Hardened at each real `TestStore` initializer (per-store closure, or once per shared factory) rather than introducing a suite-level dependency trait — the plan explicitly rules out the trait because it would require declaring an additional test-support package that is currently only transitive.
- Placed `$0.analyticsClient = .noop` first (alphabetically) within multi-override closures for consistency, while single-override bare/trailing sites received a minimal multi-line closure to satisfy `single_line_trailing_closure`.

## Deviations from Plan

None - plan executed exactly as written. The three bare `TestStore` sites and the single-line trailing-closure sites were converted to the multi-line trailing dependency-closure form, which the plan explicitly anticipates ("add such a closure if the site has none").

## Issues Encountered

- **Pre-existing flaky test (out of scope):** `DownloadObserverBatchTests.testDownloadCoordinatorBatchesObserverUpdatesDuringProgressFlush()` fails intermittently under full-target *parallel* execution and passes deterministically both in isolation and under serial execution (`-parallel-testing-enabled NO`). It is a non-`TestStore`, non-analytics test whose body is byte-identical to before this plan; its own source comment documents the load-sensitivity ("a measure of how busy the machine is"). The failure mode is a 2 s observer-update timeout in `waitForTaskValue`, not any analytics-related assertion. Logged in `deferred-items.md`; not fixed here to keep this plan a pure additive hardening pass.

## Next Phase Readiness

- Wave 6 can now instrument `DownloadsReducer` (and other reducers this target exercises) without inheriting test breakage from this target.
- The remaining affected test targets (`SettingFeatureTests`, `AppFeatureTests`, `HomeFeatureTests`, `DetailFeatureTests`, `ReadingFeatureTests`) still need the same hardening in their own waves before their reducers are instrumented.

## Self-Check: PASSED

- SUMMARY.md and deferred-items.md exist on disk.
- Task commits `b7aa25b8` and `5f6475b9` are present in git history.

---
*Phase: 14-analytics-instrumentation*
*Completed: 2026-07-24*
