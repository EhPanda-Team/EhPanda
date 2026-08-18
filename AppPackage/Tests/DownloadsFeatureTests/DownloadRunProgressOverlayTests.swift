import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing

/// D-SSOT-10: what the in-app download surfaces read while a run's own measurement stands.
///
/// The record is the single source of truth about a gallery's COMPLETENESS, and it stays so — every
/// quantity and gate derived from it is asserted unmoved here. What it cannot describe is the work a
/// RUN is doing, and the wholesale-refusal family is where that bites: a record claiming every page
/// whose files are gone reads N-of-N for the entire re-download, because the irreversibility guard
/// refuses to blank a whole manifest on one scan. So a user who opened the Download Status sheet
/// during a 27-page repair read "Downloading 27/27 · Downloaded (27) · Pending (0)" while the
/// continued-processing card, fed by the run's measurement, counted up from zero (G-15-2F).
///
/// These cases pin the overlay from four sides: the refusal family reads the run at the announce, at
/// every flush and back to the record at the exit; the honest family reads identically under both
/// bases, so nothing visibly moved for the ordinary case; a page the run owes that failed still
/// reads `.failed`, and credit beats a stale failure entry; and a run whose slot was taken from it
/// mid-flight still publishes the record's reading on the way out.
///
/// The out-of-run regime — every display and predicate as a pure function of the persisted record —
/// is `DownloadManifestSSOTInvariantTests`' subject and is not restated here.
///
/// **Choreography discipline.** Record state comes only from fixture manifests, `writePageFiles` and
/// production routes; the run's measurement is announced only by
/// `prepareWorkingSeedAnnouncingProgress`; every run exit is a real `processDownload` against a stub
/// that refuses the detail fetch; and every observed row is production-published.
@Suite
struct DownloadRunProgressOverlayTests: DownloadFeatureTestCase {
    /// The reported defect, end to end: a repair of a complete-claiming record whose files are all
    /// gone reads the RUN from the announce, climbs with each flush, and returns to the record's own
    /// reading the moment the run ends.
    @Test
    func testAWholesaleRefusalRepairReadsTheRunNotTheRecord() async throws {
        let vanished = SessionGallery(
            gid: "260818-2F-a",
            title: "Vanished",
            pageCount: 6,
            completedPageCount: 6
        )
        let stubSessionID = UUID().uuidString
        SharedSessionStubURLProtocol.setHandler(for: stubSessionID) { _ in
            throw URLError(.notConnectedToInternet)
        }
        defer { SharedSessionStubURLProtocol.removeHandler(for: stubSessionID) }
        let fixture = try await makeRefusalFixture(
            gallery: vanished,
            stubSessionID: stubSessionID
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        await manager.reloadDownloadIndex()

        let staged = try #require(await manager.fetchDownload(gid: vanished.gid))
        #expect(await manager.resumeMode(for: staged) == .repair)

        // Subscribed BEFORE the announcement, so the announce publication is observable rather than
        // inferred from a later read.
        let readings = collectRunProgressReadings(
            from: await manager.observeDownloads(),
            gid: vanished.gid
        )

        try await manager.retryPages(gid: vanished.gid, pageIndices: [1, 2, 3, 4, 5, 6]).get()
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }
        let payload = try await makeRetriedPagesPayload(
            for: vanished,
            mode: .repair,
            retriedPageIndices: [1, 2, 3, 4, 5, 6],
            coordinator: manager
        )
        let folderURL = galleryFolderURL(for: vanished, in: fixture)
        _ = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: payload,
            existingDownload: staged,
            folderURL: folderURL
        )

