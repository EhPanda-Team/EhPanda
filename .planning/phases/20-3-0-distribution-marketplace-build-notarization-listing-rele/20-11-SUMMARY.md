---
phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele
plan: "11"
subsystem: release-gate
tags: [snapshot-gate, release, altstore-pal, github-actions, ci]

requires:
  - phase: 19
    provides: "snapshot-gate.yml with the `aggregate` verdict job (closed with deferred items; owner msgs 3425, 3428, 3573)"
provides:
  - "`actions-tool/require-snapshot-gate.sh <sha> <check name> [--merged-pr] [--compare-only]`: the release's and the PAL submission's reliance on the screenshot check"
  - "`deploy.yml` and `deploy-pal.yml` require the verdict right after Checkout"
  - "`20-11-GATE.md`: OQ-F's answer, the check name, the live reads and the two settled points"
affects: [20-08, 20-13]

actuals:
  tokens: n/a
  tasks: 3
  commits: 9

tech-stack:
  added: []
  patterns: ["fake `gh` on PATH for script tests"]

key-files:
  created:
    - actions-tool/require-snapshot-gate.sh
    - actions-tool/tests/test_require_snapshot_gate.py
  modified:
    - .github/workflows/deploy.yml
    - .github/workflows/deploy-pal.yml
    - actions-tool/tests/test_workflows.py
    - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-11-GATE.md

key-decisions:
  - "OQ-F = main-first (owner msg 3346): this branch merged `main` (merge `31c19a12f`); nothing was merged from or committed to `feature/gsd-phase-19`."
  - "The check name is `aggregate`, the job ID of `snapshot-gate.yml`'s verdict job (no `name:`); the name test now reads the real file and passes."
  - "Point 1 (PAL `github.sha`): `main` is linear (squash or rebase) and `snapshot-gate.yml` does not run on a push to `main`, so a dispatch on the release commit could never find a verdict. Fixed in the script with `--merged-pr` (read the merged PR's head); deploy-pal.yml passes it."
  - "Point 2 (candidate runs): a candidate run is also an `aggregate` check run and passes without comparing. Fixed in the script with `--compare-only` (the check run's workflow run must have the event `pull_request`, which always means compare); both workflows pass it. `snapshot-gate.yml` is unchanged."
  - "Exit 1 is the honest live result today: Phase 19's gate pass is deferred and there is no approved baseline, so no compare run has passed."

patterns-established:
  - "Tests for a script that calls `gh` route the fake by URL (check runs, a commit's pull requests, a workflow run)."

requirements-completed: []

coverage:
  - id: D1
    description: "The release and the PAL submission stop unless the screenshot check concluded `success`, naming the commit and the state"
    requirement: REL-18-01
    verification:
      - kind: test
        ref: "test_require_snapshot_gate.py (24 cases, fake gh); test_workflows.py step place, SHA, token, flags, permissions"
        status: pass
    human_judgment: false
  - id: D2
    description: "Reliance proven against GitHub's real check data"
    requirement: REL-18-01
    verification:
      - kind: manual
        ref: "20-11-GATE.md Task 3: PR 469's head (aggregate failure), the candidate branch head and a commit with no run, all exit 1; the exit 0 path is not yet reachable live (no green compare run)"
        status: partial
    human_judgment: false

duration: n/a
completed: 2026-11-11
status: complete
---

# Phase 20 Plan 11: the release relies on the screenshot check Summary

**The release (`deploy.yml`) and the PAL submission (`deploy-pal.yml`) refuse to run unless Phase 19's `aggregate`
check passed in a compare run on the right commit. Merging `main` brought the gate in. Live reads against
`EhPanda-Team/EhPanda` all exit 1, which is the honest result: Phase 19's gate pass is deferred and no approved
baseline exists.**

## Accomplishments

