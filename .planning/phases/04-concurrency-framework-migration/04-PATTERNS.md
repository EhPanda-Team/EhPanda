# Phase 4: Concurrency & Framework Migration - Pattern Map

**Mapped:** 2026-07-12
**Files analyzed:** 6 change groups (~40 files touched) + 2 new test files
**Analogs found:** 8 / 8 groups (all changes are in-place rewrites of existing files; only the Wave-0 test files are new, and they have a direct in-repo analog)

This phase creates almost no new files — it rewrites existing ones. Pattern assignments therefore
pair each *change group* with (a) the existing file being rewritten (the "before" shape to preserve
parity against) and (b) the target shape already fully specified in 04-RESEARCH.md §Architecture
Patterns 1–5. RESEARCH.md's patterns are compile-probe-verified on the pinned toolchain and are the
authoritative "code to copy"; this map anchors them to concrete in-repo line numbers.

## File Classification

| File / Group | Role | Data Flow | Analog / Baseline | Match Quality |
|---|---|---|---|---|
| `AppPackage/Sources/NetworkingFeature/Request.swift` (protocol + façade + 4 requests) | service (request layer) | request-response | itself (rewrite in place) + RESEARCH Patterns 1–2 | exact |
| `Request+Account/Detail/GData/GalleriesMetadata/Gallery/Image.swift` (40 request structs) | service (request layer) | request-response (Image: fan-out) | `GalleryDetailRequest` (`Request+Detail.swift:28-72`) as canonical shape | exact |
| 57 reducer `.run` call sites (21 feature files) | reducer effect | request-response | `PopularReducer.swift:74-97` + RESEARCH Pattern 3 | exact |
| 7 `DownloadClient` call sites (`+ExecutionSupport`, `+ExecutionFetch`) | service (plain async fn) | request-response | `DownloadClient+ExecutionFetch.swift:12-23` | exact |
| 4 client files (`ApplicationClient`, `AuthorizationClient`, `ImageClient`, `LibraryClient`) | dependency client | n/a (dead-import deletion) | themselves | exact |
| `AppPackage/Package.swift` (TCA entry) | config | n/a | current `.package` entry (lines 23-26) + RESEARCH §Installation | exact |
| 24 sheet/fullScreenCover scope sites (10 view files) | component (view modifier arg) | request-response (presentation) | `PopularView.swift:35-40` + RESEARCH Pattern 5 | exact |
| **NEW:** `AppPackage/Tests/NetworkingFeatureTests/RequestBaselineTests.swift` (+ counting `URLProtocol` stub) | test | fixture/no-network | `DFRequestSemanticsTests.swift` | exact (role + method) |

## Pattern Assignments

### Group 1: `Request.swift` — protocol, façade, helpers (service, request-response)

**Baseline (current shape to migrate):** `AppPackage/Sources/NetworkingFeature/Request.swift`

**Protocol today** (lines 9-13) — `publisher` requirement is replaced per RESEARCH Pattern 1:
```swift
public protocol Request {
    associatedtype Response: Sendable
    var publisher: AnyPublisher<Response, AppError> { get }
}
```
becomes (verified compiling, RESEARCH Pattern 1 — recommended discretion choice):
```swift
public protocol Request {
    associatedtype Response: Sendable
    func response() async throws(AppError) -> Response
}
```

**DELETE list (D-04), exact locations in `Request.swift`:**
- `response()` Result façade + main-queue hop — lines 20-23 (`publisher.receive(on: DispatchQueue.main).async()`)
- `Publisher.genericRetry()` — lines 145-148
- `Publisher.async()` / `asyncOutput()` continuation shim — lines 150-179
- `import Combine` — line 3 (and in the 6 `Request+*.swift` files, each ~line 2-3)

**KEEP VERBATIM (D-07 parse seam / Pitfall 6):** `ResponseParsingError` (lines 15-18),
`urlRequest(url:allowsCellular:)` (25-32), `htmlDocument` (34-49), `htmlDocumentWithUTF8Fallback`
(51-75), both `parseResponse` overloads (77-109), `mapAppError` (111-136). These are already
`throws`-based and async-agnostic — the rewrite only changes their callers.

