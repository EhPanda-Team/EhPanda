//
//  DownloadedGallery+Extensions.swift
//  EhPanda
//

import SwiftUI
import SFSafeSymbols

// MARK: - DownloadBadge
extension DownloadBadge {
    var symbol: SFSymbol {
        switch status {
        case .active: .playFill
        case .queued: .listDash
        case .inactive: .pauseFill
        case .completed: .checkmarkCircleFill
        case .updateAvailable: .arrowUpCircleFill
        case .error: .exclamationmarkTriangleFill
        }
    }

    var color: Color {
        switch status {
        case .active, .queued: .green
        case .inactive, .completed: .gray
        case .updateAvailable: .blue
        case .error: .yellow
        }
    }
}

// MARK: - DownloadRequestPayload
/// Request *identity*: *what* to download. It intentionally carries no execution options
/// (thread limit, cellular, auto-retry); those are always-latest policy resolved per run, so
/// keeping them out of the payload makes "never persisted, always fresh" a structural
/// guarantee rather than a convention. See `DownloadRequestOptions`.
struct DownloadRequestPayload: Equatable, Sendable {
    let gallery: Gallery
    let galleryDetail: GalleryDetail
    let previewURLs: [Int: URL]
    let previewConfig: PreviewConfig
    let host: GalleryHost
    let folderName: String
    let versionMetadata: DownloadVersionMetadata?
    let mode: DownloadStartMode
    let pageSelection: Set<Int>?

    init(
        gallery: Gallery,
        galleryDetail: GalleryDetail,
        previewURLs: [Int: URL],
        previewConfig: PreviewConfig,
        host: GalleryHost,
        folderName: String,
        versionMetadata: DownloadVersionMetadata? = nil,
        mode: DownloadStartMode,
        pageSelection: Set<Int>? = nil
    ) {
        self.gallery = gallery
        self.galleryDetail = galleryDetail
        self.previewURLs = previewURLs
        self.previewConfig = previewConfig
        self.host = host
        self.folderName = folderName
        self.versionMetadata = versionMetadata
        self.mode = mode
        self.pageSelection = pageSelection
    }
}

// MARK: - ReadingContentSource
/// How the reader sources its pages. `.local` is an explicit *offline mode*, not a redundant
/// copy of `.remote`: it is a wholesale network kill-switch (remote mode reads a downloaded
/// file per page when present, so a single missing entry would otherwise trigger a live,
/// quota-burning H@H fetch; the offline gate prevents that for offline reads) and it carries
/// manifest metadata provenance (gallery + language seeded from the manifest, so a downloaded
/// gallery is readable with no database record). When the local files turn up empty it
/// auto-promotes to `.remote`.
enum ReadingContentSource: Equatable {
    case remote
    case local(DownloadedGallery, DownloadManifest)
}

// MARK: - DownloadVersionMetadata
struct DownloadVersionMetadata: Equatable, Codable, Sendable {
    let gid: String
    let token: String
    let currentGID: String?
    let currentKey: String?
    let parentGID: String?
    let parentKey: String?
    let firstGID: String?
    let firstKey: String?

    func hasUpdate(comparedTo download: DownloadedGallery) -> Bool {
        (download.gid, download.token) != (resolvedCurrentGID, resolvedCurrentKey)
    }

    var resolvedCurrentGID: String {
        currentGID?.nonEmpty ?? gid
    }

    var resolvedCurrentKey: String {
        currentKey?.nonEmpty ?? token
    }
}
