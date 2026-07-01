import OSLog
import Testing
import Sharing
import Foundation
import AppModels
import LogsClient
@testable import SettingFeature
import ComposableArchitecture

@Suite
struct AppActivityLogsReducerTests {
    @MainActor
    @Test
    func testPumpAppendsNewEntriesToStateAndFile() async {
        let entryA = makeLog("first", secondsSince1970: 10)
        let entryB = makeLog("second", secondsSince1970: 20)
        let fetchCount = LockIsolated(0)
        let appended = LockIsolated([[AppActivityLog]]())
        let fileURL = URL(fileURLWithPath: "/tmp/ehpanda-20200101-090000-3.jsonl")

        var client = LogsClient.noop
        client.nextRunCount = { _ in 3 }
        client.currentRunFileURL = { _, _ in fileURL }
        client.fetchNewEntries = { _ in
            fetchCount.withValue { $0 += 1 }
            return fetchCount.value == 1 ? [entryA, entryB] : []
        }
        client.appendToRunFile = { logs, _ in
            appended.withValue { $0.append(logs) }
        }

        let storage = InMemoryStorage()
        await withDependencies {
            $0.defaultInMemoryStorage = storage
        } operation: {
            let store = TestStore(
                initialState: AppActivityLogsPumpReducer.State(),
                reducer: AppActivityLogsPumpReducer.init
            ) {
                $0.logsClient = client
                $0.continuousClock = TestClock()
                $0.date = .constant(.init(timeIntervalSince1970: 0))
                $0.defaultInMemoryStorage = storage
            }
            store.exhaustivity = .off

            await store.send(.startPump)
            await store.receive(\.didReceiveNewEntries)

            #expect(store.state.currentRunLogs == [entryA, entryB])
            #expect(store.state.lastCursorDate == entryB.date)

            await store.send(.pausePump)
            await store.finish()

            // The pump appended the batch to the per-run jsonl file exactly once.
            #expect(appended.value == [[entryA, entryB]])
        }
    }

    @MainActor
    @Test
    func testSelectingPreviousRunLoadsFileBackedLogs() async {
        let fileLog = makeLog("archived", secondsSince1970: 5)
        let run = RunLogFile(
            url: URL(fileURLWithPath: "/tmp/ehpanda-20200101-090000-2.jsonl"),
            date: .init(timeIntervalSince1970: 0),
            runCount: 2
        )
        var client = LogsClient.noop
        client.readRunFile = { _ in [fileLog] }

        let storage = InMemoryStorage()
        await withDependencies {
            $0.defaultInMemoryStorage = storage
        } operation: {
            @Shared(.appActivityLogsCurrentRun) var currentRun: RunLogFile?
            @Shared(.appActivityLogsCurrentRunLogs) var currentRunLogs: [AppActivityLog]
            $currentRun.withLock {
                $0 = RunLogFile(
                    url: URL(fileURLWithPath: "/tmp/ehpanda-20200101-100000-3.jsonl"),
                    date: .init(timeIntervalSince1970: 3600),
                    runCount: 3
                )
            }
            $currentRunLogs.withLock { $0 = [makeLog("live", secondsSince1970: 100)] }

            var initialState = AppActivityLogsReducer.State()
            initialState.previousRuns = [run]

            let store = TestStore(initialState: initialState, reducer: AppActivityLogsReducer.init) {
                $0.logsClient = client
                $0.defaultInMemoryStorage = storage
            }

            await store.send(.selectRun(run.url)) {
                $0.selectedRun = run.url
                $0.loadingState = .loading
            }
            await store.receive(\.runFileResponse) {
                $0.loadingState = .idle
                $0.selectedRunLogs = [fileLog]
            }
            #expect(store.state.displayedLogs == [fileLog])
        }
    }

    @MainActor
    @Test
    func testSelectingCurrentRunRestoresLiveLogs() async {
        let live = makeLog("live", secondsSince1970: 100)

        let storage = InMemoryStorage()
        await withDependencies {
            $0.defaultInMemoryStorage = storage
        } operation: {
            @Shared(.appActivityLogsCurrentRun) var currentRun: RunLogFile?
            @Shared(.appActivityLogsCurrentRunLogs) var currentRunLogs: [AppActivityLog]
            $currentRun.withLock {
                $0 = RunLogFile(
                    url: URL(fileURLWithPath: "/tmp/ehpanda-20200101-100000-3.jsonl"),
                    date: .init(timeIntervalSince1970: 3600),
                    runCount: 3
                )
            }
            $currentRunLogs.withLock { $0 = [live] }

            var initialState = AppActivityLogsReducer.State()
            initialState.selectedRun = URL(fileURLWithPath: "/tmp/ehpanda-20200101-090000-2.jsonl")
            initialState.selectedRunLogs = [makeLog("archived", secondsSince1970: 5)]

            let store = TestStore(initialState: initialState, reducer: AppActivityLogsReducer.init) {
                $0.logsClient = .noop
                $0.defaultInMemoryStorage = storage
            }

            await store.send(.selectRun(nil)) {
                $0.selectedRun = nil
                $0.selectedRunLogs = []
            }
            #expect(store.state.displayedLogs == [live])
        }
    }

    @MainActor
    @Test
    func testQueryLogsFiltersDisplayedLogs() async {
        let hello = makeLog("hello world", secondsSince1970: 10)
        let goodbye = makeLog("goodbye", secondsSince1970: 20)

        let storage = InMemoryStorage()
        await withDependencies {
            $0.defaultInMemoryStorage = storage
        } operation: {
            @Shared(.appActivityLogsCurrentRunLogs) var currentRunLogs: [AppActivityLog]
            $currentRunLogs.withLock { $0 = [hello, goodbye] }

            let store = TestStore(
                initialState: AppActivityLogsReducer.State(),
                reducer: AppActivityLogsReducer.init
            ) {
                $0.logsClient = .noop
                $0.defaultInMemoryStorage = storage
            }

            await store.send(.queryLogs("hello")) {
                $0.keyword = "hello"
            }
            #expect(store.state.displayedLogs == [hello])
        }
    }

    private func makeLog(
        _ message: String,
        secondsSince1970: TimeInterval,
        level: OSLogEntryLog.Level = .info
    ) -> AppActivityLog {
        AppActivityLog(
            date: .init(timeIntervalSince1970: secondsSince1970),
            category: "Test",
            level: level,
            message: message
        )
    }
}
