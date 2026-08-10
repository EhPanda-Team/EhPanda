@testable import AppFeature
import AppModels
import BackgroundProcessingClient
import DownloadClient
import Foundation
import Testing

struct DownloadRetryUpdateFallbackTests: DownloadFeatureTestCase {
    @Test
    func testRetryPagesQueuesFullUpdateWhenGalleryHasUpdate() async throws {
        let sessionID = UUID().uuidString
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 400)
        let pageIndex = 42
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let (storage, queueingManager) = makeStubbedDownloadCoordinator(
            rootURL: rootURL, sessionID: sessionID
        )
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        let fallbackResult = try await fetchUpdateFallbackPayload(
            manager: queueingManager, sessionID: sessionID, gid: gid,
            pageIndex: pageIndex
        )
        let pageCount = fallbackResult.pageCount
        let oldCount = pageCount - 5

        try writeFinalManifest(
            storage: storage,
            gid: gid,
            pageCount: oldCount
        )
        await queueingManager.reloadDownloadIndex()
        await queueingManager.testingSetUpdatedGalleryIDs([gid])
        let queuedCandidate = await queueingManager.fetchDownload(gid: gid)
        #expect(queuedCandidate?.hasUpdate == true)

        let blockerTask = Task<Void, Never> { await sleepIgnoringCancellation(for: .seconds(5)) }
        await queueingManager.testingInstallActiveTask(gid: "blocker", task: blockerTask)
        defer { blockerTask.cancel() }

        let retryResult = await queueingManager.retryPages(gid: gid, pageIndices: [pageIndex])
        guard case .success = retryResult else {
            Issue.record("retryPages should succeed, got \(retryResult)")
            return
        }

