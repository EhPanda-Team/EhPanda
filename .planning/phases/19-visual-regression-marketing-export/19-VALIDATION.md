---
phase: "19"
slug: "visual-regression-marketing-export"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: true
wave_0_complete: false
created: "2026-11-07"
---

# Phase 19 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Source: 19-RESEARCH.md §11 "Validation
> Architecture". `nyquist_compliant` is set by plan 19-17 Task 5 once every automated row is green.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | XCTest (`VisualSnapshotTests` app-hosted, `LiveCheckTests`, `EhPandaUITests`), Swift Testing (FeatureTests), Python `unittest` (`Scripts/visual`, `Scripts/live-check`) |
| **Config file** | `AppPackage/Tests/SnapshotMatrix.xctestplan` (new, 19-01), `AppPackage/Tests/LiveCheck.xctestplan` (new, 19-03), `AppPackage/Tests/VisualTests.xctestplan`, `UITests.xctestplan`, `AppPackage/Tests/FeatureTests.xctestplan`, `.swiftlint.yml` |
| **Devices** | `EhPanda iPhone Air` (`$PHONE`) then `EhPanda iPad Pro 11-inch (M5)` (`$PAD`), resolved by name: `PHONE=$(xcrun simctl list devices \| grep "EhPanda iPhone Air (" \| grep -Eo '[0-9A-F-]{36}' \| head -1)`; `PAD=$(xcrun simctl list devices \| grep "EhPanda iPad Pro 11-inch (M5) (" \| grep -Eo '[0-9A-F-]{36}' \| head -1)` |
| **Quick run command** | `Scripts/visual/run-snapshot-local.sh --device phone --config en-large --classes <Classes> --mode compare --refs DIR --out DIR` (from 19-02); `python3 -m unittest discover -s Scripts/visual -p 'test_snapshot*.py'`; `python3 -m unittest discover -s Scripts/live-check -p 'test_*.py'` |
| **Full suite command** | FeatureTests and UITests on `$PHONE` then `$PAD`; the hosted gate (20 shards, triage, retry, native-policy, aggregate) in compare mode; one live-check run; one `xcodebuild` at a time per host |
| **Lint** | `swiftlint lint --strict --no-cache --config .swiftlint.yml` → `Found 0 violations` |
| **Estimated runtime** | Python suites < 60 s; a group's snapshot classes in one configuration 2 to 6 min per device; FeatureTests ~26 min per device; the hosted gate about 2 to 3 h (19-04 measures) |

---

## Sampling Rate

- **After every task commit:** the touched Python tests, or the touched snapshot classes on `$PHONE` in `en-large`
  (candidate then compare), and strict lint of the touched paths.
- **After every plan:** the plan's classes on `$PHONE` and `$PAD`; for workflow plans, the workflow tests and
  actionlint.
- **Before `/gsd-verify-work`:** plan 19-17's gate: FeatureTests and UITests on both devices, 0 failures, 0
  Repetition nodes, lint 0, every Python suite, the Release scan; the hosted compare run green; the controlled
  regression red then green.
