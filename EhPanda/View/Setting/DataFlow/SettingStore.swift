//
//  SettingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/31.
//

import ComposableArchitecture

struct SettingState: Equatable {
    @BindableState var route: SettingRoute?

    var accountSettingState = AccountSettingState()
}

enum SettingAction: BindableAction {
    case binding(BindingAction<SettingState>)
    case setRoute(SettingRoute?)

    case account(AccountSettingAction)
}

let settingReducer = Reducer<SettingState, SettingAction, AnyEnvironment>.combine(
    .init { state, action, _ in
        switch action {
        case .binding:
            return .none

        case .setRoute(let route):
            state.route = route
            return .none

        case .account:
            return .none
        }
    }
    .binding(),
    accountSettingReducer.pullback(
        state: \.accountSettingState,
        action: /SettingAction.account,
        environment: { _ in AnyEnvironment() }
    )
)
