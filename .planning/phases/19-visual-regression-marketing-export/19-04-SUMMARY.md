---
phase: 19-visual-regression-marketing-export
plan: "04"
subsystem: testing
tags: [snapshot, ci, github-actions, hosted-runner, measurement, simulator]

requires:
  - phase: 19-02
    provides: "snapshot-cost.json, snapshot_shards.py and the 20-shard plan"
  - phase: 19-05
    provides: "the eight browsing matrix classes the measurement captures"
provides:
  - "`snapshot-measure.yml`: one build, then one job per device and text size (and all sizes) recording a candidate at 2 workers and comparing at 2, 3 and 4"
  - "`snapshot_measure.py`: shard results and memory samples to the cost table and D-15's worker choice (incomplete, infra, changed, critical memory, slowdown)"
  - "`hosted-simulator.sh` (time-limited, retried simulator setup; clone clearing) and `snapshot_infra.py` (simulator failures as infra, retried once)"
  - "Interim gate setting: `snapshot-cost.json` `workers: 2`, `source: model`, `invocationMinutes: 8.5`; `snapshot-shards.json` regenerated and current"
  - "R-1: four hosted runs, all `billable: {}` on GitHub's standard `xcode-27` runner"
affects: [19-10, 19-12]

actuals:
  tasks: 3
  commits: 14

tech-stack:
  added: []
  patterns:
    - "Every simctl call on a hosted runner has its own time limit; a failed setup is deleted and made once more"
    - "A measurement invocation that fails for a simulator reason is infra, kept beside its retry, never a measurement"

key-files:
  created:
    - .github/workflows/snapshot-measure.yml
    - Scripts/visual/snapshot_measure.py
    - Scripts/visual/test_snapshot_measure.py
    - Scripts/visual/hosted-simulator.sh
    - Scripts/visual/snapshot_infra.py
    - Scripts/visual/test_snapshot_infra.py
    - .planning/phases/19-visual-regression-marketing-export/19-04-MEASURE.md
  modified:
    - Scripts/visual/snapshot-cost.json
    - Scripts/visual/snapshot-shards.json
    - Scripts/visual/snapshot_shards.py
    - Scripts/visual/run-snapshot-local.sh
    - AppPackage/Sources/VisualSnapshotSupport/HostedWindowCapture.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Browsing.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/SnapshotMatrixCase.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/HostedWindowCaptureTests.swift

key-decisions:
  - "Memory: only `critical` excludes a count; `warn` is the hosted runner's resting state under two clones (lead's technical call after run 42455556948)."
  - "Interim worker count 2 (developer's decision after run 42475531683), kept after run 42533872440 because no hosted run passed D-15's rule."
  - "Deciding on the iPad data alone was declined: D-15's rule needs every device and text size."

requirements-completed: []

coverage:
  - id: D1
    description: "The reducer turns hosted runs into the cost table and worker choice"
    requirement: VIS-18-01
    verification:
      - kind: unit
        ref: "Scripts/visual/test_snapshot_measure.py, Scripts/visual/test_snapshot_infra.py"
        status: pass
    human_judgment: false
  - id: D2
    description: "A hosted run chooses the worker count under D-15's rule; measured cost table (`source: measured`)"
    requirement: VIS-18-01
    verification:
      - kind: integration
        ref: "runs 42455556948, 42475531683, 42533872440: no count passed; interim 2 workers on the model"
        status: fail
    human_judgment: true
  - id: D3
    description: "R-1: billing and runner recorded"
    requirement: VIS-18-01
    verification:
      - kind: manual
        ref: "19-04-MEASURE.md § R-1: billable {} in every run, runner group GitHub Actions, label xcode-27"
        status: pass
    human_judgment: false

duration: multi-session
completed: 2026-11-09
status: complete
---

# Phase 19 Plan 04: Hosted measurement Summary

**Closed on the interim count of 2 workers. Three hosted measurements ran, and none chose a worker count under
D-15's rule. The final run, 42533872440, lost 7 of 8 jobs to simulator setup, and its one measuring job had 2 changed
pictures. `snapshot-cost.json` stays `workers: 2`, `source: model`. Billing is `{}` on the standard `xcode-27`
runner.**

## Performance

