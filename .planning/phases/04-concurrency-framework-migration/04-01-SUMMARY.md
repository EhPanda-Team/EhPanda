---
phase: 04-concurrency-framework-migration
plan: 01
subsystem: networking
tags: [swift-concurrency, combine, urlsession, dependency-injection, tca]

requires: []
provides:
  - Transitional legacyResponse() Result facade with all 65 former call sites renamed
  - Injectable URLSession seam on all 44 Request conformers
  - NetworkingFeature with no hard-coded shared-session dataTaskPublisher fetches
affects: [04-02, 04-03, 04-04, 04-05, 04-06, 04-07, 04-08, 04-09, 04-13]

tech-stack:
  added: []
  patterns:
    - Defaulted URLSession injection at each request boundary
    - Transitional Result facade naming for incremental typed-throws migration

key-files:
  created:
    - .planning/phases/04-concurrency-framework-migration/04-01-SUMMARY.md
  modified:
    - AppPackage/Sources/NetworkingFeature/Request.swift
    - AppPackage/Sources/NetworkingFeature/Request+Account.swift
    - AppPackage/Sources/NetworkingFeature/Request+Detail.swift
    - AppPackage/Sources/NetworkingFeature/Request+Gallery.swift
    - AppPackage/Sources/NetworkingFeature/Request+Image.swift
    - AppPackage/Sources/HomeFeature/Popular/PopularReducer.swift
    - AppPackage/Tests/ParserFeatureTests/Other/DownloadPageErrorParserTests.swift

key-decisions:
  - "Renamed only the Result facade to legacyResponse(), preserving its behavior while reserving response() for the typed-throws implementation."
  - "Stored injected sessions on every Request conformer, including DataRequest, so the all-44-request offline test seam is complete."

patterns-established:
  - "Request session seam: accept a trailing urlSession: URLSession = .shared parameter and fetch through the stored session."
  - "Incremental migration seam: legacyResponse() remains the sole Result-returning facade until plan 04-13 removes it."

requirements-completed: [CONC-01]

coverage:
  - id: D1
    description: "The Result facade and all 65 former response() call sites use legacyResponse()."
    requirement: CONC-01
    verification:
      - kind: integration
        ref: "xcodebuild build -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator'"
        status: pass
      - kind: other
        ref: "grep counts: 65 Sources occurrences, 1 Tests occurrence, 0 old .response() calls"
        status: pass
    human_judgment: false
  - id: D2
    description: "All 44 Request conformers accept an injected URLSession and no NetworkingFeature fetch hard-codes URLSession.shared.dataTaskPublisher."
    requirement: CONC-01
    verification:
      - kind: integration
        ref: "xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air'"
        status: pass
      - kind: other
        ref: "grep counts: 44 Request structs, 44 urlSession properties, 0 shared-session dataTaskPublisher calls"
        status: pass
    human_judgment: false

duration: 11min
completed: 2026-07-13
status: complete
---

# Phase 04 Plan 01: Request Migration Seams Summary

**A compiler-green transitional Result facade plus an offline-testable URLSession seam across all 44 requests**

## Performance

- **Duration:** 11 min
- **Started:** 2026-07-12T15:25:29Z
- **Completed:** 2026-07-12T15:36:23Z
- **Tasks:** 2
- **Files modified:** 29 production files

## Accomplishments

- Renamed the Result-returning request facade to `legacyResponse()` and mechanically updated all 64 source call sites plus the parser test call.
- Added defaulted, stored `URLSession` injection to all 44 `Request` structs without changing existing call sites or request-pipeline behavior.
- Routed every NetworkingFeature `dataTaskPublisher` fetch through its request's stored session; the full package suite, including DF semantics S1-S7, remains green.

## Task Commits

Each task was committed atomically:

1. **Task 1: Rename the Result facade to legacyResponse() everywhere** - `2511f0d6` (refactor)
2. **Task 2: Injectable URLSession seam on every hard-coded request** - `3f595816` (refactor)

## Files Created/Modified

- `AppPackage/Sources/NetworkingFeature/Request.swift` - Renames the Result facade and injects sessions into the four routine requests.
- `AppPackage/Sources/NetworkingFeature/Request+Account.swift` - Injects sessions into all 14 account requests.
- `AppPackage/Sources/NetworkingFeature/Request+Detail.swift` - Completes the session seam across all seven detail requests.
- `AppPackage/Sources/NetworkingFeature/Request+Gallery.swift` - Injects sessions into all 12 gallery-list requests.
- `AppPackage/Sources/NetworkingFeature/Request+Image.swift` - Adds the missing session seam to `DataRequest`.
- 23 request-consumer source files - Rename their facade calls without changing effect or parser behavior.
- `AppPackage/Tests/ParserFeatureTests/Other/DownloadPageErrorParserTests.swift` - Renames the parser-error facade call.

## Decisions Made

- Kept `legacyResponse()` as a pure rename of the existing Result facade so later typed-throws bodies can adopt `response()` incrementally without shadowing unmigrated callers.
- Used immutable `public let urlSession` storage for newly injected requests; the default remains `.shared`, so existing production behavior is unchanged.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Wrapped four renamed calls to satisfy the lint-as-error line limit**

- **Found during:** Task 1 verification
- **Issue:** The longer transitional method name pushed four existing single-line calls beyond the 120-character SwiftLint limit.
- **Fix:** Wrapped only the affected request initializers; no expression or behavior changed.
- **Files modified:** `LoginReducer.swift`, `ReadingReducer+ImageFetch.swift`, `SearchReducer.swift`, `PreviewsReducer.swift`
- **Verification:** AppFeature build and SwiftLint build-tool plug-in passed.
- **Committed in:** `2511f0d6`

**2. [Rule 2 - Missing Critical] Added the omitted session seam to DataRequest**

- **Found during:** Task 2 acceptance verification
- **Issue:** The plan described `Request+Image.swift` as fully injected, but `DataRequest` still hard-coded `URLSession.shared.dataTaskPublisher`; leaving it unchanged would fail both the zero-shared-fetch gate and the all-44-request invariant.
- **Fix:** Added the same defaulted `URLSession` parameter and stored property used by every other request, then routed the fetch through it.
- **Files modified:** `AppPackage/Sources/NetworkingFeature/Request+Image.swift`
- **Verification:** 44 request structs, 44 session properties, zero hard-coded shared-session publishers, and full suite green.
- **Committed in:** `3f595816`

---

**Total deviations:** 2 auto-fixed (1 blocking lint issue, 1 missing critical seam).
**Impact on plan:** Both fixes were required to satisfy the plan's own build and completeness gates; no request semantics changed.

## Issues Encountered

- The first AppFeature verification attempt could not reach CoreSimulator from the restricted process. Re-running with authorized simulator access completed successfully.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The per-request session seam is ready for plan 04-02's isolated counting `URLProtocol` harness.
- No blockers remain; all production defaults still use `URLSession.shared` through injection.

## Self-Check: PASSED

- Both task commits and the summary artifact exist.
- All acceptance counts, the AppFeature build, the full package suite, and coverage classification passed.

---
*Phase: 04-concurrency-framework-migration*
*Completed: 2026-07-13*
