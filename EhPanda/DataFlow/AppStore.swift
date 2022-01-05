//
//  AppStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import SwiftUI
import ComposableArchitecture

struct AppState: Equatable {
    var appLockState = AppLockState()
    var tabBarState = TabBarState()
    var homeState = HomeState()
    var favoritesState = FavoritesState()
    var settingState = SettingState()
}

enum AppAction: BindableAction {
    case binding(BindingAction<AppState>)
    case onScenePhaseChange(ScenePhase)
    case appLock(AppLockAction)
    case appDelegate(AppDelegateAction)
    case home(HomeAction)
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
    .init { state, action, _ in
        switch action {
        case .binding:
            return .none

        case .onScenePhaseChange(let scenePhase):
            switch scenePhase {
            case .active:
                guard let date = state.appLockState.becomeInactiveDate else { return .none }
                let threshold: Int = state.settingState.setting.autoLockPolicy.rawValue
                if threshold >= 0, Date().timeIntervalSince(date) > Double(threshold) {
                    let radius = state.settingState.setting.backgroundBlurRadius
                    state.appLockState.setBlurRadius(radius)
                    state.appLockState.isAppLocked = true
                    return .init(value: .appLock(.authorize))
                } else {
                    state.appLockState.setBlurRadius(0)
                }
            case .inactive:
                let radius = state.settingState.setting.backgroundBlurRadius
                state.appLockState.setBlurRadius(radius)
                state.appLockState.becomeInactiveDate = Date()
            default:
                break
            }
            return .none

        case .appLock:
            return .none

        case .appDelegate:
            return .none

        case .home:
            state.homeState.rawFilter = state.settingState.globalFilter
            return .none

        case .favorites:
            return .none

        case .setting:
            return .none
        }
    }.binding(),
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
    settingReducer.pullback(
        state: \.settingState,
        action: /AppAction.setting,
        environment: {
            .init(
                dfClient: $0.dfClient,
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
