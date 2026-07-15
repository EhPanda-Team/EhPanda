# Phase 9: Correctness & Structured Error Handling - Pattern Map

**Mapped:** 2026-07-15
**Files analyzed:** 8 new/changed surfaces (+ the module-by-module `try?` sweep)
**Analogs found:** 8 / 8 (every surface has an in-repo analog; RESEARCH.md already cites file:line — this tightens each into copy-ready excerpts)

> This map is a companion to `09-RESEARCH.md`, which already surveyed the codebase and cited analogs with file:line. Here each analog is read and reduced to the exact code the planner copies from. No analog is abstract; all are grounded excerpts.

## File Classification

| New/Changed File | Role | Data Flow | Closest Analog | Match Quality |
|------------------|------|-----------|----------------|---------------|
| `AppComponents/ErrorInfoView.swift` (NEW) | component (view) | request-response (renders `AppError`) | `AppComponents/AlertView.swift` (`ErrorView`/`AlertView`) | role-match (both are `AppError`-driven surfaces; Form vs VStack) |
| `AppModels/Support/AppError.swift` (CHANGE) | model | transform | itself (extend in place) | exact (self-analog) |
| `AppModels/Support/AppError+Context.swift` (NEW) | model | transform | `ConcurrencyExtras/AnyHashableSendable.swift` (prior art) | exact-shape (type-erasing box + literal conformances) |
| `AppFeature/DataFlow/PresentationReducer.swift` (RENAME + `.errorInfo`) | reducer | event-driven | same file's `.setting`/`.newDawn` `@ReducerCaseIgnored` cases | exact (sibling case in same enum) |
| `AppFeature/DataFlow/AppReducer.swift` (CHANGE) | reducer | event-driven | its own `appRouteState`/`appRoute` scope lines | exact (self-analog) |
| `AppFeature/View/TabBar/TabBarView.swift` (CHANGE) | component (view) | event-driven | its own `.sheet(item:)`/`.toast()` scope lines | exact (self-analog) |
| `AppComponents/AppAlertState.swift` (CHANGE — `AppError`-bearing factory) | model | transform | its own `.error(caption:)` factories | exact (self-analog) |
| `SystemNotificationExt/View+Toast.swift` (CHANGE — `onErrorTap`) | component (view) | event-driven | its own `ToastViewModifier` gesture wiring | exact (self-analog) |
| `AppModels/Gallery/Category.swift` (CHANGE — kill `fatalError`) | model | transform | its own `value` switch (already handles `.private`) | exact (self-analog) |
| `try?` → `do throws(AppError)` sweep (~143 sites, 40 files) | each owning module | varies | `PresentationReducer.fetchGallery` typed-throws effect | exact (established Pattern-1 shape) |

## Pattern Assignments

### `AppComponents/ErrorInfoView.swift` (NEW — component, Form detail surface)

**Analog:** `AppPackage/Sources/AppComponents/AlertView.swift` (`ErrorView` lines 66-88; `AlertView` lines 90-122). Same module, same `AppError` input, same `SFSafeSymbols`/`Resources`/`LocalizedStringResource` idioms — `ErrorInfoView` is a peer, so it sits beside these and reuses their import block and public-init style. `ErrorView` stays UNCHANGED (full-screen primary-load path); `ErrorInfoView` is the new tappable-toast detail surface.

**Import + public struct + init pattern to mirror** (`AlertView.swift:1-4, 66-79`):
```swift
import SwiftUI
import AppModels
import Resources
import SFSafeSymbols
// …
public struct ErrorView: View {
    private let error: AppError
    // …
    public init(error: AppError, /* … */) { self.error = error /* … */ }
```

**`AppError` glyph/text consumption to reuse** (`AlertView.swift:82`) — `ErrorInfoView` reuses these same accessors so behavior matches `ErrorView`:
```swift
AlertView(symbol: error.symbol, message: error.alertText) { … }
```
`error.symbol` (from `AppComponents/AppError+Symbol.swift`, UNCHANGED) and `error.alertText`/`localizedDescription` (from `AppError.swift`) are the exact outputs `ErrorInfoView` renders in its Description section.

