---
phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele
plan: "02"
subsystem: infra
tags: [github-actions, release, build-number, altstore, sidestore, screenshots]

requires: []
provides:
  - "`deploy.yml` runs `check-build-number.sh` before the tests, against main's `AltStore.json`, `SideStore.json` and `altstore-beta.json` (not `AltStorePAL.json`)"
  - "`actions-tool/tests/test_workflows.py`: workflow shape tests through `ruby -ryaml -rjson` (build-number check, asset URL with `curl -sSfIL`, history-keeping filter call, release-notes checks, no tag commands)"
  - "Project at 3.0.0 (159) on the four app and extension configurations; test targets at 1.0 (1)"
  - "`Scripts/bump-version.sh` leaves configurations with `TEST_HOST` or `TEST_TARGET_NAME` alone"
  - "`EhPanda-Team/ehpanda-assets` public at `d69b30a`; the seven screenshot URLs return 200"
affects: [20-04, 20-08, 20-13, 20-14]

actuals:
  tokens: 6000
  tasks: 3
  commits: 5

tech-stack:
  added: []
  patterns:
    - "Workflow tests read the YAML through Ruby's standard library, put the workflow `env` values into each step's shell lines and skip comment lines before matching"

key-files:
  created:
    - actions-tool/tests/test_workflows.py
    - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-02-RECORD.md
  modified:
    - .github/workflows/deploy.yml
    - EhPanda.xcodeproj/project.pbxproj
    - Scripts/bump-version.sh

key-decisions:
  - "n = 159: main's AltStore.json has 158 at most, SideStore.json and altstore-beta.json are not on main yet (main 37b979965)"
  - "deploy.yml's step copies the beta's step shape, with SideStore.json added to the list; the comment says why it reads main's copies and leaves out the PAL source"
  - "The tag guard forbids `git tag`, `git push … --tags`, `git push … :refs/tags`, `git push --delete`, `gh release create/delete/edit` and `gh api … git/refs/tags` in any workflow, and allows `tag_name` only on `softprops/action-gh-release`"

patterns-established:
  - "`code(run)` in test_workflows.py: a comment that names a file is not a use of it"

requirements-completed: []

coverage:
  - id: D1
    description: "deploy.yml checks the build number before the tests, against main's three Classic-side sources and not AltStorePAL.json"
    requirement: REL-18-01
    verification:
      - kind: unit
        ref: "actions-tool/tests/test_workflows.py (11 tests); removing the step gives failures=2, errors=1"
        status: pass
      - kind: lint
        ref: "actionlint 1.7.12 on deploy.yml and deploy-beta.yml: only the pre-existing custom runner label finding"
        status: pass
    human_judgment: false
  - id: D2
    description: "Release URLs, history and notes checks are guarded; no workflow touches tags"
    requirement: REL-18-01
    verification:
      - kind: unit
        ref: "test_workflows.py: test_the_sources_point_at_the_releases_own_assets, test_the_sources_keep_their_history, test_the_release_notes_are_checked, TagOperationTests"
        status: pass
    human_judgment: false
  - id: D3
    description: "Build 159 is above every published build; MARKETING_VERSION 3.0.0 ×4; test targets 1"
    requirement: REL-18-01
    verification:
      - kind: integration
        ref: "Task 2 verify: 4 × 159, 4 × 1; check-build-number.sh 159 <main's AltStore.json> → greater than 158"
        status: pass
    human_judgment: false
  - id: D4
    description: "ehpanda-assets exists and the seven screenshot URLs resolve, with the owner's consent recorded"
    requirement: REL-18-01
    verification:
      - kind: integration
        ref: "Task 3 verify: seven 200s; 20-02-RECORD.md cites owner msgs 2787 and 2794"
        status: pass
    human_judgment: true
    rationale: "Creating the repository needed the owner's OK and his sign-in; the orchestrator did it"

duration: 6min
completed: 2026-11-09
status: complete
---

# Phase 20 Plan 02: Build-number check, build bump and screenshots repository Summary

**A release whose build number is already published now fails before it builds; the project is 3.0.0 (159), one
above main's highest build; workflow tests guard the asset URLs, history and notes checks and forbid tag commands;
and `EhPanda-Team/ehpanda-assets` serves the seven screenshots.**

## Performance

- **Duration:** 6 min (Tasks 1 and 2). Task 3 was done by the orchestrator.
- **Started:** 2026-11-09T01:25:00Z
- **Completed:** 2026-11-09T01:31:00Z
- **Tasks:** 3
- **Files modified:** 5 (2 created, 3 modified)

## Accomplishments

- `deploy.yml` has a "Check build number" step, ordered before "Install iOS 27 Platform" and "Run tests". It reads
  main's AltStore.json, SideStore.json and altstore-beta.json (T-20-04).
- `test_workflows.py` keeps the release's download URLs, `curl -sSfIL` check, history-keeping filter call and
  release-notes checks in place. It fails on any tag or release command in any workflow (D-03, D-19, T-20-06).
- The build was bumped to 159 with `Scripts/bump-version.sh`, after fixing how the script tells test targets apart.
- The screenshots' repository exists, with the owner's consent recorded (D-17, T-20-05).

## Task Commits

