//
//  AccountSettingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/31.
//

import TTProgressHUD
import ComposableArchitecture

struct CookieValue: Equatable {
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

struct AccountSettingState: Equatable {
    enum Route: Equatable {
        case hud
        case login
        case logout
        case ehSetting
        case webView(URL)
    }

    @BindableState var route: Route?
    @BindableState var ehCookiesState: CookiesState = .empty(.ehentai)
    @BindableState var exCookiesState: CookiesState = .empty(.exhentai)
    var hudConfig: TTProgressHUDConfig = .copiedToClipboardSucceeded

    var loginState = LoginState()
    var ehSettingState = EhSettingState()
}

enum AccountSettingAction: BindableAction {
    case binding(BindingAction<AccountSettingState>)
    case setNavigation(AccountSettingState.Route?)
    case onLogoutConfirmButtonTapped

    case loadCookies
    case copyCookies(GalleryHost)

    case login(LoginAction)
    case ehSetting(EhSettingAction)
}

struct AccountSettingEnvironment {
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let uiApplicationClient: UIApplicationClient
}

let accountSettingReducer = Reducer<AccountSettingState, AccountSettingAction, AccountSettingEnvironment>.combine(
    .init { state, action, environment in
        switch action {
        case .binding(\.$ehCookiesState):
            return environment.cookiesClient.setCookies(state: state.ehCookiesState).fireAndForget()

        case .binding(\.$exCookiesState):
            return environment.cookiesClient.setCookies(state: state.exCookiesState).fireAndForget()

        case .binding:
            return .none

        case .setNavigation(let route):
            state.route = route
            return .none

        case .onLogoutConfirmButtonTapped:
            return .none

        case .loadCookies:
            state.ehCookiesState = environment.cookiesClient.loadCookiesState(host: .ehentai)
            state.exCookiesState = environment.cookiesClient.loadCookiesState(host: .exhentai)
            return .none

        case .copyCookies(let host):
            return .merge(
                .init(value: .setNavigation(.hud)),
                environment.cookiesClient.copyCookies(host: host).fireAndForget()
            )

        case .login(.loginDone):
            return environment.cookiesClient.didLogin() ? .init(value: .setNavigation(nil)) : .none

        case .login:
            return .none

        case .ehSetting:
            return .none
        }
    }
    .binding(),
    loginReducer.pullback(
        state: \.loginState,
        action: /AccountSettingAction.login,
        environment: {
            .init(
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient
            )
        }
    ),
    ehSettingReducer.pullback(
        state: \.ehSettingState,
        action: /AccountSettingAction.ehSetting,
        environment: {
            .init(
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    )
)
