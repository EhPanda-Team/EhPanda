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
        XCTAssertTrue(
            bar.staticTexts[title].waitUntilHittable(timeout: 10), "\(title) is off screen at \(size).",
            file: file, line: line
        )
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
