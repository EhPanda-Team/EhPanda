import Foundation

// MARK: - Sanitization
extension DownloadCoordinator {
    @discardableResult
    func sanitizeLocalFilesIfNeeded(
        gid: String,
        clearingLastError: Bool = false
    ) async -> DownloadedGallery? {
        guard let download = await fetchDownload(gid: gid)
        else { return nil }

        scanCompletedFolder(download: download)

        guard clearingLastError, download.lastError != nil else {
            return download
        }

        downloadErrors[gid] = nil
        validationErrors[gid] = nil
        await notifyObservers()

        return await fetchDownload(gid: gid)
    }

    private func scanCompletedFolder(download: DownloadedGallery) {
        let completedFolderURL = download.folderURL
        guard fileManager.operate({
            $0.fileExists(atPath: completedFolderURL.path)
        }) else { return }
        _ = storage.existingPageRelativePaths(
            folderURL: completedFolderURL,
            manifest: download.manifest
        )
        _ = storage.existingCoverRelativePath(
            folderURL: completedFolderURL,
            manifest: download.manifest
        )
    }

    func captureTarget(
        for download: DownloadedGallery,
        index: Int
    ) -> CaptureTargetResult? {
        let completedFolderURL = download.folderURL
        guard fileManager.operate({
            $0.fileExists(atPath: completedFolderURL.path)
        })
        else {
            return nil
        }

        let completedPages =
            storage.existingPageRelativePaths(
                folderURL: completedFolderURL,
                manifest: download.manifest
            )
        return CaptureTargetResult(
            folderURL: completedFolderURL,
            preferredRelativePath: completedPages[index]
        )
    }
}
