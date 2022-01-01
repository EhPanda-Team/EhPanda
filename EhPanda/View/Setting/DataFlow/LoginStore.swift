//
//  LoginStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/01.
//

import SwiftUI
import ComposableArchitecture

struct LoginState: Equatable {
    @BindableState var focusedField: LoginFocusedField?
    @BindableState var webViewSheetPresented = false
    @BindableState var username = ""
    @BindableState var password = ""
    var loginState: LoadingState = .idle

    var loginButtonDisabled: Bool {
        username.isEmpty || password.isEmpty
    }
    var loginButtonColor: Color {
        loginState == .loading ? .clear : loginButtonDisabled
        ? .primary.opacity(0.25) : .primary.opacity(0.75)
    }
}

enum LoginAction: BindableAction {
    case binding(BindingAction<LoginState>)
    case setWebViewSheet(Bool)
    case login
    case loginDone(Result<Any, AppError>)
}

let loginReducer = Reducer<LoginState, LoginAction, AnyEnvironment> { state, action, _ in
    Logger.info(action)
    switch action {
    case .binding:
        return .none

    case .setWebViewSheet(let presented):
        state.webViewSheetPresented = presented
        return .none

    case .login:
        guard !state.loginButtonDisabled
                || state.loginState == .loading
        else { return .none }

        withAnimation { state.loginState = .loading }
        HapticUtil.generateFeedback(style: .soft)

        return LoginRequest(username: state.username, password: state.password)
            .effect.map(LoginAction.loginDone)

    case .loginDone(let result):
        if case .success(let value) = result,
           let (_, response) = value as? (Data, HTTPURLResponse)
        {
            CookiesUtil.setIgneous(for: response)
        }
        guard AuthorizationUtil.didLogin else {
            HapticUtil.generateNotificationFeedback(style: .error)
            state.loginState = .failed(.unknown)
            return .none
        }
        HapticUtil.generateNotificationFeedback(style: .success)
        state.loginState = .idle
        return .none
    }
}
.binding()