- **Max feedback latency:** 360 s for a local snapshot class run; 60 s for Python.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 19-01-01 | 01 | 1 | VIS-18-01, CAP-17-02 | T-19-01 | a compare run leaves the reference directory byte-identical | unit (app-hosted) | `-testPlan VisualTests -only-testing:VisualSnapshotTests/HostedWindowCaptureTests` | ✅ | ✅ green |
| 19-01-02 | 01 | 1 | VIS-18-01, CAP-17-01 | — | per-process language and size, in-process orientation and appearance, pins asserted | snapshot | tracer candidate + two compares, `-testPlan SnapshotMatrix -only-test-configuration en-large` | ✅ | ✅ green |
| 19-01-03 | 01 | 1 | VIS-18-01 | — | a 1-point shift is `changed`; clone counts measured | snapshot + record | `grep` of `19-01-MEASURE.md` rows | ✅ | ✅ green |
| 19-02-01 | 02 | 2 | VIS-18-01 | T-19-03 | every not-applicable rule has a reason | script | inventory assertion + `test_contracts.py` | ✅ | ✅ green |
| 19-02-02 | 02 | 2 | VIS-18-01 | T-19-04 | shard plan deterministic and balanced | unit | `test_snapshot_*.py`; `snapshot_shards.py --check` | ✅ | ✅ green |
| 19-02-03 | 02 | 2 | VIS-18-01 | — | no unknown factory ID | unit (app-hosted) | `-only-testing:VisualSnapshotTests/ScenarioInventoryTests` | ✅ | ✅ green |
| 19-03-01 | 03 | 2 | VIS-19-01 | T-19-05, T-19-06 | guard on every other target; inert without opt-in | unit | `test_network_guard.py`; LiveCheck plan without opt-in | ✅ | ✅ green |
| 19-03-02 | 03 | 2 | VIS-19-01 | T-19-05 | probe output has four fields only | live (local) | probe JSON assertion | ✅ | ✅ green |
| 19-03-03 | 03 | 2 | VIS-19-01 | T-19-08 | push only after the owner's go-ahead | checkpoint | `grep "Verdict:"` in `19-03-PROBE.md` | ✅ | ✅ green |
| 19-04-01 | 04 | 4 | VIS-18-01 | — | worker choice by the stated rule | unit | `test_snapshot_measure.py` | ✅ | ✅ green |
| 19-04-02 | 04 | 4 | VIS-18-01 | — | no `.xcresult` or reference upload | workflow | YAML assertion | ✅ | ✅ green |
| 19-04-03 | 04 | 4 | VIS-18-01 | T-19-09 | billing checked before more hosted runs | checkpoint | `source: measured`; `--check` | ✅ | ✅ green |
| 19-05-01..03 | 05 | 3 | VIS-18-01, CAP-17-01 | T-19-11 | synthetic content only; real views and reducers | snapshot | `run-snapshot-local.sh` both devices, two compares | ✅ | ✅ green |
| 19-06-01..03 | 06 | 3 | VIS-18-01, CAP-17-01 | T-19-13 | synthetic content only | snapshot | `run-snapshot-local.sh` both devices, two compares | ✅ | ✅ green |
| 19-07-01..03 | 07 | 3 | VIS-18-01, CAP-17-01 | T-19-14, T-19-15 | member IDs only; no Send dispatched | snapshot | `run-snapshot-local.sh` both devices, two compares | ✅ | ✅ green |
| 19-08-01..03 | 08 | 3 | VIS-18-01, CAP-17-01 | T-19-16 | no account details | snapshot | `run-snapshot-local.sh` both devices, two compares | ✅ | ✅ green |
| 19-09-01 | 09 | 3 | VIS-18-01 | T-19-17 | a missing result is never a pass; picture changes never retried | unit | `test_snapshot_aggregate.py` | ✅ | ✅ green |
| 19-09-02 | 09 | 3 | CAP-17-02 | T-19-18 | report loads nothing remote | unit | `test_snapshot_report.py` | ✅ | ✅ green |
| 19-10-01 | 10 | 5 | VIS-18-01 | — | every inventory ID has a factory | unit (app-hosted) | `ScenarioInventoryTests`; `--check` | ✅ (19-02) | ✅ green |
| 19-10-02 | 10 | 5 | VIS-18-01 | T-19-20 | altered, missing or extra baseline file fails | unit | `test_snapshot_fetch.py`; `bash -n run-shard.sh` | ✅ | ✅ green |
| 19-10-03 | 10 | 5 | VIS-18-01 | T-19-19 | fail-fast off, continue-on-error, minimal permissions | workflow | `test_snapshot_gate.py`; actionlint | ✅ | ✅ green |
| 19-10-04 | 10 | 5 | VIS-18-01 | T-19-22 | retries proven; fault commits never on the phase branch | checkpoint (hosted) | `19-10-PROOF.md` greps; `git log` grep | ❌ W0 | ⏸ deferred (owner msg 3425) |
| 19-11-01..02 | 11 | 1 | CAP-17-06 | T-19-23 | text size reset after tests | UI | `-testPlan UITests -only-testing:EhPandaUITests/NativeVisualPolicyUITests` both devices | ✅ | ✅ green |
| 19-12-01 | 12 | 6 | CAP-17-03 | — | publisher never pushes by itself | unit | `test_snapshot_publish.py` | ❌ W0 | ⏸ deferred (owner msg 3428) |
| 19-12-02..03 | 12 | 6 | VIS-18-01, CAP-17-03 | T-19-24 | candidate run and repository creation only after the owner's go-ahead | checkpoint | `19-12-CANDIDATE.md` greps; `gh api` visibility and commit count | ❌ W0 | ⏸ deferred (owner msg 3428) |
| 19-13-01 | 13 | 7 | VIS-18-01 | T-19-26 | every picture pre-checked; every flag decided | unit + agent review | `test_snapshot_precheck.py`; verdict grep | ❌ W0 | ⏸ deferred (owner msg 3428) |
| 19-13-02..03 | 13 | 7 | CAP-17-03 | T-19-27, T-19-28 | approval explicit; pushes after go-ahead; fingerprints pinned; hosted compare green | checkpoint | approval greps; fingerprints assertion; tag via `gh api` | ❌ W0 | ⏸ deferred (owner msg 3428) |
| 19-13-04 | 13 | 7 | CAP-17-03 | — | manifest complete, tolerances as D-10 | script | manifest assertion | ❌ W0 | ⏸ deferred (owner msg 3428) |
| 19-14-01..02 | 14 | 3 | VIS-19-01 | T-19-29, T-19-30 | GET only; enum-only results; block vs break told apart offline | unit | `test_*.py` in `Scripts/live-check`; `-only-testing:LiveCheckTests/LiveCheckOfflineTests` | ✅ | ✅ green |
| 19-14-03 | 14 | 3 | VIS-19-01 | T-19-29 | live results have four fields per page | live (local) | results JSON assertion | ✅ | ✅ green |
| 19-15-01 | 15 | 4 | VIS-19-01 | — | runner chosen by the owner after the probe | checkpoint | `Choice:` grep | ✅ | ✅ green |
| 19-15-02 | 15 | 4 | VIS-19-01 | T-19-32, T-19-33 | no input text reaches gh; unreachable never opens a parser issue | unit | `test_report_issues.py` | ✅ | ✅ green |
| 19-15-03..04 | 15 | 4 | VIS-19-01 | T-19-34 | minimal permissions; no `.xcresult`; placeholders only | script | `bash -n`, `plutil -lint`, YAML assertion; dry-run record | ✅ | ✅ green |
| 19-16-01..02 | 16 | 5 | VIS-19-01 | T-19-35, T-19-36 | first real log checked for content | checkpoint | `19-16-DEPLOY.md` greps | ✅ | ✅ green |
| 19-17-01..02 | 17 | 8 | VIS-18-01, CAP-17-06 | T-19-39 | README without personal details | script + unit | README greps; `test_preview.py` | ✅ | ✅ green (the real preview render stays open, see Manual-Only) |
| 19-17-03 | 17 | 8 | CAP-17-02 | T-19-38 | controlled regression red then green on the hosted gate | checkpoint (hosted) | `19-17-REGRESSION.md` greps | ❌ W0 | ⏸ deferred (owner msg 3428) |
| 19-17-04 | 17 | 8 | VIS-18-01 | — | required-check choice is the owner's | checkpoint | `Required check:` grep | ✅ | ✅ green (answer below) |
| 19-17-05 | 17 | 8 | all | T-19-37 | Release build free of capture code, fixtures and SnapshotTesting | suite | FeatureTests and UITests both devices; lint; Python suites; `verify-release.py` | ✅ | ✅ green under the accepted rule (clean rerun; first-run flakes and iPad retries noted, owner msgs 3539 and 3554; see Phase gate results) |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Phase gate results (19-17 Task 5, run on the local machine, one `xcodebuild` at a time)

