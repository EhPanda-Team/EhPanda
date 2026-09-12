import UIKit
import XCTest

/// Runs Xcode's accessibility audit engine over every surface the hermetic fixtures can reach.
///
/// Each test launches EhPanda through the stubbed launcher (no network, no credential, English
/// catalog), navigates to one surface, waits for it, and audits it with `.all` audit types. The
/// deployment target is iOS 26, so no `#available` guard is needed (Phase 16 D-31). Surfaces that
/// only a logged-in session renders (Favorites, Watched, Archives, Torrents, EhSetting,
/// FolderManager, Detail Search) are not reachable here and are covered by the manual
/// walkthrough; `16-CONTRAST-AUDIT.md § Automated audit (16-24)` records that assumption.
@MainActor
final class AccessibilityAuditUITests: XCTestCase {
    /// Issues on elements EhPanda does not draw — a UITabBar, UINavigationBar or UIPicker part
    /// owned by an Apple component. Each entry names the element and the Apple component that
    /// owns it, and matches that element only; nothing app-drawn belongs here. The evidence for
    /// every entry is in `16-CONTRAST-AUDIT.md § Automated audit (16-24) › System-owned`.
    private let systemOwnedExclusions: [AuditExclusion] = [
        AuditExclusion(
            id: "UISearchBar.field",
            reason: "The `.searchable` field is a UISearchBar; the audit reports the field itself "
                + "as clipped text (Search root, every run). Nothing app-side draws the field.",
            matches: { issue, _ in
                issue.auditType == .textClipped && issue.element?.elementType == .searchField
            }
        ),
        AuditExclusion(
            id: "UIDatePicker.parts",
            reason: "The graphical `DatePicker` is a UIDatePicker; every day, weekday and month "
                + "label inside its frame is the picker's own (33 Dynamic Type reports on the Date "
                + "Seek sheet). The frame test keeps the app-drawn Older/Newer buttons and the "
                + "section footer, which sit outside it, under audit.",
            matches: { issue, context in
                guard let element = issue.element, let picker = context.datePickerFrame else { return false }
                return picker.contains(element.frame)
            }
        ),
        AuditExclusion(
            id: "ContentUnavailableView.symbol",
            reason: "`ContentUnavailableView` draws the symbol of the `Label` it is given as its own "
                + "`Image`, exposed under the raw SF Symbol name (Favorites' login placeholder, "
                + "History's parse-error state). `accessibilityHidden(true)` on the label's icon — "
                + "in both `Label` forms — does not reach that image, so nothing app-side can "
                + "name or hide it. The list is the symbols the audited surfaces show, so any "
                + "other unlabelled image stays under audit.",
            matches: { issue, _ in
                guard issue.auditType == .sufficientElementDescription,
                      let element = issue.element, element.elementType == .image else { return false }
                return AccessibilityAuditUITests.contentUnavailableSymbols.contains(element.identifier)
            }
        ),
        AuditExclusion(
            id: "UIDatePicker.elementDetection",
            reason: "The two `elementDetection` reports on the Date Seek sheet carry no element; "
                + "they appear only while the UIDatePicker is on screen and are its own text "
                + "rendering. An element-less report cannot be matched more narrowly.",
            matches: { issue, context in
                issue.auditType == .elementDetection && issue.element == nil && context.datePickerFrame != nil
            }
        )
    ]

    /// The SF Symbol names `ContentUnavailableView` exposes on the audited surfaces (see
    /// `ContentUnavailableView.symbol`).
    private static let contentUnavailableSymbols: Set<String> = [
        "person.crop.circle.badge.questionmark.fill",
        "rectangle.and.text.magnifyingglass"
    ]

    /// App-owned issues that are documented false positives and cannot be resolved without a
    /// visible change the owner has not authorised — for example a `.contrast` report on text
    /// drawn over an image or a gradient. Each entry names the element, the audit type, the
    /// measured reason and quotes the owner's `E-n=approve` reply recorded in
    /// `16-CONTRAST-AUDIT.md § Automated audit (16-24)`. Nothing enters this list before that
    /// reply (Phase 16 D-22).
    private let ownerApprovedExclusions: [AuditExclusion] = []

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Tab roots

