---
phase: "20"
slug: "3-0-distribution-marketplace-build-notarization-listing-rele"
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: "2026-11-09"
---

# Phase 20 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Source: 20-RESEARCH.md "Validation
> Architecture". `nyquist_compliant` is set by plan 20-14 Task 2 once every automated row is green.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Python `unittest` (`actions-tool/tests`, `Scripts/visual`), Swift Testing (FeatureTests), `plutil -lint`, `actionlint` (`~/.local/bin/actionlint`), YAML through `ruby -ryaml -rjson` |
| **Config file** | `AppPackage/Tests/FeatureTests.xctestplan`, `.swiftlint.yml` |
| **Devices** | `EhPanda iPhone Air` (`$PHONE`) then `EhPanda iPad Pro 11-inch (M5)` (`$PAD`), resolved by name: `PHONE=$(xcrun simctl list devices \| grep "EhPanda iPhone Air (" \| grep -Eo '[0-9A-F-]{36}' \| head -1)`; `PAD=$(xcrun simctl list devices \| grep "EhPanda iPad Pro 11-inch (M5) (" \| grep -Eo '[0-9A-F-]{36}' \| head -1)` |
| **Quick run command** | `cd actions-tool && python3 -m unittest discover -s tests -q` |
| **Full suite command** | actions-tool tests; touched `Scripts/visual` tests; FeatureTests on `$PHONE` then `$PAD`; `swiftlint lint --strict --no-cache --config .swiftlint.yml`; `actionlint .github/workflows/*.yml`; the Release isolation scan for both flavors (20-14) |
| **Lint** | SwiftLint strict → `Found 0 violations`; actionlint → no output |
| **Estimated runtime** | actions-tool < 10 s; one FeatureTests target 2 to 6 min; full FeatureTests ~26 min per device; each Release scan ~15 min |

---

## Sampling Rate

- **After every task commit:** the touched Python tests, or the touched Swift test target on `$PHONE`, and strict lint
  of the touched paths; actionlint for any workflow edit.
