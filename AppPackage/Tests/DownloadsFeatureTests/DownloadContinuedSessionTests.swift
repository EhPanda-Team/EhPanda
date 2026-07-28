import BackgroundProcessingClient
import DownloadClient
import Testing

@Suite
struct DownloadContinuedSessionTests: DownloadFeatureTestCase {
    /// Every endpoint of the unimplemented test value must report an issue when called. That is
    /// the whole point of the seam's `testValue`: a call the test did not arrange for fails the
    /// test loudly instead of silently succeeding against a do-nothing stub.
    @Test
    func testUnimplementedClientReportsAnIssueForEveryEndpoint() async {
        let client = BackgroundProcessingClient()

        await withKnownIssue("start is unimplemented") {
            _ = await client.start("Downloading galleries", "0 / 10 pages · 1 gallery")
        }
        await withKnownIssue("updateProgress is unimplemented") {
            await client.updateProgress(3, 10, "3 / 10 pages · 1 gallery")
        }
        await withKnownIssue("finish is unimplemented") {
            await client.finish(true)
        }
    }

    /// The no-op value is inert in both directions: it starts nothing, and the stream it hands
    /// back is already finished, so a consumer written against the live contract drops straight
    /// out of its loop rather than hanging on a session that will never report.
    @Test
    func testNoopClientStartsAnAlreadyFinishedStream() async {
        let client = BackgroundProcessingClient.noop

        var events = [BackgroundProcessingEvent]()
        for await event in await client.start("Downloading galleries", "0 / 10 pages · 1 gallery") {
            events.append(event)
        }
        #expect(events.isEmpty)

        await client.updateProgress(3, 10, "3 / 10 pages · 1 gallery")
        await client.finish(true)
    }

