---
phase: 19-visual-regression-marketing-export
reviewed: 2026-11-11T00:00:00Z
depth: standard
files_reviewed: 97
files_reviewed_list:
  - .github/actionlint.yaml
  - .github/workflows/dependencies.yml
  - .github/workflows/deploy-beta.yml
  - .github/workflows/deploy.yml
  - .github/workflows/live-check.yml
  - .github/workflows/runner-probe.yml
  - .github/workflows/snapshot-gate.yml
  - .github/workflows/snapshot-measure.yml
  - AppPackage/Package.swift
  - AppPackage/Sources/SettingFeature/Components/LaboratorySettingView.swift
  - AppPackage/Sources/SettingFeature/WaveForm.swift
  - AppPackage/Sources/VisualSnapshotSupport/AccessibilityActionDriver.swift
  - AppPackage/Sources/VisualSnapshotSupport/Fixtures/GalleryFixtures.swift
  - AppPackage/Sources/VisualSnapshotSupport/Fixtures/LibraryFixtures.swift
  - AppPackage/Sources/VisualSnapshotSupport/Fixtures/SettingsFixtures.swift
  - AppPackage/Sources/VisualSnapshotSupport/HostedWindowCapture.swift
  - AppPackage/Sources/VisualSnapshotSupport/SnapshotCoordinate.swift
  - AppPackage/Sources/VisualSnapshotSupport/SnapshotResultWriter.swift
  - AppPackage/Tests/AppToolsTests/ReduceMotionGatingSourceTests.swift
  - AppPackage/Tests/LiveCheck.xctestplan
  - AppPackage/Tests/LiveCheckTests/.swiftlint.yml
  - AppPackage/Tests/LiveCheckTests/DailyLiveCheckTests.swift
  - AppPackage/Tests/LiveCheckTests/Fixtures/challenge.html
  - AppPackage/Tests/LiveCheckTests/Fixtures/ip-banned.html
  - AppPackage/Tests/LiveCheckTests/Fixtures/toplists-changed.html
  - AppPackage/Tests/LiveCheckTests/Fixtures/toplists.html
  - AppPackage/Tests/LiveCheckTests/LiveCheckExpectation.swift
  - AppPackage/Tests/LiveCheckTests/LiveCheckGate.swift
  - AppPackage/Tests/LiveCheckTests/LiveCheckOfflineTests.swift
  - AppPackage/Tests/LiveCheckTests/LiveCheckPage.swift
  - AppPackage/Tests/LiveCheckTests/LiveCheckResults.swift
  - AppPackage/Tests/LiveCheckTests/LiveCheckRunner.swift
  - AppPackage/Tests/LiveCheckTests/PageObservation.swift
  - AppPackage/Tests/LiveCheckTests/ProbeReportTests.swift
  - AppPackage/Tests/LiveCheckTests/RunnerProbeTests.swift
  - AppPackage/Tests/SettingFeatureTests/WaveFormReduceMotionTests.swift
  - AppPackage/Tests/SnapshotMatrix.xctestplan
  - AppPackage/Tests/VisualSnapshotTests/FixtureArtwork.swift
  - AppPackage/Tests/VisualSnapshotTests/Matrix/BrowsingSnapshotTests.swift
  - AppPackage/Tests/VisualSnapshotTests/Matrix/BrowsingStepTests.swift
  - AppPackage/Tests/VisualSnapshotTests/Matrix/GallerySnapshotTests.swift
  - AppPackage/Tests/VisualSnapshotTests/Matrix/HostedWindowCaptureTests.swift
  - AppPackage/Tests/VisualSnapshotTests/Matrix/LibrarySnapshotTests.swift
  - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Browsing.swift
  - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Gallery.swift
  - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Library.swift
  - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog+Settings.swift
  - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioCatalog.swift
  - AppPackage/Tests/VisualSnapshotTests/Matrix/ScenarioInventoryTests.swift
  - AppPackage/Tests/VisualSnapshotTests/Matrix/SettingsSnapshotTests.swift
  - AppPackage/Tests/VisualSnapshotTests/Matrix/SnapshotMatrixCase.swift
  - AppPackage/Tests/VisualSnapshotTests/Matrix/TracerSnapshotTests.swift
  - AppPackage/Tests/VisualSnapshotTests/Resources/scenarios.json
  - EhPanda.xcodeproj/xcshareddata/xcschemes/EhPanda.xcscheme
  - EhPandaUITests/NativeVisualPolicyUITests.swift
  - EhPandaUITests/Support/LiveTextSize.swift
  - EhPandaUITests/Support/XCUIApplication+GalleryNavigation.swift
  - Scripts/live-check/fake-gh/gh
  - Scripts/live-check/live-check.plist.template
  - Scripts/live-check/report_issues.py
  - Scripts/live-check/run-live-check.sh
  - Scripts/live-check/test_network_guard.py
  - Scripts/live-check/test_report_issues.py
  - Scripts/live-check/test_request_allowlist.py
  - Scripts/visual/README.md
  - Scripts/visual/contracts.py
  - Scripts/visual/hosted-simulator.sh
  - Scripts/visual/preview-review.md
  - Scripts/visual/regression-environment.json
  - Scripts/visual/run-regression.py
  - Scripts/visual/run-shard.sh
  - Scripts/visual/run-snapshot-local.sh
  - Scripts/visual/snapshot-cost.json
  - Scripts/visual/snapshot-shards.json
  - Scripts/visual/snapshot_aggregate.py
  - Scripts/visual/snapshot_fetch.py
  - Scripts/visual/snapshot_infra.py
  - Scripts/visual/snapshot_matrix.py
  - Scripts/visual/snapshot_measure.py
  - Scripts/visual/snapshot_report.py
  - Scripts/visual/snapshot_shard.py
  - Scripts/visual/snapshot_shards.py
  - Scripts/visual/test_contracts.py
  - Scripts/visual/test_hosted_simulator.py
  - Scripts/visual/test_preview.py
  - Scripts/visual/test_run_shard.py
  - Scripts/visual/test_run_snapshot_local.py
  - Scripts/visual/test_snapshot_aggregate.py
  - Scripts/visual/test_snapshot_fetch.py
  - Scripts/visual/test_snapshot_gate.py
  - Scripts/visual/test_snapshot_infra.py
  - Scripts/visual/test_snapshot_matrix.py
  - Scripts/visual/test_snapshot_measure.py
  - Scripts/visual/test_snapshot_report.py
  - Scripts/visual/test_snapshot_shard.py
  - Scripts/visual/test_snapshot_shards.py
  - Scripts/visual/validate-preview.py
