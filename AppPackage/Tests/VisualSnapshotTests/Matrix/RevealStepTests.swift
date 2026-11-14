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
        page.presentSheet()
        try await RevealStep.awaitDialogPlatter()(window)
        XCTAssertTrue(RevealStep.popoverPlatterReady(in: window))
        XCTAssertNotNil(hosted.controller.presentedViewController?.popoverPresentationController)
        XCTAssertTrue(Self.contains("_UIPopoverGlassBackground", in: window))
        await hosted.disposeAfterDismissal()
    }

    /// A page with no dialog over it never gets there: the step fails, and the capture tries again.
    @MainActor
    func testTheStepFailsWithoutADialog() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let hosted = HostedWindowCapture.host(ButtonPage(), in: window, style: .light)
        defer { hosted.dispose() }
        do {
            try await RevealStep.awaitDialogPlatter()(window)
            XCTFail("The step passed with no dialog presented")
        } catch AccessibilityActionDriver.Failure.notFound {
            // The failure the capture names `interaction:not-found` and retries.
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
