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

        // The cancel above drained S1, so under D-G2B-01 it emitted S1's own terminal push before
        // completing. That push is legitimate — it landed while S1 still owned the card — so the
        // discriminator for the *held* push is not "nothing under S1 was accepted" but "releasing
        // it adds nothing": what crossed the seam under S1 and arrived after S2 took over must be
        // rejected, never appended.
        let acceptedBeforeRelease = spy.progressUpdates
        gate.release()
        await heldPush.value

        expectNoDifference(
            spy.rejectedProgressUpdates.map(\.sessionID),
            [firstClientSessionID]
        )
        expectNoDifference(spy.progressUpdates, acceptedBeforeRelease)

        await fixture.manager.pushContinuedSessionProgress(
            sessionID: secondCoordinatorSessionID
        )
        expectNoDifference(
            spy.progressUpdates.map(\.sessionID),
            [firstClientSessionID, secondClientSessionID]
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

    /// G-15-10: the spy's one-shot refusal arm may be consumed only by the refusal it causes.
    ///
    /// The spy's start refuses for two distinct reasons — the single-session guard (a live
    /// `currentSessionID`) and the armed `refuseNextStart()` — and pre-fix it reset the arm on
    /// both. A case that armed a refusal beside an overlapping start therefore lost the arm to a
    /// refusal it did not cause, and every assertion after that point ran against control state the
    /// case believed it still held. That is the G-15-3 double-fidelity class one layer up: the
    /// double's control surface, rather than its suspension surface, failed to model which event
    /// consumes it.
    ///
    /// The subject under test here is the double itself, so the spy's own client endpoints are the
    /// correct seam and no coordinator participates.
    @Test
    func testASessionGuardRefusalLeavesAnArmedRefusalHeld() async throws {
        let spy = BackgroundProcessingClientSpy()
        let client = spy.client

        let firstSession = try #require(await client.start("Held arm", "0 / 4 pages", 0, 4))

        // Armed while a session is live: the arm belongs to the start it is armed against, not to
        // whatever the single-session guard happens to refuse in the meantime.
        spy.refuseNextStart()
        let guardRefusal = await client.start("Overlapping", "0 / 4 pages", 0, 4)
        #expect(guardRefusal == nil)

        // Terminal cleanup releases the held identity, so the single-session guard stops refusing.
        spy.expire()

        // The armed refusal fires here — the start it was armed for. Pre-fix the overlapping start
        // above burned the arm, so this call minted a session instead of being refused.
        let armedRefusal = await client.start("Armed refusal", "0 / 4 pages", 0, 4)
        #expect(armedRefusal == nil)

        // One-shot: the arm is spent, so the next start mints a real session.
        let fourthSession = try #require(await client.start("Arm spent", "0 / 4 pages", 0, 4))

        #expect(spy.startCount == 4)
        #expect(spy.startSessionIDs.count == 2)
        expectNoDifference(spy.startSessionIDs, [firstSession.id, fourthSession.id])
    }
}
