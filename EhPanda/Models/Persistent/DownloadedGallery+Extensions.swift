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

    var ringSymbol: SFSymbol {
        switch status {
        case .active: .playFill
        case .queued: .listDash
        case .inactive: .pauseFill
        case .completed: .checkmark
        case .updateAvailable: .arrowUp
        case .error: .exclamationmark
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

// MARK: - DownloadListFilter
enum DownloadListFilter: String, CaseIterable, Identifiable {
    case all
    case active
    case completed
    case failed
    case update

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return L10n.Localizable.Enum.DownloadListFilter.Title.all
        case .active:
            return L10n.Localizable.Enum.DownloadListFilter.Title.active
        case .completed:
            return L10n.Localizable.Enum.DownloadListFilter.Title.completed
        case .failed:
            return L10n.Localizable.Enum.DownloadListFilter.Title.failed
        case .update:
            return L10n.Localizable.Enum.DownloadListFilter.Title.update
        }
    }
}

// MARK: - DownloadRequestPayload
struct DownloadRequestPayload: Equatable, Sendable {
    let gallery: Gallery
    let galleryDetail: GalleryDetail
    let previewURLs: [Int: URL]
    let previewConfig: PreviewConfig
    let host: GalleryHost
    let versionMetadata: DownloadVersionMetadata?
    let options: DownloadRequestOptions
    let mode: DownloadStartMode
    let pageSelection: Set<Int>?

    init(
        gallery: Gallery,
        galleryDetail: GalleryDetail,
        previewURLs: [Int: URL],
        previewConfig: PreviewConfig,
        host: GalleryHost,
        versionMetadata: DownloadVersionMetadata? = nil,
        options: DownloadRequestOptions,
        mode: DownloadStartMode,
        pageSelection: Set<Int>? = nil
    ) {
        self.gallery = gallery
        self.galleryDetail = galleryDetail
        self.previewURLs = previewURLs
        self.previewConfig = previewConfig
        self.host = host
        self.versionMetadata = versionMetadata
        self.options = options
        self.mode = mode
        self.pageSelection = pageSelection
    }
}

// MARK: - ReadingContentSource
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
