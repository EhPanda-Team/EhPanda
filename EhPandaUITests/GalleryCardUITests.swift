import UIKit
import XCTest

@MainActor
final class GalleryCardUITests: XCTestCase {
    private let shortTitle = "[Studio] A Journey [English]"
    private let longTitle = "[Artist] A Journey Through the City and Across the Mountains with Friends [English]"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testGridAlignsDifferentTitleLengthsAtEveryTextSize() throws {
        let originalOrientation = XCUIDevice.shared.orientation
        addTeardownBlock { XCUIDevice.shared.orientation = originalOrientation }
        XCUIDevice.shared.orientation = .landscapeLeft
        let fixtures = try makeFixtures()
        for size in [UIContentSizeCategory.large, .accessibilityMedium,
                     .accessibilityExtraLarge, .accessibilityExtraExtraExtraLarge] {
            let app = XCUIApplication()
            addTeardownBlock { app.terminate() }
            app.launchArguments = ["-UIPreferredContentSizeCategoryName", size.rawValue]
            try launch(app, fixtures: fixtures)
            app.buttons["gallery-layout-favorites"].tapWhenHittable("Presentation")
            app.buttons["Grid"].tapWhenHittable("Grid")
            let first = app.buttons["gallery-list-item-1001"]
            let second = app.buttons["gallery-list-item-1002"]
            XCTAssertTrue(first.waitForExistence(timeout: 10))
            let window = app.windows.firstMatch.frame
            let hasRoomForSecondColumn = first.frame.maxX + first.frame.width <= window.maxX
            if size == .large { XCTAssertTrue(hasRoomForSecondColumn) }
            if hasRoomForSecondColumn {
                XCTAssertTrue(second.waitForExistence(timeout: 10))
                XCTAssertEqual(first.frame.minY, second.frame.minY, accuracy: 1)
                XCTAssertEqual(first.frame.maxY, second.frame.maxY, accuracy: 1)
                XCTAssertLessThanOrEqual(first.frame.maxX, second.frame.minX)
            } else {
                XCTAssertLessThanOrEqual(first.frame.maxX, window.maxX)
                XCTAssertGreaterThan(first.frame.width, window.width / 2)
            }
            XCTAssertTrue(app.staticTexts["A Journey"].firstMatch.exists)
            XCTAssertFalse(app.descendants(matching: .any)["gallery-grid-rating-1001"].firstMatch.exists)
            let title = app.staticTexts["gallery-grid-title-1001"].firstMatch
            XCTAssertEqual(title.frame.minX, first.frame.minX, accuracy: 1)
            XCTAssertLessThanOrEqual(title.frame.maxX, first.frame.maxX)
            if size == .large {
                let language = first.staticTexts["English"].firstMatch
                XCTAssertTrue(language.exists)
                XCTAssertEqual(language.frame.maxX, first.frame.maxX, accuracy: 1)
            }
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "Grid aligned titles \(size.rawValue)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
    }

    func testFrontpageGridKeepsRatings() throws {
        let originalOrientation = XCUIDevice.shared.orientation
        addTeardownBlock { XCUIDevice.shared.orientation = originalOrientation }
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        try app.launchStubbed(extraEnvironment: ["EHPANDA_AUTOMATION_TAB": "home"])
        app.buttons["Show All"].firstMatch.tapWhenHittable("Frontpage")
        app.buttons["gallery-layout-frontpage"].tapWhenHittable("Frontpage presentation")
        app.buttons["Grid"].tapWhenHittable("Frontpage Grid")
        let ratings = app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "gallery-grid-rating-"
        ))
        XCTAssertTrue(ratings.firstMatch.waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Frontpage grid retains ratings"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testSimplifiedTitleSettingUpdatesBothLayoutsAndPersists() throws {
        let fixtures = try makeFixtures()
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        try launch(app, fixtures: fixtures)
        app.buttons["gallery-layout-favorites"].tapWhenHittable("Presentation")
        app.buttons["Row"].tapWhenHittable("Row")
        XCTAssertTrue(app.staticTexts["A Journey"].firstMatch.waitForExistence(timeout: 10))
        app.descendants(matching: .any)["gearshape.circle"].firstMatch.tapWhenHittable("Setting tab")
        app.buttons["Appearance"].tapWhenHittable("Appearance settings")
        let toggle = app.switches["simplified-gallery-titles"]
        try setSimplifiedTitles(false, toggle: toggle, app: app)
        XCTAssertTrue(app.staticTexts[shortTitle].firstMatch.waitForExistence(timeout: 10))
        app.buttons["gallery-layout-favorites"].tapWhenHittable("Presentation")
        app.buttons["Grid"].tapWhenHittable("Grid")
        XCTAssertTrue(app.staticTexts[shortTitle].firstMatch.waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.staticTexts[shortTitle].firstMatch.waitForExistence(timeout: 15))
        app.descendants(matching: .any)["gearshape.circle"].firstMatch.tapWhenHittable("Setting tab")
        app.buttons["Appearance"].tapWhenHittable("Appearance settings after relaunch")
        try setSimplifiedTitles(true, toggle: toggle, app: app)
        XCTAssertTrue(app.staticTexts["A Journey"].firstMatch.waitForExistence(timeout: 10))
    }

    private func setSimplifiedTitles(_ enabled: Bool, toggle: XCUIElement, app: XCUIApplication) throws {
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        // Native SwiftUI switches expose the entire row; activate the trailing switch itself.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).press(forDuration: 0.05)
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", enabled ? "1" : "0"), object: toggle
        )
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Simplified titles setting \(enabled)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let title = app.navigationBars["Appearance"].firstMatch
        title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
            forDuration: 0.05,
            thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
        )
        XCTAssertTrue(title.waitForNonExistence(timeout: 5))
    }

    private func launch(_ app: XCUIApplication, fixtures: URL) throws {
        try app.launchStubbed(extraEnvironment: [
            "EHPANDA_AUTOMATION_TAB": "favorites",
            "EHPANDA_AUTOMATION_IPB_MEMBER_ID": "fixture-member",
            "EHPANDA_AUTOMATION_IPB_PASS_HASH": "fixture-session",
            UITestConstants.fixtureDirectoryEnvironmentKey: fixtures.path()
        ])
        XCTAssertTrue(app.buttons["gallery-layout-favorites"].waitForExistence(timeout: 15))
    }

    private func makeFixtures() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: "GalleryCardUITest-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let source = try XCTUnwrap(Bundle(for: Self.self).resourceURL)
        for file in try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        where ["html", "png"].contains(file.pathExtension) {
            try FileManager.default.copyItem(at: file, to: root.appending(path: file.lastPathComponent))
        }
        let list = root.appending(path: "LibraryGalleries.html")
        let html = try String(contentsOf: list, encoding: .utf8)
            .replacingOccurrences(of: "Library Study 01", with: shortTitle)
            .replacingOccurrences(of: "Library Study 02", with: longTitle)
        try html.write(to: list, atomically: true, encoding: .utf8)
        return root
    }
}
