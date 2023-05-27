//
//  DetailSearchReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/12.
//

import ComposableArchitecture

struct DetailSearchReducer: ReducerProtocol {
    enum Route: Equatable {
        case filters
        case quickSearch
        case detail(String)
    }

    private enum CancelID: CaseIterable {
        case fetchGalleries, fetchMoreGalleries
    }

    struct State: Equatable {
        @BindingState var route: Route?
        @BindingState var keyword = ""
        var lastKeyword = ""

        var galleries = [Gallery]()
        var pageNumber = PageNumber()
        var loadingState: LoadingState = .idle
        var footerLoadingState: LoadingState = .idle

        @Heap var detailState: DetailReducer.State!
        var filtersState = FiltersReducer.State()
        var quickDetailSearchState = QuickSearchReducer.State()

        init() {
            _detailState = .init(.init())
        }

        mutating func insertGalleries(_ galleries: [Gallery]) {
            galleries.forEach { gallery in
                if !self.galleries.contains(gallery) {
                    self.galleries.append(gallery)
                }
            }
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case clearSubStates

        case teardown
        case fetchGalleries(String? = nil)
        case fetchGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)

        case detail(DetailReducer.Action)
        case filters(FiltersReducer.Action)
        case quickSearch(QuickSearchReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.$route):
                return state.route == nil ? .init(value: .clearSubStates) : .none

            case .binding(\.$keyword):
                if !state.keyword.isEmpty {
                    state.lastKeyword = state.keyword
                }
                return .none

            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .init(value: .clearSubStates) : .none

            case .clearSubStates:
                state.detailState = .init()
                state.filtersState = .init()
                state.quickDetailSearchState = .init()
                return .merge(
                    .init(value: .detail(.teardown)),
                    .init(value: .quickSearch(.teardown))
                )

            case .teardown:
                return .cancel(ids: CancelID.allCases)

            case .fetchGalleries(let keyword):
                guard state.loadingState != .loading else { return .none }
                if let keyword = keyword {
                    state.keyword = keyword
                    state.lastKeyword = keyword
                }
                state.loadingState = .loading
                state.pageNumber.resetPages()
                let filter = databaseClient.fetchFilterSynchronously(range: .search)
                return SearchGalleriesRequest(keyword: state.lastKeyword, filter: filter).effect
                    .map(Action.fetchGalleriesDone).cancellable(id: CancelID.fetchGalleries)

            case .fetchGalleriesDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let (pageNumber, galleries)):
                    guard !galleries.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        guard pageNumber.hasNextPage() else { return .none }
                        return .init(value: .fetchMoreGalleries)
                    }
                    state.pageNumber = pageNumber
                    state.galleries = galleries
                    return databaseClient.cacheGalleries(galleries).fireAndForget()
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .fetchMoreGalleries:
                let pageNumber = state.pageNumber
                guard pageNumber.hasNextPage(),
                      state.footerLoadingState != .loading,
                      let lastID = state.galleries.last?.id
                else { return .none }
                state.footerLoadingState = .loading
                let filter = databaseClient.fetchFilterSynchronously(range: .search)
                return MoreSearchGalleriesRequest(keyword: state.lastKeyword, filter: filter, lastID: lastID).effect
                    .map(Action.fetchMoreGalleriesDone)
                    .cancellable(id: CancelID.fetchMoreGalleries)

            case .fetchMoreGalleriesDone(let result):
                state.footerLoadingState = .idle
                switch result {
                case .success(let (pageNumber, galleries)):
                    state.pageNumber = pageNumber
                    state.insertGalleries(galleries)

                    var effects: [EffectTask<Action>] = [
                        databaseClient.cacheGalleries(galleries).fireAndForget()
                    ]
                    if galleries.isEmpty, pageNumber.hasNextPage() {
                        effects.append(.init(value: .fetchMoreGalleries))
                    } else if !galleries.isEmpty {
                        state.loadingState = .idle
                    }
                    return .merge(effects)

                case .failure(let error):
                    state.footerLoadingState = .failed(error)
                }
                return .none

            case .detail:
                return .none

            case .filters:
                return .none

            case .quickSearch:
                return .none
            }
        }
        .haptics(
            unwrapping: \.route,
            case: /Route.quickSearch,
            hapticsClient: hapticsClient
        )
        .haptics(
            unwrapping: \.route,
            case: /Route.filters,
            hapticsClient: hapticsClient
        )

        Scope(state: \.filtersState, action: /Action.filters, child: FiltersReducer.init)
        Scope(state: \.quickDetailSearchState, action: /Action.quickSearch, child: QuickSearchReducer.init)
    }
}
