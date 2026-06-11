//
//  DownloadClient+Folders.swift
//  EhPanda
//

import Foundation

// MARK: - User Folder Operations
extension DownloadManager {
    func fetchFolders() async -> [String] {
        _ = await reloadDownloadIndex()
        return userFolders
    }

    func createFolder(name: String) async -> Result<Void, AppError> {
        guard let normalizedName = storage.normalizedUserFolderName(name) else {
            return .failure(
                .fileOperationFailed(
                    L10n.Localizable.DownloadFileStorage.Error.invalidFolderName
                )
            )
        }
        let folderURL = storage.userFolderURL(name: normalizedName)
        guard !fileManager.operate({ $0.fileExists(atPath: folderURL.path) }) else {
            return .failure(
                .fileOperationFailed(
                    L10n.Localizable.DownloadFileStorage.Error.folderAlreadyExists
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
        _ = await reloadDownloadIndex()
        return .success(())
    }

    func renameFolder(
        oldName: String,
        newName: String
    ) async -> Result<Void, AppError> {
        guard let normalizedName = storage.normalizedUserFolderName(newName) else {
            return .failure(
                .fileOperationFailed(
                    L10n.Localizable.DownloadFileStorage.Error.invalidFolderName
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
                    L10n.Localizable.DownloadFileStorage.Error.folderAlreadyExists
                )
            )
        }
        // The active task holds absolute paths inside the folder; renaming
        // underneath it would resurrect the old directory on the next write.
        if let activeGalleryID,
           downloadIndex[activeGalleryID]?.parentFolderName == oldName {
            return .failure(
                .fileOperationFailed(
                    L10n.Localizable.DownloadFileStorage.Error.folderBusyDownloading
                )
            )
        }
        do {
            try fileManager.operate {
                try $0.moveItem(at: sourceURL, to: destinationURL)
            }
        } catch {
            Logger.error(error)
            return .failure(.fileOperationFailed(error.localizedDescription))
        }
        _ = await reloadDownloadIndex()
        await notifyObservers()
        return .success(())
    }

    func deleteFolder(name: String) async -> Result<Void, AppError> {
        let folderURL = storage.userFolderURL(name: name)
        guard fileManager.operate({ $0.fileExists(atPath: folderURL.path) }) else {
            return .failure(.notFound)
        }
        let containedGIDs = downloadIndex.values
            .filter { $0.parentFolderName == name }
            .map(\.manifest.gid)
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
        for gid in containedGIDs {
            clearDownloadSessionState(gid: gid, includeUpdateFlag: true)
            await queueStore.remove(gid)
            downloadIndex[gid] = nil
        }
        do {
            try storage.removeFolder(at: folderURL)
        } catch let error as AppError {
            return .failure(error)
        } catch {
            Logger.error(error)
            return .failure(.fileOperationFailed(error.localizedDescription))
        }
        _ = await reloadDownloadIndex()
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
                    L10n.Localizable.DownloadFileStorage.Error.invalidFolderName
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
                    L10n.Localizable.DownloadFileStorage.Error.downloadBusy
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
                    L10n.Localizable.DownloadFileStorage.Error.folderAlreadyExists
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
            return .failure(.fileOperationFailed(error.localizedDescription))
        }
        _ = await reloadDownloadIndex()
        await notifyObservers()
        return .success(())
    }
}
