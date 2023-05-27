//
//  AppRouteReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/08.
//

import SwiftUI
import TTProgressHUD
import ComposableArchitecture

struct AppRouteReducer: ReducerProtocol {
    enum Route: Equatable, Hashable {
        case hud
        case setting
        case detail(String)
        case newDawn(Greeting)
    }

    struct State: Equatable {
        @BindingState var route: Route?
        var hudConfig: TTProgressHUDConfig = .loading

        @Heap var detailState: DetailReducer.State!

        init() {
            _detailState = .init(.init())
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
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

    @Dependency(\.userDefaultsClient) private var userDefaultsClient
    @Dependency(\.clipboardClient) private var clipboardClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.urlClient) private var urlClient

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

            case .setHUDConfig(let config):
                state.hudConfig = config
                return .none

            case .clearSubStates:
                state.detailState = .init()
                return .init(value: .detail(.teardown))

            case .detectClipboardURL:
                let currentChangeCount = clipboardClient.changeCount()
                guard currentChangeCount != userDefaultsClient
                        .getValue(.clipboardChangeCount) else { return .none }
                var effects: [EffectTask<Action>] = [
                    userDefaultsClient
                        .setValue(currentChangeCount, .clipboardChangeCount).fireAndForget()
                ]
                if let url = clipboardClient.url() {
                    effects.append(.init(value: .handleDeepLink(url)))
                }
                return .merge(effects)

            case .handleDeepLink(let url):
                let url = urlClient.resolveAppSchemeURL(url) ?? url
                guard urlClient.checkIfHandleable(url) else { return .none }
                var delay = 0
                if case .detail = state.route {
                    delay = 1000
                    state.route = nil
                    state.detailState = .init()
                }
                let (isGalleryImageURL, _, _) = urlClient.analyzeURL(url)
                let gid = urlClient.parseGalleryID(url)
                guard databaseClient.fetchGallery(gid: gid) == nil else {
                    return .init(value: .handleGalleryLink(url))
                        .delay(for: .milliseconds(delay + 250), scheduler: DispatchQueue.main).eraseToEffect()
                }
                return .init(value: .fetchGallery(url, isGalleryImageURL))
                    .delay(for: .milliseconds(delay), scheduler: DispatchQueue.main).eraseToEffect()

            case .handleGalleryLink(let url):
                let (_, pageIndex, commentID) = urlClient.analyzeURL(url)
                let gid = urlClient.parseGalleryID(url)
                var effects = [EffectTask<Action>]()
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
                return databaseClient
                    .updateReadingProgress(gid: gid, progress: progress).fireAndForget()

            case .fetchGallery(let url, let isGalleryImageURL):
                state.route = .hud
                return GalleryReverseRequest(url: url, isGalleryImageURL: isGalleryImageURL)
                    .effect.map({ Action.fetchGalleryDone(url, $0) })

            case .fetchGalleryDone(let url, let result):
                state.route = nil
                switch result {
                case .success(let gallery):
                    return .merge(
                        databaseClient.cacheGalleries([gallery]).fireAndForget(),
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
            case: /Route.newDawn,
            hapticsClient: hapticsClient
        )
        .haptics(
            unwrapping: \.route,
            case: /Route.detail,
            hapticsClient: hapticsClient
        )

        Scope(state: \.detailState, action: /Action.detail, child: DetailReducer.init)
    }
}
