//
//  HistoryReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import Foundation
import ComposableArchitecture

@Reducer
struct HistoryReducer {
    @CasePathable
    enum Route: Equatable {
        case detail(String)
        case clearHistory
    }

    struct State: Equatable {
        @BindingState var route: Route?
        @BindingState var keyword = ""
        @BindingState var clearDialogPresented = false

        var filteredGalleries: [Gallery] {
            guard !keyword.isEmpty else { return galleries }
            return galleries.filter({ $0.title.caseInsensitiveContains(keyword) })
        }
        var galleries = [Gallery]()
        var loadingState: LoadingState = .idle

        @Heap var detailState: DetailReducer.State!

        init() {
            _detailState = .init(.init())
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case clearSubStates
        case clearHistoryGalleries

        case fetchGalleries
        case fetchGalleriesDone([Gallery])

        case detail(DetailReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.$route):
                return state.route == nil ? .send(.clearSubStates) : .none

            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .send(.clearSubStates) : .none

            case .clearSubStates:
                state.detailState = .init()
                return .send(.detail(.teardown))

            case .clearHistoryGalleries:
                return .merge(
                    .run(operation: { _ in await databaseClient.clearHistoryGalleries() }),
                    .run { send in
                        try await Task.sleep(for: .milliseconds(200))
                        await send(.fetchGalleries)
                    }
                )

            case .fetchGalleries:
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                return .run { send in
                    let historyGalleries = await databaseClient.fetchHistoryGalleries()
                    await send(.fetchGalleriesDone(historyGalleries))
                }

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

        Scope(state: \.detailState, action: /Action.detail, child: DetailReducer.init)
    }
}
