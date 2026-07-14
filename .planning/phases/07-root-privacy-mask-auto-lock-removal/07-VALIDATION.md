---
phase: 7
slug: root-privacy-mask-auto-lock-removal
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-14
updated: 2026-07-14
requirements:
  UIARCH-04: covered
  UIARCH-05: covered
---

# Phase 7 — Validation Strategy

## Test Infrastructure

| Property | Value |
|----------|-------|
| Framework | Swift Testing through the `EhPanda` scheme and `FeatureTests` test plan |
| Configuration | `AppPackage/Package.swift`, `AppPackage/Tests/FeatureTests.xctestplan`, and module `.swiftlint.yml` files |
| Build gate | `xcodebuild -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator' build` |
| Focused behavior gate | `xcodebuild -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' -only-testing:AppFeatureTests/AppReducerScenePhaseTests test` |
| Regression gate | `xcodebuild -project EhPanda.xcodeproj -scheme EhPanda -testPlan FeatureTests -destination 'platform=iOS Simulator,name=iPhone Air,OS=26.5' test` |

## Requirement Coverage

| Requirement | Automated evidence | Status |
|-------------|--------------------|--------|
| UIARCH-04 | Exhaustive scene-phase tests; 39-root/39-mask bijection audit; module build; full FeatureTests regression suite | Covered |
| UIARCH-05 | Legacy-symbol and localization absence audits; six-locale Privacy Mask catalog audit; module build; full FeatureTests regression suite | Covered |

## Per-Task Verification Map

| Task | Requirement | Automated verification | Status |
|------|-------------|------------------------|--------|
| 07-01-01 | UIARCH-04 | AppFeature build and shared-key wiring check | Green |
| 07-01-02 | UIARCH-04 | AppFeature build and modifier wiring check | Green |
| 07-01-03 | UIARCH-04 | String-catalog parse and six-locale coverage audit | Green |
| 07-02-01 | UIARCH-04, UIARCH-05 | Legacy setting-symbol absence audit | Green |
| 07-02-02 | UIARCH-04 | Exhaustive `AppReducerScenePhaseTests` | Green |
| 07-02-03 | UIARCH-04, UIARCH-05 | AppFeature build and setting-control wiring audit | Green |
| 07-03-01 | UIARCH-04, UIARCH-05 | AppFeature build and root-mask wiring audit | Green |
| 07-03-02 | UIARCH-05 | Authorization module and Face ID key absence audit | Green |
| 07-03-03 | UIARCH-05 | Dead localization-key absence and catalog parse audit | Green |
| 07-04-01 | UIARCH-04 | HomeFeature legacy-parameter absence and mask-site audit | Green |
| 07-04-02 | UIARCH-04 | Favorites/TabBar wiring audit and AppFeature build | Green |
| 07-05-01 | UIARCH-04 | SearchFeature legacy-parameter absence and mask-site audit | Green |
| 07-05-02 | UIARCH-04 | DownloadsFeature audit and AppFeature build | Green |
| 07-06-01 | UIARCH-04 | DetailFeature legacy-parameter absence and mask-site audit | Green |
| 07-06-02 | UIARCH-04 | Detail presentation wiring audit and AppFeature build | Green |
| 07-07-01 | UIARCH-04 | ReadingFeature and caller-wiring audit | Green |
| 07-07-02 | UIARCH-04 | SettingFeature and activity-log mask audit | Green |
| 07-07-03 | UIARCH-04 | Global legacy-modifier absence audit and AppFeature build | Green |
| 07-08-01 | UIARCH-04, UIARCH-05 | AppFeatureTests target plus focused scene-phase suite | Green |
| 07-08-02 | UIARCH-04, UIARCH-05 | Mask coverage, orphan-symbol, Face ID, localization, build, and regression gates | Green |
| 07-08-03 | UIARCH-04 | Approved UAT plus later 39-root inventory and goal-level verification | Green |
| 07-09-01 | UIARCH-04 | AppFeature build and pre-settings scene-transition inspection | Green |
| 07-09-02 | UIARCH-04 | Pre-settings-load regression test | Green |
| 07-10-01 | UIARCH-04 | Exhaustive enabled/disabled foreground action and clipboard-cardinality tests | Green |
| 07-10-02 | UIARCH-04 | AppFeatureTests dependency audit and complete target run | Green |
| 07-11-01 | UIARCH-04 | Download Inspector single-mask audit | Green |
| 07-11-02 | UIARCH-04 | Bijective inventory audit: 39 roots, 39 unique sites, 39 executable masks | Green |
| 07-11-03 | UIARCH-04 | Reduce Motion wiring and floorless-blur audit | Green |
| 07-12-01 | UIARCH-04, UIARCH-05 | ROADMAP D-03/D-08 reconciliation audit | Green |
| 07-12-02 | UIARCH-04, UIARCH-05 | REQUIREMENTS D-03/D-08 reconciliation audit | Green |

## Manual-Only Verifications

No unresolved manual-only validation remains. The original visual privacy concern was approved during execution and is supported by the final bijective root inventory. Goal-level re-verification reports no human-verification items.

## Validation Audit 2026-07-14

| Metric | Count |
|--------|-------|
| Tasks audited | 30 |
| Automated or approved verification paths | 30 |
| Missing coverage gaps | 0 |
| Manual-only gaps | 0 |

## Sign-Off

- All tasks have an automated verification path or an approved UAT result.
- UIARCH-04 and UIARCH-05 both have behavioral and regression evidence.
- The focused scene-phase suite passes 3 tests.
- The final AppFeature build and full FeatureTests regression suite pass.
- `nyquist_compliant: true` is justified by zero remaining coverage gaps.

**Approval:** complete
