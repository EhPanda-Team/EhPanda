import UIKit
import XCTest

@MainActor
final class ReadingOrientationUITests: XCTestCase {
    private nonisolated var isDuo: Bool {
        ProcessInfo.processInfo.environment["EHPANDA_DUO_UI_TESTS"] == "1"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        let isDuo = isDuo
        addTeardownBlock {
            if isDuo {
                try DuoPose.set(.portrait)
            } else {
                XCUIDevice.shared.orientation = .portrait
            }
        }
    }

    func testAutomaticLayoutPreservesThePageOnRotationAndReentry() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad || isDuo)
        try setOrientation(landscape: false)
        let app = try openReader()
        configureAutomation(in: app, enabled: true)
        try requirePages(in: app, dual: false)
        ReaderPageProbe(app: app).dragSlider(toNormalizedPosition: 0.4)
        let resumedPage = try indicatedPage(in: app)
        XCTAssertGreaterThan(resumedPage, 10)

        try setOrientation(landscape: true)
        requireViewport(in: app, landscape: true)
        try requirePages(in: app, dual: true, containing: resumedPage)
        assertDirection("Right-to-left", in: app)
        readAgain(in: app)
        try requirePages(in: app, dual: true, containing: resumedPage)

        try setOrientation(landscape: false)
        requireViewport(in: app, landscape: false)
        try requirePages(in: app, dual: false)
        XCTAssertLessThanOrEqual(abs(try indicatedPage(in: app) - resumedPage), 1)
        assertDirection("Vertical", in: app)

        // An explicit manual change survives until the next orientation or reader entry.
        try setOrientation(landscape: true)
        try requirePages(in: app, dual: true)
        ReaderPageProbe(app: app).setDirection(.vertical)
        try requirePages(in: app, dual: false)
        let beforeReentry = try indicatedPage(in: app)
        readAgain(in: app)
        try requirePages(in: app, dual: true, containing: beforeReentry)
    }

    func testDisablingAutomationKeepsManualDirectionAfterRotation() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad || isDuo)
        try setOrientation(landscape: false)
        let app = try openReader()
        configureAutomation(in: app, enabled: false)
        ReaderPageProbe(app: app).setDirection(.vertical)
        try setOrientation(landscape: true)
        requireViewport(in: app, landscape: true)
        try requirePages(in: app, dual: false)
        assertDirection("Vertical", in: app)
        readAgain(in: app)
        try requirePages(in: app, dual: false)
        configureAutomation(in: app, enabled: true)
        try requirePages(in: app, dual: true)
    }

    func testOrdinaryPhoneOffersTwoPagesWithoutAutomaticRotation() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone && !isDuo)
        try setOrientation(landscape: false)
        let app = try openReader()
        configureAutomation(in: app, enabled: true)
        ReaderPageProbe(app: app).setDirection(.vertical)
        try setOrientation(landscape: true)
        requireViewport(in: app, landscape: true)
        try requirePages(in: app, dual: false)
        let menu = app.buttons["Dual-Page Mode"].firstMatch
        menu.tapWhenHittable("Landscape two-page menu")
        try XCTUnwrap(app.buttons.matching(identifier: "Dual-Page Mode").allElementsBoundByIndex.last)
            .tapWhenHittable("Enable two pages")
        ReaderPageProbe(app: app).showPanel()
        try requirePages(in: app, dual: true)
        assertDirection("Right-to-left", in: app)
        try setOrientation(landscape: false)
        try requirePages(in: app, dual: false)
        assertDirection("Right-to-left", in: app)
    }

    private func setOrientation(landscape: Bool) throws {
        if isDuo {
            // The simulator's inner display is wider in the hardware portrait pose.
            try DuoPose.set(landscape ? .portrait : .landscape)
        } else {
            XCUIDevice.shared.orientation = landscape ? .landscapeLeft : .portrait
        }
    }

    private func openReader() throws -> XCUIApplication {
        let app = XCUIApplication()
        try app.openCold(XCTUnwrap(UITestConstants.singlePageURL(scheme: "ehpanda")))
        app.requireElement("reading_view")
        ReaderPageProbe(app: app).showPanel()
        return app
    }

    private func requireViewport(in app: XCUIApplication, landscape: Bool) {
        let predicate = NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            return (frame.width > frame.height) == landscape
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 10),
                       .completed)
    }

    private func requirePages(in app: XCUIApplication, dual: Bool, containing page: Int? = nil) throws {
        let element = app.requireElement("reading_pages")
        let predicate = NSPredicate { _, _ in
            let value = element.value as? String ?? ""
            let position = value.components(separatedBy: " of ").first ?? ""
            let numbers = position.split(whereSeparator: { !$0.isNumber }).compactMap({ Int($0) })
            guard numbers.count == (dual ? 2 : 1) else { return false }
            return page.map({ numbers.contains($0) }) ?? true
        }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 10)
        XCTAssertEqual(result, .completed, "Unexpected reader position: \(element.value ?? "missing")")
        if !isDuo {
            let position = (element.value as? String ?? "").components(separatedBy: " of ")[0]
            let expected = position.split(whereSeparator: { !$0.isNumber }).compactMap({ Int($0) })
            try ReaderPageProbe(app: app).requireRenderedPages(expected)
        }
    }

    private func indicatedPage(in app: XCUIApplication) throws -> Int {
        let text = app.staticTexts["reading_page_indicator"].label
        return try XCTUnwrap(text.split(separator: "/").first.flatMap({
            Int($0.trimmingCharacters(in: .whitespaces))
        }))
    }

    private func readAgain(in app: XCUIApplication) {
        app.requireElement("reading_view").buttons["Close"].firstMatch.tapWhenHittable("Reader Close")
        app.buttons["Read"].firstMatch.tapWhenHittable("Read again")
        app.requireElement("reading_view")
        ReaderPageProbe(app: app).showPanel()
    }

    private func openSettings(in app: XCUIApplication) {
        let reader = app.requireElement("reading_view")
        reader.buttons.matching(NSPredicate(
            format: "identifier IN %@",
            ["OverflowBarButtonItem", "TopOverflowBarButtonItem", "BottomOverflowBarButtonItem"]
        )).firstMatch
            .tapWhenHittable("Reader More")
        app.buttons["Reading Setting"].firstMatch.tapWhenHittable("Reading Setting")
        XCTAssertTrue(app.navigationBars["Reading"].waitForExistence(timeout: 5))
    }

    private func dismissSettings(in app: XCUIApplication) {
        let title = app.navigationBars["Reading"].firstMatch
        if title.buttons["Close"].exists {
            title.buttons["Close"].tapWhenHittable("Settings Close")
        } else {
            title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
                forDuration: 0.05,
                thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
            )
        }
        XCTAssertTrue(title.waitForNonExistence(timeout: 5))
    }

    private func configureAutomation(in app: XCUIApplication, enabled: Bool) {
        openSettings(in: app)
        let toggle = app.switches["Match Screen Orientation"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        if (toggle.value as? String == "1") != enabled {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).press(forDuration: 0.05)
        }
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", enabled ? "1" : "0"), object: toggle
        )
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
        dismissSettings(in: app)
    }

    private func assertDirection(_ expected: String, in app: XCUIApplication) {
        openSettings(in: app)
        let direction = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Direction'"))
            .firstMatch
        XCTAssertTrue(direction.label.contains(expected), "Unexpected direction: \(direction.label)")
        dismissSettings(in: app)
    }
}
