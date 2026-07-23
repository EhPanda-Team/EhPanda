import Network
import Synchronization
import XCTest

@MainActor
final class ShareSheetUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
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

        // Probed and pinned on iOS 26.5: the capsule toolbar exposes the address
        // bar as a *text field* identified `TabBarItemTitle` (it was a button in
        // earlier releases). Re-probe `safari.debugDescription` if this drifts.
        let addressField = safari.textFields["TabBarItemTitle"].firstMatch
        XCTAssertTrue(
            addressField.waitForExistence(timeout: 10),
            "Safari did not expose its TabBarItemTitle address field.\n\(safari.debugDescription)"
        )
        addressField.tap()

        XCTAssertTrue(
            safari.keyboards.firstMatch.waitForExistence(timeout: 10),
            "Safari did not raise the keyboard for its address field.\n\(safari.debugDescription)"
        )
        safari.typeText(sharePageServer.url.absoluteString + "\n")

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
