//
//  HomeReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/05.
//

import SwiftUI
import Kingfisher
import UIImageColors
import ComposableArchitecture

@Reducer
struct HomeReducer {
    @CasePathable
    enum Route: Equatable, Hashable {
        case detail(String)
        case misc(HomeMiscGridType)
        case section(HomeSectionType)
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
        var cardPageIndex = 1
        var currentCardID = ""
        var allowsCardHitTesting = true
        var rawCardColors = [String: [Color]]()
        var cardColors: [Color] {
            rawCardColors[currentCardID] ?? [.clear]
        }

        var popularGalleries = [Gallery]()
        var popularLoadingState: LoadingState = .idle
        var frontpageGalleries = [Gallery]()
        var frontpageLoadingState: LoadingState = .idle
        var toplistsGalleries = [Int: [Gallery]]()
        var toplistsLoadingState = [Int: LoadingState]()

        var frontpageState = FrontpageReducer.State()
        var toplistsState = ToplistsReducer.State()
        var popularState = PopularReducer.State()
        var watchedState = WatchedReducer.State()
        var historyState = HistoryReducer.State()
        var detailState: Heap<DetailReducer.State?>

        init() {
            detailState = .init(.init())
        }

        mutating func setPopularGalleries(_ galleries: [Gallery]) {
            let sortedGalleries = galleries.sorted { lhs, rhs in
                lhs.title.count > rhs.title.count
            }
            var trimmedGalleries = Array(sortedGalleries.prefix(min(sortedGalleries.count, 10)))
                .removeDuplicates(by: \.trimmedTitle)
            if trimmedGalleries.count >= 6 {
                trimmedGalleries = Array(trimmedGalleries.prefix(6))
            }
            trimmedGalleries.shuffle()
            popularGalleries = trimmedGalleries
            currentCardID = trimmedGalleries[cardPageIndex].gid
        }