**Form/section/toolbar-close shape:** No existing `Form`-based `AppComponents` view exists to copy verbatim — the section+environment+toolbar-close skeleton is the one genuinely new shape. RESEARCH.md §6 (`09-RESEARCH.md:436-467`) gives the copy-ready skeleton: `NavigationStack { Form { Section(.errorInfoDescription){…}; if let solution…; if let context…; Section(.errorInfoEnvironment){ LabeledContent(…) } } .toolbar { ToolbarItem(placement:.confirmationAction){ Button(.close){ dismiss() } } } }`. Env sources: `AppInfo.version`/`.build`, `@Dependency(\.deviceClient).deviceType()`, `ProcessInfo.processInfo.operatingSystemVersionString` (D-09). iOS/iPadOS only — no `#if os(macOS)`, no Firebase `.analyticsScreen`.

---

### `AppModels/Support/AppError.swift` (CHANGE — model, merge context/solution/LocalizedError)

**Analog:** the file itself. This is the parity anchor: the 12-case set, `isRetryable`, `localizedDescription`, `alertText` must stay **byte-stable** (12 consumers + ~10 `ErrorView` sites + `AppError+Symbol.swift`). The additive machinery layers beside, never inside, these switches.

**Current declaration that must not change shape** (`AppError.swift:4-23`):
```swift
public enum AppError: Error, Identifiable, Equatable, Hashable, Sendable {
    public var id: String { localizedDescription }
    public init(_ error: any Error) { self = error as? AppError ?? .unknown }
    case copyrightClaim(String)
    case ipBanned(BanInterval)
    case expunged(String)
    case networkingFailed
    case webImageFailed
    case parseFailed
    case quotaExceeded
    case authenticationRequired
    case fileOperationFailed(String)
    case noUpdates
    case notFound
    case unknown
}
```

**`isRetryable` exhaustive switch that any case-shape change would break** (`AppError.swift:26-35`) — the parity test asserts these outputs per case; do NOT add an associated value to a bare case (Pitfall 1). `localizedDescription` (lines 36-63) and `alertText` (lines 64-97) are the other two exhaustive switches under the same constraint.

**Additive `LocalizedError` conformance to append** (from RESEARCH.md §3; reuses existing `localizedDescription`):
```swift
extension AppError: LocalizedError {
    public var errorDescription: String? { localizedDescription }
    public var recoverySuggestion: String? { solution }
}
```
`solution: String?` is a new per-kind localized computed property (new `.xcstrings` keys, all 6 locales). Storage mechanism for `context: Context?` is the planner's first design task (RESEARCH.md Assumption A1: companion beside the enum, NOT an associated value on every case).

---

### `AppModels/Support/AppError+Context.swift` (NEW — model, type-erasing box)

**Analog:** `swift-concurrency-extras/Sources/ConcurrencyExtras/AnyHashableSendable.swift` (resolved dependency, read in full). `AnyHashableBox` replicates this shape name-free/owned — the ONLY reason to own it rather than import is that the literal conformances the reference design needs would be a retroactive conformance on a foreign type (Swift 6 warns; RESEARCH.md "Don't Hand-Roll").

**Erasure idiom to replicate** (`AnyHashableSendable.swift:5-30`):
```swift
public struct AnyHashableSendable: Hashable, Sendable {
  public let base: any Hashable & Sendable
  public init(_ base: some Hashable & Sendable) { /* … */ self.base = base }
  public static func == (lhs: Self, rhs: Self) -> Bool { AnyHashable(lhs.base) == AnyHashable(rhs.base) }
  public func hash(into hasher: inout Hasher) { hasher.combine(base) }
}
```

**Literal-conformance idiom to replicate** (`AnyHashableSendable.swift:56-78`) — this is the ergonomics that lets a throw site read `[.action: "…", .statusCode: 200]`:
```swift
extension AnyHashableSendable: ExpressibleByBooleanLiteral { public init(booleanLiteral value: Bool) { self.init(value) } }
extension AnyHashableSendable: ExpressibleByFloatLiteral   { public init(floatLiteral value: Double) { self.init(value) } }
extension AnyHashableSendable: ExpressibleByIntegerLiteral { public init(integerLiteral value: Int) { self.init(value) } }
extension AnyHashableSendable: ExpressibleByStringLiteral  { public init(stringLiteral value: String) { self.init(value) } }
```
`AnyHashableBox` adds a `displayValue: String` (for `ErrorInfoView` rows) that the prior art expresses as `CustomStringConvertible.description` (`AnyHashableSendable.swift:44-48`). `Context = [ContextKey: AnyHashableBox]`; `ContextKey: String` enum, raw values are human-readable row labels (RESEARCH.md §3, D-06). Security: whitelist keys — URL path only, never cookies/tokens (RESEARCH.md Security Domain).

