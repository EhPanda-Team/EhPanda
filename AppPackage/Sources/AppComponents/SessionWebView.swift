public import Foundation
public import SwiftUI
public import UIKit
import WebKit

/// A web page shown with the app's own sign-in for one site, and nothing else (research §5.2, A-5; P-11).
///
/// The comment report sheet opens the site's report form here, so the form is signed in exactly when the app is. Two
/// invariants this view exists to keep, and which must survive any edit:
///
/// - Its web view runs on a `WKWebsiteDataStore.nonPersistent()` store owned by the controller. Nothing the page sets
///   reaches WebKit's on-disk store, nothing outlives the sheet, and the app's logout needs nothing extra to clear it.
/// - It is given the cookies to start from (the caller reads them from the app's cookie store for the page's host) and
///   writes every one into that private store, awaited, **before** the page loads. It never reads or writes the
///   app's own cookie store: nothing the page does is copied back into the app.
///
/// The app's other web view (`WebView` in SettingFeature) uses WebKit's default persistent store, which the app never
/// writes and logout never clears, so it must not be used for a page that needs the app's session.
public struct SessionWebView: UIViewControllerRepresentable {
    private let url: URL
    private let cookies: [HTTPCookie]
    private let loadsPage: Bool

    /// - Parameters:
    ///   - url: The page to open.
    ///   - cookies: The session to open it with. An empty list opens the page signed out.
    ///   - loadsPage: `false` seeds the store but never loads the page; a stubbed UI-test launch passes it so a test
    ///     never reaches the live site.
    public init(url: URL, cookies: [HTTPCookie], loadsPage: Bool = true) {
        self.url = url
        self.cookies = cookies
        self.loadsPage = loadsPage
    }

    // `Self.Context` is spelled out because AppModels also vends a `Context` type.
    public func makeUIViewController(context: Self.Context) -> SessionWebViewController {
        SessionWebViewController(url: url, cookies: cookies, loadsPage: loadsPage)
    }

    public func updateUIViewController(_ uiViewController: SessionWebViewController, context: Self.Context) {}

    public static func dismantleUIViewController(
        _ uiViewController: SessionWebViewController, coordinator: Coordinator
    ) {
        uiViewController.cancelSeeding()
    }
}

/// Owns the session web view and its private data store.
public final class SessionWebViewController: UIViewController {
    private let url: URL
    private let cookies: [HTTPCookie]
    private let loadsPage: Bool
    private let webView: WKWebView
    /// Held directly: `webView.configuration` vends a fresh copy on every access.
    private let cookieStore: WKHTTPCookieStore
    private var seedTask: Task<Void, Never>?

    init(url: URL, cookies: [HTTPCookie], loadsPage: Bool) {
        self.url = url
        self.cookies = cookies
        self.loadsPage = loadsPage
        let configuration = Self.makeConfiguration()
        cookieStore = configuration.websiteDataStore.httpCookieStore
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
        webView.scrollView.topEdgeEffect.style = .soft
        webView.accessibilityIdentifier = "session_web_view"
        // The page's address, so a test can tell which page the sheet holds; never a cookie value.
        webView.accessibilityValue = url.absoluteString
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("SessionWebViewController is built in code, never from a nib or a storyboard.")
    }

    /// A configuration on a fresh non-persistent store: everything the page sets stays in memory and goes with the
    /// controller.
    static func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        return configuration
    }

    override public func loadView() {
        view = webView
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        let target = WebKitSessionTarget(webView: webView, cookieStore: cookieStore)
        seedTask = Task { [cookies, url, loadsPage] in
            await SessionWebViewSeeding.seedThenLoad(cookies: cookies, url: url, loadsPage: loadsPage, into: target)
        }
    }

    func cancelSeeding() {
        seedTask?.cancel()
        seedTask = nil
    }
}

/// Where the session is written and the page loaded: the web view's own store, or a recording stand-in in tests.
@MainActor
protocol SessionWebViewTarget {
    func setCookie(_ cookie: HTTPCookie) async
    func load(_ request: URLRequest)
}

enum SessionWebViewSeeding {
    /// Writes every cookie into the target's store, each awaited, and only then loads `url`, so the first request
    /// already carries the session. A cancelled seeding (the sheet went away) loads nothing.
    @MainActor
    static func seedThenLoad(
        cookies: [HTTPCookie], url: URL, loadsPage: Bool, into target: some SessionWebViewTarget
    ) async {
        for cookie in cookies {
            await target.setCookie(cookie)
        }
        guard loadsPage, !Task.isCancelled else { return }
        target.load(URLRequest(url: url))
    }
}

@MainActor
private struct WebKitSessionTarget: SessionWebViewTarget {
    let webView: WKWebView
    let cookieStore: WKHTTPCookieStore

    func setCookie(_ cookie: HTTPCookie) async {
        await cookieStore.setCookie(cookie)
    }

    func load(_ request: URLRequest) {
        webView.load(request)
    }
}
