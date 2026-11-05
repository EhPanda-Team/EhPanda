import XCTest

/// Comment moderation end to end (UI-SPEC C-4 to C-8): the comments list's `…` menu and context menu, the Report and
/// Block alerts, the collapsed and revealed rows, the Detail strip's cards and the posting warning over the comment
/// editor.
///
/// XCUITest does not read accessibility custom actions, so the cell's and the card's named moderation actions are
/// read from the rendered accessibility tree in `BlockedCommentPresentationTests` instead.
///
/// Every launch is stubbed: the gallery and its comments come from the bundled fixtures, the report sheet never loads
/// the live site, and sign-in uses the launch automation's cookie keys with placeholder values. Each case presets its
/// own block list through `EHPANDA_UITEST_BLOCKED_AUTHORS`, so no case depends on another's storage.
@MainActor
final class CommentModerationUITests: XCTestCase {
    private enum Copy {
        /// The fixture's last comment, opened by the comment link; its author has one comment in the fixture.
        static let author = "黑锋血色"
        /// The fixture's second comment, inside the Detail strip's first six cards.
        static let stripAuthor = "Roobubba"
        static let stripCommentID = "5143504"
        static let reportOnSite = "Report on E-Hentai"
        static let reportTitle = "Report this comment?"
        static let openReportPage = "Open Report Page"
        static let block = "Block"
        static let blockTitle = "Block \(author)?"
        static let blockedRow = "Comment from a user you've blocked"
        static let show = "Show"
        static let hide = "Hide"
        static let unblock = "Unblock"
        static let postComment = "Post Comment"
        static let filterTitle = "Post this comment?"
        static let edit = "Edit"
        static let postAnyway = "Post Anyway"

        static func blockAuthor(_ author: String) -> String { "Block \(author)" }
        static func unblockAuthor(_ author: String) -> String { "Unblock \(author)" }
    }

    private enum Identifier {
        static let commentsView = "comments_view"
        static let detailView = "detail_view"
        static let sessionWebView = "session_web_view"
        static let commentCell = "comment_cell_" + UITestConstants.commentID
        static let blockedRow = "blocked_comment_" + UITestConstants.commentID
        static let stripCard = "comment_card_" + Copy.stripCommentID
        static let blockedCard = "blocked_comment_card_" + Copy.stripCommentID
    }

    private var requestLogURL: URL!

    override func setUpWithError() throws {
        continueAfterFailure = false
        requestLogURL = FileManager.default.temporaryDirectory
            .appending(path: "comment-moderation-requests-\(UUID().uuidString).log")
    }

    override func tearDownWithError() throws {
        if let requestLogURL, FileManager.default.fileExists(atPath: requestLogURL.path()) {
            try FileManager.default.removeItem(at: requestLogURL)
        }
    }

    // MARK: Comments list

    func testTheMenuOffersReportThenBlockAndReportOpensTheSignedInSheet() throws {
        let app = try openComments(blockedAuthors: [], signedIn: true)
        let cell = requireCell(in: app)

        openMenu(of: cell, in: app)
        let report = app.buttons[Copy.reportOnSite].firstMatch
        let block = app.buttons[Copy.blockAuthor(Copy.author)].firstMatch
        XCTAssertTrue(report.waitForExistence(timeout: 10), "The menu holds no Report.")
        XCTAssertTrue(block.exists, "The menu holds no Block.")
        XCTAssertLessThan(report.frame.minY, block.frame.minY, "Report does not come before Block.")
        keepScreenshot("comments-menu-open", app: app)

        report.tapWhenHittable("Report")
        let alert = app.alerts[Copy.reportTitle]
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "Report raised no confirmation.")
        keepScreenshot("comments-report-alert", app: app)
        alert.buttons[Copy.openReportPage].tapWhenHittable("Open Report Page")

