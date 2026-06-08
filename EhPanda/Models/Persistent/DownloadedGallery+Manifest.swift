//
//  DownloadedGallery+Manifest.swift
//  EhPanda
//

import Foundation

struct DownloadManifest: Codable, Equatable, Sendable {
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
    let rating: Float
    let pages: [Int: String]

    func imageURLs(folderURL: URL) -> [Int: URL] {
        DownloadFileStorage(rootURL: folderURL.deletingLastPathComponent())
            .existingPageRelativePaths(
                folderURL: folderURL,
                expectedPageCount: pageCount
            )
            .reduce(into: [Int: URL]()) { result, entry in
                result[entry.key] = folderURL.appendingPathComponent(entry.value)
            }
    }
}

extension DownloadManifest {
    var pageCount: Int {
        pages.count
    }

    var galleryURL: URL {
        host.url
            .appendingPathComponent("g")
            .appendingPathComponent(gid)
            .appendingPathComponent(token)
    }

    var completedPageCount: Int {
        pages.values.filter { !$0.isEmpty }.count
    }

    var isComplete: Bool {
        !pages.isEmpty && completedPageCount == pages.count
    }
}
