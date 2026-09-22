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
        let content = app.requireElement("detail_view", matching: .scrollView)
        let headerTitle = app.buttons[UITestConstants.primaryMarkerTitle].firstMatch
        XCTAssertTrue(headerTitle.waitForExistence(timeout: 15))
        let read = app.buttons["Read"].firstMatch
        XCTAssertTrue(read.isHittable)
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
        XCTAssertTrue(read.isHittable, "The partial scroll must retain the header actions.")
        XCTAssertFalse(title.exists, "A partially visible header must keep the navigation title hidden.")

        content.swipeDown()
        let uploader = app.buttons["Pokom"].firstMatch
        XCTAssertTrue(uploader.isHittable)
        uploader.tap()
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
        let content = app.requireElement("detail_view", matching: .scrollView)
        let headerTitle = app.buttons[UITestConstants.primaryMarkerTitle].firstMatch
        XCTAssertTrue(headerTitle.waitForExistence(timeout: 15))
        XCTAssertTrue(headerTitle.isHittable, "The gallery header must be visible on entry.")

        let title = app.navigationBars.staticTexts[UITestConstants.primaryMarkerTitle].firstMatch
        XCTAssertFalse(title.exists, "Detail must not display a navigation title while the header is visible.")

        for _ in 0..<6 {
            content.swipeUp()
            if title.exists {
                break
            }
        }
        XCTAssertTrue(title.waitForExistence(timeout: 10), "The inline title did not appear after scrolling.")
        XCTAssertTrue(title.isHittable, "The inline title must be visible in the navigation bar.")
        XCTAssertFalse(headerTitle.isHittable, "The inline title appeared before the header scrolled away.")
        XCTAssertFalse(app.buttons["Read"].firstMatch.isHittable, "The header actions are still visible.")
        XCTAssertTrue(
            app.navigationBars.buttons["OverflowBarButtonItem"].firstMatch.isHittable,
            "Showing the inline title must preserve the Detail overflow control."
        )

        for _ in 0..<6 {
            content.swipeDown()
            if headerTitle.isHittable {
                break
            }
        }
        XCTAssertTrue(headerTitle.isHittable, "Scrolling back did not restore the gallery header.")
        XCTAssertTrue(
            title.waitForNonExistence(timeout: 10),
            "The inline title remained visible after the gallery header returned."
        )
    }

    private func makeScrollableGalleryFixture() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try FileManager.default.removeItem(at: directory)
        }
        let bundle = Bundle(for: Self.self)
        for name in ["GalleryDetail", "GalleryDetailAlt", "GallerySinglePage", "FrontPageList"] {
            let source = try XCTUnwrap(bundle.url(forResource: name, withExtension: "html"))
            try FileManager.default.copyItem(at: source, to: directory.appending(path: "\(name).html"))
        }

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
