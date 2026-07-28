import AppModels
import BackgroundProcessingClient
import CustomDump
import DownloadClient
import Foundation
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
            _ = await client.start("Downloading galleries", "0 / 10 pages · 1 gallery", 0, 10)
        }
        await withKnownIssue("updateProgress is unimplemented") {
            await client.updateProgress(UUID(), 3, 10, "3 / 10 pages · 1 gallery")
        }
        await withKnownIssue("finish is unimplemented") {
            await client.finish(UUID(), true)
        }
    }

    /// The no-op value is inert in both directions: every start is visibly refused, so no
    /// consumer can mistake a dead stream for a session that exists.
    @Test
    func testNoopClientRefusesEveryStart() async {
        let client = BackgroundProcessingClient.noop

        let session = await client.start("Downloading galleries", "0 / 10 pages · 1 gallery", 0, 10)
        #expect(session == nil)

        await client.updateProgress(UUID(), 3, 10, "3 / 10 pages · 1 gallery")
        await client.finish(UUID(), true)
    }

    /// The spy has to hold up the same contract the live client does, because every later
    /// behavior assertion reads its recordings and drives its events. A foreign completion is
    /// recorded but cannot finish the held stream; the matching id can, and expiration still
    /// finishes a later stream without outside cancellation.
    @Test
    func testSpyRecordsPushedValuesAndFinishesItsStreamOnExpiration() async throws {
        let spy = BackgroundProcessingClientSpy()
        let client = spy.client

        let session = try #require(
            await client.start("Downloading galleries", "0 / 10 pages · 1 gallery", 0, 10)
        )
        #expect(spy.startCount == 1)
        #expect(spy.startTitles == ["Downloading galleries"])
        #expect(spy.startSubtitles == ["0 / 10 pages · 1 gallery"])
        #expect(spy.startSessionIDs == [session.id])

        let foreignSessionID = UUID()
        await client.finish(foreignSessionID, false)
        spy.emit(.granted)
        await client.updateProgress(session.id, 3, 10, "3 / 10 pages · 1 gallery")
        #expect(spy.progressUpdates == [
            .init(
                sessionID: session.id,
                completedUnitCount: 3,
                totalUnitCount: 10,
                subtitle: "3 / 10 pages · 1 gallery"
            )
        ])
        #expect(spy.finishRecords == [
            .init(sessionID: foreignSessionID, success: false)
        ])

        await client.finish(session.id, true)

        var events = [BackgroundProcessingEvent]()
        for await event in session.events {
            events.append(event)
        }
        #expect(events == [.granted])

        let expiringSession = try #require(
            await client.start("Downloading galleries", "3 / 10 pages · 1 gallery", 3, 10)
        )
        spy.expire()
        var expiringEvents = [BackgroundProcessingEvent]()
        for await event in expiringSession.events {
            expiringEvents.append(event)
        }
        #expect(expiringEvents == [.expired])
        #expect(spy.finishRecords == [
            .init(sessionID: foreignSessionID, success: false),
            .init(sessionID: session.id, success: true)
        ])
    }

    /// The mobilizing tap this case drives is a resume, reached through the pause toggle exactly
    /// as the app reaches it. One tap, one session — and the liveness probe agreeing means the
    /// coordinator will refuse a second registration, which is what keeps the process alive.
    @Test
    func testResumingWithSchedulableWorkStartsExactlyOneSession() async throws {
        let gid = "210001"
        let spy = BackgroundProcessingClientSpy()
        let context = try await makeInactiveCoordinator(gid: gid, client: spy.client)
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
        let context = try await makeInactiveCoordinator(gid: gid, client: spy.client)
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
        let context = try await makeInactiveCoordinator(gid: gid, client: spy.client)
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
            client: spy.client,
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

    /// Ordering is a contract of the client seam: the initial counts ride the start call, so no
    /// follow-up update is needed to make the new card internally consistent. A progress push
    /// before the session exists still has nothing to push to and is dropped rather than queued.
    @Test
    func testStartIsRecordedBeforeAnyProgressUpdate() async throws {
        let gid = "210005"
        let spy = BackgroundProcessingClientSpy()
        let context = try await makeInactiveCoordinator(gid: gid, client: spy.client)
        defer { removeTemporaryItem(at: context.rootURL) }

        // Pushing before the tap records nothing at all: no session, no card, no update.
        await context.manager.pushContinuedSessionProgress(sessionID: UUID())
        #expect(spy.progressUpdates.isEmpty)

        try await context.manager.togglePause(gid: gid).get()
        let sessionID = try #require(await context.manager.testingContinuedSessionID())
        #expect(spy.startCount == 1)
        #expect(spy.progressUpdates.isEmpty)
        expectNoDifference(spy.startCompletedUnitCounts, [0])
        expectNoDifference(spy.startTotalUnitCounts, [2])

        await context.manager.pushContinuedSessionProgress(sessionID: sessionID)
        #expect(spy.startCount == 1)
        #expect(spy.progressUpdates.count == 1)

        _ = await context.manager.pause(gid: gid)
    }

    /// The session must not outlive its work. Pausing the only download drains the queue and
    /// converges on the scheduling entry point, whose tail is the single place that notices — so
    /// this is also the case that fails if that tail call is ever dropped again.
    @Test
    func testDrainingTheQueueCompletesTheSessionWithSuccess() async throws {
        let gid = "210006"
        let spy = BackgroundProcessingClientSpy()
        let context = try await makeInactiveCoordinator(gid: gid, client: spy.client)
        defer { removeTemporaryItem(at: context.rootURL) }

        try await context.manager.togglePause(gid: gid).get()
        #expect(spy.startCount == 1)
        #expect(spy.finishCount == 0)

        _ = await context.manager.pause(gid: gid)

        #expect(spy.finishCount == 1)
        #expect(spy.finishSuccesses == [true])
        #expect(!(await context.manager.testingHasContinuedSession()))
    }

    /// A scheduling pass is not evidence the work is over — it runs on every queue mutation,
    /// most of which leave plenty to do. Completing on one of those would hand the background
    /// coverage back while the queue is still full, and only a fresh tap could get it again.
    @Test
    func testSchedulingPassWithWorkStillPendingCompletesNothing() async throws {
        let gid = "210007"
        let spy = BackgroundProcessingClientSpy()
        let context = try await makeInactiveCoordinator(gid: gid, client: spy.client)
        defer { removeTemporaryItem(at: context.rootURL) }

        try await context.manager.togglePause(gid: gid).get()
        #expect(spy.startCount == 1)

        await context.manager.scheduleNextIfNeeded()

        #expect(spy.finishCount == 0)
        #expect(spy.finishSuccesses.isEmpty)
        #expect(await context.manager.testingHasContinuedSession())

        _ = await context.manager.pause(gid: gid)
    }

    /// Completion is terminal, and the tail it hangs off runs again on every later mutation, so
    /// "at most once" is a property of the liveness flag rather than of the caller's discipline.
    @Test
    func testSchedulingPassesAfterTheDrainAddNoSecondCompletion() async throws {
        let gid = "210008"
        let spy = BackgroundProcessingClientSpy()
        let context = try await makeInactiveCoordinator(gid: gid, client: spy.client)
        defer { removeTemporaryItem(at: context.rootURL) }

        try await context.manager.togglePause(gid: gid).get()
        _ = await context.manager.pause(gid: gid)
        #expect(spy.finishCount == 1)

        await context.manager.scheduleNextIfNeeded()
        await context.manager.scheduleNextIfNeeded()

        #expect(spy.finishCount == 1)
        #expect(spy.finishSuccesses == [true])
        #expect(!(await context.manager.testingHasContinuedSession()))
    }

    /// D-10's arithmetic, asserted end to end: the card's numbers are pages across the whole
    /// schedulable set, not one gallery's. The subtitle is checked against the same pair of
    /// numbers the counts carry, which is what proves both were read from one snapshot — two
    /// snapshots would let the bar and the text disagree by whatever landed between them.
    @Test
    func testPushedCountsSumEverySchedulableGallery() async throws {
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [
                .init(gid: "210010", title: "First", pageCount: 10, completedPageCount: 3),
                .init(gid: "210011", title: "Second", pageCount: 6, completedPageCount: 2)
            ],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.ensureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        let update = try #require(spy.progressUpdates.first)
        #expect(spy.progressUpdates.count == 1)
        #expect(update.completedUnitCount == 5)
        #expect(update.totalUnitCount == 16)
        #expect(update.subtitle == "5 / 16 pages · 2 galleries")
    }

    /// D-06 folds a new gallery into the live session rather than starting a second one, so the
    /// only place that growth can show up is the next push's total.
    @Test
    func testTotalGrowsWhenAGalleryJoinsTheQueueMidSession() async throws {
        let joiningGID = "210021"
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [
                .init(gid: "210020", title: "Started", pageCount: 4, completedPageCount: 1),
                .init(gid: joiningGID, title: "Joined", pageCount: 9, completedPageCount: 2)
            ],
            queuedGIDs: ["210020"],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.ensureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        await fixture.manager.testingSetQueuedGalleryIDs(["210020", joiningGID])
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        #expect(spy.progressUpdates.map(\.totalUnitCount) == [4, 13])
        #expect(spy.progressUpdates.map(\.completedUnitCount) == [1, 3])
        #expect(spy.progressUpdates.map(\.subtitle) == [
            "1 / 4 pages · 1 gallery",
            "3 / 13 pages · 2 galleries"
        ])
    }

    /// A total may shrink — a gallery leaving the queue is ordinary — but the completed count is
    /// the stall signal the scheduler reads, and a rewind there reads as a task losing ground.
    /// The pushed total is held up with it so the pair can never describe a fraction above one.
    @Test
    func testPushedCompletedCountNeverDecreasesWithinASession() async throws {
        let leavingGID = "210030"
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [
                .init(gid: leavingGID, title: "Mostly Done", pageCount: 10, completedPageCount: 6),
                .init(gid: "210031", title: "Barely Started", pageCount: 4, completedPageCount: 0)
            ],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.ensureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        // The shrink that makes this case worth having: the gallery holding all the completed
        // pages leaves, so the raw snapshot would report 0 completed out of 4.
        await fixture.manager.testingSetQueuedGalleryIDs(["210031"])
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        let completedCounts = spy.progressUpdates.map(\.completedUnitCount)
        #expect(completedCounts == [6, 6])
        #expect(zip(completedCounts, completedCounts.dropFirst()).allSatisfy({ $0 <= $1 }))
        #expect(spy.progressUpdates.map(\.totalUnitCount) == [14, 6])
        #expect(spy.progressUpdates.map(\.subtitle) == [
            "6 / 14 pages · 2 galleries",
            "6 / 6 pages · 1 gallery"
        ])
    }

    /// A page-less gallery is the one input that can hand `Progress` a zero denominator, and the
    /// clamp turns it into a well-formed fraction instead of a division by zero.
    ///
    /// It has to be patched straight into the index because the store refuses to read a page-less
    /// manifest back, so no scan can produce one — and that same patch call is how a flush
    /// refreshes a record without rescanning, which makes this the only route by which the
    /// arithmetic could ever meet one.
    @Test
    func testZeroPageGalleryStillPushesAPositiveTotal() async throws {
        let gid = "210040"
        let title = "Empty"
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [.init(gid: gid, title: title, pageCount: 0)],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        await fixture.manager.updateDownloadIndex(
            folderURL: fixture.storage.folderURL(
                relativePath: "Folder/[\(gid)_token] \(title)"
            ),
            manifest: manifest(for: .init(gid: gid, title: title, pageCount: 0))
        )

        await fixture.manager.ensureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        let update = try #require(spy.progressUpdates.first)
        #expect(update.totalUnitCount >= 1)
        #expect(update.completedUnitCount >= 0)
        #expect(update.completedUnitCount <= update.totalUnitCount)
        #expect(update.subtitle == "0 / 1 page · 1 gallery")
    }

    /// The other zero-denominator input, and the reachable one: a session outliving its work for
    /// the moment between the queue emptying and the scheduling tail completing it. A push taken
    /// in that window sums nothing at all.
    @Test
    func testEmptySchedulableSetStillPushesAPositiveTotal() async throws {
        let gid = "210045"
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [.init(gid: gid, title: "Departing", pageCount: 6, completedPageCount: 2)],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.ensureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)
        await fixture.manager.testingSetQueuedGalleryIDs([])
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        let update = try #require(spy.progressUpdates.last)
        #expect(update.totalUnitCount >= 1)
        // The monotonic floor is what the total is held up to here: two pages were already
        // pushed, so an empty sum cannot rewind the card below them.
        #expect(spy.progressUpdates.map(\.completedUnitCount) == [2, 2])
        #expect(update.totalUnitCount == 2)
        #expect(update.subtitle == "2 / 2 pages · 0 galleries")
    }

    /// The start string is already covered; this covers every *later* string, because the card is
    /// re-titled on each push and a content leak introduced there would never touch the start
    /// path. Exact equality rather than a substring probe: that is what fails if a gallery value
    /// is ever routed into the subtitle builder.
    @Test
    func testEveryPushedSubtitleCarriesNoGalleryIdentity() async throws {
        let firstGID = "210050"
        let secondGID = "210051"
        let firstTitle = "Unmistakable Fixture Gallery Name"
        let secondTitle = "Second Unmistakable Fixture Gallery Name"
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [
                .init(gid: firstGID, title: firstTitle, pageCount: 5, completedPageCount: 1),
                .init(gid: secondGID, title: secondTitle, pageCount: 3, completedPageCount: 3)
            ],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.ensureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)
        await fixture.manager.testingSetQueuedGalleryIDs([firstGID])
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        #expect(spy.progressUpdates.map(\.subtitle) == [
            "4 / 8 pages · 2 galleries",
            "4 / 5 pages · 1 gallery"
        ])
        for recorded in spy.startSubtitles + spy.progressUpdates.map(\.subtitle) {
            #expect(!recorded.contains(firstTitle))
            #expect(!recorded.contains(secondTitle))
            #expect(!recorded.contains(firstGID))
            #expect(!recorded.contains(secondGID))
        }
    }

    /// The cadence assertion, and the reason the push sits in the flush routine: the card's
    /// numbers advance on exactly the beats the manifest does, one throttle governing both.
    ///
    /// The clock is frozen and the flush date seeded to it, so the throttle's elapsed-time branch
    /// is provably dead and the page-count branch is the only thing that can fire. That is what
    /// makes the expected update list a fact about the code rather than about machine load.
    @Test
    func testProgressIsPushedOnTheThrottledPageFlushCadence() async throws {
        let gid = "210060"
        let pageCount = 20
        let frozenNow = Date()
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [.init(gid: gid, title: "Flushing", pageCount: pageCount)],
            client: spy.client,
            now: { frozenNow }
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(gid)_token] Flushing"
        )

        await fixture.manager.ensureContinuedSession()

        var pendingResolvedPages = [DownloadCoordinator.PageResult]()
        var lastFlushDate = frozenNow
        for index in 1...pageCount {
            let relativePath = fixture.storage.makePageRelativePath(
                gid: gid,
                token: "token",
                index: index,
                fileExtension: "jpg"
            )
            try Data([UInt8(index)]).write(
                to: folderURL.appendingPathComponent(relativePath),
                options: .atomic
            )
            pendingResolvedPages.append(
                .init(index: index, relativePath: relativePath, imageURL: nil)
            )
            try await fixture.manager.flushDownloadProgress(
                context: .init(gid: gid, folderURL: folderURL),
                pendingResolvedPages: &pendingResolvedPages,
                lastFlushDate: &lastFlushDate,
                force: false
            )
        }
        try await fixture.manager.flushDownloadProgress(
            context: .init(gid: gid, folderURL: folderURL),
            pendingResolvedPages: &pendingResolvedPages,
            lastFlushDate: &lastFlushDate,
            force: true
        )

        // Two cadence flushes at the eight-page interval, then the forced one carrying the
        // remainder — fewer updates than pages, which is the coalescing the throttle exists for.
        #expect(spy.progressUpdates.map(\.completedUnitCount) == [8, 16, 20])
        #expect(spy.progressUpdates.map(\.totalUnitCount) == [20, 20, 20])
        #expect(spy.progressUpdates.count < pageCount)
    }

    /// SC2's "consistent with an in-app cancel", checked literally rather than paraphrased: the
    /// expected state is computed by running the identical fixture and pausing each gallery
    /// through the coordinator's own pause entry point. A hard-coded status would still pass if
    /// pause itself changed, which is the divergence this case exists to catch.
    @Test
    func testExpirationLeavesTheQueueInThePerGalleryPauseBaselineState() async throws {
        let gids = ["210070", "210071", "210072"]
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: expirationGalleries(gids: gids),
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let baseline = try await makeQueuedCoordinator(
            galleries: expirationGalleries(gids: gids),
            client: .noop
        )
        defer { removeTemporaryItem(at: baseline.rootURL) }

        for gid in gids {
            _ = await baseline.manager.pause(gid: gid)
        }
        try await expireSession(of: fixture, spy: spy)

        let expired = await queueSnapshot(fixture.manager)
        let paused = await queueSnapshot(baseline.manager)
        #expect(expired == paused)
        #expect(expired.count == gids.count)
    }

    /// The scheduling-blocked set is the half of pause semantics no display status reveals, and it
    /// is per-gallery bookkeeping with a `defer` on the way out — so a bulk pause path that forgot
    /// to unwind it would leave the queue permanently unschedulable and look fine on screen.
    @Test
    func testExpirationLeavesTheSchedulingBlockedSetAsAPauseDoes() async throws {
        let gids = ["210080", "210081"]
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: expirationGalleries(gids: gids),
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let baseline = try await makeQueuedCoordinator(
            galleries: expirationGalleries(gids: gids),
            client: .noop
        )
        defer { removeTemporaryItem(at: baseline.rootURL) }

        for gid in gids {
            _ = await baseline.manager.pause(gid: gid)
        }
        try await expireSession(of: fixture, spy: spy)

        let expiredBlocked = await fixture.manager.schedulingBlockedGalleryIDs
        let pausedBlocked = await baseline.manager.schedulingBlockedGalleryIDs
        #expect(expiredBlocked == pausedBlocked)
        #expect(!(await fixture.manager.testingHasContinuedSession()))
    }

    /// Pause-all walks a snapshot of the schedulable set, so the order it walks in is an
    /// implementation detail the result must not depend on. It would, if any pause mutated state
    /// a later pause reads.
    @Test
    func testExpirationResultIsIndependentOfEnqueueOrder() async throws {
        let gids = ["210090", "210091", "210092"]
        let forwardSpy = BackgroundProcessingClientSpy()
        let forward = try await makeQueuedCoordinator(
            galleries: expirationGalleries(gids: gids),
            queuedGIDs: gids,
            client: forwardSpy.client
        )
        defer { removeTemporaryItem(at: forward.rootURL) }
        let reversedSpy = BackgroundProcessingClientSpy()
        let reversed = try await makeQueuedCoordinator(
            galleries: expirationGalleries(gids: gids),
            queuedGIDs: gids.reversed(),
            client: reversedSpy.client
        )
        defer { removeTemporaryItem(at: reversed.rootURL) }

        try await expireSession(of: forward, spy: forwardSpy)
        try await expireSession(of: reversed, spy: reversedSpy)

        let forwardSnapshot = await queueSnapshot(forward.manager)
        let reversedSnapshot = await queueSnapshot(reversed.manager)
        #expect(forwardSnapshot == reversedSnapshot)
        #expect(
            await forward.manager.schedulingBlockedGalleryIDs
                == (await reversed.manager.schedulingBlockedGalleryIDs)
        )
    }

    /// An expiration clears liveness before it pauses anything, and each of those pauses
    /// reschedules — so the scheduling tail runs several times against an ended session. Nothing
    /// it does may reach the client: the identifier is already gone, and a completion for a
    /// session the system ended is a call the seam should never make.
    @Test
    func testEndedSessionReceivesNoFurtherUpdateOrCompletion() async throws {
        let gids = ["210100", "210101"]
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: expirationGalleries(gids: gids),
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.ensureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)
        let updatesBeforeExpiration = spy.progressUpdates.count
        #expect(updatesBeforeExpiration == 1)

        try await expireSession(of: fixture, spy: spy, ensuresSession: false)
        await fixture.manager.scheduleNextIfNeeded()
        await fixture.manager.pushContinuedSessionProgress(sessionID: sessionID)

        #expect(spy.progressUpdates.count == updatesBeforeExpiration)
        #expect(spy.finishCount == 0)
    }

    /// The consuming task is never cancelled from outside — the stream finishing behind the
    /// expiration is what ends it. Awaiting that task to completion is the proof, and it is also
    /// why no case here has to poll for the pause-all to settle.
    @Test
    func testConsumingTaskEndsOnItsOwnAfterExpiration() async throws {
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: expirationGalleries(gids: ["210110"]),
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.ensureContinuedSession()
        let sessionTask = try #require(await fixture.manager.continuedSessionTask)
        spy.expire()
        try await waitForTaskValue(
            sessionTask,
            timeout: .seconds(10),
            description: "the session's consuming task to finish"
        )

        #expect(!sessionTask.isCancelled)
        #expect(!(await fixture.manager.testingHasContinuedSession()))
        #expect(await fixture.manager.continuedSessionTask == nil)
    }

    /// SC3 as amended: with no fallback tier left, an unavailable session is not a degraded mode
    /// but the ordinary foreground one. Proved by running the same page work twice and comparing
    /// the results gallery for gallery — same statuses, same errors, same manifest page counts —
    /// so a page can be neither lost nor written twice on the path that has no session.
    @Test
    func testUnavailableSessionLeavesQueueStateEqualToTheInertClient() async throws {
        let gid = "210120"

        let unavailable = try await runPageFlushScenario(client: .unavailable, gid: gid)
        let inert = try await runPageFlushScenario(client: .noop, gid: gid)

        #expect(unavailable == inert)
        #expect(unavailable.count == 1)
        #expect(unavailable.allSatisfy({ $0.lastError == nil }))
        #expect(unavailable.allSatisfy({ $0.completedPageCount == $0.pageCount }))
    }

    /// The silence is the contract: nothing thrown out of the tap that asked for the session,
    /// nothing recorded as a download failure, and no session left believing it is live.
    @Test
    func testUnavailableSessionSurfacesNothingAndLeavesNoLiveSession() async throws {
        let gid = "210130"
        let context = try await makeInactiveCoordinator(gid: gid, client: .unavailable)
        defer { removeTemporaryItem(at: context.rootURL) }

        // `.get()` is the assertion: the mobilizing tap must still report success even though the
        // session it asked for was refused outright.
        try await context.manager.togglePause(gid: gid).get()
        try await waitUntil {
            await !context.manager.testingHasContinuedSession()
        }

        let download = try #require(await context.manager.fetchDownload(gid: gid))
        #expect(download.lastError == nil)
        #expect(!(await context.manager.testingHasContinuedSession()))

        _ = await context.manager.pause(gid: gid)
    }

    /// CR-02: a superseded session's trailing teardown used to clear whatever session was live
    /// when it finally re-entered the actor. The interleave that produces it — a drain completing
    /// S1 while its consuming task is still suspended, then a tap starting S2 before that task
    /// resumes — has no deterministic staging, but its effect does: a teardown carrying a foreign
    /// id, driven directly here. Before the fix it detached the live session, after which nothing
    /// pushed progress and nothing completed it.
    @Test
    func testStaleTeardownDoesNotClearANewerSession() async throws {
        let gid = "210140"
        let spy = BackgroundProcessingClientSpy()
        let context = try await makeInactiveCoordinator(gid: gid, client: spy.client)
        defer { removeTemporaryItem(at: context.rootURL) }

        try await context.manager.togglePause(gid: gid).get()
        let sessionID = try #require(await context.manager.testingContinuedSessionID())
        #expect(spy.startCount == 1)
        #expect(await context.manager.testingHasContinuedSession())

        await context.manager.markContinuedSessionEnded(sessionID: UUID())

        // Still live, and still pushing: the foreign teardown touched nothing.
        #expect(await context.manager.testingHasContinuedSession())
        await context.manager.pushContinuedSessionProgress(sessionID: sessionID)
        #expect(spy.progressUpdates.count == 1)

        // The correct-id path still tears the session down end to end.
        _ = await context.manager.pause(gid: gid)
        #expect(spy.finishCount == 1)
        #expect(spy.finishSuccesses == [true])
        #expect(!(await context.manager.testingHasContinuedSession()))
    }

    /// WR-04: the update, redownload and repair cancel mutated the queue without reaching the
    /// convergence point every other mutation exits through, so a cancel that emptied the
    /// schedulable set left the session live with nothing able to complete it — after which the
    /// system force-expired the card as stalled and the D-11 policy paused downloads the user
    /// never touched. Ordinary tap reachability: `toggleDownloadPause` routes a queued update here.
    @Test
    func testCancellingTheLastQueuedWorkItemCompletesTheSession() async throws {
        let gid = "210150"
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [.init(gid: gid, title: "Updating", pageCount: 5, completedPageCount: 1)],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.ensureContinuedSession()
        #expect(spy.startCount == 1)
        #expect(await fixture.manager.testingHasContinuedSession())

        let download = try #require(await fixture.manager.indexedDownloads(gids: [gid]).first)
        try await fixture.manager.cancelQueuedWorkItem(download, mode: .update).get()

        #expect(spy.finishCount == 1)
        #expect(spy.finishSuccesses == [true])
        #expect(!(await fixture.manager.testingHasContinuedSession()))

        // D-07: the next queue-mobilizing moment starts a fresh session rather than folding into
        // the dead one — and that one still drains, so the case leaves nothing live behind it.
        await fixture.manager.testingSetQueuedGalleryIDs([gid])
        await fixture.manager.ensureContinuedSession()
        #expect(spy.startCount == 2)

        _ = await fixture.manager.pause(gid: gid)
        #expect(spy.finishCount == 2)
        #expect(spy.finishSuccesses == [true, true])
        #expect(!(await fixture.manager.testingHasContinuedSession()))
    }
}

