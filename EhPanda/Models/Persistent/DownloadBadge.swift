//
//  DownloadBadge.swift
//  EhPanda
//

struct DownloadProgress: Equatable, Sendable {
    let completedPageCount: Int
    let pageCount: Int

    var displayPageCount: Int {
        max(pageCount, 1)
    }

    var fraction: Double {
        Double(completedPageCount) / Double(displayPageCount)
    }
}

// Presentation model for download indicators: the semantic state and the
// page progress stay separate so views can combine them per status and per
// layout (compact or full) without destructuring payloads. "Not downloaded"
// is `nil` at the use site, not a status.
struct DownloadBadge: Equatable, Sendable {
    enum Failure: Equatable, Sendable {
        case general
        case partial
        case missingFiles
    }

    let status: DownloadDisplayStatus
    let failure: Failure?
    let progress: DownloadProgress?

    init(
        status: DownloadDisplayStatus,
        failure: Failure? = nil,
        progress: DownloadProgress? = nil
    ) {
        self.status = status
        self.failure = failure
        self.progress = progress
    }

    var resolvedProgress: DownloadProgress {
        progress ?? DownloadProgress(completedPageCount: 0, pageCount: 1)
    }
}

// MARK: Presets
extension DownloadBadge {
    static let queued = DownloadBadge(status: .queued)
    static let downloaded = DownloadBadge(status: .completed)
    static let updateAvailable = DownloadBadge(status: .updateAvailable)
    static let failed = DownloadBadge(status: .error, failure: .general)
    static let missingFiles = DownloadBadge(status: .error, failure: .missingFiles)

    static func downloading(_ completedPageCount: Int, _ pageCount: Int) -> DownloadBadge {
        .init(
            status: .active,
            progress: .init(completedPageCount: completedPageCount, pageCount: pageCount)
        )
    }

    static func paused(_ completedPageCount: Int, _ pageCount: Int) -> DownloadBadge {
        .init(
            status: .inactive,
            progress: .init(completedPageCount: completedPageCount, pageCount: pageCount)
        )
    }

    static func partial(_ completedPageCount: Int, _ pageCount: Int) -> DownloadBadge {
        .init(
            status: .error,
            failure: .partial,
            progress: .init(completedPageCount: completedPageCount, pageCount: pageCount)
        )
    }
}
