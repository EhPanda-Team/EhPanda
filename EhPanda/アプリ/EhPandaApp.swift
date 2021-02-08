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
                .onAppear(perform: onAppear)
                .onOpenURL(perform: onOpenURL)
                .preferredColorScheme(preferredColorScheme)
        }
    }
    
    func onAppear() {
        sendMetrics()
    }
    func onOpenURL(_ url: URL) {
        setEntry(url.host)
    }
    
    func configureKF() {
        // クッキーをKingfisherに
        let config = KingfisherManager.shared.downloader.sessionConfiguration
        config.httpCookieStorage = HTTPCookieStorage.shared
        KingfisherManager.shared.downloader.sessionConfiguration = config
        
        // ディスクキャッシュサイズ上限
        KingfisherManager.shared.cache.diskStorage.config.sizeLimit = 200 * 1024 * 1024
    }
    
    func sendMetrics() {
        if let metricsData = currentMetricsData {
            store.dispatch(.sendMetrics(metrics: metricsData))
        }
    }
}

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions:
            [UIApplication.LaunchOptionsKey : Any]? = nil
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
        var data = Data()
        payloads.forEach { payload in
            data.append(payload.jsonRepresentation())
        }
        
        if !data.isEmpty {
            saveMetricsData(data)
        }
    }
}
