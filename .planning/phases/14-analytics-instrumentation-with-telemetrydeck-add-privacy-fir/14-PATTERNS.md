# Phase 14: Analytics Instrumentation (TelemetryDeck) - Pattern Map

**Mapped:** 2026-07-24
**Files analyzed:** 20 (6 new, 14 modified)
**Analogs found:** 19 / 20

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `AppPackage/Sources/AnalyticsClient/AnalyticsClient.swift` (new) | client (`@Dependency`) | fire-and-forget event emit | `AppPackage/Sources/HapticsClient/HapticsClient.swift` | exact |
| `AnalyticsClient/AnalyticsClient.swift` — the D-13 `live` gate | client factory w/ runtime-absent gate | config read | `AppPackage/Sources/DownloadClient/DownloadClient.swift` (`liveValue = .live()` factory + `.noop`/bare `testValue`) | role-match |
| `AnalyticsClient/AnalyticsDefaultParameters.swift` (new) | utility | `@Shared` read at call time | `DownloadClient.swift:80,120` (`@Shared(.setting)` read *inside* the closure) + `CookieClient/DidLoginKey.swift` (`@SharedReader(.didLogin)`) | exact |
| `AnalyticsClient/AnalyticsSignal.swift`, `+Rendering.swift`, `Buckets.swift` (new) | model / value types | transform | `AppPackage/Sources/AppModels/Support/AppError.swift` (closed enum + derived rendering) | role-match |
| `AppPackage/Sources/AnalyticsClient/.swiftlint.yml` (new) | config | — | `AppPackage/Sources/HapticsClient/.swiftlint.yml` | exact |
| `AppPackage/Package.swift` (modified) | config | — | its own `.cookieClient` / `.hapticsClient` entries | exact |
| `AppPackage/Tests/AnalyticsClientTests/` (new) | test target | — | `AppPackage/Tests/CookieClientTests/` (client-level test target, has `.swiftlint.yml`) | exact |
| `AppPackage/Tests/FeatureTests.xctestplan` (modified) | config | — | its own `CookieClientTests` entry | exact |
| `AppPackage/Sources/AppModels/Utilities/AppInfo.swift` (modified) | utility | bundle read | itself (`version` / `build` accessors) | exact |
| `App/Info.plist` (modified) | config | build-var substitution | its own `$(EXECUTABLE_NAME)` / `$(DEVELOPMENT_LANGUAGE)` keys | exact |
| `Config/Analytics.xcconfig` + `.gitignore` (new/modified) | config | — | `.gitignore:7` `Config/LocalSigning.xcconfig` (vestigial precedent only) | partial |
| `AppFeature/DataFlow/AppDelegateReducer.swift` (modified) | reducer | launch sequencing | itself — `.onLaunchFinish` `.merge` of `.run(operation:)` calls | exact |
| `HomeFeature/HomeReducer.swift`, `HomeFeature/Toplists/ToplistsReducer.swift` (modified) | reducer | request-response / event | `ToplistsReducer.swift:146` fire-and-forget `hapticsClient` call | exact |
| `SearchFeature/SearchReducer.swift`, `SearchRootReducer.swift` (modified) | reducer | request-response | same | exact |
| `FavoritesFeature`, `DetailFeature/DetailReducer.swift`, `DownloadsFeature/DownloadsReducer.swift` (modified) | reducer | CRUD / streaming | same | exact |
| `ReadingFeature/ReadingReducer+Body.swift` (modified) | reducer | event-driven (session end) | itself — `.onPerformDismiss` (line 73) | exact |
| `SettingFeature/Login/LoginReducer.swift`, `Components/LaboratorySettingReducer.swift` (modified) | reducer | request-response | `LaboratorySettingReducer.swift:26-32` | exact |
| `AppFeature/DataFlow/PresentationFeature.swift` (modified) | reducer | event-driven | itself — line 212 `effects.append(.run(operation:))` | exact |
| Existing test suites (`DownloadsFeatureTests`, `SettingFeatureTests`, `AppFeatureTests`, `HomeFeatureTests`, `DetailFeatureTests`, `ReadingFeatureTests`) | test | — | `SettingReducerNavigationTests.makeStore()` + `AppActivityLogsReducerTests` `LockIsolated` spy | exact |
| `README.md` (modified) | docs | — | `README.md` §Content & Copyright | exact |

