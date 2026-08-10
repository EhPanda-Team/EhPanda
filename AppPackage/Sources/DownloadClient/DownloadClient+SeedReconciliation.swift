import AppModels
import Foundation

// MARK: - Seed Reconciliation
/// The two readings `prepareWorkingSeed` takes of its one page-file scan: which refuted files this
/// preparation is authorized to destroy, and which pages the run may inherit rather than perform.
///
/// A pure move out of `DownloadClient+ExecutionSupport.swift`, which had reached 999 of the 1000
/// lines `file_length` allows at ERROR severity, so the next line added there would have failed the
/// build. The seam is the one 15-72 recorded and it mirrors 15-67's split of `PageFileScan` and the
/// blanking loop: both members below are readings of the preparation's evidence, while what stays
/// behind performs the preparation. Nothing about either function's behaviour changed in the move;
/// the only edit is the access level, widened from file-private to module-internal because the one
/// consumer of both now lives in another file of the same module.
extension DownloadCoordinator {
    /// Removes the page files this preparation positively refuted, once — and only once — the
    /// combined wholesale guard authorizes the whole set, and answers with a scan taken afterwards.
    ///
    /// **WR-02: the automatic route gets the ordering the validated-record route already had.** The
    /// shape being closed is not "a file was deleted too early" but "a file was never deleted at
    /// all". `probeAssetFileContent` — the exit `probeAssetFile` falls back to when the metadata
    /// read throws — reports an empty file as `.rejected(fileRemains: true)` unconditionally and
    /// deliberately, so a discarding scan does not clear it either. `removeRefutedPageFiles` was
    /// reachable from `reconcileValidatedRecordAgainstPageFiles` alone, which only a user-initiated
    /// Validate reaches. Between the two, a repair-seed preparation could meet a claimed page whose
    /// bytes had been positively refuted and leave it exactly as found, run after run: a record
    /// claiming a complete page over unusable bytes, with the loop's line 2b correctly declining to
    /// blank it because nothing had removed the file. Removing it here is what converts the page
    /// into the positively-absent shape the blanking loop, the fetch filter and finalize all already
    /// handle.
    ///
    /// It mirrors `reconcileValidatedRecordAgainstPageFiles`' ordering — classify, guard, remove,
    /// rescan, blank — rather than inventing a second one, with one evidence class fewer: there is
    /// no content pass on this route, so the refutations are the presence scan's own rejections and
    /// nothing else. The claimed-page derivation, the `unprobedPages` subtraction and the
    /// prospective union are the same expressions that pass reads.
    ///
    /// **The guard runs BEFORE the removal, and it is the same predicate the loop applies after.**
    /// Measuring `absences ∪ refutations` against `completedPageCount` here is exactly what the loop
    /// measures over the post-removal scan, because a removal moves a page from the refutation term
    /// to the absence term and leaves the sum where it was. So the two cannot disagree, and the
    /// removal cannot be the thing that talks the loop into blanking: a wholesale shape refuses at
    /// this guard with the disk untouched, and refuses again below for the same arithmetic.
    ///
    /// Ordering it this way round is also what keeps a FAILED removal honest. `removeRefutedPageFiles`
    /// reports the pages it could not remove; those files are still on disk, the rescan still reports
    /// them as refuted survivors, and the loop still holds their hashes — hash and file kept
    /// together, which is what a hold has to mean. Nothing here writes the manifest, so the durable
    /// blanking of everything this function did remove happens in the one loop, under the one rule.
    ///
    /// Runs inside `prepareWorkingSeed`'s existing D-G7-01 bracket rather than opening one of its
    /// own: the bracket rule is that movements compose as SIBLINGS and never nest, and every record
    /// movement this ordering produces is the loop's single write, which that bracket already spans.
    ///
    /// **It answers with the removed pages as well as the scan (WR-03), because they are the one
    /// thing no later probe can re-derive honestly.** The caller owes a compensation on every exit
    /// that fires after a removal, and that debt is defined by which files this pass destroyed —
    /// not by what a subsequent listing happened to yield. The same set is also what stops the
    /// announcement over-reporting: a page this pass deleted is positively absent by this pass's own
    /// act, whatever a failing rescan can or cannot say about it.
    func authorizedReconciliationScan(
        manifest: DownloadManifest,
        classifiedScan: PageFileScan,
        folderURL: URL,
        carriedUnprobedPages: Set<Int>
    ) -> AuthorizedReconciliation {
        // Every refusal below answers with the classification untouched and an EMPTY removal set,
        // which is a statement rather than a placeholder: a refusing pass destroyed nothing, so it
        // owes no compensation and presumes nothing absent.
        let refusal = AuthorizedReconciliation(scan: classifiedScan, removedPages: [])
        guard classifiedScan.scanSucceeded else { return refusal }
        let claimedPages = Set(manifest.pages.filter({ !$0.value.isEmpty }).keys)
        // A page whose OTHER candidate file went unprobed is subtracted: the pass holds a non-answer
        // about that page as well, and a non-answer standing beside a determination still forbids
        // destroying anything.
        let refutedPages = claimedPages
            .intersection(classifiedScan.rejectedPageRelativePaths.keys)
            .subtracting(classifiedScan.unprobedPages)
        guard !refutedPages.isEmpty else { return refusal }
        let positivelyAbsentPages = claimedPages
            .subtracting(classifiedScan.pages.keys)
            .subtracting(classifiedScan.rejectedPageRelativePaths.keys)
            .subtracting(classifiedScan.unprobedPages)
        guard positivelyAbsentPages.union(refutedPages).count < manifest.completedPageCount else {
            // Refused. The classification is handed on untouched, so the loop reaches the identical
            // arithmetic and returns the manifest verbatim over a disk this function did not move.
            return refusal
        }

        // AUTHORIZED. Everything above reads; everything below acts.
        let unremovedPages = storage.removeRefutedPageFiles(
            folderURL: folderURL,
            pageRelativePaths: classifiedScan.rejectedPageRelativePaths,
            refutedPages: refutedPages
        )
        // The pages whose files this pass actually destroyed — the validate route's own expression.
        // The unremoved complement is still not carried INTO THE SCAN: the rescan below re-derives
        // it from the disk, which is the stronger evidence and cannot drift from what the loop is
        // about to read. What the complement decides here is a different question the disk cannot
        // answer afterwards — which files this pass is responsible for having destroyed.
        let removedPages = refutedPages.subtracting(unremovedPages)
        // Taken fresh rather than derived, so a removal that failed is reported as the surviving
        // refutation it still is instead of being assumed away. The carried source-side non-answers
        // are re-unioned because this folder's listing can no more see them now than before.
        let rescan = storage.pageFileScan(
            folderURL: folderURL,
            manifest: manifest
        )
        return AuthorizedReconciliation(
            scan: PageFileScan(
                pages: rescan.pages,
                scanSucceeded: rescan.scanSucceeded,
                unprobedPages: rescan.unprobedPages.union(carriedUnprobedPages),
                rejectedPageRelativePaths: rescan.rejectedPageRelativePaths
            ),
            removedPages: removedPages
        )
    }

