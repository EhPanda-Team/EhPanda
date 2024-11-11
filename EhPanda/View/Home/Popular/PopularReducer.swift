//
//  PopularReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import ComposableArchitecture

@Reducer
struct PopularReducer {
    @dynamicMemberLookup @CasePathable
    enum Route: Equatable {
        case filters(EquatableVoid = .unique)
        case detail(String)
    }

    private enum CancelID {
        case fetchGalleries
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
        var keyword = ""

        var filteredGalleries: [Gallery] {
            guard !keyword.isEmpty else { return galleries }
            return galleries.filter({ $0.title.caseInsensitiveContains(keyword) })
        }
        var galleries = [Gallery]()
        var loadingState: LoadingState = .idle

        var filtersState = FiltersReducer.State()
        var detailState: Heap<DetailReducer.State?>

        init() {
            detailState = .init(.init())
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
                state.detailState.wrappedValue = .init()
                state.filtersState = .init()
                return .send(.detail(.teardown))

            case .teardown:
                return .cancel(id: CancelID.fetchGalleries)

            case .fetchGalleries:
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                let filter = databaseClient.fetchFilterSynchronously(range: .global)
                return .run { send in
                    let response = await PopularGalleriesRequest(filter: filter).response()
                    await send(.fetchGalleriesDone(response))
                }
                .cancellable(id: CancelID.fetchGalleries)

            case .fetchGalleriesDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let galleries):
                    guard !galleries.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        return .none
                    }
                    state.galleries = galleries
                    return .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
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
            case: \.filters,
            hapticsClient: hapticsClient
        )

        Scope(state: \.filtersState, action: \.filters, child: FiltersReducer.init)
        Scope(state: \.detailState.wrappedValue!, action: \.detail, child: DetailReducer.init)
    }
}
