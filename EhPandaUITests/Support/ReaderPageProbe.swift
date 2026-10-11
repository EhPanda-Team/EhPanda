import UIKit
import XCTest

/// Reads the reader's two answers to "which page is this?" and drives the ways of changing it.
///
/// The panel's indicator is computed from the page model, so a test that reads the indicator
/// alone only proves the model agrees with itself. Phase 16 W-38 was the model and the screen
/// disagreeing (VoiceOver on page 51 under an indicator reading `44 / 52`), and no assertion on
/// the indicator could have seen it. Every check here therefore reads both sides: the page the
/// indicator names, and the page that is actually under the center of the reader.
///
/// The second reading leans on the hermetic fixture. Its images never load, so every page is the
/// reader's failure placeholder: a page number followed by a Reload button in a stack centered in
/// the page's first screen (`UnloadedPage`), the whole page when the page is shorter than the screen.
/// The pages are one accessibility element, so VoiceOver has no page to scroll to as the reader
/// opens, and the stack is read from a screenshot instead (`ScreenPixels`). The number alone sits
/// above the stack's center. Measuring the whole stack keeps the page reading accurate near the
/// boundary between two placeholders. This does not hold for loaded images, which carry no number.
///
/// The stack nearest the center belongs to the page under the center while that page is shorter
/// than the screen, as in portrait, or positioned at the top of the screen. A landscape strip page
/// is taller than the screen, and once it is scrolled past its first screen the nearest stack can be
/// the next page's; no test reads the screen there.
@MainActor
struct ReaderPageProbe {
    /// The reading directions the tests run under, named as the Reading Setting picker names them.
    enum Direction: String, CaseIterable {
        case vertical = "Vertical"
        case leftToRight = "Left-to-right"
    }

    /// Where the reader stands: what the panel says, and what the screen shows.
    struct Standing: Equatable {
        let indicated: Int?
        let shown: Int?

        /// Both sides read, and they agree.
        var page: Int? {
            guard let indicated, indicated == shown else { return nil }
            return indicated
        }
    }

    let app: XCUIApplication

    private var readingView: XCUIElement {
        app.descendants(matching: .any).matching(identifier: "reading_view").firstMatch
    }

    private var pages: XCUIElement {
        readingView.descendants(matching: .any).matching(identifier: "reading_pages").firstMatch
    }

    private var indicator: XCUIElement {
        app.staticTexts.matching(identifier: "reading_page_indicator").firstMatch
    }

    private var slider: XCUIElement {
        readingView.descendants(matching: .slider).firstMatch
    }

    private var moreMenuButton: XCUIElement {
        let navigationBars = app.navigationBars.containing(
            .staticText,
            identifier: "reading_page_indicator"
        )
        XCTAssertEqual(
            navigationBars.count,
            1,
            "The reader page indicator did not identify exactly one navigation bar."
        )
        let navigationBar = navigationBars.element(boundBy: 0)
        let buttons = navigationBar.buttons.matching(
            NSPredicate(format: "identifier == %@", "OverflowBarButtonItem")
        )
        XCTAssertEqual(
            buttons.count,
            1,
            "The reader navigation bar did not expose exactly one More button."
        )
        return buttons.element(boundBy: 0)
    }

    // MARK: Reading

    /// Where the reader stands. The screen is read only once the indicator names a page that
    /// satisfies `condition`, as reading it matches each drawn number against every page number.
    private func standing(where condition: (Int) -> Bool) throws -> Standing {
        guard let indicated = indicatedPage(), condition(indicated) else {
            return Standing(indicated: indicatedPage(), shown: nil)
        }
        return Standing(indicated: indicated, shown: try shownPage())
    }

    /// The leading number of the indicator's `12 / 156`. SwiftUI may expose the text as the
    /// element's label or as its value.
    private func indicatedPage() -> Int? {
        indicatorText().split(separator: "/").first
            .flatMap({ Int($0.trimmingCharacters(in: .whitespaces)) })
    }

    private func indicatorText() -> String {
        guard indicator.exists else { return "" }
        return indicator.label.isEmpty ? (indicator.value as? String ?? "") : indicator.label
    }

    /// The placeholder stack nearest the center of the pages.
    private func shownPage() throws -> Int? {
        try screenReading().page
    }

