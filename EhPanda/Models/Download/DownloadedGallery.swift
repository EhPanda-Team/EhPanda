//
//  DownloadedGallery.swift
//  EhPanda
//

import SwiftUI

struct DownloadedGallery: Identifiable, Equatable {
    var id: String { gid }

    let manifest: DownloadManifest
    let folderURL: URL
    let folderName: String
    let localCoverURL: URL?
    let localPageURLs: [Int: URL]
    let displayStatus: DownloadDisplayStatus
    let lastDownloadedDate: Date?
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
        manifest: DownloadManifest,
        folderURL: URL,
        folderName: String,
        localCoverURL: URL?,
        localPageURLs: [Int: URL],
        modificationDate: Date?,
        displayStatus: DownloadDisplayStatus,
        lastError: DownloadFailure? = nil
    ) {
        self.manifest = manifest
        self.folderURL = folderURL
        self.folderName = folderName
        self.localCoverURL = localCoverURL
        self.localPageURLs = localPageURLs
        self.displayStatus = displayStatus
        self.lastDownloadedDate = modificationDate
        self.lastError = lastError
    }
}
