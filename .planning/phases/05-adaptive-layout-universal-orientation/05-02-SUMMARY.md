---
phase: 05-adaptive-layout-universal-orientation
plan: 02
subsystem: ui-architecture
tags: [swift, swiftui, tca, orientation, swift-package-manager]

requires:
  - phase: 05-adaptive-layout-universal-orientation
    provides: Device identity foundation and the Swift 6 package baseline from Plan 05-01
provides:
  - OS-governed orientation with no application-level orientation mask
  - Reading preferences without the obsolete landscape toggle or portrait-forcing flow
  - AppDelegateClient target and dependency graph removal
affects: [05-adaptive-layout-universal-orientation, reading, app-delegate, package-graph]

tech-stack:
  added: []
  patterns:
    - Supported orientations are declared by Info.plist and governed by the OS
    - Removed dependencies are pruned from production and test fixtures together

key-files:
  created:
    - .planning/phases/05-adaptive-layout-universal-orientation/deferred-items.md
  modified:
    - AppPackage/Sources/AppModels/Persistent/Setting.swift
    - AppPackage/Sources/ReadingFeature/ReadingReducer.swift
    - AppPackage/Sources/ReadingFeature/ReadingReducer+Body.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Sources/ReadingSettingFeature/ReadingSettingView.swift
    - AppPackage/Sources/ReadingSettingFeature/Resources/Localizable.xcstrings
    - AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift
    - AppPackage/Sources/DownloadClient/BackgroundTaskClient.swift
    - AppPackage/Package.swift

key-decisions:
  - "Removed obsolete AppDelegateClient overrides from test fixtures instead of retaining a test-only dependency target."

patterns-established:
  - "Orientation governance: AppDelegate does not override supportedInterfaceOrientationsFor; Info.plist and iOS own rotation."
  - "Module teardown: remove source, lint configuration, package edges, imports, and dependency overrides as one atomic change."

requirements-completed: [UIARCH-03]

coverage:
  - id: D1
    description: "The app no longer overrides supported orientations, so iOS uses the four orientations already declared in Info.plist."
    requirement: UIARCH-03
    verification:
      - kind: integration
        ref: "xcodebuild clean build -quiet -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: other
        ref: "grep -rn 'AppOrientationMask|AppDelegateClient' AppPackage/Sources"
        status: pass
    human_judgment: true
    rationale: "Actual rotation across app surfaces requires the phase-end simulator or device UAT."
  - id: D2
    description: "The enablesLandscape preference, localized toggle, and setOrientationPortrait action flow are fully removed."
    requirement: UIARCH-03
    verification:
      - kind: other
        ref: "grep -rn 'enablesLandscape|setOrientationPortrait' AppPackage/Sources"
        status: pass
    human_judgment: false
  - id: D3
    description: "AppDelegateClient is absent from the package graph and affected DownloadsFeature tests compile and pass without overrides."
    requirement: UIARCH-03
    verification:
      - kind: integration
        ref: "xcodebuild test -quiet -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:DownloadsFeatureTests"
        status: pass
      - kind: other
        ref: "grep -n 'appDelegateClient|AppDelegateClient' AppPackage/Package.swift"
        status: pass
    human_judgment: false

duration: 9min
completed: 2026-07-13
status: complete
---

# Phase 5 Plan 2: Universal Orientation Governance Summary

**The custom orientation client, mask, reader preference, and portrait-forcing effects are gone, leaving rotation to iOS and the existing four-orientation Info.plist declaration.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-07-13T04:35:12Z
- **Completed:** 2026-07-13T04:44:08Z
- **Tasks:** 2
- **Files modified:** 18

## Accomplishments

- Removed the persisted `enablesLandscape` field in place at schema v1, its six-locale catalog entry, its native toggle, and every reader action/effect that forced orientation.
- Deleted the entire `AppDelegateClient` module and `AppOrientationMask`, including target declarations, production edges, test edges, and obsolete dependency overrides.
- Removed the app-delegate orientation callback while proving `App/Info.plist` remained unchanged, so UIKit falls back to the app's existing universal orientation declaration.

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove the reading-side orientation flow and the enablesLandscape setting** - `7e8f3926` (refactor)
2. **Task 2: Delete AppOrientationMask, the AppDelegate override, and the AppDelegateClient module** - `a91a1200` (refactor)

