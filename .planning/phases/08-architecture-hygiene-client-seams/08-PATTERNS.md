# Phase 8: Architecture Hygiene & Client Seams - Pattern Map

**Mapped:** 2026-07-14
**Files analyzed:** 18 modify targets + 2 new test targets + Package.swift
**Analogs found:** 18 / 18 (every seam has an in-repo template)

This is a **behavior/appearance-parity architecture refactor**. Almost nothing is net-new
capability — each "new" file is a new *test target*, and each change *folds an existing static
into an existing `@Dependency` client* or *threads an existing value as a parameter*. The analogs
below are the exact in-tree shapes to copy.

## File Classification

| File (modify/create) | Role | Data Flow | Closest Analog | Match Quality |
|----------------------|------|-----------|----------------|---------------|
| `Sources/AppModels/Utilities/Defaults+Runtime.swift` (host global → host-taking helpers) | config/model | transform | `URLUtil.swift` builders (same module) | exact |
| `Sources/AppModels/Utilities/URLUtil.swift` (builders gain `host:`) | utility (pure namespace) | transform | itself (mechanical param add) | exact |
| `Sources/NetworkingFeature/Request+*.swift` (host as explicit param) | service/request | request-response | `SearchGalleriesRequest` in `Request+Gallery.swift` | exact |
| `Sources/CookieClient/CookieClient.swift` (`apiuid`/`setSkipServer` take host; absorb didLogin; log audit) | client | request-response | its own `live(cookieStorage:)` + `didLogin` accessor | exact |
| `Sources/SettingFeature/AccountSetting/AccountSettingReducer.swift` (delete mirror write) | reducer | event-driven | `@Shared(.setting)` read pattern | role-match |
| `Sources/SettingFeature/SettingReducer+Helpers.swift` (delete launch restore) | reducer | event-driven | `@Shared(.setting)` read pattern | role-match |
| `Sources/AppTools/HapticsUtil.swift` (**delete**; fold into client) | utility | event-driven | `HapticsClient.live` | exact |
| `Sources/HapticsClient/HapticsClient.swift` (absorb Util impl) | client | event-driven | itself + `HapticsUtil` | exact |
| `Sources/AppTools/CookieUtil.swift` (**delete**) | utility | — | `CookieClient.didLogin` (already covers it) | exact |
| `Sources/AppTools/UserDefaultsUtil.swift` (fold into client) | utility | file-I/O | `UserDefaultsClient.live` | exact |
| `Sources/UserDefaultsClient/UserDefaultsClient.swift` (absorb Util impl) | client | file-I/O | itself | exact |
| `Sources/AppModels/Utilities/AppUtil.swift` (**eliminate type**) | utility | — | small constants namespace (`FileUtil`) | role-match |
| `Sources/AppTools/FileUtil.swift` (retain pure) | utility (pure namespace) | — | itself | exact |
| `Sources/AppTools/DataCache.swift` (+ `DependencyKey`, drop `.shared`) | model/actor | file-I/O + event-driven | `ImageClientKey`/`HapticsClientKey` DependencyKey shape | role-match |
| `Sources/ImageClient/ImageClient.swift` (resolve `\.dataCache`; drop `.shared`) | client | streaming/file-I/O | itself | exact |
| `Sources/LibraryClient/LibraryClient.swift` (`.shared`→`\.dataCache`) | client | file-I/O | `DataCache.shared` sites | exact |
| `Sources/DownloadClient/DownloadClient+Cache.swift` (`.shared`→`\.dataCache`) | client | file-I/O | `DataCache.shared` sites | exact |
| `Sources/ReadingFeature/ReadingView.swift` (`.shared`→`@Dependency`) | view | request-response | its own `@Dependency(\.deviceClient)` | exact |
| 12 `CookieUtil.didLogin` + 4 `HapticsUtil` view sites | view | request-response | `ReadingView` in-body `@Dependency` | exact |
| `Tests/CookieClientTests/` (**new**) | test | request-response | `CookieClient.testing(...)` + Swift Testing | role-match |
| `Tests/ImageClientTests/` (**new**) | test | streaming/file-I/O | `Tests/DownloadsFeatureTests/ReaderImageDataTests.swift` | exact |
| `Package.swift` (2 Module cases + 2 testTargets) | config | — | `.imageColorsTests` testTarget entry | exact |

---

## Pattern Assignments

### Seam A — `galleryHost` parameterization (largest blast radius, D-03)

#### `Sources/AppModels/Utilities/Defaults+Runtime.swift` (host global → host-taking helpers)

