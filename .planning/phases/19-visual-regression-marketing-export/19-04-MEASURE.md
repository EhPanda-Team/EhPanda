# 19-04 hosted measurement: picture cost, clone count and run-to-run identity

**Status: measured twice, no worker count chosen; interim 2 workers.** Run 42455556948 chose no count of 2, 3 or 4
under D-15's rule. The memory rule, the hosted identity, invocation length and log keeping were then addressed (see
"Follow-up: the four options") and `ci/snapshot-measure` was pushed once more. Run 42475531683 chose no count
either; its main finding is that the hosted simulator itself failed in 5 of 8 jobs. The developer then decided on
robust simulator steps, the two remaining iPhone identity fixes, and 2 workers as the interim count (see "Decision
after run 42475531683"). `snapshot-cost.json` stays `source: model`.

- **Authority:** owner msg 2438 allowed pushing `ci/snapshot-measure`. The second push (one job per device and text
  size) and the third (after the follow-up) were the lead's technical calls within that go-ahead.
- **Sample:** the 19-05 classes (8 classes, 34 browsing scenarios) in `en-xSmall`, `en-large` and
  `en-accessibility5`. Per process that is 132 iPhone coordinates (both orientations) and 66 iPad coordinates
  (portrait). Each job records the candidate once at 2 workers, then compares at 2, 3 and 4, one `xcodebuild` at a
  time, and samples `kern.memorystatus_vm_pressure_level` about every 5 to 10 s.

## Runs

| Run | Commit on `ci/snapshot-measure` | Shape | Outcome |
|---|---|---|---|
| 42442284401 | `d8890c560` | one job per device | workflow error: a job `env` cannot read the `runner` context (fixed in `c3ac1e5ea`) |
| 42442366372 | `f2e9b438b` (`[skip test]`) | one job per device | no usable data: every iPad picture `error` `geometry` (Windowed Apps gives a 20 pt bottom inset; the pin is Full Screen Apps, 25 pt); the iPhone job hit its 170-minute limit and its upload was cut off |
| 42455556948 | `5dfb3d13e` (`[skip test]`, tree of `1bebdd0a2`) | one job per device and text size, 5 at a time | 5 jobs succeeded; `iphone en-xSmall` stopped at the 140-minute step limit after its candidate and the compare at 2 |
| 42475531683 | `06bc94362` (`[skip test]`, tree of `6f0e5a657`) | after the follow-up: as above plus one all-sizes job per device, logs kept | 5 jobs succeeded, 3 cancelled (two hung creating the simulator, one never launched the app); see "Run after the follow-up" |

`1bebdd0a2` sets Full Screen Apps on the iPad and reboots before Reduce Motion is set. It also splits the matrix and
adds the step limit so partial measurements still upload. With it, every iPad picture reached the pinned geometry.

## Measurements (run 42455556948)

`snapshot_measure.py --runs <artifacts> --run-id 42455556948`. Median s = median seconds per picture per clone;
x at 2 = that median over the median at 2 workers for the device and text size; Speed-up = pictures × median ÷ wall.

| Device | Configuration | Workers | Pictures | Median s | x at 2 | Wall s | Speed-up | Memory | Changed |
|---|---|---|---|---|---|---|---|---|---|
| iphone | en-xSmall | 2 | 124 | 1.99 | 1.00 | 731 | 0.34 | warn | 1 |
| iphone | en-large | 2 | 126 | 2.09 | 1.00 | 705 | 0.37 | warn | 5 |
| iphone | en-large | 3 | 128 | 1.93 | 0.92 | 805 | 0.31 | warn | 0 |
| iphone | en-large | 4 | 127 | 2.06 | 0.98 | 1307 | 0.20 | warn | 1 |
| iphone | en-accessibility5 | 2 | 121 | 2.43 | 1.00 | 1261 | 0.23 | warn | 5 |
| iphone | en-accessibility5 | 3 | 115 | 2.22 | 0.91 | 1260 | 0.20 | warn | 2 |
| iphone | en-accessibility5 | 4 | 121 | 2.18 | 0.90 | 1689 | 0.16 | warn | 6 |
| ipad | en-xSmall | 2 | 66 | 2.93 | 1.00 | 613 | 0.32 | warn | 0 |
| ipad | en-xSmall | 3 | 64 | 2.36 | 0.80 | 794 | 0.19 | warn | 0 |
| ipad | en-xSmall | 4 | 66 | 2.12 | 0.72 | 633 | 0.22 | warn | 0 |
| ipad | en-large | 2 | 66 | 2.87 | 1.00 | 500 | 0.38 | warn | 0 |
| ipad | en-large | 3 | 66 | 2.24 | 0.78 | 419 | 0.35 | warn | 0 |
| ipad | en-large | 4 | 66 | 2.22 | 0.78 | 545 | 0.27 | warn | 0 |
| ipad | en-accessibility5 | 2 | 66 | 2.04 | 1.00 | 372 | 0.36 | warn | 0 |
| ipad | en-accessibility5 | 3 | 66 | 2.06 | 1.01 | 511 | 0.27 | warn | 0 |
| ipad | en-accessibility5 | 4 | 66 | 2.65 | 1.30 | 770 | 0.23 | warn | 0 |

- 2 workers: changed, memory
- 3 workers: incomplete, changed, memory
- 4 workers: incomplete, changed, memory, slowdown
- Chosen: none (2 workers is excluded)

`iphone en-xSmall` at 3 workers was cut off after 31 pictures, and the compare at 4 never ran. The `ipad en-xSmall`
compare at 3 has no result lines for `front-page-search` portrait (light and dark) and exited 65; the reducer does not
yet count missing lines.

### Why each rule excluded

- **Memory:** `warn` was sampled during every run on every host, at every count. It also occurred during the
  candidate at 2 workers and in iPad runs whose 66 pictures all passed. Per job, 7 % to 23 % of samples were `warn`
  and none were `critical`. Example: iPad `en-large`, 33 of 211 samples. The runner shows pressure with two clones
  already, so the rule cannot separate the counts.
- **Changed** (iPhone only; iPad 0 at every count): 20 `changed` pictures against the same host's candidate. The
  repeat offenders are `shell-library-title-menu`, changed in all four coordinates in `en-large` at 2 and in
  `en-accessibility5`. The others are `front-page-search` (the list rests at a different scroll offset, visible in the
  difference image), `toplists-period-menu` landscape, `agewall-ticked` landscape and `analytics-choice-none`
  landscape. Locally, 19-05 passed these twice; on the hosted runner, run-to-run identity does not hold for them.
- **Slowdown:** only iPad `en-accessibility5` at 4 (1.30 × the median at 2). Elsewhere the per-clone median at 3 and
  4 is 0.72 to 1.01 × the median at 2.
- **Also seen, not a rule:** 42 iPhone `error` `geometry` pictures, almost all landscape, spread across scenarios and
  counts. The rotation did not reach the pin within the 5 s wait. 5 iPhone `en-accessibility5` coordinates and 2
  `en-xSmall` coordinates have `missing-baseline`, because their candidate timed out or failed.

### Time per xcodebuild and stalls

| Job | Boot and fetch | Candidate (2 workers) | Compares (2 / 3 / 4) |
|---|---|---|---|
| iphone en-xSmall | 5.7 min | 2 h 01 min | 12.2 min / cut off / not run |
| iphone en-large | 4.9 min | 12.8 min | 11.8 / 13.4 / 21.8 min |
| iphone en-accessibility5 | 7.5 min | 60.0 min | 21.0 / 21.0 / 28.2 min |
| ipad en-xSmall | 12.0 min | 11.8 min | 10.2 / 13.2 / 10.6 min |
| ipad en-large | 6.8 min | 7.5 min | 8.3 / 7.0 / 9.1 min |
| ipad en-accessibility5 | 7.6 min | 8.0 min | 6.2 / 8.5 / 12.8 min |

The capture itself is small: 66 to 132 pictures at about 2 to 3 s each is 2 to 5 clone-minutes. Each invocation
still took 6 to 28 minutes, about 7 to 10 minutes of it fixed cost: clone creation, installing the app and test runner
on each clone, launch, and uneven class sizes. So the clone speed-up (0.16 to 0.38) is below one simulator, and more
clones do not shorten the wall time. Two iPhone candidates stalled for 1 to 2 hours. The `xcodebuild` logs stayed on
the runners, so the stalled test is not known.

## R-1: billing and runner

| Run | `GET /actions/runs/{id}/timing` | Jobs: runner group, labels |
|---|---|---|
| 42442366372 | `{"billable":{},"run_duration_ms":11330000}` | `GitHub Actions`, `[xcode-27]` (runners 1000000630 to 632) |
| 42455556948 | `{"billable":{},"run_duration_ms":9699000}` | `GitHub Actions`, `[xcode-27]` (runners 1000000634 to 640) |

The billable object is empty, so no billable minutes were reported. The runner group is GitHub's own group, not a
larger-runner group, so `xcode-27` is a standard GitHub-hosted runner. Image: `xcode-27-arm64` `20261104.0337.1`
(provisioner `20261103.629`), Xcode build `27A9275`.

## Per-PR estimate

D-13 estimated **about 1½ to 2¼ hours per PR** (1.2 to 2.4 s per picture, 2 clones at 1.7×, 5 Macs at once,
30 minutes of build, 10 minutes of boot and fetch per shard). Measured on the hosted runner, with the current
20-shard plan (2 to 3 runs per shard, 5 shards at a time):

- **Build:** 8 to 14 minutes (`build` job, two runs).
- **Boot and fetch per shard:** 5 to 12 minutes, before any baseline fetch (`timing.json`: 296 to 719 s).
- **Per run:** 7 to 10 minutes of fixed cost, plus capture at the measured medians (iPhone 2.0 to 2.4 s, iPad 2.0 to
  2.9 s per picture), counted generously as halved by 2 clones.
- **Result:** each shard 41 to 66 minutes. Twenty shards at 5 at a time come to **about 3¼ to 3¾ hours of shards, so
  about 3½ to 4 hours per PR**, if nothing stalls. That is more than D-13's estimate. A stall like the two above
  (1 to 2 hours) puts a shard past the 2 × estimate timeout, so the shard retry (D-15) runs.
- **Concurrency:** more than 5 parallel shards needs GitHub Enterprise (50 macOS jobs) or a limit increase through
  GitHub support. The standard plans run at most 5 macOS jobs at once, and further jobs queue (D-15 amendment).

## What this means

The plan's rule could not choose a count from run 42455556948. These were the options:

1. **Accept `warn`:** count only `critical` as memory pressure, since `warn` is the runner's resting state under
   simulators. 3 workers then still fails `changed` and `incomplete`, so this alone does not choose a count.
2. **Fix the hosted identity first:** stabilise `shell-library-title-menu`, `front-page-search` (list rest) and the
   other menu scenarios on a loaded host, and lengthen or retry the landscape rotation wait (5 s). Then measure again.
3. **Fewer, longer invocations:** with 7 to 10 minutes of fixed cost per `xcodebuild`, clones pay off only when one
   invocation captures far more pictures.
4. **Keep `xcodebuild` logs as artifacts** in the next measurement, so a stall like the 2-hour candidate can be
   diagnosed.

The lead took all four as a technical call within owner msg 2438's go-ahead, followed by one more measurement.

## Follow-up: the four options

### 1. Memory rule

`snapshot_measure.py` excludes a count only for a `critical` sample during its run; `warn` is still counted and shown
in the table. 19-CONTEXT D-15 and the 19-04 plan's truth carry the amendment and its source.

### 2. Hosted identity: root causes and fixes

Two facts about the evidence came first:

- **The difference images were wrong.** The snapshot library builds its difference picture by reading both images'
  bytes as 8-bit RGBA, but a capture is 16-bit RGB (48 bits a pixel). Its picture is the first two thirds of the
  bytes at the wrong stride, and nothing in the bottom third of a picture ever shows in it. Reconstructing the real
  differences from run 42455556948's actual pictures showed where each change was. `HostedWindowCapture` now draws
  its own difference picture from the same 8-bit sRGB bytes the comparison reads (a changed pixel white, brighter the
  larger the change; an equal pixel the actual picture at an eighth of its brightness). The comparison and its
  tolerances are unchanged.
- **Settled did not mean at rest.** The settle loop took a picture once the window's reads stayed identical for
  `stableSpan`. On a loaded host a scroll indicator that a scroll view flashes when it appears holds still for longer
  than that before it fades, and a list can hold one offset between two steps of an animation. One run captured the
  indicator or the intermediate offset and the next did not.

| Scenario | Changed in run 42455556948 | Root cause | Fix |
|---|---|---|---|
| `shell-library-title-menu` | 12, every coordinate in `en-large` at 2 and `en-accessibility5` | Favorites under the menu hides its search field on scroll. Hosted early in a process, the list had not come to rest at its top, so the field was 2 pt short. | The scenario first brings its list to rest at the top (`restingAtTop()`), as the Favorites scenarios already do. The menu indicator stays hidden as before. |
| `front-page-search` | 4 | Activating the search bar moves the list and scrolls the field's text to the caret. The caret freeze came after a fixed 800 ms, so on a loaded host it could freeze either one mid-way. | The step waits until the window is at rest before freezing the caret, and the list is brought to rest at its top first. |
| `toplists-period-menu` landscape | 2 | The difference is the flashed vertical scroll indicator at the trailing edge, captured in one run and not in the other. | Settle counts identical reads only while nothing moves: no scroll view tracked, dragged or decelerating, no scroll indicator showing, no finite layer animation still running. Repeating animations (an indicator's spin, a caret's blink) and layers frozen at `speed` 0 do not count as motion. |
| `agewall-ticked` landscape, `analytics-choice-none` landscape | 1 each | The library's picture shows no difference, so the change is in the bottom third. Both are landscape pages whose text scrolls under a pinned button, so the scroll view flashes its indicator when it appears. This is the same class as above, inferred from the layout because the run kept no usable difference. | Same settle fix. |
| Landscape rotation (42 `geometry` errors) | — | On a loaded host the rotation took longer than the fixed 5 s wait. | The wait polls until the window matches the pin, for up to 20 s, then makes the request once more with the same wait. The geometry pin itself is unchanged. |

A settle timeout now names the last motion it read (a view or layer class and animation key, never page text), and
a picture that passes only on its second attempt (`flaky`) keeps its first attempt's picture and difference beside it
(`first-actual/`, `first-difference/`), so the next hosted run shows what moved.

**Local proof** (Xcode 27.2, iOS 27.2 runtime, iPhone Air, the 19-05 classes, 3 workers, each compare beside 8
`yes` loops to load the host):

| Configuration | Candidate | Compare 1 | Compare 2 | Compare 3 | Compares identical |
|---|---|---|---|---|---|
| `en-large` | 132 recorded | 132 passed (1 flaky, built before the first-attempt artifacts) | 132 passed, 0 flaky | 132 passed, 0 flaky | compares 2 and 3: 132 of 132 SHA-256 equal |
| `en-accessibility5` | 132 recorded | 132 passed, 0 flaky | 132 passed, 0 flaky | — | 132 of 132 SHA-256 equal |
| `en-xSmall` | 132 recorded | 132 passed, 0 flaky | 132 passed, 0 flaky | — | 131 of 132 SHA-256 equal |

All 4 `notApplicable` coordinates are the same in every run, and no picture was `changed`, `timeout` or `error`. The
only byte differences are in loading scenarios, whose indicator the scenario holds still at whatever angle it
reached: `front-page-loading` landscape light (`en-large`, the candidate against its compares) and `popular-loading`
portrait light (`en-xSmall`, one compare against the other). Both pass the comparison.

### 3. Fewer, longer invocations

A shard runs its units as few `xcodebuild` invocations as it can: one per orientation group, holding every
configuration of that group (`-only-test-configuration` once per configuration). The simulator clones are created
once per invocation and reused across its configurations. Locally, en-xSmall alone took 208 s of testing at 3
workers, and en-xSmall with en-large in one invocation took 284 s, so the second configuration added 76 s and the
same three clones ran both.

- `snapshot_shards.py` writes each shard's `invocations` (an iPhone shard 1, an iPad shard 2: portrait and
  landscape) and counts the cost table's `invocationMinutes` once per invocation in the estimate.
