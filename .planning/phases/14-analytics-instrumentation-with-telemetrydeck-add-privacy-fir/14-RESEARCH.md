# Phase 14: Analytics Instrumentation (TelemetryDeck) - Research

**Researched:** 2026-07-24
**Domain:** Third-party analytics SDK integration (TelemetryDeck Swift SDK) into a TCA + SPM modular iOS app
**Confidence:** HIGH (SDK API read from tagged source at `2.14.1`; all codebase claims read from the tree)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**D-01:** **Analytics is ON by default, with no opt-out.** No settings toggle, no first-run prompt, no consent dialog.
Consequently there is **no** new `Setting` field, **no** new `@Shared` consent key, **no** `GeneralSettingView` row, and
**no** new `.xcstrings` localization keys — this phase adds no user-facing UI whatsoever.

**D-02:** The legal basis for D-01, researched during discussion:
- TelemetryDeck's position is that it collects no data governed by GDPR/CCPA, stores **no IP addresses** anywhere (not in
  the database, logs, or elsewhere), and therefore requires neither consent nor an opt-out.
- Apple's App Store Review Guideline 5.1.1(ii) *would* require consent "even if such data is considered to be anonymous"
  — **but it does not apply here.** EhPanda is distributed as an `.ipa` installed via AltStore (`README.md:20`); there is
  no App Review gate.
- Caveats recorded honestly: the GDPR reading above is the *vendor's* legal position, not a regulator's ruling, and
  ePrivacy Art. 5(3) is read more strictly by some EU DPAs. This is not legal advice. If distribution ever moves to
  TestFlight or the App Store, **D-01 must be revisited** — 5.1.1(ii) would then bind.

**D-03:** Collection is disclosed in a new **`README.md` "Analytics" section**: that anonymous usage data is sent to
TelemetryDeck, what is collected, what is never collected, and a link to TelemetryDeck's privacy policy. This is the only
disclosure surface.

**D-04:** **No `PrivacyInfo.xcprivacy`** is added. None exists in the repository today and AltStore distribution does not
require one. (Revisit alongside D-01 if distribution changes.)

**D-05:** **All four flow families are instrumented** — the owner's framing was "collect everything that's not privacy
sensitive":
1. **Lifecycle & navigation** — launch/foreground; Home section viewed (Frontpage, Popular, Watched, Toplists, History);
   Favorites and Downloads tab opens; gallery detail opened.
2. **Search & discovery** — search performed; filter panel used; quick-search word used; tag tapped from a gallery.
3. **Reading & downloads** — reader session start/end; pages read per session; reading direction and dual-page mode in
   use; download started / completed / failed.
4. **Errors & feature adoption** — which `AppError` cases reach users (the Phase 9 typed error surface already classifies
   these); login failures; Cloudflare challenges hit; which settings are enabled in the field.

**D-06: Never-send list (hard constraint, no exceptions).** These must be impossible to transmit: gallery IDs (`gid`),
gallery tokens, gallery titles, any gallery or page URL, **search keyword strings**, tag *values*, usernames, cookies or
any credential material, and file paths.

**D-07: Allow-list of content-adjacent payloads.** Only these cross the line, and only in the stated shape:
- **Gallery category** — the E-Hentai category enum (Doujinshi, Manga, Artist CG, Game CG, Western, Non-H, Cosplay,
  Asian Porn, Misc).
- **Tag namespaces, counts only** — which namespaces are present on an opened gallery and how many of each, across the
  **full** E-Hentai namespace set **including `female` and `male`**. Tag *values* remain forbidden per D-06.
- **Host & login state** — E-Hentai vs ExHentai, and whether the user is authenticated.
- **Search shape** — word count, a "used tag syntax" boolean, bucketed result count, and **exact keyword length**. The
  keyword text itself is forbidden per D-06.

*Recorded for auditability:* during discussion Claude recommended cutting the tag namespaces and the exact keyword length
(fetish-namespace counts are weakly content-revealing; exact length plus a stable install ID plus timestamps is a usable
fingerprint for narrowing candidate queries). The owner had already selected both and reinstated them in full. **The
allow-list above is the decision — planners implement it as written.** No further narrowing.

**D-08: Bucket numeric values.** Pages read, result counts, session lengths and similar counters are transmitted as
buckets (e.g. `1 / 2-5 / 6-20 / 21+`), never as exact values — exact counters against a stable per-install identifier
erode anonymity in aggregate. **One documented exception: search keyword length ships exact** (per D-07).

**D-09: No free-form strings, enforced by type.** Every payload value originates from a closed Swift enum or a bucketed
number. `AnalyticsClient`'s public API must not accept a bare `String` anywhere, so a future contributor **cannot** leak
a title, keyword, or URL even by accident. This is a compile-time constraint, not a review-time convention, and it is the
primary mechanism protecting D-06.

**D-10:** Signals carry **TelemetryDeck's built-in anonymized identifier** — constant for the lifetime of one app
install, salted and hashed server-side, with no IP retention. This preserves retention, DAU/MAU and per-user session
analysis. No custom identifier, no rotation.

**D-11:** The feature-adoption settings (host, login state, reading direction, dual-page mode, tag translation, list
display mode) are registered as **TelemetryDeck global default parameters**, so every signal carries the current snapshot
and any metric is segmentable by any setting without a query-time join. TelemetryDeck bills per signal rather than per
byte, so the added payload is free.

**D-12:** A new **`AppPackage/Sources/AnalyticsClient`** module holding a `@Dependency` client, following the shape of
the 15 existing clients (`HapticsClient`, `DeviceClient`, …). **Only this module imports the TelemetryDeck SDK.** Its API
takes a closed `AnalyticsSignal` enum, satisfying D-09 structurally. Follow the established client idiom exactly:
`liveValue` / `previewValue` = `.noop` / `testValue` = `.unimplemented` (see
`AppPackage/Sources/HapticsClient/HapticsClient.swift` for the canonical template).

**D-13:** The **TelemetryDeck app ID is not committed.** It comes from a gitignored `xcconfig` (or an `Info.plist` key
fed by one); when absent, `AnalyticsClient` **no-ops entirely**. Rationale: the repository is public, so the ID is not
secret in any case (it is a write-only ingestion key, extractable from any released `.ipa`) — the goal is **dataset
cleanliness**, keeping contributor builds, forks and CI runs out of the owner's data. The same nil check covers DEBUG
builds, tests, previews and CI with one guard. The release machine carries the file; a missing file silently ships zero
analytics, which planners should surface in the README/build docs.

**D-14:** **Signals are emitted from reducer actions only** — including screen views, which derive from the navigation
actions the app already centralizes (`AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift`, `SettingPath`,
`StackState`). No `.onAppear`/`.task` emission: it double-counts on re-appear and tab switches and is not unit-testable.
Reducer-sourced signals are covered by `TestStore`.

### Claude's Discretion

