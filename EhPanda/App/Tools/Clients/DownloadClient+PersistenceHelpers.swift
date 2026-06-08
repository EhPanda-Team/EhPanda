//
//  DownloadClient+PersistenceHelpers.swift
//  EhPanda
//

import CoreData
import Foundation

// MARK: - Validation & Sanitization
extension DownloadManager {
    func temporaryCompletedPageCount(
        gid: String,
        expectedPageCount: Int
    ) -> Int {
        let folderURL = storage.temporaryFolderURL(gid: gid)
        guard fileManager.operate({ $0.fileExists(atPath: folderURL.path) }) else {
            return 0
        }
        return storage.existingPageRelativePaths(
            folderURL: folderURL,
            expectedPageCount: expectedPageCount
        )
        .count
    }

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

        let (hasTemporaryFolder, temporaryCompletedCount) =
            scanTemporaryFolder(gid: gid, download: download)
        scanCompletedFolder(download: download)

        let updateResult = computeSanitizeUpdate(
            download: download,
            hasTemporaryFolder: hasTemporaryFolder,
            temporaryCompletedCount: temporaryCompletedCount,
            clearingLastError: clearingLastError
        )

        guard updateResult.needsUpdate else { return download }

        do {
            try await updateDownloadRecord(
                gid: gid,
                createIfMissing: false
            ) { record in
                record.status = updateResult.status.rawValue
                record.completedPageCount =
                    Int64(updateResult.completedPageCount)
                record.lastError =
                    updateResult.lastError?.toData()
            }
            await notifyObservers()
        } catch {
            Logger.error(error)
        }

        return await fetchDownload(gid: gid)
    }

    private func scanTemporaryFolder(
        gid: String,
        download: DownloadedGallery
    ) -> (hasTemporaryFolder: Bool, temporaryCompletedCount: Int) {
        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        let hasTemporaryFolder = fileManager.operate {
            $0.fileExists(atPath: temporaryFolderURL.path)
        }
        let temporaryCompletedCount = hasTemporaryFolder
            ? storage.existingPageRelativePaths(
                folderURL: temporaryFolderURL,
                expectedPageCount: download.pageCount
            ).count
            : 0
        if hasTemporaryFolder {
            _ = storage.existingCoverRelativePath(
                folderURL: temporaryFolderURL
            )
        }
        return (hasTemporaryFolder, temporaryCompletedCount)
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
        hasTemporaryFolder: Bool,
        temporaryCompletedCount: Int,
        clearingLastError: Bool
    ) -> SanitizeUpdateResult {
        var state = MutableSanitizeState(
            status: download.status,
            completedPageCount: download.completedPageCount,
            lastError: download.lastError,
            needsUpdate: false
        )
        applyTemporaryFolderUpdate(
            download: download,
            hasTemporaryFolder: hasTemporaryFolder,
            temporaryCompletedCount: temporaryCompletedCount,
            state: &state
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

    private func applyTemporaryFolderUpdate(
        download: DownloadedGallery,
        hasTemporaryFolder: Bool,
        temporaryCompletedCount: Int,
        state: inout MutableSanitizeState
    ) {
        guard hasTemporaryFolder,
              shouldExposeTemporaryWorkingSet(for: download)
        else { return }

        if state.completedPageCount != temporaryCompletedCount {
            state.completedPageCount = temporaryCompletedCount
            state.needsUpdate = true
        }
        if download.status == .failed {
            state.status = .partial
            state.needsUpdate = true
        }
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
        let temporaryFolderURL = storage
            .temporaryFolderURL(gid: download.gid)
        if shouldExposeTemporaryWorkingSet(for: download),
           fileManager.operate({
               $0.fileExists(atPath: temporaryFolderURL.path)
           }) {
            let temporaryPages =
                storage.existingPageRelativePaths(
                    folderURL: temporaryFolderURL,
                    expectedPageCount: download.pageCount
                )
            let manifestRelativePath = (try? storage
                                            .readManifest(
                                                folderURL: temporaryFolderURL
                                            ))?
                .pages
                .first(where: { $0.index == index })?
                .relativePath
            let preferredRelativePath = temporaryPages[index]
                ?? manifestRelativePath
            return CaptureTargetResult(
                folderURL: temporaryFolderURL,
                preferredRelativePath: preferredRelativePath,
                isTemporary: true
            )
        }

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
        let manifestRelativePath = (try? storage
                                        .readManifest(folderURL: completedFolderURL))?
            .pages
            .first(where: { $0.index == index })?
            .relativePath
        let preferredRelativePath = completedPages[index]
            ?? manifestRelativePath
        return CaptureTargetResult(
            folderURL: completedFolderURL,
            preferredRelativePath: preferredRelativePath,
            isTemporary: false
        )
    }
}
