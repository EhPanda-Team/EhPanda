//
//  MigrationStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/03.
//

import ComposableArchitecture

struct MigrationState: Equatable {
    enum Route: Equatable {
        case dropDialog
    }

    @BindableState var route: Route?
    var databaseState: LoadingState = .loading
}

enum MigrationAction: BindableAction {
    case binding(BindingAction<MigrationState>)
    case setNavigation(MigrationState.Route?)
    case onDatabasePreparationSuccess

    case prepareDatabase
    case prepareDatabaseDone(Result<Void, AppError>)
    case dropDatabase
    case dropDatabaseDone(Result<Void, AppError>)
}

struct MigrationEnvironment {
    let databaseClient: DatabaseClient
}

let migrationReducer = Reducer<MigrationState, MigrationAction, MigrationEnvironment> { state, action, environment in
    switch action {
    case .binding:
        return .none

    case .setNavigation(let route):
        state.route = route
        return .none

    case .onDatabasePreparationSuccess:
        return .none

    case .prepareDatabase:
        return environment.databaseClient.prepareDatabase().map(MigrationAction.prepareDatabaseDone)

    case .prepareDatabaseDone(let result):
        switch result {
        case .success:
            state.databaseState = .idle
            return .init(value: .onDatabasePreparationSuccess)
        case .failure(let error):
            state.databaseState = .failed(error)
            return .none
        }

    case .dropDatabase:
        state.databaseState = .loading
        return .none

    case .dropDatabaseDone(let result):
        switch result {
        case .success:
            state.databaseState = .idle
            return .init(value: .onDatabasePreparationSuccess)
        case .failure(let error):
            state.databaseState = .failed(error)
            return .none
        }
    }
}
.binding()
