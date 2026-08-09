import Foundation

public enum DownloadPageStatus: String, Equatable, CaseIterable, Sendable {
    case pending
    case downloaded
    case failed
}

public struct DownloadPageInspection: Equatable, Identifiable, Sendable {
    public init(
        index: Int,
        status: DownloadPageStatus,
        relativePath: String? = nil,
        fileURL: URL? = nil,
        failure: DownloadFailure? = nil
    ) {
        self.index = index
        self.status = status
        self.relativePath = relativePath
        self.fileURL = fileURL
        self.failure = failure
    }
    public var id: Int { index }

    public let index: Int
    public let status: DownloadPageStatus
    public let relativePath: String?
    public let fileURL: URL?
    public let failure: DownloadFailure?
}

public struct DownloadInspection: Equatable, Sendable {
    public init(
        download: DownloadedGallery,
        coverURL: URL? = nil,
        pages: [DownloadPageInspection]
    ) {
        self.download = download
        self.coverURL = coverURL
        self.pages = pages
    }
    public let download: DownloadedGallery
    public let coverURL: URL?
    public let pages: [DownloadPageInspection]

    public var failedPageIndices: [Int] {
        pages.filter({ $0.status == .failed }).map(\.index)
    }

    /// D-SSOT-08: the pages the inspector's retry action may send — the failed set everywhere EXCEPT
    /// over a file-shaped failure on the error surface, where it is the WHOLE page set.
    ///
    /// That surface carries an OPERATION-level signal and nothing else: it says the last validation
    /// could not produce trustworthy evidence for every claimed page — a directory listing that
    /// failed, a page whose bytes could not be read, a wholesale reconciliation the irreversibility
    /// guard refused. It says nothing about any individual page, so no per-page subset is derivable
    /// from it, and the record offers none either. A wholesale-refusal record keeps every hash it
    /// claimed, and under D-SSOT-07 that makes every one of its pages read `.downloaded` — so a
    /// basis drawn as `failed ∪ pending` would be EMPTY for exactly the family with no other way to
    /// start, leaving the button present with nothing in it. The honest selection for "retry the
    /// record whose evidence failed" is therefore every page.
    ///
    /// Naming more pages than are broken costs nothing, because the selection is a REQUEST rather
    /// than a verdict: `retryPages` carries it explicitly into a `.repair` run, whose working seed
    /// keeps every usable file it finds and whose fetch filter re-downloads only the pages actually
    /// missing. The run's own evidence decides what happens; the selection only says which record to
    /// work on. That is also what keeps the affordance independent of the record's honesty, which is
    /// the property 15-57 established and this basis preserves.
    ///
    /// The widening stops exactly at the conjunction. Outside it, undone pages are precisely what
    /// Resume exists for, and admitting them here would grow a second, page-selection-shaped resume
    /// beside it — a blunter one under this basis than under the previous union. A failed page is
    /// itself one of `pages`, so the widened arm is a superset of the plain one and the excluded
    /// regimes keep their previous value unchanged.
    ///
    /// The set is read off `pages` rather than built as `1...download.pageCount`: the two are equal
    /// by construction (`buildInspectionPages` enumerates exactly that range), and the range form
    /// would trap on a zero-page record — the G-15-14 hazard every other page-count site in this
    /// module already guards.
    public var retryablePageIndices: [Int] {
        guard download.displayStatus == .error,
              download.lastError?.code == .fileOperationFailed
        else { return failedPageIndices }
        return pages.map(\.index).sorted()
    }
}
