# Phase 4: Concurrency & Framework Migration - Context

**Gathered:** 2026-07-12
**Status:** Ready for planning

<domain>
## Phase Boundary

Move EhPanda's request layer off Combine and onto async/await, and pin TCA with its
2.0 deprecation traits — at **request-behavior and reducer parity**. Delivers **CONC-01**
(networking + the four named clients migrated off Combine) and **CONC-02** (TCA pinned
`from: 1.25.3` with `ComposableArchitecture2Deprecations` + `ComposableArchitecture2DeprecationOverloads`,
all surfaced deprecations resolved to zero).

**What this phase is NOT:** it is not the structured-error-surface work (QUAL-04 / Phase 9) —
error *handling* stays behaviorally identical here; only the concurrency mechanism changes. It is
not the broader client-seam test coverage (CookieClient/ImageClient — QUAL-02 / Phase 8). It is not
a redesign of any request's semantics.

**Scouted scope reality (grounds the plan):**
- **44 `Request` structs** each expose `publisher: AnyPublisher<Response, AppError>` — this is the
  substantive migration.
- Consumed *only* through the already-async `response()` façade, at **64 reducer call sites** that
  already `await … .response()` and switch on `Result<_, AppError>`. Nothing consumes `.publisher`
  directly.
- **The four clients CONC-01 names — `ApplicationClient`, `AuthorizationClient`, `ImageClient`,
  `LibraryClient` — are already fully async/await.** Their `import Combine` is *dead* (no
  publisher/Future/Subject/sink usage). "Migrate off Combine" there = delete a dead import.
- The **entire** package Combine surface is exactly those 4 client files + the 7 NetworkingFeature
  files. After this phase, `grep -r "import Combine" AppPackage/Sources` must return **0**.

</domain>

<decisions>
## Implementation Decisions

### Façade shape (Area 1)
- **D-01:** Go **idiomatic `async throws`**, not the low-churn Result façade. Each request becomes
  `func response() async throws -> Response`; all **64 reducer call sites** move from `switch Result`
  to `do/catch`. Chosen over keeping `Result<Response, AppError>` because the owner prefers the modern
  Swift idiom even at higher blast radius.
- **D-02:** Use **typed throws — `throws(AppError)`** (Swift 6.3) so the compile-time `AppError`
  guarantee the current `Result<Response, AppError>` provides is preserved exactly. Requests already
  funnel everything through `mapAppError`, so the throwing body is a natural fit. Benefit compounds at
  call sites: inside a `.run` effect, `do { let x = try await req.response() } catch { … }` binds
  `error` as `AppError` directly — no `as? AppError` cast, no `.run(catch:)` untyped boundary.
- **D-03:** Reducer effect convention = `do/catch` **inside** the `.run` operation (leveraging D-02's
  typed binding), not the `.run(operation:catch:)` untyped-error parameter. Apply consistently across
  the 64 sites.
- **D-04:** Delete the Combine→async bridges once `publisher` is gone: the `Request.response()`
  continuation shim built on `Publisher.async()` / `asyncOutput()`, the `Publisher.genericRetry()`
  extension, and the `.receive(on: DispatchQueue.main)` hop in `response()` (TCA delivers reducer
  actions on the main/store scheduler, so the explicit hop is redundant).

### Parity-proof strategy (Area 2)
- **D-05:** Pull a **NetworkingFeature parity harness into Phase 4** using the Phases 1–3 **Wave-0
  method**: lock a baseline against *today's* Combine layer **first** (before the swap), then migrate,
  then prove the async layer produces identical results. This resolves the STATE.md concern
  ("NetworkingFeature parity tests must target the migrated async layer, not be silently deferred").
