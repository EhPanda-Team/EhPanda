import Foundation
import AppModels
import Resources
import ComposableArchitecture
import DatabaseClient

@Reducer
public struct MigrationReducer: Sendable {
    public enum Dialog: Equatable, Sendable {
        case confirmDropDatabase
    }

    @ObservableState
    public struct State: Equatable {
        @Presents public var confirmationDialog: ConfirmationDialogState<Dialog>?
        public var databaseState: LoadingState = .loading

        public init() {}
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case confirmationDialog(PresentationAction<Dialog>)
        case dropDatabaseButtonTapped
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

            case .dropDatabaseButtonTapped:
                state.confirmationDialog = ConfirmationDialogState {
                    TextState("")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDropDatabase) {
                        TextState(String(localized: .dropDatabase))
                    }
                    ButtonState(role: .cancel) {
                        TextState(String(localized: .RLocalizable.cancel))
                    }
                } message: {
                    TextState(String(localized: .dropDatabaseDescription))
                }
                return .none

            case .confirmationDialog(.presented(.confirmDropDatabase)):
                return .send(.dropDatabase)

            case .confirmationDialog:
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
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
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
