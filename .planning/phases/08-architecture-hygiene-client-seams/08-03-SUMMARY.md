---
phase: 08-architecture-hygiene-client-seams
plan: 03
subsystem: networking
tags: [gallery-host, request-seam, shared-setting, parity]

# Dependency graph
requires:
  - phase: 08-architecture-hygiene-client-seams
    provides: Host-taking gallery URL builders with transitional defaults
provides:
  - Explicit GalleryHost storage on all twelve gallery-list request types
  - Reducer-to-request host threading from the shared Setting value
  - Deterministic gallery-list URL parity tests using an explicit host
affects: [08-04, 08-05, 08-06, 08-07, NetworkingFeature, HomeFeature, SearchFeature, FavoritesFeature, DetailFeature]

# Tech tracking
tech-stack:
  added: []
  patterns: [explicit value threading, shared-setting snapshots, request dependency seams]

key-files:
  created:
    - .planning/phases/08-architecture-hygiene-client-seams/08-03-SUMMARY.md
  modified:
    - AppPackage/Sources/NetworkingFeature/Request+Gallery.swift
    - AppPackage/Sources/SearchFeature/SearchReducer.swift
    - AppPackage/Sources/HomeFeature/HomeReducer.swift
    - AppPackage/Sources/HomeFeature/HomeReducer+Body.swift
    - AppPackage/Sources/HomeFeature/Frontpage/FrontpageReducer.swift
    - AppPackage/Sources/HomeFeature/Popular/PopularReducer.swift
    - AppPackage/Sources/HomeFeature/Watched/WatchedReducer.swift
    - AppPackage/Sources/HomeFeature/Toplists/ToplistsReducer.swift
    - AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift
    - AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchReducer.swift
    - AppPackage/Tests/NetworkingFeatureTests/GalleryRequestBaselineTests.swift

key-decisions:
  - "Reducers snapshot setting.galleryHost when constructing each gallery-list effect, matching the existing filter and keyword snapshot semantics."
  - "Gallery request baselines use an explicit deterministic E-Hentai host instead of reading the transitional global host."

patterns-established:
  - "Gallery list flow is @SharedReader(.setting) -> Request(host:) -> URLUtil builder(host:)."
  - "Request types store all URL-construction inputs explicitly and do not resolve the active host from global state."

requirements-completed: [HYG-01]

coverage:
  - id: D1
    description: All twelve gallery-list request types store an explicit GalleryHost and pass it to every host-dependent URL builder.
    requirement: HYG-01
    verification:
      - kind: integration
        ref: "cd AppPackage && xcodebuild build -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: other
        ref: "rg -c '^    public let host: GalleryHost$' AppPackage/Sources/NetworkingFeature/Request+Gallery.swift (12 matches)"
        status: pass
    human_judgment: false
  - id: D2
    description: Every production and baseline-test gallery-list construction site supplies an explicit host, with URL and parsing parity preserved.
    requirement: HYG-01
    verification:
      - kind: integration
        ref: "cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:NetworkingFeatureTests"
        status: pass
      - kind: other
        ref: "rg multiline construction-site audit for gallery-list requests without a leading host argument (zero matches)"
        status: pass
    human_judgment: false

# Metrics
duration: 6min
completed: 2026-07-14
status: complete
---

# Phase 08 Plan 03: Explicit Gallery-List Request Hosts Summary

**All twelve gallery-list requests now carry `GalleryHost` explicitly from shared settings through URL construction, with deterministic request baselines preserving URL and parsing behavior.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-14T07:56:29Z
- **Completed:** 2026-07-14T08:02:28Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- Added a required leading `host: GalleryHost` initializer argument and stored property to all twelve gallery-list request types.
- Forwarded the stored host into all eleven host-dependent `URLUtil` calls; the supplied-URL date-seek request also records its explicit host.
- Threaded `setting.galleryHost` through Search, Home, Frontpage, Popular, Watched, Toplists, Favorites, and Detail Search request construction.
- Kept all 77 `NetworkingFeatureTests` passing while making the gallery-list baselines independent of the transitional global host.

## Task Commits

1. **Task 1: Give the gallery-list Request structs an explicit host** - `8bc1c790` (refactor)
2. **Task 2: Supply setting.galleryHost at every gallery-list construction site** - `c1513e7f` (refactor)

## Files Created/Modified

