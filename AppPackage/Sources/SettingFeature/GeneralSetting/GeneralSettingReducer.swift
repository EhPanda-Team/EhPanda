import LocalAuthentication
import AppModels
import ComposableArchitecture
import AuthorizationClient
import ApplicationClient
import LibraryClient
import DatabaseClient
import OSLogExt

private let logger = Logger(category: .init(describing: GeneralSettingReducer.self))

@Reducer
public struct GeneralSettingReducer: Sendable {
    @CasePathable
    public enum Route: Sendable {
        case appActivityLogs
        case clearCache
        case removeCustomTranslations
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        public var route: Route?

        public var loadingState: LoadingState = .idle
        public var diskImageCacheSize = "0 KB"
        public var passcodeNotSet = false

        public var appActivityLogsState = AppActivityLogsReducer.State()
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case clearSubStates
        case onTranslationsFilePicked(URL)
        case onRemoveCustomTranslations

        case clearWebImageCache
        case checkPasscodeSetting
        case navigateToSystemSetting
        case calculateWebImageDiskCache
        case calculateWebImageDiskCacheDone(UInt?)

        case appActivityLogs(AppActivityLogsReducer.Action)
    }

    @Dependency(\.authorizationClient) private var authorizationClient
    @Dependency(\.applicationClient) private var applicationClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.libraryClient) private var libraryClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.route) { _, state in
                state.route == nil ? .send(.clearSubStates) : .none
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .send(.clearSubStates) : .none

            case .clearSubStates:
                // The activity-logs pump is app-wide and always alive; never reset it on navigation.
                return .none

            case .onTranslationsFilePicked:
                return .none

            case .onRemoveCustomTranslations:
                return .none

            case .clearWebImageCache:
                return .run { send in
                    async let removeCachedImages: Void =
                        libraryClient.removeAllCachedImages()
                    async let removeImageURLs: Void =
                        databaseClient.removeImageURLs()
                    _ = await (removeCachedImages, removeImageURLs)
                    logger.notice("Cleared image cache.")
                    await send(.calculateWebImageDiskCache)
                }

            case .checkPasscodeSetting:
                state.passcodeNotSet = authorizationClient.passcodeNotSet()
                return .none

            case .navigateToSystemSetting:
                return .run(operation: { _ in await applicationClient.openSettings() })

            case .calculateWebImageDiskCache:
                return .run { send in
                    let size = await libraryClient.calculateWebImageDiskCacheSize()
                    await send(.calculateWebImageDiskCacheDone(size))
                }

            case .calculateWebImageDiskCacheDone(let bytes):
                guard let bytes = bytes else { return .none }
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = .useAll
                state.diskImageCacheSize = formatter.string(fromByteCount: .init(bytes))
                return .none

            case .appActivityLogs:
                return .none
            }
        }

        Scope(state: \.appActivityLogsState, action: \.appActivityLogs, child: AppActivityLogsReducer.init)
    }
}
