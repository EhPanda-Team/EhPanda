@testable import AppFeature
import Darwin
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

/// A user step's wait counts the time the main run loop turned, not the wall clock (``StepBudget``), and the watch
/// that counts it records, and samples, a main thread that stops (``MainThreadWatch``). Run 43621303643's steps
/// looked once or twice in waits of 15 to 172 s and failed at their first look after the stop.
final class StepBudgetTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    /// A stretch in which the main run loop does not turn counts for one second of a step's allowance, however long
    /// it lasts; the rest of the allowance is still waited for afterwards.
    ///
    /// Every bound here holds however slowly the host serves the case, short of the budget's own wall bound. The
    /// stop is three seconds on any clock, and what the run loop turned is compared with the wall clock of the same
    /// step, never with a fixed span: hosted run 43681051816 failed an earlier form of this case, which allowed two
    /// 200 ms sleeps around the stop 0.8 s between them where the runner took 1.4 s.
    @MainActor
    func testAStretchWithoutATurnCountsForOneSecond() async throws {
        var budget = StepBudget(.seconds(2))
        usleep(3_000_000)
        // Longer than the allowance on the wall clock, and nothing of it counted: the stretch has not ended yet.
        XCTAssertGreaterThanOrEqual(budget.waited, .seconds(3))
        XCTAssertFalse(budget.isSpent)
        while !budget.isSpent {
            budget.look()
            try await Task.sleep(for: .milliseconds(100))
        }
        // The stop gave the allowance one second at most, so at least one more second of turning followed it, and
        // two of the stop's three seconds are on the wall clock alone.
        XCTAssertGreaterThanOrEqual(budget.turned, .seconds(2))
        XCTAssertGreaterThanOrEqual(budget.waited, .seconds(4))
        XCTAssertGreaterThanOrEqual(budget.waited - budget.turned, .seconds(2))
        XCTAssertGreaterThan(budget.polls, 0)
    }

    /// A stop that ends as a step begins belongs to what came before the step: none of it counts toward the step's
    /// allowance, so the run loop never turns for longer than the step has waited. Hosted run 43723509533 failed a
    /// dialog step with `waited=9.2s turned=10.1s` behind a 5.2 s stop.
    @MainActor
    func testAStopBeforeAStepBeganIsNotCounted() async throws {
        MainThreadWatch.start()
        try await Task.sleep(for: .milliseconds(200))
        usleep(600_000)
        let budget = StepBudget(.seconds(2))
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertLessThanOrEqual(budget.turned, budget.waited)
    }

    /// The popover step looks for its whole allowance after the main thread stopped for longer than it: it used to
    /// fail at its first look after the stop (`opening waited=50.3s polls=2`). Its reason says how long it waited, how
    /// long the run loop turned, how often it looked and the stall it waited through.
    @MainActor
    func testTheDialogStepLooksForItsWholeAllowanceAfterTheMainThreadStops() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let hosted = HostedWindowCapture.host(Color.clear, in: window, style: .light)
        defer { hosted.dispose() }
        let stop = Task { @MainActor in
            try await Task.sleep(for: .milliseconds(300))
            usleep(12_000_000)
        }
        defer { stop.cancel() }
        do {
            try await RevealStep.awaitDialogPlatter()(window)
            XCTFail("The step passed with no dialog presented")
        } catch let failure as BrowsingScenarios.StepFailure {
            let reason = failure.reason
            let pattern = #"^not-found:popover-platter:not-presented chain=UIHostingController "#
                + #"waited=(\d+)\.\ds turned=10\.\ds polls=(\d+) stall=1[12]\.\ds/blocked process=\d+s$"#
            let match = try XCTUnwrap(reason.firstMatch(of: try Regex(pattern)), reason)
            let waited = try XCTUnwrap(match.output[1].substring.flatMap({ Int($0) }))
            let polls = try XCTUnwrap(match.output[2].substring.flatMap({ Int($0) }))
            XCTAssertGreaterThanOrEqual(waited, 19, reason)
            XCTAssertGreaterThan(polls, 50, reason)
        }
    }

    /// A main thread held while the process runs is a `blocked` stall, and the watchdog's sample of it shows where
    /// it was held.
    @MainActor
    func testTheWatchSamplesAMainThreadThatIsHeld() async throws {
        MainThreadWatch.start()
        try await Task.sleep(for: .milliseconds(200))
        let mark = MainThreadWatch.now()
        usleep(3_500_000)
        try await Task.sleep(for: .milliseconds(300))
        let stall = try XCTUnwrap(MainThreadWatch.longestStall(since: mark))
        XCTAssertGreaterThanOrEqual(stall.seconds, 3.4)
        XCTAssertEqual(stall.kind, "blocked")
        let frames = MainThreadWatch.lastSamples.flatMap(\.frames)
        XCTAssertTrue(frames.contains(where: { $0.contains("sleep") || $0.contains("semwait") }), "\(frames)")
        XCTAssertTrue(frames.contains(where: { $0.contains("VisualSnapshotTests") }), "\(frames)")
    }

    /// A stretch the watchdog thread was itself late through is one in which the process was not run: `frozen`.
    func testAStallTheWatchdogWasLateThroughIsFrozen() {
        let second: UInt64 = 1_000_000_000
        XCTAssertEqual(MainThreadWatch.Stall(start: 0, end: 10 * second, watchdogLate: 9 * second).kind, "frozen")
        XCTAssertEqual(MainThreadWatch.Stall(start: 0, end: 10 * second, watchdogLate: second).kind, "blocked")
    }
}