    /// The placeholder stacks on screen, read from one screenshot so all of them belong to the same moment. A stack's
    /// number is identified among every page the indicator counts.
    private func screenReading() throws -> ScreenReading {
        let viewport = pages.frame
        let screenshot = XCUIScreen.main.screenshot().image
        let pixels = try ScreenPixels(screenshot)
        let pageCount = indicatorText().split(separator: "/").last
            .flatMap({ Int($0.trimmingCharacters(in: .whitespaces)) }) ?? 0
        return ScreenReading(
            viewport: viewport,
            stacks: try pixels.stacks(in: viewport, pages: 1...max(pageCount, 1)),
            screenshot: screenshot
        )
    }

    /// Waits for the indicator and the screen to agree on a page that satisfies `condition`, and
    /// returns that page. A page turn is not instantaneous (the pager slides, the strip settles),
    /// so the two sides are allowed to disagree on the way and are required to agree at rest.
    @discardableResult
    func requirePage(
        _ expectation: String,
        timeout: TimeInterval = 10,
        where condition: (Int) -> Bool = { _ in true },
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Int {
        let deadline = Date.now.addingTimeInterval(timeout)
        var last = try standing(where: condition)
        while Date.now < deadline {
            if let page = last.page, condition(page) { return page }
            RunLoop.current.run(until: .now + 0.25)
            last = try standing(where: condition)
        }
        if let page = last.page, condition(page) { return page }
        let indicated = indicatedPage()
        let reading = try screenReading()
        XCTContext.runActivity(named: "Reader page failure diagnostics") { activity in
            let screenshot = XCTAttachment(image: reading.screenshot)
            screenshot.name = "reader-failure-screen"
            screenshot.lifetime = .keepAlways
            activity.add(screenshot)

            var lines = ["Viewport frame: \(reading.viewport)", "", "Placeholder stacks:"]
            lines += reading.stacks.map({ "  \($0)" })
            let text = XCTAttachment(string: lines.joined(separator: "\n"))
            text.name = "reader-failure-geometry"
            text.lifetime = .keepAlways
            activity.add(text)
        }
        XCTFail(
            "\(expectation): the indicator names \(Self.describe(indicated)) and the screen shows "
                + "\(Self.describe(reading.page)).",
            file: file,
            line: line
        )
        throw ProbeFailure()
    }

    /// Requires the pages to be one accessibility element that reads `page`, with no element of a
    /// page's own beneath it: a page element draws VoiceOver's first focus to a page the lazy
    /// stack built above the resume page. The fixture's pages never load, so the element also
    /// reads that the page failed.
    func requireOnePagesElement(reading page: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(pages.label, "Page", file: file, line: line)
        let pageCount = indicatorText().split(separator: "/").last
            .map({ $0.trimmingCharacters(in: .whitespaces) }) ?? "?"
        let expected = "\(page) of \(pageCount), failed to load"
        let deadline = Date.now.addingTimeInterval(5)
        while pages.value as? String != expected, Date.now < deadline {
            RunLoop.current.run(until: .now + 0.25)
        }
        XCTAssertEqual(pages.value as? String, expected, file: file, line: line)
        // The scroll view's own containers stay beneath the element; a page's number, Reload button
        // or image would not.
        for type in [XCUIElement.ElementType.staticText, .button, .image] {
            XCTAssertEqual(
                pages.descendants(matching: type).count,
                0,
                "The pages element has \(type) elements of its own beneath it.",
                file: file,
                line: line
            )
        }
    }

    private struct ProbeFailure: Error {}

    private static func describe(_ page: Int?) -> String {
        page.map({ "page \($0)" }) ?? "no page"
    }

    // MARK: Driving

    /// Shows the panel, which carries the indicator and the slider. A tap in the middle of the
    /// reader toggles the panel under every reading direction; the side fifths turn the pager.
    func showPanel() {
        guard !indicator.exists else { return }
        pages.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(indicator.waitForExistence(timeout: 5), "The reader did not show its panel.")
    }

    /// Scrolls towards the following pages: up the strip, or to the left of a left-to-right pager.
    func scrollForward(under direction: Direction) {
        switch direction {
        case .vertical:
            // XCTest's default swipe can stop short of half a full-height iPad page. A drag held
            // still at its end crosses that boundary and stops where the finger does, without a
            // fling. Starting above the panel and crossing 72% of the screen, it leaves the page
            // now under the center with its stack clear of the panel's controls on the iPad and
            // the iPhone alike, where the screen reading can see it.
            pages.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                .press(
                    forDuration: 0.05,
                    thenDragTo: pages.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)),
                    withVelocity: .default,
                    thenHoldForDuration: 0.3
                )
        case .leftToRight: pages.swipeLeft()
        }
    }

    /// Taps the trailing fifth of a left-to-right pager, its "next page" zone.
    func tapNextPageZone() {
        pages.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    /// Taps the status bar, which shows while the panel does and scrolls the strip to its first page. The status bar
    /// is SpringBoard's, not the app's. The tap lands on its leading part, clear of the iPhone's Dynamic Island.
    func tapStatusBar() {
        let statusBar = XCUIApplication(bundleIdentifier: "com.apple.springboard").statusBars.firstMatch
        XCTAssertTrue(statusBar.waitForExistence(timeout: 5), "SpringBoard did not expose the status bar.")
        statusBar.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
    }

    func dragSlider(toNormalizedPosition position: CGFloat) {
        XCTAssertTrue(slider.waitForExistence(timeout: 5), "The panel did not expose its page slider.")
        slider.adjust(toNormalizedSliderPosition: position)
    }

    /// Picks an auto-play interval from the toolbar's menu, by the title the menu lists it under.
    func selectAutoPlay(_ title: String) {
        app.buttons["Auto-Play"].firstMatch.tapWhenHittable("The toolbar's Auto-Play menu")
        let option = app.buttons[title].firstMatch
        option.tapWhenHittable("Auto-Play's \(title)")
        XCTAssertTrue(
            option.waitForNonExistence(timeout: 5),
            "The Auto-Play menu did not dismiss after selecting \(title)."
        )
    }

    /// Sets the reading direction through the Reading Setting sheet, the way a reader does, and
    /// leaves the sheet dismissed. The setting persists between launches, so every test states
    /// the direction it runs under instead of inheriting one.
    func setDirection(_ direction: Direction) {
        moreMenuButton.tapWhenHittable("The reader toolbar's More menu")
        app.buttons["Reading Setting"].firstMatch.tapWhenHittable("More's Reading Setting")

        let sheetTitle = app.navigationBars["Reading"].firstMatch
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5), "The Reading Setting sheet did not appear.")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Direction'"))
            .firstMatch.tapWhenHittable("The sheet's Direction picker")
        app.buttons[direction.rawValue].firstMatch.tapWhenHittable("Direction's \(direction.rawValue)")

        // ReadingView adds Close only for the phone's landscape presentation.
        if UIDevice.current.userInterfaceIdiom != .pad && XCUIDevice.shared.orientation.isLandscape {
            sheetTitle.buttons["Close"].firstMatch.tapWhenHittable("Reading Setting Close")
        } else {
            sheetTitle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        }
        XCTAssertTrue(
            sheetTitle.waitForNonExistence(timeout: 5),
            "The Reading Setting sheet did not dismiss."
        )
    }
}

