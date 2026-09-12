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
    /// owns it, and matches that element only; nothing app-drawn belongs here.
    private let systemOwnedExclusions: [AuditExclusion] = []

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
        tapScrolling(app.buttons["History"].firstMatch, in: app)
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

    /// Quick Search lives on the Search root's toolbar, not on Frontpage's.
    func testQuickSearchSheetAudit() throws {
        let app = try launch(tab: "search")
        requireNavigationTitle("Search", in: app)
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
        scrollUntilHittable(infosButton, in: app, direction: .upward)
        if !infosButton.isHittable {
            let statsStrip = detailView.scrollViews.firstMatch
            scrollUntilHittable(infosButton, in: statsStrip, direction: .leftward)
        }
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
        app.requireElement("comment_cell_" + UITestConstants.commentID)
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
    /// are empty the handler returns `false` for every issue and the test fails on the first one.
    func audit(_ app: XCUIApplication, surface: String) throws {
        let systemOwned = systemOwnedExclusions
        let ownerApproved = ownerApprovedExclusions
        try app.performAccessibilityAudit(for: .all) { issue in
            let elementDescription = issue.element?.description ?? "<no element>"
            print(
                "[a11y-audit] \(surface) | \(Self.name(of: issue.auditType)) | \(issue.compactDescription)"
                    + " | \(issue.detailedDescription) | \(elementDescription)"
            )
            return systemOwned.contains(where: { $0.matches(issue) })
                || ownerApproved.contains(where: { $0.matches(issue) })
        }
    }
}

// MARK: - Navigation

private extension AccessibilityAuditUITests {
    enum SwipeDirection {
        case upward
        case leftward
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
        scrollUntilHittable(element, in: app, direction: .upward)
        XCTAssertTrue(element.isHittable, "\(element) never became hittable.", file: file, line: line)
        element.tap()
    }

    func scrollUntilHittable(_ element: XCUIElement, in container: XCUIElement, direction: SwipeDirection) {
        var remainingSwipes = 8
        while !element.isHittable, remainingSwipes > 0 {
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
    let matches: (XCUIAccessibilityAuditIssue) -> Bool
}
