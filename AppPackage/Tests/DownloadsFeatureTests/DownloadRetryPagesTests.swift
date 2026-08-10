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

    // MARK: The public selection boundary (CR-04)

    /// An entirely out-of-domain request must move nothing at all.
    ///
    /// `pageIndices` is public input. A stale inspection, a page count that shrank upstream, or any
    /// malformed caller can carry numbers this gallery does not have, and the pre-fix boundary
    /// deduplicated them without ever asking whether they existed. What made that a widening rather
    /// than a harmless no-op is downstream: `normalizeFetchedPayload` filtered the invalid values
    /// away and turned the resulting emptiness into `nil`, which `pendingPageIndices` reads as "no
    /// restriction" and answers with every pending page.
    ///
    /// **The blast radius is staged, not assumed.** The fixture claims one of three pages and has
    /// no page files on disk, so an unrestricted repair over it schedules all three — asserted
    /// directly below, so this case states the size of the widening it refuses rather than implying
    /// it. The pure composition of the two steps is pinned in `DownloadZeroPagePayloadTests`.
    ///
    /// The refusal is asserted as a whole-state comparison rather than as an error alone: a
    /// boundary that returned a refusal after clearing the recorded failure, advancing the queue
    /// generation or enqueueing would still be acting on a request the user never made.
    ///
    /// **The error VALUE is part of the contract too (WR-04).** `.notFound` is the answer to two
    /// other conditions here — the gallery is gone (`RetryHelpers.swift:73`) and its folder is gone
    /// (line 88) — so answering an inadmissible selection with it leaves the caller unable to tell
    /// "this download is gone" from "the pages you named are outside this gallery", and the
    /// localized string for `.notFound` reads as the former. The refusal therefore carries its own
    /// `.fileOperationFailed` message; the two absence exits are pinned unchanged by
    /// `testRetryPagesStillAnswersNotFoundWhenTheGalleryOrItsFolderIsAbsent`.
    @Test
    func testRetryPagesRefusesAnAllInvalidSelectionWithoutMovingAnything() async throws {
        let boundary = try await makeRetryBoundaryFixture()
        defer { boundary.tearDown() }
        let manager = boundary.session.manager

        let staged = try #require(await manager.fetchDownload(gid: boundary.gallery.gid))
        #expect(staged.pageCount == 3)
        #expect(await manager.resumeMode(for: staged) != .update)
        // What an unrestricted repair would schedule here, read through the production filter.
        let unrestricted = await manager.pendingPageIndices(
            payload: makeStartPayload(for: boundary.gallery, mode: .repair),
            folderURL: galleryFolderURL(for: boundary.gallery, in: boundary.session),
            existingPageRelativePaths: [:]
        )
        #expect(unrestricted == [1, 2, 3])

        let before = await manager.queueIntentSnapshot(
            gid: boundary.gallery.gid,
            backgroundSessionStartCount: boundary.spy.startCount
        )
        let result = await manager.retryPages(gid: boundary.gallery.gid, pageIndices: [0, 999])

        let after = await manager.queueIntentSnapshot(
            gid: boundary.gallery.gid,
            backgroundSessionStartCount: boundary.spy.startCount
        )
        #expect(after == before)
        guard case .failure(let error) = result else {
            Issue.record("An all-invalid selection must be refused, got \(result).")
            return
        }
        guard case .fileOperationFailed(let message) = error else {
            Issue.record("An inadmissible selection must not answer with an absence error, got \(error).")
            return
        }
        #expect(!message.isEmpty)

        // The two refusals this round separates must not share a sentence either. This one says the
        // pages are not this gallery's; the fetch-time collapse says the gallery changed underneath
        // a selection that WAS admissible when it was made. A fix that reused one key for both
        // would satisfy every assertion above and still leave the user unable to tell the two
        // conditions apart, which is the half of WR-04 the error kind alone does not carry.
        let collapse = await #expect(throws: AppError.self) {
            try await manager.normalizeFetchedPayload(
                makeStartPayload(for: boundary.gallery, mode: .repair, pageSelection: [999]),
                mode: .repair,
                rawPageSelection: [999]
            )
        }
        guard case .fileOperationFailed(let collapseMessage)? = collapse else {
            Issue.record("A fetch-time collapse must carry its own named error, got \(collapse as Any).")
            return
        }
        #expect(collapseMessage != message)
    }

    /// An explicitly empty request is a request, and it fails the same way.
    ///
    /// The pre-fix boundary answered `.success(())` here, which is the same collapse read from the
    /// other side: absence of a selection and a selection of nothing were treated as one value. The
    /// caller asked for no pages and was told the work was accepted, so nothing distinguishes this
    /// reply from one that queued something. Refusing states the truth and leaves the caller's own
    /// failure path — `retryPagesDone(.failure)` reloads the inspection — to resettle the screen.
    @Test
    func testRetryPagesRefusesAnExplicitlyEmptySelectionWithoutMovingAnything() async throws {
        let boundary = try await makeRetryBoundaryFixture()
        defer { boundary.tearDown() }
        let manager = boundary.session.manager

        let before = await manager.queueIntentSnapshot(
            gid: boundary.gallery.gid,
            backgroundSessionStartCount: boundary.spy.startCount
        )
        let result = await manager.retryPages(gid: boundary.gallery.gid, pageIndices: [])

        let after = await manager.queueIntentSnapshot(
            gid: boundary.gallery.gid,
            backgroundSessionStartCount: boundary.spy.startCount
        )
        #expect(after == before)
        guard case .failure(let error) = result else {
            Issue.record("An explicitly empty selection must be refused, got \(result).")
            return
        }
        guard case .fileOperationFailed(let message) = error else {
            Issue.record("An explicitly empty selection must not answer with an absence error, got \(error).")
            return
        }
        #expect(!message.isEmpty)
    }

    /// The two exits that legitimately mean absence keep answering `.notFound`.
    ///
    /// This is the other side of the distinction WR-04 asks for: giving the inadmissible-selection
    /// refusal its own error is only an improvement if these two keep theirs. A fix that renamed
    /// every refusal at once would pass the two cases above and lose exactly as much information as
    /// the conflation did.
    ///
    /// The absent-folder arm deletes the staged directory AFTER the record is indexed, which is the
    /// real shape of that exit — `fetchDownload` answers from the in-memory index while the folder
    /// the record names has gone. The snapshot is compared across both arms because an absence exit
    /// must move nothing either; the folder check sits ahead of every write for the same reason the
    /// admission test does.
    @Test
    func testRetryPagesStillAnswersNotFoundWhenTheGalleryOrItsFolderIsAbsent() async throws {
        let boundary = try await makeRetryBoundaryFixture()
        defer { boundary.tearDown() }
        let manager = boundary.session.manager

        let before = await manager.queueIntentSnapshot(
            gid: boundary.gallery.gid,
            backgroundSessionStartCount: boundary.spy.startCount
        )
        let absentGallery = await manager.retryPages(gid: "no-such-gallery", pageIndices: [1])
        guard case .failure(let absentGalleryError) = absentGallery else {
            Issue.record("An unknown gallery must be refused, got \(absentGallery).")
            return
        }
        #expect(absentGalleryError == .notFound)

        removeTemporaryItem(at: galleryFolderURL(for: boundary.gallery, in: boundary.session))
        let absentFolder = await manager.retryPages(gid: boundary.gallery.gid, pageIndices: [1])
        guard case .failure(let absentFolderError) = absentFolder else {
            Issue.record("A gallery whose folder is gone must be refused, got \(absentFolder).")
            return
        }
        #expect(absentFolderError == .notFound)

        let after = await manager.queueIntentSnapshot(
            gid: boundary.gallery.gid,
            backgroundSessionStartCount: boundary.spy.startCount
        )
        #expect(after == before)
    }

    /// A mixed request keeps exactly its valid part — no wider, and no narrower.
    ///
    /// `[0, 2, 2, 999]` has one page this gallery owns. The stored intent must be `[2]`: dropping
    /// the invalid values is the fix, and dropping page 2 with them would be the fix overshooting
    /// into a refusal the caller did not earn. The duplicate is in the argument because the entry
    /// the coordinator stores is its own transform of the request rather than the literal a caller
    /// typed.
    @Test
    func testRetryPagesQueuesExactlyTheValidSubsetOfAMixedSelection() async throws {
        let boundary = try await makeRetryBoundaryFixture()
        defer { boundary.tearDown() }
        let manager = boundary.session.manager

        try await manager
            .retryPages(gid: boundary.gallery.gid, pageIndices: [0, 2, 2, 999])
            .get()

        let intent = await manager.queueIntentSnapshot(
            gid: boundary.gallery.gid,
            backgroundSessionStartCount: boundary.spy.startCount
        )
        #expect(intent.queuedPageSelection == [2])
        #expect(intent.queuedMode == .repair)
        #expect(intent.isQueued)
        #expect(intent.queueIntentGeneration == 1)
        // The accepted half of the contract: the clears the refusal cases prove are NOT performed
        // are performed here, so "nothing moved" above is a property of the refusal rather than of
        // a fixture with nothing to move.
        #expect(intent.downloadError == nil)
        #expect(intent.failedPageIndices.isEmpty)
        let queued = try #require(await manager.fetchDownload(gid: boundary.gallery.gid))
        #expect(queued.displayStatus == .queued)
    }
}