- **Tasks:** 3 (Task 3 is the owner's go-ahead, the hosted runs and R-1)
- **Hosted runs:** 42442284401 and 42442366372 (no data), 42455556948, 42475531683 and 42533872440 (measured)

## Accomplishments

- **Measurement tooling** (Tasks 1 and 2):
  - `snapshot_measure.py`, with tests, reduces shard results and memory samples to the cost table and D-15's choice.
  - `snapshot-measure.yml` runs on push to `ci/snapshot-measure`.
- **Hosted identity fixes**, proven locally under load (`19-04-MEASURE.md` § Option 2):
  - Settling happens only at rest, and the rotation wait holds on a loaded host.
  - `front-page-search` is refocused until it stays first responder.
  - Indicators freeze at a fixed frame.
  - `HostedWindowCaptureTests` no longer assumes host speed.
- **Robust simulator steps** (§ Option 1):
  - Every `simctl` call has its own limit, and the setup has one retry.
  - Clones are cleared between invocations.
  - A startup watchdog stops invocations that never start.
  - Simulator failures count as infra, with one retry.
- **The final run, 42533872440** (owner msg 2743; § Final hosted run (run 42533872440)):
  - The run took 2 h 40 min. The build took 8.7 min.
  - 7 jobs failed "Create the pinned simulator" in both attempts, within 5 to 13 minutes. The causes were settings
    writes over 60 s, `bootstatus` over 300 s, "device is not booted" right after boot, and one iPad shutdown over
    180 s.
  - `iphone en-xSmall` measured at 2 and 3 and reached its 140-minute step limit during the compare at 4:
    - Median per picture: 2.06 s at 2 workers and 2.19 s at 3 (1.06×). Wall time: 971 s at 2 and 1,099 s at 3.
    - Memory never reached `critical`.
  - Rule: 2 workers incomplete and changed, 3 infra and changed, 4 incomplete. No count chosen.
- **What the final run found:**
  - **`agewall-unticked`:** the candidate was the outlier. In two pictures, the glass Continue button had settled on
    the 2-read floor, and they differ by at most 1/255 from compares that are byte-identical to each other.
  - **`front-page-search`:** the 15 s focus deadline ran out on the hosted runner in 3 of 5 compare attempts.
  - **`home-loading`:** byte-identical to the candidate, so the indicator freeze holds on the hosted runner.
  - **About 68 of the 140 minutes** went to faults in the new steps:
    - `clear-clones` waits its full 10 minutes when no testing device set exists yet.
    - The startup watchdog killed two invocations that were writing pictures but had printed no `Test case` line.
    - A completed compare was counted as infra because of a recovered `server died` line.

## Fixed after the final run

The lead kept 2 workers on the model with no new measurement, and the run's faults were fixed for 19-10 and 19-12
(`19-04-MEASURE.md` § Fixed after the final run). All fixes were proven locally or by unit tests, with no hosted run:

- **Simulator setup:** longer per-call limits: settings writes 180 s, `bootstatus` 600 s, shutdown 360 s. A write that
  finds the device not booted waits, boots it again and is made once more. The step limit is now 60 minutes.
- **`clear-clones`:** no testing device set means no clones.
- **Startup watchdog:** `results.jsonl` growth counts as a test begun, and its note is no longer overwritten.
- **Infra check:** a recovered `server died` is not infra when xcodebuild reported every test.
- **First-launch glass pictures:** they settle on at least 6 identical reads.
- **`front-page-search`:** the focus step has 40 s and outlasts a window that is still moving after one rest wait.

## Task Commits

1. **Task 1: Measurement reducer:** `1c6ed5e46` (test)
2. **Task 2: The measurement workflow:** `a8cb801e3` (test), then the fixes `dfaf8c25a`, `ab5b71a57` and `85fb4b77e`
3. **Task 3: Hosted runs and R-1:** `4ba0b5d6e`, `279d155f0`, `35173299f`, `fd7db5187`, `1b381ae4f`, `e6b86ac8f`,
   `691edf222` and `e2c6acb5b`, plus this closing docs commit

## Deviations

- **Must-have not met:** the measured cost table (`source: measured`) and the measured worker count are not
  delivered. The plan closes on the interim count of 2 workers on the model. Following the stop rule, nothing more was
  pushed.
- **Memory rule amended:** only `critical` excludes a count; `warn` does not (lead's call, recorded in the plan).

## Issues for later plans

- **19-10** runs the gate on the model at 2 workers: 47.6 to 60.7 minutes per shard (`invocationMinutes: 8.5`), and
  about 3½ to 4 hours per PR if nothing stalls (`19-04-MEASURE.md` § Per-PR estimate).
- Simulator setup on the hosted runner failed in 7 of 8 jobs in the last run. The longer limits and the step fixes
  (§ Fixed after the final run) are proven only locally. 19-10's first hosted run is their first test on a runner.

## Owner decision

Measure again after fixing the setup limits, `clear-clones`, the startup watchdog, the infra classifier and the two
identity causes (one more `ci/snapshot-measure` push), or accept 2 workers on the model as the gate's setting.

The lead's call: no new measurement; 2 workers on the model is the gate's setting. The fixes above were made anyway.
