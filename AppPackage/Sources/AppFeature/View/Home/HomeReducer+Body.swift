import SwiftUI
import Kingfisher
import ComposableArchitecture
import Networking

extension HomeReducer {
    @ReducerBuilder<State, Action>
    var reducerBody: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.route) { _, state in
                state.route == nil ? .send(.clearSubStates) : .none
            }
            .onChange(of: \.cardPageIndex) { _, state in
                guard state.cardPageIndex < state.popularGalleries.count else { return .none }
                state.currentCardID = state.popularGalleries[state.cardPageIndex].gid
                state.allowsCardHitTesting = false
                return .run { send in
                    try await Task.sleep(for: .milliseconds(300))
                    await send(.setAllowsCardHitTesting(true))
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
                    await send(.fetchFrontpageGalleriesDone(response.map { ($0.pageNumber, $0.galleries) }))
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
                state.rawCardColors[gid] = colors
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

        Scope(state: \.frontpageState, action: \.frontpage, child: FrontpageReducer.init)
        Scope(state: \.toplistsState, action: \.toplists, child: ToplistsReducer.init)
        Scope(state: \.popularState, action: \.popular, child: PopularReducer.init)
        Scope(state: \.watchedState, action: \.watched, child: WatchedReducer.init)
        Scope(state: \.historyState, action: \.history, child: HistoryReducer.init)
        Scope(state: \.detailState.wrappedValue!, action: \.detail, child: DetailReducer.init)
    }
}
