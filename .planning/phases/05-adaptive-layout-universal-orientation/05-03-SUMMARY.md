---
phase: 05-adaptive-layout-universal-orientation
plan: 03
subsystem: ui-architecture
tags: [swift, swiftui, dependencies, adaptive-layout, device-idiom]

requires:
  - phase: 05-adaptive-layout-universal-orientation
    provides: DeviceType and the single-fact DeviceClient from Plan 05-01
provides:
  - Injected device-class branches for tab settings, tag suggestions, and search keywords
  - Container-relative settings widths and editor height
affects: [05-adaptive-layout-universal-orientation, app-components, settings-layout]

tech-stack:
  added: []
  patterns:
    - SwiftUI device-class branches read the injected DeviceClient fact
    - Settings dimensions derive from the active SwiftUI container

key-files:
  created: []
  modified:
    - AppPackage/Package.swift
    - AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift
    - AppPackage/Sources/AppComponents/TagSuggestionView.swift
    - AppPackage/Sources/SearchFeature/SearchRootView+Keywords.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift

key-decisions:
  - "AppComponents declares DeviceClient directly because TagSuggestionView owns the injected device fact."
  - "EhSetting fractions use the current container dimensions, accepting the planned short-edge-to-current-dimension rotation delta."

patterns-established:
  - "View idiom branches: inject deviceClient and compare deviceType() at the branch site."
  - "Metric layout: use containerRelativeFrame instead of global window dimensions."

requirements-completed: [UIARCH-01]

coverage:
  - id: D1
    description: "The three small idiom views preserve phone and iPad branches through injected DeviceType reads."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "xcodebuild build -quiet -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: other
        ref: "grep DeviceUtil/deviceClient.deviceType() gates across the three idiom view files"
        status: pass
    human_judgment: false
  - id: D2
    description: "EhSetting language columns and uploader editor derive their dimensions from the current container."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "xcodebuild build -quiet -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: other
        ref: "three containerRelativeFrame sites and zero DeviceUtil reads in EhSettingView+Sections3.swift"
        status: pass
    human_judgment: true
    rationale: "Rotation and split-view appearance of the proportional settings layout requires phase-end visual UAT."

duration: 4min
completed: 2026-07-13
status: complete
---

# Phase 5 Plan 3: Small Adaptive View Conversions Summary

**Injected device identity now drives the remaining small idiom branches, while settings dimensions follow the active SwiftUI container instead of global window metrics.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-07-13T04:51:17Z
- **Completed:** 2026-07-13T04:55:26Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Routed the TabBar settings presentation, tag-suggestion layouts, and search-keyword columns through `@Dependency(\.deviceClient).deviceType()` without changing their device-class semantics.
- Replaced two global short-edge width calculations and one global short-edge height calculation with current-container fractions in EhSetting.
- Kept the modified SwiftUI controls' existing accessibility semantics while making their geometry responsive to rotation and resized containers.

## Task Commits

Each task was committed atomically:

1. **Task 1: Swap the 3 idiom views to deviceClient.deviceType()** - `dab3284e` (refactor)
2. **Task 2: Convert EhSetting width/height metric reads to native** - `4d20137d` (refactor)

## Files Created/Modified

- `AppPackage/Package.swift` - Gives AppComponents a direct DeviceClient dependency for view-level injection.
- `AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift` - Uses injected device identity for iPad settings presentation.
- `AppPackage/Sources/AppComponents/TagSuggestionView.swift` - Uses injected device identity for phone suggestion presentation.
- `AppPackage/Sources/SearchFeature/SearchRootView+Keywords.swift` - Uses injected device identity for single- versus double-column keyword layout.
- `AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift` - Derives language-column widths and uploader-editor height from the active container.

## Decisions Made

- Added the DeviceClient package edge directly to AppComponents. Depending on a transitive module would make the injected client unavailable to `TagSuggestionView` and violate Swift package dependency ownership.
- Used `containerRelativeFrame` at all three settings sites. This keeps sizing local to SwiftUI and intentionally changes the old orientation-independent short edge into the current container dimension, as locked by Phase 5.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added the missing AppComponents dependency edge**

- **Found during:** Task 1 package integration review
- **Issue:** `TagSuggestionView` moved into `DeviceClient`, but the AppComponents target did not directly depend on that module; the planned import would otherwise fail to compile.
- **Fix:** Added `.module(.deviceClient)` to AppComponents and imported the module in the view.
- **Files modified:** `AppPackage/Package.swift`, `AppPackage/Sources/AppComponents/TagSuggestionView.swift`
- **Verification:** The AppPackage-Package simulator build succeeds under Swift 6 and the SwiftLint build-tool plugin.
- **Committed in:** `dab3284e`

---

**Total deviations:** 1 auto-fixed blocking issue.
**Impact on plan:** The package edge is the minimum integration required by the planned dependency injection; it adds no product scope.

## Issues Encountered

None.

## Known Stubs

None introduced or exposed by the modified code.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The remaining small idiom views and EhSetting metric sites are free of `DeviceUtil`.
- Plan 05-04 can continue converting AppComponents metric sites with the same container-relative pattern.
- Phase-end UAT should rotate and resize the EhSetting form to confirm the intended current-container proportions.

## Self-Check: PASSED

- Both task commits exist and all five modified files are tracked.
- The AppPackage-Package simulator build and SwiftLint plugin pass.
- All plan-level `DeviceUtil`, `deviceType()`, and `containerRelativeFrame` gates pass.

---
*Phase: 05-adaptive-layout-universal-orientation*
*Completed: 2026-07-13*