        let sheet = app.webViews[Identifier.sessionWebView]
        XCTAssertTrue(sheet.waitForExistence(timeout: 15), "The report sheet did not open.")
        let value = try XCTUnwrap(sheet.value as? String, "The report sheet names no page.")
        XCTAssertEqual(
            value,
            "https://e-hentai.org/g/\(UITestConstants.primaryGID)/\(UITestConstants.primaryToken)/?report=select",
            "The sheet holds another page than the gallery's report page."
        )
        app.buttons["Close"].firstMatch.tapWhenHittable("Close the report sheet")
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 10), "The report sheet did not close.")
        app.terminate()
    }

    func testBlockCollapsesTheAuthorsCommentsAndShowHideAndUnblockWork() throws {
        let app = try openComments(blockedAuthors: [], signedIn: false)
        let cell = requireCell(in: app)

        openMenu(of: cell, in: app)
        app.buttons[Copy.blockAuthor(Copy.author)].firstMatch.tapWhenHittable("Block in the menu")
        let alert = app.alerts[Copy.blockTitle]
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "Block raised no confirmation.")
        keepScreenshot("comments-block-alert", app: app)
        alert.buttons[Copy.block].tapWhenHittable("Block in the alert")

        let row = app.descendants(matching: .any)[Identifier.blockedRow]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The comment did not collapse.")
        XCTAssertTrue(row.staticTexts[Copy.blockedRow].exists, "The collapsed row does not say what it is.")
        XCTAssertFalse(nameIsOnScreen(Copy.author, in: app), "The collapsed list still names the blocked user.")
        keepScreenshot("comments-blocked-row", app: app)

        row.buttons[Copy.show].tapWhenHittable("Show")
        XCTAssertTrue(app.staticTexts[Copy.author].waitForExistence(timeout: 10), "Show did not reveal the comment.")
        let hide = app.buttons[Copy.hide].firstMatch
        XCTAssertTrue(hide.exists, "The revealed comment has no Hide.")
        keepScreenshot("comments-revealed-row", app: app)
        hide.tapWhenHittable("Hide")
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Hide did not collapse the comment again.")

        row.buttons[Copy.unblock].tapWhenHittable("Unblock")
        XCTAssertTrue(row.waitForNonExistence(timeout: 10), "Unblock did not expand the comment.")
        XCTAssertTrue(app.staticTexts[Copy.author].exists, "The unblocked comment does not name its author.")
        app.terminate()
    }

    func testTheCellOffersReportAndBlockInItsContextMenu() throws {
        let app = try openComments(blockedAuthors: [], signedIn: false)
        let cell = requireCell(in: app)

        cell.press(forDuration: 1.2)
        XCTAssertTrue(
            app.buttons[Copy.reportOnSite].firstMatch.waitForExistence(timeout: 10),
            "The context menu holds no Report."
        )
        XCTAssertTrue(app.buttons[Copy.blockAuthor(Copy.author)].firstMatch.exists, "The context menu holds no Block.")
        app.terminate()
    }

    func testTheUsersOwnCommentOffersNoModeration() throws {
        let app = try openComments(blockedAuthors: [], signedIn: true, displayName: Copy.author)
        let cell = requireCell(in: app)

        XCTAssertFalse(menuButton(of: cell).exists, "The own comment has a … button.")
        cell.press(forDuration: 1.2)
        XCTAssertFalse(
            app.buttons[Copy.reportOnSite].firstMatch.waitForExistence(timeout: 3),
            "The own comment has a moderation menu."
        )
        XCTAssertFalse(app.buttons[Copy.blockAuthor(Copy.author)].firstMatch.exists, "The own comment offers Block.")
        app.terminate()
    }

    // MARK: Detail strip

    func testAStripCardOffersReportAndBlockOnALongPress() throws {
        let app = try openDetail(blockedAuthors: [])
        let card = try requireStripElement(Identifier.stripCard, in: app)

        card.press(forDuration: 1.2)
        let report = app.buttons[Copy.reportOnSite].firstMatch
        let block = app.buttons[Copy.blockAuthor(Copy.stripAuthor)].firstMatch
        XCTAssertTrue(report.waitForExistence(timeout: 10), "The card's context menu holds no Report.")
        XCTAssertTrue(block.exists, "The card's context menu holds no Block.")
        XCTAssertLessThan(report.frame.minY, block.frame.minY, "Report does not come before Block.")
        keepScreenshot("strip-card-menu", app: app)
        app.terminate()
    }

    func testABlockedAuthorsCardIsCollapsedAndShowAndUnblockWork() throws {
        let app = try openDetail(blockedAuthors: [Copy.stripAuthor])
        let card = try requireStripElement(Identifier.blockedCard, in: app)
        XCTAssertTrue(card.staticTexts[Copy.blockedRow].exists, "The collapsed card does not say what it is.")
        XCTAssertFalse(
            app.descendants(matching: .any)[Identifier.stripCard].exists, "The blocked comment's card is still shown."
        )
        XCTAssertFalse(nameIsOnScreen(Copy.stripAuthor, in: app), "The strip still names the blocked user.")
        keepScreenshot("strip-collapsed-card", app: app)

        card.buttons[Copy.show].tapWhenHittable("Show on the card")
        let revealed = app.descendants(matching: .any)[Identifier.stripCard]
        XCTAssertTrue(revealed.waitForExistence(timeout: 10), "Show did not reveal the card.")
        revealed.press(forDuration: 1.2)
        let hide = app.buttons[Copy.hide].firstMatch
        XCTAssertTrue(hide.waitForExistence(timeout: 10), "The revealed card's menu holds no Hide.")
        XCTAssertTrue(
            app.buttons[Copy.unblockAuthor(Copy.stripAuthor)].firstMatch.exists,
            "The revealed card's menu holds no Unblock."
        )
        hide.tapWhenHittable("Hide on the card")
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Hide did not collapse the card again.")

        card.buttons[Copy.unblock].tapWhenHittable("Unblock on the card")
        XCTAssertTrue(card.waitForNonExistence(timeout: 10), "Unblock did not expand the card.")
        XCTAssertTrue(revealed.waitForExistence(timeout: 10), "The unblocked comment's card is not shown.")
        app.terminate()
    }

    // MARK: Posting warning

    func testAMatchingCommentWaitsForTheSecondTap() throws {
        let app = try openComments(blockedAuthors: [], signedIn: true)
        let term = try firstEnglishFilterTerm()

        app.buttons[Copy.postComment].firstMatch.tapWhenHittable("Post Comment")
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "The comment editor did not open.")
        editor.tapWhenHittable("The editor")
        editor.typeText(term)
        let post = postButton(in: app)
        post.tapWhenHittable("Post")

        let alert = app.alerts[Copy.filterTitle]
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "A matching comment raised no warning.")
        XCTAssertTrue(editor.exists, "The editor closed under the warning.")
        keepScreenshot("comments-posting-warning", app: app)
        alert.buttons[Copy.edit].tapWhenHittable("Edit")
        XCTAssertTrue(alert.waitForNonExistence(timeout: 10), "Edit did not close the warning.")
        XCTAssertEqual(editor.value as? String, term, "Edit did not keep the text as typed.")
        let commentPost = "POST e-hentai.org /g/\(UITestConstants.primaryGID)/\(UITestConstants.primaryToken)/"
        let logged = try loggedRequests()
        XCTAssertFalse(logged.contains(commentPost), "The comment was sent before the decision: \(logged).")

        post.tapWhenHittable("Post again")
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "The second Post raised no warning.")
        alert.buttons[Copy.postAnyway].tapWhenHittable("Post Anyway")
        XCTAssertTrue(editor.waitForNonExistence(timeout: 10), "Post Anyway did not close the editor.")
        XCTAssertTrue(try waitForRequest(commentPost), "Post Anyway did not send the comment.")
        XCTAssertEqual(try loggedRequests().filter({ $0 == commentPost }).count, 1, "The comment was not sent once.")
        app.terminate()
    }
}

