# 19-10 hosted proof of the snapshot gate

## Status (2026-11-09): Task 4 stopped after hosted run 1; two gate bugs found, run 2 not started

The owner said yes in owner msg 2876. Run 1 found two gate bugs that have nothing to do with the injected faults,
plus a native-policy failure on the hosted Macs (see "Task 4: hosted run 1" below). Following the rule for this step,
I stopped there: no second proof commit, and no fix. The remote branch `ci/snapshot-gate` is deleted. The proof
commit was never on the phase branch.

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

### Gaps closed after the first review (2026-11-09, orchestrator's calls)

| Commit | What |
|---|---|
| `1e1d02cec` | Failing tests: `WaveFormReduceMotionTests`, the D-29 inventory gains the wave's gate, and the shard test expects the matrix classes to cover the whole inventory |
| `30bed51c9` | `WaveForm` pauses its timeline and draws phase 0 under Reduce Motion |
| `9d2eb3c04` | `testLoginEmpty`, `testLoginFilled` and `testLoginError` in `SettingsSnapshotTests` |
| `d49e47b76` | Failing tests: `hosted-simulator.sh settings`, the settings after each turn, iPad landscape without clones, the plan on wall seconds |
| `910ddf4d7` | Those changes, and the shard plan regenerated |
| `bc5ecf91e`, `80b1b3b20` | `run-snapshot-local.sh` refuses `--workers` for an iPad landscape run |
| `ee1d06da3`, `5b7fe6a0c` | The settings step before each turn as well (failing test, then the fix) |

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
- **Branch and commit:** `ci/snapshot-gate`, made in its own worktree from `cfce304d5`. One proof commit,
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
  artifact straight into `$RUNNER_TEMP/retry`,
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

### iPad root cause on the iOS 27.0 runtime (after the run-3 fixes)

The hosted runner's runtime, iOS 27.0 (24A434), was installed locally (gate iPad simulator, Xcode 27.2), and both
run-2 iPad errors were reproduced through `run-shard.sh`'s path: the orientation turn, then the matrix invocation.

- **First-launch settle timeout: root cause found, harness fix `1ac0720e4`.** Each settle read renders the window
  again (`drawHierarchy(afterScreenUpdates: true)`). On the iPad turned to landscape, every render draws the dimmed
  Liquid Glass Continue one step (1/255) different from the render before. That is a few to 325 bytes, cycling
  through two or three states, while nothing on the screen moves; one transient frame reached 2,480 bytes, still
  one step. Byte-exact reads rarely held for 500 ms. With the old reads, the first-launch pages settled after up to
  36 of the 40 samples, and one `analytics-choice-none` (ja-xSmall, dark) timed out and passed only on its retry.
  Settle reads drawn without the extra render (`afterScreenUpdates: false`) settled in 7 or 8 samples, which
  confirmed the cause. That was not kept: the picture would then differ from the existing references by up to 266
  pixels in the Continue button. The fix keeps the picture as it is and changes only when reads match. Two reads match
  if no byte is more than one step apart and the bytes that differ stay within half the comparison's byte budget
  (201 of 403 bytes on the iPad in landscape). Each read is compared with the first read of its run, so steps
  cannot add up. Unit tests: `readsMatch` (identical, ±1, ±2, over half the budget, size); a 4-point square that
  drifts one step every 200 ms never settles; a settled first-launch page settles again on its minimum reads. The
  fix is in the harness, not the app.
- **Proof (iOS 27.0, iPad landscape, `FirstLaunchSnapshotTests`, de/en/ja/ko/zh-Hans/zh-Hant at xSmall and
  large):** three runs in a row. Runs 1 and 2 recorded 144/144 each; run 3 compared with run 1 and passed 144/144.
  All were first attempts, with 0 timeouts and 0 flaky; samples had a median of 6 and a maximum of 9 (minimum
  reads 6). The pictures of runs 1 and 2 differ by at most 4 bytes (budget 403). The whole landscape en-large suite
  in compare mode against pictures taken with the old reads: 269 passed and 1 `changed`.
  That one is `downloads-inspector` dark: noise in the dimmed sidebar, up to 9/255. The old reads gave the
  same picture byte for byte on the same simulator session, so it comes from the session, not this fix.
- **iPad `front-page-search` `interaction`: not reproduced.** Portrait `FrontPageSnapshotTests` was run with 2
  workers (clones), as the gate runs it, for ja, ko and zh-Hans at xSmall, large and accessibility5: 108 recorded,
  then 108 passed in compare mode. That includes 36 `front-page-search` pictures, each 3.6 to 4.2 s, all first
  attempts. The full en-large portrait suite with 2 workers was also clean (268 recorded). On run 2 the step failed
  after 44 to 88 s; locally the focus holds within about 4 s. No root cause found; fix 7's retry and its
  `interaction:<reason>` stay, so run 3 will name the failure if it comes back.