        let queued = await queueingManager.fetchDownload(gid: gid)
        #expect(queued?.displayStatus == .queued)
        #expect(queued?.badge.status == .queued)
        #expect(queued?.lastError == nil)
    }

    @Test
    func testRetryPagesNormalizesImmediateUpdateWhenGalleryHasUpdate() async throws {
        let sessionID = UUID().uuidString
        let gid = String(Int(Date().timeIntervalSince1970 * 1000) + 400)
        let pageIndex = 42
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { removeTemporaryItem(at: rootURL) }

        let (storage, immediateManager) = makeStubbedDownloadCoordinator(
            rootURL: rootURL, sessionID: sessionID
        )
        defer { SharedSessionStubURLProtocol.removeHandler(for: sessionID) }

        let updateResult = try await fetchUpdateFallbackPayload(
            manager: immediateManager, sessionID: sessionID, gid: gid,
            pageIndex: pageIndex
        )
        let pageCount = updateResult.pageCount

        try setupImmediateUpdateTestState(
            storage: storage,
            context: DownloadPageContext(gid: gid, pageIndex: pageIndex, pageCount: pageCount)
        )
        await immediateManager.reloadDownloadIndex()
        await immediateManager.testingSetUpdatedGalleryIDs([gid])

        let immediateBlockerTask = Task<Void, Never> {
            await sleepIgnoringCancellation(for: .seconds(5))
        }
        await immediateManager.testingInstallActiveTask(gid: gid, task: immediateBlockerTask)
        defer { immediateBlockerTask.cancel() }

        let result = await immediateManager.retryPages(gid: gid, pageIndices: [pageIndex])
        guard case .success = result else {
            Issue.record("Immediate retryPages should succeed, got \(result)")
            return
        }

        let resumedDownload = await immediateManager.fetchDownload(gid: gid)
        #expect(resumedDownload?.displayStatus == .active)
        #expect(resumedDownload?.lastError == nil)
    }

    // MARK: - The update boundary (CR-04)

    /// The ordering finding, stated as a property: validation precedes delegation.
    ///
    /// Pre-fix, `retryPages` resolved the mode BEFORE it looked at the caller's indices at all, so
    /// an update record short-circuited into `retry(gid:mode:.update)` — which clears the whole
    /// session state, advances the queue-intent generation, queues the gallery with no page
    /// selection and ensures a continued session. That is the widest work the module can schedule
    /// for one gallery, reached from a request naming zero admissible pages. The delegation itself
    /// is correct; only its position was wrong.
    ///
    /// **The refusal's VALUE moved with the guard, and that is the point (WR-04).** Because the
    /// admission test sits ahead of mode resolution, an update record and a repair record are
    /// refused by the very same exit — so the distinct inadmissible-selection error reaches this
    /// case too, and pinning `.notFound` here would have re-conflated "the pages you named are not
    /// this gallery's" with "this gallery is gone" for exactly one of the two record kinds. The two
    /// absence exits keep `.notFound`; they are pinned in `DownloadRetryPagesTests`.
    @Test(arguments: [[Int](), [0, 999]])
    func testAnInadmissibleUpdateRequestIsRefusedBeforeDelegation(
        pageIndices: [Int]
    ) async throws {
        let boundary = try await makeUpdateBoundaryFixture()
        defer { boundary.tearDown() }
        let manager = boundary.session.manager

        let staged = try #require(await manager.fetchDownload(gid: boundary.gallery.gid))
        #expect(staged.hasUpdate)
        #expect(await manager.resumeMode(for: staged) == .update)

        let before = await manager.queueIntentSnapshot(
            gid: boundary.gallery.gid,
            backgroundSessionStartCount: boundary.spy.startCount
        )
        let result = await manager.retryPages(
            gid: boundary.gallery.gid,
            pageIndices: pageIndices
        )

        let after = await manager.queueIntentSnapshot(
            gid: boundary.gallery.gid,
            backgroundSessionStartCount: boundary.spy.startCount
        )
        #expect(after == before)
        guard case .failure(let error) = result else {
            Issue.record("An inadmissible update request must be refused, got \(result).")
            return
        }
        guard case .fileOperationFailed(let message) = error else {
            Issue.record("An inadmissible selection must not answer with an absence error, got \(error).")
            return
        }
        #expect(!message.isEmpty)
    }

    /// The documented exception, pinned so it stays deliberate.
    ///
    /// One admissible page is enough to queue the WHOLE update, with no page selection at all. That
    /// is not the subset preservation of `.repair` failing quietly: an update re-fetches the gallery
    /// against a new page count, and a subset drawn against the old one names pages that may no
    /// longer be the same pages. The mixed argument is the load-bearing half — it proves the
    /// admissibility test is "at least one valid page" rather than "every page valid", so a
    /// hardening that also refused mixed input would fail here instead of quietly removing the
    /// user's only route to an update.
    @Test(arguments: [[2], [0, 2, 999]])
    func testAnAdmissibleUpdateRequestQueuesTheWholeUpdate(
        pageIndices: [Int]
    ) async throws {
        let boundary = try await makeUpdateBoundaryFixture()
        defer { boundary.tearDown() }
        let manager = boundary.session.manager

        try await manager
            .retryPages(gid: boundary.gallery.gid, pageIndices: pageIndices)
            .get()

        let intent = await manager.queueIntentSnapshot(
            gid: boundary.gallery.gid,
            backgroundSessionStartCount: boundary.spy.startCount
        )
        #expect(intent.queuedMode == .update)
        // Explicitly nil, not merely "not the requested subset": nil is what tells the run to
        // refresh every page, which is the whole point of delegating an update.
        #expect(intent.queuedPageSelection == nil)
        #expect(intent.isQueued)
        #expect(intent.queueIntentGeneration == 1)
        let queued = try #require(await manager.fetchDownload(gid: boundary.gallery.gid))
        #expect(await manager.queuedMode(for: queued) == .update)
        #expect(queued.displayStatus == .queued)
    }
}

// MARK: - Update Boundary Fixture

/// A four-page record carrying a pending update, a recorded download failure and a recorded page
/// failure, with the active slot occupied so nothing can be scheduled underneath an assertion.
private struct UpdateBoundaryFixture {
    let session: SessionFixture
    let spy: BackgroundProcessingClientSpy
    let gallery: SessionGallery
    let blockerTask: Task<Void, Never>

    func tearDown() {
        blockerTask.cancel()
        removeTemporaryItem(at: session.rootURL)
    }
}

// MARK: - Update Fallback Payload Result

private struct UpdateFallbackPayloadResult {
    let pageCount: Int
}

// MARK: - Download Page Context

private struct DownloadPageContext {
    let gid: String
    let pageIndex: Int
    let pageCount: Int
}

// MARK: - Setup Helpers

