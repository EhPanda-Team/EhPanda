---
phase: 12
slug: cloudflare-login-restoration
# status lifecycle: draft (seeded by plan-phase) → validated (set by validate-phase §6)
# audit-milestone §5.5 distinguishes NOT-VALIDATED (draft) from PARTIAL (validated + nyquist_compliant: false) (#2117)
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-22
---

# Phase 12 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`@Test`/`@Suite`) + TCA `TestStore` |
| **Config file** | `AppPackage/Tests/FeatureTests.xctestplan` |
| **Quick run command** | `xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air' -only-testing:<Target>/<Suite>` (targeted suite for the touched target) |
| **Full suite command** | `xcodebuild test -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air'` (565-test suite, parallel across 18 targets post-Phase 11) |
| **Estimated runtime** | targeted suite ~2–4 min (incremental build + simulator dominate); full suite ~8–12 min |

Command shorthand used below: every `xcodebuild test` carries `-scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone Air'`; every `xcodebuild build` carries `-scheme EhPanda -destination 'generic/platform=iOS Simulator'` (SwiftLint runs at error severity inside the build).

---

## Sampling Rate

- **After every task commit:** Run the touched target's targeted suite (quick run command) — or `xcodebuild build` for build-gated tasks (12-01-02, 12-03, 12-04-02)
- **After every plan wave:** Run both affected targets in full (`-only-testing:SettingFeatureTests -only-testing:NetworkingFeatureTests`, plus `AppModelsTests` for wave 1)
- **Before `/gsd-verify-work`:** Full suite must be green AND the owner-signed live UAT (C1, 12-06 Task 2) must be recorded
- **Max feedback latency:** ~240 seconds (targeted simulator test run including incremental build)

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 12-01-01 | 01 | 1 | C5 (D-10) | T-12-02 | Error strings static/localized, no runtime interpolation of secrets | unit | `xcodebuild test … -only-testing:AppModelsTests/AppErrorStructuredTests` | ✅ (extends existing suite) | ⬜ pending |
| 12-01-02 | 01 | 1 | C5 (D-06) | T-12-01 | Clearance key is `InMemoryKey` only — never persisted | build + source assertion | `xcodebuild build …` | ✅ (build gate) | ⬜ pending |
| 12-02-01 | 02 | 2 | C2 (D-05, D-08) | T-12-04 | Untrusted headers exact-matched; no host/setting branches | unit | `xcodebuild test … -only-testing:NetworkingFeatureTests/CloudflareChallengeDetectionTests` | ❌ W0 (created test-first by this task) | ⬜ pending |
| 12-02-02 | 02 | 2 | C4 (D-04, D-07) | T-12-05 / T-12-06 | Explicit Cookie/UA authoritative; `httpShouldHandleCookies == false` asserted on recorded request | unit | `xcodebuild test … -only-testing:NetworkingFeatureTests/CloudflareChallengeDetectionTests` | ❌ W0 (extends same file) | ⬜ pending |
| 12-03-01 | 03 | 3 | C3, C4 (D-04) | T-12-08…T-12-12 | Non-persistent data store; no shared-jar writes (grep gate); no credential injection into web view | build + grep gates (WebKit behavior rides owner UAT) | `xcodebuild build …` | ✅ (build gate) | ⬜ pending |
| 12-03-02 | 03 | 3 | seam for C2–C5 tests | — | No domain-fronting conditional (grep gate) | build + grep gate | `xcodebuild build …` | ✅ (build gate) | ⬜ pending |
| 12-04-01 | 04 | 4 | C2, C3, C4, C5 (D-01…D-11) | T-12-16 / T-12-17 | Bounded rounds; stray captures ignored; no clearance in ErrorInfo context | build + pre-existing reducer suites (behavior suite lands 12-05, next wave — checker-accepted) | `xcodebuild build … && xcodebuild test … -only-testing:SettingFeatureTests` | ✅ (interim gate) | ⬜ pending |
| 12-04-02 | 04 | 4 | C3 (D-01, D-02, D-03, D-11) | T-12-14 | `.privacyMask()` on both new sheet roots (acceptance grep) | build + diff inspection | `xcodebuild build …` | ✅ (build gate) | ⬜ pending |
| 12-05-01 | 05 | 5 | C2, C3, C5 (D-06, D-09, D-10, D-11) | T-12-19 / T-12-20 | Synthetic fixtures only; per-test @Shared seeding | reducer (exhaustive TestStore) | `xcodebuild test … -only-testing:SettingFeatureTests/LoginChallengeFlowTests` | ❌ W0 (created test-first by this task) | ⬜ pending |
| 12-05-02 | 05 | 5 | C5 (D-02, D-11) + regression | T-12-19 | Exhaustive-store silence proves no retry/toast on cancel | reducer + affected-target gate | `xcodebuild test … -only-testing:SettingFeatureTests -only-testing:NetworkingFeatureTests` | ❌ W0 (extends same file) | ⬜ pending |
| 12-06-01 | 06 | 6 | C5 (+ Pitfall-5 contract) | T-12-22…T-12-24 | Privacy-mask inventory reconciled (39→41 / 38→40 / 41→43); cookie-logging + no-persistence + jar/DF grep gates | static gates + full suite | `xcodebuild test …` (full suite) | ✅ (gates + existing suites) | ⬜ pending |
| 12-06-02 | 06 | 6 | C1 | T-12-25 | Live clearance exchange under production TLS; mask verified in App Switcher | manual — owner UAT (blocking checkpoint; automated pre-check only) | `curl -sI 'https://forums.e-hentai.org/index.php?act=Login' \| grep -ci 'cf-mitigated'` (pre-check, not proof) | N/A — owner gate | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `AppPackage/Tests/NetworkingFeatureTests/CloudflareChallengeDetectionTests.swift` — covers C2 classification matrix + C4 header carriage via `CountingStubProtocol`; created test-first inside 12-02 Task 1 (`tdd="true"`), extended by Task 2
- [ ] `AppPackage/Tests/SettingFeatureTests/LoginChallengeFlowTests.swift` — covers C2 pass-through, C3 auto-dismiss, C5 bounded fail, D-02 cancel, D-06 session pair via exhaustive `TestStore`; created test-first inside 12-05 Task 1 (`tdd="true"`), extended by Task 2
- Framework install: none needed — Swift Testing + TCA `TestStore` infrastructure already in place (`FeatureTests.xctestplan`); the two files above are absorbed into their producing plans' TDD tasks rather than a standalone Wave 0

