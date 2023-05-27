//
//  PopularReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import ComposableArchitecture

struct PopularReducer: ReducerProtocol {
    enum Route: Equatable {
        case filters
        case detail(String)
    }

    private enum CancelID {
        case fetchGalleries
    }

    struct State: Equatable {
        @BindingState var route: Route?
        @BindingState var keyword = ""

        var filteredGalleries: [Gallery] {
            guard !keyword.isEmpty else { return galleries }
            return galleries.filter({ $0.title.caseInsensitiveContains(keyword) })
        }
        var galleries = [Gallery]()
        var loadingState: LoadingState = .idle

        var filtersState = FiltersReducer.State()
        @Heap var detailState: DetailReducer.State!

        init() {
            _detailState = .init(.init())
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case clearSubStates

        case teardown
        case fetchGalleries
        case fetchGalleriesDone(Result<[Gallery], AppError>)

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
                return .cancel(id: CancelID.fetchGalleries)

            case .fetchGalleries:
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                let filter = databaseClient.fetchFilterSynchronously(range: .global)
                return PopularGalleriesRequest(filter: filter)
                    .effect.map(Action.fetchGalleriesDone).cancellable(id: CancelID.fetchGalleries)

            case .fetchGalleriesDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let galleries):
                    guard !galleries.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        return .none
                    }
                    state.galleries = galleries
                    return databaseClient.cacheGalleries(galleries).fireAndForget()
                case .failure(let error):
                    state.loadingState = .failed(error)
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
