---
phase: 19-visual-regression-marketing-export
verified: 2026-11-11T12:00:00Z
status: human_needed
score: 5/8 must-haves verified
behavior_unverified: 2
overrides_applied: 0
behavior_unverified_items:
  - truth: "The full-matrix gate runs on every PR and release, with its runtime reported, and a shard crash is retried once without cancelling others (SC 4)"
    test: "Dispatch or push snapshot-gate.yml on the hosted runner and read the run summary (19-10 Task 4; STATE Deferred Items)"
    expected: "aggregate passes; triage names only injected shards and their retries pass; all four failure-class counts are 0; wall time is reported"
    why_human: "The workflow, run-shard.sh, triage, retry and aggregate are present, wired and covered by Python tests, but no hosted run has passed. Runs 1 to 3 failed and were fixed; run 4 was never read. Owner msgs 3425, 3428."
  - truth: "A controlled one-point regression makes the gate fail with exactly the affected coordinates, then pass again (SC 2, D-18)"
    test: "Push the shifted-token commit and the restoring commit to ci/snapshot-gate against the approved baseline (19-17 Task 3)"
    expected: "Red run: only picture changes, only the affected keys; green run: all counts 0; both run IDs in 19-17-REGRESSION.md"
    why_human: "Needs the hosted runner and an approved baseline, neither of which exists. Only the local 1-point shift (19-01 tracer) was proven. Deferred, owner msg 3428."
human_verification:
  - test: "Hosted candidate run, public snapshot repository, agent pre-check, the owner's one approval, pinned baseline, green compare run (19-12, 19-13)"
    expected: "snapshot repository created; Baseline/fingerprints.json and manifest.json committed; approval recorded with its message number; a compare run is green"
    why_human: "Owner judgement and hosted pushes. Deferred before release day, owner msgs 3425, 3428. SC 3 cannot be marked met until then."
  - test: "Green snapshot-gate run before release day (19-10 Task 4)"
    expected: "A successful aggregate check on the shipped commit; deploy.yml and deploy-beta.yml need it and are blocked until it exists (compare mode fails with 'no approved baseline yet' today)"
    why_human: "Hosted run. Deferred, owner msgs 3425, 3428."
  - test: "Real preview render of DownloadsView+Subviews.swift in two locales, validated with validate-preview.py"
    expected: "Metadata accepted by the validator; destination matches the request; no errors"
    why_human: "Needs a running Xcode with the preview tools. Manual-Only by decision."
  - test: "After merge: first scheduled live-check run from main, second and third runs log previous results with no rejected files, first real issue and the live-check label, 60-day inactivity rule"
    expected: "Runs succeed from main; issue text matches the fixed templates"
    why_human: "Schedules run only from the default branch. Listed in 19-16-DEPLOY.md and 19-VALIDATION.md Manual-Only."
deferred:
  - truth: "SC 3: one owner-approved baseline covers the complete set"
    addressed_in: "STATE.md Deferred Items (19-13), not a later roadmap phase"
    evidence: "Owner msg 3428; owed before release day. Recorded in STATE, ROADMAP 19-12/19-13 unchecked, README 'Status' paragraphs, 19-VALIDATION.md rows."
---

# Phase 19: Visual Regression & Daily Live-Parsing Check Verification Report

**Phase Goal:** Complete the screenshot check (snapshot matrix over every screen, Phase 18 and 18.1 included; real-app dispatch; strict never-record comparison and review report; one owner-approved baseline; full-matrix CI gate on every PR and release; preview review docs; `Scripts/visual/README.md` rewrite) and add a daily live-parsing check that reports a break through one self-closing GitHub issue. No marketing pictures.
**Verified:** 2026-11-11 at HEAD bac1ca916 (branch feature/gsd-phase-19), including review fixes bded61963..bac1ca916 and the Laboratory title fix b10fb61aa.
**Status:** human_needed
**Re-verification:** No, initial verification.

All checks were read-only. Run: `python3 -m unittest` for `Scripts/visual` (384 tests OK) and `Scripts/live-check` (27 OK), `snapshot_shards.py --check` (current), `bash -n` on the shell scripts, YAML parse of all nine workflows. No `xcodebuild`, no hosted run, no push. Hosted results (run IDs, hosted timings) are read from the phase records and not re-proven here.

