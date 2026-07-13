---
phase: 07-root-privacy-mask-auto-lock-removal
plan: 05
subsystem: ui
tags: [swiftui, privacy-mask, shared-state, parameter-drilling]

# Dependency graph
requires:
  - phase: 07-01
    provides: self-sourcing privacyMask modifier and shared blur key
  - phase: 07-04
    provides: prior module sweep and temporary default-zero Detail routing inputs
provides:
  - SearchFeature view initializers without blurRadius parameters
  - DownloadsFeature view initializers without owned blurRadius parameters
  - Nine self-sourcing privacy-mask sites across SearchFeature and DownloadsFeature
  - TabBarView Search and Downloads calls without blur arguments
  - Transitional ReadingView blurRadius zero bridge retained until 07-07
affects: [07-06, 07-07, UIARCH-04]

# Tech tracking
tech-stack:
  added: []
  patterns: [self-sourcing root privacy masks, sequential parameter-drilling removal]

key-files:
  created: []
  modified:
    - AppPackage/Sources/SearchFeature/SearchRootView.swift
    - AppPackage/Sources/SearchFeature/SearchView.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsView.swift
    - AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift
    - AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift

key-decisions:
  - "07-05: DownloadsView keeps the plan-specified ReadingView blurRadius: 0 bridge until 07-07 while all Downloads-owned blur inputs are removed."

patterns-established:
  - "Module sweep: remove stored blur input, remove initializer and caller arguments, and replace each root autoBlur call with privacyMask in one module-consistent change."

requirements-completed: [UIARCH-04]

coverage:
  - id: D1
    description: SearchFeature has no blurRadius or autoBlur tokens and owns exactly five privacyMask sites.
    requirement: UIARCH-04
    verification:
      - kind: integration
        ref: "rg token counts: Search blurRadius=0, autoBlur=0, privacyMask()=5; TabBar SearchRootView multiline blur search=0"
        status: pass
    human_judgment: false
  - id: D2
    description: DownloadsFeature has no owned blur input, owns exactly four privacyMask sites, and retains only the ReadingView zero-valued bridge.
    requirement: UIARCH-04
    verification:
      - kind: integration
        ref: "rg token counts: Downloads autoBlur=0, privacyMask()=4, blurRadius=1 at ReadingView blurRadius: 0; TabBar DownloadsView multiline blur search=0"
        status: pass
      - kind: integration
        ref: "xcodebuild build -project ../EhPanda.xcodeproj -scheme AppFeature -destination generic/platform=iOS Simulator"
        status: pass
    human_judgment: false

# Metrics
duration: 5min
completed: 2026-07-14
status: complete
---

# Phase 07 Plan 05: Search and Downloads Privacy-Mask Sweep Summary

**Search and Downloads now self-source nine live privacy masks with all module-owned blur parameters and TabBar inputs removed.**

## Performance

- **Duration:** 5 min
- **Started:** 2026-07-13T17:52:55Z
- **Completed:** 2026-07-13T17:58:21Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Removed `blurRadius` from `SearchRootView` and `SearchView`, including internal calls and previews.
- Replaced all five SearchFeature `.autoBlur(radius:)` sites with the self-sourcing `.privacyMask()` modifier.
- Removed the owned blur inputs from `DownloadsView` and `DownloadInspectorView` and replaced all four DownloadsFeature mask sites.
- Removed the Search and Downloads blur arguments from `TabBarView` while preserving the one plan-specified `ReadingView(blurRadius: 0)` bridge.

## Task Commits

Each task was committed atomically:

1. **Task 1: Strip blurRadius and swap masks across SearchFeature** - `4e3840c1` (refactor)
2. **Task 2: Strip blurRadius and swap masks across DownloadsFeature** - `a76344da` (refactor)

## Files Created/Modified

- `AppPackage/Sources/SearchFeature/SearchRootView.swift` - Removed root blur input and self-sourced two privacy masks.
- `AppPackage/Sources/SearchFeature/SearchView.swift` - Removed child blur input and self-sourced three privacy masks.
- `AppPackage/Sources/DownloadsFeature/DownloadsView.swift` - Removed owned blur drilling, self-sourced three masks, and retained the ReadingView bridge.
- `AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift` - Removed the inspector blur input and self-sourced its mask.
- `AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift` - Removed only the Search and Downloads blur arguments.

## Decisions Made

- Preserved `ReadingView(blurRadius: 0)` as the only DownloadsFeature blur token because ReadingFeature keeps that parameter until its planned 07-07 sweep.
- Left the Setting and Detail transitional arguments untouched for their later phase plans.
- Preserved existing view hierarchy, accessibility semantics, and presentation anchors; the sweep changes only mask sourcing and initializer data flow.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for 07-06 to remove DetailFeature blur drilling.
- The ReadingView and SettingFeature transitional inputs remain intentionally scheduled for 07-07.

## Self-Check: PASSED

- All five modified source files and this summary exist.
- Task commits `4e3840c1` and `a76344da` are present in git history.
- Acceptance token counts, `git diff --check`, and the AppFeature simulator build passed.

---
*Phase: 07-root-privacy-mask-auto-lock-removal*
*Completed: 2026-07-14*
