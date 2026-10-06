---
phase: 17-localized-screenshot-capture-harness
plan: "02"
subsystem: testing
tags: [simulator, regression, render-server, vision, python, xctest, rendering-pin]
requires:
  - phase: 17-01
    provides: Verified app-hosted full-content capture, public fixtures and the native compatibility gate
  - phase: 17-24
    provides: Measured rendering pin with fresh-destination validation
provides:
  - Complete 576-coordinate candidate run of the hosted Home tracer with per-coordinate outcome and artifact accounting
  - Owned-row two-pass read verification and a shared full-content render settle
  - Rendering pin that records Reduce Motion, and a source guard that covers uncommitted build inputs
affects: [17-05, 17-07, 17-08, 17-09, 17-10, 17-11, regression, marketing, ci]
actuals:
  tasks: 2
  commits: 8
tech-stack:
  added: []
  patterns: [owned-row read verification, injected-clock settle rule, per-coordinate artwork export, pinned device settings, evidence-bounded OCR geometry]
key-files:
  created:
    - Scripts/visual/run-regression.py
    - Scripts/visual/contracts.py
    - Scripts/visual/test_contracts.py
    - AppPackage/Tests/VisualSnapshotTests/VisualMatrixTests.swift
    - AppPackage/Tests/VisualSnapshotTests/Resources/scenarios.json
    - AppPackage/Sources/VisualSnapshotSupport/RenderSettlement.swift
    - AppPackage/Tests/VisualSnapshotTests/RenderSettlementTests.swift
    - AppPackage/Tests/VisualSnapshotTests/HostedHierarchyTests.swift
    - AppPackage/Tests/VisualSnapshotTests/FixtureArtwork.swift
    - AppPackage/Tests/VisualSnapshotTests/FixtureArtworkTests.swift
  modified:
    - AppPackage/Sources/VisualSnapshotSupport/FullContentHost.swift
    - AppPackage/Sources/VisualSnapshotSupport/RenderServerCapture.swift
    - AppPackage/Sources/VisualSnapshotSupport/RenderedContentInspection.swift
    - AppPackage/Sources/VisualSnapshotSupport/PublicVisualFixtures.swift
    - AppPackage/Tests/VisualSnapshotTests/RenderServerCaptureTests.swift
    - AppPackage/Tests/VisualSnapshotTests/RenderedContentInspectionTests.swift
    - AppPackage/Tests/VisualSnapshotTests/FullContentFeasibilityTests.swift
    - AppPackage/Tests/VisualSnapshotTests/GeometryTests.swift
    - AppPackage/Sources/AppComponents/GalleryCover.swift
    - AppPackage/Sources/AppComponents/GalleryCoverMetrics.swift
    - AppPackage/Sources/AppComponents/GalleryCoverStyle.swift
    - AppPackage/Sources/HomeFeature/HomeView.swift
    - AppPackage/Sources/HomeFeature/HomeView+Sections.swift
    - Scripts/verify-full-content-capture.py
    - Scripts/visual/environment.py
    - Scripts/visual/test_environment.py
    - Scripts/visual/regression-environment.json
    - Scripts/visual/README.md
key-decisions:
  - A coordinate key is scenario, locale, size, orientation, family and theme; equal pixels never merge keys.
  - Fixture markers stay English-only at confidence 0.8 or higher; the localized trailing heading uses one coordinate-language pass with exact identity (owner, 2026-10-04).
  - Every read keeps the native viewport size; read 0 owns the whole native viewport and later origins stay on a 16-pixel grid (orchestrator, 2026-10-05).
  - Two complete passes compare same-rect reads; the owned rows of every read gate, read 0 gates its whole read, and whole-read digests are evidence (owner, 2026-10-05).
  - The grown window settles under the same 500 ms rule as the native viewport before the verified capture; no runner quiet period (owner, 2026-10-05).
  - Production covers size in whole device pixels and clip with one shared continuous shape; the carousel seeds from one viewport measurement.
  - Reduce Motion is part of the rendering pin (owner, 2026-10-06).
  - Each Vision box is kept to the window pixels its request analyzed (owner, 2026-10-06).
