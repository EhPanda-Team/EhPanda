---
phase: 08-architecture-hygiene-client-seams
plan: 13
subsystem: architecture
tags: [swiftui, dependencies, haptics, user-defaults]
requires:
  - phase: 08-architecture-hygiene-client-seams
    provides: Explicit client seams and the single-case AppUserDefaults key inventory from plans 08-01 through 08-12
provides:
  - HapticsClient-owned modern and legacy feedback implementation
  - Injected HapticsClient reads at all four former HapticsUtil view sites
  - Direct UserDefaultsClient reads with AppUserDefaults retained as a pure AppTools key enum
  - Complete removal of HapticsUtil and UserDefaultsUtil
affects: [app-components, detail, settings, app-tools, haptics-client, user-defaults-client]
tech-stack:
  added: []
  patterns:
    - View-owned HapticsClient dependency reads at the interaction source
    - Client-owned platform implementation without redundant static utility wrappers
key-files:
  created:
    - AppPackage/Sources/AppTools/AppUserDefaults.swift
  modified:
    - AppPackage/Package.swift
    - AppPackage/Sources/HapticsClient/HapticsClient.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift
    - AppPackage/Sources/AppComponents/CategoryView.swift
    - AppPackage/Sources/AppComponents/SubSection.swift
    - AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift
    - AppPackage/Sources/UserDefaultsClient/UserDefaultsClient.swift
    - AppPackage/Sources/AppTools/HapticsUtil.swift
    - AppPackage/Sources/AppTools/UserDefaultsUtil.swift
key-decisions:
  - "Preserve the legacy-device sound sequence and modern UIKit feedback calls verbatim inside HapticsClient.live."
  - "Keep AppUserDefaults in AppTools as the shared key type while removing only the redundant UserDefaultsUtil wrapper."
patterns-established:
  - "Injected UI effects: views resolve HapticsClient and invoke it at the same interaction point as the former static call."
  - "Utility folds: clients own impure platform access; AppTools retains only the pure shared key enum."
requirements-completed: [HYG-01]
coverage:
  - id: D1
    description: "HapticsClient owns the folded modern and legacy feedback implementation, and all four former direct utility sites use the injected client."
    requirement: HYG-01
    verification:
      - kind: other
        ref: "four-site hapticsClient.generateFeedback source inventory and HapticsUtil absence check"
        status: pass
      - kind: integration
        ref: "xcodebuild -quiet build -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
    human_judgment: false
  - id: D2
    description: "UserDefaultsClient reads UserDefaults directly, AppUserDefaults remains in AppTools, and UserDefaultsUtil is removed."
    requirement: HYG-01
    verification:
      - kind: other
        ref: "AppUserDefaults location, direct UserDefaults read, and UserDefaultsUtil absence checks"
        status: pass
      - kind: integration
        ref: "xcodebuild -quiet test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
    human_judgment: false
  - id: D3
    description: "The four migrated interactions produce feedback with device-level behavior identical to the former HapticsUtil calls."
    requirement: HYG-01
    verification: []
    human_judgment: true
    rationale: "Source parity and a passing build prove the same implementation and timing are wired, but physical haptic output requires the phase-level owner device check."
duration: 6 min
completed: 2026-07-14
status: complete
---

# Phase 8 Plan 13: Redundant Client Utility Folds Summary

Haptic feedback and typed defaults reads now live directly in their injected clients, with both redundant AppTools utility types deleted and the four UI interactions preserved.

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-14T10:34:15Z
- **Completed:** 2026-07-14T10:39:52Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- Folded the complete legacy-device detection, system-sound fallback, and modern UIKit feedback behavior into `HapticsClient.live` while preserving main-actor isolation.
- Migrated all four direct haptic view sites to `@Dependency(\.hapticsClient)` without changing their triggering interactions, layout, accessibility semantics, or presentation anchors.
- Folded the generic UserDefaults read into `UserDefaultsClient`, relocated the single-case `AppUserDefaults` enum, and deleted both redundant utility wrappers.

## Task Commits

1. **Task 1: Fold HapticsUtil into HapticsClient.live and migrate four view sites** - `b68e11dc`
2. **Task 2: Fold UserDefaultsUtil into UserDefaultsClient and relocate AppUserDefaults** - `0fc2832a`

**Plan metadata:** committed with this summary

## Files Created/Modified

