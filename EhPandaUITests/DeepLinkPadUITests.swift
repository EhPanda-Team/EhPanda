import UIKit
import XCTest

@MainActor
final class DeepLinkPadUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPadTabModalReplacedByDeepLink() throws {
        // The tab-modal route needs a window regular in both dimensions. This suite runs iPads in
        // full screen, whose window is, so the idiom stands in for that window here. The idiom
        // read is main-actor-isolated, so it lives here rather than in `setUpWithError`:
        // that override matches XCTest's nonisolated declaration, so this class's `@MainActor` does
        // not reach it and annotating the override is an error. `XCTSkipUnless` is unusable for the
        // same reason (its condition is a nonisolated autoclosure), so only the skip goes to XCTest.
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("The tab-modal gallery detail needs an iPad's full-screen window.")
        }

        let app = XCUIApplication()
        try app.launchStubbed()
        app.requireForeground()

        // Home's Frontpage section, then its first gallery row: the tab-rooted tap
        // that routes through `presentGalleryDetail` in this window instead of
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
