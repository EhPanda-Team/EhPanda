import AppComponents
import ComposableArchitecture
import CookieClient
import Foundation
import SwiftUI

/// The gallery's report page on its site, opened from a comment's Report (D-10, UI-SPEC C-4; research §5.2, A-5).
///
/// The page opens in `SessionWebView`, a private web view seeded with the app's cookies for the report page's host
/// only, so the site's form is signed in exactly when the app is and no other site's cookies reach it (T-18-19). It is
/// never shown in the persistent-store `WebView` or the system browser (P-11). Large detent, a close button, no title.
struct ReportPageSheet: View {
    @Dependency(\.cookieClient) private var cookieClient

    let url: URL

    var body: some View {
        let input = Self.sessionInput(for: url, cookieClient: cookieClient)
        NavigationStack {
            SessionWebView(
                url: input.url, cookies: input.cookies, loadsPage: Self.loadsPage
            )
                .ignoresSafeArea(edges: .bottom)
                .scrollEdgeEffectStyle(.soft, for: .top)
                .toolbar {
                    SheetCloseToolbar()
                }
                .toolbarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .privacyMask()
    }

    /// What the sheet's web view opens: the report page and the app's session for its host, exactly as
    /// `CookieClient.sessionCookies(for:)` returns it.
    static func sessionInput(for url: URL, cookieClient: CookieClient) -> SessionInput {
        SessionInput(url: url, cookies: cookieClient.sessionCookies(for: url))
    }

    struct SessionInput {
        let url: URL
        let cookies: [HTTPCookie]
    }

    /// A stubbed UI-test launch never loads the live site: the sheet opens, seeded, on a blank page.
    private static var loadsPage: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["EHPANDA_UITEST_STUB_NETWORK"] != "1"
        #else
        true
        #endif
    }
}
