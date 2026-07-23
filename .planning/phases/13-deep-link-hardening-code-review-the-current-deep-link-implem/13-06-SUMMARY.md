---
phase: 13-deep-link-hardening
plan: 06
subsystem: toast-presentation
tags: [swift, swiftui, composable-architecture, swift-testing, animation]

requires:
  - phase: 13-deep-link-hardening
    plan: 05
    provides: Completion-driven modal replacement with no fixed dismissal delay
provides:
  - Identity-keyed toast replacement animation using each presented toast's UUID
  - Immediate loading-to-error state replacement in both deep-link gallery fetch reducers
  - Exhaustive reducer regressions proving replacement ordering and no delayed follow-up actions
affects: [13-07-ui-test-preparation, app-presentation, comments-links, system-notification]

tech-stack:
  added: []
  patterns: [identity-driven SwiftUI animation, synchronous reducer presentation replacement, exhaustive TestStore completion]

key-files:
  created: []
  modified:
    - AppPackage/Sources/SystemNotification/View+Toast.swift
    - AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift
    - AppPackage/Sources/DetailFeature/Comments/CommentsReducer.swift
    - AppPackage/Tests/AppFeatureTests/PresentationFeatureTests.swift
    - AppPackage/Tests/DetailFeatureTests/CommentsReducerTests.swift

key-decisions:
  - "The toast overlay watches the presented state's existing UUID, so nil-to-toast, toast-to-nil, and toast-to-toast identity changes share one scoped animation boundary."
  - "Both gallery failure arms replace loading state synchronously; only successful gallery resolution clears the toast before routing."
  - "The existing id-keyed auto-dismiss task remains unchanged, preserving replacement cancellation and timer restart behavior."

patterns-established:
  - "Presentation replacement animation follows presented-value identity rather than a Boolean presence projection."
  - "Reducers publish the final presentation state immediately and leave visual sequencing to the view transition."

requirements-completed: [SC-1]

coverage:
  - id: D1
    description: "The toast overlay animates every presented-toast identity change while retaining its id-keyed dismissal timer."
    requirement: SC-1
    verification:
      - kind: integration
        ref: "xcodebuild build -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -skipMacroValidation"
        status: pass
      - kind: other
        ref: "Source assertion: View+Toast.swift scopes animation to item?.state.id and retains .task(id: id)"
        status: pass
    human_judgment: false
  - id: D2
    description: "PresentationFeature and CommentsReducer replace loading toasts with error toasts directly, with no 500ms routing-path sleeps or follow-up actions."
    requirement: SC-1
    verification:
      - kind: unit
        ref: "PresentationFeatureTests#galleryFailureToastUsesSanitizedContext and CommentsReducerTests#galleryFetchFailureReplacesLoadingToastWithoutFollowUpAction"
        status: pass
      - kind: integration
        ref: "xcodebuild test -quiet -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -skipMacroValidation"
        status: pass
      - kind: other
        ref: "SwiftLint 0.65.0 lint --strict --no-cache across 460 repository-owned Swift files"
        status: pass
    human_judgment: false

duration: 7 min
completed: 2026-07-23
status: complete
---

# Phase 13 Plan 06: Identity-Driven Toast Replacement Summary

**Loading-to-error toast hand-offs now cross-transition by presented UUID while both gallery reducers publish failures immediately with no timing gap**

## Performance

- **Duration:** 7 min
- **Started:** 2026-07-23T03:14:47Z
- **Completed:** 2026-07-23T03:21:06Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Re-keyed the toast overlay animation from Boolean presence to the presented toast UUID, covering insertion, removal, and replacement without broadening animation to the host view.
- Removed both 500ms loading-to-error sleeps and made PresentationFeature and CommentsReducer set their final error toast synchronously.
- Preserved the id-keyed auto-dismiss task, reducer success behavior, error payload sanitization, and unrelated comment-editor/scroll timing.
- Added exhaustive TestStore regressions that begin from loading state, assert direct error replacement, and prove no delayed action remains.
- Verified the targeted feature bundles, full default unit plan, application build, and strict lint across all 460 repository-owned Swift files.

## Task Commits

Each task was committed atomically:

1. **Task 1: Identity-keyed toast replacement and direct reducer error sets** - `1aec18ab` (fix)
2. **Task 2: Direct replacement reducer regressions** - `7c7ce2d7` (test)

## Files Created/Modified

- `AppPackage/Sources/SystemNotification/View+Toast.swift` - Watches the optional presented-toast UUID at the overlay's scoped animation boundary.
- `AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift` - Replaces a loading toast with the existing sanitized persistent gallery error synchronously.
- `AppPackage/Sources/DetailFeature/Comments/CommentsReducer.swift` - Replaces a loading toast with the existing auto-hiding caption-only error synchronously.
- `AppPackage/Tests/AppFeatureTests/PresentationFeatureTests.swift` - Starts gallery failure fixtures from loading state and finishes exhaustively after the direct error mutation.
- `AppPackage/Tests/DetailFeatureTests/CommentsReducerTests.swift` - Adds direct loading-to-error replacement coverage with no follow-up action.

## Decisions Made

- Reused `AppAlertState.id` as the single identity for view replacement, transition animation, gesture guards, accessibility focus, and timer restart rather than introducing a parallel view-local token.
- Moved toast clearing into the success arms so failure reductions expose a true loading-ID to error-ID replacement to SwiftUI.
- Left the comments reducer's post-comment and scroll-highlight sleeps unchanged because they are unrelated to deep-link routing and explicitly outside D-14.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Allowed Xcode verification to use required system services and caches**

- **Found during:** Task 1 build verification
- **Issue:** The filesystem sandbox denied CoreSimulator, DerivedData, SwiftPM manifest-cache, and compiler module-cache access required by Xcode.
- **Fix:** Re-ran build and test verification with the required filesystem access; no source behavior, assertions, or warning policy changed.
- **Files modified:** None
- **Verification:** Application build, targeted reducer tests, and full default unit tests all completed successfully.
- **Committed in:** Not applicable

---

**Total deviations:** 1 auto-fixed (1 blocking environment issue).
**Impact on plan:** Verification required broader filesystem access only; implementation scope and behavior remained exactly as planned.

## Issues Encountered

- SwiftLint is supplied by the resolved Swift package artifact rather than the shell PATH. The artifact's 0.65.0 binary completed the required strict, no-cache repository scan with zero violations.

## Known Stubs

None. The scan found only established optional resets, empty compose defaults, and fixture defaults; this plan introduced no placeholder data or disconnected presentation path.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- D-14 is fully closed: Plan 13-05 removed modal dismissal timing, and this plan removed both remaining loading-to-error delays from the deep-link routing path.
- Plan 13-07 can add deterministic app-side UI-test seams on top of timing-free routing and toast presentation behavior.
- No blockers remain.

## Self-Check: PASSED

- Confirmed `1aec18ab` and `7c7ce2d7` exist in git history in task order.
- Confirmed all five modified files exist and no 500ms or 1000ms sequencing remains in the deep-link gallery path.
- Confirmed the overlay animation value is `item?.state.id` and its existing `.task(id: id)` auto-dismiss lifecycle is unchanged.
- Confirmed targeted AppFeature and DetailFeature tests, the full default unit plan, application build, and strict repository-owned source/test/extension lint pass.

---
*Phase: 13-deep-link-hardening*
*Completed: 2026-07-23*
