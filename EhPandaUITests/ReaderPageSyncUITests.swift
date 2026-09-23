import XCTest

/// Changes the reader's page by every route a UI test can drive and requires, after each, that the
/// panel's indicator and the page on screen name the same page (see `ReaderPageProbe` for why both
/// sides are read). The routes are scrolling, the slider, the pager's tap zones, auto-play, and
/// entering the reader, which seeds the page from a link or from the progress saved on leaving.
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
        defer { device.orientation = .portrait }

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
