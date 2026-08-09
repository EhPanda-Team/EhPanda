@testable import AppFeature
import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Resources
import Testing

struct DownloadRetryPagesTests: DownloadFeatureTestCase {
    @Test
    func testRetryPagesQueuesWorkWhenAnotherDownloadIsActive() async throws {
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 2)
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(storage: storage, urlSession: .shared)
        try writeManifestFolder(
            storage: storage,
            gid: gid,
            title: "Retry Pages",
            pageHashes: ["sha256:done", ""]
        )
        await manager.reloadDownloadIndex()
        await manager.testingSetFailedPageErrors(
            [
                .init(
                    index: 2,
                    relativePath: "123_token_2.jpg",
                    error: .networkingFailed
                )
            ],
            gid: gid
        )

        let blockingTask = Task<Void, Never> { await sleepIgnoringCancellation(for: .seconds(60)) }
        defer { blockingTask.cancel() }
        await manager.testingInstallActiveTask(gid: "other-active-download", task: blockingTask)

        let result = await manager.retryPages(gid: gid, pageIndices: [2])
        guard case .success = result else {
            Issue.record("Retry pages should succeed, got \(result)")
            return
        }

        let stored = await manager.fetchDownload(gid: gid)
        #expect(stored?.displayStatus == .queued)
        #expect(stored?.badge.status == .queued)
        #expect(stored?.lastError == nil)

    }

    /// D-SSOT-08 on the production path: the REFUSAL family keeps its start after the display basis
    /// moved, and the start does not depend on the record's claims.
    ///
    /// The fixture is the shape 15-56 deliberately left on the `.error` surface — a complete-claiming
    /// record whose page files are all gone. Validation reports `.missingFiles`, the blanking loop's
    /// all-or-nothing guard refuses to empty every claimed hash at once, so the manifest stands and
    /// the transient `validationErrors` entry pins `.error`. From there `togglePause` is hard-closed
    /// and Validate only re-reports itself; the one route out is `retryPages`, whose page selection
    /// travels EXPLICITLY and therefore never consults the manifest's claims.
    ///
    /// **The composition hazard this case exists to name.** Under D-SSOT-07 the page states are
    /// manifest-derived, and this record claims every page — so it has NO pending page and NO failed
    /// page. 15-57's `failed ∪ pending` basis would therefore be EMPTY here, silently re-creating
    /// the G-15-5 dead end for precisely the family the affordance was built for, and doing it
    /// invisibly: the button would still exist, with nothing to send. The basis is asserted
    /// non-empty and equal to the whole page set BEFORE `retryPages` is driven, so a regression to
    /// any subset-shaped basis fails here rather than in a device session.
    ///
    /// The `.queued` assertion is the load-bearing one: `validationErrors` outranks both
    /// `activeGalleryID` and queue membership in `displayStatus`, so `.queued` is reachable only
    /// once `performRetryPages`'s failure-state clearing has removed the entry at enqueue.
    ///
    /// **Determinism.** A single-gallery fixture would race: `scheduleNextIfNeeded` assigns
    /// `activeGalleryID` before returning and `displayStatus` reads it AHEAD of queue membership, so
    /// the status would read `.active` until the run settles. A second BLOCKER gallery therefore
    /// takes the active slot first and never gives it back — the runner double suspends inside
    /// `BlockingRunnerControl.park()`, at its `withCheckedContinuation`, resumed only by `release()`
    /// in teardown — and `control.started()` is awaited before anything is asserted, so the
    /// blocker's occupancy is a production-issued fact. `scheduleNextIfNeededCore`'s
    /// `activeTask == nil` guard then refuses every promotion, making the target's `.queued` stable
    /// indefinitely rather than momentarily true.
    @Test
    func testRetryingAWholesaleRefusedRecordQueuesARepairOverEveryPage() async throws {
        let target = SessionGallery(
            gid: "215701",
            title: "Refused",
            pageCount: 2,
            completedPageCount: 2
        )
        let blocker = SessionGallery(gid: "215702", title: "Blocking", pageCount: 2)
        let spy = BackgroundProcessingClientSpy()
        let control = BlockingRunnerControl()
        let fixture = try await makeQueuedCoordinator(
            galleries: [blocker, target],
            queuedGIDs: [blocker.gid],
            client: spy.client,
            taskRunner: DownloadTaskRunner(
                runScheduledDownload: { _, _ in
                    await control.park()
                    return .skippedOperation
                }
            )
        )
        // Release before removal, so the parked runner is not holding a directory being deleted.
        defer {
            control.release()
            removeTemporaryItem(at: fixture.rootURL)
        }

        await fixture.manager.scheduleNextIfNeeded()
        await control.started()
        let blocking = try #require(await fixture.manager.fetchDownload(gid: blocker.gid))
        #expect(blocking.displayStatus == .active)

        let validation = await fixture.manager.validateImageData(gid: target.gid)

        #expect(validation == .missingFiles(.RLocalizable.downloadStorePageMissing(page: 1)))
        let refused = try #require(await fixture.manager.fetchDownload(gid: target.gid))
        #expect(refused.displayStatus == .error)
        #expect(refused.lastError?.code == .fileOperationFailed)
        // The refusal's substance: the record still claims every page it claimed before.
        #expect(refused.completedPageCount == 2)

        let inspection = try await fixture.manager.loadInspection(gid: target.gid).get()
        // The manifest-derived reading of a refusal record: it claims every page, so every page
        // reads `.downloaded` and neither of the sets a subset-shaped basis could draw from exists.
        #expect(inspection.pages.map(\.status) == [.downloaded, .downloaded])
        #expect(inspection.failedPageIndices.isEmpty)
        #expect(inspection.pages.filter({ $0.status == .pending }).isEmpty)
        // D-SSOT-08: the operation-level error is a record-wide signal, so the honest selection is
        // every page. Asserted non-empty explicitly — that is the property the superseded
        // `failed ∪ pending` union would have lost here without failing anything else.
        #expect(inspection.retryablePageIndices.isEmpty == false)
        #expect(inspection.retryablePageIndices == [1, 2])
        #expect(inspection.canRetryPages)

        // Routed through the very array the button sends, so the selection under test is the
        // production one rather than a set only this test knows how to derive.
        try await fixture.manager
            .retryPages(gid: target.gid, pageIndices: inspection.retryablePageIndices)
            .get()

        let queued = try #require(await fixture.manager.fetchDownload(gid: target.gid))
        #expect(queued.displayStatus == .queued)
        #expect(queued.lastError == nil)
        #expect(await fixture.manager.queuedMode(for: queued) == .repair)
        #expect(await fixture.manager.queuedPageSelections[target.gid] == [1, 2])
    }

    @Test
    func testCancelQueuedWorkClearsQueueIntent() async throws {
        let gid = "cancel-repair-\(UUID().uuidString)"
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let storage = DownloadStore(rootURL: rootURL, fileManager: .default)
        let manager = DownloadCoordinator(
            storage: storage,
            urlSession: .shared
        )

        try writeManifestFolder(
            storage: storage,
            gid: gid,
            title: "Queued",
            pageHashes: ["sha256:done", ""]
        )
        await manager.reloadDownloadIndex()
        await manager.testingSetQueuedGalleryIDs([gid])

        let result = await manager.togglePause(gid: gid)
        guard case .success = result else {
            Issue.record("Cancelling queued work should succeed, got \(result)")
            return
        }

        let stored = await manager.fetchDownload(gid: gid)
        #expect(stored?.displayStatus == .inactive)
        #expect(stored?.completedPageCount == 1)
        #expect(
            stored?.badge == DownloadBadge(
                status: .inactive,
                progress: .init(completedPageCount: 1, pageCount: 2)
            )
        )
    }

    // MARK: The operation-level retry basis (D-SSOT-08)

    /// The widened regime, and the only one: at `.error` over a file-shaped failure the basis is the
    /// WHOLE page set, whatever the individual pages happen to read.
    ///
    /// The failure is operation-level — it says the last validation could not produce trustworthy
    /// evidence for every claimed page — so no per-page subset is derivable from it, and drawing one
    /// anyway is a category error. Every index goes, and the repair run's own evidence (the working
    /// seed's scan, the missing-file fetch filter) decides what is actually re-fetched.
    @Test
    func testTheRetryBasisIsTheWholePageSetForTheFileFailureErrorShape() {
        let inspection = basisInspection(
            status: .missingFiles,
            pageStatuses: [.downloaded, .failed, .pending]
        )

        #expect(inspection.retryablePageIndices == [1, 2, 3])
        #expect(inspection.canRetryPages)
    }

    /// The boundary from the inside: `.error` alone does not widen anything. A networking-shaped
    /// failure is an ordinary interruption rather than a statement about the whole record, so its
    /// per-page evidence is intact and the basis stays the failed set alone.
    @Test
    func testTheRetryBasisStaysFailedOnlyForAnErrorWithADifferentFailureCode() {
        let inspection = basisInspection(
            status: .failed,
            pageStatuses: [.downloaded, .failed, .pending]
        )

        #expect(inspection.retryablePageIndices == [2])
        #expect(inspection.canRetryPages)
    }

    /// The boundary from the outside: a healthy-incomplete `.inactive` record's undone pages stay
    /// Resume's business, so the basis is the failed set alone and the gate closes when that set is
    /// empty. Without this pin the widening would silently become a second, page-selection-shaped
    /// resume — and under the full-set basis it would be an even blunter one.
    @Test
    func testTheRetryBasisStaysFailedOnlyForANonErrorDownloadWithPendingPages() {
        let withFailure = basisInspection(
            status: .paused,
            pageStatuses: [.failed, .pending, .pending]
        )

        #expect(withFailure.retryablePageIndices == [1])
        #expect(withFailure.canRetryPages)

        let withoutFailure = basisInspection(
            status: .paused,
            pageStatuses: [.downloaded, .pending, .pending]
        )

        #expect(withoutFailure.retryablePageIndices.isEmpty)
        #expect(withoutFailure.canRetryPages == false)
    }

    /// The composition hazard, stated at the unit level beside the arc that drives it end to end.
    ///
    /// This is the manifest-derived reading of a wholesale-refusal record: it claims every page, so
    /// under D-SSOT-07 no page reads `.pending` and none reads `.failed`. Any basis drawn as a
    /// subset of those two sets — 15-57's `failed ∪ pending` in particular — is EMPTY here, which
    /// would close the gate on exactly the family the affordance exists for while leaving the button
    /// visibly present. The full-set basis is what keeps the gate open, so a nonzero-page record on
    /// the error surface is always retryable.
    @Test
    func testTheWholesaleRefusalShapeIsFullyRetryableThoughNoPageReadsPendingOrFailed() {
        let inspection = basisInspection(
            status: .missingFiles,
            pageStatuses: [.downloaded, .downloaded]
        )

        #expect(inspection.failedPageIndices.isEmpty)
        #expect(inspection.pages.filter({ $0.status == .pending }).isEmpty)
        #expect(inspection.retryablePageIndices == [1, 2])
        #expect(inspection.canRetryPages)
    }
}