- `snapshot-cost.json` (still `source: model`) gains `invocationMinutes: 8.5`, the middle of the 7 to 10 minutes from
  run 42455556948. The model plan now estimates 47.6 to 60.7 minutes a shard.
- The measurement adds an `all` job per device that records all three text sizes in one invocation at 2 workers.
  With F as the fixed cost of an invocation, each single-size candidate takes F + C_i and the `all` candidate takes
  F + sum(C_i), so `snapshot_measure.py` derives F = (sum of the single walls - the `all` wall) / 2 and writes the
  larger device's F as `invocationMinutes`.

### 4. Logs

Every invocation's `xcodebuild` log is uploaded under `logs/` in the job's artifact (they hold only synthetic
fixtures), and `run-snapshot-local.sh` takes `--workers` and several configurations so the hosted shape can be run
locally.

## Run after the follow-up (run 42475531683)

Commit `06bc94362` on `ci/snapshot-measure` (`[skip test]`, tree of `6f0e5a657`), 8 measure jobs, 5 at a time. Run
duration 3 h 40 min. R-1: `{"billable":{}}`; every job ran in runner group `GitHub Actions` with label `xcode-27`
(runners 1000000641 to 649), image `xcode-27-arm64` `20261104.0337.1`, so it is still a standard, unbilled runner.

