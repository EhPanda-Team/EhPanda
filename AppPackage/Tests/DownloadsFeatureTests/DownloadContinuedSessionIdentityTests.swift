import DownloadClient
import Foundation
import Testing

/// Pins the coordinator-side session-identity invariant installed by the round-two gap closure.
///
/// These cases live outside the established lifecycle suite because that file sits at the
/// project's hard file-length boundary (IN-09).
@Suite
struct DownloadContinuedSessionIdentityTests: DownloadFeatureTestCase {
    /// CR-04: draining while a start is in flight, then tapping again, must never let the first
    /// start's bail-out complete the second tap's session. The pre-fix seam finished whichever
    /// session the store held and destroyed the second tap's live coverage.
    @Test
    func testBailOutFinishNeverLandsOnTheMostRecentStartsSession() async throws {
        let gid = "210160"
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [
                .init(gid: gid, title: "Interleaved", pageCount: 5, completedPageCount: 1)
            ],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        let gate = spy.armStartGate()
        let firstTap = Task {
            await fixture.manager.ensureContinuedSession()
        }
        await gate.entered()

        let download = try #require(await fixture.manager.indexedDownloads(gids: [gid]).first)
        try await fixture.manager.cancelQueuedWorkItem(download, mode: .update).get()
        #expect(spy.finishRecords.isEmpty)
        #expect(await fixture.manager.testingHasContinuedSession() == false)

        await fixture.manager.testingSetQueuedGalleryIDs([gid])
        await fixture.manager.ensureContinuedSession()
        #expect(spy.startCount == 2)
        #expect(await fixture.manager.testingHasContinuedSession())

        gate.release()
        await firstTap.value

        let firstSessionID = try #require(spy.startSessionIDs.first)
        let mostRecentSessionID = try #require(spy.startSessionIDs.last)
        let bailOutFinish = try #require(spy.finishRecords.first)
        #expect(spy.finishRecords.count == 1)
        #expect(bailOutFinish.sessionID == firstSessionID)
        #expect(bailOutFinish.sessionID != mostRecentSessionID)
        #expect(bailOutFinish.success)
        #expect(await fixture.manager.testingHasContinuedSession())

        let survivorSessionID = try #require(
            await fixture.manager.testingContinuedSessionID()
        )
        let updatesBeforePush = spy.progressUpdates.count
        await fixture.manager.pushContinuedSessionProgress(sessionID: survivorSessionID)
        #expect(spy.progressUpdates.count == updatesBeforePush + 1)

        _ = await fixture.manager.pause(gid: gid)
        #expect(spy.finishRecords == [
            .init(sessionID: firstSessionID, success: true),
            .init(sessionID: mostRecentSessionID, success: true)
        ])
        #expect(await fixture.manager.testingHasContinuedSession() == false)
    }

    /// WR-01: a refused store start must synchronously surrender coordinator ownership so the
    /// next queue-mobilizing tap can install a real session instead of consuming a dead stream.
    @Test
    func testARefusedStartRollsBookkeepingBackAndTheNextTapStartsARealSession() async throws {
        let gid = "210170"
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [
                .init(gid: gid, title: "Retryable", pageCount: 6, completedPageCount: 2)
            ],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        spy.refuseNextStart()
        await fixture.manager.ensureContinuedSession()

        #expect(spy.startCount == 1)
        #expect(await fixture.manager.testingHasContinuedSession() == false)
        #expect(spy.finishRecords.isEmpty)

        await fixture.manager.ensureContinuedSession()
        #expect(spy.startCount == 2)
        #expect(await fixture.manager.testingHasContinuedSession())

        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        let updatesBeforePush = spy.progressUpdates.count
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)
        #expect(spy.progressUpdates.count == updatesBeforePush + 1)

        _ = await fixture.manager.pause(gid: gid)
        #expect(spy.finishRecords == [
            .init(sessionID: try #require(spy.startSessionIDs.last), success: true)
        ])
        #expect(await fixture.manager.testingHasContinuedSession() == false)
    }

    /// WR-08: an expiration from a superseded session must stop before pausing any work covered
    /// by the successor, and the successor must remain live enough to push and finish normally.
    @Test
    func testAForeignExpirationCannotPauseWorkASuccessorSessionCovers() async throws {
        let gid = "210180"
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [
                .init(gid: gid, title: "Successor", pageCount: 7, completedPageCount: 3)
            ],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.ensureContinuedSession()
        #expect(spy.startCount == 1)
        #expect(await fixture.manager.testingHasContinuedSession())

        await fixture.manager.pauseAllSchedulable(expiring: UUID())
        #expect(spy.finishRecords.isEmpty)
        #expect(await fixture.manager.testingHasContinuedSession())

        let updatesBeforeReconcile = spy.progressUpdates.count
        await fixture.manager.reconcileContinuedSession()
        #expect(spy.progressUpdates.count == updatesBeforeReconcile + 1)
        #expect(spy.finishRecords.isEmpty)

        _ = await fixture.manager.pause(gid: gid)
        #expect(spy.finishRecords == [
            .init(sessionID: try #require(spy.startSessionIDs.last), success: true)
        ])
        #expect(await fixture.manager.testingHasContinuedSession() == false)
    }
}
