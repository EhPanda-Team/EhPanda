import AppModels
import Foundation
import OSLogExt
import Resources

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

// MARK: - Public API
extension DownloadCoordinator {
    public func observeDownloads() async -> AsyncStream<[DownloadedGallery]> {
        // Let the hub pull the snapshot inside its own registration so the
        // capture-then-register hop can't strand a new observer on a stale
        // initial when a notify lands in the window (BUG-16).
        await observerHub.observe {
            await self.indexedDownloads()
        }
    }

    public func fetchDownloads() async -> [DownloadedGallery] {
        return await indexedDownloads()
    }

    public func reconcileDownloads() async {
        await syncDownloadsState(scheduleNext: false)
    }

    public func refreshDownloads() async {
        await syncDownloadsState(scheduleNext: true)
    }

    public func resumeQueue() async {
        await scheduleNextIfNeeded()
    }

    public func updateRemoteVersion(
        gid: String,
        metadata: DownloadVersionMetadata
    ) async -> DownloadedGallery? {
        guard let download = await fetchDownload(gid: gid) else {
            return nil
        }
        guard downloadIndex[gid] != nil else {
            return download
        }
        guard [.completed, .updateAvailable].contains(download.displayStatus) else {
            return download
        }

        let hadUpdate = updatedGalleryIDs.contains(gid)
        let hasUpdate = metadata.hasUpdate(comparedTo: download)
        if hasUpdate {
            updatedGalleryIDs.insert(gid)
        } else {
            updatedGalleryIDs.remove(gid)
        }
        if hadUpdate != hasUpdate {
            await notifyObservers()
        }
        return await fetchDownload(gid: gid)
    }

    /// Commits a gallery to the download queue.
    ///
    /// **D-G14-01: a zero-page payload is refused here, ahead of every folder and queue mutation.**
    /// The run could not finish such a gallery — each page range it would build is empty — and this
    /// phase deleted the discretionary background tier, so a queue entry no run can finish is a
    /// standing liveness hazard rather than a harmless no-op. `.notFound` is the disposition the
    /// fetch boundary already gives a detail that cannot support a run, so both entrances answer
    /// the same degenerate parse the same way.
    public func enqueue(
        payload: DownloadRequestPayload
    ) async -> Result<Void, AppError> {
        guard payload.galleryDetail.pageCount > 0 else { return .failure(.notFound) }
        do {
            try storage.ensureRootDirectory()
            // An already-known gallery keeps its current folder; only brand-new
            // downloads land in the folder carried by the payload.
            let parentFolderName: String
            if let record = downloadIndex[payload.gallery.gid] {
                parentFolderName = record.parentFolderName
            } else if let normalizedName = storage.normalizedUserFolderName(payload.folderName) {
                parentFolderName = normalizedName
            } else {
                return .failure(
                    .fileOperationFailed(
                        String(localized: .RLocalizable.downloadStoreInvalidFolderName)
                    )
                )
            }
            // No separate user-folder creation here (CR-02). `writeInitialManifest` creates
            // `<root>/<parentFolderName>/<galleryFolder>` with intermediate directories a few
            // lines below, so the parent was already being created by the call that creates the
            // gallery folder; the extra one existed only to make it eagerly, and it made it by
            // appending a name to the root with no confinement — the construction that let
            // `deleteFolder` reach a gallery folder. Two consequences, both wanted: no user-folder
            // mutation takes a name on this route at all, and a manifest write that fails no
            // longer leaves an empty user folder behind. `ensureRootDirectory` above still owns
            // the root itself, including its backup exclusion.
            let folderRelativePath = folderRelativePath(
                for: payload,
                parentFolderName: parentFolderName
            )
            try writeInitialManifest(
                payload: payload,
                folderRelativePath: folderRelativePath
            )
            // The fifth entrance to the queue, and the one that used to skip this. `validationErrors`
            // and `downloadErrors` outrank queue membership in `displayStatus`, so an entry standing
            // over a gallery this call enqueues derives `.error`, `shouldSchedule` fails both arms,
            // and the gallery sits in the queue store forever without ever running — the G-15-5 dead
            // end, silently. This path explicitly supports an already-known gallery (above), and
            // Detail presents its download menu on `downloadBadge == nil` rather than on
            // `hasLoadedDownloadBadge`, so a record carrying an entry really can arrive here.
            clearDownloadFailureState(gid: payload.gallery.gid)
            advanceQueueIntentGeneration(for: payload.gallery.gid)
            await queueStore.enqueue(payload.gallery.gid)
            await notifyObservers()
            await scheduleNextIfNeeded()
            // Ensured here, after the work is committed and already running, rather than at the
            // scheduling convergence point: only a foreground user action can submit a session.
            // Work that becomes schedulable without a tap — the queue resuming at cold launch,
            // say — therefore runs foreground-only until the next qualifying tap, deliberately.
            await ensureContinuedSession()
            // Hash masking preserves cross-line gallery correlation without disclosure. Errors stay
            // private because gallery-folder paths embed titles; titles add no operational signal.
            logger.notice(
                "Download enqueued, gid: \(payload.gallery.gid, privacy: .private(mask: .hash))."
            )
            return .success(())
        } catch let error as AppError {
            return .failure(error)
        } catch {
            logger.error("\(error, privacy: .private)")
            return .failure(.unknown)
        }
    }