## Decided items, checked for correct recording

| Decision | Recorded in | Status |
|---|---|---|
| Hosted gate pass deferred to before release day; 19-10, 19-12, 19-13 and 19-17 hosted parts deferred (owner msgs 3425, 3428) | STATE.md Deferred Items (four rows); ROADMAP plan lines for 19-10, 19-12, 19-13, 19-17; README "Status" paragraphs; 19-VALIDATION.md rows ⏸ | RECORDED. The claim that release workflows refuse to ship is true in code: `deploy.yml` and `deploy-beta.yml` run `snapshot-gate.yml` in compare mode and the `Deploy` job `needs` it; with no `fingerprints.json` the compare run fails at once. |
| Required check on `main`: not required for now (owner msg 3431) | 19-VALIDATION.md rows 19-17-04 and Manual-Only; STATE.md; ROADMAP 19-17 line | RECORDED |
| UITests first-run flakes environmental, accepted with retries noted (owner msgs 3539, 3554) | 19-VALIDATION.md "Phase gate results" notes 1 to 4 | RECORDED, with evidence per flaky test, clean phone rerun, 4 iPad Repetition nodes disclosed |
| Preview render needing Xcode is Manual-Only | 19-VALIDATION.md Manual-Only; 19-17-SUMMARY | RECORDED |

## Goal Achievement

### Observable Truths (ROADMAP success criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Matrix covers every screen and state, Phase 18 and 18.1 included, across 6 locales, 3 text sizes, portrait and landscape, iPhone and iPad, light and dark; each coordinate captured, failed or justified not applicable | ✓ VERIFIED | `scenarios.json` schema 2: 137 unique scenario IDs, every ID has a literal in the four `ScenarioCatalog+*.swift` files (script check, 0 missing); `snapshot_matrix.py --totals`: 19,728 coordinates = 19,368 expected + 360 not applicable, five by-design rules with reasons (72 each), four D-05 `notCaptured` surfaces with reasons; no rule removes a whole scenario. `SnapshotMatrix.xctestplan` has 18 configurations. Factories use real views and reducers; only `VisualSnapshotTests` links `VisualSnapshotSupport`. Whole-matrix capture on the hosted runner has not happened (see 4). |
| 2 | Comparison is strict and never records; screen-grouped baseline/actual/diff report is filterable; a controlled regression proves detection | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | Strict compare: `HostedWindowCapture` records only in explicit candidate mode (`.recorded` status), compare never writes the reference directory (unit tests). `snapshot_aggregate.py` (missing result never passes) and `snapshot_report.py` (offline, filters) pass their tests. The controlled red-then-green regression is deferred (owner msg 3428); only the local 1-point shift (19-01) was shown. |
| 3 | One owner-approved baseline covers the complete set | ⚠️ DEFERRED (human) | No `Baseline/` directory, no `fingerprints.json`, `manifest.json`, `19-12-CANDIDATE.md`, `19-13-APPROVAL.md`, and `snapshot_publish.py` does not exist. Decided and recorded (owner msgs 3425, 3428). Not a defect, but the criterion is not met today. |
| 4 | Complete matrix gates every PR and release in CI, runtime reported; native visual policy tests run in it | ⚠️ PRESENT_BEHAVIOR_UNVERIFIED | `snapshot-gate.yml`: triggers `pull_request`, dispatch, `workflow_call`, push `ci/snapshot-gate`; `checks`, `build`, 27-shard matrix (`fail-fast: false`, `continue-on-error`), `triage`, `retry`, `native-policy` (iPhone and iPad), `aggregate` failing on any class or a non-success policy job. Wired into `deploy.yml`, `deploy-beta.yml` (`needs`) and `dependencies.yml` (`gh workflow run`, `actions: write`). Runtime is estimated in README (about 2,013 shard-minutes, 8.7 to 9 h at 5 at a time) from run 42577585956; no passing run exists. |
| 5 | Preview review documented and validated (17-15) | ✓ VERIFIED | `preview-review.md`, `validate-preview.py`, `test_preview.py` present; suite OK. The real render is a recorded Manual-Only human item. |
| 6 | Daily live check: app's parsers on the listed live pages, GET only, one self-closing issue per failure, no page content in issues or logs, sign-in pages skipped until a secret exists, runner-IP result recorded | ✓ VERIFIED | `LiveCheckTests` is the only target without the network guard (`Package.swift`, `test_network_guard.py` OK). `test_request_allowlist.py` OK; grep for POST and write request types in `LiveCheckTests` prints nothing. `report_issues.py` builds text from constant templates (16 tests against the recording fake `gh`). `live-check.yml`: daily 04:17 UTC, dispatch, `ci/live-check`; permissions `contents: read, issues: write, actions: read`; uploads only `results.json`; review fix IN-05 keeps the token out of `xcodebuild` and the checkout. `19-03-PROBE.md` `Verdict: reachable`; `19-15-RUNNER.md` `Choice: hosted (owner msg 2441)`; `19-16-DEPLOY.md` records hosted run 42443815779 with "log checked: no content". Post-merge items are human items above. |
| 7 | `Scripts/visual/README.md` matches the reduced Phase 17 harness and this phase's runner | ✓ VERIFIED | Contains `website-capture-20261104.json`; 0 matches for "Visual capture" or `run-regression.py`; describes Path B, 18 configurations, 27 shards (explains the re-plan from 20), triage, retry, aggregate, 5-job limit, baseline, candidates and approval, live check; states plainly what is not done. No home paths, addresses or names found. |
| 8 | Release builds contain no capture code, fixtures, test assets or SnapshotTesting linkage | ✓ VERIFIED | `VisualSnapshotSupport` (which imports SnapshotTesting) is linked only by the `VisualSnapshotTests` target in the project file and by the test module in `Package.swift`; no import in `AppPackage/Sources` outside it or in `App/` and `ShareExtension/`. `verify-release.py` forbids `SnapshotTesting`, `EHPANDA_`, `XCUI`, capture symbols, including IN-02's `captureSystemOverlay`. The recorded Release build scan PASS (0 findings) is in 19-VALIDATION.md; it was not re-run here (no xcodebuild). |

