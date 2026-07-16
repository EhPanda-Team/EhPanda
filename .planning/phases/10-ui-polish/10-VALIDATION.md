---
phase: 10
slug: ui-polish
status: approved
nyquist_compliant: true
wave_0_complete: true
created: 2026-07-17
---

# Phase 10 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Populated from 10-RESEARCH.md §Validation Architecture (grep-verified 2026-07-17).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (Xcode-run only — bare `swift build`/`swift test` fails on this package) |
| **Config file** | `AppPackage/Tests/FeatureTests.xctestplan` |
| **Quick run command** | `xcodebuild build -project EhPanda.xcodeproj -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` (clean-build gate; adjust destination to the installed simulator) |
| **Full suite command** | `xcodebuild test -project EhPanda.xcodeproj -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| **Estimated runtime** | build ~1–3 min; full suite ~48 s test time on prior-phase runs (plus build) |

**Constraint (D-12):** strictly ONE xcodebuild invocation at a time on this machine — never overlap build/test runs (wedged-testmanagerd risk). xcodebuild buffers stdout until exit; sparse output is not a hang.

---

## Sampling Rate

- **After every task commit:** clean build of the AppPackage-Package scheme + SwiftLint (DerivedData artifactbundle binary) zero-new (D-10/D-12)
- **After every plan wave:** the plan's grep gates; full suite at 10-01 (rename proof) and 10-12 (phase gate)
- **Before `/gsd-verify-work`:** full suite green + D-03 owner sign-off + D-11 spot-check evidence complete
- **Max feedback latency:** one sequential build (~minutes); greps are instant

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 10-01-01 | 01 | 1 | CRIT-11 | — | N/A | static | `grep -rnF "SystemNotificationExt" AppPackage/Sources AppPackage/Tests App ShareExtension AppPackage/Package.swift \| wc -l` == 0 | ✅ grep | ⬜ pending |
| 10-01-02 | 01 | 1 | CRIT-11 | — | N/A | full suite | full suite command; output must contain `SystemNotificationTests` | ✅ existing tests | ⬜ pending |
| 10-02-01 | 02 | 2 | CRIT-07 | — | N/A | static | `grep -rnF ".foregroundColor(" AppPackage/Sources App ShareExtension --include="*.swift" \| wc -l` == 0 | ✅ grep | ⬜ pending |
| 10-02-02 | 02 | 2 | CRIT-07 | — | N/A | static | `grep -rnF ".accentColor(" AppPackage/Sources App ShareExtension --include="*.swift" \| wc -l` == 0; 3-file implicit-member `.accentColor` count == 4 | ✅ grep | ⬜ pending |
| 10-02-03 | 02 | 2 | CRIT-07 | — | N/A | build+lint | build gate: `grep -c "warning: "` output 0 | ✅ infra | ⬜ pending |
| 10-03-01 | 03 | 3 | CRIT-07 | — | N/A | static | `.cornerRadius(` / `disableAutocorrection` / `.statusBar(hidden` greps (-F, scoped) all == 0 | ✅ grep | ⬜ pending |
| 10-03-02 | 03 | 3 | CRIT-08 | — | N/A | static | `grep -rnF "RoundedCorner" AppPackage/Sources --include="*.swift" \| wc -l` == 0 | ✅ grep | ⬜ pending |
| 10-03-03 | 03 | 3 | CRIT-07/08 | — | N/A | build+manual | build gate + D-11 sim-use corner spot-checks (radius-15 sites) | ✅ infra | ⬜ pending |
| 10-04-01 | 04 | 4 | CRIT-06 | T-10-04 | `.privacyMask()` survives at all 4 chained setter sites | static | `grep -rn "inSheet" AppPackage/Sources AppPackage/Tests App ShareExtension --include="*.swift" \| wc -l` == 0; `grep -rnF ".privacyMask()" AppPackage/Sources --include="*.swift" \| wc -l` == 41 | ✅ grep | ⬜ pending |
| 10-04-02 | 04 | 4 | CRIT-06 | T-10-04 | elevated-trait probe + light/dark parity | build+manual | build gate; sim-use A3 probe + delta screenshots | ✅ infra | ⬜ pending |
| 10-04-03 | 04 | 4 | CRIT-06 | T-10-04 | owner-gated delta decision | checkpoint | inSheet grep stays 0 post-decision | ✅ grep | ⬜ pending |
| 10-05-01 | 05 | 5 | CRIT-10 | — | dialog anchors stay on triggering controls | build+static | build gate; `grep -rnF "systemImage:" AppPackage/Sources --include="*.swift"` == 0 | ✅ grep | ⬜ pending |
| 10-05-02 | 05 | 5 | CRIT-09 | — | no empty-string labels | static+manual | empty-string regex grep == 0; sim-use toolbar spot-check | ✅ grep | ⬜ pending |
| 10-06-01 | 06 | 6 | POLISH-02 | — | N/A | audit | ZStack count baseline grep recorded (~35) | ✅ grep | ⬜ pending |
| 10-06-02 | 06 | 6 | POLISH-02 | — | N/A | build+lint | build gate; remaining ZStack count == KEEP verdicts | ✅ infra | ⬜ pending |
| 10-06-03 | 06 | 6 | POLISH-02 | — | N/A | manual (D-11) | before/after sim-use screenshot pairs per converted screen | manual — justified: layout parity is visual | ⬜ pending |
| 10-07-01 | 07 | 7 | POLISH-01 | — | N/A | static | per-file pair-check: `monospacedDigit` and `numericText` counts both nonzero in the 6 treated files | ✅ grep | ⬜ pending |
| 10-07-02 | 07 | 7 | POLISH-01 | — | N/A | build+manual | build gate; sim-use reader page-swipe jitter check | ✅ infra | ⬜ pending |
| 10-08-01 | 08 | 8 | POLISH-03 | T-10-09 | synthetic fixtures only | static | per-file `PreviewProvider` count == 0 (5 cell files) | ✅ grep | ⬜ pending |
| 10-08-02 | 08 | 8 | POLISH-03 | T-10-09 | synthetic fixtures only | static+build | per-file count == 0 (3 component files); build gate | ✅ grep | ⬜ pending |
| 10-09-01 | 09 | 9 | POLISH-03 | T-10-11 | synthetic fixtures only | static | `PreviewProvider` grep == 0 in SettingFeature | ✅ grep | ⬜ pending |
| 10-09-02 | 09 | 9 | POLISH-03 | T-10-11 | synthetic fixtures only | static | `PreviewProvider` grep == 0 in HomeFeature/SearchFeature/DetailFeature | ✅ grep | ⬜ pending |
| 10-09-03 | 09 | 9 | POLISH-03 | T-10-11 | synthetic fixtures only | static+build | global `PreviewProvider` grep (Sources/Tests/App/ShareExtension) == 0; build gate | ✅ grep | ⬜ pending |
| 10-10-01 | 10 | 10 | CRIT-05 | — | N/A | static+build | `grep -rnE '\.font\(\.system\(size: [0-9]' AppPackage/Sources --include="*.swift" \| wc -l` == 0 | ✅ grep | ⬜ pending |
| 10-10-02 | 10 | 10 | CRIT-05 | — | N/A | manual audit | sim-use XXL/AX3/AX5 pass; live `lineLimit(1)` count grep anchors the verdict-table coverage | manual — justified per D-03: static checks cannot prove readable-and-operable | ⬜ pending |
| 10-11-01 | 11 | 11 | CRIT-05 | — | N/A | static | prohibition greps: `dynamicTypeSize` == 0, `minimumScaleFactor` <= 8, `GeometryReader` == 0 | ✅ grep | ⬜ pending |
| 10-11-02 | 11 | 11 | CRIT-05 | — | N/A | build+manual | build gate; AX5 re-check + default-size parity screenshots | ✅ infra | ⬜ pending |
| 10-12-01 | 12 | 12 | all | T-10-15 | privacyMask call sites == 41 on final tree | full suite+static | full suite command + phase grep battery | ✅ infra | ⬜ pending |
| 10-12-02 | 12 | 12 | CRIT-05 | — | N/A | manual (D-03 evidence) | sim-use full-screen-inventory pass at XXL/AX3/AX5 | manual — justified per D-03 | ⬜ pending |
| 10-12-03 | 12 | 12 | all | — | owner sign-off | checkpoint | full suite tail green at sign-off | ✅ infra | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

Existing infrastructure covers all phase requirements. This phase adds no unit-testable logic (view-layer only); the 505-test suite + grep gates + sim-use visual gates are the full validation surface (10-RESEARCH.md §Wave 0 Gaps: none). The one flaky-history test (`DownloadSchedulingTests`) is deterministically fixed — any failure during this phase is a real regression.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Numeric transitions animate without layout jitter | POLISH-01 (criteria 2-3) | Jitter is visual; modifier presence is greppable but motion is not | sim-use: reader page swipes + downloads progress at default size (10-07 T2, 10-12 T2) |
| ZStack conversion layout parity | POLISH-02 (criterion 4) | Composite sizing drift is visual | sim-use before/after screenshot pairs per converted screen (10-06 T1/T3) |
| Corner-shape parity at radius 15 | CRIT-08 | circular-vs-continuous drift only visible on device | sim-use spot-check thumbnail/card/category corners (10-03 T3) |
| Sheet-elevation gray + trait delta | CRIT-06 | Rendered gray tones depend on runtime traits | sim-use A3 probe + previously-unflagged-sheet delta; owner-gated (10-04 T2/T3) |
| Toolbar Label rendering (no title appears) | CRIT-10 | Toolbar icon-only rendering is runtime behavior | sim-use toolbar screenshots (10-05 T2) |
| DT readable-and-operable at XXL/AX3/AX5, every screen incl. sheets | CRIT-05 (D-03) | Owner-signed visual gate; static/unit checks cannot prove it | sim-use full screen-inventory pass; owner signs at 10-12 T3 |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (every task carries an `<automated>` command; visual gates additionally carry manual steps)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (none — existing infra suffices)
- [x] No watch-mode flags
- [x] Feedback latency: greps instant; builds sequential per D-12 (accepted machine constraint)
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-17
