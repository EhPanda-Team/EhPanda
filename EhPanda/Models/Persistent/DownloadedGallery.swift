//
//  DownloadedGallery.swift
//  EhPanda
//

import SwiftUI

struct DownloadOptionsSnapshot: Codable, Equatable, Sendable {
    var threadLimit = 1
    var allowCellular = true
    var autoRetryFailedPages = true

    var workerCount: Int {
        threadLimit
    }

    private enum CodingKeys: String, CodingKey {
        case threadLimit
        case allowCellular
        case autoRetryFailedPages
    }

    init(
        threadLimit: Int = 1,
        allowCellular: Bool = true,
        autoRetryFailedPages: Bool = true
    ) {
        self.threadLimit = threadLimit
        self.allowCellular = allowCellular
        self.autoRetryFailedPages = autoRetryFailedPages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        threadLimit = try container.decodeIfPresent(Int.self, forKey: .threadLimit) ?? 1
        allowCellular = try container.decodeIfPresent(Bool.self, forKey: .allowCellular) ?? true
        autoRetryFailedPages = try container.decodeIfPresent(Bool.self, forKey: .autoRetryFailedPages) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(threadLimit, forKey: .threadLimit)
        try container.encode(allowCellular, forKey: .allowCellular)
        try container.encode(autoRetryFailedPages, forKey: .autoRetryFailedPages)
    }
}

enum DownloadStatus: String, Codable, Equatable, CaseIterable, Sendable {
    case queued
    case downloading
    case paused
    case partial
    case completed
    case failed
    case updateAvailable
    case missingFiles
}

enum DownloadFailureCode: String, Codable, Equatable, Sendable {
    case quotaExceeded
    case authenticationRequired
    case fileOperationFailed
    case ipBanned
    case networkingFailed
    case parseFailed
    case notFound
    case unknown
}

struct DownloadFailure: Codable, Equatable, Sendable {
    var code: DownloadFailureCode
    var message: String

    init(code: DownloadFailureCode, message: String) {
        self.code = code
        self.message = message
    }

    init(error: AppError) {
        switch error {
        case .quotaExceeded:
            self = .init(code: .quotaExceeded, message: error.alertText)
        case .authenticationRequired:
            self = .init(code: .authenticationRequired, message: error.alertText)
        case .fileOperationFailed(let reason):
            self = .init(code: .fileOperationFailed, message: reason)
        case .ipBanned(let interval):
            self = .init(code: .ipBanned, message: interval.description)
        case .networkingFailed:
            self = .init(code: .networkingFailed, message: error.alertText)
        case .parseFailed:
            self = .init(code: .parseFailed, message: error.alertText)
        case .notFound:
            self = .init(code: .notFound, message: error.alertText)
        default:
            self = .init(code: .unknown, message: error.alertText)
        }
    }

    var appError: AppError {
        switch code {
        case .quotaExceeded:
            return .quotaExceeded
        case .authenticationRequired:
            return .authenticationRequired
        case .fileOperationFailed:
            return .fileOperationFailed(message)
        case .ipBanned:
            return .ipBanned(.unrecognized(content: message))
        case .networkingFailed:
            return .networkingFailed
        case .parseFailed:
            return .parseFailed
        case .notFound:
            return .notFound
        case .unknown:
            return .unknown
        }
    }
}

enum DownloadStartMode: String, Codable, Equatable, Sendable {
    case initial
    case update
    case redownload
    case repair
}

struct DownloadFailedPagesSnapshot: Codable, Equatable, Sendable {
    struct Page: Codable, Equatable, Identifiable, Sendable {
        var id: Int { index }

        let index: Int
        let relativePath: String?
        let failure: DownloadFailure
    }

    var pages: [Page]

    var map: [Int: Page] {
        Dictionary(uniqueKeysWithValues: pages.map { ($0.index, $0) })
    }
}

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

