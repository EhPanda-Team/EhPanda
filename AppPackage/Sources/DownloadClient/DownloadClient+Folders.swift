import AppModels
import Foundation
import OSLogExt
import Resources

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

// MARK: - User Folder Operations
extension DownloadCoordinator {
    public func fetchFolders() async -> [String] {
        return userFolders
    }

    /// Orchestration only; the filesystem boundary belongs to `DownloadStore` (CR-02).
    ///
    /// The coordinator normalizes, because creating a folder is the one case where the caller is
    /// asking for a name to be MADE and rewriting it is the whole point. Everything after that —
    /// confinement, the already-exists refusal and the creation itself — belongs to the store,
    /// which decides all three inside the lock that creates. The URL construction this used to do
    /// here is the same one that let `deleteFolder` reach a gallery folder, so no coordinator site
    /// keeps it.
    public func createFolder(name: String) async -> Result<Void, AppError> {
        guard let normalizedName = storage.normalizedUserFolderName(name) else {
            return .failure(
                .fileOperationFailed(
                    String(localized: .RLocalizable.downloadStoreInvalidFolderName)
                )
            )
        }
        do {
            try storage.createUserFolder(named: normalizedName)
        } catch let error as AppError {
            return .failure(error)
        } catch {
            logger.error("\(error, privacy: .private)")
            return .failure(.fileOperationFailed(error.localizedDescription))
        }
        insertUserFolder(normalizedName)
        return .success(())
    }

    /// Orchestration only; the filesystem boundary belongs to `DownloadStore` (CR-03).
    ///
    /// The coordinator keeps what it alone knows — the busy-download guard, the post-failure
    /// reload, the index repoint and the observer notification — and hands the move itself to
    /// `storage.renameUserFolder`, which is the one place that decides whether `oldName` names a
    /// direct child of the download root at all. Constructing the source URL here, as this used to,
    /// put a caller-controlled name straight into `moveItem` with no confinement check between.
    ///
    /// One ordering changed with the move: existence and collision are now discovered at the
    /// mutation, so the busy guard runs ahead of them. Nothing observable turns on it — the guard
    /// keys on an indexed record's `parentFolderName`, which is always a real direct child, so it
    /// cannot fire for a name the store would have refused.
    public func renameFolder(
        oldName: String,
        newName: String
    ) async -> Result<Void, AppError> {
        guard let normalizedName = storage.normalizedUserFolderName(newName) else {
            return .failure(
                .fileOperationFailed(
                    String(localized: .RLocalizable.downloadStoreInvalidFolderName)
                )
            )
        }
        // Names rather than URLs, and no longer the same string on both sides of the comparison:
        // `oldName` is a raw on-disk name the listing produced, `normalizedName` is the minted one
        // (CR-01). Equality still means the requested move would land the folder exactly where it
        // already is, which is the only thing this exit claims — and for a source the app would
        // rewrite, the two simply never match, so such a folder is renamed rather than short
        // circuited.
        guard oldName != normalizedName else {
            return .success(())
        }
        // The active task holds absolute paths inside the folder; renaming
        // underneath it would resurrect the old directory on the next write.
        if let activeGalleryID,
           downloadIndex[activeGalleryID]?.parentFolderName == oldName {
            return .failure(
                .fileOperationFailed(
                    String(localized: .RLocalizable.downloadStoreFolderBusyDownloading)
                )
            )
        }
        do {
            try storage.renameUserFolder(oldName: oldName, newName: normalizedName)
        } catch let error as AppError {
            // A refusal moved nothing, so this reload re-reads records that never changed; it is
            // kept on every failing exit because only the store knows which of them mutated first.
            await reloadDownloadRecordIfPossible(gidInFolder: oldName)
            return .failure(error)
        } catch {
            logger.error("\(error, privacy: .private)")
            await reloadDownloadRecordIfPossible(gidInFolder: oldName)
            return .failure(.fileOperationFailed(error.localizedDescription))
        }
        repointRenamedUserFolder(oldName: oldName, newName: normalizedName)
        await notifyObservers()
        return .success(())
    }

