import XCTest

@MainActor
final class DeepLinkSchemeUITests: XCTestCase {
    private let pageCount = 156

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testGalleryLinkColdLaunchLandsOnDetail() throws {
        let app = XCUIApplication()
        let url = try XCTUnwrap(UITestConstants.galleryURL(scheme: "ehpanda"))

        try app.openCold(url)

        assertGalleryDestination(in: app)
    }

    func testGalleryLinkWarmForegroundLandsOnDetail() throws {
        let app = XCUIApplication()
        let url = try XCTUnwrap(UITestConstants.galleryURL(scheme: "ehpanda"))

        try app.launchStubbed()
        app.requireForeground()
        app.openWarm(url)

        assertGalleryDestination(in: app)
    }

    func testPageLinkColdLaunchOpensReaderAtPage() throws {
        let app = XCUIApplication()
        let url = try XCTUnwrap(UITestConstants.singlePageURL(scheme: "ehpanda"))

        try app.openCold(url)

        assertReaderDestination(in: app)
    }

    func testPageLinkWarmForegroundOpensReaderAtPage() throws {
        let app = XCUIApplication()
        let url = try XCTUnwrap(UITestConstants.singlePageURL(scheme: "ehpanda"))

        try app.launchStubbed()
        app.requireForeground()
        app.openWarm(url)

        assertReaderDestination(in: app)
    }

    func testCommentLinkColdLaunchScrollsToComment() throws {
        let app = XCUIApplication()
        let url = try XCTUnwrap(UITestConstants.commentURL(scheme: "ehpanda"))

        try app.openCold(url)

        assertCommentDestination(in: app)
    }

    func testCommentLinkWarmForegroundScrollsToComment() throws {
        let app = XCUIApplication()
        let url = try XCTUnwrap(UITestConstants.commentURL(scheme: "ehpanda"))

        try app.launchStubbed()
        app.requireForeground()
        app.openWarm(url)

        assertCommentDestination(in: app)
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
    ) {
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
}
