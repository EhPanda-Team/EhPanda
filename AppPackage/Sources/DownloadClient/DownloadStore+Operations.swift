import AppModels
import AppTools
import Foundation
import OSLogExt
import Resources

private let logger = Logger(category: .init(describing: DownloadStore.self))

/// What a fresh content pass was able to determine about each CLAIMED page whose file a presence
/// scan yielded — a partition, not a flag.
///
/// The three sets are disjoint and together cover exactly the claimed pages the presence scan
/// accounted for, which is what lets a caller ask "did this pass classify everything it had to?"
/// without re-deriving a remainder. They are kept apart rather than collapsed into a
/// mismatch/no-mismatch answer for the same reason `PageFileScan` keeps its two signals apart: they
/// answer different questions and license different actions. `mismatched` is positive evidence and
/// licenses destroying a recorded hash; `held` is the absence of an answer and licenses nothing;
/// `verified` is positive evidence that nothing is wrong.
struct ContentMismatchScan: Equatable, Sendable {
    /// The recorded hash and the file's fresh hash agree.
    ///
    /// Read by `reconcileValidatedRecordAgainstPageFiles`' coverage answer, which subtracts the
    /// whole partition from the claimed set to name the pages the pass could not classify at all.
    /// Without this member that subtraction would report every intact page as unclassified, so the
    /// set is load-bearing rather than informational.
    let verified: Set<Int>
    /// The file was read and its fresh hash disagrees with the record — a positive, page-scoped
    /// determination that the recorded hash is wrong (D-SSOT-01).
    let mismatched: Set<Int>
    /// The bytes could not be probed or could not be read, so nothing was established. Never
    /// authority to destroy a recorded hash or its file (D-SSOT-03).
    let held: Set<Int>
}

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

    /// Classifies every CLAIMED page whose file `pageFileScan` yielded by re-hashing its bytes here
    /// and now, into three disjoint sets.
    ///
    /// **D-SSOT-01: a readable file whose fresh hash mismatches its recorded hash is POSITIVE,
    /// page-scoped evidence — the same evidence class as a positive absence — so `mismatched`
    /// licenses durable blanking.** That is what shrinks the validation refusal surface to
    /// operation-level signals: a scan that could not run, a page that could not be read, and the
    /// wholesale-shape guard. `verified` licenses nothing and is returned because the caller
    /// deciding whether the pass covered every claimed page reads the whole partition rather than a
    /// remainder it re-derives — `reconcileValidatedRecordAgainstPageFiles`' `unclassifiedPages`,
    /// where a re-derived remainder is exactly what lost the unprobed population once.
    ///
    /// **D-SSOT-03: `held` is a NON-ANSWER, and a non-answer is never authority to destroy state.**
    /// A page lands there when its bytes could not be probed or could not be read at all — the same
    /// per-file class D-G13-01 protects one level up, where an unprobeable file's recorded hash
    /// survives. Nothing about such a page was established, so its hash stands and its file stays.
    /// `validate(download:verifiesContentHashes:)` deliberately REPORTS an unreadable page as
    /// corrupted, because for a reader they are equally unusable; that equivalence is a message, and
    /// a message is not a licence to blank.
    ///
    /// The classification is taken fresh and never from a validation verdict.
    /// `validate(download:verifiesContentHashes:)` returns at its FIRST failing page, so its message
    /// names one page while a partially-mismatched gallery has a SET — and reconciling from the
    /// verdict would correct whichever page the short-circuit happened to reach and silently leave
    /// its siblings claiming bytes that are no longer there.
    ///
    /// Pages the scan did not yield are skipped entirely: absence is the presence scan's question,
    /// answered under its own discipline, and answering it a second time here would fork the rule.
    func contentMismatchScan(
        folderURL: URL,
        manifest: DownloadManifest,
        pageFileScan: PageFileScan
    ) -> ContentMismatchScan {
        var verified = Set<Int>()
        var mismatched = Set<Int>()
        var held = Set<Int>()
        for page in manifest.pages.keys.sorted() {
            guard let expectedHash = manifest.pages[page],
                  !expectedHash.isEmpty,
                  let relativePath = pageFileScan.pages[page]
            else {
                continue
            }
            guard let pageURL = validatedChildURL(root: folderURL, relativePath: relativePath),
                  sanitizeAssetFileIfNeeded(at: pageURL)
            else {
                held.insert(page)
                continue
            }
            do {
                let actualHash = try fileHash(at: pageURL)
                if actualHash == expectedHash {
                    verified.insert(page)
                } else {
                    mismatched.insert(page)
                }
            } catch {
                // The read itself failed, so nothing at all was established about these bytes. The
                // error is not logged: this is the ordinary negative answer of a probe, and the
                // caller's kept operation-level signal is what surfaces it.
                held.insert(page)
            }
        }
        return ContentMismatchScan(verified: verified, mismatched: mismatched, held: held)
    }

    /// Removes the page files a fresh content pass positively established as mismatched, and returns
    /// the subset that could NOT be removed.
    ///
    /// **D-SSOT-04: blanking a corrupt page's hash while leaving its file in place would LAUNDER the
    /// corruption, so the removal is part of the correction rather than housekeeping beside it.**
    /// The chain is two production mechanisms, both verified rather than assumed.
    /// `resolveSourceIfNeeded` (`DownloadClient+ExecutionPerform.swift`) filters a run's pending
    /// pages down to those whose file is MISSING before it resolves any fetch, so a repair would skip
    /// a blanked page whose file survived. `finalizeDownload`'s `addingCurrentFileHashes` merge then
    /// hashes exactly the blank-hash pages from the files currently on disk, so the stale bytes would
    /// be re-recorded as truth and every later validation would pass over them. Both behaviors are
    /// correct for the missing-file family — an existing file there really is reusable — and only
    /// this family makes them wrong, which is why the fix is to remove the file rather than to add a
    /// branch to either of them.
    ///
    /// Removing destroys nothing recoverable: the page must be re-fetched either way, and what it
    /// converts is the SHAPE — a corrupt-in-place page becomes the positively-absent one that the
    /// blanking loop, the working-seed preparation, the fetch filter and finalize already handle
    /// with no new branches.
    ///
    /// Containment mirrors `removeFolder(at:)`'s posture: the path is resolved through
    /// `validatedChildURL`, so a relative path that escapes the gallery folder removes nothing and is
    /// reported back instead, and an already-absent file is a no-op success because the goal state is
    /// simply that no file remains. Everything returned demotes to a hold at the caller — a page
    /// whose file could not be removed must keep its recorded hash, or the record would claim nothing
    /// while the disk still holds bytes the fetch would reuse.
    func removeMismatchedPageFiles(
        folderURL: URL,
        pageRelativePaths: [Int: String],
        mismatchedPages: Set<Int>
    ) -> Set<Int> {
        var unremovedPages = Set<Int>()
        for page in mismatchedPages.sorted() {
            guard let relativePath = pageRelativePaths[page],
                  let pageURL = validatedChildURL(root: folderURL, relativePath: relativePath)
            else {
                unremovedPages.insert(page)
                continue
            }
            do {
                try fileManager.operate {
                    guard $0.fileExists(atPath: pageURL.path) else { return }
                    try $0.removeItem(at: pageURL)
                }
            } catch {
                // A removal failure is not logged for the same reason the hold above is not: it
                // costs the page its blanking, and the kept operation-level signal is the surface.
                unremovedPages.insert(page)
            }
        }
        return unremovedPages
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
