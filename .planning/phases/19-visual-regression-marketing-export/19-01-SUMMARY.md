---
phase: 19-visual-regression-marketing-export
plan: "01"
subsystem: testing
tags: [visual-regression, snapshot, xctest, xctestplan, simulator]

requires: []
provides:
  - "`HostedWindowCapture` in VisualSnapshotSupport: host a SwiftUI root as the key window's root, settle (100 ms samples, 500 ms identical, at most 40 samples, else `timeout`), draw at scale 1, compare with `precision 0.9999`, one retry (`flaky`)"
  - "`SnapshotCoordinate` (key `<scenario>__<locale>__<size>__<orientation>__<device>__<appearance>`, baseline path `<device>/<locale>/<size>/<scenario>/<orientation>-<appearance>.png`) and `SnapshotResultWriter` (one `results.jsonl` line per coordinate)"
  - "`AccessibilityActionDriver` in VisualSnapshotSupport: performs a view's own named accessibility action in process"
  - "`SnapshotMatrixCase` base class: per-process configuration checks, pinned geometry per orientation, light and dark, candidate and compare modes, `EHPANDA_SNAPSHOT_SHIFT`, `_ONLY`, `_ORIENTATIONS`"
  - "`AppPackage/Tests/SnapshotMatrix.xctestplan` with 18 configurations `<locale>-<size>`; the plan is listed in the EhPanda scheme"
  - "Tracer `TracerSnapshotTests` (home-populated, agewall-unticked, comments-block-confirmation) and `ScenarioCatalog`"
  - "`19-01-MEASURE.md`: geometry proof, tracer runs, controlled shift, clone measurements"
affects: [19-02, 19-04, 19-05, 19-06, 19-07, 19-08, 19-09, 19-10, 19-12]

actuals:
  tokens: 70000
  tasks: 3
  commits: 3

tech-stack:
  added: []
  patterns:
    - "Language and text size per process (test-plan configuration); orientation and appearance in process"
    - "iPad orientation per process: the device is turned before launch and the process names its orientation"
    - "Scenarios that need a state behind an interaction reach it through the view's own accessibility action"

key-files:
  created:
    - AppPackage/Sources/VisualSnapshotSupport/HostedWindowCapture.swift
    - AppPackage/Sources/VisualSnapshotSupport/SnapshotCoordinate.swift
    - AppPackage/Sources/VisualSnapshotSupport/SnapshotResultWriter.swift
    - AppPackage/Sources/VisualSnapshotSupport/AccessibilityActionDriver.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/HostedWindowCaptureTests.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/SnapshotMatrixCase.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/TracerSnapshotTests.swift
    - AppPackage/Tests/SnapshotMatrix.xctestplan
    - .planning/phases/19-visual-regression-marketing-export/19-01-MEASURE.md
  modified:
    - EhPanda.xcodeproj/xcshareddata/xcschemes/EhPanda.xcscheme

key-decisions:
  - "iPadOS 27 refuses `requestGeometryUpdate` orientation changes in every windowing mode (UISceneErrorDomain 101) and `XCUIDevice` is not authorized in an app-hosted test. An iPad process therefore captures one orientation, the one the device was turned to before launch (Phase 17's rotation UI test), named by `EHPANDA_SNAPSHOT_ORIENTATIONS`. iPhone keeps both in one process. iPad units double to 36; 19-02's shard units become 54."
  - "The block confirmation is reached through the comment row's own accessibility action (`AccessibilityActionDriver`), which needs the app accessibility runtime on; each process asserts it (`accessibility-runtime`) next to Reduce Motion. The first comment is used: at `ja-accessibility5` the second is below the fold."
  - "iPad pins require Full Screen Apps (`SBMedusaMultitaskingEnabled` off): Windowed Apps gives a 20 pt bottom inset instead of the pinned 25 pt."
  - "With three tracer classes XCTest used one clone at every worker count 2 to 4, so the measurement shows clone cost (about 40 to 50 s per invocation) and picture stability across N, not speed-up. 19-04 measures with full shards."

patterns-established:
  - "A matrix test reads its mode, output, references, shift, filter and orientations from `EHPANDA_SNAPSHOT_*` (passed with the `TEST_RUNNER_` prefix); compare mode never writes into the references"