        mutating func setFrontpageGalleries(_ galleries: [Gallery]) {
            frontpageGalleries = Array(galleries.prefix(min(galleries.count, 25)))
                .removeDuplicates(by: \.trimmedTitle)
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case clearSubStates
        case setAllowsCardHitTesting(Bool)
        case analyzeImageColors(String, RetrieveImageResult)
        case analyzeImageColorsDone(String, UIImageColors?)

        case fetchAllGalleries
        case fetchAllToplistsGalleries
        case fetchPopularGalleries
        case fetchPopularGalleriesDone(Result<[Gallery], AppError>)
        case fetchFrontpageGalleries
        case fetchFrontpageGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
        case fetchToplistsGalleries(Int, Int? = nil)
        case fetchToplistsGalleriesDone(Int, Result<(PageNumber, [Gallery]), AppError>)

        case frontpage(FrontpageReducer.Action)
        case toplists(ToplistsReducer.Action)
        case popular(PopularReducer.Action)
        case watched(WatchedReducer.Action)
        case history(HistoryReducer.Action)
        case detail(DetailReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.libraryClient) private var libraryClient

    var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.route) { _, newValue in
                Reduce({ _, _ in newValue == nil ? .send(.clearSubStates) : .none })
            }
            .onChange(of: \.cardPageIndex) { _, newValue in
                Reduce { state, _ in
                    guard newValue < state.popularGalleries.count else { return .none }
                    state.currentCardID = state.popularGalleries[state.cardPageIndex].gid
                    state.allowsCardHitTesting = false
                    return .run { send in
                        try await Task.sleep(for: .milliseconds(300))
                        await send(.setAllowsCardHitTesting(true))
                    }
                }
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .send(.clearSubStates) : .none

            case .clearSubStates:
                state.frontpageState = .init()
                state.toplistsState = .init()
                state.popularState = .init()
                state.watchedState = .init()
                state.historyState = .init()
                state.detailState.wrappedValue = .init()
                return .merge(
                    .send(.frontpage(.teardown)),
                    .send(.toplists(.teardown)),
                    .send(.popular(.teardown)),
                    .send(.watched(.teardown)),
                    .send(.detail(.teardown))
                )

            case .setAllowsCardHitTesting(let isAllowed):
                state.allowsCardHitTesting = isAllowed
                return .none

            case .fetchAllGalleries:
                return .merge(
                    .send(.fetchPopularGalleries),
                    .send(.fetchFrontpageGalleries),
                    .send(.fetchAllToplistsGalleries)
                )

            case .fetchAllToplistsGalleries:
                return .merge(
                    ToplistsType.allCases
                        .map { Action.fetchToplistsGalleries($0.categoryIndex) }
                        .map(Effect<Action>.send)
                )

            case .fetchPopularGalleries:
                guard state.popularLoadingState != .loading else { return .none }
                state.popularLoadingState = .loading
                state.rawCardColors = [String: [Color]]()
                let filter = databaseClient.fetchFilterSynchronously(range: .global)
                return .run { send in
                    let response = await PopularGalleriesRequest(filter: filter).response()
                    await send(.fetchPopularGalleriesDone(response))
                }

            case .fetchPopularGalleriesDone(let result):
                state.popularLoadingState = .idle
                switch result {
                case .success(let galleries):
                    guard !galleries.isEmpty else {
                        state.popularLoadingState = .failed(.notFound)
                        return .none
                    }
                    state.setPopularGalleries(galleries)
                    return .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                case .failure(let error):
                    state.popularLoadingState = .failed(error)
                }
                return .none

            case .fetchFrontpageGalleries:
                guard state.frontpageLoadingState != .loading else { return .none }
                state.frontpageLoadingState = .loading
                let filter = databaseClient.fetchFilterSynchronously(range: .global)
                return .run { send in
                    let response = await FrontpageGalleriesRequest(filter: filter).response()
                    await send(.fetchFrontpageGalleriesDone(response))
                }

            case .fetchFrontpageGalleriesDone(let result):
                state.frontpageLoadingState = .idle
                switch result {
                case .success(let (_, galleries)):
                    guard !galleries.isEmpty else {
                        state.frontpageLoadingState = .failed(.notFound)
                        return .none
                    }
                    state.setFrontpageGalleries(galleries)
                    return .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                case .failure(let error):
                    state.frontpageLoadingState = .failed(error)
                }
                return .none

            case .fetchToplistsGalleries(let index, let pageNum):
                guard state.toplistsLoadingState[index] != .loading else { return .none }
                state.toplistsLoadingState[index] = .loading
                return .run { send in
                    let response = await ToplistsGalleriesRequest(catIndex: index, pageNum: pageNum).response()
                    await send(.fetchToplistsGalleriesDone(index, response))
                }

            case .fetchToplistsGalleriesDone(let index, let result):
                state.toplistsLoadingState[index] = .idle
                switch result {
                case .success(let (_, galleries)):
                    guard !galleries.isEmpty else {
                        state.toplistsLoadingState[index] = .failed(.notFound)
                        return .none
                    }
                    state.toplistsGalleries[index] = galleries
                    return .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                case .failure(let error):
                    state.toplistsLoadingState[index] = .failed(error)
                }
                return .none

            case .analyzeImageColors(let gid, let result):
                guard !state.rawCardColors.keys.contains(gid) else { return .none }
                return .run { send in
                    let colors = await libraryClient.analyzeImageColors(result.image)
                    await send(.analyzeImageColorsDone(gid, colors))
                }

            case .analyzeImageColorsDone(let gid, let colors):
                if let colors = colors {
                    state.rawCardColors[gid] = [
                        colors.primary, colors.secondary,
                        colors.detail, colors.background
                    ]
                    .map(Color.init)
                }
                return .none

            case .frontpage:
                return .none

            case .toplists:
                return .none

            case .popular:
                return .none

            case .watched:
                return .none

            case .history:
                return .none

            case .detail:
                return .none
            }
        }

        Scope(state: \.frontpageState, action: /Action.frontpage, child: FrontpageReducer.init)
        Scope(state: \.toplistsState, action: /Action.toplists, child: ToplistsReducer.init)
        Scope(state: \.popularState, action: /Action.popular, child: PopularReducer.init)
        Scope(state: \.watchedState, action: /Action.watched, child: WatchedReducer.init)
        Scope(state: \.historyState, action: /Action.history, child: HistoryReducer.init)
        Scope(state: \.detailState.wrappedValue!, action: /Action.detail, child: DetailReducer.init)
    }
}
