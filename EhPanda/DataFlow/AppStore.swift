//
//  AppReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import ComposableArchitecture

struct AltAppState: Equatable {
    var sharedData = SharedData()

    var tabBarState = TabBarState()
    var favoritesState = FavoritesState()
    var settingState = SettingState()
}

enum AltAppAction {
    case appDelegate(AppDelegateAction)
    case sharedData(SharedDataAction)

    case tabBar(TabBarAction)
    case favorites(FavoritesAction)
    case setting(SettingAction)
}

struct AppEnvironment {
    let dfClient: DFClient
    let libraryClient: LibraryClient
    let cookiesClient: CookiesClient
}

let appReducer = Reducer<AltAppState, AltAppAction, AppEnvironment>.combine(
    appDelegateReducer.pullback(
        state: \.sharedData.setting.bypassesSNIFiltering,
        action: /AltAppAction.appDelegate,
        environment: {
            .init(
                dfClient: $0.dfClient,
                libraryClient: $0.libraryClient,
                cookiesClient: $0.cookiesClient
            )
        }
    ),
    sharedDataReducer.pullback(
        state: \.sharedData,
        action: /AltAppAction.sharedData,
        environment: { _ in AnyEnvironment() }
    ),
    tabBarReducer.pullback(
        state: \.tabBarState,
        action: /AltAppAction.tabBar,
        environment: { _ in AnyEnvironment() }
    ),
    favoritesReducer.pullback(
        state: \.favoritesState,
        action: /AltAppAction.favorites,
        environment: { _ in FavoritesEnvironment() }
    ),
    settingReducer.pullback(
        state: \.settingState,
        action: /AltAppAction.setting,
        environment: { _ in AnyEnvironment() }
    ),
    .init { _, action, _ in
        switch action {
        case .setting(.account(.login(.loginDone))):
            return .init(value: .sharedData(.didFinishLogining))
        default:
            return .none
        }
    }
)

struct AnyEnvironment {}