- **Also found:** `BrowsingStepTests.testFocusFailsTheStepAtItsDeadline` still expected the error that fix 7 replaced
  and failed. `629f27294` fixes the test.

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
- iPad landscape `agewall-unticked` / `analytics-choice-none`: 0 timeouts after `1ac0720e4`.
- The `interaction:…` reason, if the iPad search error comes back.

### Native-policy recovery (2026-11-10; local verification only)

The interrupted work and `/tmp/np27` evidence were preserved. No hosted run or push was started during recovery.

**Runtime attribution:** the supplied local iPhone simulator and iPad
simulator use **iOS 27.2 (24B8117)**, the expected local verification runtime.
`simctl list -j devices`, their device records and the earlier RED/GREEN result-bundle summaries confirm this.
The earlier local `red-phone` and `green-phone-ax5` observations belong to 27.2, not to the hosted pin, iOS 27.0
(24A434). Their original bundles were subsequently lost in the scratch wipe; they are historical observations,
not retained recovery RED/GREEN evidence. The installed 27.0 runtime had no devices at recovery's start.
Neither original device was erased, recreated or silently reassigned. Normal local/runtime policy and the pinned
workflow runtime are unchanged.

**Probe correction:** the failed AX1 checks in `red3-phone`, `red5-phone` and `exp-scroll-phone` measured the
Account row's 65-point frame, not the rendered font. The row's icon reserves 45 points plus vertical padding;
Large and AX1 therefore share that height. SwiftUI also exposes this same frame for its StaticText child. The
screens show visibly larger AX1 text despite the unchanged frame. This is an insensitive probe, not evidence
that the slider failed to set AX1. The strengthened test calibrates the actual native row render independently
at all four cold categories, requires distinguishable reference measurements, and compares each live change
(including Large) against its own reference. It keeps screenshots of every reference and live read. No app
probe, size override on the live app, title fallback or assertion removal is introduced.

**Recovered test/workflow changes:** wait for either Library presentation before choosing its title assertion;
resolve the iPad Home tab directly with the existing identifier instead of first querying a known-absent TabBar;
keep its selected and hittable assertions. The native-policy allowance is 1,200 seconds. Each host-side policy
attempt resets Large (a reset failure aborts the attempt), caps failed-test repetitions at two, disables the
slow system diagnostics collector, and retains failed native-policy result bundles with its logs for seven
days. Snapshot shards still upload no result bundle. This is the native-policy-only exception to the original
D-14 workflow check, requested for recovering tap/wait evidence.

For additional pinned-hosted-failure reproduction only, continuation authorized two **new** project-scoped
27.0 devices (not replacements for normal local 27.2 verification):
- iPhone Air simulator.
- iPad Pro 11-inch (M5) simulator.

Both use `com.apple.CoreSimulator.SimRuntime.iOS-27-0` (24A434). The original 27.2 devices remain intact.

**Recovery checks so far (not a completed native-policy sign-off):**
- Final workflow tests: `python3 -m unittest discover -s Scripts/visual -p 'test_snapshot_gate.py'`, **30/30**
  passed in **416.664 s** under severe host contention.
- Full visual Python suite: **375/376** passed; the 12-second fake shard timeout test recorded one snapshot call
  instead of two. Its isolated rerun also failed (**52.452 s**, zero snapshot calls instead of two). This remaining
  failure is not waived or changed.
- The 27.2 render-probe trial failed because XCTest requested a screenshot of a transiently empty element frame.
  Its surviving manager console records **exit 65 after 691 s** and the empty-frame error. This is a **probe
  harness error, not a Settings-helper RED**. The probe now crops the app render and rejects empty measurements
  rather than letting an element screenshot crash XCTest. The earlier calibration log was lost in the scratch
  wipe, so no numerical calibration results or native-policy PASS are claimed from it.
- The added 27.0 phone's second `bootstatus -b` reported **Data Migration Failed** (terminal status 3) even though
  the command returned zero. A directly inspected screenshot shows SpringBoard with placeholder icons;
  `simctl launch` did start Settings. The pinned-runtime test attempt is still needed before claiming
  hosted-failure reproduction. No migration failure is counted as a test RED.