**NEW fetch-with-retry helper:** copy RESEARCH.md §Pattern 2 verbatim (concrete
`throws(AppError)`, 4 total attempts, cancellation short-circuit via `URLError(.cancelled)` /
`Task.isCancelled`, `mapAppError` funnel). Lives as a `Request` extension in `Request.swift`
alongside the kept helpers.

### Group 2: The 44 request bodies (service, request-response)

**Canonical analog:** `GalleryDetailRequest`, `AppPackage/Sources/NetworkingFeature/Request+Detail.swift:28-72`

**Current pipeline shape** (lines 45-63) — every simple request follows this:
```swift
public var publisher: AnyPublisher<GalleryDetailResponse, AppError> {
    urlSession.dataTaskPublisher(
        for: urlRequest(url: URLUtil.galleryDetail(url: galleryURL), allowsCellular: allowsCellular)
    )
        .genericRetry()
        .tryMap { try htmlDocumentWithUTF8Fallback(data: $0.data) }
        .tryMap { doc in try parseResponse(doc: doc) { ... Parser.parseGalleryDetail ... } }
        .mapError(mapAppError)
        ...
}
```

**Target shape** — mechanical translation, each pipeline stage maps 1:1:
```swift
public func response() async throws(AppError) -> GalleryDetailResponse {
    let (data, _) = try await fetch(                       // = dataTaskPublisher + genericRetry
        urlRequest(url: URLUtil.galleryDetail(url: galleryURL), allowsCellular: allowsCellular),
        in: urlSession
    )
    do {
        let doc = try htmlDocumentWithUTF8Fallback(data: data)   // parse steps NOT retried
        return try parseResponse(doc: doc) { ... }               // (helper returns before parsing)
    } catch {
        throw mapAppError(error: error)                          // funnel exactly once
    }
}
```

**Injected-session seam (D-07):** copy `GalleryDetailRequest`'s init pattern
(`Request+Detail.swift:29-43` — `urlSession: URLSession = .shared` init param + stored property)
onto the 39 requests that currently hard-code `URLSession.shared.dataTaskPublisher` (e.g. all four
requests in `Request.swift:255-341`, `Request+Detail.swift:183,197,224,262,279,299,320`). Defaulted
`.shared`, zero behavior change — this is the Wave-0 prerequisite so the baseline harness can stub.

**POST-body pattern (preserve byte-identical):** `Request+Account.swift:31-33` (repeats at 96-98, 197-198):
```swift
request.httpMethod = "POST"
request.httpBody = params.dictString().urlEncoded.data(using: .utf8)
request.setURLEncodedContentType()
```
URLRequest assembly is untouched by the migration — only the transport call changes.

**Multi-step chain analog:** `TagTranslatorRequest`, `Request.swift:299-341`. Note the retry
asymmetry to preserve: fetch₁ (`githubAPI`) has `.genericRetry()` (line 322); fetch₂ (the
`flatMap` download, lines 332-337) has **no retry**. Target body: copy RESEARCH.md §Code Examples
"TagTranslatorRequest body" verbatim (fetch₁ via helper, fetch₂ via bare
`URLSession.shared.data(for:)` + `mapAppError`). `throw AppError.noUpdates` (line 329) is control
flow — preserved as-is.

**Fan-out analog:** `GalleryNormalImageURLRequest`, `Request+Image.swift:86-117`
(`.flatMap { index, url in urlSession.dataTaskPublisher... }` + `.collect()`, per-child retry).
Target: copy RESEARCH.md §Pattern 4 (`withThrowingTaskGroup`, retry helper called *inside* each
child, `do`/`mapAppError` at the group boundary because the group throws untyped).

### Group 3: 57 reducer `.run` call sites (reducer effect, request-response)

**Canonical analog:** `AppPackage/Sources/HomeFeature/Popular/PopularReducer.swift:74-97`

