import XCTest

/// The native behaviour the snapshot matrix cannot see, because it lives in transitions (D-19, 17-09-T2): entry at
/// each text size the policy checks, a text size changed while the app runs, and rotation.
///
/// The text sizes are Large, AX1, AX3 and AX5 (AGENTS.md). A cold entry asks for its size with
/// `-UIPreferredContentSizeCategoryName`; a live change goes through the Settings app (`LiveTextSize`), so it needs a
/// launch without that argument. No screenshot from this class is a matrix picture (D-07).
@MainActor
final class NativeVisualPolicyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Cold entry

    func testColdEntryAtLarge() throws {
        try checkColdEntry(at: .large, named: "Large")
    }

    func testColdEntryAtAX1() throws {
        try checkColdEntry(at: .accessibilityMedium, named: "AX1")
    }

    func testColdEntryAtAX3() throws {
        try checkColdEntry(at: .accessibilityExtraLarge, named: "AX3")
    }

    func testColdEntryAtAX5() throws {
        try checkColdEntry(at: .accessibilityExtraExtraExtraLarge, named: "AX5")
    }

    // MARK: Live text size

    /// The Settings route reaches every size the policy checks while the app runs, and the app comes back to the
    /// page it showed.
    func testLiveTextSizeRouteReachesEverySize() throws {
        let app = XCUIApplication()
        addTeardownBlock { @MainActor in
            LiveTextSize.reset()
        }
        try app.launchStubbed(extraEnvironment: [Self.tabKey: "search"])
        app.requireForeground()
        requireTitle("Search", in: app)
        for size in [LiveTextSize.Size.accessibility1, .accessibility3, .accessibility5, .large] {
            LiveTextSize.set(size, returningTo: app)
            requireTitle("Search", in: app, at: size.name)
        }
    }

    /// A change after Settings has quit at AX5 still reaches its size. On the hosted runners Settings is gone by the
    /// next change (run 3: `Terminate com.apple.Preferences:0` on both devices), so it opens fresh at AX5. The
    /// first row on the Settings tab grows with the text size, so its height shows the app took each change.
    func testLiveTextSizeReachesLargeAfterSettingsQuitAtAX5() throws {
        let app = XCUIApplication()
        addTeardownBlock { @MainActor in
            LiveTextSize.reset()
        }
        try app.launchStubbed(extraEnvironment: [Self.tabKey: "setting"])
        app.requireForeground()
        requireTitle("Settings", in: app)
        let row = app.buttons["Account"].firstMatch
        XCTAssertTrue(row.waitUntilHittable(timeout: XCUIElement.hittableTimeout), "Account is not on screen.")
        let large = row.frame.height
        LiveTextSize.set(.accessibility5, returningTo: app)
        XCTAssertTrue(holds { row.frame.height > large }, "The app did not take AX5.")
        XCUIApplication(bundleIdentifier: LiveTextSize.settingsBundleIdentifier).terminate()
        LiveTextSize.set(.large, returningTo: app)
        XCTAssertTrue(holds { abs(row.frame.height - large) < 1 }, "The app did not come back to Large.")
    }

    /// Whether `condition` comes to hold within 15 seconds, the time a size change takes to reach the layout.
    private func holds(_ condition: @escaping () -> Bool) -> Bool {
        let met = NSPredicate { _, _ in condition() }
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: met, object: nil)], timeout: 15) == .completed
    }

    // MARK: Preservation

    /// A typed, focused query on the Search tab keeps its text, focus, title and tab through live size changes
    /// and turns (17-09-T2 idempotency edge): each size is entered and each turn made more than once.
    func testSearchKeepsQueryFocusAndTabThroughSizesAndTurns() throws {
        let app = XCUIApplication()
        addTeardownBlock { @MainActor in
            XCUIDevice.shared.orientation = .portrait
            LiveTextSize.reset()
        }
        XCUIDevice.shared.orientation = .portrait
        try app.launchStubbed(extraEnvironment: [Self.tabKey: "search"])
        app.requireForeground()
        let field = revealSearchField(in: app)
        field.tapWhenHittable("Search field")
        field.typeText(Self.query)
        let state = SearchState(app: app)
        state.require(at: "Large")
        for size in [LiveTextSize.Size.accessibility3, .accessibility5, .accessibility3, .large] {
            LiveTextSize.set(size, returningTo: app)
            state.require(at: size.name)
            for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
                turn(app, to: orientation)
                state.require(at: "\(size.name) \(orientation.isLandscape ? "landscape" : "portrait")")
            }
        }
    }

    /// A settings page's picker and toggle marks and its title survive live size changes and turns. On iPad the
    /// page is pushed inside the Settings sheet, whose title mode is `large`.
    func testSettingMarksAndTitleSurviveSizesAndTurns() throws {
        let app = XCUIApplication()
        addTeardownBlock { @MainActor in
            XCUIDevice.shared.orientation = .portrait
            LiveTextSize.reset()
        }
        XCUIDevice.shared.orientation = .portrait
        try app.launchStubbed(extraEnvironment: [Self.tabKey: "setting"])
        app.requireForeground()
        requireTitle("Settings", in: app)
        let row = app.buttons["Appearance"].firstMatch
        revealElement(row, in: app)
        row.tapWhenHittable("Appearance")
        requireTitle("Appearance", in: app)
        let marks = Self.markLabels.map({ mark($0, in: app) })
        XCTAssertFalse(marks.contains(""), "Appearance shows no mark for one of \(Self.markLabels).")
        for size in [LiveTextSize.Size.accessibility5, .large] {
            LiveTextSize.set(size, returningTo: app)
            for orientation in [UIDeviceOrientation.landscapeLeft, .portrait] {
                turn(app, to: orientation)
                let step = "\(size.name) \(orientation.isLandscape ? "landscape" : "portrait")"
                XCTAssertTrue(app.navigationBars["Appearance"].waitForExistence(timeout: 10),
                              "Appearance left at \(step).")
                let now = Self.markLabels.map({ mark($0, in: app) })
                XCTAssertEqual(now, marks, "The marks changed at \(step).")
            }
        }
    }

    // MARK: Toolbar overflow and anchors

    /// The reader keeps Close and the page indicator, its high-priority items, at every width, and its overflow
    /// keeps Reading Settings: the narrowest pinned width is the phone upright, the widest the pad turned.
    func testReaderToolbarKeepsPriorityAtEveryWidth() throws {
        let app = XCUIApplication()
        addTeardownBlock { @MainActor in
            XCUIDevice.shared.orientation = .portrait
        }
        XCUIDevice.shared.orientation = .portrait
        try app.openCold(XCTUnwrap(UITestConstants.singlePageURL(scheme: "ehpanda")))
        let reader = app.requireElement("reading_view")
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft, .portrait] {
            turn(app, to: orientation)
            let width = "\(Int(app.windows.firstMatch.frame.width)) points"
            showReaderPanel(in: app)
            let indicator = app.staticTexts.matching(identifier: "reading_page_indicator").firstMatch
            XCTAssertTrue(indicator.waitUntilHittable(timeout: 10), "The page indicator overflowed at \(width).")
            XCTAssertTrue(reader.buttons["Close"].firstMatch.isHittable, "Close overflowed at \(width).")
            let more = reader.buttons.matching(UITestConstants.overflowButtonPredicate).firstMatch
            XCTAssertTrue(more.waitUntilHittable(timeout: 10), "More overflowed at \(width).")
            // The open menu covers the bar, so More is read before it opens.
            let source = more.frame
            more.tapWhenHittable("The reader's More at \(width)")
            let settings = app.buttons["Reading Settings"].firstMatch
            XCTAssertTrue(settings.waitForExistence(timeout: 5), "More lost Reading Settings at \(width).")
            requireAnchored(settings.frame, to: source, named: "More at \(width)")
            dismissPopover(in: app, until: settings)
        }
    }

    /// The action-source dialog (Search's Remove All) and the overflow menu stay with their controls through a
    /// turn: on iPad both are popovers whose arrow points at the control (AGENTS.md dialog placement).
    func testDialogAndMenuStayAnchoredThroughTurns() throws {
        let app = XCUIApplication()
        addTeardownBlock { @MainActor in
            XCUIDevice.shared.orientation = .portrait
        }
        XCUIDevice.shared.orientation = .portrait
        try app.launchStubbed(extraEnvironment: [Self.tabKey: "search"])
        app.requireForeground()
        let field = revealSearchField(in: app)
        field.tapWhenHittable("Search field")
        field.typeText(Self.query + "\n")
        // The results page's overflow menu.
        let more = app.navigationBars.buttons.matching(UITestConstants.overflowButtonPredicate).firstMatch
        checkAnchorThroughTurns(
            of: app.buttons["Quick Search"].firstMatch, from: more, isDialog: false, named: "More", in: app
        )
        // Back on the Search root, the query is a recent search that Remove All can clear.
        app.buttons["BackButton"].firstMatch.tapWhenHittable("Back to Search")
        let source = app.buttons["search-remove-all-keywords"].firstMatch
        revealElement(source, in: app)
        let confirm = app.buttons.matching(
            // Not either section's own Remove All, which open the dialogs.
            NSPredicate(format: "label == %@ AND NOT identifier BEGINSWITH %@", "Remove All", "search-remove-all")
        ).firstMatch
        checkAnchorThroughTurns(of: confirm, from: source, isDialog: true, named: "Remove All", in: app)
        XCTAssertTrue(app.staticTexts[Self.query].firstMatch.exists, "Dismissing the dialog removed the search.")
    }

    // MARK: Support

    /// A root with a designed `inlineLarge` title, which the tab bar or launch opens (the scroll-edge inventory's
    /// tab roots). On iPad, Settings opens as a sheet, whose title is `large`.
    struct Root {
        let tab: String
        let title: String
        /// Favorites and Downloads title the Library root: the source is the title beside a sidebar, and the
        /// subtitle under Library's source menu without one.
        let isLibrarySource: Bool
        let isSearchable: Bool
        var environment: [String: String] = [:]
    }

    static let tabKey = "EHPANDA_AUTOMATION_TAB"

    static let roots = [
        Root(tab: "home", title: "Home", isLibrarySource: false, isSearchable: false),
        Root(tab: "search", title: "Search", isLibrarySource: false, isSearchable: true),
        Root(tab: "favorites", title: "Favorites", isLibrarySource: true, isSearchable: true, environment: [
            "EHPANDA_AUTOMATION_IPB_MEMBER_ID": "fixture-member",
            "EHPANDA_AUTOMATION_IPB_PASS_HASH": "fixture-session"
        ]),
        Root(tab: "downloads", title: "Downloads", isLibrarySource: true, isSearchable: true),
        Root(tab: "setting", title: "Settings", isLibrarySource: false, isSearchable: false)
    ]

    /// Launches every root at `category`, named `size` in failures, and checks its title is up and its search
    /// field, where it has one, can be reached.
    private func checkColdEntry(at category: UIContentSizeCategory, named size: String) throws {
        for root in Self.roots {
            let app = XCUIApplication()
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", category.rawValue]
            try app.launchStubbed(extraEnvironment: root.environment.merging([Self.tabKey: root.tab]) { $1 })
            app.requireForeground()
            let label = "\(root.title) at \(size)"
            if root.isLibrarySource {
                app.requireLibraryNavigationTitle(root.title)
            } else {
                requireTitle(root.title, in: app, at: size)
            }
            if root.isSearchable {
                XCTAssertTrue(revealSearchField(in: app).isHittable, "\(label) has no search field to reach.")
            }
            app.terminate()
        }
    }

    /// Checks the page titled `title` is up, with its title on screen.
    func requireTitle(
        _ title: String, in app: XCUIApplication, at size: String = "launch",
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let bar = app.navigationBars[title]
        XCTAssertTrue(bar.waitForExistence(timeout: 15), "\(title) is not up at \(size).", file: file, line: line)
        let heading = bar.staticTexts[title]
        if UIDevice.current.userInterfaceIdiom == .pad, !heading.waitForExistence(timeout: 2) {
            // An iPad tab bar sits at the top in the navigation bar's place, which then shows no title: the
            // selected tab names the page.
            let tab = Self.tab(title, in: app)
            XCTAssertTrue(
                tab.waitUntilHittable(timeout: 10) && tab.isSelected, "\(title)'s tab is off screen at \(size).",
                file: file, line: line
            )
        } else {
            XCTAssertTrue(
                heading.waitUntilHittable(timeout: 10), "\(title) is off screen at \(size).", file: file, line: line
            )
        }
    }

    /// The tab named `title`. A phone's tab bar is a tab bar; an iPad's floats at the top as plain buttons, ahead
    /// of the keyboard's in the hierarchy.
    nonisolated static func tab(_ title: String, in app: XCUIApplication) -> XCUIElement {
        let bar = app.tabBars.firstMatch
        let buttons = bar.exists ? bar.buttons : app.buttons
        return buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    nonisolated static let query = "panda"

    /// The Appearance marks read before and after each change: a menu picker's choice and two toggles.
    nonisolated static let markLabels = ["Theme", "Show Tags in List", "Show Japanese Titles"]

    /// What the Search tab must keep: the title, the typed query and its focus, and the selected tab.
    struct SearchState {
        let app: XCUIApplication

        func require(at step: String, file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 10), "Search left at \(step).",
                          file: file, line: line)
            let field = app.searchFields.firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 10), "The search field left at \(step).",
                          file: file, line: line)
            let query = NativeVisualPolicyUITests.query
            XCTAssertEqual(field.value as? String, query, "The query changed at \(step).", file: file, line: line)
            XCTAssertEqual(field.value(forKey: "hasKeyboardFocus") as? Bool, true,
                           "The search field lost focus at \(step).", file: file, line: line)
            // An iPad's tab bar, floating at the top, hides while a search is active: the Search page stands for
            // its tab then.
            guard app.tabBars.firstMatch.exists || NativeVisualPolicyUITests.tab("Home", in: app).isHittable else {
                return
            }
            let tab = NativeVisualPolicyUITests.tab("Search", in: app)
            XCTAssertTrue(tab.exists && tab.isSelected, "The Search tab is not selected at \(step).",
                          file: file, line: line)
        }
    }

    /// Turns the device and waits until the window has turned with it.
    func turn(_ app: XCUIApplication, to orientation: UIDeviceOrientation) {
        if XCUIDevice.shared.orientation != orientation {
            XCUIDevice.shared.orientation = orientation
        }
        let turned = NSPredicate { _, _ in
            let frame = app.windows.firstMatch.frame
            return (frame.width > frame.height) == orientation.isLandscape
        }
        let wait = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: turned, object: nil)], timeout: 10)
        XCTAssertEqual(wait, .completed, "The window did not turn.")
    }

    /// Reads the mark of the switch or menu picker labelled `label`, scrolling it into view: a switch's 0 or 1, a
    /// picker's choice. Returns an empty string when there is none.
    func mark(_ label: String, in app: XCUIApplication) -> String {
        let predicate = NSPredicate(format: "label BEGINSWITH %@ AND elementType IN %@", label,
                                    [XCUIElement.ElementType.switch, .button].map(\.rawValue))
        let element = app.descendants(matching: .any).matching(predicate).firstMatch
        revealElement(element, in: app)
        guard element.exists else { return "" }
        // A menu picker's button carries its choice as a value, or after its label.
        let value = element.value as? String ?? ""
        return value.isEmpty
            ? String(element.label.dropFirst(label.count).drop(while: { $0 == "," || $0 == " " }))
            : value
    }

    /// Scrolls the page until `element` can be tapped: towards it when it is built, and otherwise back to the top
    /// first, then down the page, since a row far off is not in the hierarchy at all.
    func revealElement(_ element: XCUIElement, in app: XCUIApplication) {
        _ = element.waitForExistence(timeout: 5)
        for scroll in 0..<Self.maximumScrolls where !(element.exists && element.isHittable) {
            let list = app.descendants(matching: .any).matching(Self.listPredicate).firstMatch
            let host = list.exists ? list : app.windows.firstMatch
            let isAbove = element.exists ? element.frame.midY < host.frame.midY : scroll < Self.maximumScrolls / 2
            if isAbove {
                host.swipeDown(velocity: .slow)
            } else {
                host.swipeUp(velocity: .slow)
            }
        }
    }

    private static let maximumScrolls = 12

    /// Shows the reader's panel, which carries the toolbar, with a tap in the middle of the page.
    func showReaderPanel(in app: XCUIApplication) {
        let indicator = app.staticTexts.matching(identifier: "reading_page_indicator").firstMatch
        guard !indicator.waitForExistence(timeout: 2) else { return }
        app.requireElement("reading_pages").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(indicator.waitForExistence(timeout: 5), "The reader did not show its panel.")
    }

    /// Checks `item`, opened from `source`, is beside its source upright, turned and upright again. A dialog is
    /// opened before each turn and must stay up through it. A menu may close in a turn, so it is opened after each
    /// turn: a menu reopened right after a turn once left the app animating for minutes on an iPhone simulator.
    /// An open menu or popover covers its source, so the item is read open and the source after it closes.
    func checkAnchorThroughTurns(
        of item: XCUIElement, from source: XCUIElement, isDialog: Bool, named name: String, in app: XCUIApplication
    ) {
        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft, .portrait] {
            if !isDialog {
                turn(app, to: orientation)
            }
            source.tapWhenHittable(name)
            XCTAssertTrue(item.waitForExistence(timeout: 5), "\(name) did not open.")
            if isDialog {
                turn(app, to: orientation)
                XCTAssertTrue(item.waitForExistence(timeout: 5), "\(name) closed in a turn.")
            }
            let itemFrame = item.frame
            dismissPopover(in: app, until: item)
            XCTAssertTrue(source.waitForExistence(timeout: 5), "\(name)'s control left.")
            let side = orientation.isLandscape ? "landscape" : "portrait"
            if !(isDialog && UIDevice.current.userInterfaceIdiom == .phone) {
                // A phone shows a dialog as a sheet along the bottom edge, not beside its control.
                requireAnchored(itemFrame, to: source.frame, named: "\(name) in \(side)")
            }
        }
    }

    /// On iPad a dialog or menu is a popover beside its source, and a menu is beside it on a phone too.
    func requireAnchored(
        _ item: CGRect, to source: CGRect, named name: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let reach = source.insetBy(dx: -Self.anchorReach, dy: -Self.anchorReach)
        XCTAssertTrue(
            reach.intersects(item), "\(name) at \(item) left its source at \(source).", file: file, line: line
        )
    }

    /// How far a popover's nearest item may sit from its source: the arrow and the popover's margin.
    private static let anchorReach: CGFloat = 160

    /// Closes an open menu, popover or dialog without choosing anything: by its Cancel, or by a tap outside it,
    /// which an open menu or popover takes to close without passing it on. The tap goes to the half of the window
    /// the item is not in, away from the edges, where a turned phone's camera housing takes no taps.
    func dismissPopover(in app: XCUIApplication, until item: XCUIElement) {
        let cancel = app.buttons["Cancel"].firstMatch
        if cancel.exists, cancel.isHittable {
            cancel.tap()
        } else {
            let window = app.windows.firstMatch.frame
            let isInUpperHalf = item.exists && item.frame.midY < window.midY
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: isInUpperHalf ? 0.8 : 0.2)).tap()
        }
        XCTAssertTrue(item.waitForNonExistence(timeout: 5), "The popover did not close.")
    }

    /// Returns the page's search field, pulling the list down when its drawer is closed.
    func revealSearchField(in app: XCUIApplication) -> XCUIElement {
        let field = app.searchFields.firstMatch
        _ = field.waitForExistence(timeout: 10)
        for _ in 0..<Self.maximumPulls where !(field.exists && field.isHittable) {
            let list = app.descendants(matching: .any).matching(Self.listPredicate).firstMatch
            (list.exists ? list : app.windows.firstMatch).swipeDown(velocity: .slow)
        }
        return field
    }

    private static let maximumPulls = 3

    private static let listPredicate = NSPredicate(
        format: "elementType IN %@",
        [XCUIElement.ElementType.collectionView, .table, .scrollView].map(\.rawValue)
    )
}
