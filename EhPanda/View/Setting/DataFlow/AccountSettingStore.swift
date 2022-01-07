//
//  AccountSettingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/31.
//

import TTProgressHUD
import ComposableArchitecture

struct AccountSettingState: Equatable {
    @BindableState var route: AccountSettingRoute?
    @BindableState var logoutDialogPresented = false
    @BindableState var webViewSheetPresented = false
    @BindableState var hudVisible = false
    var hudConfig = TTProgressHUDConfig()
    var cookiesSectionIdentifier = ""

    var loginState = LoginState()
    var ehSettingState = EhSettingState()
}

enum AccountSettingAction: BindableAction {
    case binding(BindingAction<AccountSettingState>)
    case setNavigation(AccountSettingRoute?)
    case setWebViewSheetPresented(Bool)
    case setLogoutDialogPresented(Bool)
    case setHUD(Bool, TTProgressHUDConfig)
    case refreshCookiesSection

    case login(LoginAction)
    case logoutConfirmButtonTapped
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

        case .setWebViewSheetPresented(let isPresented):
            state.webViewSheetPresented = isPresented
            return environment.hapticClient.generateFeedback(.light).fireAndForget()

        case .setLogoutDialogPresented(let isPresented):
            state.logoutDialogPresented = isPresented
            return .none

        case .setHUD(let visible, let config):
            state.hudVisible = visible
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

        case .logoutConfirmButtonTapped:
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
