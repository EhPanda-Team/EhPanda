import XCTest

/// Builds the reader's pager anew in the middle of reading, by each route that does so, and requires that the panel's
/// indicator and the page on screen still name the same page afterwards (Phase 17 gaps G1 and G2, D-19). The routes
/// are a forced refresh (Reload All Images), a change of reading direction while auto-play turns the pages, and a
/// switch between the two horizontal directions.
///
/// Each check reads both sides through `ReaderPageProbe`. The forced refresh also runs with
/// `EHPANDA_UITEST_DROP_INITIAL_IDLE=1`, which makes every pager drop the first rest it reports: a new pager's turns
/// and its page must then hold without that report (17-VERIFICATION.md R5-1). Like the page-sync suite, every test
/// states its direction and ends on the vertical default, which the next suite expects.
@MainActor
final class ReaderRebuildUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// G1, the forced-refresh path: a reload at a middle page, then one turn by the edge tap. The tap follows the
    /// reload at once, without waiting for the new pager to report its rest.
    func testReloadAllImagesThenATurnKeepsTheIndicatorOnThePageShown() throws {
        try reloadThenTurn()
    }

    /// The same route with every pager's first rest report dropped, so only the new generation's own reports can
    /// pass it (R5-1).
    func testReloadAllImagesThenATurnKeepsTheIndicatorOnThePageShownWithoutTheFirstIdleReport() throws {
        try reloadThenTurn(extraEnvironment: [UITestConstants.dropInitialIdleEnvironmentKey: "1"])
    }

    /// G1, the direction path: the direction changes right after auto-play has turned the pages. The change is made
    /// from the Reading Setting sheet, and presenting a sheet stops auto-play (`ReadingView`), so auto-play is then
    /// started again on the pager the change built. After its next tick, the indicator names the page shown.
    func testChangingDirectionDuringAutoPlayKeepsTheIndicatorOnThePageShown() throws {
        let reader = try openReader()
        reader.setDirection(.leftToRight)
        let start = try reader.requirePage("On entering the pager")

        reader.selectAutoPlay("1 second")
        let ticked = try reader.requirePage("While auto-play turns the pager", timeout: 15, where: { $0 > start })
        reader.setDirection(.rightToLeft)
        let switched = try reader.requirePage(
            "After changing the direction during auto-play",
            where: { $0 >= ticked }
        )
        reader.selectAutoPlay("1 second")
        try reader.requirePage(
            "At auto-play's next tick on the pager the change built",
            timeout: 15,
            where: { $0 > switched }
        )
        reader.selectAutoPlay("Off")
        try reader.requirePage("After auto-play stopped")

        reader.setDirection(.vertical)
    }

    /// G2: left to right, then right to left, then left to right again at a middle page. After each switch the
    /// indicator names the page shown, and the next-page zone of the new direction turns exactly one page.
    func testSwitchingLeftToRightAndRightToLeftKeepsThePageInSync() throws {
        let reader = try openReader()
        reader.setDirection(.leftToRight)
        var page = try reader.requirePage("On entering the pager")
        reader.dragSlider(toNormalizedPosition: 0.5)
        page = try reader.requirePage("After dragging the slider to a middle page", where: { abs($0 - page) > 10 })

        for direction in [ReaderPageProbe.Direction.rightToLeft, .leftToRight] {
            reader.setDirection(direction)
            let shown = page
            try reader.requirePage("After switching to \(direction.rawValue)", where: { $0 == shown })
            reader.tapNextPageZone(under: direction)
            page = try reader.requirePage(
                "After tapping the \(direction.rawValue) pager's next-page zone",
                where: { $0 == shown + 1 }
            )
        }

        reader.setDirection(.vertical)
    }

    // MARK: Helpers

    private func reloadThenTurn(extraEnvironment: [String: String] = [:]) throws {
        let reader = try openReader(extraEnvironment: extraEnvironment)
        reader.setDirection(.leftToRight)
        let start = try reader.requirePage("On entering the pager")
        reader.dragSlider(toNormalizedPosition: 0.5)
        let middle = try reader.requirePage(
            "After dragging the slider to a middle page",
            where: { abs($0 - start) > 10 }
        )

        reader.reloadAllImages()
        reader.tapNextPageZone()
        try reader.requirePage("After reloading all images and turning one page", where: { $0 == middle + 1 })

        reader.setDirection(.vertical)
    }

    /// Opens the fixture gallery's reader through its page link and shows its panel. The reader is under whatever
    /// direction the last launch left, so the caller sets one next.
    private func openReader(extraEnvironment: [String: String] = [:]) throws -> ReaderPageProbe {
        let app = XCUIApplication()
        let pageURL = try XCTUnwrap(UITestConstants.singlePageURL(scheme: "ehpanda"))
        try app.openCold(pageURL, extraEnvironment: extraEnvironment)
        app.requireForeground()
        app.requireElement("reading_view")
        let reader = ReaderPageProbe(app: app)
        reader.showPanel()
        return reader
    }
}
