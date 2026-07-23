import XCTest

@MainActor
final class DeepLinkEntryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testClipboardGalleryLinkColdLaunchLandsOnDetail() throws {
        let app = XCUIApplication()
        let galleryURL = try XCTUnwrap(UITestConstants.galleryURL(scheme: "https"))

        try app.launchStubbed(
            extraEnvironment: [
                UITestConstants.clipboardURLEnvironmentKey: galleryURL.absoluteString
            ]
        )

        app.requireForeground()
        app.requireElement("detail_view", matching: .scrollView)
        XCTAssertTrue(
            app.buttons[UITestConstants.primaryMarkerTitle]
                .waitForExistence(timeout: 5),
            "The clipboard route did not render the hermetic gallery marker."
        )
    }

    func testCommentLinkTapPushesLinkedGallery() throws {
        let app = XCUIApplication()
        let commentURL = try XCTUnwrap(UITestConstants.commentURL(scheme: "ehpanda"))

        try app.openCold(commentURL)

        app.requireForeground()
        app.requireElement("comments_view", matching: .collectionView)
        let linkedGallery = app.staticTexts[UITestConstants.alternateMarkerTitle]
        XCTAssertTrue(
            linkedGallery.waitForExistence(timeout: 5),
            "The fixture gallery link did not appear in the linked comment."
        )
        XCTAssertTrue(
            linkedGallery.isHittable,
            "The fixture gallery link appeared but was not tappable."
        )

        linkedGallery.tap()

        app.requireElement("detail_view", matching: .scrollView)
        XCTAssertTrue(
            app.buttons[UITestConstants.alternateMarkerTitle]
                .waitForExistence(timeout: 15),
            "Tapping the comment link did not push the alternate gallery detail."
        )
    }
}
