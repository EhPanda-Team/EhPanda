---
phase: 08-architecture-hygiene-client-seams
plan: 05
subsystem: networking
tags: [gallery-host, cookie-client, detail-feature, parity]

# Dependency graph
requires:
  - phase: 08-architecture-hygiene-client-seams
    provides: Host-taking URL helpers and explicit Setting request hosts
provides:
  - Explicit GalleryHost storage on five Detail-consumed account requests
  - Host-taking CookieClient apiuid lookup
  - Detail request and cookie host resolution from shared Setting
affects: [08-06, 08-07, 08-08, NetworkingFeature, CookieClient, DetailFeature]

# Tech tracking
tech-stack:
  added: []
  patterns: [explicit value threading, shared-setting snapshots, host-scoped cookie access]

key-files:
  created:
    - .planning/phases/08-architecture-hygiene-client-seams/08-05-SUMMARY.md
  modified:
    - AppPackage/Sources/NetworkingFeature/Request+Account.swift
    - AppPackage/Sources/CookieClient/CookieClient.swift
    - AppPackage/Sources/DetailFeature/DetailReducer+Fetch.swift
    - AppPackage/Sources/DetailFeature/Comments/CommentsReducer.swift
    - AppPackage/Tests/NetworkingFeatureTests/AccountRequestBaselineTests.swift

key-decisions:
  - "Detail reducers snapshot setting.galleryHost when constructing each host-dependent effect."
  - "CookieClient apiuid reads the selected host URL supplied by its caller."
  - "Account request baselines use an explicit deterministic E-Hentai host."

patterns-established:
  - "Detail flow is @SharedReader(.setting) -> cookieClient.apiuid(host:) and Request(host:)."
  - "Detail-consumed account requests store every host-dependent URL-construction input explicitly."

requirements-completed: [HYG-01]

coverage:
  - id: D1
    description: All five Detail-consumed account requests store an explicit GalleryHost, use host-taking URL helpers, and preserve their request payloads.
    requirement: HYG-01
    verification:
      - kind: integration
        ref: "cd AppPackage && xcodebuild build -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: integration
        ref: "cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:NetworkingFeatureTests"
        status: pass
      - kind: other
        ref: "Static request audit for required GalleryHost properties and host-taking URL construction"
        status: pass
    human_judgment: false
  - id: D2
    description: Detail flows supply setting.galleryHost to all three apiuid reads and all five requests without changing action, guard, or cancellation behavior.
    requirement: HYG-01
    verification:
      - kind: integration
        ref: "xcodebuild -skipMacroValidation -project EhPanda.xcodeproj -scheme EhPanda -destination 'generic/platform=iOS Simulator' -quiet build"
        status: pass
      - kind: integration
        ref: "cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:DetailFeatureTests"
        status: pass
      - kind: other
        ref: "Static audit of DetailFeature apiuid reads and request construction sites"
        status: pass
    human_judgment: false

# Metrics
duration: 16min
completed: 2026-07-14
status: complete
---

# Phase 08 Plan 05: Explicit Detail Account Request Hosts Summary

**Five Detail account requests and the CookieClient apiuid lookup now receive `GalleryHost` explicitly from shared settings while preserving request payloads, reducer flow, and cancellation behavior.**

## Performance

- **Duration:** 16 min
- **Started:** 2026-07-14T08:20:49Z
- **Completed:** 2026-07-14T08:36:49Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added a required leading `host: GalleryHost` initializer argument and stored property to FavorGalleryRequest, UnfavorGalleryRequest, RateGalleryRequest, VoteGalleryCommentRequest, and VoteGalleryTagRequest.
- Converted CookieClient's parameterless apiuid property into `apiuid(host:)`, resolving its cookie lookup from the caller-supplied host URL.
- Threaded `setting.galleryHost` through all three Detail apiuid reads and all five affected account request constructions.
- Kept reducer effect captures on the opening-brace line by snapshotting their values into immutable local constants.
- Preserved the existing guards, action flow, request payloads, response mapping, and cancellation IDs.
- Kept the full app build warning-free, all four DetailFeature tests passing, and all 77 NetworkingFeature tests passing with deterministic explicit-host baselines.

## Task Commits

1. **Task 1: Give the Detail-consumed account requests explicit host + make apiuid host-taking** - `c5bf8253` (refactor)
2. **Task 2: Supply setting.galleryHost from the Detail reducer call sites** - `edcc05c3` (refactor)
3. **Post-completion fix: Align Detail effect captures with SwiftLint** - `b2643b8d` (fix)

## Files Created/Modified

