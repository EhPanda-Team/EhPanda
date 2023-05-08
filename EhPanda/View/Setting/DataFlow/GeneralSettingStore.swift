//
//  GeneralSettingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/03.
//

import Kingfisher
import LocalAuthentication
import ComposableArchitecture

struct GeneralSettingState: Equatable {
    enum Route {
        case logs
        case clearCache
        case removeCustomTranslations
    }

    @BindingState var route: Route?

    var loadingState: LoadingState = .idle
    var diskImageCacheSize = "0 KB"
    var passcodeNotSet = false

    var logsState = LogsState()
}

enum GeneralSettingAction: BindableAction, Equatable {
    case binding(BindingAction<GeneralSettingState>)
    case setNavigation(GeneralSettingState.Route?)
    case clearSubStates
    case onTranslationsFilePicked(URL)
    case onRemoveCustomTranslations

    case clearWebImageCache
    case checkPasscodeSetting
    case navigateToSystemSetting
    case calculateWebImageDiskCache
    case calculateWebImageDiskCacheDone(UInt?)

    case logs(LogsAction)
}

struct GeneralSettingEnvironment {
    let fileClient: FileClient
    let loggerClient: LoggerClient
    let libraryClient: LibraryClient
    let databaseClient: DatabaseClient
    let uiApplicationClient: UIApplicationClient
    let authorizationClient: AuthorizationClient
}

let generalSettingReducer = Reducer<GeneralSettingState, GeneralSettingAction, GeneralSettingEnvironment>.combine(
    .init { state, action, environment in
        switch action {
        case .binding(\.$route):
            return state.route == nil ? .init(value: .clearSubStates) : .none

        case .binding:
            return .none

        case .setNavigation(let route):
            state.route = route
            return route == nil ? .init(value: .clearSubStates) : .none

        case .clearSubStates:
            state.logsState = .init()
            return .init(value: .logs(.teardown))

        case .onTranslationsFilePicked:
            return .none

        case .onRemoveCustomTranslations:
            return .none

        case .clearWebImageCache:
            return .merge(
                environment.libraryClient.clearWebImageDiskCache().fireAndForget(),
                environment.databaseClient.removeImageURLs().fireAndForget(),
                .init(value: .calculateWebImageDiskCache)
            )

        case .checkPasscodeSetting:
            state.passcodeNotSet = environment.authorizationClient.passcodeNotSet()
            return .none

        case .navigateToSystemSetting:
            return environment.uiApplicationClient.openSettings().fireAndForget()

        case .calculateWebImageDiskCache:
            return environment.libraryClient.calculateWebImageDiskCacheSize()
                .map(GeneralSettingAction.calculateWebImageDiskCacheDone)

        case .calculateWebImageDiskCacheDone(let bytes):
            guard let bytes = bytes else { return .none }
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = .useAll
            state.diskImageCacheSize = formatter.string(fromByteCount: .init(bytes))
            return .none

        case .logs:
            return .none
        }
    }
    .binding(),
    logsReducer.pullback(
        state: \.logsState,
        action: /GeneralSettingAction.logs,
        environment: {
            .init(
                fileClient: $0.fileClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    )
)