- **Blocked prerequisite:** during the next build, recovery scratch files, `Build/Products` and `SourcePackages`
  disappeared from the existing `/tmp/np27` tree. The build failed after **257.864 s** because SwiftLint plugin
  output/plist files no longer existed; its saved-helper restore also failed because that backup had disappeared.
  The recovered helper was immediately restored from the recorded diff and backed up outside that scratch tree.
  The source changes remain preserved, but the safe crop probe is not yet build-verified. No runnable products
  remain from that scratch tree for a pinned-runtime test attempt. The deleting process is unknown; no deletion
  was requested by recovery. A fresh baseline build was then started in `/var/tmp/np27-recover/DD`, with a
  1,790-second hard timeout and the recovered helper backed up outside `/tmp`. Surviving manager logs and the
  working diff were also copied into `/var/tmp/np27-recover`.
- Still pending: rebuild products, actual 27.0 hosted-failure RED/GREEN, full native-policy local verification on
  the normal 27.2 iPhone/iPad, and repeated iPad AX3/AX1 cold checks. No new recovery commit or hosted run/push has
  been made. The existing signed baseline commits remain unchanged.

### Task 4: hosted run 3 (run 42727781967)

Commit `c560ead1d` on `ci/snapshot-gate` (phase head `1046633b6` plus the fault `s03=crash,s20=no-artifact`),
candidate mode, 2026-11-10T00:22:20Z to 07:21:12Z (6 h 59 min). 35 jobs: 31 success, 4 failure (native policy
iPad and iPhone, retry s03, aggregate). The run **failed**; nothing in it is baseline approval.

- **Faults and triage worked.** s03 attempt 1 was killed after 180 s by the fault (`infra=crash`); s20 attempt 1
  left no artifact. `triage` selected exactly s03 and s20. s20's retry is a valid candidate capture: 1,096 keys
  (1,076 recorded, 20 not applicable), no error or timeout, about 55 min.
