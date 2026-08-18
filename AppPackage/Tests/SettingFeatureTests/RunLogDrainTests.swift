import AppModels
import Foundation
import LogsClient
import OSLog
import Synchronization
import Testing

/// Pins the atomicity `RunLogDrain` exists for: an entry reaches the run file exactly once however
/// the callers overlap, a failed write leaves the cursor where it was, and a failed read moves
/// nothing at all.
///
/// It lives in this target because `LogsClient` has no test target of its own and its only consumer
/// — the activity-log pump — is tested here. Everything it touches is public API.
///
/// **Every fetch double here is CURSOR-FAITHFUL**, filtering on the `after` it is handed. A double
/// that ignored `after` would answer the same entries to every call and could not discriminate a
/// stale cursor from a fresh one — which is precisely the defect these cases stand for.
@Suite
struct RunLogDrainTests {
    private struct DrainFailure: Error {}

    /// How many fetches are inside the drain at once, and the most that ever were.
    ///
    /// A small named value rather than a pair of counters, because the peak is only meaningful
    /// beside the current depth it was taken from.
    private struct FetchOverlap {
        var current = 0
        var peak = 0
    }

    private static let fileURL = URL(fileURLWithPath: "/tmp/ehpanda-run-log-drain-tests.jsonl")

    @Test
    func aSecondDrainOverTheSameEntriesWritesNothing() async {
        let entryA = Self.makeLog("first", secondsSince1970: 10)
        let entryB = Self.makeLog("second", secondsSince1970: 20)
        let appended = Mutex([[AppActivityLog]]())
        let drain = RunLogDrain(
            fetch: { after in [entryA, entryB].filter({ $0.date > (after ?? .distantPast) }) },
            append: { logs, _ in appended.withLock({ $0.append(logs) }) }
        )

        let first = await drain.drain(into: Self.fileURL)
        let second = await drain.drain(into: Self.fileURL)

        #expect(first == [entryA, entryB])
        #expect(second.isEmpty)
        #expect(appended.withLock({ $0 }) == [[entryA, entryB]])
    }

    @Test
    func overlappingDrainsAppendEachEntryExactlyOnce() async {
        let entryA = Self.makeLog("first", secondsSince1970: 10)
        let entryB = Self.makeLog("second", secondsSince1970: 20)
        let appended = Mutex([[AppActivityLog]]())
        let overlap = Mutex(FetchOverlap())
        let drain = RunLogDrain(
            fetch: { after in
                overlap.withLock { state in
                    state.current += 1
                    state.peak = max(state.peak, state.current)
                }
                defer { overlap.withLock({ $0.current -= 1 }) }
                return [entryA, entryB].filter({ $0.date > (after ?? .distantPast) })
            },
            append: { logs, _ in appended.withLock({ $0.append(logs) }) }
        )

        async let firstDrain = drain.drain(into: Self.fileURL)
        async let secondDrain = drain.drain(into: Self.fileURL)
        let results = await [firstDrain, secondDrain]

        #expect(results.flatMap({ $0 }) == [entryA, entryB])
        #expect(appended.withLock({ $0 }).flatMap({ $0 }) == [entryA, entryB])
        // The whole mechanism, asserted directly: no second fetch may enter while one is inside the
        // drain, because `drain(into:)` has no suspension point for it to enter through.
        #expect(overlap.withLock({ $0.peak }) == 1)
    }

    @Test
    func aFailedAppendLeavesTheCursorSoTheEntriesAreReOffered() async {
        let entryA = Self.makeLog("first", secondsSince1970: 10)
        let entryB = Self.makeLog("second", secondsSince1970: 20)
        let appended = Mutex([[AppActivityLog]]())
        let appendAttempts = Mutex(0)
        let drain = RunLogDrain(
            fetch: { after in [entryA, entryB].filter({ $0.date > (after ?? .distantPast) }) },
            append: { logs, _ in
                let isFirstAttempt = appendAttempts.withLock { attempts in
                    attempts += 1
                    return attempts == 1
                }
                if isFirstAttempt { throw DrainFailure() }
                appended.withLock({ $0.append(logs) })
            }
        )

        let refused = await drain.drain(into: Self.fileURL)
        #expect(refused.isEmpty)
        #expect(appended.withLock({ $0 }).isEmpty)

        let retried = await drain.drain(into: Self.fileURL)
        #expect(retried == [entryA, entryB])
        #expect(appended.withLock({ $0 }) == [[entryA, entryB]])
    }

    @Test
    func aFailedFetchYieldsNothingAndMovesTheCursorNowhere() async {
        let entryA = Self.makeLog("first", secondsSince1970: 10)
        let entryB = Self.makeLog("second", secondsSince1970: 20)
        let appended = Mutex([[AppActivityLog]]())
        let fetchAttempts = Mutex(0)
        let drain = RunLogDrain(
            fetch: { after in
                let isFirstAttempt = fetchAttempts.withLock { attempts in
                    attempts += 1
                    return attempts == 1
                }
                if isFirstAttempt { throw DrainFailure() }
                return [entryA, entryB].filter({ $0.date > (after ?? .distantPast) })
            },
            append: { logs, _ in appended.withLock({ $0.append(logs) }) }
        )

        let refused = await drain.drain(into: Self.fileURL)
        #expect(refused.isEmpty)
        #expect(appended.withLock({ $0 }).isEmpty)

        let recovered = await drain.drain(into: Self.fileURL)
        #expect(recovered == [entryA, entryB])
        #expect(appended.withLock({ $0 }) == [[entryA, entryB]])
    }

    private static func makeLog(
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
