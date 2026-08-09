import AppModels
import Foundation

// MARK: - Private helpers for public API
extension DownloadCoordinator {
    /// D-SSOT-07: a page's displayed state is a function of the RECORD — its manifest hash and its
    /// recorded page failure — and of nothing else.
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

            if download.manifest.pages[page]?.isEmpty == false {
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
