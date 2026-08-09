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
    /// irreversibility defence exists for, so the mismatched pages join the positively-absent ones
    /// under the loop's own comparison shape rather than under a second, laxer one. With an empty
    /// mismatch set this reduces byte for byte to the presence arm's behavior, so nothing 15-56
    /// established is weakened. The complementary systematic shape — the read failing for every page
    /// — produces an empty mismatch set and blanks nothing, which D-SSOT-03 covers.
    ///
    /// The ordering is load-bearing rather than stylistic: guard, then removal, then a fresh presence
    /// scan, then the loop. A refusal has to precede the first destructive act, or a reconciliation
    /// this function declined to write would already have destroyed the files it declined to write
    /// about.
    ///
    /// **D-SSOT-04: the mismatched files are removed, and the blanking still flows through the ONE
    /// loop.** Nothing here blanks a hash. Removal converts a corrupt-in-place page into the
    /// positively-absent shape, the rescan sees it as such, and
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
        let presenceScan = storage.pageFileScan(folderURL: folderURL, manifest: manifest)
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
        let prospectiveBlankPages = prospectiveBlankPages(
            claimedPages: claimedPages,
            presenceScan: presenceScan,
            mismatchedPages: contentScan.mismatched
        )
        guard prospectiveBlankPages.count < manifest.completedPageCount else { return false }

        let unremovedPages = storage.removeMismatchedPageFiles(
            folderURL: folderURL,
            pageRelativePaths: presenceScan.pages,
            mismatchedPages: contentScan.mismatched
        )
        let heldPages = contentScan.held
            .union(unremovedPages)
            .union(
                unclassifiedPages(
                    claimedPages: claimedPages,
                    contentScan: contentScan,
                    prospectiveBlankPages: prospectiveBlankPages
                )
            )
        // Taken after the removals, so the pages they emptied reach the loop as the positive
        // absences they now are. Reusing the pre-removal scan would hide them from the very
        // reconciliation the removal was performed for.
        let reconciliationScan = storage.pageFileScan(folderURL: folderURL, manifest: manifest)
        do {
            let reconciledManifest = try withdrawingCountedBasisMovement(gid: download.gid) {
                try reconcileWorkingManifestAgainstPageFiles(
                    manifest: manifest,
                    pageFileScan: reconciliationScan,
                    folderURL: folderURL
                )
            }
            return heldPages.isEmpty && reconciledManifest.pages != manifest.pages
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

    /// The pages this reconciliation would end up blanking if nothing refused — the set D-SSOT-02's
    /// wholesale guard is measured over.
    ///
    /// Its two halves are the two positive determinations, unioned because they license the same
    /// act: a claimed page the successful listing did not yield and no per-file signal held (the
    /// presence arm's own discipline, restated here rather than re-decided — the blanking loop
    /// applies exactly this predicate), and a claimed page the content pass read and refuted.
    ///
    /// Computing it BEFORE any removal is what makes the guard meaningful. After a removal the two
    /// halves are no longer distinguishable — a removed file is simply absent — so a guard measured
    /// then would be measuring the consequence of the act it is supposed to authorize.
    ///
    /// `claimedPages` arrives from the caller rather than being derived here, so this set and the
    /// coverage answer beside it are read off one expression.
    private func prospectiveBlankPages(
        claimedPages: Set<Int>,
        presenceScan: PageFileScan,
        mismatchedPages: Set<Int>
    ) -> Set<Int> {
        let positivelyAbsentPages = claimedPages
            .subtracting(presenceScan.pages.keys)
            .subtracting(presenceScan.unprobedPages)
        return positivelyAbsentPages.union(mismatchedPages)
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