| Step | Result |
|------|--------|
| FeatureTests `$PHONE` | `** TEST SUCCEEDED **`; 1838 passed, 0 failed, 140 skipped, 9 expected failures. 2 Repetition nodes, both passed (see note 1). |
| FeatureTests `$PAD` | `** TEST SUCCEEDED **`; same counts. 2 Repetition nodes, both passed (note 1). |
| UITests `$PHONE`, first run | `** TEST SUCCEEDED **`; 122 passed, 0 failed, 21 skipped. 2 Repetition nodes: `AccessibilityAuditUITests.testFiltersSheetAudit()` failed its first run ("The Front Page navigation title did not appear") and passed on retry 1 (note 2). |
| UITests `$PAD`, first run | `** TEST SUCCEEDED **`; 125 passed, 0 failed, 18 skipped. 2 Repetition nodes: `AccessibilityAuditUITests.testPadSettingAndDetailModalsAudit()` failed its first run ("Front Page did not render a gallery row") and passed on retry 1 (note 2). |
| UITests `$PHONE`, clean rerun (owner msg 3539) | `** TEST SUCCEEDED **`; 122 passed, 0 failed, 21 skipped; **0 Repetition nodes**; 143 test cases. |
| UITests `$PAD`, rerun (owner msgs 3539, 3554) | `** TEST SUCCEEDED **`; 125 passed, 0 failed, 18 skipped; 143 test cases; **4 Repetition nodes** from two other tests, each failed run 1 and passed retry 1 (note 3). The two audit tests that failed in the first run passed their first run here. |
| Strict no-cache SwiftLint | `Found 0 violations, 0 serious in 862 files` (SwiftLint 0.65.1, the pinned plugin binary, all tracked `*.swift` files; the bare repository root also picks up untracked worktrees and package checkouts, which are not project files). |
| `Scripts/visual` Python suite | 384 tests, OK. `snapshot_shards.py --check`: current. `test_preview.py` is part of it. |
| `Scripts/live-check` Python suite | 27 tests, OK. |
| Release simulator build | `** BUILD SUCCEEDED **` (`$TMPDIR/ehp-1917/release/DerivedData`, built with `CLANG_COVERAGE_MAPPING=NO LD_GENERATE_MAP_FILE=YES`). |
| `verify-release.py` | exit 0, `PASS: 0 finding(s)` with the app, build log, both app and extension link maps, a launch probe on `$PHONE` and a Debug control build (`$TMPDIR/ehp-1917/release/scan/release-isolation.json`). |

