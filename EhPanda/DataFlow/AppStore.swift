//
//  AppStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import SwiftUI
import ComposableArchitecture

struct AppState: Equatable {
    var appSheetState = AppSheetState()
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
    case appSheet(AppSheetAction)
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
    let fileClient: FileClient
    let deviceClient: DeviceClient
    let loggerClient: LoggerClient
    let hapticClient: HapticClient
    let libraryClient: LibraryClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
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

    case .appSheet(.filters(.onResetFilterConfirmed)):
        return .init(value: .setting(.resetFilter(state.appSheetState.filtersState.filterRange)))

    case .appSheet:
        return .none

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
            .home(.watched(.onFiltersButtonTapped)), .search(.searchRequest(.onFiltersButtonTapped)):
        state.appSheetState.sheetState = .filters
        return .none

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
        return .init(value: .appSheet(.fetchGreetingDone(result)))

    case .setting:
        return .none
    }
}
.binding()

let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
    appReducerCore,
    appSheetReducer.pullback(
        state: \.appSheetState,
        action: /AppAction.appSheet,
        environment: { _ in
            .init()
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
                hapticClient: $0.hapticClient,
                libraryClient: $0.libraryClient,
                databaseClient: $0.databaseClient
            )
        }
    ),
    favoritesReducer.pullback(
        state: \.favoritesState,
        action: /AppAction.favorites,
        environment: {
            .init(
                hapticClient: $0.hapticClient,
                databaseClient: $0.databaseClient
            )
        }
    ),
    searchReducer.pullback(
        state: \.searchState,
        action: /AppAction.search,
        environment: {
            .init(
                hapticClient: $0.hapticClient,
                databaseClient: $0.databaseClient
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
                appDelegateClient: $0.appDelegateClient,
                userDefaultsClient: $0.userDefaultsClient,
                uiApplicationClient: $0.uiApplicationClient,
                authorizationClient: $0.authorizationClient
            )
        }
    )
)