/// The placeholder stacks a screenshot shows over the reader's pages.
private struct ScreenReading {
    let viewport: CGRect
    let stacks: [PlaceholderStack]
    let screenshot: UIImage

    /// The page whose stack lies nearest the center of the pages, as the reader's own page is the
    /// one under that center.
    var page: Int? {
        let center = CGPoint(x: viewport.midX, y: viewport.midY)
        let nearest = stacks
            .compactMap { stack in
                stack.page.map({ (page: $0, distance: hypot(stack.center.x - center.x, stack.center.y - center.y)) })
            }
            .min(by: { $0.distance < $1.distance })
        guard let nearest, nearest.distance < max(viewport.width, viewport.height) / 2 else { return nil }
        return nearest.page
    }
}

/// A failure placeholder's number above its Reload glyph, in points in the screen's coordinate space.
private struct PlaceholderStack: CustomStringConvertible {
    let number: CGRect
    let glyph: CGRect
    /// The page whose number matches the drawn one, if any matches.
    let page: Int?
    /// How much of the drawn number and the best matching number overlap, as a share of either.
    let overlap: Double

    var center: CGPoint {
        CGPoint(x: number.midX, y: (number.minY + glyph.maxY) / 2)
    }

    var description: String {
        "page=\(page.map(String.init) ?? "none") overlap=\(String(format: "%.2f", overlap)) "
            + "number=\(number) glyph=\(glyph)"
    }
}

