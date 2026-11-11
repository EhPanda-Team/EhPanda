import AppModels
import CookieClient
import Sharing

// The global default parameters attached to every signal (D-11).
//
// The SDK evaluates the `live` closure on *every* signal, so it must never capture a snapshot: a
// setting the user changes mid-session has to be reflected on the very next signal. That per-signal
// freshness is what makes D-11's "segmentable by any setting without a query-time join" claim true —
// each signal already carries the current settings state, so the dashboard needs no join back to a
// separate settings event.
//
// The type is split on purpose. `snapshot` is a pure, total function that owns all the mapping logic
// and carries no shared state, so every spelling can be swept exhaustively in tests without touching
// process-global storage. `live` is a three-line adapter that reads the live shared state inside its
// own body and forwards to `snapshot`.
enum AnalyticsDefaultParameters {
    /// The default parameters for a given settings state, as a flat dot-namespaced dictionary: none
    /// before a level is chosen or at Minimal, the channel alone at Basic, and the channel plus the
    /// five settings at Full.
    ///
    /// Pure and total: no shared state, no I/O. The two `Int`-raw enums render through their stable
    /// analytics spelling rather than their persisted ordinal, so no value is ever a bare integer
    /// that an upstream case insertion could silently re-number. No key collides with the SDK's flat
    /// reserved set — every key carries a dot.
    static func snapshot(
        setting: Setting,
        didLogin: Bool,
        distributionChannel: DistributionChannel = .current
    ) -> [String: String] {
        // The channel rides on every SDK signal at Basic and Full (20-12 §3, owner msg 2842). Minimal's
        // description already says where the app came from, and Basic begins "Everything in Minimal", so
        // no description changes. Minimal itself never starts the SDK, so nothing is added there.
        let channel = ["App.distributionChannel": distributionChannel.rawValue]

        switch setting.analyticsLevel {
        case nil, .minimal:
            return [:]

        case .basic:
            return channel

        // App-authored telemetry rather than SDK enrichment: "your main settings" are promised only
        // by Full's description (D-06f), so below Full the user's host, login state and reading
        // preferences must not ride along on any signal, the SDK's own included.
        case .full:
            return channel.merging([
                "App.host": setting.galleryHost.rawValue,
                "App.loggedIn": String(didLogin),
                "App.readingDirection": setting.readingDirection.analyticsName,
                "App.dualPageMode": String(setting.enableDualPageMode),
                "App.translateTags": String(setting.translateTags)
            ]) { channel, _ in channel }
        }
    }

    /// The default-parameters closure handed to the SDK configuration.
    ///
    /// Both readers are declared *inside* the closure body, never captured at file or type scope, so
    /// each invocation re-reads live state (D-11). `AnalyticsDefaultParametersTests` proves this by
    /// mutating the shared setting between two calls and asserting the second reflects the change.
    static let live: @Sendable () -> [String: String] = {
        @Shared(.setting) var setting
        @SharedReader(.didLogin) var didLogin
        return snapshot(setting: setting, didLogin: didLogin, distributionChannel: .current)
    }
}
