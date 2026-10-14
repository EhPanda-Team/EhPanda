import XCTest

@MainActor
final class DuoReadingPanelUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["EHPANDA_DUO_UI_TESTS"] == "1")
    }

    func testLowerPanelFollowsTheLandscapeFold() throws {
        try DuoPose.set(.half)
        try DuoPose.set(.portrait)
        let app = XCUIApplication()
        try app.openCold(XCTUnwrap(UITestConstants.singlePageURL(scheme: "ehpanda")))
        app.requireElement("reading_view")
        ReaderPageProbe(app: app).showPanel()
        requirePanel(in: app, landscape: true, onRight: true)

        let slider = app.sliders.firstMatch
        slider.adjust(toNormalizedSliderPosition: 0.4)
        XCTAssertTrue(slider.isHittable)

        try DuoPose.set(.landscape)
        requirePanel(in: app, landscape: false, onRight: false)
        try DuoPose.set(.portrait)
        requirePanel(in: app, landscape: true, onRight: true)
        try DuoPose.set(.open)
        requirePanel(in: app, landscape: true, onRight: false)
        try DuoPose.set(.half)
        requirePanel(in: app, landscape: true, onRight: true)

        app.requireElement("reading_view").buttons["Close"].tapWhenHittable("Reader toolbar Close")
        XCTAssertTrue(app.buttons["Read"].firstMatch.waitForExistence(timeout: 5))
    }

    func testLowerPanelRemainsPhysicallyRightInRTL() throws {
        try DuoPose.set(.half)
        try DuoPose.set(.portrait)
        let app = XCUIApplication()
        app.launchArguments += ["-AppleTextDirection", "YES", "-NSForceRightToLeftWritingDirection", "YES"]
        try app.openCold(XCTUnwrap(UITestConstants.singlePageURL(scheme: "ehpanda")))
        app.requireElement("reading_view")
        requirePanel(in: app, landscape: true, onRight: true)
    }

    private func requirePanel(in app: XCUIApplication, landscape: Bool, onRight: Bool) {
        ReaderPageProbe(app: app).showPanel()
        let panel = app.requireElement("reading_lower_panel")
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let viewport = app.windows.firstMatch.frame
            let frame = panel.frame
            let closeCount = app.otherElements["reading_view"].buttons.matching(identifier: "Close").count
            return (viewport.width > viewport.height) == landscape
                && (onRight ? frame.minX >= viewport.midX : frame.minX < viewport.midX)
                && closeCount == (onRight ? 1 : 2)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 10), .completed,
                       "Panel: \(panel.frame), viewport: \(app.windows.firstMatch.frame)")
        XCTAssertLessThanOrEqual(panel.frame.maxX, app.windows.firstMatch.frame.maxX)
        XCTAssertTrue(panel.sliders.firstMatch.isHittable)
        if onRight {
            XCTAssertGreaterThanOrEqual(panel.sliders.firstMatch.frame.minX, app.windows.firstMatch.frame.midX)
            XCTAssertEqual(panel.buttons.matching(identifier: "Close").count, 0)
        }
    }
}
