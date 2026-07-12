---
phase: 4
slug: concurrency-framework-migration
status: approved
nyquist_compliant: true
wave_0_complete: false
created: 2026-07-12
approved: 2026-07-13
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (not XCTest) |
| **Config file** | `AppPackage/Tests/…` test targets in `AppPackage/Package.swift`; no `-testPlan` for the package scheme |
| **Quick run command** | `xcodebuild build -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator'` (build+lint gate; grep log for `error:\|warning:`) |
| **Full suite command** | `cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air'` (≈436 tests; read the `✔ Test run with N tests` lines, not the XCTest counter) |
| **Estimated runtime** | ~300 seconds (full suite); one invocation at a time — never overlap xcodebuild test runs |

---

## Sampling Rate

- **After every task commit:** Run the quick build (AppFeature scheme) — clean build ⇒ lint clean (SwiftLint plugin runs in-build)
- **After every plan wave:** Run the full suite (`AppPackage-Package`)
- **Before `/gsd-verify-work`:** Full suite green + `grep -r "import Combine" AppPackage/Sources` empty + TCA deprecation grep empty
- **Max feedback latency:** ~300 seconds

---

## Per-Task Verification Map

*(Task IDs filled at plan approval 2026-07-13 from PLAN.md files 04-01…04-14; "Wave" is the
plan's execution wave. The Wave-0 baseline work maps to plans 04-02–04-05, which run before any
migration plan.)*

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| T1–T2 | 04-03, 04-04, 04-05 | 3–5 | CONC-01 | — | N/A | unit (fixture, no network) | Full suite — baseline suites lock URLRequest assembly parity (44 requests: url/method/headers/body) | ❌ W0 | ⬜ pending |
| T1–T2 | 04-03, 04-04, 04-05 | 3–5 | CONC-01 | — | N/A | unit | Full suite — parse-output parity per request on fixtures | ❌ W0 | ⬜ pending |
| T1–T2 (harness) + T1 (counts) | 04-02 + 04-03 | 2–3 | CONC-01 | — | N/A | unit (counting URLProtocol stub) | Full suite — retry counts (4 on transport failure; 1 on success; 1 for TagTranslator fetch₂) | ❌ W0 | ⬜ pending |
| T1 | 04-03 | 3 | CONC-01 | — | N/A | unit | Full suite — `mapAppError` mapping table incl. `ResponseParsingError` server-text path + `noUpdates` | ❌ W0 | ⬜ pending |
| every full-suite run; final gate T2 | 04-13 | 13 | CONC-01 | T-04-01 | DF routing preserved | unit | Existing `DFRequestSemanticsTests` (S1–S7) | ✅ | ⬜ pending |
| T2 | 04-13 | 13 | CONC-01 | — | N/A | smoke | `grep -r "import Combine" AppPackage/Sources` returns empty | ✅ (command) | ⬜ pending |
| every wave merge; final gate T2 | 04-13 | 13 | CONC-01 | — | N/A | regression | Full suite (existing reducer/TestStore tests unchanged) | ✅ | ⬜ pending |
| T1 | 04-14 | 14 | CONC-02 | — | N/A | build check (positive control) | Build log shows expected deprecation warning at a known site pre-fix | ✅ (command) | ⬜ pending |
| T3 | 04-14 | 14 | CONC-02 | — | N/A | smoke | Build app scheme + package; `grep -iE "warning:.*deprecat" build.log` (filter SwiftLint noise) returns empty | ✅ (command) | ⬜ pending |
| T3 + post-phase UAT | 04-14 | 14 | CONC-02 | T-04-32 | N/A | regression | Full suite green; existing UI flows via `/gsd-verify-work` UAT | ✅ | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*(Checkboxes track execution, not planning — they flip with `wave_0_complete` once the plans run.)*

- [ ] `AppPackage/Tests/NetworkingFeatureTests/RequestBaselineTests.swift` (or split per request family) — locks URLRequest assembly, parse fixtures, retry counts, `mapAppError` table against the **current Combine layer first** (D-05), covering CONC-01 → plans 04-03/04-04/04-05
- [ ] Counting `URLProtocol` stub + fixture loading in `NetworkingFeatureTests` (or `TestingSupport`) — keep stubs per-test-configured, no shared globals (DataCache.shared-style pollution lesson) → plan 04-02
- [ ] Prerequisite code seam: injectable `urlSession` on the requests that hard-code `URLSession.shared` (39 publisher sites) — Wave 0 may add the parameter (defaulted `.shared`, zero behavior change) so the baseline can execute offline → plan 04-01 Task 2

*(Framework install: none — Swift Testing already in use.)*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Traits applied positive control | CONC-02 | Requires reading a build log for an expected warning at a known site *before* fixes; guards against Xcode trait-application flakiness producing a false "zero deprecations" pass | Flip traits, build, confirm ≥1 expected TCA deprecation warning appears at a known `.destination?.case` scope site; only then fix and drive to zero |
| Reducer/store behavior identical in real UI flows | CONC-02 | End-to-end feel (navigation, sheet presentation) beyond TestStore coverage | Device/simulator UAT via `/gsd-verify-work` after execution |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references (plans 04-01 T2 seam, 04-02 harness, 04-03/04/05 baselines)
- [x] No watch-mode flags
- [x] Feedback latency < 300s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** approved 2026-07-13 — all sign-off criteria satisfied by plans 04-01…04-14
