---
phase: 13-deep-link-hardening
plan: 03
subsystem: deep-link-routing
tags: [swift, composable-architecture, dependencies, swiftpm, swift-testing]

requires:
  - phase: 13-deep-link-hardening
    plan: 01
    provides: Exact-host GalleryURLParser and normalized gallery route facts
provides:
  - Direct GalleryURLParser consumption across app, comments, reading, and download flows
  - Complete removal of the injected URLClient dependency and Swift package module
  - Reducer tests exercising production URL parsing instead of URLClient overrides
affects: [13-04-deep-link-policy-wiring, 13-05-routing-coordination, app-package-graph]

tech-stack:
  added: []
  patterns: [pure parser namespace, direct deterministic parsing, dependency ceremony removal]

key-files:
  created: []
  modified:
    - AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift
    - AppPackage/Sources/DetailFeature/Comments/CommentsReducer.swift
    - AppPackage/Sources/ReadingFeature/ReadingReducer+ImageFetch.swift
    - AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift
    - AppPackage/Package.swift

key-decisions:
  - "Normalized route.url is passed into gallery fetches so custom-scheme opens retain the parser's HTTPS normalization."
  - "The browser fallback, initial-tab fallback, silent unsupported-link no-op, cancellation structure, and existing sleeps remain unchanged for strict seam-swap parity."
  - "Reducer tests no longer override parsing; fixtures now flow through GalleryURLParser exactly as production does."

patterns-established:
  - "Pure URL interpretation is called directly from reducers and clients rather than modeled as an injected dependency."
  - "Unparseable gallery-link analysis preserves the former nil page/comment deep-link result until policy changes land separately."

requirements-completed: [SC-1]

coverage:
  - id: D1
    description: "Every former URLClient consumer routes through GalleryURLParser while preserving existing destination, fallback, timing, and MPV behavior."
    requirement: SC-1
    verification:
      - kind: integration
        ref: "xcodebuild build -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -skipMacroValidation"
        status: pass
      - kind: unit
        ref: "xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -skipMacroValidation -only-testing:AppFeatureTests -only-testing:DownloadsFeatureTests -only-testing:ParserFeatureTests"
        status: pass
    human_judgment: false
  - id: D2
    description: "The URLClient source directory, target, package dependencies, imports, and test overrides are fully removed."
    requirement: SC-1
    verification:
      - kind: other
        ref: "test ! -d AppPackage/Sources/URLClient && ! rg 'urlClient|URLClient' AppPackage/Sources AppPackage/Tests AppPackage/Package.swift"
        status: pass
      - kind: integration
        ref: "xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -skipMacroValidation"
        status: pass
      - kind: other
        ref: "SwiftLint 0.62.2 lint --strict --config .swiftlint.yml AppPackage/Sources AppPackage/Tests"
        status: pass
    human_judgment: false

duration: 19 min
completed: 2026-07-23
status: complete
---

# Phase 13 Plan 03: URLClient Migration Summary

**Exact-host gallery parsing now runs directly at every routing seam, with the obsolete injected client and its package target removed at strict behavior parity**

## Performance

- **Duration:** 19 min
- **Started:** 2026-07-23T02:10:00Z
- **Completed:** 2026-07-23T02:29:13Z
- **Tasks:** 2
- **Files modified:** 16

## Accomplishments

- Migrated app presentation, launch automation, comments links, reading MPV detection, and download source resolution to direct `GalleryURLParser` calls.
- Deleted the complete `URLClient` module and removed every Swift package dependency, import, injected property, and test override.
- Proved the seam swap with affected-target tests, the full default unit plan, a clean app build, and strict source/test lint.

## Task Commits

Each task was committed atomically:

1. **Task 1: Migrate the six source call sites to GalleryURLParser at behavior parity** - `77db8b33` (refactor)
2. **Task 2: Delete URLClient and migrate its dependent tests and package graph** - `264dad69` (refactor)

## Files Created/Modified

- `AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift` - Parses once, uses the normalized route URL, and preserves both deliberate sleeps and unsupported-link no-op behavior.
- `AppPackage/Sources/AppFeature/DataFlow/AppReducer.swift` - Uses the real parser for launch-automation eligibility while retaining initial-tab fallback.
- `AppPackage/Sources/DetailFeature/Comments/CommentsReducer.swift` - Uses normalized routes while preserving the browser fallback for unsupported links.
- `AppPackage/Sources/ReadingFeature/ReadingReducer.swift` - Removes the obsolete injected parser dependency.
- `AppPackage/Sources/ReadingFeature/ReadingReducer+ImageFetch.swift` - Uses the pure MPV path predicate directly without changing cancellation or effect ordering.
- `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionSupport.swift` - Uses the same direct MPV predicate for download source selection.
- `AppPackage/Package.swift` - Removes the URLClient module case, target, and all production/test dependencies.
- `AppPackage/Sources/URLClient/` - Deleted the obsolete source module and its SwiftLint forwarding config.
- Seven existing reducer/parser test files - Removed URLClient imports and overrides; MPV expectations now call `GalleryURLParser` directly.

## Decisions Made

- Used `route.url` after parsing rather than the input URL, preserving the former custom-scheme-to-HTTPS normalization.
- Kept unsupported explicit opens silent in this plan, retained the comments browser fallback and launch initial-tab fallback, and left both magic sleeps untouched for their dedicated later plans.
- Removed every artificial test parser override. No test assertion changed because an override was load-bearing; only the MPV assertion's called symbol changed from the removed client to the pure parser.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Xcode rejected package macros when the plan's bare build command was used. Re-running with the repository's established `-skipMacroValidation` flag produced a successful build.
- A first manual lint invocation included `AppPackage/.build` dependency checkouts. The corrected repository-owned scope, `AppPackage/Sources AppPackage/Tests`, passed strict lint with zero violations.

## Known Stubs

None. The scan found only established state defaults and optional reset values; no placeholder data was introduced.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Plan 13-04 can now apply explicit-open versus clipboard failure policy at one hardened parser boundary.
- No blockers remain; the browser fallback, initial-tab fallback, cancellation identifiers, effect ordering, and deliberate timing delays are intact.

## Self-Check: PASSED

- Confirmed `77db8b33` and `264dad69` exist in git history.
- Confirmed `AppPackage/Sources/URLClient/` is absent.
- Confirmed `GalleryURLParser.swift` exists and no `urlClient` or `URLClient` identifier remains in package sources, tests, or `Package.swift`.
- Confirmed affected tests, full default unit tests, build, and strict repository-owned source/test lint pass.

---
*Phase: 13-deep-link-hardening*
*Completed: 2026-07-23*
