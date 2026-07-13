---
phase: 07-root-privacy-mask-auto-lock-removal
plan: 02
subsystem: ui-architecture
tags: [swift, swiftui, tca, sharing, privacy-mask, accessibility]

requires:
  - phase: 07-root-privacy-mask-auto-lock-removal
    provides: Shared privacyMaskBlur key, self-sourcing modifier, and localized Privacy Mask copy from Plan 01
provides:
  - Persisted privacyMaskIntensity preference with no auto-lock coupling
  - Scene-phase privacy-mask writes with explicit cold-launch clipboard ownership
  - Privacy Mask control in Appearance settings and no General security section
affects: [07-root-privacy-mask-auto-lock-removal, app-feature, app-models, setting-feature]

tech-stack:
  added: []
  patterns:
    - Reducer state owns writable Shared values and mutates them through withLock
    - Cold-launch and later-foreground effects have distinct documented owners
    - Native sliders carry localized accessibility labels while decorative icons stay hidden

key-files:
  created:
    - AppPackage/Tests/AppModelsTests/SettingPrivacyMaskTests.swift
  modified:
    - AppPackage/Sources/AppModels/Persistent/Setting.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
    - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift
    - AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingReducer.swift
    - AppPackage/Sources/SettingFeature/AppearanceSetting/AppearanceSettingView.swift

key-decisions:
  - "loadUserSettingsDone is the single cold-launch clipboard-detection owner; the active scene branch handles later foreground entries."
  - "The privacy-mask intensity remains a version-1 persisted Setting field with a default of 10 and no migration."
  - "The Privacy Mask slider has its own localized accessibility label, and its eye icons are decorative."

patterns-established:
  - "Scene mask: inactive copies privacyMaskIntensity into privacyMaskBlur; active clears privacyMaskBlur before foreground effects."
  - "Launch split: settings load owns cold-launch clipboard detection while scene active owns subsequent foreground detection."

requirements-completed: [UIARCH-04, UIARCH-05]

coverage:
  - id: D1
    description: "Setting exposes an independently zeroable privacyMaskIntensity defaulting to 10, with AutoLockPolicy removed and schema version 1 retained."
    requirement: UIARCH-05
    verification:
      - kind: unit
        ref: "AppPackage/Tests/AppModelsTests/SettingPrivacyMaskTests.swift"
        status: pass
      - kind: other
        ref: "Setting model acceptance grep for removed names and unchanged SchemaV1"
        status: pass
    human_judgment: false
  - id: D2
    description: "AppReducer writes the shared mask on inactive and active while retaining foreground logging, download reconciliation, and launch automation."
    requirement: UIARCH-04
    verification:
      - kind: integration
        ref: "xcodebuild -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator' build"
        status: pass
      - kind: integration
        ref: "FeatureTests only-testing:DownloadsFeatureTests"
        status: pass
      - kind: other
        ref: "AppReducer acceptance grep for shared writes and removed AppLock transitions"
        status: pass
    human_judgment: false
  - id: D3
    description: "Cold launch has one documented clipboard-detection owner while later active transitions retain greeting and conditional clipboard effects."
    requirement: UIARCH-04
    verification:
      - kind: other
        ref: "AppReducer cold-launch owner comment and effect-branch structural assertions"
        status: pass
    human_judgment: true
    rationale: "The dedicated exactly-once TestStore coverage is intentionally scheduled for Plan 07-08."
  - id: D4
    description: "General settings no longer show security controls, and Appearance presents the labeled Privacy Mask slider and footer below tint color."
    requirement: UIARCH-05
    verification:
      - kind: integration
        ref: "xcodebuild -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator' build"
        status: pass
      - kind: other
        ref: "Settings view and reducer acceptance greps"
        status: pass
    human_judgment: true
    rationale: "Visual placement and VoiceOver reading order are confirmed during the phase's end-of-phase UI verification."

duration: 13min
completed: 2026-07-14
status: complete
---

# Phase 7 Plan 2: Privacy Mask Behavioral Core Summary

**The persisted mask intensity now drives scene-phase privacy blur directly, while custom auto-lock settings are gone and the accessible control lives under Appearance.**

## Performance

- **Duration:** 13 min
- **Started:** 2026-07-13T17:00:09Z
- **Completed:** 2026-07-13T17:12:49Z
- **Tasks:** 3
- **Files modified:** 7

## Accomplishments

