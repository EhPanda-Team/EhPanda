import UIKit
import XCTest

/// The Report form sheet in each of its UI-SPEC C-13 states (18.1-04), on the device each applies to: loading [31],
/// ready from a comment [25], typing and an invalid email [26], sending [27], sent [28], failed [29], unavailable [30],
/// the largest text size [33] and the iPad form sheet with ⌘↩ [34]. Frame 32 is withdrawn: there are no gallery
/// reports.
///
/// Every launch is stubbed. The form's page and the reply to a report come from the bundled fixtures, picked by the
/// launch's `EHPANDA_UITEST_REPORT_SCENARIO`, and the site's report page opens on a blank page. Each case keeps a
/// request log, so it can prove what was posted and what was not.
@MainActor
final class ReportFormUITests: XCTestCase {
    private enum Copy {
        static let reportOnSite = "Report on E-Hentai"
        static let title = "Report on E-Hentai"
        static let loading = "Loading the report form…"
        static let send = "Send Report"
        static let sending = "Sending…"
        static let done = "Done"
        static let openReportPage = "Open Report Page"
        static let sentTitle = "Report Sent"
        static let sentBody = "Your report was sent to E-Hentai's staff."
        static let failedTitle = "Couldn't Send Report"
        static let retry = "Retry"
        static let cancel = "Cancel"
        static let emailFooter = "E-Hentai requires a working email address."
        static let emailInvalid = "Enter a working email address."
        static let prefillStart = "Reporting a comment by"
        static let close = "Close"
        static let validEmail = "tester@example.com"
        static let typedDetails = "The linked page hosts illegal content."
    }

    private enum Identifier {
        static let form = "report_form"
        static let loading = "report_loading"
        static let unavailable = "report_unavailable"
        static let sent = "report_sent"
        static let primary = "report_primary_button"
        static let email = "report_email"
        static let details = "report_details"
        static let illegalWarning = "report_illegal_warning"
        static let emailInvalid = "report_email_invalid"
        static let child = "report_reason_child"
        static let other = "report_reason_other"
        static let sessionWebView = "session_web_view"
        static let commentsView = "comments_view"
        static let commentCell = "comment_cell_" + UITestConstants.commentID
    }

    /// Where every report request goes: the stub logs the gallery path without its `report` query.
    private static let reportPost =
        "POST e-hentai.org /g/\(UITestConstants.primaryGID)/\(UITestConstants.primaryToken)/"
    private static let reportPageURL =
        "https://e-hentai.org/g/\(UITestConstants.primaryGID)/\(UITestConstants.primaryToken)/?report=select"

