---
phase: 05-adaptive-layout-universal-orientation
plan: 17
subsystem: ui-architecture
tags: [swift, swiftui, ipad, semantic-colors, scene-manifest]

requires:
  - phase: 05-adaptive-layout-universal-orientation
    provides: Universal orientation and window-aware reader chrome
provides:
  - Explicit semantic Home content surface with normal-window parity
  - Single-scene app declaration matching the shared-store architecture
affects: [05-adaptive-layout-universal-orientation, home-feature, app-shell]

tech-stack:
  added: []
  patterns:
    - Semantic system backgrounds override presentation backdrops without changing normal-window appearance
    - Scene capabilities stay aligned with the app's actual state-ownership model

key-files:
  created: []
  modified:
    - AppPackage/Sources/HomeFeature/HomeView.swift
    - App/Info.plist

key-decisions:
  - "Home's content root uses systemBackground so systemGray6 cards remain distinct while light, dark, and increased-contrast appearances stay adaptive."
  - "Multiple-scene support is disabled because every WindowGroup currently receives the single AppDelegate-owned store."

patterns-established:
  - "Presentation-specific window backdrops do not leak into Home's visual hierarchy; Home declares its own semantic content surface."

requirements-completed: [UIARCH-03]

coverage:
  - id: D1
    description: "Home owns a semantic content-root surface that separates its systemGray6 Other cards from grouped or sheet-style iPad window backdrops."
    requirement: UIARCH-03
    verification:
      - kind: integration
        ref: "xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' build"
        status: pass
      - kind: other
        ref: "Static source gate confirms Color(.systemBackground) on Home's ZStack content root and no change to MiscGridItem or localized catalogs"
        status: pass
    human_judgment: true
    rationale: "Normal-window visual parity and Other-card boundary contrast in a freeform iPad window require runtime inspection."
  - id: D2
    description: "The app no longer advertises multiple-scene support while using one AppDelegate-owned store."
    requirement: UIARCH-03
    verification:
      - kind: integration
        ref: "xcodebuild -workspace AppPackage/.swiftpm/xcode/package.xcworkspace -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' build"
        status: pass
      - kind: other
        ref: "plutil validates App/Info.plist; PlistBuddy prints false; the plist diff contains only the true-to-false scene capability change"
        status: pass
    human_judgment: true
    rationale: "The absence of drag-to-side and new-window affordances requires iPad runtime confirmation."

duration: 3min
completed: 2026-07-13
status: complete
---

# Phase 5 Plan 17: Home Surface and Scene Capability Summary

**Home now keeps its cards distinct from iPad window backdrops, and the app declaration matches its single shared-store scene architecture.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-07-13T09:42:30Z
- **Completed:** 2026-07-13T09:45:25Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Applied `Color(.systemBackground)` to Home's content root, preserving the default normal-window appearance while preventing grouped or sheet-style backdrops from matching its `systemGray6` Other cards.
- Left `MiscGridItem`, the carousel, cover wall, toplists, other feature surfaces, and localized resources unchanged.
- Set `UIApplicationSupportsMultipleScenes` to false so the app no longer advertises independent windows while all roots share the one AppDelegate-owned store.

## Task Commits

Each task was committed atomically:

1. **Task 1: Establish a distinct Home content-root surface** - `c252e09a` (fix)
2. **Task 2: Disable unsupported multiple-scene support** - `4216c9e9` (fix)

## Files Created/Modified

- `AppPackage/Sources/HomeFeature/HomeView.swift` - Gives the Home content ZStack an explicit adaptive system background.
- `App/Info.plist` - Disables the unsupported multiple-scene capability and changes no other key.

## Decisions Made

- Used the preferred semantic background fix instead of adding material to each card: it exactly matches the ordinary content surface while overriding presentation-specific inherited backdrops.
- Kept scene state architecture unchanged and narrowed the advertised capability to what the existing single-store ownership model supports.

## Deviations from Plan

None - plan executed exactly as written. The preferred Home root background was sufficient, so `HomeView+Sections.swift` did not require modification.

## Issues Encountered

- The first build attempt could not reach simulator services inside the restricted filesystem sandbox and misreported the generated package workspace. Re-running the same required command with Xcode simulator/cache access succeeded; this was an environment limitation, not a source issue.

## Accessibility Review

- `systemBackground` and `systemGray6` remain semantic, adaptive colors across light and dark appearances; no hard-coded color or contrast assumption was introduced.
- No controls, labels, focus order, activation behavior, motion, or Dynamic Type layout changed.
- Runtime UAT should include light, dark, and Increase Contrast appearances when confirming Other-card boundaries.

## Performance Review

- The static background modifier introduces no observed state, geometry measurement, layout feedback loop, or additional content computation.
- Home's existing observation and scrolling hierarchy remain unchanged.

## Tests

- No unit test was added because the changes are a SwiftUI surface modifier and a plist capability declaration. The exact package build with SwiftLint, static source gate, plist validation, PlistBuddy assertion, and single-line plist diff provide the appropriate automated coverage; visual and system window affordances remain UAT gates.

## Human Check

- Pending UAT: confirm Home looks unchanged in normal iPhone and iPad windows and Other-card boundaries remain visible in a freeform iPad window.
- Pending UAT: confirm iPad no longer presents drag-to-side or new-window affordances for the app.

## Known Stubs

None introduced or exposed by the modified code.

## Threat Review

No new trust boundary or input, network, authentication, or persistence surface was introduced. Disabling multiple scenes removes the previously advertised unsupported path where multiple windows would share navigation, lock, and feature state.

## User Setup Required

None - no external service configuration is required.

## Next Phase Readiness

- G-05-4 defects 8 and 9 are closed in source and ready for the locked iPad visual and window-capability UAT.
- Plan 05-18 can proceed with the final Phase 5 gap closure.

## Self-Check: PASSED

- `AppPackage/Sources/HomeFeature/HomeView.swift` and `App/Info.plist` exist; task commits `c252e09a` and `4216c9e9` are present.
- The required iPhone Air simulator package build succeeded for both tasks with SwiftLint build-tool plugin execution.
- Static and plist gates confirm the semantic Home root surface, a false multiple-scene capability, an otherwise unchanged plist, and no changes to localized resources or non-Home surfaces.

---
*Phase: 05-adaptive-layout-universal-orientation*
*Completed: 2026-07-13*
