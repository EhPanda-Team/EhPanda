---
phase: 14-analytics-instrumentation
plan: 01
subsystem: infra
tags: [telemetrydeck, spm, swift-testing, swiftlint, analytics]

# Dependency graph
requires:
  - phase: 11-infra-refactor-lint-capstone
    provides: the repository-wide SwiftLint ratchet and the per-module `.swiftlint.yml` convention every new target must follow
provides:
  - AnalyticsClient SPM source target, lint-covered, with the D-08 bucket vocabulary as its first content
  - AnalyticsClientTests, SearchFeatureTests and FavoritesFeatureTests declared and registered in the default test plan
  - TelemetryDeck SDK pinned at a 2.x stable tag with the telemetryDeck target-dependency alias
  - Every feature and test target later waves instrument already resolves AnalyticsClient
  - ANALYTICS-01 opened in REQUIREMENTS.md
affects: [14-03, 14-05, 14-06, 14-12, 14-17]

# Tech tracking
tech-stack:
  added: [TelemetryDeck SwiftSDK 2.14.1]
  patterns:
    - "One shared bucket vocabulary for every analytics numeric, rather than per-metric boundaries"
    - "Classification by `switch` over ranges so the compiler carries the no-gaps guarantee"
    - "Single-owner manifest: one plan owns Package.swift and the test plan for the whole phase"

key-files:
  created:
    - AppPackage/Sources/AnalyticsClient/Buckets.swift
    - AppPackage/Sources/AnalyticsClient/.swiftlint.yml
    - AppPackage/Tests/AnalyticsClientTests/BucketTests.swift
    - AppPackage/Tests/AnalyticsClientTests/.swiftlint.yml
    - AppPackage/Tests/SearchFeatureTests/.swiftlint.yml
    - AppPackage/Tests/SearchFeatureTests/SearchFeatureTests.swift
    - AppPackage/Tests/FavoritesFeatureTests/.swiftlint.yml
    - AppPackage/Tests/FavoritesFeatureTests/FavoritesFeatureTests.swift
  modified:
    - AppPackage/Package.swift
    - AppPackage/Package.resolved
    - AppPackage/Tests/FeatureTests.xctestplan
    - EhPanda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
    - .planning/REQUIREMENTS.md

key-decisions:
  - "`package: \"SwiftSDK\"` is the correct product reference — research assumption A1 resolved in favor of the URL-last-component convention already used for ColorfulX and SwiftyOpenCC; no fallback to `package: \"TelemetryDeck\"` was needed"
  - "A NaN duration clamps to the shortest bucket rather than falling through to the longest — NaN compares false against every range, so the default arm would have silently inflated session-length metrics"
  - "Both new search-family test targets ship a placeholder `@Suite` so SwiftPM does not warn on a source-less target directory; plan 14-12 replaces them"
  - "`AnalyticsClient` takes a `.module(.cookieClient)` edge so D-11's login-state default parameter can read `@SharedReader(.didLogin)` per signal rather than freezing it at launch"

patterns-established:
  - "Bucket vocabulary: closed String-raw-value enums with a failable-free classifying initializer, total by construction over the whole input domain"
  - "Totality proof without restating the switch: a monotonicity sweep asserts no ascending input ever revisits an earlier bucket and every declared case is reachable"

requirements-completed: []

