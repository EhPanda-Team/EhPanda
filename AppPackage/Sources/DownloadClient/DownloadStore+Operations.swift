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
/// What one validation pass is permitted to do while it forms its verdict.
///
/// Both members are decided ONCE, at the public boundary, and never vary per page, so they travel as
/// one value rather than as two flags threaded side by side through every level of the walk. Naming
/// them together is also the honest description: they are not two unrelated knobs but one answer to
/// "what may this pass do to the thing it is judging" — `verifiesContentHashes` says how deeply it
/// may READ, and `discardingRejected` says whether it may WRITE at all.
///
/// The second is the one CR-01 added, and it is false wherever the verdict feeds a reconciliation
/// that may refuse: a pass whose evidence gathering deletes files cannot honour a refusal, because
/// the refusal arrives after the deletion.
private struct DownloadValidationPolicy {
    let verifiesContentHashes: Bool
    let discardingRejected: Bool
}

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
    /// authority to destroy a recorded hash or its file (D-SSOT-03). A page whose file the presence
    /// scan yielded and this pass then found unusable lands here too: the two reads can only
    /// disagree if the file changed between them, which is a race rather than a determination.
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
            // Non-discarding, like every other pass validation takes before its guard has authorized
            // anything (CR-01). This re-probe can only disagree with the presence scan that just
            // yielded the file if the file CHANGED between the two reads, and a race is the weakest
            // evidence in the building — so the page is held, with its hash and its file both
            // intact, and the next validate classifies it from a settled disk.
            guard let pageURL = validatedChildURL(root: folderURL, relativePath: relativePath),
                  sanitizeAssetFileIfNeeded(at: pageURL, discardingRejected: false)
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

    /// Removes the page files this pass positively REFUTED — the content pass's mismatches and the
    /// presence scan's rejections alike — and returns the subset that could NOT be removed.
    ///
    /// **The two families are one population here, because they are one evidence class (CR-01).** A
    /// file whose fresh hash disagrees with the record and a file that is zero bytes or not a
    /// regular file are both positive, page-scoped determinations that the recorded hash describes
    /// nothing reusable. What made them look different was an accident of WHERE the determination
    /// was made: the mismatch was decided by a content pass that could not delete, and the rejection
    /// by a probe that deleted as it went. With the probe's deletion withheld, both arrive here as
    /// refuted-and-still-present, and both are removed under one authorization.
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
    /// converts is the SHAPE — a corrupt-in-place or structurally refused page becomes the
    /// positively-absent one that the blanking loop, the working-seed preparation, the fetch filter
    /// and finalize already handle with no new branches.
    ///
    /// `pageRelativePaths` must therefore cover BOTH families: the presence scan's `pages` for the
    /// mismatched ones and its `rejectedPageRelativePaths` for the refused ones. A page missing from
    /// the map removes nothing and is reported back, which is the same conservative answer a failed
    /// removal gets.
    ///
    /// Containment mirrors `removeFolder(at:)`'s posture: the path is resolved through
    /// `validatedChildURL`, so a relative path that escapes the gallery folder removes nothing and is
    /// reported back instead, and an already-absent file is a no-op success because the goal state is
    /// simply that no file remains. Everything returned demotes to a hold at the caller — a page
    /// whose file could not be removed must keep its recorded hash, or the record would claim nothing
    /// while the disk still holds bytes the fetch would reuse.
    func removeRefutedPageFiles(
        folderURL: URL,
        pageRelativePaths: [Int: String],
        refutedPages: Set<Int>
    ) -> Set<Int> {
        var unremovedPages = Set<Int>()
        for page in refutedPages.sorted() {
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

    /// Renames a user folder, owning the whole filesystem boundary of that move (CR-03).
    ///
    /// `oldName` arrives from a public client API, so it is untrusted input rather than a name the
    /// UI is assumed to have read out of a listing. Two refusals carry the boundary:
    ///
    /// - **A source is never normalized.** `normalizedUserFolderName` maps separators to spaces and
    ///   trims padding, so normalizing `"  Photos  "` would select the real folder `"Photos"` — one
    ///   the caller never named. An accepted source must already BE its normalized spelling;
    ///   anything else is refused rather than repaired. A destination is the opposite case: the
    ///   caller is asking for a name to be created, so normalizing it is the entire point.
    /// - **Containment is decided against the resolved filesystem, and decided again at the move.**
    ///   Lexical standardization answers `..`, nested components and absolute paths; only symlink
    ///   resolution answers a direct child that points somewhere else entirely. Both run once more
    ///   inside the same `operate` closure that performs the move, so no decision taken against a
    ///   stale view of the disk is what authorizes the mutation.
    ///
    /// - Throws: `.fileOperationFailed` for a name that is not an acceptable direct child, for a
    ///   source that is not a plain directory, and for a destination that already exists;
    ///   `.notFound` for an acceptable source that is simply absent — the one case where the caller
    ///   learns something true about a name it was allowed to use.
    public func renameUserFolder(oldName: String, newName: String) throws {
        guard let normalizedNewName = normalizedUserFolderName(newName),
              let sourceURL = confinedDirectUserFolderURL(named: oldName),
              let destinationURL = confinedDirectUserFolderURL(named: normalizedNewName)
        else {
            throw invalidUserFolderNameError()
        }
        guard sourceURL != destinationURL else { return }
        try fileManager.operate { manager in
            guard confinedDirectUserFolderURL(named: oldName) == sourceURL,
                  confinedDirectUserFolderURL(named: normalizedNewName) == destinationURL
            else {
                throw invalidUserFolderNameError()
            }
            guard let sourceType = itemType(at: sourceURL, using: manager) else {
                throw AppError.notFound
            }
            // `attributesOfItem` describes the item itself rather than what it points at, so a
            // symbolic link reports `.typeSymbolicLink` and fails this equality. That is the
            // rejection the resolved-parent check cannot make on its own: a link whose target is
            // another direct child of the same root resolves inside the boundary, and renaming
            // through it would still move the link instead of the folder the caller named.
            guard sourceType == .typeDirectory else {
                throw invalidUserFolderNameError()
            }
            guard itemType(at: destinationURL, using: manager) == nil else {
                throw AppError.fileOperationFailed(
                    String(localized: .downloadStoreFolderAlreadyExists)
                )
            }
            try manager.moveItem(at: sourceURL, to: destinationURL)
        }
    }

    /// The URL of `rawName`, but only when it names a direct child of the download root.
    ///
    /// The single-component requirement is stated here rather than inherited from what the name
    /// sanitizer happens to rewrite today, so a future change to normalization cannot quietly widen
    /// this boundary. The two parent comparisons are both required and neither implies the other:
    /// the standardized one refuses a name that climbs out lexically, the resolved one refuses a
    /// name whose own last component is a link out.
    private func confinedDirectUserFolderURL(named rawName: String) -> URL? {
        guard !rawName.isEmpty,
              rawName != ".",
              rawName != "..",
              rawName.split(separator: "/", omittingEmptySubsequences: false).count == 1,
              normalizedUserFolderName(rawName) == rawName
        else {
            return nil
        }
        let candidateURL = rootURL.appendingPathComponent(rawName, isDirectory: true)
        guard candidateURL.standardizedFileURL.deletingLastPathComponent().path
                == rootURL.standardizedFileURL.path,
              candidateURL.resolvingSymlinksInPath().deletingLastPathComponent().path
                == rootURL.resolvingSymlinksInPath().path
        else {
            return nil
        }
        return candidateURL
    }

    /// The type of whatever sits at `url`, or nil when nothing readable does.
    ///
    /// A throw here reports only that the path has no reachable item, which is precisely the answer
    /// both call sites need; there is no second outcome for a caller to distinguish.
    private func itemType(at url: URL, using manager: FileManager) -> FileAttributeType? {
        do {
            let attributes = try manager.attributesOfItem(atPath: url.path)
            return attributes[.type] as? FileAttributeType
        } catch {
            return nil
        }
    }

    private func invalidUserFolderNameError() -> AppError {
        .fileOperationFailed(String(localized: .RLocalizable.downloadStoreInvalidFolderName))
    }

    /// Reports the first way this download's files contradict its manifest, without ever being
    /// required to change them.
    ///
    /// **`discardingRejected` is the mutation half, and it is a caller's decision (CR-01).** The
    /// verdict is identical either way — a zero-byte or non-regular page file is missing content
    /// whether or not it is deleted — so the flag decides only whether the probe's housekeeping
    /// deletion is allowed to fire while this verdict is being reached. It defaults to the
    /// historical behavior for the two callers whose answer feeds nothing destructive
    /// (`loadManifest`'s readability check and `resumeMode`'s repair-versus-redownload question).
    /// `validateImageData` passes false: its verdict is the input to a reconciliation that may
    /// refuse, and a refusal must find the disk exactly as it was.
    public func validate(
        download: DownloadedGallery,
        verifiesContentHashes: Bool,
        discardingRejected: Bool = true
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
            policy: DownloadValidationPolicy(
                verifiesContentHashes: verifiesContentHashes,
                discardingRejected: discardingRejected
            )
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
        policy: DownloadValidationPolicy
    ) -> DownloadValidationState? {
        let existingPages = existingPageRelativePaths(
            folderURL: folderURL,
            manifest: manifest,
            discardingRejected: policy.discardingRejected
        )
        for page in manifest.pages.keys.sorted() {
            if let validationFailure = validatePage(
                folderURL: folderURL,
                page: page,
                expectedHash: manifest.pages[page] ?? "",
                existingPageRelativePaths: existingPages,
                policy: policy
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
        policy: DownloadValidationPolicy
    ) -> DownloadValidationState? {
        guard !expectedHash.isEmpty else {
            return nil
        }

        // The re-probe carries the caller's mutation decision too: the page was classified usable a
        // moment ago, so a rejection here is a file that CHANGED between the two reads, and a
        // non-discarding caller must be left to authorize that removal like any other.
        guard let relativePath = existingPageRelativePaths[page],
              let pageURL = validatedChildURL(root: folderURL, relativePath: relativePath),
              sanitizeAssetFileIfNeeded(at: pageURL, discardingRejected: policy.discardingRejected)
        else {
            return .missingFiles(.RLocalizable.downloadStorePageMissing(page: page))
        }

        if policy.verifiesContentHashes {
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
