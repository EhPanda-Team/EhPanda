---
phase: 10-ui-polish
plan: 08
subsystem: ui
tags: [swiftui, preview, previewable, sizeThatFitsLayout, swiftlint]

# Dependency graph
requires:
  - phase: 10-ui-polish (10-07)
    provides: preceding POLISH-03 preview-migration groundwork
provides:
  - Named #Preview state matrices for the 8 stateful cell/component views (POLISH-03 heavy tier)
  - File-private synthetic previewFixture helpers per gallery cell
affects: [10-09, POLISH-03]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Named #Preview(\"…\") cases with boundary-value fixtures per D-08 full-matrix tier"
    - "@Previewable @State to drive an interactive display-only view preview (RatingView slider)"
    - "traits: .sizeThatFitsLayout for intrinsic-size cells"

key-files:
  created: []
  modified:
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift
    - AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift
    - AppPackage/Sources/HomeFeature/GalleryCardCell.swift
    - AppPackage/Sources/HomeFeature/GalleryRankingCell.swift
    - AppPackage/Sources/SearchFeature/GalleryHistoryCell.swift
    - AppPackage/Sources/AppComponents/RatingView.swift
    - AppPackage/Sources/AppComponents/NewDawnView.swift
    - AppPackage/Sources/AppComponents/SubSection.swift

key-decisions:
  - "RatingView is display-only (no Binding); its @Previewable requirement satisfied with a Slider driving a @Previewable @State rating value"
  - "Built via the EhPanda app scheme (whole AppPackage graph) — the plan's AppPackage-Package scheme does not exist in this project"

patterns-established:
  - "previewFixture: file-private Gallery factory varying title/rating/pageCount/uploader for boundary cases, keyed off the existing Gallery init (no new model API)"
  - "Baseline case reuses Gallery.preview; boundary cases use the file-private factory"

requirements-completed: [POLISH-03]

coverage:
  - id: D1
    description: "5 gallery cells (Thumbnail/Detail/Card/Ranking/History) migrated to named #Preview state matrices with min/max-rating and short/long-title boundary cases"
    requirement: POLISH-03
    verification:
      - kind: automated
        ref: "grep -cF PreviewProvider across 5 cells = 0; xcodebuild build EhPanda scheme BUILD SUCCEEDED"
        status: pass
    human_judgment: false
  - id: D2
    description: "RatingView/NewDawnView/SubSection migrated; RatingView interactive @Previewable + 0/2.5/5 cases"
    requirement: POLISH-03
    verification:
      - kind: automated
        ref: "grep -cF PreviewProvider across 3 files = 0; @Previewable present in RatingView; SwiftLint clean"
        status: pass
    human_judgment: false
  - id: D3
    description: "Preview visual correctness (Xcode canvas renders each state as intended)"
    verification: []
    human_judgment: true
    rationale: "Canvas rendering is a visual judgment the build cannot assert; deferred to end-of-phase human-verify"

# Metrics
duration: 20min
completed: 2026-07-18
status: complete
---

# Phase 10 Plan 08: Stateful Cell/Component Preview Enrichment Summary

**Migrated the 8 stateful cell/component views off legacy `PreviewProvider` structs onto named `#Preview("…")` state matrices — boundary-value fixtures (min/max rating, short/long title, page-count extremes), `@Previewable`-driven interactive rating preview, `.sizeThatFitsLayout` traits — with a clean zero-warning build and clean SwiftLint.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-07-18
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- 5 gallery cells (Thumbnail, Detail, Card, Ranking, History) now carry the D-08 full-matrix tier: named cases covering a loaded baseline plus min/max-rating and short/long-title boundaries, driven by synthetic `.preview` / file-private `previewFixture` data.
- RatingView gained an interactive `@Previewable @State` slider preview plus 0 / 2.5 / 5 boundary cases; NewDawnView and SubSection migrated at the pragmatic tier (single case / default+loading pair).
- Zero legacy preview structs remain in any of the 8 files; build zero warnings, SwiftLint zero violations (D-10/D-12 gate held, sequential build).

## Task Commits

1. **Task 1: Migrate + enrich the 5 gallery cells** - `e02a3e89` (refactor)
2. **Task 2: Migrate + enrich RatingView, NewDawnView, SubSection; build gate** - `42fb00c4` (refactor)

## Files Created/Modified
- `AppPackage/Sources/GalleryListComponents/Cells/GalleryThumbnailCell.swift` - Named #Preview matrix + previewFixture factory
- `AppPackage/Sources/GalleryListComponents/Cells/GalleryDetailCell.swift` - Named #Preview matrix + previewFixture factory
- `AppPackage/Sources/HomeFeature/GalleryCardCell.swift` - Named #Preview matrix; file-private card colors + previewFixture
- `AppPackage/Sources/HomeFeature/GalleryRankingCell.swift` - Named #Preview matrix (rank/title boundaries)
- `AppPackage/Sources/SearchFeature/GalleryHistoryCell.swift` - Named #Preview matrix (rating/title boundaries)
- `AppPackage/Sources/AppComponents/RatingView.swift` - Interactive @Previewable slider + 0/2.5/5 cases
- `AppPackage/Sources/AppComponents/NewDawnView.swift` - Single named #Preview (dropped sheet wrapper)
- `AppPackage/Sources/AppComponents/SubSection.swift` - Default + loading/no-show-all cases

## Decisions Made
- **RatingView `@Previewable`:** The view is display-only (`rating: Float`, no Binding), so the `@Previewable` requirement is met with a Slider bound to a `@Previewable @State var rating` that drives the star fill live — plus static 0/2.5/5 cases for boundary coverage.
- **Build scheme:** The plan named `AppPackage-Package`, which this project does not expose as a scheme. Built the `EhPanda` app scheme instead, which links the full `AppPackage` graph and therefore compiles all four touched modules (AppComponents, GalleryListComponents, HomeFeature, SearchFeature). Simulator retargeted from the unavailable iPhone 17 Pro to iPhone Air (OS 27.0).
- **D-09 held:** No color-scheme / dynamic-type / fixed-size preview variants; dropped the old `preferredColorScheme(.dark)` and deprecated `previewLayout(.fixed(...))` calls in favor of `.sizeThatFitsLayout`.

## Deviations from Plan

None - plan executed exactly as written. (The build-scheme and simulator substitutions above are environment adaptations, not code deviations: the plan's named scheme/device were absent locally; the equivalent app-scheme build over the same package graph satisfies the D-10/D-12 gate.)

## Issues Encountered
- `xcodebuild` initially failed on the plan's `AppPackage-Package` scheme and the `iPhone 17 Pro` destination (neither present locally). Resolved by building the `EhPanda` scheme on `iPhone Air,OS=27.0`. `BUILD SUCCEEDED` in ~26s, zero warnings. The `LLVM Profile Error: Failed to write default.profraw` line is a sandbox coverage-write artifact, not a build warning.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- POLISH-03 heavy tier complete for the 8 stateful cells/components. The remaining 34 screen files (D-07 remainder) follow in plan 10-09.
- No blockers.

## Self-Check: PASSED

---
*Phase: 10-ui-polish*
*Completed: 2026-07-18*