// MARK: - Helpers

private extension DownloadContinuedSessionTests {
    /// Everything about one gallery that a pause is allowed to change, plus the two facts a lost
    /// or duplicated page would move. Compared as a whole so a divergence anywhere fails, rather
    /// than only where an assertion happened to look.
    struct GalleryStateSnapshot: Equatable {
        let gid: String
        let displayStatus: DownloadDisplayStatus
        let completedPageCount: Int
        let pageCount: Int
        let lastError: DownloadFailure?
    }

    func queueSnapshot(_ manager: DownloadCoordinator) async -> [GalleryStateSnapshot] {
        let downloads = await manager.indexedDownloads()
        return downloads
            .map({
                GalleryStateSnapshot(
                    gid: $0.gid,
                    displayStatus: $0.displayStatus,
                    completedPageCount: $0.completedPageCount,
                    pageCount: $0.pageCount,
                    lastError: $0.lastError
                )
            })
            .sorted(by: { $0.gid < $1.gid })
    }

    /// Galleries with differing page counts and differing amounts already done, so a comparison
    /// against the pause baseline cannot pass by accident on identical rows.
    func expirationGalleries(gids: [String]) -> [SessionGallery] {
        gids.enumerated().map { offset, gid in
            SessionGallery(
                gid: gid,
                title: "Expiring \(offset)",
                pageCount: 4 + offset * 3,
                completedPageCount: offset
            )
        }
    }

