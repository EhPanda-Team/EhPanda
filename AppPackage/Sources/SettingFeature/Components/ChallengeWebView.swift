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
final class ChallengeWebViewController: UIViewController, WKHTTPCookieStoreObserver, WKNavigationDelegate {
    /// The cookie Cloudflare issues once one of its challenges has been passed.
    private static let clearanceCookieName = "cf_clearance"

    var onClearance: (CloudflareClearance) -> Void

    private let url: URL
    private let webView: WKWebView
    /// Held directly rather than reached through `webView.configuration`, which vends a fresh copy on
    /// every access — registering an observer against one copy and unregistering against another is a
    /// silent leak, and the identity of the store matters for both.
    private let cookieStore: WKHTTPCookieStore
    private var isObservingCookieStore = false
    /// Latches on the first fully captured pair, so a later cookie change cannot report a second one.
    private var hasReportedClearance = false
    private var pollTask: Task<Void, Never>?
    /// Suppresses the "still nothing" line unless the jar's size actually moved, so a poll running
    /// twice a second cannot bury the interesting entries.
    private var lastLoggedJarEntryCount: Int?

    /// The poll's cadence and its ceiling — 500ms apart, up to five minutes.
    ///
    /// The ceiling is a leak guard, not a deadline: teardown cancels the task, so it only matters if
    /// that ever fails to run. It is set well past how long any wall takes to clear so that a user who
    /// walks away mid-challenge and comes back still gets captured.
    private static let clearancePollInterval = Duration.milliseconds(500)
    private static let maxClearancePolls = 600

    init(url: URL, onClearance: @escaping (CloudflareClearance) -> Void) {
        self.url = url
        self.onClearance = onClearance
        let configuration = WKWebViewConfiguration()
        // Everything this run mints, the clearance included, stays in memory: a non-persistent store
        // keeps it out of WebKit's on-disk cookie database, so there is nothing to clean up afterwards
        // and no relaunch can resurrect it.
        let dataStore = WKWebsiteDataStore.nonPersistent()
        configuration.websiteDataStore = dataStore
        cookieStore = dataStore.httpCookieStore
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
        webView.navigationDelegate = self
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
        startPollingForClearance()
    }

    /// Polls the jar until the clearance lands. This is the guarantee; the two event triggers below
    /// are only nudges that keep the common case instant.
    ///
    /// Neither trigger is dependable on its own, and both were observed failing against the live wall:
    /// `cookiesDidChange` never fired at all for cookies the page set via `Set-Cookie`, and the
    /// `didFinish` check read an empty jar because WebKit's network process had not yet propagated the
    /// entries into the store. Relying on either alone strands the flow in exactly the way that looks
    /// like a hang — wall passed, page redirected, surface still sitting there. Polling makes capture
    /// a property of the clearance existing rather than of a notification arriving.
    private func startPollingForClearance() {
        pollTask = Task { [weak self] in
            for _ in 0 ..< Self.maxClearancePolls {
                do {
                    try await Task.sleep(for: Self.clearancePollInterval)
                } catch {
                    // Cancellation is the only failure `sleep` reports, and it is the teardown path:
                    // the pair was captured, or the surface went away. Either way there is no more
                    // polling to do.
                    return
                }
                guard let self, !self.hasReportedClearance else { return }
                await self.reportClearanceIfPresent(in: self.cookieStore)
            }
        }
    }

    /// Stops both the observer and the poll. Idempotent, so the capture path and teardown can both
    /// call it.
    func stopObservingCookieStore() {
        pollTask?.cancel()
        pollTask = nil
        guard isObservingCookieStore else { return }
        isObservingCookieStore = false
        cookieStore.remove(self)
    }

    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        guard !hasReportedClearance else { return }
        logger.notice("Challenge jar changed; checking for a clearance.")
        Task { await reportClearanceIfPresent(in: cookieStore) }
    }

    /// The second, and more dependable, capture trigger.
    ///
    /// The cookie-store observer is the fast path, not a guarantee: WebKit does not reliably notify
    /// for cookies a *page* sets via `Set-Cookie`, and a notification that lands mid-navigation can
    /// fail the User-Agent read below and be dropped entirely. A finished navigation is the moment
    /// the clearance is certain to be in the jar with JavaScript ready to answer — and passing a wall
    /// always ends in one, since Cloudflare redirects back to the original URL. This is the same
    /// signal the sibling `WebView` already relies on for its own cookie handoff.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !hasReportedClearance else { return }
        logger.notice("Challenge navigation finished; checking for a clearance.")
        Task { await reportClearanceIfPresent(in: cookieStore) }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        logger.error("Challenge navigation failed. \(error, privacy: .public)")
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        logger.error("Challenge provisional navigation failed. \(error, privacy: .public)")
    }

    private func reportClearanceIfPresent(in cookieStore: WKHTTPCookieStore) async {
        guard !hasReportedClearance else { return }
        let jar = await cookieStore.allCookies()
        let clearanceCookie = jar.first(where: { candidate in
            candidate.name == Self.clearanceCookieName && !candidate.value.isEmpty
        })
        guard let clearanceCookie else {
            // Named entries are never logged — only how many there are, which is enough to tell
            // "the jar is empty" apart from "the jar filled but carries no clearance".
            let jarEntryCount = jar.count
            if lastLoggedJarEntryCount != jarEntryCount {
                lastLoggedJarEntryCount = jarEntryCount
                logger.notice("No clearance in the challenge jar yet. Entries: \(jarEntryCount, privacy: .public)")
            }
            return
        }

        // Cloudflare binds a clearance to the exact User-Agent that earned it, so the string is read
        // from this very web view, here, before anything can dismiss the surface. A reconstructed or
        // defaulted UA would be rejected as a fresh challenge.
        let userAgent: String
        do {
            let evaluated = try await webView.evaluateJavaScript("navigator.userAgent")
            guard let string = evaluated as? String, !string.isEmpty else {
                logger.error("The challenge web view returned an empty User-Agent.")
                return
            }
            userAgent = string
        } catch {
            // The latch stays open on purpose: half a pair is worthless, so a later trigger gets to
            // try the read again rather than reporting a clearance with no UA to bind it. That is
            // only safe because `didFinish` above guarantees another attempt — relying on the next
            // cookie change alone could strand the flow, since passing a wall may mint no further
            // change and the surface would then sit open forever on the redirected page.
            logger.error("Failed to read the challenge web view's User-Agent. \(error, privacy: .public)")
            return
        }

        // The entry guard above is only a fast path. Main-actor isolation serialises the *steps* of
        // this method, not the method itself: the two `await`s above are suspension points where a
        // second invocation — the poll, `cookiesDidChange` and `didFinish` all call in — can pass the
        // entry guard and run to here as well. Latching after the last suspension is what actually
        // makes the "exactly once" in this file's doc comment true.
        guard !hasReportedClearance else { return }
        hasReportedClearance = true
        stopObservingCookieStore()
        logger.notice("Captured Cloudflare clearance.")
        onClearance(.init(cookieValue: clearanceCookie.value, userAgent: userAgent))
    }
}