    /// What an authorized reconciliation answers with: the post-removal scan, and the claimed pages
    /// whose files this preparation destroyed to produce it.
    ///
    /// A named type rather than a labelled tuple, per this module's `labeled_tuple_elements` rule.
    /// Module-internal rather than file-private because the split above moved the producer out of
    /// the file its one consumer lives in; `prepareWorkingSeed` is still the only consumer, and
    /// what crosses out of that function is `WorkingSeed.removedPages`.
    struct AuthorizedReconciliation {
        let scan: PageFileScan
        let removedPages: Set<Int>
    }

    /// The pages a run inherits rather than performs — `RunProgressBasis.inheritedPages`'s one
    /// derivation, read from the very scan the preparation's destructive consumer read, so the
    /// credit rule and the blanking rule can never answer from different probes.
    ///
    /// Evidence, in order of authority. **THIS PASS'S OWN REMOVALS OUTRANK EVERYTHING (WR-03):** a
    /// page whose file this very preparation deleted is positively absent by the preparation's own
    /// act, so it is subtracted in BOTH branches and can never be presumed done. That knowledge is
    /// this pass's, not a probe's, which is why no rescan — succeeding, failing or refused — can
    /// overrule it. Below that, a successful listing is authoritative both ways: it yields the probed
    /// files, plus the claimed pages the per-file probe could not answer for — the same population
    /// the blanking loop refuses to blank, presumed done here for the same positive-signal reason it
    /// is preserved there. A failed listing is a non-answer, so the record's claims stand whole; only
    /// a POSITIVE absence — a successful listing that simply did not yield a claimed page's file —
    /// zeroes a claim. A COMPLETE-reading record then forfeits the claims the run was asked to fetch,
    /// because a repair or retry of a "finished" gallery is itself the route's assertion that those
    /// claimed pages are bad; an incomplete record's claims carry no such refutation — its to-do
    /// overlap comes only from the scan's own failure — so they stand, and the credited count's union
    /// is what keeps the overlap from ever counting twice.
    ///
    /// **The `scanSucceeded` source is decided here rather than inherited, and the subtraction is
    /// what makes the decision safe.** 15-67 re-sourced `WorkingSeed.scanSucceeded` from the
    /// POST-removal rescan so the credit rule and the blanking rule read one probe, and that stays:
    /// it is honest about whether this preparation could enumerate. What it newly admitted was a
    /// false value produced by a rescan failing AFTER a successful removal, which drove the
    /// non-answer branch below into presuming every claim done — including the pages the same pass
    /// had just deleted. Over-reporting is the direction the announcement's own doc calls "the
    /// defect", so the removals are subtracted instead of the source being reverted: the basis can
    /// still UNDER-report toward re-fetching, which D-G4-01 and the retirement ledger both choose on
    /// purpose, and it can no longer over-report at all.
    func inheritedPages(
        workingSeed: WorkingSeed,
        pendingPages: Set<Int>
    ) -> Set<Int> {
        let manifest = workingSeed.manifest
        let claimedPages = Set(manifest.pages.filter({ $0.value.isEmpty == false }).keys)
        let probedDonePages: Set<Int>
        if workingSeed.scanSucceeded {
            probedDonePages = Set(workingSeed.existingPages.keys)
                .union(claimedPages.intersection(workingSeed.unprobedPages))
        } else {
            probedDonePages = Set(workingSeed.existingPages.keys).union(claimedPages)
        }
        let presumedDonePages = probedDonePages.subtracting(workingSeed.removedPages)
        guard manifest.completedPageCount >= manifest.pageCount else { return presumedDonePages }
        return presumedDonePages.subtracting(pendingPages)
    }
}
