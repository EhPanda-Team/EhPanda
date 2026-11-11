---
phase: 19-visual-regression-marketing-export
plan: "10"
subsystem: ci
tags: [snapshot-gate, github-actions, shards, retry, triage, aggregate, native-policy, simulator]

requires: [19-04, 19-05, 19-06, 19-07, 19-08, 19-09, 19-11]
provides:
  - "`snapshot-gate.yml`: `checks`, `build`, 27 shards, `triage`, `retry`, `native-policy` (both devices) and `aggregate`, whose result is the run's verdict"
  - "`run-shard.sh`, `snapshot_fetch.py`, `snapshot_shard.py`, `hosted-simulator.sh`: one shard's pins, baseline slice, simulator, invocations, class re-run and `shard.json`"
  - "The gate wired into `deploy.yml`, `deploy-beta.yml` and `dependencies.yml`"
affects: [19-12, 19-13, 19-17, 20-11]

actuals:
  tasks: 4
  hosted_runs: 4

key-files:
  created:
    - Scripts/visual/run-shard.sh
    - Scripts/visual/snapshot_fetch.py
    - Scripts/visual/snapshot_shard.py
    - Scripts/visual/hosted-simulator.sh
    - .github/workflows/snapshot-gate.yml
    - .planning/phases/19-visual-regression-marketing-export/19-10-PROOF.md
  modified:
    - AppPackage/Tests/VisualSnapshotTests/Resources/scenarios.json
    - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioInventoryTests.swift
    - AppPackage/Tests/VisualSnapshotTests/Matrix/SnapshotMatrixCase.swift
    - AppPackage/Sources/VisualSnapshotSupport/HostedWindowCapture.swift
    - Scripts/visual/snapshot-shards.json
    - Scripts/visual/snapshot_aggregate.py
    - EhPandaUITests/NativeVisualPolicyUITests.swift
    - EhPandaUITests/Support/LiveTextSize.swift
    - .github/workflows/deploy.yml
    - .github/workflows/deploy-beta.yml
    - .github/workflows/dependencies.yml

requirements-completed: []

deferred:
  - "19-10 Task 4: a green snapshot-gate run (aggregate pass, triage naming only the injected shards)"
  - "19-12: the full hosted candidate run and the public snapshot repository"
  - "19-13: the owner's approval of the candidate set, the pinned baseline and a green hosted compare run"
  - "19-17: the controlled regression on the hosted runner"
---

# 19-10 summary: the snapshot gate is built; its green hosted run is deferred

**Status: closed without a passing hosted run** (owner msg 3425, product lead msg 3426). Tasks 1 to 3 are done
and verified locally. Task 4's proof of retries and error handling has been tried in three hosted runs, each
failing on causes that were then fixed. A fourth run was still running at handoff, and its result was not read.
The green run is a deferred item, owed before release day. VIS-18-01 stays Pending.

## Tasks 1 to 3 (delivered)

- **Task 1, inventory closed** (`0b8af222e`): the not-applicable rules from 19-05 to 19-08 are applied with their
  reasons (`favorites-category-menu` is not applicable on iPad, D-12), and `ScenarioInventoryTests` fails on any
  inventory ID without a factory. The Login gap was closed with option (a): `WaveForm` pauses under Reduce Motion
  (D-29) and `SettingsSnapshotTests` gained the three Login methods (`940ae2bf1`, `aa5fe657c`).
- **Task 2, the shard runner** (`acc1f213c`, `9741ff5b8`, `2fe20743a`): `run-shard.sh` checks the pins and records
  `drift` without capturing; fetches and verifies the baseline slice in compare mode (`snapshot_fetch.py`, sparse
  and blobless, SHA-256 per picture, `baseline-mismatch` / "no approved baseline yet"); makes the pinned simulator
  through `hosted-simulator.sh`; runs the shard's invocations (iPad turned per orientation, no clones in iPad
  landscape); re-runs once only the classes left without results; and writes `shard.json`.
- **Task 3, the workflow and its wiring** (`aeb19f7ce`, `832ac3d88`, `51e36c8b7`): `snapshot-gate.yml` with the
  jobs above, `fail-fast: false`, per-shard limits from `snapshot-shards.json`, candidate mode on `ci/snapshot-gate`
  while there is no `fingerprints.json`, and separate concurrency for PRs and candidate runs. `deploy.yml` and
  `deploy-beta.yml` need the gate in compare mode; `dependencies.yml` dispatches it. The fault switch
  `EHPANDA_SNAPSHOT_FAULT` exists only on the proof branch (`git grep` on the phase branch finds none).

## Task 4: hosted runs (details in `19-10-PROOF.md`)

