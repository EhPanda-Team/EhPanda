---
phase: 08-architecture-hygiene-client-seams
plan: 06
subsystem: networking
tags: [gallery-host, networking, parser, cookies, swift-testing]

# Dependency graph
requires:
  - phase: 08-architecture-hygiene-client-seams
    provides: Explicit GalleryHost threading through Detail request flows
provides:
  - Host-explicit image, gdata, metadata, and torrent requests
  - Host-explicit date-seek parsing and skip-server cookie writes
  - Host-global-free NetworkingFeature, ParserFeature, and CookieClient request layers
affects: [08-07, 08-08, NetworkingFeature, ReadingFeature, DownloadClient]

# Tech tracking
tech-stack:
  added: []
  patterns: [caller-owned host snapshots, explicit request inputs, host-scoped cookie writes]

key-files:
  created:
    - .planning/phases/08-architecture-hygiene-client-seams/08-06-SUMMARY.md
  modified:
    - AppPackage/Sources/NetworkingFeature/Request+Image.swift
    - AppPackage/Sources/NetworkingFeature/Request+GData.swift
    - AppPackage/Sources/NetworkingFeature/Request+GalleriesMetadata.swift
    - AppPackage/Sources/NetworkingFeature/Request+Detail.swift
    - AppPackage/Sources/NetworkingFeature/Request+Gallery.swift
    - AppPackage/Sources/ParserFeature/Parser+Shared.swift
    - AppPackage/Sources/CookieClient/CookieClient.swift
    - AppPackage/Sources/ReadingFeature/ReadingReducer+ImageFetch.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient.swift
    - AppPackage/Sources/DetailFeature/Torrents/TorrentsReducer.swift
    - AppPackage/Sources/HomeFeature/History/HistoryReducer.swift
    - AppPackage/Sources/SearchFeature/SearchRootReducer.swift
    - AppPackage/Tests/NetworkingFeatureTests/DetailRequestBaselineTests.swift
    - AppPackage/Tests/NetworkingFeatureTests/GalleriesMetadataBaselineTests.swift
    - AppPackage/Tests/NetworkingFeatureTests/GalleriesMetadataDecodeTests.swift
    - AppPackage/Tests/NetworkingFeatureTests/ImageRequestBaselineTests.swift

key-decisions:
  - "Reader, history, search, torrents, and download flows snapshot GalleryHost when constructing host-dependent requests."
  - "Saved-download refreshes use their manifest host, while the live DownloadClient version-metadata closure resolves the current shared setting."
  - "Metadata decoding receives GalleryHost explicitly so decoded gallery URLs remain tied to the originating request host."

patterns-established:
  - "Host-explicit request seam: request types store GalleryHost and derive URLs only from it."
  - "Async request callers snapshot shared host state before entering effects."

requirements-completed: [HYG-01]

coverage:
  - id: D1
    description: Remaining image, gdata, metadata, and torrent requests derive host-sensitive URLs only from an explicit GalleryHost.
    requirement: HYG-01
    verification:
      - kind: integration
        ref: "cd AppPackage && xcodebuild build -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: other
        ref: "Static audit of required GalleryHost properties and host-taking URL construction"
        status: pass
    human_judgment: false
  - id: D2
    description: Reading, download, torrents, history, search, and date-seek callers supply the selected host without changing effect ordering or cancellation behavior.
    requirement: HYG-01
    verification:
      - kind: integration
        ref: "cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:ReadingFeatureTests"
        status: pass
      - kind: other
        ref: "Host-global and bare host-derived Defaults.URL source sweeps across NetworkingFeature, ParserFeature, and CookieClient"
        status: pass
    human_judgment: false
  - id: D3
    description: Host-sensitive request and decoder baselines prove deterministic E-Hentai and ExHentai URL behavior.
    requirement: HYG-01
    verification:
      - kind: integration
        ref: "cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:NetworkingFeatureTests"
        status: pass
    human_judgment: false

# Metrics
duration: 9min
completed: 2026-07-14
status: complete
---

# Phase 08 Plan 06: Remaining Request Host Seams Summary

**The request, parser, and cookie layers now receive gallery host selection explicitly, with production callers supplying stable host snapshots and request baselines proving parity.**

## Performance

- **Duration:** 9 min
- **Started:** 2026-07-14T08:50:08Z
- **Completed:** 2026-07-14T08:58:47Z
- **Tasks:** 2
- **Files modified:** 18

## Accomplishments

- Added required `GalleryHost` inputs to the remaining image-refetch, MPV, gdata, galleries-metadata, version-metadata, and torrents request paths.
- Made date-seek parsing and skip-server cookie writes require their host instead of consulting the transitional global.
- Threaded host snapshots from Reading, downloads, torrents, history, search, and gallery request callers without changing retry, cancellation, or effect ordering.
- Removed every `Defaults.URL.host` read and every bare host-derived `Defaults.URL` property listed by the plan from NetworkingFeature, ParserFeature, and CookieClient.
- Kept all 18 ReadingFeature tests and all 77 NetworkingFeature tests passing on the installed simulator.

## Task Commits

1. **Task 1: Thread host through the remaining request readers and production callers** - `cd802e7f` (refactor)
2. **Task 2: Update explicit-host request and decoder baselines** - `bc8ea4c8` (test)

## Files Created/Modified

