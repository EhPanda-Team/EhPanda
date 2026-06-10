//
//  DownloadClient+SchedulingHelpers.swift
//  EhPanda
//

import Foundation

// MARK: - Mode Resolution
extension DownloadManager {
    func queuedMode(
        for download: DownloadedGallery
    ) -> DownloadStartMode {
        if let mode = queuedModes[download.gid] {
            return effectiveRetryMode(
                for: download,
                requestedMode: mode
            )
        }
        switch download.displayStatus {
        case .error where download.lastError?.code == .fileOperationFailed:
            return effectiveRetryMode(
                for: download,
                requestedMode: .repair
            )
        case .updateAvailable:
            return .update
        case .inactive:
            return resumeMode(for: download)
        case .completed:
            return effectiveRetryMode(
                for: download,
                requestedMode: .redownload
            )
        case .error:
            return effectiveRetryMode(
                for: download,
                requestedMode: initialOrRedownloadMode(for: download)
            )
        case .queued, .active:
            return effectiveRetryMode(
                for: download,
                requestedMode: initialOrRedownloadMode(for: download)
            )
        }
    }

    func resumeMode(
        for download: DownloadedGallery
    ) -> DownloadStartMode {
        if download.hasUpdate {
            return .update
        }
        if download.displayStatus == .inactive, download.isIncomplete {
            return effectiveRetryMode(
                for: download,
                requestedMode: .repair
            )
        }
        if case .missingFiles = storage.validate(download: download) {
            return .repair
        }
        return .redownload
    }

    private func initialOrRedownloadMode(
        for download: DownloadedGallery
    ) -> DownloadStartMode {
        download.completedPageCount == 0 ? .initial : .redownload
    }

    func effectiveRetryMode(
        for download: DownloadedGallery,
        requestedMode: DownloadStartMode
    ) -> DownloadStartMode {
        guard requestedMode != .initial, download.hasUpdate else {
            return requestedMode
        }
        return .update
    }
}