requirements-completed: []

coverage:
  - id: D1
    description: "HostedWindowCapture settles, captures at 1x and compares with one retry; a timed-out or differing first pass is retried and marked flaky when the second passes"
    requirement: VIS-18-01
    verification:
      - kind: unit
        ref: "AppPackage/Tests/VisualSnapshotTests/Matrix/HostedWindowCaptureTests.swift (9 passed on $PHONE; TracerSnapshotTests skips without EHPANDA_SNAPSHOT_MODE)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Each process asserts language, text size, Reduce Motion, accessibility runtime and the fixed date; each orientation reaches the pinned geometry before capture"
    requirement: CAP-17-01
    verification:
      - kind: integration
        ref: "TracerSnapshotTests on $PHONE en-large, ja-accessibility5, de-xSmall and on $PAD portrait and landscape (19-01-MEASURE.md, Geometry proof)"
        status: pass
    human_judgment: false
  - id: D3
    description: "The tracer records, then compares twice with 0 mismatches on both devices; a 1-point shift of the age wall is reported changed"
    requirement: VIS-18-01
    verification:
      - kind: integration
        ref: "19-01-MEASURE.md, Tracer runs and Controlled shift ($PHONE 12/12 twice; $PAD 6/6 twice per orientation; shift: changed on 4 + 2 + 2 coordinates)"
        status: pass
    human_judgment: false
  - id: D4
    description: "18 `<locale>-<size>` configurations in SnapshotMatrix.xctestplan, listed in the EhPanda scheme"
    requirement: CAP-17-02
    verification:
      - kind: integration
        ref: "Tracer runs in en-large, ja-accessibility5 and de-xSmall pass their configuration checks"
        status: pass
    human_judgment: false
  - id: D5
    description: "Clone runs at worker counts 1 to 4 with per-picture time, memory and picture identity recorded"
    verification:
      - kind: other
        ref: "19-01-MEASURE.md, Clones"
        status: pass
    human_judgment: false

duration: multi-session
completed: 2026-11-07
status: complete
---

# Phase 19 Plan 01: Hosted-window capture and the tracer Summary

**The key-window capture with settle and one retry is committed API; an 18-configuration test plan and a 3-scenario
tracer record, then compare cleanly on both simulators, and a 1-point shift is caught.**

## Performance

- **Tasks:** 3
- **Files created or modified:** 11

## Accomplishments

- `HostedWindowCapture`, `SnapshotCoordinate`, `SnapshotResultWriter` and `AccessibilityActionDriver` in
  VisualSnapshotSupport.
- `SnapshotMatrixCase` with configuration and geometry checks; `SnapshotMatrix.xctestplan` with 18 configurations.
- Tracer green twice on `$PHONE` and `$PAD` (both orientations); the controlled shift is `changed` on both attempts.
- Local clone measurement in `19-01-MEASURE.md`.

## Task Commits

1. **Task 1: Host, settle, capture and compare** - `3ed2d5f5c` (feat)
2. **Task 2: Matrix base class, test plan and tracer** - `7876a08a1` (test)
3. **Task 3: Local measurement** - `56261d13b` (docs)

## Decisions Made

See `key-decisions`.

## Deviations from Plan

1. **iPad orientation per process (technical call, Research §3 left to the developer).** iPadOS refuses
   programmatic rotation, so the iPad does not reach both orientations in one process. The iPad runs once per
   orientation after the device is turned. Verified: the iPad reaches both pinned geometries this way.
2. **`AccessibilityActionDriver.swift` added** (not in `files_modified`): needed to open the block confirmation
   without UI testing in an app-hosted test.
3. **Clones:** the plan expects one class per clone at N = 2 to 4; XCTest used one clone for the 3 tracer classes
   at every N. Recorded as found; 19-04 measures with full shards.
4. **Simulator settings** (documented in `19-01-MEASURE.md`): Reduce Motion on, app accessibility runtime on, iPad
   Full Screen Apps.

## Issues Encountered

- The first `comments-block-confirmation` landscape picture after rotation sometimes times out settling once and
  passes on the retry (`flaky`). Flagged for 19-07.

## User Setup Required

None.

## Next Phase Readiness

19-02 can build the runner and shards on this base; the shard unit count is 54 (18 iPhone + 36 iPad).
