import Foundation
import AppModels
import ComposableArchitecture
import SwiftUINavigationExt
import HapticsClient
import ClipboardClient
import CookieClient
import DesignSystem

@Reducer
public struct AccountSettingReducer: Sendable {
    @dynamicMemberLookup @CasePathable
    public enum Route: Equatable, Sendable {
        case hud
        case login
        case logout
        case ehSetting
        case webView(URL)
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var route: Route?
        public var ehCookiesState: CookiesState = .empty(.ehentai)
        public var exCookiesState: CookiesState = .empty(.exhentai)
        public var hudConfig: ProgressHUDConfigState = .copiedToClipboardSucceeded

        public var loginState = LoginReducer.State()
        public var ehSettingState = EhSettingReducer.State()
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case onLogoutConfirmButtonTapped
        case clearSubStates
        case loadCookies
        case copyCookies(GalleryHost)
        case login(LoginReducer.Action)
        case ehSetting(EhSettingReducer.Action)
    }

    @Dependency(\.clipboardClient) private var clipboardClient
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.route) { _, state in
                state.route == nil ? .send(.clearSubStates) : .none
            }
            .onChange(of: \.ehCookiesState) { _, state in
                .run(operation: { [value = state.ehCookiesState] _ in cookieClient.setCookies(state: value) })
            }
            .onChange(of: \.exCookiesState) { _, state in
                .run(operation: { [value = state.exCookiesState] _ in cookieClient.setCookies(state: value) })
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .send(.clearSubStates) : .none

            case .onLogoutConfirmButtonTapped:
                return .send(.loadCookies)

            case .clearSubStates:
                state.loginState = .init()
                state.ehSettingState = .init()
                return .merge(
                    .send(.login(.teardown)),
                    .send(.ehSetting(.teardown))
                )

            case .loadCookies:
                state.ehCookiesState = cookieClient.loadCookiesState(host: .ehentai)
                state.exCookiesState = cookieClient.loadCookiesState(host: .exhentai)
                return .none

            case .copyCookies(let host):
                let cookiesDescription = cookieClient.getCookiesDescription(host: host)
                return .merge(
                    .send(.setNavigation(.hud)),
                    .run(operation: { _ in clipboardClient.saveText(cookiesDescription) }),
                    .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) })
                )

            case .login(.loginDone):
                return cookieClient.didLogin ? .send(.setNavigation(nil)) : .none

            case .login:
                return .none

            case .ehSetting:
                return .none
            }
        }
        .haptics(
            unwrapping: \.route,
            case: \.webView,
            hapticsClient: hapticsClient
        )

        Scope(state: \.loginState, action: \.login, child: LoginReducer.init)
        Scope(state: \.ehSettingState, action: \.ehSetting, child: EhSettingReducer.init)
    }
}
