---
phase: 9
slug: correctness-structured-error-handling
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-07-15
---

# Phase 9 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Source: 09-RESEARCH.md `## Validation Architecture`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Swift Testing (`import Testing`) |
| **Config file** | none — targets declared in `AppPackage/Package.swift` |
| **Quick run command** | `xcodebuild test -scheme AppPackage-Package -only-testing:<ModuleUnderEdit>Tests` (Xcode-only; ONE invocation at a time — never overlap) |
| **Full suite command** | `xcodebuild test -scheme AppPackage-Package` |
| **Estimated runtime** | quick ~15–25s per module · full suite ~50s |

*Bare `swift build`/`swift test` fails for this project — Xcode-only. Never run two `xcodebuild test` invocations concurrently (wedges testmanagerd).*

---

## Sampling Rate

- **After every task commit:** Run the quick command scoped to the module under edit (`-only-testing:AppModelsTests`, `-only-testing:ParserFeatureTests`, `-only-testing:AppFeatureTests`, …).
- **After every plan wave:** Run the full `AppPackage-Package` suite.
- **Before `/gsd-verify-work`:** Full suite green **and** SwiftLint clean.
- **Max feedback latency:** ~50 seconds (full suite).

---

## Per-Task Verification Map

> Task IDs are assigned when PLAN.md files are written; this seeds the map from the requirement→test map in 09-RESEARCH.md. The planner/executor refines Task ID + Plan + Wave per row.

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| TBD | TBD | TBD | QUAL-03 SC-1 | — | N/A | unit | `withExpectedIssue { #expect(Category.private.filterValue == 0) }` (AppModelsTests) | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | QUAL-03 | — | N/A | unit | assert filter-cases set excludes `.private`; `URLUtil.categoryValue` over a full filter never traps | ⚠️ verify | ⬜ pending |
| TBD | TBD | TBD | QUAL-04 | T-9-CTX | Context/env carry no secrets | unit | build `AppError` w/ context; assert `errorDescription`/`recoverySuggestion`/`solution` round-trip | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | QUAL-04 parity | — | N/A | unit | table test over all 12 cases: `isRetryable`/`alertText`/`symbol` unchanged | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | QUAL-04 | — | N/A | unit | `AnyHashableBox` literal ergonomics + `Hashable`/`Equatable` + dict keying | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | QUAL-04 SC-3 | — | Route carries error, not secrets | reducer (TestStore) | send present-error-info action; assert `destination == .errorInfo(error)` | ❌ W0 | ⬜ pending |
| TBD | TBD | TBD | QUAL-04 | T-9-CTX | Redact per whitelist | unit | per-module `try?` sweep parity: `ParserFeatureTests`/`DownloadsFeatureTests` green post-conversion | ✅ exist | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `AppModelsTests` — new `Category.private` `withExpectedIssue` test (QUAL-03 SC-1: returns 0 **and** issue fires)
- [ ] `AppModelsTests` — `AppError` context/solution/`LocalizedError` tests + all-12-cases parity table (QUAL-04, guards Pitfall 1)
- [ ] `AppModelsTests` — `AnyHashableBox` equality/hashing/literal-ergonomics tests
- [ ] `AppFeatureTests` — present-error-info → `.errorInfo` route test (QUAL-04 SC-3)
- [ ] Framework already present (Swift Testing) — no install needed

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Failure toast is tappable within its 3s window and opens `ErrorInfoView` | QUAL-04 SC-3 | Timed gesture + live presentation; the route resolution is automated (reducer test) but the tap-within-window affordance and sheet render are visual | On device/simulator, trigger a surfaced failure; within 3s tap the toast; confirm `ErrorInfoView` opens with Description / Solution / Context / Environment sections and a working close button |
| `.private.filterValue` raises a dev-time issue (purple runtime warning) in a debug **run** (not test) | QUAL-03 | The `reportIssue` runtime-warning UI is a debugger affordance; the automated proof is the `withExpectedIssue` test | In a Debug run, invoke `Category.private.filterValue`; confirm a non-fatal issue is reported and the app does not crash |

---

## Validation Sign-Off

- [ ] All tasks have an `<automated>` verify or a Wave 0 dependency
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (4 new test cases above)
- [ ] No watch-mode flags
- [ ] Feedback latency < ~50s
- [ ] `nyquist_compliant: true` set in frontmatter (after plan-checker verifies Dimension 8)

**Approval:** pending
