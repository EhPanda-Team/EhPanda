@testable import AppFeature
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

/// The browsing steps: the first-launch read floor, the stopped caret and the keyboard's reading.
final class BrowsingStepTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    @MainActor
    func testEveryScenarioSettlesOnAtLeastSixReads() {
        XCTAssertGreaterThanOrEqual(HostedWindowCapture.minimumReads, 6)
        XCTAssertEqual(BrowsingScenarios.firstLaunchMinimumReads, HostedWindowCapture.minimumReads)
        XCTAssertFalse(ScenarioCatalog.states.isEmpty)
        for state in ScenarioCatalog.states {
            XCTAssertGreaterThanOrEqual(state.factory.minimumReads, 6, state.id)
        }
    }

    @MainActor
    func testRestingAtTopKeepsTheReadFloor() {
        let factory = ScenarioFactory(make: { AnyView(EmptyView()) }, minimumReads: 7).restingAtTop()
        XCTAssertEqual(factory.minimumReads, 7)
    }

    /// A focused field's caret, once its blink is stopped and the page frozen as the caret steps freeze it, reads the
    /// same over two blink periods: a caret held by the stopped layer clock alone kept turning on and off.
    @MainActor
    func testAStoppedCaretReadsTheSameOverTwoBlinks() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let page = SearchPage()
        let hosted = HostedWindowCapture.host(page, in: window, style: .light)
        defer { hosted.dispose() }
        let field = try await page.field()
        XCTAssertTrue(field.becomeFirstResponder())
        defer { field.resignFirstResponder() }
        let clock = ContinuousClock()
        var cursor: (any UITextCursorView)?
        for _ in 0..<50 where cursor == nil {
            try await clock.sleep(for: .milliseconds(100))
            cursor = Self.views(in: window).compactMap({ $0 as? any UIView & UITextCursorView }).first
        }
        let caret = try XCTUnwrap(cursor, "The focused field drew no caret")
        BrowsingScenarios.stopCaretBlink(in: window)
        XCTAssertFalse(caret.isBlinking)
        try await BrowsingScenarios.freezeIndicators(window)
        let first = try XCTUnwrap(HostedWindowCapture.comparedBytes(HostedWindowCapture.capture(window)))
        for read in 1...6 {
            try await clock.sleep(for: .milliseconds(400))
            let bytes = try XCTUnwrap(HostedWindowCapture.comparedBytes(HostedWindowCapture.capture(window)))
            guard bytes != first else { continue }
            // Where the read differs, not the reads themselves: two pictures in a message are 15 MB of numbers.
            let region = HostedWindowCapture.changedRegion(first, bytes, width: Int(window.bounds.width))
            XCTFail("Read \(read) differs from the first in \(region ?? "its size")")
        }
    }

    /// The keyboard counts as up while the frame UIKit last announced for it covers the bottom of the screen, and
    /// not once it is announced below the screen, as it is when it goes down.
    @MainActor
    func testTheKeyboardIsUpWhileItsAnnouncedFrameCoversTheScreen() throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let screen = window.screen.bounds
        KeyboardWatch.start()
        let raised = CGRect(x: 0, y: screen.maxY - 300, width: screen.width, height: 300)
        let lowered = CGRect(x: 0, y: screen.maxY, width: screen.width, height: 300)
        defer { Self.announceKeyboard(lowered) }
        Self.announceKeyboard(raised)
        XCTAssertTrue(GalleryScenarios.keyboardIsUp(over: window))
        Self.announceKeyboard(lowered)
        XCTAssertFalse(GalleryScenarios.keyboardIsUp(over: window))
    }

    /// A keyboard step's failure says why the keyboard was not held up: the field lost the focus, no frame was
    /// announced since the step began, the last one is below the screen, or the keyboard is up but was not yet held
    /// (run 43575259346 said only `no-keyboard`).
    @MainActor
    func testAKeyboardStepsFailureSaysWhatTheKeyboardLastDid() throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let screen = window.screen.bounds
        KeyboardWatch.start()
        let raised = CGRect(x: 0, y: screen.maxY - 300, width: screen.width, height: 300)
        let lowered = CGRect(x: 0, y: screen.maxY, width: screen.width, height: 300)
        defer { Self.announceKeyboard(lowered) }
        let start = KeyboardWatch.announcements
        XCTAssertEqual(
            GalleryScenarios.keyboardState(over: window, focused: false, since: start), "field-unfocused announced=0"
        )
        XCTAssertEqual(
            GalleryScenarios.keyboardState(over: window, focused: true, since: start), "never-announced announced=0"
        )
        Self.announceKeyboard(raised)
        XCTAssertEqual(
            GalleryScenarios.keyboardState(over: window, focused: true, since: start), "announced-up announced=1"
        )
        Self.announceKeyboard(lowered)
        XCTAssertEqual(
            GalleryScenarios.keyboardState(over: window, focused: true, since: start), "announced-hidden announced=2"
        )
    }

    /// A step's failure says how long its attempt waited, how long the main run loop turned meanwhile, how many times
    /// it looked, the longest stall it waited through and how long the process had run.
    func testAStepsFailureSaysHowLongItWaited() throws {
        let failure = BrowsingScenarios.StepFailure(
            reason: "no-keyboard:never-announced", waited: .milliseconds(50_260), turned: .milliseconds(30_040),
            polls: 24, stall: " stall=40.1s/frozen"
        )
        XCTAssertTrue(
            failure.reason.hasPrefix(
                "no-keyboard:never-announced waited=50.3s turned=30.0s polls=24 stall=40.1s/frozen process="
            ),
            failure.reason
        )
        let process = try XCTUnwrap(BrowsingScenarios.processSeconds)
        XCTAssertGreaterThan(process, 0)
        XCTAssertLessThan(process, 24 * 3600)
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

/// A plain search field, which takes the focus as any field does, with its caret. It has no clear button: the caret is
/// what its case reads. In the three runs that failed the case (hosted 43681051816 and 43689174320, and one local) the
/// reads differed in the button's 20 points alone, drawn after the first read, and the caret was the same in all of
/// them. Each of those runs took 95 s or more where the case takes 4; why the button is late then is not known.
private struct SearchPage: UIViewRepresentable {
    let box = Box()

    final class Box {
        var field: UISearchTextField?
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .systemBackground
        let field = UISearchTextField(frame: CGRect(x: 20, y: 120, width: 280, height: 36))
        field.clearButtonMode = .never
        field.text = "keyword"
        view.addSubview(field)
        box.field = field
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
