import UIKit
import XCTest

/// Runs Xcode's accessibility audit engine over every surface the hermetic fixtures can reach.
///
/// Each test launches EhPanda through the stubbed launcher (no network, no credential, English
/// catalog), navigates to one surface, waits for it, and audits it with the three stable audit
/// types — `.hitRegion`, `.sufficientElementDescription` and `.trait`; `auditTypeNames` records why
/// the others are not run. The deployment target is iOS 26, so no `#available` guard is needed
/// (Phase 16 D-31). Surfaces that only a logged-in session renders (Favorites, Watched, Archives,
/// Torrents, EhSetting, FolderManager, Detail Search) are not reachable here and are covered by the
/// manual walkthrough; `16-CONTRAST-AUDIT.md § Automated audit (16-24)` records that assumption.
@MainActor
final class AccessibilityAuditUITests: XCTestCase {
    /// Issues on elements EhPanda does not draw — a part an Apple component renders on its own,
    /// such as the symbol image of a `ContentUnavailableView`. Each entry names the element and the
    /// Apple component that owns it, and matches that element only; nothing app-drawn belongs
    /// here. The evidence for every entry is in `16-CONTRAST-AUDIT.md § Automated audit (16-24) ›
    /// System-owned`.
    private let systemOwnedExclusions: [AuditExclusion] = [
        AuditExclusion(
            id: "ContentUnavailableView.symbol",
            reason: "`ContentUnavailableView` draws the symbol of the `Label` it is given as its own "
                + "`Image`, exposed under the raw SF Symbol name (Favorites' login placeholder, "
                + "History's parse-error state). `accessibilityHidden(true)` on the label's icon — "
                + "in both `Label` forms — does not reach that image, so nothing app-side can "
                + "name or hide it. The list is the symbols the audited surfaces show, so any "
                + "other unlabelled image stays under audit.",
            matches: { report in
                guard report.auditType == .sufficientElementDescription,
                      let element = report.element, element.type == "Image" else { return false }
                return AccessibilityAuditUITests.contentUnavailableSymbols.contains(element.name)
            }
        )
    ]

    /// The SF Symbol names `ContentUnavailableView` exposes on the audited surfaces (see
    /// `ContentUnavailableView.symbol`).
    private static let contentUnavailableSymbols: Set<String> = [
        "person.crop.circle.badge.questionmark.fill",
        "rectangle.and.text.magnifyingglass"
    ]

    /// App-owned issues that cannot be resolved without a visible change the owner has not
    /// authorised or has withdrawn — for example an element the app keeps in the hierarchy while
    /// hidden, which the audit still walks. Each entry names the element, the audit type, the
    /// measured reason and quotes the owner's reply recorded in `16-CONTRAST-AUDIT.md`. Nothing
    /// enters this list before that reply (Phase 16 D-22). Every matcher reads the report's element
    /// by name and type from its description alone — see `AuditElement` for why.
    private let ownerApprovedExclusions: [AuditExclusion] = [
        AuditExclusion(
            id: "E-1.hidden-content",
            reason: "The reader's slider-preview strip, kept in the hierarchy at opacity 0 through "
                + "`visible(false)` (`opacity` + `accessibilityHidden`) while the control panel shows "
                + "no strip: the audit still walks the strip's activity indicators and reports each "
                + "as `sufficientElementDescription` \"Element has no description\". Matched on the "
                + "`Reading › control panel` surface by the `ActivityIndicator` element type. Owner: "
                + "`E-1=approve` (2026-09-13).",
            matches: { report in
                report.surface == "Reading › control panel"
                    && report.auditType == .sufficientElementDescription
                    && report.element?.type == "ActivityIndicator"
            }
        ),
        AuditExclusion(
            id: "V-1.designed-hit-regions",
            reason: "Buttons drawn at their designed size, under the 24-point WCAG 2.5.8 floor: the "
                + "section headings' \"Show All\" (subheadline, 18 tall), Detail's uploader button "
                + "(callout, 19 tall; named by the fixture gallery's uploader) and \"Similar Gallery\" "
                + "(19 tall). 16-24 had grown them to 24 points, which moved Detail's action row by 3.7 "
                + "points; the owner withdrew that visible change. Owner: \"剩下的這 1-8 都撤回，一個 "
                + "commit 就好\" (revert the remaining eight visible changes; 2026-09-15).",
            matches: { report in
                guard report.auditType == .hitRegion,
                      AccessibilityAuditUITests.designedHitRegionSurfaces.contains(report.surface),
                      let element = report.element, element.type == "Button" else { return false }
                return AccessibilityAuditUITests.designedHitRegionButtons.contains(element.name)
            }
        )
    ]

    /// The surfaces that show the buttons of `V-1.designed-hit-regions`: Home and the toast raised
    /// over it (the section headings) and both Detail presentations.
    private static let designedHitRegionSurfaces: Set<String> = [
        "Home root",
        "Toast (unsupported link)",
        "Gallery Detail",
        "Gallery Detail (iPad modal)"
    ]