findings:
  # Workflow tiers: critical = Critical; warning = High + Medium; info = Low + Info. Detail in `severity` below.
  critical: 0
  warning: 2
  info: 16
  total: 18
  necessity: 0
severity:
  critical: 0
  high: 0
  medium: 2
  low: 10
  info: 6
status: issues_found
---

# Phase 19: Code Review Report

**Reviewed:** 2026-11-11
**Depth:** standard
**Files Reviewed:** 97
**Status:** issues_found

## Summary

Scope: the 96 non-planning files that the phase's `(19-NN)` commits touched (`git log --grep='(19-' --name-only`),
plus `LaboratorySettingView.swift` from commit 8b5799daa (added to the phase by the lead after the first pass), cross-checked against the `key-files` of every `19-*-SUMMARY.md`; the two lists agree. No evaluation-scope
resolver was needed (SUMMARY scoping was complete). Read in full: the eight workflows, every Python tool under
`Scripts/visual` and `Scripts/live-check` that carries logic, both shell runners and the simulator helper, all of
`VisualSnapshotSupport`, `SnapshotMatrixCase`, the LiveCheck target (runner, classifier, observer, reporter inputs),
`LiveTextSize`, `NativeVisualPolicyUITests`, `WaveForm` and its tests. Read selectively (structure, registration and
data consistency checked by script, not line by line): the four `ScenarioCatalog+*.swift` group files, the
`*SnapshotTests.swift` class lists, `scenarios.json`, `snapshot-shards.json`, `SnapshotMatrix.xctestplan`, the
LiveCheck fixtures and offline tests, the Python test files, `README.md`. Nothing was built or run.

Checked by script and found consistent: the 137 inventory scenarios against the `capture(scenario:)` calls (every
scenario captured by at least one non-`Tracer` class, none unregistered); the 18 `SnapshotMatrix` configurations
against the `<locale>-<size>` naming, `-AppleLanguages`, `-AppleLocale`, content size category and
`EHPANDA_SNAPSHOT_CONFIGURATION`; the 27 shards (18 iPhone x 1 configuration, 9 iPad x 2) against `runs`,
`invocations` and the README; the `WaveForm` entries of the Reduce Motion census (6 mentions, 1 ternary, 1 read).

Overall the gate is built fail-closed in the places that matter: a coordinate without a line is an error, a
missing or malformed `shard.json` is a lost runner, a shard-level error is retried once and a picture-level one is
not, the baseline is hash-verified before any comparison, `compare` never writes to a reference, and the live
check's reporter validates the results file against a fixed vocabulary before any `gh` call. No Critical or High
defect was found. Two Medium and sixteen smaller findings follow. 8b5799daa (a 4-line `.toolbarTitleDisplayMode(.large)` on Laboratory) is correct and has no defect; one Info note on it is IN-16.

### Accepted / deferred (not re-raised)

- Hosted snapshot gate passing is deferred to before release day (owner msg 3425, 3428); the hosted parts of
  19-12, 19-13 and 19-17 are deferred with it. Findings below that touch the gate concern code, not that pass.
- Rare simulator tap mis-delivery and the iPad share-sheet retry: environmental, accepted with retries noted
  (owner msg 3539, 3554).

## Warnings

### WR-01: Release workflow has no concurrency guard, and the gate now widens the overlap window to hours

**Severity:** Medium
**File:** `.github/workflows/deploy.yml:27-41` (also `.github/workflows/deploy-beta.yml:31-44`)
**Issue:** 19-10 put `needs: snapshot-gate` in front of `Deploy`. The gate is a 27-shard run that the README puts at
hours, and its own concurrency group is `snapshot-gate-run-<run_id>` (`snapshot-gate.yml:47-52`), so two merged
release pull requests, or two beta dispatches, gate and then deploy in parallel. `deploy.yml` has no `concurrency`
at all. In `deploy.yml` the second run to finish creates its GitHub release and tag (`:156-168`), then fails at
`git push origin HEAD` (`:235`, non-fast-forward against the other run's AltStore/SideStore commit), leaving a
published release whose source catalogue was never updated. Before 19-10 the window was one build; now it is the
gate's duration, so the overlap is likelier. Deploy workflows are the case the CI/CD rubric asks a guard for.
**Fix:** a workflow-level guard that queues rather than cancels (cancelling a release half way is worse):
```yaml
concurrency:
  group: deploy-release        # deploy-beta.yml: deploy-beta
  cancel-in-progress: false
```
Note that a `concurrency` key on the caller does not collide with the callee's own group (`snapshot-gate-run-*`).

### WR-02: `reset_simulators` kills the whole host's simulator service, with no hosted-only guard

**Severity:** Medium
**File:** `Scripts/visual/hosted-simulator.sh:152-161`
**Issue:** After a failed setup attempt the helper runs `killall -9 com.apple.CoreSimulator.CoreSimulatorService`
(`:159`). The header justifies it with "Nothing else runs simulators on a hosted runner" (`:150-151`), but nothing
enforces that, and `run-shard.sh` is written to run locally too (`wait_for_host` returns early only when `CI` is
set, `run-shard.sh:164-168`; `run-snapshot-local.sh` and the README describe local runs). On a developer Mac, or one
shared by several agents and apps, a failed `create` attempt force-kills every other process's simulators and
UI-test sessions. The device delete just above it is correctly limited to this attempt's UDID; only the service kill
is global.
**Fix:** skip the service kill unless the run is hosted, and say so:
```bash
if [ -n "${CI:-}" ]; then
    killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true
else
    echo "hosted-simulator: not restarting the simulator service outside CI" >&2
fi
sleep 10
```

## Info

### IN-01: `--started` misses non-parallel xcodebuild logs (case-sensitive `Test case '`)

**Severity:** Low
**File:** `Scripts/visual/snapshot_infra.py:72`
**Issue:** `started()` looks for `"Test case '"`. xcodebuild prints lower-case `Test case '…' started on 'Clone N …'`
only for parallel destinations; a non-parallel run prints `Test Case '-[Class method]' started.` (capital C; the
repository's own evidence logs show this form, and the workflow's grep already uses `[Cc]`, `snapshot-gate.yml:444`).
`run-shard.sh` starts two kinds of run with `-parallel-testing-enabled NO`: the iPad turn (`:227-229`) and the iPad
landscape capture (`:257`). For them the startup watchdog (`run-shard.sh:197-200`) has only `results.jsonl` growth to
go on, so a run that has begun a test but not yet finished its first scenario at `STARTUP_SECONDS` (20 min) is killed
as `no-test-started`. `test_snapshot_infra.py` only feeds the lower-case form, so the gap is untested.
**Fix:** `if re.search(r"Test [Cc]ase '", text): return True`, and add a capital-C case to `test_snapshot_infra.py`.

### IN-02: Any failure of the `drift` helper is recorded as environment drift

**Severity:** Low
**File:** `Scripts/visual/run-shard.sh:125-130`, `Scripts/visual/snapshot_shard.py:230-235`
**Issue:** `if ! DRIFT=$(helper drift …)` treats every non-zero exit as drift. `helper drift` exits 1 both when
problems are found and when Python itself fails (unreadable or malformed runtimes JSON, missing environment file,
`KeyError`). The latter records `infra: drift` with an empty detail and exits 0, so a tooling fault reads as an
environment mismatch, is never retried (drift is not a shard-level error) and fails the gate with a misleading class.
**Fix:** reserve exit 3 for "differs from the pin" in `snapshot_shard.py`, and in the script treat 3 as drift and any
other non-zero status as `unusable 'the drift check failed'` (no `shard.json`, so the gate retries it).

### IN-03: The result line is written before its picture, so a kill between the two loses the picture for good

**Severity:** Low
**File:** `AppPackage/Tests/VisualSnapshotTests/Matrix/SnapshotMatrixCase.swift:157-187`
**Issue:** `captureCoordinate` appends the line to `results.jsonl` (`:157-161`) and only then writes the candidate
picture (`:172-175`) or the `actual`/`difference` pair (`:178-184`). `results.jsonl` is the "done" marker for the
re-run logic (`snapshot_shard.py` `pending`, `SnapshotResultWriter.recordedKeys`). A clone killed by the budget
watchdog, the fault hook or a runner crash between the two writes leaves a `recorded` or `changed` line with no file:
the coordinate counts as finished, is never re-run, and the candidate set or the failure triplet silently lacks a
picture. The window is small but the run is built to be killed.
**Fix:** write the pictures first and the line last, so a line always implies its files.

### IN-04: The flake table in the step summary has no cap

**Severity:** Low
**File:** `Scripts/visual/snapshot_aggregate.py:232-238`
**Issue:** Every other list in `summary()` is capped at `SUMMARY_ITEMS` (200, `:229-231`); the flake log lists every
flaky coordinate. After a bad hosted run (a frozen runner makes hundreds of pictures pass on a retry) the Markdown
can pass GitHub's 1 MiB step-summary limit, which drops the whole summary, including the four class counts the cap
was designed to keep. The same rows are rendered unbounded in `snapshot_report.py:181-187` (that one is a file, not
a limited channel).
**Fix:** cap the table at `SUMMARY_ITEMS` rows and append `… and N more in aggregate.json`.

### IN-05: The `issues: write` token reaches the xcodebuild process tree and persists in the checkout

**Severity:** Low
**File:** `Scripts/live-check/run-live-check.sh:130-141`, `.github/workflows/live-check.yml:30-31,41-44`
**Issue:** `GH_TOKEN` is set for the one step that runs both the build and the reporter. `xcodebuild` therefore
inherits it with `-skipMacroValidation -skipPackagePluginValidation`, so third-party macro and plugin code builds
with a token that can open and close issues in a public repository in its environment (`TEST_RUNNER_` filtering only
protects the test process). `actions/checkout` also leaves the job's token in `.git/config` (default
`persist-credentials: true`). Both are the sandbox's job to contain, but neither is needed.
**Fix:** `env -u GH_TOKEN -u GITHUB_TOKEN xcodebuild …` in `run_check`, and `persist-credentials: false` on the
checkout in `live-check.yml` (the job reaches `gh` only through the step's `GH_TOKEN`).

### IN-06: A missing input after an `ok` page is reported as "that page failed"

**Severity:** Low
**File:** `AppPackage/Tests/LiveCheckTests/LiveCheckRunner.swift:30-34` (callers `:94`, `:112-115`)
**Issue:** `classify` maps `.blocked(after:)` to `unreachable` after a block and to `parser` + `.earlierPage` for
everything else, including `.okay`. `.blocked(after: .okay)` happens when Toplists parsed but its first row carries no
gallery URL (`:91-93`), or when the gallery URL is valid but `reportFormURL(galleryURL:)` returns `nil`
(`:279-288`). The reporter then opens a `Live check: Gallery parser` or `Report form parser` issue whose fixed
sentence says the value was missing "because that page failed" (`report_issues.py:59`), which is false and sends the
reader to the wrong page.
**Fix:** treat a nil input after an `ok` page as that page's own unmet expectation (`.unmet(.toplistsRows)` for the
row without a link, `.unmet(.reportFormFields)` for the form URL), and keep `.earlierPage` for earlier `parser`
results only; add an offline test for each.

### IN-07: Four back-to-back retries per list page, no pause

**Severity:** Low
**File:** `AppPackage/Tests/LiveCheckTests/LiveCheckRunner.swift:199-209`
**Issue:** `get(_:in:)` repeats a failed GET up to four times immediately. The check exists to be a polite, rare
guest (5 s between pages, one run a day), and a transport failure from a blocked runner IP is the case where
hammering costs most. The request types the check reuses retry in the app's own pattern, but the app's retries are
user-driven; a daily job should not look like a burst.
**Fix:** sleep 1-2 s between attempts (`try? await Task.sleep(for: .seconds(attempt))`), or reduce to two attempts.

### IN-08: `validate-preview.py` fails open when the response leaves out the checked fields

**Severity:** Low
**File:** `Scripts/visual/validate-preview.py:87-97`
**Issue:** The docstring (`:11-16`) and `preview-review.md` say a render in another locale or variant than requested,
and a render with live content, are rejected. The code rejects only when the response *has* the field: a response
with no `locale`/`variant` passes (`rendered is not None`, `:89`), and a response with no `review` object skips the
live-content check entirely (`:91-97`). The accepted record then says `countsAsSnapshotAcceptance: false`, but the
evidence it keeps can be unverified on exactly the two properties the tool exists to check.
**Fix:** require `review` (an object with a boolean `liveContent`) unconditionally, and when `locale`/`variant` was
requested but the response omits it, reject, or record `"verified": false` in the metadata.

### IN-09: Shard time margin is thin against the spread the cost table itself records

**Severity:** Low
**File:** `Scripts/visual/snapshot-shards.json` (every iPhone shard, `estimatedMinutes` 73.2), `Scripts/visual/snapshot-cost.json:5-8`, `Scripts/visual/run-shard.sh:103-104`
**Issue:** The plan uses the median iPhone figure (5.66 s a picture). The same note records runs from 4.0 to 8.6 s a
picture. A shard budget is `(120 - 5) x 60` s with `FIRST_PASS = 3/4` of it, i.e. 86 min for the first pass, against
an estimate of 73.2 min (boot, fetch and invocation cost included): at the slow end of the recorded spread
(538 pictures x 8.6 s / 0.82 speed-up, plus boot) the first pass runs out, and the in-job re-run and the one gate
retry both draw on the same 120-minute limit. This is a margin observation for the pre-release hosted pass, not a
re-raise of the deferred pass itself.
**Fix:** none needed now; when the pre-release pass runs, read `shard.json` timings per shard and, if any iPhone
shard ends `timeout`, either raise the share headroom (`TARGET_SHARE`) or split to more shards.

### IN-10: Deploy and dependency jobs have no `timeout-minutes`

**Severity:** Low
**File:** `.github/workflows/deploy.yml:37`, `.github/workflows/deploy-beta.yml:40`, `.github/workflows/dependencies.yml:12`
**Issue:** All of `snapshot-gate.yml`, `snapshot-measure.yml`, `live-check.yml` and `runner-probe.yml` set job
timeouts; these three jobs, which 19-10 edited, do not, so a hung `xcodebuild -downloadPlatform` or archive holds a
`xcode-27` runner for the 6-hour default, in a repository where five macOS slots are shared with a multi-hour gate.
**Fix:** `timeout-minutes: 120` on each (the existing steps finish in well under that).

### IN-11: Fault-injection hooks remain although the header says they never reach the phase branch

**Severity:** Info
**File:** `Scripts/visual/run-shard.sh:38-41,88-93,202-207,274`; `Scripts/visual/snapshot_shard.py:146-156`
**Issue:** The header says the `EHPANDA_SNAPSHOT_FAULT` hooks are "for the hosted proof only (19-10 Task 4, never on
the phase branch or main)", and they are on the phase branch. They are environment-gated and documented in the
README, so this is a comment/behaviour mismatch, not a hazard.
**Fix:** reword the header ("kept for re-running the proof") or remove the hooks after the proof.