    func testHomeRootAudit() throws {
        let app = try launch(tab: "home")
        requireHomeRoot(in: app)
        try audit(app, surface: "Home root")
    }

    func testSearchRootAudit() throws {
        let app = try launch(tab: "search")
        requireNavigationTitle("Search", in: app)
        try audit(app, surface: "Search root")
    }

    func testDownloadsEmptyStateAudit() throws {
        let app = try launch(tab: "downloads")
        requireNavigationTitle("Downloads", in: app)
        try audit(app, surface: "Downloads (empty)")
    }

    /// Favorites renders its login placeholder without a session; the placeholder is the surface
    /// the fixtures can reach, and it is what this test audits.
    func testFavoritesLoginPlaceholderAudit() throws {
        let app = try launch(tab: "favorites")
        requireNavigationTitle("Favorites", in: app)
        XCTAssertTrue(
            app.buttons["Login"].firstMatch.waitForExistence(timeout: 15),
            "Favorites did not render its login placeholder."
        )
        try audit(app, surface: "Favorites (login placeholder)")
    }

    func testSettingRootAudit() throws {
        let app = try launch(tab: "setting")
        requireNavigationTitle("Setting", in: app)
        try audit(app, surface: "Setting root")
    }

    // MARK: Home children

    func testFrontpageAudit() throws {
        let app = try launch(tab: "home")
        try pushFrontpage(in: app)
        try audit(app, surface: "Frontpage")
    }

    func testPopularAudit() throws {
        let app = try launch(tab: "home")
        requireHomeRoot(in: app)
        tapScrolling(app.buttons["Popular"].firstMatch, in: app)
        requireNavigationTitle("Popular", in: app)
        try audit(app, surface: "Popular")
    }

    func testHistoryAudit() throws {
        let app = try launch(tab: "home")
        requireHomeRoot(in: app)
        // History is the last item of the horizontal misc grid at the foot of Home: scroll the
        // page down to the grid, then scroll the grid itself sideways until the item is on screen.
        let historyButton = app.buttons["History"].firstMatch
        XCTAssertTrue(historyButton.waitForExistence(timeout: 15), "Home did not render its misc grid.")
        scrollUntilHittable(historyButton, in: app, of: app, direction: .upward)
        scrollUntilHittable(historyButton, in: app.buttons["Popular"].firstMatch, of: app, direction: .leftward)
        XCTAssertTrue(historyButton.isHittable, "The History grid item never became hittable.")
        historyButton.tap()
        requireNavigationTitle("History", in: app)
        try audit(app, surface: "History")
    }

    // MARK: Toolbar sheets

    func testFiltersSheetAudit() throws {
        let app = try launch(tab: "home")
        try pushFrontpage(in: app)
        try presentSheet(titled: "Filters", from: "Filters", in: app)
        try audit(app, surface: "Filters sheet")
        dismissSheet(in: app)
    }

    func testDateSeekSheetAudit() throws {
        let app = try launch(tab: "home")
        try pushFrontpage(in: app)
        try presentSheet(titled: "Date Seek", from: "Date Seek", in: app)
        try audit(app, surface: "Date Seek sheet")
        dismissSheet(in: app)
    }

    /// Quick Search lives on the Search root's toolbar, not on Frontpage's, inside its More menu.
    func testQuickSearchSheetAudit() throws {
        let app = try launch(tab: "search")
        requireNavigationTitle("Search", in: app)
        let moreButton = app.buttons["More"].firstMatch
        XCTAssertTrue(moreButton.waitForExistence(timeout: 15), "The Search toolbar did not expose More.")
        moreButton.tap()
        try presentSheet(titled: "Quick Search", from: "Quick Search", in: app)
        try audit(app, surface: "Quick Search sheet")
        dismissSheet(in: app)
    }

