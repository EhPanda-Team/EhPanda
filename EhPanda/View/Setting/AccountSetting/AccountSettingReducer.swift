//
//  AccountSettingReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/31.
//

import Foundation
import TTProgressHUD
import ComposableArchitecture

@Reducer
struct AccountSettingReducer {
    @CasePathable
    enum Route: Equatable {
        case hud
        case login
        case logout
        case ehSetting
        case webView(URL)
    }

    struct State: Equatable {
        @BindingState var route: Route?
        @BindingState var ehCookiesState: CookiesState = .empty(.ehentai)
        @BindingState var exCookiesState: CookiesState = .empty(.exhentai)
        var hudConfig: TTProgressHUDConfig = .copiedToClipboardSucceeded

        var loginState = LoginReducer.State()
        var ehSettingState = EhSettingReducer.State()
    }

    enum Action: BindableAction, Equatable {
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

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.$route):
                return state.route == nil ? .send(.clearSubStates) : .none

            case .binding(\.$ehCookiesState):
                return .run { [state] _ in
                    cookieClient.setCookies(state: state.ehCookiesState)
                }

            case .binding(\.$exCookiesState):
                return .run { [state] _ in
                    cookieClient.setCookies(state: state.exCookiesState)
                }

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
                    .run(operation: { _ in hapticsClient.generateNotificationFeedback(.success) })
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
            case: /Route.webView,
            hapticsClient: hapticsClient
        )

        Scope(state: \.loginState, action: /Action.login, child: LoginReducer.init)
        Scope(state: \.ehSettingState, action: /Action.ehSetting, child: EhSettingReducer.init)
    }
}

// MARK: Models
struct CookieValue: Equatable {
    static let empty: Self = .init(
        rawValue: .init(), localizedString: .init()
    )

    let rawValue: String
    let localizedString: String

    var isInvalid: Bool {
        !localizedString.isEmpty && !rawValue.isEmpty
    }
    var placeholder: String {
        localizedString.isEmpty ? rawValue : localizedString
    }
}

struct CookiesState: Equatable {
    static func empty(_ host: GalleryHost) -> Self {
        .init(
            host: host,
            igneous: .empty,
            memberID: .empty,
            passHash: .empty
        )
    }
    var allCases: [CookieState] {[
        igneous, memberID, passHash
    ]}

    let host: GalleryHost
    var igneous: CookieState
    var memberID: CookieState
    var passHash: CookieState
}

struct CookieState: Equatable {
    static let empty: Self = .init(
        key: "", value: .init(
            rawValue: "", localizedString: ""
        )
    )

    let key: String
    var value: CookieValue
    var editingText = ""
}
