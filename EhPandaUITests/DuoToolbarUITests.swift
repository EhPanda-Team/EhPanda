import XCTest

/// Run on the Duo cover display in landscape, where tabs and list tools compete for vertical space.
@MainActor
final class DuoToolbarUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["EHPANDA_DUO_COMPACT_UI_TESTS"] == "1")
    }

    func testListToolsRemainVisibleAndCompressedTabsCanExpand() throws {
        let app = XCUIApplication()
        try app.launchStubbed()
        app.requireElement("home_carousel", matching: .scrollView)
        app.buttons["Show All"].firstMatch.tapWhenHittable("Frontpage")
        XCTAssertTrue(app.navigationBars["Frontpage"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Date Seek"].isHittable)
        XCTAssertTrue(app.buttons["Filters"].isHittable)
        // The native bar keeps clipped tabs in the accessibility tree, and XCTest can report
        // those as hittable. Their actual positions distinguish the collapsed and expanded bar.
        let downloads = app.buttons["Downloads"].frame
        XCTAssertFalse(app.windows.firstMatch.frame.contains(CGPoint(x: downloads.midX, y: downloads.midY)))
        app.buttons["Home"].tapWhenHittable("Expand tabs")
        app.buttons["Favorites"].tapWhenHittable("Favorites")
        app.requireLibraryNavigationTitle("Favorites")
    }
}
