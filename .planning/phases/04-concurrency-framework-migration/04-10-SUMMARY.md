---
phase: 04-concurrency-framework-migration
plan: 10
subsystem: reducers
tags: [tca, swift-concurrency, typed-throws, home, search, favorites]

requires:
  - phase: 04-concurrency-framework-migration
    provides: Parity-proven typed async request layer
provides:
  - Typed async request consumption across 21 Home, Search, and Favorites effects
  - Explicit AppError do/catch conversion with unchanged Done actions
affects: [04-13, 04-14]

tech-stack:
  added: []
  patterns:
    - Explicit do throws AppError inside TCA run effects
    - Existing Result action payloads constructed in success and catch arms

key-files:
  created:
    - .planning/phases/04-concurrency-framework-migration/04-10-SUMMARY.md
  modified:
    - AppPackage/Sources/HomeFeature/HomeReducer+Body.swift
    - AppPackage/Sources/HomeFeature/Toplists/ToplistsReducer.swift
    - AppPackage/Sources/HomeFeature/Popular/PopularReducer.swift
    - AppPackage/Sources/HomeFeature/Watched/WatchedReducer.swift
    - AppPackage/Sources/HomeFeature/History/HistoryReducer.swift
    - AppPackage/Sources/HomeFeature/Frontpage/FrontpageReducer.swift
    - AppPackage/Sources/SearchFeature/SearchRootReducer.swift
    - AppPackage/Sources/SearchFeature/SearchReducer.swift
    - AppPackage/Sources/FavoritesFeature/FavoritesReducer.swift

key-decisions:
  - "Done action payloads and handlers remain Result-based; only request acquisition inside effects changed."
  - "Every effect uses explicit do throws(AppError), with no casts or unknown fallbacks."

requirements-completed: [CONC-01]

coverage:
  - id: D1
    description: "Fourteen Home effects consume typed async requests with unchanged reducer actions"
    requirement: CONC-01
    verification:
      - kind: build
        ref: "AppFeature iOS Simulator build"
        status: pass
      - kind: other
        ref: "Zero HomeFeature legacyResponse or AppError-cast grep gate"
        status: pass
    human_judgment: false
  - id: D2
    description: "Seven Search and Favorites effects consume typed async requests with unchanged tests"
    requirement: CONC-01
    verification:
      - kind: unit
        ref: "Full AppPackage iOS Simulator test suite"
        status: pass
      - kind: other
        ref: "Zero SearchFeature/FavoritesFeature legacyResponse grep gate"
        status: pass
    human_judgment: false

duration: 7min
completed: 2026-07-13
status: complete
---

# Phase 04 Plan 10: Home, Search, and Favorites Consumer Switch Summary

**Twenty-one reducer effects now consume typed-throws requests while preserving their exact Result actions and state-machine handlers.**

## Performance

- **Duration:** 7 min
- **Completed:** 2026-07-13
- **Tasks:** 2
- **Files:** 9

## Accomplishments

- Converted all 14 HomeFeature request effects to explicit typed do/catch acquisition.
- Converted all four SearchFeature and three FavoritesFeature request effects.
- Preserved every cancellable modifier, capture list, Done action shape, and Result handler.
- Removed all facade calls and AppError casts from the three feature areas.

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `e1657b13` | Switch Home effects to typed async |
| 2 | `eb1f41fa` | Switch Search and Favorites effects to typed async |

## Deviations from Plan

None.

## Validation Results

- SwiftLint over all nine modified source files — **passed**, 0 violations.
- Home facade/cast grep gate — **passed**, zero matches and 14 typed do/catch sites.
- Search/Favorites facade grep gate — **passed**, zero matches and 7 typed do/catch sites.
- AppFeature generic iOS Simulator build — **passed**.
- Full AppPackage iOS Simulator suite — **passed** (`TEST SUCCEEDED`); no test files changed.

## Issues Encountered

None.

## Next Phase Readiness

- Home, Search, and Favorites no longer depend on the legacy request facade.
- Remaining consumer areas can follow the same proven effect convention.

## Self-Check: PASSED

- Twenty-one explicit typed do/catch sites exist across the nine files.
- No facade call or AppError cast remains in the scoped feature directories.
- Both task commits and all declared files exist.
