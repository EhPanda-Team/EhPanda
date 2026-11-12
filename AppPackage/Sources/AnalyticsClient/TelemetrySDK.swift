import ComposableArchitecture
import DeviceClient
import Foundation
import TelemetryDeck

// The seam over the TelemetryDeck SDK, and the only file in the app that imports it (Phase 14 D-12).
// `AnalyticsClient` decides what may leave the app and when the SDK runs; this file only translates
// those decisions into SDK calls, so the client is tested against a recording fake instead.

/// The four SDK calls the analytics client makes.
struct TelemetrySDK: Sendable {
    struct Configuration: Sendable {
        let appID: String
        let salt: String?
        /// Evaluated by the SDK on every signal, so it must read live state (D-11).
        let defaultParameters: @Sendable () -> [String: String]
    }

    var initialize: @Sendable (Configuration) -> Void
    var terminate: @Sendable () -> Void
    var signal: @Sendable (_ name: String, _ parameters: [String: String]) -> Void
    var errorOccurred: @Sendable (
        _ id: String, _ category: AnalyticsErrorCategory, _ parameters: [String: String]
    ) -> Void
}

extension TelemetrySDK {
    /// The real SDK.
    ///
    /// It owns the orientation enricher, which overrides the SDK's own always-"Unknown" orientation
    /// parameter. The enricher is held here rather than rebuilt per signal so its cache survives between
    /// signals; see `OrientationEnricher`.
    ///
    /// The dependency is declared *inside* the read closure, never captured out here: this value is a
    /// `static let`, so anything resolved at its scope would freeze whatever the container held at
    /// static-init time and ignore every override applied afterwards. Reaching for `DeviceClient.live`
    /// directly would sidestep the container entirely, which Phase 5 ruled out when it made the device
    /// client `@Dependency`-only.
    static let live: Self = {
        let orientation = OrientationEnricher(read: {
            @Dependency(\.deviceClient) var deviceClient
            return deviceClient.interfaceOrientation()
        })

        return Self(
            initialize: { configuration in
                let config = TelemetryDeck.Config(appID: configuration.appID, salt: configuration.salt)
                config.defaultParameters = configuration.defaultParameters
                config.metadataEnrichers = [orientation]

                // Primed before `initialize`, not after. Initializing assigns `Config.sessionID`, whose
                // `didSet` emits `TelemetryDeck.Session.started` — the one signal that never passes
                // through `signal` below, so it is the only one this refresh cannot catch later.
                // Priming afterwards left the cache empty at exactly that moment and every session
                // signal reported "Unknown" forever.
                //
                // Ordering is enough to fix it even when this runs off the main queue: this refresh
                // and the SDK's payload assembly both hop through the main queue, and it is FIFO, so
                // enqueueing ours first lands the value before the session signal is built.
                orientation.refresh()
                TelemetryDeck.initialize(config: config)
            },
            terminate: {
                TelemetryDeck.terminate()
            },
            signal: { name, parameters in
                // Refreshed per signal, and only for a signal the client let through, so a dropped
                // signal never touches the scene graph on behalf of analytics.
                orientation.refresh()
                TelemetryDeck.signal(name, parameters: parameters)
            },
            errorOccurred: { id, category, parameters in
                orientation.refresh()
                TelemetryDeck.errorOccurred(
                    id: id,
                    category: ErrorCategory(rawValue: category.rawValue),
                    parameters: parameters
                )
            }
        )
    }()
}

// The enricher is declared without the SDK in `AnalyticsOrientation.swift`; its SDK conformance lives
// here so that file needs no SDK import.
extension OrientationEnricher: SignalEnricher {}
