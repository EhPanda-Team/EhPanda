---
phase: 19-visual-regression-marketing-export
plan: "09"
subsystem: testing
tags: [snapshot, aggregate, report, python, ci]

requires:
  - phase: 19-01
    provides: "SnapshotResultWriter's results.jsonl and shard.json"
  - phase: 19-02
    provides: "snapshot_matrix.py (expected coordinates), scenarios.json schema 2, snapshot-shards.json"
provides:
  - "`Scripts/visual/snapshot_aggregate.py`: merge with retries, four failure classes, `--triage`, flake log, `aggregate.json` and the Markdown step summary"
  - "`Scripts/visual/snapshot_report.py`: the static offline review report and `--packet` (the owner's short packet)"
affects: [19-10, 19-12, 19-13]

actuals:
  tokens: 70000
  tasks: 2
  commits: 2

tech-stack:
  added: []
  patterns:
    - "Every expected coordinate needs exactly one line; absence is an infrastructure error, never a pass"
    - "Retry selection reads only infrastructure errors and missing artifacts; picture changes never retry"

key-files:
  created:
    - Scripts/visual/snapshot_aggregate.py
    - Scripts/visual/test_snapshot_aggregate.py
    - Scripts/visual/snapshot_report.py
    - Scripts/visual/test_snapshot_report.py
  modified: []

key-decisions:
  - "Classes in a fixed order: picture changes (`changed`, `missing-baseline`), infrastructure errors (shard `crash`, `timeout`, `runner-lost`; coordinate `timeout`, `error`; `missing-result`, `duplicate-result`, `unexpected-result`, a malformed line or shard file), drift, baseline mismatches."
  - "A shard marked `drift` or `baseline-mismatch` counts once as that class and its coordinates are not also reported as missing results."
  - "A flaky coordinate that ended in `timeout` or `error` is an infrastructure error, not a flake-log entry."
  - "The packet's default coordinate is `<scenario>__en__large__portrait__iphone__light`; when it is not applicable, the first applicable coordinate in axis order."

patterns-established:
  - "Scripts read the writer's JSON Lines as is; the line keys (`key`, `status`, `attempts`, `flaky`, `seconds`, `reason`) are the contract"

requirements-completed: []

coverage:
  - id: D1
    description: "Merge, classify, triage, flake log and summary from files alone"
    requirement: VIS-18-01
    verification:
      - kind: unit
        ref: "python3 -m unittest discover -s Scripts/visual -p 'test_snapshot_aggregate.py' (11 tests, OK)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Offline report with filters and failure triplets; short packet"
    requirement: CAP-17-02
    verification:
      - kind: unit
        ref: "python3 -m unittest discover -s Scripts/visual -p 'test_snapshot_report.py' (6 tests, OK)"
        status: pass
    human_judgment: false

duration: one session
completed: 2026-11-08
status: complete
---

# Phase 19 Plan 09: Aggregate logic and the review report Summary

**The gate's final job now has tested logic: it merges shard results with their retries, fails on any of four named
failure classes, lists only infrastructure failures for a retry, and writes an offline review report and the owner's
short packet.**

## Performance

- **Tasks:** 2
- **Files:** 4 created

## Accomplishments

- **Aggregate** (Task 1). `snapshot_aggregate.py --results DIR [--retry DIR] --inventory --env --shards --out
  [--triage] [--summary]` reads `<DIR>/<shard-id>/results.jsonl` and `shard.json`, keeps the retry's attempt where
  there is one, and checks every coordinate `snapshot_matrix.py` expects. It writes `aggregate.json` (schema 1:
  counts and items per class, flaky list, per-shard attempt and infra, status counts) and a Markdown summary whose
  first four lines are the class counts in fixed order. Exit 1 on any non-empty class. `--triage` prints the JSON
  list of shard IDs to retry and exits 0.
- **Report** (Task 2). `snapshot_report.py --aggregate --pictures --out [--packet] [--flags]` writes one static
  `index.html` grouped by the inventory's group, then scenario. Failing coordinates show baseline, actual and
  difference side by side, all from `img/` inside the report. Filters cover language, text size, device,
  orientation and appearance in an inline script. The page has the environment and counts in its header, the
  not-applicable list with reasons and the flake log. `--packet` keeps one picture per scenario plus every key in
  `flags.json` (19-13's pre-check output).
- **Verification:**
  - `test_snapshot_aggregate.py`: 11 tests, OK. One named test per plan behaviour, plus coordinate timeout and
    malformed lines, and not-applicable coordinates needing no line.
  - `test_snapshot_report.py`: 6 tests, OK (no remote reference, the five filters, failure triplets, packet
    selection, the flake log and infrastructure items, the command line).
  - The whole `Scripts/visual` suite (`test_*.py`) passes.
  - Format check against real data: the lines in `/tmp/ehp19/r08/c-phone/c1/results.jsonl` (19-08 runs) carry
    the keys the aggregate reads.

## Task Commits

1. **Task 1: Aggregate, classify and triage** - `0fe8d3c62` (test)
2. **Task 2: Static offline report and the short packet** - `58c9c092b` (test)

## Decisions Made

See `key-decisions`.

## Deviations from Plan

None. The two scripts were written in the same session as 19-08 and 19-14 (all wave 3) and committed once their
suites passed.

## Issues Encountered

None. The scripts have not yet run on a real multi-shard upload; 19-10's hosted proof is the first.

## User Setup Required

None.

## Next Phase Readiness

- 19-10's aggregate job calls `snapshot_aggregate.py` (and `--triage` for the retry matrix) and
  `snapshot_report.py`.
- 19-12 and 19-13 use `--packet` with `flags.json` for the candidate review.
- VIS-18-01 and CAP-17-02 stay Pending (later plans share them).