### IN-12: Shard and retry jobs duplicate roughly 60 lines

**Severity:** Info
**File:** `.github/workflows/snapshot-gate.yml:182-252` and `:306-376`
**Issue:** install platform, download and unpack products, run, record runner, pack and upload are copied between
`shard`, `retry` (and the first half again in `native-policy`). They have already drifted once in the step comments.
**Fix:** a composite action or a `Scripts/visual/pack-results.sh` for the pack step at least.

### IN-13: Comment miscounts the levels to the repository root

**Severity:** Info
**File:** `AppPackage/Tests/VisualSnapshotTests/Matrix/SnapshotMatrixCase.swift:422-428`
**Issue:** "four levels above this file" precedes five `deletingLastPathComponent()` calls (the first removes the
file name). The code is right (it reaches the repository root); the comment is off by one.
**Fix:** "five `deletingLastPathComponent()` calls: the file, then four directories".

### IN-14: Custom-action fallback reads a `BOOL` as an object pointer

**Severity:** Info
**File:** `AppPackage/Sources/VisualSnapshotSupport/AccessibilityActionDriver.swift:28-29`
**Issue:** `target.perform(action.selector, with: action) != nil` interprets the selector's return register as an
`Unmanaged` object. For a `BOOL` handler `YES`/`NO` reads as non-nil/nil, which works, but a `void` handler or one
returning an object gives an arbitrary answer. The scenarios only hit the `actionHandler` branch today.
**Fix:** drop the selector branch (throw `refused` when there is no `actionHandler`), or document the BOOL-only
assumption at the call.

