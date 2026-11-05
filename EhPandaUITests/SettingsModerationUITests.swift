import XCTest

/// Settings end to end for Phase 18: the analytics level picker in General (UI-SPEC C-9) and the Blocked Users row and
/// list in Account (C-10 to C-12).
///
/// Every launch is stubbed and signed out, starts at the Settings tab and presets its own block list through
/// `EHPANDA_UITEST_BLOCKED_AUTHORS`, so no case depends on another's storage. A stubbed launch is preset past the first
/// launch with the Minimal level, so the picker always starts from Minimal.
@MainActor
final class SettingsModerationUITests: XCTestCase {
    private enum Copy {
        static let settings = "Settings"
        static let account = "Account"
        static let general = "General"
        static let blockedUsers = "Blocked Users"
        static let shareAnalyticsData = "Share Analytics Data"
        static let full = "Full"
        static let privacyPolicy = "Privacy Policy"
        static let minimalDescription =
            "Sends only a signal that EhPanda is installed, and where you installed the app from."
        static let fullDescription =
            "Everything in Basic, plus your reading and download activity and your main settings."
        static let empty = "You haven't blocked anyone."
        static let footer = "Comments from these users are collapsed on this device."
        static let logIn = "Log In"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Analytics

    func testTheAnalyticsPickerChangesTheLevelAndItsDescription() throws {
        let app = try launchAtSettings(blockedAuthors: [])
        try push(Copy.general, in: app)

        let picker = app.buttons["setting_analytics_level"]
        try scrollIntoReach(picker, in: app)
        XCTAssertTrue(app.staticTexts[Copy.minimalDescription].exists, "The footer does not describe Minimal.")
        // A `Link`, so a link element rather than a button.
        let privacyPolicy = app.links["setting_privacy_policy"]
        try scrollIntoReach(privacyPolicy, in: app)
        XCTAssertEqual(privacyPolicy.label, Copy.privacyPolicy, "The Privacy Policy row is mislabelled.")
        try scrollIntoReach(picker, in: app, direction: .downward)
        keepScreenshot("settings-analytics-minimal", app: app)

        picker.tapWhenHittable("The analytics picker")
        let full = app.buttons[Copy.full].firstMatch
        full.tapWhenHittable("The Full level")
        XCTAssertTrue(
            app.staticTexts[Copy.fullDescription].waitForExistence(timeout: 10),
            "The footer did not change to Full's description."
        )
        XCTAssertFalse(app.staticTexts[Copy.minimalDescription].exists, "Minimal's description stayed.")
        keepScreenshot("settings-analytics-full", app: app)
        app.terminate()
    }

    // MARK: Blocked Users

    func testBlockedUsersCanBeUnblockedBySwipeAndContextMenu() throws {
        let app = try launchAtSettings(blockedAuthors: ["囧斯诺", "Roobubba"])
        try push(Copy.account, in: app)

        // Blocking works without an account, so the row is there signed out (D-14a).
        XCTAssertTrue(app.buttons[Copy.logIn].firstMatch.exists, "The launch is not signed out.")
        let row = app.buttons["setting_blocked_users"]
        try scrollIntoReach(row, in: app)
        XCTAssertEqual(row.label, Copy.blockedUsers, "The Blocked Users row is mislabelled.")
        XCTAssertEqual(row.value as? String, "2", "The Blocked Users row does not count two names.")
        keepScreenshot("account-blocked-users-row", app: app)

        row.tapWhenHittable("The Blocked Users row")
        requireNavigationTitle(Copy.blockedUsers, in: app)
        let latin = app.staticTexts["Roobubba"]
        let han = app.staticTexts["囧斯诺"]
        XCTAssertTrue(latin.waitForExistence(timeout: 10), "Roobubba is not listed.")
        XCTAssertTrue(han.exists, "囧斯诺 is not listed.")
        XCTAssertLessThan(latin.frame.minY, han.frame.minY, "The names are not in localized standard order.")
        XCTAssertTrue(app.staticTexts[Copy.footer].exists, "The footer is missing.")
        keepScreenshot("blocked-users-list", app: app)

        // A full swipe unblocks at once, with no confirmation.
        fullSwipe(cell(containing: latin, in: app), in: app)
        XCTAssertTrue(latin.waitForNonExistence(timeout: 10), "The full swipe did not unblock Roobubba.")
        XCTAssertTrue(han.exists, "The full swipe removed the wrong name.")

        // The context menu unblocks the other, also with no confirmation.
        cell(containing: han, in: app).press(forDuration: 1.2)
        app.buttons["Unblock 囧斯诺"].firstMatch.tapWhenHittable("The context menu's Unblock")
        XCTAssertTrue(han.waitForNonExistence(timeout: 10), "The context menu did not unblock 囧斯诺.")

        // The last name gone, the screen shows the empty state in place, without the footer.
        XCTAssertTrue(app.staticTexts[Copy.empty].waitForExistence(timeout: 10), "The empty state is missing.")
        XCTAssertFalse(app.staticTexts[Copy.footer].exists, "The footer shows with nobody blocked.")
        requireNavigationTitle(Copy.blockedUsers, in: app)
        keepScreenshot("blocked-users-empty", app: app)

        app.navigationBars[Copy.blockedUsers].buttons.firstMatch.tapWhenHittable("Back")
        requireNavigationTitle(Copy.account, in: app)
        let countsZero = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "0"), object: row)
        XCTAssertEqual(
            XCTWaiter.wait(for: [countsZero], timeout: 10), .completed, "The Blocked Users row does not count zero."
        )
        app.terminate()
    }

    func testTheRowCountsZeroAndOpensTheEmptyList() throws {
        let app = try launchAtSettings(blockedAuthors: [])
        try push(Copy.account, in: app)

        let row = app.buttons["setting_blocked_users"]
        try scrollIntoReach(row, in: app)
        XCTAssertEqual(row.value as? String, "0", "The Blocked Users row does not show 0.")

        row.tapWhenHittable("The Blocked Users row")
        requireNavigationTitle(Copy.blockedUsers, in: app)
        XCTAssertTrue(app.staticTexts[Copy.empty].waitForExistence(timeout: 10), "The empty state is missing.")
        XCTAssertFalse(app.staticTexts[Copy.footer].exists, "The footer shows with nobody blocked.")
        app.terminate()
    }
}

