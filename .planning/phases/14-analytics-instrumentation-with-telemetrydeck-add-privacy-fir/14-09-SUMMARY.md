---
phase: 14-analytics-instrumentation
plan: 09
subsystem: testing
tags: [telemetrydeck, analytics, tca, teststore, dependency-hardening, swift-testing]

# Dependency graph
requires:
  - phase: 14-06
    provides: "AnalyticsClient with testValue = .unimplemented (loud default) and .noop; the four test targets already declare .module(.analyticsClient)"
provides:
  - "Every TestStore in AppFeatureTests, HomeFeatureTests, DetailFeatureTests and ReadingFeatureTests resolves analyticsClient to the no-op client"
  - "The app-root target (AppFeatureTests) is fully hardened, including scoped-child stores, so any wave-6 plan's emission cannot turn it red"
affects: [wave-6 instrumentation of AppFeature/HomeFeature/DetailFeature/ReadingFeature reducers, phase-close ANALYTICS-01]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Per-store analyticsClient = .noop override placed in each TestStore's existing dependency closure"
    - "Bare TestStores given a labeled withDependencies: closure (single_line_trailing_closure is error severity, so a labeled-argument closure is used, not a trailing one)"
    - "Shared makeStore/makePresentationStore/makeHomeStore factories hardened once, covering every store they vend"
    - "Behavioral probe sited on a scoped-child case the app-root store also drives, to prove scoped-child exposure at runtime"

key-files:
  created:
    - .planning/phases/14-analytics-instrumentation-with-telemetrydeck-add-privacy-fir/14-09-SUMMARY.md
  modified:
    - AppPackage/Tests/AppFeatureTests/ (3 files: AppReducerScenePhaseTests, PresentationLifecycleTests, PresentationFeatureTests — 10 stores)
    - AppPackage/Tests/HomeFeatureTests/ (2 files: FiltersPresentationLifecycleTests, HomePresentationLifecycleTests — 8 stores)
    - AppPackage/Tests/DetailFeatureTests/ (3 files: CommentsReducerTests, DetailReadingSeedTests, DetailReadingLifecycleTests — 5 stores)
    - AppPackage/Tests/ReadingFeatureTests/ (1 file: ReadingReducerImageFetchTests — 1 store)

key-decisions:
  - "Hardened at each real TestStore initializer (24 sites across 9 files) rather than adding a suite-level dependency trait, per plan guidance"
  - "Existing per-suite factories (makeStore, makePresentationStore, presentationStore, makeHomeStore, DetailReadingLifecycleTests.makeStore) were hardened once, covering every store they vend"
  - "The client's testValue = .unimplemented was left untouched — hardening happens only at the store sites, so every un-hardened target elsewhere still fails loudly"
  - "The AppFeature probe was sited on PresentationFeature.detectClipboardURL — a scoped-child case the AppReducer root store also drives (via receive(\\.presentation.detectClipboardURL)) — to prove the scoped-child exposure at runtime, not just the direct child store"

patterns-established:
  - "Analytics dependency hardening: add sorted 'import AnalyticsClient' + '$0.analyticsClient = .noop' to every TestStore closure in a target ahead of reducer instrumentation"

requirements-completed: []

coverage:
  - id: D1
    description: "Every TestStore in the four targets resolves analyticsClient to the no-op client (24 store constructions across 9 files)"
    requirement: ANALYTICS-01
    verification:
      - kind: unit
        ref: "xcodebuild test -only-testing:AppFeatureTests -only-testing:HomeFeatureTests -only-testing:DetailFeatureTests -only-testing:ReadingFeatureTests => TEST SUCCEEDED"
        status: pass
      - kind: other
        ref: "temporary real analyticsClient.send(.quickSearchWordUsed) emission from one case in each of the four modules (PresentationFeature.detectClipboardURL, HomeReducer.onPresented, DetailReducer.presentReading, ReadingReducer.refetchNormalImageURLsDone) => four-target run stayed green, no unimplemented issue"
        status: pass
    human_judgment: false

# Metrics
duration: ~12min
completed: 2026-07-24
status: complete
---

# Phase 14 Plan 09: Harden the Four Remaining Test Targets' Analytics Dependency Summary

**Every `TestStore` in `AppFeatureTests`, `HomeFeatureTests`, `DetailFeatureTests` and `ReadingFeatureTests` (24 store constructions across 9 files) now resolves `analyticsClient` to the no-op client, so no wave-6 reducer instrumentation can turn these targets red — proven by exact count reconciliation and by a temporary real analytics emission from all four modules, including one sited on a scoped-child case that the app-root store also drives.**

## Performance

