//
//  DownloadClient+Folders.swift
//  EhPanda
//

import Foundation

// MARK: - User Folder Operations
extension DownloadCoordinator {
    func fetchFolders() async -> [String] {
        return userFolders
    }

    func createFolder(name: String) async -> Result<Void, AppError> {
        guard let normalizedName = storage.normalizedUserFolderName(name) else {
            return .failure(
                .fileOperationFailed(
                    L10n.Localizable.DownloadStore.Error.invalidFolderName
                )
            )
        }
        let folderURL = storage.userFolderURL(name: normalizedName)
        guard !fileManager.operate({ $0.fileExists(atPath: folderURL.path) }) else {
            return .failure(
                .fileOperationFailed(
                    L10n.Localizable.DownloadStore.Error.folderAlreadyExists
                )
            )
        }
        do {
            try storage.ensureRootDirectory()
            try createDirectory(at: folderURL)
        } catch {
            Logger.error(error)
            return .failure(.fileOperationFailed(error.localizedDescription))
        }
        insertUserFolder(normalizedName)
        return .success(())
    }

    func renameFolder(
        oldName: String,
        newName: String
    ) async -> Result<Void, AppError> {
        guard let normalizedName = storage.normalizedUserFolderName(newName) else {
            return .failure(
                .fileOperationFailed(
                    L10n.Localizable.DownloadStore.Error.invalidFolderName
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
                    L10n.Localizable.DownloadStore.Error.folderAlreadyExists
                )
            )
        }
        // The active task holds absolute paths inside the folder; renaming
        // underneath it would resurrect the old directory on the next write.
        if let activeGalleryID,
           downloadIndex[activeGalleryID]?.parentFolderName == oldName {
            return .failure(
                .fileOperationFailed(
                    L10n.Localizable.DownloadStore.Error.folderBusyDownloading
                )
            )
        }
        do {
            try fileManager.operate {
                try $0.moveItem(at: sourceURL, to: destinationURL)
            }
        } catch {
            Logger.error(error)
            await reloadDownloadRecordIfPossible(gidInFolder: oldName)
            return .failure(.fileOperationFailed(error.localizedDescription))
        }
        renameUserFolder(oldName: oldName, newName: normalizedName)
        await notifyObservers()
        return .success(())
    }

    func deleteFolder(name: String) async -> Result<Void, AppError> {
        let folderURL = storage.userFolderURL(name: name)
        guard fileManager.operate({ $0.fileExists(atPath: folderURL.path) }) else {
            return .failure(.notFound)
        }
        let containedRecords = downloadIndex.values
            .filter { $0.parentFolderName == name }
        let containedGIDs = containedRecords.map(\.manifest.gid)
        for gid in containedGIDs {
            schedulingBlockedGalleryIDs.insert(gid)
        }
        defer {
            for gid in containedGIDs {
                schedulingBlockedGalleryIDs.remove(gid)
            }
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
            return .failure(error)
        } catch {
            Logger.error(error)
            await reloadDownloadRecords(containedRecords)
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
        }
        userFolders.removeAll { $0 == name }
        await notifyObservers()
        await scheduleNextIfNeeded()
        return .success(())
    }

    func moveDownload(
        gid: String,
        toFolderName folderName: String
    ) async -> Result<Void, AppError> {
        guard let normalizedName = storage.normalizedUserFolderName(folderName) else {
            return .failure(
                .fileOperationFailed(
                    L10n.Localizable.DownloadStore.Error.invalidFolderName
                )
            )
        }
        schedulingBlockedGalleryIDs.insert(gid)
        defer {
            schedulingBlockedGalleryIDs.remove(gid)
        }
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }
        guard activeGalleryID != gid else {
            return .failure(
                .fileOperationFailed(
                    L10n.Localizable.DownloadStore.Error.downloadBusy
                )
            )
        }
        let destinationParentURL = storage.userFolderURL(name: normalizedName)
        let destinationURL = destinationParentURL.appendingPathComponent(
            download.folderURL.lastPathComponent,
            isDirectory: true
        )
        guard destinationURL.standardizedFileURL != download.folderURL.standardizedFileURL else {
            return .success(())
        }
        guard !fileManager.operate({ $0.fileExists(atPath: destinationURL.path) }) else {
            return .failure(
                .fileOperationFailed(
                    L10n.Localizable.DownloadStore.Error.folderAlreadyExists
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
            Logger.error(error)
            await reloadDownloadRecord(gid: download.gid, token: download.token)
            return .failure(.fileOperationFailed(error.localizedDescription))
        }
        await reloadDownloadRecord(gid: download.gid, token: download.token)
        await notifyObservers()
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
        let movedRecords = downloadIndex.values.filter { $0.parentFolderName == oldName }
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
        let records = downloadIndex.values.filter { $0.parentFolderName == folderName }
        await reloadDownloadRecords(records)
    }

    private func reloadDownloadRecords(_ records: [DownloadFolderRecord]) async {
        for record in records {
            await reloadDownloadRecord(gid: record.manifest.gid, token: record.manifest.token)
        }
    }
}
