import AppModels
import BackgroundProcessingClient
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

    /// The session must not outlive its work. Pausing the only download drains the queue and
    /// converges on the scheduling entry point, whose tail is the single place that notices — so
    /// this is also the case that fails if that tail call is ever dropped again.
    @Test
    func testDrainingTheQueueCompletesTheSessionWithSuccess() async throws {
        let gid = "210006"
        let spy = BackgroundProcessingClientSpy()
        let context = try await makeInactiveCoordinator(gid: gid, spy: spy)
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
        let context = try await makeInactiveCoordinator(gid: gid, spy: spy)
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
        let context = try await makeInactiveCoordinator(gid: gid, spy: spy)
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
            spy: spy
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.ensureContinuedSession()
        await fixture.manager.pushContinuedSessionProgress()

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
            spy: spy
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.ensureContinuedSession()
        await fixture.manager.pushContinuedSessionProgress()

        await fixture.manager.testingSetQueuedGalleryIDs(["210020", joiningGID])
        await fixture.manager.pushContinuedSessionProgress()

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
            spy: spy
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.ensureContinuedSession()
        await fixture.manager.pushContinuedSessionProgress()

        // The shrink that makes this case worth having: the gallery holding all the completed
        // pages leaves, so the raw snapshot would report 0 completed out of 4.
        await fixture.manager.testingSetQueuedGalleryIDs(["210031"])
        await fixture.manager.pushContinuedSessionProgress()

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
            spy: spy
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        await fixture.manager.updateDownloadIndex(
            folderURL: fixture.storage.folderURL(
                relativePath: "Folder/[\(gid)_token] \(title)"
            ),
            manifest: manifest(for: .init(gid: gid, title: title, pageCount: 0))
        )

        await fixture.manager.ensureContinuedSession()
        await fixture.manager.pushContinuedSessionProgress()

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
            spy: spy
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.ensureContinuedSession()
        await fixture.manager.pushContinuedSessionProgress()
        await fixture.manager.testingSetQueuedGalleryIDs([])
        await fixture.manager.pushContinuedSessionProgress()

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
            spy: spy
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }

        await fixture.manager.ensureContinuedSession()
        await fixture.manager.pushContinuedSessionProgress()
        await fixture.manager.testingSetQueuedGalleryIDs([firstGID])
        await fixture.manager.pushContinuedSessionProgress()

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
            spy: spy,
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

    /// One gallery to seed on disk. A named value rather than a tuple, so a case that cares only
    /// about page counts still reads as page counts at the call site.
    struct SessionGallery {
        let gid: String
        let title: String
        let pageCount: Int
        var completedPageCount = 0
    }

    struct SessionFixture {
        let manager: DownloadCoordinator
        let storage: DownloadStore
        let rootURL: URL
    }

    /// A coordinator holding `galleries` on disk with `queuedGIDs` enqueued, and nothing running.
    ///
    /// Deliberately not the blocking fixture: a queued gallery is schedulable on its own, so this
    /// makes the queue's *shape* the only variable an arithmetic case has to reason about. No task
    /// runner is installed either, so no download can start and mutate the counts underneath an
    /// assertion.
    func makeQueuedCoordinator(
        galleries: [SessionGallery],
        queuedGIDs: [String]? = nil,
        spy: BackgroundProcessingClientSpy,
        now: @escaping @Sendable () -> Date = { Date() }
    ) async throws -> SessionFixture {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared,
            backgroundProcessingClient: spy.client,
            now: now
        )

        try storage.ensureRootDirectory()
        for gallery in galleries {
            try writeGalleryFolder(storage: storage, gallery: gallery)
        }
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs(queuedGIDs ?? galleries.map(\.gid))
        return SessionFixture(manager: manager, storage: storage, rootURL: rootURL)
    }

    /// Writes one gallery folder whose manifest reports `completedPageCount` finished pages: a
    /// page counts as done when its hash entry is non-empty, which is the same rule the index
    /// derives progress from.
    func writeGalleryFolder(
        storage: DownloadStore,
        gallery: SessionGallery
    ) throws {
        let folderURL = storage.folderURL(
            relativePath: "Folder/[\(gallery.gid)_token] \(gallery.title)"
        )
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(manifest(for: gallery), folderURL: folderURL)
    }

    func manifest(for gallery: SessionGallery) -> DownloadManifest {
        DownloadManifest(
            gid: gallery.gid,
            host: .ehentai,
            token: "token",
            title: gallery.title,
            jpnTitle: nil,
            category: .doujinshi,
            language: .japanese,
            remoteCoverURL: URL(string: "https://example.com/cover.jpg"),
            uploader: "Uploader",
            tags: [],
            postedDate: .now,
            rating: 4,
            pages: Dictionary(
                uniqueKeysWithValues: (0..<gallery.pageCount).map { offset in
                    (offset + 1, offset < gallery.completedPageCount ? "sha256:done" : "")
                }
            )
        )
    }
}