- **Task 1, OQ-F.** Answered by owner msg 3346 ("wait for phase 19 closure. before that, we update the github
  actions workflow"): `main-first`. Phase 19 closed and reached `origin/main` (`57e5e6f2b`, owner msgs 3425, 3428,
  3573); this branch merged it as `31c19a12f`.
- **The merge.** Conflicts in `.github/actionlint.yaml` (add/add; `main`'s comment kept, same `xcode-27` label),
  `.github/workflows/deploy.yml` (both kept: `main`'s `snapshot-gate` reusable-workflow job, `needs`, timeout and
  concurrency, plus this branch's "Require the screenshot check" step and `checks: read`), `.planning/ROADMAP.md`
  (Phase 19 complete with deferred items from `main`; Phase 20's own line and progress from here) and
  `.planning/STATE.md` (frontmatter: phase 20, `completed_phases: 19`; both bodies kept). The state's current phase
  stays 20. After it: `actions-tool` tests green (186 then), actionlint clean on the four workflows,
  `Scripts/visual` tests green (384).
- **Task 2 (earlier, `6d8e46499`, `ae7c691c6`).** The script and both steps. Now also: the name test runs against
  the real `snapshot-gate.yml` and passes with `aggregate`.
- **Task 3 and the two open points.** See `20-11-GATE.md`. Two real gaps, both fixed in `actions-tool`:
  1. A PAL dispatch on a commit on `main` has no check run (the gate does not run on pushes to `main`; history is
     linear): `--merged-pr` reads the verdict on the merged pull request's head.
  2. A candidate-mode run is also an `aggregate` check run and passes: `--compare-only` requires the check run's
     workflow run to come from a `pull_request` event.

## Task Commits

1. **Merge of `origin/main`:** `31c19a12f`.
2. **RED (script):** `50668dd74`. **RED (workflow steps):** `687a8ccbe`.
3. **GREEN:** `9cc65e33e` (script, `deploy.yml`, `deploy-pal.yml`; the RED commits spelled the second option
   `--event pull_request`, renamed in GREEN because `deploy-pal.yml`'s own "dispatched by hand only" test forbids the
   word `pull_request` in that file; that assertion is untouched).
4. **Docs:** `82b11cebd` (`20-11-GATE.md`), and the commit that adds this summary and updates ROADMAP and STATE.

## Deviations from Plan

1. **The plan says the release never runs the gate; `main` now does.** `deploy.yml` and `deploy-beta.yml` call
   `snapshot-gate.yml` in compare mode and `Deploy` needs it (19-10). That call's check is named
   `snapshot-gate / aggregate`, so this plan's step (name `aggregate`, the PR head's own run) is independent and kept
   as the second line. Whether to drop it is the owner's call.
2. **The script gained two options** beyond the plan's `<sha> <check name>` (points 1 and 2). Both workflows' jobs
   gained `actions: read` (the lookup of the workflow run).
3. **The name test is read from the file**, as the plan said; Task 2 could not do that before the merge.

## Requirements

- **REL-18-01:** stays Pending. The build-number, history and download-URL parts are done at 20-02; this plan adds the
  gate reliance. The requirement also covers the final Release isolation scan (20-14).

## Open items

- **First live exit 0** needs a green compare run, which needs an approved baseline and a hosted pass (Phase 19's
  deferred items). Until then every release and PAL submission is refused, as intended.
- **PR 469** (dependabot bump of `actions/download-artifact` to 8) fails the gate's own script tests
  (`Scripts/visual` expects `@v7`); Phase 19's workflow files are not edited here.
- **The deploy.yml double gate** (deviation 1): the owner may drop this plan's step in favour of `main`'s call.
- **`allow_*_merge` settings** are not visible to the agent's login; the merge style was read from the history.

## Next Phase Readiness

20-13 (the analytics implementation) is no longer blocked by 20-11. 20-08 will dispatch `deploy-pal.yml` on the
release commit on `main`, which `--merged-pr` accepts only when it is a merged pull request's merge commit.