**Analog:** itself (current global form) + `URLUtil` builders.

**BEFORE** (`Defaults+Runtime.swift:13-23`) — the global to delete:
```swift
extension Defaults.URL {
    public static var host: Foundation.URL { AppUtil.galleryHost == .exhentai ? exhentai : ehentai }
    public static var api: Foundation.URL { host.appendingPathComponent("api.php") }
    public static var myTags: Foundation.URL { host.appendingPathComponent("mytags") }
    // uConfig / galleryPopups / galleryTorrents / popular / watched / favorites …
}
```
**AFTER pattern:** delete `host`; convert each derived sibling to a host-taking helper
(`Defaults.URL.api(host:)`) or use `GalleryHost.url` at the call site. `GalleryHost.url`
already resolves eh/ex (`Setting.swift:154`), so `host.url.appendingPathComponent("api.php")`
is the clean substitution. **Enumerate every reader first** (Pitfall 1): 8 `Defaults.URL.host`
direct-read files + 21 host-derived `Defaults.URL.*` sites before deleting the global, or the
build breaks with "Cannot find `host`/`AppUtil` in scope".

#### `Sources/AppModels/Utilities/URLUtil.swift` (builders gain `host:`)

**Analog:** itself — the change is purely adding a `host: GalleryHost` param and replacing
`Defaults.URL.host` / `Defaults.URL.popular` etc. with `host.url` / host-taking helper.

**BEFORE** (`URLUtil.swift:6-8`):
```swift
public static func searchList(keyword: String, filter: Filter) -> URL {
    Defaults.URL.host.appending(queryItems: [.fSearch: keyword]).applyingFilter(filter)
}
```
**AFTER** (from RESEARCH §Pattern 3):
```swift
public static func searchList(host: GalleryHost, keyword: String, filter: Filter) -> URL {
    host.url.appending(queryItems: [.fSearch: keyword]).applyingFilter(filter)
}
```
Apply the same `host:`-prepended signature to all 19 builders that currently read the global.

#### `Sources/NetworkingFeature/Request+*.swift` (host becomes explicit `Request` param)

**Analog:** `SearchGalleriesRequest` in `Request+Gallery.swift:8-38` — copy its stored-property +
`init` + `response()` shape, adding a `host`.

**BEFORE** (`Request+Gallery.swift:8-24`):
```swift
public struct SearchGalleriesRequest: Request {
    public init(keyword: String, filter: Filter, urlSession: URLSession = .shared) {
        self.keyword = keyword; self.filter = filter; self.urlSession = urlSession
    }
    public let keyword: String
    public let filter: Filter
    public let urlSession: URLSession
    public func response() async throws(AppError) -> GalleriesResult {
        let request = URLRequest(url: URLUtil.searchList(keyword: keyword, filter: filter))
        // …
    }
}
```
**AFTER pattern:** add `public let host: GalleryHost`, add `host:` to `init`, pass
`host: host` into the `URLUtil.searchList(...)` call. Reducers construct
`SearchGalleriesRequest(host: setting.galleryHost, keyword:, filter:)`. Phase-4
`NetworkingFeatureTests` baselines are the parity guard for this wave.

#### `Sources/CookieClient/CookieClient.swift` — `apiuid`/`setSkipServer` host source

**Analog:** the accessor block itself (`CookieClient.swift:199-201`).

**BEFORE** (`CookieClient.swift:199-201`):
```swift
public var apiuid: String {
    getCookie(Defaults.URL.host, Defaults.Cookie.ipbMemberId).rawValue
}
```
**AFTER pattern:** take `host: GalleryHost` (accessor → method) and use `host.url`. `setSkipServer`
at line 319 similarly reads `Defaults.URL.host` → thread host. Callers
(`DetailReducer+Fetch`, `CommentsReducer`, `ReadingReducer+ImageFetch`, `SettingReducer+Body`)
all have `@Shared`/`@SharedReader(.setting)` — pass `host: setting.galleryHost` (Open Q3).

#### `AccountSettingReducer.swift` + `SettingReducer+Helpers.swift` — delete the mirror

**Analog:** the existing `@Shared(.setting)` read pattern (single source of truth).
Delete `AccountSettingReducer.galleryHostChanged`'s `UserDefaults` write and the
`SettingReducer+Helpers:127` launch restore. Host henceforth lives **only** in
`@Shared(.setting).galleryHost`. `AppUserDefaults` enum shrinks to `clipboardChangeCount` only
(in-place v1 edit — no `VersionedSchema` bump).

---

