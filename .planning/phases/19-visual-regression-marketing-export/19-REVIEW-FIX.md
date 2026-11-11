---
phase: 19-visual-regression-marketing-export
fixed_at: 2026-11-11T00:00:00Z
review_path: .planning/phases/19-visual-regression-marketing-export/19-REVIEW.md
iteration: 1
findings_in_scope: 5
fixed: 5
skipped: 0
status: all_fixed
---

# Phase 19: Code Review Fix Report

**Fixed at:** 2026-11-11
**Source review:** `.planning/phases/19-visual-regression-marketing-export/19-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 5 (WR-01, WR-02, and the cheap, real Low items IN-01, IN-05, IN-10)
- Fixed: 5
- Skipped: 0

Scope was set by the owner brief: the two warnings plus IN-01, IN-05 and IN-10. IN-02, IN-03, IN-04, IN-06,
IN-07, IN-08, IN-09, IN-11, IN-12, IN-13, IN-14, IN-15 and IN-16 were left as they are (not attempted, not rejected);
they remain open in `19-REVIEW.md`. No hosted run was triggered and nothing was pushed.

## Fixed Issues

### WR-01: Release workflow has no concurrency guard

**Files modified:** `.github/workflows/deploy.yml`, `.github/workflows/deploy-beta.yml`
**Commit:** bded61963
**Applied fix:** a `concurrency` block (`deploy-release` / `deploy-beta`, `cancel-in-progress: false`) on the
`Deploy` job, so a second release queues behind the first instead of publishing a release and then failing the
catalogue push. Placed on the job rather than the workflow (a deviation from the review's suggested placement): a
pull request closed without merging also starts `deploy.yml`, and at workflow level it would take the group's one
pending place from a real release. The gate jobs still run in parallel. Note: GitHub keeps one running and one pending
run per group, so a third queued run replaces the pending second one; for releases that is rare and visible.

### WR-02: `reset_simulators` kills the whole host's simulator service

**Files modified:** `Scripts/visual/hosted-simulator.sh`
**Commit:** 62717e38a
**Applied fix:** the `killall -9 com.apple.CoreSimulator.CoreSimulatorService` now runs only when `CI` is set;
otherwise the helper prints a one-line note on stderr. The per-attempt device delete is unchanged.
**Test note:** `test_hosted_simulator.py::test_a_device_that_stays_not_booted_fails_the_attempt` asserts three
`killall` calls and passes only with `CI` set (hosted runners set it); run without `CI` it now fails 0 != 3. That test
encodes the old unconditional behaviour for a local run. It was not edited (owner rule); it needs `CI=true` locally
or a decision on how it should pin the environment.

### IN-01: `--started` misses non-parallel xcodebuild logs

**Files modified:** `Scripts/visual/snapshot_infra.py`
**Commit:** d878ce83b
**Applied fix:** `started()` matches `Test [Cc]ase '`, so serial runs (iPad turn, iPad landscape capture) are seen by
the startup watchdog. No test was added (owner rule); the review's suggested capital-C case is therefore not in
`test_snapshot_infra.py`.

### IN-05: The `issues: write` token reaches the xcodebuild tree and the checkout

**Files modified:** `Scripts/live-check/run-live-check.sh`, `.github/workflows/live-check.yml`
**Commit:** 297164e62
**Applied fix:** `xcodebuild` runs under `env -u GH_TOKEN -u GITHUB_TOKEN` (the reporter keeps the token), and the
checkout sets `persist-credentials: false`.

### IN-10: Deploy and dependency jobs have no `timeout-minutes`

**Files modified:** `.github/workflows/deploy.yml`, `.github/workflows/deploy-beta.yml`, `.github/workflows/dependencies.yml`
**Commit:** 7de7fa873
**Applied fix:** `timeout-minutes: 120` on the `Deploy` and `dependencies` jobs.

## Verification

- Workflow YAML parsed with Ruby `YAML.load_file` (actionlint is not installed): all edited workflows load; job
  keys checked.
- `bash -n` on both edited shell scripts.
- `python3 -m unittest` (pytest is not installed): `test_snapshot_infra`, `test_run_shard`, `test_snapshot_gate`
  (30), the three `Scripts/live-check` test modules: all pass. `test_hosted_simulator`: 9 pass with `CI=true`, 1
  fails without it (see WR-02).

## Skipped Issues

None of the five in-scope findings was skipped. Out-of-scope findings are listed above.

---

_Fixed: 2026-11-11_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
