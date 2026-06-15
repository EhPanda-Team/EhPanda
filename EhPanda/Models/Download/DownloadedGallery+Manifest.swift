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
    let remoteCoverURL: URL?
    let uploader: String?
    let tags: [GalleryTag]
    let postedDate: Date
    let rating: Float
    var pages: [Int: String]
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