| Job | Outcome |
|---|---|
| ipad all | candidate of all three sizes in one invocation: 198 recorded in 13.5 min |
| iphone all | candidate of all three sizes in one invocation: 396 recorded in 34.3 min; exit 65 because the runner process of one clone ended during `ToplistsSnapshotTests.testGrid()` after its pictures were written |
| ipad en-xSmall | candidate 10.0 min, compares at 2 / 3 / 4: 66 passed each; at 4 a clone failed to boot within 60 s and the run took 35 min |
| ipad en-large | candidate 11.0 min, compares at 2 / 3 / 4: 66 passed each |
| iphone en-accessibility5 | candidate 132 recorded. The compares at 2 and 3 produced no pictures: the test runner could not launch, because a clone was still "Shutting Down" from the previous invocation, and then the connection to it was lost. The compare at 4: 129 passed, 3 changed, 1 flaky |
| iphone en-large | the candidate started no test in 46 min (the app launch on the clones never returned); the job was then cancelled by the runner at 51 min, before its step limit |
| iphone en-xSmall, ipad en-accessibility5 | "Create the pinned simulator" (`simctl create`, `boot`, `bootstatus`) hung until the 170-minute job limit; no artifact |

`snapshot_measure.py --runs <artifacts> --run-id 42475531683`:

