import AppModels
import Foundation

#if DEBUG
/// The module's one test seam, compiled out of release builds.
///
/// It carries only members a suite actually consumes: an unconsumed forwarder is attack surface
/// rather than a seam, which is exactly what G-15-11 removed by dropping the session-lifecycle
/// mutators to internal. A future test that needs one of the remaining mutators adds its forwarder
/// then.
extension DownloadCoordinator {
    public func testingInstallActiveTask(
        gid: String,
        task: Task<Void, Never>
    ) {
        // This test seam installs ownership; it does not clear completed work and is outside
        // ACTIVE-OWNERSHIP CONVERGENCE.
        activeTaskGeneration += 1
        activeGalleryID = gid
        activeTask = task
    }

    public func testingSetActiveGalleryID(_ gid: String?) {
        activeGalleryID = gid
    }

    public func testingSetQueuedGalleryIDs(_ gids: [String]) async {
        await queueStore.removeAll()
        for gid in gids {
            await queueStore.enqueue(gid)
        }
    }

    public func testingSetDownloadError(
        _ failure: DownloadFailure?,
        gid: String
    ) {
        downloadErrors[gid] = failure
    }

    public func testingSetFailedPageErrors(
        _ failures: [PageFailure],
        gid: String
    ) {
        failedPageErrors[gid] = Dictionary(
            uniqueKeysWithValues: failures.map({ ($0.index, $0) })
        )
    }

    public func testingSetUpdatedGalleryIDs(_ gids: Set<String>) {
        updatedGalleryIDs = gids
    }

    public func testingHasActiveTask() -> Bool {
        activeTask != nil
    }

    public func testingActiveGalleryID() -> String? {
        activeGalleryID
    }

    public func testingHasContinuedSession() -> Bool {
        hasLiveContinuedSession
    }

    /// Returns the coordinator identity the current continued-processing session must present to
    /// every late-arriving mutation.
    public func testingContinuedSessionID() -> UUID? {
        continuedSessionID
    }

    /// Forwards to `ensureContinuedSession()`, the coordinator's single session-start entry point.
    public func testingEnsureContinuedSession() async {
        await ensureContinuedSession()
    }

    /// Forwards to `pushContinuedSessionProgress(sessionID:)`, the coordinator's only route from a
    /// schedulable snapshot onto the system card.
    public func testingPushContinuedSessionProgress(sessionID: UUID) async {
        await pushContinuedSessionProgress(sessionID: sessionID)
    }

    /// Forwards to `reconcileContinuedSession()`, the scheduling tail's session convergence point.
    public func testingReconcileContinuedSession() async {
        await reconcileContinuedSession()
    }

    /// Forwards to `markContinuedSessionEnded(sessionID:)`, the coordinator's session teardown.
    public func testingMarkContinuedSessionEnded(sessionID: UUID) {
        markContinuedSessionEnded(sessionID: sessionID)
    }

    /// The task consuming the live session's event stream — the exact settle point for an
    /// expiration, whose whole policy runs inside that task.
    ///
    /// Stated as the rule every consumer obeys rather than as a roster of them, because a roster
    /// goes stale the next time an interleave case is added: the capture must be taken BEFORE the
    /// expiration is fired, since the handler nils the property on its way through and a capture
    /// taken afterwards hands back `nil` with no settle point at all.
    public func testingContinuedSessionTask() -> Task<Void, Never>? {
        continuedSessionTask
    }

    /// Forwards to `pauseAllSchedulable(expiring:)`, the expiration policy's bulk pause.
    public func testingPauseAllSchedulable(expiring sessionID: UUID) async {
        await pauseAllSchedulable(expiring: sessionID)
    }

    /// The galleries at least one live operation currently holds a scheduling block on.
    ///
    /// The keys rather than the counts: a parity comparison asks which galleries are blocked, and
    /// spelling that as a `Set` keeps those assertions reading exactly as they did against the
    /// former set-typed storage.
    public func testingSchedulingBlockedGalleryIDs() -> Set<String> {
        Set(schedulingBlockedGalleryCounts.keys)
    }

    /// Whether `gid` is currently blocked from scheduling — the exact fact
    /// `isSchedulableDownload` tests before it consults `shouldSchedule`.
    public func testingIsSchedulingBlocked(_ gid: String) -> Bool {
        schedulingBlockedGalleryCounts[gid] != nil
    }

    /// Forwards to `blockScheduling(gid:)`, one operation's claim on the gallery's scheduling
    /// block, so a suite can stage two overlapping holders without racing two real operations.
    public func testingBlockScheduling(gid: String) {
        blockScheduling(gid: gid)
    }

    /// Forwards to `releaseScheduling(gid:)`, one operation's hand-back of that block.
    ///
    /// Two consumers: the overlapping-holders case, and the canary that drives an *unmatched*
    /// release — a call no production path makes, and the only way to prove the guard reports the
    /// violation and still mutates nothing.
    public func testingReleaseScheduling(gid: String) {
        releaseScheduling(gid: gid)
    }

    /// Deliberately writes the one shape the counted-basis bracket's SIBLINGS-only rule forbids: a
    /// synchronous actor-isolated movement called from inside another bracket's body.
    ///
    /// The inner movement is `advanceQueueIntentGeneration(for:)`, a real production mover that
    /// brackets itself, rather than a contrived empty closure — so the probe reproduces the exact
    /// shape a future queue-mobilizing path would be written in.
    ///
    /// It exists because the rule has no compile-time enforcement to point at. The bracket's closure
    /// is non-escaping and non-`Sendable`, so it inherits the enclosing actor isolation and this
    /// nesting compiles; what refuses it is the depth counter, and a detector nobody has watched fire
    /// is a convention wearing a test's clothes. This is the module's ONE deliberate nesting call
    /// site, and `DownloadSourceInventoryTests`' bracket census names it as such.
    public func testingProbeNestedBasisMovement(gid: String) {
        withdrawingCountedBasisMovement(gid: gid) {
            advanceQueueIntentGeneration(for: gid)
        }
    }

    /// Forwards to `prepareWorkingSeedAnnouncingProgress(payload:existingDownload:folderURL:)`, the
    /// redo path's pre-page-work preparation and basis announcement.
    ///
    /// It returns the whole prepared run rather than only the seed, because the run's pending page
    /// list is what the announcement is gated on: a forwarder that dropped it would let a suite
    /// assert over the seed while the decision it cares about stayed invisible.
    public func testingPrepareWorkingSeedAnnouncingProgress(
        payload: DownloadRequestPayload,
        existingDownload: DownloadedGallery,
        folderURL: URL
    ) async throws -> PreparedWorkingRun {
        try await prepareWorkingSeedAnnouncingProgress(
            payload: payload,
            existingDownload: existingDownload,
            folderURL: folderURL
        )
    }
}
#endif
