//
//  LogsReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/03.
//

import ComposableArchitecture

struct LogsReducer: Reducer {
    enum Route: Equatable {
        case log(Log)
    }

    private enum CancelID {
        case fetchLogs
    }

    struct State: Equatable {
        @BindingState var route: Route?
        var loadingState: LoadingState = .idle
        var logs = [Log]()
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case navigateToFileApp

        case teardown
        case fetchLogs
        case fetchLogsDone(Result<[Log], AppError>)
        case deleteLog(String)
        case deleteLogDone(Result<String, AppError>)
    }

    @Dependency(\.uiApplicationClient) private var uiApplicationClient
    @Dependency(\.fileClient) private var fileClient

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return .none

            case .navigateToFileApp:
                return .run { _ in
                    uiApplicationClient.openFileApp()
                }

            case .teardown:
                return .cancel(id: CancelID.fetchLogs)

            case .fetchLogs:
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                return .run { send in
                    let result = await fileClient.fetchLogs()
                    await send(.fetchLogsDone(result))
                }
                .cancellable(id: CancelID.fetchLogs)

            case .fetchLogsDone(let result):
                switch result {
                case .success(let logs):
                    state.logs = logs
                    state.loadingState = .idle
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .deleteLog(let fileName):
                return .run { send in
                    let result = await fileClient.deleteLog(fileName)
                    await send(.deleteLogDone(result))
                }

            case .deleteLogDone(let result):
                if case .success(let fileName) = result {
                    state.logs = state.logs.filter({ $0.fileName != fileName })
                }
                return .none
            }
        }
    }
}
