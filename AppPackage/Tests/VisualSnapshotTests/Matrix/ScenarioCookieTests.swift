import AppFeature
import CookieClient
import Observation
import Sharing
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

/// The scenario's cookie jar for a page that is created again outside the capture's task-local scope (19-30).
///
/// A step's tap changes a page, and the page renders again from the main run loop, where the scenario's task-local
/// dependencies are not set. A view that is created again by that render and holds `@SharedReader(.didLogin)` used to
/// read the host's inert jar and draw signed out, whatever the scenario's jar was (Account's Log Out row was replaced
/// by Log In the moment the tap changed the page).
///
/// Sharing's reference table is a dependency, cached per context: a page renders in the scope's `.preview` table at
/// first and, once a step changed it, in the process context's table, where a reference stays cached until XCTest
/// resets the dependency cache at the start of the next test method. A jar is therefore read for one scenario per test
/// method (``SnapshotMatrixCase`` fails a second, different one). The tests below do not rely on running after one
/// another: the signed-in and the signed-out method each start from a reset cache, so either order is the guard that
/// the next method reads its own jar.
final class ScenarioCookieTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded(cookieClient: ScenarioCookieClient.forwarding)
    }

    /// A signed-in scenario's page that is created again after a step's state change still reads signed in.
    @MainActor
    func testAViewCreatedAgainOutsideTheScopeStaysSignedInInASignedInScenario() async throws {
        let reads = try await Self.readsAfterAStateChange(signedIn: true)
        XCTAssertEqual(reads, [Read(tick: 0, didLogin: true), Read(tick: 1, didLogin: true)])
    }

    /// A signed-out scenario's page stays signed out through the same state change.
    @MainActor
    func testAViewCreatedAgainOutsideTheScopeStaysSignedOutInASignedOutScenario() async throws {
        let reads = try await Self.readsAfterAStateChange(signedIn: false)
        XCTAssertEqual(reads, [Read(tick: 0, didLogin: false), Read(tick: 1, didLogin: false)])
    }

    /// A capture that fails leaves the inert jar behind as a capture that records does: the holder is released
    /// whichever way the scenario ends.
    @MainActor
    func testTheHolderIsInertAfterACaptureThatFails() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        struct Refused: Error {}
        let factory = ScenarioFactory(make: { throw Refused() })
        let outcome = await SnapshotMatrixCase.inScenarioDependencies(factory) {
            await HostedWindowCapture.captureAndCompare(
                make: { try factory.make() }, window: window, style: .light, reference: nil, mode: .candidate,
                height: CaptureHeight(
                    points: window.bounds.height, freezeViewport: { _ in }, keyboardTop: { _ in nil }
                )
            )
        }
        XCTAssertNotEqual(outcome.status, .recorded)
        XCTAssertFalse(ScenarioCookieClient.forwarding.didLogin)
    }

    /// A test method captures one scenario: a second, different one is refused, the same one again is not (its
    /// coordinates and a shard's re-run).
    func testAMethodAdmitsOneScenarioOnly() {
        var admitted = OneScenarioPerMethod()
        XCTAssertTrue(admitted.admits("first"))
        XCTAssertTrue(admitted.admits("first"))
        XCTAssertFalse(admitted.admits("second"))
        XCTAssertTrue(admitted.admits("first"))
    }

    /// The holder is the scenario's jar while its operation runs and the inert jar when it ends, whichever jar the
    /// scenario names.
    @MainActor
    func testTheHolderIsTheScenarioJarWhileItRunsAndInertAfter() async {
        let signedIn = ScenarioFactory(make: { AnyView(EmptyView()) })
        let during = await SnapshotMatrixCase.inScenarioDependencies(signedIn) {
            ScenarioCookieClient.forwarding.didLogin
        }
        XCTAssertTrue(during)
        XCTAssertFalse(ScenarioCookieClient.forwarding.didLogin)
        let named = ScenarioFactory(
            cookies: .testing(memberID: "member", passHash: "hash"), make: { AnyView(EmptyView()) }
        )
        let duringNamed = await SnapshotMatrixCase.inScenarioDependencies(named) {
            ScenarioCookieClient.forwarding.didLogin
        }
        XCTAssertTrue(duringNamed)
        XCTAssertFalse(ScenarioCookieClient.forwarding.didLogin)
    }

    // MARK: Helpers

    private struct Read: Equatable {
        let tick: Int
        let didLogin: Bool
    }

    @MainActor
    private final class Reads {
        var values: [Read] = []
    }

    @MainActor @Observable
    final class Model {
        var tick = 0
    }

    /// A child that is created again by every state change of its parent, as Account's sign-in section is.
    private struct Probe: View {
        @SharedReader(.didLogin) private var didLogin: Bool
        let tick: Int
        let reads: Reads

        var body: some View {
            reads.values.append(Read(tick: tick, didLogin: didLogin))
            return Text(verbatim: "\(tick) \(didLogin)")
        }
    }

    private struct Host: View {
        let model: Model
        let reads: Reads

        var body: some View {
            Probe(tick: model.tick, reads: reads)
        }
    }

    /// What the probe read when the page was built and after a step changed its state and the window came to rest.
    @MainActor
    private static func readsAfterAStateChange(signedIn: Bool) async throws -> [Read] {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let model = Model()
        let reads = Reads()
        let factory = ScenarioFactory(signedIn: signedIn, make: { AnyView(Host(model: model, reads: reads)) })
        let outcome = await SnapshotMatrixCase.inScenarioDependencies(factory) {
            await HostedWindowCapture.captureAndCompare(
                make: { try factory.make() }, window: window, style: .light, reference: nil, mode: .candidate,
                interact: { window in
                    model.tick = 1
                    // The page renders from the main run loop, outside the scope, once this step suspends; a settle
                    // would render it in place, inside the scope, so it only waits for the render to have happened.
                    var budget = StepBudget(.seconds(10))
                    while reads.values.last?.tick != 1, !budget.isSpent {
                        budget.look()
                        try await ContinuousClock().sleep(for: .milliseconds(10))
                    }
                    _ = await HostedWindowCapture.settle(window)
                },
                height: CaptureHeight(
                    points: window.bounds.height, freezeViewport: { _ in }, keyboardTop: { _ in nil }
                )
            )
        }
        XCTAssertEqual(outcome.status, .recorded, outcome.reason ?? "")
        return reads.values.reduce(into: []) { distinct, read in
            if distinct.last != read { distinct.append(read) }
        }
    }
}
