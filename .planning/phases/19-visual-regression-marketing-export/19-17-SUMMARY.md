---
phase: 19-visual-regression-marketing-export
plan: "17"
subsystem: testing
tags: [readme, preview-review, validator, phase-gate, release-isolation]

requires:
  - phase: 19-13
    provides: "the approval and baseline (deferred, owner msg 3428)"
  - phase: 19-16
    provides: "the live-check deployment and its pending-after-merge items"
provides:
  - "`Scripts/visual/README.md` rewritten for the in-process runner, the 27-shard gate, baseline, report, approval and live check"
  - "`preview-review.md`, `validate-preview.py`, `test_preview.py` (8 tests)"
  - "the local phase gate results and the final `19-VALIDATION.md` statuses"
affects: [phase-19-verification, 20-11]

actuals:
  tasks: 5
  commits: 4

key-files:
  created:
    - Scripts/visual/preview-review.md
    - Scripts/visual/validate-preview.py
    - Scripts/visual/test_preview.py
  modified:
    - Scripts/visual/README.md
    - .planning/phases/19-visual-regression-marketing-export/19-VALIDATION.md

key-decisions:
  - "Task 3 (controlled regression on the hosted runner) is deferred (owner msg 3428); it is in STATE.md Deferred Items."
  - "Task 4: Required check: not required for now (owner msg 3431). The gate runs on every PR but is not required to merge into `main`."
  - "`nyquist_compliant` stays false: the UITests plan's retry shows 2 Repetition nodes per device (flaky first runs), and the plan's bar is 0. No test or assertion was changed."

requirements-completed: []
status: complete-with-deferred-parts
---

# Phase 19 Plan 17: README, preview review and the phase gate Summary

**Tasks 1, 2 and 5 are done; Task 3 is deferred; Task 4 is answered. Every gate step passed except the "0 Repetition
nodes" bar: two accessibility-audit UI tests (one per device) failed their first run and passed on retry.**

## Accomplishments

- **Task 1:** README rewritten (`1240992ad`): no "Visual capture" workflow, no per-coordinate `run-regression.py`;
  covers the in-process runner, 18 configurations, the 27-shard gate with triage, retry and aggregate, baseline and
  fingerprints, the report, candidate and approval, hosted runner limits, the live check and the fixture index
  `website-capture-20261104.json`.
- **Task 2:** RED `4ab811374`, GREEN `b255c6969`: `preview-review.md` and `validate-preview.py` (rejects a destination
  mismatch, non-empty errors, a missing snapshot and an unsupported locale or variant; writes metadata on a match).
  `test_preview.py` 8 tests green. **Open:** the real render of the first preview in `DownloadsView+Subviews.swift` in two
  locales needs a running Xcode with the preview tools enabled; Xcode was not opened (brief). It is listed in
  `19-VALIDATION.md` Manual-Only.
- **Task 3:** deferred, owner msg 3428. `19-17-REGRESSION.md` is not written.
- **Task 4:** Required check: not required for now (owner msg 3431).
- **Task 5:** results in `19-VALIDATION.md` "Phase gate results". Summary:

| Step | Result |
|------|--------|
| FeatureTests phone / pad | succeeded; 1838 passed, 0 failed each |
| UITests phone / pad | succeeded; 122 / 125 passed, 0 failed; **2 Repetition nodes each** (flaky first runs of `testFiltersSheetAudit` and `testPadSettingAndDetailModalsAudit`, passed on retry 1) |
| SwiftLint strict no-cache | 0 violations in 862 tracked files |
| Python suites | `Scripts/visual` 384 OK; `Scripts/live-check` 27 OK; shard plan current |
| Release build + `verify-release.py` | build succeeded; PASS, 0 findings |

## Deviations from Plan

- The gate's lint was run on the tracked Swift files: a bare `swiftlint lint` at the repository root also scans
  untracked worktrees and package checkouts (43,017 findings, none in project files).
- The FeatureTests plan reports two Repetition nodes for one parameterized kana test whose two arguments print the
  same; no retry is involved.

## Open / for the orchestrator

- The two UITests first-run failures are the reason `nyquist_compliant` is false. Decide whether to accept the
  retry as green, or fix those two tests' Front Page wait (outside this plan's files).
- Deferred and owed: Task 3, the real preview render, and the hosted rows of 19-10, 19-12 and 19-13.
- Phase 19 is not marked complete.
