//
//  DownloadClient+RetryHelpers.swift
//  EhPanda
//

import CoreData
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
        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        let existingResumeState = fileManager.operate {
            $0.fileExists(atPath: temporaryFolderURL.path)
        }
            ? (try? storage.readResumeState(folderURL: temporaryFolderURL))
            : nil
        let retryParams = computeRetryParams(
            download: download,
            resolvedMode: resolvedMode,
            existingResumeState: existingResumeState,
            gid: gid
        )
        if !retryParams.shouldResumeExistingWork {
            try? storage.removeTemporaryFolder(gid: gid)
        }
        if downloadIndex[gid] != nil {
            downloadErrors[gid] = nil
            validationErrors[gid] = nil
            await queueStore.enqueue(gid)
            if fileManager.operate({ $0.fileExists(atPath: temporaryFolderURL.path) }) {
                writeRetryResumeState(
                    download: download,
                    resolvedMode: resolvedMode,
                    existingResumeState: existingResumeState,
                    temporaryFolderURL: temporaryFolderURL
                )
            }
            await notifyObservers()
            await scheduleNextIfNeeded()
            return
        }
        try await updateDownloadRecord(
            gid: gid, createIfMissing: false
        ) { record in
            record.status = retryParams.resumedStatus.rawValue
            record.completedPageCount = Int64(retryParams.completedPageCount)
            record.lastDownloadedAt = .now
            record.lastError = nil
            record.pendingOperation = retryParams.pendingOperation?.rawValue
        }
        if fileManager.operate({ $0.fileExists(atPath: temporaryFolderURL.path) }) {
            writeRetryResumeState(
                download: download,
                resolvedMode: resolvedMode,
                existingResumeState: existingResumeState,
                temporaryFolderURL: temporaryFolderURL
            )
        }
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

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        guard fileManager.operate({ $0.fileExists(atPath: temporaryFolderURL.path) }) else {
            return .failure(.notFound)
        }
        do {
            try await performRetryPages(
                gid: gid,
                download: download,
                mode: mode,
                selectedPageIndices: selectedPageIndices,
                temporaryFolderURL: temporaryFolderURL
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
        temporaryFolderURL: URL
    ) async throws {
        let existingResumeState = try? storage.readResumeState(
            folderURL: temporaryFolderURL
        )
        let versionSignature = preferredVersionSignature(
            for: download, mode: mode, resumeState: existingResumeState
        )
        let pageCount = preferredWorkingPageCount(
            for: download, mode: mode,
            versionSignature: versionSignature,
            resumeState: existingResumeState
        )
        let resumedStatus: DownloadStatus =
            activeTask == nil || activeGalleryID == gid
            ? .downloading : .queued

        clearSelectedFailedPages(
            selectedPageIndices: selectedPageIndices,
            temporaryFolderURL: temporaryFolderURL
        )
        try storage.writeResumeState(
            .init(
                mode: mode,
                versionSignature: versionSignature,
                pageCount: pageCount,
                downloadOptions: download.downloadOptionsSnapshot,
                pageSelection: selectedPageIndices
            ),
            folderURL: temporaryFolderURL
        )
        try await updateDownloadRecord(
            gid: gid, createIfMissing: false
        ) { record in
            record.status = resumedStatus.rawValue
            record.lastDownloadedAt = .now
            record.lastError = nil
            record.pendingOperation = nil
        }
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

        let completedFolderURL = download
            .resolvedFolderURL(rootURL: storage.rootURL)
        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        let hasTemporaryFolder = fileManager.operate {
            $0.fileExists(atPath: temporaryFolderURL.path)
        }
        let shouldExposeTemp = hasTemporaryFolder
            && self.shouldExposeTemporaryWorkingSet(for: download)
        let completedValidation = storage.validate(download: download)

        let completedPageURLs = buildCompletedPageURLs(
            completedFolderURL: completedFolderURL,
            download: download
        )
        let temporaryPageURLs = buildTemporaryPageURLs(
            hasTemporaryFolder: hasTemporaryFolder,
            temporaryFolderURL: temporaryFolderURL,
            download: download
        )

        return resolveLocalPageURLs(
            completedValidation: completedValidation,
            completedFolderURL: completedFolderURL,
            completedPageURLs: completedPageURLs,
            temporaryPageURLs: temporaryPageURLs,
            shouldExposeTemp: shouldExposeTemp
        )
    }
}
