//
//  AppStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import SwiftUI
import ComposableArchitecture

struct AppState: Equatable {
    var appDelegateState = AppDelegateState()
    var appRouteState = AppRouteState()
    var appLockState = AppLockState()
    var tabBarState = TabBarState()
    var homeState = HomeState()
    var favoritesState = FavoritesState()
    var searchRootState = SearchRootState()
    var settingState = SettingState()
}

enum AppAction: BindableAction {
    case binding(BindingAction<AppState>)
    case onScenePhaseChange(ScenePhase)

    case appDelegate(AppDelegateAction)
    case appRoute(AppRouteAction)
    case appLock(AppLockAction)

    case tabBar(TabBarAction)

    case home(HomeAction)
    case favorites(FavoritesAction)
    case searchRoot(SearchRootAction)
    case setting(SettingAction)
}

struct AnyEnvironment {}
struct AppEnvironment {
    let dfClient: DFClient
    let urlClient: URLClient
    let fileClient: FileClient
    let imageClient: ImageClient
    let deviceClient: DeviceClient
    let loggerClient: LoggerClient
    let hapticClient: HapticClient
    let libraryClient: LibraryClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let clipboardClient: ClipboardClient
    let appDelegateClient: AppDelegateClient
    let userDefaultsClient: UserDefaultsClient
    let uiApplicationClient: UIApplicationClient
    let authorizationClient: AuthorizationClient
}

let appReducerCore = Reducer<AppState, AppAction, AppEnvironment> { state, action, environment in
    switch action {
    case .binding(\.appRouteState.$route):
        return state.appRouteState.route == nil ? .init(value: .appRoute(.clearSubStates)) : .none

    case .binding(\.settingState.$setting):
        return .init(value: .setting(.syncSetting))

    case .binding:
        return .none

    case .onScenePhaseChange(let scenePhase):
        switch scenePhase {
        case .active:
            let threshold = state.settingState.setting.autoLockPolicy.rawValue
            let blurRadius = state.settingState.setting.backgroundBlurRadius
            return .init(value: .appLock(.onBecomeActive(threshold, blurRadius)))
        case .inactive:
            let blurRadius = state.settingState.setting.backgroundBlurRadius
            return .init(value: .appLock(.onBecomeInactive(blurRadius)))
        default:
            break
        }
        return .none

    case .appDelegate(.migration(.onDatabasePreparationSuccess)):
        return .merge(
            .init(value: .appDelegate(.removeExpiredImageURLs)),
            .init(value: .setting(.loadUserSettings))
        )

    case .appDelegate:
        return .none

    case .appRoute(.clearSubStates):
        var effects = [Effect<AppAction, Never>]()
        if environment.deviceClient.isPad() {
            state.settingState.route = nil
            effects.append(.init(value: .setting(.clearSubStates)))
        }
        return effects.isEmpty ? .none : .merge(effects)

    case .appRoute:
        return .none

    case .appLock(.unlockApp):
        var effects: [Effect<AppAction, Never>] = [
            .init(value: .setting(.fetchGreeting))
        ]
        if state.settingState.setting.detectsLinksFromClipboard {
            effects.append(.init(value: .appRoute(.detectClipboardURL)))
        }
        return .merge(effects)

    case .appLock:
        return .none

    case .tabBar(.setTabBarItemType(let type)):
        var effects = [Effect<AppAction, Never>]()
        let hapticEffect: Effect<AppAction, Never> = environment.hapticClient
            .generateFeedback(.soft).fireAndForget()
        if type == state.tabBarState.tabBarItemType {
            switch type {
            case .home:
                if state.homeState.route != nil {
                    effects.append(.init(value: .home(.setNavigation(nil))))
                } else {
                    effects.append(.init(value: .home(.fetchAllGalleries)))
                }
            case .favorites:
                if state.favoritesState.route != nil {
                    effects.append(.init(value: .favorites(.setNavigation(nil))))
                } else {
                    effects.append(.init(value: .favorites(.fetchGalleries())))
                }
            case .search:
                if state.searchRootState.route != nil {
                    effects.append(.init(value: .searchRoot(.setNavigation(nil))))
                } else {
                    effects.append(.init(value: .searchRoot(.fetchDatabaseInfos)))
                }
            case .setting:
                if state.settingState.route != nil {
                    effects.append(.init(value: .setting(.setNavigation(nil))))
                    effects.append(hapticEffect)
                }
            }
            if [.home, .favorites, .search].contains(type) {
                effects.append(hapticEffect)
            }
        }
        if type == .setting && environment.deviceClient.isPad() {
            effects.append(.init(value: .appRoute(.setNavigation(.setting))))
        }
        return effects.isEmpty ? .none : .merge(effects)

    case .tabBar:
        return .none

    case .home(.watched(.onNotLoginViewButtonTapped)), .favorites(.onNotLoginViewButtonTapped):
        var effects: [Effect<AppAction, Never>] = [
            environment.hapticClient.generateFeedback(.soft).fireAndForget(),
            .init(value: .tabBar(.setTabBarItemType(.setting)))
        ]
        effects.append(.init(value: .setting(.setNavigation(.account))))
        if !environment.cookiesClient.didLogin {
            effects.append(
                .init(value: .setting(.account(.setNavigation(.login))))
                    .delay(
                        for: .milliseconds(environment.deviceClient.isPad() ? 1200 : 200),
                        scheduler: DispatchQueue.main
                    )
                    .eraseToEffect()
            )
        }
        return .merge(effects)

    case .home:
        return .none

    case .favorites:
        return .none

    case .searchRoot:
        return .none

    case .setting(.fetchGreetingDone(let result)):
        return .init(value: .appRoute(.fetchGreetingDone(result)))

    case .setting:
        return .none
    }
}
.binding()

