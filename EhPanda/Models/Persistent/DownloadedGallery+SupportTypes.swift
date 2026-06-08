//
//  DownloadedGallery+SupportTypes.swift
//  EhPanda
//

import SwiftUI

// MARK: DownloadedGallery Computed Properties
extension DownloadedGallery {
    var displayTitle: String {
        jpnTitle?.nonEmpty ?? title
    }

    var searchableText: String {
        [
            title,
            jpnTitle ?? "",
            uploader ?? "",
            category.value,
            tags.flatMap(\.contents).map(\.text).joined(separator: " ")
        ]
        .joined(separator: " ")
    }

    func resolvedFolderURL(rootURL: URL? = FileUtil.downloadsDirectoryURL) -> URL? {
        rootURL?.appendingPathComponent(folderRelativePath, isDirectory: true)
    }

    func resolvedManifestURL(rootURL: URL? = FileUtil.downloadsDirectoryURL) -> URL? {
        resolvedFolderURL(rootURL: rootURL)?
            .appendingPathComponent(Defaults.FilePath.downloadManifest)
    }

    func resolvedLocalCoverURL(rootURL: URL? = FileUtil.downloadsDirectoryURL) -> URL? {
        guard let folderURL = resolvedFolderURL(rootURL: rootURL),
              let coverRelativePath,
              coverRelativePath.notEmpty
        else { return nil }
        let coverURL = folderURL.appendingPathComponent(coverRelativePath)
        guard isReadableLocalAssetFile(coverURL) else {
            return nil
        }
        return coverURL
    }

    func resolvedTemporaryCoverURL(rootURL: URL? = FileUtil.downloadsDirectoryURL) -> URL? {
        guard shouldPreserveTemporaryWorkingSet,
              let rootURL
        else {
            return nil
        }

        let temporaryFolderURL = rootURL.appendingPathComponent(".tmp-\(gid)", isDirectory: true)
        guard FileManager.default.fileExists(atPath: temporaryFolderURL.path) else {
            return nil
        }

        if let coverRelativePath,
           coverRelativePath.notEmpty {
            let coverURL = temporaryFolderURL.appendingPathComponent(coverRelativePath)
            if isReadableLocalAssetFile(coverURL) {
                return coverURL
            }
        }

        guard let fileURLs = try? FileManager.default.contentsOfDirectory(
            at: temporaryFolderURL,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }

        return fileURLs.first(where: {
            $0.lastPathComponent.hasPrefix("cover.") && isReadableLocalAssetFile($0)
        })
    }

    func resolvedCoverURL(rootURL: URL? = FileUtil.downloadsDirectoryURL) -> URL? {
        resolvedLocalCoverURL(rootURL: rootURL)
            ?? resolvedTemporaryCoverURL(rootURL: rootURL)
            ?? onlineCoverURL
    }

    var folderURL: URL? {
        resolvedFolderURL()
    }

    var manifestURL: URL? {
        resolvedManifestURL()
    }

    var localCoverURL: URL? {
        resolvedLocalCoverURL()
    }

    var coverURL: URL? {
        resolvedCoverURL()
    }

    var badge: DownloadBadge {
        if isQueuedWorkItem {
            return .queued
        }
        switch status {
        case .queued:
            return .queued
        case .downloading:
            return .downloading(completedPageCount, pageCount)
        case .paused:
            return .paused(completedPageCount, pageCount)
        case .partial:
            return .partial(completedPageCount, pageCount)
        case .completed:
            return .downloaded
        case .failed:
            return .failed
        case .updateAvailable:
            return .updateAvailable
        case .missingFiles:
            return .missingFiles
        }
    }

    var sortPriority: Int {
        if isQueuedWorkItem {
            return 1
        }

        switch status {
        case .downloading:
            return 0
        case .paused:
            return 1
        case .queued:
            return 2
        case .partial:
            return 3
        case .updateAvailable:
            return 4
        case .missingFiles:
            return 5
        case .failed:
            return 6
        case .completed:
            return 7
        }
    }

    var gallery: Gallery {
        Gallery(
            gid: gid,
            token: token,
            title: displayTitle,
            rating: rating,
            tags: tags,
            category: category,
            uploader: uploader,
            pageCount: pageCount,
            postedDate: postedDate,
            coverURL: coverURL,
            galleryURL: host.url
                .appendingPathComponent("g")
                .appendingPathComponent(gid)
                .appendingPathComponent(token)
        )
    }

    var canRetry: Bool {
        [.partial, .failed, .missingFiles].contains(status)
    }

    var canValidateImageData: Bool {
        [.completed, .updateAvailable, .missingFiles].contains(status)
    }

    var canPauseOrResume: Bool {
        [.downloading, .paused].contains(status)
    }

    var canTogglePause: Bool {
        canPauseOrResume || isPendingQueue
    }

    var shouldPreserveTemporaryWorkingSet: Bool {
        pendingOperation != nil
            || [.queued, .downloading, .paused, .partial].contains(status)
    }

    var isPendingQueue: Bool {
        badge == .queued
    }

    var canCancelFromDetailAction: Bool {
        isPendingQueue || canPauseOrResume || [.partial, .completed].contains(status)
    }

    var canTriggerUpdate: Bool {
        guard !isQueuedWorkItem, !canPauseOrResume else { return false }
        return status == .updateAvailable || ([.completed, .missingFiles].contains(status) && hasUpdate)
    }

    var isQueuedWorkItem: Bool {
        status == .queued || pendingOperation != nil
    }

    var hasUpdate: Bool {
        DownloadSignatureBuilder.hasUpdateComparison(
            remoteVersionSignature: remoteVersionSignature,
            latestRemoteVersionSignature: latestRemoteVersionSignature,
            gid: gid,
            token: token
        ) == .different
    }

    func needsInterruptedDownloadNormalization(
        activeGalleryID: String?,
        hasActiveTask: Bool
    ) -> Bool {
        status == .downloading && !(hasActiveTask && activeGalleryID == gid)
    }

    func matches(filter: DownloadListFilter) -> Bool {
        if isQueuedWorkItem {
            return filter == .all || filter == .active
        }

        switch filter {
        case .all:
            return true
        case .active:
            return [.downloading, .paused].contains(status)
        case .completed:
            return status == .completed
        case .failed:
            return [.partial, .failed, .missingFiles].contains(status)
        case .update:
            return status == .updateAvailable || hasUpdate
        }
    }

    func matches(queryFilter: DownloadGalleryFilter) -> Bool {
        if queryFilter.excludedCategories.contains(category) {
            return false
        }

        if queryFilter.minimumRatingActivated && rating < Float(queryFilter.minimumRating) {
            return false
        }

        guard queryFilter.pageRangeActivated else { return true }

        if let lowerBound = Int(queryFilter.pageLowerBound), pageCount < lowerBound {
            return false
        }
        if let upperBound = Int(queryFilter.pageUpperBound), pageCount > upperBound {
            return false
        }

        return true
    }
}

extension DownloadedGallery {
    func isReadableLocalAssetFile(_ url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        let isRegularFile = values?.isRegularFile ?? true
        let fileSize = values?.fileSize ?? 0
        return isRegularFile && fileSize > 0
    }
}

extension DownloadInspection {
    var hasDownloadedPages: Bool {
        pages.contains { $0.status == .downloaded }
    }

    var canRetryFailedPages: Bool {
        !failedPageIndices.isEmpty
    }

    var canValidateImageData: Bool {
        hasDownloadedPages && download.canValidateImageData
    }
}