### IN-15: Nothing checks the baseline for fingerprints no scenario captures

**Severity:** Info
**File:** `Scripts/visual/snapshot_fetch.py:76-98`, `Scripts/visual/snapshot_aggregate.py:89-155`
**Issue:** The fetch compares a slice's files with `fingerprints.json`; the aggregate compares result lines with the
expected coordinates. A fingerprinted picture whose scenario was later removed or marked not applicable is in
neither comparison, so an orphan baseline picture stays in the snapshot repository and the pinned set forever.
**Fix:** in `snapshot_fetch.verify` (or `--check` of the approval step), report fingerprint keys that are not
expected coordinates of the inventory.

### IN-16: Laboratory is pinned to a large title; sibling pushed Setting pages still rely on `automatic`

**Severity:** Info
**File:** `AppPackage/Sources/SettingFeature/Components/LaboratorySettingView.swift:30-33`
**Issue:** The fix is sound: Laboratory is a one-cell `ScrollView`, so a large title has nothing to collapse into and
the mode no longer depends on the root's `inlineLarge` having settled (`SettingView.swift:45`). The commit message's
cause (a launch route that pushes in the same turn as the tab switch) is not specific to Laboratory, though; the
other pages pushed from the Setting root declare no mode either (`grep toolbarTitleDisplayMode` finds only this page,
`SettingView.swift:45` and `AppActivityLogsView.swift:166`), so any of them captured through the same launch route
can flip the same way. No test pins the Laboratory title mode.
**Fix:** none required now. If a capture launch route reaches other Setting pages, give each page the mode its
design wants, and add an entry for Laboratory to the native title policy checks so the mode cannot be dropped.

---

_Reviewed: 2026-11-11_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
