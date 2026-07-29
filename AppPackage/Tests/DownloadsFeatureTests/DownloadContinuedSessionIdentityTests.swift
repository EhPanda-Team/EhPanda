import CustomDump
import DownloadClient
import Foundation
import Testing

/// Pins the coordinator-side session-identity invariant installed by the round-two gap closure.
///
/// These cases live outside the established lifecycle suite because that file sits at the
/// project's hard file-length boundary (IN-09).
@Suite
struct DownloadContinuedSessionIdentityTests: DownloadFeatureTestCase {
    /// CR-01: a push that crossed the client seam under S1 must be rejected if S2 becomes the
    /// held client session before that push reaches the client's identity guard.
    @Test
    func testAHeldProgressPushCannotRepaintASuccessorSessionsCard() async throws {
        let gid = "210150"
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [
                .init(gid: gid, title: "Held push", pageCount: 5, completedPageCount: 1)
            ],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.ensureContinuedSession()
        let firstCoordinatorSessionID = try #require(
            await fixture.manager.testingContinuedSessionID()
        )
        let firstClientSessionID = try #require(spy.startSessionIDs.first)
        let download = try #require(await fixture.manager.indexedDownloads(gids: [gid]).first)

        let gate = spy.armProgressGate()
        defer { gate.release() }
        let heldPush = Task { @concurrent in
            await fixture.manager.pushContinuedSessionProgress(
                sessionID: firstCoordinatorSessionID
            )
        }
        await gate.entered()

        try await fixture.manager.cancelQueuedWorkItem(download, mode: .update).get()
        #expect(await fixture.manager.testingHasContinuedSession() == false)

        await fixture.manager.testingSetQueuedGalleryIDs([gid])
        await fixture.manager.ensureContinuedSession()
        #expect(spy.startCount == 2)
        #expect(await fixture.manager.testingHasContinuedSession())
        let secondCoordinatorSessionID = try #require(
            await fixture.manager.testingContinuedSessionID()
        )
        let secondClientSessionID = try #require(spy.startSessionIDs.last)

        gate.release()
        await heldPush.value

        expectNoDifference(
            spy.rejectedProgressUpdates.map(\.sessionID),
            [firstClientSessionID]
        )
        #expect(!spy.progressUpdates.contains(where: { $0.sessionID == firstClientSessionID }))

        await fixture.manager.pushContinuedSessionProgress(
            sessionID: secondCoordinatorSessionID
        )
        expectNoDifference(
            spy.progressUpdates.map(\.sessionID),
            [secondClientSessionID]
        )

        _ = await fixture.manager.pause(gid: gid)
        expectNoDifference(
            spy.finishRecords,
            [
                .init(sessionID: firstClientSessionID, success: true),
                .init(sessionID: secondClientSessionID, success: true)
            ]
        )
        #expect(await fixture.manager.testingHasContinuedSession() == false)
    }

    /// CR-01 real-behavior change: a drain crossing an in-flight start defers reconciliation.
    ///
    /// The pre-fix seam cleared ownership mid-start and let a second tap reach an overlapping
    /// start that the live store refuses. This deliberately inverts the old impossible-contract
    /// assertion: the successor tap now folds into the first session instead of starting another.
    @Test
    func testADrainDuringAnInFlightStartDefersReconciliationAndKeepsCoverage() async throws {
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
        defer { gate.release() }
        let firstTap = Task {
            await fixture.manager.ensureContinuedSession()
        }
        await gate.entered()

        let download = try #require(await fixture.manager.indexedDownloads(gids: [gid]).first)
        try await fixture.manager.cancelQueuedWorkItem(download, mode: .update).get()
        #expect(spy.finishRecords.isEmpty)
        #expect(await fixture.manager.testingHasContinuedSession())

        await fixture.manager.testingSetQueuedGalleryIDs([gid])
        await fixture.manager.ensureContinuedSession()
        #expect(spy.startCount == 1)
        #expect(await fixture.manager.testingHasContinuedSession())

        gate.release()
        await firstTap.value

        let firstSessionID = try #require(spy.startSessionIDs.first)
        #expect(spy.finishRecords.isEmpty)
        #expect(spy.startSessionIDs == [firstSessionID])
        #expect(await fixture.manager.testingHasContinuedSession())
        expectNoDifference(
            spy.progressUpdates.map(\.sessionID),
            [firstSessionID]
        )

        _ = await fixture.manager.pause(gid: gid)
        #expect(spy.finishRecords == [
            .init(sessionID: firstSessionID, success: true)
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

    /// WR-08: pause-all belonging to a superseded session stops before its first pause, and the
    /// successor remains live enough to push and finish normally. The post-guard suspension window
    /// itself is covered by `DownloadContinuedSessionInterleaveTests`.
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
