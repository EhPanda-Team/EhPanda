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
        pages.filter { $0.status == .failed }.map(\.index)
    }
}
