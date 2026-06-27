import Foundation

// MARK: - Background Processing Drain
extension DownloadCoordinator {
    /// Drives the queue to completion (or until cancelled), pumping the scheduler
    /// itself rather than relying on the detached reschedule `Task` that
    /// `finishActiveTaskIfOwned` installs one hop later.
    ///
    /// Invoked from the `BGProcessingTask` handler. On cancellation (the task's
    /// expiration), the in-flight download is cancelled so the loop can observe the
    /// cancellation and return promptly instead of waiting out a transfer that may not
    /// finish before the process is suspended.
    func runQueueUntilIdle() async {
        while !Task.isCancelled {
            await scheduleNextIfNeeded()
            guard let task = activeTask else {
                if await hasPendingWork() {
                    // The reschedule hop has not installed the next task yet; yield and
                    // re-check rather than declaring the queue idle prematurely.
                    await Task.yield()
                    continue
                }
                break
            }
            await withTaskCancellationHandler {
                await task.value
            } onCancel: {
                task.cancel()
            }
        }
    }
}
