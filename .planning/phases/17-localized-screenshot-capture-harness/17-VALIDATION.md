---
phase: "17"
slug: localized-screenshot-capture-harness
status: validated
nyquist_compliant: false
wave_0_complete: true
created: "2026-10-02"
signed_off: "2026-11-04"
signed_off_source: "b5eca09d1"
validated: "2026-11-05"
validated_head: "48c3bda08"
validation_effort: "low (resolved from .planning/config.json)"
validation_result: "partial: kept scope automated except the WR-01 rebuild wiring, which is escalated to manual-only (Phase 18 Step 4b)"
---

# Phase17 validation strategy

> **Reduced scope, 2026-11-03 (owner msg 1305); signed off on 2026-11-04 at `b5eca09d1`** (17-23's gate
> at `52df81fa3`, repeated at `b5eca09d1` after the code review). Only
> the plans Phase 17 kept were executed. The map below is the original plan; rows for moved plans are
> moved to Phase 18 and are not evidence. See "Reduced-scope sign-off" at the end and
> 17-FINAL-VALIDATION.md. `/gsd-validate-phase 17` ran on 2026-11-05 at `48c3bda08` (see "Nyquist audit" at the
> end): `status: validated`, `nyquist_compliant: false` (PARTIAL), because the WR-01 rebuild wiring has no
> committed automated test.

Exact producer/task map below is planned, not executed. Set implementation compliance flags only after runtime evidence. Every plan task has an automated command and immediately adjacent observable fails_when; checkpoints additionally require explicit human evidence.

## Infrastructure and commands

- Wave0 producer17-01-T1 (execution wave1): VisualSnapshotTests target in AppPackage and existing FeatureTests.xctestplan; real active UIWindow tracer, exact SnapshotTesting1.19.6 clean integration.17-01-T2: FullContentFeasibilityTests.testExportPublicFixtures deterministically materializes all committed PublicVisualFixtures/scenario inputs into any fresh run directory with manifest, asset checksums and generator-source hashes; .capture/regression is disposable.
- Wave0 producer17-24-T1 (execution wave2): environment.py measure/validate and real GeometryTests;17-24-T2 authors tracked regression-environment.json only after those verified measurements, then validates it against fresh destinations.17-02-T1 (wave3) owns matrix runner/contracts and consumes that verified pin;17-02-T2 executes the complete576-coordinate hosted tracer and edge contracts. No matrix consumer precedes pin/geometry production.
- Native producers17-05-T1 (wave6) and17-11-T1 (wave9, before expansion17-08–17-10): MarketingCaptureUITests.testCaptureCoordinate and NativeVisualMatrixUITests.testCaptureScenario in existing EhPandaUITests target/UITests plan.
- Strict comparison/report producers17-12-T1/T2: NativeFrameComparisonTests, never-record and promotion policy, report.py and review ledger.
- Quick command after17-02: `python3 -m unittest discover -s scripts/visual -p 'test_*.py'`. Nonzero or zero tests fails. Target under30seconds, measure actual latency; never claim native/full matrix runs fit that budget.
- Complete regression after17-12: `python3 scripts/visual/run-regression.py --all --mode compare --fixtures .capture/regression --environment scripts/visual/regression-environment.json --output .capture/final-regression`. Nonzero, incomplete expected counts, failed/unknown/missing outcome or reference mutation fails.
- Candidate generation: same command with `--mode candidate` and a separate output directory; no reference writes. Initial17-13 and post-layout17-20 require complete review/owner approval.
- Website full export: `python3 scripts/visual/export-marketing.py --all --fixtures .capture/marketing/current --environment scripts/visual/regression-environment.json --output .capture/export-final`; expected384 rows with all outcome/metadata fields; final requires all passed and independent cold-rerun equality.
- Existing behavior: `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID"`.
- Existing native: `python3 Scripts/visual/run-single-pass.py --device "$PHONE_UDID"`.
- Existing build: `xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda -destination 'generic/platform=iOS Simulator'`.
- Resolve current UDIDs; run phone then tablet sequentially. No concurrent xcodebuild tests, automatic retries, zero-test successes or Repetition nodes. Keep full logs/result bundles and actual exit status.
- Strict lint: resolve exactly one current installed binary under `$HOME/Library/Developer/Xcode/DerivedData/EhPanda-*/SourcePackages/artifacts/swiftlintplugins/*/macos/swiftlint`, then run `lint --strict --no-cache --config .swiftlint.yml AppPackage/Sources App ShareExtension EhPandaUITests AppPackage/Tests`. Ambiguous/missing binary or nonzero exit fails; never pipe away failure.
- Release gate17-14-T2/T3/17-23: build Release and validate actual app/link map/build graph using verify-release.py; launch Release with capture flags and prove inactivity.

### Single-pass UITests validation

`Scripts/visual/run-single-pass.py` builds `UITests` for a generic simulator, then uses
`Gate.single_pass_run` to remove every `TestRepetitionPolicy` from a run-local xctestrun copy.
The source test plan retains its general regression retry policy. Xcode 27.1 RC documents
`-retry-tests-on-failure` as a flag with no value; none of these validation commands uses it.

The entry point enumerates the compiled selection with Xcode before execution. It requires a
nonempty, unique selection from one configuration, rejects disabled requested tests and selectors with no
matches, and records the actual expected test identities and count. `Gate.run` then requires that
count to pass without failures, skips or Repetition nodes; the entry point also checks that each
result is exactly one of the enumerated methods. A suite that has not been implemented fails
instead of passing with zero tests. Required fixture and capture-context setup still belongs to
each producer task; this entry point does not replace the native capture runner's scene setup.

