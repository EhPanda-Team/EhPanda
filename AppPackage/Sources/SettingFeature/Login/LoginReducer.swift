import SwiftUI
import AppModels
import ComposableArchitecture
import SwiftUINavigationExt
import HapticsClient
import NetworkingFeature
import CookieClient
import OSLogExt

private let logger = Logger(category: .init(describing: LoginReducer.self))

@Reducer
public struct LoginReducer: Sendable {
    private enum CancelID: Hashable {
        case login
    }

    @Reducer
    public enum Destination {
        @ReducerCaseIgnored
        case webView(URL)
    }

    public enum FocusedField: Sendable {
        case username
        case password
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        @Presents public var destination: Destination.State?
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
        case destination(PresentationAction<Destination.Action>)
        case presentWebView(URL)

        case teardown
        case login
        case loginDone(Result<HTTPURLResponse?, AppError>)
    }

    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.dismiss) private var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .destination:
                return .none

            case .presentWebView(let url):
                state.destination = .webView(url)
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
                state.destination = nil
                var effects = [Effect<Action>]()
                if cookieClient.didLogin {
                    state.loginState = .idle
                    effects.append(.run(operation: { _ in
                        logger.notice("Login succeeded.")
                        await hapticsClient.generateNotificationFeedback(.success)
                    }))
                    // Pop this login screen off the Setting stack now that we're signed in.
                    effects.append(.run { _ in await dismiss() })
                } else {
                    state.loginState = .failed(.unknown)
                    effects.append(.run(operation: { _ in
                        logger.notice("Login failed.")
                        await hapticsClient.generateNotificationFeedback(.error)
                    }))
                }
                if case .success(let response) = result, let response = response {
                    effects.append(.run(operation: { _ in cookieClient.setCredentials(response: response) }))
                }
                return .merge(effects)
            }
        }
        .haptics(
            unwrapping: \.destination,
            case: \.webView,
            hapticsClient: hapticsClient
        )
        .ifLet(\.$destination, action: \.destination)
    }
}

extension LoginReducer.Destination.State: Equatable, Sendable {}
extension LoginReducer.Destination.Action: Equatable, Sendable {}