## Pattern Assignments

### `AppPackage/Sources/AnalyticsClient/AnalyticsClient.swift` (client, fire-and-forget)

**Analog:** `AppPackage/Sources/HapticsClient/HapticsClient.swift` (whole file, 43 lines — the canonical D-12 template)

**Imports + struct-of-closures** (lines 1-7):
```swift
import ComposableArchitecture
import SwiftUI

public struct HapticsClient: Sendable {
    public let generateFeedback: @MainActor @Sendable (UIImpactFeedbackGenerator.FeedbackStyle) -> Void
    public let generateNotificationFeedback: @MainActor @Sendable (UINotificationFeedbackGenerator.FeedbackType) -> Void
}
```
Note: `let` (not `var`) properties; no `import IssueReporting` — `IssueReporting` is reached
through `ComposableArchitecture`'s re-export. `sorted_imports` is an error-severity lint rule.

**`live` extension** (lines 9-14):
```swift
extension HapticsClient {
    public static let live: Self = .init(
        generateFeedback: { UIImpactFeedbackGenerator(style: $0).impactOccurred() },
        generateNotificationFeedback: { UINotificationFeedbackGenerator().notificationOccurred($0) }
    )
}
```

**`DependencyKey` + `DependencyValues`, under a `// MARK: API` banner** (lines 16-28):
```swift
// MARK: API
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

**`noop` / `unimplemented`, under a `// MARK: Test` banner** (lines 30-43):
```swift
// MARK: Test
extension HapticsClient {
    public static let noop: Self = .init(
        generateFeedback: { _ in },
        generateNotificationFeedback: { _ in }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        generateFeedback: IssueReporting.unimplemented(placeholder: placeholder()),
        generateNotificationFeedback: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
```

**Secondary analog for the D-13 gate — a `live` *factory* rather than a stored `let`:**
`AppPackage/Sources/DownloadClient/DownloadClient.swift:180-184`
```swift
// MARK: API
public enum DownloadClientKey: DependencyKey {
    public static let liveValue = DownloadClient.live()
    public static let previewValue = DownloadClient.noop
    public static let testValue = DownloadClient()
}
```
`DownloadClient.live()` is a `static func` that builds collaborators, kicks off launch work, and
returns `makeDownloadClient(manager:)`. That is the in-tree precedent for `AnalyticsClient.live`
doing conditional work (D-13: `guard appID != nil else { return .noop }`) before returning a
client. Note `DownloadClient` deviates on `testValue` (bare `init()` with defaulted closures) —
**do not copy that deviation**; D-12 locks `testValue = .unimplemented`, i.e. the `HapticsClient`
form.

---

### `AppPackage/Sources/AnalyticsClient/AnalyticsDefaultParameters.swift` (utility, `@Shared` read)

**Analog A — reading `@Shared(.setting)` *inside* a closure so it is re-read per call:**
`AppPackage/Sources/DownloadClient/DownloadClient.swift:78-82` and `:119-121`
```swift
downloadOptionsProvider: {
    @Shared(.setting) var setting
    return setting.downloadRequestOptions
}
```
```swift
fetchVersionMetadata: { gid, token in
    @Shared(.setting) var setting
    // ...
    switch await manager.fetchVersionMetadata(host: setting.galleryHost, gid: gid, token: token) {
```
This is exactly the D-11 / Pitfall-7 shape: declare the `@Shared` property wrapper *inside* the
closure body, never capture a snapshot outside it.

