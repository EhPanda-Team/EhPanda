import XCTest

/// The first launch end to end (AGE-18-01, CONSENT-18-01; UI-SPEC C-1 to C-3): the age wall, then the analytics
/// choice, then the app, with nothing of the app rendered and no request made before the age wall's Continue.
///
/// Each launch asks for its own first-launch state through `UITestConstants.firstLaunchEnvironmentKey` and logs its
/// requests to a file of its own, so the cases share no storage or order.
@MainActor
final class FirstLaunchUITests: XCTestCase {
    private enum Copy {
        static let ageWallTitle = "EhPanda is for adults"
        static let ageWallBody = "This app shows sexually explicit content."
        static let declaration =
            "Under every law that applies to me, I'm an adult and may view sexually explicit content."
        static let footnote = "If this isn't true for you, please close EhPanda."
        static let consentTitle = "Choose what EhPanda shares"
        static let consentBody = "Anonymous analytics. Your searches and the galleries you view are never sent."
        static let consentFooter = "You can change this anytime in Settings."
        static let recommended = "Recommended"
        static let minimalDescription =
            "Sends only a signal that EhPanda is installed, and where you installed the app from."
        static let basicDescription = "Everything in Minimal, plus how often the app is used, which screens and "
            + "features you use, technical details such as device model and app version, and which kinds of errors "
            + "occur."
        static let fullDescription =
            "Everything in Basic, plus your reading and download activity and your main settings."
    }

    private enum Identifier {
        static let ageWall = "first_launch_age_wall"
        static let analyticsChoice = "first_launch_analytics_choice"
        static let declaration = "first_launch_declaration"
        static let continueButton = "first_launch_continue"
        static let intro = "first_launch_analytics_intro"
        static let privacyLink = "first_launch_privacy_link"
        static func level(_ name: String) -> String { "first_launch_level_\(name)" }
    }

