# Phase 8: Architecture Hygiene & Client Seams - Research

**Researched:** 2026-07-14
**Domain:** TCA `@Dependency` de-globalization, actor-singleton→dependency reshape, request-parameter threading, deterministic client tests (Swift Testing)
**Confidence:** HIGH (every claim verified against the current source tree; no external packages introduced)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** QUAL-01 is rescoped to a **logging audit only**; the Keychain migration is **dropped** (out of the milestone, NOT deferred). Reconcile `REQUIREMENTS.md` (QUAL-01) and `ROADMAP.md` (Phase 8 goal + success criterion 2) to the logging-audit-only scope as a **docs task in this phase**.
- **D-02:** The audit — no cookie value is ever emitted to logs at `.public` privacy. Sweep `logger`/OSLog sites; where a cookie value must appear in diagnostics use `.private` (or omit). The cookie UI + clipboard export (`getCookiesDescription`) are **not logs** and stay as-is.
- **D-03:** `galleryHost` is **parameterized all the way**. Delete the global read (`Defaults.URL.host` deriving host from a global), `AppUtil.galleryHost`, **and** the manual `UserDefaults` mirror (`AccountSettingReducer.galleryHostChanged` write + `SettingReducer+Helpers` launch restore). Host lives **only** in `@Shared(.setting)`. Views take host from store state / parent params; the ~44 `NetworkingFeature` requests take host **explicitly** as a parameter. **Accepted behavior change:** if the setting blob is lost, host resets to `.ehentai`. `AppUserDefaults` shrinks to `clipboardChangeCount` only.
- **D-04:** View-layer global reads become `@Dependency`. The 12 `CookieUtil.didLogin` and 4 `HapticsUtil.generateFeedback` view sites become `@Dependency(\.cookieClient)` / `@Dependency(\.hapticsClient)` reads. Direct `.live`/`.shared`/static usage is **forbidden in consumers** (extends Phase 5 D-01). Read timing stays identical (views re-read each render), so parity holds; in-body `@Dependency` read accepted over reducer-state promotion.
- **D-05:** `CookieUtil` is **deleted** (`didLogin`/`verify` already covered by `CookieClient.didLogin`). `HapticsUtil`'s implementation is **folded into `HapticsClient.live`** and the standalone type deleted. `UserDefaultsUtil` similarly folds into `UserDefaultsClient`.
- **D-06:** `URLUtil` and `FileUtil` are **retained as pure constant/helper namespaces — NOT wrapped in clients** (anti-wrapper principle; HYG-01 retains pure value types/constants). May be relocated/renamed to shed the `*Util` label. `URLUtil`'s only hidden impurity (its `Defaults.URL.host` read) is resolved by D-03. The docs reconciliation (D-01) notes this **tightens** the requirement's "convert URLUtil/AppUtil to clients" wording.
- **D-07:** `AppUtil.dispatchMainSync` is **deleted** (zero callers). The `AppUtil` type is **eliminated**; placement of surviving `version`/`build`/`isTesting` is **Claude's discretion**.
- **D-08:** `DataCache.shared` becomes a standalone `@Dependency(\.dataCache)`; `DataCache` stays an `actor`. Add a `DataCache` `DependencyKey` whose `liveValue` is the single shared instance. `ImageClient`/`LibraryClient`/`DownloadClient` resolve `\.dataCache` inside their live values; `ReadingView` uses `@Dependency`. Delete `DataCache.shared` and `ImageClient`'s hardcoded `.shared` defaults.
- **D-09:** `NetworkingFeature`'s QUAL-02 share is satisfied by the **Phase 4 baselines** — no new networking tests. New work targets **only** `CookieClient` + `ImageClient`. This clears the `STATE.md` Phase-8 blocker.
- **D-10:** Coverage is reworked-seam-first with a behavior matrix — **deep, not padded**. `CookieClient`: `didLogin` full matrix (eh/ex × `igneous` present/mystery/absent × expiry), `setCredentials` + `setSkipServer` `Set-Cookie` parsing, `syncExCookies`, `fulfillAnotherHostField`, `importAutomationCookies`. `ImageClient`: cache hit/miss + failure retry, **per-test `DataCache` instance** (never process-global), compare **decoded pixel dimensions**. Do **not** pad untouched paths (`editCookie`/`removeYay`/`loadCookiesState`). New test targets carry a `parent_config` `.swiftlint.yml`.

### Claude's Discretion
- `AppUtil.version`/`build`/`isTesting` placement after `AppUtil` is eliminated (D-07).
- `URLUtil`/`FileUtil` final relocation and naming (D-06).
- `DataCache` `testValue` strategy (`unimplemented` vs fresh per-test) — but tests MUST use a per-test instance (D-08/D-10).
- Removing the stale empty `AppPackage/Sources/AuthorizationClient/` directory if confirmed orphaned.
- Plan/wave decomposition (seams a–g listed in CONTEXT). Planner sequences; **xcodebuild invocations must never overlap**.

### Deferred Ideas (OUT OF SCOPE)
- None. The dropped Keychain cookie migration is **not** deferred — it is out of the milestone by D-01, reconciled in this phase.
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| **HYG-01** | De-globalize `*Util` into injected clients; remove singletons; retain pure value types/constants; no static global helper with side effects remains. | Verified inventory below: `CookieUtil` (14 refs), `HapticsUtil` (5 refs), `UserDefaultsUtil`, `AppUtil` (12 refs + `galleryHost`/`dispatchMainSync`), `DataCache.shared` (5 non-def sites). Fold/parameterize/delete mechanics documented per Util. `URLUtil`/`FileUtil` stay pure per D-06. Device slice + `TouchHandler.shared` already gone (Phase 5). |
| **QUAL-01** (rescoped → logging audit) | No cookie value emitted to logs at `.public`. | Audit sweep result below: **zero** logger sites currently interpolate a cookie value; `getCookiesDescription` flows only to the clipboard, not a logger. Audit is a *confirm-and-guard* task, not a *fix* task. Docs reconciliation required (D-01). |
| **QUAL-02** | Client-layer tests for the reworked seams; deterministic and green. | `CookieClient.testing(...)` in-memory double + `CookieClient.live(cookieStorage:)` injectable factory both exist. An extensive `ImageClient`/`DataCache` suite already exists in `DownloadsFeatureTests` (per-test isolated cache + `URLProtocol` stub) — the model for the new `ImageClientTests`. `NetworkingFeature` share satisfied by Phase 4 (D-09). |
</phase_requirements>

