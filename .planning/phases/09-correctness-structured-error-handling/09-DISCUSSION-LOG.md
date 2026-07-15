# Phase 9: Correctness & Structured Error Handling - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-15
**Phase:** 9-Correctness & Structured Error Handling
**Areas discussed:** optional_try escape hatch, AppError structure, Failure surface & routing, Category.private fix

---

## optional_try escape hatch

### Q1 — form for genuinely best-effort (Bucket A) sites

| Option | Description | Selected |
|--------|-------------|----------|
| Named `optionalTry{}` helper | Single free function `optionalTry { … }`; lint-clean, greppable intent marker | |
| Inline `do/catch→nil` | No new API; explicit per-site do/catch | |
| You decide / discuss | Weigh against anti-wrapper rule | |

**User's choice:** (reframed) do/catch defaulting to throw a proper `AppError`; when the error warrants the user's attention, surface it through `ErrorInfoView`. Applies to every site unless a decode intentionally falls back to a default value. Surviving `try?` sites get reported for the owner's personal review.
**Notes:** Rejected the "silent optional bucket" framing — default is throw-and-propagate, not swallow.

### Q2 — handling surviving `try?` at phase end

| Option | Description | Selected |
|--------|-------------|----------|
| Inventory doc + your review | External residual-`try?` inventory file | |
| Zero `try?` this phase | Rewrite even decode-with-default as explicit do/catch | |
| You decide / discuss | — | |

**User's choice:** Every surviving `try?` must be a deliberate exception by phase end, commented inline with the just cause to keep it.
**Notes:** Justification lives at the site, not in an external doc.

### Q3 — reconciling survivors with Phase 11 (optional_try at error, no swiftlint:disable)

| Option | Description | Selected |
|--------|-------------|----------|
| No true survivors | Rewrite decode-with-default so no literal `try?` remains | |
| Owner-blessed disable | Survivors keep `try?` + just-cause comment + owner-blessed `swiftlint:disable` at Phase 11 | ✓ |
| You decide / discuss | — | |

**User's choice:** Allow suppress statements for the exceptions.
**Notes:** Requires Phase 11 / LINT-01 "no swiftlint:disable" wording to carve out these owner-reviewed `optional_try` suppressions (flagged downstream, not edited now).

---

## AppError structure

### Q1 — shape for per-incident context + environment

| Option | Description | Selected |
|--------|-------------|----------|
| Kind enum + wrapping struct | `SurfacedError` wraps AppError + context + environment | |
| Associated context on cases | Each case gains `ErrorContext?` | |
| You decide / discuss | Lean wrapping struct | |

**User's choice:** Check the reference project's `AppError`.
**Notes:** Directed to an established design — read and extracted name-free: nested-category `AppError` (`LocalizedError, Hashable, Sendable, Identifiable`) with `context: [ContextKey: AnyHashableBox]`, computed `description`/`solution`/`context`/`symbol`, `ContextKey` string enum for labels, `AnyHashableBox` type-erasing box, `ErrorInfoView` Form surface, presentation reducer routing.

### Q2 — merge into EhPanda's existing flat AppError

| Option | Description | Selected |
|--------|-------------|----------|
| Keep cases, add context | Preserve cases + isRetryable/alertText; add `context` + `solution` + LocalizedError | ✓ |
| Restructure into categories | Reshape into nested category enums like the reference | |
| You decide / discuss | Lean keep-cases | |

**User's choice:** Keep cases, add context.
**Notes:** EhPanda's domain cases encode E-Hentai response semantics the reference's generic taxonomy would lose; keeps the ~10 ErrorView sites stable.

---

## Failure surface & routing

### Q1 — where the failure toast → ErrorInfoView surface lives

| Option | Description | Selected |
|--------|-------------|----------|
| Reusable failure-surface seam | Shared modifier bundling error toast + ErrorInfoView sheet | |
| Centralize at app root | One app-level `.errorInfo` route + failure toast on AppReducer/TabBarView | |
| Per-feature route | Each toast owner adds its own `.errorInfo` sheet | |
| You decide / discuss | Lean reusable seam | |

**User's choice:** Use `AppRouteReducer.Destination`, but rename it to `PresentationReducer`.
**Notes:** Leverage the reducer that already owns the app-root toast + destinations; add `.errorInfo(AppError)` there.

### Q2 — toast → detail affordance (given 3s auto-hide)

| Option | Description | Selected |
|--------|-------------|----------|
| Tap toast; persist until dismissed | AppError-bearing failure toasts don't auto-hide | |
| Tap toast; keep 3s auto-hide | Tap within the window opens ErrorInfoView | ✓ |
| You decide / discuss | Lean persist | |

**User's choice:** Tap toast; keep 3s auto-hide.

### Q3 — which failures get the tappable failure toast

| Option | Description | Selected |
|--------|-------------|----------|
| Secondary/action failures | ErrorView for primary loads; toast for secondary/action failures | |
| All AppError throw sites | Every throw fires the toast (double-surfaces primary loads) | |
| You decide / discuss | Lean secondary/action | |

**User's choice:** All AppError throw sites must ensure the error is carried to the nearest surface (most likely reducers); presentation-as-toast is decided per-site.
**Notes:** The rule is propagation (never swallow); toast-vs-ErrorView-vs-silent is a per-site reducer decision.

---

## Category.private fix

### Q1 — fix so filterValue can't trap

| Option | Description | Selected |
|--------|-------------|----------|
| Optional filterValue (nil) | `filterValue: Int?` = nil for .private | |
| Compile-time filter subset | Separate `FilterCategory` enum excluding .private | |
| Safe sentinel (0) + doc | Return 0 for .private + doc comment + test | |
| You decide / discuss | — | |

**User's choice:** Return 0 + doc + an assert method that crashes the dev env (production returns 0, dev-time report catches misuse). Likely PointFree `IssueReporting.reportIssue` so the test can assert both the 0 return and the fired issue.

---

## Claude's Discretion

- Exact set of AppError cases that gain `context`, and the concrete `ContextKey` members.
- Module placement of `AnyHashableBox` and `ErrorInfoView` / the context machinery.
- Per-site `try?` → do/catch conversion and per-reducer toast-vs-silent presentation decisions.
- Exact `IssueReporting` API for the D-13 dev-time report (research to confirm).

## Deferred Ideas

None — discussion stayed within phase scope.