- **Duration:** ~12 min
- **Completed:** 2026-07-24
- **Tasks:** 3 (2 with code commits; Task 3 is a revert-to-clean behavioral proof)
- **Files modified:** 9 test files across 4 targets

## Accomplishments

- Hardened the analytics dependency at every `TestStore` site in all four targets: added a sorted `import AnalyticsClient` and `$0.analyticsClient = .noop` to each store's dependency closure (or once per shared factory).
- Fully hardened the load-bearing app-root target `AppFeatureTests`, including the scoped-child `PresentationFeature` stores that `AppReducer` composes — the sites most likely to have been missed.
- Proved full coverage per target by reconciling the `TestStore(` count against the hardened-store count (a clean 24/24 with zero difference), and by a behavioral probe: a temporary real `analyticsClient.send(...)` emission from one case in each of the four modules, all of which stayed green.
- Left the client's loud `testValue = .unimplemented` default untouched, so any un-hardened target elsewhere still fails loudly on an unexpected analytics call.

## Task Commits

1. **Task 1: Harden AppFeatureTests and HomeFeatureTests** — `7934d74a` (test)
2. **Task 2: Harden DetailFeatureTests and ReadingFeatureTests** — `7eed115c` (test)
3. **Task 3: Prove the pass with a real emission from each of the four modules** — no code commit (probe added to four source reducers, verified green across the four targets, then fully reverted — leaves no residue)

**Plan metadata:** `<final>` (docs: complete plan)

## Store-Count Reconciliation

The research figure of **24 store constructions across 9 files** was confirmed by counting the substring `TestStore(` in each target. Every one is a real `TestStore(...)` initializer; where a suite uses a shared factory, that factory's single `TestStore` is one of the counted sites and is hardened once, covering every case that routes through it.

**Reconciliation result:** 24 `TestStore(` sites, 24 `analyticsClient = .noop` overrides — a 1:1 match with **zero difference** in every target.

### Per-file `TestStore(` counts (all hardened)

| Target | File | count | how hardened |
|---|---|---|---|
| AppFeatureTests | AppReducerScenePhaseTests.swift | 1 | `makeStore(...)` factory (the AppReducer root store, vends 3 instances) |
| AppFeatureTests | PresentationLifecycleTests.swift | 1 | `makePresentationStore()` factory (scoped-child PresentationFeature store) |
| AppFeatureTests | PresentationFeatureTests.swift | 8 | `presentationStore(...)` factory + 7 inline stores (4 bare → labeled `withDependencies:` closure) |
| HomeFeatureTests | FiltersPresentationLifecycleTests.swift | 1 | store's trailing closure |
| HomeFeatureTests | HomePresentationLifecycleTests.swift | 7 | `makeHomeStore(...)` factory + 6 inline stores (4 bare → labeled closure) |
| DetailFeatureTests | CommentsReducerTests.swift | 2 | one bare → labeled closure, one trailing closure |
| DetailFeatureTests | DetailReadingSeedTests.swift | 2 | each store's trailing closure |
| DetailFeatureTests | DetailReadingLifecycleTests.swift | 1 | `makeStore()` factory |
| DetailFeatureTests | GalleryNavigationTests.swift | 0 | no store — navigation-helper tests, nothing to harden |
| ReadingFeatureTests | ReadingReducerImageFetchTests.swift | 1 | store's `withDependencies:` closure |
| **Total** | | **24** | **All covered** |

Per-target subtotals: AppFeatureTests **10**, HomeFeatureTests **8**, DetailFeatureTests **5**, ReadingFeatureTests **1** — matching the plan's artifact figures exactly.

## Behavioral Probe

**Result: PASS for all four modules.** A throwaway `analyticsClient.send(.quickSearchWordUsed)` emission (plus `import AnalyticsClient` and `@Dependency(\.analyticsClient)`) was temporarily added to one reducer case each module's target exercises:

| Module | Probe case | Exercised by | Result |
|---|---|---|---|
| AppFeature | `PresentationFeature.detectClipboardURL` | `PresentationFeatureTests` (direct child store) **and** `AppReducerScenePhaseTests` via `receive(\.presentation.detectClipboardURL)` on the AppReducer root store | PASS |
| HomeFeature | `HomeReducer.onPresented` | `HomePresentationLifecycleTests.homeTabPresentationSkipsFetchWhenAlreadyPopulated` | PASS |
| DetailFeature | `DetailReducer.presentReading` | `DetailReadingSeedTests` + `DetailReadingLifecycleTests` | PASS |
| ReadingFeature | `ReadingReducer.refetchNormalImageURLsDone` | `ReadingReducerImageFetchTests` | PASS |