| Device | Configuration | Workers | Pictures | Median s | x at 2 | Wall s | Speed-up | Memory | Changed |
|---|---|---|---|---|---|---|---|---|---|
| iphone | en-accessibility5 | 2 | 0 | - | - | 53 | - | normal | 0 |
| iphone | en-accessibility5 | 3 | 0 | - | - | 147 | - | normal | 0 |
| iphone | en-accessibility5 | 4 | 132 | 2.09 | - | 996 | 0.28 | warn | 3 |
| ipad | en-xSmall | 2 | 66 | 2.27 | 1.00 | 418 | 0.36 | warn | 0 |
| ipad | en-xSmall | 3 | 66 | 2.48 | 1.09 | 698 | 0.23 | warn | 0 |
| ipad | en-xSmall | 4 | 66 | 3.15 | 1.39 | 2079 | 0.10 | warn | 0 |
| ipad | en-large | 2 | 66 | 2.87 | 1.00 | 481 | 0.39 | warn | 0 |
| ipad | en-large | 3 | 66 | 3.46 | 1.21 | 769 | 0.30 | warn | 0 |
| ipad | en-large | 4 | 66 | 2.50 | 0.87 | 769 | 0.21 | warn | 0 |

- 2 workers: incomplete
- 3 workers: incomplete
- 4 workers: changed, slowdown
- Chosen: none (2 workers is excluded)
- Fixed cost per invocation: not measured (no device has all three single-size candidates)

