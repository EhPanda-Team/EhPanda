import Foundation
import XCTest

/// The opt-in that every `LiveCheckTests` test passes first (19-03; 19-CONTEXT D-21). This target does not link
/// the test network guard, so without `EHPANDA_LIVE_CHECK=1` each test skips before it can build a request.
enum LiveCheckGate {
    private static var environment: [String: String] { ProcessInfo.processInfo.environment }

    static func requireOptIn() throws {
        guard environment["EHPANDA_LIVE_CHECK"] == "1" else {
            throw XCTSkip("The live check runs only with EHPANDA_LIVE_CHECK=1.")
        }
    }

    /// The directory the check writes its results to (`EHPANDA_LIVE_CHECK_OUTPUT`).
    static var outputDirectory: URL? {
        environment["EHPANDA_LIVE_CHECK_OUTPUT"].flatMap({ $0.isEmpty ? nil : URL(filePath: $0) })
    }

    /// `hosted` on GitHub's runner, `local` on the development machine (`EHPANDA_LIVE_CHECK_MODE`).
    static var mode: String {
        environment["EHPANDA_LIVE_CHECK_MODE"] == "hosted" ? "hosted" : "local"
    }
}
