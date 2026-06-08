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
        pageCount: Int,
        downloadOptions: DownloadOptionsSnapshot
    ) -> DownloadManifest? {
        guard let manifest = try? storage
                .readManifest(folderURL: folderURL),
              manifest.gid == gid,
              manifest.pageCount == pageCount,
              manifest.pages.count == pageCount,
              manifest.downloadOptions == downloadOptions
        else {
            return nil
        }
        return manifest
    }

    func activeInspectionFolderURL(
        for download: DownloadedGallery
    ) -> URL? {
        let temporaryFolderURL = storage
            .temporaryFolderURL(gid: download.gid)
        let completedFolderURL = download
            .resolvedFolderURL(rootURL: storage.rootURL)
        let temporaryFolderExists = fileManager.operate {
            $0.fileExists(atPath: temporaryFolderURL.path)
        }
        let completedFolderExists = fileManager.operate {
            $0.fileExists(atPath: completedFolderURL.path)
        }

        if shouldExposeTemporaryWorkingSet(for: download) {
            return temporaryFolderExists
                ? temporaryFolderURL
                : completedFolderURL
        }
        if completedFolderExists {
            return completedFolderURL
        }
        if temporaryFolderExists {
            return temporaryFolderURL
        }
        return nil
    }

    func sanitizedFailedPages(
        folderURL: URL
    ) -> [Int: DownloadFailedPagesSnapshot.Page] {
        guard var snapshot = try? storage
                .readFailedPages(folderURL: folderURL) else {
            return [:]
        }
        let filteredPages = snapshot.pages.filter {
            !isCancellationLikeAppError($0.failure.appError)
        }
        guard filteredPages.count != snapshot.pages.count
        else {
            return snapshot.map
        }

        snapshot.pages = filteredPages
        if filteredPages.isEmpty {
            try? storage.removeFailedPages(
                folderURL: folderURL
            )
        } else {
            try? storage.writeFailedPages(
                snapshot,
                folderURL: folderURL
            )
        }
        return snapshot.map
    }

    func normalizeNeedsAttentionDownloads(
        _ downloads: [DownloadedGallery]
    ) async {
        for download in downloads {
            let shouldClearCancellationError =
                download.lastError.map {
                    isCancellationLikeAppError($0.appError)
                } ?? false
            guard download.status == .failed
                    || shouldClearCancellationError else {
                continue
            }
            if downloadIndex[download.gid] != nil {
                if shouldClearCancellationError {
                    downloadErrors[download.gid] = nil
                }
                continue
            }

            let normalizedCompletedPageCount = max(
                download.completedPageCount,
                temporaryCompletedPageCount(
                    gid: download.gid,
                    expectedPageCount:
                        max(download.pageCount, 1)
                )
            )
            do {
                try await updateDownloadRecord(
                    gid: download.gid,
                    createIfMissing: false
                ) { record in
                    if download.status == .failed {
                        record.status =
                            DownloadStatus.partial.rawValue
                        record.completedPageCount = Int64(
                            normalizedCompletedPageCount
                        )
                    }
                    if shouldClearCancellationError {
                        record.lastError = nil
                    }
                }
            } catch {
                Logger.error(error)
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
            if downloadIndex[download.gid] != nil {
                if activeGalleryID == download.gid, !hasActiveTask {
                    self.activeGalleryID = nil
                }
                continue
            }
            do {
                try await updateDownloadRecord(
                    gid: download.gid,
                    createIfMissing: false
                ) { record in
                    record.status =
                        DownloadStatus.paused.rawValue
                }
            } catch {
                Logger.error(error)
            }
        }
    }

    func reconcileActiveDownloadState() async {
        guard activeTask != nil,
              let activeGalleryID,
              let activeDownload = await fetchDownload(
                gid: activeGalleryID
              ),
              activeDownload.status != .downloading
        else { return }

        do {
            try await updateDownloadRecord(
                gid: activeGalleryID,
                createIfMissing: false
            ) { record in
                record.status =
                    DownloadStatus.downloading.rawValue
                record.lastError = nil
            }
        } catch {
            Logger.error(error)
        }
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
        let isIndexedDownload = downloadIndex[download.gid] != nil
        switch validation {
        case .valid:
            refreshMissingManifestHashesIfNeeded(download: download)
            if isIndexedDownload {
                validationErrors[download.gid] = nil
                return validation
            }
            let expectedStatus: DownloadStatus =
                download.hasUpdate
                ? .updateAvailable : .completed
            guard download.status != expectedStatus
            else { return validation }
            do {
                try await updateDownloadRecord(
                    gid: download.gid,
                    createIfMissing: false
                ) { record in
                    record.status = expectedStatus.rawValue
                }
            } catch {
                Logger.error(error)
            }

        case .missingFiles(let message):
            let failure = DownloadFailure(
                code: .fileOperationFailed,
                message: message
            )
            if isIndexedDownload {
                validationErrors[download.gid] = failure
                return validation
            }
            do {
                try await updateDownloadRecord(
                    gid: download.gid,
                    createIfMissing: false
                ) { record in
                    record.status = DownloadStatus.missingFiles.rawValue
                    record.lastError = failure.toData()
                }
            } catch {
                Logger.error(error)
            }
        }
        return validation
    }

    private func refreshMissingManifestHashesIfNeeded(
        download: DownloadedGallery
    ) {
        let folderURL = download
            .resolvedFolderURL(rootURL: storage.rootURL)
        guard let manifest = try? storage.readManifest(folderURL: folderURL),
              manifest.needsFileHashRefresh
        else {
            return
        }

        do {
            try storage.refreshManifestFileHashes(folderURL: folderURL)
        } catch {
            Logger.error(error)
        }
    }
}

private extension DownloadManifest {
    var needsFileHashRefresh: Bool {
        let needsCoverHash = coverRelativePath?.nonEmpty != nil
            && coverFileHash == nil
        return needsCoverHash || pages.contains { $0.fileHash == nil }
    }
}