| Run | Commit | Result | Causes found | Fixed by |
|---|---|---|---|---|
| 1, 42562780142 | `6460a82e7` | failed (92 min) | the aggregate missed a lone retried shard (artifact layout); no job selected the pinned Xcode, so every shard recorded `drift`; native policy failed on both devices | `2f5b2628c` (artifacts merged, pinned Xcode selected), `0e98cc0c9` (Xcode 27.1 pinned) |
| 2, 42577585956 | `3140c6665` | failed (9 h 47 min) | lost runners and stuck `bootstatus` / first writes; iPhone shards planned at 60 min needed 113+; the aggregate let a lost retry replace a good first attempt and capped its list; iPad landscape glass re-render steps kept settle reads from matching | `c99a3c0d4`, `dd8963996`, `4a61a9008` (27 shards), `62164ab1a`, `c2fdafbf6`, `be0b64f6a`, `a52224a73` (`19-10-PROOF.md` lists them under their pre-rebase hashes) |
| 3, 42727781967 | `c560ead1d` | failed (6 h 59 min) | see below | the run-4 fixes |
| 4, 42951290351 | `a100173b5` | **still running at handoff; result not read** | | |

Run 3 proved the faults and triage: s03 was killed by its injected crash, s20 left no artifact, `triage` selected
exactly s03 and s20, and s20's retry was a valid capture (1,076 recorded, 20 not applicable). The aggregate
counted 0 picture changes, 0 drift, 0 baseline mismatches and 529 infrastructure errors. Root causes and fixes:

- **Retry s03 could not make its simulator** (`Invalid runtime: …iOS-27-0` after the runtime left mid-setup):
  each create attempt now waits for the pinned runtime and downloads its pinned build if it does not come back
  (`67b76839c`). Why the image lost the runtime is not known.
- **s26 `history-grid` iPad timeouts:** a host freeze of about 27 minutes outlasted Kingfisher's 300 s memory
  expiry for the fixture covers, which then drew as spinning placeholders; fixture artwork no longer expires
  (`cede4bd90`).
- **s07 `comments-post-empty` landscape `geometry`:** the rotation wait was on the wall clock, so a freeze used it
  up unread; it now counts reads (`3226efb9f`).
- **iPad native policy cold AX1/AX3:** sidebar Downloads waited for a folder link that All Downloads never has;
  the iPad's Home tab was looked up through a tab bar it does not have; plus the Settings route's allowance, a
  Large start per attempt, at most two iterations, and result bundles kept on failure (`4898e6309`). The iPhone's
  "Settings never opened Larger Text" was fixed by `893517c89` and `9c1de0fbc`.

Local checks for the run-4 fixes (Xcode 27.2, iOS 27.2, so not hosted proof): Python 376/376; SwiftLint clean;
both run-3 coordinates recorded through `run-snapshot-local.sh` (4/4 and 2/2); native policy 10/10 on the iPad and
10/10 on the iPhone, and iPad cold AX1/AX3 4/4. Record: `830f2717a`.

`ci/snapshot-gate` was not deleted (plan step 5), because run 4 is still running on it. Run 4 was not cancelled.

## Deferred

**Task 4's pass proof: a green snapshot-gate run is still owed.** It needs a hosted run in which the `aggregate`
job passes and `triage` names only the injected shards (the faulty shards' retries pass). Plan step 4, the run
with a crash that persists on retry (the aggregate fails naming only that shard), is still owed too. The release
workflows refuse to ship without a passing check: `deploy.yml` and `deploy-beta.yml` already run the gate in compare
mode and `needs` it, so a 3.0 release cannot ship until a successful `aggregate` check exists on the shipped commit.
`deploy-pal.yml` does not exist yet; it arrives in Phase 20 and takes the same gate. **It must be done before release day.** First read run 42951290351's result: if it passed, it may
serve as the pass proof; if not, triage it as runs 1 to 3 were. A candidate-mode pass is not baseline approval
(19-12, 19-13). Two more open items for Phase 20 are in `19-10-PROOF.md` ("Open items for Phase 20"): a
candidate run's `aggregate` check could shadow a compare run on the same commit, and a squashed or rebased
commit on main may have no run of its own.

**Also deferred (owner msg 3428), each owing a run of the GitHub screenshot check (`snapshot-gate.yml` on the
hosted runner); none is marked done and none has a summary:**

- **19-12:** the full hosted candidate run (every shard in candidate mode, its pictures kept as artifacts) and the
  public snapshot repository (`EhPanda-Team/ehpanda-snapshot`, created with its README only; no pictures are pushed
  in 19-12). Needs the GitHub screenshot check to run green in candidate mode.
- **19-13:** the owner's one approval of that candidate set, the approved pictures pushed and pinned
  (`fingerprints.json`, `manifest.json`) and a green hosted compare run against them. Needs the GitHub screenshot check in
  compare mode; the release gate's `aggregate` check is only meaningful after this.
- **19-17:** the controlled regression on the hosted runner (D-18): a one-point change to one layout token on the
  proof branch makes the hosted gate fail with exactly the affected coordinates as picture changes and nothing as
  an infrastructure error, and restoring it makes the next run green; both run IDs go in `19-17-REGRESSION.md`.
  Needs the GitHub screenshot check in compare mode against the approved baseline. 19-17's local
  parts (README rewrite, preview-review docs) are not deferred and are planned separately.
