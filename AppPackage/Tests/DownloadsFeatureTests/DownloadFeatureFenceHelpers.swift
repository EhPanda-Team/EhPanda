import AppModels
import DownloadClient
import Foundation

extension DownloadFeatureTestCase {
    /// Collects observer snapshots until a sentinel the test itself pushes, and hands back
    /// everything that arrived before it.
    ///
    /// **This is the fence the two missing-notification detectors use instead of a deadline
    /// (DEF-15-09), and the reasoning lives here rather than at either call site.** Those cases ask
    /// whether a convergence exit published its index at all, and the pre-fix answer was a
    /// notification that never came. A clock cannot state that: wall time cannot tell "the
    /// notification will never arrive" from "the parallel suite has not scheduled the collector
    /// yet". The one-second bound that once stood at one of these sites bought nine seconds on a red
    /// run by making every green run a coin flip — plan 15-21 recorded 13.2 s of scheduling delay
    /// there — and the ten-second bound that replaced it still measured the scheduler, not the code.
    ///
    /// Two structural facts make the clock unnecessary. `DownloadObserverHub.observe` registers its
    /// continuation BEFORE returning and the stream is built by `AsyncStream.makeStream` — an
    /// unbounded buffer — and every convergence exit awaits `notifyObservers()` before returning.
    /// So the moment the operation under test returns, its notification is either already buffered
    /// ahead of anything pushed afterwards, or it will never come. Pushing a distinct sentinel at
    /// that point therefore fences the sequence: what the collector reads before the sentinel is the
    /// complete set of notifications the operation produced, no scheduling delay can shorten it, and
    /// a missing notification fails the case immediately, by name, on the assertion that says which
    /// emission is absent.
    ///
    /// Termination is by construction rather than by budget — the caller pushes the fence into a
    /// continuation that is already registered — so there is deliberately no deadline on
    /// `await task.value`, and nothing here relies on cancellation draining the buffer, which
    /// `AsyncStream` does not document. Build the sentinel with a fresh gid (`notify` drops a
    /// snapshot equal to the last one it observed, and a fresh gid can never be equal).
    ///
    /// `waitForTaskValue` and its ten-second default are untouched; its other callers wait on tasks
    /// that no fence can terminate.
    func collectSnapshots(
        from stream: AsyncStream<[DownloadedGallery]>,
        untilFence fenceGID: String
    ) -> Task<[[DownloadedGallery]], Never> {
        Task {
            var emissions = [[DownloadedGallery]]()
            for await snapshot in stream {
                guard snapshot.map(\.gid) != [fenceGID] else { return emissions }
                emissions.append(snapshot)
            }
            return emissions
        }
    }
}
