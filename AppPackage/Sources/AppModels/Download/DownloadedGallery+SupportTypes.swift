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
        .compactMap({ $0 })
        .filter({ !$0.isEmpty })
        .joined(separator: " ")
    }

    public var manifestURL: URL {
        folderURL.appendingPathComponent(Defaults.FilePath.downloadManifest)
    }

    public var coverURL: URL? {
        localCoverURL ?? onlineCoverURL
    }

    /// The DISPLAY pair: while a run's measurement stands the numerator is that run's credited page
    /// count, and it is the record's own count otherwise (D-SSOT-10). The denominator is the
    /// record's page count either way — the run's target is the whole gallery.
    ///
    /// `completedPageCount`, `isIncomplete`, `canValidateImageData` and every gate below stay on the
    /// RECORD. Only what a user is shown moves.
    public var badge: DownloadBadge {
        DownloadBadge(
            status: displayStatus,
            progress: DownloadProgress(
                completedPageCount: runProgress?.creditedPageCount ?? completedPageCount,
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
        pages.contains(where: { $0.status == .downloaded })
    }

    /// Reads the same basis the retry action sends, so the gate can never enable a button whose
    /// selection would be empty.
    public var canRetryPages: Bool {
        !retryablePageIndices.isEmpty
    }

    public var canValidateImageData: Bool {
        hasDownloadedPages && download.canValidateImageData
    }
}