// MARK: Helpers

private extension CommentModerationUITests {
    func environment(blockedAuthors: [String], signedIn: Bool, displayName: String?) throws -> [String: String] {
        let names = try XCTUnwrap(String(bytes: JSONEncoder().encode(blockedAuthors), encoding: .utf8))
        var environment = [
            UITestConstants.blockedAuthorsEnvironmentKey: names,
            UITestConstants.requestLogEnvironmentKey: requestLogURL.path()
        ]
        if signedIn {
            environment["EHPANDA_AUTOMATION_IPB_MEMBER_ID"] = "fixture-member"
            environment["EHPANDA_AUTOMATION_IPB_PASS_HASH"] = "fixture-session"
        }
        if let displayName {
            environment[UITestConstants.displayNameEnvironmentKey] = displayName
        }
        return environment
    }

    /// Opens the fixture's comment link cold, which lands on the comments list scrolled to comment 6894060.
    func openComments(
        blockedAuthors: [String], signedIn: Bool, displayName: String? = nil
    ) throws -> XCUIApplication {
        let app = XCUIApplication()
        let url = try XCTUnwrap(UITestConstants.commentURL(scheme: "ehpanda"))
        try app.openCold(url, extraEnvironment: environment(
            blockedAuthors: blockedAuthors, signedIn: signedIn, displayName: displayName
        ))
        app.requireForeground()
        app.requireElement(Identifier.commentsView, matching: .collectionView)
        return app
    }

    func openDetail(blockedAuthors: [String]) throws -> XCUIApplication {
        let app = XCUIApplication()
        let url = try XCTUnwrap(UITestConstants.galleryURL(scheme: "ehpanda"))
        try app.openCold(url, extraEnvironment: environment(
            blockedAuthors: blockedAuthors, signedIn: false, displayName: nil
        ))
        app.requireForeground()
        app.requireElement(Identifier.detailView, matching: .scrollView)
        return app
    }

