---
phase: 19-visual-regression-marketing-export
plan: "02"
subsystem: testing
tags: [snapshot, inventory, sharding, xctest, python]

requires:
  - phase: 19-01
    provides: "the capture core, SnapshotCoordinate, the tracer scenarios and 19-01-MEASURE.md"
provides:
  - "Schema-2 `scenarios.json`: 137 scenarios in 20 groups, each with its plan, state, signed-in flag and reasoned not-applicable rules; D-05 surfaces under `notCaptured`"
  - "`snapshot_matrix.py`: the 144 coordinates per scenario in the shared key and path format, with totals"
  - "`snapshot_shards.py`, `snapshot-cost.json` (source: model) and the committed 20-shard `snapshot-shards.json` over 54 per-process units, with `--check`"
  - "One catalog file per group (`ScenarioCatalog+Browsing/Library/Gallery/Settings.swift`) and `ScenarioInventoryTests`"
  - "`Scripts/visual/run-snapshot-local.sh` for 19-05 to 19-08"
affects: [19-04, 19-05, 19-06, 19-07, 19-08, 19-10, 19-13]

actuals:
  tokens: 85000
  tasks: 3
  commits: 4

tech-stack:
  added: []
  patterns:
    - "A plan that adds factories edits only its own group file; `ScenarioInventoryTests` checks that the ID's inventory `plan` matches the group file"
    - "Phase 17 readers read the schema-2 inventory through a fixture-scenario view (`contracts.legacy_scenarios`, `FixtureArtwork.fixtureScenarios`)"

key-files:
  created:
    - Scripts/visual/snapshot_matrix.py
    - Scripts/visual/test_snapshot_matrix.py
    - Scripts/visual/snapshot_shards.py
    - Scripts/visual/test_snapshot_shards.py
    - Scripts/visual/snapshot-cost.json
    - Scripts/visual/snapshot-shards.json
    - Scripts/visual/run-snapshot-local.sh
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Browsing.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Library.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Gallery.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Settings.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioInventoryTests.swift
  modified:
    - AppPackage/Tests/VisualSnapshotTests/Resources/scenarios.json
    - AppPackage/Tests/VisualSnapshotTests/FixtureArtwork.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/TracerSnapshotTests.swift
    - Scripts/visual/contracts.py
    - Scripts/visual/run-regression.py
    - Scripts/visual/test_contracts.py

key-decisions:
  - "The inventory has 137 scenarios (D-12 counts 136). Downloads has a move-to-folder dialog, not a retry confirmation, because retry lives on Gallery detail. General's remove-custom-translations confirmation is added. The app-wide alert is Toplists' jump-page alert."
  - "The Library sidebar and the gallery sheet are iPad-only, and the Library title menu is iPhone-only. The code decides these by device, not width, so the rules use `family`. The two-page reader spread needs a landscape window. These four rules remove 288 coordinates (72 each)."
  - "The D-05 surfaces (keyboard, live web content, share sheet, file importer) are listed under `notCaptured`, each with a reason. They are not per-coordinate rules, so no scenario loses every coordinate."
  - "Totals: 19,728 coordinates, 19,440 expected and 288 not applicable."
  - "A shard unit is one test process, because an iPad process captures only one orientation (19-01). An iPhone configuration is one unit with both orientations; an iPad configuration is two units, one per orientation. That gives 54 units (18 + 36). Each shard lists its `runs` (configuration and orientations) in configuration order, portrait first."
  - "Shards are assigned per device in proportion to cost (8 iPhone, 12 iPad), longest unit first, with ties broken by unit key. The largest shard is 1.160 × the mean. Estimates run from 39.1 to 48.0 minutes. Each timeout is twice the estimate, capped at 120 minutes; the largest is 96."
  - "The Phase 17 readers see only the fixture scenarios (today just `home-populated` → `home-finite`). Their outputs therefore do not change."

patterns-established:
  - "19-05 to 19-08 check each class with `run-snapshot-local.sh --mode candidate`, then `--mode compare --refs <candidate out>`"

requirements-completed: []

coverage:
  - id: D1
    description: "Schema-2 inventory, 130 to 150 unique IDs, every rule reasoned, plans 19-05 to 19-08; Phase 17 readers green"
    requirement: VIS-18-01
    verification:
      - kind: unit
        ref: "plan Task 1 inline check (ok 137); python3 -m unittest discover -s Scripts/visual -p 'test_*.py' (251 OK); FixtureArtworkTests 7/7"
        status: pass
    human_judgment: false
  - id: D2
    description: "Coordinate totals and a byte-identical 20-shard plan within 1.25 × the mean"
    requirement: VIS-18-01
    verification:
      - kind: unit
        ref: "test_snapshot_matrix.py, test_snapshot_shards.py; snapshot_shards.py --check; snapshot_matrix.py --totals"
        status: pass
    human_judgment: false
  - id: D3
    description: "Group catalog files, ScenarioInventoryTests, and the tracer through run-snapshot-local.sh"
    requirement: VIS-18-01
    verification:
      - kind: integration
        ref: "ScenarioInventoryTests 5/5 on $PHONE (VisualTests and SnapshotMatrix en-large); run-snapshot-local.sh --device phone --config en-large tracer classes: candidate recorded=12, compare passed=12 (1 flaky)"
        status: pass
    human_judgment: false
  - id: D4
    description: "Not-applicable rules are only D-05 limits and D-12 by-design rules"
    requirement: VIS-18-01
    verification:
      - kind: manual
        ref: "owner reads the totals and reasons in the 19-13 approval packet (T-19-03)"
        status: pending
    human_judgment: true