    // MARK: Setting children

    func testAccountSettingAudit() throws {
        let app = try launch(tab: "setting")
        try pushSettingRow("Account", in: app)
        try audit(app, surface: "Setting › Account")
    }

    func testGeneralSettingAudit() throws {
        let app = try launch(tab: "setting")
        try pushSettingRow("General", in: app)
        try audit(app, surface: "Setting › General")
    }

    func testActivityLogsAudit() throws {
        let app = try launch(tab: "setting")
        try pushSettingRow("General", in: app)
        tapScrolling(app.buttons["App Activity Logs"].firstMatch, in: app)
        requireNavigationTitle("App Activity Logs", in: app)
        // The entries load after the title; audit the list, not the empty state.
        XCTAssertTrue(
            app.collectionViews.cells.firstMatch.waitForExistence(timeout: 15),
            "App Activity Logs did not render a log row."
        )
        try audit(app, surface: "Setting › General › App Activity Logs")
    }

    func testAppearanceSettingAudit() throws {
        let app = try launch(tab: "setting")
        try pushSettingRow("Appearance", in: app)
        try audit(app, surface: "Setting › Appearance")
    }

    func testReadingSettingAudit() throws {
        let app = try launch(tab: "setting")
        try pushSettingRow("Reading", in: app)
        try audit(app, surface: "Setting › Reading")
    }

    func testDownloadSettingAudit() throws {
        let app = try launch(tab: "setting")
        try pushSettingRow("Download", in: app)
        try audit(app, surface: "Setting › Download")
    }

    func testLaboratorySettingAudit() throws {
        let app = try launch(tab: "setting")
        try pushSettingRow("Laboratory", in: app)
        try audit(app, surface: "Setting › Laboratory")
    }

    /// The About screen's navigation title is the app name, not the row's label.
    func testAboutAudit() throws {
        let app = try launch(tab: "setting")
        try pushSettingRow("About", titled: "EhPanda", in: app)
        try audit(app, surface: "Setting › About")
    }

    // MARK: Gallery detail and its children

    func testGalleryDetailAudit() throws {
        let app = XCUIApplication()
        try openGalleryDetail(in: app)
        try audit(app, surface: "Gallery Detail")
    }

    func testPreviewsAudit() throws {
        let app = XCUIApplication()
        let detailView = try openGalleryDetail(in: app)
        // The fixture gallery has more than twenty pages, so the Previews section offers Show All;
        // the query is scoped to the detail scroll view so Home's own Show All buttons never match.
        tapScrolling(detailView.buttons["Show All"].firstMatch, in: app)
        requireNavigationTitle("Previews", in: app)
        try audit(app, surface: "Detail › Previews")
    }

    func testGalleryInfosAudit() throws {
        let app = XCUIApplication()
        let detailView = try openGalleryDetail(in: app)
        // The Gallery Infos button is the last item of the horizontal stats strip: bring the strip
        // on screen first, then scroll the strip itself until the button can be tapped.
        let infosButton = detailView.buttons["Gallery Infos"].firstMatch
        XCTAssertTrue(infosButton.waitForExistence(timeout: 15), "Detail did not render its stats strip.")
        scrollUntilHittable(infosButton, in: app, of: app, direction: .upward)
        scrollUntilHittable(infosButton, in: detailView.scrollViews.firstMatch, of: app, direction: .leftward)
        XCTAssertTrue(infosButton.isHittable, "The Gallery Infos button never became hittable.")
        infosButton.tap()
        requireNavigationTitle("Gallery Infos", in: app)
        try audit(app, surface: "Detail › Gallery Infos")
    }