- **D-06:** The baseline/parity assertions cover, at minimum: **URLRequest assembly** (URL, method,
  headers, `httpBody`), **fixture-based parse output** per request, **retry count**, **`mapAppError`
  error mapping**, the **DF request transforms**, and the **multi-step chains** (notably
  `TagTranslatorRequest`'s two-step fetch + `noUpdates` early-out). No live network — mirror Phase 1's
  "`resume()` never called" pure-transform approach.
- **D-07:** The async rewrite **must expose a testable request-construction + parse seam** so D-06 is
  assertable offline. This is a design constraint on how requests are structured, not an afterthought.
- **D-08:** Scope boundary — **CookieClient/ImageClient** coverage (the rest of QUAL-02) stays in
  **Phase 8**. Only the NetworkingFeature slice is pulled forward.

### CONC-02 sequencing & deprecation containment (Area 3)
- **D-09:** **CONC-01 async migration lands and commits first**, then CONC-02. Rationale: the async
  migration deletes Combine/`EffectPublisher` effect code that would otherwise surface as TCA-2.0
  deprecations, and flipping traits first would churn code we're about to rewrite.
- **D-10:** CONC-02 first step = flip the two traits, then a **reconnaissance build to count and
  categorize** the surfaced deprecations *before* planning the fixes (size the unknown). Then resolve
  **all** to zero within Phase 4 (CONC-02 acceptance = zero TCA deprecation warnings).
- **D-11:** **Checkpoint with the owner only if** the deprecation surface is surprisingly large or
  entangled. Default intent is to contain CONC-02 entirely within Phase 4; splitting it out is a
  fallback, not the plan.
- **D-12:** Pin is `from: 1.25.3` (resolves to newest compatible 1.25.x); regenerate
  `AppPackage/Package.resolved`.

### Clients boundary (Area 4)
- **D-13:** Drop the vestigial `import Combine` from **all four** named clients — including
  `AuthorizationClient`, even though Phase 7 (UIARCH-05) deletes it wholesale — so CONC-01's "migrated
  off Combine" is literally true and the package ends fully Combine-free this phase. One-line change
  each, no behavior change. AuthorizationClient's full removal remains Phase 7's job.

### Claude's Discretion
- Exact structure of the async retry helper (preserving `retry(3)` = up to 3 re-subscribes / 4 total
  attempts, applied at the **network-fetch** scope only — parse/map steps are *not* retried, matching
  the current chains where `.genericRetry()` precedes the `tryMap` parse steps).
- URLSession async API choice (`data(for:)` vs `bytes(for:)`) — pick per request; `data(for:)` is the
  default expectation. Must route through the **injected per-request `URLSession`** so the DF session
  path is preserved.
- Whether the `Request` protocol requirement itself is restated as `func response() async throws(AppError) -> Response`
  or each struct implements the async body directly.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Requirements & roadmap (the locked contract)
- `.planning/REQUIREMENTS.md` §CONC — CONC-01 (Combine→async/await) and CONC-02 (TCA traits +
  deprecations) acceptance criteria.
- `.planning/ROADMAP.md` §"Phase 4: Concurrency & Framework Migration" — goal + 4 success criteria.
- `.planning/PROJECT.md` §Constraints/Key Decisions — parity bar, v1-schema freeze, "Combine→async/await
  stays in this milestone", lint-as-error.

### Codebase maps (already-analyzed context)
- `.planning/codebase/ARCHITECTURE.md` — TCA reducer/effect + `@DependencyClient` layering, request
  data-flow path.
- `.planning/codebase/INTEGRATIONS.md` — E-Hentai/ExHentai endpoints, DF/domain-fronting, Hath image
  hosts, GitHub/EhTagTranslation fetches.
- `.planning/codebase/STACK.md` — TCA pin, upcoming Swift features, toolchain.

### Cross-phase carry-forward (read for dependency awareness, do not action here)
- `.planning/STATE.md` §Blockers/Concerns — the Phase 8 QUAL-02 note (satisfied here by D-05) and the
  spike-gate lesson.

No external ADRs or design specs are referenced for Phase 4 — the contract is fully captured in the
requirements/roadmap above plus the decisions in this document.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- **`response()` façade** (`AppPackage/Sources/NetworkingFeature/Request.swift`) — the single public
  seam; today `async -> Result<Response, AppError>`, becomes `async throws(AppError) -> Response` (D-01/D-02).
- **`mapAppError(error:)`** (same file) — the error-mapping funnel; preserved verbatim, now feeding the
  `throw` path instead of `Publisher.mapError`.
- **`htmlDocument`/`parseResponse`/`htmlDocumentWithUTF8Fallback`** (same file) — pure parse helpers,
  unchanged; they become the fixture-testable parse seam (D-07).
- **DF stack** (`DFURLProtocol.swift`, `DFExtensions.swift`, `DFRequest.swift`, `DFStreamHandler.swift`,
  `DomainResolver.swift`) — the custom `URLSession` with `protocolClasses = [DFURLProtocol]`; Phase 1
  locked DF byte-identical. The async rewrite must keep routing through the injected per-request session.

### Established Patterns
- **Wave-0 baseline-lock-then-swap** (Phases 1–3) — the proven parity method reused for D-05/D-06:
  a test-first plan locks current behavior before the migration plans run.
- **`@DependencyClient` struct-of-closures with live/preview/unimplemented values** — the 4 clients
  already follow this and are already async; only their dead `import Combine` is removed (D-13).
- **Reducer effects already `await request.response()`** inside `.run` — so CONC-01's "consuming
  reducer effects" change is mechanical (`switch Result` → `do/catch`), not architectural.

### Integration Points
- **64 `.response()` call sites** across feature reducers (DetailFeature, CommentsReducer, AppRouteReducer,
  Home/Search/Favorites/Reading effects, …) — every one moves to `do/catch` (D-01/D-03).
- **`AppPackage/Package.swift`** — the TCA `.package(...)` entry (currently `from: 1.25.0`, no traits)
  gains `from: 1.25.3` + the two traits (D-12); `Package.resolved` regenerated.
- **`AppModels.AppError`** — the thrown/typed error; unchanged shape, now the typed-throws payload.

### Parity constraints locked (do not re-litigate)
- **DF/domain-fronting stays byte-identical** — custom `URLSession(protocolClasses:[DFURLProtocol])`,
  per-request session injection preserved.
- **`retry(3)` semantics preserved** — network-fetch scope only, not parse/map (D-Claude's-discretion).
- **`TagTranslatorRequest`** two-step (`published_at` date check → conditional `noUpdates` throw →
  download) preserved; other `flatMap` chains in `Request+Detail`/`Request+Image`/`Request+GalleriesMetadata`
  preserved.
- **No reducer/store behavior change** — CONC-02 success = zero deprecation warnings AND identical
  reducer/store behavior.

</code_context>

<specifics>
## Specific Ideas

- Owner explicitly chose the higher-churn, more-idiomatic path twice (idiomatic `async throws`, then
  typed `throws(AppError)`) — signal that Phase 4 should land as *modern, clean* async code, not a
  minimal shim. Write new code to the new bar.
- Acceptance verifiable by a single grep for the Combine-free goal: `grep -r "import Combine" AppPackage/Sources`
  must be empty after the phase.

</specifics>

<deferred>
## Deferred Ideas

- **Structured error surface / replace silent `try?`** (QUAL-04) — Phase 9. Error *handling* here stays
  behaviorally identical; only the concurrency mechanism changes.
- **CookieClient & ImageClient test coverage** (rest of QUAL-02) — Phase 8.
- **AuthorizationClient full removal + biometric re-auth path** (UIARCH-05) — Phase 7. Phase 4 only drops
  its dead `import Combine`.

None of the above were pulled into Phase 4 scope beyond what the decisions above state.

</deferred>

---

*Phase: 4-Concurrency & Framework Migration*
*Context gathered: 2026-07-12*
