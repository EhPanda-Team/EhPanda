# Phase 4: Concurrency & Framework Migration - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-07-12
**Phase:** 4-concurrency-framework-migration
**Areas discussed:** Façade shape, Parity-proof strategy, CONC-02 trait sequencing, Already-async clients boundary

---

## Façade shape

### Q1 — public entry-point signature

| Option | Description | Selected |
|--------|-------------|----------|
| Keep Result façade | Preserve `response() async -> Result<Response, AppError>`; only NetworkingFeature internals change; zero of 64 call sites touched | |
| Go idiomatic async throws | `response() async throws -> Response`; convert all 64 call sites from `switch Result` to `do/catch` | ✓ |
| Hybrid: throws internally, Result at seam | Requests throw internally; thin `response()` maps to Result at the boundary | |

**User's choice:** Go idiomatic async throws
**Notes:** Higher blast radius (64 call sites) accepted in favor of the modern Swift idiom, consistent with the project-wide "prefer newest API" preference.

### Q2 — error typing

| Option | Description | Selected |
|--------|-------------|----------|
| Typed throws(AppError) | `async throws(AppError) -> Response`; preserves the compile-time AppError guarantee the current `Result<_, AppError>` gives; most modern Swift 6.3 idiom | ✓ |
| Untyped throws | `async throws -> Response`; simpler, matches TCA `.run(catch:)`'s `any Error` boundary, but drops the compile-time AppError guarantee | |

**User's choice:** Typed throws(AppError)
**Notes:** Preserves the typed-error contract exactly. Payoff at call sites: inside a `.run` effect, `do/catch` binds `error` as `AppError` directly — no cast, no `.run(catch:)` untyped boundary.

---

## Parity-proof strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Pull NetworkingFeature tests into Phase 4 | Wave-0 baseline lock against today's Combine layer (request assembly, fixture parse, retry count, error mapping, DF transforms, multi-step chains), migrate, prove parity; CookieClient/ImageClient stay in Phase 8 | ✓ |
| Defer all tests to Phase 8 | Keep QUAL-02 whole in Phase 8; verify Phase 4 by manual device UAT only | |
| Thin smoke tests now, full in Phase 8 | Cover only DF path, retry count, multi-step chains now; bulk assembly/parse coverage deferred | |

**User's choice:** Pull NetworkingFeature tests into Phase 4
**Notes:** Reuses the proven Phases 1–3 Wave-0 method and resolves the STATE.md concern that NetworkingFeature parity tests must target the migrated async layer rather than being silently deferred. Requires the async rewrite to expose a testable request-construction + parse seam (no live network).

---

## CONC-02 trait sequencing

| Option | Description | Selected |
|--------|-------------|----------|
| CONC-01 first, then recon-then-sweep | Commit async migration first; then flip traits, reconnaissance build to size deprecations, resolve all to zero; checkpoint only if surprisingly large | ✓ |
| Traits first, one combined sweep | Flip traits before migration so all deprecations surface together in one pass | |
| Allow CONC-02 to split out if it balloons | Do CONC-01 first; split CONC-02 into a follow-up phase if the deprecation surface is large/entangled | |

**User's choice:** CONC-01 first, then recon-then-sweep
**Notes:** Async migration deletes Combine/EffectPublisher effect code that would otherwise register as deprecations; flipping traits first would churn code about to be rewritten. Reconnaissance build sizes the unknown before fix-planning. Splitting out remains a fallback, not the plan.

---

## Already-async clients boundary

| Option | Description | Selected |
|--------|-------------|----------|
| Drop dead import from all 4 now | Remove vestigial `import Combine` from ApplicationClient/ImageClient/LibraryClient/AuthorizationClient; package ends fully Combine-free | ✓ |
| Skip AuthorizationClient | Drop from the other 3 but leave AuthorizationClient untouched since Phase 7 deletes it | |

**User's choice:** Drop dead import from all 4 now
**Notes:** All four named clients are already async; the import is dead. Removing it from all four (including the Phase-7-doomed AuthorizationClient) makes CONC-01 literally true and leaves `grep -r "import Combine" AppPackage/Sources` empty. AuthorizationClient's full removal stays Phase 7's job.

---

## Claude's Discretion

- Exact async retry-helper structure preserving `retry(3)` (up to 3 re-subscribes / 4 total attempts), applied at network-fetch scope only (not parse/map).
- URLSession async API choice per request (`data(for:)` default vs `bytes(for:)`), always routed through the injected per-request session to preserve the DF path.
- Whether the `Request` protocol requirement is restated as an async typed-throws function or each struct implements the body directly.

## Deferred Ideas

- Structured error surface / replace silent `try?` (QUAL-04) — Phase 9.
- CookieClient & ImageClient test coverage (rest of QUAL-02) — Phase 8.
- AuthorizationClient full removal + biometric re-auth path (UIARCH-05) — Phase 7.