Commands below use this entry point for Existing native, 17-05-T1, 17-11-T1/T2 and
17-08/17-09/17-10-T1/T2. Their selectors and phone/tablet sequence are unchanged. Test discovery
and execution wait for other exact `xcodebuild`/`xctest` processes to finish and never signal them.
The generic build does not need that test window.

`--output` must name a new evidence directory; omission creates one under
`.capture/single-pass/<timestamp>`. `--derived-data` defaults inside that directory and can name a
dedicated reusable build directory when invocations are serial. Build, enumeration and execution
retain their commands, logs, exit codes and result bundles. Run-local copies leave the original
xctestrun and `UITests.xctestplan` unchanged. Original content size and boot ownership are restored.

Run `python3 -B -m unittest discover -s Scripts/visual -p test_single_pass.py` for the entry-point
contracts, including zero/missing/duplicate/unrequested tests and native repetition rejection.

Entry-point verification on 2026-10-15 passed 196 Python tests and one selected
`VisualCaptureOrientationUITests/testRotateToPortrait` on each dedicated iPhone/iPad, serially.
Both compiled selections and result trees contain exactly that one passing method, with no skips
or Repetition nodes. Generic builds reported zero warnings/errors; original content size and
Shutdown ownership were restored. Evidence is under
`$HOME/Library/Caches/Appshot/handoff/phase17-single-pass-phone-3` and
`$HOME/Library/Caches/Appshot/handoff/phase17-single-pass-tablet`; the earlier interrupted run and
the enumeration-parser failure are retained. This validates the entry point; the producer/task
map below still requires its own complete scene, fixture and artifact evidence.

## Per-task verification map

Every command below is runnable only after its own producer task creates the suite/script. Existing tests and source paths were grounded in tracked repository files. New CLI symbols/flags and generated outputs are listed in each plan.