    /// Orchestration only; the filesystem boundary belongs to `DownloadStore` (CR-02).
    ///
    /// `name` is public client input, so it is resolved through the store's confined direct-child
    /// boundary before anything happens and removed through the store operation that decides the
    /// same question again inside the lock that removes. What this used to do — append the raw
    /// name to the root and hand the result to `removeFolder(at:)`, whose containment is a lexical
    /// prefix — admitted every nested path, so `"MyFolder/[123_abc] Some Title"` recursively
    /// erased a gallery folder nobody named.
    ///
    /// **The existence pre-check is kept AHEAD of the store deliberately.** An absent folder has
    /// always answered `.notFound` without first blocking scheduling or cancelling an active task,
    /// and that stays true; it is a question about a name the boundary has already accepted, so it
    /// can no longer be answered about a path the caller did not name. The store answers
    /// `.notFound` too, for the folder that vanishes between here and the removal.
    ///
    /// **The cleanup key below is exact by construction now, not by luck.** Only a single confined
    /// component can be deleted, so the galleries this call removes are precisely those whose
    /// `parentFolderName` equals `name` — the set the loop clears. The nested name that used to
    /// erase a gallery folder while matching no record at all, leaving `downloadIndex`, the queue
    /// store and the background-task store claiming it, never reaches the removal.
    public func deleteFolder(name: String) async -> Result<Void, AppError> {
        guard let folderURL = storage.confinedDirectUserFolderURL(named: name) else {
            return .failure(
                .fileOperationFailed(
                    String(localized: .RLocalizable.downloadStoreInvalidFolderName)
                )
            )
        }
        guard fileManager.operate({ $0.fileExists(atPath: folderURL.path) }) else {
            return .failure(.notFound)
        }
        let containedRecords = downloadIndex.values
            .filter({ $0.parentFolderName == name })
        let containedGIDs = containedRecords.map(\.manifest.gid)
        for gid in containedGIDs {
            blockScheduling(gid: gid)
        }
        if let activeGalleryID,
           containedGIDs.contains(activeGalleryID) {
            let taskToCancel = activeTask
            activeTask?.cancel()
            activeTask = nil
            self.activeGalleryID = nil
            await taskToCancel?.value
        }
        do {
            try storage.deleteUserFolder(named: name)
        } catch let error as AppError {
            await reloadDownloadRecords(containedRecords)
            // ACTIVE-OWNERSHIP CONVERGENCE: release every contained gallery before converging or
            // the scheduler would silently skip it. Exactly one release per exit — the former
            // function-scoped `defer` sat behind these explicit removes, which a `Set` tolerated
            // and a reference count would not.
            for gid in containedGIDs {
                releaseScheduling(gid: gid)
            }
            await notifyObservers()
            await scheduleNextIfNeeded()
            return .failure(error)
        } catch {
            logger.error("\(error, privacy: .private)")
            await reloadDownloadRecords(containedRecords)
            for gid in containedGIDs {
                releaseScheduling(gid: gid)
            }
            await notifyObservers()
            await scheduleNextIfNeeded()
            return .failure(.fileOperationFailed(error.localizedDescription))
        }
        // Clear session and queue state only once the folder is gone; a failed
        // removal above leaves the galleries intact and must not silently
        // dequeue a download that lived inside the folder.
        for gid in containedGIDs {
            clearDownloadSessionState(gid: gid, includeUpdateFlag: true)
            await queueStore.remove(gid)
            await backgroundTaskStore.removeAll(for: gid)
            downloadIndex[gid] = nil
            releaseScheduling(gid: gid)
        }
        userFolders.removeAll { $0 == name }
        await notifyObservers()
        await scheduleNextIfNeeded()
        return .success(())
    }