- **Aggregate: 0 picture changes, 0 drift, 0 baseline mismatches, 529 infrastructure errors.** s03: 525 (1
  `retry-lost`, the first attempt's `crash`, 523 `missing-result`), because the retry could not make its
  simulator. s07: 2 `error` (`comments-post-empty`, ja, accessibility5, iPhone landscape, light and dark;
  `geometry`). s26: 2 `timeout` (`history-grid`, ja, large, iPad portrait, light and dark;
  `settle-timeout:animation:UIImageView:contents`). Merged: 18,841 recorded, 350 not applicable.
- **Native policy, iPhone:** eight cases passed; `testSettingMarksAndTitleSurviveSizesAndTurns` failed
  ("Settings never opened Larger Text") and ran past the 10-minute allowance. Fixed after the run by `aa3c13d4c` /
  `f7dbdbed4` (Settings launched laid out at Large; a row tapped after the AX5 swipes opened nothing).
- **Native policy, iPad:** cold AX1 failed twice waiting for the Library title, passing on its third iteration;
  cold AX3 failed all three (Library title, "Home's tab is off screen at AX3", a hierarchy query timeout); the
  Settings test also ran past 10 minutes.

### Run-4 fixes (root causes of run 3)

1. `1877226d3` **s03 retry: the pinned runtime left the runner mid-setup.** The retry's `hosted-simulator.sh create`
   made the device, then `defaults write` found it not booted ("Bad or unknown session"), the boot failed ("cannot
   determine the runtime bundle"), and both further attempts were refused at once (`Invalid runtime:
   com.apple.CoreSimulator.SimRuntime.iOS-27-0`). The script retried a device on a runtime that was gone. Why the
   hosted image lost the runtime is not known. Fix: every create attempt first waits (up to 300 s) for the pinned
   runtime to be listed as available; if it does not come back, the pinned build (`regression-environment.json`,
   24A434) is downloaded again (`xcodebuild -downloadPlatform iOS -buildVersion`, 20 min limit) and waited for once
   more. The pins are unchanged.
2. `8f830801d` **s26 `history-grid`: fixture covers expired during a host freeze.** The light picture took 1,668 s for
   2 attempts of at most 40 reads each (100 ms apart), so the runner was frozen for about 27 minutes. The scenario's
   synthetic covers are stored in Kingfisher's memory cache once, before its first coordinate, and Kingfisher expires
   a memory entry 300 s after it is stored. After the freeze both pictures drew every cover as its loading
   placeholder, whose spinner repeats forever: `settle-timeout:animation:UIImageView:contents` was a correct verdict
   on a wrong picture. Fix: fixture artwork is stored with `.memoryCacheExpiration(.never)`
   (`TracerScenarios.cacheArtwork`, used by every matrix scenario that stores artwork). A partial change found in the
   tree, which skipped forever-repeating animations in `HostedWindowCapture`'s settle check, was not kept: it would
   have let the placeholder picture settle and be recorded.
3. `dc1e6dfd7` **s07 `comments-post-empty` landscape: the rotation wait was counted on the wall clock.** The test took
   78 s where its neighbours took 6 to 26; at the same time the other clone's `settings-pages-site-settings-error`
   (light) took 49 s for 3 settle reads, against a shard median of 2.3 s per picture: the host froze.
   `SnapshotMatrixCase.rotate` waited until a 20 s deadline; a freeze that used up the deadline ended the wait without
   reading the window again, and so, by inference, did the one repeated request, so both pictures were `geometry` with
   0 attempts. Fix: the wait is counted in reads (400 reads, 50 ms apart, the same 20 s when nothing freezes), as the
   settle wait already is. The pin check and the two matching reads are unchanged.
4. `58a04fb37` **iPad native policy cold AX1/AX3.**
   - Library: on the iPad sidebar the test required a selected `library-downloads-*` link, but cold Downloads
     selects All Downloads (`.downloads(.all)`), which has no folder link (`LibraryView.swift`), so the wait could
     only time out. Readiness for sidebar Downloads is now its content, `downloads-gallery-list`; Favorites still
     needs its selected category, and the native title must be hittable in both. The presentation (sidebar or
     title menu) is chosen anew on every sample, since the layout can change while the bar appears.
   - Home tab: `tab(_:in:)` first queried a tab bar the iPad does not have; at AX3 that query took about 30 s
     and used up the 10 s wait. The iPad's floating tabs are queried as the buttons they are, with the long
     hittable wait; selected and hittable are still both required, and the message says which failed.
   - Live text size (recovered work above): the two Settings-route tests match each live render of the Account row
     with a cold render at the same size (height and ink), since the row is 65 points at Large and AX1 alike.
   - The Settings route takes 760 to 860 s on the hosted iPad when nothing goes wrong, so the class's allowance
     is 1,200 s. Each workflow attempt starts at Large, a failing test runs at most twice
     (`-retry-tests-on-failure -test-iterations 2`), and the native-policy job keeps its result bundles on
     failure (7 days); snapshot shards still upload none.
5. `58a04fb37` workflow: the native-policy step's test list now matches `Test Case` lines (it matched none).

**Local checks (Xcode 27.2, iOS 27.2; not hosted proof):**
- Python: `python3 -m unittest discover -p 'test_*.py'` in `Scripts/visual`, **376/376** passed (92.8 s). This
  includes `test_snapshot_gate.py` and `test_hosted_simulator.py`; the fake shard timeout failure recorded
  during the recovery above did not recur. SwiftLint (`--strict`) on the changed Swift files: 0 violations.
- Snapshot coordinates through `run-snapshot-local.sh`, candidate mode: iPhone `CommentsSnapshotTests/testPostEmpty`
  at ja-accessibility5, **4/4 recorded** (portrait and landscape, light and dark, 5 settle reads each, first
  attempts); iPad `HistorySnapshotTests/testGrid` at ja-large portrait, **2/2 recorded**, every cover drawn. A
  freeze cannot be made on purpose here, so these show only that the changes keep the pictures; run 4 is the proof.
- Native policy on the 27.2 iPad: cold AX3 twice and cold AX1 twice, **4/4 passed** (54 to 68 s each); then the
  whole class, **10/10 passed** (930 s; the Settings test 196 s).
- Native policy on the 27.2 iPhone: the whole class, 8 of 10 passed before the local run was cut off by a
  harness time limit during the ninth (no failure); the two it had not reached were then run on their own,
  **2/2 passed** (search 106 s, Settings 165 s). Every run started at Large; each device was left Shutdown at
  Large with its accessibility settings as found.
- Not run: actionlint (not installed here; the workflow's YAML is parsed by `test_snapshot_gate.py`). No local
  27.0 run: the hosted pins (Xcode 27.1 27A9275, iOS 27.0 24A434) are unchanged and only the hosted run proves them.

**Run 4.** The fixes above, merged into `ci/snapshot-gate` with the same fault, `s03=crash,s20=no-artifact`, so
that run 3's unmet expectations are tested again: `triage` lists exactly s03 and s20, both retries make their
simulator and pass, both native-policy jobs pass, and the aggregate is green with all four classes at 0. A green
run is candidate mode and is not baseline approval.

### Open items for Phase 20 (release gate on the `aggregate` check)

Phase 20's release workflows require a successful check run named `aggregate` (the job id in
`snapshot-gate.yml`) on the shipped commit. That name stays as it is. Two gaps remain open:

1. A candidate-mode run pushed to `ci/snapshot-gate` also ends in a passing `aggregate` check, without any
   baseline comparison. On a commit that also has a compare run, the candidate run's check could shadow it.
2. The gate runs on pull requests, so a squashed or rebased commit on main may have no run of its own, and so
   no `aggregate` check.
