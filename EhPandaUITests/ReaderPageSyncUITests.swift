import XCTest

/// Changes the reader's page by every route a UI test can drive and requires, after each, that the
/// panel's indicator and the page on screen name the same page (see `ReaderPageProbe` for why both
/// sides are read). The routes are scrolling, the slider, the pager's tap zones, auto-play, the
/// status bar's scroll to the top, and entering the reader, which seeds the page from a link or
/// from the progress saved on leaving.
///
/// One route is not here because XCTest cannot drive it: an assistive technology's own scrolling,
/// which is what Phase 16 W-38 was found with. XCTest neither turns VoiceOver on nor issues its
/// Move to Next Item, so nothing below sees that route. W-38 was closed on the owner-approved
/// native VoiceOver recording documented in `16-W38-ROOT-CAUSE.md`.
///
/// Each route runs under the vertical strip and the left-to-right pager in one launch, switching
/// through the Reading Setting sheet. The direction persists between launches, so every test
/// states it, and ends on the default so a later suite opens the reader it expects.
@MainActor
final class ReaderPageSyncUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testThePagesAreOneElementReadingTheirPage() throws {
        try underEachDirection { reader, _, start in
            reader.requireOnePagesElement(reading: start)
        }
    }

    func testScrollingKeepsTheIndicatorOnThePageShown() throws {
        try underEachDirection { reader, direction, start in
            reader.scrollForward(under: direction)
            try reader.requirePage("After scrolling the \(direction.rawValue) reader", where: { $0 > start })
        }
    }

    func testTheSliderLandsOnThePageItNames() throws {
        try underEachDirection { reader, direction, start in
            // Far enough from either end of the track that the two directions, one after the
            // other in the same launch, both have to move.
            let position: CGFloat = direction == .vertical ? 0.4 : 0.7
            reader.dragSlider(toNormalizedPosition: position)
            try reader.requirePage(
                "After dragging the slider of the \(direction.rawValue) reader",
                where: { abs($0 - start) > 10 }
            )
        }
    }

    func testThePagersTapZoneTurnsOnePage() throws {
        let reader = try openReader()
        reader.setDirection(.leftToRight)
        let start = try reader.requirePage("On entering the pager")

        reader.tapNextPageZone()
        try reader.requirePage("After tapping the pager's next-page zone", where: { $0 == start + 1 })

        reader.setDirection(.vertical)
    }

    /// The status bar shows while the panel does, and tapping it scrolls the strip to its first
    /// page. SwiftUI reports no scroll phase for that scroll, so the indicator has to follow the
    /// strip's position rather than wait for a scroll to come to rest. The scroll is vertical
    /// only, so the pager has no such route.
    func testTheStatusBarScrollsTheStripToItsFirstPageAndTheIndicatorFollows() throws {
        let reader = try openReader()
        reader.setDirection(.vertical)
        reader.dragSlider(toNormalizedPosition: 0.5)
        try reader.requirePage("After dragging the slider", where: { $0 > 10 })

        reader.tapStatusBar()
        try reader.requirePage("After tapping the status bar", where: { $0 == 1 })
    }

    /// Auto-play at its shortest interval, on the real clock: a page turn has an animation to
    /// finish, and a second is what a reader can actually choose. `AutoPlayHandlerTests` pins the
    /// cadence itself against a test clock.
    func testAutoPlayTurnsThePageAndKeepsTheIndicatorOnIt() throws {
        try underEachDirection { reader, direction, start in
            reader.selectAutoPlay("1 second")
            try reader.requirePage(
                "While auto-play turns the \(direction.rawValue) reader",
                timeout: 15,
                where: { $0 >= start + 2 }
            )
            reader.selectAutoPlay("Off")
            try reader.requirePage("After auto-play stopped in the \(direction.rawValue) reader")
        }
    }

    /// Leaving the landscape reader saves the page; reading again after restoring portrait
    /// seeds the reader from it. Settings and the indicator must remain usable in landscape.
    func testReadingAgainResumesOnThePageLeft() throws {
        let device = XCUIDevice.shared
        device.orientation = .landscapeLeft
        // A failed check stops the test without running a `defer`; the teardown block still restores portrait for
        // the tests that follow.
        addTeardownBlock {
            device.orientation = .portrait
        }

        let reader = try openReader()
        reader.setDirection(.vertical)
        reader.dragSlider(toNormalizedPosition: 0.5)
        let left = try reader.requirePage("After dragging the slider", where: { $0 > 10 })

        let app = reader.app
        app.buttons["Close"].firstMatch.tapWhenHittable("Reader Close")
        let readButton = app.buttons["Read"].firstMatch
        XCTAssertTrue(readButton.waitForExistence(timeout: 10), "Gallery Detail did not expose Read.")
        XCTAssertTrue(
            app.buttons[UITestConstants.primaryMarkerTitle].waitForExistence(timeout: 10),
            "Closing the reader did not return to Gallery Detail."
        )

        let restorationStart = ContinuousClock.now
        device.orientation = .portrait
        readButton.tapWhenHittable("Gallery Detail Read after portrait restoration")
        XCTAssertLessThan(
            ContinuousClock.now - restorationStart,
            Duration.seconds(15),
            "Portrait restoration exceeded the 15-second screen-readiness budget."
        )
        app.requireElement("reading_view")
        reader.showPanel()

        try reader.requirePage("On reading again", where: { $0 == left })
    }

    /// Turning the device after a resume, with no jump since, keeps the page named and at the top of the screen. After
    /// each turn the number of the page's placeholder lies exactly where a resume in that orientation puts it, and a
    /// resume puts the page's top on the screen's top row. `AdvancedList` positions its page again after each change of
    /// its width.
    func testTurningTheDeviceKeepsTheResumedPageAtTheTop() throws {
        let device = XCUIDevice.shared
        device.orientation = .portrait
        // A failed check stops the test without running a `defer`; the teardown block still restores portrait for
        // the tests that follow.
        addTeardownBlock {
            device.orientation = .portrait
        }

        let reader = try openReader()
        reader.setDirection(.vertical)
        reader.dragSlider(toNormalizedPosition: 0.3)
        let page = try reader.requirePage("After dragging the slider", where: { $0 > 5 })
        readAgain(reader)
        let portrait = try reader.requirePlaceholderNumber(of: page, "On resuming in portrait")

        device.orientation = .landscapeLeft
        let firstLandscape = try reader.requirePlaceholderNumber(of: page, "Turned to landscape")
        device.orientation = .portrait
        let portraitAgain = try reader.requirePlaceholderNumber(of: page, "Turned back to portrait")
        device.orientation = .landscapeLeft
        let secondLandscape = try reader.requirePlaceholderNumber(of: page, "Turned to landscape again")
        readAgain(reader)
        let landscape = try reader.requirePlaceholderNumber(of: page, "On resuming in landscape")

        XCTAssertEqual(firstLandscape, landscape, "Turned to landscape")
        XCTAssertEqual(portraitAgain, portrait, "Turned back to portrait")
        XCTAssertEqual(secondLandscape, landscape, "Turned to landscape again")
    }

    // MARK: Helpers

    /// Opens the fixture gallery's reader through its page link and shows its panel. The reader
    /// is under whatever direction the last launch left, so the caller sets one next.
    private func openReader() throws -> ReaderPageProbe {
        let app = XCUIApplication()
        let pageURL = try XCTUnwrap(UITestConstants.singlePageURL(scheme: "ehpanda"))
        try app.openCold(pageURL)
        app.requireForeground()
        app.requireElement("reading_view")
        let reader = ReaderPageProbe(app: app)
        reader.showPanel()
        return reader
    }

    /// Closes the reader and reads the gallery again, which resumes on the page left, and shows the panel.
    private func readAgain(_ reader: ReaderPageProbe) {
        let app = reader.app
        app.buttons["Close"].firstMatch.tapWhenHittable("Reader Close")
        let readButton = app.buttons["Read"].firstMatch
        XCTAssertTrue(readButton.waitForExistence(timeout: 10), "Gallery Detail did not expose Read.")
        readButton.tapWhenHittable("Gallery Detail Read")
        app.requireElement("reading_view")
        reader.showPanel()
    }

    /// Runs `route` under every direction in one launch. Switching direction is itself an entry
    /// into a reader surface, so the page it opens on is required to be in step before the route
    /// starts, and is handed to the route as the page it starts from.
    private func underEachDirection(
        _ route: (ReaderPageProbe, ReaderPageProbe.Direction, Int) throws -> Void
    ) throws {
        let reader = try openReader()
        for direction in ReaderPageProbe.Direction.allCases {
            reader.setDirection(direction)
            let start = try reader.requirePage("On entering the \(direction.rawValue) reader")
            try route(reader, direction, start)
        }
        reader.setDirection(.vertical)
    }
}
