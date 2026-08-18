import AppModels
import Foundation

// MARK: - Private helpers for public API
extension DownloadCoordinator {
    /// A page's displayed state is a function of ONE completeness basis and its recorded page
    /// failure, and of nothing else. Which basis is the two regimes below.
    ///
    /// **D-SSOT-10 — while a run's own measurement stands for this gallery, that measurement is the
    /// basis (G-15-2F).** `download.runProgress` carries the run's credited page set, and a page
    /// reads `.downloaded` exactly when it is credited. The record cannot serve here: for the
    /// wholesale-refusal family it claims every page for the ENTIRE re-download, because the
    /// irreversibility guard refuses to blank a whole manifest on one scan — so a user who opened
    /// the Download Status sheet during a 27-page repair read "Downloading 27/27 · Downloaded (27) ·
    /// Pending (0)" while the continued-processing card, fed by this same measurement, correctly
    /// counted up from zero. Per AGENTS.md's SSOT clause this is an operation-level, run-scoped
    /// signal for what the record legitimately cannot record; it writes nothing, consults no disk,
    /// never outranks queue membership, and is retired with the run. The badge's numerator is the
    /// SIZE of the very set this reads membership from (`RunProgressBasis.creditedPageIndices`), so
    /// the header and the page groups cannot disagree. Consequences, all deliberate: a page the run
    /// owes that failed still reads `.failed`; a page the run owes that has not landed reads
    /// `.pending` even while the manifest claims it; a page the run neither inherited nor owes reads
    /// `.pending` for the run's duration and returns to its record reading at the exit; and a
    /// credited page with a stale failure entry reads `.downloaded`, exactly as a recorded hash does
    /// below. For the honest family the two regimes agree at every flush, so nothing visibly moves.
    ///
    /// **D-SSOT-07 — out of a run the basis is the RECORD**, its manifest hash and its recorded page
    /// failure, unchanged.
    ///
    /// The badge counts a gallery's finished pages by the manifest's non-empty hashes
    /// (`completedPageCount`). Deriving these page states from a live file-presence probe made the
    /// two displays two different functions of two different inputs, and they diverged in exactly
    /// the window G-15-5 reported: page files deleted outside the app, the record still claiming
    /// complete, the badge reading 36-of-36 beside a page list reading 10 pending. Reading both from
    /// the one persisted basis removes that possibility by construction, rather than by keeping two
    /// sensors in step.
    ///
    /// So the inspector shows the record's CLAIM. After an external deletion that claim is stale,
    /// and it is deliberately shown stale: it is honest about what the record says, it agrees with
    /// the badge beside it, and **Validate is the single tap that senses such a divergence and
    /// reconciles it durably** (D-G5B-01, D-SSOT-01) — after which this same derivation reports the
    /// correction, because the record moved. A sensor here could only re-open a disagreement it has
    /// no authority to fix: this function writes nothing.
    ///
    /// The directory listing keeps exactly one job: resolving a page's on-disk `relativePath` and
    /// `fileURL` so a thumbnail can render, answering nil when no file is there. It is a
    /// rendering-resource resolver, never a status basis — so a missing thumbnail under a downloaded
    /// claim is the approved pre-validate appearance, and a stray file beside a blank hash renders
    /// while still reading `.pending`. `existingRelativePaths` is already an existence-verified
    /// listing, so this helper performs no file-system call of its own.
    public func buildInspectionPages(
        download: DownloadedGallery,
        activeFolderURL: URL?,
        existingRelativePaths: [Int: String],
        failedPages: [Int: PageFailure]
    ) -> [DownloadPageInspection] {
        // G-15-14, same class as the two range sites: a record's page count reaches a range here
        // too. `validateDecodedManifest` rejects an empty page dictionary, so no manifest READ from
        // disk can be zero — but an in-memory index record is written straight from
        // `makeInitialManifest`, and this function is public, so the guard stands for direct
        // callers and future routes rather than resting on a producer-side argument.
        guard download.pageCount > 0 else { return [] }
        return (1...download.pageCount).map { page -> DownloadPageInspection in
            let listedRelativePath = existingRelativePaths[page]
            let fileURL: URL? =
                if let listedRelativePath, let activeFolderURL {
                    activeFolderURL.appendingPathComponent(listedRelativePath)
                } else {
                    nil
                }
            let isDownloaded = download.runProgress
                .map({ $0.creditedPageIndices.contains(page) })
                ?? (download.manifest.pages[page]?.isEmpty == false)

            if isDownloaded {
                return .init(
                    index: page,
                    status: .downloaded,
                    relativePath: listedRelativePath,
                    fileURL: fileURL,
                    failure: nil
                )
            }

            if let failedPage = failedPages[page] {
                return .init(
                    index: page,
                    status: .failed,
                    // The failure's own recorded path stays the fallback: it is failure metadata
                    // rather than a listing product, and it is what this branch carried for a page
                    // with no file on disk — which, before the status probe was removed, was the
                    // only way a page could reach here at all.
                    relativePath: listedRelativePath ?? failedPage.relativePath,
                    fileURL: fileURL,
                    failure: .init(error: failedPage.error)
                )
            }

            return .init(
                index: page,
                status: .pending,
                relativePath: listedRelativePath,
                fileURL: fileURL,
                failure: nil
            )
        }
    }

    public func clearSelectedFailedPages(
        gid: String,
        selectedPageIndices: [Int]
    ) {
        for index in selectedPageIndices {
            failedPageErrors[gid]?[index] = nil
        }
        if failedPageErrors[gid]?.isEmpty == true {
            failedPageErrors[gid] = nil
        }
    }
}