// MARK: - Retry Boundary Fixture

/// A three-page record with one page claimed, no page files on disk, a recorded download failure
/// and a recorded page failure — staged so that an unrestricted repair over it would be materially
/// broader than any single-page request, and so that every clear the retry paths perform has
/// something to destroy.
private struct RetryBoundaryFixture {
    let session: SessionFixture
    let spy: BackgroundProcessingClientSpy
    let gallery: SessionGallery
    let blockerTask: Task<Void, Never>

    func tearDown() {
        blockerTask.cancel()
        removeTemporaryItem(at: session.rootURL)
    }
}

// MARK: - Setup Helpers

private extension DownloadRetryPagesTests {
    /// Stages `RetryBoundaryFixture` and occupies the active slot.
    ///
    /// The occupant is a plain sleeping task installed through the test seam rather than a parked
    /// production runner: these cases assert that nothing is scheduled, so a live scheduling round
    /// would only add a way for the fixture to start work of its own. With `activeTask` non-nil,
    /// `scheduleNextIfNeededCore` refuses every promotion, and nothing here can reach the network.
    /// The continued session is left unstarted for the same reason — `ensureContinuedSession`
    /// short-circuits on a live session, so a pre-started one would silently blunt the start-count
    /// half of the snapshot.
    func makeRetryBoundaryFixture() async throws -> RetryBoundaryFixture {
        let gallery = SessionGallery(
            gid: "215704",
            title: "Boundary",
            pageCount: 3,
            completedPageCount: 1
        )
        let spy = BackgroundProcessingClientSpy()
        let session = try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [],
            client: spy.client
        )
        await session.manager.testingSetDownloadError(
            .init(code: .networkingFailed, message: "Recorded before the boundary call."),
            gid: gallery.gid
        )
        await session.manager.testingSetFailedPageErrors(
            [
                .init(
                    index: 2,
                    relativePath: "215704_token_2.jpg",
                    error: .networkingFailed
                )
            ],
            gid: gallery.gid
        )
        let blockerTask = Task<Void, Never> {
            await sleepIgnoringCancellation(for: .seconds(60))
        }
        await session.manager.testingInstallActiveTask(
            gid: "retry-boundary-blocker",
            task: blockerTask
        )
        return RetryBoundaryFixture(
            session: session,
            spy: spy,
            gallery: gallery,
            blockerTask: blockerTask
        )
    }

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
