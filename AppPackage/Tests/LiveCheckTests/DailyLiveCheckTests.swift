import Foundation
import XCTest

/// The daily live-parsing check (19-14; 19-CONTEXT D-20 to D-24). It runs only with `EHPANDA_LIVE_CHECK=1`, reads
/// every guest page in order and writes `results.json` to `EHPANDA_LIVE_CHECK_OUTPUT`. It passes whenever the
/// results were written: the reporter judges them (19-15), so no assertion here carries page-derived text.
final class DailyLiveCheckTests: XCTestCase {
    func testLivePages() async throws {
        try LiveCheckGate.requireOptIn()
        let output = try XCTUnwrap(LiveCheckGate.outputDirectory, "EHPANDA_LIVE_CHECK_OUTPUT is not set.")
        let mode: LiveCheckMode = LiveCheckGate.mode == "hosted" ? .hosted : .local
        let results = await LiveCheckRunner().run(mode: mode)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try results.encoded().write(to: output.appending(path: "results.json"))
    }
}
