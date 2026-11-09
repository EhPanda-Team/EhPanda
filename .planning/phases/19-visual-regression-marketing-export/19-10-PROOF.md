# 19-10 hosted proof of the snapshot gate

## Status (2026-11-09): Tasks 1 to 3 done and the review's gaps closed; Task 4 waiting for the owner

The orchestrator pushed the phase branch through `7749f8e7f`. The commits from the review follow-up are not pushed
yet. No `ci/snapshot-gate` branch exists yet and no hosted run has started. The gate has been checked only locally:
unit tests against fake tools, `actionlint`, and one `run-shard.sh` iPad check on this Mac with the drift pin set
aside (see 2 below).

### Built (phase branch `feature/gsd-phase-19`)

| Commit | Task | What |
|---|---|---|
| `0b8af222e` | 1 | Inventory closed. `favorites-category-menu` is not applicable on iPad (D-12). A missing factory now fails `ScenarioInventoryTests`. Shard plan regenerated: 137 scenarios, 19,368 expected, 360 not applicable |
| `acc1f213c` | 2 | Failing tests: `test_snapshot_fetch.py`, `test_snapshot_shard.py`, `test_run_shard.py` |
| `9741ff5b8` | 2 | `run-shard.sh`, `snapshot_fetch.py`, `snapshot_shard.py` |
| `2fe20743a` | 2 | Budget test timing |
| `aeb19f7ce` | 3 | Failing tests: `test_snapshot_gate.py` |
| `832ac3d88` | 3 | `snapshot-gate.yml`; the gate wired into `deploy.yml`, `deploy-beta.yml` and `dependencies.yml`; `.github/actionlint.yaml` |
| `51e36c8b7` | 3 | The fault-switch test is skipped on the proof branch only |

Local checks:
- `python3 -m unittest discover -p 'test_*.py'` in `Scripts/visual`: 351 tests, OK.
- `actionlint .github/workflows/*.yml`: clean.
- `run-shard.sh --shard s09` on this Mac: records `drift`, because this Mac has Xcode 27.2 (27B52) and no iOS 27.0 runtime, so it captures nothing.

### Gaps closed after the first review (2026-11-09, orchestrator's calls)

| Commit | What |
|---|---|
| `7a13a704b` | Failing tests: `WaveFormReduceMotionTests`, the D-29 inventory gains the wave's gate, and the shard test expects the matrix classes to cover the whole inventory |
| `940ae2bf1` | `WaveForm` pauses its timeline and draws phase 0 under Reduce Motion |
| `aa5fe657c` | `testLoginEmpty`, `testLoginFilled` and `testLoginError` in `SettingsSnapshotTests` |
| `bcd7b912d` | Failing tests: `hosted-simulator.sh settings`, the settings after each turn, iPad landscape without clones, the plan on wall seconds |
| `a2369ea0c` | Those changes, and the shard plan regenerated |
| `65f88e625`, `3317c2fc9` | `run-snapshot-local.sh` refuses `--workers` for an iPad landscape run |
| `0d64a79bf`, `e8c309e61` | The settings step before each turn as well (failing test, then the fix) |

1. **Login: closed with option (a).** Under Reduce Motion, `WaveForm` pauses its `TimelineView` and draws the wave at
   phase 0. That is the D-29 rule for continuous position motion, not a capture-only path. Without Reduce Motion
   the waves slide as before.
   - `WaveFormReduceMotionTests` renders the public view twice, 250 ms apart. Under Reduce Motion the two renders
     are identical; without it they differ. A mutant that ignored the value failed the first test.
   - `ReduceMotionGatingSourceTests` now counts `SettingFeature/WaveForm.swift`: 1 read, 1 ternary, 6 mentions.
   - Local stills (iPhone Air, iOS 27.2, `en-large`, candidate): all 12 Login coordinates were recorded, taking 1.3
     to 2.2 s each with 5 to 9 settle samples. On the iPad in landscape, the 6 Login coordinates were also
     recorded. I looked at the stills:
     - The two grey waves show in the lower part of the page in light and dark, portrait and landscape. The
       backdrop is not blank.
     - In the error still, the toast sits over the sign-in button.
     - The password field is empty in the filled and error stills. The secure field's dots are not in the capture.
       19-13 should judge this when it reviews the baseline.
   - The shard plan did not change for this, because it already counted the 648 Login coordinates.