        // At the announce: the record is untouched and still claims six, and every display reads the
        // run's own zero instead.
        let announced = try #require(await manager.fetchDownload(gid: vanished.gid))
        #expect(announced.completedPageCount == 6)
        #expect(announced.runProgress?.creditedPageIndices == [])
        #expect(announced.badge.progress.completedPageCount == 0)
        #expect(announced.badge.progress.pageCount == 6)
        let openedSheet = try await manager.loadInspection(gid: vanished.gid).get()
        #expect(
            openedSheet.pages.map(\.status)
                == Array(repeating: DownloadPageStatus.pending, count: 6)
        )
        // Header and page groups from ONE value: the badge numerator is the size of the very set the
        // page states read membership from.
        #expect(openedSheet.download.badge.progress.completedPageCount == 0)

        try await flushPages([1, 2, 3], of: vanished, in: fixture)

        let midRun = try #require(await manager.fetchDownload(gid: vanished.gid))
        #expect(midRun.runProgress?.creditedPageIndices == [1, 2, 3])
        #expect(midRun.badge.progress.completedPageCount == 3)
        // The record never moved: it claimed six throughout, which is exactly why it could not
        // describe this run.
        #expect(midRun.completedPageCount == 6)
        let midRunSheet = try await manager.loadInspection(gid: vanished.gid).get()
        #expect(
            midRunSheet.pages.map(\.status) == [
                .downloaded, .downloaded, .downloaded, .pending, .pending, .pending
            ]
        )

        // A real run exit, through the public entry point against an offline stub.
        await manager.processDownload(gid: vanished.gid)
        try await waitUntil {
            await manager.testingHasActiveTask() == false
        }

        let settled = try #require(await manager.fetchDownload(gid: vanished.gid))
        #expect(settled.runProgress == nil)
        #expect(settled.badge.progress.completedPageCount == settled.completedPageCount)

        let published = try await waitForTaskValue(
            readings,
            timeout: .seconds(30),
            description: "published run-progress readings"
        )
        #expect(published.contains(where: { $0?.creditedPageIndices == [] }))
        #expect(published.contains(where: { $0?.creditedPageIndices == [1, 2, 3] }))
        #expect(published.last == .some(nil))
    }

    /// The other side of the same rule: for an HONEST record the overlay equals the record at every
    /// point, so adopting it changed nothing a user of the ordinary family can see.
    @Test
    func testAnHonestRecordReadsTheSameUnderTheOverlayAndTheRecord() async throws {
        let honest = SessionGallery(
            gid: "260818-2F-b",
            title: "Honest",
            pageCount: 6,
            completedPageCount: 3
        )
        let fixture = try await makeQueuedCoordinator(
            galleries: [honest],
            queuedGIDs: [],
            client: .noop,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation })
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager

        try writePageFiles(for: honest, in: fixture, indices: [1, 2, 3])
        await manager.reloadDownloadIndex()
        let staged = try #require(await manager.fetchDownload(gid: honest.gid))
        #expect(await manager.resumeMode(for: staged) == .repair)

        _ = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: honest),
            existingDownload: staged,
            folderURL: galleryFolderURL(for: honest, in: fixture)
        )
        // Non-vacuity: an overlay really is standing, so the agreement below is the two bases
        // answering alike rather than the overlay being absent.
        #expect(await manager.fetchDownload(gid: honest.gid)?.runProgress != nil)

        try await expectTheOverlayAgreesWithTheRecord(gid: honest.gid, manager: manager)
        try await flushPages([4], of: honest, in: fixture)
        try await expectTheOverlayAgreesWithTheRecord(gid: honest.gid, manager: manager)
        try await flushPages([5], of: honest, in: fixture)
        try await expectTheOverlayAgreesWithTheRecord(gid: honest.gid, manager: manager)
    }

    /// A page the run OWES that failed reads `.failed`, and a page it has since credited reads
    /// `.downloaded` even with the failure entry still standing — the same precedence a recorded
    /// hash has over a stale failure out of a run.
    @Test
    func testAFailedOutstandingPageReadsFailedUnderTheOverlay() async throws {
        let vanished = SessionGallery(
            gid: "260818-2F-c",
            title: "Vanished",
            pageCount: 6,
            completedPageCount: 6
        )
        let fixture = try await makeRefusalFixture(gallery: vanished, stubSessionID: nil)
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        await manager.reloadDownloadIndex()

        let staged = try #require(await manager.fetchDownload(gid: vanished.gid))
        _ = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: vanished),
            existingDownload: staged,
            folderURL: galleryFolderURL(for: vanished, in: fixture)
        )
        await manager.testingSetFailedPageErrors(
            [.init(index: 4, relativePath: nil, error: .networkingFailed)],
            gid: vanished.gid
        )

        let failedSheet = try await manager.loadInspection(gid: vanished.gid).get()
        #expect(
            failedSheet.pages.map(\.status) == [
                .pending, .pending, .pending, .failed, .pending, .pending
            ]
        )

        try await flushPages([4], of: vanished, in: fixture)

        let creditedSheet = try await manager.loadInspection(gid: vanished.gid).get()
        #expect(
            creditedSheet.pages.map(\.status) == [
                .pending, .pending, .pending, .downloaded, .pending, .pending
            ]
        )
    }

    /// A run that no longer owns its gallery's active slot still publishes the record's reading on
    /// the way out.
    ///
    /// `pause`, `delete` and D-11's expiration sweep each null the active slot while the run they
    /// interrupt is still executing, so such a run's exit is not the one `finishActiveTaskIfOwned`
    /// publishes from. Without the exit publication the row would keep the retired run's reading
    /// until some unrelated publish came along — for the refusal family, a row stuck at k-of-N over
    /// a record that reads N-of-N.
    @Test
    func testANonOwningRunExitStillPublishesTheRecordRead() async throws {
        let vanished = SessionGallery(
            gid: "260818-2F-d",
            title: "Vanished",
            pageCount: 6,
            completedPageCount: 6
        )
        let stubSessionID = UUID().uuidString
        SharedSessionStubURLProtocol.setHandler(for: stubSessionID) { _ in
            throw URLError(.notConnectedToInternet)
        }
        defer { SharedSessionStubURLProtocol.removeHandler(for: stubSessionID) }
        let fixture = try await makeRefusalFixture(
            gallery: vanished,
            stubSessionID: stubSessionID
        )
        defer { removeTemporaryItem(at: fixture.rootURL) }
        let manager = fixture.manager
        await manager.reloadDownloadIndex()

        let staged = try #require(await manager.fetchDownload(gid: vanished.gid))
        _ = try await manager.testingPrepareWorkingSeedAnnouncingProgress(
            payload: makeRepairPayload(for: vanished),
            existingDownload: staged,
            folderURL: galleryFolderURL(for: vanished, in: fixture)
        )

        // Another gallery holds the slot: this run is not superseded (the slot names a different
        // gallery) so it still retires its own measurement, but it does not own the slot either, so
        // `finishActiveTaskIfOwned` publishes nothing for it.
        await manager.testingInstallActiveTask(gid: "busy", task: Task {})
        let readings = collectRunProgressReadings(
            from: await manager.observeDownloads(),
            gid: vanished.gid
        )

        await manager.processDownload(gid: vanished.gid)

        let published = try await waitForTaskValue(
            readings,
            timeout: .seconds(30),
            description: "published rows across a non-owning run exit"
        )
        #expect(published.last == .some(nil))
        #expect(await manager.fetchDownload(gid: vanished.gid)?.runProgress == nil)
    }
}

