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
/// reader's failure placeholder: a page number followed by a Reload button in a centered stack.
/// The number alone sits above the page center. Measuring the whole stack keeps the page reading
/// accurate near the boundary between two placeholders. This does not hold for loaded images,
/// which carry no number.
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

    private var pageList: XCUIElement {
        readingView.descendants(matching: .scrollView).firstMatch
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

    func standing() throws -> Standing {
        Standing(indicated: indicatedPage(), shown: try shownPage())
    }

    /// The leading number of the indicator's `12 / 156`. SwiftUI may expose the text as the
    /// element's label or as its value.
    private func indicatedPage() -> Int? {
        guard indicator.exists else { return nil }
        let text = indicator.label.isEmpty ? (indicator.value as? String ?? "") : indicator.label
        return text.split(separator: "/").first
            .flatMap({ Int($0.trimmingCharacters(in: .whitespaces)) })
    }

    /// The placeholder stack nearest the center of the page list, read from one snapshot so all
    /// frames belong to the same moment. Match each number to its nearest Reload button by frame:
    /// accessibility-tree ordering differs between the vertical strip and horizontal pager.
    private func shownPage() throws -> Int? {
        let snapshot = try pageList.snapshot()
        let viewport = snapshot.frame
        var numbers: [(page: Int, frame: CGRect)] = []
        var reloads: [CGRect] = []
        var pending = [snapshot]
        while let node = pending.popLast() {
            pending.append(contentsOf: node.children)
            if node.elementType == .staticText, let page = Int(node.label) {
                numbers.append((page: page, frame: node.frame))
            } else if node.elementType == .button, node.label == "Reload" {
                reloads.append(node.frame)
            }
        }
        var nearest: (page: Int, distance: CGFloat)?
        for number in numbers {
            guard let reload = reloads.min(by: {
                hypot($0.midX - number.frame.midX, $0.midY - number.frame.midY)
                    < hypot($1.midX - number.frame.midX, $1.midY - number.frame.midY)
            }) else { continue }
            let frame = number.frame.union(reload)
            let distance = hypot(frame.midX - viewport.midX, frame.midY - viewport.midY)
            if distance < nearest?.distance ?? .infinity {
                nearest = (number.page, distance)
            }
        }
        guard let nearest, nearest.distance < max(viewport.width, viewport.height) / 2 else { return nil }
        return nearest.page
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
        var last = try standing()
        while Date.now < deadline {
            if let page = last.page, condition(page) { return page }
            RunLoop.current.run(until: .now + 0.25)
            last = try standing()
        }
        if let page = last.page, condition(page) { return page }
        let snapshot = try pageList.snapshot()
        XCTContext.runActivity(named: "Reader page failure diagnostics") { activity in
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "reader-failure-screen"
            screenshot.lifetime = .keepAlways
            activity.add(screenshot)

            var nodes = snapshot.children
            var numericLabels = [(label: String, frame: CGRect)]()
            var reloadButtons = [(label: String, identifier: String, frame: CGRect)]()
            while let node = nodes.popLast() {
                nodes.append(contentsOf: node.children)
                if node.elementType == .staticText,
                   Int(node.label.trimmingCharacters(in: .whitespacesAndNewlines)) != nil {
                    numericLabels.append((label: node.label, frame: node.frame))
                } else if node.elementType == .button, node.label == "Reload" {
                    reloadButtons.append(
                        (label: node.label, identifier: node.identifier, frame: node.frame)
                    )
                }
            }

            var lines = [
                "Viewport frame: \(snapshot.frame)",
                "",
                "Numeric static texts:"
            ]
            lines += numericLabels.map {
                "  label=\($0.label) frame=\($0.frame)"
            }
            lines += ["", "Reload buttons:"]
            lines += reloadButtons.map {
                "  label=\($0.label) identifier=\($0.identifier) frame=\($0.frame)"
            }
            lines += ["", "Snapshot hierarchy:", String(describing: snapshot.dictionaryRepresentation)]

            let text = XCTAttachment(string: lines.joined(separator: "\n"))
            text.name = "reader-failure-geometry"
            text.lifetime = .keepAlways
            activity.add(text)
        }
        XCTFail(
            "\(expectation): the indicator names \(Self.describe(last.indicated)) and the screen shows "
                + "\(Self.describe(last.shown)).",
            file: file,
            line: line
        )
        throw ProbeFailure()
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
        pageList.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(indicator.waitForExistence(timeout: 5), "The reader did not show its panel.")
    }

    /// Scrolls towards the following pages: up the strip, or to the left of a left-to-right pager.
    func scrollForward(under direction: Direction) {
        switch direction {
        case .vertical:
            // XCTest's default swipe can stop short of half a full-height iPad page.
            // Cross that boundary explicitly so this gesture actually changes the current page.
            pageList.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
                .press(
                    forDuration: 0.05,
                    thenDragTo: pageList.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
                )
        case .leftToRight: pageList.swipeLeft()
        }
    }

    /// Taps the trailing fifth of a left-to-right pager, its "next page" zone.
    func tapNextPageZone() {
        pageList.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    func dragSlider(toNormalizedPosition position: CGFloat) {
        XCTAssertTrue(slider.waitForExistence(timeout: 5), "The panel did not expose its page slider.")
        slider.adjust(toNormalizedSliderPosition: position)
    }

    /// Picks an auto-play interval from the toolbar's menu, by the title the menu lists it under.
    func selectAutoPlay(_ title: String) {
        tap(app.buttons["Auto-Play"].firstMatch, "the toolbar's Auto-Play menu")
        let option = app.buttons[title].firstMatch
        tap(option, "Auto-Play's \(title)")
        XCTAssertTrue(
            option.waitForNonExistence(timeout: 5),
            "The Auto-Play menu did not dismiss after selecting \(title)."
        )
    }

    /// Sets the reading direction through the Reading Setting sheet, the way a reader does, and
    /// leaves the sheet dismissed. The setting persists between launches, so every test states
    /// the direction it runs under instead of inheriting one.
    func setDirection(_ direction: Direction) {
        tap(moreMenuButton, "the reader toolbar's More menu")
        tap(app.buttons["Reading Setting"].firstMatch, "More's Reading Setting")

        let sheetTitle = app.navigationBars["Reading"].firstMatch
        XCTAssertTrue(sheetTitle.waitForExistence(timeout: 5), "The Reading Setting sheet did not appear.")
        tap(
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Direction'")).firstMatch,
            "the sheet's Direction picker"
        )
        tap(app.buttons[direction.rawValue].firstMatch, "Direction's \(direction.rawValue)")

        sheetTitle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95)))
        XCTAssertTrue(
            sheetTitle.waitForNonExistence(timeout: 5),
            "The Reading Setting sheet did not dismiss."
        )
    }

    /// Taps a control once it can take the tap. Existing is not enough: while the menu or sheet
    /// before it is still leaving, a toolbar button is in the tree with nowhere to be hit, and a
    /// tap sent then goes nowhere without failing.
    private func tap(
        _ element: XCUIElement,
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let becomesHittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [becomesHittable], timeout: 10),
            .completed,
            "The reader never let \(name) be tapped.",
            file: file,
            line: line
        )
        element.tap()
    }
}