    /// ACTIVE-OWNERSHIP CONVERGENCE, applied to the move (G-15-8).
    ///
    /// This is the sixth member of the family and the one the phase's convergence rounds never
    /// swept. It blocks its gid and then suspends three times — at `fetchDownload` and at both
    /// `reloadDownloadRecord` calls — and every exit below used to return with a function-scoped
    /// `defer` as its only release and no scheduling at all. Two failures came out of that, and
    /// both are closed here by releasing and then converging on every exit:
    ///
    /// - While the block is held the gid is invisible to `schedulableDownloads()`, so a completion
    ///   path's convergence landing in that window could read no pending work and end the
    ///   continued-processing session over a gallery that was merely hidden.
    /// - Even on success nothing rescheduled, so the moved gallery stayed queued and idle until an
    ///   unrelated mutation happened to converge. D-03 removed the fallback tier, so no tap short
    ///   of a fresh qualifying one could restart it.
    ///
    /// The invalid-name guard precedes the block and therefore needs neither. It now also resolves
    /// the destination parent, because that resolution answers the same question and refuses on
    /// the same terms (CR-02): the guard stays one exit, ahead of every side effect.
    public func moveDownload(
        gid: String,
        toFolderName folderName: String
    ) async -> Result<Void, AppError> {
        // `folderName` is a PICKED destination, not a minted one: the move menu offers only values
        // `fetchFolders()` produced, so it is admitted as written rather than rewritten (CR-01).
        // Rewriting it was a near-duplicate hazard in its own right — picking the listed
        // `"Art  Books"` normalized to `"Art Books"`, which the recreation below would then CREATE
        // beside it, moving the gallery into a second folder the user never made and leaving two
        // near-identical rows in the list.
        guard let destinationParentURL = storage.confinedDirectUserFolderURL(named: folderName)
        else {
            return .failure(
                .fileOperationFailed(
                    String(localized: .RLocalizable.downloadStoreInvalidFolderName)
                )
            )
        }
        // `ensureUserFolder` below MINTS, which is not the question the admission above answered,
        // and admission is deliberately the looser of the two: `".hidden"`, `"  "`, `"Misc etc."`
        // and a 400-byte name are all admitted verbatim and none of them is a name this app would
        // make. `.hidden` is the sharp one — `directoryURLs(in:)` enumerates with
        // `.skipsHiddenFiles`, so a gallery moved into one leaves `fetchFolders()`, leaves every
        // folder filter, and has its record dropped by the next index rebuild while its files stay
        // on disk. Before CR-01 the normalization that ran here happened to refuse all four; taking
        // it away left this site both the one that admits and the one that mints.
        //
        // So creation is licensed on its own terms, by either of the two things that make a folder
        // this app's to make: the listing already carries the name — which is what lets a
        // destination the user removed through the Files app be recreated VERBATIM, the property
        // CR-01 exists to protect — or the app would mint the name itself. A folder that is simply
        // already there mints nothing and needs neither.
        //
        // No in-app route reaches this exit: the move menu and the list dialog both offer values
        // `fetchFolders()` produced. But `moveDownload` is a public endpoint on `DownloadClient`,
        // and a comment asserting what its callers happen to pass is not a guard.
        guard fileManager.operate({ $0.fileExists(atPath: destinationParentURL.path) })
                || userFolders.contains(folderName)
                || storage.normalizedUserFolderName(folderName) == folderName
        else {
            return .failure(
                .fileOperationFailed(
                    String(localized: .RLocalizable.downloadStoreInvalidFolderName)
                )
            )
        }
        blockScheduling(gid: gid)
        guard let download = await fetchDownload(gid: gid) else {
            releaseScheduling(gid: gid)
            await notifyObservers()
            await scheduleNextIfNeeded()
            return .failure(.notFound)
        }
        guard activeGalleryID != gid else {
            releaseScheduling(gid: gid)
            await notifyObservers()
            await scheduleNextIfNeeded()
            return .failure(
                .fileOperationFailed(
                    String(localized: .RLocalizable.downloadStoreDownloadBusy)
                )
            )
        }
        let destinationURL = destinationParentURL.appendingPathComponent(
            download.folderURL.lastPathComponent,
            isDirectory: true
        )
        guard destinationURL.standardizedFileURL != download.folderURL.standardizedFileURL else {
            releaseScheduling(gid: gid)
            await notifyObservers()
            await scheduleNextIfNeeded()
            return .success(())
        }
        guard !fileManager.operate({ $0.fileExists(atPath: destinationURL.path) }) else {
            releaseScheduling(gid: gid)
            await notifyObservers()
            await scheduleNextIfNeeded()
            return .failure(
                .fileOperationFailed(
                    String(localized: .RLocalizable.downloadStoreFolderAlreadyExists)
                )
            )
        }
        do {
            // Recreate the destination folder if it vanished via the Files app — verbatim, and
            // through the store's confined creation, so the only URL this move can write under is
            // one the boundary produced and the folder that reappears is the one the user picked
            // rather than a rewritten neighbour of it. `destinationURL` is a child of that same
            // resolved parent. That this call is allowed to MINT at all is decided by the minting
            // guard above, not here.
            try storage.ensureUserFolder(named: folderName)
            try fileManager.operate {
                try $0.moveItem(at: download.folderURL, to: destinationURL)
            }
        } catch {
            logger.error("\(error, privacy: .private)")
            await reloadDownloadRecord(gid: download.gid, token: download.token)
            releaseScheduling(gid: gid)
            await notifyObservers()
            await scheduleNextIfNeeded()
            return .failure(.fileOperationFailed(error.localizedDescription))
        }
        await reloadDownloadRecord(gid: download.gid, token: download.token)
        releaseScheduling(gid: gid)
        await notifyObservers()
        await scheduleNextIfNeeded()
        return .success(())
    }

