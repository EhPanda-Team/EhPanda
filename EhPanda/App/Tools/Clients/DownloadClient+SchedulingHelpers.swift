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
            return readResumeMode(gid: download.gid)
                ?? effectiveRetryMode(
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
        if let mode = readResumeMode(gid: download.gid) {
            return effectiveRetryMode(
                for: download,
                requestedMode: mode
            )
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

    func preferredWorkingPageCount(
        for download: DownloadedGallery,
        mode: DownloadStartMode,
        resumeState: DownloadResumeState?
    ) -> Int {
        guard mode == .update else {
            return download.pageCount
        }

        let temporaryFolderURL = storage
            .temporaryFolderURL(gid: download.gid)
        guard fileManager.operate({
            $0.fileExists(atPath: temporaryFolderURL.path)
        }) else {
            return download.pageCount
        }

        if let manifest = try? storage
            .readManifest(folderURL: temporaryFolderURL),
           manifest.gid == download.gid {
            return manifest.pageCount
        }

        if let resumeState {
            return resumeState.pageCount
        }

        return download.pageCount
    }

    func shouldResumeExistingWorkingSet(
        for download: DownloadedGallery,
        mode: DownloadStartMode,
        resumeState: DownloadResumeState?
    ) -> Bool {
        guard download.status == .failed
                || storage.temporaryFolderExists(gid: download.gid),
              let resumeState
        else {
            return false
        }

        let pageCount = preferredWorkingPageCount(
            for: download,
            mode: mode,
            resumeState: resumeState
        )

        guard resumeState.mode == mode,
              resumeState.downloadOptions ==
                download.downloadOptionsSnapshot
        else {
            return false
        }

        if mode == .update,
           let manifest = try? storage.readManifest(
            folderURL: storage.temporaryFolderURL(gid: download.gid)
           ),
           manifest.gid == download.gid {
            return manifest.pageCount == pageCount
        }

        return resumeState.pageCount == pageCount
    }

    func readResumeMode(gid: String) -> DownloadStartMode? {
        let folderURL = storage.temporaryFolderURL(gid: gid)
        return try? storage.readResumeState(folderURL: folderURL).mode
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