Notes:

1. The two FeatureTests Repetition nodes are one parameterized test,
   `CommentFilterTests.aKanaTermMatchesInFullOrHalfWidthWithItsDakuten(text:)`, whose argument list holds two inputs
   that print the same (`"ゲゴ語"` precomposed and with combining marks). Both ran once and passed; the FeatureTests plan
   has no retry setting, so this is a display artefact of the result bundle, not a retry.
2. The two first-run UITests Repetition nodes were real retries of a flaky first run (`UITests.xctestplan` retries on
   failure, up to 3 runs). Both tests tap Home's "Show All" and wait for the Front Page. Root cause, from the
   evidence kept with the run: the tap was delivered but the app saw it at about 1/3 of the intended point. In an
   instrumented phone failure the app received one touch at window point (125, 131) while "Show All" is centred at
   (374.7, 395), a factor of 3, the phone's display scale; the app received no `sectionTapped` action and no push.
   The synthesized event recorded in the original gate failure was correct (374.67, 395, window 420 x 912), so the
   misplacement is below both the test and the app (simulator or XCTest touch injection). Home was fully loaded and
   settled at the time (hierarchy and screen recording), the launch automation never pops the pushed path, and the
   "Show All" frame was stable in all 30 sampled iterations. Frequency: 3 failures in about 30 early tries of the
   single test, 0 in about 310 later iterations (including 60 with a second simulator booting and shutting down) and
   0 in the clean phone rerun; the Mac was shared with other agents (load average 70 to 127). No app, test or plan
   change was made, no retry helper added, no assertion weakened.
