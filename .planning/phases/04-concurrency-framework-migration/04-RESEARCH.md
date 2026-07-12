# Phase 4: Concurrency & Framework Migration - Research

**Researched:** 2026-07-12
**Domain:** Swift concurrency migration (Combine → async/await with typed throws) + TCA 1.25.x deprecation traits
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

#### Façade shape (Area 1)
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

#### Parity-proof strategy (Area 2)
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

#### CONC-02 sequencing & deprecation containment (Area 3)
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

#### Clients boundary (Area 4)
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

### Deferred Ideas (OUT OF SCOPE)
- **Structured error surface / replace silent `try?`** (QUAL-04) — Phase 9. Error *handling* here stays
  behaviorally identical; only the concurrency mechanism changes.
- **CookieClient & ImageClient test coverage** (rest of QUAL-02) — Phase 8.
- **AuthorizationClient full removal + biometric re-auth path** (UIARCH-05) — Phase 7. Phase 4 only drops
  its dead `import Combine`.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| CONC-01 | Migrate Combine-based requests to async/await: `NetworkingFeature` returns async results (no `AnyPublisher`); `ApplicationClient`/`AuthorizationClient`/`ImageClient`/`LibraryClient` + consuming reducer effects off Combine; behavior/error paths preserved | Verified façade/retry/fan-out patterns compile on the pinned toolchain (§Code Examples); the four clients confirmed dead-import-only (§Codebase Facts); the closure catch-inference pitfall that would break D-02's ergonomics is identified with the working form (§Pitfall 1) |
| CONC-02 | Pin TCA `from: 1.25.3` with `ComposableArchitecture2Deprecations` + `ComposableArchitecture2DeprecationOverloads` traits; zero TCA deprecation warnings; identical reducer/store behavior | Traits verified verbatim in TCA's Package.swift at tag; exact `Package.swift` syntax from the official migration guide; the trait-gated deprecation list mapped against EhPanda by grep — surface pre-sized at ~24 sites, all one pattern (§Deprecation Surface) |
</phase_requirements>

## Summary

This phase is lower-risk than its size suggests, for two verified reasons. First, the Combine
surface is almost entirely mechanical: 44 `Request` structs share one pipeline shape
(`dataTaskPublisher → genericRetry → tryMap parse → mapError(mapAppError)`), consumed only through
the already-async `response()` façade at 64 call sites; the four named clients' `import Combine`
lines are confirmed dead. Second, the codebase **already resolves and builds against TCA 1.26.0
warning-free** (`AppPackage/Package.resolved` pins `swift-composable-architecture 1.26.0`), which
means every *hard* deprecation from the 1.25 wave is already handled — CONC-02's unknown is only
the *trait-gated* set, and a grep of that set against the codebase finds exactly **one pattern: 24
non-projected destination scope sites** (21 `.sheet`, 3 `.fullScreenCover`), all targeting reducer
cases, migrating to the projected `\.$destination` syntax. All other trait-gated APIs
(`Effect.concatenate`/`Effect.map`, `StorePublisher`, old `onChange`, `store.send(_:animation:)`)
have zero hits.

The one landmine this research defuses: **D-02's promised typed catch binding does not work with a
bare `do/catch` inside a TCA `.run` closure.** Compile probes on the pinned Swift 6.3.3 toolchain
prove that catch-type inference works in function bodies but *not* inside closures typed
`async throws` — there, `catch` binds `any Error`. The fix is one keyword: write
`do throws(AppError) { … } catch { … }` at the 64 sites, which binds `error: AppError` exactly as
D-02 intends. The same probes verify the typed-throws protocol requirement compiles, that
`Task<_, AppError>` typed init is **not** available on 6.3.3 (Swift 6.4 feature — don't design
around it), and that `Result { … }` closure inference fails (annotate or avoid).

**Primary recommendation:** Restate the `Request` protocol requirement as
`func response() async throws(AppError) -> Response`, funnel every network fetch through one
concrete `throws(AppError)` fetch-with-retry helper (4 total attempts, fetch scope only,
cancellation short-circuit), convert call sites with explicit `do throws(AppError)`, keep the
existing `Result<_, AppError>`-carrying `…Done` actions unchanged for literal reducer parity — then
flip both traits and burn down the pre-sized ~24-warning scope migration with a positive-control
check that the traits actually took effect in Xcode.

## Project Constraints (from CLAUDE.md)

Directives from the repository `AGENTS.md`/`CLAUDE.md` that bind this phase:

- **Reducer naming**: `Feature`/project-established suffixes stay as-is (project convention overrides
  TCA-skill naming guidance; existing types like `PopularReducer` keep their names — this phase does
  not rename reducers).
- **Read `.swiftlint.yml` before writing Swift**; resolve every violation at root; suppressions
  forbidden without explicit permission. Relevant here: `force_try`/`force_unwrapping` banned; custom
  TCA regex rules (e.g. `Scope(...child: Reducer.init)` form; `Delegate` enum as sibling of `Action`);
  line length 120 as error. The 64 call-site edits and new request bodies must be lint-clean from the start.
- **SwiftLint coverage for new modules**: no new modules are expected this phase; if one is added,
  it needs a `.swiftlint.yml` with `parent_config`.
- **No absolute home paths in generated docs**; **never record local reference project names** —
  both honored in this document and binding on PLAN/SUMMARY artifacts.
