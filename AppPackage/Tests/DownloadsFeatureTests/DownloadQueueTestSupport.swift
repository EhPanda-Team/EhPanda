import AppModels
import DownloadClient
import Foundation
import Synchronization

/// Scheduled runs for queue cases: each holds the active slot, as a real download does while it runs, until the
/// coordinator cancels it or the case stops the gate; a case's `defer` calls `stop()`.
final class QueueRunGate: Sendable {
    private struct State {
        var isStopped = false
        var scheduledGIDs = [String]()
    }

    private let state = Mutex(State())

    /// The galleries the scheduler started, in start order.
    var scheduledGIDs: [String] {
        state.withLock({ $0.scheduledGIDs })
    }

    /// Ends every current and later run.
    func stop() {
        state.withLock({ $0.isStopped = true })
    }

    var taskRunner: DownloadTaskRunner {
        DownloadTaskRunner(
            recordScheduledGallery: { [self] gid in
                state.withLock({ $0.scheduledGIDs.append(gid) })
            },
            runScheduledDownload: { [self] _, _ in
                while !Task.isCancelled, !state.withLock({ $0.isStopped }) {
                    await sleepIgnoringCancellation(for: .milliseconds(10))
                }
                return .skippedOperation
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
}
