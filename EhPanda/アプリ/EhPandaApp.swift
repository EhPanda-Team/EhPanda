//
//  EhPandaApp.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI
import Kingfisher
import Introspect

@main
struct EhPandaApp: App {
    @StateObject var store = Store()
    
    var preferredColorScheme: ColorScheme? {
        store.appState
            .settings.setting?
            .colorScheme ?? .none
    }
    
    init() {
        configureKF()
    }
    
    var body: some Scene {
        WindowGroup {
            Home()
                .environmentObject(store)
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
