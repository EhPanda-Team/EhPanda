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
  - "UITests first runs had 2 Repetition nodes per device (flaky first runs). Root cause: the \"Show All\" tap reached the app at about 1/3 of the intended point, below the app and the test (simulator or XCTest touch injection). Owner msgs 3539 and 3554: environmental, gate on a clean rerun, accepted with the retries noted. `nyquist_compliant` is true under that rule. No code, test or plan change."

requirements-completed: []
status: complete-with-deferred-parts
---

# Phase 19 Plan 17: README, preview review and the phase gate Summary

**Tasks 1, 2 and 5 are done; Task 3 is deferred; Task 4 is answered. Every gate step passed except the "0 Repetition
nodes" bar on the first run: two accessibility-audit UI tests (one per device) failed their first run and passed on
retry. The clean rerun (owner msg 3539) was phone 0 Repetition nodes, iPad 0 failures with 4 Repetition nodes from two
other tests; accepted with the retries noted (owner msg 3554).**

## Accomplishments

- **Task 1:** README rewritten (`b92a952bf`): no "Visual capture" workflow, no per-coordinate `run-regression.py`;
  covers the in-process runner, 18 configurations, the 27-shard gate with triage, retry and aggregate, baseline and
  fingerprints, the report, candidate and approval, hosted runner limits, the live check and the fixture index
  `website-capture-20261104.json`.
- **Task 2:** RED `f62223a28`, GREEN `4879ea44f`: `preview-review.md` and `validate-preview.py` (rejects a destination
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
| UITests phone / pad, first run | succeeded; 122 / 125 passed, 0 failed; **2 Repetition nodes each** (flaky first runs of `testFiltersSheetAudit` and `testPadSettingAndDetailModalsAudit`, passed on retry 1) |
| UITests phone, clean rerun | succeeded; 122 passed, 0 failed, **0 Repetition nodes** |
| UITests pad, rerun | succeeded; 125 passed, 0 failed; 4 Repetition nodes: `GalleryCardUITests.testFrontPageGridKeepsRatings()` (the same dropped "Show All" tap) and `ShareSheetUITests.testShareSheetHandoffLandsOnDetail()` (the system share sheet never presented; extension embedded and found on the retry; simulator and slowness, not an app bug) |
| SwiftLint strict no-cache | 0 violations in 862 tracked files |
| Python suites | `Scripts/visual` 384 OK; `Scripts/live-check` 27 OK; shard plan current |
| Release build + `verify-release.py` | build succeeded; PASS, 0 findings |

## Deviations from Plan

- The gate's lint was run on the tracked Swift files: a bare `swiftlint lint` at the repository root also scans
  untracked worktrees and package checkouts (43,017 findings, none in project files).
- The FeatureTests plan reports two Repetition nodes for one parameterized kana test whose two arguments print the
  same; no retry is involved.

## Open / for the orchestrator

- The UITests first-run failures were traced to a misplaced tap below the app and the test (the app saw the touch at
  about 1/3 of the intended point: (125, 131) against a target centred at (374.7, 395), a factor equal to the
  phone's display scale; 3 failures in about 30 early tries, 0 in about 310 later ones). The share-sheet failure on
  the iPad is the simulator's system flow, not the extension. Details and evidence: `19-VALIDATION.md` "Phase gate
  results", notes 2 to 4. Owner msg 3539: environmental, gate on a clean rerun. Owner msg 3554: accepted with the
  retries noted. `nyquist_compliant` is set to true on that rule; no code, test or plan was changed.
- Deferred and owed: Task 3, the real preview render, and the hosted rows of 19-10, 19-12 and 19-13.
- Phase 19 is not marked complete.
