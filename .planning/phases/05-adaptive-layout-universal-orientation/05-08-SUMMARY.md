---
phase: 05-adaptive-layout-universal-orientation
plan: 08
subsystem: ui-architecture
tags: [swift, swiftui, gestures, adaptive-layout, swift-testing]

requires:
  - phase: 05-adaptive-layout-universal-orientation
    provides: Native adaptive-layout conventions and a GeometryReader-free source tree from Plans 05-01 through 05-07
provides:
  - Reader gesture arithmetic driven by one captured container size and explicit locations
  - Baseline tests for pan clamps, scale anchors, and direction-aware tap zones
  - Page mapping APIs with an explicit landscape input and aspect-ratio regression coverage
affects: [05-adaptive-layout-universal-orientation, reader-gestures, reader-paging]

tech-stack:
  added: []
  patterns:
    - Capture one Equatable container size outside rendering transforms and inject it into main-actor gesture state
    - Require adaptive-layout facts as explicit inputs to otherwise deterministic mapping helpers

key-files:
  created:
    - AppPackage/Tests/ReadingFeatureTests/GestureHandlerTests.swift
  modified:
    - AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/ReadingFeature/Support/GestureHandler.swift
    - AppPackage/Sources/ReadingFeature/Support/PageHandler.swift
    - AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift

key-decisions:
  - "Reader gesture math consumes one outer-container size while the existing gesture sources continue supplying locations until Plan 05-09."
  - "PageHandler requires isLandscape at every call site; the construction-time resume seed uses portrait mapping until observed geometry is available."

patterns-established:
  - "Gesture geometry seam: inject container size and location into MainActor state instead of reading process-global window or touch state inside the handler."
  - "Adaptive mapping seam: remove environment-derived default arguments so the compiler enforces explicit geometry threading."

requirements-completed: [UIARCH-01]

coverage:
  - id: D1
    description: "Reader pan-clamp, anchor, and tap-zone arithmetic derives from one captured container size plus explicit gesture locations."
    requirement: UIARCH-01
    verification:
      - kind: unit
        ref: "AppPackage/Tests/ReadingFeatureTests/GestureHandlerTests.swift"
        status: pass
      - kind: other
        ref: "Static gates: GestureHandler has no DeviceUtil or TouchHandler reads, and one ReadingView onGeometryChange write supplies containerSize"
        status: pass
      - kind: integration
        ref: "xcodebuild build -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -quiet"
        status: pass
    human_judgment: true
    rationale: "Zoom, pan, tap, and paging coexistence across rotation remains part of the phase-end reader UAT and the Plan 05-09 gesture-source swap."
  - id: D2
    description: "GestureHandler baseline tests lock representative phone and iPad clamp, anchor, LTR/RTL tap-zone, and vertical-panel behavior."
    requirement: UIARCH-01
    verification:
      - kind: unit
        ref: "xcodebuild test -only-testing:ReadingFeatureTests/GestureHandlerTests (4 tests passed)"
        status: pass
      - kind: integration
        ref: "xcodebuild test -only-testing:ReadingFeatureTests"
        status: pass
    human_judgment: false
  - id: D3
    description: "PageHandler mapping requires an explicit landscape fact and preserves dual-page cover behavior for aspect-ratio-derived flags."
    requirement: UIARCH-01
    verification:
      - kind: unit
        ref: "AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift#aspectRatioFlagControlsDualPageEligibility"
        status: pass
      - kind: integration
        ref: "xcodebuild test -only-testing:ReadingFeatureTests"
        status: pass
      - kind: other
        ref: "Static gates: PageHandler contains no DeviceUtil dependency or default isLandscape argument"
        status: pass
    human_judgment: false

duration: 15min
completed: 2026-07-13
status: complete
---

# Phase 5 Plan 8: Reader Gesture Geometry Guard Summary

**Reader gesture and page-mapping math now receive explicit container facts, protected by deterministic phone and iPad parity tests before the native gesture-source swap.**

## Performance

- **Duration:** 15 min
- **Started:** 2026-07-13T05:49:18Z
- **Completed:** 2026-07-13T06:04:23Z
- **Tasks:** 3
- **Files modified:** 6

## Accomplishments

