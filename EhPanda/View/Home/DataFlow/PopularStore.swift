//
//  PopularStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import ComposableArchitecture

struct PopularState: Equatable {
    @BindableState var keyword = ""

    // Will be passed over from `appReducer`
    var rawFilter: Filter?
    var filter: Filter {
        rawFilter ?? .init()
    }

    var filteredGalleries: [Gallery] {
        guard !keyword.isEmpty else { return galleries }
        return galleries.filter({ $0.title.localizedCaseInsensitiveContains(keyword) })
    }
    var galleries = [Gallery]()
    var loadingState: LoadingState = .idle
}

enum PopularAction: BindableAction {
    case binding(BindingAction<PopularState>)
    case fetchGalleries
    case fetchGalleriesDone(Result<[Gallery], AppError>)
}

struct PopularEnvironment {
    let databaseClient: DatabaseClient
}

let popularReducer = Reducer<PopularState, PopularAction, PopularEnvironment> { state, action, environment in
    switch action {
    case .binding:
        return .none

    case .fetchGalleries:
        guard state.loadingState != .loading else { return .none }
        state.loadingState = .loading
        return PopularGalleriesRequest(filter: state.filter)
            .effect.map(PopularAction.fetchGalleriesDone)

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
    }
}
.binding()
