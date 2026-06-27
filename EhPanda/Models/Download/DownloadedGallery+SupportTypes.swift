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

    var manifestURL: URL {
        folderURL.appendingPathComponent(Defaults.FilePath.downloadManifest)
    }

    var coverURL: URL? {
        localCoverURL ?? onlineCoverURL
    }

    var badge: DownloadBadge {
        DownloadBadge(
            status: displayStatus,
            progress: DownloadProgress(
                completedPageCount: completedPageCount,
                pageCount: pageCount
            )
        )
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
            galleryURL: manifest.galleryURL
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
        canPauseOrResume || isQueuedWorkItem
    }

    var canCancelFromDetailAction: Bool {
        isQueuedWorkItem || canPauseOrResume || displayStatus == .completed
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
