//
//  DownloadedGallery+Manifest.swift
//  EhPanda
//

import Foundation

struct DownloadManifest: Codable, Equatable, Sendable {
    struct Page: Codable, Equatable, Identifiable, Sendable {
        var id: Int { index }

        let index: Int
        let relativePath: String
        let fileHash: String?

        init(
            index: Int,
            relativePath: String,
            fileHash: String? = nil
        ) {
            self.index = index
            self.relativePath = relativePath
            self.fileHash = fileHash
        }
    }

    let gid: String
    let host: GalleryHost
    let token: String
    let title: String
    let jpnTitle: String?
    let category: Category
    let language: Language
    let uploader: String?
    let tags: [GalleryTag]
    let postedDate: Date
    let pageCount: Int
    let coverRelativePath: String?
    let coverFileHash: String?
    let galleryURL: URL
    let rating: Float
    let downloadOptions: DownloadOptionsSnapshot
    let downloadedAt: Date
    let pages: [Page]

    init(
        gid: String,
        host: GalleryHost,
        token: String,
        title: String,
        jpnTitle: String?,
        category: Category,
        language: Language,
        uploader: String?,
        tags: [GalleryTag],
        postedDate: Date,
        pageCount: Int,
        coverRelativePath: String?,
        coverFileHash: String? = nil,
        galleryURL: URL,
        rating: Float,
        downloadOptions: DownloadOptionsSnapshot,
        downloadedAt: Date,
        pages: [Page]
    ) {
        self.gid = gid
        self.host = host
        self.token = token
        self.title = title
        self.jpnTitle = jpnTitle
        self.category = category
        self.language = language
        self.uploader = uploader
        self.tags = tags
        self.postedDate = postedDate
        self.pageCount = pageCount
        self.coverRelativePath = coverRelativePath
        self.coverFileHash = coverFileHash
        self.galleryURL = galleryURL
        self.rating = rating
        self.downloadOptions = downloadOptions
        self.downloadedAt = downloadedAt
        self.pages = pages
    }

    func imageURLs(folderURL: URL) -> [Int: URL] {
        Dictionary(uniqueKeysWithValues: pages.map {
            ($0.index, folderURL.appendingPathComponent($0.relativePath))
        })
    }
}

extension DownloadManifest {
    var completedPageCount: Int {
        pages.filter { $0.fileHash?.isEmpty == false }.count
    }

    var isComplete: Bool {
        !pages.isEmpty && completedPageCount == pages.count
    }
}