`critical` was never sampled; `warn` was sampled as before and no longer excludes.

### What the run showed

- **Identity, iPad:** 0 changed and 0 flaky at every count, as before.
- **Identity, iPhone** (only `en-accessibility5` at 4 workers ran): 3 changed, against 6 at the same configuration
  and count in run 42455556948. The kept first attempts and the new difference pictures show each cause:
  - `front-page-search` portrait light and dark, on both attempts: the search field shows no caret and its text is
    not scrolled to the end, so the field was not focused when the picture was taken. `becomeFirstResponder()`
    returned true, so the focus was taken back during the search bar's activation on a loaded host. This is a new
    root cause, distinct from the text-offset race fixed above; the step must check that the field is still first
    responder after rest and focus it again if not.
  - `home-loading` portrait light: the indicator and the loading card's glass edge around it differ.
    `freezeIndicators` stops the indicator's layer at whatever angle it has reached when the step runs, so the angle
    depends on timing; locally the same shows as byte differences that stay within the comparison
    (`front-page-loading`, `popular-loading` above), and on the loaded hosted runner it exceeded it. The freeze must
    stop the indicator at a fixed point of its animation, not at the current time.
  - `analytics-choice-none` landscape light (flaky, passed on its second attempt): the first attempt differed only
    in fine noise over the glass button and the scroll edge at the bottom, the material sampling the content behind
    it before that content was at rest.
  - The rotation wait: 0 `geometry` errors in every run of this measurement (42 in run 42455556948).
