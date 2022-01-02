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

struct LoginEnvironment {
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
}

let loginReducer = Reducer<LoginState, LoginAction, LoginEnvironment> { state, action, environment in
    switch action {
    case .binding:
        return .none

    case .setWebViewSheet(let presented):
        state.webViewSheetPresented = presented
        return environment.hapticClient.generateFeedback(.light).fireAndForget()

    case .login:
        guard !state.loginButtonDisabled
                || state.loginState == .loading
        else { return .none }

        withAnimation {
            state.loginState = .loading
        }

        return .merge(
            LoginRequest(username: state.username, password: state.password)
                .effect.map(LoginAction.loginDone),
            environment.hapticClient.generateFeedback(.soft).fireAndForget()
        )

    case .loginDone(let result):
        guard environment.cookiesClient.didLogin() else {
            state.loginState = .failed(.unknown)
            return environment.hapticClient.generateNotificationFeedback(.error).fireAndForget()
        }
        state.loginState = .idle
        return environment.hapticClient.generateNotificationFeedback(.success).fireAndForget()
    }
}
.binding()
