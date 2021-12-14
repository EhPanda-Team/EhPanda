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
    @State private var tabType: TabType = .home
    @StateObject private var store = Store()

    // MARK: EhPandaApp.body
    var body: some Scene {
        WindowGroup {
            TabView(selection: $tabType) {
                ForEach(TabType.allCases) { type in
                    type.view.tabItem(type.label).tag(type).accentColor(accentColor)
                }
            }
            .onReceive(AppNotification.bypassesSNIFilteringDidChange.publisher, perform: toggleDomainFronting)
            .onReceive(UIDevice.orientationDidChangeNotification.publisher) { _ in
                if DeviceUtil.isPad || DeviceUtil.isLandscape { NotificationUtil.post(.appWidthDidChange) }
            }
            .onReceive(UIApplication.didBecomeActiveNotification.publisher) { _ in
                NotificationUtil.post(.appWidthDidChange)
            }
            .accentColor(.primary).preferredColorScheme(preferredColorScheme)
            .environmentObject(store).onAppear(perform: onStartTasks)
            .navigationViewStyle(.stack)
        }
    }
}
// MARK: TabType.view
private extension TabType {
    var view: some View {
        Group {
            switch self {
            case .home:
                HomeView()
            case .favorites:
                FavoritesView()
            case .search:
                Text("Hello")
            case .setting:
                SettingView()
            }
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
    func toggleDomainFronting(_: Any? = nil) {
        if setting.bypassesSNIFiltering {
            URLProtocol.registerClass(DFURLProtocol.self)
        } else {
            URLProtocol.unregisterClass(DFURLProtocol.self)
        }
        AppUtil.configureKingfisher(bypassesSNIFiltering: setting.bypassesSNIFiltering)
    }
}

// MARK: Tasks
private extension EhPandaApp {
    func onStartTasks() {
        AppUtil.dispatchMainSync {
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

    func fetchTagTranslator() {
        store.dispatch(.fetchTagTranslator)
    }
    func fetchAccountInfoIfNeeded() {
        guard AuthorizationUtil.didLogin else { return }

        CookiesUtil.removeYay()
        store.dispatch(.fetchUserInfo)
        store.dispatch(.verifyEhProfile)
        store.dispatch(.fetchFavoriteNames)
    }
    func fetchIgneousIfNeeded() {
        let url = Defaults.URL.exhentai.safeURL()
        guard setting.bypassesSNIFiltering,
              !CookiesUtil.get(for: url, key: Defaults.Cookie.ipbMemberId).rawValue.isEmpty,
              !CookiesUtil.get(for: url, key: Defaults.Cookie.ipbPassHash).rawValue.isEmpty,
              CookiesUtil.get(for: url, key: Defaults.Cookie.igneous).rawValue.isEmpty
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
            DeviceUtil.keyWindow?.addGestureRecognizer(tapGesture)
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

        Logger.addDestination(file)
        #if DEBUG
        guard !AppUtil.isUnitTesting else { return }
        Logger.addDestination(console)
        #endif
    }
    func configure(file: inout FileDestination) {
        file.logFileAmount = 10
        file.calendar = Calendar(identifier: .gregorian)
        file.logFileURL = FileUtil.logsDirectoryURL?
            .appendingPathComponent(Defaults.FilePath.ehpandaLog)
    }
    func configure(console: inout ConsoleDestination) {
        console.calendar = Calendar(identifier: .gregorian)
        #if DEBUG
        console.asynchronously = false
        #endif
        console.levelColor.verbose = "😪"
        console.levelColor.warning = "⚠️"
        console.levelColor.error = "‼️"
        console.levelColor.debug = "🐛"
        console.levelColor.info = "📖"
    }

    func configureWebImage() {
        AppUtil.configureKingfisher(bypassesSNIFiltering: setting.bypassesSNIFiltering)
    }
    func configureDomainFronting() {
        if setting.bypassesSNIFiltering {
            URLProtocol.registerClass(DFURLProtocol.self)
        }
    }
    func configureIgnoreOffensive() {
        CookiesUtil.set(for: Defaults.URL.ehentai.safeURL(), key: "nw", value: "1")
        CookiesUtil.set(for: Defaults.URL.exhentai.safeURL(), key: "nw", value: "1")
    }
}

// MARK: AppDelegate
class AppDelegate: UIResponder, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask =
        DeviceUtil.isPad ? .all : [.portrait, .portraitUpsideDown]

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

// MARK: TabType
private enum TabType: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case home = "Home"
    case favorites = "Favorites"
    case search = "Search"
    case setting = "Setting"
}

private extension TabType {
    var symbolName: String {
        switch self {
        case .home:
            return "house.circle"
        case .favorites:
            return "heart.circle"
        case .search:
            return "magnifyingglass.circle"
        case .setting:
            return "gearshape.circle"
        }
    }
    func label() -> Label<Text, Image> {
        Label(rawValue.localized, systemImage: symbolName)
    }
}
