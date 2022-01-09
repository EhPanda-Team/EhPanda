//
//  SettingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/31.
//

import ComposableArchitecture

struct SettingState: Equatable {
    // AppEnvStorage
    @BindableState var setting = Setting()
    @BindableState var searchFilter = Filter()
    @BindableState var globalFilter = Filter()
    @BindableState var watchedFilter = Filter()
    var tagTranslator = TagTranslator()
    var user = User()

    @BindableState var route: SettingRoute?
    var tagTranslatorLoadingState: LoadingState = .idle

    var accountSettingState = AccountSettingState()
    var generalSettingState = GeneralSettingState()
    var appearanceSettingState = AppearanceSettingState()

    mutating func setGreeting(_ greeting: Greeting) {
        guard let currDate = greeting.updateTime else { return }

        if let prevGreeting = user.greeting,
           let prevDate = prevGreeting.updateTime,
           prevDate < currDate
        {
            user.greeting = greeting
        } else if user.greeting == nil {
            user.greeting = greeting
        }
    }
    mutating func updateUser(_ user: User) {
        if let displayName = user.displayName {
            self.user.displayName = displayName
        }
        if let avatarURL = user.avatarURL {
            self.user.avatarURL = avatarURL
        }
        if let currentGP = user.currentGP,
           let currentCredits = user.currentCredits
        {
            self.user.currentGP = currentGP
            self.user.currentCredits = currentCredits
        }
    }
}

enum SettingAction: BindableAction {
    case binding(BindingAction<SettingState>)

    case syncAppIconType
    case syncUserInterfaceStyle

    case loadUserSettings
    case loadUserSettingsDone
    case createDefaultEhProfile
    case fetchIgneous
    case fetchUserInfo
    case fetchUserInfoDone(Result<User, AppError>)
    case fetchGreeting
    case fetchGreetingDone(Result<Greeting, AppError>)
    case fetchTagTranslator
    case fetchTagTranslatorDone(Result<TagTranslator, AppError>)
    case fetchEhProfileIndex
    case fetchEhProfileIndexDone(Result<(Int?, Bool), AppError>)
    case fetchFavoriteNames
    case fetchFavoriteNamesDone(Result<[Int: String], AppError>)

    case setNavigation(SettingRoute?)

    case account(AccountSettingAction)
    case general(GeneralSettingAction)
    case appearance(AppearanceSettingAction)
}

struct SettingEnvironment {
    let dfClient: DFClient
    let fileClient: FileClient
    let deviceClient: DeviceClient
    let loggerClient: LoggerClient
    let hapticClient: HapticClient
    let libraryClient: LibraryClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let appDelegateClient: AppDelegateClient
    let userDefaultsClient: UserDefaultsClient
    let uiApplicationClient: UIApplicationClient
    let authorizationClient: AuthorizationClient
}

