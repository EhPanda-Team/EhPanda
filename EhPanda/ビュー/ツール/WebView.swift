//
//  WebView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/27.
//

import SwiftUI
import WebKit

struct WebView: UIViewControllerRepresentable {
    @EnvironmentObject var store: Store

    class Coodinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent : WebView

        init(_ parent: WebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("読み込み開始")
            
            guard let url = webView.url?.absoluteString else { return }
            
            if url.contains("CODE=01") {
                webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                    cookies.forEach {
                        HTTPCookieStorage.shared.setCookie($0)
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("読み込み完了")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print(error)
        }
    }
    
    func setupTimer() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { (timer) in
            if didLogin {
                store.dispatch(.toggleSettingViewSheetNil)
                store.dispatch(.fetchFrontpageItems)
                store.dispatch(.fetchFavoritesItems)
                timer.invalidate()
            }
        }
    }

    func makeCoordinator() -> WebView.Coodinator {
        return Coodinator(self)
    }

    func makeUIViewController(context: Context) -> EmbeddedWebviewController {
        let webViewController = EmbeddedWebviewController(coordinator: context.coordinator)
        webViewController.loadUrl(URL(string: Defaults.URL.login)!)
        
        setupTimer()

        return webViewController
    }

    func updateUIViewController(_ uiViewController: EmbeddedWebviewController, context: UIViewControllerRepresentableContext<WebView>) {

    }
}

class EmbeddedWebviewController: UIViewController {

    var webview: WKWebView

    public var delegate: WebView.Coordinator? = nil

    init(coordinator: WebView.Coordinator) {
        self.delegate = coordinator
        self.webview = WKWebView()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.webview = WKWebView()
        super.init(coder: coder)
    }

    public func loadUrl(_ url: URL) {
        let req = URLRequest(url: url)
        webview.load(req)
    }

    override func loadView() {
        self.webview.navigationDelegate = self.delegate
        self.webview.uiDelegate = self.delegate
        view = webview
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
