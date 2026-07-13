---
phase: 05-adaptive-layout-universal-orientation
plan: 09
subsystem: ui-architecture
tags: [swift, swiftui, gestures, adaptive-layout, reader]

requires:
  - phase: 05-adaptive-layout-universal-orientation
    provides: Baseline-locked reader gesture arithmetic and one captured container size from Plan 05-08
provides:
  - SpatialTapGesture locations and MagnifyGesture anchors as the reader gesture sources
  - Container-aspect-ratio landscape eligibility across reader paging and controls
  - A ReadingFeature source tree without DeviceUtil layout reads
  - Complete removal of TouchHandler and the root UIKit gesture hook
affects: [05-adaptive-layout-universal-orientation, reading-feature, app-root, app-tools]

tech-stack:
  added: []
  patterns:
    - Native SwiftUI gesture values feed baseline-locked reader arithmetic directly
    - One observed container size drives landscape eligibility, reader widths, and control-panel geometry

key-files:
  created: []
  modified:
    - AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift
    - AppPackage/Sources/ReadingFeature/Support/GestureHandler.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift
    - AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift
    - AppPackage/Sources/AppFeature/RootView.swift
  deleted:
    - AppPackage/Sources/AppTools/TouchHandler.swift

key-decisions:
  - "Pinch gestures use MagnifyGesture.startAnchor directly, while double taps continue deriving an anchor from SpatialTapGesture.location."
  - "Reader landscape eligibility is container width greater than height; device identity remains injected only for device-class behavior."
  - "The initial zero-size control-panel pass clamps preview width to zero instead of producing an invalid negative frame."

patterns-established:
  - "Reader gesture sources: SpatialTapGesture in local coordinates and MagnifyGesture startAnchor, preserving the existing exclusive and scale gates."
  - "Reader geometry: thread the single captured CGSize through paging, placeholders, and controls rather than consulting global screen metrics."

requirements-completed: [UIARCH-01, UIARCH-03]

coverage:
  - id: D1
    description: "Reader taps and pinches use native SwiftUI gesture values while preserving the baseline-locked page-turn, zoom-anchor, and pan-clamp arithmetic."
    requirement: UIARCH-01
    verification:
      - kind: tests
        ref: "xcodebuild test -only-testing:ReadingFeatureTests/GestureHandlerTests"
        status: pass
      - kind: other
        ref: "ReadingView+Gestures.swift static gate: SpatialTapGesture, MagnifyGesture, and startAnchor present; TouchHandler and MagnificationGesture absent"
        status: pass
    human_judgment: true
    rationale: "Zoom, pan, double-tap, tap-to-turn, RTL, and assistive-technology coexistence require phase-end reader UAT."
  - id: D2
    description: "One captured reader size supplies aspect-ratio landscape eligibility, dual-page mapping, placeholder widths, and control-panel geometry."
    requirement: UIARCH-01
    verification:
      - kind: tests
        ref: "xcodebuild test -only-testing:ReadingFeatureTests"
        status: pass
      - kind: integration
        ref: "xcodebuild build -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'generic/platform=iOS Simulator'"
        status: pass
      - kind: other
        ref: "ReadingView, ReadingViewComponents, and ControlPanel contain no DeviceUtil reads"
        status: pass
    human_judgment: true
    rationale: "Rotation, dual-page resume position, and control-panel appearance across size classes require phase-end visual UAT."
  - id: D3
    description: "The TouchHandler global and delayed RootView UIKit gesture installation are fully removed."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "Package-wide generic iOS Simulator build after the final zero-size guard"
        status: pass
      - kind: other
        ref: "AppPackage/Sources search for TouchHandler and addTouchHandler is empty"
        status: pass
    human_judgment: false

duration: 10min
completed: 2026-07-13
status: complete
---

# Phase 5 Plan 9: Native Reader Gesture and Geometry Sources Summary

**The reader now consumes native local gesture values and one captured container size, with its legacy global touch and screen-metric sources removed.**

## Performance

- **Duration:** 10 min
- **Started:** 2026-07-13T06:07:22Z
- **Completed:** 2026-07-13T06:17:42Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Replaced global touch-point sampling and the deprecated magnification source with local `SpatialTapGesture` locations and `MagnifyGesture.startAnchor`, preserving the existing gesture composition and scale gates.
- Routed reader landscape eligibility, paging maps, dual-page state, placeholder sizing, slider width, and preview layout from the single captured reader size.
- Preserved device-class decisions through injected `DeviceClient` and converted width-class layout decisions to `horizontalSizeClass`.
- Deleted `TouchHandler` and the delayed root-level UIKit tap recognizer, leaving no source reference to either symbol.