The AppFeature probe was deliberately sited on a **scoped-child** case (`PresentationFeature`) that the **root** `AppReducer` store also drives, since scoped-child stores are the ones most likely to be missed — a green run proves the root store's `.noop` override propagates into the composed child. Each probe emission runs synchronously as the case is handled (a bare statement, no effect-flow change), so an un-hardened store would have tripped the `.unimplemented` client's issue-reporting `send`. All four modules' source targets already declare `.module(.analyticsClient)` (wired by 14-06), so **no Package.swift edit was needed**.

Running the full four-target suite produced **TEST SUCCEEDED** with the probes active. **No store was exposed** — every store was already hardened. The edits were then fully reverted: `git status --porcelain AppPackage/Sources` is **empty** at task end, and `git diff --name-only` lists nothing outside the four test-target directories. A grep confirms zero `analyticsClient` references remain in the four source modules.

## Verification

- `xcodebuild test -skipMacroValidation -skipPackagePluginValidation -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -only-testing:AppFeatureTests -only-testing:HomeFeatureTests`: **TEST SUCCEEDED** (Task 1 gate).
- `... -only-testing:DetailFeatureTests -only-testing:ReadingFeatureTests`: **TEST SUCCEEDED** (Task 2 gate).
- `... -only-testing:AppFeatureTests -only-testing:HomeFeatureTests -only-testing:DetailFeatureTests -only-testing:ReadingFeatureTests` with probes active: **TEST SUCCEEDED** (Task 3 gate).
- The `-skipMacroValidation -skipPackagePluginValidation` flags are required after Phase 14's TelemetryDeck dependency invalidated Xcode's macro trust approvals; they are the repo's established CI flags (`.github/workflows/test.yml`), not a suppression of a real error. The plan's `<automated>` gates omitted both, so they were added per the execution directive.
- The `git diff` for the two task commits is purely additive (import lines + `$0.analyticsClient = .noop` lines + a labeled `withDependencies:` closure for the bare-form stores); no `#expect`, `store.send`, `store.receive`, state-mutation closure, or unrelated dependency override was changed.
- Imports remain sorted (`sorted_imports`, error severity): `import AnalyticsClient` sorts first (case-insensitively before `AppFeature`/`AppComponents`/`AppModels`) in every touched file.
- SwiftLint runs as the SPM build-tool plugin during the build; error-severity violations would fail compilation, and every build succeeded. No suppression directives were added.

## Decisions Made

- Hardened at each real `TestStore` initializer (per-store closure, or once per shared factory) rather than introducing a suite-level dependency trait — the plan explicitly rules out the trait.
- Placed `$0.analyticsClient = .noop` first (alphabetically) within multi-override closures for consistency. Bare `TestStore(initialState:reducer:)` sites received a labeled `withDependencies: { $0.analyticsClient = .noop }` argument (single-statement labeled-argument closures are lint-clean; `single_line_trailing_closure` targets trailing closures, which these are not).
- Sited the AppFeature behavioral probe on a scoped-child case (`PresentationFeature.detectClipboardURL`) the root store also exercises, to exercise the highest-risk exposure path directly.

## Deviations from Plan

None - plan executed exactly as written. Bare `TestStore` sites were given a labeled `withDependencies:` closure (the plan anticipates this: "add the override to each store's existing trailing dependency-configuration closure ... otherwise per-store inline override"). Two identical `read: 7` stores in `PresentationFeatureTests` and the two identical stores in `DetailReadingSeedTests` were hardened with a single scoped `replace_all` each — same text, same intended edit.

## Requirements

ANALYTICS-01 is a **phase-spanning** requirement owned by phase-close (plan 14-17), not by this plan. It remains `- [ ]` in `.planning/REQUIREMENTS.md`. This plan advances its test-hardening prerequisite but does not close it; `requirements mark-complete` was intentionally **not** run for ANALYTICS-01.

## Issues Encountered

None.

## Next Phase Readiness

- Wave 6 can now instrument the `AppFeature`, `HomeFeature`, `DetailFeature` and `ReadingFeature` reducers without inheriting test breakage from any of these four targets.
- With plans 14-07 (DownloadsFeatureTests), 14-08 (SettingFeatureTests) and 14-09 (these four) complete, the full analytics test-hardening blast radius is covered ahead of instrumentation.

## Self-Check: PASSED

- SUMMARY.md exists on disk.
- Task commits `7934d74a` and `7eed115c` are present in git history.
- Task 3 intentionally produced no commit (probe reverted); `git status --porcelain AppPackage/Sources` empty confirms no residue.

---
*Phase: 14-analytics-instrumentation*
*Completed: 2026-07-24*
