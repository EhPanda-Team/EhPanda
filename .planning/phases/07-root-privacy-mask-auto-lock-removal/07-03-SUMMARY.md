---
phase: 07-root-privacy-mask-auto-lock-removal
plan: 03
subsystem: ui-architecture
tags: [swift, swiftui, tca, privacy-mask, package-cleanup, localization]

requires:
  - phase: 07-root-privacy-mask-auto-lock-removal
    provides: Live shared privacy-mask state and the relocated Appearance control from Plans 01-02
provides:
  - Four self-sourcing privacy masks across the app-root surfaces
  - Complete removal of the custom app-lock reducer, lock overlay, and AuthorizationClient module
  - Removal of orphaned Face ID metadata and dead auto-lock localizations
affects: [07-root-privacy-mask-auto-lock-removal, app-feature, app-package, app-metadata]

tech-stack:
  added: []
  patterns:
    - App-root surfaces observe the shared privacy mask directly rather than reducer-owned lock state
    - Removed local modules leave no package target, consumer dependency, metadata, or localization residue

key-files:
  created: []
  modified:
    - AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
    - AppPackage/Package.swift
    - App/Info.plist
    - App/InfoPlist.xcstrings
    - AppPackage/Sources/AppFeature/Resources/Localizable.xcstrings
    - AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings
    - AppPackage/Sources/AppModels/Resources/Localizable.xcstrings

key-decisions: []

patterns-established:
  - "Transitional module inputs receive a literal zero only until their blurRadius parameters are removed in Plans 04-07."
  - "Capability removal includes source, package graph, Info.plist metadata, and localized copy in the same plan."

requirements-completed: [UIARCH-04, UIARCH-05]

coverage:
  - id: D1
    description: "TabBarView applies privacyMask() to all four app-root surfaces and no longer exposes custom lock UI or reducer state."
    requirement: UIARCH-04
    verification:
      - kind: integration
        ref: "xcodebuild -quiet -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator' build"
        status: pass
      - kind: other
        ref: "grep for four privacyMask() calls and zero appLockState, AppLockReducer, lockFill, and ZStack occurrences"
        status: pass
    human_judgment: false
  - id: D2
    description: "AuthorizationClient, its package target and dependencies, and Face ID usage metadata are fully removed."
    requirement: UIARCH-05
    verification:
      - kind: integration
        ref: "xcodebuild -quiet -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator' build"
        status: pass
      - kind: other
        ref: "repo source and metadata absence audit for AuthorizationClient, LocalAuthentication, LAContext, and NSFaceIDUsageDescription"
        status: pass
    human_judgment: false
  - id: D3
    description: "Dead auto-lock, security, blur-radius, and policy strings are gone while shared duration and Privacy Mask strings remain."
    requirement: UIARCH-05
    verification:
      - kind: other
        ref: "jq catalog key, locale, and JSON validation plus Xcode string-catalog compilation"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-07-14
status: complete
---

# Phase 7 Plan 3: App-Root Auto-Lock Teardown Summary

**All app-root surfaces now use the shared privacy mask, while the custom biometric lock module, UI, package wiring, metadata, and localized residue are gone.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-13T17:21:38Z
- **Completed:** 2026-07-13T17:29:39Z
- **Tasks:** 3
- **Files modified:** 11

## Accomplishments

- Replaced all four `TabBarView` root masks with `.privacyMask()`, removed the lock button and its `ZStack`, and deleted every `AppLockReducer` state/action/scope reference.
- Deleted the complete `AuthorizationClient` module and every package-graph reference, with no change to external dependency resolution.
- Removed `NSFaceIDUsageDescription` from the app plist and its six-locale string-catalog entry after confirming no other biometric API use remained.
- Removed all dead auto-lock localizations while preserving shared `seconds`/`minutes` strings and the new Privacy Mask label/footer.

## Task Commits

Each task was committed atomically:

1. **Task 1: Swap app-root masks and remove AppLockReducer wiring** - `96cbd6a8` (refactor)
2. **Task 2: Delete AuthorizationClient, package references, and Face ID metadata** - `12404cde` (chore)
3. **Task 3: Delete dead auto-lock localizations** - `88b619a4` (chore)

## Files Created/Modified

- `AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift` - Uses four shared privacy masks and no custom-lock overlay or state.
- `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift` - Removes the dormant app-lock child domain and scope.
- `AppPackage/Sources/AppFeature/DataFlow/AppLockReducer.swift` - Deleted obsolete custom lock and blur state machine.
- `AppPackage/Sources/AuthorizationClient/` - Deleted the biometric dependency client and module lint configuration.
- `AppPackage/Package.swift` - Removes the module enum case, target, and two consumer dependencies.
- `App/Info.plist` and `App/InfoPlist.xcstrings` - Remove the orphaned Face ID usage description and localized values.
- AppFeature, SettingFeature, and AppModels `Localizable.xcstrings` catalogs - Remove six dead auto-lock/security keys.

## Decisions Made

None - followed the plan's locked teardown and transitional migration sequence.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The installed `plutil` rejects JSON string catalogs at their opening brace, including the unmodified catalogs from the preceding plans. Catalog validity and key preservation were verified with `jq` and by the warning-free Xcode string-catalog compilation instead.

## Known Stubs

None. The remaining `blurRadius: 0` arguments in `TabBarView` are intentional buildable migration seams scheduled for removal in Plans 07-04 through 07-07.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 07-04 can remove the transitional HomeFeature and FavoritesFeature blur parameters while their app-root masks remain active.
- The package graph, plist metadata, catalogs, SwiftLint plugins, and AppFeature build are clean.
- No blockers remain.

## Self-Check: PASSED

- All three atomic task commits are present in git history.
- The AppFeature build, package and source absence audits, plist validation, and string-catalog checks passed.
- This summary contains no absolute home-directory paths or private local-project references.

---
*Phase: 07-root-privacy-mask-auto-lock-removal*
*Completed: 2026-07-14*
