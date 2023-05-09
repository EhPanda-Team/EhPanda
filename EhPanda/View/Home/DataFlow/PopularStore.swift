//
//  PopularStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import ComposableArchitecture

struct PopularState: Equatable {
    enum Route: Equatable {
        case filters
        case detail(String)
    }
    struct CancelID: Hashable {
        let id = String(describing: PopularState.self)
    }

    init() {
        _detailState = .init(.init())
    }

    @BindingState var route: Route?
    @BindingState var keyword = ""

    var filteredGalleries: [Gallery] {
        guard !keyword.isEmpty else { return galleries }
        return galleries.filter({ $0.title.caseInsensitiveContains(keyword) })
    }
    var galleries = [Gallery]()
    var loadingState: LoadingState = .idle

    var filtersState = FiltersState()
    @Heap var detailState: DetailState!
}

enum PopularAction: BindableAction {
    case binding(BindingAction<PopularState>)
    case setNavigation(PopularState.Route?)
    case clearSubStates

    case teardown
    case fetchGalleries
    case fetchGalleriesDone(Result<[Gallery], AppError>)

    case filters(FiltersAction)
    case detail(DetailAction)
}

struct PopularEnvironment {
    let urlClient: URLClient
    let fileClient: FileClient
    let imageClient: ImageClient
    let deviceClient: DeviceClient
    let hapticsClient: HapticsClient
    let cookieClient: CookieClient
    let databaseClient: DatabaseClient
    let clipboardClient: ClipboardClient
    let appDelegateClient: AppDelegateClient
    let uiApplicationClient: UIApplicationClient
}

let popularReducer = Reducer<PopularState, PopularAction, PopularEnvironment>.combine(
    .init { state, action, environment in
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
            return .cancel(id: PopularState.CancelID())

        case .fetchGalleries:
            guard state.loadingState != .loading else { return .none }
            state.loadingState = .loading
            let filter = environment.databaseClient.fetchFilterSynchronously(range: .global)
            return PopularGalleriesRequest(filter: filter)
                .effect.map(PopularAction.fetchGalleriesDone).cancellable(id: PopularState.CancelID())

        case .fetchGalleriesDone(let result):
            state.loadingState = .idle
            switch result {
            case .success(let galleries):
                guard !galleries.isEmpty else {
                    state.loadingState = .failed(.notFound)
                    return .none
                }
                state.galleries = galleries
                return environment.databaseClient.cacheGalleries(galleries).fireAndForget()
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
        case: /PopularState.Route.filters,
        hapticsClient: \.hapticsClient
    )
    .binding(),
    filtersReducer.pullback(
        state: \.filtersState,
        action: /PopularAction.filters,
        environment: {
            .init(
                databaseClient: $0.databaseClient
            )
        }
    ),
    detailReducer.pullback(
        state: \.detailState,
        action: /PopularAction.detail,
        environment: {
            .init(
                urlClient: $0.urlClient,
                fileClient: $0.fileClient,
                imageClient: $0.imageClient,
                deviceClient: $0.deviceClient,
                hapticsClient: $0.hapticsClient,
                cookieClient: $0.cookieClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                appDelegateClient: $0.appDelegateClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    )
)
