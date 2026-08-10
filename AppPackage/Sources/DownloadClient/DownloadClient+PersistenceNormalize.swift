import AppModels
import Foundation
import OSLogExt

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

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
    /// folder's manifest, gathers fresh per-page evidence, and runs the D-G5-01 blanking loop under
    /// its own refusal discipline. When the loop blanks, the record itself now says the gallery is
    /// incomplete — the badge count, `displayStatus`, the start gates and `resumeMode` all read that
    /// one persisted truth, and it survives relaunch because the loop writes the manifest and
    /// re-indexes it. `validationErrors` is then cleared, deliberately: it outranks everything in
    /// `displayStatus`, so an entry left behind would pin `.error` over an honest record and make it
    /// unstartable, which is the whole defect this closes.
    ///
    /// **D-SSOT-01: both kinds of positive per-page evidence reconcile, because they are the same
    /// kind.** This is the one path that re-reads page bytes, so it holds a determination a presence
    /// scan cannot make: a readable file whose fresh hash disagrees with the recorded one. That is
    /// page-scoped and positive exactly as an absence is, so it blanks exactly as an absence does —
    /// with the refuted file removed first, so the blanked page is genuinely repairable rather than
    /// laundered (D-SSOT-04).
    ///
    /// **CR-01: every scan this path takes is non-mutating.** The same separation the display path
    /// needed for a different reason: a probe that deletes what it refuses is a mutation performed
    /// by an ACT OF LOOKING, and this function's whole contract is that it may refuse — which it
    /// cannot honour if gathering the evidence already destroyed the files the refusal was about.
    /// Rejected pages are classified, carried into the combined guard, and their files removed only
    /// once that guard authorizes the whole set. Since CR-03 that is what a scan does by DEFAULT, so
    /// this route writes no argument: the property now holds for a scan a later round adds here
    /// without anyone remembering to opt it out.
    ///
    /// **D-SSOT-05: `validationErrors` is an OPERATION-level signal and nothing else.** An entry
    /// means the pass could not produce trustworthy evidence for every claimed page — the scan
    /// failed, a page's bytes could not be read, or the wholesale guard refused the whole
    /// reconciliation — never that the record is suspect. Where the pass classified every claimed
    /// page and the licensed correction was written, the record states the finding itself and the
    /// entry is dropped; `canValidateImageData`'s error disjunct keeps Validate re-runnable wherever
    /// one is kept.
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

    /// Makes a `.missingFiles` verdict durable for every page this pass positively classified, and
    /// reports whether the pass covered every claimed page (D-G5B-01, D-SSOT-01).
    ///
    /// The evidence is gathered here and now, never taken from the verdict: `storage.validate`
    /// short-circuits at the first failing page, so its message names one page while the gallery has
    /// a SET — and a partially-broken gallery must reconcile exactly that set, whichever page
    /// validate happened to report. Two passes supply it, in the order their guards demand:
    ///
    /// 1. A page-file scan, whose 15-56 refusal line is kept verbatim — a failed enumeration answers
    ///    nothing at all, so the whole reconciliation refuses (G-15-9).
    /// 2. A content pass over what that scan yielded, which re-hashes each claimed page's bytes and
    ///    partitions them into verified, positively mismatched, and held (D-SSOT-01/D-SSOT-03).
    ///
    /// **D-SSOT-02: the wholesale guard is evaluated over the COMBINED prospective blank set, before
    /// any destructive step.** A systematically wrong hash pipeline — a `fileHash` regression, an
    /// algorithm change — would mismatch every readable page, which is exactly the class the
    /// irreversibility defence exists for, so the refuted pages join the positively-absent ones
    /// under the loop's own comparison shape rather than under a second, laxer one. With an empty
    /// refutation set this reduces byte for byte to the presence arm's behavior, so nothing 15-56
    /// established is weakened. The complementary systematic shape — the read failing for every page
    /// — produces an empty mismatch set and blanks nothing, which D-SSOT-03 covers.
    ///
    /// **CR-01: "before any destructive step" now includes the evidence gathering itself, and that
    /// is what makes the sentence true rather than aspirational.** The probe's housekeeping deletion
    /// used to fire while the pass was still deciding: `storage.validate` and this function's own
    /// presence scan both took the discarding default, so a zero-byte or non-regular page file was
    /// deleted BY the classification. On a one-page gallery the guard then refused — the prospective
    /// set was the whole record — and the pass ended having destroyed the file it had just declined
    /// to blank the hash for, leaving a divergence marked only by a session-scoped entry a relaunch
    /// drops. Every scan above the guard is therefore non-mutating — since CR-03 by taking the
    /// default rather than by naming it — and the rejected pages carry their file identity forward
    /// so the authorized step can remove exactly them.
    ///
    /// The ordering is load-bearing rather than stylistic: classify, guard, remove, take a fresh
    /// non-mutating scan, then the loop. A refusal has to precede the first destructive act, or a
    /// reconciliation this function declined to write would already have destroyed the files it
    /// declined to write about.
    ///
    /// **Removal precedes the write DELIBERATELY, and reversing it is the more dangerous order —
    /// the opposite of how it reads.** The obvious correction to "files are gone while the record
    /// still claims them" is to blank and write first and remove afterwards. Do not make it. A
    /// FAILED removal would then leave a page durably blank beside a surviving file, which is
    /// exactly the D-SSOT-04 laundering shape, and that state is one user tap from permanent silent
    /// corruption: `retryPages` clears the transient entry at enqueue and queues a `.repair`; the
    /// run's `pendingPageIndices` fetches only pages whose file is MISSING, so the surviving corrupt
    /// file is never re-fetched; and `finalizeDownload`'s `addingCurrentFileHashes` merge then
    /// re-hashes exactly the blank-hash pages from the bytes on disk, recording the corruption as
    /// truth with a matching hash no later validation can refute. The current order's own failure
    /// state — files gone, hashes still claimed — is strictly more recoverable, because the removed
    /// files are positively absent, so the next validate blanks them under the ordinary guards. That
    /// asymmetry is why the destructive step stays first and the recovery below exists instead.
    ///
    /// **Recover once, never return verbatim, and never silently (CR-02).** Three exits fire AFTER
    /// the removal — a rescan that could not enumerate, the loop's own refusal lines applied to the
    /// post-removal scan, and a thrown manifest write — and each would otherwise leave the record
    /// claiming pages this pass deleted. So every one of them re-attempts the same pass ONCE: a
    /// fresh scan through the same loop, with zero new blanking paths and every refusal guard
    /// intact. The pages this pass removed are positively absent by construction, so a retry that
    /// gets an answer blanks them under the loop's ordinary evidence rules. When the retry fails too
    /// the removed page indices are logged at `error` beside the masked gid, so a device archive can
    /// show which files were destroyed against a record that still claims them, and the entry is
    /// kept.
    ///
    /// **D-SSOT-04: the refuted files are removed, and the blanking still flows through the ONE
    /// loop.** Nothing here blanks a hash. Removal converts a corrupt-in-place or structurally
    /// refused page into the positively-absent shape, the rescan sees it as such, and
    /// `reconcileWorkingManifestAgainstPageFiles` blanks it through its own three refusal lines,
    /// unmodified — so there is no second blanking rule to drift from the first. A page whose file
    /// could not be removed is folded into the held set instead, keeping its hash.
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
    ///
    /// **D-SSOT-05: the return value is about the OPERATION, not about the record.** True means this
    /// pass classified every claimed page and wrote the correction they licensed, so the record can
    /// state the finding by itself and the caller drops its entry. Any hold, any refusal, any page
    /// the pass could not classify at all and any thrown write answers false, because there the pass
    /// has something the manifest legitimately cannot record. "Every claimed page" is answered off
    /// the content pass's own partition rather than re-derived — see `unclassifiedPages` — so a
    /// population that is invisible to one of the two sets cannot be invisible to only one of them.
    private func reconcileValidatedRecordAgainstPageFiles(
        download: DownloadedGallery
    ) -> Bool {
        let folderURL = download.folderURL
        guard let manifest = storage.probeManifest(folderURL: folderURL) else { return false }
        // Non-mutating, like the verdict scan above it: until the guard below accepts, this function
        // is gathering evidence and nothing more (CR-01). Since CR-03 that is the default, so the
        // absence of an argument here is the statement rather than the omission of one.
        let presenceScan = storage.pageFileScan(
            folderURL: folderURL,
            manifest: manifest
        )
        guard presenceScan.scanSucceeded else { return false }
        let contentScan = storage.contentMismatchScan(
            folderURL: folderURL,
            manifest: manifest,
            pageFileScan: presenceScan
        )
        // Derived once, here, and handed to both readers below. The guard's population and the
        // coverage answer are two questions about the SAME set, and deriving each from its own
        // expression is precisely how the unprobed pages came to be excluded from the blanking set
        // while still counting as covered by the answer that clears the operation-level signal.
        let claimedPages = Set(manifest.pages.filter({ !$0.value.isEmpty }).keys)
        // The claimed pages this pass positively REFUTED: a file the listing yielded whose fresh
        // hash disagrees with the record, or a file the probe refused outright and left in place.
        // One set because one evidence class and one authorized act — it decides which files are
        // removed and, with the positive absences, what the guard is measured over. A page whose
        // OTHER candidate went unprobed is subtracted: the pass has a non-answer about that page as
        // well, and a non-answer standing beside a determination still forbids destroying anything.
        let refutedPages = claimedPages
            .intersection(
                contentScan.mismatched.union(presenceScan.rejectedPageRelativePaths.keys)
            )
            .subtracting(presenceScan.unprobedPages)
        let prospectiveBlankPages = prospectiveBlankPages(
            claimedPages: claimedPages,
            presenceScan: presenceScan,
            refutedPages: refutedPages
        )
        guard prospectiveBlankPages.count < manifest.completedPageCount else { return false }

        // AUTHORIZED. Everything above reads; everything below acts.
        let unremovedPages = storage.removeRefutedPageFiles(
            folderURL: folderURL,
            pageRelativePaths: presenceScan.pages.merging(
                presenceScan.rejectedPageRelativePaths,
                uniquingKeysWith: { yielded, _ in yielded }
            ),
            refutedPages: refutedPages
        )
        // The pages whose files this pass actually destroyed, which is exactly the set the record
        // now owes a blank hash for. `unremovedPages` is its complement and keeps its recorded hash,
        // because a page whose file survived must not end up claiming nothing.
        let removedPages = refutedPages.subtracting(unremovedPages)
        let heldPages = contentScan.held
            .union(unremovedPages)
            .union(
                unclassifiedPages(
                    claimedPages: claimedPages,
                    contentScan: contentScan,
                    prospectiveBlankPages: prospectiveBlankPages
                )
            )
        do {
            let reconciledManifest = try blankingPass(
                gid: download.gid,
                manifest: manifest,
                folderURL: folderURL
            )
            guard reconciledManifest.claimsAnyPage(in: removedPages) else {
                return heldPages.isEmpty && reconciledManifest.pages != manifest.pages
            }
            // Post-removal exits 1 and 2: the loop handed the manifest back verbatim — the rescan
            // could not enumerate, or its own refusal lines fired on the post-removal scan — so the
            // record still claims pages whose files are gone.
            return recoveredBlanking(
                gid: download.gid,
                manifest: manifest,
                removedPages: removedPages,
                folderURL: folderURL
            ) && heldPages.isEmpty
        } catch {
            // Post-removal exit 3: the throw can only come from the loop's manifest write. Where
            // this pass destroyed nothing, the record still claims exactly what it claimed before,
            // so the verdict simply has nowhere durable to live and the caller's transient entry is
            // the honest surface for that — the silence is deliberate rather than swallowed, and the
            // loop logs the writes it does perform.
            guard !removedPages.isEmpty else { return false }
            // Where this pass DID destroy files, the old premise is false: returning here would
            // leave the record claiming pages that no longer exist, marked only by session state.
            return recoveredBlanking(
                gid: download.gid,
                manifest: manifest,
                removedPages: removedPages,
                folderURL: folderURL
            ) && heldPages.isEmpty
        }
    }

    /// One bracketed run of the D-G5-01 blanking loop over a page-file scan taken fresh at the call.
    ///
    /// The scan is taken here rather than passed in, so the pages a removal emptied reach the loop as
    /// the positive absences they now are, and so the recovery attempt cannot accidentally re-use the
    /// stale scan its predecessor already failed against. Reusing a pre-removal scan would hide the
    /// removed pages from the very reconciliation the removal was performed for.
    ///
    /// Both attempts route through this one function, which is also what keeps
    /// `withdrawingCountedBasisMovement` at a single call site in this file: the bracket is the same
    /// sibling bracket the repair-seed preparation wraps this loop in, the two attempts compose as
    /// SIBLINGS rather than nesting, and its delta-keying means an attempt that blanks nothing
    /// withdraws exactly zero by construction.
    ///
    /// **The scan is non-mutating here too, which is what keeps the removal's own failures honest
    /// (CR-01).** A discarding scan at this point would quietly finish the job for a page whose
    /// removal had just failed: the file would be deleted after all, outside the accounting that
    /// decided the page was a hold, and the loop would blank a hash on the strength of a deletion
    /// nobody recorded. Withheld, the surviving refuted file is still reported as such, the loop
    /// skips the page, and its hash stands — which is exactly what "a failed removal demotes to a
    /// hold" has to mean on disk.
    private func blankingPass(
        gid: String,
        manifest: DownloadManifest,
        folderURL: URL
    ) throws -> DownloadManifest {
        let pageFileScan = storage.pageFileScan(
            folderURL: folderURL,
            manifest: manifest
        )
        return try withdrawingCountedBasisMovement(gid: gid) {
            try reconcileWorkingManifestAgainstPageFiles(
                manifest: manifest,
                pageFileScan: pageFileScan,
                folderURL: folderURL
            )
        }
    }

    /// Re-attempts the blanking write ONCE for the pages this pass already removed, and reports
    /// whether the record and the disk agree when it returns.
    ///
    /// Called from every post-removal exit, because all three leave the same state: files destroyed,
    /// hashes still claimed. The retry adds no blanking path — it is the identical pass over a fresh
    /// scan — so the loop's three refusal lines and the wholesale guard still decide. What it buys is
    /// the transient case: an enumeration that failed once, a write that failed once, a folder busy
    /// for an instant. The removed pages are positively absent by construction, so an attempt that
    /// gets an answer blanks exactly them.
    ///
    /// A second failure is NOT silent. Recorded hashes now describe files this app deleted, and that
    /// divergence outlives the session while the `validationErrors` entry marking it does not, so the
    /// removed page indices go to the log at `error` with the gid hash-masked — the module's identity
    /// pattern, and the only trail a device archive could show. Returning false keeps the entry.
    private func recoveredBlanking(
        gid: String,
        manifest: DownloadManifest,
        removedPages: Set<Int>,
        folderURL: URL
    ) -> Bool {
        do {
            let recoveredManifest = try blankingPass(
                gid: gid,
                manifest: manifest,
                folderURL: folderURL
            )
            if !recoveredManifest.claimsAnyPage(in: removedPages) { return true }
        } catch {
            // The retry's own write threw. The error itself adds nothing the log line below does not
            // already say, and that line is what the removals oblige.
        }
        let removedPageList = removedPages.sorted().map(String.init).joined(separator: ", ")
        logger.error(
            """
            Validation removed refuted page files the record still claims, pages: \
            \(removedPageList, privacy: .public), \
            gid: \(gid, privacy: .private(mask: .hash)).
            """
        )
        return false
    }

    /// The pages this reconciliation would end up blanking if nothing refused — the set D-SSOT-02's
    /// wholesale guard is measured over.
    ///
    /// Its two halves are the positive determinations, unioned because they license the same act:
    /// the ABSENCES, a claimed page a successful listing did not yield at all and no per-file signal
    /// held (the presence arm's own discipline, restated here rather than re-decided — the blanking
    /// loop applies exactly this predicate), and the REFUTATIONS the caller derived, a claimed page
    /// whose file is there and was proven unusable by content or by structure.
    ///
    /// The absent half now subtracts the rejected pages explicitly, and that subtraction is not
    /// cosmetic: while the probe deleted what it refused, a rejected page WAS absent by the time
    /// anyone read this, so the two halves overlapped harmlessly. With the deletion withheld until
    /// the guard authorizes it, a rejected page's file is still on disk here, and calling it absent
    /// would be the same conflation one level up — it would count toward the guard as a page nothing
    /// needs to be done to, when in fact it owes a removal.
    ///
    /// Computing it BEFORE any removal is what makes the guard meaningful. After a removal the
    /// halves are no longer distinguishable — a removed file is simply absent — so a guard measured
    /// then would be measuring the consequence of the act it is supposed to authorize.
    ///
    /// `claimedPages` and `refutedPages` arrive from the caller rather than being derived here, so
    /// this set, the removal's population and the coverage answer beside it are read off one
    /// expression each.
    private func prospectiveBlankPages(
        claimedPages: Set<Int>,
        presenceScan: PageFileScan,
        refutedPages: Set<Int>
    ) -> Set<Int> {
        let positivelyAbsentPages = claimedPages
            .subtracting(presenceScan.pages.keys)
            .subtracting(presenceScan.rejectedPageRelativePaths.keys)
            .subtracting(presenceScan.unprobedPages)
        return positivelyAbsentPages.union(refutedPages)
    }

    /// The claimed pages this pass could not classify AT ALL — the coverage gap D-SSOT-05's return
    /// value has to see, expressed through `ContentMismatchScan`'s partition rather than re-derived.
    ///
    /// The partition identity is the whole mechanism. `verified ∪ mismatched ∪ held` covers exactly
    /// the claimed pages the presence scan YIELDED, and `prospectiveBlankPages` covers exactly the
    /// claimed pages a successful listing positively did NOT yield. Anything left over is therefore
    /// a claimed page whose file the listing did list and whose probe could not classify it — the
    /// per-file non-answer `PageFileScan.unprobedPages` carries (G-15-13). Nothing at all was
    /// established about such a page, so the pass cannot claim to have covered every claimed page,
    /// and it joins the held set: the blanking loop already refuses to touch it and
    /// `prospectiveBlankPages` already excludes it, so the coverage answer was the one reader that
    /// never saw the population — which cleared the operation-level signal over an unanswered page
    /// and, with it, disabled the only sensor that could ask again (`canValidateImageData`).
    ///
    /// `verified` is load-bearing here rather than decorative: dropping it from the union would
    /// report every intact page as unclassified. That is why the content pass returns a whole
    /// partition instead of a remainder each caller re-derives — a re-derived remainder is exactly
    /// what silently lost this population.
    private func unclassifiedPages(
        claimedPages: Set<Int>,
        contentScan: ContentMismatchScan,
        prospectiveBlankPages: Set<Int>
    ) -> Set<Int> {
        let classifiedPages = contentScan.verified
            .union(contentScan.mismatched)
            .union(contentScan.held)
        return claimedPages
            .subtracting(classifiedPages)
            .subtracting(prospectiveBlankPages)
    }
}

private extension DownloadManifest {
    /// Whether this manifest still records a non-empty hash for any of `pageIndices`.
    ///
    /// The recovery's whole question, asked of the record rather than of a return code: a blanking
    /// attempt that refused and one that threw are indistinguishable from their outcome alone, and
    /// what matters to the caller is neither — it is whether the record still claims a page whose
    /// file is gone.
    func claimsAnyPage(in pageIndices: Set<Int>) -> Bool {
        pageIndices.contains(where: { pages[$0]?.isEmpty == false })
    }
}