    private var requestLogURL: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        requestLogURL = FileManager.default.temporaryDirectory
            .appending(path: "report-form-requests-\(UUID().uuidString).log")
    }

    override func tearDownWithError() throws {
        if let requestLogURL, FileManager.default.fileExists(atPath: requestLogURL.path()) {
            try FileManager.default.removeItem(at: requestLogURL)
        }
    }

    // MARK: States

    /// [31] The page takes 6 s: after 0.3 s the spinner and its line show, and Send Report waits, dimmed.
    func testLoadingShowsTheSpinnerAndADimmedSend() throws {
        let app = try openReportForm(scenario: "slowLoad", waitsForForm: false)
        let loading = app.descendants(matching: .any)[Identifier.loading]
        XCTAssertTrue(loading.waitForExistence(timeout: 5), "The loading state shows no spinner.")
        keepScreenshot("report-31-loading", app: app)
        XCTAssertTrue(
            app.staticTexts[Copy.loading].exists || loading.label.contains(Copy.loading),
            "The spinner has no line under it."
        )
        let primary = primaryButton(in: app)
        XCTAssertTrue(primary.exists, "The loading state has no pinned button.")
        XCTAssertFalse(primary.isEnabled, "Send Report is enabled while the form loads.")
        XCTAssertTrue(
            app.descendants(matching: .any)[Identifier.form].waitForExistence(timeout: 15), "The form never loaded."
        )
        XCTAssertFalse(loading.exists, "The spinner stayed after the form loaded.")
        app.terminate()
    }

    /// [25] The form from a comment: the title, exactly two reasons with neither picked, Send Report dimmed, Close
    /// the only bar button and Details filled in with the comment.
    func testTheReadyFormFromAComment() throws {
        let app = try openReportForm(scenario: "ready")
        keepScreenshot("report-25-ready", app: app)

        XCTAssertTrue(app.navigationBars[Copy.title].exists, "The sheet is not titled \(Copy.title).")
        let reasons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'report_reason_'"))
        XCTAssertEqual(reasons.count, 2, "The form offers other reasons than child and other illegal content.")
        let child = app.buttons[Identifier.child]
        let other = app.buttons[Identifier.other]
        XCTAssertTrue(child.exists, "The form has no child pornography reason.")
        XCTAssertTrue(other.exists, "The form has no other illegal content reason.")
        XCTAssertLessThan(child.frame.minY, other.frame.minY, "Child pornography does not come first.")
        XCTAssertFalse(child.isSelected, "A reason is picked before the user picks one.")
        XCTAssertFalse(other.isSelected, "A reason is picked before the user picks one.")
        XCTAssertFalse(app.descendants(matching: .any)[Identifier.illegalWarning].exists, "The warning shows unasked.")

        let primary = primaryButton(in: app)
        XCTAssertEqual(primary.label, Copy.send, "The pinned button does not read Send Report.")
        XCTAssertFalse(primary.isEnabled, "Send Report is enabled on an empty form.")

        let barButtons = app.navigationBars[Copy.title].buttons
        XCTAssertEqual(barButtons.count, 1, "The sheet's bar holds more than Close.")
        XCTAssertEqual(barButtons.firstMatch.label, Copy.close, "The sheet's only bar button is not Close.")

        let details = detailsField(in: app)
        let value = try XCTUnwrap(details.value as? String, "Details holds no text.")
        XCTAssertTrue(value.hasPrefix(Copy.prefillStart), "Details does not start with the comment: \(value).")
        XCTAssertTrue(value.contains("黑锋血色"), "Details does not name the comment's author: \(value).")
        app.terminate()
    }

    /// [26] The warning follows the first pick, a switch keeps what was typed, Send checks the email before anything
    /// is sent, and fixing it brings the usual footer back. Return in Email moves to Details.
    func testTypingAndAnInvalidEmail() throws {
        let app = try openReportForm(scenario: "ready")
        let details = detailsField(in: app)

        app.buttons[Identifier.child].tapWhenHittable("Child pornography")
        XCTAssertTrue(app.buttons[Identifier.child].isSelected, "The picked reason is not selected.")
        XCTAssertTrue(
            app.descendants(matching: .any)[Identifier.illegalWarning].waitForExistence(timeout: 5),
            "Picking a reason shows no warning."
        )
        requireKeyboardFocus(details, "Details after the first pick")
        details.typeText(Copy.typedDetails)

        app.buttons[Identifier.other].tapWhenHittable("Other illegal content")
        XCTAssertTrue(app.buttons[Identifier.other].isSelected, "Switching does not select the other reason.")
        XCTAssertFalse(app.buttons[Identifier.child].isSelected, "Switching keeps the first reason selected.")
        XCTAssertTrue(
            (details.value as? String)?.contains(Copy.typedDetails) == true, "Switching the reason lost the text."
        )

        let email = app.textFields[Identifier.email]
        email.tapWhenHittable("Email")
        email.typeText("a")
        let primary = primaryButton(in: app)
        XCTAssertTrue(primary.waitForEnabled(), "Send Report stays dimmed on a filled-in form.")
        primary.tapWhenHittable("Send Report")

        let invalid = app.descendants(matching: .any)[Identifier.emailInvalid]
        XCTAssertTrue(invalid.waitForExistence(timeout: 5), "A malformed email shows no error.")
        XCTAssertTrue(invalid.label.contains(Copy.emailInvalid), "The error reads \(invalid.label).")
        keepScreenshot("report-26-invalid-email", app: app)
        XCTAssertFalse(try loggedRequests().contains(Self.reportPost), "A malformed email was sent.")

        requireKeyboardFocus(email, "Email after the error")
        email.typeText(XCUIKeyboardKey.delete.rawValue + Copy.validEmail)
        XCTAssertTrue(invalid.waitForNonExistence(timeout: 5), "Fixing the email kept the error.")
        let footer = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", Copy.emailFooter)).firstMatch
        XCTAssertTrue(footer.waitForExistence(timeout: 5), "The email footer did not come back.")
        keepScreenshot("report-26-typing", app: app)

        email.typeText("\n")
        requireKeyboardFocus(details, "Details after Return in Email")
        XCTAssertFalse(try loggedRequests().contains(Self.reportPost), "Something was sent without Send.")
        app.terminate()
    }

    /// [27] While a report is on the wire: a spinner with Sending…, the button and Close dimmed, and a swipe down
    /// does not close the sheet.
    func testSendingLocksTheSheet() throws {
        let app = try openReportForm(scenario: "holdSend")
        try fillInTheForm(in: app)
        let primary = primaryButton(in: app)
        primary.tapWhenHittable("Send Report")

        XCTAssertTrue(primary.waitForLabel(containing: Copy.sending, timeout: 2), "Sending shows \(primary.label).")
        keepScreenshot("report-27-sending", app: app)
        XCTAssertFalse(primary.isEnabled, "The button can be tapped again while sending.")
        let close = app.navigationBars[Copy.title].buttons[Copy.close]
        XCTAssertFalse(close.isEnabled, "Close can be tapped while sending.")
        app.navigationBars[Copy.title].swipeDown(velocity: .fast)
        XCTAssertTrue(app.descendants(matching: .any)[Identifier.form].exists, "A swipe down closed the sheet.")

        XCTAssertTrue(app.descendants(matching: .any)[Identifier.sent].waitForExistence(timeout: 10), "It never sent.")
        XCTAssertEqual(try loggedRequests().filter({ $0 == Self.reportPost }).count, 1, "The report was not sent once.")
        app.terminate()
    }

    /// [28] Sent replaces the form: the symbol, title and body, no Close, and Done closes the sheet after exactly one
    /// post.
    func testSentReplacesTheFormAndDoneCloses() throws {
        let app = try openReportForm(scenario: "ready")
        try fillInTheForm(in: app)
        primaryButton(in: app).tapWhenHittable("Send Report")

        let sent = app.descendants(matching: .any)[Identifier.sent]
        XCTAssertTrue(sent.waitForExistence(timeout: 10), "The sent state did not show.")
        XCTAssertTrue(app.staticTexts[Copy.sentTitle].exists, "The sent state has no title.")
        XCTAssertTrue(app.staticTexts[Copy.sentBody].exists, "The sent state has no body.")
        XCTAssertFalse(app.descendants(matching: .any)[Identifier.form].exists, "The form stayed under the sent state.")
        XCTAssertFalse(app.buttons[Copy.close].exists, "The sent state keeps Close.")
        let primary = primaryButton(in: app)
        XCTAssertEqual(primary.label, Copy.done, "The pinned button does not read Done.")
        keepScreenshot("report-28-sent", app: app)
        XCTAssertEqual(try loggedRequests().filter({ $0 == Self.reportPost }).count, 1, "The report was not sent once.")

        primary.tapWhenHittable("Done")
        XCTAssertTrue(sent.waitForNonExistence(timeout: 10), "Done did not close the sheet.")
        XCTAssertTrue(app.collectionViews[Identifier.commentsView].exists, "Done did not return to the comments.")
        app.terminate()
    }

    /// [29] A failed report keeps the form under an alert of Retry, Open Report Page and Cancel. Cancel keeps the
    /// text, Retry posts again, and Open Report Page shows the site's page over the form, which closing returns to.
    func testFailedOffersRetryTheSitesPageAndCancel() throws {
        let app = try openReportForm(scenario: "failSend")
        try fillInTheForm(in: app)
        let primary = primaryButton(in: app)
        primary.tapWhenHittable("Send Report")

        let alert = app.alerts[Copy.failedTitle]
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "A failed report raised no alert.")
        keepScreenshot("report-29-failed", app: app)
        let labels = alert.buttons.allElementsBoundByIndex.map(\.label)
        XCTAssertEqual(labels, [Copy.retry, Copy.openReportPage, Copy.cancel], "The alert's buttons are \(labels).")
        XCTAssertEqual(primary.label, Copy.send, "Under the alert the pinned button reads \(primary.label).")
        XCTAssertEqual(try loggedRequests().filter({ $0 == Self.reportPost }).count, 1, "The report was not sent once.")

        alert.buttons[Copy.cancel].tapWhenHittable("Cancel")
        XCTAssertTrue(alert.waitForNonExistence(timeout: 5), "Cancel did not close the alert.")
        XCTAssertTrue(
            (detailsField(in: app).value as? String)?.contains(Copy.typedDetails) == true, "Cancel lost the details."
        )
        XCTAssertEqual(app.textFields[Identifier.email].value as? String, Copy.validEmail, "Cancel lost the email.")

        primary.tapWhenHittable("Send Report again")
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "The second failure raised no alert.")
        alert.buttons[Copy.retry].tapWhenHittable("Retry")
        XCTAssertTrue(try waitForRequestCount(Self.reportPost, 3), "Retry did not post again.")
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "The failed retry raised no alert.")

        alert.buttons[Copy.openReportPage].tapWhenHittable("Open Report Page")
        let webView = app.webViews[Identifier.sessionWebView]
        XCTAssertTrue(webView.waitForExistence(timeout: 15), "Open Report Page did not show the site's page.")
        XCTAssertEqual(webView.value as? String, Self.reportPageURL, "The sheet holds another page.")
        keepScreenshot("report-29-site-page", app: app)
        topmostClose(in: app).tap()
        XCTAssertTrue(webView.waitForNonExistence(timeout: 10), "The site's page did not close.")
        XCTAssertTrue(app.descendants(matching: .any)[Identifier.form].exists, "Closing the page lost the form.")
        XCTAssertTrue(
            (detailsField(in: app).value as? String)?.contains(Copy.typedDetails) == true, "The form lost the details."
        )
        app.terminate()
    }

    /// [30] A page without the form's fields: the unavailable view with no action inside it, and the pinned Open
    /// Report Page shows the site's page.
    func testUnavailableOffersTheSitesPage() throws {
        let app = try openReportForm(scenario: "unavailable", waitsForForm: false)
        let unavailable = app.descendants(matching: .any)[Identifier.unavailable]
        XCTAssertTrue(unavailable.waitForExistence(timeout: 10), "The unavailable state did not show.")
        keepScreenshot("report-30-unavailable", app: app)
        XCTAssertEqual(unavailable.buttons.count, 0, "The unavailable view holds an action.")
        XCTAssertFalse(app.descendants(matching: .any)[Identifier.form].exists, "The form shows on the first step.")
        let primary = primaryButton(in: app)
        XCTAssertEqual(primary.label, Copy.openReportPage, "The pinned button reads \(primary.label).")
        XCTAssertTrue(primary.isEnabled, "Open Report Page is dimmed.")

        primary.tapWhenHittable("Open Report Page")
        let webView = app.webViews[Identifier.sessionWebView]
        XCTAssertTrue(webView.waitForExistence(timeout: 15), "Open Report Page did not show the site's page.")
        XCTAssertEqual(webView.value as? String, Self.reportPageURL, "The sheet holds another page.")
        topmostClose(in: app).tap()
        XCTAssertTrue(webView.waitForNonExistence(timeout: 10), "The site's page did not close.")
        XCTAssertTrue(unavailable.exists, "Closing the page lost the unavailable state.")
        app.terminate()
    }

    /// [33] At the largest text size the pinned button is in reach without scrolling, grows with its label and reads
    /// it whole.
    func testTheLargestTextSizeKeepsTheButtonInReach() throws {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            throw XCTSkip("Frame 33 is the iPhone at AX5.")
        }
        let app = try openReportForm(
            scenario: "ready", contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        keepScreenshot("report-33-ax5", app: app)
        let primary = primaryButton(in: app)
        XCTAssertTrue(primary.isHittable, "Send Report is out of reach at AX5.")
        XCTAssertGreaterThanOrEqual(primary.frame.height, 50, "The button did not grow: \(primary.frame).")
        XCTAssertEqual(primary.label, Copy.send, "The button reads \(primary.label).")
        let window = app.windows.firstMatch.frame
        XCTAssertTrue(window.contains(primary.frame), "The button runs off the screen: \(primary.frame).")
        XCTAssertTrue(app.buttons[Identifier.child].exists, "The reasons are gone at AX5.")
        app.terminate()
    }

    /// [34] On the iPad the form is a form sheet, not the full screen; ⌘↩ sends a ready form and does nothing to one
    /// that is not.
    func testThePadFormSheetAndCommandReturn() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("Frame 34 is the iPad form sheet.")
        }
        let app = try openReportForm(scenario: "ready")
        let form = app.descendants(matching: .any)[Identifier.form]
        let window = app.windows.firstMatch.frame
        XCTAssertLessThan(form.frame.width, window.width - 100, "The form fills the screen: \(form.frame).")
        keepScreenshot("report-34-ipad", app: app)

        // On the iPad simulator ⌘ with `XCUIKeyboardKey.return` ("\r") never reached the shortcut; ⌘ with "\n" does.
        app.typeKey("\n", modifierFlags: .command)
        RunLoop.current.run(until: Date.now.addingTimeInterval(2))
        XCTAssertFalse(try loggedRequests().contains(Self.reportPost), "⌘↩ sent a form that is not ready.")
        XCTAssertTrue(form.exists, "⌘↩ on a form that is not ready changed the sheet.")

        try fillInTheForm(in: app)
        keepScreenshot("report-34-ipad-ready", app: app)
        app.typeKey("\n", modifierFlags: .command)
        XCTAssertTrue(
            app.descendants(matching: .any)[Identifier.sent].waitForExistence(timeout: 10), "⌘↩ did not send."
        )
        XCTAssertEqual(try loggedRequests().filter({ $0 == Self.reportPost }).count, 1, "⌘↩ did not send once.")
        app.terminate()
    }
}

