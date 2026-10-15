import UIKit
import XCTest

@MainActor
final class GalleryLayoutUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testNativeTitlesAndGridAtEveryTextSize() throws {
        XCUIDevice.shared.orientation = .portrait
        let sizes: [UIContentSizeCategory] = [
            .large, .accessibilityMedium, .accessibilityExtraLarge, .accessibilityExtraExtraExtraLarge
        ]
        for size in sizes {
            let app = XCUIApplication()
            app.launchArguments = ["-UIPreferredContentSizeCategoryName", size.rawValue]
            try launchFavorites(app)
            defer { app.terminate() }
            let picker = app.buttons["gallery-layout-favorites"]
            picker.tapWhenHittable("Presentation at \(size.rawValue)")
            app.buttons["Grid"].tapWhenHittable("Grid at \(size.rawValue)")
            let title = app.navigationBars["Favorites"].staticTexts["Favorites"]
            XCTAssertTrue(title.isHittable, "Native title must remain usable at \(size.rawValue)")
            let gallery = app.staticTexts["Library Study 01"].firstMatch
            XCTAssertTrue(gallery.waitForExistence(timeout: 10))
            let viewport = app.windows.firstMatch.frame
            XCTAssertGreaterThanOrEqual(gallery.frame.minX, viewport.minX)
            XCTAssertLessThanOrEqual(gallery.frame.maxX, viewport.maxX)
            XCTAssertTrue(picker.isHittable)
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "Library grid \(size.rawValue)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
    }

    func testChangingLayoutKeepsMiddleGalleryAndSearchSurvivesDetailReturn() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        try launchFavorites(app)
        defer { app.terminate() }
        let picker = app.buttons["gallery-layout-favorites"]
        picker.tapWhenHittable("Favorites presentation")
        app.buttons["Row"].tapWhenHittable("Favorites Row")
        let gallery = app.staticTexts["Library Study 12"].firstMatch
        let content = app.descendants(matching: .any)["favorites-gallery-list"].firstMatch
        for _ in 0..<12 where !gallery.isHittable {
            content.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(gallery.isHittable, "The row list must reach a middle gallery.")
        let candidates = app.buttons.matching(NSPredicate(
            format: "identifier BEGINSWITH %@", "gallery-list-item-"
        ))
        let visibleFrame = app.windows.firstMatch.frame
        let navigationBottom = app.navigationBars["Favorites"].frame.maxY
        let tabs = app.tabBars.firstMatch
        let bottom = tabs.exists && tabs.frame.minY > visibleFrame.midY ? tabs.frame.minY : visibleFrame.maxY
        let anchor = try XCTUnwrap(candidates.allElementsBoundByIndex.first(where: {
            $0.isHittable && $0.frame.midY > navigationBottom && $0.frame.midY < bottom
        }))
        let anchorID = anchor.identifier
        picker.tapWhenHittable("Switch a scrolled list")
        app.buttons["Grid"].tapWhenHittable("Grid")
        XCTAssertTrue(app.buttons[anchorID].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[anchorID].isHittable, "Switching layouts must retain the visible gallery anchor.")
        picker.tapWhenHittable("Restore rows")
        app.buttons["Row"].tapWhenHittable("Row")
        let restored = app.buttons[anchorID]
        XCTAssertTrue(restored.isHittable)
        XCTAssertGreaterThan(restored.frame.midY, app.navigationBars["Favorites"].frame.maxY)
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Library row restored after grid"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let search = app.searchFields.firstMatch
        for _ in 0..<12 where !search.isHittable {
            content.swipeDown(velocity: .slow)
        }
        search.tapWhenHittable("Favorites search")
        search.typeText("Library")
        app.buttons["gallery-list-item-1001"].tapWhenHittable("Open a searched gallery")
        let detail = app.descendants(matching: .any)["detail_view"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 10))
        app.returnFromGalleryDetail()
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        XCTAssertEqual(search.value as? String, "Library")
    }

    func testGridLoadsNextPageFromTrailingVisibility() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        try launchFavorites(app)
        defer { app.terminate() }
        app.buttons["gallery-layout-favorites"].tapWhenHittable("Favorites presentation")
        app.buttons["Grid"].tapWhenHittable("Grid")
        let content = app.descendants(matching: .any)["favorites-gallery-list"].firstMatch
        let nextPage = app.buttons["gallery-list-item-1025"]
        for _ in 0..<20 where !nextPage.isHittable {
            content.swipeUp(velocity: .fast)
        }
        XCTAssertTrue(nextPage.isHittable, "The grid must load its next page when the trailing gallery is visible.")
        XCTAssertEqual(app.buttons.matching(identifier: "gallery-list-item-1025").count, 1)
    }

    private func launchFavorites(_ app: XCUIApplication) throws {
        try app.launchStubbed(extraEnvironment: [
            "EHPANDA_AUTOMATION_TAB": "favorites",
            "EHPANDA_AUTOMATION_IPB_MEMBER_ID": "fixture-member",
            "EHPANDA_AUTOMATION_IPB_PASS_HASH": "fixture-session"
        ])
        XCTAssertTrue(app.buttons["gallery-layout-favorites"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Library Study 01"].firstMatch.waitForExistence(timeout: 15))
    }
}
