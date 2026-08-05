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

    public func createFolder(name: String) async -> Result<Void, AppError> {
        guard let normalizedName = storage.normalizedUserFolderName(name) else {
            return .failure(
                .fileOperationFailed(
                    String(localized: .RLocalizable.downloadStoreInvalidFolderName)
                )
            )
        }
        let folderURL = storage.userFolderURL(name: normalizedName)
        guard !fileManager.operate({ $0.fileExists(atPath: folderURL.path) }) else {
            return .failure(
                .fileOperationFailed(
                    String(localized: .downloadStoreFolderAlreadyExists)
                )
            )
        }
        do {
            try storage.ensureRootDirectory()
            try createDirectory(at: folderURL)
        } catch {
            logger.error("\(error, privacy: .private)")
            return .failure(.fileOperationFailed(error.localizedDescription))
        }
        insertUserFolder(normalizedName)
        return .success(())
    }

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
        let sourceURL = storage.userFolderURL(name: oldName)
        let destinationURL = storage.userFolderURL(name: normalizedName)
        guard sourceURL.standardizedFileURL != destinationURL.standardizedFileURL else {
            return .success(())
        }
        guard fileManager.operate({ $0.fileExists(atPath: sourceURL.path) }) else {
            return .failure(.notFound)
        }
        guard !fileManager.operate({ $0.fileExists(atPath: destinationURL.path) }) else {
            return .failure(
                .fileOperationFailed(
                    String(localized: .downloadStoreFolderAlreadyExists)
                )
            )
        }
        // The active task holds absolute paths inside the folder; renaming
        // underneath it would resurrect the old directory on the next write.
        if let activeGalleryID,
           downloadIndex[activeGalleryID]?.parentFolderName == oldName {
            return .failure(
                .fileOperationFailed(
                    String(localized: .downloadStoreFolderBusyDownloading)
                )
            )
        }
        do {
            try fileManager.operate {
                try $0.moveItem(at: sourceURL, to: destinationURL)
            }
        } catch {
            logger.error("\(error, privacy: .private)")
            await reloadDownloadRecordIfPossible(gidInFolder: oldName)
            return .failure(.fileOperationFailed(error.localizedDescription))
        }
        renameUserFolder(oldName: oldName, newName: normalizedName)
        await notifyObservers()
        return .success(())
    }

    public func deleteFolder(name: String) async -> Result<Void, AppError> {
        let folderURL = storage.userFolderURL(name: name)
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
            try storage.removeFolder(at: folderURL)
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
    /// The invalid-name guard precedes the block and therefore needs neither.
    public func moveDownload(
        gid: String,
        toFolderName folderName: String
    ) async -> Result<Void, AppError> {
        guard let normalizedName = storage.normalizedUserFolderName(folderName) else {
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
                    String(localized: .downloadStoreDownloadBusy)
                )
            )
        }
        let destinationParentURL = storage.userFolderURL(name: normalizedName)
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
                    String(localized: .downloadStoreFolderAlreadyExists)
                )
            )
        }
        do {
            // Recreate the destination folder if it vanished via the Files app.
            try createDirectory(at: destinationParentURL)
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

    private func renameUserFolder(oldName: String, newName: String) {
        userFolders.removeAll { $0 == oldName }
        insertUserFolder(newName)
        let movedRecords = downloadIndex.values.filter({ $0.parentFolderName == oldName })
        for record in movedRecords {
            let destinationFolderURL = storage.userFolderURL(name: newName)
                .appendingPathComponent(record.folderURL.lastPathComponent, isDirectory: true)
            downloadIndex[record.manifest.gid] = DownloadFolderRecord(
                relativePath: "\(newName)/\(record.folderURL.lastPathComponent)",
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
