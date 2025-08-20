//
//  GeneralSettingReducer.swift
//  EhPanda
//

import Kingfisher
import LocalAuthentication
import ComposableArchitecture

@Reducer
struct GeneralSettingReducer {
    @CasePathable
    enum Route {
        case logs
        case clearCache
        case removeCustomTranslations
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?

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

    var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.route) { _, newValue in
                Reduce({ _, _ in newValue == nil ? .send(.clearSubStates) : .none })
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .send(.clearSubStates) : .none

            case .clearSubStates:
                state.logsState = .init()
                return .send(.logs(.teardown))

            case .onTranslationsFilePicked:
                return .none

            case .onRemoveCustomTranslations:
                return .none

            case .clearWebImageCache:
                return .merge(
                    .run(operation: { _ in libraryClient.clearWebImageDiskCache() }),
                    .run(operation: { _ in await databaseClient.removeImageURLs() }),
                    .send(.calculateWebImageDiskCache)
                )

            case .checkPasscodeSetting:
                state.passcodeNotSet = authorizationClient.passcodeNotSet()
                return .none

            case .navigateToSystemSetting:
                return .run(operation: { _ in await uiApplicationClient.openSettings() })

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

            case .logs:
                return .none
            }
        }

        Scope(state: \.logsState, action: \.logs, child: LogsReducer.init)
    }
}
