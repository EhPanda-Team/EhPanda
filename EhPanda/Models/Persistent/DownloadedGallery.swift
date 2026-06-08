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

enum DownloadStartMode: String, Codable, Equatable, Sendable {
    case initial
    case update
    case redownload
    case repair
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
    let folderURL: URL
    let status: DownloadStatus
    let completedPageCount: Int
    let lastDownloadedAt: Date?
    let lastError: DownloadFailure?

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
        folderURL: URL,
        status: DownloadStatus,
        completedPageCount: Int,
        lastDownloadedAt: Date?,
        lastError: DownloadFailure?
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
        self.folderURL = folderURL
        self.status = status
        self.completedPageCount = completedPageCount
        self.lastDownloadedAt = lastDownloadedAt
        self.lastError = lastError
    }

    init(
        manifest: DownloadManifest,
        folderURL: URL,
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
            onlineCoverURL: manifest.remoteCoverURL,
            folderURL: folderURL,
            status: displayStatus.downloadStatus,
            completedPageCount: manifest.completedPageCount,
            lastDownloadedAt: modifiedAt,
            lastError: lastError
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
