import OSLogExt
import Foundation
import AppModels
import LogsClient
import ComposableArchitecture

private let logger = Logger(category: .init(describing: AppActivityLogsReducer.self))

@Reducer
public struct AppActivityLogsReducer: Sendable {
    private enum CancelID {
        case pump
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        // The current run, derived once per app run and reused across pump pauses.
        public var currentRun: RunLogFile?
        public var lastCursorDate: Date?

        // Live, state-backed logs for the current run.
        public var currentRunLogs = [AppActivityLog]()
        // File-backed log files for previous runs (excludes the current run).
        public var previousRuns = [RunLogFile]()
        // File-backed logs for the currently selected previous run.
        public var selectedRunLogs = [AppActivityLog]()

        // `nil` selects the current run (state-backed); otherwise a previous run's file URL.
        public var selectedRun: URL?
        public var displayedLogs = [AppActivityLog]()
        public var keyword = ""
        public var loadingState: LoadingState = .idle

        public init() {}
    }

    public enum Action: Equatable, Sendable {
        case startPump
        case pausePump
        case setCurrentRun(RunLogFile)
        case didReceiveNewEntries([AppActivityLog])
        case refreshAvailableRuns
        case availableRunsResponse([RunLogFile])
        case selectRun(URL?)
        case runFileResponse([AppActivityLog])
        case queryLogs(String)
    }

    @Dependency(\.logsClient) private var logsClient
    @Dependency(\.continuousClock) private var clock
    @Dependency(\.date) private var date

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startPump:
                return .run { [existingURL = state.currentRun?.url, cursor0 = state.lastCursorDate] send in
                    let fileURL: URL
                    if let existingURL {
                        fileURL = existingURL
                    } else {
                        let now = date.now
                        let runCount = await logsClient.nextRunCount(now)
                        let resolvedURL = logsClient.currentRunFileURL(runCount, now)
                        await send(.setCurrentRun(RunLogFile(url: resolvedURL, date: now, runCount: runCount)))
                        fileURL = resolvedURL
                        let appVersion = Bundle.main
                            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "(null)"
                        logger.log(
                            """
                            App activity logging started.
                            Run \(runCount, privacy: .public)
                            App Version \(appVersion, privacy: .public)
                            OS \(ProcessInfo.processInfo.operatingSystemVersionString, privacy: .public)
                            """
                        )
                    }
                    await send(.refreshAvailableRuns)

                    var cursor = cursor0
                    while !Task.isCancelled {
                        let newEntries = (try? await logsClient.fetchNewEntries(cursor)) ?? []
                        if let lastDate = newEntries.last?.date {
                            cursor = lastDate
                            await send(.didReceiveNewEntries(newEntries))
                            try? await logsClient.appendToRunFile(newEntries, fileURL)
                        }
                        try await clock.sleep(for: .seconds(5))
                    }
                }
                .cancellable(id: CancelID.pump, cancelInFlight: true)

            case .pausePump:
                return .merge(
                    .run { [cursor = state.lastCursorDate, fileURL = state.currentRun?.url] send in
                        guard let fileURL else { return }
                        let newEntries = (try? await logsClient.fetchNewEntries(cursor)) ?? []
                        guard !newEntries.isEmpty else { return }
                        await send(.didReceiveNewEntries(newEntries))
                        try? await logsClient.appendToRunFile(newEntries, fileURL)
                    },
                    .cancel(id: CancelID.pump)
                )

            case let .setCurrentRun(run):
                state.currentRun = run
                return .none

            case .didReceiveNewEntries(let entries):
                state.currentRunLogs.append(contentsOf: entries)
                state.lastCursorDate = entries.last?.date ?? state.lastCursorDate
                if state.selectedRun == nil {
                    refreshDisplayedLogs(&state)
                }
                return .none

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
                    refreshDisplayedLogs(&state)
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
                refreshDisplayedLogs(&state)
                return .none

            case .queryLogs(let keyword):
                state.keyword = keyword
                refreshDisplayedLogs(&state)
                return .none
            }
        }
    }

    private func refreshDisplayedLogs(_ state: inout State) {
        let source = state.selectedRun == nil
            ? state.currentRunLogs
            : state.selectedRunLogs
        state.displayedLogs = logsClient.query(source, state.keyword)
            .sorted { $0.date > $1.date }
    }
}