let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
    appReducerCore,
    appRouteReducer.pullback(
        state: \.appRouteState,
        action: /AppAction.appRoute,
        environment: {
            .init(
                dfClient: $0.dfClient,
                urlClient: $0.urlClient,
                fileClient: $0.fileClient,
                imageClient: $0.imageClient,
                deviceClient: $0.deviceClient,
                loggerClient: $0.loggerClient,
                hapticClient: $0.hapticClient,
                libraryClient: $0.libraryClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                appDelegateClient: $0.appDelegateClient,
                userDefaultsClient: $0.userDefaultsClient,
                uiApplicationClient: $0.uiApplicationClient,
                authorizationClient: $0.authorizationClient
            )
        }
    ),
    appLockReducer.pullback(
        state: \.appLockState,
        action: /AppAction.appLock,
        environment: {
            .init(
                authorizationClient: $0.authorizationClient
            )
        }
    ),
    appDelegateReducer.pullback(
        state: \.self,
        action: /AppAction.appDelegate,
        environment: {
            .init(
                dfClient: $0.dfClient,
                libraryClient: $0.libraryClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient
            )
        }
    ),
    tabBarReducer.pullback(
        state: \.tabBarState,
        action: /AppAction.tabBar,
        environment: {
            .init(
                deviceClient: $0.deviceClient
            )
        }
    ),
    homeReducer.pullback(
        state: \.homeState,
        action: /AppAction.home,
        environment: {
            .init(
                urlClient: $0.urlClient,
                fileClient: $0.fileClient,
                imageClient: $0.imageClient,
                deviceClient: $0.deviceClient,
                hapticClient: $0.hapticClient,
                libraryClient: $0.libraryClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                appDelegateClient: $0.appDelegateClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    ),
    favoritesReducer.pullback(
        state: \.favoritesState,
        action: /AppAction.favorites,
        environment: {
            .init(
                urlClient: $0.urlClient,
                fileClient: $0.fileClient,
                imageClient: $0.imageClient,
                deviceClient: $0.deviceClient,
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                appDelegateClient: $0.appDelegateClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    ),
    searchRootReducer.pullback(
        state: \.searchRootState,
        action: /AppAction.searchRoot,
        environment: {
            .init(
                urlClient: $0.urlClient,
                fileClient: $0.fileClient,
                imageClient: $0.imageClient,
                deviceClient: $0.deviceClient,
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                appDelegateClient: $0.appDelegateClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    ),
    settingReducer.pullback(
        state: \.settingState,
        action: /AppAction.setting,
        environment: {
            .init(
                dfClient: $0.dfClient,
                fileClient: $0.fileClient,
                deviceClient: $0.deviceClient,
                loggerClient: $0.loggerClient,
                hapticClient: $0.hapticClient,
                libraryClient: $0.libraryClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                appDelegateClient: $0.appDelegateClient,
                userDefaultsClient: $0.userDefaultsClient,
                uiApplicationClient: $0.uiApplicationClient,
                authorizationClient: $0.authorizationClient
            )
        }
    )
)
.logging()
