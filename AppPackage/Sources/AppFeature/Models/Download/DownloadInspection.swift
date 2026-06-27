import Foundation

enum DownloadPageStatus: String, Equatable, CaseIterable, Sendable {
    case pending
    case downloaded
    case failed
}

struct DownloadPageInspection: Equatable, Identifiable, Sendable {
    var id: Int { index }

    let index: Int
    let status: DownloadPageStatus
    let relativePath: String?
    let fileURL: URL?
    let failure: DownloadFailure?
}

struct DownloadInspection: Equatable, Sendable {
    let download: DownloadedGallery
    let coverURL: URL?
    let pages: [DownloadPageInspection]

    var failedPageIndices: [Int] {
        pages.filter { $0.status == .failed }.map(\.index)
    }
}