patterns-established:
  - The real error of a failed capture is read from capture-error.json, never from the XCTest failure text.
  - Device settings the pin depends on are documented with restore commands next to the pin.
  - OCR identifies and locates; geometry claims stay within the pixels that were analyzed.
requirements-completed: [CAP-17-02, CAP-17-03]
coverage:
  - id: D1
    description: The runner requests exactly 576 canonical coordinates per scenario, validates the pin before capture and accounts for every requested row, including interruption.
    requirement: CAP-17-02
    verification:
      - kind: unit
        ref: Scripts/visual/test_contracts.py and test_environment.py; 73 tests including empty input, silent no-op filters, zero matched tests, duplicates, canonical order, equal-pixel and adjacent-fixture identity, pin drift and source drift
        status: pass
    human_judgment: false
  - id: D2
    description: The complete hosted tracer captures all 576 coordinates on both families with the tracked pin and leaves references untouched.
    requirement: CAP-17-03
    verification:
      - kind: integration
        ref: run-regression.py --all --mode candidate --fixtures .capture/regression-v3 --environment Scripts/visual/regression-environment.json --output .capture/tracer-matrix-10; independent audit .capture/tracer-matrix-10/independent-audit.json
        status: pass
      - kind: integration
        ref: Scripts/verify-full-content-capture.py --output .capture/owned-row-gate-04; 32/32 coordinates, 63 iPhone and 60 iPad native tests
        status: pass
    human_judgment: false
duration: about 2 days (2026-10-04 to 2026-10-06)
completed: 2026-10-06
status: complete
source_head: 8eaea1f8ad
---

# Phase 17 Plan 02: Complete hosted tracer regression Summary

**All 576 coordinates of the hosted Home tracer capture through the pinned runner, with every read verified twice and every outcome accounted for.**

## Performance

- Task 1 RED: 2026-10-04T09:40:36Z; the final complete tracer finished 2026-10-06T07:46:40Z.
- Tasks: 2/2; source commits: 8; documentation commits: 18 (17 checkpoints and this completion record).
- Complete tracer: 3 h 49 min for 576 coordinates.

## Accomplishments

- `run-regression.py` enumerates the canonical 576 coordinates per scenario (six locales, twelve sizes, two orientations, two families, two themes). It validates the tracked pin through `environment.py` before loading fixtures, runs one xcodebuild at a time without retries, and writes a reasoned outcome for every requested row, even after an interrupt. Filters declare reduced coverage, and candidate output stays under `--output`.
- Run integrity: native sources, producer scripts, the pin and the fixture manifest are hashed before preflight and checked after preflight and after the last capture. The gate's source guard also hashes untracked, non-ignored build inputs.
- RenderServerCapture reads the grown window in equal native-viewport reads, composes owned rows, and verifies each read in two complete passes. FullContentHost settles the grown window before that capture and records every settle pass.
- Per-coordinate artwork export and byte-exact source comparison prove that covers render their own pixels. Production covers now size in whole device pixels and share their clip shape with the comparison.
- The vertical scroll host counts adjusted insets, matching the output height formula, so iPad Home at small sizes resolves its page.
- Reduce Motion is pinned on, which freezes the dark Home card's Metal gradient that disabling UIView animations cannot reach.
- OCR frames are kept to the pixels each Vision request analyzed, so an over-wide box at the image edge no longer reads as clipped content.

## Task Commits

1. Task 1 RED: `e93c2a2033`, coordinate and preflight contracts.
2. Task 1 GREEN: `624fddfed6`, pinned hosted regression runner, matrix test and localized heading pass.
3. Task 2 production fix: `6c588338c3`, the carousel seeds from one viewport measurement.
4. Task 2 production fix: `13a3645646`, gallery covers size in device pixels.
5. Task 2: `2cee63a9b8`, owned-row verification, full-content settle, artwork export and scroll host.
6. Task 2: `990024a798`, the gate hashes untracked native capture sources.
7. Task 2: `bee89ee82e`, Reduce Motion in the rendering pin.
8. Task 2: `8eaea1f8ad`, Vision boxes kept to their analyzed windows.

