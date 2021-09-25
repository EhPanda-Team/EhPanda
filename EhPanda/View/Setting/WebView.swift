//
//  WebView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/27.
//

import WebKit
import SwiftUI
import SwiftyBeaver

struct WebView: UIViewControllerRepresentable {
    static let loginURLString
        = "https://forums.e-hentai.org/"
        + "index.php?act=Login"

    @EnvironmentObject private var store: Store
    private let url: URL

    init(url: URL) {
        self.url = url
    }

    final class Coodinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private var parent: WebView

        init(parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard parent.url.absoluteString == WebView.loginURLString,
                  webView.url?.absoluteString.contains("CODE=01") == true
            else { return }

            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                cookies.forEach { HTTPCookieStorage.shared.setCookie($0) }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard didLogin else { return }
                let store = self?.parent.store
                store?.dispatch(.toggleSettingViewSheet(state: nil))
                store?.dispatch(.fetchFrontpageItems())
                store?.dispatch(.verifyEhProfile)
                store?.dispatch(.fetchUserInfo)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            SwiftyBeaver.error(error)
        }
    }

    func makeCoordinator() -> WebView.Coodinator {
        Coodinator(parent: self)
    }

    func makeUIViewController(context: Context) -> EmbeddedWebviewController {
        let webViewController = EmbeddedWebviewController(coordinator: context.coordinator)
        webViewController.loadUrl(url)

        return webViewController
    }

    func updateUIViewController(
        _ uiViewController: EmbeddedWebviewController,
        context: UIViewControllerRepresentableContext<WebView>
    ) {}
}

final class EmbeddedWebviewController: UIViewController {
    private var webview: WKWebView

    private weak var delegate: WebView.Coordinator?

    init(coordinator: WebView.Coordinator) {
        delegate = coordinator
        webview = WKWebView()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        webview = WKWebView()
        super.init(coder: coder)
    }

    func loadUrl(_ url: URL) {
        let request = URLRequest(url: url)
        webview.load(request)
    }

    override func loadView() {
        webview.navigationDelegate = delegate
        webview.uiDelegate = delegate
        view = webview
    }
}