| Task | Wave | Requirement IDs | Exact automated command | Producer / evidence |
|---|---:|---|---|---|
| 17-01-T1 | 1 | CAP-17-02, CAP-17-03, CAP-17-06 | `xcodebuild clean build-for-testing -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID"`; then `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:VisualSnapshotTests/VisualTracerTests/testHomeFullContentTracer` | Existing project; all task acceptance and artifact evidence required |
| 17-01-T2 | 1 | CAP-17-02, CAP-17-03, CAP-17-06 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:VisualSnapshotTests/FullContentFeasibilityTests`; then `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:VisualSnapshotTests/FullContentFeasibilityTests/testExportPublicFixtures` | Existing project; all task acceptance and artifact evidence required |
| 17-24-T1 | 2 | CAP-17-02, CAP-17-03 | `python3 -m unittest discover -s scripts/visual -p test_environment.py`; then `python3 scripts/visual/environment.py measure --output .capture/environment-measurement` | 17-01; real geometry producer, no tracked pin prerequisite |
| 17-24-T2 | 2 | CAP-17-02, CAP-17-03 | `python3 scripts/visual/environment.py validate --environment scripts/visual/regression-environment.json --output .capture/environment-pin-check`; then `python3 -m unittest discover -s scripts/visual -p test_environment.py` | 17-01; verified17-24-T1 measurements, current-tree pin validation |
| 17-02-T1 | 3 | CAP-17-02, CAP-17-03 | `python3 -m unittest discover -s scripts/visual -p test_contracts.py` | 17-24; all task acceptance and artifact evidence required |
| 17-02-T2 | 3 | CAP-17-02, CAP-17-03 | `python3 -m unittest discover -s scripts/visual -p test_contracts.py`; then `python3 scripts/visual/run-regression.py --all --mode candidate --fixtures .capture/regression --environment scripts/visual/regression-environment.json --output .capture/tracer-matrix` | 17-24; complete576-coordinate actual hosted tracer |
| 17-03-T1 | 4 | CAP-17-01, CAP-17-04 | `python3 -m unittest discover -s scripts/visual -p test_fixtures.py` | 17-02; all task acceptance and artifact evidence required |
| 17-03-T2 | 4 | CAP-17-01, CAP-17-04 | `python3 -m unittest discover -s scripts/visual -p test_selection_review.py` | 17-02; all task acceptance and artifact evidence required |
| 17-04-T1 | 5 | CAP-17-01, CAP-17-04, CAP-17-07 | `xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda -destination 'generic/platform=iOS Simulator'` | 17-03; all task acceptance and artifact evidence required |
| 17-04-T2 | 5 | CAP-17-01, CAP-17-04, CAP-17-07 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:AppFeatureTests/CaptureSceneTests -only-testing:AppFeatureTests/CaptureFixtureTests` | 17-03; all task acceptance and artifact evidence required |
| 17-05-T1 | 6 | CAP-17-02, CAP-17-04, CAP-17-06 | `python3 Scripts/visual/run-single-pass.py --device "$PHONE_UDID" --only-testing EhPandaUITests/MarketingCaptureUITests/testCaptureCoordinate` | 17-04; all task acceptance and artifact evidence required |
| 17-05-T2 | 6 | CAP-17-02, CAP-17-04, CAP-17-06 | `python3 -m unittest discover -s scripts/visual -p test_capture_native.py` | 17-04; all task acceptance and artifact evidence required |
| 17-06-T1 | 7 | CAP-17-01, CAP-17-04, CAP-17-07 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:ReadingFeatureTests/CaptureLiveTextTests` | 17-05; all task acceptance and artifact evidence required |
| 17-06-T2 | 7 | CAP-17-01, CAP-17-04, CAP-17-07 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:AppFeatureTests/CaptureDownloadTests` | 17-05; all task acceptance and artifact evidence required |
| 17-07-T1 | 8 | CAP-17-04 | `python3 -m unittest discover -s scripts/visual -p test_marketing.py` | 17-06; all task acceptance and artifact evidence required |
| 17-07-T2 | 8 | CAP-17-04 | `python3 -m unittest discover -s scripts/visual -p test_handoff.py` | 17-06; all task acceptance and artifact evidence required |
| 17-11-T1 | 9 | CAP-17-01, CAP-17-02, CAP-17-06 | `python3 Scripts/visual/run-single-pass.py --device "$PHONE_UDID" --only-testing EhPandaUITests/NativeVisualMatrixUITests/testCaptureScenario` | 17-02, 17-06, 17-07; all task acceptance and artifact evidence required |
| 17-11-T2 | 9 | CAP-17-01, CAP-17-02, CAP-17-06 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:AppFeatureTests/VisualScenarioCoverageTests`; then `python3 Scripts/visual/run-single-pass.py --device "$PHONE_UDID" --only-testing EhPandaUITests/NativeVisualMatrixUITests/testCaptureScenario` | 17-02, 17-06, 17-07; all task acceptance and artifact evidence required |
| 17-08-T1 | 10 | CAP-17-02, CAP-17-06 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:VisualSnapshotTests/BrowseScenarioTests`; then `python3 Scripts/visual/run-single-pass.py --device "$PHONE_UDID" --only-testing EhPandaUITests/BrowseVisualUITests` | 17-11; all task acceptance and artifact evidence required |
| 17-08-T2 | 10 | CAP-17-02, CAP-17-06 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:VisualSnapshotTests/DetailScenarioTests`; then `python3 Scripts/visual/run-single-pass.py --device "$PHONE_UDID" --only-testing EhPandaUITests/DetailVisualUITests` | 17-11; all task acceptance and artifact evidence required |
| 17-09-T1 | 11 | CAP-17-02, CAP-17-06 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:VisualSnapshotTests/ReaderScenarioTests`; then `python3 Scripts/visual/run-single-pass.py --device "$PHONE_UDID" --only-testing EhPandaUITests/ReaderVisualUITests` | 17-08; all task acceptance and artifact evidence required |
| 17-09-T2 | 11 | CAP-17-02, CAP-17-06 | `python3 Scripts/visual/run-single-pass.py --device "$PHONE_UDID" --only-testing EhPandaUITests/NativeVisualPolicyUITests` | 17-08; all task acceptance and artifact evidence required |
| 17-10-T1 | 12 | CAP-17-02, CAP-17-06 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:VisualSnapshotTests/SettingsScenarioTests`; then `python3 Scripts/visual/run-single-pass.py --device "$PHONE_UDID" --only-testing EhPandaUITests/SettingsVisualUITests` | 17-09; all task acceptance and artifact evidence required |
| 17-10-T2 | 12 | CAP-17-02, CAP-17-06 | `python3 -m unittest discover -s scripts/visual -p test_contracts.py`; then `python3 Scripts/visual/run-single-pass.py --device "$PHONE_UDID" --only-testing EhPandaUITests/UtilityVisualUITests` | 17-09; all task acceptance and artifact evidence required |
| 17-12-T1 | 13 | CAP-17-02, CAP-17-03 | `python3 -m unittest discover -s scripts/visual -p test_baselines.py` | 17-10; all task acceptance and artifact evidence required |
| 17-12-T2 | 13 | CAP-17-02, CAP-17-03 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:VisualSnapshotTests/RegressionDetectionTests` | 17-10; all task acceptance and artifact evidence required |
| 17-13-T1 | 14 | CAP-17-02, CAP-17-03, CAP-17-06 | `python3 scripts/visual/run-regression.py --all --mode candidate --fixtures .capture/regression --environment scripts/visual/regression-environment.json --output .capture/baseline-initial` | 17-12; all task acceptance and artifact evidence required |
| 17-13-T2 | 14 | CAP-17-02, CAP-17-03, CAP-17-06 | `python3 scripts/visual/baselines.py validate-review --run .capture/baseline-initial` | 17-12; explicit owner/designer evidence required |
| 17-13-T3 | 14 | CAP-17-02, CAP-17-03, CAP-17-06 | `python3 scripts/visual/baselines.py promote --run .capture/baseline-initial` | 17-12; all task acceptance and artifact evidence required |
| 17-14-T1 | 15 | CAP-17-03, CAP-17-07 | `python3 -m unittest discover -s scripts/visual -p test_ci.py` | 17-13; current-tree real exporter/bootstrap plus orchestration tests, no HEAD acceptance |
| 17-14-T2 | 15 | CAP-17-03, CAP-17-07 | `python3 -m unittest discover -s scripts/visual -p test_release.py` | 17-13; all task acceptance and artifact evidence required |
| 17-14-T3 | 15 | CAP-17-03, CAP-17-07 | `python3 scripts/visual/ci.py --all --verify-clean-checkout --output .capture/ci-clean-checkout` | 17-13; verified and committed17-14-T1/T2 source; real full archived-HEAD and Release acceptance |
| 17-15-T1 | 16 | CAP-17-06 | `python3 -m unittest discover -s scripts/visual -p test_environment.py` | 17-14; all task acceptance and artifact evidence required |
| 17-15-T2 | 16 | CAP-17-06 | `python3 -m unittest discover -s scripts/visual -p test_preview.py` | 17-14; all task acceptance and artifact evidence required |
| 17-16-T1 | 17 | CAP-17-06, CAP-17-07 | `xcodebuild build -project EhPanda.xcodeproj -scheme EhPanda -destination 'generic/platform=iOS Simulator'` | 17-15; all task acceptance and artifact evidence required |
| 17-16-T2 | 17 | CAP-17-06, CAP-17-07 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:VisualSnapshotTests/LayoutTraitTests` | 17-15; all task acceptance and artifact evidence required |
| 17-17-T1 | 18 | CAP-17-06, CAP-17-07 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:HomeFeatureTests/HomeLayoutNavigationTests` | 17-16; all task acceptance and artifact evidence required |
| 17-17-T2 | 18 | CAP-17-06, CAP-17-07 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:FavoritesFeatureTests/FavoritesLayoutNavigationTests` | 17-16; all task acceptance and artifact evidence required |
| 17-18-T1 | 19 | CAP-17-06, CAP-17-07 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:SearchFeatureTests/SearchLayoutNavigationTests` | 17-17; all task acceptance and artifact evidence required |
| 17-18-T2 | 19 | CAP-17-06, CAP-17-07 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:DownloadsFeatureTests/DownloadsLayoutNavigationTests` | 17-17; all task acceptance and artifact evidence required |
| 17-18-T3 | 19 | CAP-17-06, CAP-17-07 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:DetailFeatureTests/GalleryNavigationTests` | 17-17; all task acceptance and artifact evidence required |
| 17-19-T1 | 20 | CAP-17-06, CAP-17-07 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:AppFeatureTests/TabBarSettingPresentationTests` | 17-18; all task acceptance and artifact evidence required |
| 17-19-T2 | 20 | CAP-17-06, CAP-17-07 | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination "platform=iOS Simulator,id=$PHONE_UDID" -only-testing:VisualSnapshotTests/LayoutTraitTests` | 17-18; all task acceptance and artifact evidence required |
| 17-20-T1 | 21 | CAP-17-03, CAP-17-06, CAP-17-07 | `python3 scripts/visual/run-regression.py --all --mode candidate --fixtures .capture/regression --environment scripts/visual/regression-environment.json --output .capture/baseline-layout` | 17-19; all task acceptance and artifact evidence required |
| 17-20-T2 | 21 | CAP-17-03, CAP-17-06, CAP-17-07 | `python3 scripts/visual/baselines.py validate-review --run .capture/baseline-layout` | 17-19; explicit owner/designer evidence required |
| 17-20-T3 | 21 | CAP-17-03, CAP-17-06, CAP-17-07 | `python3 scripts/visual/baselines.py promote --run .capture/baseline-layout` | 17-19; all task acceptance and artifact evidence required |
| 17-21-T1 | 22 | CAP-17-01, CAP-17-04 | `python3 scripts/visual/selection-review.py --fixtures .capture/marketing/current --output .capture/final-content-review` | 17-07, 17-20; explicit owner/designer evidence required |
| 17-21-T2 | 22 | CAP-17-01, CAP-17-04 | `python3 scripts/visual/export-marketing.py --all --fixtures .capture/marketing/current --environment scripts/visual/regression-environment.json --output .capture/export-final` | 17-07, 17-20; all task acceptance and artifact evidence required |
| 17-22-T1 | 23 | CAP-17-04, CAP-17-05 | `python3 -m unittest discover -s scripts/visual -p test_designer_handoff.py` | 17-21; all task acceptance and artifact evidence required |
| 17-22-T2 | 23 | CAP-17-04, CAP-17-05 | `python3 scripts/visual/designer-handoff.py validate --root .capture/altstore` | 17-21; explicit owner/designer evidence required |
| 17-22-T3 | 23 | CAP-17-04, CAP-17-05 | `python3 scripts/visual/validate-handoff.py --kind altstore --root .capture/altstore` | 17-21; all task acceptance and artifact evidence required |
| 17-23-T1 | 24 | CAP-17-01, CAP-17-02, CAP-17-03, CAP-17-04, CAP-17-05, CAP-17-06, CAP-17-07 | `python3 scripts/visual/run-regression.py --all --mode compare --fixtures .capture/regression --environment scripts/visual/regression-environment.json --output .capture/final-regression` | 17-22; all task acceptance and artifact evidence required |
| 17-23-T2 | 24 | CAP-17-01, CAP-17-02, CAP-17-03, CAP-17-04, CAP-17-05, CAP-17-06, CAP-17-07 | `python3 scripts/visual/validate-handoff.py --kind website --root .capture/export-final` | 17-22; all task acceptance and artifact evidence required |

