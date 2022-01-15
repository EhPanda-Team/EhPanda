//
//  AppearanceSettingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/03.
//

import ComposableArchitecture

struct AppearanceSettingState: Equatable {
    enum Route {
        case appIcon
    }

    @BindableState var route: Route?
}

enum AppearanceSettingAction: BindableAction {
    case binding(BindingAction<AppearanceSettingState>)
    case setNavigation(AppearanceSettingState.Route?)
}

struct AppearanceSettingEnvironment {}

let appearanceSettingReducer = Reducer<AppearanceSettingState, AppearanceSettingAction, AppearanceSettingEnvironment>
{ state, action, _ in
    switch action {
    case .binding:
        return .none

    case .setNavigation(let route):
        state.route = route
        return .none
    }
}
.binding()
