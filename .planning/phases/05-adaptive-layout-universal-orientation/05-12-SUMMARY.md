---
phase: 05-adaptive-layout-universal-orientation
plan: 12
subsystem: ui-architecture
tags: [swift, swiftui, adaptive-layout, reader, container-relative-frame]

requires:
  - phase: 05-adaptive-layout-universal-orientation
    provides: Container-driven reader geometry and the one-axis placeholder migration from Plan 05-09
provides:
  - Reader loading and failed placeholders bounded by both reader-container axes
  - Preserved single-page and dual-page aspect-fit sizing across orientation changes
affects: [05-adaptive-layout-universal-orientation, reading-feature, reader-uat]

tech-stack:
  added: []
  patterns:
    - Aspect-fit reader placeholders receive both horizontal and vertical container proposals

key-files:
  created: []
  modified:
    - AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift

key-decisions:
  - "Reader placeholders preserve the full vertical container extent while applying the dual-page divisor only to the horizontal axis."

patterns-established:
  - "Two-axis aspect fit: use containerRelativeFrame for both axes when a fixed-aspect view must choose between width- and height-bounded sizing."

requirements-completed: [UIARCH-01]

coverage:
  - id: D1
    description: "Reader loading and failed placeholders aspect-fit against both the width and height of the reader container while preserving dual-page half-width behavior."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' build"
        status: pass
      - kind: other
        ref: "ReadingViewComponents.swift static gates: two two-axis frames, zero horizontal-only frames, two aspect-ratio fits, and the loaded-image scaledToFit branch unchanged"
        status: pass
    human_judgment: true
    rationale: "Matching the loaded-page footprint in portrait and landscape, including dual-page mode, requires visual reader UAT."

duration: 2min
completed: 2026-07-13
status: complete
---

# Phase 5 Plan 12: Two-Axis Reader Placeholder Sizing Summary

**Reader loading and failed states now aspect-fit against the reader's complete viewport instead of resolving from width alone.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-07-13T09:06:37Z
- **Completed:** 2026-07-13T09:08:40Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Bounded both the image-loading placeholder helper and the explicit loading/failed page by the reader container's horizontal and vertical extents.
- Applied the dual-page divisor only to horizontal sizing while preserving the full available height.
- Kept the existing aspect ratio, background, page number, reload control, progress state, and loaded-image `scaledToFit()` branch unchanged.

## Task Commits

Each task was committed atomically:

1. **Task 1: Size both reader placeholders against both container axes** - `9732bbf3` (fix)

## Files Created/Modified

- `AppPackage/Sources/ReadingFeature/ReadingViewComponents.swift` - Supplies width and height proposals to both reader placeholder variants so aspect fitting can become height-bounded in landscape.

## Decisions Made

- Returned the complete container length for the vertical axis and retained the existing single-/dual-page divisor for the horizontal axis. This preserves page-pair behavior while allowing the aspect-ratio modifier to select the limiting viewport dimension.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The standalone `swiftlint` executable is not installed on the shell path. The required package build ran the configured SwiftLint build-tool plugin successfully and completed without lint errors.
- The standard state mutations advanced the plan count but left the prose progress and activity fields stale. Those fields were corrected to Plan 13 and 44/50 completed plans before the metadata commit.

## Accessibility Review

- No control role, label, reading order, gesture, focus behavior, text style, animation, or touch target changed.
- Preserving the loading/failed content footprint prevents controls and status content from becoming visually undersized after rotation.
- Reader UAT should confirm the placeholder footprint in portrait and landscape with VoiceOver and Switch Control enabled.

## Performance Review

- The change adds no observation, state, geometry reader, or layout wrapper; the existing container-relative calculation now handles one additional axis in the same modifier.
- The axis closure performs only a comparison and the existing dual-page division, so it introduces no meaningful render-time work or invalidation fan-out.

## Known Stubs

None introduced or exposed by the modified code. Existing `nil` assignments reset reader-image loading state and are not UI stubs.

## Threat Review

No security-relevant surface was introduced. The change is limited to SwiftUI sizing proposals and does not affect networking, authentication, persistence, files, or input trust boundaries.

## User Setup Required

None - no external service configuration is required.

## Next Phase Readiness

- G-05-1 defect 2 is closed in source and ready for portrait/landscape visual UAT in single- and dual-page reader modes.
- Plan 05-13 can proceed with the Home slideshow card-width ownership correction.

## Self-Check: PASSED

- The modified source file and task commit `9732bbf3` exist.
- The exact iPhone Air simulator package build succeeded with the SwiftLint build-tool plugin.
- Static gates confirm two two-axis container-relative frames, no horizontal-only placeholder frame, two retained aspect-ratio modifiers, the preserved dual-page divisor, and an unchanged loaded-image `scaledToFit()` branch.

---
*Phase: 05-adaptive-layout-universal-orientation*
*Completed: 2026-07-13*
