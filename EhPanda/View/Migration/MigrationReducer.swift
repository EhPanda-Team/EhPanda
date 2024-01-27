//
//  MigrationReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/03.
//

import Foundation
import ComposableArchitecture

struct MigrationReducer: ReducerProtocol {
    enum Route: Equatable {
        case dropDialog
    }

    struct State: Equatable {
        @BindingState var route: Route?
        var databaseState: LoadingState = .loading
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case onDatabasePreparationSuccess

        case prepareDatabase
        case prepareDatabaseDone(AppError?)
        case dropDatabase
        case dropDatabaseDone(AppError?)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.mainQueue) private var mainQueue

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return .none

            case .onDatabasePreparationSuccess:
                return .none

            case .prepareDatabase:
                return .run { send in
                    await send(.prepareDatabaseDone(databaseClient.prepareDatabase()))
                }

            case .prepareDatabaseDone(let appError):
                if let appError {
                    state.databaseState = .failed(appError)
                    return .none
                } else {
                    state.databaseState = .idle
                    return .send(.onDatabasePreparationSuccess)
                }

            case .dropDatabase:
                state.databaseState = .loading
                return .run { send in
                    try await mainQueue.sleep(for: .milliseconds(500))
                    await send(.dropDatabaseDone(databaseClient.dropDatabase()))
                }

            case .dropDatabaseDone(let appError):
                if let appError {
                    state.databaseState = .failed(appError)
                    return .none
                } else {
                    state.databaseState = .idle
                    return .send(.onDatabasePreparationSuccess)
                }
            }
        }
    }
}