- **Hosted simulator reliability is now the blocker.** Of 8 measure jobs, 2 hung in `simctl` for 2 h 50 min, 1 never
  launched the app on its clones, and 3 invocations failed or slowed on clone boot, shutdown or launch. None of these
  is a picture difference, and `xcodebuild` reports them only as `Failed to install or launch the test runner`,
  `Timed out trying to boot simulator` or a lost connection. The kept logs show that the stalls of run 42455556948
  (iPhone candidates of 1 to 2 hours) were most likely the same: no test case starts in the log.
- **Fixed cost per invocation:** iPad single sizes took 10.0 min (`en-xSmall`) and 11.0 min (`en-large`) and all three
  sizes in one invocation 13.5 min. With a single-size cost of about F + C and the three together F + 3C, that gives C
  of about 1.5 min and F of about 9 min, which agrees with the 7 to 10 minutes and the `invocationMinutes: 8.5` of the
  model. On the iPhone, all three sizes took 34.3 min in one invocation (396 pictures); no iPhone single size
  finished in this run to compare it against.

### What this means

D-15's rule still cannot choose a count, now mainly because the hosted simulator fails runs, not because pictures
change. The options were:

1. **Harden the hosted simulator steps:** a step limit on "Create the pinned simulator" with one retry, wait for the
   previous invocation's clones to be deleted before the next `xcodebuild`, and count an invocation that fails to
   launch or boot as `infra` (retried once) rather than as an incomplete count. Then measure again.
2. **Fix the two remaining iPhone identity causes:** re-focus the search field after rest when it lost focus, and
   freeze loading indicators at a fixed point of their animation. Prove it locally as before.
3. **Decide on the iPad data alone:** iPad passed identity at 2, 3 and 4 in both runs; 3 workers was 1.09 and 1.21
   times the time at 2 here and 0.78 to 1.01 in run 42455556948. That is not D-15's rule (which needs every device and
   text size), so it needs the owner.
4. **Stay at 2 workers on the model** for the gate until a hosted run completes, with the shard plan's
   `invocationMinutes` estimate (47.6 to 60.7 minutes a shard).

## Decision after run 42475531683

