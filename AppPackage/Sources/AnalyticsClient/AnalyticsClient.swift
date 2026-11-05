public import AppModels
public import ComposableArchitecture
import Foundation
import InstallSourceClient
import Sharing
import Synchronization

// Every payload that leaves the app is minted through this module's closed `AnalyticsSignal`
// vocabulary and handed to the SDK through `TelemetrySDK`, the one file importing it (D-12); plan
// 14-17's lint rule (D-18) makes that boundary structural. Per D-10 the SDK's built-in anonymized
// identifier is used as-is: no default user is assigned, no custom user identifier is passed, and the
// identifier-update API is never called.
//
// What leaves the app is decided by the analytics level the user chose (D-06a, D-06b, D-06f, DD-09a):
//
// - No level yet: nothing. `apply(nil)` does nothing and every signal is dropped (D-04).
// - Minimal: only the one install signal, sent by `InstallSignalSender` with the install source as its
//   one parameter. The TelemetryDeck SDK is never initialised under Minimal: every SDK signal carries
//   the SDK's device, OS, locale, region, time-zone, screen and app-version payload, so starting it
//   would make Minimal's "Sends only a signal that EhPanda is installed" false. This reverses Phase
//   14's premise that the SDK stays alive when analytics are off "so installs are still counted";
//   the own sender counts installs now. Do not restore that behaviour (Pitfall P-4).
// - Basic: the install signal, the SDK (its session and acquisition signals), and the screen, feature
//   and error signals, with no default parameters.
// - Full: Basic plus reading and download activity and the five `App.*` default parameters.

public struct AnalyticsClient: Sendable {
    // The closure properties are `var`, not `let` — a deliberate departure from the `HapticsClient`
    // template that uses `let`. The repository's signal-capture idiom builds a spy by taking `.noop`
    // and mutating one field, and this client is overridden at roughly 130 existing test sites; `var`
    // lets a test replace `send` while leaving `apply` inert.

    /// Makes the analytics client match `level`. Idempotent; call it whenever the stored level is
    /// known or changes. `nil` (not chosen yet) does nothing. Every chosen level makes sure the one
    /// install signal is sent. Minimal stops the SDK if it is running and never starts it; Basic and
    /// Full start it if it is not running.
    public var apply: @Sendable (AnalyticsLevel?) -> Void
    /// Sends a signal if the stored level covers it and the SDK is running; otherwise drops it.
    public var send: @Sendable (AnalyticsSignal) -> Void
}

extension AnalyticsClient {
    /// The live client. A nil ``AppInfo/telemetryDeckAppID`` resolves this entire value to ``noop``
    /// and neither the SDK nor the install sender is ever referenced — one check that covers
    /// contributor clones, forks, CI, the test host and previews at once (D-13).
    ///
    /// The gate lives here rather than at each call site on purpose: because a nil app ID makes the
    /// whole client a no-op, a signal can never reach an uninitialized SDK — the one behavior that
    /// would trip the SDK's assertion in debug builds. Do not "simplify" this into a call-site check.
    public static let live: Self = {
        guard let appID = AppInfo.telemetryDeckAppID else { return .noop }
        let salt = AppInfo.telemetryDeckSalt

        let sender = InstallSignalSender(
            appID: appID,
            salt: salt,
            transport: InstallSignalSender.liveTransport,
            now: { Date() },
            uuid: { UUID() },
            sleep: { try await Task.sleep(for: $0) },
            // Declared inside the closure, never captured here: this value is a `static let`, so a
            // dependency resolved at its scope would ignore every later override.
            installSource: {
                @Dependency(\.installSourceClient) var installSourceClient
                return await installSourceClient.current()
            }
        )
        return live(appID: appID, salt: salt, sdk: .live, installSignal: .live(sender))
    }()

    /// The level gate over an SDK and an install-signal trigger; `live` passes the real ones, tests pass
    /// recorders.
    static func live(
        appID: String,
        salt: String?,
        sdk: TelemetrySDK,
        installSignal: InstallSignalTrigger
    ) -> Self {
        // Whether the SDK is initialised in this process. Every SDK call is made while holding it, so
        // a signal can never reach the SDK before `initialize` or after `terminate` (threat T-14-11).
        let isRunning = Mutex(false)

        return Self(
            apply: { level in
                guard let level else { return }
                installSignal.ensureSent()

                switch level {
                case .minimal:
                    isRunning.withLock { isRunning in
                        guard isRunning else { return }
                        // Signals the SDK already handed to the network may still complete; they were
                        // emitted under the level in force at the time (Pitfall P-5).
                        sdk.terminate()
                        isRunning = false
                    }

                case .basic, .full:
                    isRunning.withLock { isRunning in
                        guard !isRunning else { return }
                        sdk.initialize(TelemetrySDK.Configuration(
                            appID: appID,
                            salt: salt,
                            defaultParameters: AnalyticsDefaultParameters.live
                        ))
                        isRunning = true
                    }
                }
            },
            send: { signal in
                // Read live inside the closure, never captured, so a level change takes effect on the
                // very next signal rather than at the next launch.
                @Shared(.setting) var setting
                guard signal.isSent(at: setting.analyticsLevel) else { return }

                isRunning.withLock { isRunning in
                    guard isRunning else { return }
                    switch signal.rendered {
                    case let .signal(name, parameters):
                        sdk.signal(name, parameters)

                    case let .error(id, category, parameters):
                        sdk.errorOccurred(id, category, parameters)
                    }
                }
            }
        )
    }
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
    public static let noop = Self(apply: { _ in }, send: { _ in })

    // Both closures return `Void`, so this uses the default-placeholder `unimplemented` form rather
    // than the `HapticsClient` template's `placeholder:` form. The template's form fits a client with
    // value-returning closures; here it would evaluate a `fatalError` placeholder and crash the test
    // runner the moment an un-hardened test actually invokes `send`, which is the very case Task 3
    // asserts on. The default `()` placeholder reports a catchable issue and returns cleanly.
    public static let unimplemented = Self(
        apply: IssueReporting.unimplemented("AnalyticsClient.apply"),
        send: IssueReporting.unimplemented("AnalyticsClient.send")
    )
}
