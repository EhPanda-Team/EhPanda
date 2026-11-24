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

    /// A page and a sheet over it each have a row named X below the fold of their list: the step names the row a
    /// user can reach, the sheet's, and leaves the page behind it where it is (found at accessibility5 on the Quick
    /// Search sheet, whose saved searches the Search page behind it lists too: the element search found the page's
    /// row first and the step scrolled the page).
    @MainActor
    func testTheStepScrollsTheFrontPresentationAndNotThePageBehindIt() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let page = TallListPage()
        let hosted = HostedWindowCapture.host(page, in: window, style: .light)
        defer { hosted.dispose() }
        let sheet = TallListController()
        page.present(sheet)
        _ = await HostedWindowCapture.settle(window)
        let list = try XCTUnwrap(page.box.list)
        let sheetList = sheet.list
        XCTAssertGreaterThan(list.contentSize.height, list.bounds.height)
        XCTAssertGreaterThan(sheetList.contentSize.height, sheetList.bounds.height)
        let pageOffset = list.contentOffset.y
        try await RevealStep.reveal(.label(TallListController.target))(window)
        XCTAssertEqual(list.contentOffset.y, pageOffset, "The page behind the sheet was scrolled")
        XCTAssertGreaterThan(sheetList.contentOffset.y, 0, "The sheet's list was not scrolled to its row")
        XCTAssertTrue(Self.rowIsVisible(in: sheetList), "The sheet's row is not inside its list's visible area")
        await hosted.disposeAfterDismissal()
    }

    /// An active search presents its own controller over the page, but the page's rows stay the page's own list:
    /// the step names the page's row and scrolls the page (found on the typing suggestions of the Search page, whose
    /// rows the search controller's view does not hold).
    @MainActor
    func testTheStepScrollsThePageUnderAnActiveSearch() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let page = SearchPage()
        let hosted = HostedWindowCapture.host(page, in: window, style: .light)
        defer { hosted.dispose() }
        page.activate()
        _ = await HostedWindowCapture.settle(window)
        let list = try XCTUnwrap(page.box.page?.list)
        XCTAssertTrue(page.box.page?.presentedViewController is UISearchController, "The search is not presented")
        XCTAssertNotNil(RevealStep.element(.label(TallListController.target), in: window), "The row was not found")
        try await RevealStep.reveal(.label(TallListController.target))(window)
        XCTAssertGreaterThan(list.contentOffset.y, 0, "The page was not scrolled to its row")
        XCTAssertTrue(Self.rowIsVisible(in: list), "The page's row is not inside its list's visible area")
        await hosted.disposeAfterDismissal()
    }

    /// A sheet presented while a search is active is the front-most presentation: the step scrolls the sheet and
    /// leaves the page behind the search where it is. (UIKit presents it from the window's root, as the chain in the
    /// failure names; a search controller that holds a sheet of its own cannot be hosted, as presenting one by hand
    /// ends the process.)
    @MainActor
    func testTheStepScrollsASheetOverAnActiveSearch() async throws {
        let window = try XCTUnwrap(HostedWindowCapture.keyWindow())
        let page = SearchPage()
        let hosted = HostedWindowCapture.host(page, in: window, style: .light)
        defer { hosted.dispose() }
        page.activate()
        _ = await HostedWindowCapture.settle(window)
        let sheet = TallListController()
        sheet.modalPresentationStyle = .overFullScreen
        try XCTUnwrap(page.box.page?.presentedViewController).present(sheet, animated: false)
        _ = await HostedWindowCapture.settle(window)
        XCTAssertTrue(
            sheet.presentingViewController != nil && page.box.search?.isActive == true,
            "The sheet is not presented while the search is active: \(RevealStep.presentationChain(in: window))"
        )
        let list = try XCTUnwrap(page.box.page?.list)
        let pageOffset = list.contentOffset.y
        try await RevealStep.reveal(.label(TallListController.target))(window)
        XCTAssertEqual(list.contentOffset.y, pageOffset, "The page behind the search was scrolled")
        XCTAssertGreaterThan(sheet.list.contentOffset.y, 0, "The sheet's list was not scrolled to its row")
        XCTAssertTrue(Self.rowIsVisible(in: sheet.list), "The sheet's row is not inside its list's visible area")
        await hosted.disposeAfterDismissal()
    }

    /// Whether the row ``TallListController/target`` of `list` is inside the area of `list` a user sees.
    @MainActor
    private static func rowIsVisible(in list: UIScrollView) -> Bool {
        let visible = list.bounds.inset(by: list.adjustedContentInset)
        let row = list.subviews.compactMap({ $0 as? UILabel }).first(where: { $0.text == TallListController.target })
        return row.map({ visible.contains($0.frame) }) ?? false
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

/// A scroll view of labelled rows with the row ``TallListController/target`` at the end, far below the first screen.
@MainActor
private func fillRows(of list: UIScrollView) {
    let rowHeight: CGFloat = 44
    let rows = 60
    for index in 0..<rows {
        let label = UILabel(frame: CGRect(x: 20, y: CGFloat(index) * rowHeight, width: 300, height: rowHeight))
        label.text = index == rows - 1 ? TallListController.target : "Row \(index)"
        list.addSubview(label)
    }
    list.contentSize = CGSize(width: 340, height: CGFloat(rows) * rowHeight)
}

/// A controller whose only content is a tall list of labelled rows.
private final class TallListController: UIViewController {
    static let target = "X"
    let list = UIScrollView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        list.frame = view.bounds
        list.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        fillRows(of: list)
        view.addSubview(list)
    }
}

/// A page with a tall list of rows that presents a sheet over itself, without covering it (`overFullScreen`), as a
/// sheet leaves the page behind it in the hierarchy.
private struct TallListPage: UIViewControllerRepresentable {
    let box = Box()

    final class Box {
        weak var controller: TallListController?
        var list: UIScrollView? { controller?.list }
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = TallListController()
        box.controller = controller
        return controller
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    @MainActor
    func present(_ sheet: UIViewController) {
        sheet.modalPresentationStyle = .overFullScreen
        box.controller?.present(sheet, animated: false)
    }
}

/// A navigation page with a tall list of rows and a search bar, which presents the search controller over it when the
/// search is made active.
private struct SearchPage: UIViewControllerRepresentable {
    let box = Box()

    final class Box {
        weak var page: TallListController?
        weak var search: UISearchController?
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let page = TallListController()
        let search = UISearchController(searchResultsController: nil)
        page.navigationItem.searchController = search
        page.definesPresentationContext = true
        box.page = page
        box.search = search
        return UINavigationController(rootViewController: page)
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}

    @MainActor
    func activate() {
        box.search?.isActive = true
    }
}
