import AppModels
import Foundation

// MARK: - Mode Resolution
extension DownloadCoordinator {
    public func queuedMode(
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

    public func resumeMode(
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
        // Near-dead after D-G5-01, and deliberately kept. Most missing-file records now resolve at
        // the branch above instead: the working-seed reconciliation blanks the recorded hash of every
        // page whose file is gone, so the record honestly reads `isIncomplete` while inactive. Two
        // states still arrive here, both of them a record that reads COMPLETE while files are missing:
        //   (a) the reconciliation REFUSED its destructive half — a failed page-file scan, or a
        //       nominally successful one that would blank every claimed page (G-15-9's
        //       positive-signal rule) — so the manifest came back verbatim, still claiming its pages;
        //   (b) no preparation has touched the record this session, so nothing has had the
        //       opportunity to blank anything.
        // In both, this branch is what still routes the record to `.repair`. Without it they would
        // fall through to `.redownload`, which deletes the working folder and re-fetches every page,
        // discarding the ones already on disk.
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

    public func effectiveRetryMode(
        for download: DownloadedGallery,
        requestedMode: DownloadStartMode
    ) -> DownloadStartMode {
        guard requestedMode != .initial, download.hasUpdate else {
            return requestedMode
        }
        return .update
    }
}
