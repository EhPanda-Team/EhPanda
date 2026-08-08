import AppModels
import AppTools
import Foundation
import OSLogExt
import Resources

private let logger = Logger(category: .init(describing: DownloadStore.self))

extension DownloadStore {
    public func linkOrCopyReadableAsset(at sourceURL: URL, to destinationURL: URL) throws {
        guard sanitizeAssetFileIfNeeded(at: sourceURL) else {
            throw AppError.fileOperationFailed(
                String(localized: .downloadStoreAssetUnreadable(sourceURL.lastPathComponent))
            )
        }

        try fileManager.operate {
            try $0.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if $0.fileExists(atPath: destinationURL.path) {
                try $0.removeItem(at: destinationURL)
            }
        }

        do {
            try fileManager.operate {
                try $0.linkItem(at: sourceURL, to: destinationURL)
            }
        } catch {
            try fileManager.operate {
                try $0.copyItem(at: sourceURL, to: destinationURL)
            }
        }
    }

    /// Copies a completed gallery's manifest, cover and reusable page files into a fresh working
    /// folder, and returns the claimed pages whose SOURCE-side classification was a NON-ANSWER.
    ///
    /// **The returned set is load-bearing, not diagnostic (G-15-19).** The manifest is copied
    /// WHOLE while the pages are copied selectively, so every page this function does not land at
    /// the destination becomes, to a later scan of that destination, a claimed page whose file a
    /// successful listing simply did not yield — a POSITIVE absence, which
    /// `reconcileWorkingManifestAgainstPageFiles` is licensed to blank. That reading is correct for
    /// a page the source scan positively rejected or never listed. It is a LIE for a page the
    /// source probe could not classify: nothing at all was established about that file, and
    /// D-G13-01 holds absolutely that a non-answer is never authority to destroy a recorded hash.
    /// Selecting through `existingPageRelativePaths` discarded exactly that distinction one layer
    /// below the round-12 defence, which is how a source-side non-answer was laundered into a
    /// destination-side positive absence: the destination listing is honest, its `scanSucceeded` is
    /// true and its `unprobedPages` is empty, so nothing downstream could tell the two apart. The
    /// classification therefore crosses the copy with the caller instead of dying at it.
    ///
    /// Two populations join the set, and both are disagreements about a file the source listing DID
    /// yield rather than absences: the scan's own `unprobedPages`, and any page the scan selected
    /// that the per-page copy guard below nonetheless skipped — a relative path that fails
    /// containment validation, or a file the scan classified `.usable` that no longer probes as
    /// such because it changed between the scan and the copy.
    ///
    /// The cover keeps its plain `Bool` guard deliberately: it carries no per-page recorded hash,
    /// so an uncopied cover costs a re-download and destroys nothing. It is outside this signal's
    /// blast radius.
    ///
    /// A throw from the manifest or page copy still propagates — a failed preparation is a
    /// recoverable failed download. Refusing the seed on a non-answer is NOT the remedy and is not
    /// taken: `setupWorkingFolder` would fall through to `createDirectory`, `ensureWorkingManifest`
    /// would write a fresh all-empty manifest at the empty destination, and the record would be
    /// republished at 0-of-N — converting a K-page hash loss into an N-page one plus a full
    /// D-G7-01 withdrawal, strictly worse than the defect it closes.
    public func materializeRepairSeed(
        from sourceFolderURL: URL,
        manifest: DownloadManifest,
        to destinationFolderURL: URL
    ) throws -> Set<Int> {
        try fileManager.operate {
            try $0.createDirectory(at: destinationFolderURL, withIntermediateDirectories: true)
        }

        try linkOrCopyReadableAsset(
            at: sourceFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest),
            to: destinationFolderURL.appendingPathComponent(Defaults.FilePath.downloadManifest)
        )