**Analog B — login state without taking a `CookieClient` module edge:**
`AppPackage/Sources/CookieClient/DidLoginKey.swift:52-57`
```swift
extension SharedReaderKey where Self == DidLoginKey.Default {
    /// `@SharedReader(.didLogin)` — live login state derived from the cookie jar.
    public static var didLogin: Self {
        Self[DidLoginKey(), default: false]
    }
}
```
⚠ Read that file's header comment before wiring D-11's login parameter: the Sharing reference cache
is process-global and keyed by the key's id alone, so *all* live `@SharedReader(.didLogin)` readers
share the first reader's captured `CookieClient`. `CookieClientTests/DidLoginKeyTests.swift`
(lines 6-26) documents the consequence — a suite must keep exactly one live reader. If
`AnalyticsDefaultParameters` opens a second long-lived reader, that constraint tightens. This is
the concrete cost of the `AnalyticsClient → CookieClient` edge RESEARCH.md flagged as a plan-time
decision.

---

### `AppPackage/Sources/AnalyticsClient/.swiftlint.yml` (config)

**Analog:** `AppPackage/Sources/HapticsClient/.swiftlint.yml` — the entire file is one line:
```yaml
parent_config: ../../../.swiftlint.yml
```
Test targets carry one too: `AppPackage/Tests/CookieClientTests/.swiftlint.yml` (same content, same
relative depth). Both the new source module and the new test target need one.

---

### `AppPackage/Package.swift` (config)

**Third-party package entry** — the array is alphabetical by URL host/owner and each
non-obvious pin carries a comment (lines 6-33):
```swift
var dependencies: [PackageDescription.Package.Dependency] = [
    .package(url: "https://github.com/Lakr233/ColorfulX", exact: "6.1.0"),
    .package(url: "https://github.com/EhPanda-Team/SwiftyOpenCC", exact: "2.1.0"),
    .package(url: "https://github.com/SDWebImage/SDWebImageSwiftUI", from: "3.0.0"),
    ...
]
```

**Product alias** — `Target.Dependency` extension, alphabetical (lines 35-51):
```swift
extension PackageDescription.Target.Dependency {
    static let casePaths: Self = .product(name: "CasePaths", package: "swift-case-paths")
    static let colorfulX: Self = .product(name: "ColorfulX", package: "ColorfulX")
    ...
    static let sharing: Self = .product(name: "Sharing", package: "swift-sharing")
}
```

**`Module` enum case** — alphabetical, `case camelCase = "PascalCase"` (lines 64-75):
```swift
enum Module: String {
    case animatedImageFeature = "AnimatedImageFeature"
    case appComponents = "AppComponents"
    ...
    case cookieClient = "CookieClient"
```
`AnalyticsClient` sorts between `animatedImageFeature` and `appComponents`. Test-target cases live
in the same enum further down (`case cookieClientTests = "CookieClientTests"`, line 122).

**Source target** — smallest client analog, `hapticsClient` (lines 436-442):
```swift
.target(
    module: .hapticsClient,
    dependencies: [
        .targetDependency(.composableArchitecture)
    ],
    plugins: swiftLintPlugins
),
```
Closer shape for a client with module edges, `cookieClient` (lines 403-413):
```swift
.target(
    module: .cookieClient,
    dependencies: [
        .module(.appModels),
        .module(.appTools),
        .targetDependency(.composableArchitecture),
        .targetDependency(.sharing)
    ],
    resources: [.process(.resources)],
    plugins: swiftLintPlugins
),
```

**Test target** — `cookieClientTests` (lines 958-965):
```swift
.testTarget(
    module: .cookieClientTests,
    dependencies: [
        .module(.cookieClient),
        .module(.appModels),
        .targetDependency(.composableArchitecture)
    ],
    plugins: swiftLintPlugins
),
```

---

### `AppPackage/Tests/AnalyticsClientTests/` (test target)

**Analog:** `AppPackage/Tests/CookieClientTests/` — a client-level (non-feature) test target with
`.swiftlint.yml`, `CookieClientTests.swift`, `DidLoginKeyTests.swift`.

