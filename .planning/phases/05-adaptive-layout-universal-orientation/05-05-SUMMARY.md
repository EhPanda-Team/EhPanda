---
phase: 05-adaptive-layout-universal-orientation
plan: 05
subsystem: ui-architecture
tags: [swift, swiftui, adaptive-layout, size-class, container-relative-frame]

requires:
  - phase: 05-adaptive-layout-universal-orientation
    provides: DeviceUtil migration conventions and universal orientation from Plans 05-01 through 05-04
provides:
  - Container-relative comment image and detail-description widths
  - Size-class-selected archive and preview grid dimensions
  - Device-independent preview downsampling cap and size-class-selected tag preview dimensions
affects: [05-adaptive-layout-universal-orientation, detail-feature, defaults-dissolution]

tech-stack:
  added: []
  patterns:
    - Direct window fractions use containerRelativeFrame without geometry state
    - Layout breakpoints use horizontal size class instead of device-derived point thresholds
    - Non-layout image downsampling limits use fixed pixel caps

key-files:
  created: []
  modified:
    - AppPackage/Sources/DetailFeature/Comments/CommentsView.swift
    - AppPackage/Sources/DetailFeature/DetailView+Subviews.swift
    - AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift
    - AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift
    - AppPackage/Sources/DetailFeature/Components/TagDetailView.swift
    - AppPackage/Sources/AppComponents/PreviewImageView.swift
    - .planning/phases/05-adaptive-layout-universal-orientation/deferred-items.md

key-decisions:
  - "Direct width fractions use containerRelativeFrame, avoiding geometry state and extra invalidation."
  - "Archive cells receive the grid's size-class-selected width so grid sizing and rendered cell sizing cannot diverge."
  - "The preview downsampling cap is fixed at 660 pixels, preserving the former regular-width maximum without making file decoding a layout concern."

patterns-established:
  - "Detail layout: use horizontalSizeClass for discrete visual breakpoints and containerRelativeFrame for direct container fractions."
  - "Image decoding: keep pixel caps independent from SwiftUI layout environment values."

requirements-completed: [UIARCH-01]

coverage:
  - id: D1
    description: "Comment images and detail description items derive their widths from the active SwiftUI container."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' build -quiet"
        status: pass
      - kind: other
        ref: "DeviceUtil and preview-size grep gate for CommentsView.swift and DetailView+Subviews.swift"
        status: pass
    human_judgment: true
    rationale: "Rotation, split-view sizing, and the retained 80-point minimum require phase-end visual UAT."
  - id: D2
    description: "Archive and preview grids, archive padding, and preview label typography select their breakpoints from horizontal size class."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' build -quiet"
        status: pass
      - kind: other
        ref: "DeviceUtil and device-derived Defaults grep gate for ArchivesView.swift and PreviewsView.swift"
        status: pass
    human_judgment: true
    rationale: "The reviewed SE-to-compact collapse and size-class transitions require phase-end visual UAT."
  - id: D3
    description: "Tag previews use size-class-selected dimensions and local preview decoding uses a fixed 660-pixel cap."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' build -quiet"
        status: pass
      - kind: other
        ref: "previewMaxW, previewAvgW, and DeviceUtil grep gate for PreviewImageView.swift and TagDetailView.swift"
        status: pass
    human_judgment: true
    rationale: "Preview appearance and thumbnail fidelity across compact and regular widths require phase-end visual UAT."

duration: 7min
completed: 2026-07-13
status: complete
---

# Phase 5 Plan 5: Detail Adaptive Layout Summary

**Detail comments, descriptions, archives, and previews now size from their SwiftUI container or horizontal size class, while thumbnail decoding uses a device-independent pixel cap.**

## Performance

- **Duration:** 7 min
- **Started:** 2026-07-13T05:09:33Z
- **Completed:** 2026-07-13T05:16:54Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Replaced global window widths in comment images and detail-description items with direct container-relative sizing.
- Moved archive and preview grid dimensions, archive padding, preview typography, and tag preview dimensions to horizontal-size-class decisions.
- Replaced the device-derived preview downsampling maximum with a fixed 660-pixel cap, leaving the preview-width Defaults properties without DetailFeature or PreviewImageView consumers.

## Task Commits

Each task was committed atomically:

1. **Task 1: Comment + detail widths to container-relative** - `09622149` (refactor)
2. **Task 2: Archive grid + preview grid/font breakpoints to size-class** - `79c18fa2` (refactor)
3. **Task 3: Preview pixel cap + TagDetail width to native/fixed values** - `6bd6ed15` (refactor)

## Files Created/Modified

- `AppPackage/Sources/DetailFeature/Comments/CommentsView.swift` - Sizes single and paired comment images from the list container.
- `AppPackage/Sources/DetailFeature/DetailView+Subviews.swift` - Sizes description items from their scroll container and preview cards from horizontal size class.
- `AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift` - Uses one size-class-selected archive width for both the adaptive grid and its cells, plus size-class-selected download padding.
- `AppPackage/Sources/DetailFeature/Previews/PreviewsView.swift` - Selects adaptive preview bounds and label typography from horizontal size class.
- `AppPackage/Sources/DetailFeature/Components/TagDetailView.swift` - Selects tag preview dimensions from horizontal size class.
- `AppPackage/Sources/AppComponents/PreviewImageView.swift` - Uses a fixed 660-pixel local-thumbnail downsampling cap.
- `.planning/phases/05-adaptive-layout-universal-orientation/deferred-items.md` - Records a pre-existing custom-control accessibility issue found during review.

## Decisions Made

- Used `containerRelativeFrame` for direct fractions instead of storing observed geometry, which keeps the views stateless and avoids unnecessary invalidation.
- Calculated the archive item width once in the size-class-owning grid and passed it into each cell so layout metadata and rendered frames remain identical.
- Preserved the old regular-width maximum as the fixed preview decode cap (`220 * 3 = 660`); decoding quality is not a layout breakpoint.
- Accepted the locked adaptive deltas: the former 125-point SE archive branch now uses the 150-point compact value, and visual breakpoints follow size class rather than the old 744-point threshold.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `AppTools` remains required in `PreviewImageView` and `TagDetailView` for genuine, device-independent `Defaults` values such as `previewAspect` and shared URLs; the build verified that only the device-derived preview-width properties were removed from these consumers.

## Accessibility Review

- No control roles, labels, focus behavior, animation, or text styles changed; existing Dynamic Type styles remain intact.
- The custom archive download control's pre-existing missing button/disabled semantics were recorded in `deferred-items.md` rather than expanded into this layout-only plan.
- Phase-end UAT should include maximum Dynamic Type, VoiceOver navigation, rotation, and split-view checks on comments, archives, and previews.

## Known Stubs

None introduced or exposed by the modified code. Image loading placeholders are functional loading UI, not unwired stubs.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- DetailFeature and `PreviewImageView` no longer consume `DeviceUtil`, `archiveGridWidth`, or the device-derived preview width properties, so Plan 05-10 can delete those orphaned Defaults values.
- Plan 05-06 can continue the same container-observation and size-class conventions in HomeFeature.
- No implementation blocker remains.

## Self-Check: PASSED

- All six production files and this summary exist, and all three task commits are present.
- The package build and SwiftLint plugin pass; task and plan-level removal greps are empty.
- Coverage metadata validates with all three deliverables routed to phase-end visual UAT.

---
*Phase: 05-adaptive-layout-universal-orientation*
*Completed: 2026-07-13*
