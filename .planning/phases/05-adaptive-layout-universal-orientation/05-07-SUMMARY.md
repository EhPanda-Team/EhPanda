---
phase: 05-adaptive-layout-universal-orientation
plan: 07
subsystem: ui-architecture
tags: [swift, swiftui, adaptive-layout, geometry-observation, canvas]

requires:
  - phase: 05-adaptive-layout-universal-orientation
    provides: Universal orientation and native adaptive-layout conventions from Plans 05-01 through 05-06
provides:
  - A GeometryReader-free AppPackage source tree
  - Login geometry observed through onGeometryChange
  - Gallery metadata columns sized through containerRelativeFrame
  - Live Text OCR geometry mapped through one captured container size
affects: [05-adaptive-layout-universal-orientation, login, gallery-infos, live-text]

tech-stack:
  added: []
  patterns:
    - Observe Equatable container size with onGeometryChange without participating in layout
    - Use Canvas size for its full-surface fill and one captured size for normalized OCR geometry

key-files:
  created: []
  modified:
    - AppPackage/Sources/SettingFeature/Login/LoginView.swift
    - AppPackage/Sources/DetailFeature/GalleryInfos/GalleryInfosView.swift
    - AppPackage/Sources/ReadingFeature/Support/LiveTextView.swift

key-decisions:
  - "Live Text skips OCR paths and interactive overlays until its first nonzero geometry observation."
  - "Canvas uses its current canvas size only for the full-surface tint; normalized OCR paths and interactive overlays share the captured size."

patterns-established:
  - "Geometry observation: project only CGSize through onGeometryChange and keep the view hierarchy responsible for layout."
  - "Normalized overlay mapping: guard zero size, then use one captured size for paths, frames, and positions."

requirements-completed: [UIARCH-01]

coverage:
  - id: D1
    description: "Login and gallery metadata preserve their proportional layout using onGeometryChange and containerRelativeFrame without GeometryReader."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "xcodebuild build -quiet -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: other
        ref: "Static gates: LoginView contains onGeometryChange, GalleryInfosView contains containerRelativeFrame, and neither contains GeometryReader"
        status: pass
    human_judgment: true
    rationale: "Decorative wave placement and metadata-column appearance across rotation and resized containers require phase-end visual UAT."
  - id: D2
    description: "Live Text maps Canvas OCR paths and interactive text overlays from one captured nonzero size without GeometryReader."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "xcodebuild build -quiet -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: other
        ref: "AppPackage/Sources GeometryReader search is empty and LiveTextView contains onGeometryChange plus a zero-size guard"
        status: pass
    human_judgment: true
    rationale: "Pixel alignment with recognized glyphs in portrait, landscape, single-page, and dual-page modes requires the planned phase-gate OCR UAT."

duration: 6min
completed: 2026-07-13
status: complete
---

# Phase 5 Plan 7: GeometryReader Removal Summary

**The AppPackage source tree is now GeometryReader-free, with login, gallery metadata, and Live Text geometry driven by native container APIs.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-13T05:36:44Z
- **Completed:** 2026-07-13T05:42:37Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments

- Removed LoginView's greedy full-body geometry wrapper and preserved its wave offset and text-field inset as fractions of one observed container size.
- Removed GalleryInfosView's geometry wrapper and made the title column one third of its horizontal scroll container.
- Preserved Live Text's normalized OCR path, frame, and position arithmetic with one captured nonzero size while letting Canvas tint its current full surface.
- Confirmed there are no remaining `GeometryReader` occurrences under `AppPackage/Sources` and that the package builds with SwiftLint clean.

## Task Commits

Each task was committed atomically:

1. **Task 1: LoginView and GalleryInfosView native geometry conversion** - `0176568e` (refactor)
2. **Task 2: LiveTextView captured OCR geometry conversion** - `f7961205` (refactor)

## Files Created/Modified

- `AppPackage/Sources/SettingFeature/Login/LoginView.swift` - Observes its container size and derives the existing decorative and form proportions without a geometry wrapper.
- `AppPackage/Sources/DetailFeature/GalleryInfos/GalleryInfosView.swift` - Sizes the metadata-title column relative to the list container.
- `AppPackage/Sources/ReadingFeature/Support/LiveTextView.swift` - Uses captured geometry for normalized OCR paths and interactive overlay placement, guarded until a nonzero size arrives.

## Decisions Made

- Kept Canvas's full-surface tint tied to the closure-provided canvas size, while every normalized OCR path and interactive overlay calculation uses the same captured size.
- Suppressed the initial zero-sized OCR work structurally by returning before path construction and omitting interactive overlays until geometry is available.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Accessibility Review

- No control roles, labels, focus behavior, text styles, or motion behavior changed.
- The Live Text overlay remains unavailable only during the initial zero-size layout pass, before any correctly sized target could be interactive.
- Phase-end UAT should include maximum Dynamic Type and VoiceOver navigation for login and gallery metadata alongside the planned OCR alignment checks.

## Known Stubs

None introduced or exposed by the modified code.

## Threat Review

No security-relevant surface was introduced; the changes consume only OS-supplied view geometry and already-decoded local OCR data.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Phase 5's source-level `GeometryReader` removal is complete.
- The phase gate must still verify OCR box alignment in portrait and landscape, single-page and dual-page reading modes.
- No implementation blocker remains for Plan 05-08.

## Self-Check: PASSED

- All three intended production files and this summary exist, and both task commits are present.
- The package-wide simulator build and SwiftLint build-tool plugin pass.
- The package source tree contains no `GeometryReader`, and all plan-level native geometry gates pass.

---
*Phase: 05-adaptive-layout-universal-orientation*
*Completed: 2026-07-13*