    func testCommentsAudit() throws {
        let app = XCUIApplication()
        let commentURL = try XCTUnwrap(UITestConstants.commentURL(scheme: "ehpanda"))
        try app.openCold(commentURL)
        app.requireForeground()
        app.requireElement("comments_view", matching: .collectionView)
        let linkedComment = app.requireElement("comment_cell_" + UITestConstants.commentID)
        // The linked row is highlighted by a fade to 25 % and back over two seconds; auditing
        // mid-pulse measured the dimmed row as three contrast failures. Let the pulse finish.
        settle(app, for: 2.5)
        XCTAssertTrue(linkedComment.exists, "The linked comment left the screen while settling.")
        try audit(app, surface: "Detail › Comments")
    }

    // MARK: Reading

    func testReadingPageAudit() throws {
        let app = XCUIApplication()
        try openReader(in: app)
        try audit(app, surface: "Reading (page)")
    }

    func testReadingControlPanelAudit() throws {
        let app = XCUIApplication()
        try showReadingControlPanel(in: app)
        try audit(app, surface: "Reading › control panel")
    }

    func testReadingSettingSheetAudit() throws {
        let app = XCUIApplication()
        try showReadingControlPanel(in: app)
        let moreButton = app.buttons["More"].firstMatch
        XCTAssertTrue(moreButton.waitForExistence(timeout: 15), "The reader toolbar did not expose More.")
        moreButton.tap()
        let settingButton = app.buttons["Reading Setting"].firstMatch
        XCTAssertTrue(settingButton.waitForExistence(timeout: 15), "The More menu did not list Reading Setting.")
        settingButton.tap()
        requireNavigationTitle("Reading", in: app)
        try audit(app, surface: "Reading › Reading Setting sheet")
    }

    // MARK: Error surface

    /// A link the app does not recognise is the one fixture-free route to the error surface: it
    /// raises the unsupported-link toast, and tapping the toast presents the error-info sheet.
    func testErrorToastAndErrorInfoAudit() throws {
        let app = XCUIApplication()
        let malformedURL = try XCTUnwrap(UITestConstants.malformedURL(scheme: "ehpanda"))
        try app.openCold(malformedURL)
        app.requireForeground()
        let toast = app.requireElement("toast_message")
        try audit(app, surface: "Toast (unsupported link)")
        XCTAssertTrue(toast.exists, "The toast left the screen before it could be tapped.")
        toast.tap()
        app.requireElement("error_info_view")
        try audit(app, surface: "Error info sheet")
    }

    // MARK: iPad presentations

    /// On the regular-width pad idiom the Setting tab and a tapped gallery present as modals rather
    /// than pushes; this mirrors `DeepLinkPadUITests`' skip so the iPhone run stays green.
    func testPadSettingAndDetailModalsAudit() throws {
        // Read here rather than in `setUpWithError`: that override matches XCTest's nonisolated
        // declaration, so the class's `@MainActor` does not reach it (see `DeepLinkPadUITests`).
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("The modal Setting and Detail presentations are iPad-exclusive.")
        }

        let app = try launch(tab: "setting")
        requireNavigationTitle("Setting", in: app)
        try audit(app, surface: "Setting (iPad modal)")

        let homeApp = try launch(tab: "home")
        requireHomeRoot(in: homeApp)
        homeApp.buttons["Show All"].firstMatch.tap()
        let firstGalleryRow = homeApp.collectionViews.buttons.firstMatch
        XCTAssertTrue(firstGalleryRow.waitForExistence(timeout: 15), "Frontpage did not render a gallery row.")
        firstGalleryRow.tap()
        homeApp.requireElement("detail_view", matching: .scrollView)
        try audit(homeApp, surface: "Gallery Detail (iPad modal)")
    }
}

// MARK: - Audit

private extension AccessibilityAuditUITests {
    /// The audit types `.all` expands to on iOS, named for the log; an unlisted raw value is
    /// printed as its number so nothing the engine reports is ever dropped from the record.
    static let auditTypeNames: [(type: XCUIAccessibilityAuditType, name: String)] = [
        (.contrast, "contrast"),
        (.elementDetection, "elementDetection"),
        (.hitRegion, "hitRegion"),
        (.sufficientElementDescription, "sufficientElementDescription"),
        (.dynamicType, "dynamicType"),
        (.textClipped, "textClipped"),
        (.trait, "trait")
    ]

