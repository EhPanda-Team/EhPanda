---
phase: 05-adaptive-layout-universal-orientation
plan: 16
subsystem: ui-architecture
tags: [swift, swiftui, ipad, window-controls, safe-area]

requires:
  - phase: 05-adaptive-layout-universal-orientation
    provides: Universal reader orientation and container-relative reader geometry
provides:
  - Reader upper-toolbar clearance for iPad window controls
  - Full-screen iPad and iPhone reader-chrome parity through zero-inset gating
affects: [05-adaptive-layout-universal-orientation, reading-feature]

tech-stack:
  added: []
  patterns:
    - Observe the iOS 26 top-leading container-corner exclusion with onGeometryChange
    - Merge safe-area dimensions only when an iPad window-control corner exclusion exists

key-files:
  created: []
  modified:
    - AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift

key-decisions:
  - "Use containerCornerInsets.topLeading as the window-control signal because it resolves to zero for full-screen iPad containers without overlapping controls."
  - "Apply the captured top and leading exclusion only to UpperPanel, leaving LowerPanel, reader gestures, and paging geometry unchanged."

patterns-established:
  - "Window-control compensation is device-gated and exclusion-driven, so immersive full-screen chrome retains its existing edge placement."

requirements-completed: [UIARCH-03]

coverage:
  - id: D1
    description: "The reader upper toolbar reserves the iPad top-leading window-control region without changing full-screen iPad or iPhone chrome."
    requirement: UIARCH-03
    verification:
      - kind: integration
        ref: "xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' build"
        status: pass
      - kind: other
        ref: "Static gate confirms iPad-only containerCornerInsets/safeAreaInsets capture, no GeometryReader, and preservation of the non-pad landscape 8pt branch and 20pt horizontal baseline"
        status: pass
    human_judgment: true
    rationale: "An iPad window with visible window controls is required to confirm the dismiss button and title clear the controls; full-screen iPad and iPhone parity also remain explicit UAT checks."

duration: 8min
completed: 2026-07-13
status: complete
---

# Phase 5 Plan 16: Reader iPad Window-Control Geometry Summary

**The reader upper toolbar now clears iPad window controls while full-screen iPad and iPhone chrome retain their existing placement.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-13T09:30:00Z
- **Completed:** 2026-07-13T09:38:11Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Captured the iOS 26 top-leading window-control exclusion with an Equatable `onGeometryChange` observation on `ControlPanel`.
- Reserved the larger of the corner exclusion and rectangular safe-area dimensions for `UpperPanel` on iPad only.
- Kept the existing non-pad landscape 8-point top compensation, the panel's 20-point horizontal baseline, full-screen iPad placement, and all lower-panel/gesture/paging behavior intact.

## Task Commits

Each task was committed atomically:

1. **Task 1: Reserve the iPad window-control exclusion region for the reader upper toolbar** - `826e3cff` (fix)

## Files Created/Modified

- `AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift` - Observes iPad window-control geometry and applies its top-leading exclusion to the upper reader toolbar.

## Decisions Made

- Used `GeometryProxy.containerCornerInsets.topLeading` as the definitive signal that system window controls overlap the container. Its zero value keeps a full-screen iPad unchanged.
- Folded in `safeAreaInsets` only after that overlap signal is nonzero, preventing ordinary full-screen safe geometry from moving immersive reader chrome.
- Applied padding outside `UpperPanel` so its established 20-point internal horizontal padding remains the baseline and only the leading side gains the window-control exclusion.

## Deviations from Plan

None - plan executed exactly as written. The preferred `onGeometryChange` path was used instead of `GeometryReader`.

## Issues Encountered

None.

## Accessibility Review

- Native buttons, labels, focus behavior, and activation actions are unchanged; only the upper panel's physical placement changes when window controls overlap it.
- Clearing the system control region prevents the reader dismiss action from competing spatially with the window controls for touch, pointer, and Switch Control access.
- Runtime UAT should confirm VoiceOver and keyboard focus order in windowed iPad mode, plus unchanged full-screen iPad and iPhone placement.

## Performance Review

- The observation transforms geometry into one small Equatable `EdgeInsets` value, so state changes occur only when the relevant exclusion changes.
- Geometry state is local to `ControlPanel`; no `GeometryReader`, shared layout state, or reader-page invalidation path was introduced.

## Tests

- No unit test was added because this is platform-supplied window geometry and SwiftUI layout behavior. The exact simulator package build, SwiftLint build-tool plugin, and static source gates provide automated coverage; the actual window-control overlap remains a human UAT gate.

## Human Check

- Pending UAT: in an iPad window with macOS-style controls, confirm the reader dismiss button and title clear the controls.
- Pending parity UAT: confirm full-screen iPad and iPhone reader chrome remain visually unchanged.

## Known Stubs

None introduced or exposed by the modified code.

## Threat Review

No security-relevant surface was introduced. The change observes local SwiftUI layout geometry and adjusts padding without handling input, network, authentication, or persistence data.

## User Setup Required

None - no external service configuration is required.

## Next Phase Readiness

- G-05-4 defect 7 is closed in source and ready for windowed-iPad and full-screen parity UAT.
- Plan 05-17 can proceed with the distinct Home root surface and multi-scene declaration gap closure.

## Self-Check: PASSED

- `AppPackage/Sources/ReadingFeature/Support/ControlPanel.swift` exists, and task commit `826e3cff` is present.
- The required iPhone Air simulator package build succeeded with SwiftLint build-tool plugin execution.
- Static gates confirm iPad-only safe-geometry handling, no `GeometryReader`, and preservation of the existing non-pad landscape and horizontal-padding baselines.

---
*Phase: 05-adaptive-layout-universal-orientation*
*Completed: 2026-07-13*