## Summary

Phase 8 is a **behavior/appearance-parity architecture refactor** with three mechanically-distinct workstreams plus tests and docs. Nothing here is new-feature design; the research value is the exact seam-swap mechanics and their blast radii, all of which I verified against the tree.

**Workstream sizes (verified):**
1. **`galleryHost` parameterization (D-03) — by far the largest blast radius.** The global `Defaults.URL.host` computed property (which reads `AppUtil.galleryHost` ← a `UserDefaults` mirror) is consumed *far beyond* the "44 requests": it is read directly in **8 files** and its host-derived siblings (`Defaults.URL.api/myTags/uConfig/popular/watched/favorites/galleryPopups/galleryTorrents`) in **21 more sites**, plus `AppUtil.galleryHost` is read in **12 view/reducer sites**. Every one must receive host explicitly (from `@Shared(.setting).galleryHost`) or the build breaks when the global is deleted. `URLUtil`'s 19 builders, `CookieClient.apiuid`/`setSkipServer`, `Parser+Shared`, and 3 `SettingFeature` sites are *all* host-global consumers, not just `NetworkingFeature`.
2. **Util folds (D-04/D-05/D-06/D-07) — medium, mechanical.** `CookieUtil` delete (12 view sites → `@Dependency`), `HapticsUtil` fold into `HapticsClient.live` (4 view sites → `@Dependency`), `UserDefaultsUtil` fold into `UserDefaultsClient`, `AppUtil` eliminate, `URLUtil`/`FileUtil` kept pure.
3. **`DataCache` dependency reshape (D-08) — small but has one non-obvious coupling** (the module-level system-purge observer references `.shared`).

**QUAL-01 is a near-empty audit:** the sweep already shows no cookie value is logged. The task is to *prove and lock that in* (a grep gate / comment), not to fix a leak, plus the docs reconciliation.

**QUAL-02 leans on existing test infrastructure:** `CookieClient.testing(...)`, `CookieClient.live(cookieStorage:)`, and a full `ImageClient` suite (in `DownloadsFeatureTests`) already exist — the new dedicated `CookieClientTests`/`ImageClientTests` targets adapt these established patterns.

**Primary recommendation:** Sequence the phase so the `galleryHost` parameterization lands as its own bottom-up wave (`GalleryHost` param → `URLUtil` builders → `Request` structs → reducers/views → delete `Defaults.URL.host` + `AppUtil.galleryHost` + the mirror last), guarded by the Phase-4 `NetworkingFeature` baselines. Run the Util folds and `DataCache` reshape as independent waves. Add the two test targets after their seams are final. Never overlap `xcodebuild` invocations.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| Active gallery host selection | Persistence (`@Shared(.setting)`) | Reducers (read + thread) | D-03 makes `@Shared(.setting).galleryHost` the single source of truth; the `UserDefaults` mirror is deleted. |
| Request URL construction | Networking (`Request` structs + `URLUtil`) | Reducers (supply `host`) | Host becomes an explicit request parameter; `URLUtil` builders take `host` instead of reading a global. |
| Login-state gating | Client (`CookieClient.didLogin`) | Views (`@Dependency` read) | `CookieUtil` deleted; the accessor already lives on the client. |
| Haptic feedback | Client (`HapticsClient`) | Views (`@Dependency` read) | `HapticsUtil` device-detection logic folds into `HapticsClient.live`. |
| Reader byte cache | `AppTools.DataCache` (actor) via `@Dependency(\.dataCache)` | Clients/Views resolving the key | Singleton identity supplied by the dependency system's `liveValue`, not a static `.shared`. |
| Pure URL/path constants | `AppModels`/`AppTools` namespaces (`URLUtil`, `FileUtil`) | — | Deterministic, substitution-free → no client wrapper (D-06). |
| Cookie storage | `HTTPCookieStorage.shared` (unchanged) | `CookieClient` | Keychain migration dropped (D-01); at-rest storage unchanged. |

## Standard Stack

No new third-party packages. Everything uses in-repo modules and libraries already declared in `AppPackage/Package.swift`.

### Core (existing, in-repo)
| Component | Where | Purpose | Why Standard |
|-----------|-------|---------|--------------|
| `swift-composable-architecture` (`@Dependency`, `DependencyKey`, `TestStore`, `withDependencies`) | Package.swift (pinned `from: 1.25.3` + traits, Phase 4) | Dependency injection + reducer tests | The project's DI + test substrate; `@Dependency`-only consumer rule (Phase 5 D-01). `[VERIFIED: codebase]` |
| `swift-testing` (`@Suite`/`@Test`/`#expect`/`#require`) | Test targets | Deterministic client tests | Project standard (not XCTest). `[VERIFIED: codebase]` |
| `swift-dependencies` `IssueReporting.unimplemented` | client `testValue`s | Fail-on-unexpected-call test doubles | Established `liveValue`/`previewValue`/`testValue`/`.noop` shape. `[VERIFIED: codebase]` |
| `Synchronization.Mutex` | `CookieClientTestingStore` | Sendable in-memory cookie store | Already used; `no_nslock` lint rule bans `NSLock`. `[VERIFIED: codebase]` |