    static func name(of auditType: XCUIAccessibilityAuditType) -> String {
        let names = auditTypeNames
            .filter({ auditType.contains($0.type) })
            .map(\.name)
        return names.isEmpty ? "rawValue \(auditType.rawValue)" : names.joined(separator: "+")
    }

    /// Audits everything on screen. Every issue is logged with the surface name so the result
    /// bundle carries the complete finding, then judged against the two allow-lists; while both
    /// are empty the handler returns `false` for every issue and each one fails the test.
    ///
    /// XCTest records the failure for a non-ignored issue inside the handler, so with the class's
    /// `continueAfterFailure = false` the test would stop at the first issue and every later one
    /// would never reach the log. The flag is lifted for the audit call alone — navigation before
    /// it still stops at its first failed wait — so one run records a surface's complete list.
    func audit(_ app: XCUIApplication, surface: String) throws {
        let systemOwned = systemOwnedExclusions
        let ownerApproved = ownerApprovedExclusions
        let context = AuditContext(app: app)
        let stopsAfterFailure = !continueAfterFailure
        continueAfterFailure = true
        defer { continueAfterFailure = !stopsAfterFailure }
        // The screenshot the audit judged, kept in the result bundle beside its finding so a
        // contrast verdict can be measured against the rendered pixels afterwards.
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "surface-\(surface)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        try app.performAccessibilityAudit(for: .all) { issue in
            // The element's description only, never its frame: reading the frame here takes a
            // fresh snapshot of the app, after which the audit's identity-bound elements in lazy
            // containers (list cells, the carousels) no longer resolve and the later issues on the
            // same surface log as "<no element>" (a 16-24 diagnostic run lost 111 of 267 that way).
            let elementDescription = issue.element?.description ?? "<no element>"
            print(
                "[a11y-audit] \(surface) | \(Self.name(of: issue.auditType)) | \(issue.compactDescription)"
                    + " | \(issue.detailedDescription) | \(elementDescription)"
            )
            return systemOwned.contains(where: { $0.matches(issue, context) })
                || ownerApproved.contains(where: { $0.matches(issue, context) })
        }
    }
}

// MARK: - Navigation

private extension AccessibilityAuditUITests {
    enum SwipeDirection {
        case upward
        case leftward
    }

    /// Waits out an animation the screen is known to run before auditing it. XCTest has no
    /// expectation for "no element is animating", so the interval is the animation's own length;
    /// the unfulfilled expectation is the framework's idiom for a timed pause on the main thread.
    func settle(_ app: XCUIApplication, for seconds: TimeInterval) {
        let pause = XCTestExpectation(description: "\(app.description) settles for \(seconds) s")
        _ = XCTWaiter.wait(for: [pause], timeout: seconds)
    }

    func launch(tab: String) throws -> XCUIApplication {
        let app = XCUIApplication()
        try app.launchStubbed(extraEnvironment: ["EHPANDA_AUTOMATION_TAB": tab])
        app.requireForeground()
        return app
    }