## Revision acceptance contracts

- Environment input contract: every regression and marketing --environment argument names scripts/visual/regression-environment.json, authored and validated in17-24.17-02 and17-05 call its real validator before capture;17-07 forwards the same pin unchanged. Measurements and fresh destination IDs remain separate run outputs linked by pin SHA-256. Marketing retains per-coordinate environment-check/environment.json and measurement attachments; missing/malformed pins, observation inputs and drift fail before capture without pin mutation.17-05 test_capture_native.py and17-07 test_marketing.py own positive/negative boundary checks. Marketing chrome/configuration remains separate from regression. No pre-existing local observation file is required.
- Execution order:17-01,17-24,17-02–17-07,17-11,17-08–17-10,17-12–17-23. Twenty-four plans/waves and53 tasks. Native dispatch remains before expansion.17-14 has three tasks: current-tree CI bootstrap, current-tree Release producer, then real clean-checkout acceptance after both verified commits.
-17-04 defines public/marketing purpose, scenarioID and fixtureID fields.17-11 wires public native factories and launcher using existing fixtures and inline smoke descriptors; both feature route checks and real native smoke capture must pass.17-08–17-10 extend the corresponding factory concurrently with each scenario and run their UI suites on both families before completion.17-10 reruns final route completeness;17-12 adds strict comparisons after captures already exist.
- Fresh-checkout CI gate17-14-T3 (wave15), after verified producer commits17-14-T1 and17-14-T2: `python3 scripts/visual/ci.py --all --verify-clean-checkout --output .capture/ci-clean-checkout`. From tracked HEAD only, materialize all public fixtures using the committed Swift exporter and scenarios, compare repeated export hashes, validate tracked pin against live destinations, and run the real complete hosted/native matrix plus actual Release isolation. No copied local .capture or marketing acquisition. Retain bootstrap.json with source/scenario/generator/fixture/pin/baseline digests and offline request evidence. Pin mismatch and missing fixture are nonzero preflight failures; incomplete outputs never pass. This execution check is intentionally longer than quick unit tests.

