import UIKit
import XCTest

/// The round glyph's top edge against the top of the first line's capital letters (UI-SPEC C-2 and C-3, rev 1.8):
/// the age wall's checkbox beside "Under every law…" and the analytics choice's radio beside Minimal, Basic and
/// Full. The test reads a screenshot of the screen, as the owner sees it, and compares the first row the circle
/// colours with the first dark row of the capital letter's stem, at every text size below the accessibility sizes,
/// where the glyph sits in the row. Above them the glyph moves over the text, and the screens are only kept.
///
/// The screenshots are kept as attachments under `<screen>-<size>`.
@MainActor
final class FirstLaunchCircleTopUITests: XCTestCase {
    /// How far the circle's top may sit from the capital's top, in points (spec rev 1.8).
    private static let tolerance = 0.5

    /// The sizes in a row layout, as `-UIPreferredContentSizeCategoryName` values.
    private static let rowSizes = ["XS", "S", "M", "L", "XL", "XXL", "XXXL"]
    /// The accessibility sizes, kept as screenshots only.
    private static let accessibilitySizes = [
        "AccessibilityM", "AccessibilityL", "AccessibilityXL", "AccessibilityXXL", "AccessibilityXXXL"
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTheCircleTopMeetsTheCapitalsTopAtEveryRowSize() throws {
        for size in Self.rowSizes {
            try measure(size: size, assertAlignment: true)
        }
    }

    func testTheAccessibilitySizesAreKept() throws {
        for size in Self.accessibilitySizes {
            try measure(size: size, assertAlignment: false)
        }
    }

    private func measure(size: String, assertAlignment: Bool) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(size)"]
        try app.launchStubbed(extraEnvironment: [UITestConstants.firstLaunchEnvironmentKey: "show"])
        app.requireForeground()
        defer { app.terminate() }

        let ageWall = app.scrollViews["first_launch_age_wall"]
        XCTAssertTrue(ageWall.waitForExistence(timeout: 15), "The age wall is missing at \(size).")
        let declaration = app.switches["first_launch_declaration"]
        XCTAssertTrue(declaration.waitUntilHittable(timeout: XCUIElement.hittableTimeout))
        keepAndMeasure(app, card: declaration, name: "age-wall-\(size)", assertAlignment: assertAlignment)

        let continueButton = app.buttons["first_launch_continue"]
        scrollIntoReach(declaration, in: ageWall, clearOf: continueButton)
        declaration.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(continueButton.wait(for: \.isEnabled, toEqual: true, timeout: 5), "Continue stayed dimmed.")
        continueButton.tapWhenHittable("Continue")

        let title = app.staticTexts["first_launch_analytics_title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "The analytics choice is missing at \(size).")
        XCTAssertTrue(title.waitUntilHittable(timeout: XCUIElement.hittableTimeout), "The step never settled.")
        let levels = ["minimal", "basic", "full"].map { app.buttons["first_launch_level_\($0)"] }
        keepAndMeasure(app, cards: levels, name: "analytics-\(size)", assertAlignment: assertAlignment)

        let basic = levels[1]
        scrollIntoReach(basic, in: app.scrollViews["first_launch_analytics_choice"], clearOf: continueButton)
        basic.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        // The fade between the ring and the filled disc takes 0.15 s.
        _ = app.staticTexts["never-present"].waitForExistence(timeout: 1)
        keepAndMeasure(app, cards: levels, name: "analytics-picked-\(size)", assertAlignment: assertAlignment)
    }

    private func keepAndMeasure(_ app: XCUIApplication, card: XCUIElement, name: String, assertAlignment: Bool) {
        keepAndMeasure(app, cards: [card], name: name, assertAlignment: assertAlignment)
    }

    /// Keeps the screenshot; with `assertAlignment`, measures every card that is wholly above the pinned bar.
    private func keepAndMeasure(_ app: XCUIApplication, cards: [XCUIElement], name: String, assertAlignment: Bool) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard assertAlignment else { return }

        let barTop = app.buttons["first_launch_continue"].frame.minY
        var measured = 0
        for card in cards where card.frame.maxY <= barTop {
            guard let result = CircleTopMeasurement(screenshot: screenshot, card: card.frame) else {
                XCTFail("\(name): no circle or no capital letter found in \(card.identifier).")
                continue
            }
            let line = "\(name) \(card.identifier): circle top \(result.circleTop) px, capital top "
                + "\(result.capitalTop) px, difference \(result.differenceInPoints) pt"
            let note = XCTAttachment(string: line)
            note.name = "\(name) \(card.identifier) measure"
            note.lifetime = .keepAlways
            add(note)
            XCTAssertLessThanOrEqual(abs(result.differenceInPoints), Self.tolerance, line)
            measured += 1
        }
        XCTAssertGreaterThan(measured, 0, "\(name): no card was measured.")
    }

