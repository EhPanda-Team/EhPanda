# 19-04 hosted measurement: picture cost, clone count and run-to-run identity

**Status: measured, no worker count chosen.** Under D-15's rule, no count of 2, 3 or 4 passes on the hosted runner.
The cost table (`Scripts/visual/snapshot-cost.json`, `source: model`) and `snapshot-shards.json` are therefore
unchanged. The decision is open; see "What this means".

- **Authority:** owner msg 2438 allowed pushing `ci/snapshot-measure`. The second push (one job per device and text
  size) was the lead's technical call within that go-ahead. The remote branch was deleted afterwards under the same
  go-ahead.
- **Sample:** the 19-05 classes (8 classes, 34 browsing scenarios) in `en-xSmall`, `en-large` and
  `en-accessibility5`. Per process that is 132 iPhone coordinates (both orientations) and 66 iPad coordinates
  (portrait). Each job records the candidate once at 2 workers, then compares at 2, 3 and 4, one `xcodebuild` at a
  time, and samples `kern.memorystatus_vm_pressure_level` about every 5 to 10 s.

## Runs

| Run | Commit on `ci/snapshot-measure` | Shape | Outcome |
|---|---|---|---|
| 42442284401 | `d8890c560` | one job per device | workflow error: a job `env` cannot read the `runner` context (fixed in `dfaf8c25a`) |
| 42442366372 | `f2e9b438b` (`[skip test]`) | one job per device | no usable data: every iPad picture `error` `geometry` (Windowed Apps gives a 20 pt bottom inset; the pin is Full Screen Apps, 25 pt); the iPhone job hit its 170-minute limit and its upload was cut off |
| 42455556948 | `5dfb3d13e` (`[skip test]`, tree of `ab5b71a57`) | one job per device and text size, 5 at a time | 5 jobs succeeded; `iphone en-xSmall` stopped at the 140-minute step limit after its candidate and the compare at 2 |

`ab5b71a57` sets Full Screen Apps on the iPad and reboots before Reduce Motion is set. It also splits the matrix and
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

## What this means (decision needed)

The plan's rule cannot choose a count, so the next step needs a decision. These are options, none taken:

1. **Accept `warn`:** count only `critical` as memory pressure, since `warn` is the runner's resting state under
   simulators. 3 workers then still fails `changed` and `incomplete`, so this alone does not choose a count.
2. **Fix the hosted identity first:** stabilise `shell-library-title-menu`, `front-page-search` (list rest) and the
   other menu scenarios on a loaded host, and lengthen or retry the landscape rotation wait (5 s). Then measure again.
   This is scenario work in the 19-05 and 19-01 code, not in this plan's scripts.
3. **Fewer, longer invocations:** with 7 to 10 minutes of fixed cost per `xcodebuild`, clones pay off only when one
   invocation captures far more pictures. Each process holds one configuration, so the lever is fewer runs per
   shard (fewer, larger shards), which changes the estimate more than the worker count does.
4. **Keep `xcodebuild` logs as artifacts** in the next measurement (they hold only synthetic fixtures), so a stall like
   the 2-hour candidate can be diagnosed.

Until then `snapshot-cost.json` stays `source: model` and the gate's shard plan is the 19-02 model plan.