**Score:** 5/8 truths verified (2 present but behavior-unverified: 2 and 4; 1 deferred by decision: 3).

### Deferred Items

| # | Item | Addressed In | Evidence |
|---|------|-------------|----------|
| 1 | Green hosted gate run | STATE.md Deferred Items | Owner msgs 3425, 3426 |
| 2 | 19-12 candidate run and public snapshot repository | STATE.md Deferred Items | Owner msg 3428 |
| 3 | 19-13 approval, pinned baseline, green compare | STATE.md Deferred Items | Owner msg 3428 |
| 4 | 19-17 hosted controlled regression | STATE.md Deferred Items | Owner msg 3428 |

These are not in a later roadmap phase, so they stay visible as human items and keep the phase from `passed`.

### Required Artifacts

| Artifact | Expected | Status | Details |
|---|---|---|---|
| `AppPackage/Sources/VisualSnapshotSupport/HostedWindowCapture.swift` | host, settle, capture at 1x, compare, one retry | ✓ VERIFIED | Present, substantive, used by `SnapshotMatrixCase` |
| `AppPackage/Tests/SnapshotMatrix.xctestplan` | 18 configurations | ✓ VERIFIED | 18 |
| `AppPackage/Tests/VisualSnapshotTests/Resources/scenarios.json` | schema 2 inventory | ✓ VERIFIED | 137 scenarios |
| `Scripts/visual/snapshot_matrix.py`, `snapshot_shards.py`, `snapshot-shards.json` | enumeration, balanced plan | ✓ VERIFIED | `--check` current; 27 shards |
| `Scripts/visual/snapshot_aggregate.py`, `snapshot_report.py`, `snapshot_fetch.py`, `run-shard.sh`, `hosted-simulator.sh` | gate tooling | ✓ VERIFIED | Present; tests OK; `bash -n` OK |
| `.github/workflows/snapshot-gate.yml` | sharded gate | ✓ VERIFIED (code) | See truth 4 |
| `EhPandaUITests/NativeVisualPolicyUITests.swift`, `Support/LiveTextSize.swift` | 19-11 policy tests | ✓ VERIFIED | Present; run in `native-policy` job |
| `Scripts/visual/preview-review.md`, `validate-preview.py` | preview review | ✓ VERIFIED | Present; tests OK |
| `Scripts/live-check/*`, `.github/workflows/live-check.yml`, `AppPackage/Tests/LiveCheckTests/*` | daily check | ✓ VERIFIED | Present; tests OK |
| `Baseline/fingerprints.json`, `Baseline/manifest.json`, `Scripts/visual/snapshot_publish.py`, `Scripts/visual/snapshot-repo-README.md`, `19-12-CANDIDATE.md`, `19-13-APPROVAL.md`, `19-17-REGRESSION.md` | 19-12, 19-13, 19-17 Task 3 outputs | ⏸ DEFERRED | Absent by decision (owner msg 3428) |