Each of the last five commits was verified in a temporary tree holding exactly its contents: a clean build with zero diagnostics and strict SwiftLint where its Swift differs, and the Python suites (`.capture/commit-trees-03/`). After each commit, the committed tree was compared byte for byte with its verified tree.

## Verification

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.0.0.app/Contents/Developer
python3 -B -m unittest discover -s Scripts/visual -p 'test_*.py'
python3 -B Scripts/verify-full-content-capture.py \
  --phone <iPhone Air UDID> --tablet <iPad Pro 11-inch (M5) UDID> \
  --derived-data <DerivedData> --output .capture/owned-row-gate-04
python3 -B Scripts/visual/run-regression.py --all --mode candidate \
  --fixtures .capture/regression-v3 \
  --environment Scripts/visual/regression-environment.json \
  --output .capture/tracer-matrix-10
```

The final complete tracer `.capture/tracer-matrix-10/` passes: 576 of 576 coordinates captured, none
failed or not applicable, coverage complete and references unchanged, on pin SHA-256
`5c507a4c0c5013fad010a19222ef7b8b1eec86d354b89fc1b7c07610567c725c`, in 3 h 49 min (2026-10-06,
03:57 to 07:46 UTC). All 592 native invocations pass with exactly one test each (10 environment, 6
rotation and restore, 576 captures), with zero failures, skips, expected failures, Repetition nodes,
runtime warnings or compiler and lint diagnostics.

The independent audit (`independent-audit.json`, produced by the copied `independent-audit.py`) finds
no problem. It checks the canonical coordinate set and order, the pinned geometry including Reduce
Motion in every coordinate, the environment observation against the pin, every invocation, census,
viewport parity, settle and read ledgers, artwork verification, artifact digests and sizes, simulator
lifecycles, unchanged native and runner sources, references and reserved entries:

| Measure | Result |
|---|---|
| Reads | 2,088; every owned-row digest matched in both passes; no whole-read digest differed |
| Full-content settle | No pass changed a read; 2 passes: 34, 3: 298, 4: 244; at most 1,031 ms |
| Artwork | 3,456 images, 265,172,088 compared pixels, all exact |
| Census | VH1 to VH6 exactly once and the localized trailing heading in every coordinate |
| Distinct images | 576 full-content images, none shared between coordinates |
| Devices | iPhone Shutdown, iPad Booted, both portrait and Large, as found |

| Family | Orientation | Coordinates | Reads per capture | Output height (px) |
|---|---|---|---|---|
| iPhone Air | Portrait | 144 | 2 to 4 | 4,039 to 8,183 |
| iPhone Air | Landscape | 144 | 5 to 10 | 3,865 to 7,216 |
| iPad Pro 11-inch (M5) | Portrait | 144 | 2 to 3 | 2,606 to 5,100 |
| iPad Pro 11-inch (M5) | Landscape | 144 | 2 to 4 | 2,606 to 4,534 |

The final-source compatibility gate `.capture/owned-row-gate-04/` passes with a clean build: 32 of 32
coordinates, 63 iPhone and 60 iPad native tests, 40 captures with 412 reads all matched, no settle pass
changing a read (at most 1,890 ms), unchanged sources and restored devices (its own
`independent-audit.json`). The Python suites pass 73 tests: 44 contract and 29 environment. Strict
SwiftLint over App, AppPackage sources and tests, EhPandaUITests and ShareExtension finds no violation.
No approved reference exists or was written; candidate output stays under `.capture/`.

## Decisions and Deviations

Every acceptance change came from an explicit owner approval or a recorded orchestrator disposition in
17-02-PLAN.md; none was inferred:

- 2026-10-04: localized trailing heading pass with exact identity and no confidence floor, while
  fixture markers keep English-only recognition at 0.8 (owner, options A to D).
- 2026-10-04 and 2026-10-05: native read geometry, coordinate artwork export, production cover pixel
  sizing, the production clip extent and equal native-viewport reads (orchestrator dispositions).
- 2026-10-05: same-rect two-pass verification replaces cross-origin seam equality, which equal reads
  cannot satisfy on glass rims and SF Symbols (owner).
- 2026-10-05: owned-row gating with read 0 gating its whole read, and a full-content settle under
  the shared 500 ms rule; the owner declined a runner quiet period.
- 2026-10-06: Reduce Motion is pinned on (owner); the pin gained four measured fields and a new
  SHA-256, authored from a real measurement and validated fresh.
- 2026-10-06: each Vision box is kept to the window it analyzed (owner).

Scope beyond the plan's original file list, each recorded in the plan: production fixes in
GalleryCover, GalleryCoverMetrics, GalleryCoverStyle, HomeView and HomeView+Sections; the new
RenderSettlement, FixtureArtwork and HostedHierarchy test support; GeometryTests, environment.py,
test_environment.py, the pin and its README for Reduce Motion. The gate's source guard now hashes
untracked, non-ignored build inputs; this gap was found by the gate audit, and no earlier result
depended on it. Apart from these decisions, no threshold, tolerance, retry or exclusion was added to
strict viewport parity or the census; the artwork source comparison excludes only the corner squares
of the production clip, derived from its actual path (orchestrator disposition, 2026-10-05).

## Issues Encountered

The complete tracer needed ten runs. Each failure was diagnosed from its retained evidence and fixed
at its cause before a fresh run; every failed run stays on disk unchanged:

| Run | Stopped at | Cause and fix |
|---|---|---|
| tracer-matrix | before any capture | simctl reads two content sizes back with different capitalization; case-insensitive comparison |
| tracer-matrix-02 | 1 captured | read-rectangle-dependent rasterization; native read geometry |
| tracer-matrix-03 | 43 captured | equal reads still differ on a glass rim; same-rect two-pass verification |
| tracer-matrix-04 | 144 captured | carousel opened on a provisional width; production carousel fix `6c588338c3` |
| tracer-matrix-05 | 160 captured | a glass rim cut by a read edge flipped under load; owned-row gating and full-content settle |
| tracer-matrix-06 | interrupted on purpose | background job limit; later runs launch detached |
| tracer-matrix-07 | 288 captured | scroll host ignored adjusted insets on iPad; inset-aware host |
| tracer-matrix-08 | 411 captured | dark card gradient bloom raced the settle rule; Reduce Motion pinned |
| tracer-matrix-09 | 455 captured | a Vision box 16 pt too wide past the image edge; boxes kept to their windows |
| tracer-matrix-10 | 576 captured | passed |

A cleanup on 2026-10-05 deleted every CoreSimulator device directory, DerivedData and /tmp. With owner
approval both pinned simulators were erased in place under their UDIDs and returned to the pin's
device settings, now documented in the README. Evidence that lived only under /tmp, cited by earlier
checkpoints in 17-02-INTEGRATION-NOTES.md, no longer exists; later evidence is under `.capture/`, with
the glass reread probe copied to `.capture/research/glass-reread/`.

Failed matrix tests often report SwiftUI's gesture `InvalidTransition` instead of the thrown error;
`capture-error.json` always holds the real one. The mechanism is unproven and nothing was changed for
it. One RED build named the pinned iPhone as its destination and booted it; it was shut down again,
and build-only steps now use a generic destination in a separate DerivedData. Inline review:
17-02-REVIEW.md, no open finding. The four reserved staged entries keep their recorded blob IDs.

## User Setup Required

The pinned simulators need three device settings that a new or erased simulator lacks: Reduce Motion on (both), dark appearance (iPhone) and Full Screen Apps (iPad). `Scripts/visual/README.md` lists the restore commands; environment validation stops the run before capture when any one is missing. The contract tests and the runner read the canonical fixture export at `.capture/regression-v3`, which is local run output. On a fresh checkout, run the native gate and extract the phone run's `phase17-public-fixtures` attachment into that directory.

## Next Plan Readiness

Ready for **17-03**, which acquires provisional real marketing fixtures and depends on this plan.
The runner and the native gate are the regression entry points for later plans: 17-11 adds the
native dispatcher, and 17-08 to 17-10 expand the scenario inventory beyond the one Home tracer.
Candidate output has not been promoted; approved references need the owner's review. Phase progress
is 3/24 plans; the shared CAP-17-02 and CAP-17-03 requirements stay open until every declaring plan
finishes.
