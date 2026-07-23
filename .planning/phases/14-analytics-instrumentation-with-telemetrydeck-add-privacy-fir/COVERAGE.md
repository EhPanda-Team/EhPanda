# API Coverage — TelemetryDeck Swift SDK

> Full coverage by default. Opt-outs are explicit, reasoned decisions.

**SDK:** `github.com/TelemetryDeck/SwiftSDK`, product `TelemetryDeck`, tag `2.14.1`
**Surface enumerated from:** `Sources/TelemetryDeck/*.swift` at that tag (read 2026-07-24), not from memory.
**Phase:** 14 — Analytics Instrumentation

Decision keys reference the locked owner decisions in `14-CONTEXT.md` (`D-01` … `D-14`).

---

## Initialization & configuration

| capability | decision | reason |
|---|---|---|
| `TelemetryDeck.initialize(config:)` | INTEGRATE | |
| `TelemetryDeck.Config.init(appID:)` | INTEGRATE | |
| `TelemetryDeck.Config.salt` | INTEGRATE | Set once from the gitignored local xcconfig; permanent commitment, owner-confirmed in plan `14-02`. |
| `TelemetryDeck.Config.defaultParameters` | INTEGRATE | D-11 — the settings snapshot on every signal. |
| `TelemetryDeck.Config.sendNewSessionBeganSignal` | INTEGRATE | Kept at its `true` default; this *is* D-05 family 1 (launch / foreground). |
| `TelemetryDeck.Config.sessionStatsEnabled` | INTEGRATE | Kept at its `true` default; feeds the vendor's built-in session insights. |
| `TelemetryDeck.Config.testMode` | INTEGRATE | Kept at its auto-`DEBUG` default so debug builds are segregated server-side. |
| `TelemetryDeck.Config.swiftUIPreviewMode` | INTEGRATE | Kept at its auto-detected default; belt-and-braces with `previewValue = .noop`. |
| `TelemetryDeck.Config.reservedParameterWarningsEnabled` | INTEGRATE | Kept `true` so a reserved-key collision is logged rather than silent. |
| `TelemetryDeck.Config.logHandler` | INTEGRATE | Kept at the default `.standard(.info)` — it is the only channel that surfaces reserved-key errors. |
| `TelemetryDeck.Config.baseURL` / `apiBaseURL` | OPT-OUT | Not needed — the vendor endpoint is the target; no self-hosted ingestion. |
| `TelemetryDeck.Config.namespace` | OPT-OUT | Not needed — one dataset; the app ID already scopes it, and the SDK docs advise against setting it. |
| `TelemetryDeck.Config.defaultSignalPrefix` | OPT-OUT | Explicitly out of scope — dotted `Domain.event` names are chosen instead; a prefix adds a second place where names are assembled. |
| `TelemetryDeck.Config.defaultParameterPrefix` | OPT-OUT | Explicitly out of scope — same reason; parameter keys are dotted at the rendering site. |
| `TelemetryDeck.Config.defaultUser` | OPT-OUT | D-10 mandates the built-in anonymized identifier; no custom user ID. |
| `TelemetryDeck.Config.sessionID` | OPT-OUT | Not needed — SDK-managed; the app has no custom session semantics. |
| `TelemetryDeck.Config.urlSession` | OPT-OUT | Not needed — the default `URLSession.shared` matches the rest of the app's transport posture. |
| `TelemetryDeck.Config.cacheLimit` | OPT-OUT | Not needed — the 10 000 default is correct; tuning transport is explicitly out of scope. |
| `TelemetryDeck.Config.transmitInterval` | OPT-OUT | Not needed — the 10 s default is correct. |
| `TelemetryDeck.Config.maxBackoffInterval` | OPT-OUT | Not needed — the 300 s default is correct. |
| `TelemetryDeck.Config.analyticsDisabled` | OPT-OUT | D-01 — there is no runtime opt-out; D-13's absent-app-ID gate is the only disable mechanism, and it resolves before the SDK is touched. |
| `TelemetryDeck.Config.metadataEnrichers` (`SignalEnricher`) | OPT-OUT | Explicitly out of scope — a second parameter-injection point would sit outside the D-09 type wall; `defaultParameters` covers the same need inside it. |
| `TelemetryDeck.Config.sendSignalsInDebugConfiguration` | OPT-OUT | Deprecated in the SDK in favour of `testMode`; this project does not accept deprecation warnings. |
| `TelemetryDeck.Config.showDebugLogs` | OPT-OUT | Deprecated in the SDK in favour of `logHandler`. |
| `TelemetryDeck.Config.telemetryAllowDebugBuilds` | OPT-OUT | Deprecated alias of `sendSignalsInDebugConfiguration`. |

## Signal emission

| capability | decision | reason |
|---|---|---|
| `TelemetryDeck.signal(_:parameters:)` | INTEGRATE | The single emission call behind `AnalyticsClient.send`. |
| `TelemetryDeck.signal(_:floatValue:)` | OPT-OUT | Explicitly out of scope — `floatValue` is an exact `Double`; D-08 requires every numeric to be bucketed, so leaving it unused keeps the bucketing guarantee total. |
| `TelemetryDeck.signal(_:customUserID:)` | OPT-OUT | D-10 — the built-in anonymized identifier is the only identity; a per-signal override would defeat it. |
| `TelemetryDeck.updateDefaultUserID(to:)` | OPT-OUT | D-10 — no custom identifier, no rotation. |
| `TelemetryManager.hashedDefaultUser` | OPT-OUT | D-10 — the app never reads or reasons about the identifier. |
| `TelemetryDeck.generateNewSession()` | OPT-OUT | Not needed — the SDK's own session boundaries (cold launch, foreground after 5 min) are the intended semantics. |
| `TelemetryDeck.requestImmediateSync()` | OPT-OUT | Not needed — the SDK's batching and backoff are correct; a manual flush has no trigger in this app. |
| `TelemetryDeck.terminate()` | OPT-OUT | Not needed — there is no teardown point; the client lives for the process. |

