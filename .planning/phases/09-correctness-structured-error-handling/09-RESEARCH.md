# Phase 9: Correctness & Structured Error Handling - Research

**Researched:** 2026-07-15
**Domain:** Swift/TCA error modeling, PointFree IssueReporting, SwiftUI failure surfaces, `try?` sweep
**Confidence:** HIGH (all findings grounded in the repo + the resolved dependency source; no external package additions)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- **D-01:** Default posture — every `try?` becomes `do/catch` that throws a proper `AppError`; the error is propagated (never swallowed) and surfaced via toast → `ErrorInfoView` where it warrants attention.
- **D-02:** A `try?` may survive **only** where `do/catch` cannot express the intent — a decode/parse that intentionally falls back to a default. Every survivor carries an inline just-cause comment. No silent best-effort bucket.
- **D-03:** Surviving just-cause `try?` sites are owner-blessed exceptions; Phase 11 grants them the only sanctioned `// swiftlint:disable`. (Downstream: Phase 11/LINT-01 wording needs reconciliation — flagged, not edited here.)
- **D-04:** `optional_try` stays **commented** in `.swiftlint.yml` this phase; the at-error flip + zero-violation verification are Phase 11. Phase 9 drives the count to (near-)zero.
- **D-05:** Merge, don't replace — keep the existing `AppError` case set and `isRetryable`/`alertText` semantics (real E-Hentai response meaning, ~10 `ErrorView` sites). Layer structured machinery on top.
- **D-06:** Add typed `context: Context?` where `Context = [ContextKey: AnyHashableBox]`; `ContextKey` is a `String` enum with human-readable raw values (row labels); `AnyHashableBox` is a small `Hashable & Sendable` box with `ExpressibleBy*Literal`. Which cases carry context = research/planning detail.
- **D-07:** Add `solution: String?` (per-kind, localized); conform `AppError` to `LocalizedError` (`errorDescription`→description, `recoverySuggestion`→solution). Keep `alertText`/`isRetryable` intact.
- **D-08:** Reuse + extend the existing Liquid Glass toast infra (`AppAlertState` + `.toast()` + `ToastMessageView`). Do not rebuild a renderer.
- **D-09:** Detail surface is `ErrorInfoView` — a `Form` (Description/Solution/Context/Environment + close). iOS/iPadOS only (drop every `#if os(macOS)` + Firebase `.analyticsScreen`). Env info from `AppInfo`/`DeviceClient`/`ProcessInfo` — never `AppUtil.*`/`DeviceUtil.*`.
- **D-10:** Rename `AppRouteReducer` → `PresentationReducer`; add `.errorInfo(AppError)` to its `Destination`; present `ErrorInfoView` from there.
- **D-11:** Failure toast keeps the existing 3s auto-hide; tapping it within that window opens `ErrorInfoView`. An `AppError`-bearing toast carries the error so the tap can route.
- **D-12:** Every throw site carries the error up to the nearest surface (owning reducer), never swallowed. Whether it is *presented* (tappable toast, full-screen `ErrorView`, or silent-with-justification) is decided **per site** — not a blanket rule.
- **D-13:** `.private.filterValue` returns `0` in production (display-only category, no filter bit) with a doc comment; replace `fatalError` with a dev-time issue report (inert in release) + a test. Confirm exact IssueReporting API.

### Claude's Discretion
- Exact set of `AppError` cases that gain `context` + the concrete `ContextKey` members (D-06).
- Module placement of `AnyHashableBox` (own module vs folded in) and of `ErrorInfoView` / context machinery across `AppModels`/`AppComponents`.
- Precise `try?` → `do/catch` conversion per site, and which reducers present a toast vs handle silently (D-12).

### Deferred Ideas (OUT OF SCOPE)
- None — no error-telemetry/crash-reporting backend, offline error queue, or new distribution surface. Those would be their own phases. (Analytics is the separate Phase 13.)
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| QUAL-03 | Fix the `Category.private.filterValue` `fatalError` landmine — no crash for `.private`, no all-categories iteration traps, covered by a test. | Target 1 (`reportIssue` + `withExpectedIssue`, copy-pasteable), Target section "`.private.filterValue` consumers" (URLUtil lists non-private cases explicitly; `allFiltersCases` drops `.private`), Validation Architecture QUAL-03 rows |
| QUAL-04 | Structured `AppError` (description/solution/typed context) + user-facing failure toast → dismissable detail surface; `try?` → `do/catch`; best-effort parses stay optional; `optional_try` enable-able at error with zero violations (verified Phase 11). | Targets 2 (143-site survey + 4 buckets), 3 (`AppError` merge + `AnyHashableBox`), 4 (env sourcing), 5 (toast + routing + rename blast radius), 6 (`ErrorInfoView`), Validation + Security sections |
</phase_requirements>

## Summary

This phase is a re-homing exercise, not a capability build. Every mechanism it needs already
exists in the repo: the `AppError` enum (`AppModels/Support/AppError.swift`), the unified
`AppAlertState` toast infra (`AppComponents/AppAlertState.swift` + `SystemNotificationExt`), the
full-screen `ErrorView` (`AppComponents/AlertView.swift`), the app-root presentation reducer
(`AppFeature/DataFlow/AppRouteReducer.swift`), and PointFree's `IssueReporting` (already a
resolved dependency, used ~30× as `IssueReporting.unimplemented`). The work is additive layering
plus a mechanical `try?` sweep, all held to strict behavior/appearance parity.

The two highest-risk unknowns are both resolved here with copy-pasteable answers. (1) The D-13
dev-time report is `reportIssue(_:)` from `IssueReporting`; it is a non-fatal purple runtime
warning in dev, an inert fault-level log in release, and a recordable test failure that a test
asserts with `withExpectedIssue { }` (the IssueReporting-native generalization of Swift Testing's
`withKnownIssue`). (2) The `try?` blast radius is confirmed at exactly **143 non-test sites across
40 files**, matching the CONTEXT estimate module-for-module (Parser 44, Download 36, AppTools 17,
Networking 9, FileClient 8, AppModels 6, Setting 5, Logs/Library/Image 4 each, plus singles).

