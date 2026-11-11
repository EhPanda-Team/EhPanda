---
phase: 20-3-0-distribution-marketplace-build-notarization-listing-rele
plan: "14"
subsystem: release-gate
tags: [release, isolation-scan, phase-gate, validation]

requires:
  - phase: 20
    provides: "20-09 (device checks) and 20-13 (analytics revision), plus the three TCA deprecation refactors"
provides:
  - "20-14-RELEASE-SCAN.md: the Release isolation scan of the default and marketplace flavors (0 findings each) and the phase gate results"
  - "20-VALIDATION.md rows updated; nyquist_compliant stays false (named rows below)"
affects: [20-08]

actuals:
  tokens: n/a
  tasks: 2
  commits: 3

tech-stack:
  added: []
  patterns: []

key-files:
  created:
    - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-14-RELEASE-SCAN.md
  modified:
    - .planning/phases/20-3-0-distribution-marketplace-build-notarization-listing-rele/20-VALIDATION.md

key-decisions:
  - "No source, test or script changed. The plan writes records only."
  - "`nyquist_compliant` and `status: validated` are not set: not every automated row is green (20-10-02 superseded, 20-11-03 live read exits 1, 20-08-02 not yet run)."

requirements-completed: []

coverage:
  - id: D1
    description: "The final 3.0 Release build ships, links and activates no capture, UI-test or snapshot facility, in both flavors (SC9)"
    requirement: DIST-18-01
    verification:
      - kind: scan
        ref: "verify-release.py: default 0 findings, marketplace 0 findings; both launch probes: Release alive, Debug control ended"
        status: pass
    human_judgment: false
  - id: D2
    description: "The phase gate is green"
    requirement: ANALYTICS-02
    verification:
      - kind: suite
        ref: "actions-tool 201 OK; Scripts/visual 384 OK; FeatureTests iPhone and iPad 2034 tests, 0 failed each; swiftlint strict 0 violations (867 files); actionlint clean on 10 workflows"
        status: pass
    human_judgment: false
  - id: D3
    description: "The TCA refactors changed no Detail, Comments or Settings snapshot"
    requirement: ANALYTICS-02
    verification:
      - kind: snapshot
        ref: "before (db476cdba) and after (head) local runs: iPhone 248 of 248 identical, iPad portrait 126 of 126 identical; iPad landscape could not run locally"
        status: pass
    human_judgment: false

duration: n/a
completed: 2026-11-11
status: complete
---

# Phase 20 Plan 14: Release isolation scan and phase gate Summary

**Both flavors pass the Release isolation scan with 0 findings, and the phase gate is green. The record is
`20-14-RELEASE-SCAN.md`; the validation file is updated but not signed off.**

## Accomplishments

- **Scans (Task 1).** Default and marketplace (`-xcconfig Config/Marketplace.xcconfig`, stamp `altstorePAL`), each with a
  fresh DerivedData for Release and for the Debug control, the full log, all four link maps and the launch probe on the
  iPhone simulator: 0 findings each, 379 payload files, 150 graph targets, one accepted name (`UITestAutomation`, an
  inert shell). The Release process survived the probe's launch; the Debug control ended.
- **Gate (Task 2).** `actions-tool` 201 tests; `Scripts/visual` 384 tests; FeatureTests on iPhone and iPad, 2034 tests
  each, 1885 passed, 9 expected failures, 140 skipped (the snapshot matrix without a mode), 0 failed; strict lint 0
  violations on all 867 tracked Swift files; actionlint clean on the 10 workflows.
- **TCA refactors.** No recorded references exist (Phase 19's baseline is deferred), so a before-state was recorded from
  `db476cdba` and compared with the head for nine Comments, Detail and Settings classes: no diff on the iPhone (248
  pictures) or the iPad in portrait (126). iPad landscape could not run locally (see the record). No reference was
  re-recorded.

## Task Commits

All are signed (`%G?` = G).

1. **Tasks 1 and 2 (scan record, gate, validation rows):** `d82ef9494`.
2. **20-09 ticked in the roadmap (separate):** `52dca0981`.
3. **Docs:** the commit that adds this summary and ticks 20-14 in ROADMAP and updates STATE.

## Deviations from Plan

1. **Tool paths.** `~/.local/bin/actionlint` does not exist: `/opt/homebrew/bin/actionlint` 1.7.12 was used (it is clean
   with the repository's `.github/actionlint.yaml`). `swiftlint` is not on PATH: 0.65.1 from the package artifact bundle in
   an existing DerivedData, run on `git ls-files '*.swift'`, because a bare run from the root walks untracked checkouts.
2. **`Scripts/visual` tests.** None was touched by this phase; the whole directory was run anyway (384 OK).
3. **Probe needs a booted simulator.** `verify-release.py --device` fails on a Shutdown device
   (`simctl install ... Shutdown`); the iPhone simulator was booted for the two scans and both visual simulators were Shutdown
   again afterwards.
4. **Extra snapshot comparison** (not in the plan; the brief asked for it): described above.
5. **A driver-script slip.** My first scan launch for the default flavor died on an empty bash array before building
   anything (`unbound variable`); it was rerun with the same commands. No result was discarded.
6. **`dfda0e3f4` (README wording) landed on the branch while the runs were in progress.** It changes no source.

## Requirements

REQUIREMENTS.md was not edited. This plan's gate completes the parts of DIST-18-01 (flavor, isolation) and ANALYTICS-02
that were left Pending for it. REL-18-01 and DEV-18-01 are still unticked there; the release itself is outside this plan.

## Validation status

`nyquist_compliant` stays **false** and `status` stays `draft`, because three automated rows are not green:
20-10-02 (superseded: no store renders, no `store_screenshots.py`; 20-10 deviation 1), 20-11-03 (live reads exit 1 until
Phase 19's gate pass), and 20-08-02 (20-08 is not executed). Rows of 20-06, 20-07-02 and 20-08 are checkpoints of plans
still to run.

## Open items for the owner

- **Release order (not set here):** Classic release, then the PAL submission of the same build (20-08), then the first
  look at `altstorePAL` on the dashboard from a live PAL install (D-03, D-20, D-26). Every release and PAL dispatch is
  refused until Phase 19's gate pass exists.
- **Sign-off of `20-VALIDATION.md`:** whether to accept 20-10-02 as superseded and 20-11-03 as deferred, which would let
  `nyquist_compliant` be set once 20-06, 20-07 and 20-08 are done.
- **iPad landscape snapshots** can only be checked by the hosted gate; the local script's rotation lands on a parallel clone.
