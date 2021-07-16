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
        configureDomainFronting()
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
    var setting: Setting {
        store.appState.settings.setting
    }
    var accentColor: Color {
        setting.accentColor
    }
    var preferredColorScheme: ColorScheme? {
        setting.colorScheme
    }

    func onStartTasks() {
        DispatchQueue.main.async {
            syncGalleryHost()
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

    func syncGalleryHost() {
        setGalleryHost(with: setting.galleryHost)
    }
    func configureLogging() {
        var file = FileDestination()
        var console = ConsoleDestination()
        let format = [
            "$Dyyyy-MM-dd HH:mm:ss.SSS$d",
            "$C$L$c $N.$F:$l - $M $X"
        ].joined(separator: " ")

        file.format = format
        console.format = format
        configure(file: &file)
        configure(console: &console)

        SwiftyBeaver.addDestination(file)
        #if DEBUG
        SwiftyBeaver.addDestination(console)
        #endif
    }
    func configure(file: inout FileDestination) {
        file.calendar = Calendar(identifier: .gregorian)
        file.logFileAmount = 10
        file.logFileURL = logsDirectoryURL?
            .appendingPathComponent(
                Defaults.FilePath.ehpandaLog
            )
    }
    func configure(console: inout ConsoleDestination) {
        console.calendar = Calendar(identifier: .gregorian)
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
        config.protocolClasses = [DFURLProtocol.self]
        config.httpCookieStorage = HTTPCookieStorage.shared
        KingfisherManager.shared.downloader.sessionConfiguration = config
    }
    func configureDomainFronting() {
        DFManager.shared.dfState = .activated
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