3. The iPad rerun's four Repetition nodes are two other tests:
   - `GalleryCardUITests.testFrontPageGridKeepsRatings()` failed its first run ("Front Page layout never became
     hittable", 30 s wait). The failure screenshot shows Home still on screen with "Show All" visible, so it is the
     same dropped "Show All" tap as note 2.
   - `ShareSheetUITests.testShareSheetHandoffLandsOnDetail()` failed its first run ("The activity view did not expose
     the EhPanda extension", 431 s). Verdict: simulator and slowness, not the app. In the failing run Safari's link
     menu was open and the tap on "Share..." closed it, but no activity view, popover or sheet was presented at all
     (screen recording and the failure hierarchy), so the extension list was never shown. The extension is embedded
     (`PlugIns/ShareExtension.appex`) and its activation rule (`NSExtensionActivationSupportsWebURLWithMaxCount` = 1)
     is the one the passing retry uses: on the same simulator a few minutes later the "EhPanda" share cell appeared
     and the hand-off reached Detail, and `testDetailOverflowDisabledActionsAndSharePresentation` passed in the same
     session. The time went to Safari never reporting idle: each action waits the full 60 s quiescence timeout (five
     times in the failing run, three in the retry), the first run also had the link preview to hide, and the menu
     stayed open about four minutes before the "Share..." tap, then about 125 s of failure triage. No crash or
     extension fault was found. Safari remembers "Hide preview", which is why the retry skipped it.
4. Acceptance: the plan's bar is 0 failures and 0 Repetition nodes. Owner msg 3539: record as environmental and gate
   on a clean rerun. Owner msg 3554: accept, with the retries noted. The phone rerun is clean; the iPad rerun has
   0 failures and 4 Repetition nodes, noted here. Under that accepted rule the local rows are green and
   `nyquist_compliant` is true. The hosted rows below stay deferred.

Deferred rows (not green, not red): 19-10-04, 19-12-01..03, 19-13-01..04 and 19-17-03 need the hosted runner and its
pushes (owner msgs 3425, 3428). Row 19-17-04 is answered: Required check: not required for now (owner msg 3431).

---

## Wave 0 Requirements

- [ ] Each plan writes the test files it names before the code they test (TDD tasks); no framework install is
  needed: XCTest, Swift Testing and Python `unittest` are already used.
- [ ] `Scripts/visual/run-snapshot-local.sh` (19-02) exists before the scenario plans 19-05 to 19-08 run.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Runner-IP answer on GitHub's hosted Mac | VIS-19-01 | needs a push, which needs the owner's go-ahead (OQ-6) | 19-03 Task 3 |
| Hosted cost, worker count and billing | VIS-18-01 | needs a push and reading the run's billing (R-1) | 19-04 Task 3 |
| Retries and error handling on GitHub | VIS-18-01 | needs pushes with fault commits on a `ci/` branch | 19-10 Task 4 |
| Agent visual pre-check of every picture | VIS-18-01 | visual judgement on contact sheets | 19-13 Task 1 |
| The owner's one approval | VIS-18-01, CAP-17-03 | owner judgement (D-17) | 19-13 Task 2 |
| Runner choice for the live check | VIS-19-01 | owner decision after the probe (OQ-3) | 19-15 Task 1 |
| Required status check on `main` | VIS-18-01 | repository setting only the owner changes | 19-17 Task 4. Required check: not required for now (owner msg 3431). The check runs on every PR but is not required to merge into `main`. |
| Controlled regression, red then green, on the hosted gate | CAP-17-02 | needs two pushes to a `ci/` branch and a green hosted gate | 19-17 Task 3. Deferred (owner msg 3428). |
| Hosted runs of 19-10 Task 4, 19-12, 19-13 | VIS-18-01, CAP-17-03 | need the hosted runner and pushes | Deferred (owner msgs 3425, 3428); see STATE.md Deferred Items. |
| First scheduled live-check run from `main` (hosted) or the timer's first unattended day (Mac) | VIS-19-01 | schedules run only from the default branch, after merge | 19-16 "Pending after merge" |
| Scheduled workflows disabled after 60 days without repository activity | VIS-19-01 | GitHub behaviour over time | README note; re-enable if disabled |
| Previous-results path of the live check | VIS-19-01 | the first run found no earlier artifacts | 19-16 "Pending after merge": the second and third scheduled runs log `2 previous run(s) found` (or 1) with no rejected files |
| The `live-check` label and the first real issue | VIS-19-01 | no page broke on the first run, so neither exists yet | 19-16 "Pending after merge": the first scheduled run with a `parser` page; check the issue title and body against the fixed templates |
| Real preview render of `DownloadsView+Subviews.swift` | CAP-17-06 | needs a running Xcode with the preview tools, which this run did not open | 19-17 Task 2: render the first preview in two locales and validate it with `validate-preview.py` |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [ ] Feedback latency < 360 s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
