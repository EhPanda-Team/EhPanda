//
//  AppRouteReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/08.
//

import SwiftUI
import TTProgressHUD
import ComposableArchitecture

struct AppRouteReducer: Reducer {
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

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.$route):
                return state.route == nil ? Effect.send(.clearSubStates) : .none

            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? Effect.send(.clearSubStates) : .none

            case .setHUDConfig(let config):
                state.hudConfig = config
                return .none

            case .clearSubStates:
                state.detailState = .init()
                return .send(.detail(.teardown))

            case .detectClipboardURL:
                let currentChangeCount = clipboardClient.changeCount()
                guard currentChangeCount != userDefaultsClient
                        .getValue(.clipboardChangeCount) else { return .none }
                var effects: [Effect<Action>] = [
                    userDefaultsClient
                        .setValue(currentChangeCount, .clipboardChangeCount).fireAndForget()
                ]
                if let url = clipboardClient.url() {
                    effects.append(.send(.handleDeepLink(url)))
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
                    return .publisher {
                        Effect.send(.handleGalleryLink(url))
                            .delay(for: .milliseconds(delay + 250), scheduler: DispatchQueue.main)
                    }
                }
                return .publisher {
                    Effect.send(.fetchGallery(url, isGalleryImageURL))
                        .delay(for: .milliseconds(delay), scheduler: DispatchQueue.main)
                }

            case .handleGalleryLink(let url):
                let (_, pageIndex, commentID) = urlClient.analyzeURL(url)
                let gid = urlClient.parseGalleryID(url)
                var effects = [Effect<Action>]()
                state.detailState = .init()
                effects.append(.send(.detail(.fetchDatabaseInfos(gid))))
                if let pageIndex = pageIndex {
                    effects.append(.send(.updateReadingProgress(gid, pageIndex)))
                    effects.append(
                        .publisher {
                            Effect.send(.detail(.setNavigation(.reading)))
                                .delay(for: .milliseconds(500), scheduler: DispatchQueue.main)
                        }
                    )
                } else if let commentID = commentID {
                    state.detailState.commentsState?.scrollCommentID = commentID
                    effects.append(
                        .publisher {
                            Effect.send(.detail(.setNavigation(.comments(url))))
                                .delay(for: .milliseconds(500), scheduler: DispatchQueue.main)
                        }
                    )
                }
                effects.append(.send(.setNavigation(.detail(gid))))
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
                        Effect.send(.handleGalleryLink(url))
                    )
                case .failure:
                    return .publisher {
                        Effect.send(Action.setHUDConfig(.error))
                            .delay(for: .milliseconds(500), scheduler: DispatchQueue.main)
                    }
                }

            case .fetchGreetingDone(let result):
                if case .success(let greeting) = result, !greeting.gainedNothing {
                    return .send(.setNavigation(.newDawn(greeting)))
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
