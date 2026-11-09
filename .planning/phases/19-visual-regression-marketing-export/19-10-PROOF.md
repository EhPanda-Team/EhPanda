# 19-10 hosted proof of the snapshot gate

## Status (2026-11-09): Tasks 1 to 3 done, Task 4 waiting for the owner

Nothing has been pushed. No `ci/snapshot-gate` branch exists yet and no hosted run has started. The gate has been
checked only locally: unit tests against fake tools, and `actionlint`.

### Built (phase branch `feature/gsd-phase-19`)

| Commit | Task | What |
|---|---|---|
| `4f61f2af1` | 1 | Inventory closed. `favorites-category-menu` is not applicable on iPad (D-12). A missing factory now fails `ScenarioInventoryTests`. Shard plan regenerated: 137 scenarios, 19,368 expected, 360 not applicable |
| `96d826fa6` | 2 | Failing tests: `test_snapshot_fetch.py`, `test_snapshot_shard.py`, `test_run_shard.py` |
| `59e47f320` | 2 | `run-shard.sh`, `snapshot_fetch.py`, `snapshot_shard.py` |
| `994357126` | 2 | Budget test timing |
| `5041db455` | 3 | Failing tests: `test_snapshot_gate.py` |
| `decf93929` | 3 | `snapshot-gate.yml`; the gate wired into `deploy.yml`, `deploy-beta.yml` and `dependencies.yml`; `.github/actionlint.yaml` |
| `bac068b98` | 3 | The fault-switch test is skipped on the proof branch only |

Local checks:
- `python3 -m unittest discover -p 'test_*.py'` in `Scripts/visual`: 351 tests, OK.
- `actionlint .github/workflows/*.yml`: clean.
- `run-shard.sh --shard s09` on this Mac: records `drift`, because this Mac has Xcode 27.2 (27B52) and no iOS 27.0 runtime, so it captures nothing.

### Open before the proof (owner or orchestrator decision)

1. **Login gap: blocks a meaningful proof.** The three Login scenarios have factories but no matrix method. The
   page's `WaveForm` backdrop is drawn in `TimelineView(.animation)` from the wall clock, so it never settles (19-08).
   19-08 proposed a not-applicable rule for them. That rule meets neither D-05 nor D-12, so Task 1 did not apply it.
   - Effect: all 648 Login coordinates are expected, and none gets a result line. Every shard therefore has
     `missing-result` infrastructure errors.
   - `triage` then lists all 20 shards, `retry` runs all 20 again, and the aggregate fails on infrastructure errors.
   - The proof would show that path, not the two injected faults alone.
   - Fix options:
     - (a) An app change: `WaveForm` draws a fixed phase when `accessibilityReduceMotion` is on (the capture
       simulator has Reduce Motion on), plus three `testLogin…` methods in `SettingsSnapshotTests`.
     - (b) The owner accepts the not-applicable rule as a by-design exception.
2. **iPad landscape is unverified on clones.** `run-shard.sh` turns the base iPad with
   `VisualCaptureOrientationUITests` before each landscape invocation. Nobody has checked whether the parallel
   clones start in that orientation. If they do not, the iPad landscape coordinates fail geometry (`error`). The
   proof run will show which.
3. **Pins.** `regression-environment.json` pins Xcode 27.0 (27A266a) and runtime iOS 27.0 (24A434). A runner image
   that has moved on records `drift` in every shard. This is correct behaviour, but it would make the proof
   uninformative.
4. **Expected time.** The shard plan sums to 1,124 shard-minutes. At 5 jobs at a time that is about 3 h 45 min, plus
   the build (about 30 to 40 min), the retries and the native-policy jobs, which share the 5 slots. D-13 and
   Research §5 estimated 2 to 3 hours.

### The proof commits (Task 4, only after the owner's explicit yes)

The branch `ci/snapshot-gate` is made from the phase-branch head. The proof commits are made on that branch only and
never reach the phase branch or `main`. Each commit message carries `[skip test]` so that `test.yml` does not also
run. There is no `fingerprints.json`, so a push runs in **candidate** mode.

- **Proof commit 1:** one line added to the workflow-level `env:` of `.github/workflows/snapshot-gate.yml`:
  `EHPANDA_SNAPSHOT_FAULT: 's03=crash,s11=no-artifact'`.
  - `s03` is an iPhone shard. Both of its capture runs on attempt 1 (the first pass and the in-job re-run) are
    killed after 180 s, so `shard.json` records `crash`.
  - `s11` is an iPad shard. On attempt 1 it leaves no output, so no artifact is uploaded and the aggregate reads it
    as `runner-lost`.
  - Expected: `triage` lists exactly `["s03","s11"]` (if the Login gap is closed first). `retry` runs both with
    `--attempt 2`, where the fault is off. The aggregate passes with 0 in each class.
- **Proof commit 2:** the same line becomes `EHPANDA_SNAPSHOT_FAULT: 's03=crash@every-attempt'`.
  - Expected: `s03` crashes on its retry as well. The aggregate fails with "infrastructure errors" naming `s03` (its
    `crash` and its missing results) and no other shard.
- The test for the fault switch skips itself when `GITHUB_REF` is `refs/heads/ci/snapshot-gate`, so the `checks`
  job does not stop the proof.
- After both runs are recorded here, the remote branch is deleted unless the owner says otherwise.

### To record after the runs

- Owner message number.
- Run IDs.
- How many shards ran at once.
- Each shard's minutes against its limit.
- Triage and retry evidence.
- The aggregate's four class counts.
- That no shard was cancelled.
- Total wall time against D-13's estimate.
