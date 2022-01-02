//
//  AccountSettingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/31.
//

import TTProgressHUD
import ComposableArchitecture

struct AccountSettingState: Equatable {
    @BindableState var route: AccountSettingRoute?
    @BindableState var logoutDialogPresented = false
    @BindableState var webViewSheetPresented = false
    @BindableState var hudVisible = false
    var hudConfig = TTProgressHUDConfig()

    var loginState = LoginState()
    var ehSettingState = EhSettingState()
}

enum AccountSettingAction: BindableAction {
    case binding(BindingAction<AccountSettingState>)
    case setRoute(AccountSettingRoute?)
    case setWebViewSheet(Bool)
    case setLogoutDialog(Bool)
    case setHUD(Bool, TTProgressHUDConfig)

    case login(LoginAction)
    case ehSetting(EhSettingAction)
}

let accountSettingReducer = Reducer<AccountSettingState, AccountSettingAction, AnyEnvironment>.combine(
    .init { state, action, _ in
        switch action {
        case .binding:
            return .none

        case .setRoute(let route):
            state.route = route
            return .none

        case .setWebViewSheet(let presented):
            state.webViewSheetPresented = presented
            return .none

        case .setLogoutDialog(let presented):
            state.logoutDialogPresented = presented
            return .none

        case .setHUD(let visible, let config):
            state.hudVisible = visible
            state.hudConfig = config
            return .none

        case .login(.loginDone):
            return .init(value: .setRoute(nil))

        case .login:
            return .none

        case .ehSetting:
            return .none
        }
    }
    .binding(),
    loginReducer.pullback(
        state: \.loginState,
        action: /AccountSettingAction.login,
        environment: { _ in AnyEnvironment() }
    ),
    ehSettingReducer.pullback(
        state: \.ehSettingState,
        action: /AccountSettingAction.ehSetting,
        environment: { _ in AnyEnvironment() }
    )
)