- `AppPackage/Sources/NetworkingFeature/Request+Image.swift` - Stores explicit hosts for normal-image refetch and MPV requests.
- `AppPackage/Sources/NetworkingFeature/Request+GData.swift` - Derives the gdata endpoint from the supplied host.
- `AppPackage/Sources/NetworkingFeature/Request+GalleriesMetadata.swift` - Threads host through request execution and decoded gallery URL construction.
- `AppPackage/Sources/NetworkingFeature/Request+Detail.swift` - Makes version-metadata and torrent requests host-explicit.
- `AppPackage/Sources/NetworkingFeature/Request+Gallery.swift` - Supplies the request host to date-seek parsing.
- `AppPackage/Sources/ParserFeature/Parser+Shared.swift` - Requires a date-seek host URL.
- `AppPackage/Sources/CookieClient/CookieClient.swift` - Scopes skip-server cookie writes to the caller-selected host.
- `AppPackage/Sources/ReadingFeature/ReadingReducer+ImageFetch.swift` - Snapshots and supplies the reading host to requests and cookie writes.
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift` - Supplies saved-download hosts to version refreshes.
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` - Supplies download payload hosts to image requests.
- `AppPackage/Sources/DownloadClient/DownloadClient.swift` - Resolves the current shared host for live version-metadata fetches.
- `AppPackage/Sources/DetailFeature/Torrents/TorrentsReducer.swift` - Reads shared settings and supplies the selected torrent host.
- `AppPackage/Sources/HomeFeature/History/HistoryReducer.swift` - Snapshots the selected host for metadata requests.
- `AppPackage/Sources/SearchFeature/SearchRootReducer.swift` - Snapshots the selected host for metadata requests.
- `AppPackage/Tests/NetworkingFeatureTests/*.swift` - Makes affected request and decoder baselines explicitly host-scoped.
- `.planning/phases/08-architecture-hygiene-client-seams/08-06-SUMMARY.md` - Records implementation and verification evidence.

## Decisions Made

- Request construction owns an immutable host snapshot so later setting changes cannot redirect an in-flight operation.
- Saved downloads use the host stored in their payload, preserving the gallery origin across later setting changes.
- Galleries-metadata decoding receives the request host because gallery model URLs are part of the host-sensitive response interpretation.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Updated production callers together with required request interfaces**

- **Found during:** Task 1 implementation
- **Issue:** Making the remaining request, parser, and cookie signatures require a host made the package uncompilable until every production construction site supplied one.
- **Fix:** Threaded host through all affected callers in the same atomic, buildable source commit; Task 2 then updated deterministic test baselines.
- **Files modified:** ReadingFeature, DownloadClient, DetailFeature, HomeFeature, SearchFeature, and gallery request caller files listed above.
- **Verification:** The package build and both focused test suites succeeded.
- **Committed in:** `cd802e7f`

**2. [Rule 2 - Missing Critical] Covered additional metadata and version-metadata callers discovered by the complete host-reader inventory**

- **Found during:** Task 1 implementation
- **Issue:** The plan's primary file list named the reader, download support, and torrents callers, but requiring host on shared metadata/version-metadata APIs also affected history, search, download refresh, and the live DownloadClient closure.
- **Fix:** Supplied request-origin or current shared hosts at every discovered construction site rather than retaining a compatibility default.
- **Files modified:** `HistoryReducer.swift`, `SearchRootReducer.swift`, `DownloadClient+ExecutionFetch.swift`, and `DownloadClient.swift`.
- **Verification:** Source sweeps returned zero forbidden readers, and build plus focused tests passed.
- **Committed in:** `cd802e7f`

**3. [Rule 3 - Blocking] Adapted verification to the installed simulator**

- **Found during:** Task 1 verification
- **Issue:** The planned iPhone 16 destination is not installed in this environment.
- **Fix:** Ran the same package build and focused tests sequentially on the available iPhone Air simulator with iOS 26.5.
- **Files modified:** None.
- **Verification:** Build succeeded; ReadingFeatureTests passed 18 tests in three suites; NetworkingFeatureTests passed 77 tests in nine suites.
- **Committed in:** No source change required.

---

**Total deviations:** 3 auto-fixed issues (two blocking, one missing critical coverage).
**Impact on plan:** All additional edits were required callers or deterministic baselines for the planned explicit-host interfaces; no unrelated behavior or scope was added.

## Issues Encountered

- The first sandboxed NetworkingFeatureTests retry lost CoreSimulator access; rerunning with simulator access succeeded without code changes.
- A baseline assertion initially referenced an unavailable test import; comparing against `GalleryHost.exhentai.url.host` kept the assertion focused and compiled cleanly.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- NetworkingFeature, ParserFeature, and CookieClient no longer read the transitional host global or the plan's bare host-derived URL properties.
- Plan 08-07 can drain the remaining view/reducer host mirror reads before the 08-08 teardown.
- No blockers remain.

## Self-Check: PASSED

- The exact host-global and host-derived source sweeps from the plan return no matches.
- All affected requests, parser calls, and cookie writes require and receive explicit host values.
- The AppPackage build succeeds on the installed simulator.
- ReadingFeatureTests passes all 18 tests across three suites.
- NetworkingFeatureTests passes all 77 tests across nine suites.
- Task commits `cd802e7f` and `bc8ea4c8` exist in git history and pass `git show --check`.
- Changed lines add no warning suppression, TODO, FIXME, placeholder, or compatibility fallback.
- The concurrency review found no cancellation, isolation, or unstructured-task regressions; immutable host values cross effect boundaries safely.
- Generated documentation contains no absolute home-directory paths or private local-project names.

---
*Phase: 08-architecture-hygiene-client-seams*
*Completed: 2026-07-14*