**Suite shape** (`AppPackage/Tests/HomeFeatureTests/FiltersPresentationLifecycleTests.swift:1-20`):
```swift
import AppModels
import ComposableArchitecture
import FiltersFeature
import Foundation
@testable import HomeFeature
import Sharing
import Testing

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
@Suite
struct FiltersPresentationLifecycleTests {
    @MainActor
    @Test
    func presentingFiltersLoadsThePersistedFilters() async {
```
`@Suite` on the type, `@MainActor` + `@Test` on each store-driving member — never `@MainActor` on
the type. Imports sorted (`sorted_imports` is error severity); `@testable import X` sorts by module
name, not by the `@testable` prefix.

**Registration — the one place that matters.**
`AppPackage/Tests/FeatureTests.xctestplan` (`CookieClientTests` entry, lines 127-133):
```json
{
  "target" : {
    "containerPath" : "container:AppPackage",
    "identifier" : "CookieClientTests",
    "name" : "CookieClientTests"
  }
},
```
**Correction to RESEARCH.md §Validation Architecture:** `EhPanda.xcscheme` contains **no**
`TestableReference` entries at all — its `<TestAction>` holds only two `<TestPlanReference>`s
(`container:AppPackage/Tests/FeatureTests.xctestplan`, default, and `container:UITests.xctestplan`).
So the xctestplan is the *sole* registration surface; there is no separate scheme edit. Verify the
new entry is present in the plan (`CookieClientTests` **is** listed today, so the Phase 11 skip was
a plan omission for other targets, not a scheme mechanism).

---

### `AppPackage/Sources/AppModels/Utilities/AppInfo.swift` (utility, bundle read)

**Analog:** itself — whole file, 19 lines:
```swift
import Foundation

public enum AppInfo {
    public static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "null"
    }
    public static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "null"
    }

    private static let internalIsTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    public static var isTesting: Bool {
        #if DEBUG
        internalIsTesting
        #else
        false
        #endif
    }
}
```
`telemetryDeckAppID` copies the `Bundle.main.object(forInfoDictionaryKey:) as? String` line exactly,
returning `String?` instead of the `?? "null"` fallback. `isTesting` is also the existing
`!AppInfo.isTesting` gate that `AppDelegate` already uses (see below).

---

### `App/Info.plist` (config, build-var substitution)

**Analog:** the file's own existing substituted keys (lines 11-14):
```xml
	<key>CFBundleDevelopmentRegion</key>
	<string>$(DEVELOPMENT_LANGUAGE)</string>
	<key>CFBundleExecutable</key>
	<string>$(EXECUTABLE_NAME)</string>
```
Keys are alphabetically ordered (`BGTaskSchedulerPermittedIdentifiers`,
`CADisableMinimumFrameDurationOnPhone`, `CFBundle…`); indentation is a hard tab. A
`TelemetryDeckAppID` key sorts near the end. The file already proves `$(VAR)` substitution is
enabled for this target — no build-setting change is needed to turn it on.

**`.gitignore` precedent** (line 7): `Config/LocalSigning.xcconfig` — the `Config/` directory does
not currently exist in the tree; this phase gives it its first real file.

---

### `AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift` (reducer, launch sequencing)

**Analog:** itself. **This is the SDK-initialization seam.**

**The launch reducer** (lines 15-46):
```swift
@Reducer
struct AppDelegateReducer {
    @ObservableState
    struct State: Equatable {}

    enum Action: Equatable {
        case onLaunchFinish
    }

    @Dependency(\.libraryClient) private var libraryClient
    @Dependency(\.cookieClient) private var cookieClient

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .onLaunchFinish:
                return .merge(
                    .run { _ in
                        @Shared(.galleryHistory) var galleryHistory
                        $galleryHistory.withLock({ $0.pruneToHistoryCap() })
                    },
                    .run(operation: { _ in libraryClient.initializeWebImage() }),
                    .run(operation: { _ in cookieClient.removeYay() }),
                    ...
                )
            }
        }
    }
}
```
`libraryClient.initializeWebImage()` is the precise precedent RESEARCH.md's Pattern 2 points at:
a one-shot, synchronous client `start`-style call sequenced through `.run(operation: { _ in … })`
inside `.onLaunchFinish`. Add `analyticsClient.start()` as one more `.merge` element. Note
`@Dependency` properties are declared `private` at reducer scope, and closures use the
parenthesized `.run(operation:)` form (`single_line_trailing_closure` is an error-severity rule) —
except the multi-line `.run { _ in … }` at the top, which is the trailing-closure form the rule
permits for multi-statement bodies.