- **Confirmation dialog/alert placement rule**: the 24 sheet/fullScreenCover scope-syntax migrations
  touch presentation modifiers — the migration must not move any modifier off its stable
  action-source anchor (it's a pure argument-syntax change; keep attachments where they are).
- All third-party dependency changes go in `AppPackage/Package.swift`, never the Xcode project.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Request construction + fetch + retry | `NetworkingFeature` (request layer) | — | Owns `URLRequest` assembly, session routing (incl. DF), retry policy; the only tier that touches `URLSession` |
| HTML/JSON parse + error mapping | `NetworkingFeature` (pure helpers) → `ParserFeature` | — | `htmlDocument`/`parseResponse`/`mapAppError` stay pure and fixture-testable (D-07 seam) |
| Effect orchestration (`do/catch`, `send`) | Feature reducers (`.run` effects) | `DownloadClient` (plain async fns) | 57 of 64 `.response()` sites are reducer effects; 7 live in `DownloadClient` async functions (no `send`, plain `throws`/`Result` handling) |
| TCA dependency pin + traits | `AppPackage/Package.swift` | `AppPackage/Package.resolved` | Single source of truth for deps; traits are declared on the `.package` entry of the root package (AppPackage) |
| Deprecation-free UI scoping | Feature views (24 sheet/cover sites) | — | Projected `\.$destination` syntax is a view-layer argument change; reducers unchanged |
| Parity proof | `NetworkingFeatureTests` | — | Wave-0 baseline against Combine layer, re-run against async layer; extends existing `DFRequestSemanticsTests` no-live-network approach |

## Standard Stack

### Core

No new libraries. This phase changes *versions and mechanisms*, not dependencies.

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| swift-composable-architecture | floor `from: "1.25.3"` (resolves 1.26.0, already in `Package.resolved`) | Reducers/effects; 2.0-prep deprecation traits | Already the app architecture; 1.25.3 is the first tag with the `ComposableArchitecture2DeprecationOverloads` trait [VERIFIED: gh api releases — trait added in 1.25.3, published 2026-03-27] |
| Foundation `URLSession` async API | iOS 26 SDK | `data(for:)` replaces `dataTaskPublisher` | Native async; participates in task cancellation; no auto-retry (matches the explicit `retry(3)` policy) [CITED: developer.apple.com URLSession docs; Swift forums 65041] |
| Swift 6.3.3 toolchain (Xcode 26.6) | installed, verified | Typed throws (`throws(AppError)`) | SE-0413 base features verified working by compile probe on this exact toolchain [VERIFIED: local swiftc probes] |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| `withThrowingTaskGroup` | stdlib | Fan-out for `GalleryNormalImageURLRequest` (N thumbnail fetches → collect) | Only request using Combine `flatMap`+`collect` fan-out; group throws untyped — wrap in `do`/map to `AppError` at the boundary |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `data(for:)` | `bytes(for:)` | Only useful for streaming consumption; every current request buffers full bodies (`$0.data`) — `data(for:)` everywhere preserves behavior. No request needs `bytes` |
| Concrete `throws(AppError)` fetch helper | Generic-over-error `retrying<T, E: Error>` helper | Generic form compiles but trailing closures at call sites need explicit `throws(E)` annotations (verified probe) — noise at 40+ fetch sites. Concrete helper wins |
| Keeping `response()` as protocol extension over a new async primitive | Making `response()` the protocol requirement | Requirement form (`func response() async throws(AppError) -> Response`) verified to compile with associatedtype; it deletes `publisher` from the protocol in one move and makes conformance the migration checklist. **Recommended** (Claude's-discretion area) |

**Installation:** No new packages. Manifest edit only:

```swift
// AppPackage/Package.swift — replaces the current entry (from: "1.25.0", no traits)
.package(
    url: "https://github.com/pointfreeco/swift-composable-architecture",
    from: "1.25.3",
    traits: [
        "ComposableArchitecture2Deprecations",
        "ComposableArchitecture2DeprecationOverloads"
    ]
)
```

[VERIFIED: syntax verbatim from TCA's official MigratingTo1.25 guide fetched at tag 1.26.0]

**Version verification:** `gh api repos/pointfreeco/swift-composable-architecture/releases` confirms
1.25.3 (2026-03-27), 1.25.4, 1.25.5 (2026-04-02), and latest **1.26.0 (2026-06-09)**. Note:
`from: "1.25.3"` resolves to **1.26.0** under semver — which is *already* the resolved version in
`AppPackage/Package.resolved`, so resolution output is expected to be unchanged (manifest floor +
traits are the real diff; `Package.resolved` may only change its `originHash`). D-12's "newest
compatible 1.25.x" wording is superseded by reality: newest compatible is 1.26.0, already in use.

## Package Legitimacy Audit

No new packages are installed this phase. The only dependency change is a version-floor bump +
trait flags on the existing, long-standing `pointfreeco/swift-composable-architecture` dependency
(already resolved at 1.26.0 in `Package.resolved`; canonical Point-Free repository; verified via
GitHub API this session).

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

TCA's traits were additionally verified to be deprecation-only — its `dependencies:` array at tag
1.26.0 is unconditional (no trait-gated dependencies), so enabling traits cannot change dependency
resolution. [VERIFIED: raw Package.swift at tag 1.26.0]

## Codebase Facts (verified by grep/read this session)

These ground the plan's task sizing:

- **44 `Request` structs** conform via `var publisher: AnyPublisher<Response, AppError>` across
  `Request.swift`, `Request+Account/Detail/GData/GalleriesMetadata/Gallery/Image.swift`.
- **64 `.response()` call sites** total: 57 in reducer `.run` effects across 21 files
  (Home/Search/Favorites/Detail/Reading/Setting/AppFeature), **7 in `DownloadClient`**
  (`+ExecutionSupport` 5, `+ExecutionFetch` 2) which are *plain async functions*, not effects —
  they use `.get()`/`switch` on the Result today and become straight `try await` (their enclosing
  functions can carry `throws(AppError)` or map locally).
- **39 hard-coded `URLSession.shared.dataTaskPublisher` sites** vs. injected-`urlSession` requests
  (all of `Request+GData`, most of `Request+Image`/`+Detail`/`+GalleriesMetadata` take a session; DF
  paths inject `URLSessionConfiguration.domainFronting` sessions). The async rewrite should give
  every request the same injectable `urlSession: URLSession = .shared` seam — required by D-07 so
  the parity harness can substitute a counting `URLProtocol` stub session *per request* instead of
  global `URLProtocol.registerClass` hacks.
- **`genericRetry()` placement**: always attached directly to `dataTaskPublisher` (fetch scope,
  before `tryMap` parse). Asymmetry to preserve: `TagTranslatorRequest`'s **second** fetch (the
  download inside `flatMap`) has **no retry**; `GalleryNormalImageURLRequest`'s inner per-thumbnail
  fetches **do** retry. Retry parity is per-fetch-step, not per-request.
- **`AppError.noUpdates` is control flow**: `TagTranslatorRequest` throws it when GitHub's
  `published_at` isn't newer — callers treat it as benign. The typed-throws body preserves this
  as a plain `throw AppError.noUpdates`.
- **Response payloads that carry `HTTPURLResponse`**: `LoginRequest` (`HTTPURLResponse?`),
  `VerifyEhProfileRequest`-adjacent (`compactMap $0.response as? HTTPURLResponse`), and
  `GalleryPreviewURLsRequest` area (`([Int: URL], HTTPURLResponse?)`). `data(for:)` returns
  `(Data, URLResponse)` so these map 1:1.
- **The four clients** (`ApplicationClient`, `AuthorizationClient`, `ImageClient`, `LibraryClient`):
  `import Combine` confirmed present and confirmed dead (no publisher/Future/Subject/sink usage) —
  D-13 is literally four one-line deletions.
- **Combine-free acceptance grep**: after this phase `grep -r "import Combine" AppPackage/Sources`
  must return 0 (today: exactly the 4 client files + 7 NetworkingFeature files).
- **Existing `.run(operation:catch:)` untyped handlers** (~10, in `DetailReducer+Download`,
  `FolderManagerReducer`, `PreviewsReducer`): these wrap *DownloadClient/file* work, not
  `.response()` calls, and are **out of scope** for the D-03 convention sweep (only `.response()`
  consumers move to `do throws(AppError)`).

## Deprecation Surface (CONC-02 pre-sized)

The codebase **already builds warning-free against TCA 1.26.0**, so every *hard* 1.25 deprecation
(`BindingViewState`/`BindingViewStore`, `Store.withState`, `Effect.animation/transaction/debounce/throttle`,
enum-state `Scope`, direct `Reducer.reduce`) is already absent — confirmed by grep. The recon build
(D-10) therefore only surfaces the **trait-gated** set [VERIFIED: official MigratingTo1.25.md at tag 1.26.0]:

| Trait-gated API | EhPanda hits (grep) | Migration |
|---|---|---|
| `$store.scope(state: \.destination?.case, action: \.destination.case)` (non-projected) | **24** (21 `.sheet`, 3 `.fullScreenCover`, across ReadingFeature, FavoritesFeature, HomeFeature ×4 screens, SearchFeature ×3, DetailFeature ×3 files) | `$store.scope(state: \.$destination, action: \.destination).case` |
| `Effect.concatenate`, `Effect.map` | 0 | — |
| `StorePublisher` / `store.publisher` | 0 | — |
| Old `onChange` (reducer-builder, `(old, new)`) | 0 — `AccountSettingReducer` already uses the new streamlined `(old, state) -> Effect` overload | — |
| `store.send(_:animation:)` (trait-deprecated in 1.25.3) | 0 | — |

**Key structural luck:** all 24 sites scope to **reducer cases** of `@Reducer enum Destination`.
The migration guide's two hairy sub-cases — non-reducer data cases needing `Identifiable` or
`Binding(...)`/`isPresented` conversion, and `@ReducerCaseIgnored` cases needing an explicit
`@CasePathable enum Action` — do **not** apply: EhPanda's `@ReducerCaseIgnored` data cases
(`share(URL)`, `newDawn(Greeting)`, `tagDetail(TagDetail)`, `postComment`, alerts) are already
presented via `$store.destination.case` **bindings**, not deprecated scopes, and no Destination
holds an `AlertState` case requiring the new explicit-Action treatment through a deprecated scope.
Expected recon result: **≈24 warnings, one mechanical pattern**. If recon materially exceeds this
(e.g. overload-trait warnings appearing in unexpected places), that's the D-11 checkpoint trigger.

Also note from 1.25 release history: **1.25.0 temporarily deprecated `Effect` in favor of
`EffectOf`, and 1.25.3 reverted that** ("Un-trait deprecate `Effect`… no longer a need to
pre-migrate `Effect` code for 2.0"). EhPanda's ~10 `Effect<Action>` type annotations are fine —
do not churn them. [VERIFIED: 1.25.3 release notes via gh api]

## Architecture Patterns

### System Architecture Diagram

```
Reducer .run effect (57 sites)          DownloadClient async fns (7 sites)
        │                                        │
        │  do throws(AppError) {                 │  try await …  /  do-catch
        ▼                                        ▼
   Request.response() async throws(AppError) -> Response      ← protocol requirement (D-01/D-02)
        │
        ├─► URLRequest assembly (urlRequest(url:allowsCellular:), POST bodies, headers)   ── pure, testable (D-07)
        │
        ├─► fetch helper: session.data(for:) + retry×4, fetch-scope only (helper below)
        │        │
        │        └─► injected URLSession (default .shared │ DF: protocolClasses=[DFURLProtocol])  ── unchanged byte-path
        │
        ├─► parse seam: htmlDocument / htmlDocumentWithUTF8Fallback / parseResponse / JSONDecoder  ── pure, unchanged
        │
        └─► error funnel: mapAppError(error:) → throw AppError                                     ── unchanged mapping table
                 │
                 ▼
        catch { error: AppError }  →  send(.…Done(.failure(error)))   /   throw error (client)
```

Multi-step chains stay inside the one `response()` body as straight-line async
(TagTranslator: fetch₁ → date check → `throw .noUpdates` early-out → fetch₂;
GalleryNormalImageURL: task-group fan-out → collect).

### Recommended Project Structure

No new files/modules required. Changes live in:

```
AppPackage/Sources/NetworkingFeature/   # Request.swift protocol + 6 Request+*.swift bodies rewritten
AppPackage/Sources/{21 feature dirs}/   # 57 .run call sites → do throws(AppError)
AppPackage/Sources/DownloadClient/      # 7 plain-async call sites
AppPackage/Sources/{4 client dirs}/     # 4 dead `import Combine` deletions
AppPackage/Package.swift                # TCA floor + traits
AppPackage/Tests/NetworkingFeatureTests/ # Wave-0 parity harness (new files) + existing DF tests
```

### Pattern 1: Typed-throws protocol requirement (recommended for the discretion area)

**What:** Replace the `publisher` requirement with the async one; delete the Result façade.

```swift
// Source: verified to compile via swiftc 6.3.3 probe (protocol + associatedtype + typed throws)
public protocol Request {
    associatedtype Response: Sendable
    func response() async throws(AppError) -> Response
}
```

**When to use:** Everywhere — making it the requirement turns "which structs still need migrating"
into a compiler error list, and guarantees no `publisher` stragglers. The alternative (per-struct
async bodies + extension façade) leaves the protocol carrying a dead requirement mid-migration.

### Pattern 2: Concrete fetch-with-retry helper (Claude's-discretion recommendation)

**What:** One non-generic-over-error helper that owns `retry(3)` parity: 4 total attempts, retries
**only** `URLError`s from the fetch (never parse errors — they happen after the helper returns),
short-circuits on cancellation.

```swift
// Semantics verified against Combine: retry(3) = up to 3 re-subscribes (4 total attempts) of the
// upstream dataTaskPublisher only; tryMap failures pass through retry untouched.
extension Request {
    public func fetch(
        _ request: URLRequest,
        in session: URLSession = .shared
    ) async throws(AppError) -> (data: Data, response: URLResponse) {
        var lastError: any Error = URLError(.unknown)
        for attempt in 1...4 {
            do {
                return try await session.data(for: request)
            } catch {
                // data(for:) throws URLError(.cancelled) when the surrounding Task is cancelled;
                // Combine's retry never re-subscribes after cancellation — mirror that.
                if (error as? URLError)?.code == .cancelled || Task.isCancelled {
                    throw mapAppError(error: error)
                }
                lastError = error
                _ = attempt
            }
        }
        throw mapAppError(error: lastError)
    }
}
```

**When to use:** every retried fetch step (39 `.shared` sites + injected-session sites). For the
un-retried steps (TagTranslator's second download), call `session.data(for:)` directly inside a
`do`/`mapAppError` — do **not** route through the helper, preserving the current asymmetry.

**Why not generic over `E: Error`:** verified probe — a generic `throws(E)` helper compiles, but
call-site trailing closures don't infer the typed error (`{ try await f() }` fails to convert
`any Error` → `E`); every call would need `{ () throws(AppError) in … }` noise.

### Pattern 3: Call-site convention — explicit `do throws(AppError)` (load-bearing)

**What:** The D-03 convention, with the one keyword that makes D-02's typed binding actually work
inside `.run` closures (see Pitfall 1).

```swift
// Before (PopularReducer):
return .run { send in
    let response = await PopularGalleriesRequest(filter: filter).response()
    await send(.fetchGalleriesDone(response))
}

// After — action payload unchanged (still Result<_, AppError>), reducer Done handler unchanged:
return .run { send in
    do throws(AppError) {
        let galleries = try await PopularGalleriesRequest(filter: filter).response()
        await send(.fetchGalleriesDone(.success(galleries)))
    } catch {
        await send(.fetchGalleriesDone(.failure(error)))   // error: AppError — no cast
    }
}
.cancellable(id: CancelID.fetchGalleries)
```

**When to use:** all 57 reducer sites. **Keep the `…Done(Result<_, AppError>)` action payloads and
their handlers untouched** — this preserves reducer behavior *literally* (same actions, same
`Equatable` payloads, existing tests and TestStore assertions unaffected), which is the parity bar.
Sites that today `switch await …response()` inline in the effect (e.g. `SettingReducer+Helpers`
TagTranslator, `DownloadClient`) convert their switch to `do/catch` per D-01. Restructuring Done
actions into separate success/failure cases is QUAL-04/Phase 9 territory — out of scope.

### Pattern 4: Fan-out chain (`GalleryNormalImageURLRequest`)

```swift
// Combine today: thumbnailURLs.publisher.flatMap { inner fetch+parse }.collect()
//   — unlimited concurrency; one failure cancels the rest; order restored via index keys.
public func response() async throws(AppError) -> ([Int: URL], [Int: URL]) {
    do {
        return try await withThrowingTaskGroup(
            of: (index: Int, imageURL: URL, originalImageURL: URL?).self
        ) { group in
            for (index, url) in thumbnailURLs {
                group.addTask {
                    let (data, _) = try await fetch(
                        urlRequest(url: url, allowsCellular: allowsCellular), in: urlSession
                    )
                    let doc = try htmlDocument(data: data)
                    return try parseResponse(doc: doc) {
                        try Parser.parseGalleryNormalImageURL(doc: $0, index: index)
                    }
                }
            }
            var imageURLs = [Int: URL](); var originalImageURLs = [Int: URL]()
            for try await info in group {
                imageURLs[info.index] = info.imageURL
                originalImageURLs[info.index] = info.originalImageURL
            }
            return (imageURLs, originalImageURLs)
        }
    } catch {
        throw mapAppError(error: error)   // group throws untyped — funnel at the boundary
    }
}
```

Task-group failure cancels sibling children, matching Combine's subscription teardown on inner
failure; per-child `genericRetry` placement is preserved by calling the retry helper *inside* each
child. Note the group closure throws untyped, so this body uses the `do`/`mapAppError` funnel
rather than typed propagation — acceptable because the function signature still guarantees
`throws(AppError)`.

### Pattern 5: Projected destination scope (the 24 CONC-02 sites)

```diff
 .sheet(
-    item: $store.scope(state: \.destination?.filters, action: \.destination.filters)
+    item: $store.scope(state: \.$destination, action: \.destination).filters
 ) { store in
     FiltersView(store: store)
 }
```

[VERIFIED: official MigratingTo1.25.md]. Purely a view-layer argument change; `@Presents var
destination` and the reducers are untouched. The CLAUDE.md dialog-placement rule is unaffected
(modifiers stay on their anchors).

### Anti-Patterns to Avoid

- **Bare `do { } catch { }` in `.run` closures expecting `AppError`:** binds `any Error` (verified) —
  always write `do throws(AppError)`.
- **`Task { try await request.response() }` wrappers:** `Task<_, AppError>` typed init doesn't exist
  on Swift 6.3.3 (verified compile error — it's a 6.4 feature); effects don't need `Task` anyway.
- **`Result { try await … }` / `Result(catching:)` for async work:** stdlib `init(catching:)` is
  sync-only and closure typed-throw inference fails (verified). Build `.success`/`.failure`
  explicitly in the do/catch arms.
- **Routing *parse* steps through the retry helper:** silently changes behavior — today a parse
  failure is never retried; a flaky-HTML retry loop would hammer E-Hentai 4×.
- **Adding `@MainActor` or main-queue hops to replace `receive(on: DispatchQueue.main)`:** the hop
  is dead weight for async callers — the awaiting function resumes on its own executor regardless of
  the thread the continuation resumed from, and TCA marshals `send` to the store. Delete it (D-04),
  add nothing.
- **Churning `Effect<Action>` → `EffectOf<…>`:** 1.25.3 reverted that deprecation; not needed for 2.0.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Publisher→async bridging | Any new continuation shim (`withCheckedThrowingContinuation` over sinks) | `URLSession.data(for:)` directly | The existing shim is the thing being deleted (D-04); native async is cancellation-aware, the shim is not |
| Concurrency fan-out | Manual child-`Task` arrays + manual cancellation | `withThrowingTaskGroup` | Group handles sibling cancellation on failure and structured lifetime |
| Generic retry combinator library | Generic-over-error/policy retry types | The one concrete `throws(AppError)` fetch helper | Only one policy exists in the app (`retry(3)`, fetch scope); generic form fights closure inference (verified) |
| Deprecation discovery | Reading TCA source to guess the deprecation set | The trait flags + a recon build (D-10) | The traits *are* the discovery mechanism; the surfaced warnings are the exact worklist |
| Main-thread delivery | `MainActor.run`/`DispatchQueue.main` result hops | Nothing — TCA `send` handles marshaling | Reducer actions are processed on the store's executor; extra hops add latency and imply a false invariant |

**Key insight:** every piece of Combine machinery in this layer exists to emulate what async/await
does natively (sequencing, error funneling, cancellation, fan-out). The migration is a *deletion*
project wearing a rewrite costume — resist adding any new abstraction beyond the one fetch helper.

## Runtime State Inventory

This is a mechanism refactor, not a rename/data migration — checked each category explicitly:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no persisted schema, key, or identifier changes; `@Shared` models untouched (v1-schema freeze holds) | none |
| Live service config | None — E-Hentai/ExHentai/GitHub endpoints, DF domain table, and request shapes are byte-identical by requirement | none |
| OS-registered state | None — background task id (`app.ehpanda.downloads.processing`) and entitlements untouched | none |
| Secrets/env vars | None — no secret config exists in this app (cookies handled by CookieClient, out of scope) | none |
| Build artifacts | `AppPackage/Package.resolved` (+ the Xcode workspace's `Package.resolved` mirror) after the manifest edit; stale DerivedData may mask/echo trait changes | re-resolve; if trait warnings behave inconsistently, clear DerivedData (known Xcode trait-caching flakiness) |

## Common Pitfalls

### Pitfall 1: Typed catch binding silently degrades to `any Error` inside `.run` closures
**What goes wrong:** `do { try await req.response() } catch { }` inside a TCA `.run` operation binds
`error` as `any Error`, not `AppError` — `send(.done(.failure(error)))` then fails to compile (or
worse, invites an `as? AppError ?? .unknown` cast that D-02 explicitly wanted to eliminate).
**Why it happens:** catch-type inference (SE-0413) works in function bodies but defers to the
closure's own error type inside closures typed `async throws` — `.run`'s operation is exactly that.
[VERIFIED: swiftc 6.3.3 compile probes — function-body inference OK (throwing and non-throwing
contexts), closure-body inference fails, explicit form works.]
**How to avoid:** the convention is `do throws(AppError) { … } catch { … }` — explicit at all 57
reducer sites. (The 7 DownloadClient sites are function bodies where inference works, but use the
explicit form there too for grep-able consistency.)
**Warning signs:** any `as? AppError`, `?? .unknown`, or `error as! AppError` appearing in a new
call site — the convention slipped.

### Pitfall 2: Traits silently not applied by the build
**What goes wrong:** traits flip in `Package.swift`, the recon build shows zero new warnings, and
CONC-02 is declared done — but the traits never took effect (Xcode trait support is recent and has
known caching/ignoring bugs; project-settings trait UI only exists since Xcode 26.4).
**Why it happens:** Xcode's SwiftPM integration lagged SwiftPM's SE-0450 implementation; stale
DerivedData can pin the old trait set. [CITED: forums.swift.org/t/82819, massicotte.org
"Package Traits in Xcode"; installed Xcode is 26.6 ≥ 26.4]
**How to avoid:** the recon build needs a **positive control**: before fixing anything, confirm the
build surfaces the expected deprecation at a known site (any of the 24 non-projected scopes, e.g.
`PopularView.swift:36`). Zero warnings at recon = traits not applied → clean DerivedData /
re-resolve, don't proceed.
**Warning signs:** recon count is 0; warnings don't change after edits.

### Pitfall 3: Retry behavior drift (scope, count, cancellation)
**What goes wrong:** subtle non-parity — retrying parse failures, retrying the TagTranslator second
fetch (never retried today), off-by-one attempt counts (`retry(3)` = **4** total attempts), or
spinning retries after effect cancellation.
**Why it happens:** the Combine placement (`genericRetry` directly on `dataTaskPublisher`, upstream
of `tryMap`) is easy to misread as whole-chain retry; async loops don't inherit Combine's
cancellation teardown.
**How to avoid:** D-06's baseline locks per-request retry counts via a counting `URLProtocol` stub
*before* the swap; the helper short-circuits on `URLError(.cancelled)`/`Task.isCancelled`.
**Warning signs:** parity test shows attempt counts ≠ 4 for retried steps or ≠ 1 for the
TagTranslator download step.

### Pitfall 4: Cancellation semantics change (accept, but knowingly)
**What goes wrong:** confusion at review time — today's continuation shim is *not*
cancellation-aware (cancelling a TCA effect leaves the HTTP request running; the late result is
discarded); after migration, cancellation propagates into `URLSession` and `data(for:)` throws
`URLError(.cancelled)` → mapped to `.networkingFailed` → sent from a cancelled effect → **discarded
by TCA**. Net user-visible behavior: identical; resource behavior: strictly better.
**Why it happens:** native async URLSession participates in structured cancellation; the old bridge
didn't. [CITED: forums.swift.org/t/65041 — Task cancellation propagates to URLSession tasks,
throwing URLError, not CancellationError]
**How to avoid:** document this as the one intentional non-byte-identical delta in the plan; don't
"fix" it by detaching tasks.
**Warning signs:** anyone adding `Task.detached` to restore fire-and-forget semantics.

### Pitfall 5: The `…Done(Result)` switch handlers are NOT part of the 64-site sweep
**What goes wrong:** over-eager interpretation of D-01 ("call sites move from switch Result to
do/catch") rewrites the *reducer action handlers* (`case .fetchGalleriesDone(let result): switch
result …`) into new action shapes — churning 20+ reducers' state machines and their tests, breaking
the "reducers/stores behave identically" acceptance.
**Why it happens:** the word "call site" is ambiguous; the actual `switch Result` at the *await*
sites (e.g. TagTranslator helper, DownloadClient) vs. the Done-handler switches look similar.
**How to avoid:** scope = the 64 `.response()` **await sites** only. Done actions keep their
`Result<_, AppError>` payloads; their handlers keep their switches. (Structured error surfaces are
Phase 9.)
**Warning signs:** action enum diffs in feature reducers; TestStore assertions needing updates.

### Pitfall 6: `ResponseParsingError` funnel must survive the rewrite
**What goes wrong:** the private `ResponseParsingError` (underlying + parsed `responseError`)
carries E-Hentai's *server-provided* error text (bans, IP blocks) from `htmlDocument`/`parseResponse`
into `mapAppError`; a rewrite that catches parse errors and throws `.parseFailed` directly loses
those messages — an error-path behavior change.
**How to avoid:** keep `htmlDocument*`/`parseResponse`/`mapAppError` verbatim (they're already
`throws`-based and async-agnostic); the typed body just funnels every caught error through
`mapAppError` exactly once.
**Warning signs:** parity tests on `mapAppError` mapping tables failing for HTML fixture inputs
containing response-error text.

### Pitfall 7: Overloads trait vs. compile time
**What goes wrong:** TCA's own description warns `ComposableArchitecture2DeprecationOverloads`
"can tax the compiler and prevent existing applications from compiling"; the migration guide says
it's "meant to be enabled temporarily during migration". CONC-02's acceptance pins **both** traits
in `Package.swift`, so it ships enabled.
**How to avoid:** requirement wins — keep both traits. But record build-time before/after during
recon; if type-checking time regresses noticeably with zero deprecated usages remaining, raise it
at the D-11 checkpoint rather than silently dropping the trait. [VERIFIED: trait descriptions from
raw Package.swift at tag]

## Code Examples

The load-bearing examples are inline in Architecture Patterns 1–5 above. Two supporting shapes:

### TagTranslatorRequest body (two-step chain + noUpdates early-out, retry asymmetry preserved)

```swift
// Step retry parity: fetch₁ retried (genericRetry today), fetch₂ NOT retried (bare inner publisher today).
public func response() async throws(AppError) -> TagTranslatorPayload {
    let (data, _) = try await fetch(                       // retried ×4
        urlRequest(url: URLUtil.githubAPI(repoName: language.repoName), allowsCellular: true)
    )
    guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let postedDateString = dict["published_at"] as? String,
          let postedDate = dateFormatter.date(from: postedDateString)
    else { throw AppError.parseFailed }
    guard postedDate > updatedDate else { throw AppError.noUpdates }   // control-flow error, preserved

    do {                                                   // second fetch: NO retry (parity)
        let (payload, _) = try await URLSession.shared.data(
            for: urlRequest(
                url: URLUtil.githubDownload(repoName: language.repoName, fileName: language.remoteFilename),
                allowsCellular: true
            )
        )
        return TagTranslatorPayload(data: payload, updatedDate: postedDate)
    } catch {
        throw mapAppError(error: error)
    }
}
```

### Parity-harness seam sketch (D-06/D-07, Wave 0)

```swift
// Baseline (pre-swap): a URLProtocol stub session that never touches the network —
// counts startLoading invocations (retry count) and serves fixture bytes / URLError failures.
final class CountingStubProtocol: URLProtocol { /* class-level fixture + attempt counter */ }
let stubbedSession = URLSession(configuration: {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [CountingStubProtocol.self]
    return config
}())
// Requires every request to accept an injected session (D-07) — the same seam DF already uses.
// Lock per-request: assembled URLRequest (url/method/headers/httpBody), parse output on fixtures,
// attempt counts (4 on failure, 1 on success, 1 always for TagTranslator fetch₂), mapAppError table.
// Re-run the identical suite against the async layer post-swap.
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `AnyPublisher<T, AppError>` + continuation bridge | `async throws(AppError)` end-to-end | Swift 6.0 (SE-0413 typed throws), stdlib/Foundation async APIs | Compile-time error typing preserved without Result wrappers; cancellation-aware fetches |
| `TaskResult` in TCA effects | `Result` or do/catch in `.run` | TCA 1.x (long deprecated) | Codebase already compliant (0 `TaskResult` hits) |
| `\.destination?.case` scoping | Projected `\.$destination` + case chaining | TCA 1.25 (trait-gated), mandatory in 2.0 | The 24-site migration; 2.0-ready |
| `Effect` → `EffectOf` pre-migration | Reverted | TCA 1.25.3 | Do not churn `Effect<Action>` annotations |
| Deprecations via version bumps | SwiftPM package traits (SE-0450) as opt-in deprecation gates | SwiftPM 6.1 / TCA 1.25 | The traits are the CONC-02 discovery mechanism; Xcode support from 26.4 |

**Deprecated/outdated:**
- `Publisher`-based TCA observation (`StorePublisher`), Combine effect operators — all absent from
  EhPanda already.
- `dataTaskPublisher`: not formally deprecated by Apple, but the app's last uses die this phase.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `data(for:)` throws `URLError(.cancelled)` (not `CancellationError`) on task cancellation | Pitfall 4, retry helper | Low — the helper checks both `URLError.code == .cancelled` and `Task.isCancelled`, and either error type maps into a discarded send from a cancelled effect; behavior identical either way [ASSUMED, corroborated by Swift forums] |
| A2 | TCA `.run` reports (runtime warning) and swallows uncaught non-cancellation errors in debug when no `catch:` handler is given | Pattern 3 | Low — moot under D-03 since `do throws(AppError)` catches everything before the closure boundary [ASSUMED from TCA `Effect.run` docs] |
| A3 | Enabling TCA's traits does not alter dependency resolution (`Package.resolved` versions unchanged) | Standard Stack | Low — deps verified unconditional at tag 1.26.0; if wrong, `swift package resolve` output makes it visible immediately |
| A4 | Xcode 26.6 honors `traits:` declared in a *local* package's manifest for a remote dependency (AppPackage → TCA) | Pitfall 2 | Medium — mitigated by the mandatory positive-control check at recon; fallback documented (DerivedData clean, workspace resolve) [ASSUMED, corroborated by Xcode 26.4+ trait support reports] |
| A5 | The recon build surfaces ≈24 warnings (only the scope pattern), no overload-trait surprises | Deprecation Surface | Low-Medium — grep pre-sizing is thorough, but overload-based deprecations can surface in non-grep-able forms; D-10/D-11 exist precisely to absorb this |

## Open Questions

1. **Does `ComposableArchitecture2DeprecationOverloads` stay enabled after reaching zero warnings?**
   - What we know: CONC-02 acceptance pins both traits in `Package.swift`; TCA's guide calls the
     overloads trait "temporary during migration" and warns of compile-time tax.
   - What's unclear: whether the owner wants it dropped post-migration (a later, trivial edit).
   - Recommendation: keep both (requirement wins); measure build time at recon; surface at D-11
     checkpoint only if type-checking regresses.
2. **`response()` as protocol requirement vs. per-struct bodies** (Claude's-discretion area).
   - Recommendation: protocol requirement (Pattern 1) — verified to compile; makes the compiler
     drive the 44-struct checklist. Planner may confirm at plan time; no owner input needed.
3. **Do the 7 DownloadClient sites' enclosing functions adopt `throws(AppError)` signatures?**
   - What we know: they currently `.get()` or switch on the Result inside plain async functions.
   - Recommendation: convert minimally (local `do throws(AppError)`/`try await`), keep their public
     signatures unchanged — DownloadClient decomposition is explicitly out of milestone scope.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode + iOS 26 SDK | build/test (bare `swift build` fails for this project) | ✓ | Xcode 26.6 (17F113) | — |
| Swift toolchain w/ typed throws | D-02 | ✓ | 6.3.3 (verified by compile probes this session) | — |
| Xcode ≥ 26.4 (trait support) | CONC-02 traits taking effect | ✓ | 26.6 | positive-control check at recon guards residual flakiness |
| iOS Simulator (concrete device) | test runs (`AppPackage-Package` scheme) | ✓ | iPhone Air sim (pin by id — two exist; see memory note) | any concrete iOS 26 sim |
| `gh` CLI | release verification (done) | ✓ | — | — |
| SwiftLint | lint gate | ✓ (build-tool plugin; binary in DerivedData artifactbundle) | 0.65.0 pin | — |
| Network access to GitHub | `swift package resolve` after manifest edit | ✓ | — | — |

**Missing dependencies with no fallback:** none.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (not XCTest) |
| Config file | `AppPackage/Tests/…` test targets in `Package.swift`; no `-testPlan` for the package scheme |
| Quick run command | `xcodebuild build -project EhPanda.xcodeproj -scheme AppFeature -destination 'generic/platform=iOS Simulator'` (build+lint gate; grep log for `error:|warning:`) |
| Full suite command | `cd AppPackage && xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone Air'` (≈436 tests; read the `✔ Test run with N tests` lines, not the XCTest counter) |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CONC-01 | URLRequest assembly parity (44 requests: url/method/headers/body) | unit (fixture, no network) | full-suite run; new baseline suite in `NetworkingFeatureTests` | ❌ Wave 0 |
| CONC-01 | Parse-output parity per request on fixtures | unit | same | ❌ Wave 0 |
| CONC-01 | Retry counts (4 on transport failure; 1 on success; 1 for TagTranslator fetch₂) | unit (counting URLProtocol stub) | same | ❌ Wave 0 |
| CONC-01 | `mapAppError` mapping table incl. `ResponseParsingError` server-text path + `noUpdates` | unit | same | ❌ Wave 0 |
| CONC-01 | DF request transforms unchanged | unit | existing `DFRequestSemanticsTests` (S1–S7) | ✅ |
| CONC-01 | No `import Combine` in `AppPackage/Sources` | smoke | `grep -r "import Combine" AppPackage/Sources` returns empty | ✅ (command) |
| CONC-01 | Reducer behavior unchanged around effects | regression | full suite (existing reducer/TestStore tests unchanged) | ✅ |
| CONC-02 | Traits applied (positive control) | manual-gated build check | build log shows expected warning at a known site pre-fix | ✅ (command) |
| CONC-02 | Zero TCA deprecation warnings | smoke | build EhPanda app scheme + package; `grep -iE "warning:.*deprecat" build.log` (filter SwiftLint noise) returns empty | ✅ (command) |
| CONC-02 | Reducers/stores behave identically | regression | full suite green; existing UI flows via `/gsd-verify-work` UAT | ✅ |

### Sampling Rate
- **Per task commit:** quick build (AppFeature scheme) — clean build ⇒ lint clean (plugin runs in-build)
- **Per wave merge:** full suite (`AppPackage-Package`)
- **Phase gate:** full suite green + Combine grep empty + deprecation grep empty before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `AppPackage/Tests/NetworkingFeatureTests/RequestBaselineTests.swift` (or split per request
  family) — locks URLRequest assembly, parse fixtures, retry counts, `mapAppError` table against the
  **current Combine layer first** (D-05), covering CONC-01
- [ ] Counting `URLProtocol` stub + fixture loading in `NetworkingFeatureTests` (or `TestingSupport`)
  — note `DataCache.shared`-style pollution lessons: keep stubs per-test-configured, no shared globals
- [ ] Prerequisite code seam: injectable `urlSession` on the requests that hard-code
  `URLSession.shared` (39 publisher sites) — Wave 0 may add the parameter (defaulted `.shared`,
  zero behavior change) so the baseline can execute offline

*(Framework install: none — Swift Testing already in use.)*

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no (login request migrated mechanically; cookie auth untouched — QUAL-01/Phase 8) | — |
| V3 Session Management | no | cookies out of scope this phase |
| V4 Access Control | no | n/a (client app) |
| V5 Input Validation | yes | existing Kanna/`JSONDecoder` parse funnels preserved verbatim; no new input paths introduced |
| V6 Cryptography | no new surface | TLS via URLSession unchanged; DF custom trust path (`DFURLProtocol`/`LegacyCFReadStream`) byte-identical by requirement — do not touch trust evaluation code |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Retry amplification against origin (accidental DoS/self-ban) | Denial of service | Preserve exact `retry(3)` scope/count; never retry parse failures or the un-retried steps (Pitfall 3) |
| Error-message information loss (server ban/block text) | Repudiation/UX-security | Preserve `ResponseParsingError` → `mapAppError` funnel (Pitfall 6) |
| Supply chain (dependency bump) | Tampering | Version floor on the already-resolved 1.26.0 canonical Point-Free repo; traits verified deprecation-only, no resolution change (§Package Legitimacy Audit) |
| Weakening DF trust handling during refactor | Spoofing | DF stack files are out of the rewrite's blast radius — only the *session injection* seam is threaded through, not the protocol/trust code |

## Sources

### Primary (HIGH confidence)
- `pointfreeco/swift-composable-architecture` raw `Package.swift` at tag 1.26.0 — traits declaration
  verbatim, no default traits, unconditional dependencies [VERIFIED]
- Official `MigratingTo1.25.md` at tag 1.26.0 (raw fetch) — trait semantics, hard vs. trait-gated
  deprecation lists, `Package.swift` traits syntax, projected-scope migration incl. edge cases,
  reentrant-action runtime warning [VERIFIED]
- `gh api` release notes for 1.25.0–1.26.0 — 1.25.3 adds the Overloads trait + un-deprecates
  `Effect`; 1.26.0 latest (2026-06-09) [VERIFIED]
- Local `swiftc -typecheck` probes on Swift 6.3.3 (pinned toolchain) — typed-throws catch inference
  (function vs. closure), `do throws(E)` form, `Task` typed-failure unavailability, `Result`
  catching variants, generic retry inference limits, protocol-requirement compilation [VERIFIED]
- EhPanda codebase greps/reads this session — 44 requests, 64 call sites (57 reducer + 7
  DownloadClient), 24 deprecated scope sites, 0 hits for all other trait-gated APIs, 4 dead Combine
  imports, retry placement map, `Package.resolved` at TCA 1.26.0 [VERIFIED]

### Secondary (MEDIUM confidence)
- Swift forums: Task-cancellation propagation to URLSession tasks (t/65041), Xcode SwiftPM traits
  support (t/81994, t/82819) — corroborated across multiple threads
- massicotte.org "Package Traits in Xcode"; docs.swift.org SwiftPM `package(url:_:traits:)` reference

### Tertiary (LOW confidence)
- WebSearch summaries of Swift 6.4 concurrency changes (typed-throws `Task`) — only used as the
  *prompt* to run the authoritative local compile probe, which superseded them

## Metadata

**Confidence breakdown:**
- Deprecation surface & traits: HIGH — official guide at tag + exhaustive grep + release notes
- Typed-throws behavior: HIGH — verified on the exact installed toolchain by compile probes
- Async migration patterns: HIGH — shapes verified compiling; Combine semantics read from source
- Xcode trait application: MEDIUM — support confirmed ≥26.4 but flakiness reported; mitigated by
  positive-control recon step

**Research date:** 2026-07-12
**Valid until:** 2026-08-12 (stable domain; re-check only if a TCA 1.27+/2.0-beta lands before planning)