Seam note (from RESEARCH §Wave 0 Gaps): the WebKit half (cookie-store observer, `navigator.userAgent` readout) is not unit-testable through `TestStore`; it is isolated behind the `onClearance` callback + `LoginClient` seam (12-03) so the reducer half is fully testable, and the WebKit half rides the owner UAT (12-06 Task 2).

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Live end-to-end login through the real Cloudflare wall | C1 | Clearance is TLS-fingerprint-bound (RESEARCH Pitfall 2); no automated test can prove the live edge accepts the URLSession retry — owner UAT is the authoritative go/no-go gate | 12-06 Task 2 numbered steps: silent cancel (button + swipe-down), full login with spinner spanning the flow, App Switcher mask during challenge, optional session-reuse and failure-surface checks; owner resume signal recorded verbatim |
| ChallengeWebView WebKit behavior (observer fires, UA readout, non-persistent store) | C3, C4 | WKWebView/cookie-store behavior cannot run under `TestStore`; only static grep gates + build cover it offline | Exercised implicitly by 12-06 Task 2 steps 2–4 (auto-dismiss on clearance, successful retry with the captured UA, wall skipped on session reuse) |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies (12-06-02's automated line is a pre-check; its proof is the blocking human checkpoint, listed under Manual-Only)
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (both ❌ W0 files map to the TDD task that creates them)
- [x] No watch-mode flags
- [x] Feedback latency < 240s for targeted runs
- [ ] `nyquist_compliant: true` set in frontmatter — left false: 12-04's state machine lands one wave before its behavior suite (12-05), an interim-coverage gap the checker accepted as-is; compliance flips at validate-phase once the Wave 0 files exist and both suites are green

**Approval:** pending — sign-off completes at `/gsd-validate-phase` after execution (Wave 0 files created, suites green, owner UAT recorded)
