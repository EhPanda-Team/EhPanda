import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import CookieClient
import HapticsClient
import NetworkingFeature
import OSLogExt
import SwiftUI

private let logger = Logger(category: .init(describing: LoginReducer.self))

@Reducer
public struct LoginReducer: Sendable {
    /// How many times a single login attempt may put the challenge surface on screen.
    ///
    /// Wall → solve → retry, and if the retry comes back challenged, one more round; a third
    /// challenge means the clearance is not getting this attempt through, so it fails instead of
    /// looping. This is a *reducer-level* count and deliberately unrelated to `fetch`'s four-attempt
    /// transport policy: a challenged 403 is a successful response, so it never touches that budget.
    private static let maxChallengeRounds = 2

    private enum CancelID: Hashable {
        case login
    }

    @Reducer
    public enum Destination {
        @ReducerCaseIgnored
        case webView(URL)
        @ReducerCaseIgnored
        case challenge(URL)
        @ReducerCaseIgnored
        case errorInfo(ErrorInfo)
    }

    public enum FocusedField: Sendable {
        case username
        case password
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        @Presents public var destination: Destination.State?
        @Presents public var toast: AppAlertState<Never>?
        // The session-lifetime clearance holder. In-memory only, so it starts at `nil` on every
        // launch with no cleanup code — that *is* the no-persistence guarantee, not a step towards it.
        @Shared(.cloudflareClearance) public var cloudflareClearance: CloudflareClearance?
        public var focusedField: FocusedField?
        public var username = ""
        public var password = ""
        public var loginState: LoadingState = .idle
        /// Challenge surfaces presented during the current attempt; reset by every `.login`.
        public var challengeRounds = 0

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
        case toast(PresentationAction<Never>)
        case presentWebView(URL)
        case presentErrorInfo(ErrorInfo)

        case login
        case loginDone(Result<HTTPURLResponse?, AppError>)
        case challengeDetected
        case challengeClearanceCaptured(CloudflareClearance)
        case cancelChallenge
    }

    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.loginClient) private var loginClient
    @Dependency(\.dismiss) private var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            // A swipe-down on the challenge sheet means the same thing as its cancel button. The
            // destination is still populated here: `.ifLet` clears it after this reducer runs.
            case .destination(.dismiss):
                guard state.destination?.is(\.challenge) == true, state.loginState == .loading else {
                    return .none
                }
                state.loginState = .idle
                return .cancel(id: CancelID.login)

            case .destination:
                return .none

            case .toast:
                return .none

            case .presentWebView(let url):
                state.destination = .webView(url)
                return .none

            case .presentErrorInfo(let errorInfo):
                state.destination = .errorInfo(errorInfo)
                return .none

            case .login:
                guard !state.loginButtonDisabled || state.loginState == .loading else { return .none }
                state.focusedField = nil
                state.loginState = .loading
                // The bound is per attempt, so a fresh tap always gets a full budget of rounds.
                state.challengeRounds = 0
                return .merge(
                    .run(operation: { _ in await hapticsClient.generateFeedback(.soft) }),
                    loginEffect(state: state)
                )

            case .challengeDetected:
                guard state.challengeRounds < Self.maxChallengeRounds else {
                    logger.notice("Cloudflare challenge rounds exhausted.")
                    return .send(.loginDone(.failure(.cloudflareChallengeFailed)))
                }
                state.challengeRounds += 1
                // Presented straight away, with no hidden pre-attempt: an auto-passing wall flashes
                // by and dismisses itself, and an interactive one is ready with zero added delay.
                // `loginState` stays `.loading`, so the login button's spinner spans the whole flow.
                state.destination = .challenge(Defaults.URL.login)
                return .none

            case .challengeClearanceCaptured(let clearance):
                // Ignore a capture that arrives without a challenge on screen: it can only be a
                // straggler from a surface that was already cancelled or already reported.
                guard state.destination?.is(\.challenge) == true else { return .none }
                state.$cloudflareClearance.withLock({ $0 = clearance })
                // The surface has served its purpose the instant the pair lands, so it goes away
                // here rather than waiting for the retry to come back.
                state.destination = nil
                return loginEffect(state: state)

            // User-initiated cancel is silent by design: no retry, no toast, no failure state.
            case .cancelChallenge:
                state.destination = nil
                state.loginState = .idle
                return .cancel(id: CancelID.login)

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
                    if case .failure(.cloudflareChallengeFailed) = result {
                        state.loginState = .failed(.cloudflareChallengeFailed)
                        // The clearance value itself is never carried here — only the whitelisted
                        // rows that tell the user which request failed and how.
                        state.toast = .error(
                            .init(
                                error: .cloudflareChallengeFailed,
                                context: [.action: "Login", .statusCode: 403]
                            )
                        )
                    } else {
                        state.loginState = .failed(.unknown)
                    }
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
        .haptics(
            unwrapping: \.destination,
            case: \.challenge,
            hapticsClient: hapticsClient
        )
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$toast, action: \.toast)
    }

    /// The login POST, shared by the first attempt and by every post-challenge retry.
    ///
    /// The held clearance pair is attached proactively, so a still-valid one from earlier in the
    /// session skips the wall outright and an expired one simply comes back challenged and re-runs
    /// the flow — which is why expiry needs no timer. A challenged response is classified purely
    /// from what the edge sent back: no host list, no app setting, nothing to keep in sync.
    private func loginEffect(state: State) -> Effect<Action> {
        .run { [state] send in
            do throws(AppError) {
                let response = try await loginClient.login(state.username, state.password, state.cloudflareClearance)
                if isCloudflareChallenge(response) {
                    await send(.challengeDetected)
                } else {
                    await send(.loginDone(.success(response)))
                }
            } catch {
                await send(.loginDone(.failure(error)))
            }
        }
        .cancellable(id: CancelID.login)
    }
}

extension LoginReducer.Destination.State: Equatable, Sendable {}
extension LoginReducer.Destination.Action: Equatable, Sendable {}
