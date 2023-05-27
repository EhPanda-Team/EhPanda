//
//  GeneralSettingReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/03.
//

import Kingfisher
import LocalAuthentication
import ComposableArchitecture

struct GeneralSettingReducer: ReducerProtocol {
    enum Route {
        case logs
        case clearCache
        case removeCustomTranslations
    }

    struct State: Equatable {
        @BindingState var route: Route?

        var loadingState: LoadingState = .idle
        var diskImageCacheSize = "0 KB"
        var passcodeNotSet = false

        var logsState = LogsReducer.State()
    }

    enum Action: BindableAction, Equatable {
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

        case logs(LogsReducer.Action)
    }

    @Dependency(\.authorizationClient) private var authorizationClient
    @Dependency(\.uiApplicationClient) private var uiApplicationClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.libraryClient) private var libraryClient

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Reduce { state, action in
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
                    libraryClient.clearWebImageDiskCache().fireAndForget(),
                    databaseClient.removeImageURLs().fireAndForget(),
                    .init(value: .calculateWebImageDiskCache)
                )

            case .checkPasscodeSetting:
                state.passcodeNotSet = authorizationClient.passcodeNotSet()
                return .none

            case .navigateToSystemSetting:
                return uiApplicationClient.openSettings().fireAndForget()

            case .calculateWebImageDiskCache:
                return libraryClient.calculateWebImageDiskCacheSize()
                    .map(Action.calculateWebImageDiskCacheDone)

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

        Scope(state: \.logsState, action: /Action.logs, child: LogsReducer.init)
    }
}