coverage:
  - id: D1
    description: "CountBucket and DurationBucket map every Int / TimeInterval to exactly one bucket, with no gaps or overlaps at any boundary (D-08)"
    requirement: "ANALYTICS-01"
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AnalyticsClientTests/BucketTests.swift#countBucketMapsEveryBoundary, #durationBucketMapsEveryBoundary, #countBucketIsTotalAndMonotonic, #durationBucketIsTotalAndMonotonic, #notANumberDurationClampsToTheShortestBucket, #everyRenderingIsDistinct"
        status: pass
    human_judgment: false
  - id: D2
    description: "The TelemetryDeck SPM package resolves to a 2.x stable tag with no pre-release pin (D-12 supply-chain hygiene)"
    requirement: "ANALYTICS-01"
    verification:
      - kind: other
        ref: "swift package --package-path AppPackage resolve && ! grep -q -- '-beta' AppPackage/Package.resolved — resolved 2.14.1 at ad4a03ec"
        status: pass
    human_judgment: false
  - id: D3
    description: "All three new test targets are declared, lint-covered, and actually execute in the default test plan"
    requirement: "ANALYTICS-01"
    verification:
      - kind: integration
        ref: "xcodebuild test -skipMacroValidation -skipPackagePluginValidation -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' — TEST SUCCEEDED; BucketTests, SearchFeatureTests and FavoritesFeatureTests all present in the executed-suite list"
        status: pass
    human_judgment: false
  - id: D4
    description: "Every feature and test target later waves instrument already resolves AnalyticsClient, so no later plan modifies Package.swift or FeatureTests.xctestplan"
    requirement: "ANALYTICS-01"
    verification:
      - kind: other
        ref: "grep -c 'module(.analyticsClient)' AppPackage/Package.swift — 18 (criterion: at least 17)"
        status: pass
    human_judgment: false
  - id: D5
    description: "ANALYTICS-01 exists in REQUIREMENTS.md, unchecked, with acceptance criteria, a Phase 14 mapping row and consistent coverage counts"
    requirement: "ANALYTICS-01"
    verification:
      - kind: other
        ref: "grep -c 'ANALYTICS-01' .planning/REQUIREMENTS.md — 3; coverage counts 23 total / 23 mapped / 0 unmapped"
        status: pass
    human_judgment: false

# Metrics
duration: ~8min (execution), closed out retroactively
completed: 2026-07-24
status: complete
---

# Phase 14-01: AnalyticsClient module foundation Summary

**TelemetryDeck 2.14.1 pinned and wired into a new lint-covered `AnalyticsClient` module whose first content is the D-08 bucket vocabulary — `CountBucket` and `DurationBucket`, total over their whole input domains and proven so at every boundary.**

## Performance

- **Duration:** ~8 min (first commit 08:29:28+09:00, last commit 08:37:48+09:00)
- **Started:** 2026-07-24T08:29:28+09:00
- **Completed:** 2026-07-24T08:37:48+09:00
- **Tasks:** 3
- **Files modified:** 13 (8 created, 5 modified)

## Accomplishments

- `AnalyticsClient` exists as a compilable SPM source target carrying its own `.swiftlint.yml`, alongside three new test targets — `AnalyticsClientTests`, `SearchFeatureTests` and `FavoritesFeatureTests` — all four lint-covered and all three test targets registered in the default test plan.
- The TelemetryDeck SDK is pinned with `.upToNextMajor(from: "2.14.1")` and resolves to the stable `2.14.1` tag (revision `ad4a03ec`); no `-beta` substring appears anywhere in either resolved file.
- `CountBucket` and `DurationBucket` classify every `Int` and every `TimeInterval` into exactly one bucket via a `switch` over ranges, so exhaustiveness checking carries the no-gaps guarantee rather than a hand-written chain of `if`s.
- `.module(.analyticsClient)` is wired into all nine feature source targets and six existing feature test targets up front (18 occurrences in the manifest), so no later plan in this phase has to touch `Package.swift` or `FeatureTests.xctestplan` while wave 6's seven parallel plans build against them.
- `ANALYTICS-01` is opened unchecked in REQUIREMENTS.md with a Phase 14 mapping row and coverage counts raised to 23/23 mapped.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add the TelemetryDeck dependency and declare every target the phase needs** — `8695c090` (chore)
2. **Task 2: Implement the D-08 bucket vocabulary with exhaustive boundary tests** — `ac564069` (test, RED) → `b43cde92` (feat, GREEN)
3. **Task 3: Register the new test targets and open ANALYTICS-01** — `b43cde92` (test-plan registration, folded into the GREEN commit) + `f3047e6f` (docs)

_Note: TDD tasks may have multiple commits (test → feat → refactor)_

## Files Created/Modified

