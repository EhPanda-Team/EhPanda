//
//  LoginStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/01.
//

import SwiftUI
import ComposableArchitecture

struct LoginState: Equatable {
    enum Route: Equatable {
        case webView(URL)
    }
    enum FocusedField {
        case username
        case password
    }

    @BindableState var route: Route?
    @BindableState var focusedField: FocusedField?
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
    case setNavigation(LoginState.Route?)
    case onTextFieldSubmitted
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

    case .setNavigation(let route):
        state.route = route
        return .none

    case .onTextFieldSubmitted:
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
        state.route = nil
        state.loginState = .idle
        return environment.hapticClient.generateNotificationFeedback(.success).fireAndForget()
    }
}
.binding()
