import AppModels
@testable import DownloadClient
import Foundation
import Synchronization

/// Scheduled runs for queue cases: each holds the active slot, as a real download does while it runs, until the
/// coordinator cancels it or the case stops the gate; a case's `defer` calls `stop()`.
///
/// Two optional behaviors stage what happens after a cancellation. `holdCancelledRuns()` keeps a cancelled run
/// alive until `releaseCancelledRuns()`, which stages an interleaving inside the interrupt's wait for the run.
/// The hold suspends on a continuation rather than polling with `sleepIgnoringCancellation`: a cancelled task's
/// `Task.sleep` returns at once, so a polling loop in the cancelled run would never suspend and would starve the
/// executor the case needs in order to release it.
/// `runsOperationAfterCancellation` makes the cancelled run invoke the operation it was handed, the scheduler's own
/// `processDownload`, so the exit under test is the run's real `defer`, as `DownloadInterruptedRunWriteBackTests`
/// does.
final class QueueRunGate: Sendable {
    private struct State {
        var isStopped = false
        var holdsCancelledRuns = false
        var heldRuns = [CheckedContinuation<Void, Never>]()
        var cancelledRunCount = 0
        var scheduledGIDs = [String]()
    }

    private let state = Mutex(State())
    private let runsOperationAfterCancellation: Bool

    init(runsOperationAfterCancellation: Bool = false) {
        self.runsOperationAfterCancellation = runsOperationAfterCancellation
    }

    /// The galleries the scheduler started, in start order.
    var scheduledGIDs: [String] {
        state.withLock({ $0.scheduledGIDs })
    }

    /// How many runs ended by cancellation.
    var cancelledRunCount: Int {
        state.withLock({ $0.cancelledRunCount })
    }

    /// Ends every current and later run.
    func stop() {
        let held = state.withLock({ state in
            state.isStopped = true
            return takeHeldRuns(from: &state)
        })
        held.forEach({ $0.resume() })
    }

    /// Keeps each run that is cancelled from now on alive until `releaseCancelledRuns()`.
    func holdCancelledRuns() {
        state.withLock({ $0.holdsCancelledRuns = true })
    }

    func releaseCancelledRuns() {
        let held = state.withLock({ state in
            state.holdsCancelledRuns = false
            return takeHeldRuns(from: &state)
        })
        held.forEach({ $0.resume() })
    }

    private func takeHeldRuns(from state: inout State) -> [CheckedContinuation<Void, Never>] {
        defer { state.heldRuns = [] }
        return state.heldRuns
    }

    /// Suspends the cancelled run until the hold is released or the gate stops, resuming at once when neither holds.
    private func holdCancelledRun() async {
        await withCheckedContinuation({ continuation in
            let resumesNow = state.withLock({ state in
                guard state.holdsCancelledRuns, !state.isStopped else { return true }
                state.heldRuns.append(continuation)
                return false
            })
            if resumesNow {
                continuation.resume()
            }
        })
    }

    var taskRunner: DownloadTaskRunner {
        DownloadTaskRunner(
            recordScheduledGallery: { [self] gid in
                state.withLock({ $0.scheduledGIDs.append(gid) })
            },
            runScheduledDownload: { [self] _, operation in
                while !Task.isCancelled, !state.withLock({ $0.isStopped }) {
                    await sleepIgnoringCancellation(for: .milliseconds(10))
                }
                guard Task.isCancelled, !state.withLock({ $0.isStopped }) else {
                    return .skippedOperation
                }
                state.withLock({ $0.cancelledRunCount += 1 })
                await holdCancelledRun()
                guard runsOperationAfterCancellation else {
                    return .skippedOperation
                }
                await operation()
                return .ranOperation
            }
        )
    }
}

extension DownloadFeatureTestCase {
    /// The waiting group in the order the list shows it.
    func waitingGIDs(in manager: DownloadCoordinator) async -> [String] {
        await manager.indexedDownloads()
            .filter({ $0.displayStatus == .queued })
            .map(\.gid)
    }

    /// An offline stub for a run's detail request; the caller removes it when the case ends.
    func makeOfflineStub() -> String {
        let stubSessionID = UUID().uuidString
        SharedSessionStubURLProtocol.setHandler(for: stubSessionID) { _ in
            throw URLError(.notConnectedToInternet)
        }
        return stubSessionID
    }
}

extension DownloadCoordinator {
    /// Stands in for the retry route's queued intent, so a case can name the mode a run started under without
    /// driving that route's preconditions.
    func stageQueuedMode(_ mode: DownloadStartMode, gid: String) {
        queuedModes[gid] = mode
    }
}
