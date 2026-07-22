import AppModels
import OSLogExt
import SwiftUI
import WebKit

private let logger = Logger(category: .init(describing: ChallengeWebView.self))

/// A web view whose only job is to let a Cloudflare wall be solved and to report the proof it mints.
///
/// Where `WebView` watches the page URL for a completion marker, this wrapper watches its own cookie
/// store. The moment a `cf_clearance` cookie appears — whether the user tapped through an interactive
/// wall or the page passed with no interaction at all — it reads the exact `navigator.userAgent` of the
/// very view that earned the clearance and hands the pair upward through `onClearance`, exactly once.
///
/// Two invariants this wrapper exists to keep, and which must survive any edit:
///
/// - It writes nothing into `HTTPCookieStorage.shared`. The clearance is a flow-scoped value attached
///   as an explicit header to the retried login POST, never a cookie the rest of the app inherits.
/// - Its web view runs on a non-persistent website data store, so nothing the challenge run mints
///   reaches WebKit's on-disk cookie database and a relaunch provably starts clean.
///
/// It is also deliberately given no credentials: it clears the wall and nothing else.
struct ChallengeWebView: UIViewControllerRepresentable {
    private let url: URL
    private let onClearance: (CloudflareClearance) -> Void

    init(url: URL, onClearance: @escaping (CloudflareClearance) -> Void) {
        self.url = url
        self.onClearance = onClearance
    }

    // `Self.Context` is spelled out because AppModels also vends a `Context` type; the unqualified
    // name resolves to that one and silently breaks the conformance.
    func makeUIViewController(context: Self.Context) -> ChallengeWebViewController {
        ChallengeWebViewController(url: url, onClearance: onClearance)
    }

    func updateUIViewController(_ uiViewController: ChallengeWebViewController, context: Self.Context) {
        uiViewController.onClearance = onClearance
    }

    static func dismantleUIViewController(
        _ uiViewController: ChallengeWebViewController,
        coordinator: Coordinator
    ) {
        uiViewController.stopObservingCookieStore()
    }
}

/// Owns the challenge web view and observes its cookie store.
///
/// The controller is the observer itself: `WKHTTPCookieStore` explicitly does not retain the observers
/// it is handed, so pairing registration with an object the view hierarchy already keeps alive removes
/// a whole class of "the callback silently stopped firing" bug. Registration is undone in
/// `stopObservingCookieStore()`, which runs both when the pair has been captured and when SwiftUI
/// dismantles the representable.
final class ChallengeWebViewController: UIViewController, WKHTTPCookieStoreObserver {
    /// The cookie Cloudflare issues once one of its challenges has been passed.
    private static let clearanceCookieName = "cf_clearance"

    var onClearance: (CloudflareClearance) -> Void

    private let url: URL
    private let webView: WKWebView
    private var isObservingCookieStore = false
    /// Latches on the first fully captured pair, so a later cookie change cannot report a second one.
    private var hasReportedClearance = false

    private var cookieStore: WKHTTPCookieStore {
        webView.configuration.websiteDataStore.httpCookieStore
    }

    init(url: URL, onClearance: @escaping (CloudflareClearance) -> Void) {
        self.url = url
        self.onClearance = onClearance
        let configuration = WKWebViewConfiguration()
        // Everything this run mints, the clearance included, stays in memory: a non-persistent store
        // keeps it out of WebKit's on-disk cookie database, so there is nothing to clean up afterwards
        // and no relaunch can resurrect it.
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("ChallengeWebViewController is built in code, never from a nib or a storyboard.")
    }

    override func loadView() {
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        cookieStore.add(self)
        isObservingCookieStore = true
        logger.notice("Loading Cloudflare challenge page.")
        webView.load(URLRequest(url: url))
    }

    /// Unregisters from the cookie store. Idempotent, so the capture path and teardown can both call it.
    func stopObservingCookieStore() {
        guard isObservingCookieStore else { return }
        isObservingCookieStore = false
        cookieStore.remove(self)
    }

    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        guard !hasReportedClearance else { return }
        Task { await reportClearanceIfPresent(in: cookieStore) }
    }

    private func reportClearanceIfPresent(in cookieStore: WKHTTPCookieStore) async {
        guard !hasReportedClearance else { return }
        let clearanceCookie = await cookieStore.allCookies().first(where: { cookie in
            cookie.name == Self.clearanceCookieName && !cookie.value.isEmpty
        })
        guard let clearanceCookie else { return }

        // Cloudflare binds a clearance to the exact User-Agent that earned it, so the string is read
        // from this very web view, here, before anything can dismiss the surface. A reconstructed or
        // defaulted UA would be rejected as a fresh challenge.
        let userAgent: String
        do {
            let evaluated = try await webView.evaluateJavaScript("navigator.userAgent")
            guard let string = evaluated as? String, !string.isEmpty else { return }
            userAgent = string
        } catch {
            // The latch stays open on purpose: half a pair is worthless, so the next cookie change
            // gets to try the read again rather than reporting a clearance with no UA to bind it.
            logger.error("Failed to read the challenge web view's User-Agent. \(error, privacy: .public)")
            return
        }

        hasReportedClearance = true
        stopObservingCookieStore()
        logger.notice("Captured Cloudflare clearance.")
        onClearance(.init(cookieValue: clearanceCookie.value, userAgent: userAgent))
    }
}