### Seam B — Util folds + view `@Dependency` swaps (D-04/D-05)

#### `Sources/HapticsClient/HapticsClient.swift` (fold `HapticsUtil` in, delete the Util)

**Analog:** `HapticsClient.live` (`HapticsClient.swift:11-19`) currently delegates to the Util;
`HapticsUtil.swift:6-38` is the impl to move in verbatim.

**BEFORE** (`HapticsClient.swift:11-19`):
```swift
public static let live: Self = .init(
    generateFeedback: { style in HapticsUtil.generateFeedback(style: style) },
    generateNotificationFeedback: { style in HapticsUtil.generateNotificationFeedback(style: style) }
)
```
**AFTER** (RESEARCH §"Folding HapticsUtil"): inline the guard body; move
`private static isLegacyTapticEngine` (`HapticsUtil.swift:29-38`) and `generateLegacyFeedback`
(`HapticsUtil.swift:22-27`) into `HapticsClient` **verbatim** (preserve `@MainActor` on the
closures). Then delete `Sources/AppTools/HapticsUtil.swift`.

#### `Sources/UserDefaultsClient/UserDefaultsClient.swift` (fold `UserDefaultsUtil` in)

**Analog:** `UserDefaultsClient.swift:16-19` already the only real consumer of
`UserDefaultsUtil.value(forKey:)`:
```swift
public func getValue<T: Codable>(_ key: AppUserDefaults) -> T? {
    UserDefaultsUtil.value(forKey: key)
}
```
**AFTER pattern:** inline `UserDefaultsUtil`'s `value(forKey:)` body here (the `AppUserDefaults`
enum type stays/shrinks in AppTools), delete the standalone `UserDefaultsUtil.swift`.

#### The 12 `CookieUtil.didLogin` + 4 `HapticsUtil` view sites → in-body `@Dependency`

**Analog:** `ReadingView.swift:19,41` — the repo's canonical in-body `@Dependency` read.

**Property form** (`ReadingView.swift:19`):
```swift
@Dependency(\.deviceClient) private var deviceClient
```
**Init-scope form** (`ReadingView.swift:41`, for use inside `init`):
```swift
@Dependency(\.deviceClient) var deviceClient
```
**AFTER pattern** (RESEARCH §Pattern 2): each view declares
`@Dependency(\.cookieClient) private var cookieClient` /
`@Dependency(\.hapticsClient) private var hapticsClient`, then `cookieClient.didLogin` /
`hapticsClient.generateFeedback(style:)`. Direct `.live`/`.shared`/static is **forbidden in
consumers** (Phase 5 D-01 extended). Read timing is unchanged (statics were per-render too), so
parity holds. Example gated site — `DetailView.swift:64`:
```swift
&& (AppUtil.galleryHost == .ehentai || CookieUtil.didLogin),   // BEFORE
&& (setting.galleryHost == .ehentai || cookieClient.didLogin), // AFTER (host from store, login from client)
```
`CookieUtil.didLogin` (`CookieUtil.swift:5-7`) is exactly `CookieClient.didLogin`
(`CookieClient.swift:189-198`) — verify the eh/ex × igneous × expiry matrix in tests **first**
(Pitfall 2), then delete `CookieUtil.swift`.

---

### Seam C — `AppUtil` residue (D-07)

#### `Sources/AppModels/Utilities/AppUtil.swift` (**eliminate the type**)

