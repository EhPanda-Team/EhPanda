---
phase: 08-architecture-hygiene-client-seams
plan: 15
subsystem: reader-networking
tags: [swift, tca, cookies, gallery-host, regression-testing]
requires:
  - phase: 08-architecture-hygiene-client-seams
    provides: Explicit caller-owned GalleryHost request construction from plans 08-03 through 08-06
provides:
  - Request-origin GalleryHost propagation through normal-image refetch completion
  - Deterministic reducer regression for a response arriving after the shared host changes
affects: [reading-feature, cookie-client, gallery-host-routing]
tech-stack:
  added: []
  patterns:
    - Async completion actions carry the request-origin host instead of re-reading mutable shared settings
    - Reducer cookie-routing tests use an isolated CookieClient testing store
key-files:
  created:
    - AppPackage/Tests/ReadingFeatureTests/ReadingReducerImageFetchTests.swift
  modified:
    - AppPackage/Sources/ReadingFeature/ReadingReducer.swift
    - AppPackage/Sources/ReadingFeature/ReadingReducer+ImageFetch.swift
    - AppPackage/Package.swift
key-decisions:
  - "Carry GalleryHost in refetchNormalImageURLsDone so both success and failure completions preserve request identity."
  - "Observe the injected CookieClient testing store as the host-routing spy instead of widening CookieClient production API solely for a test callback."
patterns-established:
  - "Request-origin action payload: an asynchronous response uses immutable construction-time routing context across mutable shared-setting changes."
requirements-completed: [HYG-01]
coverage:
  - id: D1
    description: "Normal-image refetch completion writes skipserver cookies to the request-origin host after the shared host changes."
    requirement: HYG-01
    verification:
      - kind: unit
        ref: "AppPackage/Tests/ReadingFeatureTests/ReadingReducerImageFetchTests.swift#refetchResponseWritesSkipServerToOriginatingHost"
        status: pass
      - kind: integration
        ref: "xcodebuild test -quiet -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:ReadingFeatureTests"
        status: pass
      - kind: integration
        ref: "xcodebuild test -quiet -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
    human_judgment: false
duration: 11 min
completed: 2026-07-14
status: complete
---

# Phase 8 Plan 15: Reader Refetch Host Preservation Summary

Normal-image refetch responses now retain their construction-time gallery host through cookie handling, with a reducer regression covering a mid-flight shared-host switch.

## Performance

- **Duration:** 11 min
- **Started:** 2026-07-14T11:55:00Z
- **Completed:** 2026-07-14T12:05:51Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments

- Added the request-origin `GalleryHost` to `refetchNormalImageURLsDone` and forwarded it from both response paths.
- Removed the completion-time shared-setting host read so `setSkipServer` always receives the host used to construct the request.
- Added an isolated TCA reducer regression that switches the shared host before completion and proves the cookie lands only on the originating host.

## Task Commits

1. **Task 1: Carry the originating GalleryHost through refetch completion** - `ffefbe43`
2. **Task 2: Add the suspended-request host-switch regression** - `f9344450`

**Plan metadata:** committed with this summary

## Files Created/Modified

- `AppPackage/Sources/ReadingFeature/ReadingReducer.swift` - adds the originating host to the refetch completion action payload.
- `AppPackage/Sources/ReadingFeature/ReadingReducer+ImageFetch.swift` - forwards and consumes the immutable request-origin host.
- `AppPackage/Tests/ReadingFeatureTests/ReadingReducerImageFetchTests.swift` - verifies cookie routing after a shared-host switch.
- `AppPackage/Package.swift` - gives ReadingFeatureTests direct ComposableArchitecture and CookieClient dependencies.

## Decisions Made

- Kept the action payload ordered as index, host, result so the routing context is explicit at every sender and handler.
- Used `CookieClient.testing()` as an isolated observable spy: asserting which host store receives `skipserver` proves the externally meaningful behavior without adding a production-only callback seam.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Used the observable CookieClient test store instead of an unavailable endpoint callback**
- **Found during:** Task 2
- **Issue:** `CookieClient.setSkipServer` is a behavior method built from private cookie primitives, not an injectable stored closure, so the proposed `LockIsolated` endpoint spy cannot be constructed outside CookieClient without widening production API solely for this test.
- **Fix:** Injected a fresh `CookieClient.testing()` and asserted that only the originating host's isolated cookie store receives `skipserver`. This observes the same host argument through its externally meaningful effect and never touches a process-global cookie store.
- **Files modified:** `AppPackage/Tests/ReadingFeatureTests/ReadingReducerImageFetchTests.swift`
- **Verification:** The focused ReadingFeatureTests target and full AppPackage suite pass; the old completion-time host read would place the cookie on ExHentai and fail both host assertions.
- **Committed in:** `f9344450`

**2. [Rule 3 - Blocking] Corrected the focused test invocation to the generated package scheme**
- **Found during:** Task 2 verification
- **Issue:** The plan's repository-root `AppPackage-Package` scheme does not exist in the app project, and ReadingFeatureTests is not yet a member of the shared FeatureTests plan.
- **Fix:** Ran the generated `AppPackage-Package` scheme from the `AppPackage` directory, first focused to ReadingFeatureTests and then without a filter for the complete package suite.
- **Files modified:** None
- **Verification:** Both corrected commands exited successfully.
- **Committed in:** Plan metadata commit

**3. [Rule 1 - Bug] Reconciled stale state progress after the gap-plan advance**
- **Found during:** Plan metadata update
- **Issue:** The state handlers counted 77 of 80 summaries but left the frontmatter percentage, human-readable plan number, next action, progress bar, and velocity count stale or based on the four-plan gap subset.
- **Fix:** Reconciled STATE to Plan 15 of 18, 77 of 80 completed plans, 96 percent, and the 08-16 execution handoff while retaining the orchestrator's executing status.
- **Files modified:** `.planning/STATE.md`
- **Verification:** STATE frontmatter and prose now agree with the 15 Phase 8 summaries and 80 milestone plans on disk.
- **Committed in:** Plan metadata commit

---

**Total deviations:** 3 auto-fixed issues (1 bug, 2 blocking issues).
**Impact on plan:** Verification targets the same package products and simulator requested by the plan, while the behavior-level cookie assertion avoids adding a test-only production seam.

## Issues Encountered

- The first focused command failed because the repository-root app project does not expose `AppPackage-Package`; the corrected package-directory command passed.
- The shared FeatureTests test plan does not yet include ReadingFeatureTests, so the focused suite ran through SwiftPM's generated scheme as intended for this plan.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- GAP-01 is closed with implementation and deterministic regression evidence.
- Phase 8 can continue with the remaining gap-closure plans for profile-host propagation, UserDefaults substitution, and cookie-log enforcement.

---
*Phase: 08-architecture-hygiene-client-seams*
*Completed: 2026-07-14*

## Self-Check: PASSED

- Task commits `ffefbe43` and `f9344450` exist in Git history.
- `ReadingReducerImageFetchTests.swift` exists and the focused ReadingFeatureTests suite passes.
- The full AppPackage test suite and app build pass with SwiftLint build-tool checks enabled.
- The action has one definition, two construction-time-host senders, and one carried-host handler; the completion no longer reads shared host state.