/// A screenshot drawn upright into 8-bit sRGB pixels at the screen's scale, so its pixels lie
/// where the screen shows them whatever the orientation.
///
/// Placeholder numbers are told apart by their ink: each is matched against every page number drawn
/// as the placeholder draws it, in the bold large title style, in this process on the same screen.
/// Text recognition is no use here, as it drops a lone digit.
@MainActor
private struct ScreenPixels {
    private struct Color: Hashable {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
    }

    private let scale: CGFloat
    private let width: Int
    private let height: Int
    /// Keeps `pixels` alive.
    private let context: CGContext
    /// Each pixel's red, green, blue and alpha bytes, in that order in memory.
    private let pixels: UnsafeBufferPointer<UInt32>

    init(_ screenshot: UIImage) throws {
        scale = screenshot.scale
        width = Int((screenshot.size.width * scale).rounded())
        height = Int((screenshot.size.height * scale).rounded())
        context = try ScreenPixels.context(width: width, height: height)
        // UIKit draws top down in points and honors the screenshot's orientation.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        UIGraphicsPushContext(context)
        screenshot.draw(at: .zero)
        UIGraphicsPopContext()
        pixels = UnsafeBufferPointer(
            start: try XCTUnwrap(context.data).assumingMemoryBound(to: UInt32.self),
            count: width * height
        )
    }

    /// The placeholder stacks in a band down the middle of `viewport`, where the placeholders
    /// center their stacks: runs of ink rows, a number's followed by its glyph's 10 to 60 points
    /// below. Ink is any pixel unlike the background, the commonest color at the band's edges.
    func stacks(in viewport: CGRect, pages: ClosedRange<Int>) throws -> [PlaceholderStack] {
        let middle = Int((viewport.midX * scale).rounded())
        let columns = max(middle - Int(60 * scale), 0)..<min(middle + Int(60 * scale), width)
        let rows = max(Int(viewport.minY * scale), 0)..<min(Int(viewport.maxY * scale), height)
        guard let first = columns.first, let last = columns.last, !rows.isEmpty else { return [] }
        let background = commonestColor(in: [first, last], rows: rows)
        let runs = inkRuns(columns: columns, rows: rows, background: background)
        let templates = try PageNumberTemplates.shared.templates(for: pages, scale: scale)
        return zip(runs, runs.dropFirst()).compactMap { number, glyph -> PlaceholderStack? in
            let gap = CGFloat(glyph.minY - number.maxY) / scale
            guard (10...60).contains(gap) else { return nil }
            let mask = inkMask(of: number, background: background)
            // A number of another width or height cannot be the one drawn; this spares most of the matching.
            let best = templates
                .filter({ abs($0.mask.width - mask.width) <= 4 && abs($0.mask.height - mask.height) <= 4 })
                .map({ (page: $0.page, overlap: $0.mask.overlap(with: mask)) })
                .max(by: { $0.overlap < $1.overlap })
            return PlaceholderStack(
                number: points(of: number),
                glyph: points(of: glyph),
                page: best.flatMap({ $0.overlap >= 0.8 ? $0.page : nil }),
                overlap: best?.overlap ?? 0
            )
        }
    }

    private func points(of pixels: CGRect) -> CGRect {
        pixels.applying(CGAffineTransform(scaleX: 1 / scale, y: 1 / scale))
    }

    /// The pixel's color; black outside the screenshot.
    private func color(column: Int, row: Int) -> Color {
        let pixel = row * width + column
        guard (0..<width).contains(column), pixels.indices.contains(pixel) else {
            return Color(red: 0, green: 0, blue: 0)
        }
        let rgba = UInt32(bigEndian: pixels[pixel])
        return Color(
            red: UInt8(truncatingIfNeeded: rgba >> 24),
            green: UInt8(truncatingIfNeeded: rgba >> 16),
            blue: UInt8(truncatingIfNeeded: rgba >> 8)
        )
    }

    private func isInk(column: Int, row: Int, background: Color) -> Bool {
        let pixel = color(column: column, row: row)
        let difference = abs(Int(pixel.red) - Int(background.red))
            + abs(Int(pixel.green) - Int(background.green))
            + abs(Int(pixel.blue) - Int(background.blue))
        return difference > 48
    }

