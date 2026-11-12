import UIKit
import XCTest

/// Search's Recently Viewed row when a gallery is viewed and lands at its front. The row keeps showing what the
/// reader was looking at: the galleries on screen stay where they are, and the new one waits before them.
@MainActor
final class RecentlyViewedAnchorUITests: XCTestCase {
    /// How far a card may sit from where it was, in points.
    private static let tolerance = 1.0
    private static let seeded = 6

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testANewGalleryAtTheFrontLeavesTheRowAtItsStart() throws {
        try verifyNewGalleryKeepsRow(scrolledFirst: false)
    }

    func testANewGalleryAtTheFrontLeavesAScrolledRowWhereItIs() throws {
        try verifyNewGalleryKeepsRow(scrolledFirst: true)
    }

    private func verifyNewGalleryKeepsRow(scrolledFirst: Bool) throws {
        // Neutral titles of the test's own: the list fixture's are a real site's.
        let fixtures = try StubFixtureCopy(for: self, named: "RecentlyViewed")
        try fixtures.retitle(listNamed: "FrontPageList.html", { index, _ in "Quiet Harbor \(index + 1)" })
        try fixtures.neutralizeUploaders()
        try fixtures.neutralizeDetail()
        // Every layout of a Recently Viewed card is logged, so the test sees the frames in between as well as the one
        // the row settles on.
        let frameLog = FrameLog(url: fixtures.root.appending(path: "recent-frames.log"))
        let app = XCUIApplication()
        try app.launchStubbed(extraEnvironment: [
            "EHPANDA_AUTOMATION_TAB": "home", UITestConstants.fixtureDirectoryEnvironmentKey: fixtures.root.path(),
            "EHPANDA_UITEST_RECENT_FRAME_LOG": frameLog.url.path()
        ])
        app.requireForeground()
        defer { app.terminate() }

        let covers = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home_front_page_title_"))
        XCTAssertTrue(covers.firstMatch.waitForExistence(timeout: 20), "Front Page has no cover.")
        clearHistory(app)
        app.tabBars.buttons["Home"].tap()
        var opened = Set<String>()
        for _ in 0..<Self.seeded { openUnseenCover(app, covers: covers, opened: &opened) }
        app.tabBars.buttons["Search"].tap()
        XCTAssertTrue(
            Polling.wait { self.recentlyViewed(app).cards.count == Self.seeded },
            "Recently Viewed does not show the \(Self.seeded) galleries seen."
        )
        settle(app)

        if scrolledFirst { swipeRow(app, to: .left) }
        let before = recentlyViewed(app)
        let anchor = try XCTUnwrap(before.cards.first(where: { $0.minX >= 0 }), "No card is fully on screen.")
        attach(app, "before")
        // The leading card is the one the row is anchored on: the first whose edge is on screen.
        let resting = frameLog.latest()
        let anchorID = try XCTUnwrap(
            resting.filter({ $0.value >= 0 }).min(by: { $0.value < $1.value })?.key, "The frame log has no card."
        )
        let anchorX = try XCTUnwrap(resting[anchorID])
        XCTAssertEqual(anchorX, anchor.minX, accuracy: Self.tolerance, "The frame log and the screen disagree.")
        let mark = frameLog.count

        // A gallery not seen yet is viewed from Home and the Search tab comes back.
        app.tabBars.buttons["Home"].tap()
        openUnseenCover(app, covers: covers, opened: &opened)
        app.tabBars.buttons["Search"].tap()
        XCTAssertTrue(
            Polling.wait { self.recentlyViewed(app).cards.count == Self.seeded + 1 },
            "Recently Viewed did not gain the gallery just seen."
        )
        settle(app)
        attach(app, "after")

        // No frame in between: from the tap back to the settled row, the leading card is laid out where it was. The
        // screen takes what each run loop turn leaves behind, so a turn is a frame: a layout that a later layout in the
        // same turn replaces never reaches it, and the last one of each turn is the card as the screen can see it.
        let lines = frameLog.lines(after: mark)
        let log = XCTAttachment(string: lines.map(\.description).joined(separator: "\n"))
        log.name = "Card layouts, by run loop turn"
        log.lifetime = .keepAlways
        add(log)
        let turns = Dictionary(grouping: lines.filter({ $0.id == anchorID }), by: \.turn)
        let seen = turns.keys.sorted().compactMap({ turns[$0]?.last?.edge })
        let moved = seen.filter({ abs($0 - anchorX) > Self.tolerance })
        XCTAssertTrue(
            moved.isEmpty,
            "The leading card was on screen away from \(anchorX): \(seen.map({ String(format: "%.1f", $0) }))."
        )

        let after = recentlyViewed(app)
        let kept = try XCTUnwrap(
            after.cards.first(where: { $0.title == anchor.title }), "\(anchor.title) is no longer in the row."
        )
        XCTAssertEqual(
            kept.minX, anchor.minX, accuracy: Self.tolerance,
            "\(anchor.title) moved from \(anchor.minX) to \(kept.minX) when a gallery was added before it."
        )
        let front = try XCTUnwrap(after.cards.first)
        XCTAssertNotEqual(front.title, anchor.title, "The gallery just seen must be in front of the one kept.")
        XCTAssertLessThan(front.minX, anchor.minX, "The new gallery must lie before the kept one.")

        // The new gallery is not lost: scrolling back brings it in, resting at the row's inset.
        func newCard() -> Card? {
            recentlyViewed(app).cards.first(where: { $0.title == front.title })
        }
        var swipes = 0
        while swipes < 4, (newCard()?.minX ?? -1) < 0 {
            swipeRow(app, to: .right)
            swipes += 1
        }
        let arrived = try XCTUnwrap(newCard())
        XCTAssertEqual(arrived.minX, 16, accuracy: Self.tolerance, "\(front.title) did not come back to the inset.")
        attach(app, "scrolled back")
    }

