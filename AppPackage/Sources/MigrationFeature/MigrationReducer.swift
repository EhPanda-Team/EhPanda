import Foundation
import AppModels
import ComposableArchitecture
import DatabaseClient

@Reducer
public struct MigrationReducer: Sendable {
    @CasePathable
    public enum Route: Equatable {
        case dropDialog
    }

    @ObservableState
    public struct State: Equatable {
        public var route: Route?
        public var databaseState: LoadingState = .loading

        public init() {}
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case onDatabasePreparationSuccess

        case prepareDatabase
        case prepareDatabaseDone(AppError?)
        case dropDatabase
        case dropDatabaseDone(AppError?)
    }

    @Dependency(\.databaseClient) private var databaseClient

    public init() {}

    public var body: some Reducer<State, Action> {
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
                    let result = await databaseClient.prepareDatabase()
                    await send(.prepareDatabaseDone(result.error))
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
                    try await Task.sleep(for: .milliseconds(500))
                    let result = await databaseClient.dropDatabase()
                    await send(.dropDatabaseDone(result.error))
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

private extension Result {
    var error: Failure? {
        switch self {
        case .success:
            return nil
        case let .failure(error):
            return error
        }
    }
}
