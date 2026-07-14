import Foundation
import AppModels
import Sharing
import ComposableArchitecture
import ApplicationClient
import HapticsClient
import LibraryClient
import DFClient
import FileClient
import CookieClient

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
        // `setting` is stored directly in `@Shared(.setting)`. The parent only reads it for launch
        // reconciliation and its non-binding syncs (e.g. `syncAppIconTypeDone`); each Setting screen
        // reads and writes it through its own `@Shared`/`@SharedReader`, so there is no working copy and
        // no `.binding` cascade here. `user` is likewise shared. `tagTranslator` is derived,
        // re-downloadable data: it lives in memory only and is rebuilt at launch from the cached raw
        // JSON; only its thin `tagTranslatorInfo` metadata persists (see `AppSharedKeys`).
        @Shared(.setting) public var setting: Setting
        @Shared(.tagTranslator) public var tagTranslator: TagTranslator
        @Shared(.tagTranslatorInfo) public var tagTranslatorInfo: TagTranslatorInfo
        @Shared(.user) public var user: User
        @Shared(.greeting) public var greeting: Greeting?

        public var hasLoadedInitialSetting = false

        public var path = StackState<SettingPath.State>()
        public var tagTranslatorLoadingState: LoadingState = .idle

        public init() {}

        mutating func setGreeting(_ newGreeting: Greeting) {
            $greeting.withLock { $0.mergeNewer(newGreeting) }
        }

        mutating func updateUser(_ user: User) {
            $user.withLock { current in
                if let displayName = user.displayName {
                    current.displayName = displayName
                }
                if let avatarURL = user.avatarURL {
                    current.avatarURL = avatarURL
                }
                if let galleryPoints = user.galleryPoints,
                   let credits = user.credits {
                    current.galleryPoints = galleryPoints
                    current.credits = credits
                }
            }
        }
    }

    public enum Action {
        case path(StackActionOf<SettingPath>)
        case settingRowTapped(RootScreen)
        case pushLogin

        case syncAppIconType
        case syncAppIconTypeDone(String?)
        case syncUserInterfaceStyle

        case loadUserSettings
        case loadUserSettingsDone
        case createDefaultEhProfile(GalleryHost)
        case fetchIgneous
        case fetchIgneousDone(Result<HTTPURLResponse, AppError>)
        case fetchUserInfo
        case fetchUserInfoDone(Result<User, AppError>)
        case fetchGreeting
        case fetchGreetingDone(Result<Greeting, AppError>)
        case fetchTagTranslator
        case fetchTagTranslatorDone(Result<TagTranslator, AppError>)
        case rebuildTagTranslator
        case tagTranslatorRebuilt(TagTranslator)
        case fetchEhProfileIndex
        case fetchEhProfileIndexDone(GalleryHost, Result<VerifyEhProfileResponse, AppError>)
        case fetchFavoriteCategories
        case fetchFavoriteCategoriesDone(Result<[Int: String], AppError>)
        case igneousRefreshed
    }

    @Dependency(\.applicationClient) var applicationClient
    @Dependency(\.libraryClient) var libraryClient
    @Dependency(\.cookieClient) var cookieClient
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.dfClient) var dfClient

    public init() {}

    public var body: some Reducer<State, Action> { reducerBody }
}