let settingReducer = Reducer<SettingState, SettingAction, SettingEnvironment>.combine(
    .init { state, action, environment in
        switch action {
        case .binding(\.$setting.galleryHost):
            return .merge(
                environment.userDefaultsClient.setString(
                    state.setting.galleryHost.rawValue,
                    AppUserDefaults.galleryHost.rawValue
                )
                .fireAndForget(),
                environment.databaseClient.updateSetting(state.setting).fireAndForget()
            )

        case .binding(\.$setting.translatesTags):
            var effects: [Effect<SettingAction, Never>] = [
                environment.databaseClient.updateSetting(state.setting).fireAndForget()
            ]
            if state.setting.translatesTags {
                effects.append(.init(value: .fetchTagTranslator))
            }
            return .merge(effects)

        case .binding(\.$setting.preferredColorScheme):
            return .merge(
                .init(value: .syncUserInterfaceStyle),
                environment.databaseClient.updateSetting(state.setting).fireAndForget()
            )

        case .binding(\.$setting.appIconType):
            return .merge(
                environment.databaseClient.updateSetting(state.setting).fireAndForget(),
                environment.uiApplicationClient.setAlternateIconName(state.setting.appIconType.iconName)
                    .map { _ in SettingAction.syncAppIconType }
            )

        case .binding(\.$setting.prefersLandscape):
            var effects: [Effect<SettingAction, Never>] = [
                environment.databaseClient.updateSetting(state.setting).fireAndForget()
            ]
            if !state.setting.prefersLandscape && !environment.deviceClient.isPad() {
                effects.append(environment.appDelegateClient.setPortraitOrientationMask().fireAndForget())
            }
            return .merge(effects)

        case .binding(\.$setting.maximumScaleFactor):
            if state.setting.doubleTapScaleFactor > state.setting.maximumScaleFactor {
                state.setting.doubleTapScaleFactor = state.setting.maximumScaleFactor
            }
            return environment.databaseClient.updateSetting(state.setting).fireAndForget()

        case .binding(\.$setting.doubleTapScaleFactor):
            if state.setting.maximumScaleFactor < state.setting.doubleTapScaleFactor {
                state.setting.maximumScaleFactor = state.setting.doubleTapScaleFactor
            }
            return environment.databaseClient.updateSetting(state.setting).fireAndForget()

        case .binding(\.$setting.bypassesSNIFiltering):
            return .merge(
                environment.hapticClient.generateFeedback(.soft).fireAndForget(),
                environment.databaseClient.updateSetting(state.setting).fireAndForget(),
                environment.dfClient.setActive(state.setting.bypassesSNIFiltering).fireAndForget()
            )

        case .binding(\.$searchFilter):
            return environment.databaseClient.updateSearchFilter(state.searchFilter).fireAndForget()

        case .binding(\.$globalFilter):
            return environment.databaseClient.updateGlobalFilter(state.globalFilter).fireAndForget()

        case .binding(\.$watchedFilter):
            return environment.databaseClient.updateWatchedFilter(state.watchedFilter).fireAndForget()

        case .binding:
            return .none

        case .syncAppIconType:
            if let iconName = environment.uiApplicationClient.alternateIconName() {
                state.setting.appIconType = AppIconType.allCases.filter({
                    iconName.contains($0.iconName)
                }).first ?? .default
            }
            return .none

        case .syncUserInterfaceStyle:
            let style = state.setting.preferredColorScheme.userInterfaceStyle
            return environment.uiApplicationClient.setUserInterfaceStyle(style)
                .subscribe(on: DispatchQueue.main).fireAndForget()

        case .loadUserSettings:
            let appEnv = environment.databaseClient.fetchAppEnv()
            state.setting = appEnv.setting
            state.searchFilter = appEnv.searchFilter
            state.globalFilter = appEnv.globalFilter
            state.watchedFilter = appEnv.watchedFilter
            state.tagTranslator = appEnv.tagTranslator
            state.user = appEnv.user
            return .init(value: .loadUserSettingsDone)

        case .loadUserSettingsDone:
            var effects: [Effect<SettingAction, Never>] = [
                .init(value: .syncAppIconType),
                .init(value: .syncUserInterfaceStyle)
            ]

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
                    .init(value: .fetchGreeting),
                    .init(value: .fetchFavoriteNames),
                    .init(value: .fetchEhProfileIndex)
                ])
            }
            if state.setting.translatesTags {
                effects.append(.init(value: .fetchTagTranslator))
            }

            return .merge(effects)

        case .createDefaultEhProfile:
            return EhProfileRequest(action: .create, name: "EhPanda").effect.fireAndForget()

        case .fetchIgneous:
            return IgneousRequest().effect.fireAndForget()

        case .fetchUserInfo:
            let uid = environment.cookiesClient.getCookie(Defaults.URL.host, Defaults.Cookie.ipbMemberId).rawValue
            if !uid.isEmpty {
                return UserInfoRequest(uid: uid).effect.map(SettingAction.fetchUserInfoDone)
            }
            return .none

        case .fetchUserInfoDone(let result):
            if case .success(let user) = result {
                state.updateUser(user)
                return environment.databaseClient.updateUser(user).fireAndForget()
            }
            return .none

        case .fetchGreeting:
            func verifyDate(with updateTime: Date?) -> Bool {
                guard let updateTime = updateTime else { return true }

                let currentTime = Date()
                let formatter = DateFormatter()
                formatter.locale = Locale.current
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = Defaults.DateFormat.greeting

                let currentTimeString = formatter.string(from: currentTime)
                if let currentDay = formatter.date(from: currentTimeString) {
                    return currentTime > currentDay && updateTime < currentDay
                }

                return false
            }

            guard state.setting.showNewDawnGreeting else { return .none }
            let requestEffect = GreetingRequest().effect
                .map(SettingAction.fetchGreetingDone)
            if let greeting = state.user.greeting {
                if verifyDate(with: greeting.updateTime) {
                    return requestEffect
                }
            } else {
                return requestEffect
            }
            return .none

        case .fetchGreetingDone(let result):
            switch result {
            case .success(let greeting):
                state.setGreeting(greeting)
                return environment.databaseClient.updateUser(state.user).fireAndForget()
            case .failure(let error):
                if case .parseFailed = error {
                    var greeting = Greeting()
                    greeting.updateTime = Date()
                    state.setGreeting(greeting)
                    return environment.databaseClient.updateUser(state.user).fireAndForget()
                }
            }
            return .none

        case .fetchTagTranslator:
            guard state.tagTranslatorLoadingState != .loading,
                  let preferredLanguage = Locale.preferredLanguages.first,
                  let language = TranslatableLanguage.allCases.compactMap({ lang in
                      preferredLanguage.contains(lang.languageCode) ? lang : nil
                  }).first
            else {
                state.tagTranslator = TagTranslator()
                return environment.databaseClient.updateTagTranslator(TagTranslator()).fireAndForget()
            }
            state.tagTranslatorLoadingState = .loading

            var databaseEffect: Effect<SettingAction, Never>?
            if state.tagTranslator.language != language {
                state.tagTranslator = TagTranslator()
                databaseEffect = environment.databaseClient.updateTagTranslator(TagTranslator()).fireAndForget()
            }
            let updatedDate = state.tagTranslator.updatedDate
            let requestEffect = TagTranslatorRequest(language: language, updatedDate: updatedDate)
                .effect.map(SettingAction.fetchTagTranslatorDone)
            if let databaseEffect = databaseEffect {
                return .merge(databaseEffect, requestEffect)
            } else {
                return requestEffect
            }

        case .fetchTagTranslatorDone(let result):
            state.tagTranslatorLoadingState = .idle
            switch result {
            case .success(let tagTranslator):
                state.tagTranslator = tagTranslator
                return environment.databaseClient.updateTagTranslator(tagTranslator).fireAndForget()
            case .failure(let error):
                state.tagTranslatorLoadingState = .failed(error)
            }
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

        case .setNavigation(let route):
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
                environment.databaseClient.updateUser(User()).fireAndForget(),
                environment.libraryClient.clearWebImageDiskCache().fireAndForget()
            )

        case .account:
            return .none

        case .general:
            return .none

        case .appearance:
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
    ),
    generalSettingReducer.pullback(
        state: \.generalSettingState,
        action: /SettingAction.general,
        environment: {
            .init(
                fileClient: $0.fileClient,
                loggerClient: $0.loggerClient,
                libraryClient: $0.libraryClient,
                databaseClient: $0.databaseClient,
                uiApplicationClient: $0.uiApplicationClient,
                authorizationClient: $0.authorizationClient
            )
        }
    ),
    appearanceSettingReducer.pullback(
        state: \.appearanceSettingState,
        action: /SettingAction.appearance,
        environment: { _ in
            .init()
        }
    )
)
