//
//  SettingReducer.swift
//  EhPanda
//

import Foundation
import ComposableArchitecture

@Reducer
struct SettingReducer {
    @CasePathable
    enum Route: Int, Equatable, Hashable, Identifiable, CaseIterable {
        var id: Int { rawValue }

        case account
        case general
        case appearance
        case reading
        case downloads
        case laboratory
        case about
    }

    @ObservableState
    struct State: Equatable {
        // AppEnvStorage
        var setting = Setting()
        var tagTranslator = TagTranslator()
        var user = User()

        var hasLoadedInitialSetting = false

        var route: Route?
        var tagTranslatorLoadingState: LoadingState = .idle

        var accountSettingState = AccountSettingReducer.State()
        var generalSettingState = GeneralSettingReducer.State()
        var appearanceSettingState = AppearanceSettingReducer.State()

        mutating func setGreeting(_ greeting: Greeting) {
            guard let currDate = greeting.updateTime else { return }

            if let prevGreeting = user.greeting,
               let prevDate = prevGreeting.updateTime,
               prevDate < currDate {
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
               let credits = user.credits {
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
        case syncAppIconTypeDone(String?)
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

    @Dependency(\.uiApplicationClient) var uiApplicationClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.appDelegateClient) var appDelegateClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.libraryClient) var libraryClient
    @Dependency(\.hapticsClient) var hapticsClient
    @Dependency(\.loggerClient) var loggerClient
    @Dependency(\.cookieClient) var cookieClient
    @Dependency(\.deviceClient) var deviceClient
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.dfClient) var dfClient

    var body: some Reducer<State, Action> { reducerBody }
}
