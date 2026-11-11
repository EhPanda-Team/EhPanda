@testable import AppFeature
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

/// The first-launch read floor and the Front Page search focus step (fixed after run 42533872440).
final class BrowsingStepTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    func testFirstLaunchPicturesSettleOnMoreReadsThanOtherPages() throws {
        let ids = [
            "agewall-unticked", "agewall-ticked", "analytics-choice-none", "analytics-choice-minimal",
            "analytics-choice-basic", "analytics-choice-full"
        ]
        XCTAssertGreaterThan(ScenarioCatalog.firstLaunchMinimumReads, HostedWindowCapture.minimumReads)
        for id in ids {
            let factory = try XCTUnwrap(ScenarioCatalog.factories[id], id)
            XCTAssertEqual(factory.minimumReads, ScenarioCatalog.firstLaunchMinimumReads, id)
        }
        let others = ScenarioCatalog.factories.filter({ !ids.contains($0.key) })
        XCTAssertFalse(others.isEmpty)
        for (id, factory) in others {
            XCTAssertEqual(factory.minimumReads, HostedWindowCapture.minimumReads, id)
        }
    }

    @MainActor
    func testRestingAtTopKeepsTheReadFloor() {
        let factory = ScenarioFactory(make: { AnyView(EmptyView()) }, minimumReads: 7).restingAtTop()
        XCTAssertEqual(factory.minimumReads, 7)
    }

    /// The step outlasts a window that is still moving after one ``BrowsingScenarios/waitForRest(_:)`` (10 s): it
    /// used to fail the attempt there, as it did in 3 of 5 compare invocations of run 42533872440.
    ///
    /// What this proves is the step's loop and the window's motion read, so it needs neither the keyboard nor a
    /// runner's speed. The field takes its focus without the keyboard (``SearchPage/Field``): on the hosted
    /// FeatureTests runs, which put the app beside every other target's processes on a few cores, the step with a
    /// real field ran to its deadline in three runs (42996343921, 43002788032, 43016480727: 41 to 45 s against 30 s,
    /// the keyboard's session restarting in their logs), and locally it passes in 13 s. The real keyboard's focus is
    /// the snapshot matrix's, whose front-page-search scenario goes through this same step. The deadline is the
    /// step's own budget on top of the time the window moves, not a total that the motion eats into: 30 s had to
    /// cover the 12 s of motion and left 18 s for the focus.
    @MainActor
    func testFocusOutlastsAWindowThatMovesLongerThanOneRestWait() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let motion: CFTimeInterval = 12
        let page = SearchPage(motion: motion)
        let hosted = HostedWindowCapture.host(page, in: window, style: .light)
        defer { hosted.dispose() }
        let field = try await page.field()
        try await BrowsingScenarios.focusSearchField(
            window, deadline: .seconds(motion) + BrowsingScenarios.focusDeadline
        )
        XCTAssertTrue(field.isFirstResponder)
        XCTAssertNil(HostedWindowCapture.motion(in: window))
        field.resignFirstResponder()
    }

    @MainActor
    func testFocusFailsTheStepAtItsDeadline() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let page = SearchPage(motion: 0, refusesFocus: true)
        let hosted = HostedWindowCapture.host(page, in: window, style: .light)
        defer { hosted.dispose() }
        _ = try await page.field()
        let clock = ContinuousClock()
        let start = clock.now
        do {
            try await BrowsingScenarios.focusSearchField(window, deadline: .seconds(3))
            XCTFail("A field that never takes the focus was focused")
        } catch let failure as BrowsingScenarios.StepFailure {
            XCTAssertEqual(failure.reason, "search-focus-not-held")
            XCTAssertLessThan(start.duration(to: clock.now), .seconds(15))
        }
    }

    @MainActor
    func testTheFocusDeadlineIsLongerThanTheOneRun42533872440Overran() {
        XCTAssertGreaterThanOrEqual(BrowsingScenarios.focusDeadline, .seconds(30))
    }
}

/// A search field, and a layer that moves for `motion` seconds once the page is shown.
private struct SearchPage: UIViewRepresentable {
    let motion: CFTimeInterval
    var refusesFocus = false
    let box = Box()

    final class Box {
        var field: UISearchTextField?
    }

    /// A search field that holds its focus itself: it never reaches the keyboard, so how fast the host serves the
    /// keyboard's session cannot decide the step's outcome. One that `refuses` never takes the focus.
    final class Field: UISearchTextField {
        var refuses = false
        private var holdsFocus = false
        override var canBecomeFirstResponder: Bool { !refuses && super.canBecomeFirstResponder }
        override var isFirstResponder: Bool { holdsFocus }

        override func becomeFirstResponder() -> Bool {
            holdsFocus = canBecomeFirstResponder
            return holdsFocus
        }

        override func resignFirstResponder() -> Bool {
            holdsFocus = false
            return true
        }
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .systemBackground
        let field = Field(frame: CGRect(x: 20, y: 120, width: 280, height: 36))
        field.refuses = refusesFocus
        field.text = "keyword"
        view.addSubview(field)
        box.field = field
        if motion > 0 {
            let mover = UIView(frame: CGRect(x: 20, y: 200, width: 40, height: 40))
            mover.backgroundColor = .systemOrange
            view.addSubview(mover)
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 1
            animation.toValue = 0.5
            animation.duration = motion
            animation.beginTime = CACurrentMediaTime()
            mover.layer.add(animation, forKey: "fade")
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    @MainActor
    func field() async throws -> UISearchTextField {
        for _ in 0..<50 {
            if let field = box.field, field.window != nil { return field }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw AccessibilityActionDriver.Failure.notFound("search field")
    }
}
