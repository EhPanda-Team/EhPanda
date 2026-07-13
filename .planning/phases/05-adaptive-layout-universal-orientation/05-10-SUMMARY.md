---
phase: 05-adaptive-layout-universal-orientation
plan: 10
subsystem: ui-architecture
tags: [swift, swiftui, adaptive-layout, application-client, cleanup]

requires:
  - phase: 05-adaptive-layout-universal-orientation
    provides: Native adaptive layout, reader gesture sources, and orientation governance from Plans 05-01 through 05-09
provides:
  - A source tree without DeviceUtil or device-derived Defaults geometry
  - ApplicationClient-owned main-actor window discovery for interface-style overrides
  - Automated source and test evidence plus documented manual Phase 5 UAT gates
affects: [05-adaptive-layout-universal-orientation, app-models, app-tools, application-client]

tech-stack:
  added: []
  patterns:
    - Keep non-layout UIKit window discovery private to the client that performs the side effect
    - Retain only device-independent constants in shared Defaults geometry namespaces

key-files:
  created: []
  modified:
    - AppPackage/Sources/AppModels/Utilities/Defaults+Runtime.swift
    - AppPackage/Sources/ApplicationClient/ApplicationClient.swift
  deleted:
    - AppPackage/Sources/AppTools/DeviceUtil.swift

key-decisions:
  - "ApplicationClient selects the last key window from foreground-active scenes, then falls back to the last window of the last scene, preserving the former behavior locally."
  - "Defaults.FrameSize keeps only the device-independent card height and no longer needs main-actor isolation."
  - "Runtime rotation and Live Text visual checks remain explicit manual gates for phase verification rather than being inferred from static or unit-test evidence."

patterns-established:
  - "UIKit side effects own their private scene lookup instead of depending on a process-global device utility."
  - "Phase cleanup proves global removal with source-wide residual gates after the compiler and tests pass."

requirements-completed: [UIARCH-01]

coverage:
  - id: D1
    description: "Shared FrameSize and ImageSize declarations contain no device-derived geometry, while cardCellHeight remains available."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "AppPackage-Package iPhone Air simulator build"
        status: pass
      - kind: other
        ref: "Source-wide deleted Defaults property-name gate"
        status: pass
    human_judgment: false
  - id: D2
    description: "ApplicationClient preserves the interface-style override through a private main-actor scene lookup without DeviceUtil."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "AppPackage-Package iPhone Air simulator build"
        status: pass
      - kind: other
        ref: "ApplicationClient DeviceUtil removal and overrideUserInterfaceStyle presence gate"
        status: pass
    human_judgment: false
  - id: D3
    description: "DeviceUtil and all residual screen-metric, GeometryReader, global touch-handler, and custom orientation-lock source symbols are absent."
    requirement: UIARCH-01
    verification:
      - kind: tests
        ref: "Full AppPackage-Package iPhone Air simulator test suite"
        status: pass
      - kind: integration
        ref: "Clean AppPackage-Package iPhone Air simulator build"
        status: pass
      - kind: other
        ref: "Phase 5 source-wide residual gates"
        status: pass
    human_judgment: true
    rationale: "Rotation, reader interaction parity, RTL paging, and Live Text alignment still require the documented phase UAT."

duration: 7min
completed: 2026-07-13
status: complete
---

# Phase 5 Plan 10: Terminal Adaptive-Layout Cleanup Summary

**Device-derived Defaults and the final DeviceUtil consumer are gone, leaving container-native layout and a client-local UIKit window lookup with the full package suite green.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-07-13T06:23:15Z
- **Completed:** 2026-07-13T06:29:53Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Removed every orphaned device-derived FrameSize and ImageSize property while retaining the genuine card-height constant and unrelated gallery-host URLs.
- Moved foreground key-window discovery and the fallback window selection into a private main-actor ApplicationClient helper without changing interface-style behavior.
- Deleted DeviceUtil after confirming it had no consumers, then passed the clean package build, full package test suite, SwiftLint plugin, and every Phase 5 residual source gate.
- Confirmed automated evidence for native reader gestures, explicit container geometry, and orientation-lock removal remains present across the source tree.

