//
//  AccountSettingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/31.
//

import TTProgressHUD
import ComposableArchitecture

struct AccountSettingState: Equatable {
    enum Route: Equatable {
        case hud
        case login
        case logout
        case ehSetting
        case webView(URL)
    }

    @BindableState var route: Route?

    var hudConfig = TTProgressHUDConfig()
    var cookiesSectionIdentifier = ""

    var loginState = LoginState()
    var ehSettingState = EhSettingState()
}

enum AccountSettingAction: BindableAction {
    case binding(BindingAction<AccountSettingState>)
    case setNavigation(AccountSettingState.Route?)
    case setHUDConfig(TTProgressHUDConfig)
    case refreshCookiesSection

    case login(LoginAction)
    case onLogoutConfirmButtonTapped
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
        case .binding:
            return .none

        case .setNavigation(let route):
            state.route = route
            return .none

        case .setHUDConfig(let config):
            state.hudConfig = config
            return .none

        case .refreshCookiesSection:
            state.cookiesSectionIdentifier = UUID().uuidString
            return .none

        case .login(.loginDone):
            return environment.cookiesClient.didLogin()
            ? .merge(
                .init(value: .refreshCookiesSection),
                .init(value: .setNavigation(nil))
            )
            : .none

        case .login:
            return .none

        case .onLogoutConfirmButtonTapped:
            return .init(value: .refreshCookiesSection)

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