2. **iPad landscape with clones: the clones do not inherit the turn. Fixed.** I checked this on this Mac's iOS 27.2
   runtime with my own iPad Pro 11-inch (M5) simulator (Full Screen Apps), the drift pin set aside, `en-large`, four
   Settings classes, candidate mode:
   - **Clones.** I turned the device to landscape with `VisualCaptureOrientationUITests`, then started a 2-worker
     run. xcodebuild shut the device down to clone it, and both clones booted in portrait. All 60 coordinates
     failed `geometry`: the window was 834×1210, and the scene refused the turn ("The current windowing mode does
     not allow for programmatic changes to interface orientation").
   - **Same run without clones**, on the turned device: 60 of 60 recorded.
   - **Accessibility runtime.** The turn's UI test run left `ApplicationAccessibilityEnabled` at 0. Every coordinate
     after a turn would therefore have failed `configuration-accessibility-runtime`. `run-shard.sh` never set it
     again.
   - **A turned device can lose the turn.** In a `run-shard.sh` check with a stub that stood in my simulator for
     `create`, the portrait invocation's clones had shut the device down, and the turn's own xcodebuild booted it
     again. The device was back in portrait by the time the capture started, so all 60 landscape coordinates
     failed `geometry`, even without clones. Shut down and turned the same way: 2 of 2 failed. With
     `hosted-simulator.sh settings` (boot, wait, settings) before the turn: 2 of 2 recorded.
   - **The fix:**
     - `hosted-simulator.sh settings <udid>`: `bootstatus -b`, then both switches set and read back. `run-shard.sh`
       runs it before and after every turn.
     - An iPad landscape invocation runs with `-parallel-testing-enabled NO`.
     - `snapshot_shards.py` gives an iPad landscape process no clone speedup, and it balances and estimates shards
       on wall seconds.
     - `run-snapshot-local.sh` refuses `--workers` for an iPad landscape run.
   - **Checked end to end.** I ran `run-shard.sh` with the fix on a one-shard plan: iPad, `en-large` portrait then
     landscape, four classes. The portrait invocation ran on 2 clones (20 and 9 tests). Then came the settings,
     the turn, the settings again, and landscape on the device itself. Result: 120 of 120 recorded, `infra` null,
     no re-run, 4 minutes.
   - **New plan:** 14 iPad shards and 6 iPhone shards, where it was 12 and 8. iPad shards run 53 to 70 minutes and
     iPhone shards 60 minutes. Every limit is 107 or 120 minutes. `s03` is still an iPhone shard and `s11` an iPad
     shard, so the proof commits below stand.
3. **Red until a baseline exists: accepted by design.** With no `Baseline/fingerprints.json`, every compare run fails
   at once with "no approved baseline yet": pull requests, the release gate in `deploy.yml` and `deploy-beta.yml`,
   and dependency updates. That is intended. Phase 19 merges to `main` only after 19-13 approves the baseline, so
   `main` never carries a gate that cannot pass. Until then, the proof on `ci/snapshot-gate` runs in candidate mode.
   The rule is also in `Scripts/visual/README.md` ("Snapshot gate").
4. **Pins (unchanged).** `regression-environment.json` pins Xcode 27.0 (27A266a) and runtime iOS 27.0 (24A434). A
   runner image that has moved on records `drift` in every shard. That is correct behaviour, but it would make the
   proof uninformative. This Mac has Xcode 27.2 (27B52) and only iOS 27.2, so it cannot run an unmodified shard.
5. **Expected time (for the owner).** The plan now sums to 1,247.8 shard-minutes, up from 1,124 because the iPad
   landscape processes lost the clone speedup. At 5 jobs at a time, that is about **4 h 10 min**, up from the
   3 h 45 min estimated before.
   - On top of that come the build (about 30 to 40 min) and any retries.
   - The native-policy jobs share the 5 slots.
   - D-13 and Research §5 estimated 2 to 3 hours.
   - The estimate rests on the modelled cost table (`snapshot-cost.json`, `source: model`), not on a measured one.
     The proof run will be the first measurement.
6. **T-19-21 (all 5 macOS slots held for hours): accepted, written down.** `Scripts/visual/README.md` now has a
   "Snapshot gate" section that covers:
   - the cost;
   - the queueing of `test.yml`, the deploys and other gate runs;
   - the cancellation of superseded pull-request runs;
   - red until a baseline exists;
   - the iPad orientation steps;
   - local use.

Local checks after these commits:
- `python3 -m unittest discover -p 'test_*.py'` in `Scripts/visual`: 356 tests, OK.
- `WaveFormReduceMotionTests` and `ReduceMotionGatingSourceTests` (FeatureTests plan, iOS 27.2): all passed.

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
  - Expected: `triage` lists exactly `["s03","s11"]` (the Login gap is closed). `retry` runs both with
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
