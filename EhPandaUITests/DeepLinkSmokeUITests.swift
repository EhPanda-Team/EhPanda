import XCTest

@MainActor
final class DeepLinkSmokeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testColdGalleryDeepLinkUsesHermeticFixture() throws {
        let app = XCUIApplication()
        let url = try XCTUnwrap(
            UITestConstants.galleryURL(scheme: "ehpanda")
        )

        try app.openCold(url)

        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 15),
            "Cold deep-link delivery did not foreground EhPanda."
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["detail_view"]
                .waitForExistence(timeout: 15),
            "Cold deep-link delivery did not reach the gallery detail screen."
        )
        XCTAssertTrue(
            app.buttons[UITestConstants.primaryMarkerTitle]
                .waitForExistence(timeout: 5),
            "The marker title was not rendered from the hermetic fixture."
        )
    }
}
