---
phase: 08-architecture-hygiene-client-seams
plan: 04
subsystem: networking
tags: [gallery-host, request-seam, shared-setting, parity]

# Dependency graph
requires:
  - phase: 08-architecture-hygiene-client-seams
    provides: Host-taking URL helpers and explicit gallery-list request hosts
provides:
  - Explicit GalleryHost storage on four account request types and FavoriteCategoriesRequest
  - SettingFeature request and cookie host resolution from the shared Setting value
  - Deterministic account and routine request baselines using an explicit host
affects: [08-05, 08-06, 08-07, 08-08, NetworkingFeature, SettingFeature]

# Tech tracking
tech-stack:
  added: []
  patterns: [explicit value threading, shared-setting snapshots, request dependency seams]

key-files:
  created:
    - .planning/phases/08-architecture-hygiene-client-seams/08-04-SUMMARY.md
  modified:
    - AppPackage/Sources/NetworkingFeature/Request+Account.swift
    - AppPackage/Sources/NetworkingFeature/Request.swift
    - AppPackage/Sources/SettingFeature/SettingReducer+Body.swift
    - AppPackage/Sources/SettingFeature/SettingReducer+Helpers.swift
    - AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift
    - AppPackage/Tests/NetworkingFeatureTests/AccountRequestBaselineTests.swift
    - AppPackage/Tests/NetworkingFeatureTests/RoutineRequestBaselineTests.swift

key-decisions:
  - "Setting reducers snapshot setting.galleryHost when constructing each host-dependent effect."
  - "EhSettingFeature state reads shared Setting directly because it previously had no host source."
  - "Account and routine request baselines use an explicit deterministic E-Hentai host."

patterns-established:
  - "Setting flow is @SharedReader(.setting) -> Request(host:) or setting.galleryHost.url for cookie access."
  - "Setting-consumed request types store every host-dependent URL-construction input explicitly."

requirements-completed: [HYG-01]

coverage:
  - id: D1
    description: All five Setting-consumed account and miscellaneous requests store an explicit GalleryHost and use the host-taking uConfig helper.
    requirement: HYG-01
    verification:
      - kind: integration
        ref: "cd AppPackage && xcodebuild build -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: integration
        ref: "cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:NetworkingFeatureTests"
        status: pass
      - kind: other
        ref: "Static request audit for required GalleryHost properties and Defaults.URL.uConfig(host:) calls"
        status: pass
    human_judgment: false
  - id: D2
    description: Setting flows supply setting.galleryHost to requests and resolve direct cookie hosts from setting.galleryHost.url without changing action or cancellation behavior.
    requirement: HYG-01
    verification:
      - kind: integration
        ref: "cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:SettingFeatureTests"
        status: pass
      - kind: other
        ref: "Static audit of SettingFeature host reads and request construction sites"
        status: pass
    human_judgment: false

# Metrics
duration: 6min
completed: 2026-07-14
status: complete
---

# Phase 08 Plan 04: Explicit Setting Request Hosts Summary

**Five Setting-consumed requests now carry `GalleryHost` explicitly from shared settings through URL construction, while Setting cookie access resolves against the same shared host.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-14T08:07:56Z
- **Completed:** 2026-07-14T08:14:46Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Added a required leading `host: GalleryHost` initializer argument and stored property to VerifyEhProfileRequest, EhProfileRequest, EhSettingRequest, SubmitEhSettingChangesRequest, and FavoriteCategoriesRequest.
- Forwarded the stored host into every affected `Defaults.URL.uConfig(host:)` call without changing response or parsing behavior.
- Threaded `setting.galleryHost` through Setting profile verification, profile loading, favorite categories, EhSetting loading, and EhSetting submission.
- Replaced Setting-owned direct global cookie hosts with `setting.galleryHost.url` while preserving the deferred launch mirror machinery.
- Kept all 24 SettingFeature tests and all 77 NetworkingFeature tests passing with deterministic explicit-host baselines.

## Task Commits

1. **Task 1: Give the Setting-consumed account/misc requests an explicit host** - `615f3729` (refactor)
2. **Task 2: Supply setting.galleryHost from the Setting reducers and convert direct host reads** - `8ff4c06e` (refactor)

## Files Created/Modified

