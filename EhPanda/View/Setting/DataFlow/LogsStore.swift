//
//  LogsStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/03.
//

import ComposableArchitecture

struct LogsState: Equatable {
    enum Route: Equatable {
        case log(Log)
    }
    struct CancelID: Hashable {
        let id = String(describing: LogsState.self)
    }

    @BindingState var route: Route?
    var loadingState: LoadingState = .idle
    var logs = [Log]()
}

enum LogsAction: BindableAction, Equatable {
    case binding(BindingAction<LogsState>)
    case setNavigation(LogsState.Route?)
    case navigateToFileApp

    case teardown
    case fetchLogs
    case fetchLogsDone(Result<[Log], AppError>)
    case deleteLog(String)
    case deleteLogDone(Result<String, AppError>)
}

struct LogsEnvironment {
    let fileClient: FileClient
    let uiApplicationClient: UIApplicationClient
}

let logsReducer = Reducer<LogsState, LogsAction, LogsEnvironment> { state, action, environment in
    switch action {
    case .binding:
        return .none

    case .setNavigation(let route):
        state.route = route
        return .none

    case .navigateToFileApp:
        return environment.uiApplicationClient.openFileApp().fireAndForget()

    case .teardown:
        return .cancel(id: LogsState.CancelID())

    case .fetchLogs:
        guard state.loadingState != .loading else { return .none }
        state.loadingState = .loading
        return environment.fileClient.fetchLogs().map(LogsAction.fetchLogsDone).cancellable(id: LogsState.CancelID())

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
        return environment.fileClient.deleteLog(fileName).map(LogsAction.deleteLogDone)

    case .deleteLogDone(let result):
        if case .success(let fileName) = result {
            state.logs = state.logs.filter({ $0.fileName != fileName })
        }
        return .none
    }
}
.binding()
