---
phase: 09-correctness-structured-error-handling
plan: 05
subsystem: clients
tags: [swift, typed-throws, app-error, file-client, networking]

requires:
  - phase: 09-04
    provides: App-root ErrorInfo routing and the nearest-surface structured error convention
provides:
  - Typed AppError propagation for FileClient decode, read, write, and removal operations
  - Explicit parse-failure propagation for NetworkingFeature JSON serialization and metadata decoding
  - Just-cause documentation for four intentional parse-with-fallback survivors
affects: [09-06, 09-11, structured-error-handling, optional-try]

tech-stack:
  added: []
  patterns:
    - Typed-throwing dependency endpoints carry file failures to the owning reducer
    - Shared JSON helpers map Foundation serialization errors once to AppError.parseFailed

key-files:
  created: []
  modified:
    - AppPackage/Sources/FileClient/FileClient.swift
    - AppPackage/Sources/FileClient/TagTranslation+ChtConverted.swift
    - AppPackage/Sources/NetworkingFeature/Request.swift
    - AppPackage/Sources/NetworkingFeature/Request+Account.swift
    - AppPackage/Sources/NetworkingFeature/Request+Detail.swift
    - AppPackage/Sources/NetworkingFeature/Request+GData.swift
    - AppPackage/Sources/NetworkingFeature/Request+Image.swift

key-decisions:
  - "FileClient uses fixed operation descriptors in AppError context so failures never disclose a file path."
  - "Missing cached translations recover through the existing remote fetch, while removal failures reach SettingFeature state."
  - "HTML repair, greeting, archive funds, and Chinese conversion remain optional because each has an explicit behavior-preserving fallback."

patterns-established:
  - "File dependency endpoints declare throws(AppError), and callers make the recovery or presentation decision."
  - "Intentional try? fallback sites carry an immediately adjacent just-cause comment."

requirements-completed: [QUAL-04]

coverage:
  - id: D1
    description: FileClient file and decode failures propagate as AppError while successful import, cache, rebuild, conversion, and removal behavior remains intact.
    requirement: QUAL-04
    verification:
      - kind: unit
        ref: "xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:FileClientTests"
        status: pass
    human_judgment: false
  - id: D2
    description: NetworkingFeature JSON failures propagate as parse failures while request retry, chunking, and response fallback semantics remain unchanged.
    requirement: QUAL-04
    verification:
      - kind: integration
        ref: "xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:NetworkingFeatureTests"
        status: pass
    human_judgment: false

duration: 1h15m
completed: 2026-07-15
status: complete
---

# Phase 09 Plan 05: File and Networking Error Sweep Summary

**File and JSON failures now cross typed AppError boundaries, while four intentional fallback parses remain explicitly documented and behavior-preserving.**

## Performance

- **Duration:** 1h 15m
- **Started:** 2026-07-15T06:35:00Z
- **Completed:** 2026-07-15T07:50:20Z
- **Tasks:** 2
- **Files modified:** 11

## Accomplishments

- Replaced seven silent FileClient operations with typed file-operation failures and carried them into SettingFeature's existing recovery/state boundaries.
- Replaced six NetworkingFeature JSON probes with shared typed parse-failure mapping without changing request counts, retry placement, or response semantics.
- Retained and documented exactly four intentional fallbacks: Chinese conversion, UTF-8 repair, optional greeting enrichment, and optional archive-funds enrichment.
- Kept diagnostic reasons free of credentials, URLs, and local filesystem paths.

## Task Commits

Each task was committed atomically:

1. **Task 1: FileClient try? sweep** - `5c39ff48` (refactor)
2. **Task 2: NetworkingFeature try? sweep** - `af886d1b` (refactor)

## Files Created/Modified

