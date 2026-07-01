import OSLog
import Testing
import Foundation
import AppModels
import LogsClient
import SettingFeature
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

        let store = TestStore(initialState: AppActivityLogsReducer.State(), reducer: AppActivityLogsReducer.init) {
            $0.logsClient = client
            $0.continuousClock = TestClock()
            $0.date = .constant(.init(timeIntervalSince1970: 0))
        }
        store.exhaustivity = .off

        await store.send(.startPump)
        await store.receive(\.didReceiveNewEntries)

        #expect(store.state.currentRunLogs == [entryA, entryB])
        #expect(store.state.lastCursorDate == entryB.date)
        // Newest entry is shown first.
        #expect(store.state.displayedLogs == [entryB, entryA])

        await store.send(.pausePump)
        await store.finish()

        // The pump appended the batch to the per-run jsonl file exactly once.
        #expect(appended.value == [[entryA, entryB]])
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

        var initialState = AppActivityLogsReducer.State()
        initialState.currentRun = RunLogFile(
            url: URL(fileURLWithPath: "/tmp/ehpanda-20200101-100000-3.jsonl"),
            date: .init(timeIntervalSince1970: 3600),
            runCount: 3
        )
        initialState.previousRuns = [run]
        initialState.currentRunLogs = [makeLog("live", secondsSince1970: 100)]

        let store = TestStore(initialState: initialState, reducer: AppActivityLogsReducer.init) {
            $0.logsClient = client
        }

        await store.send(.selectRun(run.url)) {
            $0.selectedRun = run.url
            $0.loadingState = .loading
        }
        await store.receive(\.runFileResponse) {
            $0.loadingState = .idle
            $0.selectedRunLogs = [fileLog]
            $0.displayedLogs = [fileLog]
        }
    }

    @MainActor
    @Test
    func testSelectingCurrentRunRestoresLiveLogs() async {
        let live = makeLog("live", secondsSince1970: 100)
        var initialState = AppActivityLogsReducer.State()
        initialState.currentRun = RunLogFile(
            url: URL(fileURLWithPath: "/tmp/ehpanda-20200101-100000-3.jsonl"),
            date: .init(timeIntervalSince1970: 3600),
            runCount: 3
        )
        initialState.currentRunLogs = [live]
        initialState.selectedRun = URL(fileURLWithPath: "/tmp/ehpanda-20200101-090000-2.jsonl")
        initialState.selectedRunLogs = [makeLog("archived", secondsSince1970: 5)]
        initialState.displayedLogs = initialState.selectedRunLogs

        let store = TestStore(initialState: initialState, reducer: AppActivityLogsReducer.init) {
            $0.logsClient = .noop
        }

        await store.send(.selectRun(nil)) {
            $0.selectedRun = nil
            $0.selectedRunLogs = []
            $0.displayedLogs = [live]
        }
    }

    @MainActor
    @Test
    func testQueryLogsFiltersDisplayedLogs() async {
        let hello = makeLog("hello world", secondsSince1970: 10)
        let goodbye = makeLog("goodbye", secondsSince1970: 20)
        var client = LogsClient.noop
        client.query = { logs, keyword in logs.filter { $0.message.contains(keyword) } }

        var initialState = AppActivityLogsReducer.State()
        initialState.currentRunLogs = [hello, goodbye]

        let store = TestStore(initialState: initialState, reducer: AppActivityLogsReducer.init) {
            $0.logsClient = client
        }

        await store.send(.queryLogs("hello")) {
            $0.keyword = "hello"
            $0.displayedLogs = [hello]
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
