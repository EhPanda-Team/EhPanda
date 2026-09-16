---
phase: "16"
slug: "dynamic-type-accessibility"
status: validated
nyquist_compliant: true
wave_0_complete: true
created: "2026-08-23"
audited: "2026-09-17"
---

# Phase 16 — Validation Strategy

Pre-owner review prepared on immutable source b01add4c11b1f9c355ac8f2e055ed8b24fe8146c; owner 16-26 Task 3, verifier, and completion remain pending; no new source or test was added.


## Test Infrastructure

| Property | Value |
|---|---|
| Framework | Swift Testing; XCTest/XCUITest |
| Config | `AppPackage/Tests/FeatureTests.xctestplan`; `UITests.xctestplan` |
| Quick run | Existing lint/build gates; strict no-cache SwiftLint evidence in closing cache |
| Full suite | FeatureTests iPhone, UITests iPhone, UITests iPad in prescribed order |
| Toolchain | Xcode 26.6 via `DEVELOPER_DIR`; phase-local `xb2.sh`; independent xcodebuild concurrency authorized |
| Gate devices | iPhone `73E148DA-26E4-4892-8C8A-7EDC6725D0E7`; iPad `B6679864-3783-4A3B-89B5-B0B010588C13` |

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Type | Automated | Manual/checkpoint | Class | Status |
|---|---|---|---|---|---|---|---|---|
| 16-01-T1 | 16-01 | 1 | A11Y-01, A11Y-02 | auto | yes | yes | test | existing-artifact |
| 16-01-T2 | 16-01 | 1 | A11Y-01, A11Y-02 | auto | yes | yes | task | existing-artifact |
| 16-02-T1 | 16-02 | 1 | A11Y-01 | auto | yes | yes | docs | existing-artifact |
| 16-02-T2 | 16-02 | 1 | A11Y-01 | auto | yes | yes | docs | existing-artifact |
| 16-03-T1 | 16-03 | 2 | A11Y-01 | checkpoint:human-action | no | yes | task | existing-artifact |
| 16-03-T2 | 16-03 | 2 | A11Y-01 | auto | yes | yes | docs | existing-artifact |
| 16-04-T1 | 16-04 | 3 | A11Y-01 | auto | yes | no | task | existing-artifact |
| 16-04-T2 | 16-04 | 3 | A11Y-01 | auto | yes | yes | task | existing-artifact |
| 16-05-T1 | 16-05 | 4 | A11Y-01 | auto | yes | yes | task | existing-artifact |
| 16-05-T2 | 16-05 | 4 | A11Y-01 | auto | yes | yes | task | existing-artifact |
| 16-06-T1 | 16-06 | 5 | A11Y-01 | auto | yes | no | task | existing-artifact |
| 16-06-T2 | 16-06 | 5 | A11Y-01 | auto | yes | no | task | existing-artifact |
| 16-07-T1 | 16-07 | 6 | A11Y-01 | auto | yes | no | task | existing-artifact |
| 16-07-T2 | 16-07 | 6 | A11Y-01 | auto | yes | no | task | existing-artifact |
| 16-08-T1 | 16-08 | 7 | A11Y-01 | auto | yes | no | task | existing-artifact |
| 16-08-T2 | 16-08 | 7 | A11Y-01 | auto | yes | no | task | existing-artifact |
| 16-09-T1 | 16-09 | 8 | A11Y-01 | auto | yes | no | task | existing-artifact |
| 16-09-T2 | 16-09 | 8 | A11Y-01 | auto | yes | no | task | existing-artifact |
| 16-10-T1 | 16-10 | 9 | A11Y-01 | auto | yes | yes | docs | existing-artifact |
| 16-10-T2 | 16-10 | 9 | A11Y-01 | checkpoint:human-action | no | yes | source | existing-artifact |
| 16-11-T1 | 16-11 | 10 | A11Y-01 | auto | yes | yes | test | existing-artifact |
| 16-11-T2 | 16-11 | 10 | A11Y-01 | checkpoint:human-action | no | yes | docs | existing-artifact |
| 16-11-T3 | 16-11 | 10 | A11Y-01 | auto | yes | yes | docs | existing-artifact |
| 16-12-T1 | 16-12 | 11 | A11Y-01 | auto | yes | yes | task | existing-artifact |
| 16-12-T2 | 16-12 | 11 | A11Y-01 | checkpoint:human-verify | no | yes | docs | existing-artifact |
| 16-12-T3 | 16-12 | 11 | A11Y-01 | auto | yes | yes | docs | existing-artifact |
| 16-13-T1 | 16-13 | 12 | A11Y-02 | auto | yes | yes | task | existing-artifact |
| 16-13-T2 | 16-13 | 12 | A11Y-02 | checkpoint:decision | no | yes | source | existing-artifact |
| 16-13-T3 | 16-13 | 12 | A11Y-02 | auto | yes | yes | docs | existing-artifact |
| 16-14-T1 | 16-14 | 12 | A11Y-02 | auto | yes | no | test | existing-artifact |
| 16-14-T2 | 16-14 | 12 | A11Y-02 | auto | yes | no | test | existing-artifact |
| 16-15-T1 | 16-15 | 13 | A11Y-02 | auto | yes | yes | task | existing-artifact |
| 16-15-T2 | 16-15 | 13 | A11Y-02 | auto | yes | yes | task | existing-artifact |
| 16-15-T3 | 16-15 | 13 | A11Y-02 | auto | yes | yes | task | existing-artifact |
| 16-16-T1 | 16-16 | 14 | A11Y-02 | auto | yes | yes | task | existing-artifact |
| 16-16-T2 | 16-16 | 14 | A11Y-02 | auto | yes | yes | task | existing-artifact |
| 16-17-T1 | 16-17 | 15 | A11Y-02 | auto | yes | yes | task | existing-artifact |
| 16-17-T2 | 16-17 | 15 | A11Y-02 | auto | yes | yes | task | existing-artifact |
| 16-18-T1 | 16-18 | 16 | A11Y-02 | auto | yes | no | task | existing-artifact |
| 16-18-T2 | 16-18 | 16 | A11Y-02 | auto | yes | yes | task | existing-artifact |
| 16-19-T1 | 16-19 | 17 | A11Y-02 | auto | yes | no | task | existing-artifact |
| 16-19-T2 | 16-19 | 17 | A11Y-02 | auto | yes | no | task | existing-artifact |
| 16-19-T3 | 16-19 | 17 | A11Y-02 | auto | yes | yes | task | existing-artifact |
| 16-20-T1 | 16-20 | 18 | A11Y-02 | auto | yes | no | task | existing-artifact |
| 16-20-T2 | 16-20 | 18 | A11Y-02 | auto | yes | no | task | existing-artifact |
| 16-21-T1 | 16-21 | 19 | A11Y-02 | auto | yes | no | task | existing-artifact |
| 16-21-T2 | 16-21 | 19 | A11Y-02 | auto | yes | no | task | existing-artifact |
| 16-21-T3 | 16-21 | 19 | A11Y-02 | auto | yes | no | test | existing-artifact |
| 16-22-T1 | 16-22 | 20 | A11Y-02 | auto | yes | yes | task | existing-artifact |
| 16-22-T2 | 16-22 | 20 | A11Y-02 | auto | yes | yes | docs | existing-artifact |
| 16-23-T1 | 16-23 | 21 | A11Y-02 | auto | yes | yes | source | existing-artifact |
| 16-23-T2 | 16-23 | 21 | A11Y-02 | auto | yes | yes | task | existing-artifact |
| 16-23-T3 | 16-23 | 21 | A11Y-02 | auto | yes | yes | docs | existing-artifact |
| 16-24-T1 | 16-24 | 22 | A11Y-02 | auto | yes | yes | test | existing-artifact |
| 16-24-T2 | 16-24 | 22 | A11Y-02 | auto | yes | yes | source | existing-artifact |
| 16-24-T3 | 16-24 | 22 | A11Y-02 | checkpoint:human-verify | no | yes | test | existing-artifact |
| 16-24-T4 | 16-24 | 22 | A11Y-02 | auto | yes | yes | docs | existing-artifact |
| 16-25-T1 | 16-25 | 23 | A11Y-02 | tracer | yes | yes | task | existing-artifact |
| 16-25-T2 | 16-25 | 23 | A11Y-02 | auto | yes | yes | docs | existing-artifact |
| 16-25-T3 | 16-25 | 23 | A11Y-02 | checkpoint:human-action | no | yes | task | existing-artifact |
| 16-25-T4 | 16-25 | 23 | A11Y-02 | auto | yes | yes | docs | existing-artifact |
| 16-25-T5 | 16-25 | 23 | A11Y-02 | checkpoint:decision | no | yes | docs | existing-artifact |
| 16-25-T6 | 16-25 | 23 | A11Y-02 | auto | yes | yes | source | existing-artifact |
| 16-25-T7 | 16-25 | 23 | A11Y-02 | auto | yes | yes | source | completed-evidence |
| 16-26-T1 | 16-26 | 24 | A11Y-01, A11Y-02 | tracer | yes | yes | docs | completed-evidence |
| 16-26-T2 | 16-26 | 24 | A11Y-01, A11Y-02 | auto | yes | no | docs | completed-evidence |
| 16-26-T3 | 16-26 | 24 | A11Y-01, A11Y-02 | checkpoint:decision | no | yes | docs | manual-pending-owner |
| 16-26-T4 | 16-26 | 24 | A11Y-01, A11Y-02 | auto | yes | yes | docs | manual-pending-owner |

