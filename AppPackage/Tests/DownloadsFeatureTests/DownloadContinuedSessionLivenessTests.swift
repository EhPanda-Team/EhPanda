import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing

/// The seam that lets the activity-log pump outlive a background transition: the coordinator
/// publishes whether it currently holds a continued-processing session, and `AppReducer` decides
/// what to do about it.
///
/// The stream's contract has two halves and both are asserted here, in order: the CURRENT value on
/// subscribe — so a consumer starting mid-session is not told "not live" by silence — and every
/// transition after it.
@Suite
struct DownloadContinuedSessionLivenessTests: DownloadFeatureTestCase {
    @Test
    func theStreamReportsTheCurrentValueOnSubscribeThenEveryTransition() async throws {
        let gid = "220010"
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [.init(gid: gid, title: "Liveness", pageCount: 4)],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        var liveness = await fixture.manager.observeContinuedSessionLiveness().makeAsyncIterator()

        let onSubscribe = await liveness.next()
        #expect(onSubscribe == false)

        await fixture.manager.testingEnsureContinuedSession()
        let afterStart = await liveness.next()
        #expect(afterStart == true)

        // Captured before the expiration fires: the handler nils the task on its way through, so a
        // capture taken afterwards has no settle point at all.
        let sessionTask = try #require(await fixture.manager.testingContinuedSessionTask())
        spy.expire()
        try await waitForTaskValue(
            sessionTask,
            timeout: .seconds(10),
            description: "the session's consuming task to finish after expiration"
        )

        let afterEnd = await liveness.next()
        #expect(afterEnd == false)
        #expect(!(await fixture.manager.testingHasContinuedSession()))
    }
}