## Task Commits

Each task was committed atomically:

1. **Task 1: Dissolve the device-derived Defaults props** - `a401dfb5` (refactor)
2. **Task 2: Rehome ApplicationClient window access into a private inline lookup** - `6c4f3522` (refactor)
3. **Task 3: Delete DeviceUtil.swift and prove the phase source gates** - `c1b77dc7` (refactor)

## Files Created/Modified

- `AppPackage/Sources/AppModels/Utilities/Defaults+Runtime.swift` - Keeps only the device-independent card height and active-host URL values.
- `AppPackage/Sources/ApplicationClient/ApplicationClient.swift` - Discovers the interface-style window through a private main-actor helper.
- `AppPackage/Sources/AppTools/DeviceUtil.swift` - Deleted after its final consumers were removed.

## Decisions Made

- Preserved the former window-selection order exactly: the last key window from foreground-active scenes, followed by the last window from the last available scene.
- Removed `@MainActor` from `Defaults.FrameSize` because its only remaining member is an immutable device-independent constant.
- Kept `import AppTools` in ApplicationClient for its unrelated FileUtil dependency and in Defaults runtime support for AppUtil.

## Deviations from Plan

None - the three implementation tasks were executed exactly as written.

## Issues Encountered

- The full suite still emits the pre-existing TestingSupport warning that `HTMLFilename` is not Sendable when carried by `TestError`. It was already recorded in `deferred-items.md`; no warning was suppressed or changed out of scope.

## Manual Phase Gate

- **Status:** Pending `/gsd-verify-work`; no runtime device-rotation or Live Text fixture was exercised during this source-execution plan.
- Required UAT remains: rotate reader portrait/landscape in single- and dual-page modes, verify RTL paging and zoom/pan/tap coexistence, confirm the landscape-phone grid reaches roughly four columns, rotate detail and home without snap-back, and verify Live Text overlays remain aligned.
- Static evidence is green: the four-orientation Info.plist remains the OS source of truth, all custom orientation-lock symbols are absent, and reader landscape eligibility is container-driven.

## Accessibility Review

- No control roles, labels, focus order, touch targets, text styles, or accessibility actions changed.
- The interface-style override still reaches the same selected window, preserving the app's light/dark appearance behavior.
- Runtime verification should pair rotation checks with VoiceOver, Switch Control, Dark Interface, and Increase Contrast checks on the reader and representative adaptive layouts.

## Performance and Concurrency Review

- The window helper is main-actor isolated with its UIKit caller, introduces no asynchronous work, and retains no window or scene state.
- Removing device-derived computed properties eliminates repeated global scene/screen enumeration from shared layout constants.
- No actor, task, continuation, unchecked Sendable conformance, or cross-isolation transfer was added.

## Known Stubs

- `AppPackage/Sources/ApplicationClient/ApplicationClient.swift` retains the existing generic `placeholder()` trap used only by IssueReporting's unimplemented test dependency; it does not feed production UI or data.

## Threat Review

No security-relevant surface was introduced or removed. The private lookup enumerates existing UIKit scenes only to apply a cosmetic interface style; authentication, storage, networking, privacy blur, and biometric auto-lock remain untouched.

## User Setup Required

None - no external service configuration is required.

## Next Phase Readiness

- Phase 5 implementation is complete and all automated gates pass.
- The documented manual rotation, reader interaction, accessibility, and Live Text checks are ready for `/gsd-verify-work`.
- No source or test blocker remains for Phase 6 planning.

## Self-Check: PASSED

- All intended modified files and this summary are present, DeviceUtil is absent, and all three task commits exist.
- The clean simulator build and full simulator test suite pass with SwiftLint clean apart from the separately documented compiler warning.
- Source-wide gates confirm no DeviceUtil, GeometryReader, TouchHandler, AppOrientationMask, AppDelegateClient, enablesLandscape, or setOrientationPortrait references remain, while onGeometryChange remains in use.

---
*Phase: 05-adaptive-layout-universal-orientation*
*Completed: 2026-07-13*