    func requireNavigationTitle(
        _ title: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            app.navigationBars[title].waitForExistence(timeout: 15),
            "The \(title) navigation title did not appear.",
            file: file,
            line: line
        )
    }

    /// Home has rendered once its Frontpage section offers Show All.
    func requireHomeRoot(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(
            app.buttons["Show All"].firstMatch.waitForExistence(timeout: 15),
            "Home did not render its Frontpage section.",
            file: file,
            line: line
        )
    }

    func pushFrontpage(in app: XCUIApplication) throws {
        requireHomeRoot(in: app)
        // The first Show All on Home belongs to the Frontpage section.
        app.buttons["Show All"].firstMatch.tap()
        requireNavigationTitle("Frontpage", in: app)
    }

    func pushSettingRow(_ label: String, titled title: String? = nil, in app: XCUIApplication) throws {
        requireNavigationTitle("Setting", in: app)
        tapScrolling(app.buttons[label].firstMatch, in: app)
        requireNavigationTitle(title ?? label, in: app)
    }

    func presentSheet(titled title: String, from buttonLabel: String, in app: XCUIApplication) throws {
        let button = app.buttons[buttonLabel].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15), "The toolbar did not expose \(buttonLabel).")
        button.tap()
        requireNavigationTitle(title, in: app)
    }

    func dismissSheet(in app: XCUIApplication) {
        let cancelButton = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "The sheet did not expose Cancel.")
        cancelButton.tap()
    }

    @discardableResult
    func openGalleryDetail(in app: XCUIApplication) throws -> XCUIElement {
        let galleryURL = try XCTUnwrap(UITestConstants.galleryURL(scheme: "ehpanda"))
        try app.openCold(galleryURL)
        app.requireForeground()
        let detailView = app.requireElement("detail_view", matching: .scrollView)
        XCTAssertTrue(
            app.buttons[UITestConstants.primaryMarkerTitle].waitForExistence(timeout: 15),
            "The gallery marker title did not render from the hermetic fixture."
        )
        return detailView
    }

    @discardableResult
    func openReader(in app: XCUIApplication) throws -> XCUIElement {
        let pageURL = try XCTUnwrap(UITestConstants.singlePageURL(scheme: "ehpanda"))
        try app.openCold(pageURL)
        app.requireForeground()
        app.requireElement("detail_view", matching: .scrollView)
        return app.requireElement("reading_view")
    }

    func showReadingControlPanel(in app: XCUIApplication) throws {
        let readingView = try openReader(in: app)
        readingView.tap()
        app.requireElement("reading_page_indicator", matching: .staticText, timeout: 5)
    }

    /// Waits for the element, scrolls it into the hittable area if the screen is longer than the
    /// window, then taps it.
    func tapScrolling(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            element.waitForExistence(timeout: 15),
            "\(element) did not appear.",
            file: file,
            line: line
        )
        scrollUntilHittable(element, in: app, of: app, direction: .upward)
        XCTAssertTrue(element.isHittable, "\(element) never became hittable.", file: file, line: line)
        element.tap()
    }

    /// Swipes the container until the element lies inside the window, or gives up after a
    /// screenful of swipes. The window test is done on frames, never through `isHittable`: XCTest
    /// records a failure ("activation point invalid") when hittability is asked of an element that
    /// is laid out beyond the screen edge, which is exactly the state this loop exists to leave.
    func scrollUntilHittable(
        _ element: XCUIElement,
        in container: XCUIElement,
        of app: XCUIApplication,
        direction: SwipeDirection
    ) {
        let window = app.windows.firstMatch.frame
        var remainingSwipes = 8
        while remainingSwipes > 0 {
            let frame = element.frame
            if !frame.isEmpty, window.contains(frame), element.isHittable {
                return
            }
            switch direction {
            case .upward:
                container.swipeUp()
            case .leftward:
                container.swipeLeft()
            }
            remainingSwipes -= 1
        }
    }
}

/// One allow-listed audit issue. `matches` is deliberately narrow — it identifies one element
/// and one audit type — so an entry can never silence a neighbouring finding.
private struct AuditExclusion {
    let id: String
    let reason: String
    let matches: (XCUIAccessibilityAuditIssue, AuditContext) -> Bool
}

/// What the exclusions and the log need to know about the screen, captured once before the
/// audit so the issue handler does not query the app for every issue.
private struct AuditContext {
    /// The graphical UIDatePicker's frame, when one is on screen.
    let datePickerFrame: CGRect?

    @MainActor init(app: XCUIApplication) {
        let picker = app.datePickers.firstMatch
        datePickerFrame = picker.exists ? picker.frame : nil
    }
}
