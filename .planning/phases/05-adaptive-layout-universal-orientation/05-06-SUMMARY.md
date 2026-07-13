---
phase: 05-adaptive-layout-universal-orientation
plan: 06
subsystem: ui-architecture
tags: [swift, swiftui, adaptive-layout, geometry-observation, container-relative-frame]

requires:
  - phase: 05-adaptive-layout-universal-orientation
    provides: DeviceType, universal orientation, and adaptive-layout conventions from Plans 05-01 through 05-05
provides:
  - Home carousel card width and centering inset derived from one observed container width
  - Size-class-selected ranking widths and injected Toplists device identity
  - Container-relative gallery-card width with injected title-trimming device identity
affects: [05-adaptive-layout-universal-orientation, home-feature, defaults-dissolution]

tech-stack:
  added: []
  patterns:
    - Coupled layout values derive from one Equatable onGeometryChange measurement
    - Direct width fractions use containerRelativeFrame while device identity uses DeviceClient

key-files:
  created: []
  modified:
    - AppPackage/Sources/HomeFeature/HomeView+Sections.swift
    - AppPackage/Sources/HomeFeature/GalleryCardCell.swift

key-decisions:
  - "The carousel's card width, card pitch, and symmetric peek inset derive from one observed container width."
  - "Ranking layout follows horizontal size class, while Toplists and title trimming retain device-class semantics through DeviceClient."

patterns-established:
  - "Home carousel geometry: capture one CGFloat width and derive all coupled horizontal measurements from it."
  - "Home card layout: let the scroll container supply proportional width instead of reading device-derived Defaults values."

requirements-completed: [UIARCH-01]

coverage:
  - id: D1
    description: "The Home carousel derives card width and symmetric peek inset from one observed container width, while ranking width follows horizontal size class and Toplists idiom follows DeviceType."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' build -quiet"
        status: pass
      - kind: other
        ref: "HomeView+Sections.swift static gate: one onGeometryChange and zero DeviceUtil/cardCellSize/rankingCellWidth references"
        status: pass
    human_judgment: true
    rationale: "Carousel centering, scrolling, and the reviewed compact/regular ranking-width delta require phase-end visual UAT across rotation and resized containers."
  - id: D2
    description: "Gallery cards size from their scroll container and preserve phone-versus-iPad title trimming through the injected DeviceClient fact."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' build -quiet"
        status: pass
      - kind: other
        ref: "GalleryCardCell.swift static gate: zero DeviceUtil/cardCellWidth references and required containerRelativeFrame/deviceType sites present"
        status: pass
    human_judgment: true
    rationale: "Card appearance and title behavior across phone, iPad, rotation, and split view require phase-end visual UAT."

duration: 12min
completed: 2026-07-13
status: complete
---

# Phase 5 Plan 6: Home Adaptive Layout Summary

**The Home carousel, ranking stacks, and gallery cards now follow their active SwiftUI container or injected device identity instead of global screen-derived dimensions.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-13T05:20:00Z
- **Completed:** 2026-07-13T05:32:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Derived the carousel card width, card pitch, and symmetric peek inset from one locally observed container width while preserving the existing view-aligned scrolling and genuine card-height constant.
- Replaced the ranking stack's device-derived width with a horizontal-size-class fraction and kept the Toplists iPad branch device-class-based through `DeviceClient`.
- Made `GalleryCardCell` container-relative and migrated its phone-only title trimming to injected `DeviceType`, removing the remaining Home consumers of device-derived card-width Defaults.

## Task Commits

Each task was committed atomically:

1. **Task 1: Home carousel, ranking, and Toplists idiom conversion** - `9b95e012` (refactor)
2. **Task 2: GalleryCardCell width and idiom conversion** - `da6cd6d2` (refactor)

## Files Created/Modified

- `AppPackage/Sources/HomeFeature/HomeView+Sections.swift` - Observes one carousel width, derives coupled card/peek geometry, selects ranking fractions from size class, and reads the Toplists idiom from `DeviceClient`.
- `AppPackage/Sources/HomeFeature/GalleryCardCell.swift` - Fills 80 percent of the scroll container and reads the title-trimming idiom from `DeviceClient` while retaining genuine image-size constants from `AppTools`.

## Decisions Made

- Kept `Defaults.FrameSize.cardCellHeight` because it is a genuine, device-independent constant; only the device-derived width and compound card-size values were dissolved.
- Guarded scroll-geometry index calculation until the first nonzero width observation so the initial geometry pass cannot divide by a zero card pitch.
- Used size class only for ranking layout. Toplists composition and title trimming remain device-class decisions, preserving the Phase 5 idiom contract.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- During the internal verification handoff, `GalleryCardCell` still needed its `AppTools` import for genuine `Defaults.ImageSize` constants after the device-derived width was removed. With that import retained in the Task 2 commit, the exact package-wide simulator build completed with exit code 0; its SwiftLint build-tool plugin also passed.

## Accessibility Review

- No control roles, labels, focus behavior, text styles, or motion behavior changed; the existing Reduce Motion handling remains intact.
- The container-relative sizing introduces no new fixed text height or Dynamic Type limit.
- Phase-end UAT should include maximum Dynamic Type, VoiceOver navigation, rotation, and split-view checks for the carousel, ranking stacks, and gallery cards.

## Known Stubs

None introduced or exposed by the modified code. The existing image-loading placeholders are functional loading UI, not unwired stubs.

## Threat Review

No new security-relevant surface was introduced; the changes consume only OS-supplied container geometry and device identity.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Both HomeFeature files are free of `DeviceUtil` and the device-derived card/ranking Defaults consumers targeted by this plan.
- Plan 05-07 can proceed with the three `GeometryReader` conversions; Plan 05-10 can later delete the now-orphaned device-derived Defaults values.
- Carousel centering and card/ranking appearance remain routed to phase-end visual UAT; no implementation blocker remains.

## Self-Check: PASSED

- Both production files and this summary exist, and both task commits are present.
- The exact package-wide simulator build and SwiftLint build-tool plugin pass.
- All plan-level removal and native-adaptive-API gates pass, and coverage metadata validates with both appearance-sensitive deliverables routed to phase-end UAT.

---
*Phase: 05-adaptive-layout-universal-orientation*
*Completed: 2026-07-13*