Map counts: {"plans": 26, "tasks": 68, "automated": 59, "manualOrCheckpoint": 48, "statusExistingArtifact": 63, "statusCompletedEvidence": 3, "statusManualPendingOwner": 2}


## Authoritative Artifact Basis (68 tasks)

The per-task map records artifact basis separately from command availability; a command present in a plan is not evidence that it passed.

| Task | Artifact basis |
|---|---|
| 16-01-T1 | 16-01-SUMMARY.md |
| 16-01-T2 | 16-01-SUMMARY.md |
| 16-02-T1 | 16-02-SUMMARY.md |
| 16-02-T2 | 16-02-SUMMARY.md |
| 16-03-T1 | 16-03-SUMMARY.md |
| 16-03-T2 | 16-03-SUMMARY.md |
| 16-04-T1 | 16-04-SUMMARY.md |
| 16-04-T2 | 16-04-SUMMARY.md |
| 16-05-T1 | 16-05-SUMMARY.md |
| 16-05-T2 | 16-05-SUMMARY.md |
| 16-06-T1 | 16-06-SUMMARY.md |
| 16-06-T2 | 16-06-SUMMARY.md |
| 16-07-T1 | 16-07-SUMMARY.md |
| 16-07-T2 | 16-07-SUMMARY.md |
| 16-08-T1 | 16-08-SUMMARY.md |
| 16-08-T2 | 16-08-SUMMARY.md |
| 16-09-T1 | 16-09-SUMMARY.md |
| 16-09-T2 | 16-09-SUMMARY.md |
| 16-10-T1 | 16-10-SUMMARY.md |
| 16-10-T2 | 16-10-SUMMARY.md |
| 16-11-T1 | 16-11-SUMMARY.md |
| 16-11-T2 | 16-11-SUMMARY.md |
| 16-11-T3 | 16-11-SUMMARY.md |
| 16-12-T1 | 16-12-SUMMARY.md |
| 16-12-T2 | 16-12-SUMMARY.md |
| 16-12-T3 | 16-12-SUMMARY.md |
| 16-13-T1 | 16-13-SUMMARY.md |
| 16-13-T2 | 16-13-SUMMARY.md |
| 16-13-T3 | 16-13-SUMMARY.md |
| 16-14-T1 | 16-14-SUMMARY.md |
| 16-14-T2 | 16-14-SUMMARY.md |
| 16-15-T1 | 16-15-SUMMARY.md |
| 16-15-T2 | 16-15-SUMMARY.md |
| 16-15-T3 | 16-15-SUMMARY.md |
| 16-16-T1 | 16-16-SUMMARY.md |
| 16-16-T2 | 16-16-SUMMARY.md |
| 16-17-T1 | 16-17-SUMMARY.md |
| 16-17-T2 | 16-17-SUMMARY.md |
| 16-18-T1 | 16-18-SUMMARY.md |
| 16-18-T2 | 16-18-SUMMARY.md |
| 16-19-T1 | 16-19-SUMMARY.md |
| 16-19-T2 | 16-19-SUMMARY.md |
| 16-19-T3 | 16-19-SUMMARY.md |
| 16-20-T1 | 16-20-SUMMARY.md |
| 16-20-T2 | 16-20-SUMMARY.md |
| 16-21-T1 | 16-21-SUMMARY.md |
| 16-21-T2 | 16-21-SUMMARY.md |
| 16-21-T3 | 16-21-SUMMARY.md |
| 16-22-T1 | 16-22-SUMMARY.md |
| 16-22-T2 | 16-22-SUMMARY.md |
| 16-23-T1 | 16-23-SUMMARY.md |
| 16-23-T2 | 16-23-SUMMARY.md |
| 16-23-T3 | 16-23-SUMMARY.md |
| 16-24-T1 | 16-24-SUMMARY.md |
| 16-24-T2 | 16-24-SUMMARY.md |
| 16-24-T3 | 16-24-SUMMARY.md |
| 16-24-T4 | 16-24-SUMMARY.md |
| 16-25-T1 | 16-SWEEP.md Task 7/cache walkthrough closure |
| 16-25-T2 | 16-SWEEP.md Task 7/cache walkthrough closure |
| 16-25-T3 | 16-SWEEP.md Task 7/cache walkthrough closure |
| 16-25-T4 | 16-SWEEP.md Task 7/cache walkthrough closure |
| 16-25-T5 | 16-SWEEP.md Task 7/cache walkthrough closure |
| 16-25-T6 | 16-SWEEP.md Task 7/cache walkthrough closure |
| 16-25-T7 | 16-SWEEP.md Task 7/cache walkthrough closure |
| 16-26-T1 | 16-26 Task 1 plan/gate evidence |
| 16-26-T2 | 16-26 Task 2 plan/gate evidence |
| 16-26-T3 | 16-26 Task 3 plan/gate evidence |
| 16-26-T4 | 16-26 Task 4 plan/gate evidence |

