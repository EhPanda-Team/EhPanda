//
//  EhPandaApp.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI
import MetricKit
import Kingfisher

@main
struct EhPandaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var store = Store()
    
    var setting: Setting? {
        store.appState.settings.setting
    }
    var preferredColorScheme: ColorScheme? {
        setting?.colorScheme ?? .none
    }
    var accentColor: Color? {
        setting?.accentColor
    }
    
    init() {
        configureKF()
    }
    
    var body: some Scene {
        WindowGroup {
            Home()
                .environmentObject(store)
                .accentColor(accentColor)
                .onOpenURL(perform: onOpenURL)
                .preferredColorScheme(preferredColorScheme)
        }
    }
    
    func onOpenURL(_ url: URL) {
        let entry = url.absoluteString
        guard let range = entry.range(of: "//") else { return }
        let key = String(entry.suffix(from: range.upperBound))
        UserDefaults.standard.set(key, forKey: "entry")
    }
    
    func configureKF() {
        let config = KingfisherManager.shared.downloader.sessionConfiguration
        config.httpCookieStorage = HTTPCookieStorage.shared
        KingfisherManager.shared.downloader.sessionConfiguration = config
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        MXMetricManager.shared.add(self)
        return true
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        MXMetricManager.shared.remove(self)
    }
}

extension AppDelegate: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        payloads.forEach { payload in
            print(payload)
        }
    }
}
