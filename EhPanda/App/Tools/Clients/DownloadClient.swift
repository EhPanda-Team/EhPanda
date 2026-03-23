//
//  DownloadClient.swift
//  EhPanda
//

import Kanna
import CryptoKit
import CoreData
import Foundation
import ImageIO
import Kingfisher
import ComposableArchitecture

struct DownloadClient {
    let observeDownloads: () -> AsyncStream<[DownloadedGallery]>
    let fetchDownloads: () async -> [DownloadedGallery]
    let fetchDownload: (String) async -> DownloadedGallery?
    let reconcileDownloads: () async -> Void
    let refreshDownloads: () async -> Void
    let resumeQueue: () async -> Void
    let badges: ([String]) async -> [String: DownloadBadge]
    let updateRemoteSignature: (String, String?) async -> DownloadBadge
    let enqueue: (DownloadRequestPayload) async -> Result<Void, AppError>
    let togglePause: (String) async -> Result<Void, AppError>
    let retry: (String, DownloadStartMode) async -> Result<Void, AppError>
    let retryPages: (String, [Int]) async -> Result<Void, AppError>
    let delete: (String) async -> Result<Void, AppError>
    let loadManifest: (String) async -> Result<(DownloadedGallery, DownloadManifest), AppError>
    let loadLocalPageURLs: (String) async -> Result<[Int: URL], AppError>
    let captureCachedPage: (String, Int, URL?) async -> Void
    let loadInspection: (String) async -> Result<DownloadInspection, AppError>

    init(
        observeDownloads: @escaping () -> AsyncStream<[DownloadedGallery]>,
        fetchDownloads: @escaping () async -> [DownloadedGallery],
        fetchDownload: @escaping (String) async -> DownloadedGallery?,
        reconcileDownloads: @escaping () async -> Void = {},
        refreshDownloads: @escaping () async -> Void,
        resumeQueue: @escaping () async -> Void,
        badges: @escaping ([String]) async -> [String: DownloadBadge],
        updateRemoteSignature: @escaping (String, String?) async -> DownloadBadge,
        enqueue: @escaping (DownloadRequestPayload) async -> Result<Void, AppError>,
        togglePause: @escaping (String) async -> Result<Void, AppError>,
        retry: @escaping (String, DownloadStartMode) async -> Result<Void, AppError>,
        retryPages: @escaping (String, [Int]) async -> Result<Void, AppError> = { _, _ in .success(()) },
        delete: @escaping (String) async -> Result<Void, AppError>,
        loadManifest: @escaping (String) async -> Result<(DownloadedGallery, DownloadManifest), AppError>,
        loadLocalPageURLs: @escaping (String) async -> Result<[Int: URL], AppError> = { _ in .failure(.notFound) },
        captureCachedPage: @escaping (String, Int, URL?) async -> Void = { _, _, _ in },
        loadInspection: @escaping (String) async -> Result<DownloadInspection, AppError> = { _ in .failure(.notFound) }
    ) {
        self.observeDownloads = observeDownloads
        self.fetchDownloads = fetchDownloads
        self.fetchDownload = fetchDownload
        self.reconcileDownloads = reconcileDownloads
        self.refreshDownloads = refreshDownloads
        self.resumeQueue = resumeQueue
        self.badges = badges
        self.updateRemoteSignature = updateRemoteSignature
        self.enqueue = enqueue
        self.togglePause = togglePause
        self.retry = retry
        self.retryPages = retryPages
        self.delete = delete
        self.loadManifest = loadManifest
        self.loadLocalPageURLs = loadLocalPageURLs
        self.captureCachedPage = captureCachedPage
        self.loadInspection = loadInspection
    }
}

extension DownloadClient {
    static func live(
        rootURL: URL? = FileUtil.downloadsDirectoryURL,
        urlSession: URLSession = .shared,
        fileManager: FileManager = .default
    ) -> Self {
        let manager = DownloadManager(
            storage: .init(rootURL: rootURL, fileManager: fileManager),
            urlSession: urlSession
        )
        Task {
            await manager.reconcileDownloads()
            await manager.resumeQueue()
        }
        return .init(
            observeDownloads: {
                AsyncStream { continuation in
                    let task = Task {
                        let stream = await manager.observeDownloads()
                        for await downloads in stream {
                            continuation.yield(downloads)
                        }
                        continuation.finish()
                    }
                    continuation.onTermination = { _ in
                        task.cancel()
                    }
                }
            },
            fetchDownloads: {
                await manager.fetchDownloads()
            },
            fetchDownload: { gid in
                await manager.fetchDownload(gid: gid)
            },
            reconcileDownloads: {
                await manager.reconcileDownloads()
            },
            refreshDownloads: {
                await manager.refreshDownloads()
            },
            resumeQueue: {
                await manager.resumeQueue()
            },
            badges: { gids in
                await manager.badges(for: gids)
            },
            updateRemoteSignature: { gid, signature in
                await manager.updateRemoteSignature(gid: gid, latestSignature: signature)
            },
            enqueue: { payload in
                await manager.enqueue(payload: payload)
            },
            togglePause: { gid in
                await manager.togglePause(gid: gid)
            },
            retry: { gid, mode in
                await manager.retry(gid: gid, mode: mode)
            },
            retryPages: { gid, pageIndices in
                await manager.retryPages(gid: gid, pageIndices: pageIndices)
            },
            delete: { gid in
                await manager.delete(gid: gid)
            },
            loadManifest: { gid in
                await manager.loadManifest(gid: gid)
            },
            loadLocalPageURLs: { gid in
                await manager.loadLocalPageURLs(gid: gid)
            },
            captureCachedPage: { gid, index, imageURL in
                await manager.captureCachedPage(
                    gid: gid,
                    index: index,
                    imageURL: imageURL
                )
            },
            loadInspection: { gid in
                await manager.loadInspection(gid: gid)
            }
        )
    }
}

