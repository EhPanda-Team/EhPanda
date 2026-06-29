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
        let fileURL = URL(fileURLWithPath: "/tmp/ehpanda-20200101-3.jsonl")

        var client = LogsClient.noop
        client.nextLaunchCount = { _ in 3 }
        client.currentLaunchFileURL = { _, _ in fileURL }
        client.fetchNewEntries = { _ in
            fetchCount.withValue { $0 += 1 }
            return fetchCount.value == 1 ? [entryA, entryB] : []
        }
        client.appendToLaunchFile = { logs, _ in
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

        #expect(store.state.currentLaunchLogs == [entryA, entryB])
        #expect(store.state.lastCursorDate == entryB.date)
        // Newest entry is shown first.
        #expect(store.state.displayedLogs == [entryB, entryA])

        await store.send(.pausePump)
        await store.finish()

        // The pump appended the batch to the per-launch jsonl file exactly once.
        #expect(appended.value == [[entryA, entryB]])
    }

    @MainActor
    @Test
    func testSelectingPreviousLaunchLoadsFileBackedLogs() async {
        let fileLog = makeLog("archived", secondsSince1970: 5)
        let launch = LaunchLogFile(
            url: URL(fileURLWithPath: "/tmp/ehpanda-20200101-2.jsonl"),
            date: .init(timeIntervalSince1970: 0),
            launchCount: 2
        )
        var client = LogsClient.noop
        client.readLaunchFile = { _ in [fileLog] }

        var initialState = AppActivityLogsReducer.State()
        initialState.currentLaunchCount = 3
        initialState.previousLaunches = [launch]
        initialState.currentLaunchLogs = [makeLog("live", secondsSince1970: 100)]

        let store = TestStore(initialState: initialState, reducer: AppActivityLogsReducer.init) {
            $0.logsClient = client
        }

        await store.send(.selectLaunch(2)) {
            $0.selectedLaunchCount = 2
            $0.loadingState = .loading
        }
        await store.receive(\.launchFileResponse) {
            $0.loadingState = .idle
            $0.selectedLaunchLogs = [fileLog]
            $0.displayedLogs = [fileLog]
        }
    }

    @MainActor
    @Test
    func testSelectingCurrentLaunchRestoresLiveLogs() async {
        let live = makeLog("live", secondsSince1970: 100)
        var initialState = AppActivityLogsReducer.State()
        initialState.currentLaunchCount = 3
        initialState.currentLaunchLogs = [live]
        initialState.selectedLaunchCount = 2
        initialState.selectedLaunchLogs = [makeLog("archived", secondsSince1970: 5)]
        initialState.displayedLogs = initialState.selectedLaunchLogs

        let store = TestStore(initialState: initialState, reducer: AppActivityLogsReducer.init) {
            $0.logsClient = .noop
        }

        await store.send(.selectLaunch(nil)) {
            $0.selectedLaunchCount = nil
            $0.selectedLaunchLogs = []
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
        initialState.currentLaunchLogs = [hello, goodbye]

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
