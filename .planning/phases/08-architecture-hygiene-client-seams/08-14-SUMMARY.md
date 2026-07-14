---
phase: 08-architecture-hygiene-client-seams
plan: 14
subsystem: architecture
tags: [swift, app-metadata, architecture-hygiene, swiftlint]
requires:
  - phase: 08-architecture-hygiene-client-seams
    provides: Explicit gallery-host flow and folded client seams from plans 08-01 through 08-13
provides:
  - Pure AppInfo namespace for app version, build, and test-environment facts
  - Complete removal of AppUtil and its dead dispatchMainSync helper
  - Removal of the orphaned AuthorizationClient source directory
  - Passing full-package tests, SwiftLint build-tool checks, and cookie-logging gate
affects: [app-models, app-feature, settings, package-structure]
tech-stack:
  added: []
  patterns:
    - Uninhabited enum namespaces for pure app metadata facts
    - Direct deletion of obsolete global helpers instead of replacement wrappers
key-files:
  created:
    - AppPackage/Sources/AppModels/Utilities/AppInfo.swift
  modified:
    - AppPackage/Sources/AppModels/Utilities/AppUtil.swift
    - AppPackage/Sources/SettingFeature/Components/AboutView.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
key-decisions:
  - "Keep the Bundle keys, null fallbacks, and XCTestConfigurationFilePath environment check unchanged while relocating them to AppInfo."
  - "Represent AppInfo as an uninhabited enum because it is a pure namespace with no instance semantics."
patterns-established:
  - "Pure metadata namespace: app facts that require no substitution live in AppInfo rather than an injected client or side-effecting Util wrapper."
requirements-completed: [HYG-01]
coverage:
  - id: D1
    description: "AppUtil and dispatchMainSync are eliminated while AboutView and AppDelegate preserve their version, build, and test-detection behavior through AppInfo."
    requirement: HYG-01
    verification:
      - kind: other
        ref: "AppUtil and dispatchMainSync source-absence checks plus AppInfo consumer inventory"
        status: pass
      - kind: integration
        ref: "xcodebuild -quiet build -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
    human_judgment: false
  - id: D2
    description: "The orphaned AuthorizationClient directory and package references are absent, and the complete phase gate is green."
    requirement: HYG-01
    verification:
      - kind: other
        ref: "AuthorizationClient directory and Package.swift reference absence checks"
        status: pass
      - kind: integration
        ref: "xcodebuild -quiet test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: other
        ref: "Scripts/check-cookie-logging.sh"
        status: pass
    human_judgment: false
duration: 4 min
completed: 2026-07-14
status: complete
---

# Phase 8 Plan 14: Final App Utility Hygiene Summary

App metadata now lives in a pure `AppInfo` namespace, the dead main-queue helper and `AppUtil` type are gone, and the full architecture-hygiene phase gate passes.

## Performance

- **Duration:** 4 min
- **Started:** 2026-07-14T10:45:36Z
- **Completed:** 2026-07-14T10:48:58Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Relocated the existing app version, build number, and XCTest-environment detection into a small pure `AppInfo` namespace without changing keys, fallback values, or evaluation behavior.
- Updated AboutView and AppDelegate to use `AppInfo`, then eliminated `AppUtil` and its zero-caller `dispatchMainSync` implementation.
- Removed the empty orphaned AuthorizationClient directory and passed the complete package test suite, SwiftLint build-tool checks, and cookie-logging audit.

## Task Commits

1. **Task 1: Relocate version/build/isTesting to AppInfo and delete AppUtil** - `dba86040`
2. **Task 2: Remove the stale empty AuthorizationClient directory and run the phase gate** - no source commit (Git does not track the empty directory; verification is captured in plan metadata)

**Plan metadata:** committed with this summary

## Files Created/Modified

- `AppPackage/Sources/AppModels/Utilities/AppInfo.swift` - exposes the unchanged version, build, and test-environment facts through an uninhabited pure namespace.
- `AppPackage/Sources/AppModels/Utilities/AppUtil.swift` - removed with the dead `dispatchMainSync` helper.
- `AppPackage/Sources/SettingFeature/Components/AboutView.swift` - reads version and build metadata from `AppInfo`.
- `AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift` - preserves test-launch suppression through `AppInfo.isTesting`.
- `AppPackage/Sources/AuthorizationClient/` - removed after confirming it was empty and had no package reference.

## Decisions Made

- Used an uninhabited public enum for `AppInfo`, preventing meaningless instances while retaining the established static namespace shape.
- Moved the metadata implementations verbatim apart from the type name: the same Bundle keys, `"null"` fallbacks, debug compilation branch, and XCTest environment key remain load-bearing.
- Did not add a client wrapper because these read-only app facts need no substitution and the project forbids thin renaming wrappers.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Reconciled stale phase metadata after the final utility deletion**
- **Found during:** Plan metadata update
- **Issue:** The GSD state updater correctly moved the phase to verification but rewrote the frontmatter percentage from phase count and left the human-readable position, next action, progress, and completed-plan count stale. ROADMAP and REQUIREMENTS also still named AppUtil instead of FileUtil in D-06's retained pure namespaces.
- **Fix:** Reconciled STATE to 76 of 76 plans and the verification handoff, and corrected the D-06/D-07 wording while preserving the roadmap's In Progress status until phase verification completes.
- **Files modified:** `.planning/STATE.md`, `.planning/ROADMAP.md`, `.planning/REQUIREMENTS.md`
- **Verification:** State frontmatter and prose agree with all 76 summaries; roadmap and requirement wording now agrees with D-06, D-07, and the source tree.
- **Committed in:** Plan metadata commit

---

**Total deviations:** 1 auto-fixed bug.
**Impact on plan:** The fix records the already-implemented architecture accurately and does not change runtime behavior or phase-verification status.

## Issues Encountered

- The plan's repository-root command selected the app project, which does not expose the `AppPackage-Package` scheme, and the named iPhone 16 simulator is not installed. As in the preceding phase plans, verification ran from `AppPackage` on the installed iPhone Air simulator with iOS 26.5; both the build and full test suite passed.
- The AuthorizationClient directory was an untracked empty directory. Removing it changed the workspace as required but produced no Git delta because Git does not model empty directories.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- HYG-01 is fully delivered: the side-effecting utility and singleton seams targeted by Phase 8 are eliminated, while the retained URL, file, and markdown helpers remain pure deterministic namespaces.
- Phase 8 is ready for final verification and transition to the next roadmap phase.

---
*Phase: 08-architecture-hygiene-client-seams*
*Completed: 2026-07-14*

## Self-Check: PASSED

- Task commit `dba86040` exists in git history and the four semantic source paths match its relocation and consumer updates.
- `AppInfo.swift` exists; `AppUtil.swift`, `dispatchMainSync`, and every AppPackage `AppUtil` reference are absent.
- `AppPackage/Sources/AuthorizationClient/` and every AuthorizationClient package reference are absent.
- The warning-free package build, complete package tests, SwiftLint build-tool checks, cookie-logging gate, diff check, architecture review, security review, and SwiftUI/TCA parity review pass.
