---
phase: 17-localized-screenshot-capture-harness
plan: "24"
subsystem: testing
tags: [simulator, geometry, rendering-pin, python, xctest]
requires:
  - phase: 17-01
    provides: Verified app-hosted capture, external rotation and simulator lifecycle
provides:
  - Actual native geometry measurements for both families and orientations
  - Immutable rendering pin with fresh-destination validation and separate observations
affects: [17-02, 17-05, 17-07, regression, marketing, ci]
actuals:
  tokens: 14355
  tasks: 2
  commits: 5
tech-stack:
  added: []
  patterns: [immutable rendering contract, named geometry attachments, fresh destination resolution]
key-files:
  created:
    - Scripts/visual/environment.py
    - AppPackage/Tests/VisualSnapshotTests/GeometryTests.swift
    - Scripts/visual/test_environment.py
    - Scripts/visual/regression-environment.json
    - Scripts/visual/README.md
  modified: []
key-decisions:
  - Reuse the verified native gate's serial invocation and simulator lifecycle implementation.
  - Keep native rendering fields in the tracked pin and local destination IDs/evidence in separate observations.
  - Compare every pinned characteristic and link observations to original pin bytes by SHA-256.
  - Execute phone before tablet explicitly, independently of JSON object key ordering.
patterns-established:
  - Author the pin only after the real measurement producer passes and is committed.
  - Validation never regenerates its input or reuses prior run-local destination IDs.
requirements-completed: [CAP-17-02, CAP-17-03]
coverage:
  - id: D1
    description: Both device families and orientations have actual-window geometry and rendering metadata.
    requirement: CAP-17-02
    verification:
      - kind: integration
        ref: Scripts/visual/environment.py measure --output .capture/environment-measurement; four measurements and ten native passes
        status: pass
    human_judgment: false
  - id: D2
    description: An immutable tracked rendering pin resolves fresh devices and rejects rendering drift before capture.
    requirement: CAP-17-03
    verification:
      - kind: integration
        ref: Scripts/visual/environment.py validate --environment Scripts/visual/regression-environment.json --output .capture/environment-pin-check
        status: pass
      - kind: unit
        ref: Scripts/visual/test_environment.py; 28 tests including immutable bytes, every-field drift and input ordering
        status: pass
    human_judgment: false
duration: 16min
completed: 2026-10-04
status: complete
source_head: 3e69dc69d3
---

# Phase 17 Plan 24: Measured rendering environment Summary

**Real phone/tablet geometry now produces an immutable, fully validated rendering pin with no local UDIDs or paths.**

## Performance

- First implementation commit: 2026-10-04T09:19:10Z.
- Completion: 2026-10-04, approximately 16 minutes later.
- Tasks: 2/2; files: 5; implementation/test commits: 5.
- Actuals: 14,355 diff characters/4 units over the five delivered files, not model usage tokens.

## Accomplishments

- GeometryTests measures the real app-hosted window on iPhone Air and iPad Pro 11-inch (M5), in portrait and landscape. It verifies attachment, stable layout, native pixel rectangles and inherited classes/categories.
- environment.py resolves current destination IDs, retains named geometry attachments and xcresults, and reuses serial native rotation, single-pass tests and simulator restoration.
- The tracked pin records exact Xcode/Swift/SDK/runtime build, model/hardware identifiers, geometry, font metrics and deterministic reference settings. Validation measures again and compares every field without modifying input bytes.

## Task Commits

1. Task 1 RED: `425ae4b4e9` — 22 contract tests demonstrate the missing producer/schema.
2. Task 1 GREEN: `6bcc20cebb` — implemented actual measurements, schema, comparison, immutable validation and 27 passing contract tests.
3. Task 2 exposed a producer bug; regression RED: `ce41eb7a00` — canonical JSON sorts ipad first, reproducing test dispatch before build setup.
4. Producer correction: `f0b74d8fc9` — explicit phone-first execution; 28 contract tests and complete real producer measurements pass before commit.
5. Task 2 GREEN: `3e69dc69d3` — measured tracked pin and commands, validated against fresh real destinations before commit.