    /// The enqueue route's own deliberate mover of the session accounting basis, wrapped in the same
    /// D-G7-01 bracket the run route's preparation uses.
    ///
    /// The fresh branch replaces a record that may already be counted — an unreadable manifest, or
    /// one whose page keys no longer match the payload's page count, at enqueue or at any retry that
    /// re-enqueues — so it moves the very quantity the numerator is summed from. One shared bracket
    /// rather than a second withdrawal here is what stops the rule from forking between the two
    /// routes; the reusable branch re-indexes the same manifest, so its delta is zero and it
    /// withdraws nothing without needing a branch of its own.
    private func writeInitialManifest(
        payload: DownloadRequestPayload,
        folderRelativePath: String
    ) throws {
        try withdrawingCountedBasisMovement(gid: payload.gallery.gid) {
            let folderURL = storage.folderURL(relativePath: folderRelativePath)
            try createDirectory(at: folderURL)
            if let existingManifest = reusableExistingManifest(
                payload: payload,
                folderURL: folderURL
            ) {
                updateDownloadIndex(folderURL: folderURL, manifest: existingManifest)
                return
            }
            let manifest = makeInitialManifest(payload: payload)
            try storage.writeManifest(manifest, folderURL: folderURL)
            updateDownloadIndex(folderURL: folderURL, manifest: manifest)
        }
    }

    private func reusableExistingManifest(
        payload: DownloadRequestPayload,
        folderURL: URL
    ) -> DownloadManifest? {
        // Reuse is an optional probe; unreadable or incompatible manifests fall back
        // to the normal fresh-manifest write path in writeInitialManifest.
        guard let manifest = storage.probeManifest(folderURL: folderURL),
              manifest.gid == payload.gallery.gid,
              manifest.token == payload.gallery.token,
              manifest.host == payload.host
        else {
            return nil
        }
        let expectedPageIndices = payload.galleryDetail.pageCount > 0
            ? Set(1...payload.galleryDetail.pageCount)
            : Set<Int>()
        guard Set(manifest.pages.keys) == expectedPageIndices else {
            return nil
        }
        return manifest
    }

    public func togglePause(gid: String) async -> Result<Void, AppError> {
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }

        if activeGalleryID == gid {
            return await pause(gid: gid)
        }

        if let queuedMode = queuedModes[gid] {
            return await cancelQueuedWorkItem(download, mode: queuedMode)
        }