**Analog:** `FileUtil.swift` — a pure static-namespace `struct` of constants/computed props.
- `dispatchMainSync` (`AppUtil.swift:26-32`): **delete** (zero callers).
- `galleryHost` (`AppUtil.swift:21-24`): **delete** (resolved by Seam A).
- `version`/`build` (`AppUtil.swift:5-10`) + `isTesting` (`AppUtil.swift:12-19`): relocate
  (Claude's discretion) — candidate: a small pure constants namespace like `FileUtil`, or inline
  at the two consumers (`AboutView.swift:11`, `AppDelegateReducer.swift:62`). The
  `XCTestConfigurationFilePath` env read moves with `isTesting` (no secret rename).

`URLUtil` and `FileUtil` are **retained as-is** pure namespaces (D-06 anti-wrapper). `FileUtil`
(`FileUtil.swift`) is the reference shape for any relocated constants.

---

### Seam D — `DataCache` dependency reshape (D-08)

#### `Sources/AppTools/DataCache.swift` (+ `DependencyKey`, drop `.shared`)

**Analog for the key shape:** `ImageClientKey`/`HapticsClientKey`
(`HapticsClient.swift:22-33`, `ImageClient.swift:170-181`):
```swift
public enum HapticsClientKey: DependencyKey {
    public static let liveValue = HapticsClient.live
    public static let previewValue = HapticsClient.noop
    public static let testValue = HapticsClient.unimplemented
}
extension DependencyValues {
    public var hapticsClient: HapticsClient {
        get { self[HapticsClientKey.self] }
        set { self[HapticsClientKey.self] = newValue }
    }
}
```
**AFTER** (RESEARCH §Pattern 1): add `DataCacheKey: DependencyKey` with
`liveValue = DataCache()` (or a canonical module-level instance), and a
`\.dataCache` `DependencyValues` accessor. **Delete `DataCache.shared`** (`DataCache.swift:40`).
`DataCache` stays an `actor` (type unchanged).

**Pitfall 3 — purge observer:** `DataCache.swift:294` binds
`dataCacheSystemPurgeObserver = DataCacheSystemPurgeObserver(cache: .shared)`. After removing
`.shared`, bind the observer to the **same** instance as `DataCacheKey.liveValue` (share one
canonical module-level instance between the key and the observer) — actor identity must match, or
memory-warning/background purges hit the wrong cache. `installSystemPurgeObservers()`
(`DataCache.swift:56-60`, called from `LibraryClient.swift:58`) references that observer.

**Discretion:** `testValue` = unimplemented-style OR fresh instance, but tests MUST use a per-test
`DataCache(configuration: .init(rootURL: <UUID temp>))` (D-08/D-10).

#### `Sources/ImageClient/ImageClient.swift` (resolve `\.dataCache`; drop both `.shared`)

**Pitfall 4 — two hardcoded `.shared`:**
- Property default (`ImageClient.swift:23`): `public var dataCache: DataCache = .shared`
- Prefetch closure (`ImageClient.swift:36`): `readerImageData(url: url, dataCache: .shared, urlSession: .shared)`

**AFTER pattern:** resolve `@Dependency(\.dataCache)` when building `ImageClient.live` and use it in
**both** places; drop both `.shared` literals (and the `urlSession` default keeps its own seam).
`readerImageData(url:dataCache:urlSession:)` (`ImageClient.swift:86`) already takes `dataCache`
explicitly — only the `.live` construction sites change.

#### `LibraryClient.swift` / `DownloadClient+Cache.swift` (`.shared` → resolved `\.dataCache`)

**Sites to swap** (all `DataCache.shared` → the injected instance):
- `LibraryClient.swift:63` `DataCache.shared.removeAll()`, `:124` `DataCache.shared.totalSize()`
- `DownloadClient+Cache.swift:15` `removeData(forKeys:)`, `:92` `data(forKeys:)`

**AFTER pattern:** resolve `@Dependency(\.dataCache)` inside each `live` value and use it (same
memoized instance as ImageClient/observer → cache coherence). `ReadingView` uses the in-body
`@Dependency(\.dataCache)` form (analog: `ReadingView.swift:19`).

---

### Seam E — Cookie-logging audit (QUAL-01, D-02)

**No fix needed — confirm-and-lock.** Sweep `logger.{info,error,debug,notice,warning,fault,trace}`
interpolations; assert none carry a cookie value (`ipb_member_id`/`ipb_pass_hash`/`igneous` values
or `getCookiesDescription`) at `.public`. `getCookiesDescription` flows only to the clipboard
(`AccountSettingReducer.copyCookies`), never a logger — keep it that way. Encode as a small
grep-gate script or documented review checklist. No analog swap; this is a static gate.

---

### Seam F — New test targets (QUAL-02, D-10)

#### `Tests/ImageClientTests/` (**new**)

**Analog (exact):** `Tests/DownloadsFeatureTests/ReaderImageDataTests.swift` — relocate/adapt its
cases into the dedicated target. Copy these helpers verbatim:

**Per-test isolated cache** (`ReaderImageDataTests.swift:309-313`):
```swift
private func makeIsolatedDataCache() -> (cache: DataCache, rootURL: URL) {
    let rootURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    return (DataCache(configuration: .init(rootURL: rootURL)), rootURL)
}
```
**Stubbed session** (`ReaderImageDataTests.swift:315-323`) + `makePNGData()` 2×2 PNG
(`:325-331`). **Pixel-dim comparison** (D-10) — compare `cgImage?.width/height`, not point size
(DataCache.shared pollution rule). Cache-hit/miss + failure/placeholder shapes are already written
(`:13-227`); adapt them + add `fetchImageAsset` pixel-dim assertions. Keep `@Suite(.serialized)`
only for the shared URLProtocol handler registry (not the cache — the cache is already isolated).

#### `Tests/CookieClientTests/` (**new**)

**Analog:** `CookieClient.testing(...)` (`CookieClient.swift:485-503`) for the in-memory matrix +
`CookieClient.live(cookieStorage:)` (`CookieClient.swift:23`) for header-parsing with a per-test
`HTTPCookieStorage()` (never `.shared`).

Matrix (D-10): `didLogin` (`CookieClient.swift:189-198`) full — eh vs ex hosts × `igneous`
present/mystery/absent × expiry; `setCredentials`/`setSkipServer` `Set-Cookie` header parsing
(`CookieClient.swift:294,311`); `syncExCookies` (`:217`, host-exact matching);
`fulfillAnotherHostField` (`:235`); `importAutomationCookies` (`:115`). Do **not** pad
`editCookie`/`removeYay`/`loadCookiesState`. Header-parse example (RESEARCH §Code Examples):
```swift
let storage = HTTPCookieStorage()              // per-test, NOT .shared
let client = CookieClient.live(cookieStorage: storage)
```

#### `Package.swift` (2 Module cases + 2 testTargets)

**Analog:** `.imageColorsTests` (`Package.swift:121` enum case, `:945-951` testTarget):
```swift
// Module enum (near line 121):
case imageColorsTests = "ImageColorsTests"
// testTarget (near line 945):
.testTarget(
    module: .imageColorsTests,
    dependencies: [.module(.imageColors)],
    plugins: swiftLintPlugins
),
```
**AFTER pattern:** add `case cookieClientTests = "CookieClientTests"` +
`case imageClientTests = "ImageClientTests"` to the `Module` enum; add two `.testTarget` entries
with `dependencies: [.module(.cookieClient), .module(.appModels), …]` /
`[.module(.imageClient), .module(.appTools), .module(.appModels), .module(.testingSupport)]`,
`plugins: swiftLintPlugins`. Each new test dir needs a `.swiftlint.yml` — see Shared Patterns.

---

## Shared Patterns

### DependencyKey + accessor (applies to `DataCacheKey`)
**Source:** `Sources/HapticsClient/HapticsClient.swift:22-33` (also `ImageClient.swift:170-181`).
The `enum …Key: DependencyKey { liveValue/previewValue/testValue }` + `DependencyValues` computed
property is the canonical shape for the new `DataCacheKey`.

### In-body `@Dependency` in a View
**Source:** `Sources/ReadingFeature/ReadingView.swift:19` (property) and `:41` (init scope).
**Apply to:** all 12 `CookieUtil.didLogin` + 4 `HapticsUtil` view sites, and `ReadingView`'s own
`DataCache.shared` → `@Dependency(\.dataCache)`.

### `.testing`/`.noop`/`.unimplemented` factory shape
**Source:** `HapticsClient.swift:36-48`, `UserDefaultsClient.swift:36-46`,
`CookieClient.swift:485` (`.testing`). New test suites hang off these existing doubles.

### `parent_config` `.swiftlint.yml` for new test targets (project rule)
**Source:** `Tests/ImageColorsTests/.swiftlint.yml` (single line):
```yaml
parent_config: ../../../.swiftlint.yml
```
**Apply to:** `Tests/CookieClientTests/.swiftlint.yml` and `Tests/ImageClientTests/.swiftlint.yml`
(mandatory per CLAUDE.md new-module rule + Pitfall 5).

### Deterministic fetch/cache test harness
**Source:** `Tests/DownloadsFeatureTests/ReaderImageDataTests.swift` — `makeIsolatedDataCache`,
`makeStubbedSession`, `SharedSessionStubURLProtocol`, `makePNGData`, `TestFixtures`.
**Apply to:** `ImageClientTests` (reuse directly).

---

## No Analog Found

None. Every seam has an in-tree template; nothing here builds new capability.

---

## Metadata

**Analog search scope:** `AppPackage/Sources/{AppTools,AppModels,CookieClient,ImageClient,`
`HapticsClient,UserDefaultsClient,LibraryClient,DownloadClient,NetworkingFeature,ReadingFeature,`
`SettingFeature,DetailFeature}`, `AppPackage/Tests/{DownloadsFeatureTests,ImageColorsTests}`,
`AppPackage/Package.swift`.
**Files scanned:** ~20 source files + 1 test target + Package.swift.
**Pattern extraction date:** 2026-07-14
</content>
</invoke>