    private var requestLogURL: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        requestLogURL = FileManager.default.temporaryDirectory
            .appending(path: "first-launch-requests-\(UUID().uuidString).log")
    }

    override func tearDownWithError() throws {
        if let requestLogURL, FileManager.default.fileExists(atPath: requestLogURL.path()) {
            try FileManager.default.removeItem(at: requestLogURL)
        }
    }

    // MARK: Age wall

    func testAFreshLaunchShowsOnlyTheAgeWallAndMakesNoRequest() throws {
        let app = XCUIApplication()
        try launch(app, firstLaunch: "show")

        app.requireElement(Identifier.ageWall)
        XCTAssertTrue(app.staticTexts[Copy.ageWallTitle].exists, "The age wall title is missing.")
        XCTAssertTrue(app.staticTexts[Copy.ageWallBody].exists, "The age wall body is missing.")
        XCTAssertTrue(app.staticTexts[Copy.footnote].exists, "The footnote must always be visible.")
        let declaration = app.switches[Identifier.declaration]
        XCTAssertTrue(declaration.exists, "The checkbox card is missing.")
        XCTAssertEqual(declaration.label, Copy.declaration)

        let continueButton = app.buttons[Identifier.continueButton]
        XCTAssertTrue(continueButton.exists, "Continue is missing.")
        XCTAssertFalse(continueButton.isEnabled, "Continue must stay dimmed until the statement is ticked.")
        requireNoAppContent(app)

        // Give the launch time to start anything it would start, then require that the stub saw nothing.
        _ = app.staticTexts["never-present"].waitForExistence(timeout: 3)
        XCTAssertEqual(loggedRequests(), [], "A request was made before the age wall was confirmed.")
    }

    func testTickingTheStatementGatesContinue() throws {
        let app = XCUIApplication()
        try launch(app, firstLaunch: "show")

        app.requireElement(Identifier.ageWall)
        let declaration = app.switches[Identifier.declaration]
        let continueButton = app.buttons[Identifier.continueButton]
        XCTAssertFalse(declaration.isSelected)

        declaration.tapWhenHittable("Statement")
        XCTAssertTrue(
            continueButton.wait(for: \.isEnabled, toEqual: true, timeout: 5),
            "Ticking did not enable Continue."
        )
        XCTAssertTrue(declaration.isSelected, "The ticked checkbox is not reported as selected.")

        declaration.tapWhenHittable("Statement")
        XCTAssertTrue(
            continueButton.wait(for: \.isEnabled, toEqual: false, timeout: 5),
            "Unticking did not dim Continue again."
        )
        XCTAssertEqual(loggedRequests(), [], "Ticking alone must not open the network.")

        declaration.tapWhenHittable("Statement")
        continueButton.tapWhenHittable("Continue")
        app.requireElement(Identifier.analyticsChoice)
        XCTAssertTrue(app.staticTexts[Copy.consentTitle].exists, "The analytics title is missing.")
        XCTAssertFalse(app.staticTexts[Copy.ageWallTitle].exists, "The age wall is still shown.")
    }

    // MARK: Analytics choice

    func testTheAnalyticsChoiceStartsEmptyAndRecommendsBasicOnly() throws {
        let app = XCUIApplication()
        try launch(app, firstLaunch: "show")
        confirmAge(app)

        app.requireElement(Identifier.analyticsChoice)
        let intro = app.staticTexts[Identifier.intro]
        XCTAssertTrue(intro.exists, "The analytics intro is missing.")
        XCTAssertEqual(intro.label, "\(Copy.consentBody) \(Copy.consentFooter)")

        let minimal = app.buttons[Identifier.level("minimal")]
        let basic = app.buttons[Identifier.level("basic")]
        let full = app.buttons[Identifier.level("full")]
        for card in [minimal, basic, full] {
            XCTAssertTrue(card.exists, "\(card.identifier) is missing.")
            XCTAssertFalse(card.isSelected, "\(card.identifier) is selected before any tap.")
        }
        XCTAssertLessThan(minimal.frame.minY, basic.frame.minY, "Minimal must come before Basic.")
        XCTAssertLessThan(basic.frame.minY, full.frame.minY, "Basic must come before Full.")

        XCTAssertTrue(minimal.label.contains(Copy.minimalDescription), minimal.label)
        XCTAssertTrue(basic.label.contains(Copy.basicDescription), basic.label)
        XCTAssertTrue(full.label.contains(Copy.fullDescription), full.label)
        XCTAssertTrue(basic.label.contains(Copy.recommended), "Basic is not marked Recommended: \(basic.label)")
        XCTAssertFalse(minimal.label.contains(Copy.recommended), minimal.label)
        XCTAssertFalse(full.label.contains(Copy.recommended), full.label)

        // The Privacy Policy link sits under the intro, above the cards.
        let privacyLink = app.descendants(matching: .any)[Identifier.privacyLink]
        XCTAssertTrue(privacyLink.exists, "The Privacy Policy link is missing.")
        XCTAssertLessThan(intro.frame.maxY, privacyLink.frame.minY)
        XCTAssertLessThan(privacyLink.frame.maxY, minimal.frame.minY)

        let continueButton = app.buttons[Identifier.continueButton]
        XCTAssertFalse(continueButton.isEnabled, "Continue must stay dimmed until a level is picked.")
        requireNoAppContent(app)

        basic.tapWhenHittable("Basic")
        XCTAssertTrue(basic.wait(for: \.isSelected, toEqual: true, timeout: 5), "Basic did not become selected.")
        XCTAssertFalse(minimal.isSelected)
        XCTAssertFalse(full.isSelected)
        XCTAssertTrue(basic.label.contains(Copy.recommended), "The label must stay after selecting Basic.")
        XCTAssertTrue(continueButton.isEnabled, "Picking a level did not enable Continue.")

        full.tapWhenHittable("Full")
        XCTAssertTrue(full.wait(for: \.isSelected, toEqual: true, timeout: 5), "Full did not become selected.")
        XCTAssertFalse(basic.isSelected, "Selecting Full must deselect Basic.")

        continueButton.tapWhenHittable("Continue")
        requireAppContent(app)
        XCTAssertFalse(app.descendants(matching: .any)[Identifier.analyticsChoice].exists)
    }

    func testAnUpgraderWithTheAgeAnsweredOpensOnTheAnalyticsChoice() throws {
        let app = XCUIApplication()
        try launch(app, firstLaunch: "analytics")

        app.requireElement(Identifier.analyticsChoice)
        XCTAssertFalse(app.staticTexts[Copy.ageWallTitle].exists, "An answered age wall was shown again.")
        requireNoAppContent(app)

        app.buttons[Identifier.level("minimal")].tapWhenHittable("Minimal")
        app.buttons[Identifier.continueButton].tapWhenHittable("Continue")
        requireAppContent(app)
    }

    // MARK: Deep links (DD-07)

    func testALinkOpenedAtTheGateOpensItsGalleryAfterBothAnswers() throws {
        let app = XCUIApplication()
        let galleryURL = try XCTUnwrap(UITestConstants.galleryURL(scheme: "ehpanda"))
        try app.openCold(galleryURL, extraEnvironment: environment(firstLaunch: "show"))

        app.requireForeground()
        app.requireElement(Identifier.ageWall)
        XCTAssertFalse(app.descendants(matching: .any)["detail_view"].exists, "The link opened behind the gate.")
        XCTAssertEqual(loggedRequests(), [], "The link made a request before the age wall was confirmed.")

        confirmAge(app)
        app.requireElement(Identifier.analyticsChoice)
        XCTAssertFalse(app.descendants(matching: .any)["detail_view"].exists, "The link opened behind the choice.")
        app.buttons[Identifier.level("basic")].tapWhenHittable("Basic")
        app.buttons[Identifier.continueButton].tapWhenHittable("Continue")

        app.requireElement("detail_view", matching: .scrollView)
        XCTAssertTrue(
            app.buttons[UITestConstants.primaryMarkerTitle].waitForExistence(timeout: 15),
            "The queued link did not open its gallery after the first launch."
        )
    }
}

