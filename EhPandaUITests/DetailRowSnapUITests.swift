import UIKit
import XCTest

/// Where the gallery detail's horizontal rows (Previews, Comments) come to rest, as the Home rows do. Every stop
/// but the last lines an item's leading edge up with the inset the first item rests at. The last stop is the end of
/// the content, where the last item's trailing edge sits on the trailing inset, and the item before it may be cut
/// off on the left.
///
/// Each case scrolls its row into view and swipes it gently along to its end, reading the accessibility tree at
/// every stop, then back to the start. The stops are kept as screenshots.
@MainActor
final class DetailRowSnapUITests: XCTestCase {
    private enum Row {
        case previews
        case comments

        var heading: String {
            switch self {
            case .previews: "Previews"
            case .comments: "Comments"
            }
        }

        func isItem(_ element: any XCUIElementSnapshot) -> Bool {
            switch self {
            case .previews: element.elementType == .button && element.label.hasPrefix("Page ")
            case .comments: element.identifier.hasPrefix("comment_card_")
            }
        }
    }

    /// How far an item's edge may sit from the inset, in points.
    private static let tolerance = 1.0

    override func setUpWithError() throws {
        // Every rest is measured and reported, even after one is off.
        continueAfterFailure = true
    }

    func testPreviewsSnapToTheirColumns() throws {
        try verify(.previews)
    }

    func testCommentsSnapToTheirCards() throws {
        try verify(.comments)
    }

    private func verify(_ row: Row) throws {
        let fixtures = try StubFixtureCopy(for: self, named: "DetailRowSnap")
        try fixtures.neutralizeDetail()
        let app = XCUIApplication()
        let url = try XCTUnwrap(UITestConstants.galleryURL(scheme: "ehpanda"))
        try app.openCold(url, extraEnvironment: [UITestConstants.fixtureDirectoryEnvironmentKey: fixtures.root.path()])
        app.requireForeground()
        defer { app.terminate() }
        let detail = app.requireElement("detail_view", matching: .scrollView)

        let heading = app.staticTexts[row.heading].firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 20), "\(row.heading) is missing.")
        var scrolls = 0
        while (!heading.isHittable || heading.frame.minY > app.windows.firstMatch.frame.height * 0.45), scrolls < 10 {
            detail.swipeUp(velocity: .slow)
            scrolls += 1
        }
        XCTAssertTrue(heading.isHittable, "\(row.heading) did not scroll into view.")
        // Rows load after their data; wait for the first page to settle.
        _ = app.staticTexts["never-present"].waitForExistence(timeout: 3)

        let window = app.windows.firstMatch.frame
        let headingFrame = heading.frame
        func read() -> Reading {
            reading(app, of: row, below: headingFrame.maxY, width: window.width)
        }
        var stops: [(name: String, reading: Reading)] = []
        func rest(_ name: String, _ direction: Direction?) -> Reading {
            if let direction { swipe(app, row: stops.last?.reading ?? read(), direction: direction, window: window) }
            // A row still coasting reads differently the next time: it has come to rest when two readings agree.
            var stop = read()
            var samples = 0
            while samples < 8 {
                let again = read()
                if again.signature == stop.signature { break }
                stop = again
                samples += 1
            }
            let shot = XCTAttachment(screenshot: app.screenshot())
            shot.name = "\(row.heading)-\(name)"
            shot.lifetime = .keepAlways
            add(shot)
            stops.append((name, stop))
            return stop
        }

        let start = rest("rest", nil)
        let inset = try XCTUnwrap(start.leading.min(), "\(row.heading) shows no item at rest.")
        var previous = start
        for step in 1...24 {
            let stop = rest("left\(step)", .left)
            if step == 1 {
                XCTAssertNotEqual(stop.signature, previous.signature, "\(row.heading): the first swipe moved nothing.")
            }
            // A swipe that leaves the row where it was has found its end.
            if stop.signature == previous.signature { break }
            previous = stop
        }
        XCTAssertGreaterThan(stops.count, 2, "\(row.heading) does not scroll.")

        let endSignature = stops.last?.reading.signature
        for stop in stops.dropFirst() {
            let isLast = stop.reading.signature == endSignature
            let nearest = stop.reading.leading.map({ abs($0 - inset) }).min() ?? .infinity
            let trailingGap = stop.reading.trailing.max().map({ window.width - inset - $0 }) ?? .infinity
            let line = "\(row.heading) \(stop.name): leading edges \(stop.reading.leading), inset \(inset), "
                + "last trailing edge \(stop.reading.trailing.max() ?? -1) of \(window.width)"
            let note = XCTAttachment(string: line)
            note.name = "\(row.heading)-\(stop.name) measure"
            note.lifetime = .keepAlways
            add(note)
            if isLast {
                XCTAssertLessThanOrEqual(abs(trailingGap), Self.tolerance, "End of \(line)")
            } else {
                XCTAssertLessThanOrEqual(nearest, Self.tolerance, "No item rests on the inset: \(line)")
            }
        }
    }

    private enum Direction { case left, right }

    /// A gentle swipe along the row: a drag of half the screen's width, at the default speed, that a snapping row
    /// settles on a column after.
    private func swipe(_ app: XCUIApplication, row: Reading, direction: Direction, window: CGRect) {
        let near = window.width * (direction == .left ? 0.8 : 0.2)
        let far = window.width * (direction == .left ? 0.3 : 0.7)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let from = origin.withOffset(CGVector(dx: near, dy: row.midY))
        let to = origin.withOffset(CGVector(dx: far, dy: row.midY))
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .default, thenHoldForDuration: 0)
    }

    private struct Reading {
        /// The names and the leading and trailing edges of the items that reach the screen. A row that moves a whole
        /// item shows the same edges, so the names say which items they are.
        let names: [String]
        let leading: [Double]
        let trailing: [Double]
        let midY: Double

        var signature: String {
            zip(names, zip(leading, trailing))
                .map({ "\($0)@\(Int($1.0.rounded()))-\(Int($1.1.rounded()))" })
                .joined(separator: "|")
        }
    }

    /// The row's items on screen, read from one snapshot: every element of the row's kind below `top`.
    private func reading(_ app: XCUIApplication, of row: Row, below top: CGFloat, width: CGFloat) -> Reading {
        let snapshot: any XCUIElementSnapshot
        do {
            snapshot = try app.snapshot()
        } catch {
            XCTFail("The app could not be read: \(error)")
            return Reading(names: [], leading: [], trailing: [], midY: 0)
        }
        var items: [(name: String, frame: CGRect)] = []
        func collect(_ element: any XCUIElementSnapshot) {
            let frame = element.frame
            if row.isItem(element), frame.minY >= top - 1, frame.maxX > 0, frame.minX < width {
                items.append((element.identifier + element.label, frame))
            }
            element.children.forEach(collect)
        }
        collect(snapshot)
        items.sort(by: { $0.frame.minX < $1.frame.minX })
        return Reading(
            names: items.map(\.name), leading: items.map({ Double($0.frame.minX) }),
            trailing: items.map({ Double($0.frame.maxX) }), midY: Double(items.first?.frame.midY ?? 0)
        )
    }
}
