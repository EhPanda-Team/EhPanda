import AppModels
import ComposableArchitecture
import Foundation
import LogsClient
import OSLogExt
import Sharing

private let logger = Logger(category: .init(describing: AppActivityLogsPumpReducer.self))

// The always-alive, view-less activity-logs pump. Owned by AppReducer so it outlives Setting
// navigation, it derives the current run once per app run, appends new OS log entries to that run's
// jsonl file every few seconds, and publishes the live current run + its logs via in-memory shared
// state to the (navigation-scoped, read-only) `AppActivityLogsReducer` screen.
//
// **The cursor lives in `RunLogDrain`, not here.** This reducer owns WHEN to tick; the drain owns
// what one tick means — fetch, append and cursor-advance as one serialized step. That split is the
// fix for the ×3-duplicated jsonl lines: a cursor snapshotted into effect state, advanced through
// an action `send` and followed by an unguarded disk append could both lose the advance (a
// cancelled `Send` is a no-op) and start two effects from the same stale value.
//
// **A start on a running pump is a no-op**, and the run is derived synchronously inside the reduce
// step that first starts it — so the run, and the "App activity logging started" header that names
// it, exist exactly once per process by construction rather than by whichever effect wins a race.
//
// **This pump knows nothing about downloads.** AppReducer decides when to pause it: on `.background`
// only when no continued-processing session is live, and on the live→ended transition while
// backgrounded, so background-side lines reach disk before the process can be killed.
@Reducer
public struct AppActivityLogsPumpReducer: Sendable {
    private enum CancelID {
        case pump
    }

    @ObservableState
    public struct State: Equatable, Sendable {
        @Shared(.appActivityLogsCurrentRun) public var currentRun: RunLogFile?
        @Shared(.appActivityLogsCurrentRunLogs) public var currentRunLogs: [AppActivityLog]
        /// Whether a pump effect is in flight. This is the idempotence guard: it replaces
        /// `cancelInFlight`, which restarted the loop on every `.active` bounce.
        public var isPumpRunning = false

        public init() {}
    }

    public enum Action: Equatable, Sendable {
        case startPump
        case pausePump
    }

    @Dependency(\.logsClient) private var logsClient
    @Dependency(\.continuousClock) private var clock
    @Dependency(\.date) private var date

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startPump:
                guard !state.isPumpRunning else { return .none }
                let isFirstStart = state.currentRun == nil
                let run: RunLogFile
                if let currentRun = state.currentRun {
                    run = currentRun
                } else {
                    // Derived in the reduce step rather than in the effect: `nextRunCount` is a
                    // directory listing, and establishing the run here is what makes it a fact of
                    // the state transition instead of a race between two effects.
                    let now = date.now
                    let runCount = logsClient.nextRunCount(now)
                    run = RunLogFile(
                        url: logsClient.currentRunFileURL(runCount, now),
                        date: now,
                        runCount: runCount
                    )
                    state.$currentRun.withLock({ $0 = run })
                }
                state.isPumpRunning = true

                return .run { [logs = state.$currentRunLogs, fileURL = run.url, runCount = run.runCount] _ in
                    if isFirstStart {
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

                    while !Task.isCancelled {
                        let batch = await logsClient.drainNewEntries(fileURL)
                        if !batch.isEmpty {
                            // Published by mutating the captured shared value directly rather than
                            // through `send`: `Send` is a no-op once this effect is cancelled, and
                            // the whole point is that a cancelled tick can never lose a batch the
                            // file already holds. The drain has already written it.
                            logs.withLock({ $0.append(contentsOf: batch) })
                        }
                        // A cancelled sleep throws `CancellationError`, which `.run` swallows.
                        try await clock.sleep(for: .seconds(5))
                    }
                }
                .cancellable(id: CancelID.pump)

            case .pausePump:
                state.isPumpRunning = false
                guard let fileURL = state.currentRun?.url else { return .cancel(id: CancelID.pump) }
                return .merge(
                    .cancel(id: CancelID.pump),
                    .run { [logs = state.$currentRunLogs] _ in
                        let batch = await logsClient.drainNewEntries(fileURL)
                        guard !batch.isEmpty else { return }
                        logs.withLock({ $0.append(contentsOf: batch) })
                    }
                )
            }
        }
    }
}