---

### `AppFeature/DataFlow/PresentationReducer.swift` (RENAME from `AppRouteReducer.swift` + `.errorInfo` case — reducer, event-driven)

**Analog:** the existing `.setting`/`.newDawn` `@ReducerCaseIgnored` cases in the SAME reducer — `.errorInfo(AppError)` is a sibling that slots into the identical idiom end-to-end.

**Destination enum to extend** (`AppRouteReducer.swift:16-22`):
```swift
@Reducer
enum Destination {
    @ReducerCaseIgnored
    case setting(EquatableVoid)
    @ReducerCaseIgnored
    case newDawn(Greeting)
    // ADD: @ReducerCaseIgnored case errorInfo(AppError)
}
```

**Present-action idiom to mirror** (`AppRouteReducer.swift:106-111`) — add `presentErrorInfo(AppError)` shaped exactly like these:
```swift
case .presentSetting:
    state.destination = .setting(.init())
    return .none
case .presentNewDawn(let greeting):
    state.destination = .newDawn(greeting)
    return .none
// ADD: case .presentErrorInfo(let error): state.destination = .errorInfo(error); return .none
```

**Existing error-toast seam to build the tappable toast into** (`AppRouteReducer.swift:197-208`) — the `AppError` is already in hand here (`result` is `Result<Gallery, AppError>`); the new `AppError`-bearing factory replaces `.error()`:
```swift
case .fetchGalleryDone(let url, let result):
    state.toast = nil
    switch result {
    case .success(let gallery):
        return .send(.handleGalleryLink(url, gallery))
    case .failure:
        return .run { send in
            try await Task.sleep(for: .milliseconds(500))
            await send(.setToast(.error()))   // → .error(error) carrying the AppError (D-11)
        }
    }
```

**Rename mechanics** (`AppRouteReducer.swift:15, 229-230`): `struct AppRouteReducer` → `struct PresentationReducer`, and the two trailing `extension AppRouteReducer.Destination.State/Action` lines. Blast radius is exactly 3 files (below).

---

### `AppFeature/DataFlow/AppReducer.swift` — rename scope lines (reducer, event-driven)

**Analog:** the file's own `appRouteState`/`appRoute` wiring. Per RESEARCH.md §5 the touch points are: `var appRouteState = AppRouteReducer.State()` (line 24), `case appRoute(AppRouteReducer.Action)` (line 45), `Scope(\.appRouteState, action: \.appRoute, AppRouteReducer.init)` (line 315), plus ~10 `.appRoute(...)`/`state.appRouteState...` references (lines 67-361). A2: optionally rename `appRouteState`/`appRoute` → `presentationState`/`presentation` for consistency (recommended; stays within these 3 files).

---

### `AppFeature/View/TabBar/TabBarView.swift` — present `.errorInfo` sheet + rename scope lines (component, event-driven)

**Analog:** the file's own `.sheet(item:)` presentations — `.errorInfo` presents exactly like `.setting`/`.newDawn`, except the payload is a plain `AppError` value (no child store), so the closure takes it directly.

**Sheet-presentation idiom to mirror** (`TabBarView.swift:69-79`):
```swift
.sheet(item: $store.appRouteState.destination.newDawn) { greeting in
    NewDawnView(greeting: greeting.wrappedValue)
        .privacyMask()
}
.sheet(item: $store.appRouteState.destination.setting) { _ in
    SettingView(store: store.scope(\.settingState, action: \.setting)) …
}
// ADD:
// .sheet(item: $store.appRouteState.destination.errorInfo) { error in
//     ErrorInfoView(error: error.wrappedValue)
// }
```

**Toast scope line that gains the tap routing** (`TabBarView.swift:95`) — this is where `onErrorTap` is wired to `store.send(.appRoute(.presentErrorInfo(error)))`:
```swift
.toast($store.scope(\.appRouteState.$toast, action: \.appRoute.toast))
```