**The launch entry point** (`AppDelegate`, same file, lines 57-68):
```swift
public func application(
    _ application: UIApplication, didFinishLaunchingWithOptions
        launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
) -> Bool {
    if !AppInfo.isTesting {
        store.send(.appDelegate(.onLaunchFinish))
        BackgroundProcessingClient.live.register { task in
            AppDelegate.handleProcessingTask(task)
        }
    }
    return true
}
```
`App/EhPandaApp.swift` is a 15-line shell (`@UIApplicationDelegateAdaptor(AppDelegate.self)` +
`RootView`) and needs **no** change — the `!AppInfo.isTesting` gate already lives here.

---

### Reducer emission sites — `HomeFeature`, `SearchFeature`, `FavoritesFeature`, `DetailFeature`, `ReadingFeature`, `DownloadsFeature`, `SettingFeature`, `PresentationFeature` (reducer, D-14)

**Analog A — the simplest fire-and-forget client call from a `case`:**
`AppPackage/Sources/SettingFeature/Components/LaboratorySettingReducer.swift:19-33`
```swift
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.dfClient) private var dfClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .bypassSNIFilteringChanged(let value):
                return .merge(
                    .run { _ in await hapticsClient.generateFeedback(.soft) },
                    .run { _ in dfClient.setActive(value) }
                )
            }
        }
    }
```
This is the exact call-site shape for analytics: a synchronous, non-throwing, result-ignored client
call wrapped in `.run` purely to keep `Reduce` pure, `.merge`d alongside the case's existing effect.

