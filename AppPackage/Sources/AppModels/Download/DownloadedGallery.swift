import SwiftUI

public struct DownloadedGallery: Identifiable, Equatable, Sendable {
    public var id: String { gid }

    public let manifest: DownloadManifest
    public let folderURL: URL
    public let folderName: String
    public let localCoverURL: URL?
    public let localPageURLs: [Int: URL]
    public let displayStatus: DownloadDisplayStatus
    public let lastDownloadedDate: Date?
    public let lastError: DownloadFailure?
    /// The live run's own measurement of this gallery, while one stands (D-SSOT-10). Non-nil only
    /// between a run's announcement and its exit; it drives what is DISPLAYED and nothing else. See
    /// `DownloadRunProgress` for why the record cannot carry this itself.
    public let runProgress: DownloadRunProgress?

    public var gid: String { manifest.gid }
    public var host: GalleryHost { manifest.host }
    public var token: String { manifest.token }
    public var title: String { manifest.title }
    public var jpnTitle: String? { manifest.jpnTitle }
    public var uploader: String? { manifest.uploader }
    public var category: Category { manifest.category }
    public var tags: [GalleryTag] { manifest.tags }
    public var pageCount: Int { manifest.pageCount }
    public var postedDate: Date { manifest.postedDate }
    public var rating: Float { manifest.rating }
    public var onlineCoverURL: URL? { manifest.remoteCoverURL }
    public var completedPageCount: Int { manifest.completedPageCount }

    public init(
        manifest: DownloadManifest,
        folderURL: URL,
        folderName: String,
        localCoverURL: URL?,
        localPageURLs: [Int: URL],
        modificationDate: Date?,
        displayStatus: DownloadDisplayStatus,
        lastError: DownloadFailure? = nil,
        runProgress: DownloadRunProgress? = nil
    ) {
        self.manifest = manifest
        self.folderURL = folderURL
        self.folderName = folderName
        self.localCoverURL = localCoverURL
        self.localPageURLs = localPageURLs
        self.displayStatus = displayStatus
        self.lastDownloadedDate = modificationDate
        self.lastError = lastError
        self.runProgress = runProgress
    }
}