## Duration signals

| capability | decision | reason |
|---|---|---|
| `TelemetryDeck.startDurationSignal(_:parameters:)` | OPT-OUT | D-08 — the pair emits `TelemetryDeck.Signal.durationInSeconds` as an exact rounded value. Reader session length is computed in the reducer and bucketed instead. |
| `TelemetryDeck.stopAndSendDurationSignal(_:parameters:)` | OPT-OUT | D-08 — same. |
| `TelemetryDeck.cancelDurationSignal(_:)` | OPT-OUT | Unreachable — the start/stop pair it cancels is opted out. |

## Error signals

| capability | decision | reason |
|---|---|---|
| `TelemetryDeck.errorOccurred(id:category:)` | INTEGRATE | D-05 family 4 renders through it with `id` drawn from the closed `AppErrorKind` vocabulary, minted inside `AnalyticsClient`'s rendering layer. Unlocks the vendor's built-in error insights. |
| `ErrorCategory` (`.thrownException` / `.userInput` / `.appState`) | INTEGRATE | Closed SDK enum; each `AppErrorKind` maps to one case. |
| `TelemetryDeck.errorOccurred(id:category:message:)` | OPT-OUT | D-06 — `message` is free-form and the natural value would be an error description that can embed a title, path or URL. |
| `TelemetryDeck.errorOccurred(identifiableError:...)` (both overloads) | OPT-OUT | D-06 — the overloads send `error.localizedDescription` as `message`; `AppError`'s string-carrying cases would leak through it. |
| `IdentifiableError` / `AnyIdentifiableError` / `.with(id:)` | OPT-OUT | Unreachable — only used by the `identifiableError:` overloads, which are opted out. |

## Navigation signals

| capability | decision | reason |
|---|---|---|
| `TelemetryDeck.navigationPathChanged(from:to:)` | OPT-OUT | D-14 — screen views are sourced from reducer navigation actions, which the app already centralizes; the from/to form needs total screen coverage to produce correct graphs. |
| `TelemetryDeck.navigationPathChanged(to:)` | OPT-OUT | D-14, and the single-argument form keeps hidden global previous-path state that fabricates transitions the user never made under partial instrumentation. |
| `View.trackNavigation(path:)` / `TrackNavigationModifier` | OPT-OUT | D-14 forbids view-lifecycle emission, and the modifier trips this repository's error-severity `lifecycle_modifiers` lint rule. |
| `TelemetryDeck.navigate(from:to:)` / `navigate(to:)` | OPT-OUT | Marked unavailable in the SDK — a hard compile error, not a warning. |

## Purchase, subscription & "pirate metric" presets

| capability | decision | reason |
|---|---|---|
| `TelemetryDeck.Purchase.purchaseCompleted(...)` | OPT-OUT | Not needed — the app sells nothing; there is no StoreKit surface. |
| `TrialConversionTracker` | OPT-OUT | Not needed — no trials, no subscriptions. |
| `TelemetryDeck.Revenue.paywallShown(...)` | OPT-OUT | Not needed — no paywall. |
| `TelemetryDeck.Acquisition.acquiredUser(...)` | OPT-OUT | Not needed — no acquisition channels or campaign attribution to report. |
| `TelemetryDeck.Acquisition.leadStarted(...)` / `leadConverted(...)` | OPT-OUT | Not needed — no lead funnel. |
| `TelemetryDeck.Activation.onboardingCompleted(...)` | OPT-OUT | Not needed — the app has no onboarding flow. |
| `TelemetryDeck.Activation.coreFeatureUsed(featureName:)` | OPT-OUT | Explicitly out of scope — it would duplicate the D-05 flow-family signals under a second name and split the same event across two dashboard insights. |
| `TelemetryDeck.Referral.referralSent(...)` | OPT-OUT | Not needed — no referral mechanism. |
| `TelemetryDeck.Referral.userRatingSubmitted(...)` | OPT-OUT | Not needed — no in-app rating prompt (and D-01 adds no UI this phase). |

## Legacy / interop surface

| capability | decision | reason |
|---|---|---|
| `TelemetryClient` SPM product | OPT-OUT | Legacy alias retained for migration; it re-exports the deprecated manager API. |
| `TelemetryManager.initialize(with:)` / `.send(...)` / `.updateDefaultUser(to:)` | OPT-OUT | Deprecated across the board; this project treats warning cleanliness as load-bearing. |
| `TelemetryManager.shared` / `.isInitialized` | OPT-OUT | Internal accessor; reaching it is what trips the SDK's uninitialized `assertionFailure`. The D-13 gate keeps the app off this path entirely. |
| `TelemetryClient+ObjC` (`TelemetryManagerObjC`) | OPT-OUT | Not needed — no Objective-C call sites in this project. |
| SDK-bundled `PrivacyInfo.xcprivacy` (resource) | INTEGRATE | Ships with the SDK target automatically; does not conflict with D-04, which is about the *app* not adding one. |

---

## Coverage summary

| | count |
|---|---|
| INTEGRATE | 15 |
| OPT-OUT | 37 |
| OPT-OUT without a reason | 0 |
