//
//  WebView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/27.
//

import WebKit
import SwiftUI

struct WebView: UIViewControllerRepresentable {
    private let url: URL
    private let loginDoneAction: (() -> Void)?

    init(url: URL, loginDoneAction: (() -> Void)? = nil) {
        self.url = url
        self.loginDoneAction = loginDoneAction
    }

    final class Coodinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private var parent: WebView

        init(parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard parent.url.absoluteString == Defaults.URL.webLogin.absoluteString, let webViewURL = webView.url,
                  let queryItems = URLComponents(url: webViewURL, resolvingAgainstBaseURL: false)?.queryItems,
                  queryItems.contains(where: { queryItem in
                      queryItem.name == Defaults.URL.Component.Key.code.rawValue
                      && queryItem.value == Defaults.URL.Component.Value.zeroOne.rawValue
                  })
            else { return }

            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                cookies.forEach { HTTPCookieStorage.shared.setCookie($0) }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.parent.loginDoneAction?()
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Logger.error(error)
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
