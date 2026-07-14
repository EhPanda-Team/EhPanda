---
phase: 8
slug: architecture-hygiene-client-seams
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-14
requirements:
  HYG-01: pending
  QUAL-01: pending
  QUAL-02: pending
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Derived from
> `08-RESEARCH.md` §Validation Architecture. This is a **behavior/appearance-parity refactor** —
> the validation goal is to prove every seam swap preserves behavior: compile-time completeness +
> existing suites green + new deterministic seam tests + a cookie-logging static gate.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`import Testing`) + TCA `TestStore` / `withDependencies` |
| **Config file** | none (SPM test targets in `AppPackage/Package.swift`); test plan `AppPackage/Tests/FeatureTests.xctestplan` |
| **Quick run command** | `xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:<TargetUnderChange>` |
| **Full suite command** | `xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Build gate** | `xcodebuild build -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone 16'` |
| **Estimated runtime** | full suite ~40–60s; scoped target run ~5–15s |

> **Machine constraint:** xcodebuild invocations must **never overlap** on this machine (run one at a time; never `pkill -9` one mid-launch). Bare `swift build`/`swift test` do not work — Xcode-driven only.

---

## Sampling Rate

- **After every task commit:** quick build + the changed target's tests (`-only-testing:<Target>`); commit-per-task per repo convention.
- **After every plan wave:** full `xcodebuild test` suite (single invocation) — the Phase-4 `NetworkingFeature` baselines are the parity guard for the `galleryHost`-parameterization wave.
- **Before `/gsd-verify-work`:** full suite green **AND** SwiftLint clean (build-tool plugin, error-level, no suppressions) **AND** the cookie-logging static gate green.
- **Max feedback latency:** ~60 seconds (full suite).

---

## Phase Requirements → Test Map

| Req ID | Behavior to prove | Test Type | Automated Command / Evidence | File Exists? |
|--------|-------------------|-----------|------------------------------|--------------|
| HYG-01 | Utils folded/deleted; package compiles with no `*Util` / `.shared` / global-host reference remaining | build (compile-completeness) | `xcodebuild build …` + absence greps | n/a (build) |
| HYG-01 | `galleryHost` parameterization preserves every request URL (eh/ex) | integration (reuse) | full `NetworkingFeatureTests` (Phase-4 baselines) | ✅ existing |
| HYG-01 | Login-gating parity after `CookieUtil` delete (12 view sites) | unit | `CookieClientTests` `didLogin` matrix | ❌ Wave 0 |
| HYG-01 | 4 `DataCache` consumers share one injected instance; purge observer + `prefetchImages` bound to it | unit + manual | `ImageClientTests` cache-identity; device background-purge check | ❌ Wave 0 (+ manual) |
| QUAL-01 | No cookie value emitted to logs at `.public` privacy (audit found zero sites today) | static gate | cookie-logging grep assertion (below) + code review | ❌ Wave 0 (add gate) |
| QUAL-01 | ROADMAP + REQUIREMENTS reconciled to logging-audit-only scope (Keychain clause dropped, D-01) | docs audit | grep: no residual "Keychain" cookie clause in Phase-8 goal/criterion 2 / QUAL-01 | ❌ Wave 0 (docs task) |
| QUAL-02 | `CookieClient` seam matrix (`didLogin` eh/ex × igneous present/mystery/absent × expiry; `setCredentials`/`setSkipServer` `Set-Cookie` parsing; `syncExCookies`; `fulfillAnotherHostField`; `importAutomationCookies`) | unit | `-only-testing:CookieClientTests` | ❌ Wave 0 |
| QUAL-02 | `ImageClient` cache hit/miss + fetch-failure/placeholder handling, comparing **decoded pixel dimensions** | unit | `-only-testing:ImageClientTests` (per-test isolated `DataCache`) | ⚠️ partial — equivalent cases live in `DownloadsFeatureTests/ReaderImageDataTests.swift`; relocate/adapt into the dedicated target |
| QUAL-02 | `NetworkingFeature` async layer coverage | integration (reuse) | `-only-testing:NetworkingFeatureTests` | ✅ existing (Phase 4, D-09) |

*Per-task rows (`08-NN-MM` → Requirement → command) are assigned by the planner in the PLAN.md `<validation>`/`<verify>` fields and back-filled here during execution.*

---

## Cookie-Logging Static Gate (QUAL-01 / D-02)

A deterministic check the phase locks in (the audit found **zero** offending sites today — the job is to prove-and-gate, not fix):

- Sweep all `logger.{info,error,debug,notice,warning,fault,trace}` interpolations; assert none carry a cookie value (`ipb_member_id` / `ipb_pass_hash` / `igneous` values, or `getCookiesDescription`) at `.public` privacy.
- Confirm `getCookiesDescription` stays clipboard-only (`AccountSettingReducer.copyCookies`) and is never passed to a logger. The user-initiated cookie UI + clipboard export are **not logs** and are out of the audit's scope.
- Encode as a small script or a documented review checklist so a future regression is caught.

---

## Wave 0 Requirements

- [ ] `AppPackage/Tests/CookieClientTests/` — new test target + `.swiftlint.yml` (`parent_config`); covers HYG-01 login parity + QUAL-02 cookie matrix (hangs off `CookieClient.testing(...)` / `CookieClient.live(cookieStorage:)`).
- [ ] `AppPackage/Tests/ImageClientTests/` — new test target + `.swiftlint.yml`; covers QUAL-02 image seam. Relocate/adapt the existing `ReaderImageDataTests` cases; **per-test isolated `DataCache` instance**, compare decoded pixel dims (never a process-global — the known DataCache.shared test-pollution rule).
- [ ] `AppPackage/Package.swift` — two `Module` enum cases + two `testTarget` entries.
- [ ] Cookie-logging static gate (script or checklist) for QUAL-01.
- [ ] No framework install needed — Swift Testing + TCA already present.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Haptic feedback fires on the 4 migrated sites | HYG-01 | Haptic firing can't be asserted in a unit test | Device tap on EhSettingView+Sections3, CategoryView, SubSection, ArchivesView — confirm identical feedback |
| Host switch end-to-end (eh ↔ ex) | HYG-01 | Live network round-trip after `galleryHost` parameterization | Switch host in Settings; exercise a search / frontpage / favorites / detail request against the newly parameterized layer |

---

## Validation Sign-Off

- [ ] Every planned task has an `<automated>` verify path or a Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all `❌` / `⚠️` references above
- [ ] No watch-mode flags (single, non-overlapping xcodebuild invocations)
- [ ] Cookie-logging static gate green
- [ ] `nyquist_compliant: true` set in frontmatter once gaps close

**Approval:** pending
