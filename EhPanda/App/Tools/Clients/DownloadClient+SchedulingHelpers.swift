import Foundation

// MARK: - Mode Resolution
extension DownloadCoordinator {
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
        case .error, .queued, .active:
            return effectiveRetryMode(
                for: download,
                requestedMode: interruptedWorkMode(for: download)
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
        if case .missingFiles = storage.validate(
            download: download,
            verifiesContentHashes: false
        ) {
            return .repair
        }
        return .redownload
    }

    // Queued, active, or errored downloads reach this fallback only when the
    // in-memory queue intent is gone, typically after a relaunch interrupted
    // the session; resuming in place must not discard downloaded pages, so
    // anything with progress repairs instead of redownloading.
    private func interruptedWorkMode(
        for download: DownloadedGallery
    ) -> DownloadStartMode {
        download.completedPageCount == 0 ? .initial : .repair
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