Other rename touch points in this file (RESEARCH.md §5): lines 32, 80, 82, 97 (`.appRoute(...)`, `\.appRouteState.$detail`, `\.appRouteState.path`, `.onOpenURL`).

---

### `AppComponents/AppAlertState.swift` — `AppError`-bearing factory (model, transform)

**Analog:** the file's own button-less toast factories on `extension AppAlertState where Action == Never`. A new `.error(_ error: AppError)` factory is a sibling that stores the error and reuses `error.alertText`/`localizedDescription` for the message.

**Factory idiom to mirror** (`AppAlertState.swift:141-154`):
```swift
public static func error(caption: LocalizedStringResource) -> Self {
    .init(style: .toast(icon: .error, autoHide: true),
          title: TextState(localized: .error),
          message: TextState(localized: caption))
}
public static func error(caption: String? = nil) -> Self {
    .init(style: .toast(icon: .error, autoHide: true),
          title: TextState(localized: .error),
          message: caption.map { TextState($0) })
}
// ADD: .error(_ error: AppError) — stores an optional `error: AppError?` slot and uses
//      TextState(error.alertText) for message; identity-excluded from == like `id` (lines 72-92).
```
`Action == Never` means the toast store cannot `send` (Pitfall 2) — the tap is routed at the modifier layer via a new `onErrorTap` closure (next file), NOT as a `ButtonState`.

---

### `SystemNotificationExt/View+Toast.swift` — `onErrorTap` routing (component, event-driven)

**Analog:** the file's own `ToastViewModifier` gesture/task wiring. Add a `.onTapGesture` beside the existing `dismissGesture`, guarded on `store.state.error != nil`, calling a new `onErrorTap: (AppError) -> Void` threaded through `.toast(_:onErrorTap:)`. Keep the 3s `autoDismiss` untouched (tap fires before the timer).

**Modifier + gesture seam to extend** (`View+Toast.swift:44-50, 63-73`):
```swift
ToastMessageView(content: toast)
    .padding(.horizontal).padding(.bottom)
    .gesture(dismissGesture(autoHide: toast.autoHide))
    .task(id: id) { await autoDismiss(toast, presentedID: id) }
    .transition(.move(edge: .bottom).combined(with: .opacity))
// ADD near here: .onTapGesture { if let error = store.state.error { onErrorTap(error) } }
```
The 3s auto-hide (`View+Toast.swift:77 try? await Task.sleep(for: .seconds(3))`) stays — note this `try?` is itself a bucket-(c) cancellation-swallow survivor (D-02, keep + comment).

---

### `AppModels/Gallery/Category.swift` — kill the `fatalError` (model, transform)

**Analog:** the file's own `value` switch (lines 48-62), which already handles `.private` gracefully (`return .categoryPrivate`) — proof `.private` is a real, reachable, display-only case. `filterValue` is the outlier that traps on it.

**The landmine to replace** (`Category.swift:42-46`):
```swift
case .private:
    let message = "`Private` doesn't have a `filterValue`!"
    logger.error("\(message, privacy: .public)")
    fatalError(message)
```

**Replacement** (RESEARCH.md Target 1, copy-ready) — `import IssueReporting`; dev-time non-fatal report, inert in release, `return 0`, with a doc comment stating `.private` is display-only (no filter bit). No `reportIssue` usage exists in the codebase yet (`IssueReporting` is currently used only as `IssueReporting.unimplemented` in clients), so RESEARCH.md §1 is the authoritative template:
```swift
reportIssue("`Category.private` has no `filterValue` — it is display-only and must be excluded from filter math.")
return 0
```
Test (new `AppModelsTests` case): `withExpectedIssue { #expect(Category.private.filterValue == 0) }`. `Category.allFiltersCases` (line 11, `allCases.dropLast()`) already drops `.private`, so live `URLUtil.categoryValue` consumers never reach it — audit any existing all-categories iteration test (Pitfall 4).

---

### `try?` → `do throws(AppError)` sweep (~143 sites / 40 files — per owning module)

**Analog (Pattern 1):** `PresentationReducer.fetchGallery` typed-throws effect — the canonical before/after for every bucket-(a) conversion.

