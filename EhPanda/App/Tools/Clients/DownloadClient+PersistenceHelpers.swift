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
        let folderURL = download
            .resolvedFolderURL(rootURL: storage.rootURL)
        guard fileManager.operate({ $0.fileExists(atPath: folderURL.path) })
        else {
            return 0
        }

        guard let manifest = try? storage
                .readManifest(folderURL: folderURL) else {
            return storage.existingPageRelativePaths(
                folderURL: folderURL,
                expectedPageCount: download.pageCount
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
        let completedFolderURL = download
            .resolvedFolderURL(rootURL: storage.rootURL)
        guard fileManager.operate({
            $0.fileExists(atPath: completedFolderURL.path)
        }) else { return }
        _ = storage.existingPageRelativePaths(
            folderURL: completedFolderURL,
            expectedPageCount: download.pageCount
        )
        _ = storage.existingCoverRelativePath(
            folderURL: completedFolderURL
        )
    }

    private struct SanitizeUpdateResult {
        let needsUpdate: Bool
        let status: DownloadStatus
        let completedPageCount: Int
        let lastError: DownloadFailure?
    }

    private struct MutableSanitizeState {
        var status: DownloadStatus
        var completedPageCount: Int
        var lastError: DownloadFailure?
        var needsUpdate: Bool
    }

    private func computeSanitizeUpdate(
        download: DownloadedGallery,
        clearingLastError: Bool
    ) -> SanitizeUpdateResult {
        var state = MutableSanitizeState(
            status: download.status,
            completedPageCount: download.completedPageCount,
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
            status: state.status,
            completedPageCount: state.completedPageCount,
            lastError: state.lastError
        )
    }

    private func applyCompletedStatusUpdate(
        download: DownloadedGallery,
        clearingLastError: Bool,
        state: inout MutableSanitizeState
    ) {
        if [.completed, .updateAvailable, .missingFiles]
            .contains(download.status) {
            let validation = storage
                .validate(download: download)
            let completedPageCount =
                validatedCompletedPageCount(download)
            switch validation {
            case .valid:
                let expectedStatus: DownloadStatus =
                    download.hasUpdate
                    ? .updateAvailable : .completed
                if state.status != expectedStatus {
                    state.status = expectedStatus
                    state.needsUpdate = true
                }
                if state.completedPageCount != completedPageCount {
                    state.completedPageCount = completedPageCount
                    state.needsUpdate = true
                }
                if clearingLastError || state.lastError != nil {
                    state.lastError = nil
                    state.needsUpdate = true
                }

            case .missingFiles(let message):
                if state.status != .missingFiles {
                    state.status = .missingFiles
                    state.needsUpdate = true
                }
                if state.completedPageCount != completedPageCount {
                    state.completedPageCount = completedPageCount
                    state.needsUpdate = true
                }
                let failure = DownloadFailure(
                    code: .fileOperationFailed,
                    message: message
                )
                if state.lastError != failure {
                    state.lastError = failure
                    state.needsUpdate = true
                }
            }
        } else if clearingLastError, state.lastError != nil {
            state.lastError = nil
            state.needsUpdate = true
        }
    }

    func captureTarget(
        for download: DownloadedGallery,
        index: Int
    ) -> CaptureTargetResult? {
        let completedFolderURL = download
            .resolvedFolderURL(rootURL: storage.rootURL)
        guard fileManager.operate({
            $0.fileExists(atPath: completedFolderURL.path)
        })
        else {
            return nil
        }

        let completedPages =
            storage.existingPageRelativePaths(
                folderURL: completedFolderURL,
                expectedPageCount: download.pageCount
            )
        return CaptureTargetResult(
            folderURL: completedFolderURL,
            preferredRelativePath: completedPages[index]
        )
    }
}