The owner delegated these; planner/researcher decide:
- Signal naming convention (TelemetryDeck's `dot.separated` convention vs a flat scheme).
- Exact bucket boundaries for D-08.
- The precise app-ID plumbing mechanism (xcconfig → `Info.plist` key vs build setting).
- Which specific navigation actions map to which screen-view signals.
- Whether reader sessions emit start+end or a single end-of-session signal.

**Scope note on delegation:** "you decide" applies to open questions only. D-01 through D-14 are locked owner decisions
and must not be reopened, narrowed, or re-litigated during research, planning, or execution.

### Deferred Ideas (OUT OF SCOPE)

- **`PrivacyInfo.xcprivacy` + revisiting D-01** — required only if distribution moves to TestFlight or the App Store,
  where Guideline 5.1.1(ii) would bind. Not now.
- **ShareExtension instrumentation** — the extension is a separate target with its own lifecycle; instrumenting it was
  not discussed and is out of this phase.
- **A `REQUIREMENTS.md` entry for analytics** — Phase 14 currently maps to **no requirement ID** (all 22 v1 requirements
  belong to Phases 1–11, and the ROADMAP lists Phase 14's Requirements as "TBD"). Worth adding an `ANALYTICS-01` entry
  with traceability during planning so coverage stays honest, but it is bookkeeping, not phase scope.
- **Crash reporting / performance tracing** — adjacent to analytics, separate capability, separate phase.
</user_constraints>

<phase_requirements>
## Phase Requirements

**No requirement IDs are mapped to this phase.** `.planning/ROADMAP.md` §Phase 14 lists Requirements as "TBD", and all
22 v1 requirement IDs in `.planning/REQUIREMENTS.md` belong to Phases 1–11. CONTEXT.md `<deferred>` records an optional
`ANALYTICS-01` entry as **bookkeeping, not phase scope**.

| ID | Description | Research Support |
|----|-------------|------------------|
| — | (none mapped) | Phase scope is defined by D-01 … D-14 in `<user_constraints>` above; the planner should trace plans to decision IDs rather than requirement IDs |

If the planner adds `ANALYTICS-01` to `REQUIREMENTS.md` for traceability, the natural wording is the D-05 flow-family
list constrained by D-06/D-07 — i.e. "instrument the four flow families with a type-closed, privacy-redacted signal
vocabulary."
</phase_requirements>

## Summary

TelemetryDeck's Swift SDK is a small, dependency-free SPM package (`github.com/TelemetryDeck/SwiftSDK`, product
`TelemetryDeck`). Its current public API is namespaced under a `TelemetryDeck` enum: `TelemetryDeck.initialize(config:)`
plus `TelemetryDeck.signal(_:parameters:floatValue:customUserID:)`. The older `TelemetryManager.initialize(with:)` /
`TelemetryManager.send(...)` spellings still exist but are all `@available(*, deprecated)` — do not use them. Signal
parameters are a flat `[String: String]` dictionary; the SDK does no type-level filtering, which is exactly why D-09's
closed-enum wall has to live in `AnalyticsClient`.

Three SDK behaviors materially shape the plan. **(1)** `TelemetryManager.shared` calls `assertionFailure` when the SDK
was never initialized — so D-13's "no-op when the app ID is absent" cannot be implemented by skipping `initialize` and
letting `TelemetryDeck.signal` calls fall through; the gate must live in `AnalyticsClient.liveValue`, which resolves to
`.noop` when no app ID is present. **(2)** `Config.defaultParameters` is a `@Sendable () -> [String: String]` **closure
evaluated on every signal**, not a snapshot — so D-11 needs no mutation-after-init machinery at all; a closure that reads
`@Shared(.setting)` at call time is the whole implementation. **(3)** `sendNewSessionBeganSignal` defaults to `true`, so
the SDK already emits `TelemetryDeck.Session.started` on cold launch and on foreground-after-5-minutes. D-05 family 1's
"launch/foreground" is therefore **already covered** — hand-rolling it would double-count.

The app ID plumbing (D-13) has a clean answer that this project is already shaped for: `App/Info.plist` is a real
checked-in file that already uses `$(VAR)` substitution, and the app target currently has **no** `baseConfigurationReference`.
Attach a committed `Config/Analytics.xcconfig` that declares an empty default and then `#include?`s a gitignored local
override; surface it as an `Info.plist` key; read it from the SPM module through `Bundle.main`, which is the pattern
`AppInfo` (in `AppModels`) already uses.

**Primary recommendation:** Add `TelemetryDeck` at `from: "2.14.1"` (not the 3.0.0 betas). Build `AnalyticsClient` as a
one-function client — `send: @Sendable (AnalyticsSignal) -> Void` — whose `liveValue` is `.noop` unless an app ID is
present, whose `AnalyticsSignal` enum carries only closed enums, `Bool`s and bucket enums, and whose signal-name /
parameter-key rendering lives in one internal `AnalyticsSignal` extension so no reducer ever sees a `String`. Initialize
in `AppDelegate.application(_:didFinishLaunchingWithOptions:)` behind the existing `!AppInfo.isTesting` guard.

## Architectural Responsibility Map

| Capability | Primary Tier | Secondary Tier | Rationale |
|------------|-------------|----------------|-----------|
| SDK initialization + config | App shell (`App/`, `AppDelegateReducer`'s `AppDelegate`) | — | `initialize` must run once, before any signal, at process start; the existing `didFinishLaunchingWithOptions` already carries the `!AppInfo.isTesting` gate |
| App ID acquisition | Build system (xcconfig → `Info.plist`) → `AppModels.AppInfo` | — | Build-time value, read once via `Bundle.main`; `AppInfo` is the established Bundle-reading namespace |
| Signal vocabulary (`AnalyticsSignal`) | `AnalyticsClient` module | `AppModels` (for `Category`, `TagNamespace`, `GalleryHost`, `AppError`, `Setting` enums) | D-09 requires the vocabulary be closed and compile-checked; it must reference the app's existing domain enums |
| SDK invocation | `AnalyticsClient.live` only | — | D-12: single import site for the SDK |
| Emission decisions (when/what) | Feature reducers | — | D-14: reducer actions are the only emission trigger; makes every signal `TestStore`-provable |
| Global default parameters (D-11) | `AnalyticsClient.live` config closure reading `@Shared(.setting)` | `CookieClient`'s `.didLogin` reader for login state | The SDK evaluates the closure per signal, so the snapshot is always current with zero plumbing |
| Bucketing (D-08) | `AnalyticsClient` bucket enums | — | Bucketing must be structurally impossible to bypass; if a reducer could pass an `Int` the guarantee is a convention, not a type |

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| `TelemetryDeck` (product of `TelemetryDeck/SwiftSDK`) | `2.14.1` (latest stable) | The analytics SDK | Vendor's own first-party Swift SDK; the only supported client for the service D-01/D-02 selected |

### Supporting
None. The SDK declares **zero package dependencies** (verified in its `Package.swift`) — it adds exactly one node to the
dependency graph, which is worth stating explicitly given the v3.0.0 milestone's dependency-reduction theme.

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `2.14.1` | `3.0.0-beta.4` | 3.0.0 is in beta (four pre-releases between 2026-06-08 and 2026-07-06, no stable tag). Shipping a beta SDK into a release build for a non-load-bearing feature is not worth it. Use `from: "2.14.1"`, which will *not* resolve to 3.0.0 pre-releases (SPM excludes pre-releases from range resolution). |
| product `TelemetryDeck` | product `TelemetryClient` | `TelemetryClient` is the legacy product name retained for migration; it depends on `TelemetryDeck` and exposes the deprecated `TelemetryManager` API. Do not use. |

**Installation** (`AppPackage/Package.swift`, alphabetical among existing entries — the tree keeps them sorted):

```swift
.package(url: "https://github.com/TelemetryDeck/SwiftSDK", from: "2.14.1"),
```

```swift
// in the Target.Dependency extension, alphabetically placed:
static let telemetryDeck: Self = .product(name: "TelemetryDeck", package: "SwiftSDK")
```

Note the package *directory* name is `SwiftSDK` (repo name) while the `Package.swift` inside declares
`name: "TelemetryDeck"`. Modern SwiftPM resolves `package:` against the declared package name, so
`package: "SwiftSDK"` **or** `package: "TelemetryDeck"` may be required depending on resolution;
the safe form to try first is `package: "SwiftSDK"` (matching the URL's last path component, which is
what the existing `ColorfulX` / `SwiftyOpenCC` entries in this file do). [ASSUMED — confirm at build time;
this is a one-line fix either way.]

**Version verification** (2026-07-24):
- Repo: `TelemetryDeck/SwiftSDK`, created 2020-10-06, last push 2026-07-22, 223 stars, not archived. [VERIFIED: GitHub API]
- Latest stable release tag `2.14.1`, published 2026-06-05. [VERIFIED: GitHub releases API]
- `let sdkVersion = "2.14.1"` in `Sources/TelemetryDeck/TelemetryClient.swift` at that tag. [VERIFIED: raw source]

## Package Legitimacy Audit

The `gsd-tools query package-legitimacy` seam covers npm/PyPI/crates only; SPM was verified manually against the
authoritative source (the vendor's own docs page links to this exact repository).

| Package | Registry | Age | Signal | Source Repo | Verdict | Disposition |
|---------|----------|-----|--------|-------------|---------|-------------|
| `TelemetryDeck/SwiftSDK` | SPM (GitHub) | ~5.8 yrs (created 2020-10-06) | 223 stars, pushed 2026-07-22, active release cadence | `github.com/TelemetryDeck/SwiftSDK` | OK | Approved |

**Packages removed due to [SLOP] verdict:** none
**Packages flagged as suspicious [SUS]:** none

Provenance: the SPM URL was obtained from `https://telemetrydeck.com/docs/guides/swift-setup/` (the vendor's official
setup guide) and then confirmed against the GitHub API — authoritative-source discovery plus tool confirmation, so this
is `[VERIFIED: telemetrydeck.com/docs + GitHub API]`, not a search-derived guess.

Additional supply-chain note: the SDK ships its own `PrivacyInfo.xcprivacy` inside the target
(`Sources/TelemetryDeck/PrivacyInfo.xcprivacy`, `.copy`-ed as a resource). This does **not** conflict with D-04 — D-04 is
about the *app* not adding one; the SDK's manifest travels with the SDK regardless. [VERIFIED: SDK `Package.swift`]

## Architecture Patterns

### System Architecture Diagram

```
BUILD TIME
  Config/Analytics.local.xcconfig   (gitignored, release machine only)
              │  #include?
              ▼
  Config/Analytics.xcconfig  ──►  TELEMETRYDECK_APP_ID = <id or empty>
              │  baseConfigurationReference (EhPanda target, Debug + Release)
              ▼
  App/Info.plist   <key>TelemetryDeckAppID</key><string>$(TELEMETRYDECK_APP_ID)</string>

RUNTIME — INITIALIZATION (once, at process start)
  AppDelegate.application(_:didFinishLaunchingWithOptions:)
              │  guarded by existing  !AppInfo.isTesting
              ▼
  AnalyticsClient.live  ── reads ──►  AppInfo.telemetryDeckAppID (Bundle.main)
              │                                  │
              │ appID nil/empty ─────────────────┴──► resolve to .noop, never call initialize
              │ appID present
              ▼
  TelemetryDeck.initialize(config:)
        config.defaultParameters = { <closure reading @Shared(.setting) + didLogin> }   ← D-11
        (SDK then auto-emits TelemetryDeck.Session.started on launch & foreground)

RUNTIME — EMISSION (per user action)
  User taps / navigates / errors
              ▼
  Feature reducer receives an Action case              ← D-14: reducers only
              ▼
  .run { analyticsClient.send(.someSignal(closedEnum, bucket)) }
              ▼
  AnalyticsClient.send   ─ renders name + [String: String] ─►  TelemetryDeck.signal(...)
              │                                                        │
              │                                          merges config.defaultParameters()
              │                                          + SDK DefaultSignalPayload
              ▼                                                        ▼
   (test builds: .unimplemented / .noop)                     batched HTTPS upload
                                                             clientUser = SHA256(identifierForVendor)

TYPE WALL (D-09)
  Reducers ──► AnalyticsSignal (closed enum, no String payloads) ──► [String: String]
                                                    ▲
                                 the ONLY place a String is minted
```

### Recommended Project Structure

```
AppPackage/Sources/AnalyticsClient/
├── .swiftlint.yml                  # parent_config: ../../../.swiftlint.yml  (mandatory, CLAUDE.md)
├── AnalyticsClient.swift           # struct + DependencyKey + DependencyValues + noop/unimplemented
├── AnalyticsSignal.swift           # the closed enum — D-09's wall
├── AnalyticsSignal+Rendering.swift # internal: signal name + parameter dictionary (only String site)
├── Buckets.swift                   # CountBucket, PageCountBucket, DurationBucket (D-08)
└── AnalyticsDefaultParameters.swift# D-11 global snapshot closure
```

`AnalyticsClient`'s target dependencies: `.module(.appModels)` (for `Category`, `TagNamespace`, `GalleryHost`,
`ReadingDirection`, `ListDisplayMode`, `AppError`, `Setting`, `AppInfo`), `.module(.cookieClient)` if the D-11 login-state
parameter reads `@SharedReader(.didLogin)`, `.targetDependency(.composableArchitecture)`,
`.targetDependency(.telemetryDeck)`, `.targetDependency(.sharing)`. Plus `plugins: swiftLintPlugins`.

> ⚠ `AnalyticsClient → CookieClient` is a real new edge. If the planner prefers to avoid it, the login-state
> parameter can instead be threaded in by whoever configures the client at launch. Either is defensible; flag it as a
> plan-time decision rather than silently taking the dependency.

### Pattern 1: The `@Dependency` client (project canon)

**What:** Struct of `@Sendable` closures + `DependencyKey` with `liveValue` / `previewValue = .noop` /
`testValue = .unimplemented`, plus a `DependencyValues` computed property.
**When to use:** Always here — D-12 locks it, and 15 modules already follow it.
**Example** (shape lifted verbatim from `AppPackage/Sources/HapticsClient/HapticsClient.swift`):

```swift
// Source: AppPackage/Sources/HapticsClient/HapticsClient.swift (in-tree canonical template)
public struct AnalyticsClient: Sendable {
    public let send: @Sendable (AnalyticsSignal) -> Void
}

public enum AnalyticsClientKey: DependencyKey {
    public static let liveValue = AnalyticsClient.live
    public static let previewValue = AnalyticsClient.noop
    public static let testValue = AnalyticsClient.unimplemented
}

extension DependencyValues {
    public var analyticsClient: AnalyticsClient {
        get { self[AnalyticsClientKey.self] }
        set { self[AnalyticsClientKey.self] = newValue }
    }
}

extension AnalyticsClient {
    public static let noop: Self = .init(send: { _ in })

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        send: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
```

Note `HapticsClient` does **not** `import IssueReporting` — it reaches `IssueReporting.unimplemented` through
`ComposableArchitecture`'s re-export. Mirror that; adding an explicit import would trip nothing but is unnecessary.

### Pattern 2: The D-13 gate belongs in `liveValue`, not at the call site

```swift
extension AnalyticsClient {
    /// Resolves to a real client only when a build-time app ID is present. A contributor build, a
    /// fork, CI, a test host and a SwiftUI preview all take the `.noop` branch through one check —
    /// which is also what keeps `TelemetryDeck.signal` from ever running uninitialized (the SDK
    /// trips `assertionFailure` in that case).
    public static var live: Self {
        guard let appID = AppInfo.telemetryDeckAppID, !appID.isEmpty else { return .noop }
        var config = TelemetryDeck.Config(appID: appID)
        config.defaultParameters = AnalyticsDefaultParameters.snapshot
        TelemetryDeck.initialize(config: config)
        return .init(send: { signal in
            TelemetryDeck.signal(signal.name, parameters: signal.parameters)
        })
    }
}
```

⚠ `liveValue` is resolved lazily and cached by the `Dependencies` library, so putting `initialize` inside it works but
makes initialization implicit in first use. **Preferred:** keep `live` pure (no side effect) and expose a second closure
`start: @Sendable () -> Void` that `AppDelegate` calls explicitly on `didFinishLaunchingWithOptions`, matching how
`libraryClient.initializeWebImage()` is already sequenced in `AppDelegateReducer.onLaunchFinish`. That also lets
`onLaunchFinish` (a reducer action) own it, which is more consistent with D-14's spirit.

### Pattern 3: The D-09 type wall

`AnalyticsSignal` is a closed enum; every associated value is a closed enum, a `Bool`, or a bucket enum. The only place
a `String` is minted is an `internal` rendering extension:

```swift
public enum AnalyticsSignal: Sendable, Equatable {
    // Navigation
    case homeSectionViewed(HomeSection)          // closed enum owned by AnalyticsClient
    case tabOpened(AppTab)
    case galleryDetailOpened(category: Category, // AppModels enum
                             tagNamespaces: TagNamespaceCounts)
    // Search
    case searchPerformed(wordCount: CountBucket,
                         usedTagSyntax: Bool,
                         keywordLength: Int,     // D-07 documented exact-value exception
                         resultCount: CountBucket)
    case filterPanelUsed
    case quickSearchWordUsed
    case tagTapped(namespace: TagNamespace)      // namespace only; value forbidden by D-06
    // Reading & downloads
    case readingSessionEnded(pagesRead: CountBucket,
                             duration: DurationBucket,
                             direction: ReadingDirection,
                             dualPage: Bool)
    case downloadStateChanged(DownloadOutcome)
    // Errors & adoption
    case errorSurfaced(AppErrorKind)             // derived from AppError's case, not its payload
    case loginFailed(LoginFailureKind)
    case cloudflareChallengeEncountered
}
```

`TagNamespaceCounts` carries the D-07 "namespaces present + count of each" shape without leaking values:

```swift
public struct TagNamespaceCounts: Sendable, Equatable {
    public let counts: [TagNamespace: CountBucket]   // keys are a closed enum; values bucketed
}
```

Note the *count* of tags in a namespace is a numeric counter and therefore falls under D-08's bucketing rule; only
keyword length is exempted. If the owner intended exact per-namespace counts, that is a D-07/D-08 boundary question the
planner should surface, not resolve silently. See Open Questions.

`AppErrorKind` must be a **new** closed enum mirroring `AppError`'s 12 cases *without* their associated values —
`AppError.copyrightClaim(String)`, `.expunged(String)` and `.fileOperationFailed(String)` all carry free-form strings
that D-06 forbids, so `AppError` itself can never be an associated value of `AnalyticsSignal`. Phase 9 already made this
easy: `ErrorInfo` separates the case from the per-incident diagnostics.

### Pattern 4: Emitting from a reducer (D-14)

```swift
case .sectionTapped(let section):
    // ... existing behavior ...
    return .merge(
        existingEffect,
        .run(operation: { _ in analyticsClient.send(.homeSectionViewed(.init(section))) })
    )
```

`send` is a synchronous `@Sendable` closure (the SDK batches internally and never blocks), so `.run` is only needed to
keep the reducer pure. Calling it directly in the reducer body would be a side effect in `Reduce`, which TCA forbids.

### Anti-Patterns to Avoid

- **`TrackNavigationModifier` / `.trackNavigation(path:)`** — the SDK ships a SwiftUI view modifier for navigation
  signals. It is built on view lifecycle, which violates D-14 *and* trips this repo's `lifecycle_modifiers` custom
  SwiftLint rule (error severity). Do not use it.
- **`TelemetryDeck.navigationPathChanged(to:)`** — the single-argument form keeps hidden global state
  (`NavigationStatus.shared.previousNavigationPath`) and, per the SDK's own doc comment, "will produce incorrect graphs
  if you don't call it from every screen in your app." With partial instrumentation it fabricates transitions the user
  never made. Prefer plain `signal(_:parameters:)` for screen views.
- **`TelemetryManager.send(...)` / `TelemetryManager.initialize(with:)`** — deprecated; the compiler will warn, and this
  project treats warning cleanliness as load-bearing.
- **Reaching for `TelemetryDeck.signal` outside `AnalyticsClient`** — breaks D-12 and D-09 in one move.
- **`floatValue:`** — the SDK's numeric side-channel takes an exact `Double`. Every numeric this phase sends is bucketed
  (D-08), so `floatValue` has no legitimate use here. Leaving it unused keeps the bucketing guarantee total.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Launch / foreground session signal | A `scenePhase` observer emitting `app.launched` / `app.foregrounded` | SDK's automatic `TelemetryDeck.Session.started` (`sendNewSessionBeganSignal` defaults `true`; new session on cold launch or foreground after 5 min) | D-05 family 1 is already covered; hand-rolling double-counts against the SDK's own signal and against the built-in session insights |
| Session length / count stats | Timing reader/app sessions by hand | `sessionStatsEnabled` (defaults `true`) | Vendor-side privacy-preserving aggregation feeds the built-in insights; note it writes to `UserDefaults` ~1×/sec |
| Anonymous install identifier | A UUID in `UserDefaults` / Keychain | SDK default (`identifierForVendor`, SHA-256'd on-device, re-salted+hashed server-side) — D-10 | Zero configuration; a custom ID would need its own lifecycle, migration and privacy argument |
| Device / OS / app-version / locale context | Reading `UIDevice`, `Bundle`, `Locale` into parameters | SDK's `DefaultSignalPayload` (ships `TelemetryDeck.Device.*`, `TelemetryDeck.AppInfo.*`, locale, region, `isDebug`, `isSimulator`, …) | Already on every signal; re-sending would collide with reserved keys |
| Debug/test-build data separation | `#if DEBUG` guards around every call | SDK's `testMode` (defaults to the `DEBUG` flag) | Test-mode signals are segregated server-side; D-13's nil-app-ID gate covers the rest |
| Preview suppression | Checking `XCODE_RUNNING_FOR_PREVIEWS` yourself | SDK's `swiftUIPreviewMode` (auto-detected) — plus `previewValue = .noop` | Belt and braces, both free |
| Retry / batching / backoff on upload | A queue + timer | SDK's `SignalCache` + exponential backoff (`transmitInterval` 10s, `maxBackoffInterval` 300s, `cacheLimit` 10 000) | Non-trivial and already correct |

**Key insight:** roughly half of D-05's family 1 and the entire "device/app context" surface arrive for free. The
phase's real work is (a) the type wall, (b) choosing emission sites, and (c) the build-time ID plumbing — not
transport, identity, or lifecycle.

## Common Pitfalls

### Pitfall 1: `TelemetryDeck.signal` on an uninitialized SDK trips `assertionFailure`

**What goes wrong:** `TelemetryManager.shared` — reached by every `signal` call — does:

```swift
// Source: Sources/TelemetryDeck/TelemetryClient.swift @ 2.14.1
public static var shared: TelemetryManager {
    if let telemetryManager = initializedTelemetryManager { return telemetryManager }
    else if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { /* mock */ }
    else {
        assertionFailure("Please call TelemetryManager.initialize(...) before accessing the shared telemetryManager instance.")
        return .init(configuration: .init(appID: ""))
    }
}
```

**Why it happens:** the naive reading of D-13 is "if there's no app ID, just don't initialize." Every subsequent signal
then trips an assertion in DEBUG and allocates a throw-away manager in Release.
**How to avoid:** gate in `AnalyticsClient` — no app ID ⇒ `.noop` ⇒ `TelemetryDeck` is never touched.
**Warning signs:** debug-build crashes on a fork or a fresh clone; `TelemetryManager.isInitialized == false` at a
signal site.

### Pitfall 2: Reserved signal names and parameter keys are silently corrupting

**What goes wrong:** the SDK reserves the `TelemetryDeck.` prefix and this exact key set (case-insensitive):
`type, clientUser, appID, sessionID, floatValue, newSessionBegan, platform, systemVersion, majorSystemVersion,
majorMinorSystemVersion, appVersion, buildNumber, isSimulator, isDebug, isTestFlight, isAppStore, modelName,
architecture, operatingSystem, targetEnvironment, locale, region, appLanguage, preferredLanguage, telemetryClientVersion`.
Using one "will cause unexpected behavior" — the SDK only *logs an error* through `logHandler`; it still sends.
**Why it happens:** `region`, `locale`, `platform` are natural names for app-side parameters.
**How to avoid:** namespace every parameter key (`Search.wordCount`, `Gallery.category`). Never prefix with
`TelemetryDeck.`.
**Warning signs:** an `OSLog` error from the TelemetryDeck logger at launch; an insight whose values look like device
metadata.

### Pitfall 3: `testValue = .unimplemented` will break existing tests the moment a reducer is instrumented

**What goes wrong:** D-12 locks `testValue = .unimplemented`, so any existing test that drives an instrumented action
fails with an unimplemented-dependency issue. The blast radius across the affected targets:

| Test target | `TestStore(` sites | Files |
|---|---|---|
| `DownloadsFeatureTests` | 75 | 56 |
| `SettingFeatureTests` | 28 | 11 |
| `AppFeatureTests` | 10 | 4 |
| `HomeFeatureTests` | 8 | 2 |
| `DetailFeatureTests` | 5 | 4 |
| `ReadingFeatureTests` | 1 | 4 |

Only the subset that touches an instrumented action actually fails, but the planner must budget for it.
**Why it happens:** `.unimplemented` is the *correct* default (it is what makes an unintended signal loud) — the cost is
paid at instrumentation time, not at client-authoring time.
**How to avoid:** sequence the plan so each instrumentation task carries its own test-fixup, and prefer
`$0.analyticsClient = .noop` at the `TestStore` sites that need it (the established idiom in this repo — see
`AppPackage/Tests/DetailFeatureTests/CommentsReducerTests.swift`, which does exactly this for `hapticsClient`). A
suite-wide `@Suite(.dependency(\.analyticsClient, .noop))` trait would be tidier but requires adding
`DependenciesTestSupport` from `pointfreeco/swift-dependencies`, which is currently only a *transitive* dependency and
would have to be declared explicitly in `AppPackage/Package.swift`.
**Warning signs:** a wave of `Unimplemented: analyticsClient.send` failures in an unrelated suite.

### Pitfall 4: A missing xcconfig can become a build warning, not a silent no-op

**What goes wrong:** pointing `baseConfigurationReference` straight at a gitignored file means every fresh clone builds
with "unable to open base configuration reference file", and some CI setups escalate that.
**Why it happens:** the obvious implementation of "gitignored xcconfig."
**How to avoid:** commit the outer xcconfig; have it declare the empty default and then optionally include the local
one. `#include?` (with the question mark) is xcconfig's optional-include directive and does not error when the file is
absent. Later assignments win, so the default must come first:

```
// Config/Analytics.xcconfig  — COMMITTED
TELEMETRYDECK_APP_ID =
#include? "Analytics.local.xcconfig"
```

```
// Config/Analytics.local.xcconfig  — GITIGNORED, release machine only
TELEMETRYDECK_APP_ID = ABC123-...
```

`.gitignore` gains `Config/Analytics.local.xcconfig`. (Note `.gitignore` already carries a vestigial
`Config/LocalSigning.xcconfig` line for a `Config/` directory that does not exist — harmless, and this phase gives the
directory a real purpose.)
**Warning signs:** a yellow build warning on a clean clone.

### Pitfall 5: The default salt is empty

`Config.salt` defaults to `""`. The SDK's own doc comment recommends "a random string of 64 letters, integers and
special characters", and warns that changing it later makes every existing user look new. This is a decision the phase
must make **once** — either accept the empty default permanently, or put the salt in the same gitignored xcconfig
alongside the app ID. It cannot be revisited later without resetting all retention/DAU data. Not covered by any locked
decision; see Open Questions.

### Pitfall 6: `identifierForVendor` is not quite "constant for the lifetime of one app install"

D-10's phrasing is close but not exact: `identifierForVendor` is stable across reinstalls *unless* all apps from the
same vendor are removed from the device, at which point it regenerates. The practical effect on this phase is nil, but
the README disclosure (D-03) should not over-claim stability in either direction.

### Pitfall 7: `defaultParameters` is a closure — read it, don't snapshot it

The type is `@Sendable () -> [String: String]` and it is invoked inside `internalSignal` on **every** signal. A common
mistake is to compute the D-11 dictionary once at launch and assign `{ frozenDict }`, which then never reflects a
setting the user changes mid-session. Assign a closure that reads `@Shared(.setting)` at call time.

## Code Examples

### Reading the build-time app ID from an SPM module

`Bundle.main` inside an SPM target linked into the app resolves to the **app** bundle, so the SPM module can read the
app target's `Info.plist` directly. `AppPackage/Sources/AppModels/Utilities/AppInfo.swift` already relies on this:

```swift
// Source: AppPackage/Sources/AppModels/Utilities/AppInfo.swift (in tree)
public enum AppInfo {
    public static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "null"
    }
    // ...
}
```

The phase extends it:

```swift
extension AppInfo {
    /// The TelemetryDeck app ID, supplied at build time via `Config/Analytics.xcconfig`
    /// (`TELEMETRYDECK_APP_ID` → `Info.plist`). `nil` on any build that did not supply one —
    /// contributor clones, forks, CI, the test host — which is what makes analytics no-op there.
    public static var telemetryDeckAppID: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "TelemetryDeckAppID") as? String,
              !value.isEmpty
        else { return nil }
        return value
    }
}
```

`App/Info.plist` gains, in its existing alphabetical position:

```xml
<key>TelemetryDeckAppID</key>
<string>$(TELEMETRYDECK_APP_ID)</string>
```

The file already substitutes `$(EXECUTABLE_NAME)`, `$(PRODUCT_NAME)`, `$(MARKETING_VERSION)` and others, so no build
setting change is needed to enable substitution. [VERIFIED: `App/Info.plist`, `EhPanda.xcodeproj/project.pbxproj`
`INFOPLIST_FILE = App/Info.plist` on both app-target configurations]

### D-11 global default parameters

```swift
// Evaluated by the SDK on EVERY signal — so it always reflects current settings.
enum AnalyticsDefaultParameters {
    static let snapshot: @Sendable () -> [String: String] = {
        @Shared(.setting) var setting
        @SharedReader(.didLogin) var didLogin
        return [
            "App.host": setting.galleryHost.rawValue,          // "E-Hentai" / "ExHentai"
            "App.loggedIn": String(didLogin),
            "App.readingDirection": setting.readingDirection.analyticsName,
            "App.dualPageMode": String(setting.enableDualPageMode),
            "App.translateTags": String(setting.translateTags),
            "App.listDisplayMode": setting.listDisplayMode.analyticsName
        ]
    }
}
```

`ReadingDirection` and `ListDisplayMode` are `Int`-raw enums, so they need an explicit stable string spelling — do
**not** send `String(rawValue)`, which produces meaningless integers in the dashboard and silently changes meaning if a
case is inserted. Give each a small `analyticsName` switch inside `AnalyticsClient`. `GalleryHost` and `Category` are
`String`-raw and can use `rawValue` directly (`"E-Hentai"`, `"Doujinshi"`, `"Artist CG"`, …).

### Signal name rendering (the single String site)

```swift
extension AnalyticsSignal {
    var name: String {
        switch self {
        case .homeSectionViewed:            "Navigation.homeSectionViewed"
        case .tabOpened:                    "Navigation.tabOpened"
        case .galleryDetailOpened:          "Navigation.galleryDetailOpened"
        case .searchPerformed:              "Search.performed"
        case .filterPanelUsed:              "Search.filterPanelUsed"
        case .quickSearchWordUsed:          "Search.quickSearchWordUsed"
        case .tagTapped:                    "Search.tagTapped"
        case .readingSessionEnded:          "Reading.sessionEnded"
        case .downloadStateChanged:         "Download.stateChanged"
        case .errorSurfaced:                "Error.surfaced"
        case .loginFailed:                  "Account.loginFailed"
        case .cloudflareChallengeEncountered: "Account.cloudflareChallengeEncountered"
        }
    }
}
```

### Signal naming convention — recommendation (Claude's Discretion)

**Use dot-separated `Domain.eventName`, with no `defaultSignalPrefix`.**

Rationale, in order of weight:
1. It is TelemetryDeck's own convention — the SDK's built-in signals are `TelemetryDeck.Navigation.pathChanged`,
   `TelemetryDeck.Session.started`, `TelemetryDeck.Error.occurred`, and the setup guide's worked example is
   `Oven.Bake.startBaking`. [CITED: telemetrydeck.com/docs/guides/swift-setup/, SDK source]
2. The dashboard sorts alphabetically, so a shared prefix groups related signals visually.
   [CITED: telemetrydeck.com/docs/articles/namespaces/]
3. Skip `defaultSignalPrefix = "EhPanda."` — the app ID already scopes the dataset, and the prefix would make every
   name in the dashboard start with the same 8 characters while adding a second place where names are assembled.
4. Apply the same shape to parameter keys (`Search.wordCount`, `Gallery.category`) and skip `defaultParameterPrefix`
   for the same reason. Dotted keys also structurally avoid every reserved key in Pitfall 2.

**Bucket boundaries — recommendation (Claude's Discretion, D-08).** Powers-of-ish-four, which is the standard shape for
long-tailed usage counters:
- `CountBucket`: `zero, one, twoToFive, sixToTwenty, twentyOneToFifty, fiftyOnePlus` → `"0" "1" "2-5" "6-20" "21-50" "51+"`
- `DurationBucket` (seconds): `underTen, tenToSixty, oneToFiveMinutes, fiveToTwentyMinutes, overTwentyMinutes`

One bucket enum reused everywhere beats per-metric boundaries: it keeps the D-08 guarantee auditable in one place and
makes cross-metric comparison possible.

**Reader session shape — recommendation (Claude's Discretion).** Emit a **single end-of-session signal**
(`Reading.sessionEnded`) carrying pages-read and duration buckets. Reasons: it halves the signal count (TelemetryDeck
bills per signal); a start signal without an end is unanalyzable anyway; and `ReadingReducer` already has the exact
seam — `.onPerformDismiss` runs synchronously in the child reducer before the parent nils the presentation, which is why
`flushReadingProgress` is called there. That is the correct emission site.
⚠ Do **not** use the SDK's `startDurationSignal` / `stopAndSendDurationSignal` pair: it sends
`TelemetryDeck.Signal.durationInSeconds` as an *exact* rounded value, which violates D-08. Compute the duration in the
reducer (from an injected `\.date` or `\.continuousClock`, both already used in this repo) and bucket it.

## Codebase Map: D-05 Emission Sites

Real action cases, read from the tree on 2026-07-24. `«…»` marks where the payload must be derived rather than taken
directly from the action.

### Family 1 — Lifecycle & navigation

| D-05 item | Emission site | Action case | Note |
|---|---|---|---|
| Launch / foreground | — | — | **Already emitted by the SDK** (`TelemetryDeck.Session.started`). Do not instrument. |
| Home section viewed | `HomeFeature/HomeReducer.swift` | `.sectionTapped(HomeSectionType)` | `HomeSectionType` has only `.frontpage` and `.toplists` |
| Home section viewed (rest) | `HomeFeature/HomeReducer.swift` | `.miscTapped(HomeMiscGridType)` | Popular / Watched / History reach the user through the misc grid; read `HomeMiscGridType` in `HomeView.swift` for the case list |
| Favorites / Downloads tab open | `AppFeature/DataFlow/AppReducer.swift` + `TabBarReducer` | `.tabBar(…)` | The tab-selection action is the reducer-level seam; `AppReducer` already routes it |
| Gallery detail opened (from a list) | `HomeReducer` / `SearchRootReducer` / `FavoritesReducer` | `.pushGalleryDetail(Gallery)` (all three), `DownloadsReducer.pushGalleryDetail(DownloadedGallery)` | ⚠ four separate sites; a shared helper avoids four divergent payload constructions |
| Gallery detail opened (deep link / clipboard / iPad modal) | `AppFeature/DataFlow/PresentationFeature.swift` | `.presentGalleryDetail(gallery:downloaded:)` | The fifth entry path — easy to miss |

`«category»` = `gallery.category` (`AppModels/Gallery/Category.swift`).
`«tagNamespaces»` = derived from `Gallery.tags` / `GalleryDetail.tags`; count per `TagNamespace`, values discarded.

### Family 2 — Search & discovery

| D-05 item | Emission site | Action case |
|---|---|---|
| Search performed | `SearchFeature/SearchReducer.swift` | `.fetchGaleries(_:)` for issue; **`.fetchGalleriesDone(Result<GalleriesResult, AppError>)` is the better site** — the result count (D-07 bucketed) is only known there |
| Search performed (root) | `SearchFeature/SearchRootReducer.swift` | `.pushSearch` / `.appendHistoryKeyword(String)` | ⚠ `appendHistoryKeyword` carries the raw keyword — the D-06 wall must intercept it; only `keyword.count` may cross |
| Filter panel used | `SearchReducer` `.filtersButtonTapped`, `SearchRootReducer` `.filtersButtonTapped`, `FavoritesReducer` (none — no filters), `HomeReducer` via `HomePath` | two sites |
| Quick-search word used | `SearchReducer.quickSearchButtonTapped`, `SearchRootReducer.quickSearchButtonTapped`, `FavoritesReducer.quickSearchButtonTapped` | three sites |
| Tag tapped from a gallery | `DetailFeature/DetailReducer.swift` | `.tagDetailButtonTapped(TagDetail)` | ⚠ `TagDetail` carries the tag **value**; emit `namespace` only |

### Family 3 — Reading & downloads

| D-05 item | Emission site | Action case |
|---|---|---|
| Reader session end (pages read, duration, direction, dual-page) | `ReadingFeature/ReadingReducer+Body.swift` | `.onPerformDismiss` (line ~73; already the synchronous teardown seam) |
| Reader session start (if the planner chooses start+end) | same file | `.onPresented` (line ~82) |
| Download started | `DetailFeature/DetailReducer.swift` | `.startDownload(String)` → prefer `.startDownloadDone(Result<Void, AppError>)` |
| Download retried | `DetailReducer` | `.retryDownloadDone(Result<Void, AppError>)` |
| Download completed / failed | `DownloadsFeature/DownloadsReducer.swift` | `.observeDownloadsDone([DownloadedGallery])` — state transitions are observed here, not signalled directly; ⚠ this fires on every observation tick, so completion must be detected as a *transition* or it will emit repeatedly |
| Download deleted / moved | `DownloadsReducer` | `.deleteDownloadDone`, `.moveDownloadDone` |

⚠ The download-completion site is the least clean of the four families. `DownloadsReducer` learns about completion
through a stream of full snapshots (`.observeDownloadsDone`), so a naive emission double-counts. The planner should
either diff old-vs-new state in that case, or find a narrower seam inside `DownloadClient`/`DownloadCoordinator` and
route it through a reducer action. Budget a task for this specifically.

### Family 4 — Errors & feature adoption

| D-05 item | Emission site | Note |
|---|---|---|
| Which `AppError` cases reach users | `AppFeature/DataFlow/PresentationFeature.swift` `.setToast(AppAlertState<Never>)` / `.presentErrorInfo(ErrorInfo)` | Phase 9 centralized the user-visible error surface here — one site covers "reached the user", which is exactly D-05's wording. Far better than instrumenting every `…Done(.failure)`. |
| Login failures | `SettingFeature` login reducer | `AppError.authenticationRequired` / `.loginCaptchaRequired`; Phase 12 named these |
| Cloudflare challenges hit | `SettingFeature` login reducer | `AppError.cloudflareChallengeFailed` (Phase 12) |
| Which settings are enabled in the field | — | **Covered by D-11 global default parameters** — no dedicated signal needed. Every signal already carries the settings snapshot. |

`AppError`'s 12 cases (`AppPackage/Sources/AppModels/Support/AppError.swift`): `copyrightClaim(String)`,
`ipBanned(BanInterval)`, `expunged(String)`, `networkingFailed`, `webImageFailed`, `parseFailed`, `quotaExceeded`,
`authenticationRequired`, `cloudflareChallengeFailed`, `loginCaptchaRequired`, `unsupportedDeepLink`,
`fileOperationFailed(String)`, `noUpdates`, `notFound`, `unknown`. Three carry free-form `String` payloads — the
`AppErrorKind` mirror enum must drop them (D-06).

## Runtime State Inventory

Not a rename/refactor/migration phase — green-field addition, verified by the code scout on 2026-07-24 and re-confirmed
here (no analytics/telemetry symbols in the tree). Section retained with explicit negatives because the phase touches
build configuration and a vendor service:

| Category | Items Found | Action Required |
|----------|-------------|------------------|
| Stored data | None — no analytics store exists. The SDK creates its own `UserDefaults` suite `com.telemetrydeck.<hash>` at runtime for its signal cache and session stats. | None (SDK-managed) |
| Live service config | The TelemetryDeck dashboard app must exist and its app ID be issued before any data lands. Not in git; owner-side prerequisite. | Owner obtains the app ID; planner adds a `checkpoint:human-verify` before the release build |
| OS-registered state | None — verified: no new background task, URL scheme, or scheduler registration. | None |
| Secrets / env vars | New: `TELEMETRYDECK_APP_ID` (and optionally `salt`) in `Config/Analytics.local.xcconfig`, gitignored. Not a secret in the confidentiality sense (D-13) — a dataset-cleanliness measure. | Add `.gitignore` entry; document in README/build docs |
| Build artifacts | `AppPackage/Package.resolved` gains a `SwiftSDK` pin. `Config/Analytics.local.xcconfig` must exist on the release machine or the shipped `.ipa` sends nothing — silently, by design (D-13). | Surface prominently in the README build section |

## Project Constraints (from CLAUDE.md)

| Directive | Impact on this phase |
|---|---|
| Reducers carry a `Feature` suffix | This phase adds **no reducer** — `AnalyticsClient` is a client. No conflict. (Note: existing feature reducers in the tree are named `HomeReducer`, `SearchReducer`, … — the `Feature` suffix rule was applied going forward from Phase 9's `PresentationFeature`. Nothing here needs renaming.) |
| A new module **must** carry its own `.swiftlint.yml` | `AppPackage/Sources/AnalyticsClient/.swiftlint.yml` containing exactly `parent_config: ../../../.swiftlint.yml` |
| Read root `.swiftlint.yml` before writing Swift; no suppressions | Relevant rules for this phase: `lifecycle_modifiers` (error) forbids `.onAppear`/`.task`/`.onDisappear` — reinforces D-14 and rules out the SDK's navigation view modifier; `optional_try` (error) forbids `try?`; `no_unchecked_sendable`, `no_preconcurrency`, `no_nslock` (all error) — the SDK's own `@unchecked Sendable` types are third-party source and are not scanned, but **do not** mirror the pattern in `AnalyticsClient`; `labeled_tuple_elements` (error) means multi-element tuple types need labels or a named struct (hence `TagNamespaceCounts` as a struct); `sorted_imports` (error); `line_length` 120 error; `single_line_trailing_closure` (error) — `.run(operation: { … })` parenthesized form, matching the existing tree; `date_property_at_suffix`; `system_name_image_parameter`. |
| Labeled localized-format arguments | Not applicable — D-01 removes all UI, so no `.xcstrings` keys are added |
| Confirmation dialog / alert placement | Not applicable — no UI |
| **Local project reference privacy** (absolute, overriding) | No other local project was consulted for this research. Nothing to redact. |
| **No absolute home paths in generated docs** | Every path in this document is repository-relative. |

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Swift Testing (`import Testing`, `@Suite` / `@Test`) + TCA `TestStore` |
| Config file | `AppPackage/Tests/FeatureTests.xctestplan` |
| Quick run command | `swift test --package-path AppPackage --filter AnalyticsClientTests` |
| Full suite command | `xcodebuild test -project EhPanda.xcodeproj -scheme EhPanda -destination 'platform=iOS Simulator,name=iPhone 17'` (the `EhPanda` scheme is what runs the whole `AppPackage` graph; there is no `AppPackage-Package` scheme — noted in Phase 10) |

⚠ A new test target must be added to `AppPackage/Tests/FeatureTests.xctestplan` **and** the `EhPanda` scheme. Phase 11
found three test targets silently skipped by the scheme (`CookieClientTests`, `ImageClientTests`,
`ReadingFeatureTests`) — a new target that is not registered runs zero tests and looks green.

### Phase Requirements → Test Map
| Behavior | Test Type | Automated Command | File Exists? |
|----------|-----------|-------------------|--------------|
| `AnalyticsSignal` renders stable names + parameter keys for every case | unit | `swift test --package-path AppPackage --filter AnalyticsSignalRenderingTests` | ❌ Wave 0 |
| No rendered parameter value can be a free-form String (D-06/D-09 wall) | unit (exhaustive over all cases) | same target | ❌ Wave 0 |
| Bucket boundaries map correctly at every edge (D-08) | unit | `--filter BucketTests` | ❌ Wave 0 |
| `live` resolves to `.noop` when the app ID is absent (D-13) | unit | `--filter AnalyticsClientGateTests` | ❌ Wave 0 |
| D-11 default-parameter closure reflects a *changed* setting (not a snapshot) | unit | `--filter AnalyticsDefaultParametersTests` | ❌ Wave 0 |
| Each instrumented reducer action emits exactly the expected signal | unit (`TestStore` + spy) | per existing feature test target | ❌ per-target additions |
| No signal is emitted on non-instrumented actions | covered structurally by `testValue = .unimplemented` | — | ✅ free |

### Asserting a signal from a `TestStore`

The established repo idiom (`LockIsolated` + a closure override, both already used in `SettingFeatureTests`):

```swift
@MainActor
@Test
func tappingHomeSectionEmitsOneNavigationSignal() async {
    let signals = LockIsolated([AnalyticsSignal]())
    let store = TestStore(
        initialState: HomeReducer.State(),
        reducer: HomeReducer.init
    ) {
        $0.analyticsClient = .init(send: { signal in signals.withValue({ $0.append(signal) }) })
        $0.hapticsClient = .noop
    }

    await store.send(.sectionTapped(.frontpage)) { /* existing state mutation */ }
    await store.finish()

    #expect(signals.value == [.homeSectionViewed(.frontpage)])
}
```

This requires `AnalyticsSignal: Equatable` — make it so, and it also gives free assertions on associated values.
Because the override replaces the whole client, unrelated tests keep `.unimplemented` and stay loud.

### Sampling Rate
- **Per task commit:** `swift test --package-path AppPackage --filter <target touched by the task>`
- **Per wave merge:** full `AppPackage` test run
- **Phase gate:** full suite green through the `EhPanda` scheme before `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `AppPackage/Tests/AnalyticsClientTests/` — new test target (declare in `Package.swift` `Module` enum + `targets`, with `plugins: swiftLintPlugins`)
- [ ] Register the new target in `AppPackage/Tests/FeatureTests.xctestplan` **and** the `EhPanda` scheme
- [ ] `AppPackage/Sources/AnalyticsClient/.swiftlint.yml`
- [ ] Decide and implement the `.noop` override strategy for existing suites (see Pitfall 3)

## Security Domain

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | no | The phase adds no auth; it only *reads* login state as a boolean |
| V3 Session Management | no | TelemetryDeck sessions are analytics sessions, not auth sessions |
| V4 Access Control | no | No new access decision |
| V5 Input Validation | yes (inverted) | The relevant control is **output** validation: `AnalyticsSignal`'s closed-enum API is the compile-time control that prevents forbidden data from leaving the device (D-09) |
| V6 Cryptography | no (hand-rolling forbidden) | Identifier hashing is entirely SDK-side (SHA-256, on-device + server-side re-salt). Do not add app-side hashing. |
| V8 Data Protection / Privacy | **yes — the core of this phase** | D-06 never-send list, D-07 allow-list, D-08 bucketing, D-13 gating |
| V9 Communication | yes | SDK posts to `https://nom.telemetrydeck.com` over TLS via `URLSession`. No pinning; consistent with the rest of this app. |

### Known Threat Patterns for this stack

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| A future contributor adds a signal carrying a gallery title / search keyword / URL | Information Disclosure | D-09's closed-enum API — the only structural defense. **Recommend a `custom_rules` SwiftLint rule banning `import TelemetryDeck` outside the `AnalyticsClient` module** as a second layer enforcing D-12. (New lint rules in this repo have historically been added deliberately, with an owner decision — surface it as a proposal, not a given.) |
| Bucketed counters plus a stable install ID plus timestamps narrow a user's identity in aggregate | Information Disclosure | D-08 bucketing is the mitigation the owner chose; exact keyword length is a knowingly accepted exception (D-07, recorded in CONTEXT) |
| A parameter key collides with an SDK reserved key and overwrites device metadata | Tampering (of one's own dataset) | Dotted namespacing (Pitfall 2) |
| Contributor/fork/CI builds pollute the owner's dataset | Tampering | D-13's nil-app-ID gate |
| A DEBUG build's data mixes with production data | Tampering | SDK `testMode` defaults to the `DEBUG` flag; segregated server-side |
| The app ID is extracted from a released `.ipa` and used to inject junk signals | Tampering | Accepted and reasoned about in D-13 — it is a write-only ingestion key, not a secret. No mitigation in scope. |

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `TelemetryManager.initialize(with: config)` | `TelemetryDeck.initialize(config:)` | The "Grand Rename" (SDK 2.x) | Old spelling deprecated with a fix-it; every tutorial predating the rename shows the old form |
| `TelemetryManager.send("name", with: params)` | `TelemetryDeck.signal("name", parameters: params)` | same | Old form deprecated; argument order also changed for the `customUserID` overload (no fix-it possible) |
| `TelemetryManager.updateDefaultUser(to:)` | `TelemetryDeck.updateDefaultUserID(to:)` | same | Not needed here (D-10 uses the default identifier) |
| `TelemetryDeck.navigate(to:)` | `TelemetryDeck.navigationPathChanged(to:)` | 2.x | The old name is `@available(*, unavailable)` — a hard compile error, not a warning |

**Deprecated / outdated:**
- The `TelemetryClient` SPM *product* — legacy alias, retained only for migration.
- Any training-data snippet using `TelemetryManager` — will compile with warnings, which this project does not accept.

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `package: "SwiftSDK"` is the correct `Target.Dependency` package identifier (vs. `"TelemetryDeck"`) | Standard Stack | Build error on first resolve; one-word fix |
| A2 | `Bundle.main` from the `AnalyticsClient` SPM module resolves to the app bundle at runtime | Code Examples | Would break the D-13 read path. Strongly supported by the in-tree `AppInfo` precedent (same mechanism, shipping today), but not executed this session |
| A3 | `#include?` in an xcconfig silently no-ops when the included file is absent | Pitfall 4 | A clean-clone build warning; falls back to committing an empty `Analytics.local.xcconfig` template. Not verified against Xcode this session |
| A4 | `HomeMiscGridType` contains the Popular / Watched / History cases | Codebase Map | Emission-site list for one D-05 item shifts; the enum is in `HomeFeature/HomeView.swift` and takes 30 seconds to confirm at plan time |
| A5 | SPM `from: "2.14.1"` will not resolve to a `3.0.0-beta.*` pre-release tag | Alternatives | A beta SDK could be pinned unintentionally; mitigate with `.upToNextMajor(from: "2.14.1")` explicitly, or check `Package.resolved` after the first resolve |
| A6 | `identifierForVendor` regenerates only when all vendor apps are removed | Pitfall 6 | Only affects README wording accuracy |

## Open Questions

1. **The D-07 category list omits two `Category` cases.**
   - What we know: D-07 permits "the E-Hentai category enum" and then parenthetically lists nine names. The actual
     `Category` enum has eleven cases — the list omits `imageSet` ("Image Set") and `private` ("Private").
   - What's unclear: whether the omission is deliberate narrowing or an incomplete recitation of the enum. The owner's
     stated framing ("collect everything that's not privacy sensitive") and the named entity ("the category enum")
     both point at incomplete recitation.
   - Recommendation: implement the **full `Category` enum**, since that is the named entity, and put a
     `checkpoint:human-verify` on it. Do **not** re-narrow — CONTEXT is explicit that D-07 is not to be tightened, and
     silently dropping two cases would be tightening. Note that `Category.private` is already a display-only bucket in
     this codebase, so it may simply never occur.

2. **Do per-namespace tag counts (D-07) get bucketed under D-08?**
   - What we know: D-07 says "which namespaces are present … and how many of each." D-08 says counters ship as buckets
     with exactly one exception (keyword length).
   - What's unclear: whether the owner pictured exact counts here.
   - Recommendation: bucket them — D-08's exception list is explicit and singular, and reading it as exhaustive is the
     reading that honors both decisions. Surface as a one-line confirmation, not a re-litigation.

3. **The identifier salt (Pitfall 5).**
   - What we know: `Config.salt` defaults to `""`; the SDK recommends a random 64-character salt; changing it later
     resets every user identity.
   - What's unclear: no locked decision covers it.
   - Recommendation: set a salt now, stored in the same gitignored xcconfig as the app ID. It costs one line and is
     effectively unfixable later. Needs an owner decision because it is a permanent commitment.

4. **A lint rule enforcing D-12's single-import boundary.**
   - What we know: D-12 says only `AnalyticsClient` imports the SDK. Today that is a convention.
   - Recommendation: propose a `custom_rules` entry banning `import TelemetryDeck` with an `excluded:` path for the
     module. This repo's lint rules have all been owner-approved additions, so propose rather than assume.

5. **The ROADMAP goal line still says "opt-in."**
   - CONTEXT flags this. The planner should reword `.planning/ROADMAP.md` §Phase 14 to drop "opt-in" while keeping
     "privacy-first." Also worth adding the deferred `ANALYTICS-01` entry to `REQUIREMENTS.md` for traceability
     (CONTEXT `<deferred>` calls this bookkeeping, not scope — so it is a small task, not a plan).

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Xcode / `xcodebuild` | Building and testing | assumed present (project builds today) | — | — |
| Swift 6.3.1 toolchain | `AppPackage` (`swift-tools-version: 6.3.1`) | assumed present | — | — |
| Network access to `github.com` | SPM resolution of `SwiftSDK` | ✓ (verified this session) | — | — |
| A TelemetryDeck account + issued app ID | Any data actually landing | ✗ (owner-side, not verifiable from here) | — | **Yes, by design** — D-13 makes a missing ID a total no-op. Development and testing proceed without it. |

**Missing dependencies with no fallback:** none — the phase is fully implementable and testable without an app ID.
**Missing dependencies with fallback:** the TelemetryDeck app ID (fallback: silent no-op, which is D-13's intended
behavior; only the final "does data arrive" verification needs it).

## Sources

### Primary (HIGH confidence)
- `github.com/TelemetryDeck/SwiftSDK` @ tag `2.14.1` — `Package.swift`, `Sources/TelemetryDeck/TelemetryDeck.swift`,
  `Sources/TelemetryDeck/TelemetryClient.swift`, `Sources/TelemetryDeck/Signals/Signal.swift`,
  `Sources/TelemetryDeck/Signals/SignalManager.swift`, `Sources/TelemetryDeck/Presets/TelemetryDeck+Navigation.swift`,
  `Sources/TelemetryDeck/Presets/TelemetryDeck+Errors.swift` — read verbatim
- GitHub REST API — repo metadata and release list for `TelemetryDeck/SwiftSDK`
- `https://telemetrydeck.com/docs/guides/swift-setup/` — SPM URL, `initialize`/`signal` API, config knobs
- This repository, read directly: `AppPackage/Package.swift`, `.swiftlint.yml`, `.gitignore`, `App/Info.plist`,
  `App/EhPandaApp.swift`, `EhPanda.xcodeproj/project.pbxproj`, `AppPackage/Sources/HapticsClient/HapticsClient.swift`,
  `AppPackage/Sources/AppModels/Utilities/AppInfo.swift`, `AppPackage/Sources/AppModels/Persistent/Setting.swift`,
  `AppPackage/Sources/AppModels/Support/AppError.swift`, `AppPackage/Sources/AppModels/Gallery/Category.swift`,
  `AppPackage/Sources/AppModels/Tags/TagNamespace.swift`,
  `AppPackage/Sources/AppFeature/DataFlow/PresentationFeature.swift`,
  `AppPackage/Sources/AppFeature/DataFlow/AppDelegateReducer.swift`, and the eight feature reducers' `Action` enums

### Secondary (MEDIUM confidence)
- `https://telemetrydeck.com/docs/articles/anonymization-how-it-works/` — identifier derivation (corroborated by SDK source)
- `https://telemetrydeck.com/docs/articles/namespaces/` (via search) — alphabetical-grouping rationale for dotted names
- `https://telemetrydeck.com/docs/guides/privacy-faq/` — the D-02 basis (cited in CONTEXT; not re-litigated here)

### Tertiary (LOW confidence)
- Assumptions A1–A6 above — training knowledge or in-tree inference, not executed this session

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — package identity, version and API read from tagged source and the vendor's own docs
- Architecture: HIGH — the client shape is a locked decision with an in-tree template; the seam analysis is source-derived
- Pitfalls: HIGH — Pitfalls 1, 2, 3, 5, 7 are read directly from SDK source or counted in this tree; Pitfall 4 rests on A3
- Codebase map: HIGH for action names (read from the tree), MEDIUM for which action is the *right* site in three
  places (download completion, tab opens, `HomeMiscGridType`)

**Research date:** 2026-07-24
**Valid until:** 2026-08-23 (30 days) — but re-check the SDK version if 3.0.0 leaves beta, since a major bump may move
the `Config` type out of its `TelemetryManagerConfiguration` typealias
