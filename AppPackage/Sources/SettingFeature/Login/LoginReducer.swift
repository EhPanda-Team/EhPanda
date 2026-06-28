import SwiftUI
import AppModels
import ComposableArchitecture
import SwiftUINavigationExt
import HapticsClient
import NetworkingFeature
import CookieClient

@Reducer
public struct LoginReducer: Sendable {
    private enum CancelID: Hashable {
        case login
    }

    @CasePathable
    public enum Route: Equatable, Sendable {
        case webView(URL)
    }

    public enum FocusedField: Sendable {
        case username
        case password
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var route: Route?
        public var focusedField: FocusedField?
        public var username = ""
        public var password = ""
        public var loginState: LoadingState = .idle

        var loginButtonDisabled: Bool {
            username.isEmpty || password.isEmpty
        }
        var loginButtonColor: Color {
            loginState == .loading ? .clear : loginButtonDisabled
                ? .primary.opacity(0.25) : .primary.opacity(0.75)
        }
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route?)

        case teardown
        case login
        case loginDone(Result<HTTPURLResponse?, AppError>)
    }

    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.cookieClient) private var cookieClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return .none

            case .teardown:
                return .cancel(id: CancelID.login)

            case .login:
                guard !state.loginButtonDisabled || state.loginState == .loading else { return .none }
                state.focusedField = nil
                state.loginState = .loading
                return .merge(
                    .run(operation: { _ in await hapticsClient.generateFeedback(.soft) }),
                    .run { [state] send in
                        let response = await LoginRequest(username: state.username, password: state.password).response()
                        await send(.loginDone(response))
                    }
                    .cancellable(id: CancelID.login)
                )

            case .loginDone(let result):
                state.route = nil
                var effects = [Effect<Action>]()
                if cookieClient.didLogin {
                    state.loginState = .idle
                    effects.append(.run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) }))
                } else {
                    state.loginState = .failed(.unknown)
                    effects.append(.run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) }))
                }
                if case .success(let response) = result, let response = response {
                    effects.append(.run(operation: { _ in cookieClient.setCredentials(response: response) }))
                }
                return .merge(effects)
            }
        }
        .haptics(
            unwrapping: \.route,
            case: \.webView,
            hapticsClient: hapticsClient
        )
    }
}