- `AppPackage/Package.swift` — TelemetryDeck package entry, `telemetryDeck` target-dependency alias, four new `Module` cases, one source target, three test targets, and `.module(.analyticsClient)` edges on fifteen existing targets
- `AppPackage/Package.resolved` / `EhPanda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` — SwiftSDK pinned at 2.14.1
- `AppPackage/Sources/AnalyticsClient/Buckets.swift` — `CountBucket` and `DurationBucket`, with a header comment naming them as the sole numeric vocabulary permitted in analytics payloads per D-08
- `AppPackage/Tests/AnalyticsClientTests/BucketTests.swift` — six `@Test` functions: two parameterized boundary tables (16 and 17 fixtures), two monotonicity/reachability sweeps, the NaN clamp, and a distinct-rendering check
- `AppPackage/Sources/AnalyticsClient/.swiftlint.yml`, `AppPackage/Tests/{AnalyticsClientTests,SearchFeatureTests,FavoritesFeatureTests}/.swiftlint.yml` — one-line `parent_config` each
- `AppPackage/Tests/{SearchFeatureTests,FavoritesFeatureTests}/*.swift` — placeholder `@Suite` structs, replaced by plan 14-12
- `AppPackage/Tests/FeatureTests.xctestplan` — three new `testTargets` entries
- `.planning/REQUIREMENTS.md` — new ANALYTICS section, `ANALYTICS-01`, Phase 14 mapping row, coverage 23/23

## Decisions Made

- **Research assumption A1 resolved:** `package: "SwiftSDK"` works. The repository directory is `SwiftSDK` while the vended product is `TelemetryDeck`; SwiftPM matches on the URL's last component, consistent with the existing `ColorfulX` and `SwiftyOpenCC` entries. The `package: "TelemetryDeck"` fallback the plan authorized was not needed.
- **NaN durations clamp to `.underTenSeconds`.** The plan's behavior block specified only that negative and zero durations clamp low. `TimeInterval.nan` compares false against every range pattern, so it would have fallen through the `switch` to `.overTwentyMinutes` and silently inflated session-length metrics. An explicit `isNaN` guard precedes the switch, and a dedicated test pins it.
- **Placeholder suites over empty directories.** SwiftPM warns on a target whose source directory holds no Swift file. Each of the two search-family targets ships one empty `@Suite` struct with a comment explaining it is a placeholder for plan 14-12.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 — Missing Critical] NaN duration guard added to `DurationBucket`**
- **Found during:** Task 2 (D-08 bucket vocabulary)
- **Issue:** The plan's behavior block specified totality over `TimeInterval` but named only negative and zero inputs as clamping low. A `NaN` input compares false against every range pattern and would reach the `default:` arm, classifying an unmeasurable duration as the longest session bucket.
- **Fix:** An explicit `guard seconds.isNaN == false` precedes the switch and returns `.underTenSeconds`, matching how a negative duration is treated.
- **Files modified:** `AppPackage/Sources/AnalyticsClient/Buckets.swift`, `AppPackage/Tests/AnalyticsClientTests/BucketTests.swift`
- **Verification:** `notANumberDurationClampsToTheShortestBucket` asserts it directly.
- **Committed in:** `b43cde92` (Task 2 GREEN commit)

**2. [Rule 1 — Documented Fallback] Placeholder `@Suite` files for the two empty test targets**
- **Found during:** Task 1 (target declaration)
- **Issue:** SwiftPM warns on a declared test target whose source directory contains no Swift file. The two search-family targets are declared in wave 1 but not filled until plan 14-12.
- **Fix:** One file per target containing a comment and an empty `@Suite struct`, exactly as the plan's step 7 authorized.
- **Files modified:** `AppPackage/Tests/SearchFeatureTests/SearchFeatureTests.swift`, `AppPackage/Tests/FavoritesFeatureTests/FavoritesFeatureTests.swift`
- **Verification:** Both suites appear in the executed-suite list of the full run, reporting 0 tests.
- **Committed in:** `8695c090` (Task 1 commit)

