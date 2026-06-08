//
//  DownloadClient+PublicAPI.swift
//  EhPanda
//

import CoreData
import Foundation

// MARK: - Public API
extension DownloadManager {
    func observeDownloads() -> AsyncStream<[DownloadedGallery]> {
        let identifier = UUID()
        return AsyncStream { continuation in
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task {
                    await self.removeObserver(id: identifier)
                }
            }
            Task {
                await self.addObserver(id: identifier, continuation: continuation)
            }
        }
    }

    func fetchDownloads() async -> [DownloadedGallery] {
        await fetchDownloadsFromStore()
    }

    func reconcileDownloads() async {
        await syncDownloadsState(scheduleNext: false)
    }

    func refreshDownloads() async {
        await syncDownloadsState(scheduleNext: true)
    }

    func resumeQueue() async {
        await scheduleNextIfNeeded()
    }

    func badges(for gids: [String]) async -> [String: DownloadBadge] {
        guard !gids.isEmpty else { return [:] }
        let downloads = await fetchDownloadsFromStore(gids: gids)
        return Dictionary(uniqueKeysWithValues: downloads.map { ($0.gid, $0.badge) })
    }

    func updateRemoteVersion(
        gid: String,
        metadata: DownloadVersionMetadata
    ) async -> DownloadBadge {
        guard let download = await fetchDownload(gid: gid) else {
            return .none
        }
        guard downloadIndex[gid] != nil else {
            return download.badge
        }
        guard [.completed, .updateAvailable].contains(download.status) else {
            return download.badge
        }

        let hadUpdate = updatedGalleryIDs.contains(gid)
        let hasUpdate = metadata.hasUpdate(comparedTo: download)
        if hasUpdate {
            updatedGalleryIDs.insert(gid)
        } else {
            updatedGalleryIDs.remove(gid)
        }
        if hadUpdate != hasUpdate {
            await notifyObservers()
        }
        return (await fetchDownload(gid: gid))?.badge ?? .none
    }

    func enqueue(
        payload: DownloadRequestPayload
    ) async -> Result<Void, AppError> {
        do {
            try storage.ensureRootDirectory()
            let versionSignature = manifestVersionSignature(
                for: payload.gallery,
                versionMetadata: payload.versionMetadata
            )
            let folderRelativePath = folderRelativePath(for: payload)
            try writeInitialManifest(
                payload: payload,
                folderRelativePath: folderRelativePath,
                versionSignature: versionSignature
            )
            await queueStore.enqueue(payload.gallery.gid)
            await notifyObservers()
            await scheduleNextIfNeeded()
            return .success(())
        } catch let error as AppError {
            return .failure(error)
        } catch {
            Logger.error(error)
            return .failure(.unknown)
        }
    }

    private func writeInitialManifest(
        payload: DownloadRequestPayload,
        folderRelativePath: String,
        versionSignature: String
    ) throws {
        guard let galleryURL = payload.gallery.galleryURL else {
            throw AppError.notFound
        }
        let folderURL = storage.folderURL(relativePath: folderRelativePath)
        try createDirectory(at: folderURL)
        let pageCount = payload.galleryDetail.pageCount
        let pages = pageCount > 0
            ? (1...pageCount).map { index in
                DownloadManifest.Page(
                    index: index,
                    relativePath: storage.makePageRelativePath(
                        gid: payload.gallery.gid,
                        token: payload.gallery.token,
                        index: index,
                        fileExtension: "pending"
                    )
                )
            }
            : []
        try storage.writeManifest(
            DownloadManifest(
                gid: payload.gallery.gid,
                host: payload.host,
                token: payload.gallery.token,
                title: payload.gallery.title,
                jpnTitle: payload.galleryDetail.jpnTitle,
                category: payload.gallery.category,
                language: payload.galleryDetail.language,
                uploader: payload.galleryDetail.uploader,
                tags: payload.gallery.tags,
                postedDate: payload.galleryDetail.postedDate,
                pageCount: pageCount,
                coverRelativePath: nil,
                galleryURL: galleryURL,
                rating: payload.galleryDetail.rating,
                downloadOptions: payload.options,
                versionSignature: versionSignature,
                downloadedAt: .now,
                pages: pages
            ),
            folderURL: folderURL
        )
    }

    func togglePause(gid: String) async -> Result<Void, AppError> {
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }

        if let pendingMode = download.pendingOperation {
            return await cancelQueuedWorkItem(download, mode: pendingMode)
        }

        switch download.status {
        case .queued, .downloading:
            return await pause(gid: gid)
        case .paused:
            return await resume(gid: gid)
        case .partial, .completed, .failed, .updateAvailable, .missingFiles:
            return .failure(.unknown)
        }
    }

    func delete(gid: String) async -> Result<Void, AppError> {
        let taskToCancel: Task<Void, Never>?
        schedulingBlockedGalleryIDs.insert(gid)
        defer {
            schedulingBlockedGalleryIDs.remove(gid)
        }
        if activeGalleryID == gid {
            taskToCancel = activeTask
            activeTask?.cancel()
            activeTask = nil
            activeGalleryID = nil
        } else {
            taskToCancel = nil
        }
        await taskToCancel?.value
        await queueStore.remove(gid)
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }
        do {
            try? storage.removeTemporaryFolder(gid: gid)
            try storage.removeFolder(relativePath: download.folderRelativePath)
            try await deleteDownloadRecord(gid: gid)
            await notifyObservers()
            await scheduleNextIfNeeded()
            return .success(())
        } catch let error as AppError {
            return .failure(error)
        } catch {
            Logger.error(error)
            return .failure(.fileOperationFailed(error.localizedDescription))
        }
    }

    func loadManifest(
        gid: String
    ) async -> Result<(DownloadedGallery, DownloadManifest), AppError> {
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
        let folderURL = download.resolvedFolderURL(rootURL: storage.rootURL)
        switch storage.validate(download: download) {
        case .valid:
            break
        case .missingFiles(let message):
            return .failure(.fileOperationFailed(message))
        }
        do {
            let manifest = try storage.readManifest(folderURL: folderURL)
            return .success((download, manifest))
        } catch {
            return .failure(.fileOperationFailed(error.localizedDescription))
        }
    }

    func captureCachedPage(
        gid: String,
        index: Int,
        imageURL: URL?
    ) async {
        guard let download = await fetchDownload(gid: gid),
              index >= 1,
              index <= max(download.pageCount, 1)
        else { return }

        guard let captureTarget = captureTarget(
            for: download, index: index
        ) else { return }

        await performCacheCapture(
            gid: gid,
            index: index,
            imageURL: imageURL,
            captureTarget: captureTarget,
            download: download
        )
    }

    private func performCacheCapture(
        gid: String,
        index: Int,
        imageURL: URL?,
        captureTarget: CaptureTargetResult,
        download: DownloadedGallery
    ) async {
        let existingPages = storage.existingPageRelativePaths(
            folderURL: captureTarget.folderURL,
            expectedPageCount: download.pageCount
        )
        do {
            let cacheURLs = pageImageCacheURLs(imageURL: imageURL)
            let cacheSource = CacheRestoreSource(
                gid: download.gid,
                token: download.token,
                cacheURLs: cacheURLs,
                referenceURL: preferredPageReferenceURL(imageURL: imageURL),
                imageURL: imageURL
            )
            guard let pageResult = try await restorePageFromCache(
                index: index,
                source: cacheSource,
                folderURL: captureTarget.folderURL,
                preferredRelativePath:
                    captureTarget.preferredRelativePath ?? existingPages[index],
                overwriteExistingFile: true
            ) else { return }
            if captureTarget.isTemporary {
                try clearFailedPage(
                    index: index, folderURL: captureTarget.folderURL
                )
            }
            _ = try? storage.refreshManifestPageFileHash(
                folderURL: captureTarget.folderURL,
                pageIndex: index,
                relativePath: pageResult.relativePath
            )
            _ = await sanitizeLocalFilesIfNeeded(gid: gid, clearingLastError: true)
        } catch {
            Logger.error(error)
        }
    }

    func loadInspection(
        gid: String
    ) async -> Result<DownloadInspection, AppError> {
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }

        let activeFolderURL = activeInspectionFolderURL(for: download)

        let existingRelativePaths = activeFolderURL.map {
            storage.existingPageRelativePaths(
                folderURL: $0,
                expectedPageCount: download.pageCount
            )
        } ?? [:]
        let failedPages = activeFolderURL
            .map(sanitizedFailedPages(folderURL:)) ?? [:]

        let pages = buildInspectionPages(
            download: download,
            activeFolderURL: activeFolderURL,
            existingRelativePaths: existingRelativePaths,
            failedPages: failedPages
        )

        let coverURL = activeFolderURL.flatMap { folderURL in
            storage.existingCoverRelativePath(folderURL: folderURL).map {
                folderURL.appendingPathComponent($0)
            }
        } ?? download.coverURL

        return .success(
            .init(
                download: download,
                coverURL: coverURL,
                pages: pages
            )
        )
    }
}
