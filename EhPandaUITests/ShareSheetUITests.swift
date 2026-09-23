import Network
import Synchronization
import XCTest

@MainActor
final class ShareSheetUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Outbound sharing from Detail is independent of the inbound Safari extension handoff.
    func testDetailOverflowDisabledActionsAndSharePresentation() throws {
        let app = XCUIApplication()
        let galleryURL = try XCTUnwrap(UITestConstants.galleryURL(scheme: "ehpanda"))
        try app.openCold(galleryURL)
        app.requireForeground()
        app.requireElement("detail_view", matching: .scrollView)
        XCTAssertTrue(
            app.buttons[UITestConstants.primaryMarkerTitle].waitForExistence(timeout: 15),
            "The fixture gallery detail did not render."
        )

        app.buttons.matching(identifier: "OverflowBarButtonItem")
            .firstMatch.tapWhenHittable("Detail More")

        let archives = app.buttons["Archives"].firstMatch
        XCTAssertTrue(archives.waitForExistence(timeout: 5), "More did not expose Archives.")
        XCTAssertFalse(archives.isEnabled, "Archives must remain disabled while logged out.")

        let torrents = app.buttons["Torrents (1)"].firstMatch
        XCTAssertTrue(torrents.waitForExistence(timeout: 5), "More did not expose Torrents (1).")
        XCTAssertTrue(torrents.isEnabled, "Torrents (1) must remain enabled.")

        let share = app.buttons["Share"].firstMatch
        XCTAssertTrue(share.waitForExistence(timeout: 5), "More did not expose Share.")
        XCTAssertTrue(share.isEnabled, "Share must remain enabled.")
        share.tapWhenHittable("Share")

        XCTAssertTrue(
            app.collectionViews["activityCollectionView"].waitForExistence(timeout: 10),
            "Share did not present the system activity collection view."
        )
        app.buttons["header.closeButton"].firstMatch.tapWhenHittable("Activity Close")
        app.requireElement("detail_view", matching: .scrollView)
    }

    func testShareSheetHandoffLandsOnDetail() throws {
        let app = XCUIApplication()
        try app.launchStubbed()
        app.requireForeground()

        let galleryURL = try XCTUnwrap(UITestConstants.galleryURL(scheme: "https"))
        let sharePageServer = try LocalSharePageServer(galleryURL: galleryURL)
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()

        let tabOverviewDoneButton = safari.buttons["DoneButton"]
        if tabOverviewDoneButton.waitForExistence(timeout: 2) {
            tabOverviewDoneButton.tap()
        }

        // The start page can carry an onboarding card whose dimming overlay sits
        // over the capsule toolbar; dismiss it before reaching for the address bar.
        let onboardingCloseButton = safari.buttons["close"].firstMatch
        if onboardingCloseButton.waitForExistence(timeout: 3) {
            onboardingCloseButton.tap()
        }

        // Safari's address field is a *text field* whose identifier depends on the
        // layout, so both pinned identifiers are accepted:
        // - iPhone (probed on iOS 26.5): the capsule toolbar exposes it as
        //   `TabBarItemTitle` (it was a button in earlier releases).
        // - iPad (probed on iPadOS 26.5 and 27.0, regular width): the top tab bar
        //   has no `TabBarItemTitle`. It nests the field twice: an outer text field
        //   identified `SearchFieldItemView?isActive=true&UUID=…` (a per-tab UUID,
        //   so it cannot be pinned) wraps the editable `TabBarItemTitleContainer`
        //   ("Address", placeholder "Search or enter website"). The inner one is
        //   the stable identifier.
        // Re-probe `safari.debugDescription` if either drifts.
        let addressField = safari.textFields
            .matching(NSPredicate(format: "identifier IN %@", ["TabBarItemTitle", "TabBarItemTitleContainer"]))
            .firstMatch
        XCTAssertTrue(
            addressField.waitForExistence(timeout: 10),
            "Safari did not expose its address field.\n\(safari.debugDescription)"
        )
        addressField.tap()

        let focusedField = focusedAddressField(in: safari)
        focusedField.typeText(sharePageServer.url.absoluteString + "\n")

        // Safari greets a fresh simulator with a feature tip popover that covers
        // the page; it has to go before the link is long-pressable.
        let tipCloseButton = safari.buttons["xmark.circle.fill"].firstMatch
        if tipCloseButton.waitForExistence(timeout: 3) {
            tipCloseButton.tap()
        }

        let galleryLink = safari.links[LocalSharePageServer.linkLabel]
        XCTAssertTrue(
            galleryLink.waitForExistence(timeout: 10),
            "Safari did not render the local gallery-link fixture.\n\(safari.debugDescription)"
        )
        galleryLink.press(forDuration: 1)

        // The link menu renders a page preview above its actions, which pushes the
        // lower actions past the bottom of the screen; collapsing it lifts the whole
        // menu into hittable space (and stops Safari rendering the fetched preview).
        let hidePreviewAction = safari.staticTexts["Hide preview"].firstMatch
        if hidePreviewAction.waitForExistence(timeout: 5) {
            hidePreviewAction.tap()
        }

        // Matched by prefix: the action is titled "Share…" with a horizontal
        // ellipsis, which an exact-label lookup misses.
        let shareMenuItem = safari.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Share"))
            .firstMatch
        XCTAssertTrue(
            shareMenuItem.waitForExistence(timeout: 5),
            "Safari's link menu did not expose Share.\n\(safari.debugDescription)"
        )
        shareMenuItem.tap()

        let ehPandaActivity = safari.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "EhPanda"))
            .firstMatch
        if ehPandaActivity.waitForExistence(timeout: 5) == false {
            let activityList = safari.collectionViews.firstMatch
            if activityList.exists {
                activityList.swipeLeft()
            }
        }
        if ehPandaActivity.waitForExistence(timeout: 5) == false {
            safari.swipeUp()
        }
        XCTAssertTrue(
            ehPandaActivity.waitForExistence(timeout: 5),
            "The activity view did not expose the EhPanda extension.\n\(safari.debugDescription)"
        )
        ehPandaActivity.tap()

        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 20),
            """
            The share hand-off did not foreground EhPanda (state \(app.state.rawValue)).
            \(safari.debugDescription)
            """
        )
        app.requireElement("detail_view", matching: .scrollView, timeout: 15)
        XCTAssertTrue(
            app.buttons[UITestConstants.primaryMarkerTitle]
                .waitForExistence(timeout: 10),
            "The share handoff did not render the hermetic gallery marker."
        )
    }

    /// Returns the Safari text field that holds keyboard focus after the address field was tapped.
    ///
    /// The URL is typed into the focused element itself, never into the tapped container or the
    /// whole app, and success is judged by focus rather than by a visible software keyboard: the
    /// keyboard can be missing while focus is correct (a connected hardware keyboard hides it), and
    /// it can be up while focus sits elsewhere. Both happened on iPadOS 27.0 in 16-24
    /// (`share-fix/attempt1/share-ipad2.xcresult`), which is why the old "keyboard exists" check is gone.
    ///
    /// On iPad, Safari has two states, both read from its hierarchy dumps:
    /// - A fresh empty tab: the tap on the tab bar's `TabBarItemTitleContainer` focuses that field
    ///   directly.
    /// - A restored tab with a loaded page (`TabDocument?…IsPageLoaded=true`, e.g. the previous
    ///   run's page): the tap does not focus the tab bar's field. It opens Safari's address editor
    ///   instead, a separate overlay (615 × 720 pt on the 820-pt iPad) whose own text field is
    ///   also identified `TabBarItemTitleContainer` ("Address", with the page's host as its value,
    ///   frame (124.5, 41, 575, 44)). The tab bar's inner field leaves the hierarchy while the
    ///   editor is open. The dump showed the editor open with neither a keyboard nor a focused
    ///   element.
    ///
    /// So, when no field takes focus after the first tap, the editor's field is the only
    /// `TabBarItemTitleContainer` left, and it is tapped once, because that is the element the
    /// editor expects to be focused. No other element is re-tapped. If focus still never arrives,
    /// the test fails with the focus query and the full hierarchy.
    private func focusedAddressField(in safari: XCUIApplication) -> XCUIElement {
        let focusedField = safari.textFields
            .matching(NSPredicate(format: "hasKeyboardFocus == true"))
            .firstMatch
        if focusedField.waitForExistence(timeout: 10) {
            return focusedField
        }

        let editorFields = safari.textFields.matching(identifier: "TabBarItemTitleContainer")
        XCTAssertEqual(
            editorFields.count,
            1,
            "Safari's address editor did not expose exactly one field to focus.\n\(safari.debugDescription)"
        )
        editorFields.firstMatch.tap()

        XCTAssertTrue(
            focusedField.waitForExistence(timeout: 10),
            """
            No Safari text field took keyboard focus after tapping the address editor's field.
            Focused-element query: \(focusedField.debugDescription)
            \(safari.debugDescription)
            """
        )
        return focusedField
    }
}

