---
phase: 07-root-privacy-mask-auto-lock-removal
plan: 01
subsystem: ui-architecture
tags: [swift, swiftui, sharing, privacy-mask, localization]

requires:
  - phase: 04-combine-to-async-await-and-tca-2
    provides: Migrated AppFeature package graph used by the scene-phase integration
provides:
  - Shared in-memory privacy-mask blur value with a true-zero launch default
  - Zero-argument self-sourcing SwiftUI privacyMask modifier
  - Localized Privacy Mask label and footer in all six supported locales
affects: [07-root-privacy-mask-auto-lock-removal, app-feature, app-components, setting-feature]

tech-stack:
  added: []
  patterns:
    - Read-only SwiftUI modifiers observe cross-module transient state through SharedReader
    - Privacy-mask state uses a typed Sharing in-memory key rather than initializer parameters

key-files:
  created: []
  modified:
    - AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift
    - AppPackage/Sources/AppComponents/ViewModifiers.swift
    - AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings

key-decisions:
  - "The privacy-mask blur is transient in-memory state and starts at a true zero on every launch."
  - "The privacyMask modifier owns a read-only SharedReader so callers need no store scope or blur argument."

patterns-established:
  - "Self-sourcing mask: root surfaces call privacyMask() while the modifier reads privacyMaskBlur internally."
  - "Privacy strings: module-local catalog keys include translated values for every supported locale."

requirements-completed: [UIARCH-04]

coverage:
  - id: D1
    description: "A shared in-memory privacyMaskBlur value is available across modules and defaults to zero."
    requirement: UIARCH-04
    verification:
      - kind: integration
        ref: "xcodebuild build -project ../EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator'"
        status: pass
      - kind: other
        ref: "grep privacyMaskBlur and InMemoryKey<Double>.Default in AppSharedKeys.swift"
        status: pass
    human_judgment: false
  - id: D2
    description: "privacyMask() reads the shared blur and applies a floorless blur with hit-test protection."
    requirement: UIARCH-04
    verification:
      - kind: integration
        ref: "xcodebuild build -project ../EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator'"
        status: pass
      - kind: other
        ref: "grep PrivacyMaskModifier, SharedReader, blur, allowsHitTesting, and zero max-floor occurrences"
        status: pass
    human_judgment: false
  - id: D3
    description: "Privacy Mask label and footer strings exist in all six SettingFeature locales."
    requirement: UIARCH-04
    verification:
      - kind: integration
        ref: "xcodebuild build -project ../EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator'"
        status: pass
      - kind: other
        ref: "jq catalog structure and locale-value validation for privacy_mask and privacy_mask_footer"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-07-14
status: complete
---

# Phase 7 Plan 1: Privacy Mask Foundation Summary

**A true-zero shared blur, a self-sourcing SwiftUI mask modifier, and fully localized settings copy now form the additive privacy-mask foundation.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-13T16:43:39Z
- **Completed:** 2026-07-13T16:51:37Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Added `privacyMaskBlur` as a typed in-memory Sharing key that resets to `0` on launch.
- Added `PrivacyMaskModifier` and zero-argument `.privacyMask()` with a floorless blur, hit-test protection, and the existing linear transition.
- Added `privacy_mask` and `privacy_mask_footer` with translated values for `en`, `de`, `ja`, `ko`, `zh-Hans`, and `zh-Hant`.

## Task Commits

Each task was committed atomically:

1. **Task 1: Declare the privacyMaskBlur shared in-memory key** - `b58fee00` (feat)
2. **Task 2: Add the self-sourcing privacyMask() modifier** - `e5189e7d` (feat)
3. **Task 3: Add the two new SettingFeature l10n keys** - `e166ddc4` (feat)

## Files Created/Modified

- `AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift` - Declares the transient shared privacy-mask blur key.
- `AppPackage/Sources/AppComponents/ViewModifiers.swift` - Defines the state-owning mask modifier and zero-argument view API.
- `AppPackage/Sources/SettingFeature/Resources/Localizable.xcstrings` - Adds the Privacy Mask label and footer in six locales.

## Decisions Made

- Used `@SharedReader(.privacyMaskBlur)` because the modifier observes but never writes the mask value.
- Kept the existing `.autoBlur(radius:)` API alongside the new modifier so downstream call-site migrations can remain buildable and atomic.
- Preserved a true `0` blur with no historical minimum-radius floor, as required by the phase decision.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- The installed Swift-mode `plutil` rejects the catalog's pre-existing JSON format at line 1, including the unmodified catalog from `HEAD`. Equivalent catalog validation used `jq`, explicit per-key/per-locale assertions, and an AppFeature build that compiled the catalog and generated string symbols successfully.
- A sandboxed incremental build temporarily lost CoreSimulator service access. Re-running the same build with the approved Xcode access succeeded.

## Known Stubs

None introduced or exposed by the modified code.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 07-02 can write `privacyMaskBlur` from the scene-phase fold and relocate the persisted intensity control.
- Later mask-site plans can adopt `.privacyMask()` without threading blur values through view initializers.
- No blockers remain.

## Self-Check: PASSED

- All three modified files exist and all three task commits are present in history.
- The final AppFeature simulator build and SwiftLint plugin pass without warnings.
- Shared-key, modifier, no-floor, legacy-coexistence, catalog-locale, and existing-key preservation gates pass.

---
*Phase: 07-root-privacy-mask-auto-lock-removal*
*Completed: 2026-07-14*
