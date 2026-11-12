import UIKit
import XCTest

/// Where a horizontal row comes to rest (UI-SPEC rev 1.8 follow-up). Every stop but the last lines the first fully
/// visible item's leading edge up with its section heading's leading edge. The last stop is the end of the content,
/// where the last item's trailing edge sits on the trailing margin, as far from the screen edge as the heading's
/// leading edge is from the leading one; the item before it may be cut off on the left.
///
/// Each case drives one row (Home's Front Page wall, Toplists and More cards, Search's Recently Viewed) through
/// a rest, two swipes to the left, one to the right, then to the far end and back to the start. It reads a
/// screenshot and the accessibility tree at every stop and requires 0.5pt of agreement with the rule that stop
/// falls under. The stops are kept as attachments, with the trailing gap of the first page.
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
        let rowY = headingFrame.maxY + 85
        let labelBand = CGRect(x: 0, y: headingFrame.maxY, width: windowFrame.width, height: 400)
        let band = CGRect(x: 0, y: headingFrame.maxY + 45, width: windowFrame.width, height: 80)
        let page = CGPoint(x: windowFrame.midX, y: headingFrame.midY)
        var stops: [Stop] = []

        /// Swipes (unless `direction` is `.none`), waits for the row to come to rest, then reads it.
        func rest(_ name: String, _ direction: Direction) -> Stop? {
            swipe(app, headingFrame: headingFrame, windowFrame: windowFrame, direction: direction)
            _ = app.staticTexts["never-present"].waitForExistence(timeout: 1.2)
            let shot = app.screenshot()
            let contents = readContents(app, rowY: rowY, labelBand: labelBand)
            let attachment = XCTAttachment(screenshot: shot)
            attachment.name = "\(row.rawValue)-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            guard let reading = RowReading(shot, band: band, pageColourAt: page) else {
                XCTFail("\(row.rawValue) \(name): no item found.")
                return nil
            }
            let stop = Stop(name: name, reading: reading, contents: contents, screenWidth: windowFrame.width)
            stops.append(stop)
            return stop
        }

        // A swipe that leaves the row where it was proves nothing, so each one must move it.
        var previous = rest("rest", .none)
        for (name, direction) in [("left1", Direction.left), ("left2", .left), ("right1", .right)] {
            let stop = rest(name, direction)
            let moved = stop?.contents.signature != previous?.contents.signature
            XCTAssertTrue(moved, "\(row.rawValue) \(name): the swipe moved nothing.")
            previous = stop
        }
        // Both ends: swipe on until the row stops moving, then back to where it started.
        var lastStop: Stop?
        for (name, direction) in [("end", Direction.left), ("start", .right)] {
            var swipes = 0
            while swipes < 16 {
                let stop = rest("\(name)\(swipes)", direction)
                swipes += 1
                let settled = stop?.contents.signature == previous?.contents.signature
                previous = stop
                if settled {
                    if name == "end" { lastStop = stop }
                    break
                }
            }
            XCTAssertLessThan(swipes, 16, "\(row.rawValue) never reached its \(name).")
        }

        // The last stop is the one that matches where the row ends; every other stop is a snap position.
        let trailingMargin = windowFrame.width - headingFrame.minX
        let endSignature = lastStop?.contents.signature
        XCTAssertNotNil(endSignature, "\(row.rawValue) never reached its end.")
        XCTAssertNotEqual(stops.first?.contents.signature, endSignature, "\(row.rawValue) does not scroll.")
        for stop in stops {
            let isLast = stop.contents.signature == endSignature
            var line = "\(row.rawValue) \(stop.name): "
            let difference: Double
            if isLast {
                guard let trailing = stop.contents.trailingEdge else {
                    XCTFail(line + "no item reaches the trailing edge.")
                    continue
                }
                difference = trailing - trailingMargin
                line += "LAST STOP item trailing \(trailing) pt, trailing margin \(trailingMargin) pt, "
                    + "difference \(difference) pt"
            } else {
                difference = stop.reading.leadingPoints - headingFrame.minX
                line += "item leading \(stop.reading.leadingPixels) px (\(stop.reading.leadingPoints) pt), "
                    + "heading leading \(headingFrame.minX * stop.reading.scale) px (\(headingFrame.minX) pt), "
                    + "difference \(difference) pt"
            }
            if let gap = stop.contents.trailingGap(screenWidth: stop.screenWidth) {
                line += "; last fully visible item ends \(gap) pt from the trailing screen edge"
            }
            let note = XCTAttachment(string: line)
            note.name = "\(row.rawValue)-\(stop.name) measure"
            note.lifetime = .keepAlways
            add(note)
            XCTAssertLessThanOrEqual(abs(difference), Self.tolerance, line)
        }
        XCTAssertGreaterThan(stops.count, 4)
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

    /// What the row shows, read from one snapshot of the app: the label and position of every labelled element
    /// in `labelBand`, and the frames of the buttons on the row's line. A screenshot cannot say which items are in
    /// view, as the covers' placeholders animate.
    private func readContents(_ app: XCUIApplication, rowY: CGFloat, labelBand: CGRect) -> RowContents {
        let snapshot: any XCUIElementSnapshot
        do {
            snapshot = try app.snapshot()
        } catch {
            XCTFail("The app could not be read: \(error)")
            return RowContents(signature: "", buttonFrames: [])
        }
        let screen = app.windows.firstMatch.frame
        var entries: [String] = []
        var buttons: [CGRect] = []
        func collect(_ element: any XCUIElementSnapshot) {
            let frame = element.frame
            let onScreen = frame.maxX > screen.minX && frame.minX < screen.maxX
            if onScreen, !element.label.isEmpty, labelBand.contains(CGPoint(x: frame.midX, y: frame.midY)) {
                entries.append("\(element.label)@\(Int(frame.minX.rounded()))")
            }
            if onScreen, element.elementType == .button, frame.width >= 40, frame.minY <= rowY, rowY <= frame.maxY {
                buttons.append(frame)
            }
            element.children.forEach(collect)
        }
        collect(snapshot)
        return RowContents(signature: entries.joined(separator: "|"), buttonFrames: buttons)
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

/// What a row shows at a stop: a signature that changes when the row moves, and the frames of its buttons.
private struct RowContents {
    let signature: String
    let buttonFrames: [CGRect]

    /// Where the row's content ends on screen: the furthest trailing edge of an item that begins on screen.
    var trailingEdge: Double? {
        buttonFrames.map(\.maxX).max().map(Double.init)
    }

    /// How far the last item that is fully on screen ends from the trailing screen edge.
    func trailingGap(screenWidth: CGFloat) -> Double? {
        buttonFrames.map(\.maxX).filter({ $0 <= screenWidth + 0.5 }).max().map({ Double(screenWidth - $0) })
    }
}

/// One rest of a row: the screenshot reading and what the accessibility tree showed.
private struct Stop {
    let name: String
    let reading: RowReading
    let contents: RowContents
    let screenWidth: CGFloat
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