### Key Link Verification

| From | To | Via | Status | Details |
|---|---|---|---|---|
| `SnapshotMatrixCase` | `HostedWindowCapture` | capture through it | WIRED | |
| `snapshot-gate.yml` | `snapshot_aggregate.py`, `snapshot-shards.json`, `run-shard.sh` | triage, aggregate, `fromJSON` | WIRED | |
| `deploy.yml`, `deploy-beta.yml` | `snapshot-gate.yml` | `uses` plus `needs`, compare mode | WIRED | |
| `dependencies.yml` | `snapshot-gate.yml` | `gh workflow run ... -f mode=compare` | WIRED | |
| `run-live-check.sh` | `report_issues.py` | results handed to the reporter | WIRED | |
| `Package.swift` | `TestNetworkGuard` | every test target but `LiveCheckTests` | WIRED | guard test passes both directions |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|---|---|---|---|
| Scripts/visual suite | `python3 -m unittest discover -s Scripts/visual -p 'test_*.py'` | Ran 384, OK | ✓ PASS |
| Live-check suite | `python3 -m unittest discover -s Scripts/live-check -p 'test_*.py'` | Ran 27, OK | ✓ PASS |
| Shard plan current | `snapshot_shards.py --check` | current | ✓ PASS |
| Inventory totals | `snapshot_matrix.py --totals` | 137 / 19,728 / 19,368 / 360 | ✓ PASS |
| WR-02 test pin | suite run without `CI` set | `test_hosted_simulator` passes (fixture pins `CI=true`, bac1ca916) | ✓ PASS |
| Shell syntax, YAML | `bash -n`; Ruby `YAML.load_file` on nine workflows | all OK (`fake-gh/gh` is Python, not shell) | ✓ PASS |

### Probe Execution

SKIPPED: the phase declares no `probe-*.sh` probes.

### Requirements Coverage

| Requirement | Source Plan | Status | Evidence |
|---|---|---|---|
| VIS-18-01 | 19-01 to 19-10, 19-17 | ? NEEDS HUMAN | Inventory, capture, aggregate, report, gate, README done; baseline approval and hosted gate pass deferred. REQUIREMENTS.md still "Pending", which is accurate. |
| VIS-19-01 | 19-03, 19-14, 19-15, 19-16 | ✓ SATISFIED in code | Post-merge scheduled-run confirmations are open human items. REQUIREMENTS.md still "Pending" (appropriate until merge). |
| CAP-17-02 | 19-01 to 19-10, 19-17 | ? NEEDS HUMAN | Controlled regression deferred |
| CAP-17-03 | 19-12, 19-13 | ? NEEDS HUMAN | Baseline commit not done |
| CAP-17-01 (moved 17-11) | 19-05 to 19-08 | ✓ SATISFIED | Real-app scenario dispatch on real views and reducers |
| CAP-17-06 (moved 17-09-T2, 17-15) | 19-11, 19-17 | ✓ SATISFIED in code | Policy tests and preview docs; the real preview render is Manual-Only |

No orphaned requirement: every ID that ROADMAP maps to Phase 19 appears in a plan.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|---|---|---|---|---|
| Phase 19 code, scripts, workflows | — | `TBD`, `FIXME`, `XXX`, `TODO` | none found | The grep hits were a `mktemp` template and a content-size constant |
| `.github/workflows/snapshot-gate.yml` and others | — | stubs, empty implementations | none found | |
| `19-REVIEW.md` | — | IN-02 to IN-04, IN-06 to IN-09, IN-11 to IN-16 left open | ℹ️ Info | Owner scoped the fix to WR-01, WR-02, IN-01, IN-05, IN-10 (all fixed, commits verified in `git log`). IN-15 (baseline not checked for unscenarioed fingerprints) and IN-08 (`validate-preview.py` fails open when fields are absent) matter once the baseline and the real preview render exist. |

