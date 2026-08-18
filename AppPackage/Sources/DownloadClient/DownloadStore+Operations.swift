import AppModels
import Foundation
import OSLogExt
import Resources

private let logger = Logger(category: .init(describing: DownloadStore.self))

/// What one validation pass is permitted to do while it forms its verdict.
///
/// Both members are decided ONCE, at the public boundary, and never vary per page, so they travel as
/// one value rather than as two flags threaded side by side through every level of the walk. Naming
/// them together is also the honest description: they are not two unrelated knobs but one answer to
/// "what may this pass do to the thing it is judging" — `verifiesContentHashes` says how deeply it
/// may READ, and `discardingRejected` says whether it may WRITE at all.
///
/// The second is the one CR-01 added, and no validation route sets it: a pass whose evidence
/// gathering deletes files cannot honour a refusal, because the refusal arrives after the deletion.
/// Since CR-03 that is what the parameter's default already says, so the member exists to carry the
/// public boundary's decision inward rather than to record an opt-out at each level.
private struct DownloadValidationPolicy {
    let verifiesContentHashes: Bool
    let discardingRejected: Bool
}

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
    /// authority to destroy a recorded hash or its file (D-SSOT-03). A page whose file the presence
    /// scan yielded and this pass then found unusable lands here too: the two reads can only
    /// disagree if the file changed between them, which is a race rather than a determination.
    let held: Set<Int>
}

