//
//  WebView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/27.
//

import SwiftUI
import WebKit

struct WebView: UIViewControllerRepresentable {
    @EnvironmentObject private var store: Store
    private let webviewType: WebViewType

    init(type: WebViewType) {
        webviewType = type
    }

    final class Coodinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {

        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if parent.webviewType == .ehLogin {
                guard let url = webView.url?.absoluteString else { return }

                if url.contains("CODE=01") {
                    webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                        cookies.forEach {
                            HTTPCookieStorage.shared.setCookie($0)
                        }
                    }

                    Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
                        if didLogin {
                            let store = self?.parent.store
                            store?.dispatch(.toggleSettingViewSheetNil)
                            store?.dispatch(.fetchFrontpageItems)

                            if store?.appState.settings.user == nil {
                                store?.dispatch(.initiateUser)
                            }
                            if let uid = store?.appState.settings.user?.apiuid, !uid.isEmpty {
                                store?.dispatch(.fetchUserInfo(uid: uid))
                            }
                        }
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print(error)
        }
    }

    func makeCoordinator() -> WebView.Coodinator {
        Coodinator(self)
    }

    func makeUIViewController(context: Context) -> EmbeddedWebviewController {
        let webViewController = EmbeddedWebviewController(coordinator: context.coordinator)
        webViewController.loadUrl(webviewType.url.safeURL())

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
        self.delegate = coordinator
        self.webview = WKWebView()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.webview = WKWebView()
        super.init(coder: coder)
    }

    func loadUrl(_ url: URL) {
        let req = URLRequest(url: url)
        webview.load(req)
    }

    override func loadView() {
        self.webview.navigationDelegate = self.delegate
        self.webview.uiDelegate = self.delegate
        view = webview
    }
}

enum WebViewType {
    case ehLogin
    case ehConfig
    case ehMyTags
}

extension WebViewType {
    var url: String {
        switch self {
        case .ehLogin:
            return Defaults.URL.login
        case .ehConfig:
            return Defaults.URL.ehConfig()
        case .ehMyTags:
            return Defaults.URL.ehMyTags()
        }
    }
}