private extension DownloadRetryUpdateFallbackTests {
    /// Stages `UpdateBoundaryFixture`.
    ///
    /// Deliberately not the stubbed-session fixture the two cases above use: those need a live
    /// detail fetch because they drive a run, while these cases assert that no run is reached at
    /// all. `hasUpdate` comes from the coordinator's updated-gallery set, which is what
    /// `resumeMode` actually reads, so the `.update` regime here is the production one rather than
    /// a network response this suite would have to keep truthful.
    ///
    /// The active slot holds a plain sleeping task, so `scheduleNextIfNeededCore` refuses every
    /// promotion and nothing reaches the network. The continued session is left unstarted:
    /// `ensureContinuedSession` short-circuits on a live session, so a pre-started one would blunt
    /// the start-count half of the snapshot.
    func makeUpdateBoundaryFixture() async throws -> UpdateBoundaryFixture {
        let gallery = SessionGallery(
            gid: "215801",
            title: "Updatable",
            pageCount: 4,
            completedPageCount: 4
        )
        let spy = BackgroundProcessingClientSpy()
        let session = try await makeQueuedCoordinator(
            galleries: [gallery],
            queuedGIDs: [],
            client: spy.client
        )
        await session.manager.testingSetUpdatedGalleryIDs([gallery.gid])
        await session.manager.testingSetDownloadError(
            .init(code: .networkingFailed, message: "Recorded before the boundary call."),
            gid: gallery.gid
        )
        await session.manager.testingSetFailedPageErrors(
            [
                .init(
                    index: 2,
                    relativePath: "215801_token_2.jpg",
                    error: .networkingFailed
                )
            ],
            gid: gallery.gid
        )
        let blockerTask = Task<Void, Never> {
            await sleepIgnoringCancellation(for: .seconds(60))
        }
        await session.manager.testingInstallActiveTask(
            gid: "update-boundary-blocker",
            task: blockerTask
        )
        return UpdateBoundaryFixture(
            session: session,
            spy: spy,
            gallery: gallery,
            blockerTask: blockerTask
        )
    }

    func fetchUpdateFallbackPayload(
        manager: DownloadCoordinator, sessionID: String, gid: String,
        pageIndex: Int
    ) async throws -> UpdateFallbackPayloadResult {
        let stubContent = StubHandlerContent(
            detailHTML: try fixtureData(resource: "GalleryDetail", pathExtension: "html"),
            mpvHTML: try fixtureData(resource: "GalleryMPVKeys", pathExtension: "html"),
            metadataResponse: try makeMetadataResponseData(gid: gid)
        )
        installDownloadStubHandler(
            sessionID: sessionID, gid: gid, pageIndex: pageIndex, content: stubContent
        )
        let scaffoldDownload = sampleDownload(
            gid: gid, title: "Pause Race", status: .partial,
            pageCount: 156, completedPageCount: 155
        )
        let fetchedPayload = try await manager.fetchLatestPayload(
            for: scaffoldDownload, mode: .update, options: .init(), pageSelection: nil
        )
        let pageCount = fetchedPayload.galleryDetail.pageCount
        #expect(pageCount > pageIndex)
        #expect(pageCount > 5)
        return UpdateFallbackPayloadResult(pageCount: pageCount)
    }

    func setupImmediateUpdateTestState(
        storage: DownloadStore,
        context: DownloadPageContext
    ) throws {
        let oldCount = context.pageCount - 5
        try writeFinalManifest(
            storage: storage,
            gid: context.gid,
            pageCount: oldCount
        )
    }

    func writeFinalManifest(
        storage: DownloadStore,
        gid: String,
        pageCount: Int
    ) throws {
        try storage.ensureRootDirectory()
        let folderURL = storage.folderURL(relativePath: "Folder/[\(gid)_token] Pause Race")
        try FileManager.default.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )
        try storage.writeManifest(
            completeManifest(gid: gid, title: "Pause Race", pageCount: pageCount),
            folderURL: folderURL
        )
    }

    func completeManifest(
        gid: String,
        title: String,
        pageCount: Int
    ) throws -> DownloadManifest {
        let manifest = try sampleManifest(
            gid: gid,
            title: title,
            pageCount: pageCount
        )
        return DownloadManifest(
            gid: manifest.gid,
            host: manifest.host,
            token: manifest.token,
            title: manifest.title,
            jpnTitle: manifest.jpnTitle,
            category: manifest.category,
            language: manifest.language,
            remoteCoverURL: manifest.remoteCoverURL,
            uploader: manifest.uploader,
            tags: manifest.tags,
            postedDate: manifest.postedDate,
            rating: manifest.rating,
            pages: Dictionary(
                uniqueKeysWithValues:
                    manifest.pages.keys.sorted().map { ($0, "sha256:\($0)") }
            )
        )
    }
}
