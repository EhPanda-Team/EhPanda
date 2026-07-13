---
phase: 05-adaptive-layout-universal-orientation
plan: 13
subsystem: ui-architecture
tags: [swift, swiftui, adaptive-layout, carousel, container-relative-frame]

requires:
  - phase: 05-adaptive-layout-universal-orientation
    provides: Carousel card width, pitch, and centering derived from one container width in Plan 05-06
provides:
  - A Home slideshow card that fills the carousel-owned slot without an independent width calculation
  - One width source shared by rendered card size, scroll pitch, and centered peek
affects: [05-adaptive-layout-universal-orientation, home-feature, carousel-uat]

tech-stack:
  added: []
  patterns:
    - A child card fills its already-sized layout slot while its carousel owns coupled horizontal geometry

key-files:
  created: []
  modified:
    - AppPackage/Sources/HomeFeature/GalleryCardCell.swift

key-decisions:
  - "CardSlideSection remains the sole owner of carousel card width, pitch, and centered peek; GalleryCardCell fills the proposed slot."

patterns-established:
  - "Sole width ownership: compute coupled carousel geometry at the scroll-container boundary and do not rescale the child cell."

requirements-completed: [UIARCH-01]

coverage:
  - id: D1
    description: "The Home slideshow card fills the width selected by CardSlideSection, keeping its rendered size aligned with scroll pitch and centered peek."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' build"
        status: pass
      - kind: other
        ref: "Static ownership gate: GalleryCardCell has no containerRelativeFrame; CardSlideSection retains cardWidth, cardPitch, centeringMargin, and frame(width: cardWidth)"
        status: pass
    human_judgment: true
    rationale: "Centered appearance, matching scroll pitch, and symmetric peek in portrait and landscape on phone and iPad require visual UAT."

duration: 2min
completed: 2026-07-13
status: complete
---

# Phase 5 Plan 13: Carousel Sole-Width Ownership Summary

**The Home slideshow card now fills the carousel's pre-sized slot, so one width calculation governs the rendered card, snapping pitch, and centered peek.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-07-13T09:13:32Z
- **Completed:** 2026-07-13T09:14:52Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Removed `GalleryCardCell`'s nested 80-percent container-relative width calculation.
- Preserved `CardSlideSection` as the sole owner of `cardWidth`, `cardPitch`, and `centeringMargin`.
- Kept the cell's corner radius, animated focus handoff, color-scheme response, and fixed preview layout unchanged.

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove GalleryCardCell's independent card-width sizing** - `5d0ac2c9` (fix)

## Files Created/Modified

- `AppPackage/Sources/HomeFeature/GalleryCardCell.swift` - Fills the width proposed by its carousel slot without applying a second proportional width modifier.

## Decisions Made

- Kept all coupled carousel geometry in `CardSlideSection`; the reusable child cell now accepts its parent's proposal without independently interpreting the scroll container.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Accessibility Review

- No control roles, labels, focus behavior, text styles, motion behavior, or touch targets changed.
- The existing Reduce Motion path and opacity focus handoff remain intact.
- Visual UAT should confirm the slideshow remains readable and correctly centered in portrait and landscape on phone and iPad, including VoiceOver and larger text configurations.

## Performance Review

- Removing the redundant layout modifier eliminates one proportional layout calculation and avoids nested container-relative sizing.
- No state, observation, identity, image decoding, or animation scope changed.

## Tests

- No unit test was added because this change removes a SwiftUI sizing modifier whose contract is source-structural and appearance-sensitive.
- The static ownership gates and package-wide simulator build with the SwiftLint build-tool plugin passed; visual behavior remains routed to UAT.

## Known Stubs

None introduced or exposed by the modified code. Existing image-loading placeholders are functional loading UI.

## Threat Review

No security-relevant surface was introduced. The change only removes a SwiftUI sizing modifier and does not affect input, networking, authentication, persistence, or files.

## User Setup Required

None - no external service configuration is required.

## Next Phase Readiness

- G-05-1 defect 3 is closed in source and ready for phone/iPad portrait and landscape carousel UAT.
- Plan 05-14 can proceed with the Filters page-range prompt correction.

## Self-Check: PASSED

- The modified source file and task commit `5d0ac2c9` exist.
- The exact iPhone Air simulator package build succeeded with the SwiftLint build-tool plugin.
- Static gates confirm `GalleryCardCell` has no `containerRelativeFrame`, while the unchanged carousel retains its shared width, pitch, centering, and slot frame.

---
*Phase: 05-adaptive-layout-universal-orientation*
*Completed: 2026-07-13*
