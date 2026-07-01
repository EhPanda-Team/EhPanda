import Foundation
import AppModels
import ComposableArchitecture
import UserDefaultsClient
import ApplicationClient
import HapticsClient
import LibraryClient
import DatabaseClient
import DFClient
import FileClient
import CookieClient
import DeviceClient
import AppDelegateClient

@Reducer
public struct SettingReducer: Sendable {
    // The top-level Setting screens listed in the root menu. Each maps 1:1 to a `SettingPath`
    // element that `settingRowTapped` appends when its row is tapped.
    public enum RootScreen: Int, Equatable, Hashable, Identifiable, CaseIterable, Sendable {
        public var id: Int { rawValue }

        case account
        case general
        case appearance
        case download
        case reading
        case laboratory
        case about

        var pathElement: SettingPath.State {
            switch self {
            case .account:
                return .account(.init())
            case .general:
                return .general(.init())
            case .appearance:
                return .appearance(.init())
            case .download:
                return .download(.init())
            case .reading:
                return .reading(.init())
            case .laboratory:
                return .laboratory(.init())
            case .about:
                return .about(.init())
            }
        }
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        // AppEnvStorage
        public var setting = Setting()
        public var tagTranslator = TagTranslator()
        public var user = User()

        public var hasLoadedInitialSetting = false

        public var path = StackState<SettingPath.State>()
        public var tagTranslatorLoadingState: LoadingState = .idle

        public init() {}

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

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case path(StackActionOf<SettingPath>)
        case settingRowTapped(RootScreen)
        case pushLogin

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
        case igneousRefreshed
    }

    @Dependency(\.applicationClient) var applicationClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.appDelegateClient) var appDelegateClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.libraryClient) var libraryClient
    @Dependency(\.hapticsClient) var hapticsClient
    @Dependency(\.cookieClient) var cookieClient
    @Dependency(\.deviceClient) var deviceClient
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.dfClient) var dfClient

    public init() {}

    public var body: some Reducer<State, Action> { reducerBody }
}
