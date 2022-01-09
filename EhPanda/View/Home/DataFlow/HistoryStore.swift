//
//  HistoryStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import ComposableArchitecture

struct HistoryState: Equatable {
    @BindableState var keyword = ""
    @BindableState var clearDialogPresented = false

    // Will be passed over from `appReducer`
    var filter = Filter()

    var filteredGalleries: [Gallery] {
        guard !keyword.isEmpty else { return galleries }
        return galleries.filter({ $0.title.localizedCaseInsensitiveContains(keyword) })
    }
    var galleries = [Gallery]()
    var loadingState: LoadingState = .idle
}

enum HistoryAction: BindableAction {
    case binding(BindingAction<HistoryState>)
    case fetchGalleries
    case fetchGalleriesDone([Gallery])
    case setClearDialogPresented(Bool)
    case clearHistoryGalleries
}

struct HistoryEnvironment {
    let databaseClient: DatabaseClient
}

let historyReducer = Reducer<HistoryState, HistoryAction, HistoryEnvironment> { state, action, environment in
    switch action {
    case .binding:
        return .none

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

    case .setClearDialogPresented(let isPresented):
        state.clearDialogPresented = isPresented
        return .none

    case .clearHistoryGalleries:
        return environment.databaseClient.clearHistoryGalleries().fireAndForget()
    }
}
.binding()
