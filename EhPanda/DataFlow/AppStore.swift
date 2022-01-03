//
//  AppReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import ComposableArchitecture

struct AppState: Equatable {
    var tabBarState = TabBarState()
    var favoritesState = FavoritesState()
    var settingState = SettingState()
}

enum AppAction {
    case appDelegate(AppDelegateAction)
    case tabBar(TabBarAction)
    case favorites(FavoritesAction)
    case setting(SettingAction)
}

struct AnyEnvironment {}
struct AppEnvironment {
    let dfClient: DFClient
    let fileClient: FileClient
    let loggerClient: LoggerClient
    let hapticClient: HapticClient
    let libraryClient: LibraryClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let userDefaultsClient: UserDefaultsClient
    let uiApplicationClient: UIApplicationClient
    let authorizationClient: AuthorizationClient
}

let appReducer = Reducer<AppState, AppAction, AppEnvironment>.combine(
    appDelegateReducer.pullback(
        state: \.settingState.setting.bypassesSNIFiltering,
        action: /AppAction.appDelegate,
        environment: {
            .init(
                dfClient: $0.dfClient,
                libraryClient: $0.libraryClient,
                cookiesClient: $0.cookiesClient
            )
        }
    ),
    tabBarReducer.pullback(
        state: \.tabBarState,
        action: /AppAction.tabBar,
        environment: { _ in AnyEnvironment() }
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
    settingReducer.pullback(
        state: \.settingState,
        action: /AppAction.setting,
        environment: {
            .init(
                fileClient: $0.fileClient,
                loggerClient: $0.loggerClient,
                hapticClient: $0.hapticClient,
                libraryClient: $0.libraryClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                userDefaultsClient: $0.userDefaultsClient,
                uiApplicationClient: $0.uiApplicationClient,
                authorizationClient: $0.authorizationClient
            )
        }
    )
)
