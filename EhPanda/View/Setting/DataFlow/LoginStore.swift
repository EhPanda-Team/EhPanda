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
    case textFieldSubmitted
    case login
    case loginDone
}

struct LoginEnvironment {
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
}

let loginReducer = Reducer<LoginState, LoginAction, LoginEnvironment> { state, action, environment in
    switch action {
    case .binding:
        return .none

    case .setWebViewSheet(let isPresented):
        state.webViewSheetPresented = isPresented
        return environment.hapticClient.generateFeedback(.light).fireAndForget()

    case .textFieldSubmitted:
        switch state.focusedField {
        case .username:
            state.focusedField = .password
        case .password:
            state.focusedField = nil
            return .init(value: .login)
        default:
            break
        }
        return .none

    case .login:
        guard !state.loginButtonDisabled
                || state.loginState == .loading
        else { return .none }

        withAnimation {
            state.loginState = .loading
        }

        return .merge(
            LoginRequest(username: state.username, password: state.password)
                .effect.map({ _ in LoginAction.loginDone }),
            environment.hapticClient.generateFeedback(.soft).fireAndForget()
        )

    case .loginDone:
        guard environment.cookiesClient.didLogin() else {
            state.loginState = .failed(.unknown)
            return environment.hapticClient.generateNotificationFeedback(.error).fireAndForget()
        }
        state.loginState = .idle
        state.webViewSheetPresented = false
        return environment.hapticClient.generateNotificationFeedback(.success).fireAndForget()
    }
}
.binding()