## Task Commits

Each task was committed atomically:

1. **Task 1: Adopt native reader gesture sources** - `8d84fd17` (refactor)
2. **Task 2: Drive reader layout from captured container size** - `69c035d4` (refactor)
3. **Task 3: Delete TouchHandler and the RootView hook** - `6700e165` (refactor)
4. **Rule 1 review fix: Clamp the initial preview width** - `521cc257` (fix)

## Files Created/Modified

- `AppPackage/Sources/ReadingFeature/ReadingView+Gestures.swift` - Supplies local tap points and native magnification values and anchors.
- `AppPackage/Sources/ReadingFeature/Support/GestureHandler.swift` - Accepts `UnitPoint` directly for pinch anchors while retaining point-derived double-tap anchors.
- `AppPackage/Sources/ReadingFeature/ReadingView.swift` - Derives landscape from the observed reader size and threads that size into controls and page mapping.
- `AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift` - Sizes loading and error content relative to the reader container.
- `AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift` - Uses captured width, aspect ratio, injected device identity, and horizontal size class for layout.
- `AppPackage/Sources/AppFeature/RootView.swift` - Renders the tab root without installing a UIKit gesture recognizer.
- `AppPackage/Sources/AppTools/TouchHandler.swift` - Deleted with its `.shared` global.

## Decisions Made

- Used `MagnifyGesture.startAnchor` directly for pinch scaling because it is already a normalized `UnitPoint`; double-tap remains point-derived because `SpatialTapGesture.location` is a local `CGPoint`.
- Kept `AppTools` imported in ReadingView for its unrelated `DataCache` use after removing all `DeviceUtil` reads.
- Clamped preview width during the initial zero-sized geometry pass so a transient observation state cannot create an invalid negative frame.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Guarded zero-size preview geometry**

- **Found during:** Post-task performance and correctness review
- **Issue:** Before the first geometry observation, subtracting preview spacing from a zero container width produced a negative frame width.
- **Fix:** Clamped the derived preview width to zero until the captured container is wide enough.
- **Files modified:** `AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift`
- **Commit:** `521cc257`

---

**Total deviations:** 1 auto-fixed bug.
**Impact on plan:** The guard handles the required initial geometry state without changing steady-state reader layout.

## Issues Encountered

- Removing `AppTools` from ReadingView also hid its unrelated `DataCache` symbol; restoring the still-required import fixed the build at the source without reintroducing a DeviceUtil read.
- One escalated build request was unavailable because the account usage limit had been reached. The materially safer sandboxed generic-simulator package build completed successfully instead.

## Accessibility Review

- Existing control roles, labels, focus order, touch targets, text styles, and motion behavior remain unchanged.
- Tap-to-turn remains disabled while zoomed, and the native local gestures do not add a hidden UIKit recognizer to the accessibility interaction path.
- Phase-end UAT should cover VoiceOver, Switch Control, zoom/pan/tap coexistence, RTL page turns, and rotation.

## Performance and Concurrency Review

- The reader retains one Equatable `CGSize` observation outside its scaled content; no extra geometry observer or layout-participating wrapper was introduced.
- Control-panel geometry is derived from passed value state, and the zero-size guard prevents invalid initial layout work.
- Gesture and geometry updates remain main-actor view state with no new task, actor, or cross-isolation boundary.

## Known Stubs

None introduced or exposed by the modified code.

## Threat Review

No security-relevant surface was introduced. Gesture locations and geometry are OS-supplied local values, and removing the global UIKit recognizer reduces shared mutable input state.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- ReadingFeature is free of DeviceUtil layout reads, and TouchHandler is fully removed.
- Plan 05-10 can complete DeviceUtil and derived Defaults cleanup.
- Phase-end UAT still needs reader rotation, dual-page resume, zoom/pan/tap, RTL, and accessibility checks.

## Self-Check: PASSED

- All intended production files and this summary exist, the TouchHandler file is absent, and all four implementation commits are present.
- GestureHandlerTests and the full ReadingFeatureTests passed; the package-wide generic-simulator build passed after the final zero-size guard with SwiftLint clean.
- Static gates confirm native gesture sources, one captured-size landscape source, no targeted DeviceUtil reads, and no TouchHandler references.

---
*Phase: 05-adaptive-layout-universal-orientation*
*Completed: 2026-07-13*
