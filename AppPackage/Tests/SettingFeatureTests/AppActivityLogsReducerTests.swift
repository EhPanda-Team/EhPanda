import AnalyticsClient
import AppModels
import ComposableArchitecture
import Foundation
import LogsClient
import OSLog
@testable import SettingFeature
import Sharing
import Testing

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
@Suite
struct AppActivityLogsReducerTests {
    @MainActor
    @Test
    func testPumpAppendsNewEntriesToStateAndFile() async {
        let entryA = makeLog("first", secondsSince1970: 10)
        let entryB = makeLog("second", secondsSince1970: 20)
        let appended = LockIsolated([[AppActivityLog]]())
        let fileURL = URL(fileURLWithPath: "/tmp/ehpanda-20200101-090000-3.jsonl")

        let client = Self.pumpClient(
            entries: [entryA, entryB],
            runCount: 3,
            fileURL: fileURL,
            appended: appended
        )

        let storage = InMemoryStorage()
        await withDependencies {
            $0.defaultInMemoryStorage = storage
        } operation: {
            let store = TestStore(
                initialState: AppActivityLogsPumpReducer.State(),
                reducer: AppActivityLogsPumpReducer.init
            ) {
                $0.analyticsClient = .noop
                $0.logsClient = client
                $0.continuousClock = TestClock()
                $0.date = .constant(.init(timeIntervalSince1970: 0))
                $0.defaultInMemoryStorage = storage
            }
            // The live view is published from inside the effect rather than through an action, so
            // WHEN the batch lands relative to the next `send` is scheduling, not contract. The
            // settled state is asserted once, after `finish()`, which is the deterministic point.
            store.exhaustivity = .off

            await store.send(.startPump)
            await store.send(.pausePump)
            await store.finish()

            store.assert {
                $0.isPumpRunning = false
                $0.$currentRun.withLock {
                    $0 = RunLogFile(
                        url: fileURL,
                        date: .init(timeIntervalSince1970: 0),
                        runCount: 3
                    )
                }
                $0.$currentRunLogs.withLock({ $0 = [entryA, entryB] })
            }
            // The pump appended the batch to the per-run jsonl file exactly once.
            #expect(appended.value == [[entryA, entryB]])
        }
    }

    @MainActor
    @Test
    func startPumpTwiceDerivesTheRunOnce() async {
        let runCountCalls = LockIsolated(0)
        let fileURL = URL(fileURLWithPath: "/tmp/ehpanda-20200101-090000-3.jsonl")

        var client = LogsClient.noop
        client.currentRunFileURL = { _, _ in fileURL }
        client.nextRunCount = { _ in
            runCountCalls.withValue({ $0 += 1 })
            return 3
        }

        let storage = InMemoryStorage()
        await withDependencies {
            $0.defaultInMemoryStorage = storage
        } operation: {
            let store = TestStore(
                initialState: AppActivityLogsPumpReducer.State(),
                reducer: AppActivityLogsPumpReducer.init
            ) {
                $0.analyticsClient = .noop
                $0.logsClient = client
                $0.continuousClock = TestClock()
                $0.date = .constant(.init(timeIntervalSince1970: 0))
                $0.defaultInMemoryStorage = storage
            }

            await store.send(.startPump) {
                $0.isPumpRunning = true
                $0.$currentRun.withLock {
                    $0 = RunLogFile(
                        url: fileURL,
                        date: .init(timeIntervalSince1970: 0),
                        runCount: 3
                    )
                }
            }
            // A start on a running pump changes nothing and starts no second loop, which is what
            // keeps the run — and the "App activity logging started" header naming it — singular.
            await store.send(.startPump)
            await store.send(.pausePump) {
                $0.isPumpRunning = false
            }
            await store.finish()

            #expect(runCountCalls.value == 1)
        }
    }

    /// RED against the pre-fix reducer, whose start and pause effects each snapshotted the cursor
    /// from state and appended after an action `send` that a cancellation could swallow: both
    /// fetched from the same nil cursor and both wrote the batch.
    @MainActor
    @Test
    func overlappingStartPauseStartAppendsEachEntryOnce() async {
        let entryA = makeLog("first", secondsSince1970: 10)
        let entryB = makeLog("second", secondsSince1970: 20)
        let appended = LockIsolated([[AppActivityLog]]())
        let fileURL = URL(fileURLWithPath: "/tmp/ehpanda-20200101-090000-4.jsonl")

        let client = Self.pumpClient(
            entries: [entryA, entryB],
            runCount: 4,
            fileURL: fileURL,
            appended: appended
        )

        let storage = InMemoryStorage()
        await withDependencies {
            $0.defaultInMemoryStorage = storage
        } operation: {
            let store = TestStore(
                initialState: AppActivityLogsPumpReducer.State(),
                reducer: AppActivityLogsPumpReducer.init
            ) {
                $0.analyticsClient = .noop
                $0.logsClient = client
                $0.continuousClock = TestClock()
                $0.date = .constant(.init(timeIntervalSince1970: 0))
                $0.defaultInMemoryStorage = storage
            }
            store.exhaustivity = .off

            await store.send(.startPump)
            await store.send(.pausePump)
            await store.send(.startPump)
            await store.send(.pausePump)
            await store.finish()

            #expect(appended.value.flatMap({ $0 }) == [entryA, entryB])
            #expect(store.state.currentRunLogs == [entryA, entryB])
        }
    }

    /// A pump client whose drain is a real `RunLogDrain` over a CURSOR-FAITHFUL fetch: a double that
    /// ignored `after` would answer the same entries to every tick and could not discriminate the
    /// stale-cursor defect these cases stand for.
    private static func pumpClient(
        entries: [AppActivityLog],
        runCount: Int,
        fileURL: URL,
        appended: LockIsolated<[[AppActivityLog]]>
    ) -> LogsClient {
        let drain = RunLogDrain(
            fetch: { after in entries.filter({ $0.date > (after ?? .distantPast) }) },
            append: { logs, _ in appended.withValue({ $0.append(logs) }) }
        )
        var client = LogsClient.noop
        client.nextRunCount = { _ in runCount }
        client.currentRunFileURL = { _, _ in fileURL }
        client.drainNewEntries = { url in await drain.drain(into: url) }
        return client
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
                $0.analyticsClient = .noop
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
            $currentRunLogs.withLock({ $0 = [live] })

            var initialState = AppActivityLogsReducer.State()
            initialState.selectedRun = URL(fileURLWithPath: "/tmp/ehpanda-20200101-090000-2.jsonl")
            initialState.selectedRunLogs = [makeLog("archived", secondsSince1970: 5)]

            let store = TestStore(initialState: initialState, reducer: AppActivityLogsReducer.init) {
                $0.analyticsClient = .noop
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
            $currentRunLogs.withLock({ $0 = [hello, goodbye] })

            let store = TestStore(
                initialState: AppActivityLogsReducer.State(),
                reducer: AppActivityLogsReducer.init
            ) {
                $0.analyticsClient = .noop
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