    func requireCell(in app: XCUIApplication) -> XCUIElement {
        let cell = app.requireElement(Identifier.commentCell)
        // The linked row fades to 25 % and back over two seconds; let it finish before reading or touching it.
        XCTAssertTrue(
            cell.waitUntilHittable(timeout: XCUIElement.hittableTimeout), "The linked comment is out of reach."
        )
        Thread.sleep(forTimeInterval: 2.5)
        return cell
    }

    /// Scrolls the Detail screen down to the comment strip, then the strip along, until the whole of `identifier` is
    /// in the Detail screen's visible area: a card that sticks out past its edge has its center, where a tap lands,
    /// out of reach. The area is the Detail scroll view's frame, since on the iPad the screen is a sheet smaller than
    /// the window.
    func requireStripElement(_ identifier: String, in app: XCUIApplication) throws -> XCUIElement {
        let element = app.descendants(matching: .any)[identifier]
        let detail = app.scrollViews[Identifier.detailView].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 10), "The Detail screen is not shown.")
        let visible = detail.frame
        let window = app.windows.firstMatch
        var swipes = 0
        while !(element.exists && element.frame.maxY < visible.maxY - 24), swipes < 10 {
            detail.swipeUp()
            swipes += 1
        }
        // A drag can carry the strip past the card, so a card that ends up sticking out of the leading edge is dragged
        // back the other way.
        var drags = 0
        while element.exists, drags < 6 {
            let frame = element.frame
            let distance: CGFloat
            if frame.maxX > visible.maxX - 8 {
                distance = -min(frame.maxX - visible.maxX + 24, visible.width / 2)
            } else if frame.minX < visible.minX + 8 {
                distance = min(visible.minX - frame.minX + 24, visible.width / 2)
            } else {
                break
            }
            let startX = distance < 0 ? 0.75 : 0.25
            let start = window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                dx: visible.minX + visible.width * startX - window.frame.minX, dy: frame.midY - window.frame.minY
            ))
            start.press(
                forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: distance, dy: 0)),
                withVelocity: .slow, thenHoldForDuration: 0.3
            )
            drags += 1
        }
        XCTAssertTrue(element.waitUntilHittable(timeout: XCUIElement.hittableTimeout), "\(identifier) is out of reach.")
        XCTAssertTrue(visible.contains(element.frame), "\(identifier) is not wholly in view: \(element.frame).")
        return element
    }

    /// The cell's `…` button. VoiceOver does not reach it (its items are the cell's named actions), but XCUITest lists
    /// the children of the cell's combined element, the button's `ellipsis` glyph among them.
    func menuButton(of cell: XCUIElement) -> XCUIElement {
        cell.images["ellipsis"].firstMatch
    }

    /// Taps the `…` button where it sits. Inside the cell's combined element it never reads as hittable, since a hit
    /// test at its center finds the cell, so it is tapped by coordinate once it exists.
    func openMenu(of cell: XCUIElement, in app: XCUIApplication) {
        let button = menuButton(of: cell)
        XCTAssertTrue(button.waitForExistence(timeout: 10), "The comment has no … button.")
        button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    /// The editor's Post: the confirmation button that ends its navigation bar.
    func postButton(in app: XCUIApplication) -> XCUIElement {
        app.navigationBars[Copy.postComment].buttons.element(boundBy: 1)
    }

    /// Whether any text on screen holds `name`, which a collapsed comment must never show.
    func nameIsOnScreen(_ name: String, in app: XCUIApplication) -> Bool {
        let holdsName = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", name, name)
        return app.descendants(matching: .any).matching(holdsName).firstMatch.exists
    }

    /// The bundled list's first English term, read from the package source at test time: no term is copied here.
    func firstEnglishFilterTerm() throws -> String {
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "AppPackage/Sources/DetailFeature/Resources/CommentFilterTerms.json")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let groups = try XCTUnwrap((object as? [String: Any])?["groups"] as? [String: [String]])
        return try XCTUnwrap(groups["en"]?.first, "The bundled list has no English term.")
    }

    func loggedRequests() throws -> [String] {
        guard FileManager.default.fileExists(atPath: requestLogURL.path()) else { return [] }
        return try String(contentsOf: requestLogURL, encoding: .utf8).split(separator: "\n").map(String.init)
    }

    func waitForRequest(_ line: String, timeout: TimeInterval = 10) throws -> Bool {
        let deadline = Date.now.addingTimeInterval(timeout)
        while Date.now < deadline {
            if try loggedRequests().contains(line) {
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
