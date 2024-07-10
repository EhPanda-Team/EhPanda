//
//  SettingReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/31.
//

import Foundation
import ComposableArchitecture

struct SettingReducer: Reducer {
    enum Route: Int, Equatable, Hashable, Identifiable, CaseIterable {
        var id: Int { rawValue }

        case account
        case general
        case appearance
        case reading
        case laboratory
        case about
    }

    struct State: Equatable {
        // AppEnvStorage
        @BindingState var setting = Setting()
        var tagTranslator = TagTranslator()
        var user = User()

        var hasLoadedInitialSetting = false

        @BindingState var route: Route?
        var tagTranslatorLoadingState: LoadingState = .idle

        var accountSettingState = AccountSettingReducer.State()
        var generalSettingState = GeneralSettingReducer.State()
        var appearanceSettingState = AppearanceSettingReducer.State()

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
            if let galleryPoints = user.galleryPoints,
               let credits = user.credits
            {
                self.user.galleryPoints = galleryPoints
                self.user.credits = credits
            }
        }
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case clearSubStates

        case syncAppIconType
        case syncUserInterfaceStyle
        case syncSetting
        case syncTagTranslator
        case syncUser

        case loadUserSettings
        case onLoadUserSettings(AppEnv)
        case loadUserSettingsDone
        case createDefaultEhProfile
        case fetchIgneous
        case fetchIgneousDone(Result<HTTPURLResponse, AppError>)
        case fetchUserInfo
        case fetchUserInfoDone(Result<User, AppError>)
        case fetchGreeting
        case fetchGreetingDone(Result<Greeting, AppError>)
        case fetchTagTranslator
        case fetchTagTranslatorDone(Result<TagTranslator, AppError>)
        case fetchEhProfileIndex
        case fetchEhProfileIndexDone(Result<VerifyEhProfileResponse, AppError>)
        case fetchFavoriteCategories
        case fetchFavoriteCategoriesDone(Result<[Int: String], AppError>)