// MARK: Helpers

private extension ReportFormUITests {
    /// Opens the fixture's comment link cold, signed in, and taps Report in the linked comment's `…` menu. Waits for
    /// the form unless the scenario starts elsewhere.
    func openReportForm(
        scenario: String, contentSizeCategory: String? = nil, waitsForForm: Bool = true
    ) throws -> XCUIApplication {
        let app = XCUIApplication()
        if let contentSizeCategory {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSizeCategory]
        }
        let url = try XCTUnwrap(UITestConstants.commentURL(scheme: "ehpanda"))
        try app.openCold(url, extraEnvironment: [
            UITestConstants.blockedUsersEnvironmentKey: "[]",
            UITestConstants.requestLogEnvironmentKey: requestLogURL.path(),
            UITestConstants.reportScenarioEnvironmentKey: scenario,
            "EHPANDA_AUTOMATION_IPB_MEMBER_ID": "fixture-member",
            "EHPANDA_AUTOMATION_IPB_PASS_HASH": "fixture-session"
        ])
        app.requireForeground()
        app.requireElement(Identifier.commentsView, matching: .collectionView)
        let cell = app.requireElement(Identifier.commentCell)
        XCTAssertTrue(
            cell.waitUntilHittable(timeout: XCUIElement.hittableTimeout), "The linked comment is out of reach."
        )
        // The linked row fades to 25 % and back over two seconds; let it finish before touching it.
        Thread.sleep(forTimeInterval: 2.5)
        let menu = cell.images["ellipsis"].firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 10), "The comment has no … button.")
        menu.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons[Copy.reportOnSite].firstMatch.tapWhenHittable("Report in the menu")
        XCTAssertEqual(app.alerts.count, 0, "Report raised an alert instead of the form.")
        if waitsForForm {
            app.requireElement(Identifier.form)
            XCTAssertTrue(
                app.buttons[Identifier.child].waitForExistence(timeout: 10), "The form shows no reasons."
            )
        }
        return app
    }

    /// Fills in a sendable form: the email first, then other illegal content, whose first pick moves to Details,
    /// then a line of Details.
    func fillInTheForm(in app: XCUIApplication) throws {
        let email = app.textFields[Identifier.email]
        email.tapWhenHittable("Email")
        email.typeText(Copy.validEmail)
        app.buttons[Identifier.other].tapWhenHittable("Other illegal content")
        let details = detailsField(in: app)
        requireKeyboardFocus(details, "Details after the first pick")
        details.typeText(Copy.typedDetails)
        XCTAssertTrue(primaryButton(in: app).waitForEnabled(), "Send Report stays dimmed on a filled-in form.")
    }

    func primaryButton(in app: XCUIApplication) -> XCUIElement {
        app.buttons[Identifier.primary].firstMatch
    }

    /// Details is a vertical `TextField`, which XCUITest lists as a text field.
    func detailsField(in app: XCUIApplication) -> XCUIElement {
        app.textFields[Identifier.details].firstMatch
    }

    /// The Close button on top: with the site's page over the form, both sheets have one.
    func topmostClose(in app: XCUIApplication) -> XCUIElement {
        let closes = app.buttons.matching(NSPredicate(format: "label == %@", Copy.close))
        let hittable = closes.allElementsBoundByIndex.last(where: { $0.exists && $0.isHittable })
        return hittable ?? closes.firstMatch
    }

    func requireKeyboardFocus(
        _ element: XCUIElement, _ name: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let focused = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [focused], timeout: 10), .completed, "\(name) has no keyboard focus.",
            file: file, line: line
        )
    }

    func loggedRequests() throws -> [String] {
        guard FileManager.default.fileExists(atPath: requestLogURL.path()) else { return [] }
        return try String(contentsOf: requestLogURL, encoding: .utf8).split(separator: "\n").map(String.init)
    }

    func waitForRequestCount(_ line: String, _ count: Int, timeout: TimeInterval = 10) throws -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if try loggedRequests().filter({ $0 == line }).count >= count {
                return true
            }
            RunLoop.current.run(until: Date.now.addingTimeInterval(0.25))
        }
        return false
    }

    func keepScreenshot(_ name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
private extension XCUIElement {
    func waitForEnabled(timeout: TimeInterval = 10) -> Bool {
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isEnabled == true"), object: self)
        return XCTWaiter.wait(for: [enabled], timeout: timeout) == .completed
    }

    func waitForLabel(containing text: String, timeout: TimeInterval) -> Bool {
        let labelled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", text), object: self
        )
        return XCTWaiter.wait(for: [labelled], timeout: timeout) == .completed
    }
}
