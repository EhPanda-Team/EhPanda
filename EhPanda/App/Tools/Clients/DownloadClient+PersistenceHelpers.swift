//
//  DownloadClient+PersistenceHelpers.swift
//  EhPanda
//

import Foundation

// MARK: - Validation & Sanitization
extension DownloadManager {
    func validatedCompletedPageCount(
        _ download: DownloadedGallery
    ) -> Int {
        let folderURL = download.folderURL
        guard fileManager.operate({ $0.fileExists(atPath: folderURL.path) })
        else {
            return 0
        }

        guard let manifest = try? storage
                .readManifest(folderURL: folderURL) else {
            return storage.existingPageRelativePaths(
                folderURL: folderURL,
                manifest: download.manifest
            )
            .count
        }

        return storage.validPageCount(
            folderURL: folderURL,
            manifest: manifest
        )
    }

    @discardableResult
    func sanitizeLocalFilesIfNeeded(
        gid: String,
        clearingLastError: Bool = false
    ) async -> DownloadedGallery? {
        guard let download = await fetchDownload(gid: gid)
        else { return nil }

        scanCompletedFolder(download: download)

        let updateResult = computeSanitizeUpdate(
            download: download,
            clearingLastError: clearingLastError
        )

        guard updateResult.needsUpdate else { return download }

        downloadErrors[gid] = updateResult.lastError
        if updateResult.lastError == nil {
            validationErrors[gid] = nil
        }
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
            folderURL: completedFolderURL
        )
    }

    private struct SanitizeUpdateResult {
        let needsUpdate: Bool
        let lastError: DownloadFailure?
    }

    private struct MutableSanitizeState {
        var lastError: DownloadFailure?
        var needsUpdate: Bool
    }

    private func computeSanitizeUpdate(
        download: DownloadedGallery,
        clearingLastError: Bool
    ) -> SanitizeUpdateResult {
        var state = MutableSanitizeState(
            lastError: download.lastError,
            needsUpdate: false
        )
        applyCompletedStatusUpdate(
            download: download,
            clearingLastError: clearingLastError,
            state: &state
        )
        return SanitizeUpdateResult(
            needsUpdate: state.needsUpdate,
            lastError: state.lastError
        )
    }

    private func applyCompletedStatusUpdate(
        download: DownloadedGallery,
        clearingLastError: Bool,
        state: inout MutableSanitizeState
    ) {
        if clearingLastError {
            if state.lastError != nil {
                state.lastError = nil
                state.needsUpdate = true
            }
            return
        }

        let shouldValidateFiles =
            [.completed, .updateAvailable].contains(download.displayStatus)
            || download.lastError?.code == .fileOperationFailed
        if shouldValidateFiles {
            let validation = storage
                .validate(download: download)
            switch validation {
            case .valid:
                if state.lastError != nil {
                    state.lastError = nil
                    state.needsUpdate = true
                }

            case .missingFiles(let message):
                let failure = DownloadFailure(
                    code: .fileOperationFailed,
                    message: message
                )
                if state.lastError != failure {
                    state.lastError = failure
                    state.needsUpdate = true
                }
            }
        }
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