**3. [Commit boundary] Test-plan registration folded into the Task 2 GREEN commit**
- **Found during:** Task 2 → Task 3 boundary
- **Issue:** `AppPackage/Tests/FeatureTests.xctestplan` is a Task 3 file, but an unregistered test target reports zero tests, so the Task 2 GREEN commit could not demonstrate its own tests passing without it.
- **Fix:** The three test-plan entries landed in `b43cde92` alongside the implementation. Task 3's commit `f3047e6f` carries only the REQUIREMENTS.md change.
- **Verification:** Both files' final content matches the plan's acceptance criteria exactly.
- **Committed in:** `b43cde92`

---

**Total deviations:** 3 (1 missing-critical correctness fix, 1 plan-authorized fallback, 1 commit-boundary shift)
**Impact on plan:** The NaN guard is a genuine correctness improvement over the plan as written. The other two are mechanical. No scope creep — every file touched is in the plan's `files_modified` list.

## Issues Encountered

**Executor terminated before writing this summary.** All three tasks were executed and committed (`8695c090` … `f3047e6f`, 08:29–08:37), but the executor agent did not return and never wrote `14-01-SUMMARY.md`. `/gsd-execute-phase 14`'s safe-resume gate caught the production-commits-without-summary state on the next run and stopped before re-dispatching. This summary was reconstructed from the four commits, their diffs, and a fresh verification run against the plan's acceptance criteria — no code was re-executed or reverted.

**The Xcode workspace `Package.resolved` was left uncommitted.** `EhPanda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` carries the same TelemetryDeck 2.14.1 pin as `AppPackage/Package.resolved` but was not staged by the executor. Committed during close-out.

**Adding the dependency invalidated Xcode's macro trust approvals.** The first verification run failed at `ComputeTargetDependencyGraph` with three errors — `CasePathsMacros`, `PerceptionMacros` and `SwiftNavigationMacros` "changed since a previous approval". This is the known non-interactive macro gate, not a code defect: the new package changed the resolved graph fingerprint. The repository's own CI (`.github/workflows/test.yml`) and phases 11 and 13 all run `xcodebuild` with `-skipMacroValidation -skipPackagePluginValidation`; re-running with those two flags succeeded. **Every remaining Phase 14 plan's `<automated>` verify gate omits both flags and will hit the same wall.**

## Verification Run (close-out)

```
xcodebuild test -skipMacroValidation -skipPackagePluginValidation \
  -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air'
```

- **Result:** `** TEST SUCCEEDED **`, exit 0
- **Wall clock:** 84 s total (42.1 s of testing) — this is the full-suite feedback-latency figure `14-VALIDATION.md` asked for
- **Scale:** 641 tests across 127 suites
- **New suites present in the executed list:** `BucketTests` (passed, 0.017 s), `SearchFeatureTests` (0 tests, expected), `FavoritesFeatureTests` (0 tests, expected)
- **SwiftLint:** zero warnings repo-wide; the build-tool plugin ran against `Buckets.swift` and `BucketTests.swift`
- **Scheme untouched:** `EhPanda.xcscheme` contains zero `TestableReference` entries, confirming `14-VALIDATION.md`'s correction of the research claim — the test plan is the sole registration surface

## User Setup Required

None — no external service configuration required by this plan. The TelemetryDeck app ID is plumbed in plan 14-04.

## Next Phase Readiness

- Wave 2 (plans 14-03 and 14-04) is unblocked on this plan's side: `AnalyticsClient` compiles, `AnalyticsClientTests` runs, and every dependency edge later waves need is already declared.
- Wave 1 is **not** complete — plan 14-02 is a blocking owner-decision checkpoint (D-15 … D-19), and plans 14-03 and 14-04 both declare `depends_on: [14-01, 14-02]`.
- Carry-forward for every remaining plan in this phase: `xcodebuild` invocations need `-skipMacroValidation -skipPackagePluginValidation`.

---
*Phase: 14-analytics-instrumentation*
*Completed: 2026-07-24*
