---
phase: 19-visual-regression-marketing-export
plan: "15"
subsystem: testing
tags: [live-check, github-issues, github-actions, launchd, python]

requires:
  - phase: 19-03
    provides: "The runner-IP probe's verdict (reachable) and the runner-probe workflow's shape"
  - phase: 19-14
    provides: "`DailyLiveCheckTests` and `results.json` schema 1 with enum-only page fields"
provides:
  - "`Scripts/live-check/report_issues.py`: one issue per broken page, auto-close, the cannot-reach issue"
  - "`Scripts/live-check/fake-gh/gh`: a recording, stateful stand-in for `gh`"
  - "`Scripts/live-check/run-live-check.sh --mode hosted|local`: the one entry point for both runners"
  - "`.github/workflows/live-check.yml` (daily 04:17 UTC, dispatch, push to `ci/live-check`)"
  - "`Scripts/live-check/live-check.plist.template` (not installed: the owner chose the hosted runner)"
  - "`19-15-RUNNER.md`: Choice: hosted (owner msg 2441)"
affects: [19-16, 19-17]

actuals:
  tokens: 110000
  tasks: 4
  commits: 5

tech-stack:
  added: []
  patterns:
    - "The reporter rebuilds every value it keeps from its own vocabulary after validation, so no string read from a results file reaches gh"
    - "Titles, bodies and log lines are module-level `str.format` templates; an AST test forbids f-strings, string operators and formatting anything else"

key-files:
  created:
    - Scripts/live-check/report_issues.py
    - Scripts/live-check/test_report_issues.py
    - Scripts/live-check/fake-gh/gh
    - Scripts/live-check/run-live-check.sh
    - Scripts/live-check/live-check.plist.template
    - .github/workflows/live-check.yml
    - .planning/phases/19-visual-regression-marketing-export/19-15-RUNNER.md
  modified: []

key-decisions:
  - "Runner: GitHub's hosted runner (owner msg 2441), on 19-03's `reachable` verdict. Options shown: hosted, mac-timer, mac-runner, fixtures-only."
  - "Issue titles: `Live check: <Page> parser` with fixed display names (for example `Toplists`, `Reader image`) and `Live check: cannot reach the site`; label `live-check`, created with `gh label create --force` just before the first issue a run opens."
  - "Bodies carry only the page's display name, the date (day only), the mode, `HTTP <status>` or `no HTTP status`, the expectation's fixed sentence and, for the cannot-reach issue, the run count and the unreached pages' names."
  - "Strict validation: exactly the schema 1 keys, no duplicate keys, schema 1, an ISO 8601 UTC date, fixed enums, a status of 100 to 599 or null (never a boolean), unique pages, an expectation exactly on `parser` results, no status on `skipped`. A rejected file exits 2 with a fixed phrase, before any gh call."
  - "History: previous result files are found recursively under `--previous`. A file that does not validate is ignored and counted. Runs on or after the current run's date are excluded, so the current run never counts twice. An unreachable page leaves that page's open parser issue open, because a block says nothing about the parser."
  - "A dry run lists open issues (one read call) and prints `would open/comment/close` or `no action` lines; the entry script's dry run also stores no local result."

patterns-established:
  - "Leak testing against a recording gh: every argument must be a fixed command word, a number or a full match of a template filled with vocabulary-only patterns"

requirements-completed: []

coverage:
  - id: D1
    description: "Issue handling: open, comment, close, never a parser issue for a block, the cannot-reach issue after three runs"
    requirement: VIS-19-01
    verification:
      - kind: unit
        ref: "python3 -m unittest discover -s Scripts/live-check -p 'test_report_issues.py' (16 tests, OK)"
        status: pass
    human_judgment: false
  - id: D2
    description: "Nothing from the results but the fixed vocabulary reaches gh (T-19-32)"
    requirement: VIS-19-01
    verification:
      - kind: unit
        ref: "InputRejectionTests (4) and VocabularyTests (3) in test_report_issues.py"
        status: pass
    human_judgment: false
  - id: D3
    description: "Entry script, workflow and timer template lint clean; the whole local path runs without touching GitHub"
    requirement: VIS-19-01
    verification:
      - kind: integration
        ref: "Task 3 verify (syntax-ok, plutil OK, workflow assertion ok, 0 xcresult); local dry run on $PHONE 2026-11-08 03:26 UTC: nine guest pages ok, three skipped, the fake gh received only issue list"
        status: pass
    human_judgment: false

duration: one session
completed: 2026-11-08
status: complete
---

# Phase 19 Plan 15: Live check runner, issue reporter, entry script and workflow Summary

**The daily live check now reports through self-closing GitHub issues, and one script runs it on either runner. The
owner chose GitHub's hosted runner (owner msg 2441), on 19-03's `reachable` probe. The reporter validates
`results.json` strictly before any `gh` call and writes only fixed templates. A local dry run through the entry
script found all nine guest pages `ok`, so the reporter would take no action, and it touched no real issue.**

## Performance

- **Tasks:** 4
- **Files:** 7 created

## Accomplishments

- **Runner choice** (Task 1): `Choice: hosted (owner msg 2441)` in `19-15-RUNNER.md`, with the probe verdict and
  the options shown.