## Complete evidence gates

- Full-content: actual Home, Comments, Downloads and vertical reader at large/AX5, phone/tablet, both orientations; finite content exceeds viewport, complete item census/trailing marker, bounded convergence and unchanged logical viewport semantics.
- Complete regression: all42 groups expanded by meaningful state,576 coordinates per scenario plus distinct viewport/fullContent/nativePresentation kinds. Missing/failing methods are failures, never semantic not-applicable.
- Marketing: eight named states × six locales × two themes × two families × two declared sets=384; normal portrait, fixed documented size, measured native geometry,9:41/capsule proof, state readiness, final selected content and byte-identical cold reruns.
- Baselines: missing reference never writes; controlled mutation red/restoration green; complete agent image review; owner approves exact hashes before promotion; repeated after layout audit.
- Native behavior: standard/AX1/AX3/AX5 cold/live title/search checks on both families with focus/query/orientation, native overflow/Picker/Toggle/anchors and every independently presented soft-edge root.
- Release: dependency graph, link map, bundle assets and inactive capture flags prove isolation; no warning/lint suppression.
- Designer: actual deliberate promotional files, final source provenance, designer decisions and owner acceptance; intended AltStore references validate locally.
- Xcode previews: schema-discovered values, sequential locale calls, returned destination verification; never count as marketing/regression outputs.

## Sign-off and unresolved assumptions

Planning-time text (2026-10-02): owner checkpoints 17-13-T2, 17-20-T2, 17-21-T1 and designer/owner
17-22-T2 remain unexecuted. Those plans moved to Phase 18 and are still unexecuted. The final state is
in the next section.

## Reduced-scope sign-off (17-23, 2026-11-04)

Signed off at `52df81fa3` only where evidence exists, then repeated at the closing source `b5eca09d1`
(see "Repeated after the code review"). Evidence and counts:
[17-FINAL-VALIDATION.md](17-FINAL-VALIDATION.md), section 1.

| Kept plan or gate | Validation evidence | Status |
|---|---|---|
| 17-01, 17-24, 17-02 | Clean SnapshotTesting integration, actual-window tracer, measured pin and 576-coordinate hosted tracer (their summaries) | Executed earlier; not re-run by 17-23 |
| 17-03, 17-04, 17-05, 17-06 | Fixture acquisition, isolated capture scenes, native screens, Live Text and Downloads (their summaries); the 192 approved website images | Executed earlier; capture suites pass in the final FeatureTests and UITests runs |
| 17-16 to 17-19 | Size-class layout and routing tests, simulator checks, owner's keep decision for all five idiom reads (17-LAYOUT-AUDIT.md) | Executed; their tests pass in the final runs |
| 17-14 T2 | Release scan, Debug negative control, scanner tests (17-RELEASE-ISOLATION.md, at `50c794b53`) | Executed; repeated at `52df81fa3` by 17-23 |
| Existing behavior | FeatureTests and UITests, phone then tablet, one invocation at a time, 0 failures and 0 Repetition nodes | Passed at `52df81fa3`: all four runs exit 0, 0 failures, 0 Repetition (FV section 1) |
| Strict lint | SwiftLint 0.65.1, `--strict --no-cache`, the five paths: 0 violations in 759 files | Passed |
| Release gate | `verify-release.py` on a Release build of `52df81fa3`; `test_release.py` 19 OK | Passed (0 findings; Debug control 991) |
| Reader page sync | ReaderPageSyncUITests ×20 on the iPhone Air (`33dbf648b`), ×5 on the iPad (`52df81fa3`) | Passed: 160 of 160 and 40 of 40, 0 retries. At the closing source `b5eca09d1` both devices ran ×5 (see below) |

