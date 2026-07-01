import OSLogExt
import Foundation
import AppModels
import Sharing
import LogsClient
import ComposableArchitecture

private let logger = Logger(category: .init(describing: AppActivityLogsPumpReducer.self))

// The always-alive, view-less activity-logs pump. Owned by AppReducer so it outlives Setting
// navigation, it derives the current run once per app run, appends new OS log entries to that run's
// jsonl file every few seconds, and publishes the live current run + its logs via in-memory shared
// state to the (navigation-scoped, read-only) `AppActivityLogsReducer` screen.
@Reducer
public struct AppActivityLogsPumpReducer: Sendable {
    private enum CancelID {
        case pump
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        @Shared(.appActivityLogsCurrentRun) public var currentRun: RunLogFile?
        @Shared(.appActivityLogsCurrentRunLogs) public var currentRunLogs: [AppActivityLog]
        public var lastCursorDate: Date?

        public init() {}
    }

    public enum Action: Equatable, Sendable {
        case startPump
        case pausePump
        case setCurrentRun(RunLogFile)
        case didReceiveNewEntries([AppActivityLog])
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
                state.$currentRun.withLock { $0 = run }
                return .none

            case .didReceiveNewEntries(let entries):
                state.$currentRunLogs.withLock { $0.append(contentsOf: entries) }
                state.lastCursorDate = entries.last?.date ?? state.lastCursorDate
                return .none
            }
        }
    }
}
