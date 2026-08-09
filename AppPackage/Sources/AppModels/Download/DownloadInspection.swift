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

    public var pendingPageIndices: [Int] {
        pages.filter({ $0.status == .pending }).map(\.index)
    }

    /// D-G5C-01: the pages the inspector's retry action may send, which is the failed set everywhere
    /// EXCEPT over a file-shaped failure on the error surface, where the pending pages join it.
    ///
    /// A page whose file was deleted outside the app derives `.pending`, not `.failed` — no download
    /// attempt ever failed for it — so a failed-only basis reports nothing for a gallery whose files
    /// are simply gone. Where the record can be corrected that costs nothing, because the corrected
    /// record is `.inactive` and Resume takes it from there. Where the correction is REFUSED (a
    /// failed page-file scan, unprobed pages, or a blanking that would empty every claimed hash at
    /// once) the record keeps claiming its pages under a transient `.error`, and `.error` hard-closes
    /// the Resume path by design — so the failed-only basis left that family with no start at all.
    ///
    /// The widening stops exactly there, and the conjunction is what stops it. Outside this shape
    /// pending pages are precisely what Resume exists for, and admitting them here would grow a
    /// second, page-selection-shaped resume beside it. Because the union is empty of pending pages
    /// whenever the shape does not hold, and a failed page is never also pending, the plain
    /// failed-pages case keeps its previous value unchanged.
    ///
    /// The selection travels explicitly into `retryPages`, so a start built from this basis never
    /// consults the record's own claims — which is what makes it work for the refusal family, whose
    /// defining property is a record that cannot speak for itself.
    public var retryablePageIndices: [Int] {
        guard download.displayStatus == .error,
              download.lastError?.code == .fileOperationFailed
        else { return failedPageIndices }
        return Array(Set(failedPageIndices).union(pendingPageIndices)).sorted()
    }
}