// MARK: Helpers

private extension FirstLaunchUITests {
    func environment(firstLaunch: String) -> [String: String] {
        [
            UITestConstants.firstLaunchEnvironmentKey: firstLaunch,
            UITestConstants.requestLogEnvironmentKey: requestLogURL.path()
        ]
    }

    func launch(_ app: XCUIApplication, firstLaunch: String) throws {
        try app.launchStubbed(extraEnvironment: environment(firstLaunch: firstLaunch))
        app.requireForeground()
    }

    func confirmAge(_ app: XCUIApplication) {
        app.requireElement(Identifier.ageWall)
        app.switches[Identifier.declaration].tapWhenHittable("Statement")
        app.buttons[Identifier.continueButton].tapWhenHittable("Continue")
    }

    /// The lines the stub protocol logged so far; none when the file was never written.
    func loggedRequests() -> [String] {
        guard FileManager.default.fileExists(atPath: requestLogURL.path()) else { return [] }
        do {
            return try String(contentsOf: requestLogURL, encoding: .utf8)
                .split(separator: "\n")
                .map(String.init)
        } catch {
            XCTFail("The request log could not be read: \(error)")
            return []
        }
    }

    func requireNoAppContent(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(app.tabBars.firstMatch.exists, "A tab bar is rendered behind the gate.", file: file, line: line)
        XCTAssertFalse(app.buttons["Library"].exists, "A tab is rendered behind the gate.", file: file, line: line)
        XCTAssertFalse(
            app.descendants(matching: .any)["home_carousel"].exists,
            "Home is rendered behind the gate.",
            file: file,
            line: line
        )
    }

    func requireAppContent(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            app.buttons["Library"].waitForExistence(timeout: 15),
            "The app's tabs did not appear after the first launch.",
            file: file,
            line: line
        )
    }
}
