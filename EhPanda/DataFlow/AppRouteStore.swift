//
//  AppRouteStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/08.
//

import SwiftUI
import TTProgressHUD
import ComposableArchitecture

struct AppRouteState: Equatable {
    enum Route: Equatable, Hashable {
        case hud
        case setting
        case detail(String)
        case newDawn(Greeting)
    }

    init() {
        _detailState = .init(.init())
    }

    @BindingState var route: Route?
    var hudConfig: TTProgressHUDConfig = .loading

    @Heap var detailState: DetailReducer.State!
}

enum AppRouteAction: BindableAction {
    case binding(BindingAction<AppRouteState>)
    case setNavigation(AppRouteState.Route?)
    case setHUDConfig(TTProgressHUDConfig)
    case clearSubStates

    case detectClipboardURL
    case handleDeepLink(URL)
    case handleGalleryLink(URL)

    case updateReadingProgress(String, Int)

    case fetchGallery(URL, Bool)
    case fetchGalleryDone(URL, Result<Gallery, AppError>)
    case fetchGreetingDone(Result<Greeting, AppError>)

    case detail(DetailReducer.Action)
}

struct AppRouteEnvironment {
    let dfClient: DFClient
    let urlClient: URLClient
    let fileClient: FileClient
    let imageClient: ImageClient
    let deviceClient: DeviceClient
    let loggerClient: LoggerClient
    let hapticsClient: HapticsClient
    let libraryClient: LibraryClient
    let cookieClient: CookieClient
    let databaseClient: DatabaseClient
    let clipboardClient: ClipboardClient
    let appDelegateClient: AppDelegateClient
    let userDefaultsClient: UserDefaultsClient
    let uiApplicationClient: UIApplicationClient
    let authorizationClient: AuthorizationClient
}

let appRouteReducer = Reducer<AppRouteState, AppRouteAction, AppRouteEnvironment>.combine(
    .init { state, action, environment in
        switch action {
        case .binding(\.$route):
            return state.route == nil ? .init(value: .clearSubStates) : .none

        case .binding:
            return .none

        case .setNavigation(let route):
            state.route = route
            return route == nil ? .init(value: .clearSubStates) : .none

        case .setHUDConfig(let config):
            state.hudConfig = config
            return .none

        case .clearSubStates:
            state.detailState = .init()
            return .init(value: .detail(.teardown))

        case .detectClipboardURL:
            let currentChangeCount = environment.clipboardClient.changeCount()
            guard currentChangeCount != environment.userDefaultsClient
                    .getValue(.clipboardChangeCount) else { return .none }
            var effects: [EffectTask<AppRouteAction>] = [
                environment.userDefaultsClient
                    .setValue(currentChangeCount, .clipboardChangeCount).fireAndForget()
            ]
            if let url = environment.clipboardClient.url() {
                effects.append(.init(value: .handleDeepLink(url)))
            }
            return .merge(effects)

        case .handleDeepLink(let url):
            var url = environment.urlClient.resolveAppSchemeURL(url) ?? url
            guard environment.urlClient.checkIfHandleable(url) else { return .none }
            var delay = 0
            if case .detail = state.route {
                delay = 1000
                state.route = nil
                state.detailState = .init()
            }
            let (isGalleryImageURL, _, _) = environment.urlClient.analyzeURL(url)
            let gid = environment.urlClient.parseGalleryID(url)
            guard environment.databaseClient.fetchGallery(gid: gid) == nil else {
                return .init(value: .handleGalleryLink(url))
                    .delay(for: .milliseconds(delay + 250), scheduler: DispatchQueue.main).eraseToEffect()
            }
            return .init(value: .fetchGallery(url, isGalleryImageURL))
                .delay(for: .milliseconds(delay), scheduler: DispatchQueue.main).eraseToEffect()

        case .handleGalleryLink(let url):
            let (_, pageIndex, commentID) = environment.urlClient.analyzeURL(url)
            let gid = environment.urlClient.parseGalleryID(url)
            var effects = [EffectTask<AppRouteAction>]()
            state.detailState = .init()
            effects.append(.init(value: .detail(.fetchDatabaseInfos(gid))))
            if let pageIndex = pageIndex {
                effects.append(.init(value: .updateReadingProgress(gid, pageIndex)))
                effects.append(
                    .init(value: .detail(.setNavigation(.reading)))
                        .delay(for: .milliseconds(500), scheduler: DispatchQueue.main).eraseToEffect()
                )
            } else if let commentID = commentID {
                state.detailState.commentsState?.scrollCommentID = commentID
                effects.append(
                    .init(value: .detail(.setNavigation(.comments(url))))
                        .delay(for: .milliseconds(500), scheduler: DispatchQueue.main).eraseToEffect()
                )
            }
            effects.append(.init(value: .setNavigation(.detail(gid))))
            return .merge(effects)

        case .updateReadingProgress(let gid, let progress):
            guard !gid.isEmpty else { return .none }
            return environment.databaseClient
                .updateReadingProgress(gid: gid, progress: progress).fireAndForget()

        case .fetchGallery(let url, let isGalleryImageURL):
            state.route = .hud
            return GalleryReverseRequest(url: url, isGalleryImageURL: isGalleryImageURL)
                .effect.map({ AppRouteAction.fetchGalleryDone(url, $0) })

        case .fetchGalleryDone(let url, let result):
            state.route = nil
            switch result {
            case .success(let gallery):
                return .merge(
                    environment.databaseClient.cacheGalleries([gallery]).fireAndForget(),
                    .init(value: .handleGalleryLink(url))
                )
            case .failure:
                return .init(value: .setHUDConfig(.error))
                    .delay(for: .milliseconds(500), scheduler: DispatchQueue.main).eraseToEffect()
            }

        case .fetchGreetingDone(let result):
            if case .success(let greeting) = result, !greeting.gainedNothing {
                return .init(value: .setNavigation(.newDawn(greeting)))
            }
            return .none

        case .detail:
            return .none
        }
    }
    .haptics(
        unwrapping: \.route,
        case: /AppRouteState.Route.newDawn,
        hapticsClient: \.hapticsClient
    )
    .haptics(
        unwrapping: \.route,
        case: /AppRouteState.Route.detail,
        hapticsClient: \.hapticsClient
    )
    .binding()
//    ,
//    detailReducer.pullback(
//        state: \.detailState,
//        action: /AppRouteAction.detail,
//        environment: {
//            .init(
//                urlClient: $0.urlClient,
//                fileClient: $0.fileClient,
//                imageClient: $0.imageClient,
//                deviceClient: $0.deviceClient,
//                hapticsClient: $0.hapticsClient,
//                cookieClient: $0.cookieClient,
//                databaseClient: $0.databaseClient,
//                clipboardClient: $0.clipboardClient,
//                appDelegateClient: $0.appDelegateClient,
//                uiApplicationClient: $0.uiApplicationClient
//            )
//        }
//    )
)
