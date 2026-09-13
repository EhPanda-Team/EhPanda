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
    /// Issues on elements EhPanda does not draw — a UISearchBar, UIDatePicker or
    /// ContentUnavailableView part owned by an Apple component, or the presenting content a UIKit
    /// sheet presentation dims beneath the sheet. Each entry names the element and
    /// the Apple component that owns it, and matches that element only; nothing app-drawn belongs
    /// here. The evidence for every entry is in `16-CONTRAST-AUDIT.md § Automated audit (16-24) ›
    /// System-owned`.
    private let systemOwnedExclusions: [AuditExclusion] = [
        AuditExclusion(
            id: "UISearchBar.field",
            reason: "The `.searchable` field is a UISearchBar; the audit reports the field itself "
                + "as clipped text (Search root, every run). Nothing app-side draws the field.",
            matches: { report in
                report.auditType == .textClipped && report.element?.type == "SearchField"
            }
        ),
        AuditExclusion(
            id: "UIDatePicker.parts",
            reason: "The graphical `DatePicker` is a UIDatePicker; every day number and the month "
                + "label inside it are the picker's own (31 Dynamic Type reports on the Date Seek "
                + "sheet). Matched by name — a day of the month or a month-and-year — so the "
                + "app-drawn Older / Newer buttons and the section footer stay under audit.",
            matches: { report in
                guard report.surface == "Date Seek sheet", report.auditType == .dynamicType,
                      let element = report.element, element.type == "StaticText" else { return false }
                if let day = Int(element.name) { return (1...31).contains(day) }
                let words = element.name.split(separator: " ")
                return words.count == 2 && words[0].allSatisfy(\.isLetter) && Int(words[1]) != nil
            }
        ),
        AuditExclusion(
            id: "UIDatePicker.elementDetection",
            reason: "The two `elementDetection` reports on the Date Seek sheet carry no element; "
                + "they appear only while the UIDatePicker is on screen and are its own text "
                + "rendering. An element-less report cannot be matched more narrowly.",
            matches: { report in
                report.auditType == .elementDetection && report.element == nil && report.surface == "Date Seek sheet"
            }
        ),
        AuditExclusion(
            id: "UISheetPresentationController.dimmed-presenting-content",
            reason: "On the regular-width pad idiom Setting, Gallery Detail and the toolbar sheets are "
                + "presented as form sheets over the tab UI, and UIKit's sheet presentation keeps the "
                + "presenting content — Home's carousel, sections and the top tab bar — on screen "
                + "under its dimming view. The audit reports that dimmed text as element-less "
                + "`elementDetection` \"Potentially inaccessible text\" (4–7 per attempt on every "
                + "sheet surface of the iPad (A16) run `a11y-final-ipad`, none on the same surfaces "
                + "on iPhone). The text is the presenting app's, rendered inert by the presentation, "
                + "not the sheet's. Matched on the pad idiom and the sheet surfaces only. Owner: "
                + "\"Approve, measure four now\" (2026-09-13).",
            matches: { report in
                report.isPadIdiom && report.auditType == .elementDetection && report.element == nil
                    && AccessibilityAuditUITests.padSheetSurfaces.contains(report.surface)
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

    /// The surfaces the pad idiom presents as a sheet over the tab UI (see
    /// `UISheetPresentationController.dimmed-presenting-content`). The Date Seek sheet has its own
    /// entry; the reader surfaces cover the whole screen and are not listed.
    private static let padSheetSurfaces: Set<String> = [
        "Setting root",
        "Setting (iPad modal)",
        "Setting › Account",
        "Setting › General",
        "Setting › General › App Activity Logs",
        "Setting › Appearance",
        "Setting › Reading",
        "Setting › Download",
        "Setting › Laboratory",
        "Setting › About",
        "Gallery Detail",
        "Gallery Detail (iPad modal)",
        "Detail › Previews",
        "Detail › Gallery Infos",
        "Detail › Comments",
        "Filters sheet",
        "Quick Search sheet",
        "Error info sheet"
    ]

    /// App-owned issues that are documented false positives and cannot be resolved without a
    /// visible change the owner has not authorised — for example a `.contrast` report on text
    /// drawn over an image or a gradient. Each entry names the element, the audit type, the
    /// measured reason and quotes the owner's `E-n=approve` reply recorded in
    /// `16-CONTRAST-AUDIT.md § Automated audit (16-24)`. Nothing enters this list before that
    /// reply (Phase 16 D-22). Every matcher reads the report's element by name and type from its
    /// description alone — see `AuditElement` for why.
    private let ownerApprovedExclusions: [AuditExclusion] = [
        AuditExclusion(
            id: "E-1.hidden-content",
            reason: "Content the app keeps in the hierarchy at opacity 0 through `visible(false)` "
                + "(`opacity` + `accessibilityHidden`): the `ErrorView` beneath each list (\"Unknown "
                + "Error\", \"An unknown error occurred…\", \"Retry\" on Home, Frontpage, Popular, "
                + "Favorites and behind the toast), Detail's hidden `LoadingView` / `ErrorView` "
                + "(reported under the host identifier `detail_view`), the \"No Logs Found\" overlay "
                + "and the reader's slider-preview strip (captions \"1\"–\"3\", three activity "
                + "indicators; on the page surface the whole hidden panel). Every audit type; the "
                + "frames in the reports sit where the screenshot shows other content. Matched by "
                + "name per surface. The strip's captions share their names with the visible slider "
                + "label and page number: on the page surface only `.dynamicType` is matched, so a "
                + "placeholder contrast regression still shows there. Owner: `E-1=approve` "
                + "(2026-09-13). The iPad (A16) run names the strip's captions \"0\" and \"4\" as "
                + "well (the wider panel lays out five): each element crop is the strip's empty "
                + "`#F2F2F5` band with no caption drawn (`#CACACF` edge, 1.46:1). Owner: \"Approve, "
                + "measure four now\" (2026-09-13).",
            matches: { report in
                guard let element = report.element else { return false }
                switch report.surface {
                case "Home root", "Toast (unsupported link)", "Frontpage", "Popular", "Favorites (login placeholder)":
                    return AccessibilityAuditUITests.hiddenErrorTexts.contains(element.name)
                case "Gallery Detail", "Gallery Detail (iPad modal)":
                    return element.name == "detail_view" && element.type == "StaticText"
                case "Setting › General › App Activity Logs":
                    return element.name == "No Logs Found"
                case "Reading (page)":
                    return report.auditType == .dynamicType
                        && AccessibilityAuditUITests.hiddenPanelTexts.contains(element.name)
                case "Reading › control panel":
                    let isStripCaption = AccessibilityAuditUITests.hiddenStripCaptions.contains(element.name)
                    return (report.auditType == .contrast && isStripCaption)
                        || element.type == "ActivityIndicator"
                default:
                    return false
                }
            }
        ),
        AuditExclusion(
            id: "E-2.hidden-when-audited",
            reason: "`.contrast` \"failed\" on text hidden when the audit ran. Under the Liquid Glass tab bar or its "
                + "scroll-edge blur, the navigation bar, or the toast card at audit time: Home's "
                + "Toplists heading row and placeholder rows (and, behind the toast, its Show All), "
                + "the last Frontpage / Popular cell, the About contributor rows and General rows "
                + "at the foot of the screen, the bottom Activity Logs rows, the linked comment "
                + "(author, score, date, body) scrolled under the bar. Rendered through the bar "
                + "General \"Analytics\" is 2.60:1, yet \"Yesterday\" (18.11) and \"Kaed3mi\" (11.10) "
                + "report the same — the engine samples the blur layer. Matched on the frames of "
                + "the snapshot taken before the audit (`SurfaceInventory`): an exposed element "
                + "with the report's name intersects a bar, the toast, or the scroll-edge band "
                + "above the tab bar. The frames replace a per-surface name list that matched only "
                + "the iPhone 17e's scroll positions. Owner: `E-2=approve` (2026-09-13); the frame "
                + "matcher with the 24-pt band: \"Approve both\" (2026-09-13). Past the edge of what is "
                + "shown: on the iPad a form sheet's content below or beside its frame (Detail's "
                + "comment cards \"+113\" / \"Post Comment\" / authors / dates / body / pixiv URL, the "
                + "\"FILE SIZE\" column, Filters' \"Search Torrent Filenames\" cut by the sheet's foot, "
                + "Error info \"Environment\") — each element crop is the dimmed presenting content, "
                + "`#BABDB9`–`#C6C7C6` — and, with no sheet presented, content cut by the window "
                + "edge (Home's \"Past Month\" Toplists column at the right edge). The same geometric "
                + "rule: an exposed element with the report's name lies outside, or is cut by, the "
                + "presented sheet's frame (the window's when none is presented). Owner: \"Approve "
                + "both\" (2026-09-13).",
            matches: { report in
                report.auditType == .contrast && report.verdict == "Contrast failed" && report.wasHiddenWhenAudited
            }
        ),
        AuditExclusion(
            id: "E-3.sampling-artifacts",
            reason: "`.contrast` \"failed\" on text whose rendered contrast is high but whose frame "
                + "holds two background shades the engine compares with each other: Detail's "
                + "stats-strip captions \"110 RATINGS\" / \"PAGE COUNT\" (21.00:1, drawn under "
                + "`drawingGroup()`), the Activity Logs \"Parser\" chips (16.73:1 on the chip fill), "
                + "About \"Website\" (20.75:1), Appearance \"List\" (3.29:1, identical to "
                + "\"Gallery\" beside it, which reports \"nearly passed\"), the Previews caption "
                + "\"4\" (3.44:1, identical to its siblings). Deterministic across every run. "
                + "Owner: `E-3=approve` (2026-09-13). On the iPhone 17 the engine also fails "
                + "Frontpage / Popular cell texts that lie clear of every bar, so the frame matcher "
                + "(E-2) rightly leaves them: the category badge \"Manga\" at y 613.7 mid-screen "
                + "(8.21:1, black on `#E88C1A`, audit row 25), the page count \"52\" at y 440.7 "
                + "(`#7F7F7F` on white, 4.00:1) and the page count \"10\" at y 751.1–766.7, 0.3 pt "
                + "above the scroll-edge band (`#818181` on white, 3.90:1; its frame also holds "
                + "`#FEFEFE`). Owner: \"Approve both\" (2026-09-13). On the iPad (A16) the Previews "
                + "tile captions \"16\"–\"20\" report too: their frames lie past the foot of the form "
                + "sheet, and each element crop is the dimmed Home content beneath it, a flat "
                + "`#C6C7C6` (1.01:1). Owner: \"Approve, measure four now\" (2026-09-13). The toast "
                + "body \"This link wasn't recognized as an EhPanda gallery link.\" on the iPad renders "
                + "`#727272` on `#FDFDFD`, 4.79:1, in a frame that also holds `#FBFBFE`. Owner: "
                + "\"Approve both\" (2026-09-13).",
            matches: { report in
                guard report.auditType == .contrast, report.verdict == "Contrast failed",
                      let element = report.element else { return false }
                return AccessibilityAuditUITests.samplingArtifacts[report.surface]?.contains(element.name) == true
            }
        ),
        AuditExclusion(
            id: "E-4.secondary-text",
            reason: "`.contrast` \"nearly passed\" (≥ 3:1, < 4.5:1) on `.secondary` text and switch "
                + "labels: list-cell metadata, comment score and date, preview captions, Form section "
                + "headers, footers and descriptions. Rendered `#7F7F7F` on white 4.00:1, `#8A8A8E` on "
                + "white 3.44:1, `#85858B` on `#F2F2F7` 3.29:1 — the platform's hierarchical "
                + "`.secondary`, the recorded `secondary-meta` caveat (16-CONTRAST-AUDIT D-28). "
                + "Never a \"failed\" verdict. Owner: `E-4=approve` (2026-09-13).",
            matches: { report in
                guard report.auditType == .contrast, report.verdict == "Contrast nearly passed",
                      let element = report.element else { return false }
                return element.type == "StaticText" || element.type == "Switch"
            }
        ),
        AuditExclusion(
            id: "E-5.accent-text",
            reason: "`.contrast` on accent-tinted text controls and values: buttons (\"Login\", "
                + "\"Copy Cookies\", \"English\", \"Import Custom Translations\", \"Show All\", "
                + "\"Reset Filters\" in system red), the Reading Setting scale values \"2.0x\" / "
                + "\"3.0x\" and the Gallery Infos copy values. Rendered accent `#669D34` on white "
                + "3.26:1, on the grouped `#F2F2F7` 2.92:1 (the one \"failed\" verdict, the lower "
                + "Account \"Copy Cookies\"), `.red` `#FF383C` 3.57:1; dark passes at ≥ 9.54:1. "
                + "The brand accent is not re-authored here (16-23). Owner: `E-5=approve` "
                + "(2026-09-13).",
            matches: { report in
                guard report.auditType == .contrast, let element = report.element else { return false }
                let nearlyPassed = report.verdict == "Contrast nearly passed"
                if element.type == "Button" {
                    return nearlyPassed || (report.surface == "Setting › Account" && element.name == "Copy Cookies")
                }
                return nearlyPassed
                    && (report.surface == "Detail › Gallery Infos" || ["2.0x", "3.0x"].contains(element.name))
            }
        ),
        AuditExclusion(
            id: "E-6.disabled-controls",
            reason: "`.contrast` \"failed\" on disabled controls: Detail's \"Give a Rating\" while "
                + "logged out (1.72:1) and Date Seek's \"Newer\" with no newer page (1.71:1) — the "
                + "system's disabled tint, which WCAG 1.4.3 exempts. Owner: `E-6=approve` "
                + "(2026-09-13).",
            matches: { report in
                guard report.auditType == .contrast, report.verdict == "Contrast failed",
                      let element = report.element else { return false }
                let onDetail = AccessibilityAuditUITests.galleryDetailSurfaces.contains(report.surface)
                return (onDetail && element.name == "Give a Rating")
                    || (report.surface == "Date Seek sheet" && element.name == "Newer")
            }
        ),
        AuditExclusion(
            id: "E-7.namespace-chip",
            reason: "`.contrast` \"nearly passed\" on Detail's tag-namespace chip \"Other\": white on "
                + "`#8E8E93`, 3.26:1, the namespace palette under D-26 (the category badges beside "
                + "it pass at 8.20 / 6.37 / 4.69). Owner: `E-7=approve` (2026-09-13).",
            matches: { report in
                report.auditType == .contrast && report.verdict == "Contrast nearly passed"
                    && AccessibilityAuditUITests.galleryDetailSurfaces.contains(report.surface)
                    && report.element?.name == "Other"
            }
        ),
        AuditExclusion(
            id: "E-8.size-heuristics",
            reason: "`.dynamicType` \"partially unsupported\" and `.textClipped` on app-drawn text: "
                + "hero-carousel titles, Older / Newer, Form rows, the visible `ContentUnavailableView` "
                + "texts, Setting root \"Appearance\", the Filters \"Asian Porn\" tile, the toast "
                + "title and body (round-1 #42, accepted). Size-sampling heuristics with no "
                + "measurement; every named text renders whole at `.large` and every screen is in "
                + "the signed round-1 sweep at XXL / AX3 / AX5 (`16-SWEEP.md`). Owner: "
                + "`E-8=approve` (2026-09-13).",
            matches: { report in
                report.element != nil && (report.auditType == .dynamicType || report.auditType == .textClipped)
            }
        ),
        AuditExclusion(
            id: "E-9.reader-panel-range",
            reason: "`.dynamicType` on the reader control panel (page indicator, slider labels): the "
                + "panel is clamped to `.dynamicTypeSize(.large...xxLarge)` by owner decision "
                + "(`ControlPanel.swift`, lint rule `reading_controls_dynamic_type_range`), so "
                + "\"partially unsupported\" is literally the decision. Owner: `E-9=approve` "
                + "(2026-09-13).",
            matches: { report in
                report.auditType == .dynamicType && report.surface == "Reading › control panel"
            }
        )
    ]

    /// The two routes to the same Detail view: the deep link, and on the iPad the Frontpage row that
    /// presents it as a sheet (`testPadSettingAndDetailModalsAudit`). An entry that names a Detail
    /// element names it on both.
    private static let galleryDetailSurfaces: Set<String> = ["Gallery Detail", "Gallery Detail (iPad modal)"]

    /// The hidden `ErrorView`'s texts (E-1).
    private static let hiddenErrorTexts: Set<String> = [
        "Unknown Error",
        "An unknown error occurred.\nPlease try again later.",
        "Retry"
    ]

    /// The reader control panel's texts while the panel is hidden on the page surface (E-1).
    private static let hiddenPanelTexts: Set<String> = ["1", "2", "3", "156", "reading_page_indicator"]

    /// The slider-preview strip's captions while the control panel shows no strip: three on the
    /// iPhone, five on the iPad's wider panel (E-1).
    private static let hiddenStripCaptions: Set<String> = ["0", "1", "2", "3", "4"]

    /// The high-contrast texts the engine's two-colour sampling fails, per surface (E-3).
    private static let samplingArtifacts: [String: Set<String>] = [
        "Gallery Detail": ["110 RATINGS", "PAGE COUNT"],
        "Gallery Detail (iPad modal)": ["110 RATINGS", "PAGE COUNT"],
        "Setting › General › App Activity Logs": ["Parser"],
        "Setting › About": ["Website"],
        "Setting › Appearance": ["List"],
        "Detail › Previews": ["4", "16", "17", "18", "19", "20"],
        "Frontpage": ["Manga", "52", "10"],
        "Popular": ["Manga", "52", "10"],
        "Toast (unsupported link)": ["This link wasn't recognized as an EhPanda gallery link."]
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

    /// The audit runs as one `performAccessibilityAudit(for:)` call per audit type, never one
    /// `.all` call. On the iPad (A16) a single `.all` call over a long surface hit the engine's own
    /// limit of about 600 s ("Audit failed to complete in time", error −56: Frontpage and Popular
    /// in `a11y-final-ipad`; Date Seek, Filters, Frontpage, Popular and the iPad modals in
    /// `diag-25`), which fails the test with no report at all; smaller calls keep each one under
    /// that limit. Coverage does not shrink: the last group is `.all` less the named types — every
    /// bit the platform may add — so the groups' union is `.all` by construction. Owner: "Split
    /// audits, fix helper" (2026-09-13).
    static let auditTypeGroups: [XCUIAccessibilityAuditType] = {
        let named: [XCUIAccessibilityAuditType] = auditTypeNames.map(\.type)
        let covered = named.reduce(into: XCUIAccessibilityAuditType()) { union, group in
            union.formUnion(group)
        }
        return named + [XCUIAccessibilityAuditType.all.subtracting(covered)]
    }()

    /// The audit types whose element-less reports are logged rather than judged (see
    /// `logElementlessReport(_:surface:count:)`).
    static let elementlessLoggedTypes: [XCUIAccessibilityAuditType] = [
        .contrast, .dynamicType, .textClipped, .elementDetection
    ]

    /// Audits everything on screen. Every issue is logged with the surface name so the result
    /// bundle carries the complete finding, then judged against the two allow-lists.
    ///
    /// XCTest records the failure for a non-ignored issue inside the handler, so with the class's
    /// `continueAfterFailure = false` the test would stop at the first issue and every later one
    /// would never reach the log. The flag is lifted for the audit calls alone — navigation before
    /// them still stops at its first failed wait — so one run records a surface's complete list.
    ///
    /// The frames and the screenshot are taken once, before the first call, and the calls run one
    /// group at a time (`auditTypeGroups`). A report the allow-lists do not claim and whose
    /// element the engine withheld is logged and attached, never judged, when its type is one of
    /// `elementlessLoggedTypes`: see `logElementlessReport(_:surface:count:)`.
    func audit(_ app: XCUIApplication, surface: String) throws {
        let systemOwned = systemOwnedExclusions
        let ownerApproved = ownerApprovedExclusions
        let isPadIdiom = UIDevice.current.userInterfaceIdiom == .pad
        let stopsAfterFailure = !continueAfterFailure
        continueAfterFailure = true
        defer { continueAfterFailure = !stopsAfterFailure }
        // The screenshot the audit judged, kept in the result bundle beside its finding so a
        // contrast verdict can be measured against the rendered pixels afterwards.
        let inventory = try SurfaceInventory(app: app)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "surface-\(surface)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        var elementlessCounts: [String: Int] = [:]
        for group in Self.auditTypeGroups {
            // Each call is its own activity, so a call that stalls is named in the test report even
            // when the process is ended before its buffered output is written.
            try XCTContext.runActivity(named: "Audit \(surface): \(Self.name(of: group))") { _ in
                try app.performAccessibilityAudit(for: group) { issue in
                    let report = AuditReport(
                        surface: surface, issue: issue, inventory: inventory, isPadIdiom: isPadIdiom
                    )
                    print(
                        "[a11y-audit] \(surface) | \(Self.name(of: issue.auditType)) | \(issue.compactDescription)"
                            + " | \(issue.detailedDescription) | \(report.elementDescription)"
                    )
                    if systemOwned.contains(where: { $0.matches(report) })
                        || ownerApproved.contains(where: { $0.matches(report) }) {
                        return true
                    }
                    guard report.element == nil,
                          Self.elementlessLoggedTypes.contains(where: { $0 == report.auditType }) else {
                        // A failing report carries the pre-audit geometry its element's name had, so
                        // the record shows why no geometric rule claimed it.
                        print("[a11y-audit] \(surface) | judged | \(inventory.geometry(of: report.element?.name))")
                        return false
                    }
                    let typeName = Self.name(of: report.auditType)
                    elementlessCounts[typeName, default: 0] += 1
                    self.logElementlessReport(report, surface: surface, count: elementlessCounts[typeName, default: 0])
                    return true
                }
            }
        }
    }

    /// Records a report that arrived without its element — logged with the surface, the audit
    /// type, the verdict and that type's running count on the surface, and attached to the result
    /// bundle — and never fails the test on it.
    ///
    /// This is a known blind spot of the audit engine on Xcode 26.6 with the iOS 26.5 simulator,
    /// not a verdict on the app. For some runs the engine returns reports whose `issue.element`
    /// is nil, from cold boots on both iPhone spares, with nothing but time differing between
    /// runs: `fresh-1`/`-2`/`-3`, `a11y-final-iphone-1`/`-2` and `diag-24` bound every contrast
    /// element, while `diag-22` and `diag-23` (Frontpage alone) withheld every one (17 and 51
    /// reports). The iPad (A16) runs `a11y-final-ipad` and `diag-25` withheld most contrast
    /// elements and also delivered element-less `.dynamicType` (the top tab bar's labels,
    /// "unsupported" on Error info and About), `.textClipped` (Comments, Error info, the search
    /// field) and `.elementDetection` reports; the iPhone runs `a11y-final-iphone-1`/`-2` an
    /// element-less `.textClipped` on Gallery Detail and Activity Logs. A report without an element
    /// cannot be told apart from its bound twin — which an entry may already cover — so failing
    /// on it would make the gate fail by run, not by app, and excluding it through a list would
    /// hide what it says; it is logged instead, so the count is visible in every result bundle.
    /// The allow-lists are consulted first, so an element-less report an entry claims (the
    /// Date Seek picker's, the iPad sheets' dimmed presenting content) stays classified by that
    /// entry and is not counted here. Every report that names its element, and every element-less
    /// report of another type, is judged by the allow-lists as before. The blind spot is recorded
    /// in `16-CONTRAST-AUDIT.md § Automated audit (16-24)` for the Nutrition Label. Owner: "O-2:
    /// log, never fail" (2026-09-13); widened to `.dynamicType`, `.textClipped` and
    /// `.elementDetection`: "Extend O-2 to them" (2026-09-13).
    func logElementlessReport(_ report: AuditReport, surface: String, count: Int) {
        let typeName = Self.name(of: report.auditType)
        let line = "[a11y-audit] \(surface) | element-less \(typeName) #\(count) | \(report.verdict)"
            + " | logged, not judged (engine withheld the element)"
        print(line)
        let attachment = XCTAttachment(string: line)
        attachment.name = "elementless-\(typeName)-\(surface)-\(count)"
        attachment.lifetime = .keepAlways
        add(attachment)
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
