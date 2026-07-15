---
phase: 09-correctness-structured-error-handling
plan: 07
subsystem: downloads
tags: [swift, app-error, download-client, networking, optional-try]

requires:
  - phase: 09-06
    provides: DownloadStore optional-failure classification and adjacent just-cause convention
provides:
  - Semantic classification and just-cause documentation for all 20 scoped DownloadClient optional failures
  - Preserved download validation, networking, page progress, cache, and public API behavior
  - Verified DownloadFailure and download reducer parity
affects: [09-08, 09-11, structured-error-handling, optional-try]

tech-stack:
  added: []
  patterns:
    - Optional validation probes document the exact conservative fallback at the call site
    - Cleanup failures remain secondary to the primary download or validation outcome

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidationHelpers.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Networking.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+Cache.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+BackgroundDownloads.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift
    - AppPackage/Sources/DownloadClient/DownloadClient.swift

key-decisions:
  - "All 20 scoped try? sites are intentional parsing probes, metadata probes, optional API fallbacks, cadence writes, or cleanup operations; existing user-facing and throwing failures already propagate through AppError or DownloadFailure."
  - "Cleanup and optional probe failures preserve the primary validation/download result instead of introducing a competing error surface."

patterns-established:
  - "Every surviving try? has an immediately adjacent comment naming its behavior-preserving fallback."
  - "Nonthrowing optional DownloadClient endpoints keep nil as their established remote or no-metadata fallback."

requirements-completed: [QUAL-04]

coverage:
  - id: D1
    description: All 20 scoped DownloadClient optional failures are classified and documented without changing networking, validation, or persistence behavior.
    requirement: QUAL-04
    verification:
      - kind: integration
        ref: "xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:DownloadsFeatureTests"
        status: pass
    human_judgment: false
  - id: D2
    description: Download reducers and clients preserve response-error, page-progress, cache-cleanup, and optional public API fallbacks.
    requirement: QUAL-04
    verification:
      - kind: integration
        ref: "DownloadsFeatureTests — 250 tests across 52 suites"
        status: pass
    human_judgment: false

duration: 6min
completed: 2026-07-15
status: complete
---

# Phase 09 Plan 07: DownloadClient Optional Failure Sweep Summary

**All 20 remaining DownloadClient optional failures now state their exact fallback while established AppError, DownloadFailure, and optional API behavior remains unchanged.**

## Performance

- **Duration:** 6 min
- **Started:** 2026-07-15T08:07:58Z
- **Completed:** 2026-07-15T08:13:22Z
- **Tasks:** 2
- **Files modified:** 10

## Accomplishments

- Classified and documented all response parsing, response metadata, rejected-file cleanup, and cadence-progress survivors in the validation/networking sweep.
- Classified and documented manifest reuse probes, repair seeding, cache cleanup, staged-file cleanup, and optional public API fallbacks in the remaining DownloadClient files.
- Preserved existing structured failure surfaces: genuine networking and validation failures still propagate as `AppError` or feed `DownloadFailure`; secondary probes and cleanup never replace them.
- Kept the deterministic download suite green: 250 tests across 52 suites passed after each task.

## Task Commits

Each task was committed atomically:

1. **Task 1: Validation + networking files sweep** - `0e5822a0` (refactor)
2. **Task 2: Remaining DownloadClient files sweep** - `6462b937` (refactor)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidation.swift` - Documents prefix, full-file, DOM, and placeholder fingerprint probes.
- `AppPackage/Sources/DownloadClient/DownloadClient+ResponseValidationHelpers.swift` - Documents DOM, quota-content, and file-size probes.
- `AppPackage/Sources/DownloadClient/DownloadClient+Networking.swift` - Documents rejected-file cleanup and deferred handle-close behavior.
- `AppPackage/Sources/DownloadClient/DownloadClient+PageDownload.swift` - Documents the opportunistic cadence flush before the forced persistence boundary.
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` - Documents manifest reuse, stale-folder cleanup, and repair-seed probes.
- `AppPackage/Sources/DownloadClient/DownloadClient+PersistenceNormalize.swift` - Documents invalid manifest fallback to fresh manifest creation.
- `AppPackage/Sources/DownloadClient/DownloadClient+Cache.swift` - Documents independent best-effort data-cache eviction.
- `AppPackage/Sources/DownloadClient/DownloadClient+BackgroundDownloads.swift` - Documents staged-file cleanup as secondary to recorded download failure.
- `AppPackage/Sources/DownloadClient/DownloadClient+PublicAPI.swift` - Documents fresh-manifest fallback when reuse probing fails.
- `AppPackage/Sources/DownloadClient/DownloadClient.swift` - Documents optional metadata and local-page URL API contracts.

## Decisions Made

- Kept all 20 scoped sites as documented survivors after semantic review. None is the authoritative networking, validation, manifest-write, or page-write boundary; those operations already propagate through throwing APIs and existing `AppError`/`DownloadFailure` surfaces.
- Preserved conservative response validation: failed optional reads decline content-based classification while status codes, headers, response URLs, and existing fallback parsers continue deciding the outcome.
- Preserved cleanup precedence: rejected temporary files, staged files, stale folders, cache entries, and deferred handle closure remain secondary to the primary result.
- Preserved nonthrowing client contracts: unavailable remote version metadata and local page URLs continue returning `nil`, allowing their established no-update and remote-page fallbacks.

## Deviations from Plan

Semantic review found no bucket-(a) failure hidden by these 20 `try?` expressions; authoritative network, validation, manifest persistence, and page persistence errors already propagate through adjacent throwing boundaries.

### Auto-fixed Issues

**1. [Rule 1 - Bug] Corrected inconsistent generated planning progress**

- **Found during:** Final state update
- **Issue:** The state updater reported 96% but wrote 54% into frontmatter and left the prose position on Plan 09-07.
- **Fix:** Reconciled frontmatter and prose to 87/91 plans (96%), completed Plan 09-07, and next Plan 09-08; normalized both new decision labels to Phase 09.
- **Files modified:** `.planning/STATE.md`
- **Verification:** Compared the seven Phase 09 summaries and 91-plan milestone total against both state representations.
- **Committed in:** Final metadata commit

---

**Total deviations:** 1 auto-fixed (1 Rule 1 bug)
**Impact on plan:** Planning metadata now matches the completed summary count; source scope and runtime behavior are unchanged.

## Issues Encountered

- The plan's package test command omitted both the package working directory and a destination. Verification ran from `AppPackage` on the installed iPhone Air iOS 26.5 simulator.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The remaining DownloadClient surface contributes 20 reviewed, commented survivors to the Phase 11 optional-try lint ratchet.
- Download networking, validation, cache, background transfer, and reducer behavior are ready for the remaining module sweeps.

## Self-Check: PASSED

- Task commits `0e5822a0` and `6462b937` exist.
- DownloadsFeatureTests passed twice with 250 tests across 52 suites on iPhone Air iOS 26.5.
- All 20 surviving scoped `try?` expressions have adjacent just-cause comments.
- No SwiftLint suppression, new logging, stub, package, or threat surface was introduced.
- All 10 modified source files exist.

---
*Phase: 09-correctness-structured-error-handling*
*Completed: 2026-07-15*
