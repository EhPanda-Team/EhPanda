import UIKit
import XCTest

/// Exercises the native iOS 27 surfaces that replaced the migration-era toolbar and
/// accessibility workarounds. The selectors are app behavior (labels, titles and the
/// native overflow identifier), rather than source implementation details.
@MainActor
final class IOS27MigrationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSearchToolbarSearchAndTitleRecoveryAtStandardSize() throws {
        try exerciseSearchSurface(preferredContentSizeCategory: .large)
    }

    func testSearchToolbarSearchAndTitleRecoveryAtAX5() throws {
        try exerciseSearchSurface(
            preferredContentSizeCategory: UIContentSizeCategory.accessibilityExtraExtraExtraLarge
        )
    }

    func testDetailOverflowDisabledActionsAndSharePresentation() throws {
        let app = XCUIApplication()
        let galleryURL = try XCTUnwrap(UITestConstants.galleryURL(scheme: "ehpanda"))
        try app.openCold(galleryURL)
        app.requireForeground()
        app.requireElement("detail_view", matching: .scrollView)
        XCTAssertTrue(
            app.buttons[UITestConstants.primaryMarkerTitle].waitForExistence(timeout: 15),
            "The fixture gallery detail did not render."
        )

        tap(moreButton(in: app), named: "Detail More")

        let archives = app.buttons["Archives"].firstMatch
        XCTAssertTrue(archives.waitForExistence(timeout: 5), "More did not expose Archives.")
        XCTAssertFalse(archives.isEnabled, "Archives must remain disabled while logged out.")

        let torrents = app.buttons["Torrents (1)"].firstMatch
        XCTAssertTrue(torrents.waitForExistence(timeout: 5), "More did not expose Torrents (1).")
        XCTAssertTrue(torrents.isEnabled, "Torrents (1) must remain enabled.")

        let share = app.buttons["Share"].firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 5), "More did not expose Share.")
        XCTAssertTrue(share.isEnabled, "Share must remain enabled.")
        tap(share, named: "Share")

        let activity = app.collectionViews["activityCollectionView"]
        XCTAssertTrue(
            activity.waitForExistence(timeout: 10),
            "Share did not present the system activity collection view."
        )
        let close = app.buttons["header.closeButton"].firstMatch
        tap(close, named: "Activity Close")
        app.requireElement("detail_view", matching: .scrollView)
    }

    func testReaderOverflowSettingsCloseAndIndicatorInLandscape() throws {
        let device = XCUIDevice.shared
        device.orientation = .landscapeLeft
        var restoredToPortrait = false
        defer {
            if !restoredToPortrait {
                device.orientation = .portrait
            }
        }

        let app = XCUIApplication()
        let galleryURL = try XCTUnwrap(UITestConstants.galleryURL(scheme: "ehpanda"))
        try app.openCold(galleryURL)
        app.requireForeground()
        app.requireElement("detail_view", matching: .scrollView)

        let read = app.buttons["Read"].firstMatch
        XCTAssertTrue(read.waitForExistence(timeout: 15), "Gallery Detail did not expose Read.")
        tap(read, named: "Read")
        app.requireElement("reading_view")
        let probe = ReaderPageProbe(app: app)
        probe.showPanel()
        XCTAssertTrue(
            app.staticTexts.matching(identifier: "reading_page_indicator").firstMatch.exists,
            "The reader page indicator was not visible in landscape."
        )
        XCTAssertTrue(
            app.buttons["Close"].firstMatch.exists,
            "The reader close action was not visible in landscape."
        )

        let readingView = app.descendants(matching: .any).matching(identifier: "reading_view").firstMatch
        tap(moreButton(in: readingView), named: "Reader More")
        tap(app.buttons["Reading Setting"].firstMatch, named: "Reading Setting")

        let settingsBar = app.navigationBars["Reading"].firstMatch
        XCTAssertTrue(settingsBar.waitForExistence(timeout: 10), "Reading Setting did not open.")
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Direction"))
                .firstMatch.waitForExistence(timeout: 5),
            "Reading Setting did not expose its Direction control."
        )
        if UIDevice.current.userInterfaceIdiom == .pad {
            settingsBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(
                    forDuration: 0.05,
                    thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
                )
            XCTAssertTrue(
                settingsBar.waitForNonExistence(timeout: 5),
                "The iPad Reading Setting sheet did not dismiss."
            )
        } else {
            let settingsClose = settingsBar.buttons["Close"].firstMatch
            tap(settingsClose, named: "Reading Setting Close")
        }

        app.requireElement("reading_view")
        XCTAssertTrue(
            app.staticTexts.matching(identifier: "reading_page_indicator").firstMatch.waitForExistence(timeout: 5),
            "The reader indicator did not return with the reader."
        )
        tap(app.buttons["Close"].firstMatch, named: "Reader Close")
        XCTAssertTrue(
            app.buttons[UITestConstants.primaryMarkerTitle].waitForExistence(timeout: 10),
            "Closing the reader did not return to Gallery Detail."
        )

        let restorationStart = ContinuousClock.now
        device.orientation = .portrait
        restoredToPortrait = true
        let readBecomesHittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: read
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [readBecomesHittable], timeout: 10),
            .completed,
            "Gallery Detail Read did not become hittable after portrait restoration."
        )
        let restorationDuration = ContinuousClock.now - restorationStart
        XCTAssertLessThan(
            restorationDuration,
            Duration.seconds(15),
            "Portrait restoration exceeded the 15-second screen-readiness budget."
        )
    }

    func testHomeCarouselKeepsCenteredGalleryAcrossRotation() throws {
        let device = XCUIDevice.shared
        device.orientation = .portrait
        var restoredToPortrait = false
        defer {
            if !restoredToPortrait {
                device.orientation = .portrait
            }
        }

        let app = XCUIApplication()
        try app.launchStubbed()
        app.requireForeground()
        let carousel = try homeCarousel(in: app)
        waitForHomeCarousel(carousel)
        let portraitButton = try centeredCarouselButton(in: carousel)
        let expectedLabel = portraitButton.label
        XCTAssertFalse(expectedLabel.isEmpty, "The centered Home carousel gallery had no label.")

        let landscapeStart = ContinuousClock.now
        device.orientation = .landscapeLeft
        waitForHomeCarousel(carousel)
        let landscapeButton = try centeredCarouselButton(in: carousel)
        let landscapeLabel = landscapeButton.label
        let landscapeDuration = ContinuousClock.now - landscapeStart
        XCTAssertLessThan(
            landscapeDuration,
            Duration.seconds(15),
            "Home carousel landscape restoration exceeded the 15-second budget."
        )
        XCTAssertEqual(
            landscapeLabel,
            expectedLabel,
            "Landscape rotation changed the centered Home carousel gallery."
        )

        let portraitStart = ContinuousClock.now
        device.orientation = .portrait
        restoredToPortrait = true
        waitForHomeCarousel(carousel)
        let restoredPortraitButton = try centeredCarouselButton(in: carousel)
        let portraitLabel = restoredPortraitButton.label
        let portraitDuration = ContinuousClock.now - portraitStart
        XCTAssertLessThan(
            portraitDuration,
            Duration.seconds(15),
            "Home carousel portrait restoration exceeded the 15-second budget."
        )
        XCTAssertEqual(
            portraitLabel,
            expectedLabel,
            "Portrait rotation changed the centered Home carousel gallery."
        )
    }

    private func exerciseSearchSurface(
        preferredContentSizeCategory: UIContentSizeCategory?
    ) throws {
        let app = XCUIApplication()
        if let preferredContentSizeCategory {
            app.launchArguments += [
                "-UIPreferredContentSizeCategoryName",
                preferredContentSizeCategory.rawValue
            ]
        }
        try app.launchStubbed(extraEnvironment: ["EHPANDA_AUTOMATION_TAB": "search"])
        app.requireForeground()
        XCTAssertTrue(
            app.navigationBars["Search"].firstMatch.waitForExistence(timeout: 15),
            "Search did not render its native title."
        )

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 10), "Search did not expose its native search field.")
        XCTAssertTrue(searchField.isHittable, "Search field was hidden on entry.")
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(searchField.isHittable, "Scrolling hid the Search root field.")
        app.scrollViews.firstMatch.swipeDown()
        XCTAssertTrue(searchField.isHittable, "Returning to the top hid the Search root field.")
        XCTAssertTrue(app.navigationBars["Search"].buttons["Filters"].isHittable)
        tap(app.navigationBars["Search"].buttons["Quick Search"], named: "Quick Search")
        XCTAssertTrue(
            app.navigationBars["Quick Search"].firstMatch.waitForExistence(timeout: 10),
            "Quick Search did not open from the Search root toolbar."
        )
        tap(app.buttons["New Word"].firstMatch, named: "New Word")
        XCTAssertTrue(
            app.navigationBars["New Word"].firstMatch.waitForExistence(timeout: 10),
            "New Word editor did not open from Quick Search."
        )
        XCTAssertTrue(
            app.textFields.firstMatch.waitForExistence(timeout: 5),
            "New Word did not expose its name field."
        )
        XCTAssertTrue(
            app.textViews.firstMatch.waitForExistence(timeout: 5),
            "New Word did not expose its content editor."
        )

        tap(app.navigationBars["New Word"].buttons["Quick Search"].firstMatch, named: "New Word Back")
        tap(app.buttons["Cancel"].firstMatch, named: "Quick Search Cancel")
        XCTAssertTrue(
            app.navigationBars["Search"].firstMatch.waitForExistence(timeout: 10),
            "Returning from Quick Search did not restore Search's title."
        )

        XCTAssertTrue(searchField.waitForExistence(timeout: 10), "Search did not expose its native search field.")
        tap(searchField, named: "Search Field")
        searchField.typeText("artist:fixture")
        XCTAssertEqual(searchField.value as? String, "artist:fixture", "The search field did not accept input.")

        let clear = app.buttons["Clear text"].firstMatch
        XCTAssertTrue(clear.waitForExistence(timeout: 5), "Search did not expose its native clear action.")
        tap(clear, named: "Search Clear")
        XCTAssertTrue(
            clear.waitForNonExistence(timeout: 5),
            "The native clear action remained visible after clearing Search."
        )
        let clearedValue = try XCTUnwrap(searchField.value as? String)
        let placeholder = searchField.placeholderValue ?? ""
        XCTAssertTrue(
            clearedValue.isEmpty || clearedValue == placeholder,
            "The native clear action left Search containing \(clearedValue)."
        )
        tap(searchField, named: "Search Field After Clear")
        searchField.typeText("fixture\n")
        XCTAssertTrue(
            app.navigationBars["fixture"].firstMatch.waitForExistence(timeout: 15),
            "Submitting the cleared Search field did not open fixture results."
        )
        XCTAssertTrue(
            app.navigationBars["fixture"].buttons["Filters"].isHittable,
            "Search results did not expose Filters directly in the toolbar."
        )
        tap(
            app.navigationBars["fixture"].buttons["Search"].firstMatch,
            named: "Search Results Back"
        )
        XCTAssertTrue(
            app.navigationBars["Search"].firstMatch.waitForExistence(timeout: 10),
            "Returning from Search results did not restore Search's title."
        )
    }

    private func homeCarousel(in app: XCUIApplication) throws -> XCUIElement {
        let query = app.scrollViews.matching(identifier: "home_carousel")
        let carousel = query.element(boundBy: 0)
        XCTAssertTrue(
            carousel.waitForExistence(timeout: 15),
            "Home did not expose its carousel scroll view."
        )
        XCTAssertEqual(query.count, 1, "Home exposed an unexpected number of carousel scroll views.")
        return carousel
    }

    private func waitForHomeCarousel(
        _ carousel: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: carousel
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [ready], timeout: 10),
            .completed,
            "Home carousel did not settle after rotation.",
            file: file,
            line: line
        )
    }

    private func centeredCarouselButton(in carousel: XCUIElement) throws -> XCUIElement {
        let viewport = carousel.frame
        let visibleButtons = carousel.buttons.allElementsBoundByIndex.filter { button in
            let frame = button.frame
            return !button.label.isEmpty
                && frame.width > 0
                && frame.height > 0
                && frame.intersects(viewport)
        }
        let nearest = visibleButtons.min { left, right in
            abs(left.frame.midX - viewport.midX) < abs(right.frame.midX - viewport.midX)
        }
        let centered = try XCTUnwrap(nearest, "Home carousel had no visible labeled gallery button.")
        XCTAssertEqual(
            centered.frame.midX,
            viewport.midX,
            accuracy: 1,
            "The selected Home carousel card was not centered in its viewport."
        )
        return centered
    }

    private func moreButton(in container: XCUIElement) -> XCUIElement {
        container.descendants(matching: .button).matching(
            NSPredicate(
                format: "identifier == %@ AND label == %@",
                "OverflowBarButtonItem",
                "More"
            )
        ).firstMatch
    }

    private func tap(
        _ element: XCUIElement,
        named name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(name) did not appear.", file: file, line: line)
        let becomesHittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [becomesHittable], timeout: 10),
            .completed,
            "\(name) was not hittable.",
            file: file,
            line: line
        )
        element.tap()
    }
}
