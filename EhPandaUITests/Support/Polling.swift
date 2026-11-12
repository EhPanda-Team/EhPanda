import Foundation

/// Waits for a condition that XCUITest cannot express as one query, measured in samples as well as seconds.
///
/// A sample is one evaluation of the condition, which is several XCUITest queries, and each query resolves a fresh
/// snapshot of the app's hierarchy. On a hosted runner one snapshot takes 1 to 9 seconds, and a stalled one 30 (run 4:
/// a Library title and a render probe waited 15 seconds and took one sample). A plain timeout then ends before the
/// screen was looked at twice, so the wait ends only after `minimumSamples` evaluations as well as `timeout`. A
/// condition that holds ends the wait at once: nothing here makes a passing run slower or a failing one pass.
@MainActor
enum Polling {
    /// How long the hosted runner may take to settle a screen, in seconds (cf. `XCUIElement.hittableTimeout`).
    static let settleTimeout: TimeInterval = 60

    /// Evaluates `condition` until it returns true, or `timeout` seconds and `minimumSamples` evaluations have passed.
    /// Returns whether it held.
    static func wait(
        timeout: TimeInterval = settleTimeout, minimumSamples: Int = 3, interval: TimeInterval = 0.5,
        _ condition: () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        var samples = 0
        repeat {
            if condition() { return true }
            samples += 1
            Thread.sleep(forTimeInterval: interval)
        } while samples < minimumSamples || Date() < deadline
        return false
    }
}
