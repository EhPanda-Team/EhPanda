import UIKit
import XCTest

@MainActor
final class DeepLinkPadUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(
            UIDevice.current.userInterfaceIdiom == .pad,
            "The tab-modal gallery detail is an iPad-exclusive entry."
        )
    }

    func testPadTabModalReplacedByDeepLink() throws {
        let app = XCUIApplication()
        try app.launchStubbed()
        app.requireForeground()

        // Home's Frontpage section, then its first gallery row: the tab-rooted tap
        // that routes through `presentGalleryDetail` on the pad idiom instead of
        // pushing onto the tab's own stack.
        let showAllButton = app.buttons["Show All"].firstMatch
        XCTAssertTrue(
            showAllButton.waitForExistence(timeout: 15),
            "Home did not render its Frontpage section."
        )
        showAllButton.tap()

        let firstGalleryRow = app.collectionViews.buttons.firstMatch
        XCTAssertTrue(
            firstGalleryRow.waitForExistence(timeout: 15),
            "The Frontpage list did not render a gallery row."
        )
        firstGalleryRow.tap()

        app.requireElement("detail_view", matching: .scrollView)
        XCTAssertTrue(
            app.buttons[UITestConstants.primaryMarkerTitle]
                .waitForExistence(timeout: 15),
            "The tab-modal detail did not render the hermetic gallery marker."
        )

        // A deep link arriving over the open modal dismisses it, waits for the
        // dismissal to complete, and re-presents on the linked gallery. The Alt
        // marker title is what distinguishes the replacement from the original.
        let alternateURL = try XCTUnwrap(
            UITestConstants.galleryURL(
                scheme: "ehpanda",
                gid: UITestConstants.alternateGID,
                token: UITestConstants.alternateToken
            )
        )
        app.openWarm(alternateURL)

        XCTAssertTrue(
            app.buttons[UITestConstants.alternateMarkerTitle]
                .waitForExistence(timeout: 15),
            "The deep link did not replace the open tab-modal with the linked gallery."
        )
        app.requireElement("detail_view", matching: .scrollView)
    }
}
