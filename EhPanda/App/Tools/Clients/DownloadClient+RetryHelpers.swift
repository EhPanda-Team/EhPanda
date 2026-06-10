//
//  DownloadClient+RetryHelpers.swift
//  EhPanda
//

import Foundation

// MARK: - Retry & RetryPages
extension DownloadManager {
    func retry(
        gid: String,
        mode: DownloadStartMode
    ) async -> Result<Void, AppError> {
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }
        do {
            try await performRetry(gid: gid, download: download, mode: mode)
            return .success(())
        } catch let error as AppError {
            return .failure(error)
        } catch {
            Logger.error(error)
            return .failure(.unknown)
        }
    }

    private func performRetry(
        gid: String,
        download: DownloadedGallery,
        mode: DownloadStartMode
    ) async throws {
        let resolvedMode = effectiveRetryMode(
            for: download, requestedMode: mode
        )
        clearDownloadSessionState(gid: gid)
        queuedModes[gid] = resolvedMode
        queuedPageSelections[gid] = nil
        await queueStore.enqueue(gid)
        await notifyObservers()
        await scheduleNextIfNeeded()
    }

    func retryPages(
        gid: String,
        pageIndices: [Int]
    ) async -> Result<Void, AppError> {
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }
        let mode = resumeMode(for: download)
        if mode == .update { return await retry(gid: gid, mode: .update) }

        let selectedPageIndices = Array(Set(pageIndices)).sorted()
        guard !selectedPageIndices.isEmpty else { return .success(()) }

        let folderURL = download.folderURL
        guard fileManager.operate({ $0.fileExists(atPath: folderURL.path) }) else {
            return .failure(.notFound)
        }
        do {
            try await performRetryPages(
                gid: gid,
                download: download,
                mode: .repair,
                selectedPageIndices: selectedPageIndices,
                folderURL: folderURL
            )
            return .success(())
        } catch let error as AppError {
            return .failure(error)
        } catch {
            Logger.error(error)
            return .failure(.unknown)
        }
    }

    private func performRetryPages(
        gid: String,
        download: DownloadedGallery,
        mode: DownloadStartMode,
        selectedPageIndices: [Int],
        folderURL: URL
    ) async throws {
        clearSelectedFailedPages(gid: gid, selectedPageIndices: selectedPageIndices)
        clearDownloadFailureState(gid: gid, includePageFailures: false)
        queuedModes[gid] = mode
        queuedPageSelections[gid] = selectedPageIndices
        await queueStore.enqueue(gid)
        await notifyObservers()
        await scheduleNextIfNeeded()
    }

    func loadLocalPageURLs(
        gid: String
    ) async -> Result<[Int: URL], AppError> {
        let sanitizedDownload = await sanitizeLocalFilesIfNeeded(gid: gid)
        let resolvedDownload: DownloadedGallery?
        if let sanitizedDownload {
            resolvedDownload = sanitizedDownload
        } else {
            resolvedDownload = await fetchDownload(gid: gid)
        }
        guard let download = resolvedDownload else {
            return .failure(.notFound)
        }

        let completedFolderURL = download.folderURL
        let completedValidation = storage.validate(download: download)

        let completedPageURLs = buildCompletedPageURLs(
            completedFolderURL: completedFolderURL,
            download: download
        )

        return resolveLocalPageURLs(
            completedValidation: completedValidation,
            completedFolderURL: completedFolderURL,
            completedPageURLs: completedPageURLs
        )
    }
}
