import UIKit
import XCTest

/// Where a horizontal row comes to rest (UI-SPEC rev 1.8 follow-up): the first fully visible item's leading
/// edge sits on its section heading's leading edge, on the first page and after every swipe in either direction.
///
/// Each case drives one row (Home's Front Page wall, Toplists and More cards, Search's Recently Viewed) through
/// a rest, two swipes to the left, one to the right, then to the far end and back to the start. It reads a
/// screenshot at every rest and requires the item's leading edge within 0.5pt of the heading's. The rest frames
/// are kept as attachments.
@MainActor
final class HomeRowSnapUITests: XCTestCase {
    private enum Row: String {
        case frontPage = "Front Page"
        case rankings = "Toplists"
        case recentlyViewed = "Recently Viewed"
        case more = "More"
    }

    /// How far an item's leading edge may sit from the heading's, in points.
    private static let tolerance = 0.5

    override func setUpWithError() throws {
        // Every rest is measured and reported, even after one is off.
        continueAfterFailure = true
    }

    func testTheFrontPageWallRestsOnTheHeadingsEdge() throws {
        try verify(.frontPage)
    }

    func testTheToplistsRestOnTheHeadingsEdge() throws {
        try verify(.rankings)
    }

    func testRecentlyViewedRestsOnTheHeadingsEdge() throws {
        try verify(.recentlyViewed)
    }

    func testTheMoreCardsRestOnTheHeadingsEdge() throws {
        try verify(.more)
    }

    private func verify(_ row: Row) throws {
        // Neutral titles of the test's own: the list fixture's are a real site's.
        let fixtures = try StubFixtureCopy(for: self, named: "RowSnap")
        try fixtures.retitle(listNamed: "FrontPageList.html", { index, _ in "Quiet Harbor \(index + 1)" })
        let app = XCUIApplication()
        try app.launchStubbed(extraEnvironment: [
            "EHPANDA_AUTOMATION_TAB": "home", UITestConstants.fixtureDirectoryEnvironmentKey: fixtures.root.path()
        ])
        app.requireForeground()
        defer { app.terminate() }
        if row == .recentlyViewed {
            seedHistory(app)
            app.tabBars.buttons["Search"].tap()
        }
        let heading = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", row.rawValue))
            .firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 20), "\(row.rawValue) is missing.")
        // Bring the heading to the middle of the screen, a short drag at a time, so the row is clear of both the
        // navigation bar and the tab bar.
        let window = app.windows.firstMatch
        var scrolls = 0
        var lastTop = CGFloat.infinity
        while !heading.isHittable || heading.frame.minY > window.frame.height * 0.5, scrolls < 16 {
            // A page that cannot scroll further leaves the heading where it is: it is as high as it gets.
            if heading.isHittable, heading.frame.minY == lastTop { break }
            lastTop = heading.frame.minY
            let from = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            let to = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62))
            from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.3)
            scrolls += 1
        }
        XCTAssertTrue(heading.isHittable, "\(row.rawValue) did not scroll into view.")
        // Rows load after their data; wait for the first page to settle.
        _ = app.staticTexts["never-present"].waitForExistence(timeout: 3)

        // Read once: every element query is a fresh snapshot of the app, which costs seconds.
        let headingFrame = heading.frame
        let windowFrame = app.windows.firstMatch.frame
        var previous: String?
        var measured = 0

        /// Swipes (unless `direction` is `.none`), waits for the row to come to rest, then reads it.
        func rest(_ name: String, _ direction: Direction) -> String? {
            swipe(app, headingFrame: headingFrame, windowFrame: windowFrame, direction: direction)
            _ = app.staticTexts["never-present"].waitForExistence(timeout: 1.2)
            let shot = app.screenshot()
            let contents = visibleContents(app, band: CGRect(
                x: 0, y: headingFrame.maxY, width: windowFrame.width, height: 400
            ))
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = "\(row.rawValue)-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            let band = CGRect(x: 0, y: headingFrame.maxY + 45, width: windowFrame.width, height: 80)
            let page = CGPoint(x: windowFrame.midX, y: headingFrame.midY)
            guard let reading = RowReading(shot, band: band, pageColourAt: page) else {
                XCTFail("\(row.rawValue) \(name): no item found.")
                return nil
            }
            let difference = reading.leadingPoints - headingFrame.minX
            let line = "\(row.rawValue) \(name): item leading \(reading.leadingPixels) px "
                + "(\(reading.leadingPoints) pt), heading leading \(headingFrame.minX * reading.scale) px "
                + "(\(headingFrame.minX) pt), difference \(difference) pt"
            let note = XCTAttachment(string: line)
            note.name = "\(row.rawValue)-\(name) measure"
            note.lifetime = .keepAlways
            add(note)
            XCTAssertLessThanOrEqual(abs(difference), Self.tolerance, line)
            measured += 1
            return contents
        }

        // A swipe that leaves the row where it was proves nothing, so each one must move it.
        previous = rest("rest", .none)
        for (name, direction) in [("left1", Direction.left), ("left2", .left), ("right1", .right)] {
            let contents = rest(name, direction)
            XCTAssertNotEqual(contents, previous, "\(row.rawValue) \(name): the swipe moved nothing.")
            previous = contents
        }
        // Both ends: swipe on until the row stops moving, then back to where it started.
        for (name, direction) in [("end", Direction.left), ("start", .right)] {
            var swipes = 0
            while swipes < 16 {
                let contents = rest("\(name)\(swipes)", direction)
                swipes += 1
                let settled = contents == previous
                previous = contents
                if settled { break }
            }
            XCTAssertLessThan(swipes, 16, "\(row.rawValue) never reached its \(name).")
        }
        XCTAssertGreaterThan(measured, 4)
    }

    /// Opens a few galleries from Home's Front Page, so Search's Recently Viewed row has cards to scroll.
    private func seedHistory(_ app: XCUIApplication) {
        let covers = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home_front_page_title_"))
        XCTAssertTrue(covers.firstMatch.waitForExistence(timeout: 20), "Front Page has no cover.")
        var opened = 0
        for index in 0..<covers.count where opened < 5 {
            let cover = covers.element(boundBy: index)
            guard cover.isHittable else { continue }
            cover.tap()
            _ = app.staticTexts["never-present"].waitForExistence(timeout: 4)
            // The detail is pushed; its Back button sits at the top leading corner.
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 40, dy: 90)).tap()
            _ = app.staticTexts["never-present"].waitForExistence(timeout: 1.5)
            XCTAssertTrue(covers.element(boundBy: index).waitUntilHittable(timeout: 10), "Back did not return to Home.")
            opened += 1
        }
    }

    /// What the row shows: the label and position of every labelled element in `band`, read from one snapshot
    /// of the app. A screenshot cannot say, as the covers' placeholders animate.
    private func visibleContents(_ app: XCUIApplication, band: CGRect) -> String {
        let snapshot: any XCUIElementSnapshot
        do {
            snapshot = try app.snapshot()
        } catch {
            XCTFail("The app could not be read: \(error)")
            return ""
        }
        let screen = app.windows.firstMatch.frame
        var entries: [String] = []
        func collect(_ element: any XCUIElementSnapshot) {
            let frame = element.frame
            if !element.label.isEmpty, band.contains(CGPoint(x: frame.midX, y: frame.midY)),
               frame.maxX > screen.minX, frame.minX < screen.maxX {
                entries.append("\(element.label)@\(Int(frame.minX.rounded()))")
            }
            element.children.forEach(collect)
        }
        collect(snapshot)
        return entries.joined(separator: "|")
    }

    private enum Direction {
        case none
        case left
        case right
    }

    private func swipe(_ app: XCUIApplication, headingFrame: CGRect, windowFrame window: CGRect, direction: Direction) {
        guard direction != .none else { return }
        let rowY = (headingFrame.maxY + 90) / window.height
        let from = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: window.width * (direction == .left ? 0.8 : 0.2), dy: rowY * window.height))
        let target = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: window.width * (direction == .left ? 0.2 : 0.8), dy: rowY * window.height))
        from.press(forDuration: 0.05, thenDragTo: target, withVelocity: .default, thenHoldForDuration: 0)
    }
}