**Moved, not validated here.** Complete regression (17-12), candidate and baseline generation (17-13,
17-20), the 384 website export (17-07, 17-21), the designer handoff (17-22), native visual-policy and
preview checks (17-09 T2, 17-15), public dispatch (17-11), scenario expansion (17-08 to 17-10), and
17-14 T1/T3. Their commands above stay unexecuted and move to Phase 18 (VIS-18-01, MKT-18-01,
DIST-18-02).

**Repeated after the code review.** The review fixes `fb1ea4b18` and `443e74541` changed the built
source, so every check above except the Debug negative-control scan ran again at `b5eca09d1` and
passed, with ReaderPageSyncUITests ×5 on each device: phone 40 of 40 passed, 0 retries; iPad 40 of 40
passed, 0 retries. The last Debug negative-control scan (991 findings) is at `52df81fa3`; none ran at
`b5eca09d1`. See 17-FINAL-VALIDATION.md section 9.

**Known limits.**

- **Reduced page-sync coverage on both devices.** At the closing source `b5eca09d1`,
  ReaderPageSyncUITests ran 5 iterations on **both** the phone and the iPad (40 of 40 each). The ×20
  phone run is at `33dbf648b`, before the WR-01/IN-01 fixes. (At `52df81fa3` only the iPad was
  reduced, by the owner's choice on 2026-11-04.) Earlier iPad desyncs occurred about once in 20 runs
  or less, so 5 iterations cannot exclude that rate. The owner accepted ×5 on both devices as a known
  limit (owner msg 1640).
- ReaderPageSyncUITests covers the vertical strip and the left-to-right pager, not right-to-left.
- `ReaderPageProbe` can't read an iPad landscape two-page spread.
- The reader still keeps several copies of the current page; Phase 18 reworks it to one source of truth.

**Still open, flagged.** The CAP-17-07 unclassified edge is classified in 17-FINAL-VALIDATION.md
section 8; the verifier concurred and the owner accepted it (owner msg 1640). The three descriptor-less
prohibitions stay flagged-unverified per 17-SOURCE-AUDIT.md: the first with the owner-approved synthetic
comment (exception accepted, owner msg 1640), the other two moved to Phase 18. UAT
(`/gsd-verify-work 17`) and the remaining close steps are ahead.

## Nyquist audit (`/gsd-validate-phase 17`, 2026-11-05)

**Effort:** low (resolved from .planning/config.json). **HEAD:** `48c3bda08` (UAT complete). **Tested
source:** `b5eca09d1` (nothing outside `.planning/` changed since). **Input state:** A (this file existed).
**Method:** static audit only. No build, test run or simulator; no test code was written. Evidence is the
13 kept-plan summaries, 17-FINAL-VALIDATION.md (FV) sections 1, 6, 8 and 9, 17-VERIFICATION.md and
17-UAT.md (31/31). Moved plans (17-07 to 17-13, 17-14 T1/T3, 17-15, 17-20 to 17-22) are Phase 18 work and
are not counted as gaps here.

### Test infrastructure

| Property | Value |
|---|---|
| Framework | Swift Testing / XCTest (AppPackage targets in `AppPackage/Tests/FeatureTests.xctestplan`), XCUITest (`EhPandaUITests`, `UITests.xctestplan`), Python `unittest` (`Scripts/visual/test_*.py`) |
| Full suite | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,id=<UDID>'`, then the same with `-testPlan UITests`, phone then tablet, one invocation at a time |
| Quick | `python3 -B -m unittest discover -s Scripts/visual -p 'test_*.py'` |
| Not in the default plans | `VisualSnapshotTests/GeometryTests` (skipped in FeatureTests, opt-in measurement); `MarketingCaptureUITests`, `CaptureIsolationUITests`, `AppshotCaptureUITests` (skipped in UITests; run only through `Scripts/visual/capture-native.py`, `run-single-pass.py` or `verify-release.py`) |
| Final gate at `b5eca09d1` | FeatureTests 1541 cases, 0 failed (10 expected failures), both devices; UITests 88 cases, 0 failed (phone 20 skipped, tablet 17 skipped), 0 Repetition nodes; strict no-cache lint 0 violations in 759 files; Release scan 0 findings, `test_release.py` 19 OK; ReaderPageSyncUITests ×5 on each device, 40/40, 0 retries (owner-accepted, msg 1640) |

### Audited per-task map (kept scope)

The planned map above names some suites that were never created, because 17-16 to 17-19 verified a layout
migration that had already landed (CAP-17-07 amendment). This table records the tests that actually cover
each kept task. Status: ✅ green · ⚠️ green with caveat · 🖐 manual-only · ➡ moved.

| Task | Requirement (Phase 17 part) | Actual automated command / suite | File exists | Status |
|---|---|---|---|---|
| 17-01-T1/T2 | foundation (CAP-17-02/03 moved) | FeatureTests `VisualSnapshotTests` (`VisualTracerTests`, `FullContentFeasibilityTests` incl. `testExportPublicFixtures`, `HostedHierarchyTests`, `RenderServerCaptureTests`, `RenderSettlementTests`, `RenderedContentInspectionTests`) | ✅ | ✅ final gate |
| 17-24-T1/T2 | foundation (moved) | `python3 -B -m unittest discover -s Scripts/visual -p test_environment.py`; `GeometryTests` opt-in | ✅ | ⚠️ green at 17-24's gate, not re-run at `b5eca09d1` (scripts unchanged since 17-14); GeometryTests outside FeatureTests |
| 17-02-T1/T2 | foundation (moved) | `python3 -B -m unittest discover -s Scripts/visual -p test_contracts.py`; 576-coordinate tracer run | ✅ | ⚠️ green at 17-02's gate, not re-run at `b5eca09d1` |
| 17-03-T1/T2 | CAP-17-01 (fixture part) | `test_fixtures.py`, `test_selection_review.py` (`python3 -B -W error -m unittest discover -s Scripts/visual -p …`) | ✅ | ⚠️ green at 17-03's gate, not re-run at `b5eca09d1`; fixture validator re-run read-only by the verifier on all 11 versions |
| 17-04-T1/T2 | CAP-17-01, CAP-17-04 | build; FeatureTests `AppFeatureTests/CaptureSceneTests`, `CaptureFixtureTests`, `UITestStubTests`, `CaptureScreenDiagnosticsTests` | ✅ | ✅ final gate |
| 17-05-T1/T2 | CAP-17-04 (capture foundation) | `run-single-pass.py --only-testing EhPandaUITests/MarketingCaptureUITests/testCaptureCoordinate`; `test_capture_native.py` | ✅ | ⚠️ green at 17-05's gate and in the 2026-11-04 recapture; `MarketingCaptureUITests` is skipped in UITests.xctestplan, so the final UITests runs did not execute it (the sign-off table's "capture suites pass in the final … UITests runs" holds for FeatureTests only) |
| 17-06-T1/T2 | CAP-17-01, CAP-17-04 | FeatureTests `ReadingFeatureTests/CaptureLiveTextTests`, `AppFeatureTests/CaptureLiveTextRecordTests`, `CaptureDownloadTests`, `DownloadCoordinatorCaptureTests` | ✅ | ✅ final gate |
| 17-14-T2 | CAP-17-07 (Release isolation) | `python3 -B -m unittest discover -s Scripts/visual -p test_release.py`; `verify-release.py` on a Release build (+ launch probe) | ✅ | ✅ at `b5eca09d1` (19 OK, 0 findings); Debug negative control last at `52df81fa3` |
| 17-16-T1/T2 | CAP-17-06, CAP-17-07 | build; FeatureTests `HomeFeatureTests`, `SearchFeatureTests` (planned `LayoutTraitTests` does not exist; snapshot measurement ➡ VIS-18-01) | ✅ | ✅ final gate |
| 17-17-T1/T2 | CAP-17-06, CAP-17-07 | FeatureTests `AppFeatureTests/GalleryDetailRoutingTests`, `CaptureRouteTests` (planned `Home/FavoritesLayoutNavigationTests` do not exist) | ✅ | ✅ final gate |
| 17-18-T1–T3 | CAP-17-06, CAP-17-07 | FeatureTests `DownloadsFeatureTests/AppDownloadDetailRoutingTests`, `DownloadAutomationTests`, `DetailFeatureTests/GalleryNavigationTests` (planned `Search/DownloadsLayoutNavigationTests` do not exist) | ✅ | ✅ final gate (GalleryNavigationTests holds one case, per 17-18) |
| 17-19-T1/T2 | CAP-17-06, CAP-17-07 | FeatureTests `AppFeatureTests/TabBarSettingPresentationTests`; census grep; owner keep decisions | ✅ | ✅ tests; 🖐 census decisions |
| 17-23-T1/T2 | all kept parts | final gate above (planned `run-regression.py --mode compare` and website `validate-handoff.py` ➡ Phase 18) | ✅ | ✅ |
| WR-01 / IN-01 (code-review fixes) | CAP-17-06 (reader behavior) | FeatureTests `ReadingFeatureTests/PagerTurnGateTests` (16, incl. four `aPagerBuiltAnew…`), `PagerSeedTests` (3); UITests `ReaderPageSyncUITests` ×5 | ✅ gate logic only | ⚠️ gate logic green; **SwiftUI rebuild wiring has no committed test** (gap G1) |
| All other planned rows | moved | — | — | ➡ Phase 18 |

