//
//  FrontpageReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/08.
//

import ComposableArchitecture

struct FrontpageReducer: ReducerProtocol {
    enum Route: Equatable {
        case filters
        case detail(String)
    }

    private enum CancelID: CaseIterable {
        case fetchGalleries, fetchMoreGalleries
    }

    struct State: Equatable {
        @BindingState var route: Route?
        @BindingState var keyword = ""

        var filteredGalleries: [Gallery] {
            guard !keyword.isEmpty else { return galleries }
            return galleries.filter({ $0.title.caseInsensitiveContains(keyword) })
        }
        var galleries = [Gallery]()
        var pageNumber = PageNumber()
        var loadingState: LoadingState = .idle
        var footerLoadingState: LoadingState = .idle

        var filtersState = FiltersReducer.State()
        @Heap var detailState: DetailReducer.State!

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
        case fetchGalleries
        case fetchGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)

        case filters(FiltersReducer.Action)
        case detail(DetailReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient

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
                state.detailState = .init()
                state.filtersState = .init()
                return .init(value: .detail(.teardown))

            case .teardown:
                return .cancel(ids: CancelID.allCases)

            case .fetchGalleries:
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                state.pageNumber.resetPages()
                let filter = databaseClient.fetchFilterSynchronously(range: .global)
                return FrontpageGalleriesRequest(filter: filter).effect
                    .map(Action.fetchGalleriesDone)
                    .cancellable(id: CancelID.fetchGalleries)

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
                let filter = databaseClient.fetchFilterSynchronously(range: .global)
                return MoreFrontpageGalleriesRequest(filter: filter, lastID: lastID).effect
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

            case .filters:
                return .none

            case .detail:
                return .none
            }
        }
        .haptics(
            unwrapping: \.route,
            case: /Route.filters,
            hapticsClient: hapticsClient
        )

        Scope(state: \.filtersState, action: /Action.filters, child: FiltersReducer.init)
        Scope(state: \.detailState, action: /Action.detail, child: DetailReducer.init)
    }
}