- `AppPackage/Package.swift` - removes HapticsClient's obsolete AppTools edge and gives AppComponents a direct HapticsClient edge.
- `AppPackage/Sources/HapticsClient/HapticsClient.swift` - owns the folded modern and legacy feedback implementation.
- `AppPackage/Sources/SettingFeature/EhSetting/EhSettingView+Sections3.swift` - injects haptic feedback for excluded-language toggles.
- `AppPackage/Sources/AppComponents/CategoryView.swift` - injects haptic feedback for category filter toggles.
- `AppPackage/Sources/AppComponents/SubSection.swift` - injects haptic feedback for reload actions.
- `AppPackage/Sources/DetailFeature/Archives/ArchivesView.swift` - injects haptic feedback for valid archive selection.
- `AppPackage/Sources/UserDefaultsClient/UserDefaultsClient.swift` - reads typed values directly from `UserDefaults.standard`.
- `AppPackage/Sources/AppTools/AppUserDefaults.swift` - retains the pure `clipboardChangeCount` key enum.
- `AppPackage/Sources/AppTools/HapticsUtil.swift` - deleted after its implementation and callers moved to HapticsClient.
- `AppPackage/Sources/AppTools/UserDefaultsUtil.swift` - deleted after its read and key enum moved to their final owners.

## Decisions Made

- Kept the haptic implementation byte-for-byte equivalent in behavior: the same two legacy model identifiers, four fallback sound calls, and UIKit feedback generators now live in `HapticsClient.live`.
- Retained each existing SwiftUI interaction source and timing; only the feedback dependency changed, so no control, gesture, animation, accessibility, alert, or dialog behavior moved.
- Kept `AppUserDefaults` in AppTools because it is the shared key type consumed by UserDefaultsClient and its remaining readers; no thin replacement wrapper was introduced.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated Swift package dependencies for the folded haptics seam**
- **Found during:** Task 1 implementation
- **Issue:** AppComponents needed a direct HapticsClient dependency for its two migrated views, while HapticsClient's former AppTools dependency became obsolete after the fold.
- **Fix:** Added the direct AppComponents-to-HapticsClient edge and removed the HapticsClient-to-AppTools edge in `AppPackage/Package.swift`.
- **Files modified:** `AppPackage/Package.swift`
- **Verification:** The package build and complete package test suite pass.
- **Committed in:** `b68e11dc`

**2. [Rule 1 - Bug] Reconciled stale project-state progress after required GSD updates**
- **Found during:** Plan metadata self-check
- **Issue:** The state updater advanced to plan 14 but later rewrote the frontmatter percentage from phase-local progress and left human-readable next-plan and completed-plan fields stale.
- **Fix:** Reconciled state frontmatter and prose to plan 14, 75 of 76 plans, and 99 percent after all required GSD queries completed.
- **Files modified:** `.planning/STATE.md`
- **Verification:** State frontmatter, current position, next plan, progress bar, and completed-plan count agree with the summaries on disk.
- **Committed in:** Plan state metadata commit

---

**Total deviations:** 2 auto-fixed (1 blocking issue, 1 metadata bug).
**Impact on plan:** The manifest change is the minimal module-boundary update required by the planned dependency inversion, and the metadata repair records the verified result accurately; runtime behavior is unchanged.

## Issues Encountered

- The plan's iPhone 16 simulator destination was unavailable. Verification used the installed iPhone Air simulator on iOS 26.5, matching the preceding phase plans.
- The package scheme is resolved from the `AppPackage` directory; the initial repository-root invocation selected the app project and could not find that scheme. Both required checks then passed from the package directory.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The remaining redundant HapticsUtil and UserDefaultsUtil seams are gone; plan 08-14 can perform the final AppTools residue and phase hygiene checks.
- The physical-device haptic parity check remains explicitly routed to the phase-level manual gate.

---
*Phase: 08-architecture-hygiene-client-seams*
*Completed: 2026-07-14*

## Self-Check: PASSED

- Both task commits are present in git history.
- `HapticsUtil.swift` and `UserDefaultsUtil.swift` are absent, with no AppPackage reference to either deleted type.
- Exactly four migrated view sites resolve HapticsClient, and the folded client contains the complete legacy and modern feedback paths.
- `AppUserDefaults.swift` contains only `clipboardChangeCount`, and UserDefaultsClient performs the direct generic read.
- Warning-free package build, complete package tests, SwiftLint build-tool checks, diff checks, dependency review, security review, and accessibility-parity review pass.
