---
phase: 07-root-privacy-mask-auto-lock-removal
plan: 04
subsystem: ui
tags: [swiftui, privacy-mask, shared-state, parameter-drilling]

# Dependency graph
requires:
  - phase: 07-01
    provides: self-sourcing privacyMask modifier and shared blur key
  - phase: 07-02
    provides: live scene-phase writer for the shared privacy-mask blur
  - phase: 07-03
    provides: app-root privacy masks and transitional zero-valued child arguments
provides:
  - HomeFeature view initializers without blurRadius parameters
  - FavoritesView without a blurRadius parameter
  - Eight self-sourcing privacy-mask sites across HomeFeature and FavoritesFeature
  - TabBarView Home and Favorites calls without blur arguments
affects: [07-05, 07-06, 07-07, UIARCH-04]

# Tech tracking
tech-stack:
  added: []
  patterns: [self-sourcing root privacy masks, sequential parameter-drilling removal]

key-files:
  created: []
  modified:
    - AppPackage/Sources/HomeFeature/HomeView.swift
    - AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift
    - AppPackage/Sources/HomeFeature/Popular/PopularView.swift
    - AppPackage/Sources/HomeFeature/Watched/WatchedView.swift
    - AppPackage/Sources/HomeFeature/Toplists/ToplistsView.swift
    - AppPackage/Sources/HomeFeature/History/HistoryView.swift
    - AppPackage/Sources/FavoritesFeature/FavoritesView.swift
    - AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift
    - AppPackage/Sources/DetailFeature/GalleryDestination.swift

key-decisions:
  - "07-04: Detail routing blur inputs temporarily default to zero so Home and Favorites can remove drilling before DetailFeature's 07-06 sweep."

patterns-established:
  - "Module sweep: remove stored blur input, remove initializer/caller arguments, and replace each root autoBlur call with privacyMask in one module-consistent change."

requirements-completed: [UIARCH-04]

coverage:
  - id: D1
    description: HomeFeature has no blurRadius or autoBlur tokens and owns exactly six privacyMask sites.
    requirement: UIARCH-04
    verification:
      - kind: integration
        ref: "rg token counts: Home blurRadius=0, autoBlur=0, privacyMask()=6"
        status: pass
    human_judgment: false
  - id: D2
    description: FavoritesFeature has no blurRadius or autoBlur tokens, owns two privacyMask sites, and TabBarView no longer passes blur values to Home or Favorites.
    requirement: UIARCH-04
    verification:
      - kind: integration
        ref: "rg token counts: Favorites blurRadius=0, autoBlur=0, privacyMask()=2; TabBar Home/Favorites multiline search=0"
        status: pass
      - kind: integration
        ref: "xcodebuild -project EhPanda.xcodeproj -scheme AppFeature -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO build"
        status: pass
    human_judgment: false

# Metrics
duration: 8min
completed: 2026-07-14
status: complete
---

# Phase 07 Plan 04: Home and Favorites Privacy-Mask Sweep Summary

**Home and Favorites now self-source eight live privacy masks with all module-local blur parameters and TabBar inputs removed.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-13T17:37:33Z
- **Completed:** 2026-07-13T17:45:35Z
- **Tasks:** 2
- **Files modified:** 9

## Accomplishments

- Removed `blurRadius` from `HomeView` and its five child view initializers, call sites, and previews.
- Replaced all six HomeFeature `.autoBlur(radius:)` sites with the self-sourcing `.privacyMask()` modifier.
- Removed `blurRadius` from `FavoritesView`, replaced its two modal masks, and removed the Home/Favorites arguments from `TabBarView`.
- Kept the sequential phase buildable by defaulting the still-transitional Detail routing inputs to zero until their planned 07-06 removal.

## Task Commits

Each task was committed atomically:

1. **Task 1: Strip blurRadius and swap masks across HomeFeature** - `4f6b3247` (refactor)
2. **Task 2: Strip blurRadius from FavoritesView and drop TabBar arguments** - `9bcbe9da` (refactor)

## Files Created/Modified

- `AppPackage/Sources/HomeFeature/HomeView.swift` - Removed the public blur input and all internal Home routing arguments.
- `AppPackage/Sources/HomeFeature/Frontpage/FrontpageView.swift` - Removed blur state and self-sourced two modal masks.
- `AppPackage/Sources/HomeFeature/Popular/PopularView.swift` - Removed blur state and self-sourced its filters mask.
- `AppPackage/Sources/HomeFeature/Watched/WatchedView.swift` - Removed blur state and self-sourced three modal masks.
- `AppPackage/Sources/HomeFeature/Toplists/ToplistsView.swift` - Removed the unused blur input.
- `AppPackage/Sources/HomeFeature/History/HistoryView.swift` - Removed the unused blur input while preserving the confirmation-dialog anchor.
- `AppPackage/Sources/FavoritesFeature/FavoritesView.swift` - Removed blur drilling and self-sourced both modal masks.
- `AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift` - Removed the Home and Favorites blur arguments only.
- `AppPackage/Sources/DetailFeature/GalleryDestination.swift` - Added temporary default-zero inputs for sequential module migration.

## Decisions Made

- Used temporary default-zero Detail routing inputs instead of retaining `blurRadius` tokens in Home/Favorites or prematurely executing the larger DetailFeature sweep. Plan 07-06 removes those inputs completely.
- Preserved existing SwiftUI control semantics and confirmation-dialog placement; the sweep changes only mask sourcing and initializer data flow.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Defaulted transitional Detail routing blur inputs**
- **Found during:** Task 1 and Task 2
- **Issue:** `HomeView` and `FavoritesView` route into DetailFeature APIs that still require `blurRadius` until plan 07-06, while this plan requires zero `blurRadius` tokens in both migrated modules.
- **Fix:** Added default-zero values to `galleryDestination` and `GalleryNavigationContainer` so migrated callers can omit the argument without pulling the DetailFeature sweep forward.
- **Files modified:** `AppPackage/Sources/DetailFeature/GalleryDestination.swift`
- **Verification:** The AppFeature graph builds successfully and both migrated modules report zero `blurRadius` tokens.
- **Committed in:** `4f6b3247`, `9bcbe9da`

---

**Total deviations:** 1 auto-fixed (1 blocking issue).
**Impact on plan:** The defaults are a temporary compile bridge within the already-planned phase sequence; they add no behavior and are removed by plan 07-06.

## Issues Encountered

- The simulator build reached the expected intermediate `TabBarView` initializer mismatch after Task 1, before Task 2 removed those arguments. A post-Task-2 simulator rerun could not obtain CoreSimulator access because sandbox escalation was unavailable; the materially equivalent generic-iOS AppFeature graph build completed successfully with SwiftLint enabled.
- The state progress helper reported 93% but wrote stale body fields and an incorrect frontmatter percentage; `STATE.md` was corrected to 54/58 plans, 93%, and Plan 05 as the next action.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Ready for 07-05 to remove SearchFeature and DownloadsFeature blur drilling.
- Search, Downloads, Setting, and Detail transitional `blurRadius: 0` inputs remain intentionally scheduled for 07-05 through 07-07.

## Self-Check: PASSED

- All nine modified source files and this summary exist.
- Task commits `4f6b3247` and `9bcbe9da` are present in git history.
- Acceptance token counts and the generic-iOS AppFeature build passed.

---
*Phase: 07-root-privacy-mask-auto-lock-removal*
*Completed: 2026-07-14*