// MARK: Helpers

private extension SettingsModerationUITests {
    func launchAtSettings(blockedAuthors: [String]) throws -> XCUIApplication {
        let app = XCUIApplication()
        let names = try XCTUnwrap(
            String(bytes: JSONSerialization.data(withJSONObject: blockedAuthors), encoding: .utf8)
        )
        try app.launchStubbed(extraEnvironment: [
            "EHPANDA_AUTOMATION_TAB": "setting",
            UITestConstants.blockedAuthorsEnvironmentKey: names
        ])
        app.requireForeground()
        requireNavigationTitle(Copy.settings, in: app)
        return app
    }

    func push(_ label: String, in app: XCUIApplication) throws {
        let button = app.buttons[label].firstMatch
        try scrollIntoReach(button, in: app)
        button.tapWhenHittable("The \(label) row")
        requireNavigationTitle(label, in: app)
    }

    func requireNavigationTitle(_ title: String, in app: XCUIApplication, line: UInt = #line) {
        XCTAssertTrue(
            app.navigationBars[title].waitForExistence(timeout: 15),
            "The \(title) navigation title did not appear.",
            line: line
        )
    }

    enum ScrollDirection { case upward, downward }

    /// Swipes the screen's scroll view until `element` is hittable: upward by default, to reach further down the list,
    /// or down to come back.
    func scrollIntoReach(
        _ element: XCUIElement, in app: XCUIApplication, direction: ScrollDirection = .upward, line: UInt = #line
    ) throws {
        let list = app.collectionViews.firstMatch
        var swipes = 0
        while !element.exists, swipes < 8 {
            swipe(list, direction)
            swipes += 1
        }
        XCTAssertTrue(element.waitForExistence(timeout: 15), "\(element) did not appear.", line: line)
        while !element.isHittable, swipes < 8 {
            swipe(list, direction)
            swipes += 1
        }
        XCTAssertTrue(element.isHittable, "\(element) never came into reach.", line: line)
    }

    func swipe(_ list: XCUIElement, _ direction: ScrollDirection) {
        switch direction {
        case .upward: list.swipeUp()
        case .downward: list.swipeDown()
        }
    }

    func cell(containing text: XCUIElement, in app: XCUIApplication) -> XCUIElement {
        app.cells.containing(.staticText, identifier: text.label).firstMatch
    }

    /// Drags the row from its trailing edge past the screen's leading third, the swipe that runs the trailing action
    /// with no further tap.
    func fullSwipe(_ cell: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(cell.waitUntilHittable(timeout: XCUIElement.hittableTimeout), "The row is out of reach.")
        let start = cell.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        let end = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0))
            .withOffset(CGVector(dx: 0, dy: cell.frame.midY))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .fast, thenHoldForDuration: 0.1)
    }

    func keepScreenshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
