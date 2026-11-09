# 19-10 hosted proof of the snapshot gate

## Status (2026-11-09): Task 4 stopped after hosted run 1; two gate bugs found, run 2 not started

The owner said yes in owner msg 2876. Run 1 found two gate bugs that have nothing to do with the injected faults,
plus a native-policy failure on the hosted Macs (see "Task 4: hosted run 1" below). Following the rule for this step,
I stopped there: no second proof commit, and no fix. The remote branch `ci/snapshot-gate` is deleted. The proof
commit was never on the phase branch.

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

### Task 4: hosted run 1 (owner msg 2876)

- **Go-ahead:** owner msg 2876, the answer to the question in Task 4 step 1.
- **Branch and commit:** `ci/snapshot-gate`, made in its own worktree from `813ac0f43`. One proof commit,
  `6460a82e7` ("… [skip test]"), added `EHPANDA_SNAPSHOT_FAULT: 's03=crash,s11=no-artifact'` to the workflow
  `env:`. `test.yml` ran and was skipped, as intended.
- **Run:** [Snapshot gate run 42562780142](https://github.com/EhPanda-Team/EhPanda/actions/runs/42562780142),
  push, candidate mode. It started at 04:36:37Z, ended at 06:08:56Z (**92.3 min**), and failed.
- **Runner image:** `xcode-27-arm64` 20261104.0337.1. Its default is **Xcode 27.1 (27A9275)**. The image also has
  Xcode 27.0 (27A266a) at `/Applications/Xcode_27.0.app` and 27.2, and the pinned runtime iOS 27.0 (24A434) is
  installed. No workflow here selects an Xcode, so the gate ran on 27.1.

| Job | Result | Job minutes | Run step / limit |
|---|---|---|---|
| checks | success | 0.5 | |
| build | success | 15.5 | (job limit 90) |
| shard s01 to s20 | success (all 20) | 0.4 to 0.8 each | 0.0 to 0.1 min each; limits 120 (s13 to s16: 107) |
| triage | success | 0.1 | retried `["s11"]` |
| retry s11 | success | 0.7 | under 0.1 min / 120 |
| native policy (iphone) | **failure** | 40.8 | 33.5 / 80 (the simulator took 6.4 min to make) |
| native policy (ipad) | **failure** | 76.0 | 63.6 / 80 (the simulator took 11.4 min to make) |
| aggregate | failure | 0.1 | |

- **Shards:**
  - All 20 checked the pin, recorded `drift` ("Xcode is Xcode 27.1 / Build version 27A9275, pinned Xcode 27.0 /
    Build version 27A266a") and captured nothing. They took under a minute each, against the plan's 53 to 70 min.
  - No shard was cancelled. At most 4 macOS jobs ran at once, of the 5 slots: the 2 native-policy jobs and 2 or 3
    shards.
  - The run says nothing about the time per shard or D-13's estimate (2 to 3 h, 4 h 10 min under the current plan),
    and `snapshot-cost.json` stays `source: model`.
- **Faults:**
  - `s11=no-artifact` worked. s11 left no output ("fault: s11 leaves no artifact on attempt 1"), so `triage`
    listed exactly `["s11"]`, and `retry s11` ran with `--attempt 2` and the fault off. The retry then recorded
    `drift` like every other shard.
  - `s03=crash` was never exercised. The drift check comes before any capture, so s03 recorded `drift` and was
    correctly not retried, since drift is not a class that is retried.
- **Aggregate summary:** 0 picture changes, **1 infrastructure error** (s11: `runner-lost`, "no artifact; 806
  coordinates missing"), **19 drift**, 0 baseline mismatches. "Shards: 20; retried: none." Native visual policy:
  failure.

**Bug 1 (gate): the aggregate never sees a single retried shard.**
- `actions/download-artifact@v7` with `pattern: retry-*` matched one artifact (`retry-s11`). It extracted that
  artifact straight into `$RUNNER_TEMP/retry` ("Starting download of artifact to: /home/runner/work/_temp/retry"),
  not into `retry/retry-s11`. With several matches, each goes into its own folder, as `results/shard-s20` did.
- The rename loop therefore found no `retry-*` folder, and `snapshot_aggregate.py` read no retry. That is why s11
  was reported `runner-lost` and the summary said "retried: none", although the retry ran and uploaded its result.
- The same layout would hit `triage` and `aggregate` for `shard-*` if exactly one shard artifact existed.
- Run 2 (`s03=crash@every-attempt`, one retry) would have hit the same bug. Its verdict would have looked right
  for the wrong reason.
- Possible fix (not made): keep the shard ID folder inside each artifact and download with `merge-multiple: true`,
  or treat a `shard.json` at the top of the download folder as the only match. Either way, with a test for the
  one-artifact layout.

**Bug 2 (gate): nothing selects the pinned Xcode.**
- The macOS jobs (`build`, `shard`, `retry`, `native-policy`) use the image's default Xcode. That default has
  moved to 27.1, so every shard records `drift` and the gate can never pass on this image.
- The pinned Xcode 27.0 (27A266a) and runtime 24A434 are both on the image.
- Possible fix (not made): set `DEVELOPER_DIR` to `/Applications/Xcode_27.0.app/Contents/Developer` for those
  jobs (or `xcode-select` from the pin), with a gate test that every macOS job selects it. The other alternative
  is to re-pin to 27.1, which needs a new environment record.

**Native policy failed on both devices (Xcode 27.1, runtime iOS 27.0).**
- **iPhone:** 7 of 8 tests passed. `testSettingMarksAndTitleSurviveSizesAndTurns` failed: "Settings never opened
  Larger Text" (line 98), after the Settings app was slow to reach Display & Text Size. It then exceeded XCTest's
  10-minute allowance, and the restart executed 0 tests.
- **iPad:**
  - `testColdEntryAtAX3` failed 3 of 3 attempts and `testColdEntryAtAX5` 3 of 3. One of them was "Failed to get
    matching snapshots: Timed out while evaluating UI query"; the rest were `library-title-menu` not found within
    5 s (line 208).
  - `testColdEntryAtLarge` passed on its 3rd attempt.
  - `testSearchKeepsQueryFocusAndTabThroughSizesAndTurns` failed at line 70, then exceeded the 10-minute
    allowance.
  - `testSettingMarksAndTitleSurviveSizesAndTurns` exceeded the 10-minute allowance.
  - The other 3 passed.
- **Unclear:** whether this comes from the slower hosted simulators, from Xcode 27.1, or from the tests themselves.
  The job has no drift check of its own, so it ran on the drifted Xcode. It should be judged again after Bug 2 is
  fixed. The step took 33.5 and 63.6 min, against the 13 to 15 min measured in 19-11.

**Not done, and why:** these are gate bugs, not the injected faults, so I stopped as this step's rules require.
- Proof commit 2 was not made, and no fix was made.
- The remote branch `ci/snapshot-gate` was deleted after this record, and its worktree removed.
- A new hosted proof needs Bugs 1 and 2 fixed on the phase branch first. Whether the native-policy failures remain
  should be checked at the same time. Then both proof runs can be made again (owner msg 2876 approved two runs;
  one has been used).

### Task 4: hosted run 2 (run 42577585956)

- **Commit:** `3140c6665` on `ci/snapshot-gate`, from the phase branch with Bugs 1 and 2 fixed (Xcode 27.1 pinned,
  artifacts merged). It injected `s03=crash,s11=no-artifact` again: proof commit 1, not `@every-attempt`.
- **Run:** 07:10Z to 16:57Z (**9 h 47 min**), failed. 20 shards and 16 retries.
- **Proven:** the Xcode pin (no drift anywhere); the merged artifact layout (17 shard and 16 retry artifacts read);
  `s11=no-artifact` (triage listed it, its retry captured 806 of 806); `s03=crash` (killed after 180 s twice,
  `crash` recorded); native policy on iPad (38 min, passed).
- **Not proven:** triage listed 16 shards, not `["s03","s11"]`, and the aggregate named 12 shards and the native
  policy. Causes, by class:
  - **Hosted runner (b):** two runners lost contact (s02, s04); `bootstatus` stopped at 600 s or the first
    `defaults write` at 180 s on both create attempts (s15, s17, s19, s20; retries s02, s07, s15); the iPhone
    native-policy runner never bootstrapped (0 tests).
  - **Plan (d):** iPhone shards were estimated at 60 min on the modelled table and needed 113 to 115+ (s01, s06 and
    their retries hit the 115-minute budget); a class re-run threw away every configuration the class had done.
  - **Aggregate (d):** a lost retry replaced a good first attempt (s07: 547 recorded became `runner-lost`); one
    picture's error sent a whole shard to retry; XCTest's re-run of a class after a runner crash wrote keys twice
    (`duplicate-result`); the 200-item cap hid 11 of the 12 failing shards.
  - **App or snapshot (c):** 14 of 96 iPad landscape `agewall-unticked` / `analytics-choice-none` attempts timed
    out in settle (40 samples, no motion read); iPad `front-page-search` failed its focus step 4 times
    (`interaction`, 44 to 88 s against the 40-second deadline).

### Run-3 fixes (phase branch, after run 2)

1. `5fbfcd108` aggregate: a retry without `shard.json` keeps the first attempt (`retry-lost`); a folder without
   `shard.json` is "runner-lost — no shard.json (runner unusable)"; agreeing duplicate lines merge, disagreeing
   ones stay `duplicate-result`. (Also fixes 5 and 6 below.)
2. `21298ee1a` native policy: one more run when the runner never bootstrapped; both logs uploaded.
3. `a7edfdf0c` re-plan: `snapshot-cost.json` is measured from run 42577585956 (iPhone 6.9 s wall per picture, the
   median of 7 attempts); 18 iPhone shards (one configuration each, 73.2 min) and 9 iPad shards (77.3 min), every
   estimate within 70% of the 120-minute limit. `9278b9ba4`: a class re-run keeps the configurations it finished
   (`EHPANDA_SNAPSHOT_KEEP_CAPTURED`, pruned per configuration).
4. `b740f3f09` `hosted-simulator.sh`: `bootstatus -b` and a settle before the first write, a stopped write asked
   again, a third create attempt.
5. `5fbfcd108` triage: only shard-level errors (crash, timeout, lost runner, missing results) retry a shard; a
   picture's `timeout` or `error` is reported, not retried.
6. `5fbfcd108` summary: one line per shard (attempt, class, results, infrastructure errors) before the item list.
7. `3ef062ee9` capture: a failed user step is retried once like a timeout, and its reason names the failure
   (`interaction:no-search-field`, `search-focus-not-held`, `still-moving:…`); a settle timeout with no motion
   names the changed pixels (`settle-timeout:pixels:<x>,<y>,<w>x<h>`). This is diagnosis and resilience, not a
   root-cause fix: on this Mac (iOS 27.2 runtime only) the iPad repro stops at the geometry check, so the
   first-launch timeout could not be reproduced.

**Fault shards under the 27-shard plan.** `s03` (de-xSmall) and `s11` (ko-large) are now both iPhone shards, so
proof commit 1 no longer puts a fault on an iPad shard. The faults themselves do not depend on the device; if the
iPad path should be covered too, `s03=crash,s20=no-artifact` does it (s19 to s27 are iPad).

**Expected time.** 2,013 shard-minutes (18 x 73.2 + 9 x 77.3). With the build (about 30 min), the two
native-policy jobs and 5 macOS jobs at a time: run 3 about **9 h** (two retries of a full shard after triage), run 4
about **8.7 h** (s03's retry crashes after 180 s twice). Run 2 took 9 h 47 min with most shards cut short.

### Still to record (after the run-3 fixes)

- Run 3 (`s03=crash,s11=no-artifact`): `triage` lists exactly `["s03","s11"]`, both retries pass, the aggregate
  is green with all four classes at 0, and each shard's minutes against its limit.
- Run 4 (`s03=crash@every-attempt`): the aggregate fails with "infrastructure errors" naming only `s03`.
- The `settle-timeout:pixels:…` and `interaction:…` reasons, if the iPad first-launch or search errors come back.