extension DownloadStore {
    /// Returns the manifest with any missing page hashes filled in. Hashes are recorded at
    /// write time (per page as it downloads, and on capture-restore), so finalize only
    /// *merges*: it hashes a page solely when its recorded hash is empty, never re-hashing
    /// the whole gallery. There is no automatic re-validation anywhere; verifying existing
    /// bytes against their hashes is a user-initiated action (`validateImageData(gid:)`).
    public func addingCurrentFileHashes(
        to manifest: DownloadManifest,
        folderURL: URL
    ) throws -> DownloadManifest {
        // A READ (CR-03). The merge writes hashes for the EMPTY-hash pages only, while the scan
        // probes every claimed page — so a discarding scan here would delete the file of a page
        // whose hash this merge then leaves standing, and finalize would succeed over a record
        // claiming bytes it had itself removed. For the pages the merge does write, the verdict is
        // unchanged: a refused file is outside `pages` either way, and the throw below fires.
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
            // anything (CR-01) — and since CR-03 that is simply the default, so nothing is written
            // here. This re-probe can only disagree with the presence scan that just yielded the
            // file if the file CHANGED between the two reads, and a race is the weakest evidence in
            // the building — so the page is held, with its hash and its file both intact, and the
            // next validate classifies it from a settled disk.
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

    /// Removes whatever sits at a path inside the download root, and nothing outside it.
    ///
    /// **This is the RECORD-PATH primitive, and it is deliberately more permissive than the
    /// user-folder boundary (CR-02).** Its containment is prefix-based because its caller
    /// legitimately names a gallery folder NESTED under a user folder — `removeGalleryFolders`
    /// passes URLs the scan produced — and no direct-child boundary would admit those. That
    /// permissiveness is exactly why a caller-supplied user-folder NAME must never arrive here:
    /// prefix containment refuses `..` and an absolute path and ADMITS `"MyFolder/[123_abc] Some
    /// Title"`, which removes a gallery folder the caller never named while the coordinator's
    /// exact `parentFolderName` cleanup key matches nothing. `deleteUserFolder(named:)` owns that
    /// family now, and no user-folder deletion routes through here any more.
    ///
    /// **The string-taking spelling of this primitive is deleted rather than kept for vocabulary
    /// (WR-01).** It joined an arbitrary caller-supplied path to the root and handed the result
    /// straight here, so it was the one-call rewrite of the defect above — with no caller to weigh
    /// against that. This entry point takes a URL, so reaching the same place now takes composing
    /// two functions whose docs both refuse it.
    ///
    /// Both containment questions are asked, for the reason `confinedDirectUserFolderURL` records
    /// about its own pair: standardization answers a path that climbs out lexically, resolution
    /// answers a path whose own last component links out, and neither implies the other. Without
    /// the second, a symbolic link staged inside the root is a removal of whatever it points at.
    public func removeFolder(at folderURL: URL) throws {
        let targetURL = folderURL.standardizedFileURL
        guard targetURL.path.hasPrefix(rootURL.standardizedFileURL.path + "/"),
              targetURL.resolvingSymlinksInPath().path
                .hasPrefix(rootURL.resolvingSymlinksInPath().path + "/")
        else {
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
    ///   the caller never named. A source is admitted or refused as written, never repaired, which
    ///   is also why an admitted source may be a spelling this app would never mint: the listing
    ///   produces such names and this boundary must not disown them (CR-01). A destination is the
    ///   opposite case: the caller is asking for a name to be created, so normalizing it is the
    ///   entire point. The asymmetry is the design rather than an oversight.
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
                    String(localized: .RLocalizable.downloadStoreFolderAlreadyExists)
                )
            }
            try manager.moveItem(at: sourceURL, to: destinationURL)
        }
    }

    /// Deletes a user folder, owning the whole filesystem boundary of that removal (CR-02).
    ///
    /// The un-swept sibling of `renameUserFolder`. `rawName` reaches this from a public client API
    /// exactly as `oldName` does, and until this existed the coordinator appended it to the root
    /// and handed the result to `removeFolder(at:)`, whose prefix containment admits any nested
    /// path — so a name joining a user folder to a gallery folder inside it removed that gallery
    /// recursively. The record half followed from the same construction: the coordinator's cleanup
    /// keys on an exact `parentFolderName == rawName` match, which a nested name never satisfies,
    /// so `downloadIndex`, the queue store and the background-task store went on claiming a
    /// gallery whose folder had just been erased. Admitting only a direct child closes both at
    /// once — the removal cannot reach a gallery folder, and the cleanup key becomes exact by
    /// construction rather than by luck.
    ///
    /// - Throws: `.fileOperationFailed` for a name that is not an acceptable direct child and for
    ///   an acceptable name whose item is not a plain directory — a symbolic link included, since
    ///   `attributesOfItem` describes the link rather than its target, and removing it would
    ///   destroy the caller's own view of a folder that is still there; `.notFound` for an
    ///   acceptable name with nothing at it.
    public func deleteUserFolder(named rawName: String) throws {
        try mutatingConfinedUserFolder(named: rawName) { folderURL, manager in
            guard let folderType = itemType(at: folderURL, using: manager) else {
                throw AppError.notFound
            }
            guard folderType == .typeDirectory else {
                throw invalidUserFolderNameError()
            }
            try manager.removeItem(at: folderURL)
        }
    }

    /// Creates a user folder that must not already be there (CR-02).
    ///
    /// The already-exists refusal is taken inside the lock that creates, rather than by a caller
    /// that then creates separately, so the answer the caller acts on is the state the creation
    /// meets. `withIntermediateDirectories: false` is the honest spelling for a direct child whose
    /// only ancestor is the root this call has just ensured.
    ///
    /// - Throws: `.fileOperationFailed` for a name that is not an acceptable direct child and for
    ///   an acceptable name that is already occupied.
    @discardableResult
    public func createUserFolder(named rawName: String) throws -> URL {
        try ensureRootDirectory()
        return try mutatingConfinedUserFolder(named: rawName) { folderURL, manager in
            guard itemType(at: folderURL, using: manager) == nil else {
                throw AppError.fileOperationFailed(
                    String(localized: .RLocalizable.downloadStoreFolderAlreadyExists)
                )
            }
            try manager.createDirectory(at: folderURL, withIntermediateDirectories: false)
        }
    }

    /// Creates a user folder if it is not already there, and answers where it is (CR-02).
    ///
    /// The idempotent half of the pair, for the caller that needs the folder to exist rather than
    /// to be new — a destination whose directory the user may have removed through the Files app.
    /// It ensures the root first so a root recreated underneath us regains its backup exclusion,
    /// which creating the intermediate directories alone would silently skip.
    ///
    /// - Throws: `.fileOperationFailed` for a name that is not an acceptable direct child.
    @discardableResult
    public func ensureUserFolder(named rawName: String) throws -> URL {
        try ensureRootDirectory()
        return try mutatingConfinedUserFolder(named: rawName) { folderURL, manager in
            try manager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        }
    }

    /// Runs `body` against the confined URL for `rawName`, and only ever against that one.
    ///
    /// **This is the SHAPE of the boundary rather than a convenience (CR-02).** Every user-folder
    /// mutation is written as a closure handed to this function, so there is no spelling of
    /// "create, move or remove a user folder" that can skip the confined resolution: a later
    /// sibling cannot regress by forgetting a check, because it has nowhere else to put its
    /// mutation. That is the property 15-63 left to discipline and this round makes structural —
    /// `deleteFolder` was the sibling discipline missed.
    ///
    /// The resolution is taken once outside the lock and decided AGAIN inside it, immediately
    /// before `body` runs, for the reason `renameUserFolder` records: the leaf's symlink status
    /// and the root's own resolution are disk state, so a decision taken before the lock is a
    /// decision about a disk that may since have changed.
    @discardableResult
    private func mutatingConfinedUserFolder(
        named rawName: String,
        perform body: (URL, FileManager) throws -> Void
    ) throws -> URL {
        guard let folderURL = confinedDirectUserFolderURL(named: rawName) else {
            throw invalidUserFolderNameError()
        }
        try fileManager.operate { manager in
            guard confinedDirectUserFolderURL(named: rawName) == folderURL else {
                throw invalidUserFolderNameError()
            }
            try body(folderURL, manager)
        }
        return folderURL
    }

    /// The URL of `rawName`, but only when it names a direct child of the download root.
    ///
    /// **This is an ADMISSION test, and its terms are the LISTING's terms (CR-01).** `scanDownloads`
    /// promotes every visible non-gallery-shaped directory under the root to a user folder with no
    /// name filter at all, and the app ships with File Sharing and open-in-place over a root inside
    /// `Documents/` — so the names it produces describe a disk this app does not own. `Art  Books`,
    /// ` Photos`, `Manga\Vol1` and `Misc etc.` are all real, listed, usable folders. Requiring a
    /// source to already equal the spelling this app would MINT for it therefore refused folders the
    /// app itself displays, leaving them un-deletable and un-renamable from inside the app while the
    /// error called the displayed name invalid.
    ///
    /// Rewriting a source instead would be worse, which is why the answer is to loosen rather than
    /// to repair: `normalizedUserFolderName` maps separators and padding away, so it SELECTS —
    /// `"  Photos  "` becomes the real `Photos` — and the mutation would reach an object the caller
    /// never named. A source is admitted or refused as written, never repaired. The MINTING sites
    /// keep normalizing (`createFolder`, and the rename's new name), because there the caller is
    /// asking for a name to be made rather than pointing at one that exists.
    ///
    /// What this deliberately does NOT admit, and what each refusal costs against the listing:
    ///
    /// - An empty name, `.`, `..`, or more than one path component. `contentsOfDirectory` yields
    ///   none of these, so no listed folder can be refused by them — and they are what refuses
    ///   `"MyFolder/[123_abc] Title"`, `"../Outside"` and an absolute path.
    /// - A name carrying control characters. POSIX permits those in a filename, so this is the one
    ///   refusal that could in principle name a real listed directory. It is kept deliberately: such
    ///   a name flows into log lines, error strings and a `Result` the UI renders, and the cost of
    ///   the refusal is bounded to a shape no ordinary file browser will produce.
    /// - A gallery-shaped name. The listing never promotes one to a user folder, so this cannot
    ///   refuse a listed name either, and it keeps a user-folder mutation off a gallery folder that
    ///   happens to sit directly under the root.
    /// - A name whose standardized parent is not the root, and one whose SYMLINK-RESOLVED parent is
    ///   not. Both are required and neither implies the other: the first refuses a name that climbs
    ///   out lexically, the second a name whose own last component links out. Note that the scan
    ///   follows symlinks, so a linked directory IS listed; refusing it here is the second
    ///   deliberate narrowing, for the reason `renameUserFolder`'s type check records — renaming or
    ///   removing through a link acts on the link, not on the folder the caller is looking at.
    ///
    /// Module-visible rather than private because the coordinator has two questions that are this
    /// same question and no other: whether an absent folder should answer `.notFound` before any
    /// scheduling state moves, and where a move's destination parent is. Both are RESOLUTIONS —
    /// every mutation still goes through `mutatingConfinedUserFolder`, and handing out a URL this
    /// function has already confined widens nothing.
    func confinedDirectUserFolderURL(named rawName: String) -> URL? {
        guard !rawName.isEmpty,
              rawName != ".",
              rawName != "..",
              rawName.split(separator: "/", omittingEmptySubsequences: false).count == 1,
              !rawName.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              !DownloadStore.isGalleryFolderLikeName(rawName)
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
    /// deletion is allowed to fire while this verdict is being reached.
    ///
    /// **It defaults to withholding that deletion, and the earlier justification for the opposite
    /// applied the wrong test (CR-03).** That test was whether a caller's ANSWER feeds something
    /// destructive; the hazard is that FORMING the answer destroys files. It is the same hazard
    /// however harmless the verdict's use: `loadManifest`'s readability check and `resumeMode`'s
    /// repair-versus-redownload question decide nothing irreversible, and both of them nevertheless
    /// deleted a claimed page's file on an ordinary read while nothing on either route wrote the
    /// manifest — so the record went on claiming a page the app itself had removed, across relaunch.
    /// A report is a read. `validateImageData` needs the same value for a further reason: its
    /// verdict is the input to a reconciliation that may refuse, and a refusal must find the disk
    /// exactly as it was.
    public func validate(
        download: DownloadedGallery,
        verifiesContentHashes: Bool,
        discardingRejected: Bool = false
    ) -> DownloadValidationState {
        let folderURL = download.folderURL
        guard fileManager.operate({ $0.fileExists(atPath: folderURL.path) }) else {
            return .missingFiles(.RLocalizable.downloadStoreDownloadFolderMissing)
        }
        let manifestURL = download.manifestURL
        guard fileManager.operate({ $0.fileExists(atPath: manifestURL.path) }) else {
            return .missingFiles(.RLocalizable.downloadStoreManifestMissing)
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
        // A READ (CR-03). Both callers throw on a refusal and neither lowers the record for the page
        // it threw over, so a deletion here would leave `refreshManifestPageFileHashes`' claimed
        // page with its previous non-empty hash beside no file at all.
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
