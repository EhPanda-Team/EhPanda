import XCTest

/// Keeps a screenshot of the age wall and of the analytics choice in each of the six app languages, at the default
/// text size and at AX5, for the UI-SPEC C-3 line-break check (owner msg 1822): neither title may end on a single
/// word, or on fewer than two characters in Chinese, Japanese and Korean.
///
/// The line check is visual, read from the kept screenshots (`age-wall-<locale>-<size>` and
/// `analytics-choice-<locale>-<size>`); the test asserts only that both titles and the analytics intro are there.
/// Each language is its own case, so a slow launch never runs one case past its time allowance.
@MainActor
final class FirstLaunchTitleLayoutUITests: XCTestCase {
    private enum Identifier {
        static let ageWall = "first_launch_age_wall"
        static let ageWallTitle = "first_launch_age_wall_title"
        static let analyticsChoice = "first_launch_analytics_choice"
        static let analyticsTitle = "first_launch_analytics_title"
        static let intro = "first_launch_analytics_intro"
        static let declaration = "first_launch_declaration"
        static let continueButton = "first_launch_continue"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEnglishTitles() throws {
        try captureTitles(in: .english)
    }

    func testGermanTitles() throws {
        try captureTitles(in: .german)
    }

    func testKoreanTitles() throws {
        try captureTitles(in: .korean)
    }

    func testJapaneseTitles() throws {
        try captureTitles(in: .japanese)
    }

    func testSimplifiedChineseTitles() throws {
        try captureTitles(in: .simplifiedChinese)
    }

    func testTraditionalChineseTitles() throws {
        try captureTitles(in: .traditionalChinese)
    }
}

// MARK: Helpers

private extension FirstLaunchTitleLayoutUITests {
    /// How many swipes may bring a control at the end of an AX5 screen into reach.
    static let maximumSwipes = 12

    /// Shows the age wall, then the analytics choice, in `language` at both text sizes, keeping each screen as it
    /// first appears, scrolled to the top.
    func captureTitles(in language: LocalizedLaunch.Language) throws {
        let app = XCUIApplication()
        for textSize in LocalizedLaunch.TextSize.allCases {
            let localized = LocalizedLaunch(language: language, textSize: textSize)
            try localized.launch(app, extraEnvironment: [UITestConstants.firstLaunchEnvironmentKey: "show"])
            app.requireForeground()

            let ageWall = app.scrollViews[Identifier.ageWall]
            XCTAssertTrue(
                ageWall.waitForExistence(timeout: 15),
                "The age wall is missing in \(localized.screenshotName(of: "age-wall"))."
            )
            XCTAssertTrue(app.staticTexts[Identifier.ageWallTitle].exists, "The age wall title is missing.")
            localized.keepScreenshot(of: "age-wall", app: app, in: self)

            let continueButton = app.buttons[Identifier.continueButton]
            tapAfterScrolling(
                app.switches[Identifier.declaration], in: ageWall, clearOf: continueButton, name: "Statement"
            )
            XCTAssertTrue(continueButton.wait(for: \.isEnabled, toEqual: true, timeout: 5), "Continue stayed dimmed.")
            // Continue is pinned in the bar at every size (D-17b), so it needs no swipe.
            continueButton.tapWhenHittable("Continue")

            let analyticsChoice = app.scrollViews[Identifier.analyticsChoice]
            XCTAssertTrue(analyticsChoice.waitForExistence(timeout: 15), "The analytics choice is missing.")
            XCTAssertTrue(app.staticTexts[Identifier.analyticsTitle].exists, "The analytics title is missing.")
            XCTAssertTrue(app.staticTexts[Identifier.intro].exists, "The analytics intro is missing.")
            // The step change slides; the screenshot waits for it to settle.
            XCTAssertTrue(
                app.staticTexts[Identifier.analyticsTitle].waitUntilHittable(timeout: XCUIElement.hittableTimeout),
                "The analytics title never settled."
            )
            localized.keepScreenshot(of: "analytics-choice", app: app, in: self)
        }
        app.terminate()
    }

    /// Taps `element`, swiping `scrollView` up first until it clears `bar`, the pinned Continue (at AX5 the checkbox
    /// card runs past the screen, and a card half under the bar would take the tap on the bar).
    func tapAfterScrolling(
        _ element: XCUIElement,
        in scrollView: XCUIElement,
        clearOf bar: XCUIElement,
        name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var swipes = 0
        // The tap lands on the element's centre, so the centre must clear the bar.
        while !element.exists || element.frame.midY >= bar.frame.minY - 16, swipes < Self.maximumSwipes {
            scrollView.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(
            element.waitUntilHittable(timeout: XCUIElement.hittableTimeout),
            "\(name) is out of reach.",
            file: file,
            line: line
        )
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }
}
