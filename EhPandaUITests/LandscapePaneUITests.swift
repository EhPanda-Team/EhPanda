import XCTest

@MainActor
final class LandscapePaneUITests: XCTestCase {
    nonisolated private var isDuo: Bool { ProcessInfo.processInfo.environment["EHPANDA_DUO_UI_TESTS"] == "1" }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(isDuo || ProcessInfo.processInfo.environment["EHPANDA_IPAD_UI_TESTS"] == "1")
    }

    private func prepareLandscape() throws {
        if isDuo {
            try DuoPose.set(.open)
            try DuoPose.set(.portrait)
        } else {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
    }

    func testHomeAndNestedSheetsUseOppositeHalves() throws {
        try prepareLandscape()
        let app = XCUIApplication()
        try app.launchStubbed()
        let window = app.windows.firstMatch
        let left = app.requireElement("home_left_pane", matching: .scrollView)
        let right = app.requireElement("home_right_pane", matching: .scrollView)
        XCTAssertGreaterThan(window.frame.width, window.frame.height)
        XCTAssertEqual(left.frame.maxX, window.frame.midX, accuracy: 1)
        XCTAssertEqual(right.frame.minX, window.frame.midX, accuracy: 1)
        if !isDuo {
            let homeTab = app.buttons["house.circle"].firstMatch
            let favoritesTab = app.buttons["heart.circle"].firstMatch
            XCTAssertEqual(homeTab.frame.midY, favoritesTab.frame.midY, accuracy: 1)
            XCTAssertTrue(homeTab.isHittable)
            XCTAssertLessThan(homeTab.frame.maxY, window.frame.midY)
        }
        print("CAPTURE_LANDSCAPE_HOME")
        let title = app.navigationBars["Home"].staticTexts["Home"]
        let titleFrame = title.frame
        right.swipeUp()
        XCTAssertEqual(title.frame, titleFrame)
        left.buttons["Show All"].firstMatch.tapWhenHittable("Frontpage")
        let frontpage = app.navigationBars["Frontpage"]
        XCTAssertTrue(frontpage.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(frontpage.frame.minX, window.frame.midX)
        print("CAPTURE_LANDSCAPE_SHEET")
        app.collectionViews.buttons.firstMatch.tapWhenHittable("Gallery")
        let detail = app.requireElement("detail_view", matching: .scrollView)
        XCTAssertLessThanOrEqual(detail.frame.maxX, window.frame.midX)
        let sheetClose = try XCTUnwrap(app.buttons.matching(identifier: "Close").allElementsBoundByIndex.first {
            $0.isHittable && $0.frame.midX < window.frame.midX
        })
        sheetClose.tapWhenHittable("Detail Close")
        XCTAssertTrue(frontpage.exists)
    }

    func testReaderControlsMoveAndKeepTheirSideAfterRotation() throws {
        try prepareLandscape()
        let app = XCUIApplication()
        try app.openCold(XCTUnwrap(UITestConstants.singlePageURL(scheme: "ehpanda")))
        app.requireElement("reading_view")
        ReaderPageProbe(app: app).showPanel()
        assertControls(in: app, onLeft: false)
        print("CAPTURE_READER_RIGHT")
        app.buttons["reading_move_controls"].tapWhenHittable("Move controls left")
        assertControls(in: app, onLeft: true)
        print("CAPTURE_READER_LEFT")
        if isDuo { try DuoPose.set(.landscape) } else { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["reading_move_controls"].waitForNonExistence(timeout: 5))
        if isDuo { try DuoPose.set(.portrait) } else { XCUIDevice.shared.orientation = .landscapeLeft }
        assertControls(in: app, onLeft: true)
        app.buttons["reading_move_controls"].tapWhenHittable("Move controls right")
        assertControls(in: app, onLeft: false)
    }

    private func assertControls(in app: XCUIApplication, onLeft: Bool) {
        ReaderPageProbe(app: app).showPanel()
        let panel = app.requireElement("reading_lower_panel")
        let move = app.buttons["reading_move_controls"]
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let middle = app.windows.firstMatch.frame.midX
            return onLeft ? panel.frame.maxX <= middle + 1 : panel.frame.minX >= middle - 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
        let middle = app.windows.firstMatch.frame.midX
        if onLeft {
            XCTAssertGreaterThanOrEqual(move.frame.minX, middle)
        } else {
            XCTAssertLessThanOrEqual(move.frame.maxX, middle)
        }
        XCTAssertTrue(move.isHittable)
        XCTAssertEqual(move.label, onLeft ? "Move controls right" : "Move controls left")
        XCTAssertEqual(move.frame.height, app.otherElements["reading_slider_row"].frame.height, accuracy: 1)
        XCTAssertGreaterThanOrEqual(move.frame.height, 44)
        XCTAssertTrue(panel.sliders.firstMatch.isHittable)
        let close = panel.buttons["Close"]
        XCTAssertEqual(close.exists, !isDuo)
        if !isDuo {
            XCTAssertTrue(close.isHittable)
            XCTAssertEqual(close.frame.midX, app.otherElements["reading_slider_row"].frame.midX, accuracy: 1)
            XCTAssertLessThan(close.frame.maxY, app.otherElements["reading_slider_row"].frame.minY)
        }
        XCTAssertEqual(app.otherElements["reading_view"].buttons.matching(identifier: "Close").count, isDuo ? 1 : 2)
    }
}