- Replaced GestureHandler's window and global-touch reads with one injected container size and explicit gesture locations while preserving the existing gesture composition and enablement gates.
- Added four deterministic Swift Testing cases that baseline-lock pan clamps, normalized scale anchors, LTR/RTL tap zones, and vertical panel toggling across representative phone and iPad sizes.
- Removed PageHandler's global landscape defaults, made every call site explicit, and extended mapping tests with the D-04 aspect-ratio truth table.
- Confirmed the complete ReadingFeatureTests target and package-wide simulator build pass with SwiftLint clean.

## Task Commits

Each task was committed atomically:

1. **Task 1: Inject container size and gesture location into GestureHandler** - `b1080410` (refactor)
2. **Task 2: Baseline-lock reader gesture geometry** - `9bd76e73` (test, committed by the orchestrator at the verified task boundary)
3. **Task 3: Require explicit reader landscape context** - `3e8d088c` (refactor, committed by the orchestrator at the verified task boundary)

## Files Created/Modified

- `AppPackage/Sources/ReadingFeature/Support/GestureHandler.swift` - Uses injected geometry for pan, anchor, and tap-zone calculations.
- `AppPackage/Sources/ReadingFeature/ReadingView.swift` - Captures the untransformed reader size once and passes landscape context explicitly to page mapping.
- `AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift` - Feeds the existing gesture sources' current location into the purified handler methods.
- `AppPackage/Sources/ReadingFeature/Support/PageHandler.swift` - Requires an explicit landscape flag and no longer imports AppTools.
- `AppPackage/Tests/ReadingFeatureTests/GestureHandlerTests.swift` - Locks gesture arithmetic across representative sizes, scales, directions, and zones.
- `AppPackage/Tests/ReadingFeatureTests/PageHandlerTests.swift` - Covers aspect-ratio-derived dual-page eligibility.

## Decisions Made

- Kept `TapGesture` and `MagnificationGesture` as the runtime sources for this guard plan, moving the existing touch location only to the call site so Plan 05-09 can swap sources against a green baseline.
- Attached the single size observation to the outer reader container, outside the scaled and offset content, so the captured dimensions remain in the tap gesture's scale-one coordinate space.
- Passed `isLandscape: false` for the construction-time resume seed because container geometry is not available until the view is observed; runtime mapping continues to pass the current landscape fact explicitly until Plan 05-09.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The Swift Testing clamp assertions initially compared `CGFloat` expectations with the handler's `Double` results; making the expected arithmetic explicitly `Double` removed misleading equal-looking failures without changing production code.
- Sandbox permissions prevented two local task commits. The orchestrator committed the already verified, task-scoped files atomically as `9bd76e73` and `3e8d088c`; no task boundaries were combined.

## Accessibility Review

- No control roles, labels, focus order, Dynamic Type behavior, or accessibility actions changed.
- The existing tap, double-tap, magnification, and drag composition and its scale-one page-turn gate remain intact.
- Phase-end VoiceOver and Switch Control reader checks remain appropriate when Plan 05-09 changes the gesture source types.

## Performance and Concurrency Review

- One `CGSize` projection is observed on the outer reader container; no GeometryReader or layout-participating wrapper was introduced.
- GestureHandler and PageHandler remain main-actor observable state, with no new asynchronous work or cross-actor transfer.
- The size observation writes only when the Equatable projected value changes, avoiding render-loop state churn.

## Known Stubs

None introduced or exposed by the modified code.

## Threat Review

No security-relevant surface was introduced; the new inputs are OS-supplied local gesture coordinates and view geometry, and no network, storage, authentication, or file-access boundary changed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Gesture and page-mapping arithmetic is baseline-locked for Plan 05-09's `SpatialTapGesture` and `MagnifyGesture` source swap.
- Runtime rotation, zoom/pan/tap coexistence, RTL paging, and assistive-technology interaction remain phase-end UAT items.
- No implementation blocker remains for Plan 05-09.

## Self-Check: PASSED

- All six intended source and test files and this summary exist, and all three task commits are present.
- Targeted GestureHandlerTests and PageHandlerTests passed; the full ReadingFeatureTests target and package-wide simulator build also pass with SwiftLint clean.
- Static gates confirm one reader container-size source, explicit PageHandler landscape inputs, and no DeviceUtil or TouchHandler reads inside either handler.

---
*Phase: 05-adaptive-layout-universal-orientation*
*Completed: 2026-07-13*
