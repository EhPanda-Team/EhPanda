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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            Home()
                .accentColor(accentColor)
                .environmentObject(store)
                .onAppear(perform: onStartTasks)
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
}

// MARK: Tasks
private extension EhPandaApp {
    func onStartTasks() {
        dispatchMainSync {
            syncGalleryHost()
            configureWebImage()
            configureDomainFronting()
        }
        addTouchHandler()
        configureLogging()
        fetchTagTranslator()
        fetchIgneousIfNeeded()
        configureIgnoreOffensive()
        fetchAccountInfoIfNeeded()
    }

    func syncGalleryHost() {
        setGalleryHost(with: setting.galleryHost)
    }
    func fetchTagTranslator() {
        store.dispatch(.fetchTagTranslator)
    }
    func fetchAccountInfoIfNeeded() {
        guard didLogin else { return }

        store.dispatch(.fetchUserInfo)
        store.dispatch(.verifyEhProfile)
        store.dispatch(.fetchFavoriteNames)
    }
    func fetchIgneousIfNeeded() {
        guard setting.bypassesSNIFiltering,
              !getCookieValue(
                url: Defaults.URL.exhentai.safeURL(),
                key: Defaults.Cookie.ipbMemberId
              ).rawValue.isEmpty,
              !getCookieValue(
                url: Defaults.URL.exhentai.safeURL(),
                key: Defaults.Cookie.ipbPassHash
              ).rawValue.isEmpty,
              getCookieValue(
                url: Defaults.URL.exhentai.safeURL(),
                key: Defaults.Cookie.igneous
              ).rawValue.isEmpty
        else { return }

        store.dispatch(.fetchIgneous)
    }
}

// MARK: Configuration
private extension EhPandaApp {
    func addTouchHandler() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let tapGesture = UITapGestureRecognizer(
                target: self, action: nil
            )
            tapGesture.delegate = TouchHandler.shared
            keyWindow?.addGestureRecognizer(tapGesture)
        }
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
        guard !isUnitTesting else { return }
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
        KingfisherManager.configure(
            bypassesSNIFiltering: setting
                .bypassesSNIFiltering
        )
    }
    func configureDomainFronting() {
        if setting.bypassesSNIFiltering {
            URLProtocol.registerClass(DFURLProtocol.self)
        }
    }
    func configureIgnoreOffensive() {
        setCookie(url: Defaults.URL.ehentai.safeURL(), key: "nw", value: "1")
        setCookie(url: Defaults.URL.exhentai.safeURL(), key: "nw", value: "1")
    }
}

// MARK: AppDelegate
class AppDelegate: UIResponder, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask =
        isPad ? .all : [.portrait, .portraitUpsideDown]

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask { AppDelegate.orientationLock }
}

final class TouchHandler: NSObject, UIGestureRecognizerDelegate {
    static let shared = TouchHandler()
    var currentPoint: CGPoint?

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        currentPoint = touch.location(in: touch.window)
        return false
    }
}
