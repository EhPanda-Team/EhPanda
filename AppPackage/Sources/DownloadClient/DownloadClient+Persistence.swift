import AppModels
import AppTools
import Foundation
import OSLogExt

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

// MARK: - Disk Index
extension DownloadCoordinator {
    @discardableResult
    public func reloadDownloadIndex() async -> [DownloadedGallery] {
        do {
            let scanResult = try storage.scanDownloads()
            downloadIndex = deduplicatedDownloadIndex(from: scanResult.records)
            userFolders = scanResult.userFolders
            hasLoadedIndex = true
            return await downloads(from: scanResult.records)
        } catch {
            logger.error("\(error, privacy: .private)")
            downloadIndex = [:]
            userFolders = []
            hasLoadedIndex = true
            return []
        }
    }

    /// The filesystem is the durable source of truth, but this actor's index is the read authority
    /// between explicit sync points. Hot lookups must not walk download folders; app launch,
    /// foreground return, pull-to-refresh, and targeted surprise repair are the scan boundaries.
    public func indexedDownload(gid: String) async -> DownloadedGallery? {
        guard hasLoadedIndex else { return nil }
        guard let record = downloadIndex[gid] else { return nil }
        return downloadedGallery(from: record)
    }

    public func indexedDownloads() async -> [DownloadedGallery] {
        guard hasLoadedIndex else { return [] }
        return await downloads(from: Array(downloadIndex.values))
    }

    private func downloads(
        from records: [DownloadFolderRecord]
    ) async -> [DownloadedGallery] {
        return deduplicatedDownloadIndex(from: records).values
            .map {
                downloadedGallery(from: $0)
            }
            .sorted(by: sortDownloadsByDisplayStatus)
    }

    public func indexedDownloads(gids: [String]) async -> [DownloadedGallery] {
        guard hasLoadedIndex else { return [] }
        let gidSet = Set(gids)
        return await downloads(
            from: downloadIndex.values.filter({ gidSet.contains($0.manifest.gid) })
        )
    }

    private func deduplicatedDownloadIndex(
        from records: [DownloadFolderRecord]
    ) -> [String: DownloadFolderRecord] {
        records.reduce(into: [:]) { index, record in
            let gid = record.manifest.gid
            guard let currentRecord = index[gid] else {
                index[gid] = record
                return
            }
            if record.displayDate > currentRecord.displayDate {
                index[gid] = record
            }
        }
    }

    private func downloadedGallery(
        from record: DownloadFolderRecord
    ) -> DownloadedGallery {
        let gid = record.manifest.gid
        return DownloadedGallery(
            manifest: record.manifest,
            folderURL: record.folderURL,
            folderName: record.parentFolderName,
            localCoverURL: record.localCoverURL,
            localPageURLs: record.localPageURLs,
            modificationDate: record.modificationDate,
            displayStatus: displayStatus(for: record),
            lastError: validationErrors[gid] ?? downloadErrors[gid]
        )
    }

    private func displayStatus(
        for record: DownloadFolderRecord
    ) -> DownloadDisplayStatus {
        let gid = record.manifest.gid
        if validationErrors[gid] != nil {
            return .error
        }
        if activeGalleryID == gid {
            return .active
        }
        if queueStore.contains(gid) {
            return .queued
        }
        if record.manifest.isComplete,
           updatedGalleryIDs.contains(gid) {
            return .updateAvailable
        }
        if record.manifest.isComplete {
            return .completed
        }
        if downloadErrors[gid] != nil {
            return .error
        }
        return .inactive
    }

    private func sortDownloadsByDisplayStatus(
        _ lhs: DownloadedGallery,
        _ rhs: DownloadedGallery
    ) -> Bool {
        if lhs.displayStatus != rhs.displayStatus {
            return lhs.displayStatus.sortPriority < rhs.displayStatus.sortPriority
        }
        return (lhs.lastDownloadedDate ?? .distantPast)
            > (rhs.lastDownloadedDate ?? .distantPast)
    }
}

private extension DownloadFolderRecord {
    var displayDate: Date {
        modificationDate ?? .distantPast
    }
}

// MARK: - Store Operations
extension DownloadCoordinator {
    public func fetchDownload(
        gid: String
    ) async -> DownloadedGallery? {
        return await indexedDownload(gid: gid)
    }

    public func fetchDownloadsFromStore() async -> [DownloadedGallery] {
        return await reloadDownloadIndex()
    }

    @discardableResult
    public func reloadDownloadRecord(gid: String, token: String) async -> DownloadedGallery? {
        let records = storage.galleryFolderRecords(gid: gid, token: token)
        guard let record = deduplicatedDownloadIndex(from: records).values.first else {
            downloadIndex[gid] = nil
            return nil
        }
        downloadIndex[gid] = record
        if !userFolders.contains(record.parentFolderName) {
            userFolders.append(record.parentFolderName)
            userFolders.sort {
                $0.localizedStandardCompare($1) == .orderedAscending
            }
        }
        return await indexedDownload(gid: gid)
    }
}

// MARK: - Persist Failure & Progress
extension DownloadCoordinator {
    public func persistFailure(
        error: AppError,
        context: FailureContext
    ) async {
        await taskRunner.beforeFailurePersistence()
        await settleDownloadFailure(gid: context.gid, error: error)
    }