- Replaced the coupled background-blur and auto-lock model fields with a plain `privacyMaskIntensity` value, preserving the version-1 schema and default intensity of `10`.
- Made `AppReducer.onScenePhaseChange` write the shared mask before background snapshots and clear it on active, with launch greeting and clipboard behavior re-homed explicitly.
- Removed General's security section and biometric passcode dependency, then added an accessible Privacy Mask slider and footer directly below Appearance's tint controls.
- Replaced obsolete auto-lock coupling tests with focused Swift Testing coverage for the new model behavior.

## Task Commits

Each task was committed atomically:

1. **Task 1 RED: Define privacy-mask Setting behavior** - `709ba4ec` (test)
2. **Task 1 GREEN: Replace auto-lock settings with privacy intensity** - `c65beeea` (feat)
3. **Task 2: Fold mask writes and launch effects into scene phase** - `cff5af89` (feat)
4. **Task 3: Remove General security UI and add Appearance mask control** - `fa2442d1` (feat)

## Files Created/Modified

- `AppPackage/Tests/AppModelsTests/SettingPrivacyMaskTests.swift` - Covers the mask default and independent zero value.
- `AppPackage/Tests/AppModelsTests/SettingAutoLockClampTests.swift` - Deleted obsolete coupling tests.
- `AppPackage/Sources/AppModels/Persistent/Setting.swift` - Renames the persisted preference and removes auto-lock policy and coupling.
- `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift` - Owns the writable shared blur and scene-phase updates.
- `AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingView.swift` - Removes the complete security section and passcode check trigger.
- `AppPackage/Sources/SettingFeature/GeneralSetting/GeneralSettingReducer.swift` - Removes AuthorizationClient and passcode state/action handling.
- `AppPackage/Sources/SettingFeature/AppearanceSetting/AppearanceSettingView.swift` - Adds the Privacy Mask slider, footer, and accessibility treatment.

## Decisions Made

- Cold-launch clipboard detection remains in `loadUserSettingsDone`; the pre-load active transition is intentionally ignored, and later active transitions own foreground detection.
- `privacyMaskIntensity` stays in schema v1 with no migration because the app remains pre-release and the default-on reset is accepted.
- Eye and eye-slash symbols communicate the slider range visually but are hidden from VoiceOver; the native slider announces the localized Privacy Mask label.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Replaced obsolete auto-lock tests with privacy-mask model coverage**
- **Found during:** Task 1 (Setting model rename and auto-lock removal)
- **Issue:** The TDD task listed only the production model file, while the existing tests pinned the coupling being removed and would fail to compile after the change.
- **Fix:** Replaced the obsolete suite with failing-first tests for the new default and independently zeroable intensity.
- **Files modified:** `AppPackage/Tests/AppModelsTests/SettingAutoLockClampTests.swift`, `AppPackage/Tests/AppModelsTests/SettingPrivacyMaskTests.swift`
- **Verification:** The RED build failed specifically because `privacyMaskIntensity` did not exist; the targeted AppModelsTests run passed after the plan restored the intentionally broken cross-task graph.
- **Committed in:** `709ba4ec`

---

**Total deviations:** 1 auto-fixed (1 missing critical).
**Impact on plan:** The added test update was required by the task's TDD contract and by deletion of the old model surface; no product scope changed.

## TDD Gate Compliance

- RED: `709ba4ec` introduced tests that failed on the missing `privacyMaskIntensity` member.
- GREEN: `c65beeea` implemented the new model API after the RED commit.
- The AppModels target built immediately after GREEN. The targeted tests ran green after Tasks 2 and 3 repaired the downstream references that the plan explicitly expected to remain broken between tasks.

## Issues Encountered

- The plan's iPhone Air simulator destination at iOS 26.2 was not installed. Verification used the available iOS 26.5 iPhone Air runtime.
- The EhPanda test scheme compiles the wider feature graph even with `only-testing:AppModelsTests`; the targeted GREEN run therefore waited until the planned AppReducer and settings-reference repairs were complete.

## Known Stubs

None introduced or exposed by the modified code.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 07-03 can remove the now-dormant AppLockReducer, AuthorizationClient module, app-root lock UI, and biometric metadata.
- Plans 07-04 through 07-07 can migrate root surfaces to the live shared mask without any persisted auto-lock dependency.
- Plan 07-08 remains responsible for the dedicated scene-phase exactly-once TestStore coverage and end-of-phase visual leak audit.

## Self-Check: PASSED

- All created and modified production/test files exist, and all four task commits are present in history.
- The AppFeature simulator build, AppModelsTests, DownloadsFeatureTests, SwiftLint build plugins, and every task acceptance assertion pass.
- Coverage metadata validates with no schema errors, and this generated summary contains no absolute home-directory paths.

---
*Phase: 07-root-privacy-mask-auto-lock-removal*
*Completed: 2026-07-14*