enum DownloadBadge: Equatable {
    case none
    case queued
    case downloading(Int, Int)
    case paused(Int, Int)
    case partial(Int, Int)
    case downloaded
    case failed
    case updateAvailable
    case missingFiles
}

struct DownloadedGallery: Identifiable, Equatable {
    var id: String { gid }

    let gid: String
    let host: GalleryHost
    let token: String
    let title: String
    let jpnTitle: String?
    let uploader: String?
    let category: Category
    let tags: [GalleryTag]
    let pageCount: Int
    let postedDate: Date
    let rating: Float
    let onlineCoverURL: URL?
    let folderRelativePath: String
    let coverRelativePath: String?
    let status: DownloadStatus
    let completedPageCount: Int
    let lastDownloadedAt: Date?
    let lastError: DownloadFailure?
    let downloadOptionsSnapshot: DownloadOptionsSnapshot
    let remoteVersionSignature: String
    let latestRemoteVersionSignature: String?
    let pendingOperation: DownloadStartMode?

    init(
        gid: String,
        host: GalleryHost,
        token: String,
        title: String,
        jpnTitle: String?,
        uploader: String?,
        category: Category,
        tags: [GalleryTag],
        pageCount: Int,
        postedDate: Date,
        rating: Float,
        onlineCoverURL: URL?,
        folderRelativePath: String,
        coverRelativePath: String?,
        status: DownloadStatus,
        completedPageCount: Int,
        lastDownloadedAt: Date?,
        lastError: DownloadFailure?,
        downloadOptionsSnapshot: DownloadOptionsSnapshot,
        remoteVersionSignature: String,
        latestRemoteVersionSignature: String?,
        pendingOperation: DownloadStartMode? = nil
    ) {
        self.gid = gid
        self.host = host
        self.token = token
        self.title = title
        self.jpnTitle = jpnTitle
        self.uploader = uploader
        self.category = category
        self.tags = tags
        self.pageCount = pageCount
        self.postedDate = postedDate
        self.rating = rating
        self.onlineCoverURL = onlineCoverURL
        self.folderRelativePath = folderRelativePath
        self.coverRelativePath = coverRelativePath
        self.status = status
        self.completedPageCount = completedPageCount
        self.lastDownloadedAt = lastDownloadedAt
        self.lastError = lastError
        self.downloadOptionsSnapshot = downloadOptionsSnapshot
        self.remoteVersionSignature = remoteVersionSignature
        self.latestRemoteVersionSignature = latestRemoteVersionSignature
        self.pendingOperation = pendingOperation
    }

    init(
        manifest: DownloadManifest,
        folderRelativePath: String,
        modifiedAt: Date?,
        displayStatus: DownloadDisplayStatus,
        lastError: DownloadFailure? = nil
    ) {
        self.init(
            gid: manifest.gid,
            host: manifest.host,
            token: manifest.token,
            title: manifest.title,
            jpnTitle: manifest.jpnTitle,
            uploader: manifest.uploader,
            category: manifest.category,
            tags: manifest.tags,
            pageCount: manifest.pageCount,
            postedDate: manifest.postedDate,
            rating: manifest.rating,
            onlineCoverURL: nil,
            folderRelativePath: folderRelativePath,
            coverRelativePath: manifest.coverRelativePath,
            status: displayStatus.downloadStatus,
            completedPageCount: manifest.completedPageCount,
            lastDownloadedAt: modifiedAt ?? manifest.downloadedAt,
            lastError: lastError,
            downloadOptionsSnapshot: manifest.downloadOptions,
            remoteVersionSignature: "chain:\(manifest.gid):\(manifest.token)",
            latestRemoteVersionSignature: "chain:\(manifest.gid):\(manifest.token)"
        )
    }
}

private extension DownloadDisplayStatus {
    var downloadStatus: DownloadStatus {
        switch self {
        case .active:
            return .downloading
        case .queued:
            return .queued
        case .updateAvailable:
            return .updateAvailable
        case .error:
            return .failed
        case .inactive:
            return .paused
        case .completed:
            return .completed
        }
    }
}
