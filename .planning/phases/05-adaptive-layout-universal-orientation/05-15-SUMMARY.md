---
phase: 05-adaptive-layout-universal-orientation
plan: 15
subsystem: ui-architecture
tags: [swift, swiftui, accessibility, toolbar, menu, tca]

requires:
  - phase: 05-adaptive-layout-universal-orientation
    provides: Universal orientation and the shared toolbar action components
provides:
  - Favorites category switching retained as a direct toolbar affordance
  - Secondary Favorites actions grouped under the established features menu
  - Unavailable date seek represented by its existing disabled labeled menu row
affects: [05-adaptive-layout-universal-orientation, favorites-feature]

tech-stack:
  added: []
  patterns:
    - Primary list context remains directly reachable while secondary actions share one overflow menu
    - Existing labeled buttons retain ownership of availability and reducer action dispatch inside menus

key-files:
  created: []
  modified:
    - AppPackage/Sources/FavoritesFeature/FavoritesView.swift

key-decisions:
  - "Favorites category switching remains direct while sort, date seek, and quick search move into ToolbarFeaturesMenu."
  - "DateSeekButton continues to own its nil-navigation disabled state, and Favorites reducer behavior remains unchanged."

patterns-established:
  - "Favorites toolbar hierarchy follows the established list-screen split between a primary direct control and secondary labeled menu actions."

requirements-completed: [UIARCH-01]

coverage:
  - id: D1
    description: "Favorites keeps its category menu directly in the toolbar while sort, date seek, and quick search are grouped under ToolbarFeaturesMenu."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' build"
        status: pass
      - kind: other
        ref: "FavoritesView static hierarchy and action-payload gate; ToolbarItems.swift and FavoritesReducer.swift unchanged"
        status: pass
    human_judgment: true
    rationale: "Toolbar density, menu presentation, and action reachability require the planned interactive UAT."
  - id: D2
    description: "Date seek remains reachable as a localized labeled menu action, opens with available navigation metadata, and is visibly disabled when metadata is unavailable."
    requirement: UIARCH-01
    verification:
      - kind: integration
        ref: "xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' build"
        status: pass
      - kind: other
        ref: "DateSeekButton preserves Label(.RLocalizable.dateSeek, systemSymbol: .calendar), disabled(navigation == nil), and dateSeekButtonTapped(navigation) dispatch"
        status: pass
    human_judgment: true
    rationale: "The enabled and unavailable states need runtime confirmation with and without loaded date-seek metadata."

duration: 2min
completed: 2026-07-13
status: complete
---

# Phase 5 Plan 15: Favorites Toolbar Regrouping Summary

**Favorites now keeps category switching prominent while its secondary actions live in one accessible features menu with an explicit disabled date-seek state.**

## Performance

- **Duration:** 2 min
- **Started:** 2026-07-13T09:27:15Z
- **Completed:** 2026-07-13T09:28:31Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Kept `FavoritesIndexMenu` as the direct category-switching control and moved sort, date seek, and quick search into `ToolbarFeaturesMenu`.
- Preserved every existing TCA action and payload, including conditional category/sort sends and the navigation value passed to date seek.
- Let the menu render Quick Search with its localized text and retained `DateSeekButton`'s existing localized label and nil-navigation disabled state.

## Task Commits

Each task was committed atomically:

1. **Task 1: Regroup Favorites toolbar actions and expose date-seek availability** - `a4f06cfb` (fix)

## Files Created/Modified

- `AppPackage/Sources/FavoritesFeature/FavoritesView.swift` - Keeps the primary category menu direct and nests the three secondary actions under the shared features menu.

## Decisions Made

- Followed the established list-toolbar hierarchy: context switching stays immediately visible, while secondary commands share an overflow menu.
- Removed Quick Search's icon-only toolbar presentation inside the menu so its existing localized label is visible without adding strings or custom accessibility wrappers.
- Reused `DateSeekButton` unchanged so one component remains responsible for its localized label, action payload, and disabled state.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## Accessibility Review

- Native `Menu`, `Button`, and `Label` semantics preserve keyboard, VoiceOver, Voice Control, and Switch Control reachability for each nested action.
- Quick Search presents its localized text in the menu instead of retaining the compact icon-only toolbar label.
- Date Seek remains present with its localized text when unavailable and communicates the disabled state through the native button trait.
- Runtime UAT should confirm focus order, date-seek enabled behavior after metadata loads, and the disabled row before metadata is available.

## Tests

- No unit test was added because this change only restructures SwiftUI toolbar presentation while preserving reducer actions. The exact package build, SwiftLint build-tool plugin, static hierarchy checks, and unchanged reducer/component gates cover automated verification; interactive menu behavior remains routed to UAT.

## Known Stubs

None introduced or exposed by the modified code.

## Threat Review

No security-relevant surface was introduced. The change only regroups existing local toolbar controls and preserves their existing reducer actions.

## User Setup Required

None - no external service configuration is required.

## Next Phase Readiness

- G-05-1 defect 6 is closed in source and ready for the locked Favorites toolbar and date-seek availability UAT.
- Plan 05-16 can proceed with the next adaptive-layout gap closure.

## Self-Check: PASSED

- `AppPackage/Sources/FavoritesFeature/FavoritesView.swift` exists, and task commit `a4f06cfb` is present.
- The required iPhone Air simulator package build succeeded with SwiftLint build-tool plugin execution.
- Static gates confirm the direct Favorites index control, nested secondary actions, exact action payloads, Date Seek's localized disabled-state implementation, and no changes to `ToolbarItems.swift` or `FavoritesReducer.swift`.

---
*Phase: 05-adaptive-layout-universal-orientation*
*Completed: 2026-07-13*