## Behavior Coverage Map (23 rows)

| # | Requirement | Status | Plan/task | Evidence / disposition |
|---:|---|---|---|---|
| 1 | minimumScaleFactor rule/error and zero count | COVERED | 16-01 T1/T2; 16-12 T1 | .swiftlint.yml + strict no-cache lint evidence (0 violations) |
| 2 | .dynamicTypeSize modifier rule and negative control | COVERED | 16-01 T1/T2 | .swiftlint.yml + lint gate |
| 3 | GeometryReader rule and zero count | COVERED | 16-01 T1/T2 | .swiftlint.yml + lint gate |
| 4 | numeric .system(size:) rule and negative control | COVERED | 16-01 T1/T2 | .swiftlint.yml + lint gate |
| 5 | all surfaces readable/operable XXL AX3 AX5 both devices/orientations | MANUAL | 16-02 T1/T2; 16-04..09 T1/T2; 16-11 T1/T3; 16-25 T2/T7; 16-26 T1/T2 | 16-SWEEP.md matrix and simulator walkthrough evidence |
| 6 | five D-13 AX5 edge cases dispositioned | MANUAL | 16-02 T1; 16-11 T1/T3; 16-26 T1/T2 | 16-SWEEP.md named D-13 rows |
| 7 | .large parity after owner fixes | MANUAL | 16-05 T1/T2; 16-11 T1; 16-25 T6/T7 | before/after cache captures and owner review |
| 8 | lineLimit(1) checklist re-judged | MANUAL | 16-02 T1; 16-11 T1 | 16-SWEEP.md D-04 checklist |
| 9 | hardcoded accessibility strings guard | COVERED | 16-01 T1/T2; 16-16 T1/T2; 16-17 T1/T2 | .swiftlint.yml + strict lint evidence |
| 10 | luminance crossover and contrast helper | SUPERSEDED | 16-14 T1 | The contrast helper and its historical test were removed by the owner in cc05aca6; no current test claim |
| 11 | 84 category variants and colorset hash pins | COVERED | 16-14 T2; 16-15 T2 | AppPackage/Tests/AppToolsTests/CategoryColorsetInvariantTests.swift; closing FeatureTests pass |
| 12 | CategoryLabel/CategoryCell resolved text contrast | MANUAL | 16-15 T1/T3; 16-23 T1/T2 | Adaptive contrast implementation was reverted; owner-accepted white treatment remains a manual visual decision |
| 13 | fixture-reachable accessibility audit | COVERED | 16-24 T1/T2/T4 | EhPandaUITests/AccessibilityAuditUITests.swift; UITests closing gates pass |
| 14 | icon-only/custom tappable labels and traits | COVERED+MANUAL | 16-16 T1/T2; 16-17 T1; 16-19 T1/T2/T3; 16-24 T1/T2; 16-25 T2/T7 | UI audit + actual-focus/VC proxy evidence |
| 15 | Voice Control spoken commands/actuation | MANUAL-ONLY | 16-25 T2/T3/T7 | spoken commands not exercised; retain manual-only |
| 16 | VoiceOver announcement/order/post-navigation focus | MANUAL | 16-25 T2/T3/T7; 16-26 T1/T2 | sim-use/vot actual-focus + spoken transcripts; double-tap activation remains manual |
| 17 | Reduce Motion gating and rendered outcome | COVERED+MANUAL | 16-20 T1/T2; 16-21 T1/T2/T3 | ReduceMotionGatingSourceTests + display captures/manual rendered judgment |
| 18 | non-category contrast dark/IC | MANUAL | 16-13 T1/T2; 16-15 T2/T3; 16-23 T1/T2 | simulator display evidence and contrast measurements |
| 19 | Differentiate Without Color/grayscale | MANUAL | 16-13 T1/T2; 16-22 T1/T2; 16-23 T1/T2 | grayscale display evidence |
| 20 | D-25 targeted re-sweep | MANUAL | 16-25 T7; 16-26 T1/T2 | 9 cells: Search #9, Favorites #8, Watched #5; 8 pass plus Favorites AX5 finding #39 |
| 21 | Nutrition Label document | SUPERSEDED | 16-26 T4 | owner 2026-09-15 superseded deliverable; no test/file gap |
| 22 | package regression suite | COVERED | 16-14/16-24 and 16-26 T2 | closing FeatureTests: 1039 passed, 0 failed, 0 skipped, 11 expected; first try |
| 23 | UI regression suite | COVERED | 16-24 T4 and 16-26 T2 | closing UITests: iPhone 39 passed/2 skipped; iPad 41 passed/0 skipped; 0 failed; no Repetition |

