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
        // Launch context, derived once per app launch and reused across pump pauses.
        public var currentLaunchCount: Int?
        public var launchDate: Date?
        public var launchFileURL: URL?
        public var lastCursorDate: Date?

        // Live, state-backed logs for the current launch.
        public var currentLaunchLogs = [AppActivityLog]()
        // File-backed log files for previous launches (excludes the current launch).
        public var previousLaunches = [LaunchLogFile]()
        // File-backed logs for the currently selected previous launch.
        public var selectedLaunchLogs = [AppActivityLog]()

        // `nil` selects the current launch (state-backed); otherwise a previous launch count.
        public var selectedLaunchCount: Int?
        public var displayedLogs = [AppActivityLog]()
        public var keyword = ""
        public var loadingState: LoadingState = .idle

        public init() {}
    }

    public enum Action: Equatable, Sendable {
        case startPump
        case pausePump
        case setLaunchContext(launchCount: Int, date: Date, fileURL: URL)
        case didReceiveNewEntries([AppActivityLog])
        case refreshAvailableLaunches
        case availableLaunchesResponse([LaunchLogFile])
        case selectLaunch(Int?)
        case launchFileResponse([AppActivityLog])
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
                return .run { [existingURL = state.launchFileURL, cursor0 = state.lastCursorDate] send in
                    let fileURL: URL
                    if let existingURL {
                        fileURL = existingURL
                    } else {
                        let now = date.now
                        let launchCount = await logsClient.nextLaunchCount(now)
                        let resolvedURL = logsClient.currentLaunchFileURL(launchCount, now)
                        await send(.setLaunchContext(launchCount: launchCount, date: now, fileURL: resolvedURL))
                        fileURL = resolvedURL
                        // A persisted `.notice` so the log always has a baseline entry. Only
                        // `.notice`/`.error`/`.fault` survive in OSLogStore; `.debug`/`.info` do not.
                        let appVersion = Bundle.main
                            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
                        logger.notice("""
                            App activity logging started. \
                            Run \(launchCount, privacy: .public), \
                            version \(appVersion, privacy: .public), \
                            \(ProcessInfo.processInfo.operatingSystemVersionString, privacy: .public).
                            """)
                    }
                    await send(.refreshAvailableLaunches)

                    var cursor = cursor0
                    while !Task.isCancelled {
                        let newEntries = (try? await logsClient.fetchNewEntries(cursor)) ?? []
                        if let lastDate = newEntries.last?.date {
                            cursor = lastDate
                            await send(.didReceiveNewEntries(newEntries))
                            try? await logsClient.appendToLaunchFile(newEntries, fileURL)
                        }
                        try await clock.sleep(for: .seconds(5))
                    }
                }
                .cancellable(id: CancelID.pump, cancelInFlight: true)

            case .pausePump:
                return .merge(
                    .run { [cursor = state.lastCursorDate, fileURL = state.launchFileURL] send in
                        guard let fileURL else { return }
                        let newEntries = (try? await logsClient.fetchNewEntries(cursor)) ?? []
                        guard !newEntries.isEmpty else { return }
                        await send(.didReceiveNewEntries(newEntries))
                        try? await logsClient.appendToLaunchFile(newEntries, fileURL)
                    },
                    .cancel(id: CancelID.pump)
                )

            case let .setLaunchContext(launchCount, date, fileURL):
                state.currentLaunchCount = launchCount
                state.launchDate = date
                state.launchFileURL = fileURL
                return .none

            case .didReceiveNewEntries(let entries):
                state.currentLaunchLogs.append(contentsOf: entries)
                state.lastCursorDate = entries.last?.date ?? state.lastCursorDate
                if state.selectedLaunchCount == nil {
                    refreshDisplayedLogs(&state)
                }
                return .none

            case .refreshAvailableLaunches:
                return .run { send in
                    await send(.availableLaunchesResponse(await logsClient.listLaunchFiles()))
                }

            case .availableLaunchesResponse(let launches):
                // Exclude the current run by file (its count can repeat on earlier days).
                state.previousLaunches = launches.filter { $0.url != state.launchFileURL }
                return .none

            case .selectLaunch(let launchCount):
                guard let launchCount, launchCount != state.currentLaunchCount,
                      let file = state.previousLaunches.first(where: { $0.launchCount == launchCount })
                else {
                    state.selectedLaunchCount = nil
                    state.selectedLaunchLogs = []
                    refreshDisplayedLogs(&state)
                    return .none
                }
                state.selectedLaunchCount = launchCount
                state.loadingState = .loading
                return .run { send in
                    let logs = (try? await logsClient.readLaunchFile(file.url)) ?? []
                    await send(.launchFileResponse(logs))
                }

            case .launchFileResponse(let logs):
                state.loadingState = .idle
                state.selectedLaunchLogs = logs
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
        let source = state.selectedLaunchCount == nil
            ? state.currentLaunchLogs
            : state.selectedLaunchLogs
        state.displayedLogs = logsClient.query(source, state.keyword)
            .sorted { $0.date > $1.date }
    }
}
