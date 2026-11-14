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

    /// The step outlasts a window that is still moving after one ``BrowsingScenarios/waitForRest(_:within:)``: it
    /// used to fail the attempt there, as it did in 3 of 5 compare invocations of run 42533872440.
    ///
    /// What this proves is the step's loop and the window's motion read, so it needs neither the keyboard nor a
    /// runner's speed. The field takes its focus without the keyboard (``SearchPage/Field``): on the hosted
    /// FeatureTests runs, which put the app beside every other target's processes on a few cores, the step with a
    /// real field ran to its deadline in three runs (42996343921, 43002788032, 43016480727: 41 to 45 s against 30 s,
    /// the keyboard's session restarting in their logs). The real keyboard's focus is the snapshot matrix's, whose
    /// front-page-search scenario goes through this same step.
    ///
    /// The window's motion ends when the test ends it, not when an animation's own clock runs out. With a 12 s
    /// animation the step still read the window as moving at its deadline, 52 s in (`StillMoving`,
    /// `animation:UIView:fade`), on the hosted runner in run 43157759498, while it passed in 13 s in every local run
    /// (iOS 27.0 and 27.2, up to 24 busy processes). What the host's render clock says of a finished animation is
    /// not the step's to depend on, and is not what this proves. The rest wait is shortened to match, so the motion
    /// outlasts it twice over.
    @MainActor
    func testFocusOutlastsAWindowThatMovesLongerThanOneRestWait() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let restWait: Duration = .seconds(1)
        let page = SearchPage(moves: true)
        let hosted = HostedWindowCapture.host(page, in: window, style: .light)
        defer { hosted.dispose() }
        let field = try await page.field()
        XCTAssertNotNil(HostedWindowCapture.motion(in: window))
        let clock = ContinuousClock()
        let start = clock.now
        let stop = Task { @MainActor in
            do {
                try await clock.sleep(for: restWait * 2.5)
                page.stopMoving()
            } catch {
                // Cancelled with the test: the window is disposed of, and there is nothing left to stop.
            }
        }
        defer { stop.cancel() }
        try await BrowsingScenarios.focusSearchField(
            window, deadline: .seconds(30), restWait: restWait
        )
        await stop.value
        XCTAssertGreaterThan(start.duration(to: clock.now), restWait * 2)
        XCTAssertTrue(field.isFirstResponder)
        XCTAssertNil(HostedWindowCapture.motion(in: window))
        field.resignFirstResponder()
    }

    @MainActor
    func testFocusFailsTheStepAtItsDeadline() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let page = SearchPage(moves: false, refusesFocus: true)
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

    /// A focused field's caret, once its blink is stopped and the page frozen as the caret steps freeze it, reads the
    /// same over two blink periods: a caret held by the stopped layer clock alone kept turning on and off.
    @MainActor
    func testAStoppedCaretReadsTheSameOverTwoBlinks() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let page = SearchPage(moves: false, realField: true)
        let hosted = HostedWindowCapture.host(page, in: window, style: .light)
        defer { hosted.dispose() }
        let field = try await page.field()
        XCTAssertTrue(field.becomeFirstResponder())
        defer { field.resignFirstResponder() }
        let clock = ContinuousClock()
        var cursor: (any UITextCursorView)?
        for _ in 0..<50 where cursor == nil {
            try await clock.sleep(for: .milliseconds(100))
            cursor = Self.views(in: window).compactMap({ $0 as? UIView & UITextCursorView }).first
        }
        let caret = try XCTUnwrap(cursor, "The focused field drew no caret")
        BrowsingScenarios.stopCaretBlink(in: window)
        XCTAssertFalse(caret.isBlinking)
        try await BrowsingScenarios.freezeIndicators(window)
        let first = HostedWindowCapture.comparedBytes(HostedWindowCapture.capture(window))
        for _ in 0..<6 {
            try await clock.sleep(for: .milliseconds(400))
            XCTAssertEqual(HostedWindowCapture.comparedBytes(HostedWindowCapture.capture(window)), first)
        }
    }

    /// The keyboard counts as up while the frame UIKit last announced for it covers the bottom of the screen, and
    /// not once it is announced below the screen, as it is when it goes down.
    @MainActor
    func testTheKeyboardIsUpWhileItsAnnouncedFrameCoversTheScreen() throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let screen = window.screen.bounds
        KeyboardWatch.start()
        let up = CGRect(x: 0, y: screen.maxY - 300, width: screen.width, height: 300)
        let down = CGRect(x: 0, y: screen.maxY, width: screen.width, height: 300)
        defer { Self.announceKeyboard(down) }
        Self.announceKeyboard(up)
        XCTAssertTrue(GalleryScenarios.keyboardIsUp(over: window))
        Self.announceKeyboard(down)
        XCTAssertFalse(GalleryScenarios.keyboardIsUp(over: window))
    }

    @MainActor
    private static func announceKeyboard(_ frame: CGRect) {
        NotificationCenter.default.post(
            name: UIResponder.keyboardDidChangeFrameNotification, object: nil,
            userInfo: [UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: frame)]
        )
    }

    @MainActor
    private static func views(in view: UIView) -> [UIView] {
        [view] + view.subviews.flatMap(views(in:))
    }
}

/// A search field, and a layer that moves until ``stopMoving()``.
private struct SearchPage: UIViewRepresentable {
    let moves: Bool
    var refusesFocus = false
    /// A plain field that takes the focus as any field does, with its caret.
    var realField = false
    let box = Box()

    final class Box {
        var field: UISearchTextField?
        var mover: UIView?
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
        let frame = CGRect(x: 20, y: 120, width: 280, height: 36)
        let field = realField ? UISearchTextField(frame: frame) : Field(frame: frame)
        (field as? Field)?.refuses = refusesFocus
        field.text = "keyword"
        view.addSubview(field)
        box.field = field
        if moves {
            let mover = UIView(frame: CGRect(x: 20, y: 200, width: 40, height: 40))
            mover.backgroundColor = .systemOrange
            view.addSubview(mover)
            // Long enough to still be moving whenever the test ends it, and short of the length that reads as
            // repeating for ever (``HostedWindowCapture/repeatsForever(_:)``).
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = 1
            animation.toValue = 0.5
            animation.duration = 600
            animation.beginTime = mover.layer.convertTime(CACurrentMediaTime(), from: nil)
            mover.layer.add(animation, forKey: "fade")
            box.mover = mover
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    /// Ends the motion at once: the animation is taken off its layer.
    @MainActor
    func stopMoving() {
        box.mover?.layer.removeAnimation(forKey: "fade")
    }

    @MainActor
    func field() async throws -> UISearchTextField {
        for _ in 0..<50 {
            if let field = box.field, field.window != nil { return field }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw AccessibilityActionDriver.Failure.notFound("search field")
    }
}
