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
        if let pendingOperation = download.pendingOperation {
            return pendingOperation
        }
        switch download.status {
        case .missingFiles:
            return effectiveRetryMode(
                for: download,
                requestedMode: .repair
            )
        case .updateAvailable:
            return .update
        case .partial:
            return resumeMode(for: download)
        case .completed:
            return effectiveRetryMode(
                for: download,
                requestedMode: .redownload
            )
        case .failed:
            return effectiveRetryMode(
                for: download,
                requestedMode: download.remoteVersionSignature.isEmpty
                    ? .initial : .redownload
            )
        case .paused:
            return resumeMode(for: download)
        case .queued, .downloading:
            return effectiveRetryMode(
                for: download,
                requestedMode: download.remoteVersionSignature.isEmpty
                    ? .initial : .redownload
            )
        }
    }

    func resumeMode(
        for download: DownloadedGallery
    ) -> DownloadStartMode {
        if download.remoteVersionSignature.isEmpty {
            return .initial
        }
        if download.hasUpdate {
            return .update
        }
        if download.status == .partial {
            return effectiveRetryMode(
                for: download,
                requestedMode: download.remoteVersionSignature.isEmpty
                    ? .initial : .redownload
            )
        }
        if case .missingFiles = storage.validate(download: download) {
            return .repair
        }
        return .redownload
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

    nonisolated func fallbackStatus(
        for download: DownloadedGallery,
        mode: DownloadStartMode
    ) -> DownloadStatus {
        let shouldKeepUpdateBadge = mode == .update
            || download.status == .updateAvailable
        return shouldKeepUpdateBadge ? .updateAvailable : .completed
    }
}
