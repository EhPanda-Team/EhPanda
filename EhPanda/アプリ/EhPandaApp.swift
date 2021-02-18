//
//  EhPandaApp.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI
import Kingfisher

@main
struct EhPandaApp: App {
    @StateObject var store = Store()
    
    var setting: Setting? {
        store.appState.settings.setting
    }
    var accentColor: Color? {
        setting?.accentColor
    }
    var preferredColorScheme: ColorScheme? {
        setting?.colorScheme ?? .none
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
}