- `AppPackage/Sources/NetworkingFeature/Request+Account.swift` - Stores required hosts and forwards them to the account settings URL helper.
- `AppPackage/Sources/NetworkingFeature/Request.swift` - Stores and forwards the required favorite-categories host.
- `AppPackage/Sources/SettingFeature/SettingReducer+Body.swift` - Supplies shared hosts to profile and favorite-category requests and uses the shared cookie host.
- `AppPackage/Sources/SettingFeature/SettingReducer+Helpers.swift` - Resolves the profile-index cookie host from shared Setting.
- `AppPackage/Sources/SettingFeature/EhSetting/EhSettingReducer.swift` - Reads shared Setting and supplies its host to EhSetting requests and cookie writes.
- `AppPackage/Tests/NetworkingFeatureTests/AccountRequestBaselineTests.swift` - Makes account request URL baselines explicitly host-scoped.
- `AppPackage/Tests/NetworkingFeatureTests/RoutineRequestBaselineTests.swift` - Makes the favorite-categories baseline explicitly host-scoped.
- `.planning/phases/08-architecture-hygiene-client-seams/08-04-SUMMARY.md` - Records implementation and verification evidence.

## Decisions Made

- Snapshotted `setting.galleryHost` before each effect so each request uses a consistent construction-time host.
- Added a read-only shared Setting value to EhSettingFeature state because the reducer previously had no explicit host source.
- Made affected baseline hosts deterministic `.ehentai` constants so parity tests no longer depend on the transitional global host mirror.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated request baseline construction sites**

- **Found during:** Task 1 implementation
- **Issue:** Requiring `host` on the five request initializers made existing NetworkingFeature baseline tests fail to compile, but the plan's file inventory omitted those test files.
- **Fix:** Passed a deterministic explicit host to every affected baseline request and matching expected URL builder.
- **Files modified:** `AppPackage/Tests/NetworkingFeatureTests/AccountRequestBaselineTests.swift`, `AppPackage/Tests/NetworkingFeatureTests/RoutineRequestBaselineTests.swift`
- **Verification:** All 77 NetworkingFeature tests passed across nine suites.
- **Committed in:** `615f3729`

**2. [Rule 3 - Blocking] Supplied state to the profile-index completion helper**

- **Found during:** Task 2 implementation
- **Issue:** The helper that resolves the profile cookie host accepted only the response and therefore could not read `setting.galleryHost.url` as required.
- **Fix:** Passed reducer state into the helper as `inout State` and resolved the cookie host from its shared Setting value.
- **Files modified:** `AppPackage/Sources/SettingFeature/SettingReducer+Body.swift`, `AppPackage/Sources/SettingFeature/SettingReducer+Helpers.swift`
- **Verification:** All 24 SettingFeature tests passed across eight suites.
- **Committed in:** `8ff4c06e`

**3. [Rule 3 - Blocking] Adapted verification to the available package scheme and simulator**

- **Found during:** Task 1 verification
- **Issue:** The repository-root invocation selected the app project, which has no `AppPackage-Package` scheme, and the planned `iPhone 16` simulator is not installed. The task-level full package build also could not compile between the two atomic tasks because the newly required arguments were intentionally supplied in Task 2.
- **Fix:** Verified Task 1 with the scoped NetworkingFeature scheme, then ran the full package scheme and both focused test suites from `AppPackage` on the installed iPhone Air simulator with iOS 26.5 after Task 2.
- **Files modified:** None
- **Verification:** The NetworkingFeature build, full package build, all 24 SettingFeature tests, and all 77 NetworkingFeature tests succeeded.
- **Committed in:** No source change required.

---

**Total deviations:** 3 auto-fixed blocking issues.
**Impact on plan:** The production architecture stayed within scope; baseline edits and helper state access were required by the explicit initializer and host-source contracts, and verification remained equivalent on the installed simulator.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Setting-owned account and miscellaneous requests no longer depend on the transitional global host default.
- Plans 08-05 through 08-07 can continue parameterizing the remaining request families before 08-08 removes the mirror machinery.
- No blockers remain.

## Self-Check: PASSED

- The five named requests declare `public let host: GalleryHost`, require it as the leading initializer argument, and call `Defaults.URL.uConfig(host:)`.
- Every affected production and baseline construction site supplies an explicit host.
- Setting reducer cookie reads and writes resolve from `setting.galleryHost.url`; the deferred launch mirror restore remains intact.
- The package build succeeds with SwiftLint plugins enabled.
- SettingFeatureTests passes all 24 tests across eight suites.
- NetworkingFeatureTests passes all 77 tests across nine suites.
- Task commits `615f3729` and `8ff4c06e` exist in git history and pass `git show --check`.
- Modified source contains no new warning suppression, SwiftLint disable, TODO, FIXME, or placeholder.
- The concurrency review found no isolation, cancellation, or unstructured-task regressions; immutable host snapshots cross effect boundaries safely.
- Generated documentation contains no absolute home-directory paths or private local-project names.

---
*Phase: 08-architecture-hygiene-client-seams*
*Completed: 2026-07-14*
