import Foundation
import AppModels
import Sharing
import ComposableArchitecture
import UserDefaultsClient
import ApplicationClient
import HapticsClient
import LibraryClient
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
        // `setting` is stored directly in `@Shared(.setting)`, so every mutation — form bindings, the
        // cross-field `.onChange` fixups, and non-binding syncs like `syncAppIconTypeDone` — persists
        // atomically. There is no working copy to keep in step. `user` is likewise shared.
        // `tagTranslator` is derived, re-downloadable data: it lives in memory only and is rebuilt at
        // launch from the cached raw JSON; only its thin `tagTranslatorInfo` metadata persists (see
        // `AppSharedKeys`).
        @Shared(.setting) public var setting: Setting
        /// A write-through view of `setting` for SwiftUI bindings. `@Shared`'s own value setter is
        /// deprecated (it can't take exclusive access), so binding `$store.setting.x` directly warns;
        /// bind `$store.settingBinding.x` instead — its setter routes writes through `withLock`, while
        /// still flowing through `BindingReducer` so the cross-field `.onChange(of: \.setting.x)`
        /// cascades keep firing (both read the same shared storage). Reads should use `setting`.
        public var settingBinding: Setting {
            get { setting }
            set { $setting.withLock { $0 = newValue } }
        }
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

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case path(StackActionOf<SettingPath>)
        case settingRowTapped(RootScreen)
        case pushLogin

        case syncAppIconType
        case syncAppIconTypeDone(String?)
        case syncUserInterfaceStyle

        case loadUserSettings
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
        case rebuildTagTranslator
        case tagTranslatorRebuilt(TagTranslator)
        case fetchEhProfileIndex
        case fetchEhProfileIndexDone(Result<VerifyEhProfileResponse, AppError>)
        case fetchFavoriteCategories
        case fetchFavoriteCategoriesDone(Result<[Int: String], AppError>)
        case igneousRefreshed
    }

    @Dependency(\.applicationClient) var applicationClient
    @Dependency(\.userDefaultsClient) var userDefaultsClient
    @Dependency(\.appDelegateClient) var appDelegateClient
    @Dependency(\.libraryClient) var libraryClient
    @Dependency(\.cookieClient) var cookieClient
    @Dependency(\.deviceClient) var deviceClient
    @Dependency(\.fileClient) var fileClient
    @Dependency(\.dfClient) var dfClient

    public init() {}

    public var body: some Reducer<State, Action> { reducerBody }
}
