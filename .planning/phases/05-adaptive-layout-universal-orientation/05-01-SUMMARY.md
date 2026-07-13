---
phase: 05-adaptive-layout-universal-orientation
plan: 01
subsystem: ui-architecture
tags: [swift, swiftui, tca, dependencies, device-idiom]

requires:
  - phase: 04-concurrency-framework-migration
    provides: Async TCA effect consumers and the Swift 6 concurrency baseline
provides:
  - Injected DeviceType representation for OS device identity
  - DeviceClient reduced to one deviceType fact
  - Device-class gallery routing and login-delay branches migrated from isPad
affects: [05-adaptive-layout-universal-orientation, device-client, gallery-navigation]

tech-stack:
  added: []
  patterns:
    - Device identity is read through an injected DeviceClient closure
    - Main-actor device facts are resolved inside asynchronous TCA effects

key-files:
  created:
    - AppPackage/Sources/AppTools/DeviceType.swift
  modified:
    - AppPackage/Sources/DeviceClient/DeviceClient.swift
    - AppPackage/Sources/DetailFeature/GalleryNavigation.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
    - AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift
    - AppPackage/Sources/HomeFeature/HomeReducer+Body.swift
    - AppPackage/Sources/SearchFeature/SearchRootReducer.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift
    - AppPackage/Tests/DownloadsFeatureTests/DownloadsReducerActionTests.swift

key-decisions:
  - "DeviceType is the sole device-identity representation; boolean isPad is derived only at branch sites."
  - "Gallery navigation accepts the injected main-actor deviceType closure and resolves it inside its effect."

patterns-established:
  - "Device identity: consumers use @Dependency(\.deviceClient), while DeviceType.current remains confined to DeviceClient.live."
  - "Reducer isolation: synchronous @MainActor dependency closures are awaited when called from nonisolated effect operations."

requirements-completed: [UIARCH-01]

coverage:
  - id: D1
    description: "DeviceType and the single-fact DeviceClient compile cleanly under SwiftLint and Swift 6 strict concurrency."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "xcodebuild build -quiet -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
    human_judgment: false
  - id: D2
    description: "Gallery routing and login timing preserve the existing iPad versus non-iPad branches through DeviceType."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "xcodebuild test -quiet -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:DownloadsFeatureTests"
        status: pass
      - kind: other
        ref: "grep -rn 'deviceClient.isPad' AppPackage/Sources"
        status: pass
    human_judgment: false

duration: 6min
completed: 2026-07-13
status: complete
---

# Phase 5 Plan 1: Device Identity Foundation Summary

**A platform-backed `DeviceType` and single-fact `DeviceClient` now preserve iPad routing semantics without boolean device APIs or screen/touch globals.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-13T04:20:59Z
- **Completed:** 2026-07-13T04:27:02Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Added the owner-specified eight-case `DeviceType`, with its sole OS lookup isolated to `DeviceClient.live`.
- Collapsed `DeviceClient` from four facts to the injected `deviceType()` fact, removing its `DeviceUtil` and `TouchHandler` reads.
- Migrated gallery modal routing and the login delay branch to derive `.pad` from `DeviceType`, with the Downloads feature tests covering both routing paths.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add DeviceType and reshape DeviceClient to deviceType()** - `78fd2f14` (feat)
2. **Task 2: Swap the idiom consumers to deviceType() == .pad** - `5901ee63` (refactor)

## Files Created/Modified

- `AppPackage/Sources/AppTools/DeviceType.swift` - Defines the sendable device-idiom value and platform mapping.
- `AppPackage/Sources/DeviceClient/DeviceClient.swift` - Exposes only the injected main-actor `deviceType` fact.
- `AppPackage/Sources/DetailFeature/GalleryNavigation.swift` - Resolves injected device identity before choosing modal presentation or push navigation.
- `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift` - Derives the existing 1200/200 ms login delay from `DeviceType`.
- `AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift` - Supplies injected device identity to gallery routing.
- `AppPackage/Sources/HomeFeature/HomeReducer+Body.swift` - Supplies injected device identity to gallery routing.
- `AppPackage/Sources/SearchFeature/SearchRootReducer.swift` - Supplies injected device identity to gallery routing.
- `AppPackage/Sources/DownloadsFeature/DownloadsReducer.swift` - Supplies injected device identity to gallery routing.
- `AppPackage/Tests/DownloadsFeatureTests/DownloadsReducerActionTests.swift` - Uses the reshaped client to retain deterministic iPad routing coverage.

## Decisions Made

- Used `.phone` for `DeviceClient.noop`, matching the old `isPad: false` behavior.
- Passed the `@MainActor` device-type closure through `GalleryNavigation` and resolved it inside the effect. TCA reducer bodies are synchronous nonisolated contexts, so direct calls there do not satisfy Swift 6 actor isolation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Kept the main-actor device lookup inside asynchronous effects**

- **Found during:** Task 2 package build
- **Issue:** The plan's suggested direct synchronous call from reducer bodies failed Swift 6 isolation checking because reducer bodies are nonisolated.
- **Fix:** Gallery navigation accepts the injected `@MainActor` closure and awaits it inside `.run`; AppReducer likewise awaits the synchronous actor-isolated closure in its effect.
- **Files modified:** `GalleryNavigation.swift`, `AppReducer.swift`, and the four list reducers.
- **Verification:** The package build succeeds under Swift 6 strict concurrency.
- **Committed in:** `5901ee63`

**2. [Rule 3 - Blocking] Updated the affected DeviceClient test fixture**

- **Found during:** Task 2 call-site inventory
- **Issue:** A Downloads reducer test constructed the removed four-member client initializer and would no longer compile with the test target.
- **Fix:** The test now injects `deviceType: { .pad }`, preserving the same test intent.
- **Files modified:** `AppPackage/Tests/DownloadsFeatureTests/DownloadsReducerActionTests.swift`
- **Verification:** `DownloadsFeatureTests` passes.
- **Committed in:** `5901ee63`

---

**Total deviations:** 2 auto-fixed (1 bug, 1 blocking issue).
**Impact on plan:** Both fixes are direct consequences of the client signature change and preserve the intended behavior without expanding product scope.

## Issues Encountered

- The plan's build command requires running from `AppPackage/` with an explicit destination in this workspace. The equivalent simulator build completed successfully.

## Known Stubs

- `AppPackage/Sources/DeviceClient/DeviceClient.swift:42` — The generic `placeholder()` trap remains intentional test-dependency plumbing for `IssueReporting.unimplemented`; it does not flow to production UI or data.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Later Phase 5 plans can migrate view-level `DeviceUtil.isPad` and `isPhone` reads to the injected `DeviceType` fact.
- No blocker remains for Plan 05-02.

## Self-Check: PASSED

- Created file exists and both task commits are present.
- Package build, SwiftLint plugin execution, Task 1/2 grep gates, and Downloads feature tests pass.

---
*Phase: 05-adaptive-layout-universal-orientation*
*Completed: 2026-07-13*