    /// The spy has to hold up the same contract the live client does, because every later
    /// behavior assertion reads its recordings and drives its events. Note the drain loop below
    /// exits without anything cancelling it: `expire()` finishes the stream itself, exactly as
    /// the live session does after the system reclaims or the user cancels the card.
    @Test
    func testSpyRecordsPushedValuesAndFinishesItsStreamOnExpiration() async {
        let spy = BackgroundProcessingClientSpy()
        let client = spy.client

        let stream = await client.start("Downloading galleries", "0 / 10 pages · 1 gallery")
        #expect(spy.startCount == 1)
        #expect(spy.startTitles == ["Downloading galleries"])
        #expect(spy.startSubtitles == ["0 / 10 pages · 1 gallery"])

        spy.emit(.granted)
        await client.updateProgress(3, 10, "3 / 10 pages · 1 gallery")
        #expect(spy.progressUpdates == [
            .init(
                completedUnitCount: 3,
                totalUnitCount: 10,
                subtitle: "3 / 10 pages · 1 gallery"
            )
        ])

        spy.expire()

        var events = [BackgroundProcessingEvent]()
        for await event in stream {
            events.append(event)
        }
        #expect(events == [.granted, .expired])

        await client.finish(true)
        #expect(spy.finishCount == 1)
        #expect(spy.finishSuccesses == [true])
    }

    /// The mobilizing tap this case drives is a resume, reached through the pause toggle exactly
    /// as the app reaches it. One tap, one session — and the liveness probe agreeing means the
    /// coordinator will refuse a second registration, which is what keeps the process alive.
    @Test
    func testResumingWithSchedulableWorkStartsExactlyOneSession() async throws {
        let gid = "210001"
        let spy = BackgroundProcessingClientSpy()
        let context = try await makeInactiveCoordinator(gid: gid, spy: spy)
        defer { removeTemporaryItem(at: context.rootURL) }

        // Nothing schedulable yet, so nothing has been requested.
        #expect(spy.startCount == 0)

        try await context.manager.togglePause(gid: gid).get()

        #expect(spy.startCount == 1)
        #expect(await context.manager.testingHasContinuedSession())

        _ = await context.manager.pause(gid: gid)
    }

    /// A second tap while a session is live must fold into it. Both a real second entry point and
    /// the ensure path itself are driven here, because the guard has to hold for a caller that
    /// reaches it through the queue and for one that reaches it directly.
    @Test
    func testSecondMobilizingActionDuringLiveSessionStartsNoSecondSession() async throws {
        let gid = "210002"
        let spy = BackgroundProcessingClientSpy()
        let context = try await makeInactiveCoordinator(gid: gid, spy: spy)
        defer { removeTemporaryItem(at: context.rootURL) }

        try await context.manager.togglePause(gid: gid).get()
        #expect(spy.startCount == 1)

        try await context.manager.retryPages(gid: gid, pageIndices: [1]).get()
        await context.manager.ensureContinuedSession()

        #expect(spy.startCount == 1)
        #expect(spy.startTitles.count == 1)
        #expect(await context.manager.testingHasContinuedSession())

        _ = await context.manager.pause(gid: gid)
    }

    /// Requesting a session for an empty queue would put a progress card on screen with nothing
    /// behind it, and would burn an identifier the system then has to expire on its own.
    @Test
    func testNoSessionStartsWithoutSchedulableWork() async throws {
        let gid = "210003"
        let spy = BackgroundProcessingClientSpy()
        let context = try await makeInactiveCoordinator(gid: gid, spy: spy)
        defer { removeTemporaryItem(at: context.rootURL) }

        await context.manager.ensureContinuedSession()

        #expect(spy.startCount == 0)
        #expect(spy.startTitles.isEmpty)
        #expect(!(await context.manager.testingHasContinuedSession()))
    }

    /// The card renders in system UI, outside the app's privacy mask, so what it says is a
    /// disclosure question rather than a copy question. Asserting on the exact recorded strings —
    /// not merely on the absence of a substring — is what makes this case fail if a later change
    /// ever routes a gallery value into either string.
    @Test
    func testStartStringsCarryNoGalleryIdentity() async throws {
        let gid = "210004"
        let galleryTitle = "Unmistakable Fixture Gallery Name"
        let spy = BackgroundProcessingClientSpy()
        let context = try await makeInactiveCoordinator(
            gid: gid,
            spy: spy,
            galleryTitle: galleryTitle
        )
        defer { removeTemporaryItem(at: context.rootURL) }

        try await context.manager.togglePause(gid: gid).get()

        let recordedTitle = try #require(spy.startTitles.first)
        let recordedSubtitle = try #require(spy.startSubtitles.first)
        #expect(recordedTitle == "Downloading galleries")
        // Two pages, none downloaded, one gallery: the fixture manifest's whole content surface.
        #expect(recordedSubtitle == "0 / 2 pages · 1 gallery")
        for recorded in [recordedTitle, recordedSubtitle] {
            #expect(!recorded.contains(galleryTitle))
            #expect(!recorded.contains(gid))
        }

        _ = await context.manager.pause(gid: gid)
    }

    /// Ordering is a contract of the client seam: a progress push before the session exists has
    /// nothing to push to, and would be dropped rather than queued.
    @Test
    func testStartIsRecordedBeforeAnyProgressUpdate() async throws {
        let gid = "210005"
        let spy = BackgroundProcessingClientSpy()
        let context = try await makeInactiveCoordinator(gid: gid, spy: spy)
        defer { removeTemporaryItem(at: context.rootURL) }

        // Pushing before the tap records nothing at all: no session, no card, no update.
        await context.manager.pushContinuedSessionProgress()
        #expect(spy.progressUpdates.isEmpty)

        try await context.manager.togglePause(gid: gid).get()
        #expect(spy.startCount == 1)
        #expect(spy.progressUpdates.isEmpty)

        await context.manager.pushContinuedSessionProgress()
        #expect(spy.startCount == 1)
        #expect(spy.progressUpdates.count == 1)

        _ = await context.manager.pause(gid: gid)
    }
}

// MARK: - Helpers

private extension DownloadContinuedSessionTests {
    /// The blocking fixture with its queue cleared, so the single download starts out inactive and
    /// unschedulable. That is the state a resume has to move, which makes the tap under test the
    /// only thing that can produce schedulable work.
    func makeInactiveCoordinator(
        gid: String,
        spy: BackgroundProcessingClientSpy,
        galleryTitle: String = "Queued"
    ) async throws -> BlockingCoordinatorContext {
        let context = try await makeBlockingCoordinator(
            gid: gid,
            title: galleryTitle,
            backgroundProcessingClient: spy.client
        )
        await context.manager.testingSetQueuedGalleryIDs([])
        return context
    }
}