/// A horizontal row read from a screenshot: where its first item begins.
@MainActor
private struct RowReading {
    let leadingPixels: Int
    let scale: Double

    var leadingPoints: Double { Double(leadingPixels) / scale }

    /// The first run of at least 40 columns inside `band` (points) that differ from the page colour, which is an
    /// item's cover or card; the sliver of a neighbour at the screen edge is shorter and is skipped.
    init?(_ screenshot: XCUIScreenshot, band: CGRect, pageColourAt page: CGPoint) {
        guard let cgImage = screenshot.image.cgImage else { return nil }
        let scale = screenshot.image.scale
        let width = cgImage.width
        let height = cgImage.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let drew = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return nil }
        let top = Int(band.minY * scale)
        let bottom = min(Int(band.maxY * scale), height)
        // The page colour, read from the heading's row where no item is.
        let pageOffset = (Int(page.y * scale) * width + Int(page.x * scale)) * 4
        let backgroundChannels = [Int(data[pageOffset]), Int(data[pageOffset + 1]), Int(data[pageOffset + 2])]
        func occupied(_ column: Int) -> Bool {
            (top..<bottom).contains(where: { row in
                let offset = (row * width + column) * 4
                return (0..<3).contains(where: { abs(Int(data[offset + $0]) - backgroundChannels[$0]) > 6 })
            })
        }
        var run = 0
        var leading: Int?
        for column in 0..<width {
            if occupied(column) {
                run += 1
                if run >= 40, leading == nil { leading = column - run + 1 }
            } else {
                run = 0
            }
        }
        guard let leading else { return nil }
        self.leadingPixels = leading
        self.scale = scale
    }
}
