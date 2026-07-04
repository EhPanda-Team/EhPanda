import AppTools
import SwiftUI

// MARK: DownloadedGallery Computed Properties
extension DownloadedGallery {
    public var displayTitle: String {
        jpnTitle?.nonEmpty ?? title
    }

    public var searchableText: String {
        [
            title,
            jpnTitle,
            uploader,
            String(localized: category.value),
            tags.flatMap(\.contents).map(\.text).joined(separator: " ")
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    }

    public var manifestURL: URL {
        folderURL.appendingPathComponent(Defaults.FilePath.downloadManifest)
    }

    public var coverURL: URL? {
        localCoverURL ?? onlineCoverURL
    }

    public var badge: DownloadBadge {
        DownloadBadge(
            status: displayStatus,
            progress: DownloadProgress(
                completedPageCount: completedPageCount,
                pageCount: pageCount
            )
        )
    }

    public var gallery: Gallery {
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
            galleryURL: manifest.galleryURL
        )
    }

    public var canRetry: Bool {
        displayStatus == .error
    }

    public var canValidateImageData: Bool {
        [.completed, .updateAvailable].contains(displayStatus)
            || lastError?.code == .fileOperationFailed
    }

    public var canPauseOrResume: Bool {
        [.active, .inactive].contains(displayStatus)
    }

    public var canTogglePause: Bool {
        canPauseOrResume || isQueuedWorkItem
    }

    public var canCancelFromDetailAction: Bool {
        isQueuedWorkItem || canPauseOrResume || displayStatus == .completed
    }

    public var canTriggerUpdate: Bool {
        guard !isQueuedWorkItem, !canPauseOrResume else { return false }
        return displayStatus == .updateAvailable
    }

    public var isQueuedWorkItem: Bool {
        displayStatus == .queued
    }

    public var hasUpdate: Bool {
        displayStatus == .updateAvailable
    }

    public var isIncomplete: Bool {
        completedPageCount < pageCount
    }

    public func needsInterruptedDownloadNormalization(
        activeGalleryID: String?,
        hasActiveTask: Bool
    ) -> Bool {
        displayStatus == .active && !(hasActiveTask && activeGalleryID == gid)
    }

}

extension DownloadInspection {
    public var hasDownloadedPages: Bool {
        pages.contains { $0.status == .downloaded }
    }

    public var canRetryFailedPages: Bool {
        !failedPageIndices.isEmpty
    }

    public var canValidateImageData: Bool {
        hasDownloadedPages && download.canValidateImageData
    }
}
