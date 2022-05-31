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
    struct CancelID: Hashable {
        let id = String(describing: LoginState.self)
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

enum LoginAction: BindableAction, Equatable {
    case binding(BindingAction<LoginState>)
    case setNavigation(LoginState.Route?)

    case teardown
    case login
    case loginDone(Result<HTTPURLResponse?, AppError>)
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

    case .teardown:
        return .cancel(id: LoginState.CancelID())

    case .login:
        guard !state.loginButtonDisabled || state.loginState == .loading else { return .none }
        state.focusedField = nil
        state.loginState = .loading
        return .merge(
            environment.hapticClient.generateFeedback(.soft).fireAndForget(),
            LoginRequest(username: state.username, password: state.password)
                .effect.map(LoginAction.loginDone).cancellable(id: LoginState.CancelID())
        )

    case .loginDone(let result):
        state.route = nil
        var effects = [Effect<LoginAction, Never>]()
        if environment.cookiesClient.didLogin {
            state.loginState = .idle
            effects.append(environment.hapticClient.generateNotificationFeedback(.success).fireAndForget())
        } else {
            state.loginState = .failed(.unknown)
            effects.append(environment.hapticClient.generateNotificationFeedback(.error).fireAndForget())
        }
        if case .success(let response) = result, let response = response {
            effects.append(environment.cookiesClient.setCredentials(response: response).fireAndForget())
        }
        return .merge(effects)
    }
}
.haptics(
    unwrapping: \.route,
    case: /LoginState.Route.webView,
    hapticClient: \.hapticClient
)
.binding()