Review fixes checked in code: WR-01 job-level `concurrency` (`deploy-release`, `deploy-beta`, `cancel-in-progress: false`) present; IN-10 `timeout-minutes: 120` on `Deploy` and `dependencies`; IN-05 `persist-credentials: false` in `live-check.yml`; WR-02 `CI`-guarded `killall`, test pinned by bac1ca916. Laboratory fix b10fb61aa: one `.toolbarTitleDisplayMode(.large)` line, no test change.

### Documentation drift (warnings, no goal impact)

- ROADMAP Phase 19 "Plans: 14/17 plans executed" while 15 plan lines are checked (19-12 and 19-13 open); STATE.md progress counts (318/321) likewise lag.
- `19-VALIDATION.md`: frontmatter `status: draft`, `wave_0_complete: false`, and the sign-off boxes "Wave 0 covers all MISSING references", "Feedback latency < 360 s", "`nyquist_compliant: true` set" are unchecked and "Approval: pending" while `nyquist_compliant: true` is set; the compliance flag holds only under the accepted flake rule.
- STATE.md Deferred Items row for 19-10 mentions a `deploy-pal.yml` gate from 20-11; that workflow does not exist yet (Phase 20). The README says Phase 20's release workflows require the `aggregate` check, while `deploy.yml` and `deploy-beta.yml` already do. Neither misstates the phase result.
- 19-17 Task 4's verify regex (`Required check: (required|not required) (owner msg N)`) does not match the recorded wording "not required for now (owner msg 3431)"; the decision itself is recorded.
- The report frontmatter carries no `covered_files` or `covered_digest`: `node` is not installed on this host, so the fingerprint command could not run and the values were not hand-written. The `verification.status` self-check was skipped for the same reason; status was set by the Step 9 decision tree.

### Documentation drift: resolved at close (2026-11-11)

The drift items above were reconciled in the close-out records; the findings text above is kept as verified.

- ROADMAP Phase 19 now reads 15/17 plans executed (19-12 and 19-13 deferred, unchecked); STATE progress counts match.
- `19-VALIDATION.md`: `status: validated`, `wave_0_complete: true` (executed rows), sign-off checked, seven deferred rows
  kept as deferred.
- The STATE.md Deferred Items row and `19-10-SUMMARY.md` now say `deploy-pal.yml` arrives in Phase 20.
- The required-check answer is worded "Required check: not required (owner msg 3431), for now", which the 19-17 Task 4
  verify regex matches; the regex is unchanged.
- The security audit's four open threats are accepted-deferred by the owner (msg 3573), see `19-SECURITY.md`.
- `covered_files` and `covered_digest` are still absent (no `node` on the host).
- Phase 19 is marked complete with deferred items in ROADMAP.md and STATE.md; this report's `status: human_needed` is
  unchanged, and human items 1 to 3 stay owed (STATE.md Deferred Items).

### Human Verification Required

1. **Green hosted gate** (19-10 Task 4): run `snapshot-gate.yml` on the hosted runner; expect `aggregate` green, retries only on injected shards. Owed before release day (owner msgs 3425, 3428).
2. **Candidate run, snapshot repository, owner approval, pinned baseline, green compare run** (19-12, 19-13): owner judgement and pushes. Owner msg 3428.
3. **Controlled regression, red then green** (19-17 Task 3): needs 1 and 2 first.
4. **Real preview render** of the first `DownloadsView+Subviews.swift` preview in two locales through `validate-preview.py`: needs Xcode.
5. **After merge**: first scheduled live-check run from `main`, previous-results path on runs two and three, first real issue and label, the 60-day inactivity rule.

### Gaps Summary

No blocking gap: everything the phase built exists, is wired, and passes its local checks (384 and 27 Python tests, shard plan current, inventory 137 scenarios fully backed by factories, review fixes in place, Release isolation by construction). Success criteria 2, 3 and 4 are not proven because their hosted and owner-approval steps were deferred by decision and are recorded correctly in STATE, ROADMAP, README and VALIDATION; until then the screenshot gate cannot pass and the release workflows will refuse to ship, which is the intended safeguard. The phase must not be marked complete until human items 1 to 3 are done.

---

_Verified: 2026-11-11_
_Verifier: Claude (gsd-verifier)_
