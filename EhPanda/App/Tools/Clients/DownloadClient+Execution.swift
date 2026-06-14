//
//  DownloadClient+Execution.swift
//  EhPanda
//

import Foundation

// MARK: - Process Download
extension DownloadCoordinator {
    func processDownload(
        gid: String,
        generation: Int? = nil
    ) async {
        defer {
            finishActiveTaskIfOwned(
                gid: gid,
                generation: generation,
                schedulesNext: true
            )
        }

        guard let download = await fetchDownload(gid: gid) else {
            return
        }
        let mode = queuedMode(for: download)
        let options = await downloadOptionsProvider()

        do {
            clearDownloadFailureState(gid: gid, includePageFailures: false)
            await notifyObservers()
            let result = try await fetchNormalizeAndDownload(
                gid: gid,
                download: download,
                mode: mode,
                options: options
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
                mode: mode
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
        removeSupersededFolders(
            gid: gid,
            token: download.token,
            keeping: completedFolderURL
        )
        await notifyObservers()
    }

    // A download can finish in a different folder than it started in
    // (re-slot after a title change), and an interrupted session can leave
    // both behind; only the completed folder may survive, or the stale
    // duplicate resurfaces once the surviving record is deleted.
    func removeSupersededFolders(gid: String, token: String, keeping folderURL: URL) {
        do {
            try removeGalleryFolders(gid: gid, token: token, keeping: folderURL)
        } catch {
            Logger.error(error)
        }
    }

    func removeGalleryFolders(gid: String, token: String, keeping folderURL: URL? = nil) throws {
        let keptPath = folderURL?.standardizedFileURL.path
        for galleryFolderURL in storage.galleryFolderURLs(gid: gid, token: token) {
            guard galleryFolderURL.standardizedFileURL.path != keptPath else {
                continue
            }
            try storage.removeFolder(at: galleryFolderURL)
        }
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
        } else if let incompleteError = error as? IncompleteDownloadError {
            await handleProcessDownloadIncompleteError(
                error: incompleteError,
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
        mode: DownloadStartMode,
        options: DownloadRequestOptions
    ) async throws -> ProcessDownloadResult {
        let rawPageSelection = queuedPageSelections[gid]
        let fetchedPayload = try await fetchLatestPayload(
            for: download,
            mode: mode,
            options: options,
            pageSelection: rawPageSelection
        )
        let payload = normalizeFetchedPayload(
            fetchedPayload,
            mode: mode,
            rawPageSelection: rawPageSelection
        )
        let folderRelativePath = folderRelativePath(
            for: payload,
            parentFolderName: download.folderName
        )
        _ = try await performDownload(
            payload: payload,
            options: options,
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

    private func handleProcessDownloadIncompleteError(
        error _: IncompleteDownloadError,
        context: FailureContext
    ) async {
        guard !shouldSuppressFailurePersistence(for: context.gid) else {
            return
        }
        clearDownloadQueueIntent(gid: context.gid)
        await queueStore.remove(context.gid)
        await reloadDownloadRecord(
            gid: context.gid,
            token: context.originalDownload.token
        )
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
        await backgroundTaskStore.removeAll(for: gid)
    }

    func finishActiveTaskIfOwned(
        gid: String,
        generation: Int?,
        schedulesNext: Bool
    ) {
        guard isActiveTaskOwner(gid: gid, generation: generation) else {
            return
        }
        activeTask = nil
        activeGalleryID = nil
        guard schedulesNext else { return }
        Task {
            await self.scheduleNextIfNeeded()
        }
    }

    private func isActiveTaskOwner(
        gid: String,
        generation: Int?
    ) -> Bool {
        if let generation {
            return activeGalleryID == gid
                && activeTaskGeneration == generation
        }
        guard activeTask == nil else { return false }
        return activeGalleryID == nil || activeGalleryID == gid
    }
}
