---
phase: 11
slug: infra-refactor-lint-capstone
status: ready
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-20
---

# Phase 11 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Populated from RESEARCH.md §Validation Architecture (revision 1).

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (parallel by default — the phase's target property) + SwiftLint 0.65.0 standalone binary as the lint oracle |
| **Config file** | none (trait-driven); lint config: root `.swiftlint.yml` + per-module `parent_config` stubs |
| **Quick run command** | `xcodebuild test -scheme <Module> -destination 'platform=iOS Simulator,name=iPhone Air'` (per-module schemes exist for every module) |
| **Full suite command** | `xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air'` |
| **Estimated runtime** | full suite ~1 min of test execution once built (~48 s observed in Phase 5); cold builds dominate wall time. Per-module runs are shorter. |

**Hard constraint (RESEARCH Pitfall 9 / project memory):** run ONE `xcodebuild test` invocation at a time — never overlap, never kill one mid-launch. This is why the phase's 31 plans are deliberately sequential (one plan per wave).

**Lint zero-check (the rule IS the test for LINT-01):**

```bash
SWIFTLINT="$HOME/Library/Developer/Xcode/DerivedData/AppPackage-glhpivzptobywqasgqylwdgfzzei/SourcePackages/artifacts/swiftlintplugins/SwiftLintBinary/SwiftLintBinary.artifactbundle/macos/swiftlint"
"$SWIFTLINT" lint --quiet --reporter json AppPackage/Sources AppPackage/Tests App ShareExtension
```

Pass explicit paths (never traverse `AppPackage/.build`).

---

## Sampling Rate

- **After every task commit:** run the task's `<automated>` command — the affected module's scheme test run and/or an `EhPanda`-scheme build (the build IS the lint gate via SwiftLintBuildToolPlugin).
- **After every plan wave:** the plan's full `<verify>` battery green (one plan per wave in this phase). Full `EhPanda`-scheme parallel suite runs at the designated gates: 11-22.1 (first full parallel gate), 11-25, 11-27, and 11-29 (capstone).
- **Before `/gsd-verify-work`:** full suite green **in parallel** + all seven rules at zero via the standalone JSON zero-check + clean build under the plugin (plan 11-29's battery).
- **Max feedback latency:** ≤ ~120 s for a warm per-module run; full-suite gates are minutes (build-dominated) and are placed at the four designated waves, not every commit.

---

## Per-Task Verification Map

One row per plan (each plan's tasks share the plan's verify battery; task IDs are `11-NN-01/02`). All xcodebuild commands take `-destination 'platform=iOS Simulator,name=iPhone Air'` (omitted below for width). Requirement is LINT-01 throughout.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 11-01-01/02 | 01 | 1 | LINT-01 | T-11-01 | new logger lines carry no cookies/credentialed URLs/raw HTML (Phase 8 scan) | unit + grep | `xcodebuild test -scheme ParserFeature` + `try?` residual grep (expect 6) | ✅ | ⬜ pending |
| 11-02-01/02 | 02 | 2 | LINT-01 | T-11-02 | malformed page throws — stricter input validation (ASVS V5) | unit | `xcodebuild test -scheme ParserFeature`; `xcodebuild build -scheme EhPanda` | ✅ edited in-plan (thrown-error assertions) | ⬜ pending |
| 11-03-01/02 | 03 | 3 | LINT-01 | T-11-03 | N/A | unit | `xcodebuild test -scheme DownloadClient`; `-scheme DownloadsFeature` | ✅ | ⬜ pending |
| 11-04-01/02 | 04 | 4 | LINT-01 | T-11-04/05 | N/A | unit + grep | `xcodebuild test -scheme DownloadClient`; `-scheme DownloadsFeature` + module grep 0 | ✅ | ⬜ pending |
| 11-05-01/02 | 05 | 5 | LINT-01 | T-11-06/07 | N/A | unit + grep | `xcodebuild test -scheme AppTools`; `-scheme AppModels` + grep 0 | ✅ | ⬜ pending |
| 11-06-01/02 | 06 | 6 | LINT-01 | T-11-08 | N/A | unit + grep | `xcodebuild test -scheme NetworkingFeature`; `build -scheme EhPanda` + Sources-wide grep 0 | ✅ | ⬜ pending |
| 11-07-01/02 | 07 | 7 | LINT-01 | T-11-09 | N/A | unit | `xcodebuild test -scheme HomeFeature`; `-scheme SearchFeature` | ✅ edited in-plan (load-on-presentation asserts) | ⬜ pending |
| 11-08-01/02 | 08 | 8 | LINT-01 | T-11-10/11 | N/A | unit | `xcodebuild test -scheme DetailFeature` | ✅ edited in-plan | ⬜ pending |
| 11-09-01/02 | 09 | 9 | LINT-01 | T-11-12 | N/A | unit | `xcodebuild test -scheme ReadingFeature` | ✅ edited in-plan | ⬜ pending |
| 11-10-01/02 | 10 | 10 | LINT-01 | T-11-13 | N/A | unit | `xcodebuild test -scheme SettingFeature`; `-scheme DownloadsFeature` | ✅ edited in-plan | ⬜ pending |
| 11-11-01/02 | 11 | 11 | LINT-01 | T-11-14 | N/A | build + lint flip | `xcodebuild build -scheme EhPanda`; `build-for-testing -scheme EhPanda` | ✅ | ⬜ pending |
| 11-12-01/02 | 12 | 12 | LINT-01 | T-11-15 | checked subscript: precondition-guarded access only | build | `xcodebuild build -scheme EhPanda` | ✅ | ⬜ pending |
| 11-13-01/02 | 13 | 13 | LINT-01 | T-11-16 | bounds-guarded indexing (DoS/crash) | unit | `xcodebuild test -scheme ReadingFeature`; `build -scheme EhPanda` | ✅ | ⬜ pending |
| 11-14-01/02 | 14 | 14 | LINT-01 | T-11-17 | untrusted-input (scraped HTML) indexing guarded | unit | `xcodebuild test -scheme ParserFeature` | ✅ | ⬜ pending |
| 11-15-01/02 | 15 | 15 | LINT-01 | T-11-18 | N/A | unit | `xcodebuild test -scheme DownloadClient`; `-scheme NetworkingFeature` | ✅ | ⬜ pending |
| 11-16-01/02 | 16 | 16 | LINT-01 | T-11-19 | N/A | unit (parity fixtures) | `xcodebuild test -scheme ImageColors`; `build -scheme EhPanda` | ✅ (3 fixtures must pass UNCHANGED, D-16) | ⬜ pending |
| 11-17-01/02 | 17 | 17 | LINT-01 | T-11-20 | N/A | unit + lint flip | `xcodebuild test -scheme HomeFeature`; `build-for-testing -scheme EhPanda` | ✅ | ⬜ pending |
| 11-18-01/02 | 18 | 18 | LINT-01 | T-11-21 | N/A | build + lint flip | `xcodebuild build-for-testing -scheme EhPanda` | ✅ | ⬜ pending |
| 11-19-01/02 | 19 | 19 | LINT-01 | T-11-22 | seam default preserves exact production path derivation | unit | `xcodebuild test -scheme FileClient`; `build -scheme EhPanda` | ❌ W0 in-plan: FileClientTests parallel rewrite | ⬜ pending |
| 11-20-01/02 | 20 | 20 | LINT-01 | T-11-23 | test seams never alter production cache behavior | unit | `xcodebuild test -scheme DownloadsFeature`; `-scheme ImageClient` | ❌ W0 in-plan: Kingfisher seam coverage + DidLoginKey rationale | ⬜ pending |
| 11-21-01/02 | 21 | 21 | LINT-01 | T-11-24 | N/A | unit (stability runs) | `xcodebuild test -scheme DownloadsFeature` | ✅ | ⬜ pending |
| 11-22-01 | 22 | 22 | LINT-01 | T-11-25 | N/A | unit, parallel | `xcodebuild test -scheme DownloadsFeature` | ✅ | ⬜ pending |
| 11-22.1-01/02 | 22.1 | 23 | LINT-01 | T-11-25 | N/A | full-suite parallel gate | `xcodebuild build-for-testing -scheme EhPanda`; `test -scheme EhPanda` | ✅ | ⬜ pending |
| 11-23-01/02 | 23 | 24 | LINT-01 | T-11-26 | N/A | unit + grep | `xcodebuild test -scheme DownloadsFeature` + Tests grep 0 | ✅ | ⬜ pending |
| 11-24-01/02 | 24 | 25 | LINT-01 | T-11-27 | N/A | unit + lint flip | `xcodebuild test -scheme CookieClient`; `build-for-testing -scheme EhPanda` | ✅ | ⬜ pending |
| 11-25-01/02 | 25 | 26 | LINT-01 | T-11-28 | N/A | lint + full suite | `xcodebuild build -scheme EhPanda`; `test -scheme EhPanda` | ✅ | ⬜ pending |
| 11-26-01/02 | 26 | 27 | LINT-01 | T-11-29 | N/A | lint + build | `xcodebuild build -scheme EhPanda` | ✅ | ⬜ pending |
| 11-27-01/02 | 27 | 28 | LINT-01 | T-11-30 | N/A | lint flip + full suite | `xcodebuild build-for-testing -scheme EhPanda`; `test -scheme EhPanda` | ✅ | ⬜ pending |
| 11-28-01/02 | 28 | 29 | LINT-01 | T-11-31 | N/A | lint flip + build | `xcodebuild build -scheme EhPanda`; `build-for-testing -scheme EhPanda` | ✅ | ⬜ pending |
| 11-29-01/02 | 29 | 30 | LINT-01 | T-11-32 | no unapproved suppressions (amended criterion 3) | full battery | seven-rule JSON zero-check; `xcodebuild test -scheme EhPanda`; `test -s 11-EXCEPTIONS.md` + ROADMAP wording check | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

This phase has no separate Wave 0: the test-gap work is scheduled as Wave-0-style edits **inside the owning plans** (the phase is strictly sequential, so the gap closes before anything depends on it). `wave_0_complete` flips to `true` once 11-02, 11-19, and 11-20 have landed.

- [ ] `AppPackage/Tests/ParserFeatureTests/` — thrown-error assertions for D-04 Group C (plan 11-02, RESEARCH Pitfall 7)
- [ ] `AppPackage/Tests/FileClientTests/FileClientTests.swift` — parallel rewrite off fixed paths against the D-12 injectable-root seam (plan 11-19)
- [ ] `AppPackage/Tests/DownloadsFeatureTests/` — Kingfisher cache-injection seam coverage in the two DownloadImageParsing suites (plan 11-20)
- [ ] `AppPackage/Tests/CookieClientTests/DidLoginKeyTests.swift` — D-14 in-file rationale comment for the retained single-sequential exception (plan 11-20)
- Framework install: none needed

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Exception batch approval | LINT-01 criterion 3 (amended per D-02) | Approval is an owner judgment (D-01: per-site review), deferred to phase end per CONTEXT's exception-review flow | Owner reviews `11-EXCEPTIONS.md` (generated by 11-29): every `// reason:` + `disable:next`, retained serialization traits, retained `@MainActor`. Unapproved entries get reworked, not shipped |
| Non-idempotent lifecycle parity | LINT-01 (D-06/D-07 migration) | Whether once-per-presentation is acceptable parity is an owner call, site-by-site (RESEARCH Open Q3) | Owner reviews the parity flags recorded in 11-07/11-08/11-10 SUMMARYs |
| `@MainActor`/serialization survivor inventory | LINT-01 criterion 4 | D-13/D-14 "real need" is an owner-reviewed judgment beyond the compiler check | Owner reviews the phase-wide survivor inventory in 11-22.1's SUMMARY (merged with 11-20/11-21 serialization verdicts) |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify (every plan carries scheme-test and/or build-gate commands)
- [x] Wave 0 covers all MISSING references (scheduled in-plan: 11-02, 11-19, 11-20 — sequential waves guarantee they land before dependents)
- [x] No watch-mode flags
- [x] Feedback latency acceptable: per-module runs ≤ ~120 s warm; full-suite gates confined to waves 23/26/28/30
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-20 (revision 1 — populated from RESEARCH §Validation Architecture)
