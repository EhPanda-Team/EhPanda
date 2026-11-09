import AppModels
import Foundation
import OSLogExt

private let logger = Logger(category: .init(describing: DownloadCoordinator.self))

// MARK: - Corroborated Wholesale Absence (B1)
extension DownloadCoordinator {
    /// Whether a successful scan positively found EVERY claimed page of `manifest` absent.
    ///
    /// The one predicate both halves of B1 read, so Verify's recording and the stop's consumption
    /// cannot disagree about what "every claimed page positively absent" means. It is the
    /// positive-signal rule of `reconcileWorkingManifestAgainstPageFiles` applied to the whole
    /// gallery at once: a failed listing answers nothing, an unprobed page is a non-answer, and a
    /// page whose file the listing yielded — usable or refused — is not absent. A manifest claiming
    /// nothing has nothing to be absent and answers false.
    func everyClaimedPageIsPositivelyAbsent(
        manifest: DownloadManifest,
        pageFileScan: PageFileScan
    ) -> Bool {
        let claimedPages = manifest.pages.filter({ !$0.value.isEmpty }).keys
        guard pageFileScan.scanSucceeded, !claimedPages.isEmpty else { return false }
        return claimedPages.allSatisfy { page in
            pageFileScan.pages[page] == nil
                && pageFileScan.rejectedPageRelativePaths[page] == nil
                && !pageFileScan.unprobedPages.contains(page)
        }
    }

    /// Records Verify's evidence when its full fresh scan found every claimed page positively
    /// absent, and drops any older entry otherwise. Records only; it never blanks (G-15-2G).
    func recordWholesaleAbsenceEvidence(
        gid: String,
        manifest: DownloadManifest,
        pageFileScan: PageFileScan,
        folderURL: URL
    ) {
        guard everyClaimedPageIsPositivelyAbsent(manifest: manifest, pageFileScan: pageFileScan) else {
            wholesaleAbsenceEvidence[gid] = nil
            return
        }
        wholesaleAbsenceEvidence[gid] = WholesaleAbsenceEvidence(
            folderURL: folderURL.standardizedFileURL,
            pages: manifest.pages
        )
    }

    /// Drops the record's whole claim at a stop, when Verify's scan and this stop's fresh scan BOTH
    /// found every claimed page positively absent (B1, product lead's EhPanda msg 2903).
    ///
    /// **Why at `commitPause`.** The two stops this closes have no run evidence of their own: a
    /// pause during the payload fetch, before the run announced its measurement (K0-b), and a
    /// pause of a repair still queued behind another gallery (K0-c), which no run exit ever sees.
    /// `commitPause` is the one point the in-app Pause and the card's cancel or expiry both pass,
    /// and it runs this after the cancelled run has fully exited, so the run's own write-back
    /// (K0-a) has already acted where it could; a record that write-back moved no longer carries
    /// the hashes the evidence was taken over, and the entry declines.
    ///
    /// **The safety rule.** The entry is consumed whatever happens next, so it can license at most
    /// one act. It declines unless the gallery still lives in the folder Verify scanned and its
    /// manifest still claims exactly the hashes Verify saw, and unless a FRESH scan taken here finds
    /// every one of those pages positively absent too. Only then are the claims blanked, through
    /// the shared reconciliation with every claimed page as corroboration, so lines 1, 2 and 2b
    /// still decide page by page and no single scan can blank a whole gallery.
    ///
    /// The blanking lowers the counted basis, so it runs in a D-G7-01 bracket like every other
    /// caller of the loop. It is synchronous on the actor between `commitPause`'s awaits, so no
    /// other bracket is open and nothing inside it deletes: a sibling.
    func writeBackCorroboratedWholesaleAbsence(gid: String) {
        guard let evidence = wholesaleAbsenceEvidence.removeValue(forKey: gid),
              let folderURL = downloadIndex[gid]?.folderURL,
              folderURL.standardizedFileURL == evidence.folderURL,
              let manifest = storage.probeManifest(folderURL: folderURL),
              manifest.gid == gid,
              manifest.pages == evidence.pages
        else { return }
        let pageFileScan = storage.pageFileScan(folderURL: folderURL, manifest: manifest)
        guard everyClaimedPageIsPositivelyAbsent(manifest: manifest, pageFileScan: pageFileScan)
        else { return }
        do {
            _ = try withdrawingCountedBasisMovement(gid: gid) {
                try reconcileWorkingManifestAgainstPageFiles(
                    manifest: manifest,
                    pageFileScan: pageFileScan,
                    folderURL: folderURL,
                    corroboratedAbsentPages: Set(manifest.pages.filter({ !$0.value.isEmpty }).keys)
                )
            }
        } catch {
            // The record keeps its claim, which is the state before B1 rather than a new harm; the
            // error is private because its message can embed the gallery's folder path.
            logger.error(
                """
                Corroborated wholesale absence write-back failed, gid: \
                \(gid, privacy: .private(mask: .hash)), \
                error: \(error.localizedDescription, privacy: .private)
                """
            )
        }
    }
}
