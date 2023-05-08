//
//  AccountSettingReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/31.
//

import Foundation
import TTProgressHUD
import ComposableArchitecture

struct AccountSettingReducer: ReducerProtocol {
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

        var loginState = LoginState()
        var ehSettingState = EhSettingState()
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case onLogoutConfirmButtonTapped
        case clearSubStates

        case loadCookies
        case copyCookies(GalleryHost)

        case login(LoginAction)
        case ehSetting(EhSettingAction)
    }

    @Dependency(\.clipboardClient) private var clipboardClient
    @Dependency(\.cookiesClient) private var cookiesClient
    @Dependency(\.hapticClient) private var hapticClient

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .binding(\.$route):
                return state.route == nil ? .init(value: .clearSubStates) : .none

            case .binding(\.$ehCookiesState):
                return cookiesClient.setCookies(state: state.ehCookiesState).fireAndForget()

            case .binding(\.$exCookiesState):
                return cookiesClient.setCookies(state: state.exCookiesState).fireAndForget()

            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .init(value: .clearSubStates) : .none

            case .onLogoutConfirmButtonTapped:
                return .init(value: .loadCookies)

            case .clearSubStates:
                state.loginState = .init()
                state.ehSettingState = .init()
                return .merge(
                    .init(value: .login(.teardown)),
                    .init(value: .ehSetting(.teardown))
                )

            case .loadCookies:
                state.ehCookiesState = cookiesClient.loadCookiesState(host: .ehentai)
                state.exCookiesState = cookiesClient.loadCookiesState(host: .exhentai)
                return .none

            case .copyCookies(let host):
                let cookiesDescription = cookiesClient.getCookiesDescription(host: host)
                return .merge(
                    .init(value: .setNavigation(.hud)),
                    clipboardClient.saveText(cookiesDescription).fireAndForget(),
                    hapticClient.generateNotificationFeedback(.success).fireAndForget()
                )

            case .login(.loginDone):
                return cookiesClient.didLogin ? .init(value: .setNavigation(nil)) : .none

            case .login:
                return .none

            case .ehSetting:
                return .none
            }
        }
        .haptics(
            unwrapping: \.route,
            case: /Route.webView,
            hapticsClient: hapticClient
        )

//        // TODO: Child reducers
//        Scope(state: \.loginState, action: /Action.login, child: { loginReducer })
//        Scope(state: \.ehSettingState, action: /Action.ehSetting, child: { ehSettingReducer })

        BindingReducer()
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
