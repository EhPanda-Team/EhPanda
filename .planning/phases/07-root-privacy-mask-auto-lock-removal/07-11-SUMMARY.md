---
phase: 07-root-privacy-mask-auto-lock-removal
plan: 11
subsystem: app-privacy
tags: [swiftui, accessibility, privacy-mask, presentation-roots, audit]

# Dependency graph
requires:
  - phase: 07-08
    provides: shared privacy-mask modifier and the original coverage audit
provides:
  - Exactly one privacy-mask application for each of the 39 runtime roots
  - A checked-in bijective root-to-mask inventory covering every presentation modifier
  - Reduce-Motion-aware privacy-mask transitions
affects: [UIARCH-04, app-switcher-privacy, accessibility]

# Tech tracking
tech-stack:
  added: []
  patterns: [presentation-root privacy ownership, inventory-derived coverage audits, environment-gated animation]

key-files:
  created:
    - .planning/phases/07-root-privacy-mask-auto-lock-removal/07-PRIVACY-MASK-INVENTORY.md
  modified:
    - AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift
    - AppPackage/Sources/AppComponents/ViewModifiers.swift

key-decisions:
  - "07-11: Download Inspector privacy ownership stays on the presented NavigationStack root, not its nested content view."
  - "07-11: Privacy coverage is derived from 39 explicit runtime-root rows and reconciled against all 41 source presentation modifiers, including three preview-only exclusions."
  - "07-11: Reduce Motion applies privacy blur changes immediately while preserving the true zero blur and hit-testing threshold."

patterns-established:
  - "Every runtime presentation root maps to one unique executable privacy-mask site; count equality is derived from the inventory rather than a magic constant."
  - "Scoped SwiftUI animations use a nil animation when Reduce Motion is enabled."

requirements-completed: [UIARCH-04]

coverage:
  - id: D1
    description: The Download Inspector is masked once at its presented NavigationStack root.
    requirement: UIARCH-04
    verification:
      - kind: static
        ref: "DownloadsView+Subviews.swift mask count 0; DownloadsView.swift mask count 3"
        status: pass
    human_judgment: false
  - id: D2
    description: Every runtime root has one unique mask and every presentation modifier is reconciled.
    requirement: UIARCH-04
    verification:
      - kind: audit
        ref: ".planning/phases/07-root-privacy-mask-auto-lock-removal/07-PRIVACY-MASK-INVENTORY.md#re-runnable-bijective-audit"
        status: pass
    human_judgment: false
  - id: D3
    description: Privacy-mask animation is disabled under Reduce Motion without adding a blur floor or changing hit testing.
    requirement: UIARCH-04
    verification:
      - kind: integration
        ref: "xcodebuild -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/EhPandaPhase0711DerivedData build"
        status: pass
      - kind: static
        ref: "accessibilityReduceMotion count 1; max(0.00001 count 0"
        status: pass
    human_judgment: false

# Metrics
duration: 24min
completed: 2026-07-14
status: complete
---

# Phase 07 Plan 11: Privacy-Mask Root Audit and Reduce Motion Summary

**Every runtime root now owns exactly one privacy mask, and the blur transition respects Reduce Motion without weakening true-zero or hit-testing behavior.**

## Performance

- **Duration:** 24 min
- **Started:** 2026-07-14T00:14:00Z
- **Completed:** 2026-07-14T00:38:26Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Removed the Download Inspector's nested mask while retaining the presented NavigationStack mask that covers the complete modal and navigation chrome.
- Added an explicit 39-root inventory that maps every root to a unique mask site and reconciles all 41 source presentation modifiers with three preview-only exclusions.
- Embedded a re-runnable bijective audit that derives its expected mask total from the root rows and rejects duplicate, missing, stale, or unaccounted sites.
- Gated the scoped blur animation with `accessibilityReduceMotion`; Reduce Motion now applies state changes without animation while the floorless blur and `blur < 1` interaction guard remain unchanged.

## Task Commits

1. **Task 1: Remove the Download Inspector nested duplicate mask** - `02e40f9f` (fix)
2. **Task 2: Author the one-to-one presentation-root inventory and bijective audit** - `fe6ae9e1` (docs)
3. **Task 3: Make PrivacyMaskModifier respect Reduce Motion** - `0789198b` (fix)

## Files Created/Modified

- `.planning/phases/07-root-privacy-mask-auto-lock-removal/07-PRIVACY-MASK-INVENTORY.md` - Enumerates 39 roots, 39 unique mask sites, and all 41 source presentations with a durable audit.
- `AppPackage/Sources/DownloadsFeature/DownloadsView+Subviews.swift` - Removes the nested Download Inspector mask.
- `AppPackage/Sources/AppComponents/ViewModifiers.swift` - Reads Reduce Motion and conditionally disables the scoped blur animation.

## Decisions Made

- Kept Download Inspector privacy ownership on its stable presented NavigationStack root so the whole modal, including navigation chrome, is protected exactly once.
- Treated production activity/share presentations as masked runtime roots because their presentation roots are part of the app's runtime hierarchy; only preview harnesses are excluded.
- Derived the expected executable-mask count from inventory rows and checked every recorded file-and-line site, preventing a duplicate from compensating for an uncovered root.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Used the available Xcode verification scheme**

- **Found during:** Task 3 verification
- **Issue:** The planned `AppPackage-Package` scheme is not present in this project configuration.
- **Fix:** Built the `AppFeature` scheme for a generic iOS Simulator destination with a dedicated DerivedData path.
- **Files modified:** None
- **Verification:** The AppFeature build completed successfully with SwiftLint enabled.
- **Committed in:** No source commit required; verification-only adjustment.

---

**Total deviations:** 1 auto-fixed (1 blocking verification-environment issue).
**Impact on plan:** The intended package product and all changed Swift sources compiled successfully; implementation scope was unchanged.

## Issues Encountered

- The initial sandboxed commit attempt could not create `.git/index.lock`; the approved git operations subsequently created all atomic task commits successfully.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- GAP-3 and WR-03 are resolved in source and verified by the bijective audit and AppFeature build.
- The accessibility implementation follows the platform Reduce Motion environment value; final device-level privacy sweep should include toggling Reduce Motion to confirm the immediate transition feels correct.
- Plans 07-10 and 07-12 remain independently executable before phase re-verification.
- No stubs, lint suppressions, blur floors, new trust boundaries, or deferred implementation issues were introduced.

## Self-Check: PASSED

- The inventory contains 39 runtime-root rows, 39 unique executable mask sites, 41 presentation modifiers, and three preview-only exclusions.
- DownloadsView+Subviews.swift contains zero masks; DownloadsView.swift retains all three presented-root masks.
- PrivacyMaskModifier contains one Reduce Motion environment read, a conditional nil animation, the floorless blur, and the unchanged hit-testing guard.
- The AppFeature generic iOS Simulator build succeeded in 74.772 seconds.
- `git diff --check` passes, and generated documentation contains no absolute home paths.
- Task commits `02e40f9f`, `fe6ae9e1`, and `0789198b` exist in git history.

---
*Phase: 07-root-privacy-mask-auto-lock-removal*
*Completed: 2026-07-14*