## Files Created/Modified

- `AppPackage/Sources/AppModels/Persistent/Setting.swift` - Removes the decode-safe stale landscape preference from the v1 model.
- `AppPackage/Sources/ReadingFeature/ReadingReducer.swift` and `ReadingReducer+Body.swift` - Remove the orientation action, dependency, and effects.
- `AppPackage/Sources/ReadingFeature/ReadingView.swift` - Removes the setting-driven orientation change trigger.
- `AppPackage/Sources/ReadingSettingFeature/ReadingSettingView.swift` and `Resources/Localizable.xcstrings` - Remove the toggle and all localized values.
- `AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift` - Removes the supported-orientations override.
- `AppPackage/Sources/AppDelegateClient/` - Deletes the module source files and inherited SwiftLint configuration.
- `AppPackage/Package.swift` - Removes the module case, target, and all production/test dependency edges.
- `AppPackage/Tests/DownloadsFeatureTests/` - Removes six obsolete imports and no-op dependency overrides.
- `AppPackage/Sources/DownloadClient/BackgroundTaskClient.swift` - Describes its dependency shape without referencing the deleted client.
- `.planning/phases/05-adaptive-layout-universal-orientation/deferred-items.md` - Records a pre-existing out-of-scope test warning.

## Decisions Made

- Removed obsolete test dependency overrides along with the module. Retaining a test-only compatibility target would preserve dead architecture and violate the complete-module teardown.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Removed live AppDelegateClient references from DownloadsFeature tests**

- **Found during:** Task 2 reference inventory
- **Issue:** The plan stated that the DownloadsFeature test target had no import, but six test files still imported `AppDelegateClient` and injected `.noop`; deleting the module as planned would make them fail to compile.
- **Fix:** Removed all obsolete imports and dependency overrides, then removed the test target's package edge.
- **Files modified:** Six files under `AppPackage/Tests/DownloadsFeatureTests/` and `AppPackage/Package.swift`.
- **Verification:** `DownloadsFeatureTests` passes without the deleted dependency.
- **Committed in:** `a91a1200`

**2. [Rule 3 - Blocking] Removed the module-local SwiftLint configuration**

- **Found during:** Task 2 complete-module deletion check
- **Issue:** Deleting only the two Swift sources left `AppDelegateClient/.swiftlint.yml`, so the supposedly deleted module directory still contained a tracked artifact.
- **Fix:** Deleted the module-local configuration with the rest of the target.
- **Files modified:** `AppPackage/Sources/AppDelegateClient/.swiftlint.yml`
- **Verification:** No tracked path remains under `AppPackage/Sources/AppDelegateClient/`.
- **Committed in:** `a91a1200`

---

**Total deviations:** 2 auto-fixed blocking issues.
**Impact on plan:** Both fixes were required to make the planned module deletion complete and compilable; no product scope was added.

## Issues Encountered

- The affected test run passes but reports a pre-existing strict-concurrency warning because `TestingSupport.HTMLFilename` is not `Sendable` when carried by `TestError`. It is unrelated to these changes and is recorded in `deferred-items.md` rather than suppressed or changed out of scope.

## Known Stubs

- `AppPackage/Sources/DownloadClient/BackgroundTaskClient.swift:55` — The generic `placeholder()` trap remains intentional `IssueReporting.unimplemented` test plumbing and never feeds production UI or data.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The app-level orientation lock is gone, so later Phase 5 adaptive-layout and reader-geometry plans can respond to rotation without snap-back.
- Phase-end UAT still needs to rotate representative app and reader surfaces on a simulator or device, as already required by the phase validation plan.
- No implementation blocker remains for Plan 05-03.

## Self-Check: PASSED

- Both task commits exist and all intended module files are deleted.
- The clean package build and affected DownloadsFeatureTests pass.
- All removal grep gates pass, the string catalog parses as JSON, and `App/Info.plist` retains its pre-plan hash.

---
*Phase: 05-adaptive-layout-universal-orientation*
*Completed: 2026-07-13*
