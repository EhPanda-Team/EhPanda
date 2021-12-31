//
//  SettingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/31.
//

import ComposableArchitecture

struct SettingState: Equatable {
    var coreSettingState = CoreSettingState()
    var accountSettingState = AccountSettingState()
}

enum SettingAction {
    case core(CoreSettingAction)
    case account(AccountSettingAction)
}

struct CoreSettingState: Equatable {
    @BindableState var route: SettingRowType?
}

enum CoreSettingAction: BindableAction {
    case binding(BindingAction<CoreSettingState>)
    case setRoute(SettingRowType?)
}

let coreSettingReducer = Reducer<CoreSettingState, CoreSettingAction, AnyEnvironment> { state, action, _ in
    Logger.info(action)
    switch action {
    case .binding:
        return .none

    case .setRoute(let route):
        state.route = route
        return .none
    }
}
.binding()

let settingReducer = Reducer<SettingState, SettingAction, AnyEnvironment>.combine(
    coreSettingReducer.pullback(
        state: \.coreSettingState,
        action: /SettingAction.core,
        environment: { _ in AnyEnvironment() }
    ),
    accountSettingReducer.pullback(
        state: \.accountSettingState,
        action: /SettingAction.account,
        environment: { _ in AnyEnvironment() }
    )
)
