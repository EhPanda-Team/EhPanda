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
        sortDownloads(await fetchDownloadsFromStore())
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

    private struct SignatureUpdateInfo {
        let download: DownloadedGallery
        let latestSignature: String?
        let comparison: DownloadSignatureBuilder.Comparison
        let canonicalizedSignature: String?
    }

    func updateRemoteSignature(
        gid: String,
        latestSignature: String?
    ) async -> DownloadBadge {
        guard let download = await fetchDownload(gid: gid) else {
            return .none
        }
        let info = SignatureUpdateInfo(
            download: download,
            latestSignature: latestSignature,
            comparison: DownloadSignatureBuilder.hasUpdateComparison(
                remoteVersionSignature: download.remoteVersionSignature,
                latestRemoteVersionSignature: latestSignature,
                gid: download.gid,
                token: download.token
            ),
            canonicalizedSignature:
                DownloadSignatureBuilder.canonicalizeStoredSignatureIfSafe(
                    remoteVersionSignature: download.remoteVersionSignature,
                    latestRemoteVersionSignature: latestSignature,
                    gid: download.gid,
                    token: download.token
                )
        )
        let didChange = signatureUpdateWouldChange(info: info)
        do {
            try await updateDownloadRecord(
                gid: gid, createIfMissing: false
            ) { record in
                self.applySignatureUpdate(to: record, info: info)
            }
        } catch {
            Logger.error(error)
        }
        if didChange { await notifyObservers() }
        return (await fetchDownload(gid: gid))?.badge ?? .none
    }

    nonisolated private func applySignatureUpdate(
        to record: DownloadedGalleryMO,
        info: SignatureUpdateInfo
    ) {
        let download = info.download
        let latestSignature = info.latestSignature
        if download.latestRemoteVersionSignature != latestSignature {
            record.latestRemoteVersionSignature = latestSignature
        }
        if let canonicalized = info.canonicalizedSignature,
           canonicalized != download.remoteVersionSignature {
            record.remoteVersionSignature = canonicalized
        }
        guard latestSignature?.nonEmpty != nil,
              [.completed, .updateAvailable].contains(download.status)
        else { return }
        let desiredStatus: DownloadStatus?
        switch info.comparison {
        case .different: desiredStatus = .updateAvailable
        case .same: desiredStatus = .completed
        case .incomparable: desiredStatus = nil
        }
        if let desiredStatus, desiredStatus != download.status {
            record.status = desiredStatus.rawValue
        }
    }

    nonisolated private func signatureUpdateWouldChange(
        info: SignatureUpdateInfo
    ) -> Bool {
        let download = info.download
        let latestSignature = info.latestSignature
        if download.latestRemoteVersionSignature != latestSignature {
            return true
        }
        if let canonicalized = info.canonicalizedSignature,
           canonicalized != download.remoteVersionSignature {
            return true
        }
        guard latestSignature?.nonEmpty != nil,
              [.completed, .updateAvailable].contains(download.status)
        else { return false }
        let desiredStatus: DownloadStatus?
        switch info.comparison {
        case .different: desiredStatus = .updateAvailable
        case .same: desiredStatus = .completed
        case .incomparable: desiredStatus = nil
        }
        return desiredStatus != nil && desiredStatus != download.status
    }

    func enqueue(
        payload: DownloadRequestPayload
    ) async -> Result<Void, AppError> {
        do {
            try storage.ensureRootDirectory()
            let versionSignature = DownloadSignatureBuilder.make(
                gallery: payload.gallery,
                detail: payload.galleryDetail,
                host: payload.host,
                previewURLs: payload.previewURLs,
                versionMetadata: payload.versionMetadata
            )
            let folderRelativePath = storage.makeFolderRelativePath(
                gid: payload.gallery.gid,
                title: payload.galleryDetail.trimmedTitle.isEmpty
                    ? payload.gallery.title
                    : payload.galleryDetail.trimmedTitle
            )
            try await updateDownloadRecord(gid: payload.gallery.gid) { record in
                record.gid = payload.gallery.gid
                record.host = payload.host.rawValue
                record.token = payload.gallery.token
                record.title = payload.gallery.title
                record.jpnTitle = payload.galleryDetail.jpnTitle
                record.uploader = payload.galleryDetail.uploader
                record.category = payload.gallery.category.rawValue
                record.tags = payload.gallery.tags.toData()
                record.pageCount = Int64(payload.galleryDetail.pageCount)
                record.postedDate = payload.galleryDetail.postedDate
                record.rating = payload.galleryDetail.rating
                record.onlineCoverURL =
                    payload.galleryDetail.coverURL ?? payload.gallery.coverURL
                record.folderRelativePath = folderRelativePath
                record.downloadOptionsSnapshot = payload.options.toData()
                record.completedPageCount = 0
                record.lastDownloadedAt = .now
                record.lastError = nil
                record.latestRemoteVersionSignature = versionSignature
                record.pendingOperation = nil
                record.status = DownloadStatus.queued.rawValue
            }
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
        guard let download = resolvedDownload,
              let folderURL = download.resolvedFolderURL(rootURL: storage.rootURL)
        else {
            return .failure(.notFound)
        }
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
            await persistResolvedImageURLs(
                gid: gid, index: index, imageURL: pageResult.imageURL
            )
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