1. **Task 1: Build-number check with workflow tests**: `0c79b66d2` (test, RED), `aab86b0d4` (test: skip
   comment lines), `9800e1813` (feat, GREEN)
2. **Task 2: Bump the build number**: `08a101b1b` (fix: bump-version.sh, deviation 1), `88e842112` (chore: the bump
   and 20-02-RECORD.md)
3. **Task 3: ehpanda-assets**: done by the orchestrator (owner msgs 2787, 2794). The record and this SUMMARY are in
   the plan-metadata commit.

## Verification evidence

| Check | Result |
|-------|--------|
| `test_workflows.py` RED (before the step) | 11 tests, failures=2, errors=1 |
| `test_workflows.py` GREEN | 11 tests, OK |
| Acceptance: step removed locally, then restored | failures=2, errors=1; restored byte-identical (`cmp`), OK again |
| `actionlint` deploy.yml + deploy-beta.yml | one finding per file: `label "xcode-27" is unknown [runner-label]`, also present at the base. Clean with `-ignore 'label "xcode-27" is unknown'` |
| Task 2 verify | `4 CURRENT_PROJECT_VERSION = 159;`, `4 CURRENT_PROJECT_VERSION = 1;`; "Build 159 is greater than every published build (highest: 158)." |
| `grep -c "MARKETING_VERSION = 3.0.0;"` | 4 (test targets keep `1.0`: 4) |
| bump-version.sh auto mode on a copy | "Auto-detected current build 159, bumping to 160", 4 + 4 entries, test targets still 1 |
| Task 3 verify | seven `200` lines (the list is in `20-02-RECORD.md`); the SideStore and beta templates' seven URLs are also 200 |
| actions-tool suites, one at a time | all 7 test files OK |

## Files Created/Modified

- `.github/workflows/deploy.yml`: `ALTSTORE_BETA_JSON_PATH`, `CHECK_BUILD_NUMBER_SCRIPT_PATH`, the "Check build number" step
- `actions-tool/tests/test_workflows.py`: deploy, beta and tag-operation tests
- `Scripts/bump-version.sh`: test configurations are found by `TEST_HOST` or `TEST_TARGET_NAME` too
- `EhPanda.xcodeproj/project.pbxproj`: 158 → 159 on four configurations
- `20-02-RECORD.md`: the build-number evidence, the owner messages, the repository, the pushed commit and the URL results

## Decisions Made

See `key-decisions`. Task 3's consent came from the owner (msgs 2787, 2794).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] bump-version.sh bumped the test targets**
- **Found during:** Task 2
- **Issue:** the script recognised test configurations only by the bundle ID `app.ehpanda.tests`, which no target
  uses any more. It set EhPandaUITests and VisualSnapshotTests to 3.0.0 (159), 8 entries instead of 4.
- **Fix:** a configuration with `TEST_HOST` (unit tests) or `TEST_TARGET_NAME` (UI tests) also counts as a test
  configuration, in both the detect and the update pass. The project file was put back from `HEAD` and the bump was
  run again.
- **Files modified:** `Scripts/bump-version.sh`
- **Verification:** 4 × 159 and 4 × 1; auto mode on a copy also bumps only the four
- **Committed in:** `08a101b1b`

**2. [Rule 3 - Blocking] Test refinement after GREEN**
- **Found during:** Task 1
- **Issue:** the step's comment names `AltStorePAL.json` to explain why it is left out, which tripped the "not the
  PAL source" test.
- **Fix:** tests match only a step's shell lines, not comment lines. The tag scan does the same.
- **Committed in:** `aab86b0d4`

### Verification adaptations

- `actionlint` is not at `~/.local/bin/actionlint`; I used `/opt/homebrew/bin/actionlint` 1.7.12. Its only
  finding is the custom self-hosted runner label `xcode-27`, which is unchanged from the base. No `actionlint.yaml`
  was added, because that is outside the plan's files.
- Task 3 was not run here. The orchestrator created the repository with the owner's sign-in. This agent ran the
  verify (`jq` + `curl`) and `git ls-remote` read-only.

---

**Total deviations:** 2 auto-fixed (Rule 1, Rule 3). **Impact:** the script fix is needed for every later bump, and
the release flow is unchanged.

## Issues Encountered

None.

## Open items

- `ReleaseNotes/3.0.0.md` is owner content. It has to exist before the 3.0.0 release PR passes its notes check.
- REL-18-01 stays Pending: later plans share it.
- An `actionlint.yaml` with `self-hosted-runner.labels: [xcode-27]` would make plain `actionlint` clean. That needs
  a decision from the orchestrator.

## User Setup Required

None.

## Next Phase Readiness

The wave-2 plans that depend on 20-02 can start. 20-04's PAL workflow should have its own build-number rule
(Research §3, pitfall 4).

## Self-Check: PASSED

- key-files.created exist: `actions-tool/tests/test_workflows.py`, `20-02-RECORD.md`
- commits `0c79b66d2`, `aab86b0d4`, `9800e1813`, `08a101b1b`, `88e842112`: all `G`, all +08:00
- every task's verify and acceptance criteria re-run green (table above)

---
*Phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele*
*Completed: 2026-11-09*
