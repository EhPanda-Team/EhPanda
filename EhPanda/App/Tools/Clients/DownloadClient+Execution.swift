//
//  DownloadClient+Execution.swift
//  EhPanda
//

import Foundation

// MARK: - Process Download
extension DownloadManager {
    func processDownload(gid: String) async {
        defer {
            activeTask = nil
            activeGalleryID = nil
            Task {
                await self.scheduleNextIfNeeded()
            }
        }

        guard let download = await fetchDownload(gid: gid) else {
            return
        }
        let mode = queuedMode(for: download)
        let hadReadableFiles =
            storage.validate(download: download) == .valid

        do {
            clearDownloadFailureState(gid: gid, includePageFailures: false)
            await notifyObservers()
            let result = try await fetchNormalizeAndDownload(
                gid: gid,
                download: download,
                mode: mode
            )
            guard !Task.isCancelled else { return }
            await completeDownload(
                gid: gid,
                download: download,
                result: result
            )
        } catch is CancellationError {
            return
        } catch {
            let context = FailureContext(
                gid: gid,
                originalDownload: download,
                mode: mode,
                hadReadableFiles: hadReadableFiles
            )
            await handleProcessDownloadError(error: error, context: context)
        }
    }

    private func completeDownload(
        gid: String,
        download: DownloadedGallery,
        result: ProcessDownloadResult
    ) async {
        await settleCompletedDownload(gid: gid)
        let completedFolderURL = storage.folderURL(
            relativePath: result.folderRelativePath
        )
        if download.folderURL != completedFolderURL {
            try? storage.removeFolder(at: download.folderURL)
        }
        await notifyObservers()
    }

    private func handleProcessDownloadError(
        error: Error,
        context: FailureContext
    ) async {
        if let appError = error as? AppError {
            await handleProcessDownloadAppError(
                error: appError,
                context: context
            )
        } else if let partialError = error as? PartialDownloadError {
            await handleProcessDownloadPartialError(
                error: partialError,
                context: context
            )
        } else {
            await handleProcessDownloadGenericError(
                error: error,
                context: context
            )
        }
    }

    private struct ProcessDownloadResult {
        let folderRelativePath: String
    }

    private func fetchNormalizeAndDownload(
        gid: String,
        download: DownloadedGallery,
        mode: DownloadStartMode
    ) async throws -> ProcessDownloadResult {
        let rawPageSelection = queuedPageSelections[gid]
        let fetchedPayload = try await fetchLatestPayload(
            for: download,
            mode: mode,
            pageSelection: rawPageSelection
        )
        let payload = normalizeFetchedPayload(
            fetchedPayload,
            mode: mode,
            rawPageSelection: rawPageSelection
        )
        let folderRelativePath = folderRelativePath(for: payload)
        _ = try await performDownload(
            payload: payload,
            folderRelativePath: folderRelativePath,
            existingDownload: download
        )
        return ProcessDownloadResult(
            folderRelativePath: folderRelativePath
        )
    }

    private func handleProcessDownloadAppError(
        error: AppError,
        context: FailureContext
    ) async {
        guard !isCancellationLikeAppError(error) else { return }
        guard !shouldSuppressFailurePersistence(for: context.gid) else {
            return
        }
        Logger.error(
            "Download failed.",
            context: [
                "gid": context.gid,
                "mode": context.mode.rawValue,
                "error": error.localizedDescription
            ]
        )
        await persistFailure(error: error, context: context)
        await notifyObservers()
    }

    private func handleProcessDownloadPartialError(
        error: PartialDownloadError,
        context: FailureContext
    ) async {
        let pageError =
            error.failedPages.first?.error ?? .unknown
        guard !isCancellationLikeAppError(pageError) else { return }
        guard !shouldSuppressFailurePersistence(for: context.gid) else {
            return
        }
        failedPageErrors[context.gid] = Dictionary(
            uniqueKeysWithValues: error.failedPages.map { ($0.index, $0) }
        )
        Logger.error(
            "Download partially failed.",
            context: [
                "gid": context.gid,
                "mode": context.mode.rawValue,
                "failedPages": error.failedPages.map(\.index)
            ]
        )
        await persistFailure(error: pageError, context: context)
        await notifyObservers()
    }

    private func handleProcessDownloadGenericError(
        error: Error,
        context: FailureContext
    ) async {
        let appError = AppError.fileOperationFailed(
            error.localizedDescription
        )
        guard !isCancellationLikeAppError(appError) else { return }
        guard !shouldSuppressFailurePersistence(for: context.gid) else {
            return
        }
        Logger.error(error)
        await persistFailure(
            error: appError,
            context: context
        )
        await notifyObservers()
    }

    func settleCompletedDownload(gid: String) async {
        clearDownloadSessionState(gid: gid, includeUpdateFlag: true)
        await queueStore.remove(gid)
    }
}