duration: one session
completed: 2026-11-07
status: complete
---

# Phase 19 Plan 02: Scenario inventory, coordinate totals and the 20-shard plan Summary

**The inventory is committed: 137 scenarios and 19,440 expected coordinates. Every not-applicable rule has a reason,
and the 20-shard plan is reproducible byte for byte. Plans 19-05 to 19-08 each get their own catalog file and a
local runner.**

## Performance

- **Tasks:** 3
- **Files created or modified:** 19

## Accomplishments

- **Inventory.** `scenarios.json` is schema 2. It has 137 scenarios in 20 groups and keeps `home-populated` with
  its fixture. Four by-design rules remove 288 coordinates, and four D-05 surfaces are listed under `notCaptured`.
- **Coordinates.** `snapshot_matrix.py` enumerates the coordinates and prints the totals. Its keys and paths match
  the Swift `SnapshotCoordinate` samples.
- **Shards.** `snapshot_shards.py` writes `snapshot-shards.json`: 20 shards, each on one device, covering 19,440
  pictures in 54 per-process runs. `--check` fails if the file is stale.
- **Catalog.** The catalog is split into four group files. The three tracer factories moved into Browsing and
  Gallery. `ScenarioInventoryTests` reports `134 inventory scenarios have no factory yet.` (137 − 3).
- **Local runner.** `run-snapshot-local.sh` waits for any other `xcodebuild` run and applies the 19-01 simulator
  settings. It turns the iPad first. It then prints counts from `results.jsonl` and exits non-zero on a failed or
  empty run, or on any changed, timeout, error or (in compare mode) missing picture.
- **Verification:**
  - Python suite: 251 tests OK.
  - `snapshot_shards.py --check`: current.
  - SwiftLint (strict): 0 violations in `AppPackage/Tests/VisualSnapshotTests/Matrix`.
  - Tracer on `$PHONE` at `en-large` through the runner: the candidate run recorded 12, and the compare run passed
    12.

## Task Commits

1. **Task 1: The schema-2 inventory and its Phase 17 readers** - `158b8f59c` (test)
2. **Task 2: Coordinate totals and the 20-shard plan** - `cb42e2264` (test)
3. **Task 3: Group catalog files, the inventory test and the local runner** - `2e684b76f` (test)
4. **Task 2 follow-up: one shard unit per test process** - `3b0573255` (test)

## Decisions Made

See `key-decisions`.

## Deviations from Plan

1. **`VisualMatrixTests.testSelectedCoordinate` fails without its coordinate.** Its `XCTUnwrap` needs
   `EHPANDA_VISUAL_COORDINATE`, and only `run-regression.py` sets that variable. It fails the same way at the base
   commit, so it is not caused by this plan. The plan's Task 3 verify command therefore prints `TEST FAILED`: 6
   tests, 1 failure. That failure is the one above; ScenarioInventoryTests passed 5/5. `VisualMatrixTests.swift`
   needed no change, because it hands `scenarios.json` to the fixture export, which now filters it through
   `FixtureArtwork.fixtureScenarios`.
2. **The inventory has 137 scenarios against D-12's 136.** This is within the plan's range of 130 to 150. The
   differences are in `key-decisions`.
3. **54 shard units, not the plan's 36.** The plan text counts 36 (device, configuration) units. 19-01 found that
   an iPad process captures one orientation, and its summary asks 19-02 for 54 units. Task 2 first shipped 36 units.
   With those, the largest shard was 1.247 × the mean, just under the 1.25 limit, and nothing in the file said which
   orientation an iPad run takes. `3b0573255` splits each iPad configuration by orientation and adds `runs` to each
   shard; the largest shard is now 1.160 × the mean. 19-10's `run-shard.sh` should loop over `runs`, not
   `configurations`, and turn the iPad before each run. The plan says "per configuration".

## Issues Encountered

- **One flaky picture.** In the compare run, `comments-block-confirmation__en__large__landscape__iphone__dark` hit
  the settle timeout on its first attempt and passed on its second (31 settle samples, 11.3 s). The landscape turn
  after the block dialog is the slowest settle in the tracer. Watch it in 19-07.
- **A launch-handle error.** The simulator logged one `launchApplicationWithID` "No such process" error during the
  compare run. The run still succeeded.

## User Setup Required

None.

## Next Phase Readiness

- 19-05 to 19-08 can fill their group files in parallel and check each class with `run-snapshot-local.sh`.
- 19-04 replaces `snapshot-cost.json` with measured costs and regenerates `snapshot-shards.json`.
- 19-10 reads `snapshot-shards.json` (its `runs`) and runs `--check`.
