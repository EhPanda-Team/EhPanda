import AutomationIdentifiers
import UIKit
import XCTest

@MainActor
final class DetailNavigationTitleUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTitleFollowsHeaderVisibilityAtStandardSize() throws {
        try exerciseTitleVisibility(preferredContentSizeCategory: .large)
    }

    func testTitleFollowsHeaderVisibilityAtAX5() throws {
        try exerciseTitleVisibility(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
    }

    func testTitleFollowsHeaderVisibilityAtAX1() throws {
        try exerciseTitleVisibility(preferredContentSizeCategory: .accessibilityMedium)
    }

    func testTitleFollowsHeaderVisibilityAtAX3() throws {
        try exerciseTitleVisibility(preferredContentSizeCategory: .accessibilityExtraLarge)
    }

    func testTitleStaysHiddenForPartialHeaderAndAfterReturningFromSearch() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", UIContentSizeCategory.large.rawValue]
        let galleryURL = try XCTUnwrap(UITestConstants.galleryURL(scheme: "ehpanda"))
        try app.openCold(galleryURL)
        app.requireForeground()
        let content = app.requireElement(AccessibilityIdentifiers.detailView, matching: .scrollView)
        let headerTitle = app.buttons[UITestConstants.primaryMarkerTitle].firstMatch
        XCTAssertTrue(headerTitle.waitForExistence(timeout: 15))
        let read = app.buttons["Read"].firstMatch
        XCTAssertTrue(read.waitUntilHittable(timeout: XCUIElement.hittableTimeout))
        let initialHeaderY = headerTitle.frame.minY
        let start = content.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(
            forDuration: 0.05,
            thenDragTo: start.withOffset(CGVector(dx: 0, dy: -read.frame.height)),
            withVelocity: .slow,
            thenHoldForDuration: 0.2
        )

        let title = app.navigationBars.staticTexts[UITestConstants.primaryMarkerTitle].firstMatch
        XCTAssertLessThan(headerTitle.frame.minY, initialHeaderY, "The header must move with the scroll gesture.")
        XCTAssertTrue(
            read.waitUntilHittable(timeout: XCUIElement.hittableTimeout),
            "The partial scroll must retain the header actions."
        )
        XCTAssertFalse(title.exists, "A partially visible header must keep the navigation title hidden.")

        content.swipeDown()
        app.buttons["Pokom"].firstMatch.tapWhenHittable("The uploader")
        let searchTitle = app.navigationBars.staticTexts[#"uploader:"Pokom""#].firstMatch
        XCTAssertTrue(searchTitle.waitForExistence(timeout: 10), "Detail Search must retain its own title.")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons[UITestConstants.primaryMarkerTitle].waitForExistence(timeout: 10))
        XCTAssertFalse(title.exists, "Returning to the visible header must keep the navigation title hidden.")
    }

    private func exerciseTitleVisibility(preferredContentSizeCategory: UIContentSizeCategory) throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName", preferredContentSizeCategory.rawValue
        ]
        let galleryURL = try XCTUnwrap(UITestConstants.galleryURL(scheme: "ehpanda"))
        let fixtureDirectory = try makeScrollableGalleryFixture()
        try app.openCold(galleryURL, extraEnvironment: [
            UITestConstants.fixtureDirectoryEnvironmentKey: fixtureDirectory.path()
        ])
        app.requireForeground()
        let content = app.requireElement(AccessibilityIdentifiers.detailView, matching: .scrollView)
        let headerTitle = app.buttons[UITestConstants.primaryMarkerTitle].firstMatch
        XCTAssertTrue(headerTitle.waitForExistence(timeout: 15))
        XCTAssertTrue(
            headerTitle.waitUntilHittable(timeout: XCUIElement.hittableTimeout),
            "The gallery header must be visible on entry."
        )

        let title = app.navigationBars.staticTexts[UITestConstants.primaryMarkerTitle].firstMatch
        XCTAssertFalse(title.exists, "Detail must not display a navigation title while the header is visible.")

        for _ in 0..<6 {
            content.swipeUp()
            if title.exists {
                break
            }
        }
        XCTAssertTrue(title.waitForExistence(timeout: 10), "The inline title did not appear after scrolling.")
        XCTAssertTrue(
            title.waitUntilHittable(timeout: XCUIElement.hittableTimeout),
            "The inline title must be visible in the navigation bar."
        )
        // The app shows the title once the header has left the scroll view's bounds, and those begin below the
        // status bar. The header's last row is still drawn above them then, under the status bar: Read's lower edge
        // stood 10 to 52 points above the bounds in six runs at AX3 (2026-11-16), its middle on the screen in two of
        // them. What a look at its hit point answers up there is not what this case is about, and once it answered
        // that Read could be tapped. So the header is compared with the bounds it has to have left.
        let viewport = content.frame
        let read = app.buttons["Read"].firstMatch
        XCTAssertLessThanOrEqual(
            headerTitle.frame.maxY, viewport.minY,
            "The inline title appeared before the header scrolled away."
        )
        XCTAssertLessThanOrEqual(read.frame.maxY, viewport.minY, "The header actions are still visible.")
        XCTAssertTrue(
            app.navigationBars.buttons.matching(UITestConstants.overflowButtonPredicate).firstMatch
                .waitUntilHittable(timeout: XCUIElement.hittableTimeout),
            "Showing the inline title must preserve the Detail overflow control."
        )

        // The header is back when its title can be tapped again. It is asked once the scroll has come to rest: a
        // look at an element that still moves can end the test (`waitUntilHittable`).
        for _ in 0..<6 {
            content.swipeDown()
            if headerTitle.waitUntilHittable(timeout: Self.restTimeout) {
                break
            }
        }
        XCTAssertTrue(
            headerTitle.waitUntilHittable(timeout: XCUIElement.hittableTimeout),
            "Scrolling back did not restore the gallery header."
        )
        XCTAssertTrue(
            title.waitForNonExistence(timeout: 10),
            "The inline title remained visible after the gallery header returned."
        )
    }

    /// How long a swipe's scroll may take to come to rest before the header is looked for again.
    private static let restTimeout: TimeInterval = 2

    private func makeScrollableGalleryFixture() throws -> URL {
        // Every fixture, so Home behind the gallery still loads its list and the list's metadata.
        let directory = try StubFixtureCopy(for: self, named: "DetailNavigationTitle").root

        // The shared fixture is too short to scroll the whole header away, especially on iPad.
        let gallery = directory.appending(path: "GalleryDetail.html")
        let html = try String(contentsOf: gallery, encoding: .utf8)
        let marker = #"<div id="taglist"><table>"#
        XCTAssertTrue(html.contains(marker))
        let tags = (1...120).map { number in
            """
            <div class="gt"><a class="" id="ta_artist:landscape_\(number)">Landscape artist \(number)</a></div>
            """
        }
        .joined()
        let row = #"<tr><td class="tc">artist:</td><td>"# + tags + "</td></tr>"
        try html.replacingOccurrences(of: marker, with: marker + row)
            .write(to: gallery, atomically: true, encoding: .utf8)
        return directory
    }
}
