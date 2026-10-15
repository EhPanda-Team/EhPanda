import XCTest

@MainActor
final class LibraryPresentationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFavoritesLayoutPersistsThroughLibrary() throws {
        let app = XCUIApplication()
        try app.launchStubbed(extraEnvironment: [
            "EHPANDA_AUTOMATION_TAB": "favorites",
            "EHPANDA_AUTOMATION_IPB_MEMBER_ID": "fixture-member",
            "EHPANDA_AUTOMATION_IPB_PASS_HASH": "fixture-session"
        ])
        defer { app.terminate() }

        XCTAssertTrue(app.navigationBars["Favorites"].waitForExistence(timeout: 15))
        let gallery = app.staticTexts["Library Study 01"].firstMatch
        XCTAssertTrue(gallery.waitForExistence(timeout: 15), "Favorites must load the real parsed fixture list.")
        let presentation = app.buttons["gallery-layout-favorites"]
        presentation.tapWhenHittable("Favorites presentation")
        app.buttons["Grid"].tapWhenHittable("Favorites Grid")
        assertGrid(in: app)
        XCTAssertTrue(gallery.isHittable)
        gallery.tapWhenHittable("Open a Favorites gallery")
        XCTAssertTrue(app.descendants(matching: .any)["detail_view"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons[UITestConstants.primaryMarkerTitle].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tapWhenHittable("Return to Favorites")
        XCTAssertTrue(presentation.waitForExistence(timeout: 10))
        assertGrid(in: app)

        app.terminate()
        app.launch()
        XCTAssertTrue(presentation.waitForExistence(timeout: 15))
        XCTAssertTrue(gallery.waitForExistence(timeout: 15))
        assertGrid(in: app)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Library Favorites grid"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func assertGrid(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let first = app.staticTexts["Library Study 01"].firstMatch
        let second = app.staticTexts["Library Study 02"].firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 10), file: file, line: line)
        XCTAssertTrue(second.waitForExistence(timeout: 10), file: file, line: line)
        XCTAssertEqual(first.frame.minY, second.frame.minY, accuracy: 1, file: file, line: line)
        XCTAssertGreaterThan(second.frame.minX, first.frame.maxX, file: file, line: line)
    }

}