## Wave 0 Requirements

- [x] `.swiftlint.yml` six custom rules at error severity; strict no-cache lint reports 0 violations.
- [x] CategoryColorsetInvariantTests.swift exists and its background pins are covered by closing FeatureTests; the removed contrast helper is not current coverage.
- [x] `ReduceMotionGatingSourceTests.swift` exists.
- [x] `EhPandaUITests/AccessibilityAuditUITests.swift` exists and is covered by closing UITests.
- [x] Existing test infrastructure; no framework install required.

## Manual-Only Verifications

- Rendered Dynamic Type, D-03 readability/operability, `.large` parity and D-25 visible changes: visual simulator/cache evidence plus owner review.
- VoiceOver actual-focus/spoken evidence exists through sim-use/vot; experiential confirmation remains manual and double-tap activation is unmeasured.
- Voice Control spoken commands and VO double-tap activation were not measured; native UI/VC proxies are not command execution.
- Reduce Motion rendered effects, dark/Increase Contrast and grayscale require rendered judgment.
- Owner final sign-off remains a checkpoint.

## Superseded / excluded

- Nutrition Label deliverable is superseded by owner D-34; no missing file/test gap.
- Comments modal has no tab bar; no tab-boundary gap is asserted.


## Closing Gate Provenance (2026-09-17)