The developer took options 1 and 2, and option 4 as the interim setting; not option 3. The remote `ci/snapshot-measure`
was deleted afterwards (owner msg 2637). Another hosted measurement needs a fresh go-ahead from the owner.

### Interim worker count: 2

Until a hosted run passes D-15's rule, the plan runs **2 workers** (`snapshot-cost.json` `workers: 2`, still
`source: model`; `snapshot-shards.json` is generated from it). The reasons:

- 2 is the rule's base count, so it is the one count D-15 never excludes for slowdown, and every candidate of both
  hosted runs recorded at 2.
- Neither hosted run showed 3 or 4 workers shortening the wall time: the clone speed-up stayed between 0.10 and 0.39
  at every count, because the fixed cost per invocation (about 9 minutes) dominates the capture (the tables above).
- More clones mean more clones to boot, launch and shut down, which is where run 42475531683 failed.
- Deciding on the iPad data alone (option 3) was declined: D-15's rule needs every device and text size.

### Option 2: the two remaining iPhone identity causes

| Scenario | Root cause | Fix |
|---|---|---|
| `front-page-search` | `becomeFirstResponder()` returned true, but on the loaded hosted runner the search bar's activation took the focus back; both attempts captured an unfocused field with its text scrolled to the start and no caret. | The step focuses the field again until it is still first responder after the window has come to rest twice in a row (at most 15 s), then freezes. |
| `home-loading` (and every scenario that uses `freezeIndicators`) | Stopping the hosted view's layer clock right after hosting held the indicator wherever its animation happened to be: an animation committed before the stop showed its model value, one committed after it its first frame, and the appearing loading card could be held part-way in. Which one a run got depended on load; locally `home-loading`, `front-page-loading` and `popular-loading` each had two byte-different states across runs. | `freezeIndicators` waits until the window is at rest (every commit and finite transition done), stops the clock, and restarts every animation that repeats for as long as its view shows at its first frame, so an indicator is always held at the same point. |

Local proof under load (Xcode 27.2, iOS 27.2, `EhPanda iPhone Air`, the eight iPhone classes, 3 workers; per size a
candidate, then two compares against it, each compare beside 8 busy `yes` loops):

| Size | Candidate | Compare 1 | Compare 2 | `front-page-search` + `home-loading` (8 pictures) | All pictures byte-identical across the compares |
|---|---|---|---|---|---|
| en-large | 132 recorded, 192 s | 132 passed, 0 changed, 0 flaky, 202 s | 132 passed, 0 changed, 0 flaky, 207 s | 8 of 8 identical | 132 of 132 |
| en-accessibility5 | 132 recorded, 215 s | 132 passed, 0 changed, 0 flaky, 216 s | 132 passed, 0 changed, 0 flaky, 196 s | 8 of 8 identical | 132 of 132 |
| en-xSmall | 132 recorded, 196 s | 132 passed, 0 changed, 0 flaky, 222 s | 132 passed, 0 changed, 0 flaky, 226 s | 8 of 8 identical | 131 of 132 |

