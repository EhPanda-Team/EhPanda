//
//  AppReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import ComposableArchitecture

let appReducer = Reducer<AltAppState, AltAppAction, AppEnvironment>.combine(
    appDelegateReducer.pullback(
        state: \.userData.setting.bypassesSNIFiltering,
        action: /AltAppAction.appDelegate,
        environment: { _ in AppDelegateEnvironment() }
    ),
    userDataReducer.pullback(
        state: \.userData,
        action: /AltAppAction.userData,
        environment: { _ in AnyEnvironment() }
    ),
    favoritesReducer.pullback(
        state: \.favoritesState,
        action: /AltAppAction.favorites,
        environment: { _ in FavoritesEnvironment() }
    )
)

struct AnyEnvironment {}