    private func commonestColor(in columns: [Int], rows: Range<Int>) -> Color {
        var counts = [Color: Int]()
        for column in columns {
            for row in stride(from: rows.lowerBound, to: rows.upperBound, by: 4) {
                counts[color(column: column, row: row), default: 0] += 1
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? Color(red: 0, green: 0, blue: 0)
    }

    /// Each run of rows with ink, joined across gaps of up to two rows, with the columns its ink
    /// spans.
    private func inkRuns(columns: Range<Int>, rows: Range<Int>, background: Color) -> [CGRect] {
        var runs = [(top: Int, bottom: Int, left: Int, right: Int)]()
        for row in rows {
            guard let left = columns.first(where: { isInk(column: $0, row: row, background: background) }),
                  let right = columns.last(where: { isInk(column: $0, row: row, background: background) })
            else { continue }
            if let run = runs.last, row - run.bottom <= 3 {
                runs[runs.count - 1] = (run.top, row, min(run.left, left), max(run.right, right))
            } else {
                runs.append((row, row, left, right))
            }
        }
        return runs.map { run in
            CGRect(x: run.left, y: run.top, width: run.right - run.left + 1, height: run.bottom - run.top + 1)
        }
    }

    private func inkMask(of rect: CGRect, background: Color) -> InkMask {
        let columns = Int(rect.minX)..<Int(rect.maxX)
        let rows = Int(rect.minY)..<Int(rect.maxY)
        return InkMask(width: columns.count, height: rows.count, ink: rows.flatMap { row in
            columns.map({ isInk(column: $0, row: row, background: background) })
        })
    }

    fileprivate static func context(width: Int, height: Int) throws -> CGContext {
        try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB)),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
    }
}

/// Which pixels of a rectangle carry ink, row by row, cropped to the ink.
private struct InkMask {
    let width: Int
    let height: Int
    let ink: [Bool]

    /// The pixels inked in both masks as a share of those inked in either, with the masks aligned
    /// at their top left corners.
    func overlap(with other: InkMask) -> Double {
        var both = 0
        var either = 0
        for row in 0..<max(height, other.height) {
            for column in 0..<max(width, other.width) {
                let mine = isInk(column: column, row: row)
                let theirs = other.isInk(column: column, row: row)
                both += mine && theirs ? 1 : 0
                either += mine || theirs ? 1 : 0
            }
        }
        return either == 0 ? 0 : Double(both) / Double(either)
    }

    private func isInk(column: Int, row: Int) -> Bool {
        column < width && row < height && ink[row * width + column]
    }
}

/// Page numbers drawn as the failure placeholder draws them, black on white, cropped to their ink.
/// Ink is any pixel at least a quarter dark, about as much coverage as the screen's ink threshold
/// asks of the gray number on the gray placeholder.
@MainActor
private final class PageNumberTemplates {
    static let shared = PageNumberTemplates()

    private var cache = [Int: (scale: CGFloat, mask: InkMask)]()

    func templates(for pages: ClosedRange<Int>, scale: CGFloat) throws -> [(page: Int, mask: InkMask)] {
        try pages.map { page in
            if let cached = cache[page], cached.scale == scale {
                return (page, cached.mask)
            }
            let mask = try render(page, scale: scale)
            cache[page] = (scale, mask)
            return (page, mask)
        }
    }

    private func render(_ page: Int, scale: CGFloat) throws -> InkMask {
        let largeTitle = UIFont.preferredFont(forTextStyle: .largeTitle)
        let bold = try XCTUnwrap(largeTitle.fontDescriptor.withSymbolicTraits(.traitBold))
        let text = NSAttributedString(string: String(page), attributes: [
            .font: UIFont(descriptor: bold, size: 0),
            .foregroundColor: UIColor.black
        ])
        let size = text.size()
        let width = Int((size.width * scale).rounded(.up))
        let height = Int((size.height * scale).rounded(.up))
        let context = try ScreenPixels.context(width: width, height: height)
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: scale, y: -scale)
        UIGraphicsPushContext(context)
        text.draw(at: .zero)
        UIGraphicsPopContext()
        let pixels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let ink = (0..<width * height).map({ Int(pixels[$0 * 4]) < 192 })
        let inked = ink.indices.filter({ ink[$0] })
        let top = try XCTUnwrap(inked.first) / width
        let bottom = try XCTUnwrap(inked.last) / width
        let columns = inked.map({ $0 % width })
        let left = try XCTUnwrap(columns.min())
        let right = try XCTUnwrap(columns.max())
        let rows = top...bottom
        let span = left...right
        return InkMask(width: span.count, height: rows.count, ink: rows.flatMap { row in
            span.map({ ink[row * width + $0] })
        })
    }
}
