---
phase: 19-visual-regression-marketing-export
plan: "16"
subsystem: testing
tags: [live-check, github-actions, deployment]

requires:
  - phase: 19-15
    provides: "`live-check.yml`, `run-live-check.sh`, `report_issues.py` and the runner choice (hosted, owner msg 2441)"
provides:
  - "`19-16-DEPLOY.md`: the first real hosted run, the content check, the charge check and the pending-after-merge items"
affects: [19-17]

actuals:
  tokens: 45000
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns:
    - "A one-off `ci/` branch run is built in a worktree under `.airbuild/worktree/` as one empty signed `[skip test]` commit, then the remote branch, the worktree and the local branch are removed"

key-files:
  created:
    - .planning/phases/19-visual-regression-marketing-export/19-16-DEPLOY.md
  modified: []

key-decisions:
  - "Go-ahead: owner msg 2456 (\"Yes, push and run it once\"), covering one push of `ci/live-check`, a fix-up push only for a setup mistake (not needed), issues only for a real break, and deleting the branch."
  - "No trigger change: `live-check.yml` already runs on `push` to `ci/live-check`, and `test.yml` skips `[skip test]` commits."
  - "VIS-19-01 stays Pending in REQUIREMENTS.md. The check runs and is proven on one real run. The first scheduled run from `main` can only come after the merge, and 19-17 carries it into 19-VALIDATION.md."

patterns-established:
  - "Before anything else, read a public run's log and artifact for site URLs, site names, gallery paths, header names and bodies, and record `log checked: no content`"

requirements-completed: []

coverage:
  - id: D1
    description: "One real hosted run: every guest page classified, signed-in pages skipped, results.json with only its fixed fields"
    requirement: VIS-19-01
    verification:
      - kind: integration
        ref: "run 42443815779 (push to ci/live-check, 2026-11-08 03:42 to 03:54 UTC): success; nine guest pages HTTP 200 ok, watched/favorites/exhentai skipped; artifact live-check-results holds only results.json, schema 1 keys"
        status: pass
    human_judgment: false
  - id: D2
    description: "The public log and artifact carry no page content (T-19-35)"
    requirement: VIS-19-01
    verification:
      - kind: manual
        ref: "19-16-DEPLOY.md Content check: only GitHub URLs, only the fixed page name `exhentai`, no gallery path, header or body; `log checked: no content`"
        status: pass
    human_judgment: false
  - id: D3
    description: "The reporter ran for real and opened an issue only for a real break"
    requirement: VIS-19-01
    verification:
      - kind: integration
        ref: "run log: `0 previous run(s) found`, `no action` for every page and for cannot-reach; `gh issue list --label live-check --state all` is empty"
        status: pass
    human_judgment: false
  - id: D4
    description: "What only a merge can prove is listed with who confirms it and when"
    requirement: VIS-19-01
    verification:
      - kind: manual
        ref: "19-16-DEPLOY.md `Pending after merge`: first scheduled run, previous-results path, 60-day rule, first label and issue"
        status: pending
    human_judgment: true

duration: one session
completed: 2026-11-08
status: complete
---

# Phase 19 Plan 16: Deploy the daily live check and prove one real run Summary

**The daily live check is on GitHub's hosted runner, and one real run has passed. With owner msg 2456, one empty
`[skip test]` commit pushed to `ci/live-check` started run 42443815779, which succeeded in 12 min 34 s. All nine
guest pages returned HTTP 200 and parsed, and the three signed-in pages were skipped. The reporter found nothing
to do and opened no issue. The public log and `results.json` hold no page content. The run is not billable. The
branch and its worktree are gone.**

## Performance

- **Tasks:** 2
- **Files:** 1 created (plus this summary)

## Accomplishments

- **Task 1, the first real run.**
  - The owner's go-ahead (msg 2456) is recorded.
  - The `ci/live-check` commit `3d58637e6` was built in a worktree and sits on `398512662`.
  - `test.yml` run 42443815628 was `skipped`.
  - Live check run 42443815779 succeeded.
    - Runner: `GitHub Actions 1000000633`, group `GitHub Actions`, image `xcode-27-arm64` `20261104.0337.1`,
      Xcode 27.1.
    - Pages: frontPage, search, popular, toplists, gallery, reader, readerImage, tagSuggestions and reportForm
      were `ok`, each 200. watched, favorites and exhentai were `skipped`.
    - Reporter: `0 previous run(s) found`, then `no action` for every page and for cannot-reach. No issue was
      opened and no label was created.
- **Content check.**
  - The log's only URLs are GitHub's.
  - The only site-like string is the fixed page name `exhentai`.
  - The log has no gallery path, header or body, and the job has no annotations.
  - The artifact is `results.json` alone, with exactly the schema 1 keys.
- **Charge check.** The run's timing API reports `"billable": {}`, for a public repository.
- **Task 2, clean-up.**
  - The remote `ci/live-check` branch was deleted. `git ls-remote --heads origin 'ci/*'` shows only
    `ci/snapshot-measure`, which belongs to another plan and was left untouched.
  - The worktree was removed and its local branch deleted.
  - Four pending-after-merge items are listed, each with who confirms it and when: the first scheduled run, the
    previous-results path, the 60-day rule, and the first label and issue.

## Task Commits

1. **Task 1: Owner go-ahead and the first real run** - `15a806d47` (docs). The branch commit `3d58637e6` was
   pushed and then removed with the branch.
2. **Task 2: Post-merge items and clean-up** - `ae3a30aba` (docs)

## Verification

- `grep -E "owner msg [0-9]+" 19-16-DEPLOY.md` finds `owner msg 2456`.
- `grep -c "log checked: no content"` prints 1.
- `grep -c "Pending after merge"` prints 1.
- `grep -nE "/Users/"` on `19-16-DEPLOY.md` prints nothing.

## Decisions Made

See `key-decisions`.

## Deviations from Plan

None. The plan's question wording was given to the owner in plainer words, with the same scope: one temporary
branch, about 12 guest page reads, an issue only for a real break, no app tests, and the branch deleted afterwards.

## Issues Encountered

- `gh run watch` printed nothing for about 12 minutes, because its output was discarded on purpose. The harness
  flagged the watch as stalled, and the job's API showed it in progress on a hosted runner.
- The run's own platform step found iOS 27 already on the image. It finished after 1 attempt, unlike the 19-03
  probe's long install.

## User Setup Required

None.

## Next Phase Readiness

- 19-17 carries `19-16-DEPLOY.md`'s `Pending after merge` items into `19-VALIDATION.md`'s manual section.
- VIS-19-01 stays Pending until the phase gate. Its first scheduled run needs `live-check.yml` on `main`.
