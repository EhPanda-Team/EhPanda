---
phase: 04-concurrency-framework-migration
plan: 11
subsystem: reducers
tags: [tca, swift-concurrency, typed-throws, detail, reading]

requires:
  - phase: 04-concurrency-framework-migration
    provides: Parity-proven typed async request layer
provides:
  - Typed async request consumption across 18 Detail effects
  - Typed async request consumption across six Reading image effects and one app route effect
affects: [04-13, 04-14]

tech-stack:
  added: []
  patterns:
    - Explicit typed do/catch around high-frequency image effects
    - Void request success rebuilt as the existing Result success payload

key-files:
  created:
    - .planning/phases/04-concurrency-framework-migration/04-11-SUMMARY.md
  modified:
    - AppPackage/Sources/DetailFeature/DetailReducer+Fetch.swift
    - AppPackage/Sources/DetailFeature/Torrents/TorrentsReducer.swift
    - AppPackage/Sources/DetailFeature/Comments/CommentsReducer.swift
    - AppPackage/Sources/DetailFeature/Archives/ArchivesReducer.swift
    - AppPackage/Sources/DetailFeature/DetailSearch/DetailSearchReducer.swift
    - AppPackage/Sources/DetailFeature/Previews/PreviewsReducer.swift
    - AppPackage/Sources/ReadingFeature/ReadingReducer+ImageFetch.swift
    - AppPackage/Sources/AppFeature/DataFlow/AppRouteReducer.swift

key-decisions:
  - "Reader image effects preserve every cancellation identifier and send ordering while only changing acquisition."
  - "DownloadClient and file-operation run/catch effects remain outside the request consumer sweep."

requirements-completed: [CONC-01]

coverage:
  - id: D1
    description: "Eighteen Detail effects consume typed async requests without changing Done handlers or download effects"
    requirement: CONC-01
    verification:
      - kind: build
        ref: "AppFeature iOS Simulator build"
        status: pass
      - kind: other
        ref: "Zero DetailFeature facade/cast grep gate"
        status: pass
    human_judgment: false
  - id: D2
    description: "Six Reading image effects and one route effect preserve cancellation and Result sends"
    requirement: CONC-01
    verification:
      - kind: unit
        ref: "Full AppPackage iOS Simulator test suite including ReadingFeatureTests"
        status: pass
      - kind: other
        ref: "Zero ReadingFeature/AppFeature facade grep gate"
        status: pass
    human_judgment: false

duration: 7min
completed: 2026-07-13
status: complete
---

# Phase 04 Plan 11: Detail, Reading, and App Consumer Switch Summary

**Twenty-five Detail, Reading, and app-route effects now consume typed-throws requests with their Result actions and cancellation behavior intact.**

## Performance

- **Duration:** 7 min
- **Completed:** 2026-07-13
- **Tasks:** 2
- **Files:** 8

## Accomplishments

- Converted 18 DetailFeature request effects without touching action handlers or download/file effects.
- Converted all six high-frequency Reading image request effects while retaining cancellation ids and send order.
- Converted the app route reverse-gallery effect.
- Eliminated facade calls and AppError casts from all scoped feature directories.

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | `25a53ac8` | Switch Detail effects to typed async |
| 2 | `aa75ad81` | Switch Reading and App effects to typed async |

## Deviations from Plan

### [Rule 3 - Blocking] Imported AppModels in split reducer files

- **Found during:** Task 1 and Task 2 build verification
- **Issue:** The split Detail and Reading reducer files previously reached AppError only indirectly and did not import its defining module.
- **Fix:** Added direct `AppModels` imports so the explicit typed catch syntax resolves cleanly.
- **Verification:** SwiftLint, AppFeature build, and the full suite pass.

**Total deviations:** 1 compile-blocking import fix. **Impact:** Dependency usage is now explicit; behavior is unchanged.

## Validation Results

- SwiftLint over all eight modified files — **passed**, 0 violations.
- Detail facade/cast grep gate — **passed**, zero matches and 18 typed sites.
- Reading/App facade grep gate — **passed**, zero matches and 7 typed sites.
- AppFeature generic iOS Simulator build — **passed**.
- Full AppPackage iOS Simulator suite — **passed** (`TEST SUCCEEDED`); no tests changed.

## Issues Encountered

None outstanding.

## Next Phase Readiness

- All high-frequency Detail and Reading request consumers are off the legacy facade.
- Remaining service/client consumer migration can proceed before Combine teardown.

## Self-Check: PASSED

- Twenty-five explicit typed do/catch sites exist across the eight files.
- No scoped facade call or AppError cast remains.
- Both task commits and all declared files exist.
