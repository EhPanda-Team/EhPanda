//
//  AccountSettingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/31.
//

import TTProgressHUD
import ComposableArchitecture

struct AccountSettingState: Equatable {
    @BindableState var logoutDialogPresented = false
    @BindableState var webViewSheetPresented = false
    @BindableState var hudVisible = false
    var hudConfig = TTProgressHUDConfig()
}

enum AccountSettingAction: BindableAction {
    case binding(BindingAction<AccountSettingState>)
    case setWebViewSheet(Bool)
    case setLogoutDialog(Bool)
    case setHUD(Bool, TTProgressHUDConfig)
}

let accountSettingReducer = Reducer<AccountSettingState, AccountSettingAction, AnyEnvironment> { state, action, _ in
    Logger.info(action)
    switch action {
    case .binding:
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
    }
}
.binding()
