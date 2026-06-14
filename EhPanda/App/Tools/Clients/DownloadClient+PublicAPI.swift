//
//  DownloadClient+PublicAPI.swift
//  EhPanda
//

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
        return await indexedDownloads()
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

    func updateRemoteVersion(
        gid: String,
        metadata: DownloadVersionMetadata
    ) async -> DownloadedGallery? {
        guard let download = await fetchDownload(gid: gid) else {
            return nil
        }
        guard downloadIndex[gid] != nil else {
            return download
        }
        guard [.completed, .updateAvailable].contains(download.displayStatus) else {
            return download
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
        return await fetchDownload(gid: gid)
    }

    func enqueue(
        payload: DownloadRequestPayload
    ) async -> Result<Void, AppError> {
        do {
            try storage.ensureRootDirectory()
            // An already-known gallery keeps its current folder; only brand-new
            // downloads land in the folder carried by the payload.
            let parentFolderName: String
            if let record = downloadIndex[payload.gallery.gid] {
                parentFolderName = record.parentFolderName
            } else if let normalizedName = storage.normalizedUserFolderName(payload.folderName) {
                parentFolderName = normalizedName
            } else {
                return .failure(
                    .fileOperationFailed(
                        L10n.Localizable.DownloadFileStorage.Error.invalidFolderName
                    )
                )
            }
            try createDirectory(at: storage.userFolderURL(name: parentFolderName))
            let folderRelativePath = folderRelativePath(
                for: payload,
                parentFolderName: parentFolderName
            )
            try writeInitialManifest(
                payload: payload,
                folderRelativePath: folderRelativePath
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
        folderRelativePath: String
    ) throws {
        let folderURL = storage.folderURL(relativePath: folderRelativePath)
        try createDirectory(at: folderURL)
        if let existingManifest = reusableExistingManifest(
            payload: payload,
            folderURL: folderURL
        ) {
            updateDownloadIndex(folderURL: folderURL, manifest: existingManifest)
            return
        }
        let manifest = makeInitialManifest(payload: payload)
        try storage.writeManifest(manifest, folderURL: folderURL)
        updateDownloadIndex(folderURL: folderURL, manifest: manifest)
    }

    private func reusableExistingManifest(
        payload: DownloadRequestPayload,
        folderURL: URL
    ) -> DownloadManifest? {
        guard let manifest = try? storage.readManifest(folderURL: folderURL),
              manifest.gid == payload.gallery.gid,
              manifest.token == payload.gallery.token,
              manifest.host == payload.host
        else {
            return nil
        }
        let expectedPageIndices = payload.galleryDetail.pageCount > 0
            ? Set(1...payload.galleryDetail.pageCount)
            : Set<Int>()
        guard Set(manifest.pages.keys) == expectedPageIndices else {
            return nil
        }
        return manifest
    }

    func togglePause(gid: String) async -> Result<Void, AppError> {
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }

        if let queuedMode = queuedModes[gid] {
            return await cancelQueuedWorkItem(download, mode: queuedMode)
        }

        switch download.displayStatus {
        case .queued, .active:
            return await pause(gid: gid)
        case .inactive:
            return await resume(gid: gid)
        case .completed, .error, .updateAvailable:
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
        guard let download = await fetchDownload(gid: gid) else {
            clearDownloadSessionState(gid: gid, includeUpdateFlag: true)
            await queueStore.remove(gid)
            return .failure(.notFound)
        }
        do {
            try removeGalleryFolders(gid: download.gid, token: download.token)
        } catch let error as AppError {
            await reloadDownloadRecord(gid: download.gid, token: download.token)
            return .failure(error)
        } catch {
            Logger.error(error)
            await reloadDownloadRecord(gid: download.gid, token: download.token)
            return .failure(.fileOperationFailed(error.localizedDescription))
        }
        // Clear session and queue state only once the folders are gone; a failed
        // removal above leaves the gallery intact and must not silently dequeue it.
        clearDownloadSessionState(gid: gid, includeUpdateFlag: true)
        await queueStore.remove(gid)
        downloadIndex[gid] = nil
        await notifyObservers()
        await scheduleNextIfNeeded()
        return .success(())
    }

    func loadManifest(
        gid: String
    ) async -> Result<(DownloadedGallery, DownloadManifest), AppError> {
        guard let download = await sanitizeLocalFilesIfNeeded(gid: gid) else {
            return .failure(.notFound)
        }
        switch storage.validate(
            download: download,
            verifiesContentHashes: false
        ) {
        case .valid:
            break
        case .missingFiles(let message):
            return .failure(.fileOperationFailed(message))
        }
        do {
            let manifest = try storage.readManifest(folderURL: download.folderURL)
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
        guard downloadIndex[gid] != nil else { return }
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
            manifest: download.manifest
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
            let manifest = try storage.refreshManifestPageFileHash(
                folderURL: captureTarget.folderURL,
                pageIndex: index,
                relativePath: pageResult.relativePath
            )
            updateDownloadIndex(folderURL: captureTarget.folderURL, manifest: manifest)
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
                manifest: download.manifest
            )
        } ?? [:]
        let failedPages = (failedPageErrors[gid] ?? [:])
            .filter { !isCancellationLikeAppError($0.value.error) }

        let pages = buildInspectionPages(
            download: download,
            activeFolderURL: activeFolderURL,
            existingRelativePaths: existingRelativePaths,
            failedPages: failedPages
        )

        let coverURL = activeFolderURL.flatMap { folderURL in
            storage.existingCoverRelativePath(
                folderURL: folderURL,
                manifest: download.manifest
            ).map {
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
