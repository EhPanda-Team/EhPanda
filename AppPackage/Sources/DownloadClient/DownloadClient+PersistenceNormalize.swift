import AppModels
import Foundation

// MARK: - Manifest, Folder & Normalize
extension DownloadCoordinator {
    public func validatedManifest(
        at folderURL: URL,
        gid: String,
        pageCount: Int
    ) -> DownloadManifest? {
        // Validation is a manifest probe; unreadable or malformed data is treated as
        // no reusable manifest so the caller can create a fresh one.
        guard let manifest = storage.probeManifest(folderURL: folderURL),
              manifest.gid == gid,
              manifest.pageCount == pageCount
        else {
            return nil
        }
        return manifest
    }

    public func activeInspectionFolderURL(
        for download: DownloadedGallery
    ) -> URL? {
        let completedFolderURL = download.folderURL
        let completedFolderExists = fileManager.operate {
            $0.fileExists(atPath: completedFolderURL.path)
        }
        return completedFolderExists ? completedFolderURL : nil
    }

    /// Clears the recorded error of every download whose last failure was cancellation-like.
    ///
    /// A cancellation-like failure is interruption residue rather than something the user must
    /// attend to: `isCancellationLikeAppError` matches only a `fileOperationFailed` whose reason
    /// reads as a cancellation, which is what a pause, a superseded run or a cancelled task leaves
    /// behind. Keeping it recorded would present the app's own decision as a gallery-level failure.
    ///
    /// `displayStatus` is deliberately not consulted. It used to appear as an
    /// `|| displayStatus == .error` disjunct on this loop's guard, which admitted iterations whose
    /// body then did nothing — the clearing has only ever been conditioned on the error's own kind,
    /// and the old name promised an `.error` normalization no line here performed.
    public func clearCancellationLikeDownloadErrors(
        _ downloads: [DownloadedGallery]
    ) async {
        for download in downloads {
            let shouldClearCancellationError =
                download.lastError.map {
                    isCancellationLikeAppError($0.appError)
                } ?? false
            guard shouldClearCancellationError else { continue }
            downloadErrors[download.gid] = nil
        }
    }

    public func normalizeInterruptedDownloads(
        _ downloads: [DownloadedGallery]
    ) async {
        let hasActiveTask = activeTask != nil
        let activeGalleryID = activeGalleryID
        for download in downloads where
        download.needsInterruptedDownloadNormalization(
            activeGalleryID: activeGalleryID,
            hasActiveTask: hasActiveTask
        ) {
            if activeGalleryID == download.gid, !hasActiveTask {
                // ACTIVE-OWNERSHIP CONVERGENCE does not require scheduling here: there is no task
                // to cancel, so no deferred cleanup is disarmed. `syncDownloadsState` always
                // notifies and its caller deliberately decides whether this normalization pass
                // should schedule.
                self.activeGalleryID = nil
            }
        }
    }

    public func reconcileActiveDownloadState() async {
        guard activeTask != nil,
              let activeGalleryID,
              await fetchDownload(gid: activeGalleryID) != nil
        else { return }

        downloadErrors[activeGalleryID] = nil
    }

    /// User-initiated integrity check (the inspector's "validate" action): the only path
    /// that re-reads page bytes and verifies them against their recorded hashes
    /// (`verifiesContentHashes: true`). Routine scans and opens check file *presence* only;
    /// automatic content re-validation was removed because it re-hashed whole galleries on
    /// hot paths. The result is session-scoped status (`validationErrors`), not persisted.
    public func validateImageData(gid: String) async -> DownloadValidationState? {
        guard let download = await fetchDownload(gid: gid),
              download.canValidateImageData
        else { return nil }
        let validation = storage.validate(
            download: download,
            verifiesContentHashes: true
        )
        switch validation {
        case .valid:
            validationErrors[download.gid] = nil

        case .missingFiles(let message):
            validationErrors[download.gid] = DownloadFailure(
                code: .fileOperationFailed,
                message: String(localized: message)
            )
        }
        await notifyObservers()
        return validation
    }
}
