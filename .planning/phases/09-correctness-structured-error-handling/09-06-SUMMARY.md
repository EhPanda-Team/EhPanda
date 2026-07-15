---
phase: 09-correctness-structured-error-handling
plan: 06
subsystem: downloads
tags: [swift, app-error, download-store, filesystem, optional-try]

requires:
  - phase: 09-05
    provides: Typed file-operation boundaries and the adjacent just-cause convention
provides:
  - Semantic classification and just-cause documentation for all 16 DownloadStore optional failures
  - Preserved manifest discovery, validation, asset sanitation, and cleanup behavior
  - Verified DownloadFailure and download scheduling parity
affects: [09-07, 09-11, structured-error-handling, optional-try]

tech-stack:
  added: []
  patterns:
    - Optional filesystem probes document the exact fallback at the call site
    - Validation maps read and hash failures into the existing missing-files state

key-files:
  created: []
  modified:
    - AppPackage/Sources/DownloadClient/DownloadStore.swift
    - AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift

key-decisions:
  - "All 16 scoped try? sites are intentional probe, metadata, validation, or cleanup fallbacks; genuine manifest and page persistence already propagates through throwing APIs."
  - "Download validation continues to collapse manifest decode and hash-read failures into its established missing-files states rather than introducing a second error channel."

patterns-established:
  - "Every surviving try? has an immediately adjacent comment naming its behavior-preserving fallback."
  - "Cleanup failures remain secondary to the primary read, hash, or sanitization result."

requirements-completed: [QUAL-04]

coverage:
  - id: D1
    description: All DownloadStore optional failures are classified and documented without changing manifest, page, or scheduling behavior.
    requirement: QUAL-04
    verification:
      - kind: integration
        ref: "xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:DownloadsFeatureTests"
        status: pass
    human_judgment: false
  - id: D2
    description: Download validation preserves corrupted-manifest and corrupted-page mapping for read and hash failures.
    requirement: QUAL-04
    verification:
      - kind: integration
        ref: "xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:DownloadsFeatureTests"
        status: pass
    human_judgment: false

duration: 8min
completed: 2026-07-15
status: complete
---

# Phase 09 Plan 06: DownloadStore Optional Failure Sweep Summary

**All 16 DownloadStore optional failures now state their precise fallback while existing throwing persistence and DownloadFailure paths remain unchanged.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-07-15T07:55:00Z
- **Completed:** 2026-07-15T08:03:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Classified and documented all 14 `DownloadStore.swift` sites as intentional metadata, discovery, sanitation, or cleanup fallbacks.
- Classified both `DownloadStore+Operations.swift` sites as explicit conversions into the established corrupted-manifest or corrupted-page validation state.
- Preserved the existing throwing manifest/page write APIs and `DownloadFailure` mapping without adding a second error surface.
- Kept the deterministic download suite green: 250 tests across 52 suites passed.

## Task Commits

Each task was committed atomically:

1. **Task 1: Classify + convert DownloadStore.swift try? sites** - `1afa3249` (refactor)
2. **Task 2: DownloadStore+Operations.swift try? sweep** - `529ae507` (refactor)

## Files Created/Modified

- `AppPackage/Sources/DownloadClient/DownloadStore.swift` - Documents all 14 intentional optional filesystem and metadata fallbacks.
- `AppPackage/Sources/DownloadClient/DownloadStore+Operations.swift` - Documents both validation-state fallbacks.

## Decisions Made

- Kept all 16 scoped sites as documented survivors. None performs a genuine manifest or page persistence operation: those operations already use propagating `try` through throwing store APIs.
- Preserved filesystem discovery semantics in which unreadable unrelated folders are excluded, not promoted to a gallery-wide failure.
- Preserved validation as a nonthrowing diagnostic query: manifest decode failures map to corrupted manifest, while hash-read failures map to corrupted page image.
- Kept handle closing and rejected-asset deletion best-effort because a cleanup error must not replace the primary read, hash, or invalid-asset result.

## Deviations from Plan

None - plan execution classified every site as required. Semantic review found no bucket-(a) persistence failure among the 16 scoped `try?` expressions; all actual manifest/page persistence calls already propagate errors.

## Issues Encountered

- The plan's package test command omitted both the package working directory and a destination. Verification ran from `AppPackage` on the installed iPhone Air iOS 26.5 simulator.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- DownloadStore contributes 16 reviewed, commented survivors to the Phase 11 optional-try lint ratchet.
- DownloadFailure behavior and the download state machine remain ready for the remaining DownloadClient sweeps.

## Self-Check: PASSED

- Task commits `1afa3249` and `529ae507` exist.
- DownloadsFeatureTests passed with 250 tests across 52 suites on iPhone Air iOS 26.5.
- All 16 surviving scoped `try?` expressions have adjacent just-cause comments.
- No SwiftLint suppression was introduced.
- Both modified source files exist and contain no new stubs or threat surface.

---
*Phase: 09-correctness-structured-error-handling*
*Completed: 2026-07-15*
