import AppModels
import ComposableArchitecture
import DeviceClient
import Sharing
import Synchronization
import TelemetryDeck

// The sole owner of the TelemetryDeck SDK import (D-12). Every payload that leaves the app is minted
// through this module's closed `AnalyticsSignal` vocabulary and translated to the vendor's API here,
// at the one call site — plan 14-17's lint rule (D-18) makes that boundary structural. Per D-10 the
// SDK's built-in anonymized identifier is used as-is: no default user is assigned, no custom user
// identifier is passed, and the identifier-update API is never called.

public struct AnalyticsClient: Sendable {
    // The closure properties are `var`, not `let` — a deliberate departure from the `HapticsClient`
    // template that uses `let`. The repository's signal-capture idiom builds a spy by taking `.noop`
    // and mutating one field, and this client is overridden at roughly 130 existing test sites; `var`
    // lets a test replace `send` while leaving `start` inert.
    public var start: @Sendable () -> Void
    public var send: @Sendable (AnalyticsSignal) -> Void
}

extension AnalyticsClient {
    /// The live client. A nil ``AppInfo/telemetryDeckAppID`` resolves this entire value to ``noop``
    /// and the SDK is never referenced — one check that covers contributor clones, forks, CI, the
    /// test host and previews at once (D-13).
    ///
    /// The gate lives here rather than at each call site on purpose: because a nil app ID makes the
    /// whole client a no-op, a signal can never reach an uninitialized SDK — the one behavior that
    /// would trip the SDK's assertion in debug builds. Do not "simplify" this into a call-site check.
    public static let live: Self = {
        guard let appID = AppInfo.telemetryDeckAppID else { return .noop }

        // Flipped true once `start` has initialized the SDK. `send` stays inert until then, so a
        // signal emitted between process start and the launch-finish action cannot reach an
        // uninitialized SDK and trip its assertion (threat T-14-11).
        let started = Mutex(false)

        // Overrides the SDK's own always-"Unknown" orientation parameter. Held here rather than
        // rebuilt per signal so its cache survives between signals; see `OrientationEnricher`.
        //
        // The dependency is declared *inside* the read closure, never captured out here, for the
        // same reason `AnalyticsDefaultParameters.live` declares its readers inside its body: this
        // value is a `static let`, so anything resolved at its scope would freeze whatever the
        // container held at static-init time and ignore every override applied afterwards. Reaching
        // for `DeviceClient.live` directly would sidestep the container entirely, which Phase 5
        // ruled out when it made this client `@Dependency`-only.
        let orientation = OrientationEnricher(read: {
            @Dependency(\.deviceClient) var deviceClient
            return deviceClient.interfaceOrientation()
        })

        return Self(
            start: {
                let config = TelemetryDeck.Config(appID: appID, salt: AppInfo.telemetryDeckSalt)
                config.defaultParameters = AnalyticsDefaultParameters.live
                config.metadataEnrichers = [orientation]

                // Primed before `initialize`, not after. Initializing assigns `Config.sessionID`,
                // whose `didSet` emits `TelemetryDeck.Session.started` — the one signal that never
                // passes through `send` below, so it is the only one this refresh cannot catch
                // later. Priming afterwards left the cache empty at exactly that moment and every
                // session signal reported "Unknown" forever.
                //
                // Ordering is enough to fix it even when `start` runs off the main queue: this
                // refresh and the SDK's payload assembly both hop through the main queue, and it is
                // FIFO, so enqueueing ours first lands the value before the session signal is built.
                orientation.refresh()
                TelemetryDeck.initialize(config: config)
                started.withLock({ $0 = true })
            },
            send: { signal in
                guard started.withLock({ $0 }) else { return }

                // The runtime opt-out. Read live inside the closure, never captured, so toggling the
                // setting takes effect on the very next signal rather than at the next launch.
                //
                // The gate sits on `send` alone, deliberately leaving `start` untouched: the SDK stays
                // initialized so its own session signal keeps counting installs and retention, while
                // every app-authored signal stops. `Config.analyticsDisabled` would silence both and is
                // opted out in COVERAGE.md for that reason.
                @Shared(.setting) var setting
                guard setting.isSharingAnalyticsData else { return }

                // Refreshed here, after the opt-out gate, so an opted-out install never touches the
                // scene graph on behalf of analytics.
                orientation.refresh()

                switch signal.rendered {
                case let .signal(name, parameters):
                    TelemetryDeck.signal(name, parameters: parameters)

                case let .error(id, category, parameters):
                    TelemetryDeck.errorOccurred(
                        id: id,
                        category: ErrorCategory(rawValue: category.rawValue),
                        parameters: parameters
                    )
                }
            }
        )
    }()
}

// MARK: API
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

// MARK: Test
extension AnalyticsClient {
    public static let noop = Self(start: {}, send: { _ in })

    // Both closures return `Void`, so this uses the default-placeholder `unimplemented` form rather
    // than the `HapticsClient` template's `placeholder:` form. The template's form fits a client with
    // value-returning closures; here it would evaluate a `fatalError` placeholder and crash the test
    // runner the moment an un-hardened test actually invokes `send`, which is the very case Task 3
    // asserts on. The default `()` placeholder reports a catchable issue and returns cleanly.
    public static let unimplemented = Self(
        start: IssueReporting.unimplemented("AnalyticsClient.start"),
        send: IssueReporting.unimplemented("AnalyticsClient.send")
    )
}
