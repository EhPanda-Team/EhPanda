//
//  AppearanceSettingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/03.
//

import ComposableArchitecture

struct AppearanceSettingState: Equatable {
    @BindableState var route: AppearanceSettingRoute?
}

enum AppearanceSettingAction: BindableAction {
    case binding(BindingAction<AppearanceSettingState>)
    case setRoute(AppearanceSettingRoute?)
}

struct AppearanceSettingEnvironment {}

let appearanceSettingReducer = Reducer<AppearanceSettingState, AppearanceSettingAction, AppearanceSettingEnvironment>
{ state, action, _ in
    switch action {
    case .binding:
        return .none

    case .setRoute(let route):
        state.route = route
        return .none
    }
}
.binding()
