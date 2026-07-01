import Foundation
import AppModels
import Sharing
import LogsClient
import ApplicationClient
import ComposableArchitecture

@Reducer
public struct AppActivityLogsReducer: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        // Live, read-only view of the current run + its logs, published by the always-alive
        // `AppActivityLogsPumpReducer`. Read-only so the screen can never write stale data back.
        @SharedReader(.appActivityLogsCurrentRun) public var currentRun: RunLogFile?
        @SharedReader(.appActivityLogsCurrentRunLogs) public var currentRunLogs: [AppActivityLog]

        // File-backed log files for previous runs (excludes the current run).
        public var previousRuns = [RunLogFile]()
        // File-backed logs for the currently selected previous run.
        public var selectedRunLogs = [AppActivityLog]()

        // `nil` selects the current run (live/shared); otherwise a previous run's file URL.
        public var selectedRun: URL?
        public var keyword = ""
        public var loadingState: LoadingState = .idle

        // Derived live from the shared current-run buffer (or the selected previous run), newest
        // first. Computed rather than stored so it tracks the pump's shared writes without an action.
        public var displayedLogs: [AppActivityLog] {
            let source = selectedRun == nil ? currentRunLogs : selectedRunLogs
            let filtered = keyword.isEmpty ? source : source.filter { log in
                [log.dateDescription, log.level.title, log.category, log.message]
                    .joined(separator: " ")
                    .caseInsensitiveContains(keyword)
            }
            return filtered.sorted { $0.date > $1.date }
        }

        public init() {}
    }

    public enum Action: Equatable, Sendable {
        case refreshAvailableRuns
        case availableRunsResponse([RunLogFile])
        case selectRun(URL?)
        case runFileResponse([AppActivityLog])
        case queryLogs(String)
        case navigateToFileApp
    }

    @Dependency(\.logsClient) private var logsClient
    @Dependency(\.applicationClient) private var applicationClient

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .refreshAvailableRuns:
                return .run { send in
                    await send(.availableRunsResponse(await logsClient.listRunFiles()))
                }

            case .availableRunsResponse(let runs):
                // Exclude the current run by file (its count can repeat on earlier days).
                state.previousRuns = runs.filter { $0.url != state.currentRun?.url }
                return .none

            case .selectRun(let url):
                guard let url, state.previousRuns.contains(where: { $0.url == url }) else {
                    state.selectedRun = nil
                    state.selectedRunLogs = []
                    return .none
                }
                state.selectedRun = url
                state.loadingState = .loading
                return .run { send in
                    let logs = (try? await logsClient.readRunFile(url)) ?? []
                    await send(.runFileResponse(logs))
                }

            case .runFileResponse(let logs):
                state.loadingState = .idle
                state.selectedRunLogs = logs
                return .none

            case .queryLogs(let keyword):
                state.keyword = keyword
                return .none

            case .navigateToFileApp:
                return .run { _ in await applicationClient.openFileApp() }
            }
        }
    }
}
