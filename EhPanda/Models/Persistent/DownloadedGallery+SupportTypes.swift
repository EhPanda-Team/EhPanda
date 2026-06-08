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
            jpnTitle,
            uploader,
            category.value,
            tags.flatMap(\.contents).map(\.text).joined(separator: " ")
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    func resolvedFolderURL(rootURL _: URL = FileUtil.downloadsDirectoryURL) -> URL {
        folderURL
    }

    func resolvedManifestURL(rootURL _: URL = FileUtil.downloadsDirectoryURL) -> URL {
        folderURL.appendingPathComponent(Defaults.FilePath.downloadManifest)
    }

    func resolvedLocalCoverURL(rootURL: URL = FileUtil.downloadsDirectoryURL) -> URL? {
        return DownloadFileStorage(rootURL: rootURL)
            .existingCoverRelativePath(folderURL: folderURL)
            .map { folderURL.appendingPathComponent($0) }
    }

    func resolvedCoverURL(rootURL: URL = FileUtil.downloadsDirectoryURL) -> URL? {
        resolvedLocalCoverURL(rootURL: rootURL)
            ?? onlineCoverURL
    }

    var manifestURL: URL {
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

    var displayStatus: DownloadDisplayStatus {
        if status == .updateAvailable {
            return .updateAvailable
        }
        if status == .completed {
            return .completed
        }
        if status == .downloading {
            return .active
        }
        if isQueuedWorkItem {
            return .queued
        }
        if lastError != nil || [.failed, .missingFiles].contains(status) {
            return .error
        }
        return .inactive
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

    var isPendingQueue: Bool {
        badge == .queued
    }

    var canCancelFromDetailAction: Bool {
        isPendingQueue || canPauseOrResume || [.partial, .completed].contains(status)
    }

    var canTriggerUpdate: Bool {
        guard !isQueuedWorkItem, !canPauseOrResume else { return false }
        return status == .updateAvailable
    }

    var isQueuedWorkItem: Bool {
        status == .queued
    }

    var hasUpdate: Bool {
        status == .updateAvailable
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
            return status == .updateAvailable
        }
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