actor DownloadManager {
    private static let retryLimit = 3
    private static let progressFlushPageInterval = 8
    private static let progressFlushMinimumInterval: TimeInterval = 0.4
    private static let responseInspectionPrefixLength = 4096
    private static let kokomadeImageByteCount = 144844
    private static let kokomadeImageSHA1 = "e48ed350e902a51581246d2a764fa7827e8e6988"
    private static let kokomadeImageURLSuffixes = [
        "exhentai.org/img/kokomade.jpg"
    ]
    private static let quotaExceededImageByteCount = 28658
    private static let quotaExceededImageSHA1 = "f54b887b017694dc25eb1a1404f71981885f8ed9"
    private static let quotaExceededImageURLSuffixes = [
        "exhentai.org/img/509.gif",
        "ehgt.org/g/509.gif"
    ]

    private struct PageResult: Sendable {
        let index: Int
        let relativePath: String
        let imageURL: URL?
    }

    private struct PageFailure: Error, Sendable {
        let index: Int
        let relativePath: String?
        let error: AppError
    }

    private struct DownloadBatchResult: Sendable {
        let pages: [PageResult]
        let failedPages: [DownloadFailedPagesSnapshot.Page]
    }

    private enum PageTaskOutcome: Sendable {
        case success(PageResult)
        case failure(PageFailure)
        case cancelled
    }

    private struct RepairSeed: Sendable {
        let folderURL: URL
        let manifest: DownloadManifest
    }

    private struct WorkingSeed: Sendable {
        let folderURL: URL
        let manifest: DownloadManifest?
        let existingPages: [Int: String]
        let coverRelativePath: String?
    }

    private enum ResolvedSource: Sendable {
        case normal([Int: URL])
        case mpv(String, [Int: String])
    }

    private struct ResolvedImageSource: Sendable {
        let imageURL: URL
    }

    private struct CachedGalleryImageState: Sendable {
        let previewURLs: [Int: URL]
        let imageURLs: [Int: URL]
    }

    private struct PartialDownloadError: Error, Sendable {
        let failedPages: [DownloadFailedPagesSnapshot.Page]
    }

    private let storage: DownloadFileStorage
    private let urlSession: URLSession
    private var observers = [UUID: AsyncStream<[DownloadedGallery]>.Continuation]()
    private var lastObservedDownloads = [DownloadedGallery]()
    private var activeGalleryID: String?
    private var activeTask: Task<Void, Never>?
    private var schedulingBlockedGalleryIDs = Set<String>()

    init(storage: DownloadFileStorage, urlSession: URLSession) {
        self.storage = storage
        self.urlSession = urlSession
    }

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

    private func syncDownloadsState(scheduleNext: Bool) async {
        let downloads = await fetchDownloadsFromStore()
        // Normalize legacy failures before temp cleanup so recoverable working sets are not
        // deleted just because older records still say `.failed`.
        await normalizeNeedsAttentionDownloads(downloads)
        await normalizeInterruptedDownloads(downloads)

        let normalizedDownloads = await fetchDownloadsFromStore()
        do {
            try storage.ensureRootDirectory()
            try storage.cleanupTemporaryFolders(
                preservingGIDs: Set(
                    normalizedDownloads.compactMap { download in
                        download.shouldPreserveTemporaryWorkingSet
                            ? download.gid
                            : nil
                    }
                )
            )
        } catch {
            Logger.error(error)
        }
        await reconcileActiveDownloadState()
        await validateDownloads()
        await notifyObservers()
        guard scheduleNext else { return }
        await scheduleNextIfNeeded()
    }

    func resumeQueue() async {
        await scheduleNextIfNeeded()
    }

    func badges(for gids: [String]) async -> [String: DownloadBadge] {
        guard !gids.isEmpty else { return [:] }
        let downloads = await fetchDownloadsFromStore(gids: gids)
        return Dictionary(uniqueKeysWithValues: downloads.map { ($0.gid, $0.badge) })
    }

    func updateRemoteSignature(gid: String, latestSignature: String?) async -> DownloadBadge {
        guard let download = await fetchDownload(gid: gid) else { return .none }
        let comparison = DownloadSignatureBuilder.hasUpdateComparison(
            remoteVersionSignature: download.remoteVersionSignature,
            latestRemoteVersionSignature: latestSignature,
            gid: download.gid,
            token: download.token
        )
        let canonicalizedSignature = DownloadSignatureBuilder.canonicalizeStoredSignatureIfSafe(
            remoteVersionSignature: download.remoteVersionSignature,
            latestRemoteVersionSignature: latestSignature,
            gid: download.gid,
            token: download.token
        )
        var didChange = false

        do {
            try await updateDownloadRecord(gid: gid, createIfMissing: false) { record in
                if download.latestRemoteVersionSignature != latestSignature {
                    record.latestRemoteVersionSignature = latestSignature
                    didChange = true
                }

                if let canonicalizedSignature,
                   canonicalizedSignature != download.remoteVersionSignature
                {
                    record.remoteVersionSignature = canonicalizedSignature
                    didChange = true
                }

                guard latestSignature?.notEmpty == true,
                      [.completed, .updateAvailable].contains(download.status)
                else { return }

                let desiredStatus: DownloadStatus?
                switch comparison {
                case .different:
                    desiredStatus = .updateAvailable
                case .same:
                    desiredStatus = .completed
                case .incomparable:
                    desiredStatus = nil
                }

                if let desiredStatus,
                   desiredStatus != download.status
                {
                    record.status = desiredStatus.rawValue
                    didChange = true
                }
            }
        } catch {
            Logger.error(error)
        }

        if didChange {
            await notifyObservers()
        }
        return (await fetchDownload(gid: gid))?.badge ?? .none
    }

    func enqueue(payload: DownloadRequestPayload) async -> Result<Void, AppError> {
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
                record.onlineCoverURL = payload.galleryDetail.coverURL ?? payload.gallery.coverURL
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

    func retry(gid: String, mode: DownloadStartMode) async -> Result<Void, AppError> {
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }
        do {
            let resolvedMode = effectiveRetryMode(for: download, requestedMode: mode)
            let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
            let existingResumeState = fileManager().fileExists(atPath: temporaryFolderURL.path)
                ? (try? storage.readResumeState(folderURL: temporaryFolderURL))
                : nil
            let shouldResumeExistingWork = shouldResumeExistingWorkingSet(
                for: download,
                mode: resolvedMode,
                resumeState: existingResumeState
            )
            let shouldStartImmediately = activeTask == nil || activeGalleryID == gid
            let resumedStatus: DownloadStatus
            let completedPageCount: Int
            let pendingOperation: DownloadStartMode?

            if shouldResumeExistingWork {
                resumedStatus = shouldStartImmediately ? .downloading : .queued
                completedPageCount = download.completedPageCount
                pendingOperation = nil
            } else if shouldStartImmediately {
                resumedStatus = .downloading
                completedPageCount = validatedCompletedPageCount(download)
                pendingOperation = nil
            } else {
                resumedStatus = download.status
                completedPageCount = validatedCompletedPageCount(download)
                pendingOperation = resolvedMode
            }

            if !shouldResumeExistingWork {
                try? storage.removeTemporaryFolder(gid: gid)
            }
            try await updateDownloadRecord(gid: gid, createIfMissing: false) { record in
                record.status = resumedStatus.rawValue
                record.completedPageCount = Int64(completedPageCount)
                record.lastDownloadedAt = .now
                record.lastError = nil
                record.pendingOperation = pendingOperation?.rawValue
            }
            if fileManager().fileExists(atPath: temporaryFolderURL.path) {
                let downloadOptions = download.downloadOptionsSnapshot
                let versionSignature = preferredVersionSignature(
                    for: download,
                    mode: resolvedMode,
                    resumeState: existingResumeState
                )
                let pageCount = preferredWorkingPageCount(
                    for: download,
                    mode: resolvedMode,
                    versionSignature: versionSignature,
                    resumeState: existingResumeState
                )
                try? storage.writeResumeState(
                    .init(
                        mode: resolvedMode,
                        versionSignature: versionSignature,
                        pageCount: pageCount,
                        downloadOptions: downloadOptions
                    ),
                    folderURL: temporaryFolderURL
                )
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

    func retryPages(gid: String, pageIndices: [Int]) async -> Result<Void, AppError> {
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }

        let mode = resumeMode(for: download)
        if mode == .update {
            return await retry(gid: gid, mode: .update)
        }

        let selectedPageIndices = Array(Set(pageIndices)).sorted()
        guard !selectedPageIndices.isEmpty else { return .success(()) }

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        guard fileManager().fileExists(atPath: temporaryFolderURL.path) else {
            return .failure(.notFound)
        }

        let existingResumeState = try? storage.readResumeState(folderURL: temporaryFolderURL)
        let versionSignature = preferredVersionSignature(
            for: download,
            mode: mode,
            resumeState: existingResumeState
        )
        let pageCount = preferredWorkingPageCount(
            for: download,
            mode: mode,
            versionSignature: versionSignature,
            resumeState: existingResumeState
        )
        let resumedStatus: DownloadStatus = activeTask == nil || activeGalleryID == gid
            ? .downloading
            : .queued

        do {
            if let failedSnapshot = try? storage.readFailedPages(folderURL: temporaryFolderURL) {
                let remainingPages = failedSnapshot.pages.filter { !selectedPageIndices.contains($0.index) }
                if remainingPages.isEmpty {
                    try? storage.removeFailedPages(folderURL: temporaryFolderURL)
                } else {
                    try storage.writeFailedPages(.init(pages: remainingPages), folderURL: temporaryFolderURL)
                }
            }
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
            try await updateDownloadRecord(gid: gid, createIfMissing: false) { record in
                record.status = resumedStatus.rawValue
                record.lastDownloadedAt = .now
                record.lastError = nil
                record.pendingOperation = nil
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

    func loadManifest(gid: String) async -> Result<(DownloadedGallery, DownloadManifest), AppError> {
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

    func loadLocalPageURLs(gid: String) async -> Result<[Int: URL], AppError> {
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

        let completedFolderURL = download.resolvedFolderURL(rootURL: storage.rootURL)
        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        let hasTemporaryFolder = fileManager().fileExists(atPath: temporaryFolderURL.path)
        let shouldExposeTemporaryWorkingSet = hasTemporaryFolder
            && self.shouldExposeTemporaryWorkingSet(for: download)
        let completedValidation = storage.validate(download: download)

        let completedPageRelativePaths = completedFolderURL.map {
            storage.existingPageRelativePaths(
                folderURL: $0,
                expectedPageCount: download.pageCount
            )
        } ?? [:]
        let temporaryPageRelativePaths = hasTemporaryFolder
            ? storage.existingPageRelativePaths(
                folderURL: temporaryFolderURL,
                expectedPageCount: download.pageCount
            )
            : [:]

        let completedPageURLs = completedPageRelativePaths.reduce(into: [Int: URL]()) { result, entry in
            guard let folderURL = completedFolderURL else { return }
            result[entry.key] = folderURL.appendingPathComponent(entry.value)
        }
        let temporaryPageURLs = temporaryPageRelativePaths.reduce(into: [Int: URL]()) { result, entry in
            result[entry.key] = temporaryFolderURL.appendingPathComponent(entry.value)
        }

        if completedValidation == .valid,
           let completedFolderURL,
           fileManager().fileExists(atPath: completedFolderURL.path),
           let manifest = try? storage.readManifest(folderURL: completedFolderURL)
        {
            let completedManifestPageURLs = manifest.imageURLs(folderURL: completedFolderURL)
            guard shouldExposeTemporaryWorkingSet else {
                return .success(completedManifestPageURLs)
            }
            return .success(
                completedManifestPageURLs.merging(
                    temporaryPageURLs,
                    uniquingKeysWith: { _, temporary in temporary }
                )
            )
        }

        guard shouldExposeTemporaryWorkingSet else {
            return .success(completedPageURLs)
        }

        if !completedPageURLs.isEmpty, !temporaryPageURLs.isEmpty {
            return .success(
                completedPageURLs.merging(
                    temporaryPageURLs,
                    uniquingKeysWith: { _, temporary in temporary }
                )
            )
        }

        if !temporaryPageURLs.isEmpty {
            return .success(temporaryPageURLs)
        }

        return .success(completedPageURLs)
    }

    func captureCachedPage(
        gid: String,
        index: Int,
        imageURL: URL?
    ) async {
        guard let download = await fetchDownload(gid: gid),
              index >= 1,
              index <= max(download.pageCount, 1)
        else {
            return
        }

        guard let captureTarget = captureTarget(
            for: download,
            index: index
        ) else {
            return
        }

        let existingPages = storage.existingPageRelativePaths(
            folderURL: captureTarget.folderURL,
            expectedPageCount: download.pageCount
        )
        do {
            let cacheURLs = pageImageCacheURLs(imageURL: imageURL)
            guard let pageResult = try await restorePageFromCache(
                index: index,
                cacheURLs: cacheURLs,
                folderURL: captureTarget.folderURL,
                preferredRelativePath: captureTarget.preferredRelativePath ?? existingPages[index],
                referenceURL: preferredPageReferenceURL(imageURL: imageURL),
                imageURL: imageURL,
                overwriteExistingFile: true
            ) else {
                return
            }

            await persistResolvedImageURLs(
                gid: gid,
                index: index,
                imageURL: pageResult.imageURL
            )
            if captureTarget.isTemporary {
                try clearFailedPage(index: index, folderURL: captureTarget.folderURL)
            }
            _ = await sanitizeLocalFilesIfNeeded(gid: gid, clearingLastError: true)
        } catch {
            Logger.error(error)
        }
    }

    func loadInspection(gid: String) async -> Result<DownloadInspection, AppError> {
        guard let download = await fetchDownload(gid: gid) else {
            return .failure(.notFound)
        }

        let activeFolderURL = activeInspectionFolderURL(for: download)

        let existingRelativePaths = activeFolderURL.map {
            storage.existingPageRelativePaths(folderURL: $0, expectedPageCount: download.pageCount)
        } ?? [:]
        let failedPages = activeFolderURL.map(sanitizedFailedPages(folderURL:)) ?? [:]

        let pages = (1...download.pageCount).map { index -> DownloadPageInspection in
            if let relativePath = existingRelativePaths[index], let folderURL = activeFolderURL {
                let fileURL = folderURL.appendingPathComponent(relativePath)
                if fileManager().fileExists(atPath: fileURL.path) {
                    return .init(
                        index: index,
                        status: .downloaded,
                        relativePath: relativePath,
                        fileURL: fileURL,
                        failure: nil
                    )
                }
            }

            if let failedPage = failedPages[index] {
                return .init(
                    index: index,
                    status: .failed,
                    relativePath: failedPage.relativePath,
                    fileURL: nil,
                    failure: failedPage.failure
                )
            }

            return .init(
                index: index,
                status: .pending,
                relativePath: nil,
                fileURL: nil,
                failure: nil
            )
        }

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

    private func addObserver(id: UUID, continuation: AsyncStream<[DownloadedGallery]>.Continuation) async {
        observers[id] = continuation
        let downloads = await fetchDownloads()
        lastObservedDownloads = downloads
        continuation.yield(downloads)
    }

    private func removeObserver(id: UUID) {
        observers[id] = nil
    }

    private func notifyObservers() async {
        let downloads = await fetchDownloads()
        guard downloads != lastObservedDownloads else { return }
        lastObservedDownloads = downloads
        observers.values.forEach { $0.yield(downloads) }
    }

    private func scheduleNextIfNeeded() async {
        guard activeTask == nil else {
            await reconcileActiveDownloadState()
            return
        }
        let downloads = await fetchDownloadsFromStore()
        let nextDownload = downloads
            .filter {
                !schedulingBlockedGalleryIDs.contains($0.gid)
                && shouldSchedule(download: $0)
            }
            .sorted { lhs, rhs in
                let lhsIsDownloading = lhs.status == .downloading
                let rhsIsDownloading = rhs.status == .downloading
                if lhsIsDownloading != rhsIsDownloading {
                    return lhsIsDownloading
                }
                return (lhs.lastDownloadedAt ?? .distantPast) < (rhs.lastDownloadedAt ?? .distantPast)
            }
            .first
        guard let nextDownload else { return }

        activeGalleryID = nextDownload.gid
        activeTask = Task { [weak self] in
            guard let self else { return }
            await self.processDownload(gid: nextDownload.gid)
        }
    }

    private func shouldSchedule(download: DownloadedGallery) -> Bool {
        if download.status == .downloading || download.isQueuedWorkItem {
            return true
        }

        guard download.status == .partial else {
            return false
        }

        let temporaryFolderURL = storage.temporaryFolderURL(gid: download.gid)
        guard let resumeState = try? storage.readResumeState(folderURL: temporaryFolderURL),
              let pageSelection = resumeState.pageSelection
        else {
            return false
        }
        return !pageSelection.isEmpty
    }

    private func processDownload(gid: String) async {
        defer {
            activeTask = nil
            activeGalleryID = nil
            Task {
                await self.scheduleNextIfNeeded()
            }
        }

        guard let download = await fetchDownload(gid: gid) else { return }
        let mode = queuedMode(for: download)
        let previousFolderRelativePath = download.folderRelativePath
        let hadReadableFiles = storage.validate(download: download) == .valid
        var fetchedVersionSignature: String?

        do {
            try await updateDownloadRecord(gid: gid, createIfMissing: false) { record in
                record.status = DownloadStatus.downloading.rawValue
                record.completedPageCount = Int64(download.completedPageCount)
                record.lastError = nil
                record.pendingOperation = nil
            }
            await notifyObservers()

            let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
            let existingResumeState = try? storage.readResumeState(folderURL: temporaryFolderURL)
            let rawPageSelection = existingResumeState?.pageSelection
            let (fetchedPayload, versionSignature) = try await fetchLatestPayload(
                for: download,
                mode: mode,
                pageSelection: rawPageSelection
            )
            fetchedVersionSignature = versionSignature
            let payload = normalizeFetchedPayload(
                fetchedPayload,
                mode: mode,
                versionSignature: versionSignature,
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
                versionSignature: versionSignature,
                folderRelativePath: folderRelativePath,
                existingDownload: download
            )

            guard !Task.isCancelled else { return }

            try await updateDownloadRecord(gid: gid, createIfMissing: false) { record in
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
                record.onlineCoverURL = payload.galleryDetail.coverURL ?? payload.gallery.coverURL
                record.folderRelativePath = folderRelativePath
                record.coverRelativePath = downloadResult.coverRelativePath
                record.downloadOptionsSnapshot = payload.options.toData()
                record.completedPageCount = Int64(payload.galleryDetail.pageCount)
                record.lastDownloadedAt = .now
                record.lastError = nil
                record.remoteVersionSignature = versionSignature
                record.latestRemoteVersionSignature = versionSignature
                record.pendingOperation = nil
                record.status = DownloadStatus.completed.rawValue
            }
            if previousFolderRelativePath != folderRelativePath {
                try? storage.removeFolder(relativePath: previousFolderRelativePath)
            }
            await notifyObservers()
        } catch is CancellationError {
            return
        } catch let error as AppError {
            guard !isCancellationLikeAppError(error) else { return }
            guard !shouldSuppressFailurePersistence(for: gid) else { return }
            Logger.error(
                "Download failed.",
                context: [
                    "gid": gid,
                    "mode": mode.rawValue,
                    "error": error.localizedDescription
                ]
            )
            await persistFailure(
                gid: gid,
                error: error,
                originalDownload: download,
                mode: mode,
                hadReadableFiles: hadReadableFiles,
                latestSignature: fetchedVersionSignature
            )
            await notifyObservers()
        } catch let error as PartialDownloadError {
            let pageError = error.failedPages.first?.failure.appError ?? .unknown
            guard !isCancellationLikeAppError(pageError) else { return }
            guard !shouldSuppressFailurePersistence(for: gid) else { return }
            Logger.error(
                "Download partially failed.",
                context: [
                    "gid": gid,
                    "mode": mode.rawValue,
                    "failedPages": error.failedPages.map(\.index)
                ]
            )
            await persistFailure(
                gid: gid,
                error: pageError,
                originalDownload: download,
                mode: mode,
                hadReadableFiles: hadReadableFiles,
                latestSignature: fetchedVersionSignature
            )
            await notifyObservers()
        } catch {
            let appError = AppError.fileOperationFailed(error.localizedDescription)
            guard !isCancellationLikeAppError(appError) else { return }
            guard !shouldSuppressFailurePersistence(for: gid) else { return }
            Logger.error(error)
            await persistFailure(
                gid: gid,
                error: appError,
                originalDownload: download,
                mode: mode,
                hadReadableFiles: hadReadableFiles,
                latestSignature: fetchedVersionSignature
            )
            await notifyObservers()
        }
    }

    private func queuedMode(for download: DownloadedGallery) -> DownloadStartMode {
        if let pendingOperation = download.pendingOperation {
            return pendingOperation
        }
        switch download.status {
        case .missingFiles:
            return effectiveRetryMode(for: download, requestedMode: .repair)
        case .updateAvailable:
            return .update
        case .partial:
            return resumeMode(for: download)
        case .completed:
            return effectiveRetryMode(for: download, requestedMode: .redownload)
        case .failed:
            return effectiveRetryMode(
                for: download,
                requestedMode: download.remoteVersionSignature.isEmpty ? .initial : .redownload
            )
        case .paused:
            return resumeMode(for: download)
        case .queued, .downloading:
            return readResumeMode(gid: download.gid)
                ?? effectiveRetryMode(
                    for: download,
                    requestedMode: download.remoteVersionSignature.isEmpty ? .initial : .redownload
                )
        }
    }

    private func pause(gid: String) async -> Result<Void, AppError> {
        let taskToCancel: Task<Void, Never>?
        do {
            schedulingBlockedGalleryIDs.insert(gid)
            defer {
                schedulingBlockedGalleryIDs.remove(gid)
            }
            guard let currentDownload = await fetchDownload(gid: gid) else {
                return .failure(.notFound)
            }
            guard [.queued, .downloading].contains(currentDownload.status) else {
                await notifyObservers()
                await scheduleNextIfNeeded()
                return .success(())
            }

            let initialCompletedPageCount = max(
                currentDownload.completedPageCount,
                temporaryCompletedPageCount(
                    gid: gid,
                    expectedPageCount: max(currentDownload.pageCount, 1)
                )
            )
            try await updateDownloadRecord(gid: gid, createIfMissing: false) { record in
                record.status = DownloadStatus.paused.rawValue
                record.completedPageCount = Int64(initialCompletedPageCount)
                record.lastError = nil
                record.lastDownloadedAt = .now
            }
            await notifyObservers()

            if activeGalleryID == gid {
                taskToCancel = activeTask
                activeTask?.cancel()
                activeTask = nil
                activeGalleryID = nil
            } else {
                taskToCancel = nil
            }
            await taskToCancel?.value
            let settledCompletedPageCount = max(
                currentDownload.completedPageCount,
                temporaryCompletedPageCount(
                    gid: gid,
                    expectedPageCount: max(currentDownload.pageCount, 1)
                )
            )
            try await updateDownloadRecord(gid: gid, createIfMissing: false) { record in
                record.status = DownloadStatus.paused.rawValue
                record.completedPageCount = Int64(settledCompletedPageCount)
                record.lastError = nil
                record.lastDownloadedAt = .now
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

    private func cancelQueuedWorkItem(
        _ download: DownloadedGallery,
        mode: DownloadStartMode
    ) async -> Result<Void, AppError> {
        switch mode {
        case .initial:
            return await pause(gid: download.gid)
        case .redownload, .update, .repair:
            break
        }

        let restoredStatus = download.status
        let restoredCompletedPageCount = validatedCompletedPageCount(download)
        do {
            try await updateDownloadRecord(gid: download.gid, createIfMissing: false) { record in
                record.status = restoredStatus.rawValue
                record.completedPageCount = Int64(restoredCompletedPageCount)
                record.lastDownloadedAt = .now
                record.pendingOperation = nil
            }
            await notifyObservers()
            return .success(())
        } catch let error as AppError {
            return .failure(error)
        } catch {
            Logger.error(error)
            return .failure(.unknown)
        }
    }

    private func resume(gid: String) async -> Result<Void, AppError> {
        guard await fetchDownload(gid: gid) != nil else {
            return .failure(.notFound)
        }

        do {
            // If another gallery is already active, keep this task in the queue and let the
            // temporary resume state decide whether it resumes an update/redownload/repair later.
            let resumedStatus: DownloadStatus = activeTask == nil ? .downloading : .queued
            try await updateDownloadRecord(gid: gid, createIfMissing: false) { record in
                record.status = resumedStatus.rawValue
                record.lastError = nil
                record.lastDownloadedAt = .now
                record.pendingOperation = nil
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

    private func resumeMode(for download: DownloadedGallery) -> DownloadStartMode {
        if download.remoteVersionSignature.isEmpty {
            return .initial
        }
        if download.hasUpdate {
            return .update
        }
        if let mode = readResumeMode(gid: download.gid) {
            return effectiveRetryMode(for: download, requestedMode: mode)
        }
        if download.status == .partial {
            return effectiveRetryMode(
                for: download,
                requestedMode: download.remoteVersionSignature.isEmpty ? .initial : .redownload
            )
        }
        if case .missingFiles = storage.validate(download: download) {
            return .repair
        }
        return .redownload
    }

    private func effectiveRetryMode(
        for download: DownloadedGallery,
        requestedMode: DownloadStartMode
    ) -> DownloadStartMode {
        guard requestedMode != .initial, download.hasUpdate else {
            return requestedMode
        }
        return .update
    }

    private func preferredVersionSignature(
        for download: DownloadedGallery,
        mode: DownloadStartMode,
        resumeState: DownloadResumeState?
    ) -> String {
        switch mode {
        case .update:
            if let latestSignature = download.latestRemoteVersionSignature,
               latestSignature.notEmpty
            {
                return latestSignature
            }
        case .initial, .redownload, .repair:
            break
        }

        if let resumeState,
           resumeState.versionSignature.notEmpty
        {
            return resumeState.versionSignature
        }

        if download.remoteVersionSignature.notEmpty {
            return download.remoteVersionSignature
        }

        return download.latestRemoteVersionSignature ?? ""
    }

    private func preferredWorkingPageCount(
        for download: DownloadedGallery,
        mode: DownloadStartMode,
        versionSignature: String,
        resumeState: DownloadResumeState?
    ) -> Int {
        guard mode == .update else {
            return download.pageCount
        }

        let temporaryFolderURL = storage.temporaryFolderURL(gid: download.gid)
        guard fileManager().fileExists(atPath: temporaryFolderURL.path) else {
            return download.pageCount
        }

        if let manifest = try? storage.readManifest(folderURL: temporaryFolderURL),
           manifest.gid == download.gid,
           manifest.versionSignature == versionSignature
        {
            return manifest.pageCount
        }

        if let resumeState,
           resumeState.versionSignature == versionSignature
        {
            return resumeState.pageCount
        }

        return download.pageCount
    }

    private func shouldResumeExistingWorkingSet(
        for download: DownloadedGallery,
        mode: DownloadStartMode,
        resumeState: DownloadResumeState?
    ) -> Bool {
        guard download.status == .failed || storage.temporaryFolderExists(gid: download.gid),
              let resumeState
        else {
            return false
        }

        let versionSignature = preferredVersionSignature(
            for: download,
            mode: mode,
            resumeState: resumeState
        )
        let pageCount = preferredWorkingPageCount(
            for: download,
            mode: mode,
            versionSignature: versionSignature,
            resumeState: resumeState
        )

        guard resumeState.mode == mode,
              resumeState.versionSignature == versionSignature,
              resumeState.downloadOptions == download.downloadOptionsSnapshot
        else {
            return false
        }

        if mode == .update,
           let manifest = try? storage.readManifest(
               folderURL: storage.temporaryFolderURL(gid: download.gid)
           ),
           manifest.gid == download.gid,
           manifest.versionSignature == versionSignature
        {
            return manifest.pageCount == pageCount
        }

        return resumeState.pageCount == pageCount
    }

    private func readResumeMode(gid: String) -> DownloadStartMode? {
        let folderURL = storage.temporaryFolderURL(gid: gid)
        return try? storage.readResumeState(folderURL: folderURL).mode
    }

    private func fallbackStatus(
        for download: DownloadedGallery,
        mode: DownloadStartMode,
        latestSignature: String?
    ) -> DownloadStatus {
        let comparison = DownloadSignatureBuilder.hasUpdateComparison(
            remoteVersionSignature: download.remoteVersionSignature,
            latestRemoteVersionSignature: latestSignature,
            gid: download.gid,
            token: download.token
        )
        let shouldKeepUpdateBadge = mode == .update
            || download.status == .updateAvailable
            || comparison == .different
        return shouldKeepUpdateBadge ? .updateAvailable : .completed
    }

    private func persistFailure(
        gid: String,
        error: AppError,
        originalDownload: DownloadedGallery,
        mode: DownloadStartMode,
        hadReadableFiles: Bool,
        latestSignature: String?
    ) async {
        let workingCompletedPageCount = temporaryCompletedPageCount(
            gid: gid,
            expectedPageCount: originalDownload.pageCount
        )
        let hasTemporaryWorkingSet = storage.temporaryFolderExists(gid: gid)
        let recoveredCompletedPageCount = hasTemporaryWorkingSet
            ? workingCompletedPageCount
            : max(originalDownload.completedPageCount, workingCompletedPageCount)
        do {
            try await updateDownloadRecord(gid: gid, createIfMissing: false) { record in
                record.lastError = DownloadFailure(error: error).toData()
                record.pendingOperation = nil
                if mode == .repair {
                    record.status = DownloadStatus.missingFiles.rawValue
                    record.completedPageCount = Int64(originalDownload.completedPageCount)
                    record.folderRelativePath = originalDownload.folderRelativePath
                    record.coverRelativePath = originalDownload.coverRelativePath
                    record.remoteVersionSignature = originalDownload.remoteVersionSignature
                    record.latestRemoteVersionSignature = latestSignature
                        ?? originalDownload.latestRemoteVersionSignature
                } else if hadReadableFiles, [.update, .redownload].contains(mode) {
                    record.status = self.fallbackStatus(
                        for: originalDownload,
                        mode: mode,
                        latestSignature: latestSignature
                    )
                    .rawValue
                    record.completedPageCount = Int64(originalDownload.pageCount)
                    record.folderRelativePath = originalDownload.folderRelativePath
                    record.coverRelativePath = originalDownload.coverRelativePath
                    record.remoteVersionSignature = originalDownload.remoteVersionSignature
                    record.latestRemoteVersionSignature = latestSignature
                        ?? originalDownload.latestRemoteVersionSignature
                } else if workingCompletedPageCount > 0 {
                    record.status = DownloadStatus.partial.rawValue
                    record.completedPageCount = Int64(workingCompletedPageCount)
                    record.latestRemoteVersionSignature = latestSignature
                        ?? originalDownload.latestRemoteVersionSignature
                } else {
                    record.status = DownloadStatus.partial.rawValue
                    record.completedPageCount = Int64(recoveredCompletedPageCount)
                    record.latestRemoteVersionSignature = latestSignature
                        ?? originalDownload.latestRemoteVersionSignature
                }
            }
        } catch {
            Logger.error(error)
        }
    }

    private func fetchLatestPayload(
        for download: DownloadedGallery,
        mode: DownloadStartMode,
        pageSelection: [Int]?
    ) async throws -> (DownloadRequestPayload, String) {
        let galleryURL = download.gallery.galleryURL
        guard let galleryURL else { throw AppError.notFound }
        let (detail, galleryState) = try await withRetry(
            operation: "fetchLatestPayload",
            context: [
                "gid": download.gid,
                "mode": mode.rawValue,
                "galleryURL": galleryURL.absoluteString
            ]
        ) {
            let doc = try await htmlDocument(
                url: URLUtil.galleryDetail(url: galleryURL),
                allowsCellular: download.downloadOptionsSnapshot.allowCellular,
                retriesRequest: false
            )
            return try Parser.parseGalleryDetail(doc: doc, gid: download.gid)
        }
        let gallery = Gallery(
            gid: download.gid,
            token: download.token,
            title: detail.title,
            rating: detail.rating,
            tags: galleryState.tags,
            category: detail.category,
            uploader: detail.uploader,
            pageCount: detail.pageCount,
            postedDate: detail.postedDate,
            coverURL: detail.coverURL ?? download.onlineCoverURL,
            galleryURL: galleryURL
        )
        let previewConfig = galleryState.previewConfig ?? .normal(rows: 4)
        let previewURLs = galleryState.previewURLs
        let versionMetadata: DownloadVersionMetadata?
        switch await GalleryVersionMetadataRequest(gid: download.gid, token: download.token).response() {
        case .success(let metadata):
            versionMetadata = metadata
        case .failure:
            versionMetadata = nil
        }
        let versionSignature = DownloadSignatureBuilder.make(
            gallery: gallery,
            detail: detail,
            host: download.host,
            previewURLs: previewURLs,
            versionMetadata: versionMetadata
        )
        return (
            .init(
                gallery: gallery,
                galleryDetail: detail,
                previewURLs: previewURLs,
                previewConfig: previewConfig,
                host: download.host,
                versionMetadata: versionMetadata,
                options: download.downloadOptionsSnapshot,
                mode: mode,
                pageSelection: pageSelection.map(Set.init)
            ),
            versionSignature
        )
    }

    private func normalizeFetchedPayload(
        _ payload: DownloadRequestPayload,
        mode: DownloadStartMode,
        versionSignature: String,
        existingResumeState: DownloadResumeState?,
        rawPageSelection: [Int]?
    ) -> DownloadRequestPayload {
        let shouldPreservePageSelection = rawPageSelection?.isEmpty == false
            && existingResumeState?.matches(
                mode: mode,
                versionSignature: versionSignature,
                pageCount: payload.galleryDetail.pageCount,
                downloadOptions: payload.options
            ) == true
            && mode != .update

        guard !shouldPreservePageSelection else {
            return payload
        }

        return .init(
            gallery: payload.gallery,
            galleryDetail: payload.galleryDetail,
            previewURLs: payload.previewURLs,
            previewConfig: payload.previewConfig,
            host: payload.host,
            versionMetadata: payload.versionMetadata,
            options: payload.options,
            mode: payload.mode,
            pageSelection: nil
        )
    }

    private func performDownload(
        payload: DownloadRequestPayload,
        versionSignature: String,
        folderRelativePath: String,
        existingDownload: DownloadedGallery
    ) async throws -> (coverRelativePath: String?, pages: [PageResult]) {
        try storage.ensureRootDirectory()

        let temporaryFolderURL = storage.temporaryFolderURL(gid: payload.gallery.gid)
        let workingSeed = try prepareWorkingSeed(
            payload: payload,
            existingDownload: existingDownload,
            temporaryFolderURL: temporaryFolderURL,
            versionSignature: versionSignature
        )
        let pendingPageIndices = pendingPageIndices(
            payload: payload,
            folderURL: temporaryFolderURL,
            existingPageRelativePaths: workingSeed.existingPages
        )
        try storage.writeResumeState(
            .init(
                mode: payload.mode,
                versionSignature: versionSignature,
                pageCount: payload.galleryDetail.pageCount,
                downloadOptions: payload.options,
                pageSelection: payload.pageSelection?.sorted()
            ),
            folderURL: temporaryFolderURL
        )

        do {
            let storedGalleryImageState = await fetchCachedGalleryImageState(gid: payload.gallery.gid)
            let coverRelativePath = try await downloadCoverImage(
                payload: payload,
                temporaryFolderURL: temporaryFolderURL,
                existingCoverRelativePath: workingSeed.coverRelativePath
            )
            if coverRelativePath != existingDownload.coverRelativePath {
                try? await updateDownloadRecord(
                    gid: payload.gallery.gid,
                    createIfMissing: false
                ) { record in
                    record.coverRelativePath = coverRelativePath
                }
            }
            let canSatisfyPendingPagesFromCache = await canSatisfyPendingPageDownloadsFromCache(
                pendingPageIndices: pendingPageIndices,
                temporaryFolderURL: temporaryFolderURL,
                existingPageRelativePaths: workingSeed.existingPages,
                storedGalleryImageState: storedGalleryImageState
            )
            let source: ResolvedSource?
            if pendingPageIndices.isEmpty || canSatisfyPendingPagesFromCache {
                source = nil
            } else {
                source = try await resolveSource(
                    payload: payload,
                    requiredPageIndices: pendingPageIndices
                )
            }
            let batchResult = try await downloadPages(
                payload: payload,
                pendingPageIndices: pendingPageIndices,
                source: source,
                temporaryFolderURL: temporaryFolderURL,
                existingManifest: workingSeed.manifest,
                existingPageRelativePaths: workingSeed.existingPages,
                storedGalleryImageState: storedGalleryImageState
            )
            if payload.pageSelection != nil {
                try? storage.writeResumeState(
                    .init(
                        mode: payload.mode,
                        versionSignature: versionSignature,
                        pageCount: payload.galleryDetail.pageCount,
                        downloadOptions: payload.options
                    ),
                    folderURL: temporaryFolderURL
                )
            }
            if !batchResult.failedPages.isEmpty {
                throw PartialDownloadError(failedPages: batchResult.failedPages)
            }

            let manifest = DownloadManifest(
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
                pageCount: payload.galleryDetail.pageCount,
                coverRelativePath: coverRelativePath,
                galleryURL: payload.gallery.galleryURL.forceUnwrapped,
                rating: payload.galleryDetail.rating,
                downloadOptions: payload.options,
                versionSignature: versionSignature,
                downloadedAt: .now,
                pages: batchResult.pages
                    .sorted(by: { $0.index < $1.index })
                    .map { .init(index: $0.index, relativePath: $0.relativePath) }
            )
            try storage.writeManifest(manifest, folderURL: temporaryFolderURL)
            try? storage.removeFailedPages(folderURL: temporaryFolderURL)
            try storage.replaceFolder(
                relativePath: folderRelativePath,
                with: temporaryFolderURL
            )
            cleanupCachedRemoteAssetsAfterSuccessfulDownload(
                payload: payload,
                storedGalleryImageState: storedGalleryImageState,
                pages: batchResult.pages,
                existingDownload: existingDownload
            )
            return (coverRelativePath, batchResult.pages)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw error
        }
    }

    private func downloadCoverImage(
        payload: DownloadRequestPayload,
        temporaryFolderURL: URL,
        existingCoverRelativePath: String?
    ) async throws -> String? {
        if let coverRelativePath = existingCoverRelativePath,
           !coverRelativePath.isEmpty
        {
            let localCoverURL = temporaryFolderURL.appendingPathComponent(coverRelativePath)
            if fileManager().fileExists(atPath: localCoverURL.path) {
                return coverRelativePath
            }
        }
        guard let coverURL = payload.galleryDetail.coverURL ?? payload.gallery.coverURL else {
            return nil
        }
        if let cachedData = await validatedCachedAssetData(for: [coverURL]) {
            let fileExtension = fileExtension(for: coverURL, response: nil, prefixData: cachedData)
            let relativePath = storage.makeCoverRelativePath(fileExtension: fileExtension)
            let fileURL = temporaryFolderURL.appendingPathComponent(relativePath)
            try write(data: cachedData, to: fileURL)
            return relativePath
        }
        let (downloadedFileURL, response) = try await downloadResponse(
            url: coverURL,
            allowsCellular: payload.options.allowCellular
        )
        let prefixData = try readResponsePrefixData(at: downloadedFileURL)
        let fileExtension = fileExtension(
            for: coverURL,
            response: response,
            prefixData: prefixData
        )
        let relativePath = storage.makeCoverRelativePath(fileExtension: fileExtension)
        let fileURL = temporaryFolderURL.appendingPathComponent(relativePath)
        try moveDownloadedFile(from: downloadedFileURL, to: fileURL)
        return relativePath
    }

    private func cleanupCachedRemoteAssetsAfterSuccessfulDownload(
        payload: DownloadRequestPayload,
        storedGalleryImageState: CachedGalleryImageState?,
        pages: [PageResult],
        existingDownload: DownloadedGallery
    ) {
        let previewURLs = (
            Array(payload.previewURLs.values)
                + (storedGalleryImageState.map { Array($0.previewURLs.values) } ?? [])
        )
        .flatMap { $0.previewCacheCleanupURLs() }
        let pageURLs = pages.compactMap(\.imageURL)
            + (storedGalleryImageState.map { Array($0.imageURLs.values) } ?? [])
        let coverURLs = [
            payload.galleryDetail.coverURL,
            payload.gallery.coverURL,
            existingDownload.onlineCoverURL
        ]
        .compactMap(\.self)

        let urls = Array(Set(previewURLs + pageURLs + coverURLs)).map(Optional.some)
        removeCachedImages(for: urls, includeStableAlias: true)
    }

    private func resolveSource(
        payload: DownloadRequestPayload,
        requiredPageIndices: [Int]
    ) async throws -> ResolvedSource {
        let requiredPageNumbers = Array(
            Set(requiredPageIndices.map { payload.previewConfig.pageNumber(index: $0) })
        )
        .sorted()
        var thumbnailURLs = [Int: URL]()
        for pageNumber in requiredPageNumbers {
            let pageURLs = try await fetchThumbnailURLs(
                galleryURL: payload.gallery.galleryURL.forceUnwrapped,
                pageNum: pageNumber,
                allowsCellular: payload.options.allowCellular
            )
            thumbnailURLs.merge(pageURLs, uniquingKeysWith: { _, new in new })
        }
        guard let firstURL = requiredPageIndices.lazy.compactMap({ thumbnailURLs[$0] }).first
            ?? thumbnailURLs.values.first
        else {
            throw AppError.notFound
        }
        if firstURL.pathComponents.count > 1, firstURL.pathComponents[1] == "mpv" {
            let (mpvKey, imageKeys) = try await fetchMPVKeys(
                mpvURL: firstURL,
                allowsCellular: payload.options.allowCellular
            )
            return .mpv(mpvKey, imageKeys)
        } else {
            return .normal(thumbnailURLs)
        }
    }

    private func downloadPages(
        payload: DownloadRequestPayload,
        pendingPageIndices: [Int],
        source: ResolvedSource?,
        temporaryFolderURL: URL,
        existingManifest: DownloadManifest?,
        existingPageRelativePaths: [Int: String],
        storedGalleryImageState: CachedGalleryImageState?
    ) async throws -> DownloadBatchResult {
        let manifestPages = Dictionary(
            uniqueKeysWithValues: (existingManifest?.pages ?? []).map { ($0.index, $0.relativePath) }
        )
        let existingPages = manifestPages.merging(
            existingPageRelativePaths,
            uniquingKeysWith: { manifestPath, _ in manifestPath }
        )
        var failedPages = (try? storage.readFailedPages(folderURL: temporaryFolderURL).map) ?? [:]
        let pageIndices = Array(1...payload.galleryDetail.pageCount)
        var results = [PageResult]()
        for index in pageIndices {
            guard let relativePath = existingPages[index] else { continue }
            let fileURL = temporaryFolderURL.appendingPathComponent(relativePath)
            guard fileManager().fileExists(atPath: fileURL.path) else { continue }
            failedPages[index] = nil
            results.append(
                .init(
                    index: index,
                    relativePath: relativePath,
                    imageURL: storedGalleryImageState?.imageURLs[index]
                )
            )
        }
        var completedCount = results.count
        var pendingResolvedPages = [PageResult]()
        var lastFlushDate = Date()

        if completedCount > 0 {
            try await updateDownloadRecord(gid: payload.gallery.gid, createIfMissing: false) { record in
                record.completedPageCount = Int64(completedCount)
            }
            await notifyObservers()
        }

        let restoredCachedPages = try await restorePendingPagesFromStoredCache(
            indices: pendingPageIndices,
            temporaryFolderURL: temporaryFolderURL,
            existingPages: existingPages,
            storedGalleryImageState: storedGalleryImageState
        )
        if !restoredCachedPages.isEmpty {
            restoredCachedPages.forEach {
                failedPages[$0.index] = nil
                results.append($0)
            }
            completedCount += restoredCachedPages.count
            pendingResolvedPages.append(contentsOf: restoredCachedPages)
            try await flushDownloadProgress(
                gid: payload.gallery.gid,
                pendingResolvedPages: &pendingResolvedPages,
                completedCount: completedCount,
                lastFlushDate: &lastFlushDate,
                force: true
            )
        }

        let restoredIndices = Set(restoredCachedPages.map(\.index))
        let remainingPageIndices = pendingPageIndices.filter { !restoredIndices.contains($0) }
        var wasCancelled = false
        await withTaskGroup(of: PageTaskOutcome.self) { group in
            var pendingIterator = remainingPageIndices.makeIterator()
            for _ in 0..<min(payload.options.workerCount, remainingPageIndices.count) {
                guard let index = pendingIterator.next() else { break }
                group.addTask {
                    do {
                        return .success(
                            try await self.downloadPage(
                                index: index,
                                payload: payload,
                                source: source,
                                temporaryFolderURL: temporaryFolderURL,
                                preferredRelativePath: existingPages[index],
                                storedGalleryImageState: storedGalleryImageState
                            )
                        )
                    } catch is CancellationError {
                        return .cancelled
                    } catch let error as AppError {
                        return .failure(
                            .init(
                                index: index,
                                relativePath: existingPages[index],
                                error: error
                            )
                        )
                    } catch {
                        if Self.isCancellationLikeError(error) {
                            return .cancelled
                        }
                        return .failure(
                            .init(
                                index: index,
                                relativePath: existingPages[index],
                                error: .fileOperationFailed(error.localizedDescription)
                            )
                        )
                    }
                }
            }

            while let result = await group.next() {
                if wasCancelled || Task.isCancelled || schedulingBlockedGalleryIDs.contains(payload.gallery.gid) {
                    wasCancelled = true
                    group.cancelAll()
                    continue
                }

                switch result {
                case .success(let pageResult):
                    completedCount += 1
                    failedPages[pageResult.index] = nil
                    results.append(pageResult)
                    pendingResolvedPages.append(pageResult)
                    try? await flushDownloadProgress(
                        gid: payload.gallery.gid,
                        pendingResolvedPages: &pendingResolvedPages,
                        completedCount: completedCount,
                        lastFlushDate: &lastFlushDate,
                        force: false
                    )

                case .failure(let failure):
                    if isCancellationLikeAppError(failure.error) {
                        wasCancelled = true
                        group.cancelAll()
                        continue
                    }
                    failedPages[failure.index] = .init(
                        index: failure.index,
                        relativePath: failure.relativePath,
                        failure: .init(error: failure.error)
                    )

                case .cancelled:
                    wasCancelled = true
                    group.cancelAll()
                    continue
                }

                guard !wasCancelled else { continue }
                if let nextIndex = pendingIterator.next() {
                    group.addTask {
                        do {
                            return .success(
                                try await self.downloadPage(
                                    index: nextIndex,
                                    payload: payload,
                                    source: source,
                                    temporaryFolderURL: temporaryFolderURL,
                                    preferredRelativePath: existingPages[nextIndex],
                                    storedGalleryImageState: storedGalleryImageState
                                )
                            )
                        } catch is CancellationError {
                            return .cancelled
                        } catch let error as AppError {
                            return .failure(
                                .init(
                                    index: nextIndex,
                                    relativePath: existingPages[nextIndex],
                                    error: error
                                )
                            )
                        } catch {
                            if Self.isCancellationLikeError(error) {
                                return .cancelled
                            }
                            return .failure(
                                .init(
                                    index: nextIndex,
                                    relativePath: existingPages[nextIndex],
                                    error: .fileOperationFailed(error.localizedDescription)
                                )
                            )
                        }
                    }
                }
            }
        }

        if wasCancelled || Task.isCancelled {
            throw CancellationError()
        }

        try await flushDownloadProgress(
            gid: payload.gallery.gid,
            pendingResolvedPages: &pendingResolvedPages,
            completedCount: completedCount,
            lastFlushDate: &lastFlushDate,
            force: true
        )

        let failedSnapshot = DownloadFailedPagesSnapshot(
            pages: failedPages.values
                .filter { !isCancellationLikeAppError($0.failure.appError) }
                .sorted(by: { $0.index < $1.index })
        )
        if failedSnapshot.pages.isEmpty {
            try? storage.removeFailedPages(folderURL: temporaryFolderURL)
        } else {
            try storage.writeFailedPages(failedSnapshot, folderURL: temporaryFolderURL)
        }

        return .init(
            pages: results,
            failedPages: failedSnapshot.pages
        )
    }

    private func downloadPage(
        index: Int,
        payload: DownloadRequestPayload,
        source: ResolvedSource?,
        temporaryFolderURL: URL,
        preferredRelativePath: String?,
        storedGalleryImageState: CachedGalleryImageState?
    ) async throws -> PageResult {
        let attempts = payload.options.autoRetryFailedPages ? 2 : 1
        var capturedError: AppError = .unknown

        for _ in 0..<attempts {
            do {
                let storedCacheURLs = pageImageCacheURLs(
                    resolvedImageSource: nil,
                    index: index,
                    storedGalleryImageState: storedGalleryImageState
                )
                if let pageResult = try await restorePageFromCache(
                    index: index,
                    cacheURLs: storedCacheURLs,
                    folderURL: temporaryFolderURL,
                    preferredRelativePath: preferredRelativePath,
                    referenceURL: storedCacheURLs.compactMap(\.self).first,
                    imageURL: storedGalleryImageState?.imageURLs[index]
                ) {
                    return pageResult
                }
                guard let source else { throw AppError.notFound }
                let resolvedImageSource = try await resolvedImageSource(
                    index: index,
                    payload: payload,
                    source: source,
                    retriesRequest: false
                )
                let resolvedCacheURLs = pageImageCacheURLs(
                    resolvedImageSource: resolvedImageSource,
                    index: index,
                    storedGalleryImageState: storedGalleryImageState
                )
                if let pageResult = try await restorePageFromCache(
                    index: index,
                    cacheURLs: resolvedCacheURLs,
                    folderURL: temporaryFolderURL,
                    preferredRelativePath: preferredRelativePath,
                    referenceURL: preferredPageReferenceURL(resolvedImageSource: resolvedImageSource),
                    imageURL: resolvedImageSource.imageURL
                ) {
                    return pageResult
                }
                // Offline download intentionally stays on the normal image URL path.
                let targetURL = resolvedImageSource.imageURL
                let (downloadedFileURL, response) = try await downloadResponse(
                    url: targetURL,
                    allowsCellular: payload.options.allowCellular,
                    retriesRequest: false
                )
                let relativePath: String
                if let preferredRelativePath {
                    relativePath = preferredRelativePath
                } else {
                    let prefixData = try readResponsePrefixData(at: downloadedFileURL)
                    let fileExtension = fileExtension(
                        for: targetURL,
                        response: response,
                        prefixData: prefixData
                    )
                    relativePath = storage.makePageRelativePath(
                        index: index,
                        fileExtension: fileExtension
                    )
                }
                let fileURL = temporaryFolderURL.appendingPathComponent(relativePath)
                try moveDownloadedFile(from: downloadedFileURL, to: fileURL)
                return .init(
                    index: index,
                    relativePath: relativePath,
                    imageURL: resolvedImageSource.imageURL
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as AppError {
                capturedError = error
                guard error.isRetryable else { throw error }
            } catch {
                if Self.isCancellationLikeError(error) {
                    throw CancellationError()
                }
                throw error
            }
        }

        throw capturedError
    }

    private func prepareWorkingSeed(
        payload: DownloadRequestPayload,
        existingDownload: DownloadedGallery,
        temporaryFolderURL: URL,
        versionSignature: String
    ) throws -> WorkingSeed {
        let fileManager = fileManager()
        let resumeState = try? storage.readResumeState(folderURL: temporaryFolderURL)
        let shouldReuseTemporaryFolder = resumeState?.matches(
            mode: payload.mode,
            versionSignature: versionSignature,
            pageCount: payload.galleryDetail.pageCount,
            downloadOptions: payload.options
        ) == true
            && fileManager.fileExists(atPath: temporaryFolderURL.path)

        if !shouldReuseTemporaryFolder {
            try? fileManager.removeItem(at: temporaryFolderURL)
        }

        if !fileManager.fileExists(atPath: temporaryFolderURL.path) {
            if let repairSeed = repairSeed(
                for: existingDownload,
                payload: payload,
                versionSignature: versionSignature
            ) {
                try storage.materializeRepairSeed(
                    from: repairSeed.folderURL,
                    manifest: repairSeed.manifest,
                    to: temporaryFolderURL
                )
            } else {
                try createDirectory(at: temporaryFolderURL)
            }
        }

        let pagesFolderURL = temporaryFolderURL.appendingPathComponent(
            Defaults.FilePath.downloadPages,
            isDirectory: true
        )
        try createDirectory(at: pagesFolderURL)

        let manifest = validatedManifest(
            at: temporaryFolderURL,
            gid: payload.gallery.gid,
            pageCount: payload.galleryDetail.pageCount,
            versionSignature: versionSignature,
            downloadOptions: payload.options
        )
        let existingPages = storage.existingPageRelativePaths(
            folderURL: temporaryFolderURL,
            expectedPageCount: payload.galleryDetail.pageCount
        )
        let coverRelativePath = manifest?.coverRelativePath
            ?? storage.existingCoverRelativePath(folderURL: temporaryFolderURL)

        return .init(
            folderURL: temporaryFolderURL,
            manifest: manifest,
            existingPages: existingPages,
            coverRelativePath: coverRelativePath
        )
    }

    private func resolvedImageSource(
        index: Int,
        payload: DownloadRequestPayload,
        source: ResolvedSource,
        retriesRequest: Bool
    ) async throws -> ResolvedImageSource {
        switch source {
        case .normal(let thumbnailURLs):
            guard let thumbnailURL = thumbnailURLs[index] else { throw AppError.notFound }
            let doc = try await htmlDocument(
                url: thumbnailURL,
                allowsCellular: payload.options.allowCellular,
                retriesRequest: retriesRequest
            )
            let (_, imageURL, _) = try Parser.parseGalleryNormalImageURL(
                doc: doc,
                index: index
            )
            return .init(imageURL: imageURL)

        case .mpv(let mpvKey, let imageKeys):
            guard let imageKey = imageKeys[index] else { throw AppError.notFound }
            let imageURL = try await fetchMPVImageURL(
                host: payload.host,
                gid: payload.gallery.gid,
                index: index,
                mpvKey: mpvKey,
                imageKey: imageKey,
                allowsCellular: payload.options.allowCellular,
                retriesRequest: retriesRequest
            )
            return .init(imageURL: imageURL)
        }
    }

    private func repairSeed(
        for download: DownloadedGallery,
        payload: DownloadRequestPayload,
        versionSignature: String
    ) -> RepairSeed? {
        guard payload.mode == .repair,
              let folderURL = download.resolvedFolderURL(rootURL: storage.rootURL),
              fileManager().fileExists(atPath: folderURL.path),
              let manifest = try? storage.readManifest(folderURL: folderURL),
              manifest.gid == download.gid,
              manifest.pageCount == payload.galleryDetail.pageCount,
              manifest.pages.count == manifest.pageCount,
              manifest.versionSignature == versionSignature
        else {
            return nil
        }
        return .init(folderURL: folderURL, manifest: manifest)
    }

    private func fetchThumbnailURLs(
        galleryURL: URL,
        pageNum: Int,
        allowsCellular: Bool
    ) async throws -> [Int: URL] {
        let detailPageURL = URLUtil.detailPage(url: galleryURL, pageNum: pageNum)
        let urls = try await withRetry(
            operation: "fetchThumbnailURLs",
            context: [
                "galleryURL": galleryURL.absoluteString,
                "detailPageURL": detailPageURL.absoluteString,
                "pageNum": pageNum
            ]
        ) {
            let doc = try await htmlDocument(
                url: detailPageURL,
                allowsCellular: allowsCellular,
                retriesRequest: false
            )
            return try Parser.parseThumbnailURLs(doc: doc)
        }
        guard !urls.isEmpty else { throw AppError.notFound }
        return urls
    }

    private func fetchMPVKeys(
        mpvURL: URL,
        allowsCellular: Bool
    ) async throws -> (String, [Int: String]) {
        try await withRetry(
            operation: "fetchMPVKeys",
            context: [
                "mpvURL": mpvURL.absoluteString
            ]
        ) {
            let doc = try await htmlDocument(
                url: mpvURL,
                allowsCellular: allowsCellular,
                retriesRequest: false
            )
            return try Parser.parseMPVKeys(doc: doc)
        }
    }

    private func fetchMPVImageURL(
        host: GalleryHost,
        gid: String,
        index: Int,
        mpvKey: String,
        imageKey: String,
        allowsCellular: Bool,
        retriesRequest: Bool = true
    ) async throws -> URL {
        guard let gidInteger = Int(gid) else { throw AppError.notFound }
        let params: [String: Any] = [
            "method": "imagedispatch",
            "gid": gidInteger,
            "page": index,
            "imgkey": imageKey,
            "mpvkey": mpvKey
        ]

        var request = URLRequest(url: host.url.appendingPathComponent("api.php"))
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: params)
        request.allowsCellularAccess = allowsCellular

        let (data, response) = try await dataResponse(for: request, retriesRequest: retriesRequest)
        if let error = detectResponseError(
            data: data,
            response: response,
            requestURL: request.url
        ) {
            throw error
        }
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let imageURLString = dictionary["i"] as? String,
              let imageURL = URL(string: imageURLString)
        else {
            throw AppError.parseFailed
        }
        return imageURL
    }

    private func htmlDocument(
        url: URL,
        allowsCellular: Bool,
        retriesRequest: Bool = true
    ) async throws -> HTMLDocument {
        var request = URLRequest(url: url)
        request.allowsCellularAccess = allowsCellular
        let (data, response) = try await dataResponse(for: request, retriesRequest: retriesRequest)
        if let error = detectResponseError(
            data: data,
            response: response,
            requestURL: request.url,
            expectsHTML: true
        ) {
            throw error
        }
        if let document = try? Kanna.HTML(html: data, encoding: .utf8) {
            return document
        }
        if let document = try? Kanna.HTML(
            html: data.utf8InvalidCharactersRipped,
            encoding: .utf8
        ) {
            return document
        }
        throw AppError.parseFailed
    }

    private func downloadResponse(
        url: URL,
        allowsCellular: Bool,
        retriesRequest: Bool = true
    ) async throws -> (URL, URLResponse) {
        var request = URLRequest(url: url)
        request.allowsCellularAccess = allowsCellular
        return try await downloadResponse(for: request, retriesRequest: retriesRequest)
    }

    private func downloadResponse(
        for request: URLRequest,
        retriesRequest: Bool = true
    ) async throws -> (URL, URLResponse) {
        let performRequest = {
            try await self.rawDownloadResponse(for: request)
        }

        let response: (URL, URLResponse)
        if retriesRequest {
            response = try await withRetry(
                operation: "downloadResponse",
                context: [
                    "url": request.url?.absoluteString ?? ""
                ]
            ) {
                try await performRequest()
            }
        } else {
            response = try await performRequest()
        }

        if let error = detectResponseError(
            fileURL: response.0,
            response: response.1,
            requestURL: request.url
        ) {
            try? fileManager().removeItem(at: response.0)
            throw error
        }

        return response
    }

    private func dataResponse(
        for request: URLRequest,
        retriesRequest: Bool = true
    ) async throws -> (Data, URLResponse) {
        if retriesRequest {
            return try await withRetry(
                operation: "dataResponse",
                context: [
                    "url": request.url?.absoluteString ?? ""
                ]
            ) {
                try await rawDataResponse(for: request)
            }
        }
        return try await rawDataResponse(for: request)
    }

    private func rawDataResponse(for request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await urlSession.data(for: request)
        } catch let error as AppError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            if Self.isCancellationLikeError(error) {
                throw CancellationError()
            }
            if error is URLError {
                throw AppError.networkingFailed
            }
            throw AppError.unknown
        }
    }

    private func rawDownloadResponse(for request: URLRequest) async throws -> (URL, URLResponse) {
        do {
            return try await urlSession.download(for: request)
        } catch let error as AppError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            if Self.isCancellationLikeError(error) {
                throw CancellationError()
            }
            if error is URLError {
                throw AppError.networkingFailed
            }
            throw AppError.unknown
        }
    }

    private func detectResponseError(
        data: Data,
        response: URLResponse,
        requestURL: URL?,
        expectsHTML: Bool = false
    ) -> AppError? {
        detectResponseError(
            prefixData: Data(data.prefix(Self.responseInspectionPrefixLength)),
            fullData: data,
            response: response,
            requestURL: requestURL,
            expectsHTML: expectsHTML
        )
    }

    private func detectResponseError(
        fileURL: URL,
        response: URLResponse,
        requestURL: URL?
    ) -> AppError? {
        let prefixData = (try? readResponsePrefixData(at: fileURL)) ?? Data()
        let placeholderData: Data?
        if let byteCount = responseContentLength(response) ?? fileSize(at: fileURL),
           byteCount == Self.kokomadeImageByteCount
                || byteCount == Self.quotaExceededImageByteCount
        {
            placeholderData = try? Data(contentsOf: fileURL, options: .mappedIfSafe)
        } else {
            placeholderData = nil
        }
        if let placeholderData {
            if isAuthenticationRequiredPlaceholderImageData(placeholderData) {
                return .authenticationRequired
            }
            if isQuotaExceededAssetData(placeholderData) {
                return .quotaExceeded
            }
        }
        if isAuthenticationRequiredPlaceholderResponse(
            response: response,
            requestURL: requestURL
        ) {
            return .authenticationRequired
        }
        if isQuotaExceededResponse(
            fullData: nil,
            fileURL: fileURL,
            response: response,
            requestURL: requestURL
        ) {
            return .quotaExceeded
        }
        let mimeType = normalizedMimeType(response)
        let shouldInspect = shouldInspectTextResponse(
            mimeType: mimeType,
            prefixData: prefixData
        )
        guard shouldInspect else {
            if statusCode(for: response) == 404 {
                return .notFound
            }
            return nil
        }

        let looksLikeHTML = responseLooksLikeHTML(
            mimeType: mimeType,
            prefixData: prefixData,
            expectsHTML: false
        )
        let fullData = looksLikeHTML
            ? placeholderData ?? (try? Data(contentsOf: fileURL, options: .mappedIfSafe))
            : placeholderData

        return detectResponseError(
            prefixData: prefixData,
            fullData: fullData,
            response: response,
            requestURL: requestURL,
            expectsHTML: false
        )
    }

    private func detectResponseError(
        prefixData: Data,
        fullData: Data?,
        response: URLResponse,
        requestURL: URL?,
        expectsHTML: Bool
    ) -> AppError? {
        if let fullData {
            if isAuthenticationRequiredPlaceholderImageData(fullData) {
                return .authenticationRequired
            }
            if isQuotaExceededAssetData(fullData) {
                return .quotaExceeded
            }
        }
        if isAuthenticationRequiredPlaceholderResponse(
            response: response,
            requestURL: requestURL
        ) {
            return .authenticationRequired
        }
        if isQuotaExceededResponse(
            fullData: fullData,
            fileURL: nil,
            response: response,
            requestURL: requestURL
        ) {
            return .quotaExceeded
        }

        let mimeType = normalizedMimeType(response)
        let shouldInspect = expectsHTML || shouldInspectTextResponse(
            mimeType: mimeType,
            prefixData: prefixData
        )
        if shouldInspect {
            let inspectedData = fullData ?? prefixData
            if let error = detectTextualDownloadError(
                data: inspectedData,
                looksLikeHTML: responseLooksLikeHTML(
                    mimeType: mimeType,
                    prefixData: prefixData,
                    expectsHTML: expectsHTML
                )
            ) {
                return error
            }
        }
        if isAuthenticationRequiredResponse(
            prefixData: prefixData,
            fullData: fullData,
            response: response,
            requestURL: requestURL
        ) {
            return .authenticationRequired
        }
        guard shouldInspect else { return nil }

        let textPrefix = String(bytes: prefixData, encoding: .utf8) ?? ""

        let looksLikeHTML = responseLooksLikeHTML(
            mimeType: mimeType,
            prefixData: prefixData,
            expectsHTML: expectsHTML
        )
        guard looksLikeHTML else {
            if statusCode(for: response) == 404 {
                return .notFound
            }
            return nil
        }

        if let fullData,
           let document = try? Kanna.HTML(
            html: fullData.utf8InvalidCharactersRipped,
            encoding: .utf8
           ),
           let error = Parser.parseDownloadPageError(doc: document)
        {
            return error
        }
        if expectsHTML {
            if statusCode(for: response) == 404 {
                return .notFound
            }
            return nil
        }
        Logger.error(
            "Download received unexpected HTML response.",
            context: [
                "url": requestURL?.absoluteString ?? "",
                "snippet": String(textPrefix.prefix(240))
            ]
        )
        if statusCode(for: response) == 404 {
            return .notFound
        }
        return .parseFailed
    }

    private func withRetry<T>(
        operation: String,
        context: [String: Any],
        maxAttempts: Int = retryLimit,
        body: () async throws -> T
    ) async throws -> T {
        var attempt = 1
        while true {
            do {
                return try await body()
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as AppError {
                guard error.isRetryable, attempt < maxAttempts else {
                    throw error
                }
                Logger.error(
                    "Download operation will retry.",
                    context: context.merging([
                        "operation": operation,
                        "attempt": attempt,
                        "error": error.localizedDescription
                    ], uniquingKeysWith: { _, new in new })
                )
                attempt += 1
            } catch {
                guard attempt < maxAttempts else {
                    throw error
                }
                Logger.error(
                    "Download operation will retry after unexpected error.",
                    context: context.merging([
                        "operation": operation,
                        "attempt": attempt,
                        "error": error.localizedDescription
                    ], uniquingKeysWith: { _, new in new })
                )
                attempt += 1
            }
        }
    }

    private func fileExtension(
        for url: URL,
        response: URLResponse?,
        prefixData: Data
    ) -> String {
        if url.pathExtension.notEmpty {
            return url.pathExtension.lowercased()
        }
        if let mimeType = response?.mimeType?.lowercased() {
            switch mimeType {
            case "image/jpeg":
                return "jpg"
            case "image/png":
                return "png"
            case "image/gif":
                return "gif"
            case "image/webp":
                return "webp"
            default:
                break
            }
        }
        if prefixData.starts(with: [0x47, 0x49, 0x46]) {
            return "gif"
        }
        if prefixData.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        }
        if prefixData.starts(with: [0x52, 0x49, 0x46, 0x46]),
           prefixData.count >= 12,
           String(bytes: prefixData[8..<12], encoding: .utf8) == "WEBP"
        {
            return "webp"
        }
        return "jpg"
    }

    private func createDirectory(at url: URL) throws {
        try fileManager().createDirectory(at: url, withIntermediateDirectories: true)
    }

    private func write(data: Data, to url: URL) throws {
        try createDirectory(at: url.deletingLastPathComponent())
        try data.write(to: url, options: .atomic)
    }

    private func moveDownloadedFile(from sourceURL: URL, to destinationURL: URL) throws {
        try createDirectory(at: destinationURL.deletingLastPathComponent())
        if fileManager().fileExists(atPath: destinationURL.path) {
            try fileManager().removeItem(at: destinationURL)
        }
        try fileManager().moveItem(at: sourceURL, to: destinationURL)
    }

    private func readResponsePrefixData(at fileURL: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        return try handle.read(upToCount: Self.responseInspectionPrefixLength) ?? Data()
    }

    private func normalizedMimeType(_ response: URLResponse) -> String? {
        if let mimeType = response.mimeType?.lowercased(), mimeType.notEmpty {
            return mimeType
        }
        if let httpResponse = response as? HTTPURLResponse,
           let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased(),
           let mimeType = contentType.split(separator: ";").first,
           !mimeType.isEmpty
        {
            return String(mimeType)
        }
        return nil
    }

    private func shouldInspectTextResponse(
        mimeType: String?,
        prefixData: Data
    ) -> Bool {
        if let mimeType {
            if mimeType.hasPrefix("image/") {
                return prefixLooksLikeHTML(prefixData)
            }
            if mimeType == "text/html" || mimeType == "text/plain" {
                return true
            }
            return prefixLooksLikeHTML(prefixData)
        }

        guard !prefixIsKnownBinaryImage(prefixData) else {
            return false
        }
        return true
    }

    private func prefixLooksLikeHTML(_ prefixData: Data) -> Bool {
        let prefix = String(bytes: prefixData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard prefix.notEmpty else { return false }

        let htmlMarkers = [
            "<html",
            "<!doctype",
            "your ip address has been temporarily banned",
            "access to exhentai.org is restricted"
        ]
        return htmlMarkers.contains(where: prefix.contains)
    }

    private func responseLooksLikeHTML(
        mimeType: String?,
        prefixData: Data,
        expectsHTML: Bool
    ) -> Bool {
        expectsHTML
            || mimeType == "text/html"
            || prefixLooksLikeHTML(prefixData)
    }

    private func detectTextualDownloadError(
        data: Data,
        looksLikeHTML: Bool
    ) -> AppError? {
        let normalizedData = data.utf8InvalidCharactersRipped
        let rawContent = String(data: normalizedData, encoding: .utf8) ?? ""
        if !looksLikeHTML {
            return Parser.parseDownloadPageError(content: rawContent)
        }

        if let document = try? Kanna.HTML(
            html: normalizedData,
            encoding: .utf8
        ),
           let error = Parser.parseDownloadPageError(doc: document)
        {
            return error
        }

        guard rawContent.count <= 1024 else {
            return nil
        }
        return Parser.parseDownloadPageError(content: rawContent)
    }

    private func prefixIsKnownBinaryImage(_ prefixData: Data) -> Bool {
        prefixData.starts(with: [0xFF, 0xD8, 0xFF])
            || prefixData.starts(with: [0x89, 0x50, 0x4E, 0x47])
            || prefixData.starts(with: [0x47, 0x49, 0x46])
            || (
                prefixData.starts(with: [0x52, 0x49, 0x46, 0x46])
                    && prefixData.count >= 12
                    && String(bytes: prefixData[8..<12], encoding: .utf8) == "WEBP"
            )
    }

    private func isQuotaExceededResponse(
        fullData: Data?,
        fileURL: URL?,
        response: URLResponse,
        requestURL: URL?
    ) -> Bool {
        let urls = [requestURL, response.url].compactMap(\.self)
        let lowercasedURLs = urls.map { $0.absoluteString.lowercased() }
        guard lowercasedURLs.contains(where: { url in
            Self.quotaExceededImageURLSuffixes.contains(where: url.hasSuffix)
        }) else {
            return false
        }

        let byteCount = fullData?.count ?? responseContentLength(response) ?? fileSize(at: fileURL)
        guard byteCount == Self.quotaExceededImageByteCount else {
            return false
        }

        let data: Data?
        if let fullData {
            data = fullData
        } else if let fileURL {
            data = try? Data(contentsOf: fileURL, options: .mappedIfSafe)
        } else {
            data = nil
        }
        guard let data else { return false }
        return isQuotaExceededAssetData(data)
    }

    private func isAuthenticationRequiredPlaceholderResponse(
        response: URLResponse,
        requestURL: URL?
    ) -> Bool {
        [requestURL, response.url].contains { isAuthenticationRequiredPlaceholderURL($0) }
    }

    private func isAuthenticationRequiredPlaceholderURL(_ url: URL?) -> Bool {
        guard let url else { return false }
        let normalizedURL = url.absoluteString.lowercased()
        // JDownloader treats `bounce_login.php` as an account / re-login required signal for EH/EX.
        // Reference: https://github.com/mirror/jdownloader/blob/master/src/jd/plugins/hoster/EHentaiOrg.java
        if normalizedURL.contains("bounce_login.php") {
            return true
        }
        return isKokomadePlaceholderURL(url)
    }

    private func isKokomadePlaceholderURL(_ url: URL?) -> Bool {
        guard let url else { return false }
        let normalizedURL = url.absoluteString.lowercased()
        // Ex login failures commonly surface as a kokomade placeholder wall when `igneous` is missing.
        // Reference: https://github.com/OpportunityLiu/E-Viewer/issues/124
        return isExHentaiURL(url)
            && Self.kokomadeImageURLSuffixes.contains(where: normalizedURL.hasSuffix)
    }

    private func isAuthenticationRequiredResponse(
        prefixData: Data,
        fullData: Data?,
        response: URLResponse,
        requestURL: URL?
    ) -> Bool {
        guard isExHentaiURL(requestURL) || isExHentaiURL(response.url) else {
            return false
        }
        guard normalizedMimeType(response) == "text/html" else {
            return false
        }
        guard fullData?.isEmpty ?? prefixData.isEmpty else {
            return false
        }

        let cookies = responseCookies(response: response, requestURL: requestURL)
        let hasYay = cookies.contains {
            $0.name == Defaults.Cookie.yay && $0.value.notEmpty
        }
        let hasValidIgneous = cookies.contains {
            $0.name == Defaults.Cookie.igneous
                && $0.value.notEmpty
                && $0.value != Defaults.Cookie.mystery
        }
        return hasYay && !hasValidIgneous
    }

    private func responseCookies(
        response: URLResponse,
        requestURL: URL?
    ) -> [HTTPCookie] {
        let urls = [response.url, requestURL, Defaults.URL.exhentai, Defaults.URL.sexhentai]
            .compactMap(\.self)
        var uniqueURLs = [URL]()
        for url in urls where !uniqueURLs.contains(url) {
            uniqueURLs.append(url)
        }

        var cookies = [HTTPCookie]()
        if let httpResponse = response as? HTTPURLResponse,
           let responseURL = httpResponse.url
        {
            let headerFields = httpResponse.allHeaderFields.reduce(into: [String: String]()) { partial, item in
                guard let key = item.key as? String,
                      let value = item.value as? String
                else { return }
                partial[key] = value
            }
            cookies += HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: responseURL)
        }

        for url in uniqueURLs {
            cookies += HTTPCookieStorage.shared.cookies(for: url) ?? []
        }
        return cookies
    }

    private func isExHentaiURL(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else {
            return false
        }
        return host == "exhentai.org" || host.hasSuffix(".exhentai.org")
    }

    private func statusCode(for response: URLResponse) -> Int? {
        (response as? HTTPURLResponse)?.statusCode
    }

    private func responseContentLength(_ response: URLResponse) -> Int? {
        if response.expectedContentLength > 0 {
            return Int(response.expectedContentLength)
        }
        if let httpResponse = response as? HTTPURLResponse,
           let header = httpResponse.value(forHTTPHeaderField: "Content-Length"),
           let contentLength = Int(header)
        {
            return contentLength
        }
        return nil
    }

    private func fileSize(at fileURL: URL?) -> Int? {
        guard let fileURL else { return nil }
        let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize
    }

    private func fileManager() -> FileManager {
        storage.fileManager
    }

    private func cachedImageData(for url: URL) async -> Data? {
        await cachedImageData(for: [url], includeStableAlias: false)
    }

    private func cachedImageData(
        for urls: [URL?],
        includeStableAlias: Bool
    ) async -> Data? {
        let allKeys = urls
            .compactMap { $0 }
            .flatMap { cacheKeys(for: $0, includeStableAlias: includeStableAlias) }
        let keys = allKeys.reduce(into: [String]()) { partialResult, key in
            guard !partialResult.contains(key) else { return }
            partialResult.append(key)
        }

        for key in keys {
            if let data = await cachedImageData(forKey: key) {
                return data
            }
        }
        return nil
    }

    private func cachedImageData(forKey key: String) async -> Data? {
        if let image = KingfisherManager.shared.cache.retrieveImageInMemoryCache(forKey: key),
           let data = image.kf.data(format: .unknown)
        {
            return data
        }

        if let data = try? KingfisherManager.shared.cache.diskStorage.value(forKey: key) {
            return data
        }

        return await withCheckedContinuation { continuation in
            KingfisherManager.shared.cache.retrieveImage(forKey: key) { result in
                switch result {
                case .success(let value):
                    guard let image = value.image,
                          let data = image.kf.data(format: .unknown)
                    else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: data)

                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func validatedCachedAssetData(for urls: [URL?]) async -> Data? {
        guard let cachedData = await cachedImageData(for: urls, includeStableAlias: true) else {
            return nil
        }
        guard detectCachedAssetError(data: cachedData, referenceURLs: urls) == nil else {
            removeCachedImages(for: urls, includeStableAlias: true)
            return nil
        }
        return cachedData
    }

    private func detectCachedAssetError(
        data: Data,
        referenceURLs _: [URL?]
    ) -> AppError? {
        guard !data.isEmpty else { return .parseFailed }
        if isAuthenticationRequiredPlaceholderImageData(data) {
            return .authenticationRequired
        }
        if isQuotaExceededAssetData(data) {
            return .quotaExceeded
        }

        let looksLikeHTML = prefixLooksLikeHTML(Data(data.prefix(Self.responseInspectionPrefixLength)))
        if let error = detectTextualDownloadError(data: data, looksLikeHTML: looksLikeHTML) {
            return error
        }

        return isDecodableImageData(data) ? nil : .parseFailed
    }

    // Cached assets may be keyed by the original image URL even when the response was redirected
    // to a placeholder image, so placeholder detection must rely on content fingerprints instead
    // of the cache key alone.
    // Observed in our own tests by fetching the live kokomade placeholder asset:
    // https://exhentai.org/img/kokomade.jpg
    private func isAuthenticationRequiredPlaceholderImageData(_ data: Data) -> Bool {
        guard data.count == Self.kokomadeImageByteCount else {
            return false
        }
        return sha1Hex(for: data) == Self.kokomadeImageSHA1
    }

    // Verified from the live 509 placeholder asset captured in our own tests.
    private func isQuotaExceededAssetData(_ data: Data) -> Bool {
        guard data.count == Self.quotaExceededImageByteCount else {
            return false
        }
        return sha1Hex(for: data) == Self.quotaExceededImageSHA1
    }

    private func sha1Hex(for data: Data) -> String {
        let digest = Insecure.SHA1.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func isDecodableImageData(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return false
        }
        return CGImageSourceGetCount(source) > 0
    }

    private func shouldSuppressFailurePersistence(for gid: String) -> Bool {
        schedulingBlockedGalleryIDs.contains(gid) || Task.isCancelled
    }

    nonisolated private static func isCancellationLikeError(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain,
           nsError.code == URLError.cancelled.rawValue
        {
            return true
        }

        let message = nsError.localizedDescription.lowercased()
        return message.contains("cancellation")
            || message.contains("cancelled")
            || message.contains("canceled")
    }

    private func isCancellationLikeAppError(_ error: AppError) -> Bool {
        guard case .fileOperationFailed(let reason) = error else { return false }
        return Self.isCancellationLikeError(NSError(
            domain: NSCocoaErrorDomain,
            code: NSUserCancelledError,
            userInfo: [NSLocalizedDescriptionKey: reason]
        ))
    }

    private func cacheKeys(for url: URL, includeStableAlias: Bool) -> [String] {
        url.imageCacheKeys(includeStableAlias: includeStableAlias)
    }

    private func removeCachedImages(
        for urls: [URL?],
        includeStableAlias: Bool
    ) {
        let keys = urls
            .compactMap(\.self)
            .flatMap { cacheKeys(for: $0, includeStableAlias: includeStableAlias) }

        for key in Set(keys) {
            KingfisherManager.shared.cache.removeImage(forKey: key)
        }
    }

    private func pageImageCacheURLs(
        resolvedImageSource: ResolvedImageSource?,
        index: Int,
        storedGalleryImageState: CachedGalleryImageState?
    ) -> [URL?] {
        [resolvedImageSource?.imageURL, storedGalleryImageState?.imageURLs[index]]
    }

    private func pageImageCacheURLs(
        imageURL: URL?
    ) -> [URL?] {
        [imageURL]
    }

    private func canSatisfyPendingPageDownloadsFromCache(
        pendingPageIndices: [Int],
        temporaryFolderURL: URL,
        existingPageRelativePaths: [Int: String],
        storedGalleryImageState: CachedGalleryImageState?
    ) async -> Bool {
        guard !pendingPageIndices.isEmpty else { return true }
        for index in pendingPageIndices {
            if let relativePath = existingPageRelativePaths[index] {
                let fileURL = temporaryFolderURL.appendingPathComponent(relativePath)
                if fileManager().fileExists(atPath: fileURL.path) {
                    continue
                }
            }
            guard await validatedCachedAssetData(
                for: pageImageCacheURLs(
                    resolvedImageSource: nil,
                    index: index,
                    storedGalleryImageState: storedGalleryImageState
                )
            ) != nil else {
                return false
            }
        }
        return true
    }

    private func restorePendingPagesFromStoredCache(
        indices: [Int],
        temporaryFolderURL: URL,
        existingPages: [Int: String],
        storedGalleryImageState: CachedGalleryImageState?
    ) async throws -> [PageResult] {
        var restoredPages = [PageResult]()
        for index in indices {
            let cacheURLs = pageImageCacheURLs(
                resolvedImageSource: nil,
                index: index,
                storedGalleryImageState: storedGalleryImageState
            )
            guard let pageResult = try await restorePageFromCache(
                index: index,
                cacheURLs: cacheURLs,
                folderURL: temporaryFolderURL,
                preferredRelativePath: existingPages[index],
                referenceURL: cacheURLs.compactMap(\.self).first,
                imageURL: storedGalleryImageState?.imageURLs[index]
            ) else {
                continue
            }
            restoredPages.append(pageResult)
        }
        return restoredPages
    }

    private func pendingPageIndices(
        payload: DownloadRequestPayload,
        folderURL: URL,
        existingPageRelativePaths: [Int: String]
    ) -> [Int] {
        let selectedIndices = payload.pageSelection.map(Set.init)
        return (1...payload.galleryDetail.pageCount).filter { index in
            if let selectedIndices, !selectedIndices.contains(index) {
                return false
            }
            guard let relativePath = existingPageRelativePaths[index] else {
                return true
            }
            let fileURL = folderURL.appendingPathComponent(relativePath)
            return !fileManager().fileExists(atPath: fileURL.path)
        }
    }

    private func shouldExposeTemporaryWorkingSet(for download: DownloadedGallery) -> Bool {
        download.shouldPreserveTemporaryWorkingSet || download.status == .failed
    }

    private func restorePageFromCache(
        index: Int,
        cacheURLs: [URL?],
        folderURL: URL,
        preferredRelativePath: String?,
        referenceURL: URL?,
        imageURL: URL?,
        overwriteExistingFile: Bool = false
    ) async throws -> PageResult? {
        // Cache-assisted restores must reject known placeholder images before promoting them to offline files.
        guard let cachedData = await validatedCachedAssetData(for: cacheURLs)
        else {
            return nil
        }

        let relativePath: String
        if let preferredRelativePath {
            relativePath = preferredRelativePath
        } else {
            let fallbackURL = referenceURL ?? URL(string: "https://example.com/\(index).jpg")!
            let fileExtension = fileExtension(
                for: fallbackURL,
                response: nil,
                prefixData: cachedData
            )
            relativePath = storage.makePageRelativePath(
                index: index,
                fileExtension: fileExtension
            )
        }

        let fileURL = folderURL.appendingPathComponent(relativePath)
        if overwriteExistingFile || !fileManager().fileExists(atPath: fileURL.path) {
            try write(data: cachedData, to: fileURL)
        }

        return .init(
            index: index,
            relativePath: relativePath,
            imageURL: imageURL
        )
    }

    private func preferredPageReferenceURL(
        resolvedImageSource: ResolvedImageSource
    ) -> URL? {
        resolvedImageSource.imageURL
    }

    private func preferredPageReferenceURL(
        imageURL: URL?
    ) -> URL? {
        imageURL
    }

    private func clearFailedPage(index: Int, folderURL: URL) throws {
        guard let failedSnapshot = try? storage.readFailedPages(folderURL: folderURL) else { return }
        let remainingPages = failedSnapshot.pages.filter { $0.index != index }
        if remainingPages.count == failedSnapshot.pages.count {
            return
        }
        if remainingPages.isEmpty {
            try? storage.removeFailedPages(folderURL: folderURL)
        } else {
            try storage.writeFailedPages(.init(pages: remainingPages), folderURL: folderURL)
        }
    }

    private func temporaryCompletedPageCount(
        gid: String,
        expectedPageCount: Int
    ) -> Int {
        let folderURL = storage.temporaryFolderURL(gid: gid)
        guard fileManager().fileExists(atPath: folderURL.path) else { return 0 }
        return storage.existingPageRelativePaths(
            folderURL: folderURL,
            expectedPageCount: expectedPageCount
        )
        .count
    }

    private func validatedCompletedPageCount(_ download: DownloadedGallery) -> Int {
        guard let folderURL = download.resolvedFolderURL(rootURL: storage.rootURL),
              fileManager().fileExists(atPath: folderURL.path)
        else {
            return 0
        }

        guard let manifest = try? storage.readManifest(folderURL: folderURL) else {
            return storage.existingPageRelativePaths(
                folderURL: folderURL,
                expectedPageCount: download.pageCount
            )
            .count
        }

        return storage.validPageCount(folderURL: folderURL, manifest: manifest)
    }

    @discardableResult
    private func sanitizeLocalFilesIfNeeded(
        gid: String,
        clearingLastError: Bool = false
    ) async -> DownloadedGallery? {
        guard let download = await fetchDownload(gid: gid) else { return nil }

        let temporaryFolderURL = storage.temporaryFolderURL(gid: gid)
        let hasTemporaryFolder = fileManager().fileExists(atPath: temporaryFolderURL.path)
        let temporaryCompletedCount = hasTemporaryFolder
            ? storage.existingPageRelativePaths(
                folderURL: temporaryFolderURL,
                expectedPageCount: download.pageCount
            )
            .count
            : 0
        if hasTemporaryFolder {
            _ = storage.existingCoverRelativePath(folderURL: temporaryFolderURL)
        }

        if let completedFolderURL = download.resolvedFolderURL(rootURL: storage.rootURL),
           fileManager().fileExists(atPath: completedFolderURL.path)
        {
            _ = storage.existingPageRelativePaths(
                folderURL: completedFolderURL,
                expectedPageCount: download.pageCount
            )
            _ = storage.existingCoverRelativePath(folderURL: completedFolderURL)
        }

        var needsUpdate = false
        var updatedStatus = download.status
        var updatedCompletedPageCount = download.completedPageCount
        var updatedLastError = download.lastError

        if hasTemporaryFolder,
           shouldExposeTemporaryWorkingSet(for: download)
        {
            if updatedCompletedPageCount != temporaryCompletedCount {
                updatedCompletedPageCount = temporaryCompletedCount
                needsUpdate = true
            }
            if download.status == .failed {
                updatedStatus = .partial
                needsUpdate = true
            }
        }

        if [.completed, .updateAvailable, .missingFiles].contains(download.status) {
            let validation = storage.validate(download: download)
            let completedPageCount = validatedCompletedPageCount(download)
            switch validation {
            case .valid:
                let expectedStatus: DownloadStatus = download.hasUpdate ? .updateAvailable : .completed
                if updatedStatus != expectedStatus {
                    updatedStatus = expectedStatus
                    needsUpdate = true
                }
                if updatedCompletedPageCount != completedPageCount {
                    updatedCompletedPageCount = completedPageCount
                    needsUpdate = true
                }
                if clearingLastError || updatedLastError != nil {
                    updatedLastError = nil
                    needsUpdate = true
                }

            case .missingFiles(let message):
                if updatedStatus != .missingFiles {
                    updatedStatus = .missingFiles
                    needsUpdate = true
                }
                if updatedCompletedPageCount != completedPageCount {
                    updatedCompletedPageCount = completedPageCount
                    needsUpdate = true
                }
                let failure = DownloadFailure(
                    code: .fileOperationFailed,
                    message: message
                )
                if updatedLastError != failure {
                    updatedLastError = failure
                    needsUpdate = true
                }
            }
        } else if clearingLastError, updatedLastError != nil {
            updatedLastError = nil
            needsUpdate = true
        }

        guard needsUpdate else { return download }

        do {
            try await updateDownloadRecord(gid: gid, createIfMissing: false) { record in
                record.status = updatedStatus.rawValue
                record.completedPageCount = Int64(updatedCompletedPageCount)
                record.lastError = updatedLastError?.toData()
            }
            await notifyObservers()
        } catch {
            Logger.error(error)
        }

        return await fetchDownload(gid: gid)
    }

    private func captureTarget(
        for download: DownloadedGallery,
        index: Int
    ) -> (folderURL: URL, preferredRelativePath: String?, isTemporary: Bool)? {
        let temporaryFolderURL = storage.temporaryFolderURL(gid: download.gid)
        if shouldExposeTemporaryWorkingSet(for: download),
           fileManager().fileExists(atPath: temporaryFolderURL.path)
        {
            let temporaryPages = storage.existingPageRelativePaths(
                folderURL: temporaryFolderURL,
                expectedPageCount: download.pageCount
            )
            let manifestRelativePath = (try? storage.readManifest(folderURL: temporaryFolderURL))?
                .pages
                .first(where: { $0.index == index })?
                .relativePath
            let preferredRelativePath = temporaryPages[index]
                ?? manifestRelativePath
            return (temporaryFolderURL, preferredRelativePath, true)
        }

        guard let completedFolderURL = download.resolvedFolderURL(rootURL: storage.rootURL),
              fileManager().fileExists(atPath: completedFolderURL.path)
        else {
            return nil
        }

        let completedPages = storage.existingPageRelativePaths(
            folderURL: completedFolderURL,
            expectedPageCount: download.pageCount
        )
        let manifestRelativePath = (try? storage.readManifest(folderURL: completedFolderURL))?
            .pages
            .first(where: { $0.index == index })?
            .relativePath
        let preferredRelativePath = completedPages[index]
            ?? manifestRelativePath
        return (completedFolderURL, preferredRelativePath, false)
    }

    private func flushDownloadProgress(
        gid: String,
        pendingResolvedPages: inout [PageResult],
        completedCount: Int,
        lastFlushDate: inout Date,
        force: Bool
    ) async throws {
        let shouldFlush = force
            || pendingResolvedPages.count >= Self.progressFlushPageInterval
            || Date().timeIntervalSince(lastFlushDate) >= Self.progressFlushMinimumInterval
        guard shouldFlush else { return }

        let resolvedPages = pendingResolvedPages
        pendingResolvedPages.removeAll(keepingCapacity: true)
        await persistResolvedImageURLs(gid: gid, entries: resolvedPages)
        try await updateDownloadRecord(gid: gid, createIfMissing: false) { record in
            record.completedPageCount = Int64(completedCount)
        }
        lastFlushDate = Date()
        await notifyObservers()
    }

    private func persistResolvedImageURLs(
        gid: String,
        index: Int,
        imageURL: URL?
    ) async {
        await persistResolvedImageURLs(
            gid: gid,
            entries: [
                .init(
                    index: index,
                    relativePath: "",
                    imageURL: imageURL
                )
            ]
        )
    }

    private func persistResolvedImageURLs(
        gid: String,
        entries: [PageResult]
    ) async {
        guard gid.isValidGID else { return }
        let validEntries = entries.filter { $0.imageURL != nil }
        guard !validEntries.isEmpty else { return }

        await MainActor.run {
            let context = PersistenceController.shared.container.viewContext
            let request = NSFetchRequest<GalleryStateMO>(entityName: "GalleryStateMO")
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "gid == %@", gid)

            let object: GalleryStateMO
            if let stored = try? context.fetch(request).first {
                object = stored
            } else {
                object = GalleryStateMO(context: context)
                object.gid = gid
            }

            var imageURLs = (object.imageURLs?.toObject() as [Int: URL]?) ?? [:]
            var hasChanges = false

            for entry in validEntries {
                if let imageURL = entry.imageURL,
                   imageURLs[entry.index] != imageURL
                {
                    imageURLs[entry.index] = imageURL
                    hasChanges = true
                }
            }

            guard hasChanges else {
                return
            }

            object.imageURLs = imageURLs.toData()

            guard context.hasChanges else { return }
            try? context.save()
        }
    }

    private func fetchCachedGalleryImageState(gid: String) async -> CachedGalleryImageState? {
        await MainActor.run {
            guard gid.isValidGID else { return nil }
            let context = PersistenceController.shared.container.viewContext
            let request = NSFetchRequest<GalleryStateMO>(entityName: "GalleryStateMO")
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "gid == %@", gid)
            guard let object = try? context.fetch(request).first else { return nil }
            let state = object.toEntity()
            return .init(
                previewURLs: state.previewURLs,
                imageURLs: state.imageURLs
            )
        }
    }

    private func validatedManifest(
        at folderURL: URL,
        gid: String,
        pageCount: Int,
        versionSignature: String,
        downloadOptions: DownloadOptionsSnapshot
    ) -> DownloadManifest? {
        guard let manifest = try? storage.readManifest(folderURL: folderURL),
              manifest.gid == gid,
              manifest.pageCount == pageCount,
              manifest.pages.count == pageCount,
              manifest.versionSignature == versionSignature,
              manifest.downloadOptions == downloadOptions
        else {
            return nil
        }
        return manifest
    }

    private func activeInspectionFolderURL(for download: DownloadedGallery) -> URL? {
        let temporaryFolderURL = storage.temporaryFolderURL(gid: download.gid)
        let completedFolderURL = download.resolvedFolderURL(rootURL: storage.rootURL)
        let temporaryFolderExists = fileManager().fileExists(atPath: temporaryFolderURL.path)
        let completedFolderExists = completedFolderURL.map { fileManager().fileExists(atPath: $0.path) } ?? false

        if shouldExposeTemporaryWorkingSet(for: download) {
            return temporaryFolderExists
                ? temporaryFolderURL
                : completedFolderURL
        }
        if completedFolderExists {
            return completedFolderURL
        }
        if temporaryFolderExists {
            return temporaryFolderURL
        }
        return nil
    }

    private func sanitizedFailedPages(folderURL: URL) -> [Int: DownloadFailedPagesSnapshot.Page] {
        guard var snapshot = try? storage.readFailedPages(folderURL: folderURL) else {
            return [:]
        }
        let filteredPages = snapshot.pages.filter { !isCancellationLikeAppError($0.failure.appError) }
        guard filteredPages.count != snapshot.pages.count else {
            return snapshot.map
        }

        snapshot.pages = filteredPages
        if filteredPages.isEmpty {
            try? storage.removeFailedPages(folderURL: folderURL)
        } else {
            try? storage.writeFailedPages(snapshot, folderURL: folderURL)
        }
        return snapshot.map
    }

    private func normalizeNeedsAttentionDownloads(_ downloads: [DownloadedGallery]) async {
        for download in downloads {
            let shouldClearCancellationError = download.lastError.map {
                isCancellationLikeAppError($0.appError)
            } ?? false
            guard download.status == .failed || shouldClearCancellationError else { continue }

            let normalizedCompletedPageCount = max(
                download.completedPageCount,
                temporaryCompletedPageCount(
                    gid: download.gid,
                    expectedPageCount: max(download.pageCount, 1)
                )
            )
            do {
                try await updateDownloadRecord(gid: download.gid, createIfMissing: false) { record in
                    if download.status == .failed {
                        record.status = DownloadStatus.partial.rawValue
                        record.completedPageCount = Int64(normalizedCompletedPageCount)
                    }
                    if shouldClearCancellationError {
                        record.lastError = nil
                    }
                }
            } catch {
                Logger.error(error)
            }
        }
    }

    private func normalizeInterruptedDownloads(_ downloads: [DownloadedGallery]) async {
        let hasActiveTask = activeTask != nil
        let activeGalleryID = activeGalleryID
        for download in downloads where
            download.needsInterruptedDownloadNormalization(
                activeGalleryID: activeGalleryID,
                hasActiveTask: hasActiveTask
            )
        {
            do {
                try await updateDownloadRecord(gid: download.gid, createIfMissing: false) { record in
                    record.status = DownloadStatus.paused.rawValue
                }
            } catch {
                Logger.error(error)
            }
        }
    }

    private func reconcileActiveDownloadState() async {
        guard activeTask != nil,
              let activeGalleryID,
              let activeDownload = await fetchDownload(gid: activeGalleryID),
              activeDownload.status != .downloading
        else { return }

        do {
            try await updateDownloadRecord(gid: activeGalleryID, createIfMissing: false) { record in
                record.status = DownloadStatus.downloading.rawValue
                record.lastError = nil
            }
        } catch {
            Logger.error(error)
        }
    }

    private func validateDownloads() async {
        let downloads = await fetchDownloadsFromStore()
        for download in downloads
        where [.completed, .updateAvailable, .missingFiles].contains(download.status) {
            let validation = storage.validate(download: download)
            switch validation {
            case .valid:
                let expectedStatus: DownloadStatus = download.hasUpdate ? .updateAvailable : .completed
                guard download.status != expectedStatus else { continue }
                do {
                    try await updateDownloadRecord(gid: download.gid, createIfMissing: false) { record in
                        record.status = expectedStatus.rawValue
                    }
                } catch {
                    Logger.error(error)
                }

            case .missingFiles(let message):
                do {
                    try await updateDownloadRecord(gid: download.gid, createIfMissing: false) { record in
                        record.status = DownloadStatus.missingFiles.rawValue
                        record.lastError = DownloadFailure(
                            code: .fileOperationFailed,
                            message: message
                        )
                        .toData()
                    }
                } catch {
                    Logger.error(error)
                }
            }
        }
    }

    private func sortDownloads(_ downloads: [DownloadedGallery]) -> [DownloadedGallery] {
        downloads.sorted { lhs, rhs in
            let lhsPriority = lhs.sortPriority
            let rhsPriority = rhs.sortPriority
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return (lhs.lastDownloadedAt ?? .distantPast) > (rhs.lastDownloadedAt ?? .distantPast)
        }
    }

    fileprivate func fetchDownload(gid: String) async -> DownloadedGallery? {
        await MainActor.run {
            let context = PersistenceController.shared.container.viewContext
            let request = NSFetchRequest<DownloadedGalleryMO>(
                entityName: "DownloadedGalleryMO"
            )
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "gid == %@", gid)
            return try? context.fetch(request).first?.toEntity()
        }
    }

    private func fetchDownloadsFromStore() async -> [DownloadedGallery] {
        await MainActor.run {
            let context = PersistenceController.shared.container.viewContext
            let request = NSFetchRequest<DownloadedGalleryMO>(
                entityName: "DownloadedGalleryMO"
            )
            request.sortDescriptors = [
                NSSortDescriptor(
                    keyPath: \DownloadedGalleryMO.lastDownloadedAt,
                    ascending: false
                )
            ]
            let objects = (try? context.fetch(request)) ?? []
            return objects.map { $0.toEntity() }
        }
    }

    private func fetchDownloadsFromStore(gids: [String]) async -> [DownloadedGallery] {
        await MainActor.run {
            let context = PersistenceController.shared.container.viewContext
            let request = NSFetchRequest<DownloadedGalleryMO>(
                entityName: "DownloadedGalleryMO"
            )
            request.predicate = NSPredicate(format: "gid IN %@", gids)
            request.sortDescriptors = [
                NSSortDescriptor(
                    keyPath: \DownloadedGalleryMO.lastDownloadedAt,
                    ascending: false
                )
            ]
            let objects = (try? context.fetch(request)) ?? []
            return objects.map { $0.toEntity() }
        }
    }

    private func updateDownloadRecord(
        gid: String,
        createIfMissing: Bool = true,
        update: @escaping (DownloadedGalleryMO) -> Void
    ) async throws {
        try await MainActor.run {
            let context = PersistenceController.shared.container.viewContext
            let request = NSFetchRequest<DownloadedGalleryMO>(
                entityName: "DownloadedGalleryMO"
            )
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "gid == %@", gid)

            let object: DownloadedGalleryMO
            if let storedObject = try context.fetch(request).first {
                object = storedObject
            } else if !createIfMissing {
                return
            } else {
                object = DownloadedGalleryMO(context: context)
                object.gid = gid
                object.host = GalleryHost.ehentai.rawValue
                object.token = ""
                object.title = ""
                object.category = Category.private.rawValue
                object.pageCount = 0
                object.postedDate = .now
                object.rating = 0
                object.folderRelativePath = gid
                object.status = DownloadStatus.queued.rawValue
                object.remoteVersionSignature = ""
                object.completedPageCount = 0
            }

            update(object)
            guard context.hasChanges else { return }
            do {
                try context.save()
            } catch {
                throw AppError.databaseCorrupted(error.localizedDescription)
            }
        }
    }

    private func deleteDownloadRecord(gid: String) async throws {
        try await MainActor.run {
            let context = PersistenceController.shared.container.viewContext
            let request = NSFetchRequest<DownloadedGalleryMO>(
                entityName: "DownloadedGalleryMO"
            )
            request.fetchLimit = 1
            request.predicate = NSPredicate(format: "gid == %@", gid)
            guard let object = try context.fetch(request).first else { return }
            context.delete(object)
            guard context.hasChanges else { return }
            do {
                try context.save()
            } catch {
                throw AppError.databaseCorrupted(error.localizedDescription)
            }
        }
    }

#if DEBUG
    func testingInstallActiveTask(gid: String, task: Task<Void, Never>) {
        activeGalleryID = gid
        activeTask = task
    }

    func testingScheduleNextIfNeeded() async {
        await scheduleNextIfNeeded()
    }

    func testingFetchDownload(gid: String) async -> DownloadedGallery? {
        await fetchDownload(gid: gid)
    }

    func testingActiveGalleryID() -> String? {
        activeGalleryID
    }

    func testingRestoreCachedPages(payload: DownloadRequestPayload) async throws -> Int {
        try storage.ensureRootDirectory()
        let temporaryFolderURL = storage.temporaryFolderURL(gid: payload.gallery.gid)
        try? fileManager().removeItem(at: temporaryFolderURL)
        try createDirectory(at: temporaryFolderURL)
        try createDirectory(
            at: temporaryFolderURL.appendingPathComponent(
                Defaults.FilePath.downloadPages,
                isDirectory: true
            )
        )

        let batchResult = try await downloadPages(
            payload: payload,
            pendingPageIndices: pendingPageIndices(
                payload: payload,
                folderURL: temporaryFolderURL,
                existingPageRelativePaths: [:]
            ),
            source: nil,
            temporaryFolderURL: temporaryFolderURL,
            existingManifest: nil,
            existingPageRelativePaths: [:],
            storedGalleryImageState: await fetchCachedGalleryImageState(gid: payload.gallery.gid)
        )
        return batchResult.pages.count
    }

    func testingFetchLatestPayload(
        for download: DownloadedGallery,
        mode: DownloadStartMode,
        pageSelection: [Int]? = nil
    ) async throws -> (DownloadRequestPayload, String) {
        try await fetchLatestPayload(
            for: download,
            mode: mode,
            pageSelection: pageSelection
        )
    }

    func testingPrepareWorkingSeed(
        payload: DownloadRequestPayload,
        existingDownload: DownloadedGallery,
        versionSignature: String
    ) throws -> (
        folderURL: URL,
        manifest: DownloadManifest?,
        existingPages: [Int: String],
        coverRelativePath: String?
    ) {
        let temporaryFolderURL = storage.temporaryFolderURL(gid: payload.gallery.gid)
        try? fileManager().removeItem(at: temporaryFolderURL)
        let workingSeed = try prepareWorkingSeed(
            payload: payload,
            existingDownload: existingDownload,
            temporaryFolderURL: temporaryFolderURL,
            versionSignature: versionSignature
        )
        return (
            folderURL: workingSeed.folderURL,
            manifest: workingSeed.manifest,
            existingPages: workingSeed.existingPages,
            coverRelativePath: workingSeed.coverRelativePath
        )
    }

    func testingProcessDownload(gid: String) async {
        await processDownload(gid: gid)
    }

    func testingDetectResponseError(
        fileURL: URL,
        response: URLResponse,
        requestURL: URL?
    ) -> AppError? {
        detectResponseError(
            fileURL: fileURL,
            response: response,
            requestURL: requestURL
        )
    }
#endif
}

// MARK: API
enum DownloadClientKey: DependencyKey {
    static let liveValue = DownloadClient.live()
    static let previewValue = DownloadClient.noop
    static let testValue = DownloadClient.unimplemented
}

extension DependencyValues {
    var downloadClient: DownloadClient {
        get { self[DownloadClientKey.self] }
        set { self[DownloadClientKey.self] = newValue }
    }
}

// MARK: Test
extension DownloadClient {
    static let noop: Self = .init(
        observeDownloads: {
            .init { continuation in
                continuation.yield([])
                continuation.finish()
            }
        },
        fetchDownloads: { [] },
        fetchDownload: { _ in nil },
        reconcileDownloads: {},
        refreshDownloads: {},
        resumeQueue: {},
        badges: { _ in [:] },
        updateRemoteSignature: { _, _ in .none },
        enqueue: { _ in .success(()) },
        togglePause: { _ in .success(()) },
        retry: { _, _ in .success(()) },
        retryPages: { _, _ in .success(()) },
        delete: { _ in .success(()) },
        loadManifest: { _ in .failure(.notFound) },
        loadLocalPageURLs: { _ in .failure(.notFound) },
        captureCachedPage: { _, _, _ in },
        loadInspection: { _ in .failure(.notFound) }
    )

    static func placeholder<Result>() -> Result { fatalError() }

    static let unimplemented: Self = .init(
        observeDownloads: IssueReporting.unimplemented(placeholder: placeholder()),
        fetchDownloads: IssueReporting.unimplemented(placeholder: placeholder()),
        fetchDownload: IssueReporting.unimplemented(placeholder: placeholder()),
        reconcileDownloads: IssueReporting.unimplemented(placeholder: placeholder()),
        refreshDownloads: IssueReporting.unimplemented(placeholder: placeholder()),
        resumeQueue: IssueReporting.unimplemented(placeholder: placeholder()),
        badges: IssueReporting.unimplemented(placeholder: placeholder()),
        updateRemoteSignature: IssueReporting.unimplemented(placeholder: placeholder()),
        enqueue: IssueReporting.unimplemented(placeholder: placeholder()),
        togglePause: IssueReporting.unimplemented(placeholder: placeholder()),
        retry: IssueReporting.unimplemented(placeholder: placeholder()),
        retryPages: IssueReporting.unimplemented(placeholder: placeholder()),
        delete: IssueReporting.unimplemented(placeholder: placeholder()),
        loadManifest: IssueReporting.unimplemented(placeholder: placeholder()),
        loadLocalPageURLs: IssueReporting.unimplemented(placeholder: placeholder()),
        captureCachedPage: IssueReporting.unimplemented(placeholder: placeholder()),
        loadInspection: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
