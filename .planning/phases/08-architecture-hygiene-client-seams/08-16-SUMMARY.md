---
phase: 08-architecture-hygiene-client-seams
plan: 16
subsystem: setting-networking
tags: [swift, tca, gallery-host, cookies, regression-testing]
requires:
  - phase: 08-architecture-hygiene-client-seams
    provides: Explicit caller-owned GalleryHost request construction and the sibling reader completion pattern
provides:
  - Request-origin GalleryHost propagation through profile verification completion
  - Origin-stable selected-profile cookie writes and default-profile creation
  - Deterministic SettingReducer regressions for shared-host changes during verification
affects: [setting-feature, networking-feature, cookie-client, gallery-host-routing]
tech-stack:
  added: []
  patterns:
    - Async profile completion actions carry immutable request-routing context
    - Reducer host-routing tests use an isolated CookieClient testing store
key-files:
  created:
    - AppPackage/Tests/SettingFeatureTests/SettingReducerTests.swift
  modified:
    - AppPackage/Sources/SettingFeature/SettingReducer.swift
    - AppPackage/Sources/SettingFeature/SettingReducer+Body.swift
    - AppPackage/Sources/SettingFeature/SettingReducer+Helpers.swift
key-decisions:
  - "Carry GalleryHost in fetchEhProfileIndexDone and createDefaultEhProfile so every profile side effect retains request identity."
  - "Observe selected-profile routing through an isolated CookieClient testing store while asserting default-profile routing at the follow-up action boundary."
patterns-established:
  - "Request-origin action payload: profile verification preserves its construction-time host across mutable shared-setting changes."
requirements-completed: [HYG-01]
coverage:
  - id: D1
    description: "Profile verification writes selectedProfile cookies to the request-origin host after the shared host changes."
    requirement: HYG-01
    verification:
      - kind: unit
        ref: "AppPackage/Tests/SettingFeatureTests/SettingReducerTests.swift#selectedProfileWriteUsesOriginatingHostAfterSharedHostChanges"
        status: pass
      - kind: integration
        ref: "xcodebuild test -quiet -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:SettingFeatureTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "Missing-profile recovery creates the default profile on the request-origin host after the shared host changes."
    requirement: HYG-01
    verification:
      - kind: unit
        ref: "AppPackage/Tests/SettingFeatureTests/SettingReducerTests.swift#defaultProfileCreationUsesOriginatingHostAfterSharedHostChanges"
        status: pass
      - kind: integration
        ref: "xcodebuild test -quiet -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
    human_judgment: false
duration: 6 min
completed: 2026-07-14
status: complete
---

# Phase 8 Plan 16: Profile Verification Host Preservation Summary

Profile verification now retains its construction-time gallery host through selected-profile cookie writes and default-profile recovery, with deterministic regressions covering a mid-flight shared-host change.

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-14T12:16:48Z
- **Completed:** 2026-07-14T12:22:23Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added the request-origin `GalleryHost` to profile verification completion and default-profile creation actions.
- Removed completion-time shared-setting host reads from selected-profile cookie routing and profile creation.
- Added isolated TCA reducer regressions that switch the shared host before completion and prove both side effects retain the originating host.

## Task Commits

1. **Task 1: Carry the originating GalleryHost through profile verification completion** - `4fb37c24`
2. **Task 2: Add the suspended-request host-switch regressions** - `f40213f1`

**Plan metadata:** committed with this summary

## Files Created/Modified

- `AppPackage/Sources/SettingFeature/SettingReducer.swift` - adds originating-host payloads to profile lifecycle actions.
- `AppPackage/Sources/SettingFeature/SettingReducer+Body.swift` - forwards and consumes the immutable request-origin host.
- `AppPackage/Sources/SettingFeature/SettingReducer+Helpers.swift` - routes profile cookies and recovery through the carried host.
- `AppPackage/Tests/SettingFeatureTests/SettingReducerTests.swift` - covers selected-profile and default-profile routing after a shared-host change.

## Decisions Made

- Kept host first and result second in `fetchEhProfileIndexDone`, matching request context before response data at every sender and handler.
- Used `CookieClient.testing()` to observe the selected-profile destination without touching a process-global cookie store or widening production API for a test-only callback.
- Asserted default-profile routing on the typed follow-up action, which is the reducer boundary that supplies the request constructor's host.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Corrected the focused test invocation to the generated package scheme**
- **Found during:** Task 2 verification
- **Issue:** The repository-root app project does not expose the plan's `AppPackage-Package` scheme.
- **Fix:** Ran the same focused and full suite through SwiftPM's generated `AppPackage-Package` scheme from the `AppPackage` directory.
- **Files modified:** None
- **Verification:** Focused SettingFeatureTests and the full AppPackage suite exited successfully on the requested simulator.
- **Committed in:** Plan metadata commit

**2. [Rule 1 - Bug] Reconciled stale state progress after the gap-plan advance**
- **Found during:** Plan metadata update
- **Issue:** The state handlers counted 79 of 80 summaries but wrote a 55 percent frontmatter value and left the human-readable progress, activity, plan count, and next action stale.
- **Fix:** Reconciled STATE to Plan 17 of 18, 79 of 80 completed plans, 99 percent, and the 08-17 execution handoff.
- **Files modified:** `.planning/STATE.md`
- **Verification:** STATE frontmatter, current position, progress prose, and velocity count now agree with the summaries on disk.
- **Committed in:** Plan metadata commit

---

**Total deviations:** 2 auto-fixed issues (1 bug, 1 blocking issue).
**Impact on plan:** Verification exercised the same package products and simulator requested by the plan, and planning state now reflects actual completion; implementation scope was unchanged.

## TDD Gate Compliance

- Confirmed both new regressions fail against a temporary pre-fix completion implementation before restoring the committed Task 1 fix.
- Confirmed both regressions pass with the request-origin host implementation.
- Task 1 and Task 2 remain separate atomic commits because this plan intentionally schedules the production correction before its regression task.

## Issues Encountered

- The generated package scheme reports an empty supported-platform diagnostic before running, but all focused and full package tests complete successfully.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- GAP-02 is closed with implementation and deterministic reducer evidence.
- Phase 8 can continue with the remaining UserDefaults substitution gap plan.

---
*Phase: 08-architecture-hygiene-client-seams*
*Completed: 2026-07-14*

## Self-Check: PASSED

- Task commits `4fb37c24` and `f40213f1` exist in Git history.
- `SettingReducerTests.swift` exists and the focused SettingFeatureTests suite passes.
- The full AppPackage suite and warning-free app build pass with SwiftLint build-tool checks enabled.
- Profile completion has one originating-host payload, two construction-time-host senders, and one carried-host handler; the completion no longer reads shared host state.