- `AppPackage/Sources/NetworkingFeature/Request+Account.swift` - Stores required hosts and forwards them to each affected URL helper.
- `AppPackage/Sources/CookieClient/CookieClient.swift` - Replaces the parameterless apiuid property with a host-taking accessor.
- `AppPackage/Sources/DetailFeature/DetailReducer+Fetch.swift` - Supplies lint-clean immutable host snapshots to favorite, rating, and tag-vote effects.
- `AppPackage/Sources/DetailFeature/Comments/CommentsReducer.swift` - Supplies the shared host to comment-vote cookie and request access.
- `AppPackage/Tests/NetworkingFeatureTests/AccountRequestBaselineTests.swift` - Makes affected account request URL baselines explicitly host-scoped.
- `.planning/phases/08-architecture-hygiene-client-seams/08-05-SUMMARY.md` - Records implementation and verification evidence.

## Decisions Made

- Snapshotted `setting.galleryHost` before each effect so every request uses a consistent construction-time host.
- Required callers to select the CookieClient apiuid cookie host explicitly rather than retaining a transitional global-host fallback.
- Made affected baseline hosts deterministic `.ehentai` constants so parity tests no longer depend on the transitional global host mirror.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated request baseline construction sites**

- **Found during:** Task 1 implementation
- **Issue:** Requiring `host` on the five request initializers made existing NetworkingFeature baseline tests fail to compile, but the plan's file inventory omitted the test file.
- **Fix:** Passed a deterministic explicit host to every affected baseline request and matching expected URL builder.
- **Files modified:** `AppPackage/Tests/NetworkingFeatureTests/AccountRequestBaselineTests.swift`
- **Verification:** All 77 NetworkingFeature tests passed across nine suites.
- **Committed in:** `c5bf8253`

**2. [Rule 3 - Blocking] Adapted verification to the available package scheme and simulator**

- **Found during:** Task 1 verification
- **Issue:** The repository-root invocation selected the app project, which has no `AppPackage-Package` scheme, and the planned `iPhone 16` simulator is not installed. The full package also could not compile between the two atomic tasks because Task 2 intentionally supplied the newly required arguments.
- **Fix:** Verified Task 1 with the scoped NetworkingFeature scheme, then ran the full package scheme and both focused test suites from `AppPackage` on the installed iPhone Air simulator with iOS 26.5 after Task 2.
- **Files modified:** None
- **Verification:** The NetworkingFeature build, full package build, all four DetailFeature tests, and all 77 NetworkingFeature tests succeeded.
- **Committed in:** No source change required.

**3. [Rule 1 - Bug] Fixed closure capture placement warnings found by the full-app lint pass**

- **Found during:** Post-completion full-app verification
- **Issue:** The new multiline capture lists placed capture entries after the closure's opening-brace line, producing 13 `closure_parameter_position` warnings.
- **Fix:** Snapshotted each effect input into immutable local constants, then used compact capture lists on the same line as the opening brace.
- **Files modified:** `AppPackage/Sources/DetailFeature/DetailReducer+Fetch.swift`
- **Verification:** The full app build completed with SwiftLint enabled and no warnings; all four DetailFeature tests passed.
- **Committed in:** `b2643b8d`

---

**Total deviations:** 3 auto-fixed issues (one bug, two blocking).
**Impact on plan:** The production architecture stayed within scope; the baseline edit was required by the explicit initializer contract, effect snapshots remain behaviorally identical, and verification remained equivalent on the installed simulator.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Detail-owned account requests and apiuid cookie access no longer depend on the transitional global host default.
- Plan 08-06 can parameterize the remaining CookieClient skip-server path before the later mirror removal.
- No blockers remain.

## Self-Check: PASSED

- The five named requests declare `public let host: GalleryHost`, require it as the leading initializer argument, and use host-taking URL construction.
- CookieClient exposes `apiuid(host:)`; no parameterless Detail apiuid access remains.
- All three Detail apiuid reads and all five affected request construction sites supply `setting.galleryHost`.
- The full app build succeeds with SwiftLint plugins enabled and emits no warnings.
- DetailFeatureTests passes all four tests across three suites.
- NetworkingFeatureTests passes all 77 tests across nine suites.
- Task commits `c5bf8253`, `edcc05c3`, and `b2643b8d` exist in git history and pass `git show --check`.
- Modified source contains no new warning suppression, SwiftLint disable, TODO, FIXME, or placeholder.
- The concurrency review found no isolation, cancellation, or unstructured-task regressions; immutable host snapshots cross effect boundaries safely.
- Generated documentation contains no absolute home-directory paths or private local-project names.

---
*Phase: 08-architecture-hygiene-client-seams*
*Completed: 2026-07-14*
