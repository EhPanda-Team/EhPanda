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
}
