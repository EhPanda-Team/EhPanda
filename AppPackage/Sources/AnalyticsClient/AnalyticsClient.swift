import AppModels
import ComposableArchitecture
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

        return Self(
            start: {
                let config = TelemetryDeck.Config(appID: appID, salt: AppInfo.telemetryDeckSalt)
                config.defaultParameters = AnalyticsDefaultParameters.live
                TelemetryDeck.initialize(config: config)
                started.withLock({ $0 = true })
            },
            send: { signal in
                guard started.withLock({ $0 }) else { return }

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

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented = Self(
        start: IssueReporting.unimplemented(placeholder: placeholder()),
        send: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
