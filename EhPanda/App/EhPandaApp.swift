//
//  EhPandaApp.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI
import Kingfisher
import SwiftyBeaver
import SDWebImageSwiftUI

@main
struct EhPandaApp: App {
    @StateObject private var store = Store()

    init() {
        configureLogging()
        configureWebImage()
        clearImageCachesIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            Home()
                .task(onStartTasks)
                .environmentObject(store)
                .accentColor(accentColor)
                .onOpenURL(perform: onOpenURL)
                .preferredColorScheme(preferredColorScheme)
        }
    }
}

private extension EhPandaApp {
    var setting: Setting? {
        store.appState.settings.setting
    }
    var accentColor: Color? {
        setting?.accentColor
    }
    var preferredColorScheme: ColorScheme? {
        setting?.colorScheme ?? .none
    }

    func onStartTasks() {
        DispatchQueue.main.async {
            store.dispatch(.initializeStates)
            store.dispatch(.fetchFavoriteNames)
            store.dispatch(.fetchUserInfo)
        }
    }
    func onOpenURL(url: URL) {
        switch url.host {
        case "debugMode":
            setDebugMode(with: url.pathComponents.last == "on")
        default:
            break
        }
    }

    func configureLogging() {
        var file = FileDestination()
        var console = ConsoleDestination()

        configure(file: &file)
        configure(console: &console)
        SwiftyBeaver.addDestination(file)
        SwiftyBeaver.addDestination(console)
    }
    func configure(file: inout FileDestination) {
        let dateFormat = "$Dyyyy-MM-dd HH:mm:ss.SSS$d"
        let messageFormat = "$C$L$c $N.$F:$l - $M"
        file.format = [dateFormat, messageFormat]
            .joined(separator: " ")
        file.logFileAmount = 5
        file.logFileURL = try? FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
               appropriateFor: nil, create: true
        ).appendingPathComponent("EhPanda.log")
    }
    func configure(console: inout ConsoleDestination) {
        #if DEBUG
        console.asynchronously = false
        #endif
        console.levelColor.verbose = "😪"
        console.levelColor.debug = "🐛"
        console.levelColor.info = "📖"
        console.levelColor.warning = "⚠️"
        console.levelColor.error = "‼️"
    }

    func configureWebImage() {
        let config = KingfisherManager.shared.downloader.sessionConfiguration
        config.httpCookieStorage = HTTPCookieStorage.shared
        KingfisherManager.shared.downloader.sessionConfiguration = config
    }
    func clearImageCachesIfNeeded() {
        let threshold = 200 * 1024 * 1024

        if SDImageCache.shared.totalDiskSize() > threshold {
            SDImageCache.shared.clearDisk()
        }
        KingfisherManager.shared.cache.calculateDiskStorageSize { result in
            if case .success(let size) = result {
                if size > threshold {
                    KingfisherManager.shared.cache.clearDiskCache()
                }
            }
        }
    }
}