**Primary recommendation:** Fold the structured-error machinery (`Context`, `ContextKey`,
`AnyHashableBox`, `solution`, `LocalizedError`) into **AppModels** alongside `AppError`; place
`ErrorInfoView` in **AppComponents** alongside `AlertView`/`ErrorView`/`AppError+Symbol`; rename
`AppRouteReducer` → `PresentationReducer` (blast radius: **exactly 3 files**) and add a
`@ReducerCaseIgnored .errorInfo(AppError)` destination; drive the `try?` sweep module-by-module
in wave order Parser → Download → AppTools → the rest, classifying each site into one of four
buckets before converting.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| `AppError` + `Context`/`ContextKey`/`AnyHashableBox`/`solution`/`LocalizedError` | AppModels (domain) | — | AppError already lives here; the box + context are pure value types with no UI/UIKit needs |
| `AppError.symbol` (SFSymbol) | AppComponents (view support) | — | Already there (`AppError+Symbol.swift`); needs SFSafeSymbols, which AppModels lacks |
| `ErrorInfoView` (Form detail surface) | AppComponents (view) | DeviceClient (env info) | Peer of `AlertView`/`ErrorView`; AppComponents already depends on DeviceClient + AppModels + Resources |
| Failure toast (`AppError`-bearing, tappable) | AppComponents (`AppAlertState`) + SystemNotificationExt (render) | — | Reuse the existing unified presentation state + `.toast()` renderer |
| Routing: failure toast → `ErrorInfoView` | AppFeature (`PresentationReducer`) | AppFeature (`TabBarView` sheet) | The renamed reducer already owns the app-root toast + `@Presents destination` |
| `.private.filterValue` dev-time report | AppModels (`Category.swift`) | AppModelsTests (assertion) | The landmine and its consumers are all in AppModels |
| `try?` → `do/catch(AppError)` sweep | Each owning module | its reducer (routing decision) | Per-site decision belongs where the throw originates (D-12) |

## Standard Stack

No new packages. Every dependency this phase touches is already resolved.

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `IssueReporting` (from `pointfreeco/xctest-dynamic-overlay`) | **1.10.1** `[VERIFIED: AppPackage/Package.resolved:257-263]` | `reportIssue(_:)` dev-time report + `withExpectedIssue { }` test assertion (D-13) | Already a project dependency; used ~30× as `IssueReporting.unimplemented` across every client |
| ComposableArchitecture | 1.25.3+ (traits) `[VERIFIED: STATE.md CONC-02]` | `@Presents`/`@ReducerCaseIgnored` destination, `_EphemeralState` toast | The app's architecture |
| `ConcurrencyExtras` | resolved (transitive) `[VERIFIED: .build/checkouts/swift-concurrency-extras/Sources/ConcurrencyExtras/AnyHashableSendable.swift]` | Prior art: `AnyHashableSendable` (`Hashable & Sendable` erasure) | Optional backing for `AnyHashableBox`; see Don't Hand-Roll |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SFSafeSymbols | resolved | `AppError.symbol` glyphs in `ErrorInfoView` | Already used by `AppError+Symbol.swift` |
| Resources (module) | in-repo | `LocalizedStringResource` + `.xcstrings` for new solution/label strings | All new user-visible strings |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `reportIssue(_:)` default reporter | `IssueReporters.current = [.breakpoint]` / `[.fatalError]` | Default runtime-warning is exactly the "dev-time warning, release-safe" behavior D-13 asks for; overriding to `.fatalError` would re-introduce the crash the phase is removing. **Do not override.** |
| Own `AnyHashableBox` in AppModels | `ConcurrencyExtras.AnyHashableSendable` directly | The box needs `ExpressibleBy*Literal` conformances; adding those to a type we don't own is a retroactive conformance (Swift 6 warns). A small owned type is cleaner (see Don't Hand-Roll). |

**Installation:** None. `IssueReporting` is already linked wherever clients define `.unimplemented`;
`import IssueReporting` in `Category.swift` and the test file is the only new import.

## Package Legitimacy Audit

No external packages are added this phase. `IssueReporting` and `ConcurrencyExtras` are already
resolved via TCA's dependency closure.

| Package | Registry | Age | Downloads | Source Repo | Verdict | Disposition |
|---------|----------|-----|-----------|-------------|---------|-------------|
| IssueReporting (`xctest-dynamic-overlay`) | SwiftPM | 5+ yrs | very high | github.com/pointfreeco/xctest-dynamic-overlay | OK | Already resolved (1.10.1) |
| ConcurrencyExtras | SwiftPM | 3+ yrs | very high | github.com/pointfreeco/swift-concurrency-extras | OK | Already resolved (transitive) |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

## Focused Answers to the Research Targets

### 1. D-13 — IssueReporting dev-time report API (RESOLVED)

**The exact API is `reportIssue(_:)`** from `import IssueReporting`. Confirmed against the resolved
source at `AppPackage/.build/checkouts/xctest-dynamic-overlay/Sources/IssueReporting/ReportIssue.swift:31`
`[VERIFIED: resolved dependency source]`:

```swift
public func reportIssue(
  _ message: @autoclosure () -> String? = nil,
  severity: IssueSeverity = .error,
  fileID: StaticString = #fileID, filePath: StaticString = #filePath,
  line: UInt = #line, column: UInt = #column
)
```

**Behavior by context** (from the doc comment + `_DefaultReporter`, `IssueReporter.swift:196`
`@TaskLocal fileprivate static var _current = LockIsolated<[any IssueReporter]>([.default])`):

