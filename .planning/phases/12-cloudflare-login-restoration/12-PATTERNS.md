# Phase 12: Cloudflare Login Restoration - Pattern Map

**Mapped:** 2026-07-22
**Files analyzed:** 11 new/modified files
**Analogs found:** 10 / 11

All paths are repository-relative.

## File Classification

| New/Modified File | Kind | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|------|-----------|----------------|---------------|
| `AppPackage/Sources/NetworkingFeature/Request.swift` | edit | networking helper | request-response classification | itself (`mapAppError`, `fetch` extension) | exact |
| `AppPackage/Sources/NetworkingFeature/Request+Account.swift` | edit | request struct | request-response (POST) | `LoginRequest` in same file | exact |
| `AppPackage/Sources/SettingFeature/Components/ChallengeWebView.swift` (name TBD) | new | UIKit-bridged component | event-driven (cookie observation → callback) | `AppPackage/Sources/SettingFeature/Components/WebView.swift` | role-match (adds observer + UA readout; must NOT copy its shared-jar write) |
| `AppPackage/Sources/SettingFeature/Login/LoginReducer.swift` | edit | reducer | event-driven (TCA effects, destination presentation) | itself | exact |
| Optional child `CloudflareChallengeFeature` (Claude's discretion) | new | reducer | event-driven | `LoginReducer.swift` (`@Reducer`, `Destination`, `CancelID`) | role-match |
| `AppPackage/Sources/SettingFeature/Login/LoginView.swift` | edit | SwiftUI view | request-response UI | itself (sheet + toolbar) + `DateSeekPickerView` (cancellationAction) | exact |
| `AppPackage/Sources/AppModels/Support/AppError.swift` | edit | model (error enum) | — | itself (`authenticationRequired` case) | exact |
| `AppPackage/Sources/AppModels/Resources/Localizable.xcstrings` | edit | localization catalog | — | existing `appError*` keys in same catalog | exact |
| Session holder key (if `@Shared(.inMemory)` chosen): `AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift` or a SettingFeature-local keys file | edit/new | shared-state key | in-memory session state | `AppSharedKeys.swift` (`greeting`, `privacyMaskBlur`) / `SettingFeature/AppActivityLogs/AppActivityLogsSharedKeys.swift` | exact |
| `AppPackage/Tests/NetworkingFeatureTests/CloudflareChallengeDetectionTests.swift` | new | test | stubbed request-response | `AppPackage/Tests/NetworkingFeatureTests/Support/CountingStubProtocol.swift` + `AccountRequestBaselineTests.swift` | exact |
| `AppPackage/Tests/SettingFeatureTests/LoginChallengeFlowTests.swift` | new | test | TCA `TestStore` | `AppPackage/Tests/SettingFeatureTests/AccountSettingReducerTests.swift` | exact |

No-analog entry (see bottom): `WKHTTPCookieStoreObserver` usage — no existing observer in the tree; follow RESEARCH.md Pattern 2.

## Pattern Assignments

### `NetworkingFeature/Request.swift` — challenge classifier (D-05)

**Analog:** the same file's protocol-extension helper style. Helpers live in `extension Request` (e.g. `mapAppError(error:)`, lines 140–165) or as free/`URLRequest` extensions (lines 193–206). A response classifier that must also be callable from tests without a `Request` instance fits best as a `public` free function or static helper beside `mapAppError`.

**Existing seam — `fetch` returns `(data, response)` untyped** (lines 39–55):
```swift
public func fetch(
    _ request: URLRequest,
    in session: URLSession = .shared
) async throws(AppError) -> (data: Data, response: URLResponse) {
    var lastError: any Error = URLError(.unknown)
    for _ in 1...4 {
        do {
            return try await session.data(for: request)
        } catch { ... }
    }
    throw mapAppError(error: lastError)
}
```
A 403 is a successful transport response — it returns on attempt 1; the classifier runs *after* `fetch`, never inside it (RESEARCH anti-pattern).

**Labeled-tuple lint note:** `fetch`'s return type labels both tuple elements (`(data: Data, response: URLResponse)`); the `labeled_tuple_elements` custom rule (error) requires the same for any new multi-element tuple type (e.g. a `(clearance: String, userAgent: String)` pair — or use a small named struct).

### `NetworkingFeature/Request+Account.swift` — clearance-carrying `LoginRequest` variant

**Analog:** `LoginRequest` itself (lines 8–40). Copy its shape verbatim and add optional clearance/UA parameters (RESEARCH "Alternatives Considered" recommends preserving the no-clearance path unchanged):

**Imports pattern** (lines 1–5, `sorted_imports` is error-level):
```swift
import AppModels
import AppTools
import Foundation
import Kanna
import ParserFeature
```

**Core request pattern** (lines 22–39):
```swift
public func response() async throws(AppError) -> HTTPURLResponse? {
    let params: [String: String] = [
        "b": "d",
        "bt": "1-1",
        "CookieDate": "1",
        "UserName": username,
        "PassWord": password,
        "ipb_login_submit": "Login!"
    ]

    var request = URLRequest(url: Defaults.URL.login)
    request.httpMethod = "POST"
    request.httpBody = params.dictString().urlEncoded.data(using: .utf8)
    request.setURLEncodedContentType()

    let (_, response) = try await fetch(request, in: urlSession)
    return response as? HTTPURLResponse
}
```
Change for this phase: the classifier needs the response headers/status, and the challenge-detection call site needs them too — return enough for classification (the `HTTPURLResponse` already carries `value(forHTTPHeaderField:)`). The clearance variant additionally sets `request.httpShouldHandleCookies = false` plus explicit `Cookie`/`User-Agent` headers (RESEARCH Pattern 3, D-04/C4).

**Injected `urlSession` convention** (lines 9–20): every request takes `urlSession: URLSession = .shared` in `init` — keep it; this is what makes the stub harness work.

### `SettingFeature/Components/ChallengeWebView.swift` (new) — dedicated WKWebView wrapper

**Analog:** `AppPackage/Sources/SettingFeature/Components/WebView.swift` (91 lines, whole file read).

**Imports + module logger pattern** (lines 1–7):
```swift
import AppModels
import AppTools
import OSLogExt
import SwiftUI
import WebKit

private let logger = Logger(category: .init(describing: WebView.self))
```

**Representable + embedded controller pattern** (lines 9–91): `struct WebView: UIViewControllerRepresentable` with a `Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate`, and a `final class EmbeddedWebviewController: UIViewController` that owns the `WKWebView`, sets `view = webview` in `loadView()`, and loads via `loadUrl(_:)`:
```swift
func makeUIViewController(context: Self.Context) -> EmbeddedWebviewController {
    let webViewController = EmbeddedWebviewController(coordinator: context.coordinator)
    webViewController.loadUrl(url)
    return webViewController
}
```

**Callback-into-store pattern** (lines 11–13): the wrapper takes a plain closure (`loginDoneAction: (() -> Void)?`) that the hosting view wires to `store.send(...)` — copy this shape for `onClearance: (String, String) -> Void` (or a named-struct payload per the tuple lint), so the WebKit half stays behind an injectable seam and the reducer half is `TestStore`-testable (RESEARCH Wave 0 note).

**DO NOT COPY** (lines 34–36) — the shared-jar write violates D-04 for the challenge wrapper:
```swift
webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
    cookies.forEach({ HTTPCookieStorage.shared.setCookie($0) })
}
```
The challenge wrapper instead registers a `WKHTTPCookieStoreObserver` on `webview.configuration.websiteDataStore.httpCookieStore` and reports `(cf_clearance, navigator.userAgent)` upward without ever touching `HTTPCookieStorage.shared` (RESEARCH Pattern 2; no in-tree analog for the observer).

**Cosmetic note:** `WebView.swift` misspells `Coodinator` (declared line 18) yet references `WebView.Coordinator` at lines 68/70 — meaning a correctly-spelled typealias/second type must exist elsewhere; the new wrapper should just use `Coordinator`.

**Lint constraints:** no `.onAppear`/`.task` (`lifecycle_modifiers` error) — observer registration/teardown lives in the controller/coordinator lifecycle (`loadView`/`deinit`-equivalent), not SwiftUI lifecycle. `single_line_trailing_closure` (error) applies to `forEach`/`map`/`sink` etc. `no_nslock`, `no_unchecked_sendable`, `no_preconcurrency` all error-level.

### `SettingFeature/Login/LoginReducer.swift` — flow orchestration

**Analog:** itself (whole file, 131 lines).

**Destination + presented sheet pattern** (lines 17–21, 71–73, 120–125) — the challenge surface is a sibling case:
```swift
@Reducer
public enum Destination {
    @ReducerCaseIgnored
    case webView(URL)
}
...
case .presentWebView(let url):
    state.destination = .webView(url)
    return .none
...
.haptics(
    unwrapping: \.destination,
    case: \.webView,
    hapticsClient: hapticsClient
)
.ifLet(\.$destination, action: \.destination)
```
Note the file's closing extensions (lines 129–130): `extension LoginReducer.Destination.State: Equatable, Sendable {}` / same for `.Action` — a new destination case keeps these compiling.

**Cancellable login effect + typed throws** (lines 75–94) — the seam the challenge branch extends, and the `CancelID.login` D-02 cancel reuses:
```swift
case .login:
    guard !state.loginButtonDisabled || state.loginState == .loading else { return .none }
    state.focusedField = nil
    state.loginState = .loading
    return .merge(
        .run(operation: { _ in await hapticsClient.generateFeedback(.soft) }),
        .run { [state] send in
            do throws(AppError) {
                let response = try await LoginRequest(
                    username: state.username,
                    password: state.password
                )
                .response()
                await send(.loginDone(.success(response)))
            } catch {
                await send(.loginDone(.failure(error)))
            }
        }
        .cancellable(id: CancelID.login)
    )
```
The challenge branch inserts between `response()` and `loginDone`: classify; on challenge send a present-challenge action instead of `loginDone`.

**Success/failure downstream — must stay unchanged (C4)** (lines 96–117):
```swift
case .loginDone(let result):
    state.destination = nil
    var effects = [Effect<Action>]()
    if cookieClient.didLogin {
        state.loginState = .idle
        effects.append(.run(operation: { _ in
            logger.notice("Login succeeded.")
            await hapticsClient.generateNotificationFeedback(.success)
        }))
        effects.append(.run { _ in await dismiss() })
    } else {
        state.loginState = .failed(.unknown)
        ...
        await hapticsClient.generateNotificationFeedback(.error)
    }
    if case .success(let response) = result, let response = response {
        effects.append(.run(operation: { _ in cookieClient.setCredentials(response: response) }))
    }
    return .merge(effects)
```
D-11's "existing error notification haptic" is the `.error` notification feedback above. D-10's exhausted-retries path additionally sets a `toast` (see Shared Patterns).

**If a child `CloudflareChallengeFeature` is chosen:** copy `LoginReducer`'s skeleton — `@Reducer public struct XxxFeature: Sendable`, `@ObservableState struct State: Equatable, Sendable`, `enum Action: BindableAction/Equatable`, `@Dependency` properties, `public init() {}`, `body: some Reducer<State, Action>`. Repo rule: `Feature` suffix on new reducers. Child-reducer lint: `Scope`/`ifLet` composition must use `Reducer.init` shorthand, never `{ Reducer() }` (custom rules `child_reducer_shorthand_*`, error).

### `SettingFeature/Login/LoginView.swift` — sheet, spinner, toolbar

**Analog:** itself.

**Sheet + privacyMask presentation** (lines 72–78) — the challenge sheet copies this and MUST carry `.privacyMask()` (Pitfall 5; Phase 7 root count 39 → 40):
```swift
.sheet(item: $store.destination.webView, id: \.absoluteString) { url in
    WebView(url: url.wrappedValue) {
        store.send(.loginDone(.success(nil)))
    }
    .ignoresSafeArea(edges: .bottom)
    .privacyMask()
}
```

**Chevron→spinner overlay (D-03 — already the mechanism, extend its span)** (lines 39–56):
```swift
Button {
    store.send(.login)
} label: {
    Label(.RLocalizable.login, systemSymbol: .chevronForward)
        .labelStyle(.iconOnly)
        ...
}
.overlay {
    ProgressView()
        .animation(.default) {
            $0.opacity(store.loginState == .loading ? 1 : 0)
        }
}
```
Keeping `loginState == .loading` through detect → solve → retry makes this spinner span the whole flow with no view change; `loginButtonColor` (reducer state, lines 39–42) already clears the chevron while loading.

**Cancellation-action toolbar (D-02, Phase 5 convention)** — analog `AppPackage/Sources/DateSeekFeature/DateSeekPickerView.swift` lines 85–89:
```swift
.toolbar {
    ToolbarItem(placement: .cancellationAction) {
        Button(role: .cancel, action: dismiss.callAsFunction)
    }
}
```
For the challenge sheet, the button sends the reducer's cancel action (which cancels `CancelID.login`, resets `loginState = .idle`, nils the destination) rather than a bare environment dismiss.

**`system_name_image_parameter` lint:** use `systemSymbol:`, never `systemImage:`/`systemName:` (see line 42's `Label(..., systemSymbol:)`).

### `AppModels/Support/AppError.swift` — new `cloudflareChallengeFailed` case (D-10)

**Analog:** the `authenticationRequired` case, which threads all five members a case must cover:

**Case + isRetryable** (lines 11–35): add the case to the enum and to exactly one arm of `isRetryable` (non-retryable fits: user should switch method).

**localizedDescription** (lines 52–53 pattern):
```swift
case .authenticationRequired:
    return String(localized: .appErrorAuthenticationRequired)
```

**alertText** (lines 84–85 pattern):
```swift
case .authenticationRequired:
    return String(localized: .appErrorAuthenticationRequiredDescription)
```

**solution / recoverySuggestion** (lines 100–128) — this is where D-10's "steer to in-app web login / manual cookie entry" text goes:
```swift
extension AppError {
    public var solution: String? {
        switch self {
        case .networkingFailed:
            String(localized: .appErrorNetworkSolution)
        case .authenticationRequired:
            String(localized: .appErrorAuthenticationSolution)
        ...
        }
    }
}
extension AppError: LocalizedError {
    public var errorDescription: String? { localizedDescription }
    public var recoverySuggestion: String? { solution }
}
```
`AppError.id` is `localizedDescription` (line 5) — a distinct description string is required.

**Associated-value option:** cases carry small payloads (`expunged(String)`, `ipBanned(BanInterval)`); if the case carries attempt count/host, follow that shape — but per Phase 9 conventions, per-incident diagnostics belong in `ErrorInfo.context`, not the enum (see Shared Patterns).

### `AppModels/Resources/Localizable.xcstrings` — new keys

**Analog:** the existing `appErrorAuthenticationRequired` / `appErrorAuthenticationSolution` / `appErrorNetworkSolution` key family in the same catalog (referenced from `AppError.swift`). New keys follow AGENTS.md rules: no bare numeric specifiers in a module-local catalog (use `%#@variable@` substitutions for numbers); `%@` string args positional; `shouldTranslate: false` keys must copy the English `stringUnit` into every supported locale; plural-category coherence (`en`==`de`; `ja`/`ko`/`zh-Hans`/`zh-Hant` `other`-only).

### Session holder (if `@Shared(.inMemory)` chosen) — D-06

**Analog:** `AppPackage/Sources/AppModels/Persistence/AppSharedKeys.swift` lines 66–79 (the Phase 7 precedent, including the doc-comment style explaining launch-reset semantics):
```swift
// The daily "New Dawn" greeting is an ephemeral reward, not durable account identity, so it lives in
// memory only and resets to `nil` on the next launch. ...
extension SharedKey where Self == InMemoryKey<Greeting?>.Default {
    public static var greeting: Self {
        Self[.inMemory("greeting"), default: nil]
    }
}

/// Transient scene-phase blur written by `AppReducer` and read by `.privacyMask()`, reset to `0` on launch.
extension SharedKey where Self == InMemoryKey<Double>.Default {
    public static var privacyMaskBlur: Self {
        Self[.inMemory("privacyMaskBlur"), default: 0]
    }
}
```
If the holder is SettingFeature-local, the module-local analog is `AppPackage/Sources/SettingFeature/AppActivityLogs/AppActivityLogsSharedKeys.swift` (same `Self[.inMemory("namespaced.key"), default:]` shape). The pair value must be a small named `Sendable` struct (not an unlabeled tuple — `labeled_tuple_elements`).

### `NetworkingFeatureTests/CloudflareChallengeDetectionTests.swift` (new)

**Analog:** `AppPackage/Tests/NetworkingFeatureTests/Support/CountingStubProtocol.swift` (whole file) + sibling `AccountRequestBaselineTests.swift`.

**Harness usage** (`CountingStubProtocol.swift` lines 52–65 + `StubStep` lines 4–7):
```swift
enum StubStep: Sendable {
    case transportFailure(URLError.Code)
    case http(status: Int, data: Data, headers: [String: String] = [:])
}

func makeStubbedSession(script: StubScript) -> (session: URLSession, handle: StubHandle) {
    let token = UUID()
    CountingStubProtocol.register(script: script, for: token)
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [CountingStubProtocol.self]
    configuration.httpAdditionalHeaders = [CountingStubProtocol.tokenHeader: token.uuidString]
    return (URLSession(configuration: configuration), StubHandle(token: token))
}
```
Per-URL step sequences model "403-challenge then 200" directly; `handle.receivedRequests` (lines 43–45) exposes the recorded `URLRequest`s for the C4 header assertions (`Cookie: cf_clearance=…`, `User-Agent`); `handle.attempts(for:)` counts calls; call `handle.tearDown()` when done. Inject the stubbed session through the request's `urlSession` parameter.

### `SettingFeatureTests/LoginChallengeFlowTests.swift` (new)

**Analog:** `AppPackage/Tests/SettingFeatureTests/AccountSettingReducerTests.swift`.

**Suite conventions** (lines 1–36):
```swift
import AppModels
import ComposableArchitecture
import CookieClient
import Foundation
@testable import SettingFeature
import Testing

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. ...
struct AccountSettingReducerTests {
    @MainActor
    @Test
    func onPresentedLoadsCookiesAndObservesJarChanges() async {
        ...
        let store = makeStore(cookieClient: client)
        await store.send(.onPresented)
        await store.receive(\.loadCookies) {
            $0.ehCookiesState = client.loadCookiesState(host: .ehentai)
            ...
        }
        ...
        await store.finish()
    }
```
Copy: `@MainActor` on each test member (not the type), a private `makeStore(...)` factory taking overridable dependencies, exhaustive `TestStore` assertions (a silent `send` with no `receive` proves "no retry/no toast" for D-02), and the `TestStore(initialState:reducer: Reducer.init)` shorthand (lint rule `child_reducer_shorthand_store`). `CookieClient.testing(memberID:passHash:)` is available for `didLogin` control.

## Shared Patterns

### Error toast → ErrorInfoView (D-11, Phase 9 standard path)

**Toast state on the owning reducer** — `AppPackage/Sources/SettingFeature/AccountSetting/AccountSettingReducer.swift` lines 35, 44, 76, 155:
```swift
@Presents public var toast: AppAlertState<Never>?
...
case toast(PresentationAction<Never>)
...
case .toast:
    return .none
...
.ifLet(\.$toast, action: \.toast)
```

**Persistent tappable error toast factory** — `AppPackage/Sources/AppComponents/AppAlertState.swift` lines 165–172 (note `autoHide: false` — this is the persistent variant D-11 requires):
```swift
public static func error(_ errorInfo: ErrorInfo) -> Self {
    .init(
        style: .toast(icon: .error, autoHide: false),
        title: TextState(localized: .error),
        message: TextState(errorInfo.error.alertText),
        errorInfo: errorInfo
    )
}
```

**View-side rendering + tap-through to detail** — `AppPackage/Sources/AppFeature/View/TabBar/TabBarView.swift` lines 95–100:
```swift
.toast(
    $store.scope(\.presentationState.$toast, action: \.presentation.toast),
    onErrorTap: { errorInfo in
        store.send(.presentation(.presentErrorInfo(errorInfo)))
    }
)
```
Phase 9 convention: presentation at the *owning* reducer — LoginView/LoginReducer own this toast (LoginView gains no inline error text).

**Building the ErrorInfo with context** — `AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift` lines 218–230:
```swift
let context = Context.galleryFailure(
    url: url,
    action: "Fetch gallery",
    reason: error.localizedDescription
)
let errorInfo = ErrorInfo(error: error, context: context)
...
await send(.setToast(.error(errorInfo)))
```
`Context` is `[ContextKey: AnyHashableBox]` and `ContextKey` is a **fixed whitelist** — `AppModels/Support/AppError+Context.swift` lines 87–92:
```swift
public enum ContextKey: String, Hashable, Sendable {
    case action = "Action"
    case reason = "Reason"
    case statusCode = "Status Code"
    case gid = "Gallery ID"
}
```
New context rows (e.g. attempt count) require extending this enum — deliberately no raw-URL/free-form slot; do not log or surface the `cf_clearance` value anywhere (Phase 8 cookie-privacy gate).

### Haptics

Sheet-presentation haptic via `.haptics(unwrapping:case:hapticsClient:)` on the destination (LoginReducer lines 120–124); failure haptic via `hapticsClient.generateNotificationFeedback(.error)` (LoginReducer line 111). Reuse both for the challenge sheet and the exhausted-retries failure.

### Logging

Module-scope `private let logger = Logger(category: .init(describing: LoginReducer.self))` (LoginReducer line 9; WebView line 7); `logger.notice(...)` for flow milestones. Never log cookie values at `.public` privacy.

### Lint rules new code must satisfy from the start (all error severity)

`.swiftlint.yml` (root): `lifecycle_modifiers` (no `.onAppear`/`.onDisappear`/`.task`), `optional_try` (no `try?`), `single_line_trailing_closure`, `sorted_imports`, `force_unwrapping`/`force_try`, `labeled_tuple_elements` (tuple *types*), `no_nslock`/`no_unchecked_sendable`/`no_preconcurrency`, `binding_initializer` (no `Binding(get:set:)`), `system_name_image_parameter`, `child_reducer_shorthand_*` (use `Reducer.init`), 120-char lines. Any sanctioned `swiftlint:disable` needs a preceding `// reason:` comment — but suppression requires explicit user permission.

## No Analog Found

| Capability | Role | Reason | Fallback |
|------------|------|--------|----------|
| `WKHTTPCookieStoreObserver` registration + `evaluateJavaScript("navigator.userAgent")` readout | event-driven WebKit observation | No cookie-store observer exists anywhere in the tree (`WebView.swift` uses a one-shot `getAllCookies` on navigation finish) | RESEARCH.md Pattern 2 (SDK-verified): observer not retained by the store — the wrapper owns it strongly and removes it on teardown; all cookie-store work main-thread |

## Metadata

**Analog search scope:** `AppPackage/Sources/{NetworkingFeature,SettingFeature,AppModels,AppComponents,AppFeature,DateSeekFeature}`, `AppPackage/Tests/{NetworkingFeatureTests,SettingFeatureTests}`, root `.swiftlint.yml`
**Files read in full:** 9 (LoginReducer, LoginView, WebView, Request.swift, Request+Account.swift, AppError.swift, AppError+Context.swift, AppAlertState.swift, CountingStubProtocol.swift) + targeted excerpts of 5 more
**Pattern extraction date:** 2026-07-22
