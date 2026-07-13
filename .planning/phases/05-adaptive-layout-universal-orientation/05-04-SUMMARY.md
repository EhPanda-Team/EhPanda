---
phase: 05-adaptive-layout-universal-orientation
plan: 04
subsystem: ui-architecture
tags: [swift, swiftui, adaptive-layout, container-relative-frame, geometry-observation]

requires:
  - phase: 05-adaptive-layout-universal-orientation
    provides: DeviceType, the injected DeviceClient fact, and the Phase 5 adaptive-layout conventions
provides:
  - Container-relative alert and reader-placeholder widths
  - Size-class-driven category grid sizing
  - Container-observed New Dawn geometry with injected device-class semantics
affects: [05-adaptive-layout-universal-orientation, app-components, device-util-removal]

tech-stack:
  added: []
  patterns:
    - Window-fraction view dimensions use containerRelativeFrame
    - Width-dependent decorative geometry observes one Equatable scalar with onGeometryChange
    - Layout breakpoints use horizontal size class while device-class factors use DeviceClient

key-files:
  created: []
  modified:
    - AppPackage/Sources/AppComponents/AlertView.swift
    - AppPackage/Sources/AppComponents/Placeholder.swift
    - AppPackage/Sources/AppComponents/CategoryView.swift
    - AppPackage/Sources/AppComponents/NewDawnView.swift

key-decisions:
  - "Alert and placeholder widths use the nearest SwiftUI container while preserving their existing 0.8 and 0.25/0.5 factors."
  - "NewDawnView observes only container width and keeps its iPad-specific sun factor through the injected DeviceClient."

patterns-established:
  - "AppComponents metric sizing: choose containerRelativeFrame for direct fractions and onGeometryChange only when multiple derived values share one measurement."
  - "Adaptive branching: use horizontalSizeClass for layout breakpoints and DeviceType for device-identity behavior."

requirements-completed: [UIARCH-01]

coverage:
  - id: D1
    description: "Alert and reader progress-placeholder widths follow the nearest container without changing the custom alert's action hierarchy."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' build -quiet"
        status: pass
      - kind: other
        ref: "DeviceUtil and system-dialog-anchor grep gates for AlertView.swift and Placeholder.swift"
        status: pass
    human_judgment: true
    rationale: "Rotation and resized-container appearance of the custom alert and reader placeholder requires phase-end visual UAT."
  - id: D2
    description: "CategoryView uses a size-class grid minimum, while NewDawnView derives offsets and sun size from observed container width and injected device identity."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' build -quiet"
        status: pass
      - kind: other
        ref: "DeviceUtil removal and horizontalSizeClass/onGeometryChange/deviceType grep gates"
        status: pass
    human_judgment: true
    rationale: "The reviewed size-class breakpoint delta and New Dawn composition across phone, iPad, rotation, and split view require phase-end visual UAT."

duration: 4min
completed: 2026-07-13
status: complete
---

# Phase 5 Plan 4: AppComponents Adaptive Layout Summary

**Four AppComponents now size and branch from their active SwiftUI container or injected device identity instead of global window metrics.**

## Performance

- **Duration:** 4 min
- **Started:** 2026-07-13T05:00:53Z
- **Completed:** 2026-07-13T05:05:13Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Replaced the alert card and reader progress-placeholder window fractions with container-relative widths while preserving their existing sizing factors.
- Moved the category grid's 80/100-point adaptive minimum to a horizontal-size-class decision.
- Made New Dawn's sun geometry respond to its actual container width while preserving the iPad-specific factor through `DeviceClient`.

## Task Commits

Each task was committed atomically:

1. **Task 1: AlertView + Placeholder window-fraction widths to container-relative** - `f69202a5` (refactor)
2. **Task 2: CategoryView grid breakpoint to size-class; NewDawnView offsets + idiom to native** - `83aaf65a` (refactor)

## Files Created/Modified

- `AppPackage/Sources/AppComponents/AlertView.swift` - Sizes the custom alert content to 80 percent of its nearest container without moving any action or presentation modifiers.
- `AppPackage/Sources/AppComponents/Placeholder.swift` - Sizes progress bars to one-quarter or one-half of the active container for dual- and single-page modes.
- `AppPackage/Sources/AppComponents/CategoryView.swift` - Selects the adaptive grid minimum from `horizontalSizeClass`.
- `AppPackage/Sources/AppComponents/NewDawnView.swift` - Captures container width once and derives its sun offsets, dimensions, and injected device-class factor from native inputs.

## Decisions Made

- Used direct `containerRelativeFrame` fractions where each site needed only one dimension, keeping measurement state out of AlertView and Placeholder.
- Captured only `CGFloat` width in NewDawnView. The Equatable geometry value updates state only when width changes and avoids broader geometry-driven invalidation.
- Preserved device-class semantics solely for New Dawn's 0.5/0.6 sun factor; CategoryView's visual breakpoint intentionally follows size class.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The package-wide scheme is exposed through `AppPackage/.swiftpm/xcode/package.xcworkspace`, not the root Xcode project. Running the required build through that local package workspace completed successfully.

## Known Stubs

None introduced or exposed by the modified code.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- These four AppComponents are free of `DeviceUtil`, reducing the remaining final-deletion inventory for Plan 05-10.
- Phase-end visual UAT should rotate and resize the custom alert, reader placeholder, category grid, and New Dawn greeting to validate the reviewed adaptive-layout deltas.
- No implementation blocker remains for Plan 05-05.

## Self-Check: PASSED

- Both task commits exist and all four modified source files are tracked.
- The package-wide iOS simulator build and SwiftLint build-tool plugin pass.
- All four source files are free of `DeviceUtil`; the required native adaptive APIs and injected device fact are present.

---
*Phase: 05-adaptive-layout-universal-orientation*
*Completed: 2026-07-13*
