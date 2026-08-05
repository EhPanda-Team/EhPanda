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

    /// Forwards to `pauseAllSchedulable(expiring:)`, the expiration policy's bulk pause.
    public func testingPauseAllSchedulable(expiring sessionID: UUID) async {
        await pauseAllSchedulable(expiring: sessionID)
    }

    /// Forwards to `prepareWorkingSeedAnnouncingProgress(payload:existingDownload:folderURL:)`, the
    /// redo path's pre-page-work preparation and basis announcement.
    public func testingPrepareWorkingSeedAnnouncingProgress(
        payload: DownloadRequestPayload,
        existingDownload: DownloadedGallery,
        folderURL: URL
    ) async throws -> WorkingSeed {
        try await prepareWorkingSeedAnnouncingProgress(
            payload: payload,
            existingDownload: existingDownload,
            folderURL: folderURL
        )
    }
}
#endif
