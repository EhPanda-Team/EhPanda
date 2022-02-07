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

    init() {
        _detailState = .init(.init())
    }

    @BindableState var route: Route?
    @BindableState var keyword = ""

    var filteredGalleries: [Gallery] {
        guard !keyword.isEmpty else { return galleries }
        return galleries.filter({ $0.title.caseInsensitiveContains(keyword) })
    }
    var galleries = [Gallery]()
    var loadingState: LoadingState = .idle

    @Heap var detailState: DetailState!
}

enum PopularAction: BindableAction {
    case binding(BindingAction<PopularState>)
    case setNavigation(PopularState.Route?)
    case clearSubStates
    case onFiltersButtonTapped

    case teardown
    case fetchGalleries
    case fetchGalleriesDone(Result<[Gallery], AppError>)

    case detail(DetailAction)
}

struct PopularEnvironment {
    let urlClient: URLClient
    let fileClient: FileClient
    let imageClient: ImageClient
    let deviceClient: DeviceClient
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
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
            return .init(value: .detail(.teardown))

        case .onFiltersButtonTapped:
            return .none

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
                imageClient: $0.imageClient,
                deviceClient: $0.deviceClient,
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                appDelegateClient: $0.appDelegateClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    )
)