### Supporting (existing test helpers to reuse)
| Helper | Where | Use case |
|--------|-------|----------|
| `CookieClient.testing(memberID:passHash:igneous:)` | `CookieClient/CookieClient.swift` (`#if DEBUG`) | In-memory cookie double for `didLogin` matrix, `syncExCookies`, `fulfillAnotherHostField`, `importAutomationCookies`. `[VERIFIED: codebase]` |
| `CookieClient.live(cookieStorage:)` | `CookieClient/CookieClient.swift` | Inject a **per-test `HTTPCookieStorage`** for `setCredentials`/`setSkipServer` header-parsing tests (avoids `.shared` pollution — same principle as the DataCache rule). `[VERIFIED: codebase]` |
| `SharedSessionStubURLProtocol` + `makeStubbedSession()` + `makeIsolatedDataCache()` + `makePNGData()` | `Tests/DownloadsFeatureTests/ReaderImageDataTests.swift` | Deterministic `ImageClient` fetch/cache tests; per-test `DataCache(configuration:.init(rootURL:UUID))`. `[VERIFIED: codebase]` |
| `TestFixtures`/`TestHelper` (`TestingSupport`) | `Sources/TestingSupport/` | HTML/image fixtures (e.g. `BandwidthExceeded.html`, `Kokomade.jpg`). `[VERIFIED: codebase]` |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `DataCache` as its own `DependencyKey` (D-08) | Fold `DataCache` into `ImageClient` | Rejected in D-08: creates client→client deps (`LibraryClient`/`DownloadClient` → `ImageClient`) and contradicts `DataCache`'s documented reader-pipeline scope. |
| Host as an explicit `Request` parameter (D-03) | Keep `Defaults.URL.host` reading `@Shared(.setting)` from a static | A static computed prop can't cleanly read `@Shared`/`@Dependency` context; D-03 chose parameterization for testability + no hidden global. |
| `URLUtil`/`FileUtil` kept as pure namespaces (D-06) | Wrap in a `URLClient`/`FileClient` | Anti-wrapper rule: a client over a pure deterministic builder adds no substitutability value. (Note: a `FileClient` and `URLClient` module already exist for the *side-effecting* file/URL ops; `FileUtil`/`URLUtil` are the pure-constant complements.) |

**Installation:** none. Package.swift changes are **internal**: add two `Module` enum cases + two `testTarget` entries (`CookieClientTests`, `ImageClientTests`); optionally remove the empty `AuthorizationClient` source dir.

## Package Legitimacy Audit

**Not applicable — this phase installs no external packages.** All work uses in-repo modules and already-pinned dependencies (`swift-composable-architecture`, `swift-dependencies`, `swift-testing`, `Synchronization`). No `npm`/`PyPI`/`crates` or SPM registry additions. The only Package.swift edits are internal target/module declarations.

**Packages removed due to [SLOP] verdict:** none.
**Packages flagged as suspicious [SUS]:** none.

## Architecture Patterns

### System Architecture Diagram

**`galleryHost` flow — BEFORE (current):**
```
UserDefaults[.galleryHost] ──(read)──> AppUtil.galleryHost ──> Defaults.URL.host (global computed)
        ▲                                                              │
        │(mirror write)                                                ├─> Defaults.URL.{api,myTags,uConfig,popular,watched,favorites,...}
 AccountSettingReducer.galleryHostChanged                              ├─> URLUtil.* builders (19)
 SettingReducer+Helpers (launch restore) ──> @Shared(.setting).host   ├─> CookieClient.apiuid / setSkipServer
                                                                       ├─> Parser+Shared (default host param)
                                                                       └─> Request structs (44) via URLUtil
 View reads: AppUtil.galleryHost (12 sites)
```

**`galleryHost` flow — AFTER (D-03):**
```
@Shared(.setting).galleryHost  ── single source of truth ──┐
        │ (read in reducers/views)                          │
        ▼                                                    ▼
 Reducers construct Request(host: setting.galleryHost, ...)  Views read setting.galleryHost
        │                                                    (from @Shared / @SharedReader / parent param)
        ▼
 Request.response() ──> URLUtil.searchList(host: host, keyword:, filter:) ──> host.url + query
        (Defaults.URL.host global DELETED; host-derived Defaults.URL.* become host-taking helpers)
```

**`DataCache` flow — AFTER (D-08):**
```
@Dependency(\.dataCache)  ─────────────────────────────────┐  (single liveValue instance)
   resolved inside:                                          │
     • ImageClient.live (prefetch + readerImageData)         ▼
     • LibraryClient.live (removeAll / totalSize / purge)   one DataCache actor
     • DownloadClient+Cache (removeData / data)              │
     • ReadingView (@Dependency, per D-04)                   │
 system-purge observer  ──── must observe THIS instance ─────┘  (was: DataCache(cache: .shared))
```

### Recommended Project Structure
```
AppPackage/Sources/
├── AppTools/
│   ├── DataCache.swift            # actor kept; + DataCacheKey: DependencyKey; .shared DELETED
│   ├── HapticsUtil.swift          # DELETED (impl folds into HapticsClient.live)
│   ├── CookieUtil.swift           # DELETED
│   ├── UserDefaultsUtil.swift     # folded into UserDefaultsClient (impl moves; AppUserDefaults enum stays/shrinks)
│   └── FileUtil.swift             # RETAINED as pure namespace (D-06)
├── AppModels/Utilities/
│   ├── AppUtil.swift              # type ELIMINATED (dispatchMainSync deleted; version/build/isTesting relocated)
│   ├── URLUtil.swift              # RETAINED; builders gain host param (D-03/D-06)
│   └── Defaults+Runtime.swift     # Defaults.URL.host global DELETED; host-derived helpers take host
├── CookieClient/CookieClient.swift        # absorbs didLogin (already present); apiuid/setSkipServer take host
├── ImageClient/ImageClient.swift          # resolve @Dependency(\.dataCache); drop `.shared` defaults
└── AuthorizationClient/                    # empty dir — DELETE (Claude's discretion)
AppPackage/Tests/
├── CookieClientTests/             # NEW target + .swiftlint.yml (parent_config)
└── ImageClientTests/              # NEW target + .swiftlint.yml (parent_config)
```