// MARK: - Helpers

private extension DownloadRunProgressOverlayTests {
    /// The wholesale-refusal staging: a record claiming every page with no page file on disk at all,
    /// so a successful scan accounts for none of the claims and the all-or-nothing guard refuses to
    /// blank any of them.
    ///
    /// A stubbed session is injected for the cases that drive a REAL `processDownload` to a real
    /// exit: the run's first step is a live detail request, and on the shared session that request
    /// would reach the network.
    func makeRefusalFixture(
        gallery: SessionGallery,
        stubSessionID: String?
    ) async throws -> SessionFixture {
        try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [],
            client: .noop,
            taskRunner: DownloadTaskRunner(runScheduledDownload: { _, _ in .skippedOperation }),
            urlSession: stubSessionID
                .map({ makeStubbedURLSession(stubSessionID: $0) }) ?? .shared
        )
    }

    /// Lands `indices` through the production flush, which is the one point every landed page passes
    /// and therefore the only way a case may move the run's measurement.
    func flushPages(
        _ indices: [Int],
        of gallery: SessionGallery,
        in fixture: SessionFixture
    ) async throws {
        try writePageFiles(for: gallery, in: fixture, indices: indices)
        var pendingResolvedPages = pageResults(for: gallery, in: fixture, indices: indices)
        var lastFlushDate = Date.distantPast
        try await fixture.manager.flushDownloadProgress(
            context: .init(
                gid: gallery.gid,
                folderURL: galleryFolderURL(for: gallery, in: fixture)
            ),
            pendingResolvedPages: &pendingResolvedPages,
            lastFlushDate: &lastFlushDate,
            force: true
        )
    }

    /// The honest family's whole claim: badge numerator and inspector `.downloaded` set are what the
    /// record says, whichever basis produced them.
    func expectTheOverlayAgreesWithTheRecord(
        gid: String,
        manager: DownloadCoordinator
    ) async throws {
        let download = try #require(await manager.fetchDownload(gid: gid))
        #expect(download.badge.progress.completedPageCount == download.completedPageCount)
        let inspection = try await manager.loadInspection(gid: gid).get()
        let recordedPages = download.manifest.pages
            .filter({ !$0.value.isEmpty })
            .keys
            .sorted()
        #expect(
            inspection.pages.filter({ $0.status == .downloaded }).map(\.index) == recordedPages
        )
    }

    /// Every published row's run-progress reading for one gallery, in order, up to and including the
    /// first one taken after a standing measurement was withdrawn.
    ///
    /// The stream buffers, so a consumer started before the announcement records what a live one
    /// would have seen without racing the scheduler for it.
    func collectRunProgressReadings(
        from stream: AsyncStream<[DownloadedGallery]>,
        gid: String
    ) -> Task<[DownloadRunProgress?], Never> {
        Task {
            var readings = [DownloadRunProgress?]()
            var sawStandingMeasurement = false
            for await downloads in stream {
                guard let row = downloads.first(where: { $0.gid == gid }) else { continue }
                readings.append(row.runProgress)
                if row.runProgress != nil {
                    sawStandingMeasurement = true
                } else if sawStandingMeasurement {
                    break
                }
            }
            return readings
        }
    }
}