- **After every plan:** all actions-tool tests; for Swift plans, the plan's targets on `$PHONE` and `$PAD`.
- **Before `/gsd-verify-work`:** 20-14's gate.
- **Max feedback latency:** 10 s for actions-tool; 360 s for one Swift target.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 20-01-01 | 01 | 1 | DIST-18-01 | T-20-03 | each flavor's plist identity and stamp; unsigned stamping unchanged | build + plist | two unsigned archives, `plutil -extract`, `package-channel.sh` | ❌ W0 | ⬜ pending |
| 20-01-02 | 01 | 1 | DIST-18-01 | T-20-01 | marketplace scheme accepted, unknown rejected | unit | `-only-testing:AppToolsTests` | ✅ | ⬜ pending |
| 20-01-03 | 01 | 1 | DIST-18-01 | T-20-02 | manifest declares every required-reason use found | unit + build | `plutil -lint`; `test_privacy_manifest.py`; bundle membership | ❌ W0 | ⬜ pending |
| 20-02-01 | 02 | 1 | REL-18-01 | T-20-04, T-20-06 | build-number check before tests; URLs and history steps kept; no tag operations | workflow | `test_workflows.py`; actionlint | ❌ W0 | ⬜ pending |
| 20-02-02 | 02 | 1 | REL-18-01 | T-20-04 | build above every published build | script | `check-build-number.sh` against `FETCH_HEAD` sources | ✅ | ⬜ pending |
| 20-02-03 | 02 | 1 | REL-18-01 | T-20-05 | repository only after the owner's OK | checkpoint | `curl` of seven URLs; owner msg in record | — | ⬜ pending |
| 20-03-01 | 03 | 2 | DIST-18-02 | T-20-07, T-20-09 | PAL entry shape; Classic/SideStore/beta byte-identical | unit (golden) | `test_altstore_add_version.py` | ✅ | ⬜ pending |
| 20-03-02 | 03 | 2 | DIST-18-02 | T-20-08 | template + PAL checks; never zero versions | unit | `test_source_templates.py`; `jq -e` on template | ✅ | ⬜ pending |
| 20-04-01 | 04 | 3 | DIST-18-03 | T-20-10, T-20-11 | JWT valid; sequence; endpoint allow-list; no secret in logs | unit (fake server) | `test_asc.py` | ❌ W0 | ⬜ pending |
| 20-04-02 | 04 | 3 | DIST-18-03 | T-20-12 | per-target profiles without automatic signing | build settings | `marketplace-signing.sh xcconfig-only` + `-showBuildSettings` | ❌ W0 | ⬜ pending |
| 20-04-03 | 04 | 3 | DIST-18-03 | T-20-13 | dispatch-only, protected environment, ordered steps | workflow | `test_workflows.py`; actionlint | ❌ W0 | ⬜ pending |
| 20-05-01 | 05 | 4 | DIST-18-03, DIST-18-02 | T-20-14, T-20-15, T-20-16 | ADP bytes unchanged; release must exist; retry on push | unit (fakes) | `test_pal_publish.py` | ❌ W0 | ⬜ pending |
| 20-05-02 | 05 | 4 | DIST-18-03 | — | publish job separate; dry run by default | workflow | `test_workflows.py`; actionlint | ❌ W0 | ⬜ pending |
| 20-06-01 | 06 | 4 | DIST-18-03 | T-20-17, T-20-19 | records created by the collaborator; bundle IDs confirmed | checkpoint | `grep` of `20-06-ACCOUNT.md` | — | ⬜ pending |
| 20-06-02 | 06 | 4 | DIST-18-03, DIST-18-02 | T-20-17 | agreements, marketplace, privacy answers, `developerName` | checkpoint | `grep` per item; actions-tool tests | — | ⬜ pending |
| 20-06-03 | 06 | 4 | DIST-18-03 | T-20-18 | protected environment; secret names only | checkpoint | `gh api` environment and secret names | — | ⬜ pending |
| 20-07-01 | 07 | 5 | DIST-18-02 | T-20-21 | no "Apple-approved" wording | unit | `test_no_apple_approved.py` | ❌ W0 | ⬜ pending |
| 20-07-02 | 07 | 5 | UGC-18-01, DIST-18-02 | T-20-20 | four website URLs live | checkpoint | `grep` of `20-07-WEBSITE.md` status lines | — | ⬜ pending |
| 20-08-01 | 08 | 6 | DIST-18-03 | T-20-23 | OQ-A, OQ-B decided first | checkpoint (decision) | — | — | ⬜ pending |
| 20-08-02 | 08 | 6 | DIST-18-03 | — | interim screenshots at class sizes, or paused by decision | script | `sips` sizes; decision line | — | ⬜ pending |
| 20-08-03 | 08 | 6 | DIST-18-03 | T-20-22 | owner OK per dispatch; D-21 answered; verdict | checkpoint | `grep` of `20-08-SUBMISSION.md` | — | ⬜ pending |
| 20-08-04 | 08 | 6 | DIST-18-03 | T-20-24 | dry-run publish; real ADP layout | checkpoint | `grep`; actions-tool tests | — | ⬜ pending |
| 20-09-01 | 09 | 7 | DEV-18-01 | T-20-26 | ten Release cold launches on iPad | checkpoint (device) | `grep` launch rows | — | ⬜ pending |
| 20-09-02 | 09 | 7 | DEV-18-01 | T-20-25 | SC2 procedure on iPhone | checkpoint (device) | `grep` outcome lines | — | ⬜ pending |
| 20-10-01 | 10 | 8 | MKT-18-01 | — | owner's screens, decoration, wording | checkpoint (decision) | — | — | ⬜ pending |
| 20-10-02 | 10 | 8 | MKT-18-01, CAP-17-05 | T-20-27 | store renders tied to approved references; delivery check | unit + render | `test_store_screenshots.py`; `store_screenshots.py check` | ❌ W0 | ⬜ pending |
| 20-10-03 | 10 | 8 | MKT-18-01, DIST-18-02 | T-20-28 | approved, pushed, listed, uploaded | checkpoint | `curl` URLs; actions-tool tests with assets | — | ⬜ pending |
| 20-11-01 | 11 | 8 | REL-18-01 | — | OQ-F decided | checkpoint (decision) | — | — | ⬜ pending |
| 20-11-02 | 11 | 8 | REL-18-01 | T-20-29, T-20-30 | release requires the gate's `success` on its commit | unit (fake gh) + workflow | `test_require_snapshot_gate.py`; `test_workflows.py`; actionlint | ❌ W0 | ⬜ pending |
| 20-11-03 | 11 | 8 | REL-18-01 | — | live read of real verdicts | script | `grep` results | — | ⬜ pending |
| 20-12-01 | 12 | 9 | ANALYTICS-02 | T-20-31 | rules check per proposed signal; no code | document | `grep` flows; no AppPackage diff | — | ⬜ pending |
| 20-12-02 | 12 | 9 | ANALYTICS-02 | T-20-31 | sign-off before code | checkpoint (decision) | — | — | ⬜ pending |
| 20-13-01 | 13 | 10 | ANALYTICS-02 | T-20-32, T-20-33 | type-closed, level-gated, no content | unit | `-only-testing:AnalyticsClientTests` | ✅ | ⬜ pending |
| 20-13-02 | 13 | 10 | ANALYTICS-02 | T-20-33 | sent from approved actions only | unit (TestStore) | AppFeatureTests, SettingFeatureTests, DetailFeatureTests | ✅ | ⬜ pending |
| 20-13-03 | 13 | 10 | ANALYTICS-02 | — | README in six languages; full suite | script + suite | `18-copy-check.py --readmes`; FeatureTests both devices | ✅ | ⬜ pending |
| 20-14-01 | 14 | 11 | DIST-18-01 | T-20-34 | 0 findings, both flavors | scan | `verify-release.py` → `release-isolation.json` | ✅ | ⬜ pending |
| 20-14-02 | 14 | 11 | all | — | phase gate | suite | Full suite command | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `actions-tool/tests/test_privacy_manifest.py` (20-01)
- [ ] `actions-tool/tests/test_workflows.py` (20-02; extended by 20-04, 20-05, 20-11)
- [ ] `actions-tool/tests/test_asc.py` (20-04)
- [ ] `actions-tool/tests/test_pal_publish.py` and `fixtures/adp/` (20-05)
- [ ] `actions-tool/tests/test_no_apple_approved.py` (20-07)
- [ ] `Scripts/visual/test_store_screenshots.py` (20-10)
- [ ] `actions-tool/tests/test_require_snapshot_gate.py` (20-11)

Each is written first in its own task (TDD), so no separate Wave 0 plan is needed.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Apple-account records, agreements, marketplace, secrets | DIST-18-03 | collaborator's account; D-07 | 20-06 checkpoints |
| First notarization submission and verdict; D-21 key test | DIST-18-03 | live Apple review | 20-08 Task 3 |
| AltStore processing and the real ADP layout | DIST-18-03 | live AltStore service | 20-08 Task 4 |
| Website URLs | UGC-18-01 | Leto's website | 20-07 Task 2 |
| iPad stall, iPhone background downloads | DEV-18-01 | owner hardware; system UI | 20-09 |
| Store screenshot approval | MKT-18-01, CAP-17-05 | owner's judgement | 20-10 Task 3 |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or a checkpoint record check
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 360 s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