// MARK: - Setup Helpers

private extension DownloadRetryPagesTests {
    /// A `DownloadInspection` whose download carries `status`'s display status and failure code, and
    /// whose pages are `pageStatuses` in page order starting at 1.
    ///
    /// Built directly rather than through a coordinator: the basis is a pure function of the
    /// record's status, its failure code and the page statuses, so staging it on disk would only
    /// add ways for the fixture to disagree with the thing under test.
    func basisInspection(
        status: DownloadFixtureStatus,
        pageStatuses: [DownloadPageStatus]
    ) -> DownloadInspection {
        let indexedStatuses = Array(pageStatuses.enumerated())
        let pages = indexedStatuses.map({
            DownloadPageInspection(index: $0.offset + 1, status: $0.element)
        })
        return DownloadInspection(
            download: sampleDownload(
                gid: "215703",
                title: "Basis",
                status: status,
                pageCount: pageStatuses.count
            ),
            coverURL: nil,
            pages: pages
        )
    }

    @discardableResult
    func writeManifestFolder(
        storage: DownloadStore,
        gid: String,
        title: String,
        pageHashes: [String]
    ) throws -> URL {
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[\(gid)_token] \(title)")
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            DownloadManifest(
                gid: gid,
                host: .ehentai,
                token: "token",
                title: title,
                jpnTitle: nil,
                category: .doujinshi,
                language: .japanese,
                remoteCoverURL: URL(string: "https://example.com/cover.jpg"),
                uploader: "Uploader",
                tags: [],
                postedDate: .now,
                rating: 4,
                pages: Dictionary(
                    uniqueKeysWithValues:
                        pageHashes.enumerated().map({ ($0.offset + 1, $0.element) })
                )
            ),
            folderURL: folderURL
        )
        return folderURL
    }

}
