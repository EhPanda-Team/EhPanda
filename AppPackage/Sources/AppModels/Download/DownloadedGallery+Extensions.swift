import SwiftUI
import SFSafeSymbols

// MARK: - DownloadBadge
extension DownloadBadge {
    public var symbol: SFSymbol {
        switch status {
        case .active: .playFill
        case .queued: .listDash
        case .inactive: .pauseFill
        case .completed: .checkmarkCircleFill
        case .updateAvailable: .arrowUpCircleFill
        case .error: .exclamationmarkTriangleFill
        }
    }

    public var color: Color {
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
public struct DownloadRequestPayload: Equatable, Sendable {
    public let gallery: Gallery
    public let galleryDetail: GalleryDetail
    public let previewURLs: [Int: URL]
    public let previewConfig: PreviewConfig
    public let host: GalleryHost
    public let folderName: String
    public let versionMetadata: DownloadVersionMetadata?
    public let mode: DownloadStartMode
    public let pageSelection: Set<Int>?

    public init(
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
public enum ReadingContentSource: Equatable, Sendable {
    case remote
    case local(DownloadedGallery, DownloadManifest)
}

// MARK: - DownloadVersionMetadata
public struct DownloadVersionMetadata: Equatable, Codable, Sendable {
    public let gid: String
    public let token: String
    public let currentGID: String?
    public let currentKey: String?
    public let parentGID: String?
    public let parentKey: String?
    public let firstGID: String?
    public let firstKey: String?

    public init(
        gid: String,
        token: String,
        currentGID: String?,
        currentKey: String?,
        parentGID: String?,
        parentKey: String?,
        firstGID: String?,
        firstKey: String?
    ) {
        self.gid = gid
        self.token = token
        self.currentGID = currentGID
        self.currentKey = currentKey
        self.parentGID = parentGID
        self.parentKey = parentKey
        self.firstGID = firstGID
        self.firstKey = firstKey
    }

    public func hasUpdate(comparedTo download: DownloadedGallery) -> Bool {
        (download.gid, download.token) != (resolvedCurrentGID, resolvedCurrentKey)
    }

    public var resolvedCurrentGID: String {
        currentGID?.nonEmpty ?? gid
    }

    public var resolvedCurrentKey: String {
        currentKey?.nonEmpty ?? token
    }
}