**Before** (lines 78-82):
```swift
return .run { send in
    let response = await PopularGalleriesRequest(filter: filter).response()
    await send(.fetchGalleriesDone(response))
}
.cancellable(id: CancelID.fetchGalleries)
```

**After** — copy RESEARCH.md §Pattern 3 verbatim. Load-bearing keyword: `do throws(AppError)`
(bare `do/catch` in a `.run` closure binds `any Error` — Pitfall 1):
```swift
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

**Do NOT touch** the `…Done(Result<_, AppError>)` handler (`PopularReducer.swift:84-97` and its
analogs) — the Done actions and their `switch result` bodies stay verbatim (Pitfall 5; literal
reducer parity, existing TestStore assertions unaffected).

**Out of the sweep:** the ~10 existing `.run(operation:catch:)` handlers in
`DetailReducer+Download`, `FolderManagerReducer`, `PreviewsReducer` wrap DownloadClient/file work,
not `.response()` — leave them alone.

### Group 4: 7 DownloadClient call sites (service, plain async fn)

**Analog:** `AppPackage/Sources/DownloadClient/DownloadClient+ExecutionFetch.swift:12-23`

**Before** (lines 15-22 — `.response().get()` inside a `throws` function):
```swift
let detailResponse = try await GalleryDetailRequest(
    gid: download.gid, galleryURL: galleryURL,
    urlSession: urlSession, allowsCellular: options.allowCellular
)
.response()
.get()
```
**After:** drop `.get()` — `try await ....response()` directly. Sites that `switch` on the Result
(`+ExecutionSupport.swift:180,197,339,351,376`) convert to `do throws(AppError)`/`catch` (use the
explicit form here too for grep-able consistency, even though function-body inference works).
Keep enclosing public signatures unchanged (RESEARCH Open Question 3 recommendation).

### Group 5: 4 client files — dead-import deletion (dependency client)

**Analog is the files themselves.** Example `ApplicationClient.swift:1-4`:
```swift
import SwiftUI
import Combine        // ← delete this line; no other change
import ComposableArchitecture
import AppTools
```
Same one-line deletion in `AuthorizationClient/AuthorizationClient.swift:1`,
`LibraryClient/LibraryClient.swift:3`, `ImageClient/ImageClient.swift:4`. Verified dead — no
publisher/Future/Subject/sink usage in any of the four.

### Group 6: `AppPackage/Package.swift` — TCA floor + traits (config)

**Current entry** (lines 23-26):
```swift
.package(
    url: "https://github.com/pointfreeco/swift-composable-architecture",
    from: "1.25.0"
),
```
**Target:** copy RESEARCH.md §Installation verbatim (`from: "1.25.3"` + the two trait strings).
Then `swift package resolve` (regenerates `AppPackage/Package.resolved` — expect only `originHash`
to change; 1.26.0 already resolved). Remember the memory note: delete `AppPackage/.build` first if
resolve misbehaves; the workspace `Package.resolved` mirror also regenerates.

### Group 7: 24 non-projected destination scopes (component, presentation)

**Canonical analog:** `AppPackage/Sources/HomeFeature/Popular/PopularView.swift:35-40`

**Before** (line 36):
```swift
.sheet(
    item: $store.scope(state: \.destination?.filters, action: \.destination.filters)
) { store in
    FiltersView(store: store)
```
**After** (RESEARCH Pattern 5):
```swift
    item: $store.scope(state: \.$destination, action: \.destination).filters
```
Pure argument-syntax change; the modifier stays on its existing anchor (CLAUDE.md dialog-placement
rule), `@Presents var destination` and reducers untouched. The 24 sites: 21 `.sheet` + 3
`.fullScreenCover` across `ReadingView`, `FavoritesView`, `PopularView`/`WatchedView`/
`FrontpageView` (+1 more Home screen), `SearchView`, `SearchRootView`, `DetailView`,
`DetailSearchView`, `PreviewsView` (grep `state: \.destination?` to enumerate exactly).
`PopularView.swift:36` doubles as the CONC-02 positive-control site (Pitfall 2).

### Group 8 (NEW FILES): Wave-0 parity harness (test, fixture/no-network)

**Analog:** `AppPackage/Tests/NetworkingFeatureTests/DFRequestSemanticsTests.swift`

**Copy its structure exactly** — this is the project's proven Wave-0 baseline idiom:

Header doc-comment convention (lines 6-15) — states what contract is frozen, why, and the
no-network guarantee:
```swift
// Wave 0 semantics lock for DEP-06 (D-14). ... These fixtures freeze that
// contract before any DeprecatedAPI removal spike, so a later change that drifts ... fails loudly.
//
// The tests are fully deterministic and never open a socket: they exercise the pure request
// transforms ... `resume()` (which schedules the stream) is never called.
```

Swift Testing suite shape (lines 1-4, 16-17, 31-43):
```swift
import Foundation
import Testing
import AppModels
@testable import NetworkingFeature

@Suite
struct DFRequestSemanticsTests {
    /// A resolvable domain has its URL host swapped to a numeric IP while scheme and path are kept...
    @Test
    func domainIPReplacementSwapsHostToIPAndAddsHostHeader() throws {
        let request = URLRequest(url: try #require(URL(string: "https://e-hentai.org/g/123/abc")))
        let replaced = request.domainIPReplaced()
        #expect(replaced.value(forHTTPHeaderField: "Host") == "e-hentai.org")
        ...
    }
```
Conventions to carry over: `@Suite` struct, `@Test` + `throws`, `#require` for unwrapping,
`#expect` assertions, `// MARK:` sections per contract area, one doc-comment sentence per test
stating the frozen invariant.

**The counting `URLProtocol` stub:** no in-repo analog exists (DF tests never construct a session).
Copy RESEARCH.md §Code Examples "Parity-harness seam sketch": ephemeral
`URLSessionConfiguration` with `protocolClasses = [CountingStubProtocol.self]`, injected per
request via the D-07 seam. Heed the memory lesson (per-test-configured stubs, no shared globals —
the `DataCache.shared` pollution pattern; prefer injecting the stub session over
`URLProtocol.registerClass`).

## Shared Patterns

### Error funnel (apply to all 44 request bodies)
**Source:** `Request.swift:111-136` (`mapAppError`) + lines 15-18 (`ResponseParsingError`).
Every caught error passes through `mapAppError` **exactly once** before being thrown; parse
helpers keep wrapping in `ResponseParsingError` so server ban/block text survives (Pitfall 6).

### Retry policy (apply to every retried fetch step)
**Source:** RESEARCH.md §Pattern 2 helper. Semantics: `retry(3)` = 4 total attempts, fetch scope
only, never parse steps, no retry on TagTranslator fetch₂, per-child retry inside the Image
fan-out, cancellation short-circuit.

### Typed-catch convention (apply to all 64 await sites)
`do throws(AppError) { … } catch { … }` — explicit everywhere, including function bodies where
inference would work. Warning signs of drift: any new `as? AppError`, `?? .unknown`, or `as!`.

### Lint conformance (all groups)
Read root `.swiftlint.yml` before writing; relevant here: 120-char line length as error,
`force_try`/`force_unwrapping` banned, lint-as-error via build plugin (clean build ⇒ lint clean).

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| Counting `URLProtocol` stub (within Group 8) | test support | fixture | No existing test constructs a stubbed URLSession; use the RESEARCH.md seam sketch. Everything else in the phase has a direct in-repo analog. |

## Metadata

**Analog search scope:** `AppPackage/Sources/{NetworkingFeature, HomeFeature, DownloadClient, ApplicationClient}`, `AppPackage/Tests/NetworkingFeatureTests`, `AppPackage/Package.swift`
**Files scanned:** ~15 read/grepped (RESEARCH.md's exhaustive greps of 44 requests / 64 sites / 24 scopes reused rather than re-derived)
**Pattern extraction date:** 2026-07-12