### Requirement → test map (kept scope)

| Requirement | Automated coverage | Manual-only remainder | Classification |
|---|---|---|---|
| CAP-17-01, fixture part | `test_fixtures.py`, `test_selection_review.py`, `CaptureSceneTests`, `CaptureFixtureTests`, `CaptureLiveTextRecordTests`, `CaptureDownloadTests` | owner approval of the website fixture versions | COVERED (Python part last sampled at its plan gate) |
| CAP-17-04, amended (192 approved images) | capture foundation: `MarketingCaptureUITests/testCaptureCoordinate` (driver-run), `test_capture_native.py`, FeatureTests capture suites | the image set itself is accepted by owner approval (msgs 1581, 1640) | COVERED for the producer; acceptance manual-only by nature |
| CAP-17-06, bounded part | FeatureTests and UITests (behavior suites), `PagerTurnGateTests`, `PagerSeedTests`, `ReaderPageSyncUITests` | standard/AX1/AX3/AX5 title/search/top-edge checks (quick 260921-f5u); WR-01 rebuild wiring (G1); RTL page sync and iPad two-page spread (G2) | PARTIAL |
| CAP-17-07, amended | `test_release.py`, `verify-release.py` scan + launch probe, routing/layout reducer tests | one simulator layout pass, census keep decisions (msg 1409), unclassified-edge classification (msg 1640) | COVERED for automated parts; owner decisions manual-only by nature |
| CAP-17-02, -03, -05 and moved parts of -01/-04/-06 | — | — | MOVED to Phase 18 (VIS-18-01, MKT-18-01, DIST-18-02); not gaps here |

