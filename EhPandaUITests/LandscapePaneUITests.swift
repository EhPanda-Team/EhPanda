import UIKit
import XCTest

@MainActor
final class LandscapePaneUITests: XCTestCase {
    nonisolated private var isDuo: Bool { ProcessInfo.processInfo.environment["EHPANDA_DUO_UI_TESTS"] == "1" }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(isDuo || ProcessInfo.processInfo.environment["EHPANDA_IPAD_UI_TESTS"] == "1")
    }

    private func prepareLandscape() throws {
        if isDuo {
            try DuoPose.set(.open)
            try DuoPose.set(.portrait)
        } else {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
    }

    func testHomeAndNestedSheetsUseOppositeHalves() throws {
        try XCTSkipUnless(isDuo)
        try prepareLandscape()
        let app = XCUIApplication()
        try app.launchStubbed()
        let window = app.windows.firstMatch
        let left = app.requireElement("home_left_pane", matching: .scrollView)
        let right = app.requireElement("home_right_pane", matching: .scrollView)
        XCTAssertGreaterThan(window.frame.width, window.frame.height)
        XCTAssertEqual(left.frame.maxX, window.frame.midX, accuracy: 1)
        XCTAssertEqual(right.frame.minX, window.frame.midX, accuracy: 1)
        print("CAPTURE_LANDSCAPE_HOME")
        let title = app.navigationBars["Home"].staticTexts["Home"]
        let titleFrame = title.frame
        right.swipeUp()
        XCTAssertEqual(title.frame, titleFrame)
        left.buttons["Show All"].firstMatch.tapWhenHittable("Frontpage")
        let frontpage = app.navigationBars["Frontpage"]
        XCTAssertTrue(frontpage.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(frontpage.frame.minX, window.frame.midX)
        print("CAPTURE_LANDSCAPE_SHEET")
        app.collectionViews.buttons.firstMatch.tapWhenHittable("Gallery")
        let detail = app.requireElement("detail_view", matching: .scrollView)
        XCTAssertLessThanOrEqual(detail.frame.maxX, window.frame.midX)
        let sheetClose = try XCTUnwrap(app.buttons.matching(identifier: "Close").allElementsBoundByIndex.first {
            $0.isHittable && $0.frame.midX < window.frame.midX
        })
        sheetClose.tapWhenHittable("Detail Close")
        XCTAssertTrue(frontpage.exists)
    }

    func testPadHomeKeepsSinglePaneAcrossRotationAndTextSizes() throws {
        try XCTSkipUnless(!isDuo)
        let originalOrientation = XCUIDevice.shared.orientation
        addTeardownBlock { XCUIDevice.shared.orientation = originalOrientation }
        let sizes: [UIContentSizeCategory] = [
            .large, .accessibilityMedium, .accessibilityExtraLarge, .accessibilityExtraExtraExtraLarge
        ]
        for size in sizes {
            XCUIDevice.shared.orientation = .landscapeLeft
            let app = XCUIApplication()
            app.launchArguments = ["-UIPreferredContentSizeCategoryName", size.rawValue]
            try app.launchStubbed(extraEnvironment: ["EHPANDA_AUTOMATION_TAB": "home"])
            defer { app.terminate() }
            assertSingleHomePane(in: app)
            if size == .large {
                let sections = app.scrollViews["home_sections"]
                let showAll = sections.buttons["Show All"].firstMatch
                for _ in 0..<6 where !showAll.isHittable { sections.swipeUp() }
                showAll.tapWhenHittable("Frontpage from single-pane Home")
                let frontpage = app.navigationBars["Frontpage"]
                XCTAssertTrue(frontpage.waitForExistence(timeout: 10))
                let window = app.windows.firstMatch.frame
                XCTAssertLessThan(frontpage.frame.minX, window.midX)
                XCTAssertGreaterThan(frontpage.frame.maxX, window.midX)
                frontpage.buttons["Home"].tapWhenHittable("Return to Home")
                assertSingleHomePane(in: app)
            }
            XCUIDevice.shared.orientation = .portrait
            assertSingleHomePane(in: app, landscape: false)
            XCUIDevice.shared.orientation = .landscapeLeft
            assertSingleHomePane(in: app)
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "iPad single-pane Home \(size.rawValue)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
    }

    func testWideSlideshowRevealsNeighborsAndPreservesSelectionAcrossRotation() throws {
        try XCTSkipUnless(!isDuo)
        let originalOrientation = XCUIDevice.shared.orientation
        addTeardownBlock { XCUIDevice.shared.orientation = originalOrientation }
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        try app.launchStubbed(extraEnvironment: ["EHPANDA_AUTOMATION_TAB": "home"])
        let carousel = app.requireElement("home_carousel", matching: .scrollView)
        let landscapeCard = try centeredSlideshowCard(in: carousel, width: 720)
        let initialLabel = landscapeCard.label
        let initialHeight = landscapeCard.frame.height
        let visible = carousel.buttons.allElementsBoundByIndex.map(\.frame).filter {
            $0.intersects(carousel.frame) && $0.width > 0
        }
        XCTAssertTrue(visible.contains {
            $0.midX < carousel.frame.midX && $0.maxX > carousel.frame.minX + 100
        })
        XCTAssertTrue(visible.contains {
            $0.midX > carousel.frame.midX && $0.minX < carousel.frame.maxX - 100
        })
        let landscape = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        landscape.name = "Selected A landscape slideshow with neighboring cards"
        landscape.lifetime = .keepAlways
        add(landscape)

        XCUIDevice.shared.orientation = .portrait
        assertSingleHomePane(in: app, landscape: false)
        let portraitCard = try centeredSlideshowCard(in: carousel, width: app.windows.firstMatch.frame.width * 0.9)
        XCTAssertEqual(portraitCard.label, initialLabel)
        XCTAssertEqual(portraitCard.frame.height, initialHeight, accuracy: 1)
        let portrait = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        portrait.name = "Selected A preserves portrait slideshow"
        portrait.lifetime = .keepAlways
        add(portrait)

        XCUIDevice.shared.orientation = .landscapeLeft
        assertSingleHomePane(in: app)
        XCTAssertEqual(try centeredSlideshowCard(in: carousel, width: 720).label, initialLabel)
        carousel.swipeLeft()
        let nextCard = try centeredSlideshowCard(in: carousel, width: 720)
        XCTAssertNotEqual(nextCard.label, initialLabel)
        carousel.swipeRight()
        XCTAssertEqual(try centeredSlideshowCard(in: carousel, width: 720).label, initialLabel)
    }

    private func centeredSlideshowCard(in carousel: XCUIElement, width: CGFloat) throws -> XCUIElement {
        let centered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            carousel.buttons.allElementsBoundByIndex.contains {
                let frame = $0.frame
                return !frame.isEmpty && abs(frame.midX - carousel.frame.midX) < 1 && abs(frame.width - width) < 1
            }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [centered], timeout: 10), .completed)
        return try XCTUnwrap(carousel.buttons.allElementsBoundByIndex.first {
            let frame = $0.frame
            return !frame.isEmpty && abs(frame.midX - carousel.frame.midX) < 1 && abs(frame.width - width) < 1
        })
    }

    func testHomeTitlesFollowSimplifiedSettingLive() throws {
        try XCTSkipUnless(!isDuo)
        let originalOrientation = XCUIDevice.shared.orientation
        addTeardownBlock { XCUIDevice.shared.orientation = originalOrientation }
        XCUIDevice.shared.orientation = .landscapeLeft
        let root = FileManager.default.temporaryDirectory.appending(path: "HomeTitles-\(UUID())")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        addTeardownBlock { try FileManager.default.removeItem(at: root) }
        let source = try XCTUnwrap(Bundle(for: Self.self).resourceURL)
        for file in try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        where ["html", "png"].contains(file.pathExtension) {
            try FileManager.default.copyItem(at: file, to: root.appending(path: file.lastPathComponent))
        }
        let fixture = root.appending(path: "FrontPageList.html")
        var html = try String(contentsOf: fixture, encoding: .utf8)
        let titles = try NSRegularExpression(pattern: #"<div class="glink">[^<]+</div>"#)
        let matches = titles.matches(in: html, range: NSRange(html.startIndex..., in: html))
        XCTAssertGreaterThan(matches.count, 1)
        // Frontpage intentionally deduplicates titles, so each fixture must keep its own title.
        for (index, match) in matches.enumerated().reversed() {
            let range = try XCTUnwrap(Range(match.range, in: html))
            html.replaceSubrange(range, with: "<div class=\"glink\">[Studio] Home Study \(index + 1) [English]</div>")
        }
        try html.write(to: fixture, atomically: true, encoding: .utf8)
        let app = XCUIApplication()
        addTeardownBlock { app.terminate() }
        try app.launchStubbed(extraEnvironment: [
            "EHPANDA_AUTOMATION_TAB": "home", UITestConstants.fixtureDirectoryEnvironmentKey: root.path()
        ])
        assertSingleHomePane(in: app)
        for (iteration, enabled) in [true, false, true].enumerated() {
            if iteration > 0 {
                app.descendants(matching: .any)["gearshape.circle"].firstMatch.tapWhenHittable("Settings")
                app.buttons["Appearance"].tapWhenHittable("Appearance")
                let toggle = app.switches["simplified-gallery-titles"]
                XCTAssertTrue(toggle.waitForExistence(timeout: 5))
                toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).press(forDuration: 0.05)
                let changed = XCTNSPredicateExpectation(
                    predicate: NSPredicate(format: "value == %@", enabled ? "1" : "0"), object: toggle
                )
                XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
                let title = app.navigationBars["Appearance"].firstMatch
                title.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
                    forDuration: 0.05,
                    thenDragTo: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
                )
                XCTAssertTrue(title.waitForNonExistence(timeout: 5))
            }
            for prefix in ["home_slideshow_title_", "home_frontpage_title_", "home_ranking_title_"] {
                let type: XCUIElement.ElementType = prefix == "home_frontpage_title_" ? .button : .staticText
                let title = app.descendants(matching: type)
                    .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
                XCTAssertTrue(title.waitForExistence(timeout: 10), prefix)
                let pattern = enabled
                    ? #"^Home Study [0-9]+(?:,|$)"#
                    : #"^\[Studio\] Home Study [0-9]+ \[English\](?:,|$)"#
                XCTAssertNotNil(
                    title.label.range(of: pattern, options: .regularExpression), "\(prefix): \(title.label)"
                )
                if enabled { XCTAssertFalse(title.label.contains("[Studio]"), prefix) }
            }
        }
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "Home B sections with C slideshow and simplified titles"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let covers = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "home_frontpage_title_"))
        let firstRow = covers.allElementsBoundByIndex.prefix(4).map(\.frame)
        XCTAssertEqual(firstRow.count, 4)
        let firstTop = try XCTUnwrap(firstRow.first).minY
        for frame in firstRow { XCTAssertEqual(frame.minY, firstTop, accuracy: 1) }
        let history = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "History")).firstMatch
        let sections = app.scrollViews["home_sections"]
        for _ in 0..<12 where !history.isHittable { sections.swipeUp() }
        XCTAssertTrue(history.isHittable)
        let window = app.windows.firstMatch.frame
        let historyFrame = history.frame
        for name in ["Popular", "Watched", "History"] {
            let card = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
            XCTAssertTrue(card.isHittable, name)
            let frame = card.frame
            XCTAssertEqual(frame.minY, historyFrame.minY, accuracy: 1, name)
            XCTAssertGreaterThanOrEqual(frame.minX, window.minX, name)
            XCTAssertLessThanOrEqual(frame.maxX, window.maxX + 1, name)
        }
        let lowerSections = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        lowerSections.name = "Home B Toplists and Other sections"
        lowerSections.lifetime = .keepAlways
        add(lowerSections)
    }

    private func assertSingleHomePane(in app: XCUIApplication, landscape: Bool = true) {
        let orientation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            return landscape ? frame.width > frame.height : frame.height > frame.width
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [orientation], timeout: 5), .completed)
        let sections = app.scrollViews["home_sections"]
        XCTAssertTrue(sections.waitForExistence(timeout: 15))
        XCTAssertFalse(app.scrollViews["home_left_pane"].exists)
        XCTAssertFalse(app.scrollViews["home_right_pane"].exists)
        let window = app.windows.firstMatch.frame
        XCTAssertLessThan(sections.frame.minX, window.midX)
        XCTAssertGreaterThan(sections.frame.maxX, window.midX)
        XCTAssertTrue(app.navigationBars["Home"].staticTexts["Home"].isHittable)
    }

    func testReaderControlsMoveAndKeepTheirSideAfterRotation() throws {
        try prepareLandscape()
        let app = XCUIApplication()
        try app.openCold(XCTUnwrap(UITestConstants.singlePageURL(scheme: "ehpanda")))
        app.requireElement("reading_view")
        ReaderPageProbe(app: app).showPanel()
        assertControls(in: app, onLeft: false)
        print("CAPTURE_READER_RIGHT")
        app.buttons["reading_move_controls"].tapWhenHittable("Move controls left")
        assertControls(in: app, onLeft: true)
        print("CAPTURE_READER_LEFT")
        if isDuo { try DuoPose.set(.landscape) } else { XCUIDevice.shared.orientation = .portrait }
        XCTAssertTrue(app.buttons["reading_move_controls"].waitForNonExistence(timeout: 5))
        if isDuo { try DuoPose.set(.portrait) } else { XCUIDevice.shared.orientation = .landscapeLeft }
        assertControls(in: app, onLeft: true)
        app.buttons["reading_move_controls"].tapWhenHittable("Move controls right")
        assertControls(in: app, onLeft: false)
    }

    private func assertControls(in app: XCUIApplication, onLeft: Bool) {
        ReaderPageProbe(app: app).showPanel()
        let panel = app.requireElement("reading_lower_panel")
        let move = app.buttons["reading_move_controls"]
        XCTAssertTrue(move.waitForExistence(timeout: 5))
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let middle = app.windows.firstMatch.frame.midX
            return onLeft ? panel.frame.maxX <= middle + 1 : panel.frame.minX >= middle - 1
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 5), .completed)
        let middle = app.windows.firstMatch.frame.midX
        if onLeft {
            XCTAssertGreaterThanOrEqual(move.frame.minX, middle)
        } else {
            XCTAssertLessThanOrEqual(move.frame.maxX, middle)
        }
        XCTAssertTrue(move.isHittable)
        XCTAssertEqual(move.label, onLeft ? "Move controls right" : "Move controls left")
        XCTAssertEqual(move.frame.height, app.otherElements["reading_slider_row"].frame.height, accuracy: 1)
        XCTAssertGreaterThanOrEqual(move.frame.height, 44)
        XCTAssertTrue(panel.sliders.firstMatch.isHittable)
        let close = panel.buttons["Close"]
        XCTAssertEqual(close.exists, !isDuo)
        if !isDuo {
            XCTAssertTrue(close.isHittable)
            XCTAssertEqual(close.frame.midX, app.otherElements["reading_slider_row"].frame.midX, accuracy: 1)
            XCTAssertLessThan(close.frame.maxY, app.otherElements["reading_slider_row"].frame.minY)
        }
        XCTAssertEqual(app.otherElements["reading_view"].buttons.matching(identifier: "Close").count, isDuo ? 1 : 2)
    }
}