## Verification

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.0.0.app/Contents/Developer
python3 -B -m unittest discover -s Scripts/visual -p test_environment.py
python3 -B Scripts/visual/environment.py measure --output .capture/environment-measurement
python3 -B Scripts/visual/environment.py validate \
  --environment Scripts/visual/regression-environment.json \
  --output .capture/environment-pin-check
```

Both real commands pass on the final producer. Each output has four geometry tests plus six rotation/restore tests, zero failures/skips/expected failures/Repetition/runtimeWarnings and empty compiler/lint diagnostics. Independent audit JSON checks source bytes, named attachments, all observed geometry and both simulator lifecycle restorations. All 28 Python tests pass; strict SwiftLint finds zero violations in GeometryTests.

| Family | Orientation | Points | Pixels | Safe area top/left/bottom/right | H/V class |
|---|---|---|---|---|---|
| iPhone Air | Portrait | 420×912 | 1260×2736 | 68/0/34/0 | compact/regular |
| iPhone Air | Landscape | 912×420 | 2736×1260 | 0/68/20/68 | regular/compact |
| iPad Pro 11-inch (M5) | Portrait | 834×1210 | 1668×2420 | 32/0/25/0 | regular/regular |
| iPad Pro 11-inch (M5) | Landscape | 1210×834 | 2420×1668 | 32/0/25/0 | regular/regular |

Xcode 27.0 build 27A266a; Swift 6.4 (`swiftlang-6.4.0.34.1`, `clang-2100.3.34.1`); iOS runtime 27.0 build 24A434. Reference settings: en_US, GMT, fixed fixture date 2025-01-01T00:00:00Z, Large system Dynamic Type, light appearance, system fonts and animations disabled. Body/caption1/title1 metrics, Bold Text, legibility weight and gamut are measured and pinned.

Pin SHA-256: **`ffd7689fcaf9a312202fdfbf9787f0198711fd477d1e72a2a013851df85a394a`**.
The same bytes survive both the initial failed validation and final successful validation. The final observation's pinSHA256 matches the tracked input. Repeated measurements have identical rendering fields. All run-local IDs and paths remain outside the pin.

## Decisions and Deviations

The repository uses `Scripts/` with uppercase S; commands and artifacts follow the actual directory. The approved producer/consumer split is preserved. Task 2's real validation exposed reliance on dictionary insertion order; execution now explicitly follows the approved phone-then-tablet sequence. The producer was remeasured and committed before Task 2 resumed. No acceptance threshold, model, geometry or pin value was relaxed.

## Issues Encountered

The first metadata lookup omitted an explicit simulator destination, producing an Xcode selection warning. Adding the simulator destination corrected the command; subsequent actual measurement passed. The sorted-pin failure is retained at `/tmp/ehpanda-phase17-environment-pin-order-failed/`; its pin and simulator state remained intact. Earlier successful measurements are retained under `/tmp/ehpanda-phase17-environment-measurement-first/` and `/tmp/ehpanda-phase17-environment-measurement-before-order-fix/`. Current canonical evidence is under the two .capture directories above.

Inline review: `17-24-REVIEW.md`, no open finding. The four reserved staged entries are preserved. No production UI, approved baseline or marketing asset changed.

## User Setup Required

Use the selected Xcode/runtime and one available simulator for each pinned model. The README documents exact commands and failed-preflight recovery. Validation requires a new output directory and never implicitly edits the pin.

## Next Plan Readiness

Ready for **17-02**, which owns the regression matrix runner and consumes this pin. Plans 17-05/17-07 later use the same unchanged input for marketing. Run observations cannot substitute for a pin. Phase progress is 2/24 plans; shared CAP-17-02 and CAP-17-03 remain open until all declaring sibling plans finish.
