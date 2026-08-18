import Foundation

// MARK: - Continued Session Liveness
extension DownloadCoordinator {
    /// Reports whether a continued-processing session is currently held, now and at every later
    /// transition.
    ///
    /// **Why the coordinator publishes this at all.** The activity-log pump is paused when the app
    /// backgrounds, which is correct while nothing keeps the process alive — and wrong exactly when
    /// a session does, because the lines worth reading (an expiry, its pause sweep) are emitted on
    /// the background side and never reach disk. The pump must not know about downloads, so the
    /// download client publishes the fact and `AppReducer` — which already owns both — decides.
    ///
    /// The current value is yielded on subscribe rather than only on the next change, so a consumer
    /// that starts mid-session is not told "not live" by silence. `bufferingNewest(1)` matches the
    /// value's shape: a late consumer wants the CURRENT liveness, never the history of it.
    public func observeContinuedSessionLiveness() -> AsyncStream<Bool> {
        let identifier = UUID()
        let (stream, continuation) = AsyncStream.makeStream(
            of: Bool.self,
            bufferingPolicy: .bufferingNewest(1)
        )
        continuedSessionLivenessContinuations[identifier] = continuation
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task {
                await self.removeContinuedSessionLivenessObserver(identifier: identifier)
            }
        }
        continuation.yield(continuedSessionID != nil)
        return stream
    }

    /// Announces a session boundary to every observer.
    ///
    /// Called from exactly two places, and they are the two the session's own identity moves at:
    /// `ensureContinuedSession` immediately after `continuedClientSessionID` lands, and
    /// `markContinuedSessionEnded` behind its identity guard — so a superseded teardown announces
    /// nothing, exactly as it clears nothing.
    func publishContinuedSessionLiveness(_ isLive: Bool) {
        continuedSessionLivenessContinuations.values.forEach({ $0.yield(isLive) })
    }

    private func removeContinuedSessionLivenessObserver(identifier: UUID) {
        continuedSessionLivenessContinuations[identifier] = nil
    }
}