    /// Fires the expiration and returns once the coordinator has finished acting on it.
    ///
    /// The settle point is the consuming task itself rather than a polled predicate: the handler's
    /// pause-all runs inside that task, so awaiting it is exact. Capturing the task before firing
    /// is what makes that possible — the handler nils it on the way through.
    func expireSession(
        of fixture: SessionFixture,
        spy: BackgroundProcessingClientSpy,
        ensuresSession: Bool = true
    ) async throws {
        if ensuresSession {
            await fixture.manager.ensureContinuedSession()
        }
        let sessionTask = try #require(await fixture.manager.continuedSessionTask)
        spy.expire()
        try await waitForTaskValue(
            sessionTask,
            timeout: .seconds(10),
            description: "the session's consuming task to finish after expiration"
        )
    }

    /// Runs one gallery's worth of page flushes against `client` and reports the resulting queue
    /// state. Same gid in every run, so two runs' snapshots compare directly.
    func runPageFlushScenario(
        client: BackgroundProcessingClient,
        gid: String
    ) async throws -> [GalleryStateSnapshot] {
        let title = "Unavailable Path"
        let pageCount = 12
        let fixture = try await makeQueuedCoordinator(
            galleries: [.init(gid: gid, title: title, pageCount: pageCount)],
            client: client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let folderURL = fixture.storage.folderURL(
            relativePath: "Folder/[\(gid)_token] \(title)"
        )

        await fixture.manager.ensureContinuedSession()

        var pendingResolvedPages = [DownloadCoordinator.PageResult]()
        var lastFlushDate = Date.distantPast
        for index in 1...pageCount {
            let relativePath = fixture.storage.makePageRelativePath(
                gid: gid,
                token: "token",
                index: index,
                fileExtension: "jpg"
            )
            try Data([UInt8(index)]).write(
                to: folderURL.appendingPathComponent(relativePath),
                options: .atomic
            )
            pendingResolvedPages.append(
                .init(index: index, relativePath: relativePath, imageURL: nil)
            )
            try await fixture.manager.flushDownloadProgress(
                context: .init(gid: gid, folderURL: folderURL),
                pendingResolvedPages: &pendingResolvedPages,
                lastFlushDate: &lastFlushDate,
                force: false
            )
        }
        try await fixture.manager.flushDownloadProgress(
            context: .init(gid: gid, folderURL: folderURL),
            pendingResolvedPages: &pendingResolvedPages,
            lastFlushDate: &lastFlushDate,
            force: true
        )
        return await queueSnapshot(fixture.manager)
    }
}

private extension BackgroundProcessingClient {
    /// Answers every start with an identified session that immediately reports unavailable —
    /// what the Simulator reports, and what the system reports when it will not grant a task.
    static let unavailable = Self(
        start: { _, _, _, _ in
            let events = AsyncStream<BackgroundProcessingEvent> { continuation in
                continuation.yield(.unavailable)
                continuation.finish()
            }
            return BackgroundProcessingSession(id: UUID(), events: events)
        },
        updateProgress: { _, _, _, _ in },
        finish: { _, _ in }
    )
}
