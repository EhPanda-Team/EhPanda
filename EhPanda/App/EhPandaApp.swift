//
//  EhPandaApp.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/10/28.
//

import SwiftUI
import Kingfisher
import SwiftyBeaver

@main
struct EhPandaApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
//            Home()
            ContentView(gid: "1969713")
                .task(onStartTasks)
                .environmentObject(store)
                .accentColor(accentColor)
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
        dispatchMainSync {
            syncGalleryHost()
            configureDomainFronting()
        }
        DispatchQueue.main.async {
            fetchAccountInfoIfNeeded()
        }
        configureLogging()
        configureWebImage()
        configureIgnoreOffensive()
        clearImageCachesIfNeeded()
    }

    func syncGalleryHost() {
        setGalleryHost(with: setting.galleryHost)
    }
    func fetchAccountInfoIfNeeded() {
        guard didLogin else { return }

        store.dispatch(.verifyProfile)
        store.dispatch(.fetchUserInfo)
        store.dispatch(.fetchFavoriteNames)
    }
    func clearImageCachesIfNeeded() {
        let threshold = 200 * 1024 * 1024

        KingfisherManager.shared.cache.calculateDiskStorageSize { result in
            if case .success(let size) = result, size > threshold {
                KingfisherManager.shared.cache.clearDiskCache()
            }
        }
    }
}

// MARK: Configuration
private extension EhPandaApp {
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
        config.httpCookieStorage = HTTPCookieStorage.shared
        KingfisherManager.shared.downloader.sessionConfiguration = config
    }
    func configureDomainFronting() {
        if setting.bypassSNIFiltering {
            URLProtocol.registerClass(DFURLProtocol.self)
        }
    }
    func configureIgnoreOffensive() {
        setCookie(url: Defaults.URL.ehentai.safeURL(), key: "nw", value: "1")
        setCookie(url: Defaults.URL.exhentai.safeURL(), key: "nw", value: "1")
    }
}
