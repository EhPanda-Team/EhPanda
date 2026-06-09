//
//  DownloadedGallery.swift
//  EhPanda
//

import SwiftUI

struct DownloadedGallery: Identifiable, Equatable {
    var id: String { gid }

    let manifest: DownloadManifest
    let folderURL: URL
    let displayStatus: DownloadDisplayStatus
    let lastDownloadedAt: Date?
    let lastError: DownloadFailure?

    var gid: String { manifest.gid }
    var host: GalleryHost { manifest.host }
    var token: String { manifest.token }
    var title: String { manifest.title }
    var jpnTitle: String? { manifest.jpnTitle }
    var uploader: String? { manifest.uploader }
    var category: Category { manifest.category }
    var tags: [GalleryTag] { manifest.tags }
    var pageCount: Int { manifest.pageCount }
    var postedDate: Date { manifest.postedDate }
    var rating: Float { manifest.rating }
    var onlineCoverURL: URL? { manifest.remoteCoverURL }
    var completedPageCount: Int { manifest.completedPageCount }

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
        displayStatus: DownloadDisplayStatus,
        completedPageCount: Int,
        lastDownloadedAt: Date?,
        lastError: DownloadFailure?
    ) {
        let clampedCompletedPageCount = min(max(completedPageCount, 0), pageCount)
        self.manifest = DownloadManifest(
            gid: gid,
            host: host,
            token: token,
            title: title,
            jpnTitle: jpnTitle,
            category: category,
            language: .japanese,
            remoteCoverURL: onlineCoverURL,
            uploader: uploader,
            tags: tags,
            postedDate: postedDate,
            rating: rating,
            pages: pageCount > 0
                ? Dictionary(
                    uniqueKeysWithValues: (1...pageCount).map {
                        ($0, $0 <= clampedCompletedPageCount ? "sha256:fixture-\($0)" : "")
                    }
                )
                : [:]
        )
        self.folderURL = folderURL
        self.displayStatus = displayStatus
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
        self.manifest = manifest
        self.folderURL = folderURL
        self.displayStatus = displayStatus
        self.lastDownloadedAt = modifiedAt
        self.lastError = lastError
    }
}
