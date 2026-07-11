---
phase: 03-native-reader-paging-swap-spike-gated
plan: 01
subsystem: testing
tags: [swift-testing, pagehandler, dual-page, dep-05]

requires:
  - phase: 02-native-masonry-grid-swap
    provides: spike-gated swap precedent + per-module test-target plumbing pattern
provides:
  - ReadingFeatureTests SwiftPM test target (Package.swift module case + .testTarget + .swiftlint.yml)
  - PageHandlerTests — frozen mapToPager/mapFromPager behavior (single, dual, cover-exception, boundary, round-trip, direction-agnostic)
  - ContainerDataSourceTests — frozen dual-page/exceptCover stack-collapsing [Int] outputs
affects: [03-03, 03-04, 03-05]

tech-stack:
  added: []
  patterns: [zip-parameterized Swift Testing tables, explicit isLandscape injection (no DeviceUtil global reads in tests)]

key-files:
  created:
    - AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift
    - AppPackage/Tests/ReadingFeatureTests/ContainerDataSourceTests.swift
    - AppPackage/Tests/ReadingFeatureTests/.swiftlint.yml
  modified:
    - AppPackage/Package.swift

key-decisions:
  - "Test-target dependency order follows house style (testingSupport first, then alphabetical modules); set is exactly the planned four"
  - "Verify destination substituted: no iPhone 16 Pro simulator exists on this machine — used iPhone Air (OS 26.5), the device 03-VALIDATION's full-suite command names"

patterns-established:
  - "ReadingFeatureTests is the DEP-05 mapping guard: any reader re-seam must keep it green untouched"

requirements-completed: [DEP-05]

coverage:
  - id: D1
    description: "ReadingFeatureTests target registered with lint plumbing; manifest parses"
    requirement: DEP-05
    verification:
      - kind: other
        ref: "swift package dump-package + grep ReadingFeatureTests Package.swift + test -f Tests/ReadingFeatureTests/.swiftlint.yml"
        status: pass
    human_judgment: false
  - id: D2
    description: "PageHandler mapping frozen: single-page, dual-page, cover-exception, boundary clamp, round-trip identity, direction-agnostic"
    requirement: DEP-05
    verification:
      - kind: unit
        ref: "AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift (8 tests / 58 cases)"
        status: pass
    human_judgment: false
  - id: D3
    description: "containerDataSource stack collapsing frozen for zero/single/dual-false/dual-true"
    requirement: DEP-05
    verification:
      - kind: unit
        ref: "AppPackage/Tests/ReadingFeatureTests/ContainerDataSourceTests.swift (4 tests / 13 cases)"
        status: pass
    human_judgment: false

duration: 13min
completed: 2026-07-12
status: complete
---

# Phase 3 Plan 01: ReadingFeatureTests Wave-0 Guard Summary

**Dedicated ReadingFeatureTests target freezing PageHandler.mapToPager/mapFromPager (incl. dual-page cover-exception math) and ReadingReducer.State.containerDataSource stack collapsing — the DEP-05 regression guard the reader re-seam must keep green**

## Performance

- **Duration:** ~13 min
- **Started:** 2026-07-12T06:52:00+09:00
- **Completed:** 2026-07-12T07:05:00+09:00
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- New `ReadingFeatureTests` SwiftPM test target (module case, `.testTarget` with exactly testingSupport/appModels/appTools/readingFeature, SwiftLint plugin, `parent_config` lint file) — first dedicated reading test target; previously reading coverage lived only in `DownloadsFeatureTests`.
- `PageHandlerTests`: 8 tests / 58 parameterized cases pinning single-page ±1 maps, dual-page odd-first-page stacks, cover-exception even-first-page stacks, the `result+1 == pageCount` last-page clamp (and its reverse map), `mapToPager(mapFromPager(i)) == i` round-trip identity in all three modes, and LTR/RTL direction-agnosticism (mapping stays logical; RTL is a view-layer flip).
- `ContainerDataSourceTests`: 4 tests / 13 cases pinning the `[Int]` stack data source for zero pages, single-page mode (portrait or dual-off), dual-page odd strides, and cover-exception `[1] + even strides`.
- Both suites run in ~0.06 s (sub-second sampling per 03-VALIDATION), deterministic off-device: every call passes `isLandscape:` explicitly.

## Task Commits

1. **Task 1: Register the ReadingFeatureTests target and its lint config** - `75787dbe` (test)
2. **Task 2: Write the PageHandler pure-mapping and containerDataSource stack-math suites** - `d8c7e05e` (test)

Deviation commit: `202d36c1` (chore: drop stale WaterfallGrid pin from workspace resolved)

## Files Created/Modified
- `AppPackage/Package.swift` - `readingFeatureTests` module case + `.testTarget` declaration
- `AppPackage/Tests/ReadingFeatureTests/.swiftlint.yml` - `parent_config: ../../../.swiftlint.yml` (AGENTS.md rule)
- `AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift` - pure-mapping regression suite
- `AppPackage/Tests/ReadingFeatureTests/ContainerDataSourceTests.swift` - stack-collapsing regression suite

## Decisions Made
- Dependency list order follows house style (testingSupport first, then alphabetical); the set matches the plan exactly — no SwiftUIPager, no extra products.
- Tests construct `Setting()` and mutate the three relevant fields (`readingDirection`, `enablesDualPageMode`, `exceptCover`) via a `makeSetting` helper, mirroring `ReadingReducerLocalTests` idiom.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Stale artifact] Workspace Package.resolved still pinned WaterfallGrid**
- **Found during:** Task 2 (first xcodebuild invocation resolved the workspace graph)
- **Issue:** `EhPanda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` still carried the WaterfallGrid pin removed from `AppPackage/Package.swift` in Phase 2 (only `AppPackage/Package.resolved` was regenerated then); xcodebuild refreshed it (originHash + pin drop, no version bumps).
- **Fix:** Committed the regenerated file as its own commit, keeping task commits pure.
- **Files modified:** EhPanda.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved
- **Verification:** Diff is exactly originHash + WaterfallGrid pin removal; test run green afterwards.
- **Committed in:** `202d36c1`

**2. [Rule 3 - Blocking] Verify-command simulator device does not exist**
- **Found during:** Task 2 (`xcodebuild test` destination error)
- **Issue:** Plan verify commands name `iPhone 16 Pro`; this machine has no such simulator (available: iPhone Air 26.5/27.0, iPhone 17e 26.4.1, iPad Pro 11-inch).
- **Fix:** Ran on `platform=iOS Simulator,name=iPhone Air,OS=26.5` — the device 03-VALIDATION's full-suite command uses. Also note the `AppPackage-Package` scheme resolves only with `AppPackage/` as the working directory.
- **Files modified:** none
- **Verification:** TEST SUCCEEDED, 12 tests green.
- **Committed in:** n/a (command substitution only)

---

**Total deviations:** 2 auto-fixed (1 stale artifact, 1 blocking)
**Impact on plan:** No scope creep; no production code touched.

## Issues Encountered
None beyond the deviations above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- The mapping guard is frozen and sub-second; Plans 03-03/03-04 must keep `xcodebuild test ... -only-testing:ReadingFeatureTests` green (run from `AppPackage/`, destination iPhone Air).
- No production source changed; SwiftUIPager untouched.

---
*Phase: 03-native-reader-paging-swap-spike-gated*
*Completed: 2026-07-12*
