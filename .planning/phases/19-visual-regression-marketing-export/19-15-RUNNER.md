# 19-15 Live check runner

## Runner choice (Task 1)

- **Probe verdict (19-03-PROBE.md):** reachable. GitHub's hosted Mac (`xcode-27`, run 42433098473, 2026-11-08) read
  the front page, Popular and one gallery as a guest: all three 200, no `cf-mitigated`, parsed. So did the local run.
- **Options shown:** hosted (GitHub's hosted runner) | mac-timer (the owner's Mac on a `launchd` timer) |
  mac-runner (that Mac registered as a GitHub runner) | fixtures-only (saved fixtures, no live check).
- **Recommendation given:** the hosted runner, because the probe found it reachable. It is free for the public
  repository. Two limits apply: scheduled runs start only from `main`, and GitHub turns off a public repository's
  schedules after 60 days without repository activity.

Choice: hosted (owner msg 2441)

What this means for 19-16: the live check is deployed through `.github/workflows/live-check.yml`. The `launchd`
template (`Scripts/live-check/live-check.plist.template`) stays in the repository but is not installed. The check
gets its first real hosted run when a `ci/live-check` branch is pushed, which needs the owner's go-ahead. Its first
scheduled run comes only after the workflow is on `main`, a later release step. This plan did not push anything or
create that branch.

## What both runners share (Tasks 2 and 3)

- `Scripts/live-check/run-live-check.sh --mode hosted|local [--dry-run] [--gh PATH]` builds and runs
  `LiveCheckTests/DailyLiveCheckTests` from the `LiveCheck` plan. It keeps only the final `xcodebuild` status line
  and hands `results.json` to `report_issues.py`.
- Previous results:
  - hosted: the last two successful runs' `live-check-results` artifacts;
  - local: `$HOME/Library/Application Support/EhPanda live check/`, which holds result files only (the last three).
    A local run first waits up to 2 h for any other `xcodebuild` to finish, and otherwise skips the day with a note.
- `report_issues.py` validates the results strictly before any `gh` call. Titles, bodies and log lines come from
  module constants only, so no page content reaches GitHub. `fake-gh/gh` records every call for the tests.

## Dry run through the entry script (Task 4)

**Live dry run.** Command:
`Scripts/live-check/run-live-check.sh --mode local --dry-run --gh Scripts/live-check/fake-gh/gh`, on the local
simulator `$PHONE` (EhPanda iPhone Air, iOS 27), 2026-11-08 03:26 UTC.

- The test reported `** TEST SUCCEEDED **` after 66.5 s.
- The run made the nine guest GETs, as in 19-14.
- `results.json` has only the four page fields.
- The fake `gh` received one call, `issue list --label live-check --state open`. No real `gh` ran, and no issue was
  read or touched.
- The state directory was not created, because a dry run stores nothing.
- The console output has no URL.

| Page | Status | Classification | Reporter |
|------|--------|----------------|----------|
| frontPage | 200 | ok | no action (no open issue) |
| search | 200 | ok | no action (no open issue) |
| popular | 200 | ok | no action (no open issue) |
| toplists | 200 | ok | no action (no open issue) |
| gallery | 200 | ok | no action (no open issue) |
| reader | 200 | ok | no action (no open issue) |
| readerImage | 200 | ok | no action (no open issue) |
| tagSuggestions | 200 | ok | no action (no open issue) |
| reportForm | 200 | ok | no action (no open issue) |
| watched | — | skipped | no action |
| favorites | — | skipped | no action |
| exhentai | — | skipped | no action |
| cannot reach the site | — | 0 unreachable runs in a row | no action |

The real reporter would take no action on this run: nothing broke, nothing was blocked, and no issue was open.

**Synthetic dry run (made-up input, not a live result).** This shows the action path that the live run did not
reach. It took the live `results.json` and marked Toplists `parser` (`toplists.rows`) and Popular `unreachable`
(403). It ran through the same entry script with `--results`, `--dry-run`, the fake `gh` and an empty state
directory. The reporter printed:

- `would open: Live check: Toplists parser`
- `no action: popular (unreachable)`
- `no action: cannot reach the site (1 unreachable run(s) in a row)`

Again, the fake `gh` received only `issue list`.
