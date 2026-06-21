//
//  DownloadedGallery+Manifest.swift
//  EhPanda
//

import Foundation

/// The identity record for a downloaded gallery, written to `manifest.json` in its folder.
/// Identity lives *here* (`gid` / `token`), not in the folder path: the human-readable
/// `[gid_token] Title` folder name is presentation, and the title in it can change and
/// re-slot the directory without affecting identity. Folder membership follows the file's
/// location on disk, so this manifest is what re-establishes identity after the gallery is
/// moved or renamed via the Files app.
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