- Immutable source under validation: b01add4c11b1f9c355ac8f2e055ed8b24fe8146c.
- Configured test command (from .planning/config.json):

  ```bash
  DEVELOPER_DIR=/Applications/Xcode-26.6.0.app/Contents/Developer bash "$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/scripts/xb2.sh" "$HOME/Library/Caches/ehpanda-phase16/round2/close/regression-gate.log" test -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,id=73E148DA-26E4-4892-8C8A-7EDC6725D0E7' -derivedDataPath "$HOME/Library/Caches/ehpanda-phase16/round2/walkthrough/vo22/production-gates/DerivedData-Generic-Lint"
  ```
- FeatureTests iPhone: $HOME/Library/Caches/ehpanda-phase16/round2/close/20260917-final-featuretests-iphone.summary.json; 1039 passed, 0 failed, 0 skipped, 11 expected, Repetition 0; console 82.369 s.
- UI tests: iPhone summary $HOME/Library/Caches/ehpanda-phase16/round2/close/20260917-final-uitests-iphone.summary.json, 39 passed, 0 failed, 2 skipped, Repetition 0; iPad summary $HOME/Library/Caches/ehpanda-phase16/round2/close/20260917-final-uitests-ipad.summary.json, 41 passed, 0 failed, 0 skipped, Repetition 0.
- Strict no-cache SwiftLint: 579 files, 0 violations; command and binary are recorded in 20260917-final-closing-gates-evidence.txt.
- D-25 evidence is under $HOME/Library/Caches/ehpanda-phase16/resweep/20260917-final/; Search #9, Favorites #8, and Watched #5 each have XXL/AX3/AX5 coverage (9 cells, 8 pass plus the Favorites AX5 finding). Search is not pending.
- W-22 module gate: 49 tests (AppTools 13, Home 24, Search 12), zero failed/skipped/Repetition in 54.033 s; matching generic Simulator build passed in 67.206 s, debug dylib SHA 70e573ff0231029a87a233cee5b768bdd705147ded7ba869ab07afc324cf0ed0.
- Owner gates remain manual: phonetic audio judgment and final sign-off.


## Audit Trail

- Audited: 2026-09-17.
- 68 tasks and 23 behavior rows were mapped to artifact basis; command presence is not a pass assertion.
- Automated gaps: 0 genuine gaps identified; no new tests were added by this audit.
- Created baseline retained from 2026-08-23; current closing evidence is separately identified above.

## Validation Sign-Off

- [x] Complete 68-task map and 23 behavior map.
- [x] No new automated coverage gap identified.
- [x] Existing meaningful tests and first-run gates recorded.
- [x] Manual-only constraints explicit.
- [ ] Owner final sign-off and phonetic judgment.

**Approval:** pending (coverage compliant does not equal phase approved)