- **Dev (Xcode, non-test):** the `.default` reporter emits a **purple runtime warning** (hooks
  SwiftUI's runtime-issue delivery) + a fault-level `os_log`. Non-fatal — exactly the "flags misuse
  during development" behavior. `[VERIFIED: IssueReporting/IssueReporters/DefaultReporter.swift]`
- **Release:** `.default` logs a fault-level message and returns; **it does not crash**. So
  `return 0` executes normally. This satisfies D-13's "inert in release / returns 0 in production."
  `[VERIFIED: DefaultReporter.reportIssue non-test branch]`
- **Under tests (Swift Testing or XCTest):** `reportIssue` records a **test failure**. This means a
  test that calls `.private.filterValue` **fails unless wrapped** — which is precisely why a raw
  `assertionFailure` was rejected (D-13). The wrap both asserts the report fired and prevents the
  failure.

**Test assertion is `withExpectedIssue { }`, NOT `withKnownIssue`.** Confirmed at
`IssueReporting/WithExpectedIssue.swift:45` `[VERIFIED: resolved dependency source]`. Its doc: *"A
generalized version of Swift Testing's `withKnownIssue` that works with this library's `reportIssue`
… During test runs, the issue will be sent to Swift Testing's `withKnownIssue` or XCTest's
`XCTExpectFailure` accordingly."* Critically, if the expected issue does **not** fire, it records a
`"Known issue was not recorded"` failure (`WithExpectedIssue.swift:60-69`) — so the test genuinely
proves the report happened. `withKnownIssue` (bare Swift Testing) would also catch it, but
`withExpectedIssue` is the IssueReporting-native, framework-agnostic choice and is what the skill
prescribes.

**Copy-pasteable — production call site** (`Category.swift`, replacing the `fatalError` at lines 42-46):

```swift
import IssueReporting
// ...
case .private:
    // `Private` is a display-only category (a user's private-gallery bucket), not a
    // search-filter category, so it contributes no filter bit. Reaching here means a caller
    // included `.private` in a filter computation — a programming error. Report it in dev
    // (non-fatal purple warning; inert fault log in release) and contribute nothing.
    reportIssue("`Category.private` has no `filterValue` — it is display-only and must be excluded from filter math.")
    return 0
```

**Copy-pasteable — test** (new case in `AppPackage/Tests/AppModelsTests/`, Swift Testing):

```swift
import Testing
import IssueReporting
@testable import AppModels

@Test func privateFilterValueReportsIssueAndReturnsZero() {
    withExpectedIssue {
        #expect(Category.private.filterValue == 0)
    }
}
```

`[CITED: .claude skill pfw-issue-reporting]` recommends `reportIssue` + `withExpectedIssue` for
exactly this "unreachable-in-practice but must-not-crash" shape.

### 2. `try?` blast-radius survey (RESOLVED — 143 sites, 40 files)

`rg "try\?"` over `AppPackage/Sources/**/*.swift` `[VERIFIED: rg count]`. Per-module occurrence
totals (reconciled against CONTEXT — **exact match**):

| Module | Sites | Densest files |
|--------|-------|---------------|
| ParserFeature | 44 | `Parser+List.swift` (25), `Parser+Detail.swift` (13), `Parser+Shared.swift` (3) |
| DownloadClient | 36 | `DownloadStore.swift` (14), `+ResponseValidation.swift` (4), 10 others (1-3 each) |
| AppTools | 17 | `DataCache.swift` (13), `Extensions.swift` (3), `Defaults.swift` (1) |
| NetworkingFeature | 9 | `Request+Account.swift` (3), `Request.swift`/`Request+Detail.swift` (2 each), 3 singles |
| FileClient | 8 | `FileClient.swift` (7), `TagTranslation+ChtConverted.swift` (1) |
| AppModels | 6 | `Persistence/JSONValue.swift` (6) |
| SettingFeature | 5 | `AppActivityLogsPumpReducer.swift` (4), `AppActivityLogsReducer.swift` (1) |
| LogsClient | 4 | `LogsClient.swift` (4) |
| LibraryClient | 4 | `LibraryClient.swift` (4) |
| ImageClient | 4 | `ImageClient.swift` (4) |
| AppComponents | 2 | `TagSuggestionView.swift`, `PreviewImageView.swift` |
| SystemNotificationExt / ReadingFeature / MarkdownExt / DetailFeature | 1 each | — |
| **Total** | **143** | 40 files |

**Four classification buckets that drive the wave plan** (classify before converting):

- **(a) Convert → `do/catch` that throws `AppError`** — network/file/decode calls whose failure is
  a real, surfaceable error. Examples: `NetworkingFeature/Request+*.swift` response probes;
  `FileClient.swift:35` `try? JSONDecoder()...` (importing a tag translator — failure is a real
  `fileOperationFailed`); `FileClient.swift:49` `try? data.write(...)`. These become
  `do throws(AppError) { … } catch { … }` matching the established shape at
  `AppRouteReducer.fetchGallery` (lines 184-195) `[VERIFIED: AppRouteReducer.swift]`.

- **(b) Legitimate decode-with-default survivor (D-02)** — keep `try?`, add an inline just-cause
  comment. The densest cluster is **ParserFeature**: `Parser+List.swift` is almost entirely
  `(try? parseX(...)) ?? default` and `guard let x = try? parseX(...)` optional-field extraction
  (lines 9-231) `[VERIFIED: rg on Parser+List.swift]` — HTML parsing that intentionally degrades a
  missing sub-field to a default rather than failing the whole list parse. Also
  `AppModels/JSONValue.swift:30-40` — six `try? container.decode(T.self)` **type-probing** decodes
  (try Bool, then Int, then Double, …); these genuinely cannot be `do/catch` (the throw *is* the
  control flow). `[VERIFIED: JSONValue.swift]`

- **(c) Best-effort cleanup / cancellation swallow** — a sub-bucket the planner must decide per D-02
  ("best-effort expressed as `do/catch` with fallback in `catch`, unless it truly resists that
  shape"). Two shapes resist conversion:
  - **Cancellation swallow:** `try? await Task.sleep(...)` (1 site, `View+Toast.swift:77`, plus any
    in reducers). `Task.sleep` only throws `CancellationError`; swallowing it is idiomatic and there
    is no `AppError` to raise. **Survivor** with comment. `[VERIFIED: 1 Task.sleep site]`
  - **Fire-and-forget filesystem cleanup:** `AppTools/DataCache.swift` has 13 `try?` — mostly
    `try? fileManager.removeItem(...)`, `try? touchAccessDate(...)`, `try? setResourceValues(...)`
    (lines 72-339) `[VERIFIED: DataCache.swift]`. These are cache housekeeping where failure is
    genuinely ignorable. The planner chooses per site: convert to `do/catch` that **logs** (via the
    module's `logger`) vs. keep as a commented survivor. Owner reviews each (D-02/D-03).

- **(d) Already inside a typed-throws context** — a `try?` whose enclosing function already
  `throws(AppError)`; converting is a plain `try`. Rare but check ImageClient
  (`ImageClient.swift:38,84,109,129` — `try? await dataCache.store/removeData/readerImageData`;
  best-effort cache writes inside async client fns) `[VERIFIED: ImageClient.swift]`.

**Wave-planning takeaway:** ParserFeature (44) is the largest but the **highest survivor density**
(bucket b) — most sites keep `try?` + comment, so it is lower-risk-per-site than its count suggests.
DownloadClient (36) and AppTools/DataCache (13) are the real conversion labor. The `ParserFeatureTests`
and `DownloadsFeatureTests` targets already exist `[VERIFIED: Package.swift Module enum]`, so parity
is testable per module.

### 3. `AppError` extension shape (RESOLVED)

Current type (`AppModels/Support/AppError.swift`) `[VERIFIED: full read]`:
`enum AppError: Error, Identifiable, Equatable, Hashable, Sendable` with 12 cases (`copyrightClaim`,
`ipBanned(BanInterval)`, `expunged`, `networkingFailed`, `webImageFailed`, `parseFailed`,
`quotaExceeded`, `authenticationRequired`, `fileOperationFailed(String)`, `noUpdates`, `notFound`,
`unknown`), plus `isRetryable`, `localizedDescription`, `alertText`. `symbol` lives **separately**
in `AppComponents/AppError+Symbol.swift` `[VERIFIED: full read]` (needs SFSafeSymbols).

**Additive design (D-05..D-07), all in AppModels, nothing renamed or removed:**

`AppError` is a value enum, so per-incident `context` cannot be a stored property on a bare case
without adding an associated value to every case. Two viable shapes — recommend **(A)** for minimal
churn and to preserve the existing 12 `ErrorView` call sites and `Equatable` semantics unchanged:

- **(A) Companion wrapper (recommended).** Keep `enum AppError` exactly as-is. Introduce a struct
  that carries the kind + context + solution:
  ```swift
  // AppModels/Support/AppError+Context.swift
  public typealias Context = [ContextKey: AnyHashableBox]

  public enum ContextKey: String, Hashable, Sendable {
      case action = "Action"        // human-readable raw value == ErrorInfoView row label
      case reason = "Reason"
      case url = "URL"              // path only — see Security Domain
      case statusCode = "Status Code"
      case gid = "Gallery ID"
      // … only the keys EhPanda's throw sites actually need (Claude's Discretion)
  }
  ```
  Then either attach `context` via an associated payload on a *new* case, or (cleaner) thread
  `context`/`solution` as an optional sidecar on the throwing effect. **Because CONTEXT D-06 says
  `context: Context?` on `AppError` itself**, the direct reading is a stored property — which for an
  enum means a wrapping struct. Recommend a small `struct AppError` is **not** desired (would break
  the case-based call sites). Instead add an associated-value-free carrier:

- **(B) `context`/`solution` as computed + a single generic `.detailed` companion.** Riskier for
  the 12 existing sites.

**Recommendation for the planner:** treat the exact storage mechanism as the first design task and
validate it against the parity constraint (the ~12 `alertText`/`symbol`/`isRetryable` sites and ~10
`ErrorView` sites must compile and behave unchanged — see Common Pitfalls). The literal-ergonomics
and the `LocalizedError` conformance below are independent of that choice:

```swift
extension AppError: LocalizedError {
    public var errorDescription: String? { localizedDescription }   // reuse existing
    public var recoverySuggestion: String? { solution }
}

extension AppError {
    // Per-kind, localized. New keys in AppModels/Resources/Localizable.xcstrings (all 6 locales).
    public var solution: String? {
        switch self {
        case .networkingFailed:        return String(localized: .appErrorNetworkSolution)
        case .authenticationRequired:  return String(localized: .appErrorAuthSolution)
        // … nil where no actionable suggestion exists
        default:                       return nil
        }
    }
}
```

`AnyHashableBox` (AppModels, `Hashable & Sendable`, with literal ergonomics so throws read
`context: [.action: "parseGalleryList", .reason: "missing gl3m node", .statusCode: 200]`):

```swift
public struct AnyHashableBox: Hashable, Sendable {
    public let base: any Hashable & Sendable
    public init(_ base: some Hashable & Sendable) { self.base = base }
    public var displayValue: String { String(describing: base) }   // ErrorInfoView row value
    public static func == (l: Self, r: Self) -> Bool { AnyHashable(l.base) == AnyHashable(r.base) }
    public func hash(into h: inout Hasher) { h.combine(AnyHashable(base)) }
}
extension AnyHashableBox: ExpressibleByStringLiteral  { public init(stringLiteral v: StaticString) { self.init(String(describing: v)) } }
extension AnyHashableBox: ExpressibleByIntegerLiteral { public init(integerLiteral v: Int)  { self.init(v) } }
extension AnyHashableBox: ExpressibleByBooleanLiteral { public init(booleanLiteral v: Bool) { self.init(v) } }
extension AnyHashableBox: ExpressibleByFloatLiteral   { public init(floatLiteral v: Double) { self.init(v) } }
```

**Module placement (Claude's Discretion → recommendation):** fold `AnyHashableBox`, `Context`,
`ContextKey` into **AppModels/Support** (a new `AppError+Context.swift`), **not** a new module.
AppModels is already the lowest-level model module, owns `AppError`, and depends on
Resources/AppTools/CasePaths/Sharing `[VERIFIED: Package.swift:306-313]` — everything the box needs.
A dedicated module for a ~40-line value type is package ceremony with no benefit and contradicts the
anti-wrapper rule. `AnyHashableBox` maps to prior art `ConcurrencyExtras.AnyHashableSendable` — see
Don't Hand-Roll for the reasoning to keep an owned type instead.

### 4. Environment info sourcing for `ErrorInfoView` (RESOLVED)

Post-Phase-8/5 homes `[VERIFIED: file reads]`:

| Datum | Symbol available today | Home |
|-------|------------------------|------|
| App version | `AppInfo.version` → `String` (`"null"` fallback) | `AppModels/Utilities/AppInfo.swift:4` |
| App build | `AppInfo.build` → `String` | `AppModels/Utilities/AppInfo.swift:7` |
| Device type | `@Dependency(\.deviceClient).deviceType()` → `DeviceType` (`.phone`/`.pad`/…) | `DeviceClient/DeviceClient.swift:6` (`@MainActor @Sendable`) |
| OS version | `ProcessInfo.processInfo.operatingSystemVersionString` | Foundation |

`AppUtil.*` (removed Phase 8) and `DeviceUtil.*` (deleted Phase 5) are **gone** — do not reference.
`DeviceClient.deviceType` is `@MainActor`, so read it in `ErrorInfoView`'s main-actor body (e.g.
`@Dependency(\.deviceClient) private var deviceClient` then `deviceClient.deviceType()`), or resolve
once and store. `AppInfo`/`ProcessInfo` are static and callable anywhere. `AppComponents` already
depends on both `AppModels` and `DeviceClient` `[VERIFIED: Package.swift AppComponents deps]`, so no
new module dependency is needed for `ErrorInfoView`.

### 5. Failure surface & routing wiring (RESOLVED)

**Existing toast factories** (`AppComponents/AppAlertState.swift:141-154`) `[VERIFIED]`:
`AppAlertState<Never>.error(caption: LocalizedStringResource)` and `.error(caption: String? = nil)`
both build `.toast(icon: .error, autoHide: true)`. The **3s auto-hide** is in the renderer
(`SystemNotificationExt/View+Toast.swift:77` `try? await Task.sleep(for: .seconds(3))`) `[VERIFIED]`.

**To add an `AppError`-bearing tappable failure toast (D-11):** the current `AppAlertState` has no
payload slot for an `AppError` and `Action == Never` (button-less). Two integration options:

- The toast tap must send an action, but the toast store is `Store<AppAlertState<Never>, Never>` —
  it cannot send. So the tap-to-detail affordance is wired at the **renderer/modifier** layer, not
  as a `ButtonState`. Recommend: add an optional `error: AppError?` to `AppAlertState` (kept out of
  `Equatable`/`Hashable` identity the same way `id` is excluded, or included — it's `Hashable`), and
  a new factory `AppAlertState<Never>.error(_ error: AppError)` that stores it and uses
  `error.alertText`/`localizedDescription` as the toast message. Then `ToastViewModifier`
  (`View+Toast.swift:31`) gains an `onTapGesture` that, when `store.state.error != nil`, calls a
  new closure the host passes in to route to `.errorInfo`. Because the modifier currently takes only
  the toast binding, thread a second optional `onErrorTap: (AppError) -> Void` parameter through
  `.toast(_:onErrorTap:)`. Keep the existing 3s `autoDismiss` untouched (the tap just fires before
  the timer completes). `[VERIFIED: View+Toast.swift structure]`

- Alternatively route entirely in the reducer: the tap sends `store` … not possible with `Never`.
  The modifier-closure approach above is the only clean fit for the button-less toast.

**Adding `.errorInfo(AppError)` to the destination (D-10):** follow the existing
`@ReducerCaseIgnored` idiom (`AppRouteReducer.swift:16-22`) `[VERIFIED]`:

```swift
@Reducer
enum Destination {
    @ReducerCaseIgnored case setting(EquatableVoid)
    @ReducerCaseIgnored case newDawn(Greeting)
    @ReducerCaseIgnored case errorInfo(AppError)   // NEW
}
```

Add a `presentErrorInfo(AppError)` action that sets `state.destination = .errorInfo(error)`, mirroring
`presentSetting`/`presentNewDawn` (lines 106-112). Present in `TabBarView` exactly like the existing
sheets (`TabBarView.swift:69-73` `[VERIFIED]`):

```swift
.sheet(item: $store.appRouteState.destination.errorInfo) { error in ErrorInfoView(error: error) }
```

(After rename, `appRouteState`/`appRoute` also change — see below. Note the `.errorInfo` payload is a
plain `AppError`, no child store, so `ErrorInfoView(error:)` takes the value directly.)

**Rename `AppRouteReducer` → `PresentationReducer` — exact blast radius (RESOLVED):** only **3 files**
reference the symbols `[VERIFIED: grep AppRouteReducer / appRouteState / appRoute]`:
1. `AppFeature/DataFlow/AppRouteReducer.swift` — the definition (`struct AppRouteReducer`, lines 15,
   229-230). Rename the type + the two `extension AppRouteReducer.Destination.*` lines. Consider
   renaming the file to `PresentationReducer.swift`.
2. `AppFeature/DataFlow/AppReducer.swift` — `var appRouteState = AppRouteReducer.State()` (line 24),
   `case appRoute(AppRouteReducer.Action)` (line 45), `Scope(\.appRouteState, action: \.appRoute,
   AppRouteReducer.init)` (line 315), plus ~10 `.appRoute(...)`/`state.appRouteState...` references
   (lines 67-361). Decide whether `appRouteState`/`appRoute` also rename to
   `presentationState`/`presentation` (recommended for consistency) — this widens the mechanical
   edit but stays inside these same 3 files.
3. `AppFeature/View/TabBar/TabBarView.swift` — 7 references (`store.send(.appRoute(...))`,
   `$store.appRouteState.destination.newDawn/.setting`, `.scope(\.appRouteState.$detail, …)`,
   `.scope(\.appRouteState.path, …)`, `.toast($store.scope(\.appRouteState.$toast, …))`,
   `.onOpenURL`) (lines 32-97).

No other file in `AppPackage/Sources`, `App/`, or `ShareExtension/` references these symbols. The
rename is purely mechanical and confined.

**Routing precedent already exists:** `AppRouteReducer.fetchGalleryDone` failure branch already does
`.setToast(.error())` after a 500ms delay (lines 197-208) `[VERIFIED]` — the new `AppError`-bearing
toast slots into that exact seam.

### 6. `ErrorInfoView` structure (RESOLVED)

Peer of `ErrorView`/`AlertView` in `AppComponents/AlertView.swift` `[VERIFIED: full read]`. Design a
native `Form`, iOS/iPadOS only (no `#if os(macOS)`, no Firebase `.analyticsScreen`):

```swift
public struct ErrorInfoView: View {
    private let error: AppError
    @Environment(\.dismiss) private var dismiss
    @Dependency(\.deviceClient) private var deviceClient
    public init(error: AppError) { self.error = error }

    public var body: some View {
        NavigationStack {
            Form {
                Section(.errorInfoDescription) { Text(error.localizedDescription) }
                if let solution = error.solution {
                    Section(.errorInfoSolution) { Text(solution) }
                }
                if let context = error.context, !context.isEmpty {
                    Section(.errorInfoContext) {
                        ForEach(sortedRows(context), id: \.key) { row in
                            LabeledContent(String(localized: /* ContextKey.rawValue */), value: row.value.displayValue)
                        }
                    }
                }
                Section(.errorInfoEnvironment) {
                    LabeledContent(.errorInfoAppVersion, value: "\(AppInfo.version) (\(AppInfo.build))")
                    LabeledContent(.errorInfoDevice, value: String(describing: deviceClient.deviceType()))
                    LabeledContent(.errorInfoOS, value: ProcessInfo.processInfo.operatingSystemVersionString)
                }
            }
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button(.close) { dismiss() } } }
        }
    }
}
```

**Placement:** `AppComponents/ErrorInfoView.swift`. AppComponents already carries the module
`.swiftlint.yml` (it is an existing module), so no new lint config file is needed (the AGENTS.md
new-module rule does not apply). **Accessibility (swift-accessibility skill):** `LabeledContent`
already announces label+value as one element; the SFSymbol header (if any) should be
`.accessibilityHidden(true)` decoration; the close button needs a clear label. **Localization
obligations:** new keys go in `AppComponents/Resources/Localizable.xcstrings` (section titles, env
labels, close). `AppInfo`/`deviceType`/OS strings are runtime values — pass them as `value:` on
`LabeledContent`, never bake them into a catalog key (they are not translatable). Follow the
AGENTS.md labeled-format-argument + non-translated-key rules and the project-memory **labeled**
`TextState(localized:)` caveat if any `TextState` is constructed (an unlabeled init crashes the TCA
result-builder type-checker) — but `ErrorInfoView` uses plain SwiftUI `Text`/`Section`, so this
mostly does not arise. Both `AppModels` (AppError strings) and `AppComponents` (view labels) have
module-local `Localizable.xcstrings` `[VERIFIED: find *.xcstrings]`; all 6 locales
(`de/en/ja/ko/zh-Hans/zh-Hant`) must be filled `[VERIFIED: Localizable.xcstrings locale scan]`.

## Architecture Patterns

### System Architecture Diagram

```
throw site (any module)                         Category.private.filterValue
   │  do throws(AppError) { … }                    │  reportIssue("…") ; return 0
   │  catch { <build AppError                       │  (dev: purple warning · release: inert · test: withExpectedIssue)
   │           + context + solution> }
   ▼
owning reducer effect  ──►  .setToast(.error(appError))   ── D-12 per-site: present? or handle silently
   │                                    │
   │ (primary-content load failure)     │ (user-relevant failure)
   ▼                                    ▼
full-screen ErrorView            AppError-bearing failure toast (3s auto-hide, tappable)
(AlertView + error.symbol)              │  tap within 3s
                                        ▼
                          PresentationReducer.presentErrorInfo(error)
                                        │  state.destination = .errorInfo(error)
                                        ▼
                          TabBarView .sheet(item:…destination.errorInfo) { ErrorInfoView(error:) }
                                        ▼
                          Form: Description / Suggested Solution / Context / Environment  +  Close
```

### Recommended Project Structure (new/changed files)
```
AppModels/Support/
├── AppError.swift            # existing — extend (LocalizedError, solution, context accessor)
└── AppError+Context.swift    # NEW — Context, ContextKey, AnyHashableBox
AppComponents/
├── AlertView.swift           # existing ErrorView/AlertView — UNCHANGED
├── AppError+Symbol.swift     # existing — UNCHANGED
└── ErrorInfoView.swift       # NEW — Form detail surface
AppFeature/DataFlow/
├── PresentationReducer.swift # RENAMED from AppRouteReducer.swift (+ .errorInfo case)
├── AppReducer.swift          # rename appRouteState/appRoute refs
SystemNotificationExt/
└── View+Toast.swift          # add onErrorTap routing to .toast()
AppComponents/AppAlertState.swift  # add error payload + factory
```

### Pattern 1: Established typed-throws effect (the sweep target shape)
**What:** `do throws(AppError) { … } catch { … }` inside a `.run` effect.
**When to use:** every bucket-(a) `try?` conversion.
**Example** `[VERIFIED: AppRouteReducer.swift:184-195]`:
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

### Anti-Patterns to Avoid
- **Overriding `IssueReporters.current` to `.fatalError`** — re-introduces the crash D-13 removes.
- **Blanket "every throw toasts"** — D-12 is per-site; primary-content load failures use full-screen
  `ErrorView`, not a toast; some failures are handled silently with justification.
- **Adding an associated value to all 12 `AppError` cases** — breaks the ~10 `ErrorView` sites and
  every `switch self` in `isRetryable`/`alertText`/`symbol`. Layer context beside the enum, not inside every case.
- **Retroactive `ExpressibleByStringLiteral` on `ConcurrencyExtras.AnyHashableSendable`** — a type we
  don't own; Swift 6 warns. Own the box.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Dev-time-only, release-safe misuse signal | custom `#if DEBUG assertionFailure` | `IssueReporting.reportIssue(_:)` | Already handles dev-warning / release-inert / test-recordable in one call; `assertionFailure` trips the debug-config test run (the exact reason D-13 rejects it) |
| Asserting the report fired in a test | manual failure-count spying | `withExpectedIssue { }` | Framework-agnostic (Swift Testing + XCTest), and fails if the issue did *not* fire |
| `Hashable & Sendable` type erasure | fully bespoke `AnyHashable` re-implementation | own a **thin** `AnyHashableBox` backed by `any Hashable & Sendable` (or `ConcurrencyExtras.AnyHashableSendable`) | Type erasure is subtle; keep an owned type only to attach the `ExpressibleBy*Literal` ergonomics the reference design needs |
| Toast rendering / auto-hide / swipe-dismiss | new notification renderer | existing `AppAlertState` + `.toast()` + `ToastMessageView` | D-08 mandate; the 3s auto-hide, swipe, transition, and `.task(id:)` timer are already correct |
| Full-screen error UI | new error screen | existing `ErrorView`/`AlertView` | Unchanged; only the toast gains tap-to-detail |

**Key insight:** `AnyHashableSendable` already exists in a resolved dependency
(`swift-concurrency-extras`) `[VERIFIED: .build checkout]`; the *only* reason to keep an owned
`AnyHashableBox` is that the reference design's literal ergonomics require conformances you cannot
add to a foreign type without a retroactive-conformance warning. The box's *erasure logic* should
delegate to `any Hashable & Sendable`, not be re-invented.

## Runtime State Inventory

Not a rename/migration of stored data. The one rename (`AppRouteReducer` → `PresentationReducer`) is
a pure Swift-symbol rename with **no** runtime-state footprint:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — `AppRouteReducer` is an in-memory TCA reducer, not persisted; no `@Shared`/`Codable` key uses the name | None (verified: grep shows only 3 source files, no `.xcstrings`/UserDefaults/keychain key) |
| Live service config | None | None |
| OS-registered state | None | None |
| Secrets/env vars | None | None |
| Build artifacts | None — SPM rebuilds from source; no egg-info/codegen keyed on the type name | None |

## Common Pitfalls

### Pitfall 1: Breaking the 12 existing `AppError` consumers with the context merge
**What goes wrong:** adding an associated value or changing `Equatable`/`Hashable` breaks `isRetryable`,
`alertText`, `symbol` (`AppError+Symbol.swift`), and the ~10 `ErrorView` call sites.
**Why it happens:** enums propagate any case-shape change to every exhaustive `switch`.
**How to avoid:** layer `context`/`solution` beside the enum (companion), keep the 12 cases byte-identical;
add a parity test asserting `isRetryable`/`alertText`/`symbol` outputs are unchanged for all cases.
**Warning signs:** compiler forces edits to `AppError+Symbol.swift` or `AlertView.swift`.

### Pitfall 2: The failure toast's `Action == Never` cannot `send`
**What goes wrong:** you try to make the tap a `ButtonState` action; it won't compile (`Never`).
**How to avoid:** route the tap via a modifier-level closure (`.toast(_:onErrorTap:)`) that the host
wires to `presentErrorInfo`, not through the toast store.

### Pitfall 3: Converting a type-probe `try? decode` to `do/catch`
**What goes wrong:** `JSONValue.swift` tries each type in turn; `do/catch` would need nested catches
and change control flow.
**How to avoid:** classify as bucket (b) — keep `try?`, add a just-cause comment. Same for
`Task.sleep` cancellation swallows.

### Pitfall 4: `reportIssue` failing the test suite
**What goes wrong:** the new `.private.filterValue` test (or any other test that touches `.private`)
fails because `reportIssue` records a test failure.
**How to avoid:** wrap the call in `withExpectedIssue { }`. Also audit whether any *existing* test
iterates all categories and hits `.private` — if so it must also be wrapped or must use
`allFiltersCases` (which drops `.private`, `Category.swift:9`).

### Pitfall 5: New `.xcstrings` keys missing locales
**What goes wrong:** a key added only in `en` fails Xcode's translation check.
**How to avoid:** fill all 6 locales; for non-translatable runtime values, pass them as `LabeledContent`
`value:` rather than as catalog keys (per AGENTS.md non-translated-key rule).

## Code Examples

### `.private.filterValue` — production + test (see Target 1)
Shown above; `reportIssue("…"); return 0` + `withExpectedIssue { #expect(...==0) }`.

### Throw site building context
```swift
catch {
    throw AppError.parseFailed  // + attach, per chosen storage:
    // context: [.action: "parseGalleryList", .reason: "missing gl3m node", .statusCode: httpStatus]
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `fatalError` on `.private.filterValue` | `reportIssue(_:)` + `return 0` | This phase (D-13) | No release crash; dev-visible; test-covered |
| silent `try?` swallowing errors | `do throws(AppError)` + per-site routing | This phase (QUAL-04) | Errors propagate; user-relevant ones surface |
| flat `AppError` (message only) | `AppError` + `context`/`solution`/`LocalizedError` | This phase | Diagnostic detail surface, retains all domain semantics |
| `AppUtil.*` / `DeviceUtil.*` for env info | `AppInfo` + `DeviceClient` + `ProcessInfo` | Phases 5/8 (done) | ErrorInfoView sources from injected/relocated homes |

**Deprecated/outdated:** `AppUtil`, `DeviceUtil` — removed; must not be referenced.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | The cleanest `context` storage is a companion beside the enum (not an associated value on cases). CONTEXT D-06 literally says `context: Context?` "on AppError"; the exact storage mechanism that satisfies that *and* the parity constraint is a design task, not settled here. | Target 3 | Planner must resolve storage shape first; wrong choice breaks 12 consumers (Pitfall 1) |
| A2 | Whether `appRouteState`/`appRoute` (the state var / action case) should also rename alongside the type. Recommended yes for consistency; CONTEXT D-10 only names the *type*. | Target 5 | Cosmetic; either way confined to the same 3 files |
| A3 | `ConcurrencyExtras` is importable by AppModels only if its target dependency is declared; it is resolved transitively but not currently a direct AppModels dep. Recommendation avoids needing it (owned box). | Don't Hand-Roll | If planner chooses to import it, add `.targetDependency(.concurrencyExtras)` to AppModels |

## Open Questions

1. **Which `AppError` cases carry `context`, and which `ContextKey` members exist?**
   - What we know: throw sites with real diagnostic value (parse failures, file ops, networking) benefit.
   - What's unclear: the concrete key set is explicitly Claude's Discretion (D-06).
   - Recommendation: derive `ContextKey` members from the actual bucket-(a) conversion sites during the sweep; start minimal (`action`, `reason`, `url`, `statusCode`) and grow.

2. **Per-reducer present-vs-silent decision (D-12) for the ~8 toast-owning reducers.**
   - What we know: candidates are AccountSetting, Reading, Comments, Torrents, GalleryInfos, Archives, Downloads, + app-root.
   - Recommendation: decide per site during each module's sweep; default to a failure toast for user-initiated actions, silent+logged for background/best-effort.

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| IssueReporting | D-13 report + test | ✓ | 1.10.1 | — |
| ConcurrencyExtras (AnyHashableSendable) | optional box backing | ✓ (transitive) | resolved | own box (recommended) |
| Xcode build (AppPackage-Package scheme) | build/test | ✓ | — | none — bare `swift build` fails (project rule) |

**Missing dependencies with no fallback:** none.

## Validation Architecture

nyquist_validation is **enabled** `[VERIFIED: .planning/config.json]`.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (`import Testing`) |
| Config file | none — targets in `AppPackage/Package.swift` |
| Quick run command | `xcodebuild test -scheme AppPackage-Package -only-testing:AppModelsTests` (Xcode-only; one invocation at a time) |
| Full suite command | `xcodebuild test -scheme AppPackage-Package` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| QUAL-03 SC-1 | `Category.private.filterValue == 0` **and** issue fires | unit | `withExpectedIssue { #expect(Category.private.filterValue == 0) }` in `AppModelsTests` | ❌ Wave 0 (new test case) |
| QUAL-03 | no all-categories iteration traps | unit | assert `Category.allFiltersCases` excludes `.private`; assert `URLUtil.categoryValue` over a full filter never crashes | ⚠️ verify existing coverage |
| QUAL-04 | `AppError.context`/`solution` round-trip | unit | build an `AppError` with context, assert `solution`/`errorDescription`/`recoverySuggestion` | ❌ Wave 0 (`AppModelsTests`) |
| QUAL-04 parity | `isRetryable`/`alertText`/`symbol` unchanged for all 12 cases | unit | table test over all cases asserting current outputs | ❌ Wave 0 (guards Pitfall 1) |
| QUAL-04 | `AnyHashableBox` literal ergonomics + `Hashable`/`Equatable` | unit | `#expect(AnyHashableBox("a") == AnyHashableBox("a"))`, dictionary keying | ❌ Wave 0 |
| QUAL-04 SC-3 | failure toast → `.errorInfo` route resolves | reducer (TestStore) | send `presentErrorInfo(error)`, assert `destination == .errorInfo(error)` | ❌ Wave 0 (`AppFeatureTests`) |
| QUAL-04 | per-module `try?` sweep parity | unit | existing `ParserFeatureTests` / `DownloadsFeatureTests` green after conversion | ✅ targets exist |

### Sampling Rate
- **Per task commit:** `-only-testing:<ModuleUnderEdit>Tests` (e.g. AppModelsTests, ParserFeatureTests).
- **Per wave merge:** full `AppPackage-Package` suite.
- **Phase gate:** full suite green + SwiftLint clean before `/gsd-verify-work`.

### Wave 0 Gaps
- [ ] `AppModelsTests` — new `Category.private` `withExpectedIssue` test (QUAL-03 SC-1)
- [ ] `AppModelsTests` — `AppError` context/solution/LocalizedError tests + all-cases parity table (QUAL-04)
- [ ] `AppModelsTests` — `AnyHashableBox` equality/hashing/literal tests
- [ ] `AppFeatureTests` — `presentErrorInfo` route test
- [ ] (framework already present; no install needed)

## Security Domain

security_enforcement is **enabled** (ASVS L1) `[VERIFIED: .planning/config.json]`.

### Applicable ASVS Categories
| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V7 Error Handling & Logging | **yes** | `ErrorInfoView` Context/Environment must not expose secrets; logger already gated for cookies (Phase 8) |
| V8/V9 Data Protection | yes | redact credentials/tokens from any context surfaced to the user |
| V5 Input Validation | no (no new external input parsing beyond existing parser) | — |
| V6 Cryptography | no | — |

### Known Threat Patterns for this phase
| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Sensitive data leak into user-visible error `context`/environment | Information Disclosure | Whitelist context keys; never put cookies, igneous token, member-id/pass-hash, API keys, or full request bodies into `context` or `ErrorInfoView` |
| Full-URL context row leaking query secrets | Information Disclosure | Use `ContextKey.url` for **path only**, strip query string (E-Hentai URLs can carry `apikey`/session params) |
| Diagnostic detail logged at `.public` privacy | Information Disclosure | Reuse the Phase-8 cookie-logging discipline; log AppError descriptions but never credential-bearing context values at `.public` |

**Belongs in `context`/environment (safe):** action name, human-readable reason, HTTP status code,
URL **path**, gallery `gid`/`token` (public identifiers), app version/build, device type, OS version.
**Must be redacted (never surface):** cookies (`ipb_member_id`, `ipb_pass_hash`, `igneous`), any
credential, full request/response bodies, full URLs with query strings, IP addresses, file-system
absolute paths under the user's home.

## Project Constraints (from CLAUDE.md / AGENTS.md)

- **Reducer naming:** the renamed reducer is `PresentationReducer` (keeps the `*Feature`/`*Reducer`
  project convention; `AppRouteReducer` → `PresentationReducer` per D-10).
- **SwiftLint:** read root `.swiftlint.yml` before writing Swift; conform from the start; **no
  `// swiftlint:disable`** without explicit permission. `optional_try` stays **commented** this
  phase (D-04) — do not enable it. No new module is created (ErrorInfoView lands in existing
  AppComponents), so the new-module `.swiftlint.yml`/`parent_config` rule does not trigger.
- **Localization:** new `.xcstrings` keys follow the labeled-format-argument + non-translated-key
  rules; all 6 locales (`de/en/ja/ko/zh-Hans/zh-Hant`) filled; runtime values passed as
  `LabeledContent value:`, not baked into keys. Use the **labeled** `TextState(localized:)` init if
  any `TextState` is built (project memory: unlabeled init crashes the type-checker).
- **Confirmation-dialog/alert placement:** N/A here (ErrorInfoView uses a sheet + toolbar close, not
  a confirmationDialog), but keep the close button on the stable action source.
- **Local project reference privacy (ABSOLUTE):** the reference error-handling design is reproduced
  **name-free**; no artifact, comment, or commit records the source project's name. This research
  document contains no such name and downstream artifacts must not add one.
- **No absolute home paths in generated docs:** honored (this file uses repo-relative paths only).
- **Native presentation surfaces (project memory):** ErrorInfoView is a native `Form`; the toast
  stays the existing Liquid Glass renderer — do not rebuild native affordances as custom cards.

## Sources

### Primary (HIGH confidence)
- Repo source (read in full): `AppModels/Support/AppError.swift`, `AppModels/Gallery/Category.swift`,
  `AppComponents/AppAlertState.swift`, `AppComponents/AlertView.swift`, `AppComponents/AppError+Symbol.swift`,
  `SystemNotificationExt/ToastMessageView.swift` + `View+Toast.swift`,
  `AppFeature/DataFlow/AppRouteReducer.swift`, `AppModels/Utilities/AppInfo.swift`,
  `DeviceClient/DeviceClient.swift`, `Resources/ResourceStringSymbols.swift`.
- Resolved dependency source: `xctest-dynamic-overlay/Sources/IssueReporting/ReportIssue.swift` (1.10.1),
  `WithExpectedIssue.swift`, `IssueReporters/DefaultReporter.swift`, `IssueReporter.swift`;
  `swift-concurrency-extras/Sources/ConcurrencyExtras/AnyHashableSendable.swift`.
- `AppPackage/Package.resolved` (IssueReporting 1.10.1), `AppPackage/Package.swift` (module graph),
  `.planning/config.json` (nyquist + security enabled), grep-verified `try?` counts and rename blast radius.

### Secondary (MEDIUM confidence)
- `.claude` skill `pfw-issue-reporting` (reportIssue + withExpectedIssue guidance).

### Tertiary (LOW confidence)
- None.

## Metadata

**Confidence breakdown:**
- D-13 IssueReporting API: HIGH — verified against resolved 1.10.1 source, copy-pasteable pattern.
- `try?` blast radius: HIGH — exact grep counts match CONTEXT module-for-module.
- Rename blast radius: HIGH — grep shows exactly 3 files.
- `AppError` merge shape: MEDIUM — storage mechanism (companion vs associated value) is a design task (A1).
- Environment/module placement: HIGH — verified against Package.swift dep graph and file homes.

**Research date:** 2026-07-15
**Valid until:** 2026-08-14 (stable; no fast-moving deps — all resolved/pinned)
