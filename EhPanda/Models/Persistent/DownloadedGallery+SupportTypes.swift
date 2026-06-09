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
        switch displayStatus {
        case .active:
            return .downloading(completedPageCount, pageCount)
        case .queued:
            return .queued
        case .inactive:
            return .paused(completedPageCount, pageCount)
        case .updateAvailable:
            return .updateAvailable
        case .error:
            if completedPageCount > 0, completedPageCount < pageCount {
                return .partial(completedPageCount, pageCount)
            }
            if lastError?.code == .fileOperationFailed,
               completedPageCount == 0 {
                return .missingFiles
            }
            return .failed
        case .completed:
            return .downloaded
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
        displayStatus == .error
    }

    var canValidateImageData: Bool {
        [.completed, .updateAvailable].contains(displayStatus)
            || lastError?.code == .fileOperationFailed
    }

    var canPauseOrResume: Bool {
        [.active, .inactive].contains(displayStatus)
    }

    var canTogglePause: Bool {
        canPauseOrResume || isPendingQueue
    }

    var isPendingQueue: Bool {
        badge == .queued
    }

    var canCancelFromDetailAction: Bool {
        isPendingQueue || canPauseOrResume || displayStatus == .completed
    }

    var canTriggerUpdate: Bool {
        guard !isQueuedWorkItem, !canPauseOrResume else { return false }
        return displayStatus == .updateAvailable
    }

    var isQueuedWorkItem: Bool {
        displayStatus == .queued
    }

    var hasUpdate: Bool {
        displayStatus == .updateAvailable
    }

    var isIncomplete: Bool {
        completedPageCount < pageCount
    }

    func needsInterruptedDownloadNormalization(
        activeGalleryID: String?,
        hasActiveTask: Bool
    ) -> Bool {
        displayStatus == .active && !(hasActiveTask && activeGalleryID == gid)
    }

    func matches(filter: DownloadListFilter) -> Bool {
        if isQueuedWorkItem {
            return filter == .all || filter == .active
        }

        switch filter {
        case .all:
            return true
        case .active:
            return [.active, .inactive].contains(displayStatus)
        case .completed:
            return displayStatus == .completed
        case .failed:
            return displayStatus == .error
        case .update:
            return displayStatus == .updateAvailable
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
