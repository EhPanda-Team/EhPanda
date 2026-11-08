# 19-16 Live check deployment

Deploys the owner's choice in `19-15-RUNNER.md` (`Choice: hosted (owner msg 2441)`): the daily live check runs on
GitHub's hosted Mac through `.github/workflows/live-check.yml`.

## Go-ahead (Task 1)

- **Asked:** "May I push a temporary branch so GitHub runs the daily page check once now? It reads about 12 public
  pages and opens a public issue only if the app really can't read one. It doesn't start the app's tests, and I
  delete the branch afterwards."
- **Answer:** owner msg 2456: "Yes, push and run it once".
- **What it covers:** one push of `ci/live-check`, plus one fix-up push to the same branch if the run failed from a
  setup mistake (not needed); the run opening an issue only if a page really broke; deleting the remote branch
  afterwards. Nothing else was pushed: not `feature/gsd-phase-18`, `main` or a tag. No repository setting, secret or
  other branch's workflow was touched.

## The run

- **Branch:** `ci/live-check`, one empty signed commit `3d58637e6` (`ci(19-16): run the daily live check once [skip
  test]`) on `c46868930`. It was built in a separate worktree under `.airbuild/worktree/`.
- **Trigger:** `live-check.yml`'s `push: branches: [ci/live-check]`. No trigger change was needed.
- **test.yml:** run 42443815628 on the same commit, `skipped` (the `[skip test]` condition). The app's tests did not
  start.
- **Live check run:** 42443815779, attempt 1, event `push`, conclusion **success**. Job 128618430063 ran
  2026-11-08 03:42:12 to 03:54:46 UTC (12 min 34 s; run duration 757 s). Steps: checkout, iOS platform (already
  on the image, 1 attempt), `xcodebuild -version`, the entry script, upload.
- **Runner:** `GitHub Actions 1000000633`, runner group `GitHub Actions` (GitHub-hosted), label `xcode-27`, image
  `xcode-27-arm64` `20261104.0337.1`, Xcode 27.1.
- **Entry script:** `run-live-check.sh --mode hosted`. It printed `** TEST SUCCEEDED **`, then the reporter's lines.
- **Artifact:** `live-check-results` (artifact 13603420302, 394 bytes zipped, kept 30 days). It holds only
  `results.json`.

`results.json` (date `2026-11-08T03:53:07Z`, mode `hosted`, schema 1). Its top-level keys are exactly `schema`,
`date`, `mode` and `pages`. Each of the 12 page entries has exactly `page`, `status`, `classification` and
`expectation`.

| Page | Status | Classification | Reporter |
|------|--------|----------------|----------|
| frontPage | 200 | ok | no action |
| search | 200 | ok | no action |
| popular | 200 | ok | no action |
| toplists | 200 | ok | no action |
| gallery | 200 | ok | no action |
| reader | 200 | ok | no action |
| readerImage | 200 | ok | no action |
| tagSuggestions | 200 | ok | no action |
| reportForm | 200 | ok | no action |
| watched | — | skipped | no action |
| favorites | — | skipped | no action |
| exhentai | — | skipped | no action |
| cannot reach the site | — | 0 unreachable runs in a row | no action |

## The reporter's actions

- The real reporter ran with the workflow's own token (`contents: read`, `issues: write`, `actions: read`).
- It found no earlier successful run: `0 previous run(s) found; unreachable runs in a row: 0`.
- It listed the open `live-check` issues. There were none.
- Every guest page was `ok`, so it opened, commented on and closed nothing. It did not create the `live-check`
  label, because it does that only just before the first issue a run opens.
- **Issue opened:** none. `gh issue list --label live-check --state all` returns an empty list.

## Content check

The full run log (238 lines, read with `gh run view --log`) and `results.json` were read before anything else was
done.

- **URLs:** the only URLs are GitHub's own. They are the repository, the runner image's notes and release page,
  the checkout's credential-header setting and the artifact's download link. There is no site URL or host.
- **Site names:** the only match for a site name is the fixed page name `exhentai`, in the `skipped` line and the
  `no action` line.
- **Nothing else:** no gallery title, no gallery ID or gallery path, no header dump (`cf-mitigated`, `server`,
  `set-cookie`) and no page body.
- **xcodebuild:** of its output, the log shows only the final status line.
- **Annotations:** the job has none.
- **`results.json`:** fixed enums, statuses and the run date only.

log checked: no content

## Charge

- The repository is public.
- The run's billing timing (`gh api .../actions/runs/42443815779/timing`) reports `"billable": {}`, so no billable
  minutes on any runner type, with `run_duration_ms` 757000.
- GitHub-hosted runners are free for public repositories. The run made no charge.

## Clean-up (Task 2)

- **Remote branch:** `ci/live-check` was deleted under owner msg 2456, after the run was recorded.
  `git ls-remote --heads origin 'ci/*'` now lists only another plan's branch, and no `ci/live-check`.
- **Worktree:** `.airbuild/worktree/live-check` was removed with `git worktree remove`, and its local
  `ci/live-check` branch was deleted. Commit `3d58637e6` is on no branch now.
- **Not kept:** the owner did not ask to keep the branch. The next branch run needs a new go-ahead.

## Pending after merge

19-17 carries these items into `19-VALIDATION.md`'s manual section. Each one can only be proven once
`live-check.yml` is on `main`.

| Item | Why it is pending | Who or what confirms it | When |
|------|-------------------|-------------------------|------|
| The first scheduled run from `main` | GitHub runs `schedule` triggers only from the default branch. This run came from a `push` to `ci/live-check`. | The developer, from `gh run list --workflow live-check.yml --event schedule`: one run with conclusion `success`, its log checked again for content in the same way, and its reporter lines recorded. | The first 04:17 UTC after the merge to `main` (GitHub may start it late under load). |
| The previous-results path | The reporter reads the last two successful runs' `live-check-results` artifacts. This first run found none (`0 previous run(s) found`). | The developer, from the second scheduled run's log: `2 previous run(s) found` or `1 previous run(s) found`, and no rejected files reported. | The second and third days after the merge. |
| The 60-day inactivity rule | GitHub turns off a public repository's scheduled workflows after 60 days without repository activity. The check would then stop without telling anyone. | The owner or a maintainer: GitHub emails a notice before it turns the schedule off. The schedule is turned back on from the Actions page (Live check, "Enable workflow") or by any push to the repository. | Whenever 60 days pass without a commit to the repository. |
| The `live-check` label and the first real issue | No page broke, so the label was not created and no issue was opened. Its first use comes when a page really breaks. | The reporter creates the label (`gh label create --force`) just before it opens the first issue. The developer checks that issue's title and body against the fixed templates. | The first scheduled run with a `parser` page. |
