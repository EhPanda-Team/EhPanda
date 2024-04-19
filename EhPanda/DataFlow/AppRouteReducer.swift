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
                return state.route == nil ? .send(.clearSubStates) : .none

            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .send(.clearSubStates) : .none

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
                    .run { _ in
                        userDefaultsClient.setValue(currentChangeCount, .clipboardChangeCount)
                    }
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
                    return .run { [delay] send in
                        try await Task.sleep(nanoseconds: UInt64((delay + 250)) * NSEC_PER_MSEC)
                        await send(.handleGalleryLink(url))
                    }
                }
                return .run { [delay] send in
                    try await Task.sleep(nanoseconds: UInt64(delay) * NSEC_PER_MSEC)
                    await send(.fetchGallery(url, isGalleryImageURL))
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
                        .run { send in
                            try await Task.sleep(nanoseconds: UInt64(500) * NSEC_PER_MSEC)
                            await send(.detail(.setNavigation(.reading)))
                        }
                    )
                } else if let commentID = commentID {
                    state.detailState.commentsState?.scrollCommentID = commentID
                    effects.append(
                        .run { send in
                            try await Task.sleep(nanoseconds: UInt64(500) * NSEC_PER_MSEC)
                            await send(.detail(.setNavigation(.comments(url))))
                        }
                    )
                }
                effects.append(.send(.setNavigation(.detail(gid))))
                return .merge(effects)

            case .updateReadingProgress(let gid, let progress):
                guard !gid.isEmpty else { return .none }
                return .run { _ in
                    await databaseClient.updateReadingProgress(gid: gid, progress: progress)
                }

            case .fetchGallery(let url, let isGalleryImageURL):
                state.route = .hud
                return GalleryReverseRequest(url: url, isGalleryImageURL: isGalleryImageURL)
                    .effect.map({ Action.fetchGalleryDone(url, $0) })

            case .fetchGalleryDone(let url, let result):
                state.route = nil
                switch result {
                case .success(let gallery):
                    return .merge(
                        .run { _ in
                            await databaseClient.cacheGalleries([gallery])
                        },
                        .send(.handleGalleryLink(url))
                    )
                case .failure:
                    return .run { send in
                        try await Task.sleep(nanoseconds: UInt64(500) * NSEC_PER_MSEC)
                        await send(Action.setHUDConfig(.error))
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
