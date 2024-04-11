//
//  MigrationReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/03.
//

import Foundation
import ComposableArchitecture

struct MigrationReducer: Reducer {
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

    var body: some Reducer<State, Action> {
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
                return databaseClient.prepareDatabase().map(Action.prepareDatabaseDone)

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
                return .publisher {
                    databaseClient.dropDatabase()
                        .delay(for: .milliseconds(500), scheduler: DispatchQueue.main)
                        .map(Action.dropDatabaseDone)
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
