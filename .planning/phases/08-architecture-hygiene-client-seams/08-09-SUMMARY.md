---
phase: 08-architecture-hygiene-client-seams
plan: 09
subsystem: cache
tags: [swift-dependencies, actor, cache, swift-concurrency]
requires:
  - phase: 08-architecture-hygiene-client-seams
    provides: explicit host and injected view/client seams from plans 08-01 through 08-08
provides:
  - Injectable DataCache dependency with one canonical live actor
  - Cache consumers and purge observer sharing the same live cache
  - Per-test isolated DataCache use in download capture tests
affects: [image-client, library-client, download-client, reading-feature, testing]
tech-stack:
  added: []
  patterns:
    - Module-level canonical actor exposed through a DependencyKey
    - Dependency resolution at client construction and operation boundaries
key-files:
  created: []
  modified:
    - AppPackage/Package.swift
    - AppPackage/Sources/AppTools/DataCache.swift
    - AppPackage/Sources/ImageClient/ImageClient.swift
    - AppPackage/Sources/LibraryClient/LibraryClient.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Cache.swift
    - AppPackage/Sources/ReadingFeature/ReadingView.swift
    - AppPackage/Tests/DownloadClientTests/DownloadCoordinatorCaptureTests.swift
key-decisions:
  - "Expose one module-level DataCache actor through a computed DependencyKey live value so the purge observer and all live consumers share identity."
  - "Give test dependency resolution a fresh UUID-scoped temporary cache while behavior tests explicitly inject their own per-test actor."
patterns-established:
  - "Canonical actor dependency: a private module-level actor backs both DependencyKey.liveValue and non-dependency infrastructure that must share identity."
requirements-completed: [HYG-01]
coverage:
  - id: D1
    description: "DataCache is an injectable dependency whose live value and system-purge observer share one actor."
    requirement: HYG-01
    verification:
      - kind: other
        ref: "xcodebuild build -scheme AppTools -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: other
        ref: "Static acceptance checks for canonicalDataCache and DataCacheKey"
        status: pass
    human_judgment: false
  - id: D2
    description: "Image, library, download, reader, and purge paths use the coherent injected cache with no DataCache.shared source references."
    requirement: HYG-01
    verification:
      - kind: integration
        ref: "xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:DownloadsFeatureTests"
        status: pass
      - kind: other
        ref: "xcodebuild build -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: other
        ref: "rg -n 'DataCache\\.shared' AppPackage/Sources"
        status: pass
    human_judgment: false
metrics:
  duration: 12 min
  completed: 2026-07-14
status: complete
---

# Phase 8 Plan 09: DataCache Dependency Seam Summary

`DataCache` now enters the app through Swift Dependencies while its live consumers and system-purge observer retain one coherent actor identity.

## Performance

- **Duration:** 12 min
- **Started:** 2026-07-14T09:30:05Z
- **Completed:** 2026-07-14T09:41:51Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Replaced the process-wide `DataCache.shared` API with an injectable `dataCache` dependency backed by one canonical live actor.
- Migrated image, library, download, and reading consumers while keeping system-purge events on the same live cache.
- Isolated download capture tests with per-test cache actors and verified the affected package targets.

## Task Commits

1. **Task 1: Expose DataCache as an injected dependency** - `f11f907c`
2. **Task 2: Migrate cache consumers and prove coherence** - `a4458c7c`

**Plan metadata:** committed with this summary

## Files Created/Modified

- `AppPackage/Package.swift` - gives AppTools access to the Dependencies APIs exported by Composable Architecture.
- `AppPackage/Sources/AppTools/DataCache.swift` - defines the canonical live actor, dependency key, isolated test value, and purge observer integration.
- `AppPackage/Sources/ImageClient/ImageClient.swift` - resolves the cache when constructing each client variant and captures it safely in concurrent work.
- `AppPackage/Sources/LibraryClient/LibraryClient.swift` - resolves the cache for size and clearing operations.
- `AppPackage/Sources/DownloadClient/DownloadClient+Cache.swift` - resolves the cache for download image reads and removal.
- `AppPackage/Sources/ReadingFeature/ReadingView.swift` - reads animated-image data through the injected cache.
- `AppPackage/Tests/DownloadClientTests/DownloadCoordinatorCaptureTests.swift` - supplies a per-test cache through dependency overrides.

## Decisions Made

- A private module-level actor backs both `DataCacheKey.liveValue` and the system-purge observer, guaranteeing one live identity without preserving a public singleton API.
- The default test dependency creates a UUID-scoped temporary cache; tests that assert cache behavior inject their own actor explicitly.
- `ImageClient.live` copies the resolved actor into an immutable local before concurrent task capture, satisfying Swift 6 sendability checking.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added the package dependency needed to define the cache dependency key**
- **Found during:** Task 1
- **Issue:** AppTools did not depend on a product that exposes the Dependencies APIs.
- **Fix:** Added Composable Architecture as an AppTools target dependency.
- **Files modified:** `AppPackage/Package.swift`
- **Verification:** AppTools and the complete package build successfully.
- **Committed in:** `f11f907c`

**2. [Rule 3 - Blocking] Migrated existing capture tests away from the removed singleton**
- **Found during:** Task 2 verification
- **Issue:** Download capture tests still referenced `DataCache.shared`, preventing the suite from compiling after the API removal.
- **Fix:** Created a cache per test and supplied it with `withDependencies`.
- **Files modified:** `AppPackage/Tests/DownloadClientTests/DownloadCoordinatorCaptureTests.swift`
- **Verification:** `DownloadsFeatureTests` passes.
- **Committed in:** `a4458c7c`

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both fixes were necessary to expose the dependency and keep existing tests compatible; scope remained limited to the cache seam.

## Issues Encountered

- The plan's iPhone 16 simulator was unavailable, so verification used the installed iPhone Air simulator running iOS 26.5.
- Swift 6 rejected concurrent capture of the mutable dependency property wrapper; resolving once into an immutable actor reference fixed the root sendability issue.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The cache seam is ready for plan 08-10 and later client migrations.
- No blockers remain.

---
*Phase: 08-architecture-hygiene-client-seams*
*Completed: 2026-07-14*

## Self-Check: PASSED

- Both task commits are present in git history.
- All seven implementation files and this summary exist.
- Coverage classification reports both deliverables automatically covered.
- Package build, targeted tests, static acceptance checks, and diff checks pass.
