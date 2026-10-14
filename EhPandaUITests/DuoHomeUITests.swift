import UIKit
import XCTest

/// Opt in on a Duo already set to 90 degrees with the pose CLI. The explicit opt-in makes a missing
/// hinge callback fail on Duo while keeping ordinary iPhone/iPad test runs independent of hardware poses.
@MainActor
final class DuoHomeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(ProcessInfo.processInfo.environment["EHPANDA_DUO_UI_TESTS"] == "1")
    }

    func testHomeKeepsPhysicalPaneOrderAndSixRankings() throws {
        let app = XCUIApplication()
        try app.launchStubbed()
        let left = app.requireElement("home_left_pane", matching: .scrollView)
        let right = app.requireElement("home_right_pane", matching: .scrollView)

        XCTAssertEqual(left.frame.maxX, app.windows.firstMatch.frame.midX, accuracy: 1)
        XCTAssertEqual(right.frame.minX, app.windows.firstMatch.frame.midX, accuracy: 1)
        XCTAssertTrue(left.buttons["Frontpage"].exists)
        XCTAssertTrue(app.navigationBars["Toplists"].exists)
        XCTAssertTrue(app.navigationBars["Home"].exists)
        let reload = app.buttons["Reload"]
        XCTAssertEqual(app.buttons.matching(identifier: "Reload").count, 1)
        XCTAssertTrue(reload.isHittable)
        XCTAssertEqual(reload.frame.midX, app.buttons["Home"].frame.midX, accuracy: 1)
        XCTAssertGreaterThan(reload.frame.midX, app.windows.firstMatch.frame.midX)
        reload.tapWhenHittable("Refresh all Home sections")

        var previousFrame: CGRect?
        for rank in 1...6 {
            let row = right.buttons.matching(NSPredicate(
                format: "label BEGINSWITH %@ AND NOT label CONTAINS '......'", "\(rank), "
            )).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 15), "Missing ranking \(rank)")
            if let previousFrame {
                XCTAssertEqual(row.frame.minX, previousFrame.minX, accuracy: 1)
                XCTAssertGreaterThan(row.frame.minY, previousFrame.maxY)
            }
            previousFrame = row.frame
        }
    }

    func testListsAndGalleriesPresentAcrossTheFold() throws {
        let app = XCUIApplication()
        try app.launchStubbed()
        let left = app.requireElement("home_left_pane", matching: .scrollView)
        left.buttons["Show All"].firstMatch.tapWhenHittable("Frontpage Show All")
        let frontpage = app.navigationBars["Frontpage"]
        XCTAssertTrue(frontpage.waitForExistence(timeout: 15))
        XCTAssertGreaterThanOrEqual(frontpage.frame.minX, app.windows.firstMatch.frame.midX)

        app.collectionViews.buttons.firstMatch.tapWhenHittable("Frontpage gallery")
        let detail = app.requireElement("detail_view", matching: .scrollView)
        XCTAssertLessThanOrEqual(detail.frame.maxX, app.windows.firstMatch.frame.midX)
        try closeSheet(in: app, onLeft: true)
        XCTAssertTrue(frontpage.exists, "Closing Detail must retain its presenting list")
        try closeSheet(in: app, onLeft: false)
        XCTAssertTrue(frontpage.waitForNonExistence(timeout: 5))

        app.requireElement("home_right_pane", matching: .scrollView)
        app.navigationBars["Toplists"].buttons["Show All"].tapWhenHittable("Toplists Show All")
        let toplists = app.navigationBars.matching(NSPredicate(format: "identifier BEGINSWITH 'Toplists - '"))
            .firstMatch
        XCTAssertTrue(toplists.waitForExistence(timeout: 15))
        XCTAssertLessThanOrEqual(toplists.frame.maxX, app.windows.firstMatch.frame.midX)
        app.collectionViews.buttons.firstMatch.tapWhenHittable("Toplists gallery")
        let rightDetail = app.requireElement("detail_view", matching: .scrollView)
        let onRight = NSPredicate { _, _ in rightDetail.frame.minX >= app.windows.firstMatch.frame.midX }
        let positioned = XCTNSPredicateExpectation(predicate: onRight, object: nil)
        let result = XCTWaiter.wait(for: [positioned], timeout: 5)
        XCTAssertEqual(result, .completed)
        try closeSheet(in: app, onLeft: false)
        XCTAssertTrue(toplists.exists)
        try closeSheet(in: app, onLeft: true)
    }

    func testRightPaneScrollKeepsHomeTitleAndLeftPaneStill() throws {
        let categories: [UIContentSizeCategory] = [
            .large, .accessibilityMedium, .accessibilityExtraLarge, .accessibilityExtraExtraExtraLarge
        ]
        for category in categories {
            let app = XCUIApplication()
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", category.rawValue]
            try app.launchStubbed()
            let left = app.requireElement("home_left_pane", matching: .scrollView)
            let right = app.requireElement("home_right_pane", matching: .scrollView)
            let title = app.navigationBars["Home"].staticTexts["Home"]
            let frontpage = left.buttons["Frontpage"]
            let ranking = right.buttons.matching(NSPredicate(
                format: "label BEGINSWITH '1, ' AND NOT label CONTAINS '......'"
            )).firstMatch
            XCTAssertTrue(title.isHittable)
            let titleFrame = title.frame
            let frontpageFrame = frontpage.frame
            let rankingFrame = ranking.frame

            right.swipeUp()

            XCTAssertLessThan(ranking.frame.minY, rankingFrame.minY - 40)
            XCTAssertTrue(title.isHittable, "Scrolling the other pane must keep the Home title visible")
            XCTAssertEqual(title.frame.minX, titleFrame.minX, accuracy: 1)
            XCTAssertEqual(title.frame.minY, titleFrame.minY, accuracy: 1)
            XCTAssertEqual(title.frame.width, titleFrame.width, accuracy: 1)
            XCTAssertEqual(title.frame.height, titleFrame.height, accuracy: 1)
            XCTAssertEqual(frontpage.frame.minY, frontpageFrame.minY, accuracy: 1)
            XCTAssertEqual(left.frame.maxX, app.windows.firstMatch.frame.midX, accuracy: 1)
            XCTAssertEqual(right.frame.minX, app.windows.firstMatch.frame.midX, accuracy: 1)
        }
    }

    func testOtherListsPresentOnTheRight() throws {
        let app = XCUIApplication()
        for title in ["Popular", "Watched", "History"] {
            try app.launchStubbed()
            let left = app.requireElement("home_left_pane", matching: .scrollView)
            left.swipeUp()
            let button = left.buttons[title].firstMatch
            let other = left.scrollViews.containing(.button, identifier: "Popular").firstMatch
            for _ in 0..<2 where !button.isHittable {
                let start = other.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
                let end = other.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
            button.tapWhenHittable(title)
            let list = app.navigationBars[title]
            XCTAssertTrue(list.waitForExistence(timeout: 15))
            XCTAssertGreaterThanOrEqual(list.frame.minX, app.windows.firstMatch.frame.midX)
            try closeSheet(in: app, onLeft: false)
            XCTAssertTrue(list.waitForNonExistence(timeout: 5))
        }
    }

    func testDirectGalleriesAndReaderReturnKeepTheirPhysicalSide() throws {
        let app = XCUIApplication()
        try app.launchStubbed()
        let carousel = app.requireElement("home_carousel", matching: .scrollView)
        let card = try XCTUnwrap(carousel.buttons.allElementsBoundByIndex.first {
            carousel.frame.contains(CGPoint(x: $0.frame.midX, y: $0.frame.midY))
        })
        card.tapWhenHittable("Slideshow gallery")
        let detail = app.requireElement("detail_view", matching: .scrollView)
        XCTAssertGreaterThanOrEqual(detail.frame.minX, app.windows.firstMatch.frame.midX)
        app.buttons["Read"].firstMatch.tapWhenHittable("Read")
        let reader = app.requireElement("reading_view")
        XCTAssertEqual(reader.frame.width, app.windows.firstMatch.frame.width, accuracy: 1)
        ReaderPageProbe(app: app).showPanel()
        reader.buttons["Close"].firstMatch.tapWhenHittable("Reader Close")
        XCTAssertTrue(reader.waitForNonExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(detail.frame.minX, app.windows.firstMatch.frame.midX)
        try closeSheet(in: app, onLeft: false)

        let right = app.requireElement("home_right_pane", matching: .scrollView)
        let ranking = right.buttons.matching(NSPredicate(
            format: "label BEGINSWITH '1, ' AND NOT label CONTAINS '......'"
        )).firstMatch
        ranking.tapWhenHittable("Toplists gallery")
        let leftDetail = app.requireElement("detail_view", matching: .scrollView)
        XCTAssertLessThanOrEqual(leftDetail.frame.maxX, app.windows.firstMatch.frame.midX)
        try closeSheet(in: app, onLeft: true)
    }

    func testRootTitleAndPaneOrderAtAccessibilitySizes() throws {
        let categories: [UIContentSizeCategory] = [
            .large, .accessibilityMedium, .accessibilityExtraLarge, .accessibilityExtraExtraExtraLarge
        ]
        for category in categories {
            let app = XCUIApplication()
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", category.rawValue]
            try app.launchStubbed()
            let left = app.requireElement("home_left_pane", matching: .scrollView)
            let right = app.requireElement("home_right_pane", matching: .scrollView)
            let title = app.navigationBars["Home"].staticTexts["Home"]
            XCTAssertTrue(title.isHittable, "Home title is inaccessible at \(category.rawValue)")
            XCTAssertEqual(left.frame.maxX, app.windows.firstMatch.frame.midX, accuracy: 1)
            XCTAssertEqual(right.frame.minX, app.windows.firstMatch.frame.midX, accuracy: 1)
            XCTAssertTrue(app.navigationBars["Toplists"].staticTexts["Toplists"].isHittable)
        }
    }

    func testWarmLinkWhileHomeSheetIsOpen() throws {
        let app = XCUIApplication()
        try app.launchStubbed()
        let left = app.requireElement("home_left_pane", matching: .scrollView)
        left.buttons["Show All"].firstMatch.tapWhenHittable("Frontpage")
        XCTAssertTrue(app.navigationBars["Frontpage"].waitForExistence(timeout: 10))
        let url = try XCTUnwrap(UITestConstants.galleryURL(
            scheme: "ehpanda", gid: UITestConstants.alternateGID, token: UITestConstants.alternateToken
        ))
        app.openWarm(url)
        let marker = app.buttons[UITestConstants.alternateMarkerTitle]
        XCTAssertTrue(marker.waitForExistence(timeout: 15))
        XCTAssertTrue(marker.isHittable)
    }

    func testPortraitUsesOnePaneAndPushesLists() throws {
        try DuoPose.set(.landscape)
        addTeardownBlock { try DuoPose.set(.portrait) }
        let app = XCUIApplication()
        try app.launchStubbed()
        XCTAssertLessThan(app.windows.firstMatch.frame.width, app.windows.firstMatch.frame.height)
        XCTAssertFalse(app.scrollViews["home_left_pane"].exists)
        XCTAssertFalse(app.scrollViews["home_right_pane"].exists)
        app.buttons["Show All"].firstMatch.tapWhenHittable("Portrait Frontpage Show All")
        let frontpage = app.navigationBars["Frontpage"]
        XCTAssertTrue(frontpage.waitForExistence(timeout: 10))
        XCTAssertTrue(frontpage.buttons["Home"].exists, "Portrait should push onto the Home navigation stack")
        XCTAssertEqual(frontpage.frame.width, app.windows.firstMatch.frame.width, accuracy: 1)
        try DuoPose.set(.portrait)
        let back = app.buttons["BackButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        XCTAssertTrue(back.isHittable)
        XCTAssertFalse(app.scrollViews["home_right_pane"].exists)
        XCTAssertTrue(app.buttons["Date Seek"].isHittable)
        XCTAssertTrue(app.buttons["Filters"].isHittable)
        assertVerticalTabs(in: app)
        back.tapWhenHittable("Return to split Home")
        XCTAssertTrue(app.scrollViews["home_right_pane"].waitForExistence(timeout: 5))
        assertVerticalTabs(in: app)
        try DuoPose.set(.landscape)
        XCTAssertFalse(app.scrollViews["home_right_pane"].exists)
        app.buttons["Show All"].firstMatch.tapWhenHittable("Portrait Frontpage Show All")
        XCTAssertTrue(frontpage.buttons["Home"].waitForExistence(timeout: 5))
        frontpage.buttons["Home"].tapWhenHittable("Return to Home")
        XCTAssertTrue(app.navigationBars["Home"].exists)
    }

    private func assertVerticalTabs(in app: XCUIApplication) {
        let home = app.buttons["house.circle"]
        let favorites = app.buttons["heart.circle"]
        XCTAssertTrue(home.isHittable)
        XCTAssertTrue(favorites.isHittable)
        XCTAssertEqual(home.frame.midX, favorites.frame.midX, accuracy: 1)
        XCTAssertGreaterThan(favorites.frame.midY, home.frame.midY)
        XCTAssertGreaterThan(home.frame.midX, app.windows.firstMatch.frame.midX)
    }

    private func closeSheet(in app: XCUIApplication, onLeft: Bool) throws {
        let buttons = app.buttons.matching(NSPredicate(format: "label == 'Close'")).allElementsBoundByIndex
        let button = try XCTUnwrap(buttons.first {
            $0.isHittable && ($0.frame.midX < app.windows.firstMatch.frame.midX) == onLeft
        })
        button.tapWhenHittable("Close sheet")
    }
}
