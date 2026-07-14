---
phase: 08-architecture-hygiene-client-seams
plan: 10
subsystem: testing
tags: [swift-testing, image-client, data-cache, url-protocol]
requires:
  - phase: 08-architecture-hygiene-client-seams
    provides: injectable DataCache and ImageClient cache seam from plan 08-09
provides:
  - Dedicated lint-covered ImageClientTests package target
  - Deterministic cache, failure, placeholder, and cancellation coverage for ImageClient
  - Per-test DataCache isolation with decoded pixel-dimension assertions
affects: [image-client, data-cache, downloads-feature-tests, quality]
tech-stack:
  added: []
  patterns:
    - Per-test UUID-scoped DataCache actors for cache behavior tests
    - Session-scoped URLProtocol handlers behind a synchronized registry
key-files:
  created:
    - AppPackage/Tests/ImageClientTests/.swiftlint.yml
    - AppPackage/Tests/ImageClientTests/ImageClientTestHelpers.swift
    - AppPackage/Tests/ImageClientTests/ImageClientTests.swift
  modified:
    - AppPackage/Package.swift
    - AppPackage/Tests/DownloadsFeatureTests/ReaderImageDataTests.swift
key-decisions:
  - "Exercise ImageClient through an injected cache and URLSession while keeping one isolated DataCache actor per test."
  - "Render fixture PNGs at scale 1 so decoded CGImage dimensions remain exactly 2 by 2 on every simulator display scale."
patterns-established:
  - "Image cache tests assert CGImage pixel dimensions and never UIImage point size."
requirements-completed: [QUAL-02]
coverage:
  - id: D1
    description: "A dedicated ImageClientTests target is registered in Package.swift and covered by the repository SwiftLint configuration."
    requirement: QUAL-02
    verification:
      - kind: other
        ref: "xcodebuild build -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
      - kind: integration
        ref: "xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:ImageClientTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "ImageClient cache hits, misses, failures, placeholder fingerprints, and cancellation use isolated caches with pixel-accurate assertions."
    requirement: QUAL-02
    verification:
      - kind: unit
        ref: "AppPackage/Tests/ImageClientTests/ImageClientTests.swift#ImageClientTests"
        status: pass
      - kind: integration
        ref: "xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5'"
        status: pass
    human_judgment: false
metrics:
  duration: 7 min
  completed: 2026-07-14
status: complete
---

# Phase 8 Plan 10: ImageClient Seam Tests Summary

ImageClient now has a dedicated deterministic suite covering cache coherence, network failures, placeholder rejection, and cancellation without an AppFeature test dependency.

## Performance

- **Duration:** 7 min
- **Started:** 2026-07-14T09:48:12Z
- **Completed:** 2026-07-14T09:55:27Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- Added a dedicated `ImageClientTests` package target with project SwiftLint coverage and focused test helpers.
- Relocated the reader image cache tests out of `DownloadsFeatureTests` and removed their `@testable AppFeature` dependency.
- Proved cache hit/miss, primary-key storage, HTTP failure, invalid data, placeholder purge/rejection, and cancellation behavior with a fresh cache per test.
- Verified decoded images through `CGImage` pixel dimensions and passed both the targeted suite and the complete package suite.

## Task Commits

1. **Task 1: Wire the ImageClientTests target and helpers** - `02aa36a5`
2. **Task 2: Relocate and strengthen ImageClient seam coverage** - `21acbb24`

**Plan metadata:** committed with this summary

## Files Created/Modified

- `AppPackage/Package.swift` - registers the `ImageClientTests` module and test target dependencies.
- `AppPackage/Tests/ImageClientTests/.swiftlint.yml` - inherits the root SwiftLint configuration.
- `AppPackage/Tests/ImageClientTests/ImageClientTestHelpers.swift` - provides isolated caches, stubbed sessions, deterministic image bytes, fixtures, and URL protocols.
- `AppPackage/Tests/ImageClientTests/ImageClientTests.swift` - exercises the ImageClient/DataCache seam directly with Swift Testing.
- `AppPackage/Tests/DownloadsFeatureTests/ReaderImageDataTests.swift` - removed after all ImageClient-specific cases moved to their owning target.

## Decisions Made

- Each test constructs and injects its own UUID-scoped `DataCache`; suite serialization exists only because the URL protocol handler registry is shared.
- Success cases compare decoded `CGImage` width and height, while network request counts use Swift Testing confirmations rather than process-global counters.
- Cancellation coverage moved with the rest of the ImageClient cases so no client-specific behavior remains coupled to `DownloadsFeatureTests`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Made the PNG fixture deterministic in pixel space**
- **Found during:** Task 2 targeted test verification
- **Issue:** `UIGraphicsImageRenderer` inherited the simulator's 3x display scale, producing a 6-by-6 decoded image from a 2-by-2 point canvas.
- **Fix:** Set the renderer format scale to 1 before generating the fixture PNG.
- **Files modified:** `AppPackage/Tests/ImageClientTests/ImageClientTestHelpers.swift`
- **Verification:** All pixel-dimension assertions and the complete `ImageClientTests` suite pass.
- **Committed in:** `21acbb24`

**2. [Rule 1 - Bug] Corrected stale progress fields after the state updater**
- **Found during:** Plan metadata self-check
- **Issue:** The state query reported 95% progress but left stale percentage, next-plan, and progress-bar values in `STATE.md`.
- **Fix:** Reconciled those fields to plan 11 and 72 of 76 completed plans after all required state queries ran.
- **Files modified:** `.planning/STATE.md`
- **Verification:** State frontmatter and the human-readable current-position block agree with the summary count on disk.
- **Committed in:** Plan metadata commit

---

**Total deviations:** 2 auto-fixed (2 bugs)
**Impact on plan:** The fixes make pixel assertions deterministic and preserve accurate execution state without changing production behavior or scope.

## Issues Encountered

- The plan's iPhone 16 simulator was unavailable, so verification used the installed iPhone Air simulator running iOS 26.5.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- The ImageClient/DataCache seam has isolated client-layer coverage and is ready for the remaining phase 8 plans.
- No blockers remain.

---
*Phase: 08-architecture-hygiene-client-seams*
*Completed: 2026-07-14*

## Self-Check: PASSED

- Both task commits are present in git history.
- The three created test-target files and modified package manifest exist; the duplicate DownloadsFeature test file is absent.
- Targeted ImageClient tests, the full package test suite, package build, SwiftLint build-tool plugins, static acceptance checks, and diff checks pass.