**Analog B — appending to an existing effect list (multi-effect cases):**
`AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift:198-213`
```swift
case .handleGalleryLink(let url, let gallery):
    let route = GalleryURLParser.parse(url)
    let deepLink = GalleryDeepLink(pageIndex: route?.pageIndex, commentID: route?.commentID)
    var effects = [Effect<Action>]()
    if let pageIndex = route?.pageIndex {
        effects.append(.send(.updateReadingProgress(...)))
    }
    state.path.removeAll()
    state.detail = DetailReducer.State(gallery: gallery, pendingDeepLink: deepLink)
    effects.append(.send(.detail(.presented(.onPresented))))
    effects.append(.run(operation: { _ in await hapticsClient.generateFeedback(.light) }))
    return .merge(effects)
```
Use this `var effects = [Effect<Action>]()` … `.merge(effects)` form where the case already builds
a list. Note the in-line comment justifying the presentation seam ("the same presentation seam as
the tap path, no view `onAppear`") — the same D-14 reasoning applies to every analytics site, and
this codebase documents that reasoning at the site.

**Analog C — appending to a single-effect return:**
`AppPackage/Sources/HomeFeature/Toplists/ToplistsReducer.swift:146`
```swift
return .run(operation: { _ in await hapticsClient.generateFeedback(.light) })
```
(same one-liner also at `SettingFeature/Login/LoginReducer.swift:146` inside a `.merge`)

**Analog D — the reader-session-end seam (D-05 family 3):**
`AppPackage/Sources/ReadingFeature/ReadingReducer+Body.swift:73-77`
```swift
case .onPerformDismiss:
    // Flush synchronously here — this runs before the parent nils the presentation and
    // cancels the pending debounce, so the last page swiped-to isn't lost on a normal close.
    flushReadingProgress(state)
    return .run(operation: { _ in await hapticsClient.generateFeedback(.light) })
```
`Reading.sessionEnded` merges into this exact return. The synchronous-before-teardown property that
makes `flushReadingProgress` correct here is the same property the session signal needs.

**Analog E — cross-cutting reducer *modifier* instead of per-case calls:**
`AppPackage/Sources/HapticsClient/Reducer+Haptics.swift` (whole file, 31 lines) — `HapticsClient`
ships a `Reducer` extension that fires on a presentation becoming non-nil:
```swift
extension Reducer {
    public func haptics<Enum, Case>(
        unwrapping enum: @escaping (State) -> Enum?,
        case caseKeyPath: CaseKeyPath<Enum, Case>,
        hapticsClient: HapticsClient,
        style: UIImpactFeedbackGenerator.FeedbackStyle = .light
    ) -> some Reducer<State, Action> {
        onBecomeNonNil(unwrapping: `enum`, case: caseKeyPath) { _, _ in
            .run(operation: { _ in await hapticsClient.generateFeedback(style) })
        }
    }
    // private func onBecomeNonNil(...) diffs previousCase == nil && currentCase != nil
}
```
Relevant twice: (1) it is the in-tree precedent for a client module vending a `Reducer` extension,
which is a candidate answer for the four-divergent-`pushGalleryDetail`-sites problem RESEARCH.md
flags; (2) its `previousCase == nil && currentCase != nil` transition-diff is the exact technique
the `DownloadsReducer.observeDownloadsDone` double-count problem needs (compare old vs. new state
around `_reduce`).

---

### Existing test suites that break on `testValue = .unimplemented` (test)

**Analog A — the established per-store `.noop` override** (5 sites in the tree today, e.g.
`AppPackage/Tests/HomeFeatureTests/FiltersPresentationLifecycleTests.swift:32-35`):
```swift
let store = TestStore(initialState: .init(), reducer: FrontpageReducer.init) {
    $0.defaultAppStorage = defaults
    $0.hapticsClient = .noop
}
store.exhaustivity = .off
```

**Analog B — the per-suite `makeStore` factory** (`AppPackage/Tests/SettingFeatureTests/SettingReducerNavigationTests.swift:22-33`):
```swift
    // Every dependency a pushed Setting screen's presentation load can reach, stubbed inert so the
    // navigation assertions never depend on a client's behaviour.
    @MainActor
    private func makeStore(
        initialState: SettingReducer.State = .init()
    ) -> TestStoreOf<SettingReducer> {
        TestStore(initialState: initialState, reducer: SettingReducer.init) {
            $0.cookieClient = .noop
            $0.libraryClient = .noop
            $0.logsClient = .noop
        }
    }
```
This is the answer to Pitfall 3's blast radius: the repo's established way to override a dependency
across a whole suite is a `private @MainActor func makeStore` returning `TestStoreOf<…>`, **not** a
`@Suite` trait. Adding `$0.analyticsClient = .noop` to an existing `makeStore` fixes every case in
that suite at once. Suites without a factory (most of `DownloadsFeatureTests`' 75 sites) either gain
one or take the per-store line from Analog A. `AppPackage/Tests/DownloadsFeatureTests/DownloadFeatureTestHelpers.swift`
already defines a `DownloadFeatureTestCase: TestHelper` protocol shared across that target — the
natural place to hang a shared store builder if the planner chooses to add one.

**Analog C — the signal-capture spy** (`AppPackage/Tests/SettingFeatureTests/AppActivityLogsReducerTests.swift:21-35`):
```swift
        let fetchCount = LockIsolated(0)
        let appended = LockIsolated([[AppActivityLog]]())

        var client = LogsClient.noop
        client.nextRunCount = { _ in 3 }
        client.appendToRunFile = { logs, _ in
            appended.withValue({ $0.append(logs) })
        }
        ...
        let store = TestStore(...) {
            $0.logsClient = client
            $0.continuousClock = TestClock()
```
`LockIsolated` + a closure override is exactly how a test asserts *which* signals were emitted.
⚠ One structural note: this pattern does `var client = LogsClient.noop` then mutates a field —
which requires `var` properties on the client struct. `HapticsClient` (the D-12 template) uses
`let`, so an `AnalyticsClient` copying it must be re-constructed whole:
`$0.analyticsClient = .init(send: { … })`, which is what RESEARCH.md's example does. Either choice
is defensible; pick one deliberately, because it decides the ergonomics of ~127 test sites.

---

### `README.md` (docs)

**Analog:** `README.md:25-28` — §Content & Copyright, the nearest prose-disclosure section:
```markdown
## Content & Copyright
The content in this application is derived from E-Hentai, which is user-generated content.

**Users of this application should access the E-Hentai content at their own risk.**
```
Conventions to copy: `##` heading level (there is no `###` anywhere in the file); short declarative
prose, no bullet lists in the prose sections; **bold** for the one sentence that carries the
warning; inline `[text](url)` links (see §Installation lines 19-20, which is also the AltStore line
D-02 cites). Section order today: Installation → System Requirements → Content & Copyright →
Questions & Feedback → Screenshots. An "Analytics" section sits naturally after Content & Copyright.

## Shared Patterns

### Client-module file layout
**Source:** `AppPackage/Sources/HapticsClient/HapticsClient.swift`
**Apply to:** `AnalyticsClient.swift`
Single file, four sections in this order, with `// MARK:` banners on the last two: struct → `live`
extension → `// MARK: API` (`…Key: DependencyKey` + `DependencyValues` computed property) →
`// MARK: Test` (`noop`, `placeholder<Result>()`, `unimplemented`).

### Per-call `@Shared` reads
**Source:** `AppPackage/Sources/DownloadClient/DownloadClient.swift:78-82`
**Apply to:** `AnalyticsDefaultParameters` (D-11)
Declare `@Shared(.setting) var setting` *inside* the closure body, never outside it.

### Fire-and-forget client call from a reducer case
**Source:** `AppPackage/Sources/SettingFeature/Components/LaboratorySettingReducer.swift:26-32`
**Apply to:** every emission site (D-14)
`.merge(existingEffect, .run(operation: { _ in analyticsClient.send(.someSignal) }))`, with the
`@Dependency(\.analyticsClient) private var analyticsClient` declared at reducer scope.

### Per-module SwiftLint config
**Source:** `AppPackage/Sources/HapticsClient/.swiftlint.yml`, `AppPackage/Tests/CookieClientTests/.swiftlint.yml`
**Apply to:** the new source module *and* the new test target
One line: `parent_config: ../../../.swiftlint.yml`

### Lint rules that shape this phase's code
**Source:** `.swiftlint.yml` (repo root)
**Apply to:** all new Swift
`sorted_imports`, `single_line_trailing_closure` (hence `.run(operation: { … })`),
`labeled_tuple_elements` (hence `TagNamespaceCounts` as a struct), `lifecycle_modifiers`
(reinforces D-14 and rules out the SDK's navigation view modifier), `optional_try`,
`no_unchecked_sendable`, `line_length` 120 — all error severity, none suppressible.

### Test-suite dependency override
**Source:** `AppPackage/Tests/SettingFeatureTests/SettingReducerNavigationTests.swift:22-33`
**Apply to:** all six existing feature test targets
`private @MainActor func makeStore(...) -> TestStoreOf<Reducer>` with the overrides in the
trailing `withDependencies` closure of `TestStore.init`.

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `Config/Analytics.xcconfig` (+ gitignored local override) | config | build-time | No `Config/` directory exists in the tree and the app target has no `baseConfigurationReference`. `.gitignore:7` names `Config/LocalSigning.xcconfig`, but the file and directory are absent — a vestigial line, not a working precedent. Use RESEARCH.md Pitfall 4's `#include?` pattern; the `App/Info.plist` `$(VAR)` half of the path *is* precedented (see above). |

## Metadata

**Analog search scope:** `AppPackage/Sources/` (43 modules, 15 of them `*Client`),
`AppPackage/Tests/` (20 targets), `App/`, `EhPanda.xcodeproj/xcshareddata/xcschemes/`,
`README.md`, `.gitignore`
**Files scanned:** ~25 read directly; ~10 more grepped for call-site inventory
**Pattern extraction date:** 2026-07-24
