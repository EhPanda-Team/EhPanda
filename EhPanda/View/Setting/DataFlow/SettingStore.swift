//
//  SettingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/31.
//

import ComposableArchitecture

struct SettingState: Equatable {
    @AppEnvStorage(type: User.self) var user: User
    @AppEnvStorage(type: Setting.self) var setting: Setting

    @AppEnvStorage(type: Filter.self, key: "searchFilter")
    var searchFilter: Filter
    @AppEnvStorage(type: Filter.self, key: "globalFilter")
    var globalFilter: Filter

    @AppEnvStorage(type: TagTranslator.self, key: "tagTranslator")
    var tagTranslator: TagTranslator

    @BindableState var route: SettingRoute?

    var accountSettingState = AccountSettingState()
}

enum SettingAction: BindableAction {
    case binding(BindingAction<SettingState>)

    case didFinishLaunching
    case createDefaultEhProfile
    case fetchIgneous
    case fetchUserInfo
    case fetchUserInfoDone(Result<User, AppError>)
    case fetchTagTranslator(String)
    case fetchTagTranslatorDone(Result<TagTranslator, AppError>)
    case fetchEhProfileIndex
    case fetchEhProfileIndexDone(Result<(Int?, Bool), AppError>)
    case fetchFavoriteNames
    case fetchFavoriteNamesDone(Result<[Int: String], AppError>)

    case setRoute(SettingRoute?)

    case account(AccountSettingAction)
}

struct SettingEnvironment {
    let loggerClient: LoggerClient
    let hapticClient: HapticClient
    let libraryClient: LibraryClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let userDefaultsClient: UserDefaultsClient
    let uiApplicationClient: UIApplicationClient
}

let settingReducer = Reducer<SettingState, SettingAction, SettingEnvironment>.combine(
    .init { state, action, environment in
        switch action {
        case .binding(\.setting.$galleryHost):
            return environment.userDefaultsClient.setString(
                state.setting.galleryHost.rawValue,
                AppUserDefaults.galleryHost.rawValue
            )
            .fireAndForget()

        case .binding:
            return .none

        case .didFinishLaunching:
            var effects = [Effect<SettingAction, Never>]()

            if let value = environment.userDefaultsClient
                .getString(AppUserDefaults.galleryHost.rawValue),
               let galleryHost = GalleryHost(rawValue: value)
            {
                state.setting.galleryHost = galleryHost
            }
            if environment.cookiesClient.shouldFetchIgneous() {
                effects.append(.init(value: .fetchIgneous))
            }
            if environment.cookiesClient.didLogin() {
                effects.append(contentsOf: [
                    .init(value: .fetchUserInfo),
                    .init(value: .fetchFavoriteNames),
                    .init(value: .fetchEhProfileIndex)
                ])
            }
            if let preferredLanguage = Locale.preferredLanguages.first {
                effects.append(.init(value: .fetchTagTranslator(preferredLanguage)))
            }

            return effects.isEmpty ? .none : .merge(effects)

        case .createDefaultEhProfile:
            return EhProfileRequest(action: .create, name: "EhPanda").effect.fireAndForget()

        case .fetchIgneous:
            return IgneousRequest().effect.fireAndForget()

        case .fetchUserInfo:
            let uid = state.user.apiuid
            guard !uid.isEmpty else { return .none }
            return UserInfoRequest(uid: uid).effect.map(SettingAction.fetchUserInfoDone)

        case .fetchUserInfoDone(let result):
            if case .success(let user) = result {
                state.user = user
            }
            return .none

        case .fetchTagTranslator(let preferredLanguage):
            guard let language = TranslatableLanguage.allCases.compactMap({ lang in
                preferredLanguage.contains(lang.languageCode) ? lang : nil
            }).first else {
                state.tagTranslator = TagTranslator()
                state.setting.translatesTags = false
                return .none
            }
            if state.tagTranslator.language != language {
                state.tagTranslator = TagTranslator()
            }

            let updatedDate = state.tagTranslator.updatedDate
            return TagTranslatorRequest(language: language, updatedDate: updatedDate)
                .effect.map(SettingAction.fetchTagTranslatorDone)

        case .fetchTagTranslatorDone(let result):
            return .none

        case .fetchEhProfileIndex:
            return VerifyEhProfileRequest().effect.map(SettingAction.fetchEhProfileIndexDone)

        case .fetchEhProfileIndexDone(let result):
            var effects = [Effect<SettingAction, Never>]()

            if case .success(let (profileValue, profileNotFound)) = result {
                if let profileValue = profileValue {
                    let hostURL = Defaults.URL.host
                    let profileValueString = String(profileValue)
                    let selectedProfileKey = Defaults.Cookie.selectedProfile

                    let cookieValue =  environment.cookiesClient.getCookie(hostURL, selectedProfileKey)
                    if cookieValue.rawValue != profileValueString {
                        effects.append(
                            environment.cookiesClient.setCookie(
                                hostURL, selectedProfileKey, profileValueString
                            )
                            .fireAndForget()
                        )
                    }
                } else if profileNotFound {
                    effects.append(.init(value: .createDefaultEhProfile))
                } else {
                    let message = "Found profile but failed in parsing value."
                    effects.append(environment.loggerClient.error(message, nil).fireAndForget())
                }
            }
            return effects.isEmpty ? .none : .merge(effects)

        case .fetchFavoriteNames:
            return FavoriteNamesRequest().effect.map(SettingAction.fetchFavoriteNamesDone)

        case .fetchFavoriteNamesDone(let result):
            if case .success(let names) = result {
                state.user.favoriteNames = names
            }
            return .none

        case .setRoute(let route):
            state.route = route
            return .none

        case .account(.login(.loginDone)):
            var effects: [Effect<SettingAction, Never>] = [
                environment.cookiesClient.removeYay().fireAndForget(),
                environment.cookiesClient.fulfillAnotherHostField().fireAndForget()
            ]

            effects.append(.init(value: .fetchIgneous))
            if environment.cookiesClient.didLogin() {
                effects.append(contentsOf: [
                    .init(value: .fetchUserInfo),
                    .init(value: .fetchFavoriteNames),
                    .init(value: .fetchEhProfileIndex)
                ])
            }

            return effects.isEmpty ? .none : .merge(effects)

        case .account(.logoutConfirmButtonTapped):
            state.user = User()
            return .merge(
                environment.cookiesClient.clearAll().fireAndForget(),
                environment.databaseClient.removeImageURLs().fireAndForget(),
                environment.libraryClient.clearWebImageDiskCache().fireAndForget()
            )

        case .account:
            return .none
        }
    }
    .binding(),
    accountSettingReducer.pullback(
        state: \.accountSettingState,
        action: /SettingAction.account,
        environment: {
            .init(
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    )
)