- `AppPackage/Sources/FileClient/FileClient.swift` - Makes decode, cache, read, write, and removal failures typed and propagating.
- `AppPackage/Sources/FileClient/TagTranslation+ChtConverted.swift` - Documents the behavior-preserving conversion fallback.
- `AppPackage/Sources/SettingFeature/SettingReducer+Body.swift` - Recovers a missing cache through remote fetch and receives removal failures.
- `AppPackage/Sources/SettingFeature/SettingReducer+Helpers.swift` - Awaits the typed cache/build endpoint directly.
- `AppPackage/Sources/NetworkingFeature/Request.swift` - Centralizes typed JSON failure mapping and documents UTF-8 repair fallback.
- `AppPackage/Sources/NetworkingFeature/Request+Account.swift` - Propagates three request-body serialization failures.
- `AppPackage/Sources/NetworkingFeature/Request+Detail.swift` - Documents two optional response-enrichment fallbacks.
- `AppPackage/Sources/NetworkingFeature/Request+GData.swift` - Propagates request-body serialization failure.
- `AppPackage/Sources/NetworkingFeature/Request+Image.swift` - Propagates request-body serialization failure.
- `AppPackage/Tests/FileClientTests/FileClientTests.swift` - Covers typed file failures and unchanged happy paths.
- `AppPackage/Tests/SettingFeatureTests/SettingReducerNavigationTests.swift` - Updates the controlled missing-cache dependency for the typed endpoint.

## Decisions Made

- Used fixed, semantic operation descriptors for `.fileOperationFailed` rather than interpolating an underlying error or URL, satisfying the phase's disclosure threat mitigation.
- Kept the existing `Result`-returning import endpoint because it already carries AppError to its reducer; the remaining FileClient endpoints now use `throws(AppError)` directly.
- Treated an absent cached translation file as recoverable at the reducer: the explicit catch continues into the existing remote update fetch.
- Mapped JSON request-body and metadata serialization failures to `.parseFailed`; network acquisition failures continue to map through the existing retry-aware fetch boundary.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Propagated typed FileClient signatures into their owning reducer**
- **Found during:** Task 1 (FileClient try? sweep)
- **Issue:** Converting the nonthrowing cache, load, and remove endpoints without updating SettingFeature left production callers uncompilable and would not satisfy D-12's nearest-surface decision rule.
- **Fix:** Updated the cache builder to throw through `fetchTagTranslatorDone`, made missing-cache recovery explicit before the existing remote fetch, and carried removal failure into SettingFeature state.
- **Files modified:** `SettingReducer+Body.swift`, `SettingReducer+Helpers.swift`
- **Verification:** FileClientTests passed and the package test build compiled SettingFeature.
- **Committed in:** `5c39ff48`

**2. [Rule 3 - Blocking] Updated the controlled missing-cache test dependency**
- **Found during:** Task 1 verification
- **Issue:** A SettingFeature test override still returned `nil` after the endpoint became typed-throwing.
- **Fix:** The override now throws the same fixed missing-cache AppError exercised by production.
- **Files modified:** `SettingReducerNavigationTests.swift`
- **Verification:** FileClientTests passed with every package test target compiling.
- **Committed in:** `5c39ff48`

---

**Total deviations:** 2 auto-fixed (2 blocking)
**Impact on plan:** Both changes were the minimum caller propagation required by the planned typed endpoint conversion; no unrelated behavior or architecture changed.

## Issues Encountered

- The plan's package test command omitted a destination. The installed iPhone Air iOS 26.5 simulator was used for both module suites.
- Typed-throwing closure literals require explicit thrown-error annotations in Swift; named live implementations and explicitly typed test/noop closures preserve compiler-enforced `AppError` boundaries without lint warnings.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- FileClient and NetworkingFeature now contribute only four reviewed, commented `try?` survivors to the Phase 11 lint ratchet.
- The DownloadClient sweep can apply the same fixed-descriptor, nearest-surface, typed-boundary pattern.

## Self-Check: PASSED

- Task commits `5c39ff48` and `af886d1b` exist.
- FileClientTests and NetworkingFeatureTests pass on the iPhone Air iOS 26.5 simulator.
- Every surviving scoped `try?` has an adjacent just-cause comment.
- No new SwiftLint suppression exists.

---
*Phase: 09-correctness-structured-error-handling*
*Completed: 2026-07-15*