        case account(AccountSettingReducer.Action)
        case general(GeneralSettingReducer.Action)
        case appearance(AppearanceSettingReducer.Action)
    }

    @Dependency(\.uiApplicationClient) private var uiApplicationClient
    @Dependency(\.userDefaultsClient) private var userDefaultsClient
    @Dependency(\.appDelegateClient) private var appDelegateClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.libraryClient) private var libraryClient
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.loggerClient) private var loggerClient
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.deviceClient) private var deviceClient
    @Dependency(\.fileClient) private var fileClient
    @Dependency(\.dfClient) private var dfClient

    var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.setting.galleryHost) { _, newValue in
                Reduce { _, _ in
                    .merge(
                        .send(.syncSetting),
                        .run(operation: { _ in userDefaultsClient.setValue(newValue.rawValue, .galleryHost) })
                    )
                }
            }
            .onChange(of: \.setting.enablesTagsExtension) { _, newValue in
                Reduce { _, _ in
                    var effects: [Effect<Action>] = [
                        .send(.syncSetting)
                    ]
                    if newValue {
                        effects.append(.send(.fetchTagTranslator))
                    }
                    return .merge(effects)
                }
            }
            .onChange(of: \.setting.preferredColorScheme) { _, _ in
                Reduce { _, _ in
                    .merge(
                        .send(.syncSetting),
                        .send(.syncUserInterfaceStyle)
                    )
                }
            }
            .onChange(of: \.setting.appIconType) { _, newValue in
                Reduce { _, _ in
                    .merge(
                        .send(.syncSetting),
                        .run { send in
                            _ = await uiApplicationClient.setAlternateIconName(newValue.filename)
                            await send(.syncAppIconType)
                        }
                    )
                }
            }
            .onChange(of: \.setting.autoLockPolicy) { _, newValue in
                Reduce { state, _ in
                    if newValue != .never && state.setting.backgroundBlurRadius == 0 {
                        state.setting.backgroundBlurRadius = 10
                    }
                    return .send(.syncSetting)
                }
            }
            .onChange(of: \.setting.backgroundBlurRadius) { _, newValue in
                Reduce { state, _ in
                    if state.setting.autoLockPolicy != .never && newValue == 0 {
                        state.setting.autoLockPolicy = .never
                    }
                    return .send(.syncSetting)
                }
            }
            .onChange(of: \.setting.enablesLandscape) { _, newValue in
                Reduce { _, _ in
                    var effects: [Effect<Action>] = [
                        .send(.syncSetting)
                    ]
                    if !newValue && !deviceClient.isPad() {
                        effects.append(.run(operation: { _ in appDelegateClient.setPortraitOrientationMask() }))
                    }
                    return .merge(effects)
                }
            }
            .onChange(of: \.setting.maximumScaleFactor) { _, newValue in
                Reduce { state, _ in
                    if state.setting.doubleTapScaleFactor > newValue {
                        state.setting.doubleTapScaleFactor = newValue
                    }
                    return .send(.syncSetting)
                }
            }
            .onChange(of: \.setting.doubleTapScaleFactor) { _, newValue in
                Reduce { state, _ in
                    if state.setting.maximumScaleFactor < newValue {
                        state.setting.maximumScaleFactor = newValue
                    }
                    return .send(.syncSetting)
                }
            }
            .onChange(of: \.setting.bypassesSNIFiltering) { _, newValue in
                Reduce { _, _ in
                    .merge(
                        .send(.syncSetting),
                        .run(operation: { _ in hapticsClient.generateFeedback(.soft) }),
                        .run(operation: { _ in dfClient.setActive(newValue) })
                    )
                }
            }

        Reduce { state, action in
            switch action {
            case .binding(\.$setting):
                return .send(.syncSetting)

            case .binding(\.$route):
                return .none

            case .binding:
                return .merge(
                    .send(.syncUser),
                    .send(.syncSetting),
                    .send(.syncTagTranslator)
                )

            case .setNavigation(let route):
                state.route = route
                return .none

            case .clearSubStates:
                state.accountSettingState = .init()
                state.generalSettingState = .init()
                state.appearanceSettingState = .init()
                return .none

            case .syncAppIconType:
                if let iconName = uiApplicationClient.alternateIconName() {
                    state.setting.appIconType = AppIconType.allCases.filter({
                        iconName.contains($0.filename)
                    }).first ?? .default
                }
                return .none

            case .syncUserInterfaceStyle:
                let style = state.setting.preferredColorScheme.userInterfaceStyle
                return .run(operation: { _ in await uiApplicationClient.setUserInterfaceStyle(style) })

            case .syncSetting:
                return .run { [state] _ in
                    await databaseClient.updateSetting(state.setting)
                }
            case .syncTagTranslator:
                return .run { [state] _ in
                    await databaseClient.updateTagTranslator(state.tagTranslator)
                }
            case .syncUser:
                return .run { [state] _ in
                    await databaseClient.updateUser(state.user)
                }

            case .loadUserSettings:
                return .run { send in
                    let appEnv = await databaseClient.fetchAppEnv()
                    await send(.onLoadUserSettings(appEnv))
                }

            case .onLoadUserSettings(let appEnv):
                state.setting = appEnv.setting
                state.tagTranslator = appEnv.tagTranslator
                state.user = appEnv.user
                var effects: [Effect<Action>] = [
                    .send(.syncAppIconType),
                    .send(.loadUserSettingsDone),
                    .send(.syncUserInterfaceStyle),
                    .run { [state] _ in
                        dfClient.setActive(state.setting.bypassesSNIFiltering)
                    }
                ]
                if let value: String = userDefaultsClient.getValue(.galleryHost),
                   let galleryHost = GalleryHost(rawValue: value)
                {
                    state.setting.galleryHost = galleryHost
                }
                if cookieClient.shouldFetchIgneous {
                    effects.append(.send(.fetchIgneous))
                }
                if cookieClient.didLogin {
                    effects.append(contentsOf: [
                        .send(.fetchUserInfo),
                        .send(.fetchGreeting),
                        .send(.fetchFavoriteCategories),
                        .send(.fetchEhProfileIndex)
                    ])
                }
                if state.setting.enablesTagsExtension {
                    effects.append(.send(.fetchTagTranslator))
                }
                return .merge(effects)

            case .loadUserSettingsDone:
                state.hasLoadedInitialSetting = true
                return .none

            case .createDefaultEhProfile:
                return .run(operation: { _ in _ = await EhProfileRequest(action: .create, name: "EhPanda").response() })

            case .fetchIgneous:
                guard cookieClient.didLogin else { return .none }
                return .run { send in
                    let response = await IgneousRequest().response()
                    await send(.fetchIgneousDone(response))
                }

            case .fetchIgneousDone(let result):
                var effects = [Effect<Action>]()
                if case .success(let response) = result {
                    effects.append(.run(operation: { _ in cookieClient.setCredentials(response: response) }))
                }
                effects.append(.send(.account(.loadCookies)))
                return .merge(effects)

            case .fetchUserInfo:
                guard cookieClient.didLogin else { return .none }
                let uid = cookieClient
                    .getCookie(Defaults.URL.host, Defaults.Cookie.ipbMemberId).rawValue
                if !uid.isEmpty {
                    return .run { send in
                        let response = await UserInfoRequest(uid: uid).response()
                        await send(.fetchUserInfoDone(response))
                    }
                }
                return .none

            case .fetchUserInfoDone(let result):
                if case .success(let user) = result {
                    state.updateUser(user)
                    return .send(.syncUser)
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

                guard cookieClient.didLogin,
                      state.setting.showsNewDawnGreeting
                else { return .none }
                let requestEffect = Effect.run { send in
                    let response = await GreetingRequest().response()
                    await send(Action.fetchGreetingDone(response))
                }
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
                    return .send(.syncUser)
                case .failure(let error):
                    if case .parseFailed = error {
                        var greeting = Greeting()
                        greeting.updateTime = Date()
                        state.setGreeting(greeting)
                        return .send(.syncUser)
                    }
                }
                return .none

            case .fetchTagTranslator:
                guard state.tagTranslatorLoadingState != .loading,
                      !state.tagTranslator.hasCustomTranslations,
                      let language = TranslatableLanguage.current
                else { return .none }
                state.tagTranslatorLoadingState = .loading

                var databaseEffect: Effect<Action>?
                if state.tagTranslator.language != language {
                    state.tagTranslator = TagTranslator(language: language)
                    databaseEffect = .send(.syncTagTranslator)
                }
                let updatedDate = state.tagTranslator.updatedDate
                let requestEffect = Effect.run { send in
                    let response = await TagTranslatorRequest(language: language, updatedDate: updatedDate).response()
                    await send(Action.fetchTagTranslatorDone(response))
                }
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
                    return .send(.syncTagTranslator)
                case .failure(let error):
                    state.tagTranslatorLoadingState = .failed(error)
                }
                return .none

            case .fetchEhProfileIndex:
                guard cookieClient.didLogin else { return .none }
                return .run { send in
                    let response = await VerifyEhProfileRequest().response()
                    await send(.fetchEhProfileIndexDone(response))
                }

            case .fetchEhProfileIndexDone(let result):
                var effects = [Effect<Action>]()

                if case .success(let response) = result {
                    if let profileValue = response.profileValue {
                        let hostURL = Defaults.URL.host
                        let profileValueString = String(profileValue)
                        let selectedProfileKey = Defaults.Cookie.selectedProfile

                        let cookieValue = cookieClient.getCookie(hostURL, selectedProfileKey)
                        if cookieValue.rawValue != profileValueString {
                            effects.append(
                                .run { _ in
                                    cookieClient.setOrEditCookie(
                                        for: hostURL, key: selectedProfileKey, value: profileValueString
                                    )
                                }
                            )
                        }
                    } else if response.isProfileNotFound {
                        effects.append(.send(.createDefaultEhProfile))
                    } else {
                        let message = "Found profile but failed in parsing value."
                        effects.append(.run(operation: { _ in loggerClient.error(message, nil) }))
                    }
                }
                return effects.isEmpty ? .none : .merge(effects)

            case .fetchFavoriteCategories:
                guard cookieClient.didLogin else { return .none }
                return .run { send in
                    let response = await FavoriteCategoriesRequest().response()
                    await send(.fetchFavoriteCategoriesDone(response))
                }

            case .fetchFavoriteCategoriesDone(let result):
                if case .success(let categories) = result {
                    state.user.favoriteCategories = categories
                }
                return .none

            case .account(.login(.loginDone)):
                return .merge(
                    .run(operation: { _ in cookieClient.removeYay() }),
                    .run(operation: { _ in cookieClient.syncExCookies() }),
                    .run(operation: { _ in cookieClient.fulfillAnotherHostField() }),
                    .send(.fetchIgneous),
                    .send(.fetchUserInfo),
                    .send(.fetchFavoriteCategories),
                    .send(.fetchEhProfileIndex)
                )

            case .account(.onLogoutConfirmButtonTapped):
                state.user = User()
                return .merge(
                    .send(.syncUser),
                    .run(operation: { _ in cookieClient.clearAll() }),
                    .run(operation: { _ in await databaseClient.removeImageURLs() }),
                    .run(operation: { _ in libraryClient.clearWebImageDiskCache() })
                )

            case .account:
                return .none

            case .general(.onTranslationsFilePicked(let url)):
                return .run { send in
                    let result = await fileClient.importTagTranslator(url)
                    await send(.fetchTagTranslatorDone(result))
                }

            case .general(.onRemoveCustomTranslations):
                state.tagTranslator.hasCustomTranslations = false
                state.tagTranslator.translations = .init()
                return .send(.syncTagTranslator)

            case .general:
                return .none

            case .appearance:
                return .none
            }
        }

        Scope(state: \.accountSettingState, action: /Action.account, child: AccountSettingReducer.init)
        Scope(state: \.generalSettingState, action: /Action.general, child: GeneralSettingReducer.init)
        Scope(state: \.appearanceSettingState, action: /Action.appearance, child: AppearanceSettingReducer.init)
    }
}
