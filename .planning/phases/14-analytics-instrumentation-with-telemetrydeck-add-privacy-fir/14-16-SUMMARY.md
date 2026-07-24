---
phase: 14-analytics-instrumentation
plan: 16
completed: 2026-07-25
tasks_completed: 2
tasks_total: 2
requirements-completed: []
---

# 14-16 Summary: SettingFeature login instrumentation

**Classified login failures and per-round Cloudflare challenge encounters, emitted from the module that handles credentials — with the no-double-count exclusion and the credentials-never-leak guarantee both pinned by test.**

## What shipped

| Site | Signal | Placement |
|------|--------|-----------|
| Login failure | `loginFailed(LoginFailureKind)` | `loginDone` failure branch |
| Challenge detected | `cloudflareChallengeEncountered` | `challengeDetected`, **both** arms |

Login success emits nothing. Challenge cancellation emits nothing.

## The exclusion this plan turns on

The failure branch emits the classified login-failure signal **only**, never the generic `errorSurfaced`, even though it also raises an error toast. The classified signal is strictly more informative, and emitting both would count one failure twice and skew the error distribution toward login. This is the reason the generic error signal lives on the app-root toast action (plan 14-10) rather than in every reducer that raises a toast — and the exclusion is now enforced by a test that asserts an **exact one-element sequence**, not membership. A membership assertion would have passed even with the generic signal emitted alongside, which is the precise failure mode being guarded.

## The error-to-kind mapping

A `switch` over `AppError` with **no `default:` arm**:

| `AppError` | `LoginFailureKind` |
|---|---|
| `.loginCaptchaRequired` | `.captchaRequired` |
| `.cloudflareChallengeFailed` | `.cloudflareChallengeFailed` |
| `.networkingFailed` | `.networkingFailed` |
| `.unknown` | `.rejected` |
| everything else (11 cases, named explicitly) | `.other` |

`.unknown` maps to `rejected` because that is what a plainly refused credential produces — the case Phase 12 found had previously been invisible on screen. The absent `default:` arm means a new `AppError` case is a **compile error** in this function rather than a silent fall into `other`; that is a stronger guarantee than a test sweep could give, and the only one available, since `AppError` carries associated values and cannot be `CaseIterable`.

## Challenge encounters are per round

Emitted on every round, **including** the round that exhausts the bound and converts into a failure. That round emits both an encounter and a login-failure signal, because an encounter and a failure are different facts. The effect is that an exhausted-rounds sequence reads as three walls and one failure rather than as a single event — which is what makes the challenge bound's behavior legible in the data at all.

## What was deliberately not touched

Phase 12 recorded that this case's credential-setting ordering is load-bearing and was itself the subject of a bug: the response's credentials must reach the shared cookie jar **before** `didLogin` is read, or a successful post-challenge login is silently reported as a failure. The toast construction, its whitelisted diagnostics context, the round counter, the cancellation identifier and that ordering are all unchanged — verified by inspecting the diff for those tokens.

## Tests

`SettingFeatureTests/AnalyticsEmissionTests` → **TEST SUCCEEDED**. Full default plan → **759 tests, TEST SUCCEEDED**, zero warnings.

- Five-argument sweep over the four mapped errors plus one unmapped case exercising the catch-all kind.
- Seven-argument direct mapping assertion, independent of the reducer wiring.
- Exact one-element sequence for the failure case (the exclusion guard).
- Two empty-recorded-sequence assertions: successful login, and challenge cancellation.
- Sentinel username and password in the store's initial state, proven by reflection over the whole recorded signal graph to survive nowhere.
- Per-case `InMemoryStorage` isolates the process-wide `@Shared(.cloudflareClearance)` holder, matching this target's Phase 12 login suites so this suite neither pollutes nor is polluted by them.

## Deviations from plan

1. **`loginFailureKind(for:)` is a `static` method on the reducer rather than an inline mapping.** The plan asked for a `switch` at the emission site; extracting it keeps the emission line short and makes the classification directly testable without driving a store. The `switch` shape the plan required is preserved exactly.
2. **The direct-mapping test uses an explicit argument list, not `AppError.allCases`.** `AppError` carries associated values and is not `CaseIterable`; adding that conformance to production purely for a test's convenience was not justified, especially when the missing `default:` arm already gives a stronger, compile-time guarantee.

## Notes

- `ANALYTICS-01` remains `[ ]` — 14-17 closes it out.
- **Wave 6 is now complete.** All seven instrumentation plans (14-10 … 14-16) have landed and the full suite is green at 759 tests.
