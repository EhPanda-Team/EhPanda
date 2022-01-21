//
//  PopularStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import ComposableArchitecture

struct PopularState: Equatable {
    enum Route: Equatable {
        case detail(String)
    }
    struct CancelID: Hashable {
        let id = String(describing: PopularState.self)
    }

    @BindableState var route: Route?
    @BindableState var keyword = ""

    // Will be passed over from `appReducer`
    var filter = Filter()

    var filteredGalleries: [Gallery] {
        guard !keyword.isEmpty else { return galleries }
        return galleries.filter({ $0.title.caseInsensitiveContains(keyword) })
    }
    var galleries = [Gallery]()
    var loadingState: LoadingState = .idle

    var detailState = DetailState()
}

enum PopularAction: BindableAction {
    case binding(BindingAction<PopularState>)
    case setNavigation(PopularState.Route?)
    case clearSubStates
    case onFiltersButtonTapped

    case cancelFetching
    case fetchGalleries
    case fetchGalleriesDone(Result<[Gallery], AppError>)

    case detail(DetailAction)
}

struct PopularEnvironment {
    let urlClient: URLClient
    let fileClient: FileClient
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let clipboardClient: ClipboardClient
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
            return .init(value: .detail(.cancelFetching))

        case .onFiltersButtonTapped:
            return .none

        case .cancelFetching:
            return .cancel(id: PopularState.CancelID())

        case .fetchGalleries:
            guard state.loadingState != .loading else { return .none }
            state.loadingState = .loading
            return PopularGalleriesRequest(filter: state.filter)
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

        case .detail:
            return .none
        }
    }
    .binding(),
    detailReducer.pullback(
        state: \.detailState,
        action: /PopularAction.detail,
        environment: {
            .init(
                urlClient: $0.urlClient,
                fileClient: $0.fileClient,
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    )
)
