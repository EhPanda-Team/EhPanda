---
phase: 10-ui-polish
plan: 01
subsystem: ui
tags: [swift-package, module-rename, swiftlint, toast, tca]

# Dependency graph
requires:
  - phase: 06-genericlist-decomposition
    provides: parity-rename analog process (GenericList -> GalleryList)
provides:
  - Module renamed SystemNotificationExt -> SystemNotification (directory, Package.swift enum case, target dependencies)
  - Test target renamed SystemNotificationExtTests -> SystemNotificationTests (directory + xctestplan entry)
  - All 8 importers, 2 doc comments, and @testable import updated to the new name
affects: [10-ui-polish later plans that touch the same importer files]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Parity module rename: git mv preserves history + single token-swap across every reference, proven by full-suite green"

key-files:
  created: []
  modified:
    - AppPackage/Sources/SystemNotification/ (renamed from SystemNotificationExt/)
    - AppPackage/Tests/SystemNotificationTests/ (renamed from SystemNotificationExtTests/)
    - AppPackage/Package.swift
    - AppPackage/Tests/FeatureTests.xctestplan
    - AppPackage/Sources/AppComponents/AppAlertState.swift
    - 8 importer files (Setting/Reading/TabBar/Detail x4/Downloads)

key-decisions:
  - "None - parity rename executed exactly as planned"

patterns-established:
  - "Prefix-safe token swap: replacing SystemNotificationExt -> SystemNotification also correctly rewrites the *Tests target name in one pass"

requirements-completed: [CRIT-11]

coverage:
  - id: D1
    description: "SystemNotificationExt module renamed to SystemNotification with every reference (Package.swift enum + 8 module refs, 8 imports, xctestplan, doc comments) updated; zero old-name references remain repo-wide"
    requirement: "CRIT-11"
    verification:
      - kind: other
        ref: "grep -rnF 'SystemNotificationExt' AppPackage/Sources AppPackage/Tests App ShareExtension AppPackage/Package.swift | wc -l => 0"
        status: pass
    human_judgment: false
  - id: D2
    description: "Renamed SystemNotificationTests target executes (not just builds) and passes within the full suite; build + SwiftLint clean with no new warnings"
    requirement: "CRIT-11"
    verification:
      - kind: unit
        ref: "xcodebuild test -scheme EhPanda: Suite ToastInteractionTests passed; ** TEST SUCCEEDED **"
        status: pass
      - kind: other
        ref: "swiftlint lint --strict on changed files => exit 0 (zero violations)"
        status: pass
    human_judgment: false

# Metrics
duration: 17min
completed: 2026-07-16
status: complete
---

# Phase 10 Plan 01: Rename SystemNotificationExt Module Summary

**Renamed the toast module `SystemNotificationExt` -> `SystemNotification` (the `Ext` suffix was a misnomer; the module holds the full toast implementation), a zero-behavior-change parity rename proven by the full suite green with the renamed test target executing.**

## Performance

- **Duration:** 17 min
- **Started:** 2026-07-16T23:40:52Z
- **Completed:** 2026-07-16T23:58:11Z
- **Tasks:** 2
- **Files modified:** 16

## Accomplishments
- Module directory + Package.swift enum case (`systemNotification = "SystemNotification"`) and all 8 `.module(...)` target-dependency refs renamed
- Test target directory + xctestplan identifier/name renamed to `SystemNotificationTests`; `@testable import` updated
- All 8 `import SystemNotificationExt` statements and 2 AppAlertState doc comments updated; history preserved via `git mv` (renames shown as R100/R098)
- Full suite green (`** TEST SUCCEEDED **`) with `ToastInteractionTests` suite executing under the new target name; SwiftLint clean, no new compiler warnings

## Task Commits

1. **Task 1: Rename module, test target, and every reference** - `d1a1365b` (refactor)
2. **Task 2: Clean build, SwiftLint, and full suite with renamed target visible** - verification only, no code change (no commit)

**Plan metadata:** docs commit (this SUMMARY + STATE + ROADMAP + REQUIREMENTS)

## Files Created/Modified
- `AppPackage/Sources/SystemNotification/` - renamed module (ToastMessageView.swift, View+Toast.swift, .swiftlint.yml carried byte-identical)
- `AppPackage/Tests/SystemNotificationTests/` - renamed test target (ToastInteractionTests.swift, .swiftlint.yml)
- `AppPackage/Package.swift` - sources + tests enum cases and 8 module refs
- `AppPackage/Tests/FeatureTests.xctestplan` - target identifier + name
- `AppPackage/Sources/AppComponents/AppAlertState.swift` - 2 doc comments
- 8 importer files - `import` statement updated: AccountSettingView, ReadingView, TabBarView, TorrentsView, CommentsView, GalleryInfosView, ArchivesView, DownloadsView+Subviews

## Decisions Made
None - followed plan as specified. A single prefix-safe token swap (`SystemNotificationExt` -> `SystemNotification`) rewrote both the module and the `*Tests` target name correctly, since the test name is a prefix extension of the module name.

## Deviations from Plan
None - plan executed exactly as written.

Two operational notes (no plan deviation, no source change):
- The `sorted_imports` rule referenced in the plan's Task 1 caution is not active in this repo (imports are not alphabetized; SwiftUI leads every block), so in-place token swaps needed no reordering.
- The plan named the `AppPackage-Package` test scheme, which is not present in this checkout's shared schemes. Ran the full suite via the shared `EhPanda` scheme, which references `FeatureTests.xctestplan` (all 15 test targets, including the renamed `SystemNotificationTests`) — the canonical full-suite runner. Also required the explicit simulator device id (`iPhone 17e` sits at OS 26.4.1 while the scheme resolves name+OS:latest to 27.0).

## Issues Encountered
- Initial `xcodebuild` invocations failed on scheme name (`AppPackage-Package` absent) and destination resolution (`name=iPhone 17e` + implicit OS:latest). Resolved by using the `EhPanda` scheme and the explicit device id. Both were environment/invocation issues, not code problems.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Criterion 11 satisfied. Later Phase 10 plans that touch the same importer files now import `SystemNotification`.
- No blockers.

## Self-Check: PASSED

- FOUND: AppPackage/Sources/SystemNotification/View+Toast.swift
- FOUND: AppPackage/Sources/SystemNotification/.swiftlint.yml (contains parent_config: ../../../.swiftlint.yml)
- FOUND: AppPackage/Tests/SystemNotificationTests/ToastInteractionTests.swift (contains @testable import SystemNotification)
- FOUND commit: d1a1365b
- Old-name grep repo-wide: 0 hits

---
*Phase: 10-ui-polish*
*Completed: 2026-07-16*