    private func insertUserFolder(_ name: String) {
        guard !userFolders.contains(name) else { return }
        userFolders.append(name)
        userFolders.sort {
            $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    /// Repoints the in-memory read model after the store has already moved the directory.
    ///
    /// Named apart from `storage.renameUserFolder` on purpose: that one owns the filesystem, this
    /// one owns the index, and the two sit on consecutive lines at the single call site.
    ///
    /// It is also the ONE surviving name-to-URL construction outside the store's confined boundary
    /// (CR-02), and it is not a mutation: it describes where the store has already put a folder.
    /// The record's path and its URL are derived from one `relativePath` value so they cannot
    /// describe two different places, which is what building them separately risked.
    private func repointRenamedUserFolder(oldName: String, newName: String) {
        userFolders.removeAll { $0 == oldName }
        insertUserFolder(newName)
        let movedRecords = downloadIndex.values.filter({ $0.parentFolderName == oldName })
        for record in movedRecords {
            let relativePath = "\(newName)/\(record.folderURL.lastPathComponent)"
            let destinationFolderURL = storage.folderURL(relativePath: relativePath)
            downloadIndex[record.manifest.gid] = DownloadFolderRecord(
                relativePath: relativePath,
                folderURL: destinationFolderURL,
                manifest: record.manifest,
                localCoverURL: record.localCoverURL.map {
                    destinationFolderURL.appendingPathComponent($0.lastPathComponent)
                },
                localPageURLs: record.localPageURLs.mapValues {
                    destinationFolderURL.appendingPathComponent($0.lastPathComponent)
                },
                modificationDate: record.modificationDate,
                parentFolderName: newName
            )
        }
    }

    private func reloadDownloadRecordIfPossible(gidInFolder folderName: String) async {
        let records = downloadIndex.values.filter({ $0.parentFolderName == folderName })
        await reloadDownloadRecords(records)
    }

    private func reloadDownloadRecords(_ records: [DownloadFolderRecord]) async {
        for record in records {
            await reloadDownloadRecord(gid: record.manifest.gid, token: record.manifest.token)
        }
    }
}
