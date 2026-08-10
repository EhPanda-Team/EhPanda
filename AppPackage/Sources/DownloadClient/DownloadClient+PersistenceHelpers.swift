import AppModels
import Foundation

// MARK: - Error clearance
extension DownloadCoordinator {
    /// Drops the operation-level error a just-succeeded operation has falsified, and answers the
    /// record as it reads afterwards.
    ///
    /// **This was `sanitizeLocalFilesIfNeeded`, and the name stopped being true (CR-03).** Its
    /// folder scan resolved every claimed page and the cover purely so the probe would DELETE the
    /// ones it refused — both results were discarded — so an ordinary reader open destroyed a
    /// zero-byte or non-regular file while nothing here wrote the manifest, leaving the record
    /// claiming a page the app itself had removed, across relaunch. The scan is deleted rather than
    /// made non-discarding: with the deletion withheld it computed two answers nobody read.
    ///
    /// What remains is the half that was always real. `validationErrors` and `downloadErrors` are
    /// session-scoped operation-level signals that OUTRANK the record in status derivation, so an
    /// operation that has just made one of them false has to retract it or the gallery keeps
    /// displaying a failure the disk no longer supports. `failedPageErrors` is deliberately left
    /// alone: it is per-page, and a single page landing says nothing about its siblings.
    @discardableResult
    public func clearStaleDownloadErrorIfNeeded(gid: String) async -> DownloadedGallery? {
        guard let download = await fetchDownload(gid: gid)
        else { return nil }

        guard download.lastError != nil else {
            return download
        }

        clearDownloadFailureState(gid: gid, includePageFailures: false)
        await notifyObservers()

        return await fetchDownload(gid: gid)
    }

    public func captureTarget(
        for download: DownloadedGallery,
        index page: Int
    ) -> CaptureTargetResult? {
        let completedFolderURL = download.folderURL
        guard fileManager.operate({
            $0.fileExists(atPath: completedFolderURL.path)
        })
        else {
            return nil
        }

        // A READ (CR-03). This resolves the name ONE page should be written under, while the scan
        // classifies every claimed page — so a discarding scan would delete the files of pages this
        // capture never touches and whose hashes nothing here lowers. For the captured page itself
        // the answer is unchanged: a refused file is outside `pages` either way, so the restore
        // picks a fresh name and `flushManifestPageProgress` records the hash of what it wrote.
        let completedPages =
            storage.existingPageRelativePaths(
                folderURL: completedFolderURL,
                manifest: download.manifest
            )
        return CaptureTargetResult(
            folderURL: completedFolderURL,
            preferredRelativePath: completedPages[page]
        )
    }
}
