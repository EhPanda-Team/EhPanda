//
//  DownloadClient+Execution.swift
//  EhPanda
//

import Kanna
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
        var fetchedVersionSignature: String?

        do {
            try await markDownloadAsDownloading(
                gid: gid,
                completedPageCount: download.completedPageCount
            )
            await notifyObservers()
            let result = try await fetchNormalizeAndDownload(
                gid: gid,
                download: download,
                mode: mode
            )
            fetchedVersionSignature = result.versionSignature
            guard !Task.isCancelled else { return }
            try await completeDownload(
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
                hadReadableFiles: hadReadableFiles,
                latestSignature: fetchedVersionSignature
            )
            await handleProcessDownloadError(error: error, context: context)
        }
    }

    private func completeDownload(
        gid: String,
        download: DownloadedGallery,
        result: ProcessDownloadResult
    ) async throws {
        try await persistCompletedDownload(
            gid: gid,
            payload: result.payload,
            folderRelativePath: result.folderRelativePath,
            coverRelativePath: result.coverRelativePath,
            versionSignature: result.versionSignature
        )
        if download.folderRelativePath != result.folderRelativePath {
            try? storage.removeFolder(
                relativePath: download.folderRelativePath
            )
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
        let payload: DownloadRequestPayload
        let folderRelativePath: String
        let coverRelativePath: String?
        let versionSignature: String
    }

    private func markDownloadAsDownloading(
        gid: String,
        completedPageCount: Int
    ) async throws {
        try await updateDownloadRecord(
            gid: gid,
            createIfMissing: false
        ) { record in
            record.status = DownloadStatus.downloading.rawValue
            record.completedPageCount = Int64(completedPageCount)
            record.lastError = nil
            record.pendingOperation = nil
        }
    }

    private func fetchNormalizeAndDownload(
        gid: String,
        download: DownloadedGallery,
        mode: DownloadStartMode
    ) async throws -> ProcessDownloadResult {
        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        let existingResumeState = try? storage
            .readResumeState(folderURL: temporaryFolderURL)
        let rawPageSelection = existingResumeState?.pageSelection
        let fetchResult = try await fetchLatestPayload(
            for: download,
            mode: mode,
            pageSelection: rawPageSelection
        )
        let payload = normalizeFetchedPayload(
            fetchResult.payload,
            mode: mode,
            versionSignature: fetchResult.versionSignature,
            existingResumeState: existingResumeState,
            rawPageSelection: rawPageSelection
        )
        let folderRelativePath = storage.makeFolderRelativePath(
            gid: payload.gallery.gid,
            title: payload.galleryDetail.trimmedTitle.isEmpty
                ? payload.gallery.title
                : payload.galleryDetail.trimmedTitle
        )
        let downloadResult = try await performDownload(
            payload: payload,
            versionSignature: fetchResult.versionSignature,
            folderRelativePath: folderRelativePath,
            existingDownload: download
        )
        return ProcessDownloadResult(
            payload: payload,
            folderRelativePath: folderRelativePath,
            coverRelativePath: downloadResult.coverRelativePath,
            versionSignature: fetchResult.versionSignature
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
            error.failedPages.first?.failure.appError ?? .unknown
        guard !isCancellationLikeAppError(pageError) else { return }
        guard !shouldSuppressFailurePersistence(for: context.gid) else {
            return
        }
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

    func persistCompletedDownload(
        gid: String,
        payload: DownloadRequestPayload,
        folderRelativePath: String,
        coverRelativePath: String?,
        versionSignature: String
    ) async throws {
        try await updateDownloadRecord(
            gid: gid,
            createIfMissing: false
        ) { record in
            record.host = payload.host.rawValue
            record.token = payload.gallery.token
            record.title = payload.gallery.title
            record.jpnTitle = payload.galleryDetail.jpnTitle
            record.uploader = payload.galleryDetail.uploader
            record.category = payload.gallery.category.rawValue
            record.tags = payload.gallery.tags.toData()
            record.pageCount =
                Int64(payload.galleryDetail.pageCount)
            record.postedDate = payload.galleryDetail.postedDate
            record.rating = payload.galleryDetail.rating
            record.onlineCoverURL =
                payload.galleryDetail.coverURL
                ?? payload.gallery.coverURL
            record.folderRelativePath = folderRelativePath
            record.coverRelativePath = coverRelativePath
            record.downloadOptionsSnapshot =
                payload.options.toData()
            record.completedPageCount =
                Int64(payload.galleryDetail.pageCount)
            record.lastDownloadedAt = .now
            record.lastError = nil
            record.remoteVersionSignature = versionSignature
            record.latestRemoteVersionSignature = versionSignature
            record.pendingOperation = nil
            record.status = DownloadStatus.completed.rawValue
        }
    }
}