    private func scrollIntoReach(_ element: XCUIElement, in scrollView: XCUIElement, clearOf bar: XCUIElement) {
        var swipes = 0
        while !element.exists || element.frame.midY >= bar.frame.minY - 16, swipes < 12 {
            scrollView.swipeUp()
            swipes += 1
        }
    }
}

/// The first row the circle colours and the first dark row of the first capital letter, found in a screenshot.
private struct CircleTopMeasurement {
    /// The first row the circle covers by at least half, in pixels from the top of the screenshot.
    let circleTop: Int
    /// The first row the capital's stem covers by at least half, likewise.
    let capitalTop: Int
    let scale: Double

    var differenceInPoints: Double { Double(circleTop - capitalTop) / scale }

    init?(screenshot: XCUIScreenshot, card: CGRect) {
        guard let cgImage = screenshot.image.cgImage else { return nil }
        let scale = screenshot.image.scale
        self.scale = scale
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

        func pixels(_ points: CGFloat) -> Int { Int((points * scale).rounded()) }
        // The card's own colour, from its padding beside the glyph; the 2pt selection stroke and the corner radius
        // are kept out of every scan by starting 10pt inside and 6pt below the card's top.
        let left = pixels(card.minX + 10)
        let top = pixels(card.minY + 6)
        let bottom = min(pixels(card.minY + 80), height)
        let right = min(pixels(card.maxX - 10), width)
        let background = (0..<3).map({ Int(data[(top * width + left) * 4 + $0]) })
        func difference(_ column: Int, _ row: Int) -> Int {
            (0..<3).map({ abs(Int(data[(row * width + column) * 4 + $0]) - background[$0]) }).max() ?? 0
        }

        // The columns the first line's items occupy: the glyph is the first group, the text the next.
        let occupied = (left..<right).map({ column in
            (top..<bottom).contains(where: { difference(column, $0) > 40 })
        })
        guard let glyphStart = occupied.firstIndex(of: true) else { return nil }
        let gapColumns = pixels(4)
        var glyphEnd = glyphStart
        var column = glyphStart
        while column < occupied.count {
            if occupied[column] {
                glyphEnd = column
            } else if column - glyphEnd > gapColumns {
                break
            }
            column += 1
        }
        guard let textStart = occupied[(glyphEnd + 1)...].firstIndex(of: true) else { return nil }

        // First row at which half of the object's strongest colour shows, within the given columns.
        func firstRow(columns: Range<Int>) -> Int? {
            let peak = (top..<bottom).flatMap({ row in columns.map({ difference($0, row) }) }).max() ?? 0
            guard peak > 40 else { return nil }
            return (top..<bottom).first(where: { row in columns.contains(where: { difference($0, row) * 2 >= peak }) })
        }
        // The capital's stem: the first 5pt of the text, which is the left stem of U, M, B and F.
        let stemColumns = (left + textStart)..<(left + textStart + pixels(5))
        guard let circleRow = firstRow(columns: (left + glyphStart)..<(left + glyphEnd + 1)),
              let capitalRow = firstRow(columns: stemColumns) else { return nil }
        circleTop = circleRow
        capitalTop = capitalRow
    }
}
