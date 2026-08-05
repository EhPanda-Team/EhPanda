import BackgroundProcessingClient
import CustomDump
import DownloadClient
import Foundation
import Testing

@Suite
struct DownloadContinuedSessionTests: DownloadFeatureTestCase {
    /// Every endpoint on the client type's no-argument value must report an issue when called.
    /// A call the test did not arrange for therefore fails loudly instead of silently succeeding
    /// against a do-nothing stub.
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
        defer { context.cleanUp() }
        // The defer guarantees fixture teardown; the trailing pause below proves behavior.

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
        defer { context.cleanUp() }

        try await context.manager.togglePause(gid: gid).get()
        #expect(spy.startCount == 1)

        try await context.manager.retryPages(gid: gid, pageIndices: [1]).get()
        await context.manager.testingEnsureContinuedSession()

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
        defer { context.cleanUp() }

        await context.manager.testingEnsureContinuedSession()

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
        defer { context.cleanUp() }

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
        defer { context.cleanUp() }

        // Pushing before the tap records nothing at all: no session, no card, no update.
        await context.manager.testingPushContinuedSessionProgress(sessionID: UUID())
        #expect(spy.progressUpdates.isEmpty)

        try await context.manager.togglePause(gid: gid).get()
        let sessionID = try #require(await context.manager.testingContinuedSessionID())
        #expect(spy.startCount == 1)
        #expect(spy.progressUpdates.isEmpty)
        expectNoDifference(spy.startCompletedUnitCounts, [0])
        expectNoDifference(spy.startTotalUnitCounts, [2])

        await context.manager.testingPushContinuedSessionProgress(sessionID: sessionID)
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
        defer { context.cleanUp() }

        try await context.manager.togglePause(gid: gid).get()
        #expect(spy.startCount == 1)
        #expect(spy.finishCount == 0)

        _ = await context.manager.pause(gid: gid)

        #expect(spy.finishCount == 1)
        #expect(spy.finishSuccesses == [true])
        // The card's last word. Its denominator is `displayPageCount`'s one-page floor rather than
        // a page count: the gallery finished nothing before the pause, so it retired nothing.
        #expect(spy.progressUpdates.count == 1)
        #expect(spy.progressUpdates.last?.subtitle == "0 / 1 page · 0 galleries")
        #expect(spy.rejectedProgressUpdates.isEmpty)
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
        defer { context.cleanUp() }

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
        defer { context.cleanUp() }

        try await context.manager.togglePause(gid: gid).get()
        _ = await context.manager.pause(gid: gid)
        #expect(spy.finishCount == 1)
        let pushesAtDrain = spy.progressUpdates.count

        await context.manager.scheduleNextIfNeeded()
        await context.manager.scheduleNextIfNeeded()

        #expect(spy.finishCount == 1)
        #expect(spy.finishSuccesses == [true])
        // "At most once" covers the terminal push too: the later passes find no live session, so
        // the card keeps the one string the drain left it.
        #expect(spy.progressUpdates.count == pushesAtDrain)
        #expect(spy.progressUpdates.last?.subtitle == "0 / 1 page · 0 galleries")
        #expect(spy.rejectedProgressUpdates.isEmpty)
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

        await fixture.manager.testingEnsureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

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

