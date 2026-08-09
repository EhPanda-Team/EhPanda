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
    /// hot paths.
    ///
    /// **D-G5B-01: a `.missingFiles` verdict reconciles the record it judged, wherever the evidence
    /// licenses it.** The manifest is the one basis the whole system trusts, so a finding that
    /// contradicts it is written into it rather than kept beside it: the branch below re-reads the
    /// folder's manifest, takes one fresh page-file scan, and runs the D-G5-01 blanking loop under
    /// its own refusal discipline. When the loop blanks, the record itself now says the gallery is
    /// incomplete — the badge count, `displayStatus`, the start gates and `resumeMode` all read that
    /// one persisted truth, and it survives relaunch because the loop writes the manifest and
    /// re-indexes it. `validationErrors` is then cleared, deliberately: it outranks everything in
    /// `displayStatus`, so an entry left behind would pin `.error` over an honest record and make it
    /// unstartable, which is the whole defect this closes.
    ///
    /// `validationErrors` remains exactly the REFUSAL family's surface: where the scan failed, or
    /// where blanking would empty every claimed hash at once, the manifest is left verbatim and the
    /// transient entry is recorded as before — the record cannot speak for that shape, so the
    /// session must, and `canValidateImageData`'s error disjunct keeps Validate re-runnable there.
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
            if reconcileValidatedRecordAgainstPageFiles(download: download) {
                validationErrors[download.gid] = nil
            } else {
                validationErrors[download.gid] = DownloadFailure(
                    code: .fileOperationFailed,
                    message: String(localized: message)
                )
            }
        }
        await notifyObservers()
        return validation
    }

    /// Makes a `.missingFiles` verdict durable when the blanking loop's own evidence rule licenses
    /// it, and reports whether it did (D-G5B-01).
    ///
    /// The evidence is a page-file scan taken here and now, never the verdict: `storage.validate`
    /// short-circuits at the first failing page, so its message names one page while the scan
    /// classifies every page — and a partially-missing gallery must blank exactly its missing set,
    /// whichever page validate happened to report. Nothing about the refusal lines is re-decided
    /// here; the loop is called unmodified, so a failed scan, an unprobed page and the wholesale
    /// shape all refuse at validate time exactly as they refuse at repair-preparation time.
    ///
    /// A nil manifest probe is treated as a refusal rather than a fresh start. Validation just
    /// proved that file readable, so failing now is a race with a concurrent deletion — a
    /// non-answer, and a non-answer is never authority to destroy recorded hashes.
    ///
    /// The `withdrawingCountedBasisMovement` bracket is the same sibling bracket the repair-seed
    /// preparation wraps this loop in. Blanking lowers the record's counted basis, and a live
    /// continued session may still be counting this gallery — a completed-then-validated gallery
    /// while the queue drains — so the write has to withdraw its counted portion from the monotonic
    /// floor. The bracket is delta-keyed, so a refusal withdraws exactly zero by construction.
    private func reconcileValidatedRecordAgainstPageFiles(
        download: DownloadedGallery
    ) -> Bool {
        let folderURL = download.folderURL
        guard let manifest = storage.probeManifest(folderURL: folderURL) else { return false }
        let pageFileScan = storage.pageFileScan(folderURL: folderURL, manifest: manifest)
        do {
            let reconciledManifest = try withdrawingCountedBasisMovement(gid: download.gid) {
                try reconcileWorkingManifestAgainstPageFiles(
                    manifest: manifest,
                    pageFileScan: pageFileScan,
                    folderURL: folderURL
                )
            }
            return reconciledManifest.pages != manifest.pages
        } catch {
            // Silence is correct here, and is not a swallowed failure. A throw can only come from
            // the loop's manifest write, which leaves the record claiming exactly what it claimed
            // before — so nothing was destroyed, the verdict simply has nowhere durable to live, and
            // the caller records the transient entry that is the honest surface for that. The loop
            // logs the writes it DOES perform, so the observable inventory stays what it was: no new
            // log content is introduced by this second caller.
            return false
        }
    }
}