    /// Surfaces a download-level failure and clears its queue intent so it does not
    /// auto-resume. Shared by the foreground `persistFailure` and the background/orphan
    /// fatal-error paths so a fatal 509/auth/ban settles identically either way.
    public func settleDownloadFailure(gid: String, error: AppError) async {
        downloadErrors[gid] = DownloadFailure(error: error)
        clearDownloadQueueIntent(gid: gid)
        await queueStore.remove(gid)
    }

    /// Persists accumulated page progress, subject to the throttle, and reports it onwards.
    ///
    /// The continued-processing session's card is refreshed from here, not from the page loop
    /// that calls this, and not only from queue mutations. Three reasons, in ascending order of
    /// how much they matter:
    ///
    /// This routine is where the throttle decision is made, so one throttle governs both the
    /// manifest write and the card update, and the two can never drift onto different cadences.
    /// It also covers forced flushes as well as cadence flushes, which the page-loop site would
    /// miss. And it already runs on the coordinator, so session state is reachable without
    /// introducing a new suspension hazard.
    ///
    /// The reason the push exists at all is liveness, not decoration: the scheduler forcibly
    /// expires tasks that appear stalled, and prioritizes terminating the ones reporting the
    /// least progress. A session whose completed count only moved when a gallery finished would
    /// look stalled for the whole of a long gallery. Reporting on the page cadence is therefore
    /// a functional requirement of keeping the session alive, which is why it rides the flush
    /// rather than the queue mutation.
    public func flushDownloadProgress(
        context: ProgressFlushContext,
        pendingResolvedPages: inout [PageResult],
        lastFlushDate: inout Date,
        force: Bool
    ) async throws {
        let shouldFlush = force
            || pendingResolvedPages.count
            >= Self.progressFlushPageInterval
            || now().timeIntervalSince(lastFlushDate)
            >= Self.progressFlushMinimumInterval
        guard shouldFlush else { return }

        let resolvedPages = pendingResolvedPages
        try flushManifestPageProgress(
            folderURL: context.folderURL,
            pages: resolvedPages
        )
        pendingResolvedPages
            .removeAll(keepingCapacity: true)
        lastFlushDate = now()
        await notifyObservers()
        if let continuedSessionID {
            await pushContinuedSessionProgress(sessionID: continuedSessionID)
        }
    }

    /// Records the hashes of pages that have landed on disk, and shrinks the owning run's
    /// outstanding pages by exactly the pages this write recorded.
    ///
    /// **Why the landing lives HERE rather than in `flushDownloadProgress` (G-15-30).** The
    /// numerator climbing page by page is the liveness the push exists to report — the scheduler
    /// force-expires the tasks reporting the least progress — so the measurement has to advance
    /// wherever a page the run owed becomes recorded, not merely on the route the page loop happens
    /// to take. This is the single point every landed page passes: the cadence and forced flushes
    /// reach it through `flushDownloadProgress`, the restored pages of
    /// `initializePageDownloadState` reach it directly, a background page landing — which completes
    /// out of process and never touches the page loop's throttle — reaches it directly too, and
    /// `performCacheCapture` lands its restored page through it as well. That last route used to
    /// write its hash through a separate single-page refresh, recording the page while advancing no
    /// measurement — exactly the drift a "single point" claim exists to forbid (G-15-35).
    ///
    /// **Why it credits nothing when nothing was written.** Both early returns above it decline to
    /// write — an empty page list, and a folder whose manifest file is gone — and neither reaches
    /// this line. A throw from the hash refresh does not reach it either, which is the same
    /// condition that keeps `flushDownloadProgress` from clearing its pending resolved pages: the
    /// two cannot drift, because the write they both depend on is one call and this whole body is
    /// synchronous, so nothing can interleave between the record moving and the measurement
    /// following it.
    ///
    /// **Why a set subtraction rather than a count.** A page can arrive twice — a retry re-records a
    /// hash an earlier flush already wrote — and a flush can carry pages this run never owed, since
    /// the restored pages are by construction the complement of the run's pending list. Subtracting
    /// the page numbers is idempotent on the first and inert on the second; subtracting a count
    /// over-credits on both, and over-crediting is the direction D-G2-01 names as the defect.
    ///
    /// The in-flight sub-page entries of the recorded pages are removed in this same synchronous
    /// stretch, so whole-page and sub-page credit trade places atomically and no push can land
    /// between a page landing and its flush at a lower value.
    public func flushManifestPageProgress(
        folderURL: URL,
        pages: [PageResult]
    ) throws {
        guard !pages.isEmpty else { return }
        let manifestURL = folderURL
            .appendingPathComponent(Defaults.FilePath.downloadManifest)
        guard fileManager.operate({
            $0.fileExists(atPath: manifestURL.path)
        }) else {
            return
        }
        let pageRelativePaths = pages.reduce(into: [Int: String]()) { result, page in
            result[page.index] = page.relativePath
        }
        let manifest = try storage.refreshManifestPageFileHashes(
            folderURL: folderURL,
            pageRelativePaths: pageRelativePaths
        )
        updateDownloadIndex(folderURL: folderURL, manifest: manifest)
        runProgressBases[manifest.gid]?.outstandingPages.subtract(pageRelativePaths.keys)
        retireInFlightPageCredits(gid: manifest.gid, pages: pageRelativePaths.keys)
    }

    public func updateDownloadIndex(folderURL: URL, manifest: DownloadManifest) {
        downloadIndex[manifest.gid] = storage.galleryFolderRecord(
            folderURL: folderURL,
            manifest: manifest,
            parentFolderName: storage.parentFolderName(forFolderURL: folderURL) ?? ""
        )
    }
}