        switch download.displayStatus {
        case .queued, .active:
            return await pause(gid: gid)
        case .inactive:
            // The one branch of this toggle that mobilizes the queue. The branches above pause an
            // active download or cancel a queued work item, and neither may start a session.
            let result = await resume(gid: gid)
            guard case .success = result else { return result }
            await ensureContinuedSession()
            return result
        case .completed, .error, .updateAvailable:
            return .failure(.unknown)
        }
    }

    public func delete(gid: String) async -> Result<Void, AppError> {
        let taskToCancel: Task<Void, Never>?
        blockScheduling(gid: gid)
        if activeGalleryID == gid {
            taskToCancel = activeTask
            activeTask?.cancel()
            activeTask = nil
            activeGalleryID = nil
        } else {
            taskToCancel = nil
        }
        await taskToCancel?.value
        guard let download = await fetchDownload(gid: gid) else {
            clearDownloadSessionState(gid: gid, includeUpdateFlag: true)
            await queueStore.remove(gid)
            await backgroundTaskStore.removeAll(for: gid)
            // The cancelled task's generation no longer owns `activeGalleryID`, so its deferred
            // cleanup cannot schedule. Returning here would strand both the queue and its session.
            releaseScheduling(gid: gid)
            await notifyObservers()
            await scheduleNextIfNeeded()
            return .failure(.notFound)
        }
        do {
            try removeGalleryFolders(gid: download.gid, token: download.token)
        } catch let error as AppError {
            await reloadDownloadRecord(gid: download.gid, token: download.token)
            // ACTIVE-OWNERSHIP CONVERGENCE: release the failed gallery before converging or the
            // scheduler would silently skip it. Exactly one release per exit — the former
            // function-scoped `defer` sat behind these explicit removes, which a `Set` tolerated
            // and a reference count would not.
            releaseScheduling(gid: gid)
            await notifyObservers()
            await scheduleNextIfNeeded()
            return .failure(error)
        } catch {
            logger.error("\(error, privacy: .private)")
            await reloadDownloadRecord(gid: download.gid, token: download.token)
            releaseScheduling(gid: gid)
            await notifyObservers()
            await scheduleNextIfNeeded()
            return .failure(.fileOperationFailed(error.localizedDescription))
        }
        // Clear session and queue state only once the folders are gone; a failed
        // removal above leaves the gallery intact and must not silently dequeue it.
        clearDownloadSessionState(gid: gid, includeUpdateFlag: true)
        await queueStore.remove(gid)
        await backgroundTaskStore.removeAll(for: gid)
        downloadIndex[gid] = nil
        releaseScheduling(gid: gid)
        await notifyObservers()
        await scheduleNextIfNeeded()
        logger.notice("Download deleted, gid: \(gid, privacy: .private(mask: .hash)).")
        return .success(())
    }

    public func loadManifest(
        gid: String
    ) async -> Result<(download: DownloadedGallery, manifest: DownloadManifest), AppError> {
        // Opening a gallery is a READ end to end (CR-03). This used to route through the coordinator
        // sweep, whose only effect was the probe's housekeeping deletion, and then validate on the
        // discarding default — so a reader open destroyed a zero-byte or non-regular page or cover
        // file, reported the page missing, and wrote nothing to the manifest. The record kept its
        // non-empty hash, the gallery kept deriving `.completed` under D-SSOT-07, and the divergence
        // survived relaunch. Both halves are reads now, and the verdict below is unchanged.
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }
        switch storage.validate(
            download: download,
            verifiesContentHashes: false
        ) {
        case .valid:
            break
        case .missingFiles(let message):
            return .failure(.fileOperationFailed(String(localized: message)))
        }
        do {
            let manifest = try storage.readManifest(folderURL: download.folderURL)
            return .success((download, manifest))
        } catch {
            return .failure(.fileOperationFailed(error.localizedDescription))
        }
    }

    public func captureCachedPage(
        gid: String,
        index: Int,
        imageURL: URL?
    ) async {
        guard downloadIndex[gid] != nil else { return }
        // G-15-14, same class as the range sites this module guards: a record's page count bounds
        // an index here too, so a zero-page record is refused rather than widened past. The upper
        // bound used to raise that count to a floor of one instead of guarding it, which ADMITTED
        // index 1 for a record claiming no pages — a capture that would write a page file no
        // manifest claims, invisible to `pageFileScan` and skipped by
        // `refreshManifestPageFileHashes`. Reachability is closed upstream (`enqueue` refuses a
        // zero-page payload, `validateDecodedManifest` rejects an empty page dictionary on every
        // manifest read), so this is defence in depth, not a live defect.
        guard let download = await fetchDownload(gid: gid),
              download.pageCount > 0,
              index >= 1,
              index <= download.pageCount
        else { return }

        guard let captureTarget = captureTarget(
            for: download, index: index
        ) else { return }

        await performCacheCapture(
            gid: gid,
            index: index,
            imageURL: imageURL,
            captureTarget: captureTarget,
            download: download
        )
    }

    private func performCacheCapture(
        gid: String,
        index page: Int,
        imageURL: URL?,
        captureTarget: CaptureTargetResult,
        download: DownloadedGallery
    ) async {
        // A READ (CR-03), for the same reason `captureTarget` is: this names the file ONE page may
        // reuse, while the scan probes every claimed page and this capture lowers no hash but its
        // own. A refused file is outside `pages` whether or not it is deleted, so the fallback below
        // resolves identically.
        let existingPages = storage.existingPageRelativePaths(
            folderURL: captureTarget.folderURL,
            manifest: download.manifest
        )
        do {
            let cacheURLs = pageImageCacheURLs(imageURL: imageURL)
            let cacheSource = CacheRestoreSource(
                gid: download.gid,
                token: download.token,
                cacheURLs: cacheURLs,
                referenceURL: preferredPageReferenceURL(imageURL: imageURL),
                imageURL: imageURL
            )
            guard let pageResult = try await restorePageFromCache(
                index: page,
                source: cacheSource,
                folderURL: captureTarget.folderURL,
                preferredRelativePath:
                    captureTarget.preferredRelativePath ?? existingPages[page],
                overwriteExistingFile: true
            ) else { return }
            // Landed through the single point every landed page passes (G-15-35): the shared
            // flush records the hash, re-indexes, and advances the owning run's measurement, so a
            // capture during a live run is counted exactly as a page-loop landing is. A separate
            // single-page refresh here recorded the page while advancing nothing, which falsified
            // the flush's single-point premise for one route.
            try flushManifestPageProgress(
                folderURL: captureTarget.folderURL,
                pages: [pageResult]
            )
            await clearStaleDownloadErrorIfNeeded(gid: gid)
        } catch {
            logger.error("\(error, privacy: .private)")
        }
    }

    public func loadInspection(
        gid: String
    ) async -> Result<DownloadInspection, AppError> {
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }

        let activeFolderURL = activeInspectionFolderURL(for: download)

        // A display read may classify, never act (D-SSOT-07). `buildInspectionPages` itself writes
        // nothing, but the rendering resources it is handed used to be resolved by a probe that
        // DELETED the files it rejected, so merely opening the inspector could remove a zero-byte or
        // non-regular page file. Under the presence basis that deletion was self-consistent — the
        // page read `.pending` immediately after. Under the manifest basis the page goes on reading
        // `.downloaded` over a file this read destroyed, which is a record/disk divergence created
        // by looking, licensed by no reconciliation, and invisible until the user runs Validate.
        // Since CR-03 that is the default for every caller rather than this route's opt-out, so both
        // resolutions below read as written.
        let existingRelativePaths = activeFolderURL.map {
            storage.existingPageRelativePaths(
                folderURL: $0,
                manifest: download.manifest
            )
        } ?? [:]
        let failedPages = (failedPageErrors[gid] ?? [:])
            .filter({ !isCancellationLikeAppError($0.value.error) })

        let pages = buildInspectionPages(
            download: download,
            activeFolderURL: activeFolderURL,
            existingRelativePaths: existingRelativePaths,
            failedPages: failedPages
        )

        let coverURL = activeFolderURL.flatMap { folderURL in
            storage.existingCoverRelativePath(
                folderURL: folderURL,
                manifest: download.manifest
            )
            .map({ folderURL.appendingPathComponent($0) })
        } ?? download.coverURL

        return .success(
            .init(
                download: download,
                coverURL: coverURL,
                pages: pages
            )
        )
    }
}