### Gaps and disposition

The owner's instruction for this run: no new test code, no builds or simulators. Gaps that would need a new
test are therefore escalated to manual-only instead of being filled (auditor return: ESCALATE for G1 and G2,
0 debug iterations, no test written, no test failed).

| # | Gap | Type | Disposition |
|---|---|---|---|
| G1 | WR-01: the reader's rebuild wiring (`.onChange(of: store.forceRefreshID)` outside the `.id` identity, and the `readingDirection` observer calling `ReadingView.pagerRebuilt()`) | MISSING (no committed UI test; `PagerTurnGateTests` cover only `PagerTurnGate.pagerRebuilt()`) | **Escalated → manual-only.** UAT tests 1 to 3 passed through an agent-run, throwaway XCUITest at `b5eca09d1` on both simulators; that test was **not committed**, so it is not automated coverage in the repository. Phase 18 ROADMAP Step 4b plans the real UI tests (Reload all images then a turn, a direction change during Auto-Play, an LTR/RTL switch). |
| G2 | Page sync in right-to-left reading, and the iPad landscape two-page spread | MISSING (`ReaderPageSyncUITests` covers vertical and LTR only; `ReaderPageProbe` cannot read a spread) | **Escalated → manual-only.** RTL was exercised only by the same throwaway UAT test (test 3). The LTR/RTL switch test is in Phase 18 Step 4b; the two-page spread probe limit stays a known limit with no planned test. |
| G3 | Planned suites `LayoutTraitTests`, `HomeLayoutNavigationTests`, `FavoritesLayoutNavigationTests`, `SearchLayoutNavigationTests`, `DownloadsLayoutNavigationTests` do not exist | no_automated_command (planned name) | **Resolved by map update.** The kept behavior is covered by the existing suites in the audited map, green on both devices at `b5eca09d1`; the snapshot-measured part is moved to VIS-18-01. |
| G4 | Reduced page-sync stress (×5 instead of ×20 on both devices at `b5eca09d1`) | WARNING (test green; sample too small to exclude a ~1-in-20 desync) | Owner-accepted known limit (msg 1640). Not a test failure. |
| G5 | Python suites and `MarketingCaptureUITests` were last run at their own plan gates, not at the final source | WARNING (stale sample) | Recorded. `Scripts/visual/*.py` is unchanged since 17-14; the capture UI test is driver-run by design. |
| G6 | Owner and visual judgements: 192-image approval, census keep decisions, one simulator layout pass, AX title/search/top-edge checks, the "MUST NOT invent gallery content" exception, the CAP-17-07 unclassified edge | manual-only by nature | Manual-only; each has recorded owner evidence (msgs 1409, 1581, 1640; quick 260921-f5u). The other two descriptor-less prohibitions are moved to Phase 18. |

### Manual-only verifications

| Behavior | Requirement | Why manual | Test instructions / evidence |
|---|---|---|---|
| Reader page-turn gate restarts after Reload all images and after a vertical→LTR direction change (WR-01) | CAP-17-06 | No committed UI test; the UAT throwaway XCUITest was not committed; Phase 18 Step 4b adds the real tests | 17-UAT.md tests 1 and 2 (passed, agent-run, both devices) |
| LTR→RTL switch keeps turning, reversed order, indicator matches | CAP-17-06 | `ReaderPageSyncUITests` does not cover RTL | 17-UAT.md test 3 (passed, agent-run) |
| iPad landscape two-page spread page sync | CAP-17-06 | `ReaderPageProbe` cannot read a spread | Known limit, FV section 8; no planned test |
| The 192 website images are the approved set | CAP-17-04 | Owner acceptance | FV section 3; owner msgs 1581, 1640; 17-UAT.md test 8 |
| Idiom census keep decisions and the one simulator layout pass | CAP-17-07 | Owner decisions and a visual pass | 17-LAYOUT-AUDIT.md; owner msg 1409; 17-UAT.md test 6 |
| Standard/AX1/AX3/AX5 title, search and top-edge behavior | CAP-17-06 | Recorded visual checks; snapshot measurement moved to VIS-18-01 | quick 260921-f5u, 260921-f5u-VERIFICATION.md |
| Synthetic comment exception to "MUST NOT invent gallery content"; CAP-17-07 unclassified edge | CAP-17-04, CAP-17-07 | Descriptor-less, owner-classified | FV section 8; owner msg 1640 |

### Sign-off checklist

- [x] Every kept task has an automated command, or its remainder is listed as manual-only
- [x] Sampling continuity: no three consecutive kept tasks without automated verification
- [x] Wave 0 for the kept scope (17-01, 17-24) complete; moved producers belong to Phase 18
- [x] No watch-mode flags
- [ ] `nyquist_compliant: true`: **not set**. G1 (and G2) need committed UI tests, planned in Phase 18 Step 4b

**Verdict:** PARTIAL, not Nyquist-compliant. Kept scope is automated except the WR-01 rebuild wiring and
RTL page sync, which are escalated to manual-only with UAT evidence that is not a committed test.

## Validation Audit 2026-11-05

| Metric | Count |
|---|---|
| Gaps found | 6 |
| Resolved | 1 |
| Escalated | 2 |