        if let coverRelativePath = existingCoverRelativePath(
            folderURL: sourceFolderURL,
            manifest: manifest
        ),
           let sourceCoverURL = validatedChildURL(root: sourceFolderURL, relativePath: coverRelativePath),
           let destCoverURL = validatedChildURL(root: destinationFolderURL, relativePath: coverRelativePath) {
            if sanitizeAssetFileIfNeeded(at: sourceCoverURL) {
                try linkOrCopyReadableAsset(at: sourceCoverURL, to: destCoverURL)
            }
        }

        let sourceScan = pageFileScan(folderURL: sourceFolderURL, manifest: manifest)
        var unansweredPages = sourceScan.unprobedPages
        for page in manifest.pages.keys.sorted() {
            // Not selected by the scan: the listing either never yielded a file for this page or
            // positively rejected the one it did. Both are determinations, so the destination's
            // own scan may treat the page as absent.
            guard let relativePath = sourceScan.pages[page] else { continue }
            guard let sourcePageURL = validatedChildURL(root: sourceFolderURL, relativePath: relativePath),
                  let destPageURL = validatedChildURL(root: destinationFolderURL, relativePath: relativePath),
                  sanitizeAssetFileIfNeeded(at: sourcePageURL)
            else {
                unansweredPages.insert(page)
                continue
            }
            try linkOrCopyReadableAsset(at: sourcePageURL, to: destPageURL)
        }
        return unansweredPages
    }

    /// Returns the manifest with any missing page hashes filled in. Hashes are recorded at
    /// write time (per page as it downloads, and on capture-restore), so finalize only
    /// *merges*: it hashes a page solely when its recorded hash is empty, never re-hashing
    /// the whole gallery. There is no automatic re-validation anywhere; verifying existing
    /// bytes against their hashes is a user-initiated action (`validateImageData(gid:)`).
    public func addingCurrentFileHashes(
        to manifest: DownloadManifest,
        folderURL: URL
    ) throws -> DownloadManifest {
        let existingPages = existingPageRelativePaths(
            folderURL: folderURL,
            manifest: manifest
        )
        var pages = manifest.pages
        for page in manifest.pages.keys.sorted() {
            guard pages[page]?.isEmpty != false else {
                continue
            }
            guard let relativePath = existingPages[page] else {
                throw AppError.fileOperationFailed(
                    String(localized: .RLocalizable.downloadStorePageMissing(page: page))
                )
            }
            pages[page] = try hashReadableAsset(
                folderURL: folderURL,
                relativePath: relativePath,
                missingMessage: String(localized: .RLocalizable.downloadStorePageMissing(page: page))
            )
        }

        return manifest.replacing(pages: pages)
    }

    @discardableResult
    public func refreshManifestPageFileHashes(
        folderURL: URL,
        pageRelativePaths: [Int: String]
    ) throws -> DownloadManifest {
        let manifest = try readManifest(folderURL: folderURL)
        guard !pageRelativePaths.isEmpty else { return manifest }
        var pages = manifest.pages
        var didUpdate = false
        for page in pageRelativePaths.keys.sorted() {
            guard pages[page] != nil,
                  let refreshedRelativePath = pageRelativePaths[page]
            else {
                continue
            }
            pages[page] = try hashReadableAsset(
                folderURL: folderURL,
                relativePath: refreshedRelativePath,
                missingMessage: String(localized: .RLocalizable.downloadStorePageMissing(page: page))
            )
            didUpdate = true
        }

        guard didUpdate else { return manifest }

        let refreshedManifest = manifest.replacing(pages: pages)
        if refreshedManifest != manifest {
            try writeManifest(refreshedManifest, folderURL: folderURL)
        }
        return refreshedManifest
    }

    @discardableResult
    public func refreshManifestFileHashes(folderURL: URL) throws -> DownloadManifest {
        let manifest = try readManifest(folderURL: folderURL)
        let hashedManifest = try addingCurrentFileHashes(
            to: manifest,
            folderURL: folderURL
        )
        if hashedManifest != manifest {
            try writeManifest(hashedManifest, folderURL: folderURL)
        }
        return hashedManifest
    }

    public func removeFolder(relativePath: String) throws {
        let targetURL = folderURL(relativePath: relativePath)
        try removeFolder(at: targetURL)
    }

    public func removeFolder(at folderURL: URL) throws {
        let targetURL = folderURL.standardizedFileURL
        guard targetURL.path.hasPrefix(rootURL.standardizedFileURL.path + "/") else {
            throw AppError.fileOperationFailed(targetURL.path)
        }
        try fileManager.operate {
            guard $0.fileExists(atPath: targetURL.path) else { return }
            try $0.removeItem(at: targetURL)
        }
    }

    public func validate(
        download: DownloadedGallery,
        verifiesContentHashes: Bool
    ) -> DownloadValidationState {
        let folderURL = download.folderURL
        guard fileManager.operate({ $0.fileExists(atPath: folderURL.path) }) else {
            return .missingFiles(.downloadStoreDownloadFolderMissing)
        }
        let manifestURL = download.manifestURL
        guard fileManager.operate({ $0.fileExists(atPath: manifestURL.path) }) else {
            return .missingFiles(.downloadStoreManifestMissing)
        }
        // Validation converts any manifest read or decode failure into the existing corrupted-files state.
        // Unlike the discovery probes, the manifest file is known to exist here (checked above),
        // so a failure is genuine corruption and worth a log line.
        let manifest: DownloadManifest
        do {
            manifest = try readManifest(folderURL: folderURL)
        } catch {
            logger.error("Download manifest read failed during validation: \(error, privacy: .private)")
            return .missingFiles(.RLocalizable.downloadStoreManifestCorrupted)
        }
        if let pageValidationFailure = validatePages(
            folderURL: folderURL,
            manifest: manifest,
            verifiesContentHashes: verifiesContentHashes
        ) {
            return pageValidationFailure
        }
        return .valid
    }

    private func hashReadableAsset(
        folderURL: URL,
        relativePath: String,
        missingMessage: String
    ) throws -> String {
        guard let fileURL = validatedChildURL(root: folderURL, relativePath: relativePath),
              sanitizeAssetFileIfNeeded(at: fileURL)
        else {
            throw AppError.fileOperationFailed(missingMessage)
        }
        return try fileHash(at: fileURL)
    }

    private func validatePages(
        folderURL: URL,
        manifest: DownloadManifest,
        verifiesContentHashes: Bool
    ) -> DownloadValidationState? {
        let existingPages = existingPageRelativePaths(
            folderURL: folderURL,
            manifest: manifest
        )
        for page in manifest.pages.keys.sorted() {
            if let validationFailure = validatePage(
                folderURL: folderURL,
                page: page,
                expectedHash: manifest.pages[page] ?? "",
                existingPageRelativePaths: existingPages,
                verifiesContentHash: verifiesContentHashes
            ) {
                return validationFailure
            }
        }
        return nil
    }

    private func validatePage(
        folderURL: URL,
        page: Int,
        expectedHash: String,
        existingPageRelativePaths: [Int: String],
        verifiesContentHash: Bool
    ) -> DownloadValidationState? {
        guard !expectedHash.isEmpty else {
            return nil
        }

        guard let relativePath = existingPageRelativePaths[page],
              let pageURL = validatedChildURL(root: folderURL, relativePath: relativePath),
              sanitizeAssetFileIfNeeded(at: pageURL)
        else {
            return .missingFiles(.RLocalizable.downloadStorePageMissing(page: page))
        }

        if verifiesContentHash {
            // Validation deliberately treats hash-read failures the same as a content-hash mismatch:
            // a page whose bytes cannot be read is as unusable as one whose bytes changed.
            let actualHash: String?
            do {
                actualHash = try fileHash(at: pageURL)
            } catch {
                logger.error("Download page hash read failed during validation: \(error, privacy: .private)")
                actualHash = nil
            }
            guard actualHash == expectedHash else {
                return .missingFiles(.RLocalizable.downloadStorePageImageCorrupted(page: page))
            }
        }

        return nil
    }
}

private extension DownloadManifest {
    func replacing(
        pages: [Int: String]
    ) -> DownloadManifest {
        var manifest = self
        manifest.pages = pages
        return manifest
    }
}
