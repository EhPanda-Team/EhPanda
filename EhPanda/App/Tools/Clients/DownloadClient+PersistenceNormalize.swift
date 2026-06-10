//
//  DownloadClient+PersistenceNormalize.swift
//  EhPanda
//

import Foundation

// MARK: - Manifest, Folder & Normalize
extension DownloadManager {
    func validatedManifest(
        at folderURL: URL,
        gid: String,
        pageCount: Int
    ) -> DownloadManifest? {
        guard let manifest = try? storage
                .readManifest(folderURL: folderURL),
              manifest.gid == gid,
              manifest.pageCount == pageCount
        else {
            return nil
        }
        return manifest
    }

    func activeInspectionFolderURL(
        for download: DownloadedGallery
    ) -> URL? {
        let completedFolderURL = download.folderURL
        let completedFolderExists = fileManager.operate {
            $0.fileExists(atPath: completedFolderURL.path)
        }
        return completedFolderExists ? completedFolderURL : nil
    }

    func normalizeNeedsAttentionDownloads(
        _ downloads: [DownloadedGallery]
    ) async {
        for download in downloads {
            let shouldClearCancellationError =
                download.lastError.map {
                    isCancellationLikeAppError($0.appError)
                } ?? false
            guard download.displayStatus == .error
                    || shouldClearCancellationError else {
                continue
            }
            if shouldClearCancellationError {
                downloadErrors[download.gid] = nil
            }
        }
    }

    func normalizeInterruptedDownloads(
        _ downloads: [DownloadedGallery]
    ) async {
        let hasActiveTask = activeTask != nil
        let activeGalleryID = activeGalleryID
        for download in downloads where
        download.needsInterruptedDownloadNormalization(
            activeGalleryID: activeGalleryID,
            hasActiveTask: hasActiveTask
        ) {
            if activeGalleryID == download.gid, !hasActiveTask {
                self.activeGalleryID = nil
            }
        }
    }

    func reconcileActiveDownloadState() async {
        guard activeTask != nil,
              let activeGalleryID,
              await fetchDownload(gid: activeGalleryID) != nil
        else { return }

        downloadErrors[activeGalleryID] = nil
    }

    func validateDownloads() async {
        let downloads = await fetchDownloadsFromStore()
        for download in downloads where download.canValidateImageData {
            _ = await validateDownload(download)
        }
    }

    func validateImageData(gid: String) async -> DownloadValidationState? {
        guard let download = await fetchDownload(gid: gid),
              download.canValidateImageData
        else { return nil }
        let validation = await validateDownload(download)
        await notifyObservers()
        return validation
    }

    private func validateDownload(_ download: DownloadedGallery) async -> DownloadValidationState {
        let validation = storage.validate(download: download)
        switch validation {
        case .valid:
            validationErrors[download.gid] = nil

        case .missingFiles(let message):
            let failure = DownloadFailure(
                code: .fileOperationFailed,
                message: message
            )
            validationErrors[download.gid] = failure
        }
        return validation
    }
}