    // MARK: Driving

    /// Opens the first cover this test has not opened and visible, then returns to Home.
    private func openUnseenCover(_ app: XCUIApplication, covers: XCUIElementQuery, opened: inout Set<String>) {
        var tries = 0
        while tries < 12 {
            let candidate = covers.allElementsBoundByIndex.first(where: {
                !opened.contains($0.identifier) && $0.isHittable
            })
            if let candidate {
                opened.insert(candidate.identifier)
                candidate.tap()
                app.returnFromGalleryDetail()
                _ = app.staticTexts["never-present"].waitForExistence(timeout: 1)
                return
            }
            // The wall is a row to swipe along: bring the covers beyond the screen into reach.
            let window = app.windows.firstMatch.frame
            let rowY = min(max(covers.firstMatch.frame.midY, window.height * 0.3), window.height * 0.8)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            let from = origin.withOffset(CGVector(dx: window.width * 0.85, dy: rowY))
            let to = origin.withOffset(CGVector(dx: window.width * 0.15, dy: rowY))
            from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
            tries += 1
        }
        XCTFail("No cover left to open.")
    }

    /// Empties Search's Recently Viewed, which a simulator keeps from one launch to the next.
    private func clearHistory(_ app: XCUIApplication) {
        app.tabBars.buttons["Search"].tap()
        let remove = app.buttons["search-remove-all-galleries"]
        guard remove.waitForExistence(timeout: 10) else { return XCTFail("Search has no Recently Viewed.") }
        guard remove.isEnabled else { return }
        remove.tap()
        // Not either section's own Remove All, which open the dialogs.
        let confirm = app.buttons.matching(
            NSPredicate(format: "label == %@ AND NOT identifier BEGINSWITH %@", "Remove All", "search-remove-all")
        ).firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 10), "The Remove All dialog did not open.")
        confirm.tap()
        XCTAssertTrue(Polling.wait { !remove.isEnabled }, "Recently Viewed was not emptied.")
    }

    private func settle(_ app: XCUIApplication) {
        _ = app.staticTexts["never-present"].waitForExistence(timeout: 2)
    }

    private enum Direction { case left, right }

    /// Swipes the Recently Viewed row along, from a point on its first card.
    private func swipeRow(_ app: XCUIApplication, to direction: Direction) {
        let row = recentlyViewed(app)
        let window = app.windows.firstMatch.frame
        let rowY = row.cards.first.map({ $0.midY }) ?? window.midY
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let from = origin.withOffset(CGVector(dx: window.width * (direction == .left ? 0.8 : 0.2), dy: rowY))
        let to = origin.withOffset(CGVector(dx: window.width * (direction == .left ? 0.35 : 0.65), dy: rowY))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
        settle(app)
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Recently Viewed \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: Reading

    /// The log the row's cards write, one line per layout that put a card's leading edge somewhere new, with the
    /// run loop turn it happened in.
    private struct FrameLog {
        let url: URL

        var allLines: [FrameLogLine] {
            guard let data = FileManager.default.contents(atPath: url.path()),
                  let text = String(data: data, encoding: .utf8) else { return [] }
            return text.split(separator: "\n").compactMap({ line in
                let parts = line.split(separator: " ")
                guard parts.count == 4, let time = Double(parts[0]), let turn = Int(parts[1]),
                      let edge = Double(parts[3]) else { return nil }
                return FrameLogLine(time: time, turn: turn, id: String(parts[2]), edge: edge)
            })
        }

        var count: Int { allLines.count }

        func lines(after mark: Int) -> [FrameLogLine] { Array(allLines.dropFirst(mark)) }

        /// Where each card was last laid out.
        func latest() -> [String: Double] {
            allLines.reduce(into: [:], { $0[$1.id] = $1.edge })
        }
    }

    private struct Card {
        let title: String
        let minX: Double
        let midY: Double
    }

    private struct Row {
        /// The row's cards in the order they lie, left to right, whether or not they are on screen.
        let cards: [Card]
    }

    /// Reads the row from one snapshot of the app: every button below the Recently Viewed heading that is named by
    /// one of the test's titles.
    private func recentlyViewed(_ app: XCUIApplication) -> Row {
        let snapshot: any XCUIElementSnapshot
        do {
            snapshot = try app.snapshot()
        } catch {
            XCTFail("The app could not be read: \(error)")
            return Row(cards: [])
        }
        var headingBottom: Double?
        var cards: [Card] = []
        let title = /Quiet Harbor [0-9]+/
        func collect(_ element: any XCUIElementSnapshot) {
            if element.label == "Recently Viewed", headingBottom == nil { headingBottom = element.frame.maxY }
            if element.elementType == .button, let match = element.label.firstMatch(of: title),
               let bottom = headingBottom, element.frame.minY >= bottom - 1 {
                cards.append(Card(title: String(match.output), minX: element.frame.minX, midY: element.frame.midY))
            }
            element.children.forEach(collect)
        }
        collect(snapshot)
        return Row(cards: cards.sorted(by: { $0.minX < $1.minX }))
    }
}

private struct FrameLogLine: CustomStringConvertible {
    let time: Double
    let turn: Int
    let id: String
    let edge: Double

    var description: String { String(format: "%.3f turn %d %@ %.1f", time, turn, id, edge) }
}
