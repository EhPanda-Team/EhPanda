//
//  DownloadedGallery+Extensions.swift
//  EhPanda
//

import SwiftUI

// MARK: - DownloadBadge
extension DownloadBadge {
    var text: String {
        switch self {
        case .none:
            return ""
        case .queued:
            return L10n.Localizable.Struct.DownloadBadge.Text.queued
        case .downloading(let completed, let total):
            return L10n.Localizable.Struct.DownloadBadge.Text.downloading(completed, max(total, 1))
        case .paused(let completed, let total):
            return L10n.Localizable.Struct.DownloadBadge.Text.paused(completed, max(total, 1))
        case .partial(let completed, let total):
            return L10n.Localizable.Struct.DownloadBadge.Text.needsAttentionProgress(
                completed,
                max(total, 1)
            )
        case .downloaded:
            return L10n.Localizable.Struct.DownloadBadge.Text.downloaded
        case .failed:
            return L10n.Localizable.Struct.DownloadBadge.Text.needsAttention
        case .updateAvailable:
            return L10n.Localizable.Struct.DownloadBadge.Text.updateAvailable
        case .missingFiles:
            return L10n.Localizable.Struct.DownloadBadge.Text.needsRepair
        }
    }

    var color: Color {
        switch self {
        case .none:
            return .clear
        case .queued:
            return .orange
        case .downloading:
            return .blue
        case .paused:
            return .indigo
        case .partial:
            return .orange
        case .downloaded:
            return .green
        case .failed:
            return .orange
        case .updateAvailable:
            return .yellow
        case .missingFiles:
            return .pink
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

// MARK: - DownloadGalleryFilter
struct DownloadGalleryFilter: Equatable {
    var excludedCategories = Set<Category>()
    var minimumRatingActivated = false
    var minimumRating = 2
    var pageRangeActivated = false
    var pageLowerBound = ""
    var pageUpperBound = ""

    mutating func fixInvalidData() {
        if !pageLowerBound.isEmpty && Int(pageLowerBound) == nil {
            pageLowerBound = ""
        }
        if !pageUpperBound.isEmpty && Int(pageUpperBound) == nil {
            pageUpperBound = ""
        }
    }

    mutating func reset() {
        self = .init()
    }

    var hasActiveValues: Bool {
        !excludedCategories.isEmpty
            || minimumRatingActivated
            || pageRangeActivated
            || pageLowerBound.notEmpty
            || pageUpperBound.notEmpty
    }
}

// MARK: - DownloadRequestPayload
struct DownloadRequestPayload: Equatable, @unchecked Sendable {
    let gallery: Gallery
    let galleryDetail: GalleryDetail
    let previewURLs: [Int: URL]
    let previewConfig: PreviewConfig
    let host: GalleryHost
    let versionMetadata: DownloadVersionMetadata?
    let options: DownloadOptionsSnapshot
    let mode: DownloadStartMode
    let pageSelection: Set<Int>?

    init(
        gallery: Gallery,
        galleryDetail: GalleryDetail,
        previewURLs: [Int: URL],
        previewConfig: PreviewConfig,
        host: GalleryHost,
        versionMetadata: DownloadVersionMetadata? = nil,
        options: DownloadOptionsSnapshot,
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

    var versionIdentifier: String? {
        DownloadSignatureBuilder.chainVersionIdentifier(
            gid: resolvedCurrentGID,
            token: resolvedCurrentKey
        )
    }

    private var resolvedCurrentGID: String {
        currentGID?.notEmpty == true ? currentGID.forceUnwrapped : gid
    }

    private var resolvedCurrentKey: String {
        currentKey?.notEmpty == true ? currentKey.forceUnwrapped : token
    }
}
