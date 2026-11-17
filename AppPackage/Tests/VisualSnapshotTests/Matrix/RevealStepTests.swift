@testable import AppFeature
import SwiftUI
import UIKit
import VisualSnapshotSupport
import XCTest

/// The popover platter a presented dialog's step waits for, and the whole label a step can name (fixed after run
/// 43451019962).
final class RevealStepTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UITestAutomation.prepareIfNeeded()
    }

    /// An action sheet presented as a popover from a button, as Account's Log Out presents its confirmation, from a
    /// controller the root holds: the step returns once the popover has its platter.
    @MainActor
    func testTheStepWaitsForThePresentedPopoversPlatter() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let page = ButtonPage()
        let hosted = HostedWindowCapture.host(page, in: window, style: .light)
        defer { hosted.dispose() }
        XCTAssertFalse(RevealStep.popoverPlatterReady(in: window))
        XCTAssertEqual(RevealStep.platterState(in: window), .notPresented)
        page.presentSheet()
        try await RevealStep.awaitDialogPlatter()(window)
        XCTAssertTrue(RevealStep.popoverPlatterReady(in: window))
        XCTAssertNotNil(hosted.controller.presentedViewController?.popoverPresentationController)
        XCTAssertTrue(Self.contains("_UIPopoverGlassBackground", in: window))
        await hosted.disposeAfterDismissal()
    }

    /// A page with no dialog over it never gets there: the step fails, and the capture tries again. Its reason
    /// names the check the platter failed, what the window presented and how long the step waited (run 43575259346
    /// named none of them).
    ///
    /// The step waits for its whole allowance of time the run loop turned, and the wall clock is never behind that
    /// time: those two are what the case asks of the numbers. It used to read them off a pattern that allowed 10.0
    /// to 19.9 s of wall clock, 10.0 to 10.9 s of turning and no stall. A stop lengthens the wall-clock wait by
    /// design, so those bounds were not the step's. What failed the pattern on the hosted runner was the step
    /// ending early (`waited=9.8s turned=10.0s`, and `waited=9.2s turned=10.1s` behind a 5.2 s stall), which the
    /// case now names.
    @MainActor
    func testTheStepFailsWithoutADialog() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let hosted = HostedWindowCapture.host(ButtonPage(), in: window, style: .light)
        defer { hosted.dispose() }
        do {
            try await RevealStep.awaitDialogPlatter()(window)
            XCTFail("The step passed with no dialog presented")
        } catch let failure as BrowsingScenarios.StepFailure {
            // The failure the capture names `interaction:not-found:popover-platter:…` and retries.
            let reason = failure.reason
            let pattern = #"^not-found:popover-platter:not-presented chain=UIHostingController "#
                + #"waited=(\d+\.\d)s turned=(\d+\.\d)s polls=\d+( stall=\d+\.\ds/(blocked|frozen))? process=\d+s$"#
            let match = try XCTUnwrap(reason.firstMatch(of: try Regex(pattern)), reason)
            let waited = try XCTUnwrap(match.output[1].substring.flatMap({ Double($0) }))
            let turned = try XCTUnwrap(match.output[2].substring.flatMap({ Double($0) }))
            XCTAssertGreaterThanOrEqual(turned, MainThreadWatch.seconds(RevealStep.platterDeadline), reason)
            XCTAssertGreaterThanOrEqual(waited, turned, reason)
        }
    }

    /// Rate Gallery in Chinese (评分) is part of the average rating's label (平均评分) above it: a whole label names
    /// only the element whose label it is.
    @MainActor
    func testAWholeLabelNamesOnlyItsOwnElement() {
        let average = UIAccessibilityElement(accessibilityContainer: self)
        average.isAccessibilityElement = true
        average.accessibilityLabel = "平均评分"
        let button = UIAccessibilityElement(accessibilityContainer: self)
        button.isAccessibilityElement = true
        button.accessibilityLabel = "评分"
        XCTAssertTrue(RevealStep.Target.label("评分").matches(average))
        XCTAssertFalse(RevealStep.Target.wholeLabel("评分").matches(average))
        XCTAssertTrue(RevealStep.Target.wholeLabel("评分").matches(button))
    }

    @MainActor
    private static func contains(_ name: String, in view: UIView) -> Bool {
        String(describing: type(of: view)) == name || view.subviews.contains(where: { contains(name, in: $0) })
    }
}

/// A page with one button that presents an action sheet from itself.
private struct ButtonPage: UIViewControllerRepresentable {
    let box = Box()

    final class Box {
        weak var controller: UIViewController?
        weak var button: UIButton?
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .systemBackground
        let button = UIButton(type: .system)
        button.setTitle("Log Out", for: .normal)
        button.frame = CGRect(x: 20, y: 160, width: 120, height: 44)
        controller.view.addSubview(button)
        box.controller = controller
        box.button = button
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    @MainActor
    func presentSheet() {
        guard let controller = box.controller, let button = box.button else { return }
        let sheet = UIAlertController(title: "Are you sure?", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Log Out", style: .destructive))
        sheet.popoverPresentationController?.sourceView = button
        sheet.popoverPresentationController?.sourceRect = button.bounds
        controller.present(sheet, animated: false)
    }
}
