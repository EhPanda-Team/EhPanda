//
//  DownloadedGallery+Extensions.swift
//  EhPanda
//

import SwiftUI

// MARK: - DownloadBadge
extension DownloadBadge {
    var statusText: String {
        switch status {
        case .queued:
            return L10n.Localizable.Struct.DownloadBadge.Text.queued
        case .active:
            return L10n.Localizable.Struct.DownloadBadge.Text.downloading
        case .inactive:
            return L10n.Localizable.Struct.DownloadBadge.Text.paused
        case .updateAvailable:
            return L10n.Localizable.Struct.DownloadBadge.Text.updateAvailable
        case .completed:
            return L10n.Localizable.Struct.DownloadBadge.Text.downloaded
        case .error:
            return failure == .missingFiles
                ? L10n.Localizable.Struct.DownloadBadge.Text.needsRepair
                : L10n.Localizable.Struct.DownloadBadge.Text.needsAttention
        }
    }

    var progressText: String? {
        guard showsProgressText, let progress else { return nil }
        return L10n.Localizable.Struct.DownloadBadge.progress(
            progress.completedPageCount,
            progress.displayPageCount
        )
    }

    var text: String {
        [statusText, progressText]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    private var showsProgressText: Bool {
        switch status {
        case .active, .inactive:
            return true
        case .error:
            return failure == .partial
        case .queued, .updateAvailable, .completed:
            return false
        }
    }

    var color: Color {
        switch status {
        case .queued:
            return .orange
        case .active:
            return .blue
        case .inactive:
            return .indigo
        case .completed:
            return .green
        case .updateAvailable:
            return .yellow
        case .error:
            return failure == .missingFiles ? .pink : .orange
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