private final class LocalSharePageServer {
    static let linkLabel = "EhPanda Gallery"

    let url: URL

    private let listener: NWListener

    init(galleryURL: URL) throws {
        let listener = try NWListener(using: .tcp, on: .any)
        let readiness = Mutex<Result<Void, Error>?>(nil)
        let readinessSignal = DispatchSemaphore(value: 0)

        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                readiness.withLock({ $0 = .success(()) })
                readinessSignal.signal()
            case .failed(let error):
                readiness.withLock({ $0 = .failure(error) })
                readinessSignal.signal()
            default:
                break
            }
        }

        let response = Self.response(galleryURL: galleryURL)
        listener.newConnectionHandler = { connection in
            connection.start(queue: .global(qos: .userInitiated))
            connection.receive(
                minimumIncompleteLength: 1,
                maximumLength: 4_096
            ) { _, _, _, _ in
                connection.send(
                    content: response,
                    contentContext: .finalMessage,
                    isComplete: true,
                    completion: .contentProcessed({ _ in connection.cancel() })
                )
            }
        }
        listener.start(queue: .global(qos: .userInitiated))

        guard readinessSignal.wait(timeout: .now() + 5) == .success else {
            listener.cancel()
            throw LocalSharePageServerError.startTimedOut
        }
        if let readinessResult = readiness.withLock({ $0 }) {
            try readinessResult.get()
        }
        guard let port = listener.port,
              let url = URL(string: "http://127.0.0.1:\(port.rawValue)/")
        else {
            listener.cancel()
            throw LocalSharePageServerError.missingURL
        }

        self.listener = listener
        self.url = url
    }

    deinit {
        listener.cancel()
    }

    private static func response(galleryURL: URL) -> Data {
        let html = """
        <!doctype html>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <a href="\(galleryURL.absoluteString)">\(linkLabel)</a>
        """
        let htmlData = Data(html.utf8)
        // CRLF-joined explicitly: a multi-line literal would drop the terminating
        // newline of the blank header-separator line and Safari would reject the
        // response with "cannot parse response".
        let headers = [
            "HTTP/1.1 200 OK",
            "Content-Type: text/html; charset=utf-8",
            "Content-Length: \(htmlData.count)",
            "Connection: close"
        ].joined(separator: "\r\n") + "\r\n\r\n"
        var response = Data(headers.utf8)
        response.append(htmlData)
        return response
    }
}

private enum LocalSharePageServerError: Error {
    case missingURL
    case startTimedOut
}