**Canonical shape to copy** (`AppRouteReducer.swift:184-195`):
```swift
return .run { send in
    do throws(AppError) {
        let gallery = try await GalleryReverseRequest(url: url, isGalleryImageURL: isGalleryImageURL).response()
        await send(.fetchGalleryDone(url, .success(gallery)))
    } catch {
        await send(.fetchGalleryDone(url, .failure(error)))
    }
}
```

**Four buckets** (classify before converting — RESEARCH.md §2): (a) convert to `do throws(AppError)` [network/file/decode with real surfaceable failure]; (b) keep `try?` + just-cause comment [decode-with-default; densest in ParserFeature `Parser+List.swift`, and `AppModels/JSONValue.swift` type-probes]; (c) best-effort cleanup / cancellation swallow [`try? await Task.sleep`, `DataCache` fire-and-forget removeItem — convert-and-log OR commented survivor, owner reviews]; (d) already inside a `throws(AppError)` context → plain `try` [check `ImageClient`]. Wave order Parser → Download → AppTools → rest; parity via existing `ParserFeatureTests`/`DownloadsFeatureTests`.

## Shared Patterns

### Structured-throw + typed-catch (Pattern 1)
**Source:** `AppFeature/DataFlow/AppRouteReducer.swift:184-195`
**Apply to:** every bucket-(a) `try?` conversion, in each owning module's reducer/effect.

### `@ReducerCaseIgnored` Destination + present-action + sheet
**Source:** `AppRouteReducer.swift:16-22, 106-111` (reducer) + `TabBarView.swift:69-79` (view)
**Apply to:** the new `.errorInfo(AppError)` presentation (reducer case, `presentErrorInfo` action, TabBarView sheet).

### `AppError` parity anchor
**Source:** `AppModels/Support/AppError.swift:4-97` (the 12 cases + 3 exhaustive switches)
**Apply to:** all context/solution/LocalizedError additions — must layer beside, never inside, these switches; guard with an all-cases parity table test (`isRetryable`/`alertText`/`symbol` unchanged).

### Type-erasing Hashable & Sendable box
**Source:** `ConcurrencyExtras/AnyHashableSendable.swift:5-30, 44-48, 56-78` (prior art, reproduced owned/name-free)
**Apply to:** `AnyHashableBox` in `AppModels/Support/AppError+Context.swift`.

### Button-less toast factory
**Source:** `AppComponents/AppAlertState.swift:124-175` (the `Action == Never` extension)
**Apply to:** the new `AppError`-bearing `.error(_:)` factory + the `onErrorTap` modifier closure in `View+Toast.swift`.

### Dev-time issue report (release-inert)
**Source:** RESEARCH.md §1 (`reportIssue(_:)` + `withExpectedIssue { }`) — no in-repo `reportIssue` call site exists yet; `IssueReporting` is currently used only via `.unimplemented` in clients.
**Apply to:** `Category.private.filterValue` and any future "unreachable-but-must-not-crash" site.

## No Analog Found

| File / Concern | Role | Data Flow | Reason |
|----------------|------|-----------|--------|
| `ErrorInfoView` Form/section/toolbar-close skeleton | component | request-response | No existing `Form`-based detail view in `AppComponents` to copy verbatim; the section+environment+close skeleton is genuinely new. Use RESEARCH.md §6 (`09-RESEARCH.md:436-467`) as the template; borrow `AppError`-consumption + public-init/import conventions from `AlertView.swift`. |
| `reportIssue(_:)` production call site | model | transform | The codebase uses `IssueReporting` only as `.unimplemented`; no `reportIssue`/`withExpectedIssue` precedent. Use RESEARCH.md §1 copy-ready pattern. |

## Metadata

**Analog search scope:** `AppPackage/Sources/{AppModels,AppComponents,AppFeature,SystemNotificationExt}`, plus resolved dependency `AppPackage/.build/checkouts/swift-concurrency-extras`.
**Files read for extraction:** `AppError.swift`, `AlertView.swift`, `Category.swift`, `AppRouteReducer.swift`, `AppAlertState.swift`, `View+Toast.swift`, `AnyHashableSendable.swift`, `TabBarView.swift` (targeted).
**Project rules honored:** reference project name never recorded (name-free per AGENTS.md); repo-relative paths only (no absolute home paths); Swift/TCA + Swift Testing.
**Pattern extraction date:** 2026-07-15
</content>
</invoke>