        await fixture.manager.testingEnsureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        await fixture.manager.testingSetQueuedGalleryIDs(["210020", joiningGID])
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        #expect(spy.progressUpdates.map(\.totalUnitCount) == [4, 13])
        #expect(spy.progressUpdates.map(\.completedUnitCount) == [1, 3])
        #expect(spy.progressUpdates.map(\.subtitle) == [
            "1 / 4 pages · 1 gallery",
            "3 / 13 pages · 2 galleries"
        ])
    }

    /// The gap's own regression case. A gallery completing is the ordinary departure, and the
    /// pushed pair has to survive it: the pages it finished stay on both sides of the fraction, so
    /// the total does *not* shrink and the completed count rises across the gallery boundary.
    ///
    /// The completed count still never rewinds, but that is now a property of the accounting basis
    /// rather than of the `max()` floor. Which is why the discriminating assertion is the second
    /// push sitting strictly below its own total: under the old basis the finished gallery's pages
    /// left the numerator and the denominator at once, the floor held the numerator up, and the
    /// total clamp lifted the denominator to meet it — an exact 100% card with four pages still to
    /// fetch.
    @Test
    func testACompletedGalleryHoldsTheTotalAndAdvancesTheCount() async throws {
        let leavingGID = "210030"
        let leavingTitle = "Mostly Done"
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [
                .init(gid: leavingGID, title: leavingTitle, pageCount: 10, completedPageCount: 6),
                .init(gid: "210031", title: "Barely Started", pageCount: 4, completedPageCount: 0)
            ],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        // The departure this case exists for, staged the way the product reaches it: the manifest
        // completes, then the settle takes the gallery out of the queue store.
        await fixture.manager.updateDownloadIndex(
            folderURL: fixture.storage.folderURL(
                relativePath: "Folder/[\(leavingGID)_token] \(leavingTitle)"
            ),
            manifest: manifest(
                for: .init(
                    gid: leavingGID,
                    title: leavingTitle,
                    pageCount: 10,
                    completedPageCount: 10
                )
            )
        )
        await fixture.manager.settleCompletedDownload(gid: leavingGID)
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        let completedCounts = spy.progressUpdates.map(\.completedUnitCount)
        #expect(completedCounts == [6, 10])
        #expect(zip(completedCounts, completedCounts.dropFirst()).allSatisfy({ $0 <= $1 }))
        #expect(spy.progressUpdates.map(\.totalUnitCount) == [14, 14])
        let secondUpdate = try #require(spy.progressUpdates.last)
        #expect(secondUpdate.completedUnitCount < secondUpdate.totalUnitCount)
        #expect(spy.progressUpdates.map(\.subtitle) == [
            "6 / 14 pages · 2 galleries",
            "10 / 14 pages · 1 gallery"
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

        await fixture.manager.testingEnsureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        let update = try #require(spy.progressUpdates.first)
        #expect(update.totalUnitCount >= 1)
        #expect(update.completedUnitCount >= 0)
        #expect(update.completedUnitCount <= update.totalUnitCount)
        #expect(update.subtitle == "0 / 1 page · 1 gallery")
    }

    /// The reachable empty-live-sum input: a session outliving its work for the moment between the
    /// queue emptying and the scheduling tail completing it. A push taken in that window sums
    /// nothing live at all, and here the emptying is a real completion rather than a bare dequeue.
    ///
    /// What holds the pair up is the ledger, not the monotonic floor: the departing gallery retires
    /// all six of its pages to both sides, so completed equals total *because* nothing is
    /// outstanding — the one moment a 1.0 fraction is honest. Under the old basis this same staging
    /// pushed `2 / 2 pages`, a full card with two thirds of the work never done, so the case now
    /// fails on the pre-fix code instead of passing verbatim on it.
    ///
    /// A genuinely zero denominator — a session outliving work nobody finished at all — is reached
    /// under the ledger only when the departing gallery finished no pages, so that guard is not
    /// lost but moved: `DownloadContinuedSessionLedgerTests` supplies it.
    ///
    /// The terminal push is taken through `scheduleNextIfNeeded` rather than invoked directly. The
    /// pair it owes is unchanged; what changes is that the product now makes the call, and a value
    /// pinned on a call the product never makes is what hid G-15-2B.
    @Test
    func testEmptySchedulableSetStillPushesAPositiveTotal() async throws {
        let gid = "210045"
        let title = "Departing"
        let spy = BackgroundProcessingClientSpy()
        let fixture = try await makeQueuedCoordinator(
            galleries: [.init(gid: gid, title: title, pageCount: 6, completedPageCount: 2)],
            client: spy.client
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.testingEnsureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        await fixture.manager.updateDownloadIndex(
            folderURL: fixture.storage.folderURL(
                relativePath: "Folder/[\(gid)_token] \(title)"
            ),
            manifest: manifest(
                for: .init(gid: gid, title: title, pageCount: 6, completedPageCount: 6)
            )
        )
        await fixture.manager.settleCompletedDownload(gid: gid)
        await fixture.manager.scheduleNextIfNeeded()

        let update = try #require(spy.progressUpdates.last)
        #expect(update.totalUnitCount >= 1)
        #expect(spy.progressUpdates.map(\.completedUnitCount) == [2, 6])
        #expect(update.totalUnitCount == 6)
        #expect(spy.progressUpdates.map(\.subtitle) == [
            "2 / 6 pages · 1 gallery",
            "6 / 6 pages · 0 galleries"
        ])
        #expect(spy.finishSuccesses == [true])
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

        await fixture.manager.testingEnsureContinuedSession()
        let sessionID = try #require(await fixture.manager.testingContinuedSessionID())
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)
        await fixture.manager.testingSetQueuedGalleryIDs([firstGID])
        await fixture.manager.testingPushContinuedSessionProgress(sessionID: sessionID)

        // The second gallery's record was complete before the session began, so its three pages are
        // the redo's target rather than session work: it counts zero, and retires zero (D-G4-01).
        #expect(spy.progressUpdates.map(\.subtitle) == [
            "1 / 8 pages · 2 galleries",
            "1 / 5 pages · 1 gallery"
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

        await fixture.manager.testingEnsureContinuedSession()

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
}
