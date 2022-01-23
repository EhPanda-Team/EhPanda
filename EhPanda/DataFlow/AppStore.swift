//
//  AppStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import SwiftUI
import ComposableArchitecture

struct AppState: Equatable {
    var appRouteState = AppRouteState()
    var appLockState = AppLockState()
    var tabBarState = TabBarState()
    var homeState = HomeState()
    var favoritesState = FavoritesState()
    var searchState = SearchState()
    var settingState = SettingState()
}

enum AppAction: BindableAction {
    case binding(BindingAction<AppState>)
    case onScenePhaseChange(ScenePhase)
    case appRoute(AppRouteAction)
    case appLock(AppLockAction)
    case appDelegate(AppDelegateAction)
    case home(HomeAction)
    case favorites(FavoritesAction)
    case search(SearchAction)
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

let appReducerCore = Reducer<AppState, AppAction, AppEnvironment> { state, action, _ in
    switch action {
    case .binding(\.settingState.$searchFilter):
        return .init(value: .setting(.syncSearchFilter))

    case .binding(\.settingState.$globalFilter):
        return .init(value: .setting(.syncGlobalFilter))

    case .binding(\.settingState.$watchedFilter):
        return .init(value: .setting(.syncWatchedFilter))

    case .binding:
        return .none

    case .onScenePhaseChange(let scenePhase):
        switch scenePhase {
        case .active:
            var effects = [Effect<AppAction, Never>]()
            let threshold = state.settingState.setting.autoLockPolicy.rawValue
            let blurRadius = state.settingState.setting.backgroundBlurRadius
            effects.append(.init(value: .appLock(.onBecomeActive(threshold, blurRadius))))
            if threshold < 0, state.settingState.setting.detectsLinksFromClipboard {
                effects.append(.init(value: .appRoute(.detectClipboardURL)))
            }
            return .merge(effects)
        case .inactive:
            let blurRadius = state.settingState.setting.backgroundBlurRadius
            return .init(value: .appLock(.onBecomeInactive(blurRadius)))
        default:
            break
        }
        return .none

    case .appRoute(.filters(.onResetFilterConfirmed)):
        return .init(value: .setting(.resetFilter(state.appRouteState.filtersState.filterRange)))

    case .appRoute:
        return .none

    case .appLock(.authorizeDone(let isSucceeded)):
        return isSucceeded && state.settingState.setting.detectsLinksFromClipboard
        ? .init(value: .appRoute(.detectClipboardURL)) : .none

    case .appLock:
        return .none

    case .appDelegate:
        return .none

    case .home(.frontpage(.fetchGalleries)), .home(.frontpage(.fetchMoreGalleries)):
        state.homeState.frontpageState.filter = state.settingState.globalFilter
        return .none

    case .home(.popular(.fetchGalleries)):
        state.homeState.popularState.filter = state.settingState.globalFilter
        return .none

    case .home(.watched(.fetchGalleries)), .home(.watched(.fetchMoreGalleries)):
        state.homeState.watchedState.filter = state.settingState.watchedFilter
        return .none

    case .home(.fetchPopularGalleries), .home(.fetchFrontpageGalleries):
        state.homeState.filter = state.settingState.globalFilter
        return .none

    case .home(.frontpage(.onFiltersButtonTapped)), .home(.popular(.onFiltersButtonTapped)),
            .home(.watched(.onFiltersButtonTapped)), .search(.onFiltersButtonTapped),
            .search(.searchRequest(.onFiltersButtonTapped)):
        return .init(value: .appRoute(.setNavigation(.filters)))

    case .home:
        return .none

    case .favorites:
        return .none

    case .search(.searchRequest(.fetchGalleries)):
        state.searchState.searchReqeustState.filter = state.settingState.searchFilter
        return .none

    case .search:
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
                urlClient: $0.urlClient,
                fileClient: $0.fileClient,
                imageClient: $0.imageClient,
                deviceClient: $0.deviceClient,
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                userDefaultsClient: $0.userDefaultsClient,
                uiApplicationClient: $0.uiApplicationClient
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
                cookiesClient: $0.cookiesClient
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
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    ),
    searchReducer.pullback(
        state: \.searchState,
        action: /AppAction.search,
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

extension Reducer {
    func logging() -> Self {
        .init { state, action, environment in
            Logger.info(action)
            return run(&state, action, environment)
        }
    }
}