- **Reporter and fake gh** (Task 2, TDD). Tests were committed failing (`6995bee47`), then the code (`355901883`).
  - `report_issues.py --results --previous --repo [--gh] [--dry-run]` opens one issue per `parser` page, comments
    on it while the page stays broken and closes it on the next `ok`.
  - After three runs in a row with an unreachable page it opens one cannot-reach issue, comments on it while the
    block lasts and closes it on the first run that reaches every page.
  - `fake-gh/gh` logs every call to `$FAKE_GH_LOG` and keeps the open issues in `$FAKE_GH_STATE`, so multi-day
    sequences are tested end to end.
- **Entry script, workflow, template** (Task 3).
  - `run-live-check.sh` runs `DailyLiveCheckTests` with `TEST_RUNNER_EHPANDA_LIVE_CHECK=1`, `_MODE` and `_OUTPUT`.
    It keeps only the final `xcodebuild` status line, then calls the reporter.
  - Hosted previous results: the last two successful runs' `live-check-results` artifacts. Local previous results:
    the state directory, which keeps the last three result files. A local run first waits up to 2 h for any other
    `xcodebuild`, and otherwise skips the day with a note.
  - `live-check.yml` has the planned triggers and permissions, `concurrency: live-check`, and uploads only
    `results.json`.
  - The plist template uses `$HOME` and `$REPO_DIR` placeholders.
- **Dry run** (Task 4): recorded in `19-15-RUNNER.md`, with every page's classification and the reporter's
  action. A clearly labelled synthetic dry run shows the `would open` path.

## Task Commits

1. **Task 1: Runner choice** - `e76d492ff` (recorded with Task 4; the owner's answer arrived during execution)
2. **Task 2: Issue reporter and the fake gh** - `6995bee47` (test, RED), `355901883` (feat, GREEN)
3. **Task 3: Entry script, workflow and timer template** - `500f4dffc` (feat)
4. **Task 4: Dry run through the entry script** - `e76d492ff` (docs)

## Verification

- Task 1: `grep -E "Choice: (hosted|...) \(owner msg [0-9]+\)"` prints `Choice: hosted (owner msg 2441)`.
- Task 2: `python3 -m unittest discover -s Scripts/live-check -p 'test_report_issues.py'`: 16 tests, OK. All
  `test_*.py` in `Scripts/live-check`: OK.
- Task 3: `syntax-ok`; `plutil` OK; the workflow assertion prints `ok`; `grep -c xcresult` prints 0;
  `grep -rn "/Users/" Scripts/live-check` prints nothing.
- Task 4: `grep -ciE "would (open|comment|close)|no action"` on `19-15-RUNNER.md`: 17.
- Mutation checks on the tests:
  - A lenient page-key check makes 8 tests fail.
  - A cannot-reach threshold of 2 makes 3 tests fail.
  - Writing the full timestamp into bodies makes the vocabulary test fail.
  - Dropping the date exclusion makes the count-once test fail.

## Decisions Made

See `key-decisions`.

## Deviations from Plan

1. **Task 1 was answered during execution.** It had been an open checkpoint. The owner's answer (msg 2441) was
   relayed during the run and is recorded in `19-15-RUNNER.md`.
2. **The fake gh keeps state.** It answers `issue list` from `$FAKE_GH_STATE` as planned. It also adds created
   issues to that file and closes them there, so a test can run several days in a row. It also answers `run list`,
   `run download`, `label create` and `auth status`, and exits 2 on any other command.
3. **More tests than behaviours: 16 tests.** Each planned behaviour has its own named test. The others cover:
   - an unreachable page that leaves its open parser issue open;
   - comments on an open cannot-reach issue;
   - skipped pages that are not counted as unreachable;
   - the current run counted only once;
   - inconsistent or malformed files;
   - an invalid previous file;
   - the vocabulary staying in step with the Swift schema;
   - the dry run.
4. **The reporter creates its label** (`gh label create live-check --force`) before the first issue a run opens.
   Otherwise `gh issue create --label` would fail in a repository that has no such label yet.
5. **Extra entry-script options:** `--repo` (by default `$GITHUB_REPOSITORY`, or the origin remote's
   `OWNER/NAME`), `--output`, `--state-dir`, `--simulator` and `--results` (report an existing file without
   building). A dry run stores no local result, so it cannot count as a day.
6. **Local mode unsets `GH_TOKEN` and `GITHUB_TOKEN`**, so it uses the Mac's own `gh` sign-in.

## Issues Encountered

- Another executor was committing 19-04 files in the same checkout. Once, `git commit` found an `index.lock` and
  was retried. Twice, a `git status` straight after `git add` showed the file unstaged, and a few seconds later it
  showed staged. Each commit's contents were checked and hold only this plan's files.

## User Setup Required

None. The `launchd` template is not installed, because the owner chose the hosted runner.

## Next Phase Readiness

- 19-16 can push `ci/live-check` (owner go-ahead needed) and inspect one real hosted run.
  - That push also triggers `test.yml` unless the commit message carries `[skip test]`.
  - Scheduled runs start only once `live-check.yml` is on `main`.
- VIS-19-01 stays Pending (19-16).