### Pattern 1: Standalone actor as a `DependencyKey` with singleton `liveValue` (D-08)
**What:** Give `DataCache` a dependency key whose `liveValue` is a single instance; consumers resolve `@Dependency(\.dataCache)` and all get the same actor.
**When to use:** A shared actor that needs process-wide identity for cache coherence but must be substitutable in tests.
**Example:**
```swift
// Source: pattern per TCA Dependencies (pfw-dependencies skill) + existing client keys in this repo
public enum DataCacheKey: DependencyKey {
    // liveValue is evaluated once and cached by DependencyValues → the four consumers
    // resolve the SAME actor instance (the singleton semantics D-08 requires).
    public static let liveValue = DataCache()
    // Discretion (D-08): unimplemented forces tests to inject a per-test instance;
    // or supply a fresh instance. Tests MUST NOT touch a process-global cache.
    public static var testValue: DataCache { /* unimplemented-style or fresh */ }
}
extension DependencyValues {
    public var dataCache: DataCache {
        get { self[DataCacheKey.self] }
        set { self[DataCacheKey.self] = newValue }
    }
}
```
`[CITED: TCA Dependencies — liveValue is memoized per DependencyValues cache]` — confirm the memoization holds for `static let` before locking the design.

### Pattern 2: In-body `@Dependency` in a SwiftUI View (D-04)
**What:** A `View` (which can't hold reducer state) reads a client via `@Dependency` in its body, re-reading each render.
**When to use:** `CookieUtil.didLogin` / `HapticsUtil.generateFeedback` / `DataCache.shared` view call sites where promoting to reducer state is disproportionate.
**Example:**
```swift
// Source: repo convention (Phase 5 D-01 @Dependency-only rule; ReadingView already uses @Dependency)
struct SomeView: View {
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.hapticsClient) private var hapticsClient
    var body: some View {
        if cookieClient.didLogin { /* login-gated control */ }
        Button("Tap") { hapticsClient.generateFeedback(.soft); /* ... */ }
    }
}
```
Read timing is identical to today (the statics were also read per render), so parity holds (D-04).

### Pattern 3: Host as an explicit `Request` parameter (D-03)
**What:** Each `Request` struct stores a `host` and builds URLs from it; reducers supply `setting.galleryHost`.
**Example:**
```swift
public struct SearchGalleriesRequest: Request {
    public init(host: GalleryHost, keyword: String, filter: Filter, urlSession: URLSession = .shared) { ... }
    public let host: GalleryHost
    // ...
    public func response() async throws(AppError) -> GalleriesResult {
        let request = URLRequest(url: URLUtil.searchList(host: host, keyword: keyword, filter: filter))
        // ...
    }
}
// URLUtil builder gains host:
public static func searchList(host: GalleryHost, keyword: String, filter: Filter) -> URL {
    host.url.appending(queryItems: [.fSearch: keyword]).applyingFilter(filter)
}
```
`GalleryHost.url` already resolves to the correct base (`ehentai`/`exhentai`), so threading `host: GalleryHost` and calling `host.url` is the clean substitution for `Defaults.URL.host`. `[VERIFIED: codebase — Setting.swift:154]`

### Anti-Patterns to Avoid
- **Leaving `Defaults.URL.host` alive "to be safe."** D-03 requires deleting it; a lingering global that reads a deleted `AppUtil.galleryHost` won't compile, and half-threading host defeats the requirement.
- **Making `URLUtil`/`FileUtil` into clients.** Violates D-06 + the anti-wrapper rule.
- **Reintroducing `DataCache.shared` for the purge observer.** The module-level observer currently binds `.shared`; after removal it must bind the dependency's `liveValue` instance (see Pitfall 3).
- **`@Suite(.serialized)` to dodge cache pollution.** The "inject over serialize" rule: use a per-test `DataCache(rootURL: UUID)` instead. (`ReaderImageDataTests` is currently `.serialized` for the shared URLProtocol handler registry, not the cache — the cache is already isolated.)
- **Bare numeric specifiers / unlabeled localized formats** in any new strings (project CLAUDE.md rule) — unlikely here but applies to any new UI copy.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Per-test cookie store | A new mock | `CookieClient.testing(...)` + `CookieClient.live(cookieStorage:)` | Both exist; the testing double models host-exact matching (a documented subtlety). `[VERIFIED: codebase]` |
| Deterministic image fetch stub | New URLProtocol harness | `SharedSessionStubURLProtocol` + `makeStubbedSession()` | Already built + proven in `ReaderImageDataTests`. `[VERIFIED: codebase]` |
| Isolated byte cache for tests | Custom temp dir plumbing | `DataCache(configuration: .init(rootURL: <UUID temp>))` (`makeIsolatedDataCache`) | Existing helper; satisfies the per-test-instance rule. `[VERIFIED: codebase]` |
| Singleton lifetime for `DataCache` | A hand-rolled global + lock | `DependencyKey.liveValue` memoization | The dependency system supplies singleton semantics (D-08). `[CITED: TCA Dependencies]` |
| Login gating | Re-derive from `HTTPCookieStorage` | `CookieClient.didLogin` accessor | Already implemented; `CookieUtil` is the redundant copy being deleted. `[VERIFIED: codebase]` |

**Key insight:** almost every "new" piece this phase needs already exists in the tree — the work is *deleting the redundant global path* and *pointing consumers at the client/parameter*, not building capability.

## Runtime State Inventory

> Rename/refactor phase — inventory required. Verified 2026-07-14.

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| **Stored data** | `UserDefaults["galleryHost"]` — the mirror written by `AccountSettingReducer.galleryHostChanged` and read at launch by `SettingReducer+Helpers`. Removed by D-03; host henceforth only in `@Shared(.setting)`. | **Code edit** (delete write + restore). No data migration needed — the accepted behavior change is that a lost setting blob resets host to `.ehentai`. The orphaned `UserDefaults` key becomes dead (harmless; optional cleanup, not required). `AppUserDefaults` enum shrinks to `clipboardChangeCount` only. |
| **Stored data (cookies)** | Auth cookies in `HTTPCookieStorage.shared` (`ipb_member_id`/`ipb_pass_hash`/`igneous`). | **None** — Keychain migration dropped (D-01); storage is unchanged. |
| **Live service config** | None. No external service embeds any renamed string. | None — verified (no n8n/Datadog/etc. in this app). |
| **OS-registered state** | None. No Task Scheduler / launchd / pm2 names reference these Utils. | None — verified. |
| **Secrets/env vars** | `XCTestConfigurationFilePath` env read (in `AppUtil.isTesting`) — the env var is OS-provided, not renamed; only the reading Swift symbol relocates (D-07). | **Code edit** (relocate the read). No secret/key rename. |
| **Build artifacts** | (1) Empty `AppPackage/Sources/AuthorizationClient/` dir (Phase 7 leftover, no Package.swift/code refs — verified). (2) Package.swift target graph changes (two new test targets; optional AuthorizationClient removal). | **Delete** the empty dir; **Xcode/SPM re-resolves** the package graph on Package.swift edit (no `swift package resolve` of external deps needed — no dependency version changes). |

**Nothing found in categories** *Live service config* and *OS-registered state* — verified by grep across the source tree and the absence of any service/scheduler integration in this iOS app.

## Common Pitfalls

### Pitfall 1: Under-counting the `galleryHost` blast radius
**What goes wrong:** Threading host only through the "44 requests" leaves `CookieClient.apiuid`/`setSkipServer` (read `Defaults.URL.host` at lines 200/319), `Parser+Shared` (default `host: URL = Defaults.URL.host`, line 95), and 3 `SettingFeature` sites (`SettingReducer+Body:109`, `SettingReducer+Helpers:127`, `EhSettingReducer:113`) still reading a deleted global → compile break.
**Why it happens:** The global fan-out is invisible at the request layer; `Defaults.URL.host` and its derived siblings hide the dependency.
**How to avoid:** Enumerate **every** `Defaults.URL.host` reader (8 files) **and** every host-derived `Defaults.URL.{api,myTags,uConfig,popular,watched,favorites,galleryPopups,galleryTorrents}` reader (21 sites) before deleting the global; convert derived statics into host-taking helpers (e.g. `Defaults.URL.api(host:)`) or inline `host.url.appendingPathComponent(...)`.
**Warning signs:** "Cannot find `host` / `AppUtil` in scope" after deleting the global.

**Verified host-global consumer inventory:**
- `Defaults.URL.host` direct reads (8 files): `URLUtil.swift` (4), `CookieClient.swift` (`apiuid:200`, `setSkipServer:319`), `Parser+Shared.swift:95`, `Request+Image.swift:331`, `Request+GalleriesMetadata.swift:52`, `SettingReducer+Helpers.swift:127`, `SettingReducer+Body.swift:109`, `EhSettingReducer.swift:113`.
- Host-derived `Defaults.URL.*` reads (21): concentrated in `Request+Account.swift` (uConfig/favorites/api ×8), `Request+Image.swift` (apiURL default ×2), `Request.swift:288`, `Request+GData.swift:27`, `URLUtil.swift` (popular/watched/favorites/toplist/galleryTorrents/galleryPopups ×7), `AccountSettingView.swift:38` (myTags), `EhSettingView.swift:104` (uConfig).
- `AppUtil.galleryHost` reads (12): `EhSettingView.swift:14`, `EhSettingView+Sections2.swift:44`, `ToplistsView.swift:54`, `GalleryThumbnailCell.swift:48`, `GalleryDetailCell.swift:137`, `CategoryView.swift:75`, `DetailView.swift:64`, `DetailView+HeaderSection.swift:60`, `DetailReducer+Download.swift:192`, `Defaults+Runtime.swift:14`. (Plus `AboutView.swift:11` reads `AppUtil.version/build`; `AppDelegateReducer.swift:62` reads `AppUtil.isTesting`.)

### Pitfall 2: `CookieUtil.didLogin` vs `CookieClient.didLogin` semantic drift
**What goes wrong:** `CookieUtil.verify` reads `HTTPCookieStorage.shared` directly and checks `cookie.expiresDate > .now`; `CookieClient.didLogin` composes `getCookie(...)` (which returns `.cookieValueExpired` for past-dated cookies and treats the ExHentai `igneous == mystery` as not-logged-in). They *should* be equivalent, but the eh-vs-ex + `igneous` present/mystery/absent + expiry axes are exactly where a subtle mismatch would hide.
**Why it happens:** Two independent implementations of the same predicate.
**How to avoid:** Write the D-10 `didLogin` matrix **first** (against `CookieClient.testing(...)`), confirm it matches expected truth values, then delete `CookieUtil`. The 12 view sites are login-gated real controls (download/archive/comment buttons) — a drift is user-visible.
**Warning signs:** A login-gated button that appears/disappears differently after the swap.

### Pitfall 3: The `DataCache` system-purge observer still points at `.shared`
**What goes wrong:** `DataCache.swift` has a module-level `dataCacheSystemPurgeObserver = DataCacheSystemPurgeObserver(cache: .shared)` (line 294) and `installSystemPurgeObservers()` (called by `LibraryClient.swift:58`). Deleting `.shared` orphans the observer, or worse, it observes a *different* instance than consumers use → memory-warning/background purges hit the wrong cache and never clear the real one.
**Why it happens:** The observer's singleton reference is separate from the new dependency key.
**How to avoid:** Bind the observer to the **same** instance as `DataCacheKey.liveValue` (e.g. `installSystemPurgeObservers()` resolves `@Dependency(\.dataCache)` and passes it in, or the module keeps a single canonical instance that both the key and the observer share). Verify actor identity: consumers + observer must be the one instance.
**Warning signs:** Memory grows across backgrounding; `removeAllMemory`/`sweepDisk` appear to no-op.

### Pitfall 4: `ImageClient.live` hardcodes `.shared` in two places
**What goes wrong:** Besides the `dataCache: DataCache = .shared` stored default (line 23), `ImageClient.live.prefetchImages` calls `readerImageData(url:, dataCache: .shared, urlSession: .shared)` (line 36). Dropping only the property default still leaves prefetch on the global cache.
**How to avoid:** Resolve `@Dependency(\.dataCache)` when building `ImageClient.live` and use it in **both** the property and the prefetch closure; drop both `.shared` literals.
**Warning signs:** Prefetch writes to a different cache than display reads → duplicate downloads.

### Pitfall 5: New test targets missing `parent_config` lint / Package wiring
**What goes wrong:** A new `CookieClientTests`/`ImageClientTests` dir without a `.swiftlint.yml` (`parent_config: ../../../.swiftlint.yml`) escapes the project's lint-as-error rules; missing `Module` enum case or `testTarget` entry → target not built/run.
**How to avoid:** Mirror the existing `ImageColorsTests` target: add a `case cookieClientTests = "CookieClientTests"` (+ image) to the `Module` enum, add a `.testTarget(module:..., dependencies:[.module(.cookieClient)/.imageClient, ...], plugins: swiftLintPlugins)`, and add `Tests/<Name>Tests/.swiftlint.yml` with the parent config. `[VERIFIED: codebase — ImageColorsTests]`
**Warning signs:** Lint passes locally but tests don't appear in the suite; or new tests violate rules silently.

## Code Examples

### Folding `HapticsUtil` into `HapticsClient.live` (D-05)
```swift
// AFTER: HapticsClient.live owns the device-detection + legacy-feedback logic;
// HapticsUtil.swift is deleted. Note @MainActor is preserved on the closures.
extension HapticsClient {
    public static let live: Self = .init(
        generateFeedback: { style in
            guard !isLegacyTapticEngine else { generateLegacyFeedback(); return }
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        },
        generateNotificationFeedback: { style in
            guard !isLegacyTapticEngine else { generateLegacyFeedback(); return }
            UINotificationFeedbackGenerator().notificationOccurred(style)
        }
    )
    // private static isLegacyTapticEngine / generateLegacyFeedback move here verbatim.
}
```

### `CookieClient` header-parsing test with an isolated storage (D-10)
```swift
// Source: pattern per CookieClient.live(cookieStorage:) + repo Swift Testing conventions
@Test func setCredentialsParsesSetCookieHeader() async throws {
    let storage = HTTPCookieStorage()                     // per-test, NOT .shared
    let client = CookieClient.live(cookieStorage: storage)
    let response = try #require(HTTPURLResponse(
        url: Defaults.URL.ehentai, statusCode: 200, httpVersion: nil,
        headerFields: ["Set-Cookie": "ipb_member_id=42; ipb_pass_hash=deadbeef"]
    ))
    client.setCredentials(response: response)
    #expect(client.getCookie(Defaults.URL.ehentai, Defaults.Cookie.ipbMemberId).rawValue == "42")
}
```

### `ImageClient` cache-hit test with pixel-dimension comparison (D-10)
```swift
// Source: adapted from ReaderImageDataTests (existing) — per-test cache, decoded pixel dims
@Test func servesCacheHitWithoutNetwork() async throws {
    let (cache, rootURL) = makeIsolatedDataCache()
    defer { try? FileManager.default.removeItem(at: rootURL) }
    let url = try #require(URL(string: "https://example.com/reader/hit.png"))
    let bytes = try makePNGData()                          // 2×2 red PNG
    try await cache.store(bytes, forKeys: url.imageCacheKeys)
    var client = ImageClient.live; client.dataCache = cache; client.urlSession = /* stub */
    let asset = try await client.fetchImageAsset(url: url).get()
    #expect(asset.image.cgImage?.width == 2)               // decoded pixel dims, not point size
    #expect(asset.image.cgImage?.height == 2)
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `*Util` statics + singletons | `@Dependency` clients / explicit params | This milestone (HYG-01); Device slice done Phase 5 | Testable, substitutable seams |
| `DataCache.shared` global | `@Dependency(\.dataCache)` (actor unchanged) | This phase (D-08) | Injectable in tests; identity via dependency system |
| Cookies → Keychain (planned) | Stay in `HTTPCookieStorage`; audit logging only | Rescoped this phase (D-01) | Avoids Keychain-orphaning on sideload re-sign |
| Host via `UserDefaults` mirror + global | Host only in `@Shared(.setting)`, threaded as param | This phase (D-03) | One source of truth; accepted `.ehentai` reset on blob loss |

**Deprecated/outdated:**
- `CookieUtil`, `HapticsUtil`, `AppUtil`, `DataCache.shared`, `Defaults.URL.host` (global), the `galleryHost` `UserDefaults` mirror — all removed this phase.
- ROADMAP Phase-8 goal + success-criterion-2 "move session cookies to Keychain" — **stale**; reconcile to logging-audit-only (D-01).

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `DependencyKey.liveValue` declared `static let` is memoized once per `DependencyValues` cache, giving the four `DataCache` consumers the same actor instance. | Pattern 1 / D-08 | If liveValue were re-created per resolution, cache coherence breaks. Mitigate: confirm against the Dependencies library before locking; a canonical module-level instance shared by key + observer removes all doubt. `[ASSUMED — cross-check pfw-dependencies]` |
| A2 | "ImageClient failure **retry**" (D-10) maps to the existing behaviors: cache-miss re-fetch and the placeholder-purge-and-refetch path — **not** a retry loop inside `ImageClient` (the 4-attempt retry lives in `NetworkingFeature.Request.fetch`, not `ImageClient.readerImageData`). | QUAL-02 / Validation | If "retry" means something else, the ImageClient suite may miss an intended case. Mitigate: confirm scope of "failure retry" with owner during planning. `[ASSUMED]` |
| A3 | The orphaned `UserDefaults["galleryHost"]` key can be left in place (dead) rather than actively cleared. | Runtime State Inventory | If the owner wants a clean removal, add a one-time delete. Low risk (harmless dead key). `[ASSUMED]` |
| A4 | The empty `AppPackage/Sources/AuthorizationClient/` dir is fully orphaned (no Package.swift/code refs — verified) and safe to delete. | Structure / Runtime Inventory | Verified via grep; risk minimal. `[VERIFIED: codebase]` |

## Open Questions

1. **Host-derived `Defaults.URL.*` shape after the global is deleted.**
   - What we know: `api/myTags/uConfig/popular/watched/favorites/galleryPopups/galleryTorrents` are all `host.appendingPathComponent(...)`; 21 consumers.
   - What's unclear: whether the planner prefers host-taking static helpers (`Defaults.URL.api(host:)`) or inlining `host.url.appendingPathComponent("api.php")` at each site.
   - Recommendation: host-taking helpers keep the change mechanical and preserve the path strings in one place; decide in planning.

2. **Scope of "ImageClient failure retry" (A2).** Clarify whether it covers only the existing re-fetch/purge behaviors or expects a new retry.

3. **`CookieClient.apiuid`/`setSkipServer` host source.** They read `Defaults.URL.host` internally; after deletion they need host. Their callers (`DetailReducer+Fetch`, `CommentsReducer`, `ReadingReducer+ImageFetch`, `SettingReducer+Body`) all have `@Shared`/`@SharedReader(.setting)` access — recommend passing `host: GalleryHost` into these accessors. Confirm the accessor signatures during planning.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode + iOS Simulator toolchain | Build + `xcodebuild test` | ✓ (project baseline) | project-pinned | — |
| `swift-composable-architecture` | DI + tests | ✓ | `from: 1.25.3` + traits (Phase 4) | — |
| SwiftLint build-tool plugin | lint-as-error gate | ✓ | repo-pinned | — |

**Missing dependencies with no fallback:** none.
**Missing dependencies with fallback:** none. This is a code/config-only phase against the existing toolchain. **Constraint (not a dependency):** `xcodebuild test` invocations must never overlap (wedges `testmanagerd`).

## Validation Architecture

> `workflow.nyquist_validation` is enabled — section included. The parity guarantee is that every seam swap is behavior/appearance-preserving; observability = compile-time completeness + existing suites green + new deterministic seam tests + a cookie-logging grep gate.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (`import Testing`) + TCA `TestStore`/`withDependencies` |
| Config file | none (SPM test targets in `AppPackage/Package.swift`); test plan `Tests/FeatureTests.xctestplan` |
| Quick run command | `xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:CookieClientTests` (scope to the target under change) |
| Full suite command | `xcodebuild test -scheme AppPackage-Package -destination 'platform=iOS Simulator,name=iPhone 16'` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| HYG-01 | Utils folded/deleted; package compiles with no `*Util`/`.shared`/global-host reference | build (compile-completeness) | `xcodebuild build -scheme AppPackage-Package -destination '...'` | n/a (build) |
| HYG-01 | `galleryHost` parameterization preserves request URLs | integration (reuse) | full `NetworkingFeatureTests` (Phase-4 baselines) | ✅ existing |
| HYG-01 | Login-gating parity after `CookieUtil` delete | unit | `CookieClientTests` `didLogin` matrix | ❌ Wave 0 |
| HYG-01 | `DataCache` consumers share one instance; purge observer bound to it | unit + manual | `ImageClientTests` cache identity; device background-purge check | ❌ Wave 0 (+ manual) |
| QUAL-01 | No cookie value logged at `.public` | static gate | grep assertion (see Sampling) + code review | ❌ Wave 0 (add gate) |
| QUAL-02 | `CookieClient` matrix (didLogin/setCredentials/setSkipServer/syncExCookies/fulfillAnotherHostField/importAutomationCookies) | unit | `-only-testing:CookieClientTests` | ❌ Wave 0 |
| QUAL-02 | `ImageClient` cache hit/miss + failure/placeholder handling, pixel dims | unit | `-only-testing:ImageClientTests` | ⚠️ partial (equivalent tests live in `DownloadsFeatureTests/ReaderImageDataTests.swift`; relocate/adapt into the dedicated target) |
| QUAL-02 | `NetworkingFeature` async layer | integration (reuse) | `-only-testing:NetworkingFeatureTests` | ✅ existing (Phase 4) |

### Manual / device checks (not unit-observable)
- **Haptic firing** on the 4 migrated sites (EhSettingView+Sections3, CategoryView, SubSection, ArchivesView) — feedback can't be asserted in a unit test; device tap check.
- **Host switch end-to-end** (eh ↔ ex) exercising a live search/frontpage/favorites/detail request after parameterization.

### Sampling Rate
- **Per task commit:** quick build + the changed target's tests (`-only-testing:<Target>`); commit-per-task per repo convention.
- **Per wave merge:** full `xcodebuild test` suite (single invocation, never overlapping) — Phase-4 `NetworkingFeature` baselines are the parity guard for the host-parameterization wave.
- **Phase gate:** full suite green + SwiftLint clean (build-tool plugin, error-level) + the cookie-logging grep gate green before `/gsd-verify-work`.

### Cookie-logging audit gate (QUAL-01, D-02)
A deterministic static check the phase can lock in (the audit found **zero** offending sites today):
- Sweep all `logger.{info,error,debug,notice,warning,fault,trace}` interpolations; assert none carry a cookie value (`ipb_member_id`/`ipb_pass_hash`/`igneous` values or `getCookiesDescription`) at `.public`.
- Confirm `getCookiesDescription` remains clipboard-only (`AccountSettingReducer.copyCookies`), never passed to a logger.
- Recommend encoding this as a small script/test or a documented review checklist so a future regression is caught.

### Wave 0 Gaps
- [ ] `Tests/CookieClientTests/` — new target + `.swiftlint.yml` (`parent_config`); covers HYG-01 login parity + QUAL-02 cookie matrix.
- [ ] `Tests/ImageClientTests/` — new target + `.swiftlint.yml`; covers QUAL-02 image seam (relocate/adapt the existing `ReaderImageDataTests` cases; keep per-test isolated cache).
- [ ] Package.swift: two `Module` enum cases + two `testTarget` entries.
- [ ] Cookie-logging grep gate (script or checklist) for QUAL-01.
- [ ] No framework install needed — Swift Testing + TCA already present.

## Security Domain

> `security_enforcement` enabled (ASVS level 1). This is a parity refactor touching credential handling (cookies) and a shared cache — relevant categories below.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes | Auth cookies (`ipb_member_id`/`ipb_pass_hash`/`igneous`) via `CookieClient`; storage unchanged (`HTTPCookieStorage.shared`) — Keychain migration deliberately dropped (D-01, with documented sideload-orphaning rationale). |
| V3 Session Management | yes | `didLogin`/`syncExCookies`/`fulfillAnotherHostField` session-cookie logic; parity locked by the D-10 matrix. |
| V6 Cryptography | no | No crypto changes. (`DataCache` uses SHA-256 only for cache **filenames**, not security.) |
| V7 Errors & **Logging** | **yes** | **QUAL-01 core:** no cookie value emitted to logs at `.public` (D-02). Audit result: no such site exists today; add a gate to keep it that way. |
| V8 Data Protection | yes | Cookie values are intentionally user-portable (Settings UI + clipboard export) — accepted at-rest posture (D-01). No new exposure introduced. |

### Known Threat Patterns for {SwiftUI/TCA iOS, cookie auth}
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Credential leakage via logs | Information Disclosure | `.private` interpolation / omit; QUAL-01 audit + grep gate (D-02). |
| Cookie value in URL/query logging | Information Disclosure | Cookies live in headers, not URLs; verified no header/`Set-Cookie` logging in `DFStreamHandler`/request code. |
| Wrong-host cookie collateral write (syncExCookies) | Tampering | `CookieClientTestingCookie.matches` uses **host-exact** matching (documented); cover in the `syncExCookies` test. |
| Shared-cache poisoning across consumers | Tampering | Single `DataCache` instance via the dependency key; placeholder-fingerprint rejection already guards poisoned bytes (`ImageClient.readerImageData`). |

**Security note:** the Keychain drop (D-01) is a deliberate, owner-reasoned decision (sideload Team-ID re-sign orphans Keychain items; `errSecMissingEntitlement -34018`; years of zero observed cookie loss; credentials already user-portable by design). It is a *scope* decision, not an unmitigated risk — the swift-security-expert rationale is captured in CONTEXT §D-01.

## Sources

### Primary (HIGH confidence)
- Codebase (verified this session): `AppTools/{DataCache,CookieUtil,HapticsUtil,UserDefaultsUtil,FileUtil}.swift`, `AppModels/Utilities/{AppUtil,URLUtil,Defaults+Runtime}.swift`, `CookieClient/CookieClient.swift`, `ImageClient/ImageClient.swift`, `HapticsClient/HapticsClient.swift`, `UserDefaultsClient/UserDefaultsClient.swift`, `NetworkingFeature/Request*.swift`, `SettingFeature/AccountSetting/AccountSettingReducer.swift`, `SettingFeature/SettingReducer+Helpers.swift`, `AppModels/Persistent/Setting.swift`, `Tests/DownloadsFeatureTests/ReaderImageDataTests.swift`, `AppPackage/Package.swift`.
- Grep-verified counts: `CookieUtil` (14 refs / `.didLogin` 12 view sites), `HapticsUtil` (5 refs / 4 view sites), `AppUtil` (12 refs), `DataCache.shared` (5 non-def sites), `Defaults.URL.host` (8 files), host-derived `Defaults.URL.*` (21 sites), `Request: Request` structs (44).
- `.planning/codebase/{STRUCTURE,CONVENTIONS,TESTING}.md`; `.planning/phases/08.../08-CONTEXT.md`; `.planning/REQUIREMENTS.md`; `.planning/STATE.md`; project `CLAUDE.md`/`.claude/CLAUDE.md`.

### Secondary (MEDIUM confidence)
- pfw-dependencies / pfw-composable-architecture / swift-testing-pro skill knowledge for `DependencyKey` and Swift Testing idioms (patterns cross-checked against in-repo usage).

### Tertiary (LOW confidence)
- A1 (`static let liveValue` memoization) — flagged for confirmation against the Dependencies library before locking the `DataCache` key design.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new packages; all components verified present in-tree.
- Architecture / blast radius: HIGH — every consumer enumerated via grep with file:line.
- Pitfalls: HIGH — each derived from a specific verified line (purge observer `.shared`, `ImageClient.live` double `.shared`, host fan-out).
- `DataCache` singleton semantics (A1): MEDIUM — standard TCA behavior, recommended cross-check.
- "ImageClient failure retry" scope (A2): MEDIUM — assumption flagged for owner confirmation.

**Research date:** 2026-07-14
**Valid until:** ~2026-08-13 (stable internal refactor; invalidated only by further edits to the listed source files before planning)
