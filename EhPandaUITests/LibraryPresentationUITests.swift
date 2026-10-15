import XCTest

@MainActor
final class LibraryPresentationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFavoritesLayoutPersistsThroughLibrary() throws {
        let app = XCUIApplication()
        try app.launchStubbed(extraEnvironment: ["EHPANDA_AUTOMATION_TAB": "favorites"])

        XCTAssertTrue(
            app.navigationBars["Favorites"].waitForExistence(timeout: 15),
            "The Favorites group did not open through Library navigation."
        )
        let presentation = app.segmentedControls["Presentation"]
        XCTAssertTrue(presentation.waitForExistence(timeout: 10), "Favorites has no presentation picker.")
        presentation.buttons["Grid"].tapWhenHittable("Favorites Grid")
        XCTAssertEqual(presentation.buttons["Grid"].value as? String, "1")

        app.terminate()
        app.launch()

        let relaunchedPresentation = app.segmentedControls["Presentation"]
        XCTAssertTrue(
            relaunchedPresentation.waitForExistence(timeout: 15),
            "Favorites presentation picker did not return after relaunch."
        )
        XCTAssertEqual(relaunchedPresentation.buttons["Grid"].value as? String, "1")
    }
}
