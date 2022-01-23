//
//  HistoryStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import ComposableArchitecture

struct HistoryState: Equatable {
    enum Route: Equatable {
        case detail(String)
        case clearHistory
    }

    @BindableState var route: Route?
    @BindableState var keyword = ""
    @BindableState var clearDialogPresented = false

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

enum HistoryAction: BindableAction {
    case binding(BindingAction<HistoryState>)
    case setNavigation(HistoryState.Route?)
    case clearSubStates
    case clearHistoryGalleries

    case fetchGalleries
    case fetchGalleriesDone([Gallery])

    case detail(DetailAction)
}

struct HistoryEnvironment {
    let urlClient: URLClient
    let fileClient: FileClient
    let imageClient: ImageClient
    let deviceClient: DeviceClient
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let clipboardClient: ClipboardClient
    let uiApplicationClient: UIApplicationClient
}

let historyReducer = Reducer<HistoryState, HistoryAction, HistoryEnvironment>.combine(
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

        case .clearHistoryGalleries:
            return environment.databaseClient.clearHistoryGalleries().fireAndForget()

        case .fetchGalleries:
            guard state.loadingState != .loading else { return .none }
            state.loadingState = .loading
            return environment.databaseClient.fetchHistoryGalleries(nil).map(HistoryAction.fetchGalleriesDone)

        case .fetchGalleriesDone(let galleries):
            state.loadingState = .idle
            if galleries.isEmpty {
                state.loadingState = .failed(.notFound)
            } else {
                state.galleries = galleries
            }
            return .none

        case .detail:
            return .none
        }
    }
    .binding(),
    detailReducer.pullback(
        state: \.detailState,
        action: /HistoryAction.detail,
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
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    )
)