- `AppPackage/Sources/NetworkingFeature/Request+Gallery.swift` - Stores required hosts and forwards them to gallery-list URL builders.
- `AppPackage/Sources/SearchFeature/SearchReducer.swift` - Supplies the shared host to search, pagination, and date-seek requests.
- `AppPackage/Sources/HomeFeature/HomeReducer.swift` - Adds a read-only shared Setting value to Home state.
- `AppPackage/Sources/HomeFeature/HomeReducer+Body.swift` - Supplies the shared host to Home aggregate list requests.
- `AppPackage/Sources/HomeFeature/Frontpage/FrontpageReducer.swift` - Supplies the shared host to frontpage and date-seek requests.
- `AppPackage/Sources/HomeFeature/Popular/PopularReducer.swift` - Supplies the shared host to popular requests.
- `AppPackage/Sources/HomeFeature/Watched/WatchedReducer.swift` - Supplies the shared host to watched and date-seek requests.
- `AppPackage/Sources/HomeFeature/Toplists/ToplistsReducer.swift` - Supplies the shared host to toplist requests.
- `AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift` - Supplies the shared host to favorites and date-seek requests.
- `AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchReducer.swift` - Supplies the shared host to detail-search requests.
- `AppPackage/Tests/NetworkingFeatureTests/GalleryRequestBaselineTests.swift` - Updates required initializers and makes URL expectations explicitly host-scoped.
- `.planning/phases/08-architecture-hygiene-client-seams/08-03-SUMMARY.md` - Records implementation and verification evidence.

## Decisions Made

- Snapshotted `setting.galleryHost` before each effect so a request uses the same construction-time state semantics as its filter, keyword, and pagination inputs.
- Made the baseline host a deterministic `.ehentai` constant so request parity tests no longer depend on the transitional global host mirror.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated gallery request baseline construction sites**

- **Found during:** Task 2 implementation
- **Issue:** Requiring `host` on the request initializers made the existing `NetworkingFeatureTests` construction sites fail to compile, but the plan's file inventory omitted the baseline test file.
- **Fix:** Passed a deterministic explicit host to every baseline request and matching URL builder, and compared received URLs against that same host.
- **Files modified:** `AppPackage/Tests/NetworkingFeatureTests/GalleryRequestBaselineTests.swift`
- **Verification:** All 77 NetworkingFeature tests passed across nine suites.
- **Committed in:** `c1513e7f`

**2. [Rule 3 - Blocking] Adapted verification to the available package scheme and simulator**

- **Found during:** Task 1 verification
- **Issue:** The repository-root invocation selected the app project, which has no `AppPackage-Package` scheme, and the planned `iPhone 16` simulator is not installed.
- **Fix:** Ran the package scheme from `AppPackage` and used the installed `iPhone Air` simulator on iOS 26.5.
- **Files modified:** None
- **Verification:** The package build succeeded and all 77 NetworkingFeature tests passed.
- **Committed in:** No source change required.

---

**Total deviations:** 2 auto-fixed blocking issues.
**Impact on plan:** The production architecture stayed within scope; the added test edit was required by the new explicit initializer contract, and verification remained equivalent on the installed simulator.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Gallery-list requests no longer depend on the transitional `URLUtil` host default.
- Plans 08-04 through 08-06 can continue parameterizing the remaining request families.
- No blockers remain.

## Self-Check: PASSED

- All twelve gallery-list request structs declare `public let host: GalleryHost` and require it as the leading initializer argument.
- All eleven host-dependent request URL builders receive `host:` explicitly; DateSeek stores its supplied host alongside its supplied URL.
- Every gallery-list construction site in production and NetworkingFeature baselines supplies an explicit host.
- Home state now owns a read-only shared Setting value; all other constructing reducers already had one.
- The package build succeeds with SwiftLint plugins enabled.
- NetworkingFeatureTests passes all 77 tests across nine suites.
- Task commits `8bc1c790` and `c1513e7f` exist in git history.
- `git diff --check` passes for both task commits.
- Modified source contains no new warning suppression, SwiftLint disable, force unwrap, TODO, FIXME, or placeholder.
- The concurrency review found no isolation, cancellation, or unstructured-task regressions; immutable host snapshots cross effect boundaries safely.
- Generated documentation contains no absolute home-directory paths or private local-project names.

---
*Phase: 08-architecture-hygiene-client-seams*
*Completed: 2026-07-14*
