import CookieClient
import Synchronization

/// The cookie jar of the scenario that is being captured, for every reader in the process, whatever task or run loop
/// pass it reads from.
///
/// A scenario's client used to be installed only in the task-local scope of its capture
/// (``SnapshotMatrixCase/inScenarioDependencies(_:operation:)``). The first render happens inside that scope; a page
/// that a step changes renders again from the main run loop, outside it, and a view that is created again there
/// (`@SharedReader(.didLogin)` resolves `cookieClient` when its key is created) read the host's inert jar and drew
/// signed out: Account's Log Out row became Log In, with its confirmation dialog, the moment the step's tap changed the
/// page (19-30). `DidLoginKey` documents one cookie client per process, so the process holds one, ``forwarding``, and
/// it reads this holder at every call.
///
/// The limit: one scenario per test method. A view that is created again outside the scope reads Sharing's reference
/// table of the process context, where a reference stays cached until XCTest resets the dependency cache at the start
/// of the next test method; a second scenario with another jar in the same method could read the first one's value.
/// A method captures one scenario, whose jar is the same for all its coordinates and attempts, and
/// ``SnapshotMatrixCase`` fails a second, different scenario in one method.
enum ScenarioCookieClient {
    /// The running scenario's jar; the inert jar between scenarios.
    private static let current = Mutex(CookieClient.noop)

    /// The client the test process prepares for its dependency context: it forwards every call to the jar the running
    /// scenario holds, so a view created again outside the capture's task-local scope reads that jar too.
    static let forwarding = CookieClient.forwarding(to: { current.withLock({ $0 }) })

    /// Holds `client` as the scenario's jar while `operation` runs and the inert jar again on every way out of it.
    @MainActor
    static func hold<Result>(_ client: CookieClient, operation: @MainActor () async -> Result) async -> Result {
        current.withLock({ $0 = client })
        defer { current.withLock({ $0 = .noop }) }
        return await operation()
    }
}
