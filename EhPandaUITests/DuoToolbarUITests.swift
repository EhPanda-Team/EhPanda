import XCTest

/// Run on the Duo cover display in landscape, where tabs and list tools compete for vertical space.
@MainActor
final class DuoToolbarUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["EHPANDA_DUO_COMPACT_UI_TESTS"] == "1")
    }

    func testListToolsAndEveryTabStayReachable() throws {
        let app = XCUIApplication()
        try app.launchStubbed()
        app.requireElement("home_carousel", matching: .scrollView)
        app.buttons["Show All"].firstMatch.tapWhenHittable("Front Page")
        let frontPage = app.navigationBars["Front Page"]
        XCTAssertTrue(frontPage.waitForExistence(timeout: 10))

        // The native bar keeps clipped tabs in the accessibility tree, and XCTest can report
        // those as hittable. Their actual positions show that all four tabs fit on the bar.
        let window = app.windows.firstMatch.frame
        for tab in ["Home", "Library", "Search", "Settings"] {
            let frame = app.buttons[tab].frame
            XCTAssertTrue(window.contains(CGPoint(x: frame.midX, y: frame.midY)), tab)
        }
        app.buttons["Library"].tapWhenHittable("Library")
        app.requireLibraryNavigationTitle("Favorites")
        app.buttons["Home"].tapWhenHittable("Home")
        XCTAssertTrue(frontPage.waitForExistence(timeout: 10))

        // With the tabs taking the bar's height, the system folds the list tools into its overflow menu.
        app.buttons["More"].tapWhenHittable("More")
        XCTAssertTrue(app.buttons["Seek to Date"].waitForExistence(timeout: 5))
        app.buttons["Filters"].tapWhenHittable("Filters")
        XCTAssertTrue(app.navigationBars["Filters"].waitForExistence(timeout: 10))
    }
}