    /// The buttons of `V-1.designed-hit-regions`, by the name XCTest reports: the heading and action
    /// titles, and the uploaders of the galleries the Detail tests open (`Pokom` from
    /// `GalleryDetail.html`, `hobohobo` from the first `FrontPageList.html` row the iPad modal opens).
    private static let designedHitRegionButtons: Set<String> = [
        "Show All",
        "Similar Gallery",
        "Pokom",
        "hobohobo"
    ]

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
        try tapScrolling(app.buttons["Popular"].firstMatch, in: app)
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
        try scrollUntilHittable(historyButton, in: app, of: app, direction: .upward)
        try scrollUntilHittable(historyButton, in: app.buttons["Popular"].firstMatch, of: app, direction: .leftward)
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
        try tapScrolling(app.buttons["App Activity Logs"].firstMatch, in: app)
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
        try tapScrolling(detailView.buttons["Show All"].firstMatch, in: app)
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
        try scrollUntilHittable(infosButton, in: app, of: app, direction: .upward)
        try scrollUntilHittable(infosButton, in: detailView.scrollViews.firstMatch, of: app, direction: .leftward)
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

    // MARK: Walkthrough regressions (16-25)

    /// VO-2: with the reader's control panel shown and no slider preview, the slider-preview strip
    /// is hidden, so nothing inside it may reach the accessibility hierarchy.
    ///
    /// Before the fix the panel's visible ancestor wrote `accessibilityHidden(false)` over the
    /// strip's own hide, and the strip's placeholder activity indicators were exposed with it. The
    /// band is the thirty points above the page slider, which is where the strip lies; a wider
    /// window also caught the indicators of the Detail screen the reader is presented over.
    /// `16-SWEEP.md § Design proposals (16-25) › P-VO2` records the isolation builds that proved
    /// the cause and the pre-fix count this asserts away.
    func testReadingControlPanelHidesSliderPreview() throws {
        let app = XCUIApplication()
        try showReadingControlPanel(in: app)
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 15), "The page slider did not appear.")
        settle(app, for: 2)
        let sliderMinY = slider.frame.minY
        let exposed = app.activityIndicators.allElementsBoundByIndex.filter { indicator in
            indicator.frame.minY >= sliderMinY - 30 && indicator.frame.maxY <= sliderMinY
        }
        let frames = exposed.map({ NSCoder.string(for: $0.frame) }).joined(separator: " ")
        XCTAssertEqual(
            exposed.count,
            0,
            "The hidden slider-preview strip exposed \(exposed.count) activity indicators: \(frames)"
        )
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
    /// The audit types the gate runs, named for the log; an unlisted raw value is printed as its
    /// number so nothing the engine reports is ever dropped from the record.
    ///
    /// The audit runs the three types whose reports are identical run to run. `.contrast`,
    /// `.dynamicType`, `.textClipped` and `.elementDetection` are deliberately not run, because
    /// their reports were OS heuristics or varied between identical runs:
    /// - `.contrast` compares two background shades inside a frame rather than the glyph with its
    ///   backdrop, so it failed text that renders at 16:1 and blocked every round.
    /// - `.dynamicType` reported size-sampling heuristics only, and its sweep sets off a UIKit
    ///   floating tab bar layout loop on the iOS 26.5 iPad that ends in "Audit failed to complete in
    ///   time".
    /// - `.textClipped` runs the same sweep, and its failure count changed between identical runs.
    /// - `.elementDetection` reported element-less "Potentially inaccessible text" only, in counts
    ///   that changed from run to run.
    ///
    /// Accessibility automation here is best effort, not a guarantee, by owner decision
    /// (2026-09-14); `16-CONTRAST-AUDIT.md § Automated audit (16-24)` records the evidence.
    static let auditTypeNames: [(type: XCUIAccessibilityAuditType, name: String)] = [
        (.hitRegion, "hitRegion"),
        (.sufficientElementDescription, "sufficientElementDescription"),
        (.trait, "trait")
    ]

    static func name(of auditType: XCUIAccessibilityAuditType) -> String {
        let names = auditTypeNames
            .filter({ auditType.contains($0.type) })
            .map(\.name)
        return names.isEmpty ? "rawValue \(auditType.rawValue)" : names.joined(separator: "+")
    }

    /// The audit runs as one `performAccessibilityAudit(for:)` call per audit type, never one
    /// `.all` call. On the iPad (A16) a single `.all` call over a long surface hit the engine's own
    /// limit of about 600 s ("Audit failed to complete in time", error −56: Frontpage and Popular
    /// in `a11y-final-ipad`; Date Seek, Filters, Frontpage, Popular and the iPad modals in
    /// `diag-25`), which fails the test with no report at all. Owner: "Split audits, fix helper"
    /// (2026-09-13).
    static let auditTypeGroups: [XCUIAccessibilityAuditType] = auditTypeNames.map(\.type)

    /// Audits everything on screen. Every issue is logged with the surface name so the result
    /// bundle carries the complete finding, then judged against the two allow-lists.
    ///
    /// XCTest records the failure for a non-ignored issue inside the handler, so with the class's
    /// `continueAfterFailure = false` the test would stop at the first issue and every later one
    /// would never reach the log. The flag is lifted for the audit calls alone — navigation before
    /// them still stops at its first failed wait — so one run records a surface's complete list.
    ///
    /// The frames and the screenshot are taken once, before the first call, and the calls run one
    /// type at a time (`auditTypeGroups`). A report the allow-lists do not claim fails the test,
    /// whether or not the engine named its element.
    func audit(_ app: XCUIApplication, surface: String) throws {
        let systemOwned = systemOwnedExclusions
        let ownerApproved = ownerApprovedExclusions
        let stopsAfterFailure = !continueAfterFailure
        continueAfterFailure = true
        defer { continueAfterFailure = !stopsAfterFailure }
        // The screenshot the audit judged, kept in the result bundle beside its findings.
        let inventory = try SurfaceInventory(app: app)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "surface-\(surface)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        for group in Self.auditTypeGroups {
            // Each call is its own activity, so a call that stalls is named in the test report even
            // when the process is ended before its buffered output is written.
            try XCTContext.runActivity(named: "Audit \(surface): \(Self.name(of: group))") { _ in
                try app.performAccessibilityAudit(for: group) { issue in
                    let report = AuditReport(surface: surface, issue: issue)
                    print(
                        "[a11y-audit] \(surface) | \(Self.name(of: issue.auditType)) | \(issue.compactDescription)"
                            + " | \(issue.detailedDescription) | \(report.elementDescription)"
                    )
                    if systemOwned.contains(where: { $0.matches(report) })
                        || ownerApproved.contains(where: { $0.matches(report) }) {
                        return true
                    }
                    // A failing report carries the pre-audit geometry its element's name had, so the
                    // record shows where the element lay when the audit ran.
                    print("[a11y-audit] \(surface) | judged | \(inventory.geometry(of: report.element?.name))")
                    return false
                }
            }
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
        try tapScrolling(app.buttons[label].firstMatch, in: app)
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

    /// Waits for the element, scrolls it into the hittable area if the screen is longer than what
    /// is shown, then taps it.
    func tapScrolling(
        _ element: XCUIElement,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertTrue(
            element.waitForExistence(timeout: 15),
            "\(element) did not appear.",
            file: file,
            line: line
        )
        try scrollUntilHittable(element, in: app, of: app, direction: .upward)
        XCTAssertTrue(element.isHittable, "\(element) never became hittable.", file: file, line: line)
        element.tap()
    }

    /// Swipes the container until the element lies inside what is shown along the swipe's axis,
    /// or gives up after a screenful of swipes.
    ///
    /// What is shown is the presented sheet's frame, or the window's when none is presented
    /// (`SurfaceInventory.visibleBounds(in:)`): on the iPad the Detail form sheet is 580 points
    /// wide inside an 820-point window, so the stats strip's Gallery Infos button lay inside the
    /// window yet past the sheet's trailing edge, and a window test swiped the page upward until
    /// the strip left the sheet (`a11y-final-ipad`, `diag-25`). Each call settles its own axis —
    /// an upward swipe stops once the element lies within the bounds vertically, a leftward swipe
    /// once it does horizontally — and only an element wholly inside the bounds is asked whether
    /// it is hittable (still under a bar, it is swiped further). XCTest records a failure
    /// ("activation point invalid") when hittability is asked of an element laid out beyond the
    /// screen edge, which is exactly the state this loop exists to leave. Owner: "Split audits,
    /// fix helper" (2026-09-13).
    func scrollUntilHittable(
        _ element: XCUIElement,
        in container: XCUIElement,
        of app: XCUIApplication,
        direction: SwipeDirection
    ) throws {
        let bounds = SurfaceInventory.visibleBounds(in: try app.snapshot())
        var remainingSwipes = 8
        while remainingSwipes > 0 {
            let frame = element.frame
            if !frame.isEmpty, direction.axisSpan(of: frame, liesWithin: bounds) {
                if !bounds.contains(frame) || element.isHittable {
                    return
                }
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

private extension AccessibilityAuditUITests.SwipeDirection {
    /// Whether the frame lies within the bounds along the axis this direction scrolls.
    func axisSpan(of frame: CGRect, liesWithin bounds: CGRect) -> Bool {
        switch self {
        case .upward:
            frame.minY >= bounds.minY && frame.maxY <= bounds.maxY
        case .leftward:
            frame.minX >= bounds.minX && frame.maxX <= bounds.maxX
        }
    }
}