Each size also has 4 not-applicable coordinates. The one en-xSmall picture that differed, `watched-signed-out`
portrait light, passed at the first attempt in both compares; its bytes differed only below the comparison's
precision (the capture's low bits, which the comparison ignores), and compare 2 matched the candidate's bytes.
Before the fix, the loading scenarios had two byte-different states across local runs.

### Option 1: robust hosted simulator steps

- **Simulator setup** (`Scripts/visual/hosted-simulator.sh create`): every `simctl` call has its own limit (create
  2 min, boot 3 min, boot status 5 min, settings 1 min). A failed or overrun attempt is deleted, the simulator
  service is restarted, and the setup is made once more. The step has a 45-minute limit over both attempts; the
  job's limit went from 170 to 200 minutes so the upload still runs after it.
- **Clones between invocations** (`hosted-simulator.sh clear-clones`): before every `xcodebuild`, the previous
  invocation's clones ("Clone N of EhPanda measure", in the parallel-testing device set) are shut down and deleted,
  waiting up to 10 minutes, so no invocation reaches a clone that is still shutting down.
- **Startup watchdog:** an invocation with no test case begun after 20 minutes is stopped (the stalls of 46 minutes
  and 1 to 2 hours never began a test).
- **Infra, retried once** (`Scripts/visual/snapshot_infra.py`): an invocation that exits non-zero with a simulator
  failure in its log (clone shutting down, boot timeout, device not prepared, lost runner connection, simulator
  service died, runner not launched) or stopped by the startup watchdog is infra. It is made once more after the
  clones are cleared; the failed attempt's log and result lines are kept beside it (`-infra`). A run that fails that
  way twice records the reason in `shard.json` `infra`, and `snapshot_measure.py` reports its count as `infra`
  instead of `incomplete`. A failed, hung or crashed test is never infra.

### Unit test failure in run 42490998810

The Test workflow's run 42490998810 failed only `HostedWindowCaptureTests.testStaticViewSettlesAfterTheStableSpan()`:
`XCTAssertGreaterThanOrEqual failed: ("4") is less than ("5")` at line 26 (the xcresult; the failed log does not
carry the message). The test assumed host speed. Settling is timed: identical reads must span 500 ms, and each gap is
the 100 ms sample interval plus a capture, so a slower host closes the span in fewer reads. Locally a still view
settled on read 5 in every iteration, beside 8 or 32 busy loops (0.63 to 0.66 s; a gap of about 127 ms, just over the
125 ms that makes it 4). With the app clamped to background priority it settled on read 3. The floor is now two
reads; the assertion that the reads span the stable span, which is the contract, stays.

The clamp also showed `testChangingViewTimesOutAfterTheSampleCap()` settling once in 20 iterations (35 reads, not
40): its 50 ms `TimelineView` went 500 ms without a redraw. The changing view now paints its draw count and asks to be
redrawn after every draw on the main queue, ahead of the settle loop's next read, so consecutive reads always differ.
How the fix was checked (`HostedWindowCaptureTests`, FeatureTests plan, 20 iterations each):

- Beside 8 busy loops, all 9 tests passed 20 of 20.
- Clamped, the old changing view failed 1 of 20 and the new one passed 20 of 20.
- Clamped, the static test passed every iteration that ran (18), where the old floor failed every one.

The "did not return a process handle" launch error at 15:10:48Z in that run was on clone 2, not clone 1, and did
not fail the run: xcodebuild launched the app again, and the result bundle has 1 failure, 1822 passed and no test that
did not run. On the measurement workflow, the same error is infra and is retried once (option 1).

## Final hosted run (needs the owner's go-ahead)

`snapshot-measure.yml` as committed: one build job (90-minute limit; 8 minutes in run 42475531683), then 8 measurement
jobs, iPhone and iPad at en-xSmall, en-large, en-accessibility5 and `all`. The `xcode-27` runners took 5 of them at a
time. Each job does the following:

- Creates the pinned simulator (45-minute limit, one retry).
- Records the candidate at 2 workers, then compares it at 2, 3 and 4 workers. Every invocation clears the previous
  clones first, has the 20-minute startup watchdog, and gets one infra retry. The step's limit is 140 minutes.
- Uploads the shard (job limit 200 minutes).

What it measures: per job and worker count, the wall time of each `xcodebuild`, and its passed, changed, flaky,
timeout and infra counts. It also measures the memory pressure, and the identity of every compare picture against the
candidate. D-15's rule then decides the count from memory pressure, changed pictures and per-clone slowdown against
2 workers, across every device and text size.

Expected wall time: in run 42475531683 the jobs that did not stall took 24.5 to 75 minutes (the first five started
together, the other three as slots freed), and the run took 3 h 40 min only because two jobs stalled to the old
170-minute limit. Without stalls, the run should take about 1.5 to 2.5 hours: the build, then two waves of jobs of
about 25 to 75 minutes each. Now a stalled start costs at most the 20-minute watchdog plus one retry, not the job's
limit. The ceiling is the limits: 90 minutes of build, then two waves of 200-minute jobs, about 8.2 hours.
If the run passes the rule, its count replaces the interim 2 (`source: hosted`); until then the plan stays at 2.
