//
//  LoginReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/01.
//

import SwiftUI
import ComposableArchitecture

struct LoginReducer: ReducerProtocol {
    private enum CancelID: Hashable {
        case login
    }

    enum Route: Equatable {
        case webView(URL)
    }

    enum FocusedField {
        case username
        case password
    }

    struct State: Equatable {
        @BindingState var route: Route?
        @BindingState var focusedField: FocusedField?
        @BindingState var username = ""
        @BindingState var password = ""
        var loginState: LoadingState = .idle

        var loginButtonDisabled: Bool {
            username.isEmpty || password.isEmpty
        }
        var loginButtonColor: Color {
            loginState == .loading ? .clear : loginButtonDisabled
            ? .primary.opacity(0.25) : .primary.opacity(0.75)
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route?)

        case teardown
        case login
        case loginDone(Result<HTTPURLResponse?, AppError>)
    }

    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.cookieClient) private var cookieClient

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return .none

            case .teardown:
                return .cancel(id: CancelID.self)

            case .login:
                guard !state.loginButtonDisabled || state.loginState == .loading else { return .none }
                state.focusedField = nil
                state.loginState = .loading
                return .merge(
                    .fireAndForget({ hapticsClient.generateFeedback(.soft) }),
                    LoginRequest(username: state.username, password: state.password)
                        .effect.map(Action.loginDone).cancellable(id: CancelID.login)
                )

            case .loginDone(let result):
                state.route = nil
                var effects = [EffectTask<Action>]()
                if cookieClient.didLogin {
                    state.loginState = .idle
                    effects.append(.fireAndForget({ hapticsClient.generateNotificationFeedback(.success) }))
                } else {
                    state.loginState = .failed(.unknown)
                    effects.append(.fireAndForget({ hapticsClient.generateNotificationFeedback(.error) }))
                }
                if case .success(let response) = result, let response = response {
                    effects.append(cookieClient.setCredentials(response: response).fireAndForget())
                }
                return .merge(effects)
            }
        }
        .haptics(
            unwrapping: \.route,
            case: /Route.webView,
            hapticsClient: hapticsClient
        )
    }
}
