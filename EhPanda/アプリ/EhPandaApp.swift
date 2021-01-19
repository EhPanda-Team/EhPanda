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
    var preferredColorScheme: ColorScheme? {
        store.appState
            .settings.setting?
            .colorScheme ?? .none
    }
    
    var frontpageItem: some View {
        Label(
            title: { Text("ホーム") },
            icon: { Image(systemName: "house.fill") }
        )
    }
    var settingItem: some View {
        Label(
            title: { Text("設定") },
            icon: { Image(systemName: "gearshape.fill") }
        )
    }
    
    init() {
        configureKF()
    }
    
    var body: some Scene {
        WindowGroup {
            if setting?.showTabBar == true {
                NavigationView {
                    TabView {
                        Group {
                            HomeView()
                                .tabItem { frontpageItem }
                            SettingView()
                                .tabItem { settingItem }
                        }
                        .navigationBarHidden(true)
                        .navigationBarBackButtonHidden(true)
                    }
                }
                .environmentObject(store)
                .onOpenURL(perform: onOpenURL)
                .preferredColorScheme(preferredColorScheme)
            } else {
                HomeView()
                    .environmentObject(store)
                    .onOpenURL(perform: onOpenURL)
                    .preferredColorScheme(preferredColorScheme)
            }
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
