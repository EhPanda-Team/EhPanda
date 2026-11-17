import XCTest

@MainActor
final class DeepLinkSchemeUITests: XCTestCase {
    private let pageCount = 156

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The application of a case, on a device turned to portrait. The page link's reader is checked in portrait: in
    /// landscape the iPad shows a two-page spread whose indicator reads the spread's first page. A test that ran
    /// earlier on the same clone can leave the device in landscape.
    ///
    /// Every case starts here and not in set-up. The device belongs to the main actor, and XCTest declares its
    /// synchronous set-up outside it. Its asynchronous set-up does take this class's isolation, but with it
    /// overridden a failing case ends the runner process, and the plan's retries of that case are never run.
    private func applicationInPortrait() -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        return XCUIApplication()
    }

    func testGalleryLinkColdLaunchLandsOnDetail() throws {
        let app = applicationInPortrait()
        let url = try XCTUnwrap(UITestConstants.galleryURL(scheme: "ehpanda"))

        try app.openCold(url)

        assertGalleryDestination(in: app)
    }

    func testGalleryLinkWarmForegroundLandsOnDetail() throws {
        let app = applicationInPortrait()
        let url = try XCTUnwrap(UITestConstants.galleryURL(scheme: "ehpanda"))

        try app.launchStubbed()
        app.requireForeground()
        app.openWarm(url)

        assertGalleryDestination(in: app)
    }

    func testPageLinkColdLaunchOpensReaderAtPage() throws {
        let app = applicationInPortrait()
        let url = try XCTUnwrap(UITestConstants.singlePageURL(scheme: "ehpanda"))

        try app.openCold(url)

        try assertReaderDestination(in: app)
    }

    func testPageLinkWarmForegroundOpensReaderAtPage() throws {
        let app = applicationInPortrait()
        let url = try XCTUnwrap(UITestConstants.singlePageURL(scheme: "ehpanda"))

        try app.launchStubbed()
        app.requireForeground()
        app.openWarm(url)

        try assertReaderDestination(in: app)
    }

    func testCommentLinkColdLaunchScrollsToComment() throws {
        let app = applicationInPortrait()
        let url = try XCTUnwrap(UITestConstants.commentURL(scheme: "ehpanda"))

        try app.openCold(url)

        assertCommentDestination(in: app)
    }

    func testCommentLinkWarmForegroundScrollsToComment() throws {
        let app = applicationInPortrait()
        let url = try XCTUnwrap(UITestConstants.commentURL(scheme: "ehpanda"))

        try app.launchStubbed()
        app.requireForeground()
        app.openWarm(url)

        assertCommentDestination(in: app)
    }

    func testMalformedLinkColdLaunchShowsErrorToast() throws {
        let app = applicationInPortrait()
        let url = try XCTUnwrap(UITestConstants.malformedURL(scheme: "ehpanda"))

        try app.openCold(url)

        assertMalformedLinkDestination(in: app)
    }

    func testMalformedLinkWarmForegroundShowsErrorToast() throws {
        let app = applicationInPortrait()
        let url = try XCTUnwrap(UITestConstants.malformedURL(scheme: "ehpanda"))

        try app.launchStubbed()
        app.requireForeground()
        app.openWarm(url)

        assertMalformedLinkDestination(in: app)
    }

    private func assertGalleryDestination(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        app.requireForeground(file: file, line: line)
        app.requireElement("detail_view", matching: .scrollView, file: file, line: line)
        XCTAssertTrue(
            app.buttons[UITestConstants.primaryMarkerTitle]
                .waitForExistence(timeout: 5),
            "The gallery marker title did not render from the hermetic fixture.",
            file: file,
            line: line
        )
        XCTAssertFalse(
            app.descendants(matching: .scrollView)["reading_view"]
                .waitForExistence(timeout: 2),
            "A gallery-only link unexpectedly opened the reader.",
            file: file,
            line: line
        )
    }

    private func assertReaderDestination(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        app.requireForeground(file: file, line: line)
        app.requireElement("detail_view", matching: .scrollView, file: file, line: line)
        let readingView = app.requireElement(
            "reading_view",
            file: file,
            line: line
        )

        readingView.tap()

        let pageIndicator = app.requireElement(
            "reading_page_indicator",
            matching: .staticText,
            timeout: 5,
            file: file,
            line: line
        )
        let expectedValue = "\(UITestConstants.pageIndex) / \(pageCount)"
        let indicatorValue = pageIndicator.value as? String
        XCTAssertTrue(
            pageIndicator.label == expectedValue || indicatorValue == expectedValue,
            "Expected reader page indicator \(expectedValue), got label "
                + "\(pageIndicator.label.debugDescription) and value \(String(describing: indicatorValue)).",
            file: file,
            line: line
        )
        // The indicator is computed from the page model, so it cannot show that the reader opened
        // on the linked page; the page under the center of the reader can (`ReaderPageProbe`).
        try ReaderPageProbe(app: app).requirePage(
            "On opening the page link",
            where: { $0 == UITestConstants.pageIndex },
            file: file,
            line: line
        )
    }

    private func assertCommentDestination(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        app.requireForeground(file: file, line: line)
        app.requireElement("comments_view", matching: .collectionView, file: file, line: line)
        let linkedComment = app.requireElement(
            "comment_cell_" + UITestConstants.commentID,
            file: file,
            line: line
        )
        XCTAssertTrue(
            linkedComment.isHittable,
            "The linked comment exists but was not scrolled into view.",
            file: file,
            line: line
        )

        let backButton = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(
            backButton.exists,
            "Comments were not pushed over a gallery detail destination.",
            file: file,
            line: line
        )
        backButton.tap()
        app.requireElement("detail_view", matching: .scrollView, file: file, line: line)
    }

    private func assertMalformedLinkDestination(
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        app.requireForeground(file: file, line: line)
        let toast = app.requireElement("toast_message", file: file, line: line)
        XCTAssertTrue(
            toast.label.contains(UITestConstants.unsupportedLinkDescription),
            "The malformed-link toast did not explain that the link is unsupported; "
                + "its accessibility label was \(toast.label.debugDescription).",
            file: file,
            line: line
        )
        XCTAssertFalse(
            app.descendants(matching: .scrollView)["detail_view"]
                .waitForExistence(timeout: 2),
            "A malformed link unexpectedly opened a gallery detail screen.",
            file: file,
            line: line
        )

        // The toast slides and fades in under a spring, and until the spring ends the toast's UIKit alpha stays at
        // the 0 it began with, so a touch passes through a toast that already looks whole (`revealed(_:)` in
        // AppComponents has the mechanism). A whole run on 2026-11-16 found the toast untouchable for 0.1 to 0.7
        // seconds after it showed, and its hit point once answered with what lay beneath it. So the tap waits for
        // the toast to take it, as it would for any control behind a transition.
        toast.tapWhenHittable("The malformed-link toast", file: file, line: line)

        app.requireElement("error_info_view", file: file, line: line)
    }
}
